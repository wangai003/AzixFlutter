#![no_std]

use soroban_sdk::{
    contract, contracterror, contractevent, contractimpl, contracttype, Address, Bytes, Env, Symbol,
    Vec, IntoVal,
};

#[contracterror]
#[derive(Copy, Clone, Debug, Eq, PartialEq)]
pub enum RaffleError {
    RaffleNotFound = 1,
    RaffleAlreadyExists = 2,
    RaffleEnded = 3,
    InsufficientBalance = 4,
    AlreadyEntered = 5,
    InvalidDeadline = 6,
    Unauthorized = 7,
    NoParticipants = 8,
    DrawAlreadyPerformed = 9,
}

#[contracttype]
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Raffle {
    pub creator: Address,
    pub title: Symbol,
    pub description: Symbol,
    pub entry_requirement: i128, // AKOFA required to enter
    pub prize_type: Symbol,      // e.g., "AKOFA", "NFT", etc.
    pub prize_amount: i128,
    pub num_winners: u32,
    pub draw_deadline: u64, // ledger timestamp
    pub participants: Vec<Address>,
    pub winners: Vec<Address>,
    pub is_drawn: bool,
    pub created_at: u64,
}

#[contractevent]
#[derive(Clone)]
pub struct RaffleCreated {
    pub raffle_id: u64,
    pub creator: Address,
    pub title: Symbol,
    pub prize_amount: i128,
}

#[contractevent]
#[derive(Clone)]
pub struct RaffleEntered {
    pub raffle_id: u64,
    pub participant: Address,
    pub amount_paid: i128,
}

#[contractevent]
#[derive(Clone)]
pub struct WinnersDrawn {
    pub raffle_id: u64,
    pub winners: Vec<Address>,
}

#[contractevent]
#[derive(Clone)]
pub struct PrizesDistributed {
    pub raffle_id: u64,
    pub winners: Vec<Address>,
    pub prize_per_winner: i128,
}

#[contract]
pub struct RaffleContract;

#[contractimpl]
impl RaffleContract {
    /// Initialize with AKOFA token address
    pub fn initialize(env: Env, akofa_token: Address) {
        env.storage()
            .instance()
            .set(&Symbol::new(&env, "akofa_token"), &akofa_token);
    }

    /// Create a new raffle
    pub fn create_raffle(
        env: Env,
        raffle_id: u64,
        title: Symbol,
        description: Symbol,
        entry_requirement: i128,
        prize_type: Symbol,
        prize_amount: i128,
        num_winners: u32,
        draw_deadline: u64,
    ) -> Result<(), RaffleError> {
        if env.storage().persistent().has(&raffle_id) {
            return Err(RaffleError::RaffleAlreadyExists);
        }

        let current_time = env.ledger().timestamp();
        if draw_deadline <= current_time {
            return Err(RaffleError::InvalidDeadline);
        }

        let creator = env.current_contract_address(); // Use contract address as creator for now

        let raffle = Raffle {
            creator: creator.clone(),
            title: title.clone(),
            description: description.clone(),
            entry_requirement,
            prize_type: prize_type.clone(),
            prize_amount,
            num_winners,
            draw_deadline,
            participants: Vec::new(&env),
            winners: Vec::new(&env),
            is_drawn: false,
            created_at: current_time,
        };

        env.storage().persistent().set(&raffle_id, &raffle);

        RaffleCreated {
            raffle_id,
            creator,
            title,
            prize_amount,
        }
        .publish(&env);

        Ok(())
    }

    /// Enter a raffle by paying entry requirement in AKOFA
    pub fn enter_raffle(env: Env, raffle_id: u64, participant: Address) -> Result<(), RaffleError> {
        let mut raffle: Raffle = env
            .storage()
            .persistent()
            .get(&raffle_id)
            .ok_or(RaffleError::RaffleNotFound)?;

        if env.ledger().timestamp() >= raffle.draw_deadline {
            return Err(RaffleError::RaffleEnded);
        }

        if raffle.is_drawn {
            return Err(RaffleError::DrawAlreadyPerformed);
        }

        if raffle.participants.contains(&participant) {
            return Err(RaffleError::AlreadyEntered);
        }

        let akofa_token: Address = env
            .storage()
            .instance()
            .get(&Symbol::new(&env, "akofa_token"))
            .unwrap();

        let balance_args = Vec::from_array(&env, [participant.clone().into_val(&env)]);
        let balance = env.invoke_contract::<i128>(
            &akofa_token,
            &Symbol::new(&env, "balance"),
            balance_args,
        );

        if balance < raffle.entry_requirement {
            return Err(RaffleError::InsufficientBalance);
        }

        // Transfer AKOFA to contract
        let transfer_args = Vec::from_array(
            &env,
            [
                participant.clone().into_val(&env),
                env.current_contract_address().into_val(&env),
                raffle.entry_requirement.into_val(&env),
            ],
        );
        env.invoke_contract::<()>(
            &akofa_token,
            &Symbol::new(&env, "transfer"),
            transfer_args,
        );

        raffle.participants.push_back(participant.clone());
        env.storage().persistent().set(&raffle_id, &raffle);

        RaffleEntered {
            raffle_id,
            participant,
            amount_paid: raffle.entry_requirement,
        }
        .publish(&env);

        Ok(())
    }

    /// Draw winners randomly using ledger data as entropy
    pub fn draw_winners(env: Env, raffle_id: u64) -> Result<Vec<Address>, RaffleError> {
        let mut raffle: Raffle = env
            .storage()
            .persistent()
            .get(&raffle_id)
            .ok_or(RaffleError::RaffleNotFound)?;

        if env.ledger().timestamp() < raffle.draw_deadline {
            return Err(RaffleError::InvalidDeadline);
        }

        if raffle.is_drawn {
            return Err(RaffleError::DrawAlreadyPerformed);
        }

        if raffle.participants.is_empty() {
            return Err(RaffleError::NoParticipants);
        }

        let num_participants = raffle.participants.len() as u32;
        let num_winners = raffle.num_winners.min(num_participants);

        let entropy = env.ledger().sequence() as u64 + env.ledger().timestamp() + raffle_id;

        let mut winners = Vec::new(&env);
        let mut available = Vec::new(&env);
        for i in 0..num_participants {
            available.push_back(i);
        }

        for _ in 0..num_winners {
            if available.is_empty() {
                break;
            }

            let mut data = Bytes::new(&env);
            data.extend_from_slice(&entropy.to_be_bytes());
            data.extend_from_slice(&(available.len() as u32).to_be_bytes());
            data.extend_from_slice(&raffle_id.to_be_bytes());
            let hash = env.crypto().sha256(&data);

            let bytes = hash.to_array();
            let random_bytes = [bytes[0], bytes[1], bytes[2], bytes[3]];
            let random_u32 = u32::from_be_bytes(random_bytes);
            let idx = (random_u32 % available.len() as u32) as u32;

            let selected_idx = available.get_unchecked(idx);
            let winner = raffle.participants.get_unchecked(selected_idx);
            winners.push_back(winner);
            available.remove(idx);
        }

        raffle.winners = winners.clone();
        raffle.is_drawn = true;
        env.storage().persistent().set(&raffle_id, &raffle);

        WinnersDrawn {
            raffle_id,
            winners: winners.clone(),
        }
        .publish(&env);

        Ok(winners)
    }

    /// Distribute prizes equally to all winners
    pub fn distribute_prizes(env: Env, raffle_id: u64) -> Result<(), RaffleError> {
        let raffle: Raffle = env
            .storage()
            .persistent()
            .get(&raffle_id)
            .ok_or(RaffleError::RaffleNotFound)?;

        if !raffle.is_drawn {
            return Err(RaffleError::DrawAlreadyPerformed);
        }

        let akofa_token: Address = env
            .storage()
            .instance()
            .get(&Symbol::new(&env, "akofa_token"))
            .unwrap();

        let prize_per_winner = raffle.prize_amount / raffle.winners.len() as i128;

        for winner in raffle.winners.iter() {
            let args = Vec::from_array(
                &env,
                [
                    env.current_contract_address().into_val(&env),
                    winner.clone().into_val(&env),
                    prize_per_winner.into_val(&env),
                ],
            );
            env.invoke_contract::<()>(
                &akofa_token,
                &Symbol::new(&env, "transfer"),
                args,
            );
        }

        PrizesDistributed {
            raffle_id,
            winners: raffle.winners.clone(),
            prize_per_winner,
        }
        .publish(&env);

        Ok(())
    }

    /// View a raffle
    pub fn get_raffle(env: Env, raffle_id: u64) -> Option<Raffle> {
        env.storage().persistent().get(&raffle_id)
    }

    /// Get participants
    pub fn get_participants(env: Env, raffle_id: u64) -> Option<Vec<Address>> {
        env.storage()
            .persistent()
            .get(&raffle_id)
            .map(|r: Raffle| r.participants)
    }

    /// Get winners
    pub fn get_winners(env: Env, raffle_id: u64) -> Option<Vec<Address>> {
        env.storage()
            .persistent()
            .get(&raffle_id)
            .map(|r: Raffle| r.winners)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use soroban_sdk::testutils::Address as _;

    #[test]
    fn test_create_raffle() {
        let env = Env::default();
        let contract_id = env.register_contract(None, RaffleContract);
        let client = RaffleContractClient::new(&env, &contract_id);

        let akofa_token = Address::generate(&env);
        client.initialize(&akofa_token);

        client.create_raffle(
            &1u64,
            &Symbol::new(&env, "TestRaffle"),
            &Symbol::new(&env, "A_test_raffle"),
            &100i128,
            &Symbol::new(&env, "AKOFA"),
            &1000i128,
            &1u32,
            &(env.ledger().timestamp() + 86400),
        );

        let raffle = client.get_raffle(&1u64);
        assert!(raffle.is_some());
        assert_eq!(raffle.unwrap().title, Symbol::new(&env, "TestRaffle"));
    }
}

