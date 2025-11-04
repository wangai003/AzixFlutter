#![no_std]

use soroban_sdk::{
    contract, contracterror, contractevent, contractimpl, contracttype, Address, Env, Symbol,
    Vec, IntoVal,
};

#[contracterror]
#[derive(Copy, Clone, Debug, Eq, PartialEq)]
pub enum MiningError {
    SessionNotFound = 1,
    SessionAlreadyActive = 2,
    SessionNotActive = 3,
    SessionNotExpired = 4,
    InsufficientBalance = 5,
    Unauthorized = 6,
    InvalidDuration = 7,
}

#[contracttype]
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct MiningSession {
    pub user: Address,
    pub start_time: u64,
    pub end_time: u64,
    pub is_active: bool,
    pub mined_amount: i128,
    pub last_payout_time: u64,
}

#[contractevent]
#[derive(Clone)]
pub struct MiningStarted {
    pub user: Address,
    pub session_id: u64,
    pub start_time: u64,
    pub end_time: u64,
}

#[contractevent]
#[derive(Clone)]
pub struct MiningPayout {
    pub user: Address,
    pub session_id: u64,
    pub amount: i128,
    pub payout_time: u64,
}

#[contractevent]
#[derive(Clone)]
pub struct MiningEnded {
    pub user: Address,
    pub session_id: u64,
    pub total_mined: i128,
}

#[contract]
pub struct MiningContract;

#[contractimpl]
impl MiningContract {
    /// Initialize with AKOFA token address
    pub fn initialize(env: Env, akofa_token: Address) {
        env.storage()
            .instance()
            .set(&Symbol::new(&env, "akofa_token"), &akofa_token);
    }

    /// Start a mining session (24 hours duration)
    pub fn start_mining(env: Env, user: Address) -> Result<u64, MiningError> {
        // Check if user already has an active session
        let session_key = (user.clone(), Symbol::new(&env, "active_session"));
        if env.storage().persistent().has(&session_key) {
            return Err(MiningError::SessionAlreadyActive);
        }

        let current_time = env.ledger().timestamp();
        let duration_seconds = 24 * 60 * 60; // 24 hours
        let end_time = current_time + duration_seconds;

        let session_id = env.storage().instance().get(&Symbol::new(&env, "next_session_id")).unwrap_or(0u64);
        let next_session_id = session_id + 1;

        let session = MiningSession {
            user: user.clone(),
            start_time: current_time,
            end_time,
            is_active: true,
            mined_amount: 0,
            last_payout_time: current_time,
        };

        // Store session
        env.storage().persistent().set(&session_id, &session);
        // Set active session for user
        env.storage().persistent().set(&session_key, &session_id);
        // Update next session ID
        env.storage().instance().set(&Symbol::new(&env, "next_session_id"), &next_session_id);

        MiningStarted {
            user: user.clone(),
            session_id,
            start_time: current_time,
            end_time,
        }
        .publish(&env);

        Ok(session_id)
    }

    /// Process automatic payout for a session
    pub fn process_payout(env: Env, session_id: u64) -> Result<(), MiningError> {
        let mut session: MiningSession = env
            .storage()
            .persistent()
            .get(&session_id)
            .ok_or(MiningError::SessionNotFound)?;

        if !session.is_active {
            return Err(MiningError::SessionNotActive);
        }

        let current_time = env.ledger().timestamp();
        if current_time < session.end_time {
            return Err(MiningError::SessionNotExpired);
        }

        // Calculate mined amount: 0.25 AKOFA per hour
        let total_hours = (session.end_time - session.start_time) / 3600;
        let mined_amount = (total_hours as i128) * 25000000; // 0.25 * 10^8 (8 decimal places for AKOFA)

        session.mined_amount = mined_amount;
        session.is_active = false;

        // Store updated session
        env.storage().persistent().set(&session_id, &session);

        // Remove active session reference
        let session_key = (session.user.clone(), Symbol::new(&env, "active_session"));
        env.storage().persistent().remove(&session_key);

        // Transfer AKOFA to user
        let akofa_token: Address = env
            .storage()
            .instance()
            .get(&Symbol::new(&env, "akofa_token"))
            .unwrap();

        let transfer_args = Vec::from_array(
            &env,
            [
                env.current_contract_address().into_val(&env),
                session.user.clone().into_val(&env),
                mined_amount.into_val(&env),
            ],
        );
        env.invoke_contract::<()>(
            &akofa_token,
            &Symbol::new(&env, "transfer"),
            transfer_args,
        );

        MiningPayout {
            user: session.user.clone(),
            session_id,
            amount: mined_amount,
            payout_time: current_time,
        }
        .publish(&env);

        MiningEnded {
            user: session.user,
            session_id,
            total_mined: mined_amount,
        }
        .publish(&env);

        Ok(())
    }

    /// Get mining session details
    pub fn get_session(env: Env, session_id: u64) -> Option<MiningSession> {
        env.storage().persistent().get(&session_id)
    }

    /// Get active session for a user
    pub fn get_active_session(env: Env, user: Address) -> Option<u64> {
        let session_key = (user, Symbol::new(&env, "active_session"));
        env.storage().persistent().get(&session_key)
    }

    /// Get current mined amount for active session (preview)
    pub fn get_current_mined(env: Env, user: Address) -> Result<i128, MiningError> {
        let session_id = Self::get_active_session(env.clone(), user.clone())
            .ok_or(MiningError::SessionNotFound)?;

        let session: MiningSession = env
            .storage()
            .persistent()
            .get(&session_id)
            .ok_or(MiningError::SessionNotFound)?;

        if !session.is_active {
            return Err(MiningError::SessionNotActive);
        }

        let current_time = env.ledger().timestamp();
        let elapsed_seconds = current_time.saturating_sub(session.start_time);
        let elapsed_hours = elapsed_seconds / 3600;
        let mined_amount = (elapsed_hours as i128) * 25000000; // 0.25 AKOFA per hour

        Ok(mined_amount)
    }

    /// Check if session has expired and can be paid out
    pub fn is_session_expired(env: Env, session_id: u64) -> Result<bool, MiningError> {
        let session: MiningSession = env
            .storage()
            .persistent()
            .get(&session_id)
            .ok_or(MiningError::SessionNotFound)?;

        let current_time = env.ledger().timestamp();
        Ok(current_time >= session.end_time && session.is_active)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use soroban_sdk::testutils::{Address as _, Ledger};

    #[test]
    fn test_start_mining() {
        let env = Env::default();
        let contract_id = env.register_contract(None, MiningContract);
        let client = MiningContractClient::new(&env, &contract_id);

        let akofa_token = Address::generate(&env);
        client.initialize(&akofa_token);

        let user = Address::generate(&env);
        let session_id = client.start_mining(&user);

        let session = client.get_session(&session_id);
        assert!(session.is_some());
        assert_eq!(session.as_ref().unwrap().user, user);
    }

    #[test]
    fn test_process_payout() {
        let env = Env::default();
        let contract_id = env.register_contract(None, MiningContract);
        let client = MiningContractClient::new(&env, &contract_id);

        // Use a simple address for testing - in real scenario this would be the AKOFA token
        let akofa_token = Address::generate(&env);
        client.initialize(&akofa_token);

        let user = Address::generate(&env);
        let session_id = client.start_mining(&user);

        // Simulate time passing (24 hours)
        env.ledger().set_timestamp(env.ledger().timestamp() + 24 * 60 * 60);

        // Note: In a real test, we'd need to mock the token contract or fund the contract
        // For now, we'll just test that the session logic works
        let session = client.get_session(&session_id).unwrap();
        assert!(session.is_active);

        // Check if session is expired
        let is_expired = client.is_session_expired(&session_id);
        assert!(is_expired);
    }
}