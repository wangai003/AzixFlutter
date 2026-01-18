/**
 * Wallet-Based Authentication Middleware
 * Authenticates users based on their wallet address
 * Optionally verifies signature to prove wallet ownership
 */

const { ethers } = require('ethers');

/**
 * Middleware to authenticate user via wallet address
 * 
 * Expected request body:
 * {
 *   "userAddress": "0x...",  // Required: The wallet address
 *   "signature": "0x...",     // Optional: Signature to prove ownership
 *   "message": "..."          // Optional: Message that was signed
 * }
 */
exports.authenticateWallet = async (req, res, next) => {
  try {
    // Get wallet address from request body
    const { userAddress, signature, message } = req.body;
    
    if (!userAddress) {
      return res.status(401).json({
        success: false,
        error: 'Wallet address required',
        hint: 'Include "userAddress" in request body'
      });
    }
    
    // Validate wallet address format
    if (!ethers.isAddress(userAddress)) {
      return res.status(401).json({
        success: false,
        error: 'Invalid wallet address format'
      });
    }
    
    // Normalize address (checksum format)
    const normalizedAddress = ethers.getAddress(userAddress);
    
    // If signature is provided, verify it (optional but recommended)
    if (signature && message) {
      try {
        const recoveredAddress = ethers.verifyMessage(message, signature);
        
        if (recoveredAddress.toLowerCase() !== normalizedAddress.toLowerCase()) {
          return res.status(401).json({
            success: false,
            error: 'Signature verification failed',
            reason: 'Signature does not match wallet address'
          });
        }
        
        console.log(`✅ Signature verified for wallet: ${normalizedAddress.substring(0, 10)}...`);
      } catch (error) {
        return res.status(401).json({
          success: false,
          error: 'Invalid signature',
          reason: error.message
        });
      }
    } else {
      // No signature verification - just validate address format
      console.log(`⚠️  No signature verification for wallet: ${normalizedAddress.substring(0, 10)}...`);
    }
    
    // Attach wallet info to request for use in controllers
    req.wallet = {
      address: normalizedAddress,
      verified: !!(signature && message),
    };
    
    // Also set req.user for backward compatibility with rate limiter
    req.user = {
      uid: normalizedAddress, // Use wallet address as unique identifier
      wallet: normalizedAddress,
      verified: !!(signature && message),
    };
    
    next();
  } catch (error) {
    console.error('❌ Wallet authentication error:', error.message);
    
    return res.status(401).json({
      success: false,
      error: 'Wallet authentication failed',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

/**
 * Optional: Require signature verification
 * Use this after authenticateWallet if you want to enforce signature verification
 */
exports.requireSignature = (req, res, next) => {
  if (!req.wallet || !req.wallet.verified) {
    return res.status(401).json({
      success: false,
      error: 'Signature verification required',
      hint: 'Include "signature" and "message" in request body'
    });
  }
  next();
};

/**
 * Development mode: Allow requests without authentication
 * Useful for testing
 */
exports.optionalAuth = (req, res, next) => {
  if (process.env.NODE_ENV === 'development') {
    // Try to authenticate, but don't fail if it doesn't work
    exports.authenticateWallet(req, res, (err) => {
      if (err) {
        // If authentication fails in dev mode, create a dummy wallet
        req.wallet = { address: req.body.userAddress || '0x0000000000000000000000000000000000000000', verified: false };
        req.user = { uid: req.wallet.address, wallet: req.wallet.address, verified: false };
      }
      next();
    });
  } else {
    // In production, authentication is required
    exports.authenticateWallet(req, res, next);
  }
};

/**
 * Generate a message for the user to sign
 * This should be called by a separate endpoint to get the message
 */
exports.generateSignMessage = (walletAddress) => {
  const timestamp = Date.now();
  const nonce = Math.random().toString(36).substring(7);
  
  return {
    message: `AzixFlutter Gasless Transaction Authentication\n\nWallet: ${walletAddress}\nTimestamp: ${timestamp}\nNonce: ${nonce}`,
    timestamp,
    nonce,
  };
};

/**
 * Endpoint to get sign message (optional - for frontend to call)
 */
exports.getSignMessage = (req, res) => {
  const { walletAddress } = req.query;
  
  if (!walletAddress || !ethers.isAddress(walletAddress)) {
    return res.status(400).json({
      success: false,
      error: 'Valid wallet address required'
    });
  }
  
  const messageData = exports.generateSignMessage(walletAddress);
  
  res.json({
    success: true,
    message: messageData.message,
    instructions: 'Sign this message with your wallet to prove ownership'
  });
};

