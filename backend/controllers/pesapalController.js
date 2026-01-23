/**
 * PesaPal Payment Controller
 * 
 * Handles HTTP endpoints for PesaPal card payments
 */

const pesapalService = require('../services/pesapalService');
const { getFaucetService } = require('../services/tokenFaucetService');

// In-memory transaction store (replace with database in production)
const pendingTransactions = new Map();

// Firebase Admin (optional but strongly recommended for payment flows)
let admin = null;
let firestore = null;

try {
  admin = require('firebase-admin');
  const fs = require('fs');
  const path = require('path');

  if (!admin.apps.length) {
    let serviceAccount = null;
    const serviceAccountPath = path.join(__dirname, '..', 'firebase-service-account.json');
    if (fs.existsSync(serviceAccountPath)) {
      try {
        const serviceAccountFile = fs.readFileSync(serviceAccountPath, 'utf8');
        serviceAccount = JSON.parse(serviceAccountFile);
        console.log('✅ [PESAPAL] Loaded Firebase service account from file');
      } catch (fileError) {
        console.warn('⚠️  [PESAPAL] Could not parse firebase-service-account.json:', fileError.message);
      }
    }

    if (!serviceAccount && process.env.FIREBASE_SERVICE_ACCOUNT) {
      try {
        serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
        console.log('✅ [PESAPAL] Loaded Firebase service account from environment variable');
      } catch (envError) {
        console.warn('⚠️  [PESAPAL] Could not parse FIREBASE_SERVICE_ACCOUNT:', envError.message);
      }
    }

    if (serviceAccount) {
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
      firestore = admin.firestore();
      console.log('✅ [PESAPAL] Firebase Admin initialized');
    } else {
      console.warn('⚠️  [PESAPAL] Firebase Admin not configured. Token crediting may be delayed.');
    }
  } else {
    firestore = admin.firestore();
  }
} catch (error) {
  console.warn('⚠️  [PESAPAL] Firebase Admin not available:', error.message);
}

const tokenContractAddresses = {
  AKOFA: '0xf1266ACCf0f757c61e4DFDD9EBBcaC05D2Ee375F',
  USDC: '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359',
  USDT: '0xc2132D05D31c914a87C6611C10748AEb04B58e8F',
};

const tokenDecimals = {
  AKOFA: 18,
  USDC: 6,
  USDT: 6,
};

async function getTransactionDoc(orderTrackingId) {
  if (!firestore) return null;
  const snapshot = await firestore
    .collection('pesapal_transactions')
    .where('orderTrackingId', '==', orderTrackingId)
    .limit(1)
    .get();
  return snapshot.empty ? null : snapshot.docs[0];
}

async function upsertTransaction(orderTrackingId, data) {
  if (!firestore) return;
  const existingDoc = await getTransactionDoc(orderTrackingId);
  if (existingDoc) {
    await existingDoc.ref.set(
      {
        ...data,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  } else {
    await firestore.collection('pesapal_transactions').add({
      ...data,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}

async function getUserPolygonAddress(userId) {
  if (!firestore || !userId) return null;

  const polygonWalletDoc = await firestore
    .collection('polygon_wallets')
    .doc(userId)
    .get();
  if (polygonWalletDoc.exists) {
    const data = polygonWalletDoc.data() || {};
    if (data.address) return data.address;
  }

  const userDoc = await firestore.collection('users').doc(userId).get();
  if (userDoc.exists) {
    const address = userDoc.data()?.polygonAddress;
    if (address) return address;
  }

  const userDocUpper = await firestore.collection('USER').doc(userId).get();
  if (userDocUpper.exists) {
    const address = userDocUpper.data()?.polygonAddress;
    if (address) return address;
  }

  return null;
}

async function creditTokensIfNeeded(orderTrackingId, storedTx) {
  if (!storedTx) {
    return { success: false, error: 'Transaction not found' };
  }

  const status = (storedTx.status || '').toLowerCase();
  if (status === 'credited') {
    return {
      success: true,
      alreadyCredited: true,
      txHash: storedTx.polygonTxHash,
      explorerUrl: storedTx.polygonExplorerUrl,
    };
  }

  const tokenSymbol = (storedTx.tokenSymbol || 'AKOFA').toUpperCase();
  const tokenAmount = Number(storedTx.tokenAmount || storedTx.akofaAmount || 0);
  const userId = storedTx.userId;

  if (!userId) {
    return { success: false, error: 'User ID missing for transaction' };
  }

  const tokenAddress = tokenContractAddresses[tokenSymbol];
  if (!tokenAddress) {
    return { success: false, error: `Unsupported token: ${tokenSymbol}` };
  }

  if (!process.env.RPC_URL || !process.env.SERVER_PRIVATE_KEY) {
    return { success: false, error: 'Backend wallet not configured' };
  }

  const userAddress = storedTx.walletAddress || await getUserPolygonAddress(userId);
  if (!userAddress) {
    await upsertTransaction(orderTrackingId, {
      status: 'pending_wallet',
      creditError: 'Polygon wallet not found for user',
    });
    return { success: false, pending: true, error: 'User wallet not found' };
  }

  const faucet = getFaucetService();
  const decimals = tokenDecimals[tokenSymbol] ?? 18;

  try {
    const sendResult = await faucet.sendTokens({
      tokenAddress,
      toAddress: userAddress,
      amount: tokenAmount,
      decimals,
      requestedBy: userId,
    });

    await upsertTransaction(orderTrackingId, {
      status: 'credited',
      creditedAt: admin.firestore.FieldValue.serverTimestamp(),
      polygonTxHash: sendResult.txHash,
      polygonExplorerUrl:
        process.env.POLYGON_EXPLORER_URL ||
        `https://polygonscan.com/tx/${sendResult.txHash}`,
      tokenSymbol,
      tokenAmount,
      userId,
    });

    return {
      success: true,
      txHash: sendResult.txHash,
      explorerUrl:
        process.env.POLYGON_EXPLORER_URL ||
        `https://polygonscan.com/tx/${sendResult.txHash}`,
      tokenSymbol,
      tokenAmount,
    };
  } catch (error) {
    await upsertTransaction(orderTrackingId, {
      status: 'credit_failed',
      creditError: error.message || String(error),
    });
    return { success: false, error: error.message || String(error) };
  }
}

/**
 * Health check endpoint
 */
async function healthCheck(req, res) {
  try {
    const health = await pesapalService.healthCheck();
    res.json({
      success: true,
      ...health,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
}

/**
 * Register IPN URL (one-time setup)
 */
async function registerIPN(req, res) {
  try {
    const ipnUrl = req.body?.ipnUrl;
    console.log('🧾 [PESAPAL] Registering IPN URL:', ipnUrl || process.env.PESAPAL_IPN_URL);
    const result = await pesapalService.registerIPN(ipnUrl);
    res.json({
      success: true,
      ...result,
    });
  } catch (error) {
    console.error('IPN registration error:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
}

/**
 * Get registered IPN endpoints
 */
async function getIPNList(req, res) {
  try {
    const ipns = await pesapalService.getRegisteredIPNs();
    res.json({
      success: true,
      ipns,
    });
  } catch (error) {
    console.error('Get IPN list error:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
}

/**
 * Reconcile pending transactions for a user and credit if completed.
 */
async function reconcilePending(req, res) {
  try {
    if (!firestore) {
      return res.status(500).json({
        success: false,
        error: 'Firestore not configured on backend',
      });
    }

    const { userId } = req.body || {};
    if (!userId) {
      return res.status(400).json({
        success: false,
        error: 'userId is required',
      });
    }

    const pendingStatuses = ['pending', 'pending_wallet', 'processing', 'completed'];
    const snapshot = await firestore
      .collection('pesapal_transactions')
      .where('userId', '==', userId)
      .where('status', 'in', pendingStatuses)
      .get();

    let checked = 0;
    let credited = 0;
    let stillPending = 0;
    const results = [];

    for (const doc of snapshot.docs) {
      const tx = doc.data();
      const orderTrackingId = tx.orderTrackingId;
      if (!orderTrackingId) continue;

      checked += 1;
      const status = await pesapalService.getTransactionStatus(orderTrackingId);

      await upsertTransaction(orderTrackingId, {
        status: status.isCompleted ? 'completed' : status.isFailed ? 'failed' : 'pending',
        paymentStatus: status,
      });

      if (status.isCompleted) {
        const creditResult = await creditTokensIfNeeded(orderTrackingId, tx);
        if (creditResult.success) {
          await upsertTransaction(orderTrackingId, {
            status: 'credited',
            creditError: null,
          });
          credited += 1;
        } else if (creditResult.pending) {
          stillPending += 1;
        } else {
          await upsertTransaction(orderTrackingId, {
            status: 'credit_failed',
            creditError: creditResult.error,
          });
        }
        results.push({
          orderTrackingId,
          status: 'completed',
          credited: creditResult.success === true,
          error: creditResult.error,
          txHash: creditResult.txHash,
        });
      } else {
        stillPending += 1;
        results.push({
          orderTrackingId,
          status: status.status,
        });
      }
    }

    res.json({
      success: true,
      checked,
      credited,
      stillPending,
      results,
    });
  } catch (error) {
    console.error('Reconcile pending error:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
}

/**
 * Initiate card payment
 * Creates a payment order and returns redirect URL for card entry
 */
async function initiatePayment(req, res) {
  try {
    const {
      amount,
      currency = 'KES',
      email,
      phone,
      firstName,
      lastName,
      countryCode = 'KE',
      description,
      userId,
      walletAddress,
      callbackUrl,
      tokenSymbol,
      tokenAmount,
      pricePerTokenKES,
      priceLockId,
    } = req.body;

    // Validate required fields
    if (!amount || amount <= 0) {
      return res.status(400).json({
        success: false,
        error: 'Valid amount is required',
      });
    }

    if (!email) {
      return res.status(400).json({
        success: false,
        error: 'Email is required for card payments',
      });
    }

    if (!walletAddress) {
      return res.status(400).json({
        success: false,
        error: 'Wallet address is required for token purchases',
      });
    }

    // Generate unique merchant reference
    const merchantReference = pesapalService.generateMerchantReference();
    
    const resolvedSymbol = (tokenSymbol || 'AKOFA').toUpperCase();
    const resolvedAmount =
      tokenAmount != null
        ? Number(tokenAmount)
        : pesapalService.calculateAkofaAmount(amount, currency);

    console.log('💳 Initiating PesaPal card payment:', {
      merchantReference,
      amount,
      currency,
      tokenAmount: resolvedAmount,
      tokenSymbol: resolvedSymbol,
      email,
    });

    // Submit order to PesaPal
    const result = await pesapalService.submitOrderRequest({
      merchantReference,
      amount,
      currency,
      description:
        description ||
        `Purchase ${resolvedAmount.toFixed(2)} ${resolvedSymbol} tokens`,
      callbackUrl,
      billingAddress: {
        email,
        phone,
        firstName,
        lastName,
        countryCode,
      },
    });

    // Store transaction details for later verification
    pendingTransactions.set(result.orderTrackingId, {
      merchantReference,
      orderTrackingId: result.orderTrackingId,
      amount,
      currency,
      tokenAmount: resolvedAmount,
      tokenSymbol: resolvedSymbol,
      email,
      userId,
      walletAddress,
      status: 'pending',
      createdAt: new Date().toISOString(),
    });

    await upsertTransaction(result.orderTrackingId, {
      userId,
      walletAddress,
      orderTrackingId: result.orderTrackingId,
      merchantReference,
      amountKES: amount,
      tokenAmount: resolvedAmount,
      tokenSymbol: resolvedSymbol,
      pricePerTokenKES,
      priceLockId,
      currency,
      email,
      status: 'pending',
      paymentMethod: 'card',
      tokenContract: tokenContractAddresses[resolvedSymbol],
      tokenDecimals: tokenDecimals[resolvedSymbol],
    });

    console.log('✅ Payment order created:', result.orderTrackingId);

    res.json({
      success: true,
      orderTrackingId: result.orderTrackingId,
      merchantReference: result.merchantReference,
      redirectUrl: result.redirectUrl,
      tokenAmount: resolvedAmount,
      tokenSymbol: resolvedSymbol,
      amount,
      currency,
    });
  } catch (error) {
    console.error('Payment initiation error:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
}

/**
 * Query transaction status
 */
async function queryStatus(req, res) {
  try {
    const { orderTrackingId } = req.body;

    if (!orderTrackingId) {
      return res.status(400).json({
        success: false,
        error: 'orderTrackingId is required',
      });
    }

    console.log('🔍 Querying PesaPal transaction status:', orderTrackingId);

    const status = await pesapalService.getTransactionStatus(orderTrackingId);

    // Get stored transaction details
    let storedTx = pendingTransactions.get(orderTrackingId);
    if (!storedTx && firestore) {
      const doc = await getTransactionDoc(orderTrackingId);
      storedTx = doc ? doc.data() : null;
    }

    const tokenAmount = storedTx?.tokenAmount ?? storedTx?.akofaAmount;
    const tokenSymbol = storedTx?.tokenSymbol ?? 'AKOFA';

    // Persist latest payment status
    await upsertTransaction(orderTrackingId, {
      status: status.isCompleted ? 'completed' : status.isFailed ? 'failed' : 'pending',
      paymentStatus: status,
    });

    res.json({
      success: true,
      ...status,
      tokenAmount,
      tokenSymbol,
      originalAmount: storedTx?.amount ?? storedTx?.amountKES,
      originalCurrency: storedTx?.currency,
      txHash: storedTx?.polygonTxHash,
      explorerUrl: storedTx?.polygonExplorerUrl,
      creditStatus: storedTx?.status,
      creditError: storedTx?.creditError,
    });
  } catch (error) {
    console.error('Status query error:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
}

/**
 * Handle IPN (Instant Payment Notification) callback from PesaPal
 */
async function ipnCallback(req, res) {
  try {
    const {
      OrderTrackingId,
      OrderMerchantReference,
      OrderNotificationType,
    } = req.body;

    console.log('📨 Received PesaPal IPN:', {
      OrderTrackingId,
      OrderMerchantReference,
      OrderNotificationType,
    });

    if (!OrderTrackingId) {
      return res.status(400).json({
        success: false,
        error: 'OrderTrackingId is required',
      });
    }

    // Get full transaction status
    const status = await pesapalService.getTransactionStatus(OrderTrackingId);

    // Update stored transaction
    let storedTx = pendingTransactions.get(OrderTrackingId);
    if (!storedTx && firestore) {
      const doc = await getTransactionDoc(OrderTrackingId);
      storedTx = doc ? doc.data() : null;
    }

    if (storedTx) {
      storedTx.status = status.isCompleted ? 'completed' : status.isFailed ? 'failed' : 'pending';
      storedTx.paymentStatus = status;
      storedTx.updatedAt = new Date().toISOString();
      pendingTransactions.set(OrderTrackingId, storedTx);
    }

    await upsertTransaction(OrderTrackingId, {
      status: status.isCompleted ? 'completed' : status.isFailed ? 'failed' : 'pending',
      paymentStatus: status,
      orderTrackingId: OrderTrackingId,
      merchantReference: OrderMerchantReference,
    });

    if (status.isCompleted) {
      console.log('✅ Payment completed:', {
        OrderTrackingId,
        confirmationCode: status.confirmationCode,
        amount: status.amount,
      });

      // Credit tokens immediately via backend faucet
      if (storedTx) {
        const creditResult = await creditTokensIfNeeded(OrderTrackingId, storedTx);
        if (creditResult.success) {
          console.log('✅ Tokens credited from IPN:', creditResult.txHash);
        } else if (creditResult.pending) {
          console.warn('⚠️ Token credit pending (wallet not found)');
        } else {
          console.error('❌ Token credit failed:', creditResult.error);
        }
      } else {
        console.warn('⚠️ No stored transaction found for crediting');
      }
    } else if (status.isFailed) {
      console.log('❌ Payment failed:', {
        OrderTrackingId,
        message: status.message,
      });
    }

    // PesaPal expects a specific response format
    res.json({
      orderNotificationType: OrderNotificationType,
      orderTrackingId: OrderTrackingId,
      orderMerchantReference: OrderMerchantReference,
      status: status.isCompleted ? 200 : 500,
    });
  } catch (error) {
    console.error('IPN callback error:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
}

/**
 * Handle user callback (redirect after payment)
 */
async function userCallback(req, res) {
  try {
    const { OrderTrackingId, OrderMerchantReference } = req.query;

    console.log('👤 User callback received:', {
      OrderTrackingId,
      OrderMerchantReference,
    });

    if (!OrderTrackingId) {
      return res.redirect('/payment/error?message=Missing+tracking+ID');
    }

    // Get transaction status
    const status = await pesapalService.getTransactionStatus(OrderTrackingId);

    // Load stored transaction for crediting
    let storedTx = pendingTransactions.get(OrderTrackingId);
    if (!storedTx && firestore) {
      const doc = await getTransactionDoc(OrderTrackingId);
      storedTx = doc ? doc.data() : null;
    }

    if (storedTx) {
      storedTx.status = status.isCompleted ? 'completed' : status.isFailed ? 'failed' : 'pending';
      storedTx.paymentStatus = status;
      storedTx.updatedAt = new Date().toISOString();
      pendingTransactions.set(OrderTrackingId, storedTx);
    }

    await upsertTransaction(OrderTrackingId, {
      status: status.isCompleted ? 'completed' : status.isFailed ? 'failed' : 'pending',
      paymentStatus: status,
      orderTrackingId: OrderTrackingId,
      merchantReference: OrderMerchantReference,
    });

    // For API response (when called from mobile app)
    if (req.headers['accept']?.includes('application/json')) {
      const storedTx = pendingTransactions.get(OrderTrackingId);
      return res.json({
        success: status.isCompleted,
        ...status,
        akofaAmount: storedTx?.akofaAmount,
      });
    }

    // For web redirect (when user is redirected from PesaPal)
    if (status.isCompleted) {
      res.redirect(`/payment/success?trackingId=${OrderTrackingId}`);
    } else if (status.isFailed) {
      res.redirect(`/payment/failed?trackingId=${OrderTrackingId}&message=${encodeURIComponent(status.message || 'Payment failed')}`);
    } else {
      res.redirect(`/payment/pending?trackingId=${OrderTrackingId}`);
    }
  } catch (error) {
    console.error('User callback error:', error);
    res.redirect(`/payment/error?message=${encodeURIComponent(error.message)}`);
  }
}

/**
 * Get pending transaction details
 */
async function getTransaction(req, res) {
  try {
    const { orderTrackingId } = req.params;

    const storedTx = pendingTransactions.get(orderTrackingId);
    if (!storedTx) {
      return res.status(404).json({
        success: false,
        error: 'Transaction not found',
      });
    }

    res.json({
      success: true,
      transaction: storedTx,
    });
  } catch (error) {
    console.error('Get transaction error:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
}

module.exports = {
  healthCheck,
  registerIPN,
  getIPNList,
  initiatePayment,
  queryStatus,
  ipnCallback,
  userCallback,
  getTransaction,
  reconcilePending,
};

