/**
 * Wallet Monitor Service
 * Monitors backend wallet balance and prevents transactions when balance is too low
 * Sends alerts when wallet needs refilling
 */

const { ethers } = require('ethers');

// Configuration
const MONITOR_CONFIG = {
  // Minimum MATIC balance required to allow transactions (in MATIC)
  // TESTNET ONLY: Lowered for testing (production should be 5+)
  MIN_BALANCE_MATIC: 0.05,
  
  // Warning threshold - when to start warning (in MATIC)
  WARNING_THRESHOLD_MATIC: 0.2,
  
  // Critical threshold - when to alert urgently (in MATIC)
  CRITICAL_THRESHOLD_MATIC: 0.02,
  
  // How often to check balance (5 minutes)
  CHECK_INTERVAL_MS: 5 * 60 * 1000,
  
  // Estimated gas cost per transaction (in MATIC)
  ESTIMATED_GAS_PER_TX: 0.01,
};

// Global state
let lastBalance = null;
let lastCheckTime = null;
let alertsSent = {
  critical: false,
  warning: false,
  low: false,
};

/**
 * Get provider and wallet
 */
function getWallet() {
  if (!process.env.RPC_URL) {
    throw new Error('RPC_URL not configured');
  }
  
  if (!process.env.SERVER_PRIVATE_KEY) {
    throw new Error('SERVER_PRIVATE_KEY not configured');
  }
  
  const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
  const wallet = new ethers.Wallet(process.env.SERVER_PRIVATE_KEY, provider);
  
  return { provider, wallet };
}

/**
 * Check backend wallet balance
 */
async function checkBalance() {
  try {
    const { wallet } = getWallet();
    const balance = await wallet.provider.getBalance(wallet.address);
    const balanceInMatic = parseFloat(ethers.formatEther(balance));
    
    lastBalance = balanceInMatic;
    lastCheckTime = new Date();
    
    // Determine status
    let status = 'healthy';
    if (balanceInMatic < MONITOR_CONFIG.CRITICAL_THRESHOLD_MATIC) {
      status = 'critical';
    } else if (balanceInMatic < MONITOR_CONFIG.MIN_BALANCE_MATIC) {
      status = 'low';
    } else if (balanceInMatic < MONITOR_CONFIG.WARNING_THRESHOLD_MATIC) {
      status = 'warning';
    }
    
    // Send alerts based on status
    sendAlerts(status, balanceInMatic, wallet.address);
    
    return {
      success: true,
      balance: balanceInMatic,
      balanceWei: balance.toString(),
      address: wallet.address,
      status,
      canProcessTransactions: balanceInMatic >= MONITOR_CONFIG.MIN_BALANCE_MATIC,
      estimatedTransactionsRemaining: Math.floor(balanceInMatic / MONITOR_CONFIG.ESTIMATED_GAS_PER_TX),
      thresholds: {
        minimum: MONITOR_CONFIG.MIN_BALANCE_MATIC,
        warning: MONITOR_CONFIG.WARNING_THRESHOLD_MATIC,
        critical: MONITOR_CONFIG.CRITICAL_THRESHOLD_MATIC,
      },
    };
  } catch (error) {
    console.error('❌ Error checking wallet balance:', error.message);
    return {
      success: false,
      error: error.message,
    };
  }
}

/**
 * Send alerts based on wallet status
 */
function sendAlerts(status, balance, address) {
  const shortAddress = `${address.substring(0, 6)}...${address.substring(address.length - 4)}`;
  
  if (status === 'critical' && !alertsSent.critical) {
    console.error('');
    console.error('🚨🚨🚨 CRITICAL ALERT 🚨🚨🚨');
    console.error(`Backend wallet balance is CRITICALLY LOW: ${balance.toFixed(4)} MATIC`);
    console.error(`Address: ${address}`);
    console.error(`Minimum required: ${MONITOR_CONFIG.MIN_BALANCE_MATIC} MATIC`);
    console.error('⚠️  GASLESS TRANSACTIONS WILL BE BLOCKED SOON!');
    console.error('🔧 ACTION REQUIRED: Refill wallet immediately!');
    console.error('');
    alertsSent.critical = true;
    alertsSent.warning = false;
    alertsSent.low = false;
  } else if (status === 'low' && !alertsSent.low) {
    console.warn('');
    console.warn('⚠️  LOW BALANCE ALERT ⚠️');
    console.warn(`Backend wallet balance is low: ${balance.toFixed(4)} MATIC`);
    console.warn(`Address: ${shortAddress}`);
    console.warn(`Minimum required: ${MONITOR_CONFIG.MIN_BALANCE_MATIC} MATIC`);
    console.warn('🚫 Gasless transactions are now BLOCKED');
    console.warn('🔧 Please refill the wallet to resume gasless service');
    console.warn('');
    alertsSent.low = true;
    alertsSent.warning = false;
  } else if (status === 'warning' && !alertsSent.warning) {
    console.warn('');
    console.warn('⚠️  Wallet balance below warning threshold: ${balance.toFixed(4)} MATIC');
    console.warn(`Address: ${shortAddress}`);
    console.warn(`Warning threshold: ${MONITOR_CONFIG.WARNING_THRESHOLD_MATIC} MATIC`);
    console.warn('ℹ️  Consider refilling soon to avoid service interruption');
    console.warn('');
    alertsSent.warning = true;
  } else if (status === 'healthy') {
    // Reset alerts when balance is healthy
    if (alertsSent.critical || alertsSent.low || alertsSent.warning) {
      console.log('');
      console.log('✅ Wallet balance restored to healthy levels');
      console.log(`Current balance: ${balance.toFixed(4)} MATIC`);
      console.log('');
    }
    alertsSent.critical = false;
    alertsSent.warning = false;
    alertsSent.low = false;
  }
}

/**
 * Check if wallet has enough balance for a transaction
 */
async function canProcessTransaction(estimatedGasCost = MONITOR_CONFIG.ESTIMATED_GAS_PER_TX) {
  const balanceInfo = await checkBalance();
  
  if (!balanceInfo.success) {
    return {
      allowed: false,
      reason: 'Unable to check wallet balance',
      error: balanceInfo.error,
    };
  }
  
  if (balanceInfo.balance < MONITOR_CONFIG.MIN_BALANCE_MATIC) {
    return {
      allowed: false,
      reason: 'Backend wallet balance too low',
      currentBalance: balanceInfo.balance,
      minimumRequired: MONITOR_CONFIG.MIN_BALANCE_MATIC,
      message: 'Gasless service temporarily unavailable. Please try again later or use a regular transaction.',
    };
  }
  
  if (balanceInfo.balance < estimatedGasCost) {
    return {
      allowed: false,
      reason: 'Insufficient balance for this transaction',
      currentBalance: balanceInfo.balance,
      estimatedCost: estimatedGasCost,
    };
  }
  
  return {
    allowed: true,
    currentBalance: balanceInfo.balance,
    estimatedTransactionsRemaining: balanceInfo.estimatedTransactionsRemaining,
  };
}

/**
 * Get wallet status for monitoring dashboard
 */
async function getWalletStatus() {
  const balanceInfo = await checkBalance();
  
  return {
    ...balanceInfo,
    lastChecked: lastCheckTime,
    monitoring: {
      checkInterval: MONITOR_CONFIG.CHECK_INTERVAL_MS / 1000 + ' seconds',
      autoCheckEnabled: true,
    },
  };
}

/**
 * Start periodic balance monitoring
 */
function startMonitoring() {
  console.log('🔍 Starting wallet balance monitoring...');
  console.log(`   Check interval: ${MONITOR_CONFIG.CHECK_INTERVAL_MS / 1000} seconds`);
  console.log(`   Min balance: ${MONITOR_CONFIG.MIN_BALANCE_MATIC} MATIC`);
  
  // Check immediately on start
  checkBalance().then(result => {
    if (result.success) {
      const shortAddr = `${result.address.substring(0, 6)}...${result.address.substring(result.address.length - 4)}`;
      console.log(`💰 Backend Wallet: ${shortAddr}`);
      console.log(`   Balance: ${result.balance.toFixed(4)} MATIC`);
      console.log(`   Status: ${result.status.toUpperCase()}`);
      console.log(`   Est. transactions remaining: ~${result.estimatedTransactionsRemaining}`);
    }
  });
  
  // Then check periodically
  setInterval(() => {
    checkBalance();
  }, MONITOR_CONFIG.CHECK_INTERVAL_MS);
}

module.exports = {
  checkBalance,
  canProcessTransaction,
  getWalletStatus,
  startMonitoring,
  MONITOR_CONFIG,
};

