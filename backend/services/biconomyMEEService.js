/**
 * Biconomy MEE Sponsorship Service
 * Implements gas sponsorship using Biconomy MEE as per official documentation
 * https://docs.biconomy.io/new/getting-started/sponsor-gas-for-users
 */

const { createMeeClient, toMultichainNexusAccount, getMEEVersion } = require('@biconomy/abstractjs');
const { privateKeyToAccount } = require('viem/accounts');
const { polygonAmoy } = require('viem/chains');
const { http, parseUnits, encodeFunctionData, createPublicClient } = require('viem');

// ERC-20 ABI
const ERC20_ABI = [
  {
    inputs: [{ name: 'to', type: 'address' }, { name: 'amount', type: 'uint256' }],
    name: 'transfer',
    outputs: [{ name: '', type: 'bool' }],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [{ name: 'owner', type: 'address' }],
    name: 'balanceOf',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'decimals',
    outputs: [{ name: '', type: 'uint8' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'symbol',
    outputs: [{ name: '', type: 'string' }],
    stateMutability: 'view',
    type: 'function',
  },
];

class BiconomyMEEService {
  constructor() {
    this.chainId = parseInt(process.env.CHAIN_ID || '80002'); // Polygon Amoy
    this.rpcUrl = process.env.RPC_URL || 'https://rpc-amoy.polygon.technology/';
    this.apiKey = process.env.BICONOMY_API_KEY;
    
    if (!this.apiKey) {
      console.warn('⚠️  BICONOMY_API_KEY not set - sponsorship may not work');
    }
    
    // Create viem public client for reading blockchain data
    this.publicClient = createPublicClient({
      chain: polygonAmoy,
      transport: http(this.rpcUrl),
    });
    
    // Backend account that will be used for the smart account orchestrator
    this.backendAccount = privateKeyToAccount(process.env.SERVER_PRIVATE_KEY);
    
    // Initialize MEE client (will be created on first use)
    this.meeClient = null;
    
    console.log('🚀 Biconomy MEE Sponsorship Service initialized');
    console.log(`   Chain: Polygon Amoy (${this.chainId})`);
    console.log(`   API Key: ${this.apiKey ? this.apiKey.substring(0, 15) + '...' : 'NOT SET'}`);
    console.log(`   Backend Account: ${this.backendAccount.address.substring(0, 10)}...`);
  }

  /**
   * Initialize MEE Client with Biconomy-hosted sponsorship
   * This creates a client that can sponsor gas for users
   */
  async getMeeClient() {
    if (this.meeClient) {
      return this.meeClient;
    }

    try {
      console.log('🔧 [MEE] Creating MEE client with sponsorship...');
      
      // Create multichain Nexus account (smart account orchestrator)
      // Let the SDK auto-detect the MEE version for the chain
      const mcNexus = await toMultichainNexusAccount({
        signer: this.backendAccount,
        chainConfigurations: [{
          chain: polygonAmoy,
          transport: http(this.rpcUrl),
          // version will be auto-detected if not specified
        }],
      });

      console.log(`✅ [MEE] Multichain Nexus Account: ${mcNexus.address}`);

      // Create MEE client with API key for Biconomy-hosted sponsorship
      this.meeClient = await createMeeClient({
        account: mcNexus,
        apiKey: this.apiKey, // Required for hosted sponsorship
      });

      console.log('✅ [MEE] MEE Client created successfully');
      
      return this.meeClient;
    } catch (error) {
      console.error('❌ [MEE] Failed to create MEE client:', error);
      throw new Error(`Failed to initialize MEE client: ${error.message}`);
    }
  }

  /**
   * Send ERC-20 tokens with SPONSORED gas
   * User pays $0 - gas is sponsored by Biconomy using the apiKey
   * 
   * This implements the "Sponsor Gas for Users" pattern from Biconomy docs
   */
  async sendTokensSponsored({
    tokenAddress,
    toAddress,
    amount,
    decimals,
  }) {
    try {
      console.log('💫 [MEE SPONSORSHIP] Starting sponsored transaction...');
      console.log(`   Token: ${tokenAddress}`);
      console.log(`   To: ${toAddress}`);
      console.log(`   Amount: ${amount}`);

      // Get MEE client
      const meeClient = await this.getMeeClient();

      // Get token info
      const symbol = await this.publicClient.readContract({
        address: tokenAddress,
        abi: ERC20_ABI,
        functionName: 'symbol',
      });

      console.log(`   Token Symbol: ${symbol}`);

      // Parse amount
      const decimalsNum = typeof decimals === 'bigint' ? Number(decimals) : decimals;
      const amountWei = parseUnits(amount.toString(), decimalsNum);

      // Encode the transfer function call
      const transferData = encodeFunctionData({
        abi: ERC20_ABI,
        functionName: 'transfer',
        args: [toAddress, amountWei],
      });

      // Create instruction for the transfer
      const instruction = {
        chainId: this.chainId,
        calls: [{
          to: tokenAddress,
          data: transferData,
          value: 0n,
        }],
      };

      console.log('📦 [MEE SPONSORSHIP] Instruction created');

      // Get quote with SPONSORSHIP enabled
      // This is the key: sponsorship: true tells Biconomy to sponsor the gas
      console.log('🔍 [MEE SPONSORSHIP] Getting sponsored quote...');
      
      const quote = await meeClient.getQuote({
        sponsorship: true, // ⭐ KEY: Enable gas sponsorship
        instructions: [instruction],
      });

      console.log('✅ [MEE SPONSORSHIP] Quote received (gas will be sponsored)');
      console.log(`   User pays: $0.00`);
      console.log(`   Gas sponsored by: Biconomy (via apiKey)`);

      // Execute the sponsored transaction
      console.log('📤 [MEE SPONSORSHIP] Executing sponsored transaction...');
      
      const txHash = await meeClient.executeQuote({
        quote,
      });

      console.log(`✅ [MEE SPONSORSHIP] Transaction successful!`);
      console.log(`   TX Hash: ${txHash}`);
      console.log(`   User paid: $0.00 (100% sponsored)`);

      return {
        success: true,
        txHash,
        sponsored: true,
        userPaidMatic: '0',
        userPaidToken: '0',
        userPaidUSD: '0.00',
        gasPaymentMethod: 'Biconomy-hosted sponsorship',
        message: 'Transaction gas fully sponsored by Biconomy - User paid $0.00',
        token: symbol,
      };
    } catch (error) {
      console.error('❌ [MEE SPONSORSHIP] Error:', error);
      
      // Handle common errors
      if (error.message?.includes('insufficient')) {
        return {
          success: false,
          error: 'Insufficient token balance in smart account',
          details: 'The backend smart account needs to hold the tokens to distribute',
        };
      }
      
      if (error.message?.includes('apiKey') || error.message?.includes('unauthorized')) {
        return {
          success: false,
          error: 'Biconomy API key invalid or not configured',
          details: 'Please set BICONOMY_API_KEY in .env file',
        };
      }

      return {
        success: false,
        error: error.message,
        details: process.env.NODE_ENV === 'development' ? error.stack : undefined,
      };
    }
  }

  /**
   * Estimate gas cost (will show as sponsored)
   */
  async estimateGasCost({
    tokenAddress,
    toAddress,
    amount,
    decimals,
  }) {
    try {
      const decimalsNum = typeof decimals === 'bigint' ? Number(decimals) : decimals;
      const amountWei = parseUnits(amount.toString(), decimalsNum);

      const transferData = encodeFunctionData({
        abi: ERC20_ABI,
        functionName: 'transfer',
        args: [toAddress, amountWei],
      });

      const instruction = {
        chainId: this.chainId,
        calls: [{ to: tokenAddress, data: transferData, value: 0n }],
      };

      const meeClient = await this.getMeeClient();
      
      const quote = await meeClient.getQuote({
        sponsorship: true, // Get sponsored quote
        instructions: [instruction],
      });

      const symbol = await this.publicClient.readContract({
        address: tokenAddress,
        abi: ERC20_ABI,
        functionName: 'symbol',
      });

      return {
        success: true,
        userPaysMatic: '0',
        userPaysToken: '0',
        userPaysUSD: '0.00',
        sponsored: true,
        token: symbol,
        note: 'Gas fully sponsored by Biconomy - User pays $0.00',
      };
    } catch (error) {
      console.error('Error estimating gas:', error);
      return {
        success: false,
        error: error.message,
      };
    }
  }

  /**
   * Get the smart account address
   */
  async getSmartAccountAddress() {
    try {
      const meeClient = await this.getMeeClient();
      return {
        success: true,
        address: meeClient.account.address,
      };
    } catch (error) {
      return {
        success: false,
        error: error.message,
      };
    }
  }

  /**
   * Health check
   */
  async healthCheck() {
    try {
      await this.getMeeClient();
      return {
        success: true,
        message: 'MEE client initialized successfully',
        sponsorshipAvailable: !!this.apiKey,
      };
    } catch (error) {
      return {
        success: false,
        error: error.message,
      };
    }
  }
}

// Singleton instance
let meeService = null;

function getMEEService() {
  if (!meeService) {
    meeService = new BiconomyMEEService();
  }
  return meeService;
}

module.exports = {
  getMEEService,
  BiconomyMEEService,
};
