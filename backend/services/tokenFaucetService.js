/**
 * Token Faucet Service
 * Simple gasless token distribution - backend sends tokens on behalf of users
 * Users pay $0, backend pays gas fees
 */

const { ethers } = require('ethers');

// ERC-20 ABI (minimal)
const ERC20_ABI = [
  'function transfer(address to, uint256 amount) returns (bool)',
  'function balanceOf(address owner) view returns (uint256)',
  'function decimals() view returns (uint8)',
  'function symbol() view returns (string)',
  'function name() view returns (string)',
];

class TokenFaucetService {
  constructor() {
    this.provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
    this.wallet = new ethers.Wallet(process.env.SERVER_PRIVATE_KEY, this.provider);
    
    console.log('🚰 Token Faucet Service initialized');
    console.log(`   Backend wallet: ${this.wallet.address.substring(0, 10)}...`);
  }

  /**
   * Check if backend has enough tokens
   */
  async checkTokenBalance(tokenAddress, requiredAmount, decimals) {
    try {
      const tokenContract = new ethers.Contract(tokenAddress, ERC20_ABI, this.provider);
      const balance = await tokenContract.balanceOf(this.wallet.address);
      const symbol = await tokenContract.symbol();
      
      const requiredAmountBN = ethers.parseUnits(requiredAmount.toString(), decimals);
      const hasEnough = balance >= requiredAmountBN;
      
      const balanceFormatted = ethers.formatUnits(balance, decimals);
      
      console.log(`💰 Backend ${symbol} balance: ${balanceFormatted}`);
      console.log(`   Required: ${requiredAmount}`);
      console.log(`   Sufficient: ${hasEnough ? '✅' : '❌'}`);
      
      return {
        hasEnough,
        balance: balanceFormatted,
        required: requiredAmount,
        symbol,
      };
    } catch (error) {
      console.error('❌ Error checking token balance:', error.message);
      throw error;
    }
  }

  /**
   * Send tokens gaslessly - backend pays gas, user pays $0
   */
  async sendTokens({
    tokenAddress,
    toAddress,
    amount,
    decimals,
    requestedBy, // User who requested the transfer
  }) {
    try {
      console.log('🚰 [FAUCET] Sending tokens...');
      console.log(`   Token: ${tokenAddress}`);
      console.log(`   To: ${toAddress}`);
      console.log(`   Amount: ${amount}`);
      console.log(`   Requested by: ${requestedBy.substring(0, 10)}...`);

      // Get token contract
      const tokenContract = new ethers.Contract(tokenAddress, ERC20_ABI, this.wallet);
      const symbol = await tokenContract.symbol();
      const name = await tokenContract.name();

      // Check backend has enough tokens
      const balanceCheck = await this.checkTokenBalance(tokenAddress, amount, decimals);
      
      if (!balanceCheck.hasEnough) {
        throw new Error(`Backend wallet has insufficient ${symbol}. Available: ${balanceCheck.balance}, Required: ${amount}`);
      }

      // Convert amount to token units
      const amountBN = ethers.parseUnits(amount.toString(), decimals);

      console.log('📤 Sending transaction from backend wallet...');
      
      // Send tokens from backend wallet to recipient
      const tx = await tokenContract.transfer(toAddress, amountBN);
      
      console.log(`⏳ Transaction submitted: ${tx.hash}`);
      console.log('   Waiting for confirmation...');

      // Wait for confirmation
      const receipt = await tx.wait();

      if (receipt.status === 1) {
        console.log(`✅ [FAUCET] Transaction successful!`);
        console.log(`   TX Hash: ${receipt.hash}`);
        console.log(`   Block: ${receipt.blockNumber}`);
        console.log(`   Gas Used: ${receipt.gasUsed.toString()}`);
        console.log(`   💰 User paid: $0.00 (Backend paid gas)`);

        // Calculate gas cost
        const gasPrice = receipt.gasPrice || tx.gasPrice;
        const gasCost = receipt.gasUsed * gasPrice;
        const gasCostMatic = ethers.formatEther(gasCost);

        return {
          success: true,
          txHash: receipt.hash,
          blockNumber: receipt.blockNumber,
          gasUsed: receipt.gasUsed.toString(),
          gasCostMatic: gasCostMatic,
          from: this.wallet.address,
          to: toAddress,
          token: {
            address: tokenAddress,
            symbol: symbol,
            name: name,
          },
          amount: amount,
          isGasless: true,
          userPaid: '0.00',
          requestedBy: requestedBy,
        };
      } else {
        throw new Error('Transaction failed');
      }
    } catch (error) {
      console.error('❌ [FAUCET] Error:', error.message);
      throw error;
    }
  }

  /**
   * Get token info
   */
  async getTokenInfo(tokenAddress) {
    try {
      const tokenContract = new ethers.Contract(tokenAddress, ERC20_ABI, this.provider);
      
      const [symbol, name, decimals, backendBalance] = await Promise.all([
        tokenContract.symbol(),
        tokenContract.name(),
        tokenContract.decimals(),
        tokenContract.balanceOf(this.wallet.address),
      ]);

      return {
        address: tokenAddress,
        symbol,
        name,
        decimals: Number(decimals),
        backendBalance: ethers.formatUnits(backendBalance, decimals),
      };
    } catch (error) {
      console.error('❌ Error getting token info:', error.message);
      throw error;
    }
  }

  /**
   * Check if backend can distribute tokens
   */
  async canDistribute(tokenAddress, amount, decimals) {
    try {
      const check = await this.checkTokenBalance(tokenAddress, amount, decimals);
      return {
        canDistribute: check.hasEnough,
        backendBalance: check.balance,
        required: amount,
        reason: check.hasEnough ? 'Backend has sufficient tokens' : 'Backend has insufficient tokens',
      };
    } catch (error) {
      return {
        canDistribute: false,
        reason: error.message,
      };
    }
  }
}

// Singleton instance
let faucetService = null;

function getFaucetService() {
  if (!faucetService) {
    faucetService = new TokenFaucetService();
  }
  return faucetService;
}

module.exports = {
  getFaucetService,
  TokenFaucetService,
};

