/**
 * Per-User Rate Limiter
 * Limits gasless transactions per Firebase user (not per IP)
 * Prevents individual users from abusing the gasless service
 */

// In-memory store for user transaction counts
// For production, use Redis or a database
const userTransactionStore = new Map();

// Configuration
const RATE_LIMIT_CONFIG = {
  // Time window in milliseconds (24 hours)
  WINDOW_MS: 24 * 60 * 60 * 1000,
  
  // Max transactions per user per window
  MAX_TRANSACTIONS_PER_DAY: 10,
  
  // Warning threshold (when to start warning user)
  WARNING_THRESHOLD: 8,
  
  // Cleanup interval (clean old entries every hour)
  CLEANUP_INTERVAL_MS: 60 * 60 * 1000,
};

// Structure: Map<userId, { count: number, windowStart: timestamp, transactions: [] }>

/**
 * Check if user has exceeded rate limit
 */
function checkRateLimit(userId) {
  const now = Date.now();
  const userData = userTransactionStore.get(userId);
  
  // If no data, user is within limits
  if (!userData) {
    return {
      allowed: true,
      remaining: RATE_LIMIT_CONFIG.MAX_TRANSACTIONS_PER_DAY,
      resetAt: new Date(now + RATE_LIMIT_CONFIG.WINDOW_MS),
    };
  }
  
  // Check if window has expired
  const windowExpired = (now - userData.windowStart) > RATE_LIMIT_CONFIG.WINDOW_MS;
  
  if (windowExpired) {
    // Reset the window
    userTransactionStore.delete(userId);
    return {
      allowed: true,
      remaining: RATE_LIMIT_CONFIG.MAX_TRANSACTIONS_PER_DAY,
      resetAt: new Date(now + RATE_LIMIT_CONFIG.WINDOW_MS),
    };
  }
  
  // Check if user has exceeded limit
  const remaining = RATE_LIMIT_CONFIG.MAX_TRANSACTIONS_PER_DAY - userData.count;
  const allowed = remaining > 0;
  
  return {
    allowed,
    remaining: Math.max(0, remaining),
    resetAt: new Date(userData.windowStart + RATE_LIMIT_CONFIG.WINDOW_MS),
    nearLimit: remaining <= (RATE_LIMIT_CONFIG.MAX_TRANSACTIONS_PER_DAY - RATE_LIMIT_CONFIG.WARNING_THRESHOLD),
  };
}

/**
 * Record a transaction for a user
 */
function recordTransaction(userId, transactionDetails = {}) {
  const now = Date.now();
  const userData = userTransactionStore.get(userId);
  
  if (!userData) {
    // First transaction for this user in current window
    userTransactionStore.set(userId, {
      count: 1,
      windowStart: now,
      transactions: [{
        timestamp: now,
        ...transactionDetails,
      }],
    });
  } else {
    // Increment count and add transaction
    userData.count++;
    userData.transactions.push({
      timestamp: now,
      ...transactionDetails,
    });
  }
}

/**
 * Get user's transaction history
 */
function getUserHistory(userId) {
  const userData = userTransactionStore.get(userId);
  if (!userData) {
    return {
      count: 0,
      transactions: [],
    };
  }
  
  return {
    count: userData.count,
    windowStart: userData.windowStart,
    transactions: userData.transactions,
  };
}

/**
 * Cleanup old entries (called periodically)
 */
function cleanup() {
  const now = Date.now();
  let cleanedCount = 0;
  
  for (const [userId, userData] of userTransactionStore.entries()) {
    const windowExpired = (now - userData.windowStart) > RATE_LIMIT_CONFIG.WINDOW_MS;
    if (windowExpired) {
      userTransactionStore.delete(userId);
      cleanedCount++;
    }
  }
  
  if (cleanedCount > 0) {
    console.log(`🧹 Cleaned up ${cleanedCount} expired rate limit entries`);
  }
}

// Start cleanup interval
setInterval(cleanup, RATE_LIMIT_CONFIG.CLEANUP_INTERVAL_MS);

/**
 * Express middleware for per-user rate limiting
 */
exports.userRateLimiter = (req, res, next) => {
  // User must be authenticated (this middleware should run after authenticateUser)
  if (!req.user || !req.user.uid) {
    return res.status(401).json({
      success: false,
      error: 'Authentication required for rate limiting',
    });
  }
  
  const userId = req.user.uid;
  const limitStatus = checkRateLimit(userId);
  
  // Add rate limit info to request for use in controllers
  req.rateLimit = limitStatus;
  
  if (!limitStatus.allowed) {
    console.log(`⛔ User ${userId} exceeded rate limit`);
    
    return res.status(429).json({
      success: false,
      error: 'Daily gasless transaction limit reached',
      rateLimit: {
        limit: RATE_LIMIT_CONFIG.MAX_TRANSACTIONS_PER_DAY,
        remaining: 0,
        resetAt: limitStatus.resetAt,
        message: `You've reached your daily limit of ${RATE_LIMIT_CONFIG.MAX_TRANSACTIONS_PER_DAY} gasless transactions. Limit resets at ${limitStatus.resetAt.toLocaleString()}.`,
      },
    });
  }
  
  // Warn user if approaching limit
  if (limitStatus.nearLimit) {
    console.log(`⚠️  User ${userId} is near rate limit: ${limitStatus.remaining} remaining`);
  }
  
  next();
};

/**
 * Export functions for use in controllers
 */
exports.recordTransaction = recordTransaction;
exports.getUserHistory = getUserHistory;
exports.checkRateLimit = checkRateLimit;
exports.RATE_LIMIT_CONFIG = RATE_LIMIT_CONFIG;

// Export stats for monitoring
exports.getStats = () => {
  return {
    totalUsers: userTransactionStore.size,
    config: RATE_LIMIT_CONFIG,
  };
};

