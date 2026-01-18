const { ethers } = require('ethers');
const walletMonitor = require('../services/walletMonitor');
const { recordTransaction } = require('../middleware/userRateLimiter');

// ERC-20 ABI (minimal - just what we need)
const ERC20_ABI = [
  'function transfer(address to, uint256 amount) returns (bool)',
  'function balanceOf(address owner) view returns (uint256)',
  'function decimals() view returns (uint8)',
  'function symbol() view returns (string)',
];

/**
 * Relay a pre-signed transaction
 * User signs transaction with their wallet (their tokens)
 * Backend broadcasts it and pays the gas fee
 * 
 * Sustainable approach: Backend only needs MATIC, not every token type
 */
exports.sendToken = async (req, res) => {
  try {
    const { 
      signedTransaction,
      userAddress,
    } = req.body;

    console.log('🚀 [GASLESS RELAY] Relaying user-signed transaction...');
    console.log(`👤 User Wallet: ${userAddress}`);
    console.log(`🔐 Wallet Auth: ${req.wallet?.address.substring(0, 10)}...${req.wallet?.address.substring(38)}`);
    console.log(`✍️  Signature Verified: ${req.wallet?.verified ? '✅' : '⚠️  No'}`);
    console.log(`💫 Mode: Backend Relay (user tokens, backend pays gas)`);

    // Validate inputs
    if (!signedTransaction) {
      return res.status(400).json({
        success: false,
        error: 'Missing signed transaction'
      });
    }

    if (!ethers.isAddress(userAddress)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid user address'
      });
    }

    // Check backend wallet has enough MATIC for gas
    const walletStatus = await walletMonitor.canProcessTransaction();
    if (!walletStatus.allowed) {
      console.error('❌ Backend wallet insufficient MATIC:', walletStatus.reason);
      return res.status(503).json({
        success: false,
        error: 'Gasless service temporarily unavailable',
        reason: walletStatus.message || walletStatus.reason,
      });
    }

    console.log(`💰 Backend wallet: ${walletStatus.currentBalance.toFixed(4)} MATIC`);

    // Setup provider
    const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
    
    // Parse the signed transaction to verify it
    const parsedTx = ethers.Transaction.from(signedTransaction);
    
    // Verify the transaction is from the claimed user
    const recoveredAddress = parsedTx.from;
    if (recoveredAddress?.toLowerCase() !== userAddress.toLowerCase()) {
      console.error('❌ Transaction signer does not match user address');
      return res.status(400).json({
        success: false,
        error: 'Transaction signature invalid',
        details: `Expected ${userAddress}, got ${recoveredAddress}`,
      });
    }

    console.log('✅ Transaction signature verified');
    console.log(`📤 Broadcasting transaction to network...`);
    
    // Broadcast the signed transaction
    const txResponse = await provider.broadcastTransaction(signedTransaction);
    console.log(`📋 Transaction broadcast: ${txResponse.hash}`);
    console.log('⏳ Waiting for confirmation...');
    
    // Wait for confirmation
    const receipt = await txResponse.wait();
    console.log('✅ Transaction confirmed!');
    console.log(`⛽ Gas used: ${receipt.gasUsed.toString()}`);
    console.log(`💰 User paid: $0.00 (gas sponsored by backend)`);
    
    const result = {
      success: true,
      txHash: receipt.hash,
      blockNumber: receipt.blockNumber,
      gasUsed: receipt.gasUsed.toString(),
      sponsored: true,
    };

    console.log(`✅ [RELAY] Gasless relay successful!`);
    console.log(`📋 TX Hash: ${result.txHash}`);
    console.log(`💰 User paid: $0.00 (100% sponsored by Biconomy)`);
    
    // Record transaction for rate limiting
    if (req.wallet?.address) {
      recordTransaction(req.wallet.address, {
        txHash: result.txHash,
        from: userAddress,
        mode: 'relay',
      });
      const shortAddr = `${req.wallet.address.substring(0, 6)}...${req.wallet.address.substring(38)}`;
      console.log(`📊 Recorded transaction for wallet: ${shortAddr}`);
    }

    // Build response
    res.json({
      success: true,
      txHash: result.txHash,
      blockNumber: result.blockNumber,
      mode: 'relay',
      transaction: {
        from: userAddress,
        isGasless: true,
        sponsored: true,
        gasPaymentMethod: 'Backend Relay',
        userPaidMatic: '0',
        userPaidUSD: '0.00',
      },
      message: 'Transaction relayed successfully! Gas paid by backend - You paid $0.00',
      gasUsed: result.gasUsed,
      rateLimit: req.rateLimit ? {
        remaining: req.rateLimit.remaining - 1,
        resetAt: req.rateLimit.resetAt,
      } : undefined,
    });

  } catch (error) {
    console.error('❌ Error in sendToken:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      details: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
  }
};

/**
 * Estimate gas for transaction (will show as sponsored)
 */
exports.estimateGas = async (req, res) => {
  try {
    const { tokenAddress, amount } = req.body;

    const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
    const tokenContract = new ethers.Contract(tokenAddress, ERC20_ABI, provider);
    const decimals = await tokenContract.decimals();
    const symbol = await tokenContract.symbol();

    // Get estimate from MEE service
    const meeService = getMEEService();
    const estimate = await meeService.estimateGasCost({
      tokenAddress,
      toAddress: '0x0000000000000000000000000000000000000000', // Dummy address for estimation
      amount,
      decimals,
    });

    res.json({
      success: true,
      estimate: {
        isGasless: true,
        userPays: '0', // TRUE gasless - user pays NOTHING!
        userPaysUSD: '0.00',
        sponsored: true,
        token: symbol,
        note: 'Gas fully sponsored by Biconomy - you pay $0.00'
      }
    });

  } catch (error) {
    console.error('❌ Error estimating gas:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
};

/**
 * Get transaction status
 */
exports.getTransactionStatus = async (req, res) => {
  try {
    const { txHash } = req.params;

    if (!txHash || !txHash.startsWith('0x')) {
      return res.status(400).json({
        success: false,
        error: 'Invalid transaction hash'
      });
    }

    const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
    
    // Get transaction receipt
    const receipt = await provider.getTransactionReceipt(txHash);

    if (!receipt) {
      return res.json({
        success: true,
        status: 'pending',
        txHash: txHash
      });
    }

    res.json({
      success: true,
      status: receipt.status === 1 ? 'confirmed' : 'failed',
      txHash: txHash,
      blockNumber: receipt.blockNumber,
      gasUsed: receipt.gasUsed.toString(),
      from: receipt.from,
      to: receipt.to,
      sponsored: true,
    });

  } catch (error) {
    console.error('❌ Error getting transaction status:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
};

/**
 * Check if user is eligible for gasless transactions
 */
exports.checkEligibility = async (req, res) => {
  try {
    const { userAddress, tokenAddress } = req.body;

    if (!ethers.isAddress(userAddress)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid user address'
      });
    }

    // Get token info
    const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
    const tokenContract = new ethers.Contract(tokenAddress, ERC20_ABI, provider);
    const symbol = await tokenContract.symbol();
    
    // Check user's rate limit status
    const userRateLimit = req.rateLimit || { remaining: 0, resetAt: null };
    const withinRateLimit = userRateLimit.remaining > 0;

    // Check if MEE service is available
    const meeService = getMEEService();
    const healthCheck = await meeService.healthCheck();

    // User is eligible if:
    // 1. MEE service is available
    // 2. User hasn't exceeded rate limit
    const eligible = healthCheck.success && withinRateLimit;

    let reason = 'User is eligible for sponsored gasless transactions';
    if (!healthCheck.success) reason = `MEE service unavailable: ${healthCheck.error}`;
    else if (!withinRateLimit) reason = 'Daily gasless transaction limit reached';

    res.json({
      success: true,
      eligible,
      reason,
      token: {
        symbol: symbol,
      },
      rateLimit: {
        remaining: userRateLimit.remaining,
        resetAt: userRateLimit.resetAt,
      },
      sponsorship: {
        available: healthCheck.success && healthCheck.sponsorshipAvailable,
        method: 'Biconomy MEE Sponsorship',
        userCost: '$0.00',
      },
      note: 'Gas fully sponsored by Biconomy - you pay $0.00',
    });

  } catch (error) {
    console.error('❌ Error checking eligibility:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
};

/**
 * Get smart account address (for reference)
 */
exports.getSmartAccountAddress = async (req, res) => {
  try {
    const meeService = getMEEService();
    const result = await meeService.getSmartAccountAddress();
    
    res.json(result);
  } catch (error) {
    console.error('❌ Error getting smart account address:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
};

/**
 * Get backend wallet status (admin/monitoring endpoint)
 */
exports.getWalletStatus = async (req, res) => {
  try {
    const status = await walletMonitor.getWalletStatus();
    
    res.json({
      success: true,
      wallet: status,
      sponsorship: {
        method: 'Biconomy MEE Sponsorship',
        note: 'Gas is sponsored by Biconomy, not paid by backend wallet',
      },
    });
  } catch (error) {
    console.error('❌ Error getting wallet status:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
};

/**
 * MEE Sponsorship health check
 */
exports.healthCheck = async (req, res) => {
  try {
    const meeService = getMEEService();
    const healthCheck = await meeService.healthCheck();
    
    res.json({
      success: healthCheck.success,
      service: 'Biconomy MEE Sponsorship',
      ...healthCheck,
    });
  } catch (error) {
    console.error('❌ Error in health check:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
};

// Remove these old Fusion-specific endpoints as they're not needed for sponsorship
exports.checkPermitSupport = async (req, res) => {
  res.status(410).json({
    success: false,
    error: 'Endpoint deprecated - Using Biconomy MEE Sponsorship instead',
    note: 'Gas is fully sponsored, no permit checks needed',
  });
};

exports.getCompanionAddress = async (req, res) => {
  res.status(410).json({
    success: false,
    error: 'Endpoint deprecated - Using Biconomy MEE Sponsorship instead',
    note: 'Sponsorship uses smart accounts, not companion accounts',
  });
};
