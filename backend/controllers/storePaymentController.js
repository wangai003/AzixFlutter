/**
 * Store Payment Controller
 * Handles payment transactions for store purchases with order IDs
 */

// HTTP client for webhook notifications
const http = require('http');
const https = require('https');
const crypto = require('crypto');
const { JsonRpcProvider } = require('ethers');

// Firebase Admin is optional - if not available, Flutter app will store directly to Firestore
let admin = null;
let firestore = null;

try {
  admin = require('firebase-admin');
  const fs = require('fs');
  const path = require('path');
  
  // Initialize Firebase Admin if not already initialized
  if (!admin.apps.length) {
    let serviceAccount = null;
    
    // Method 1: Try to load from JSON file (EASIEST - just drop the file in backend folder)
    // __dirname is controllers/, so go up one level to backend/ folder
    const serviceAccountPath = path.join(__dirname, '..', 'firebase-service-account.json');
    if (fs.existsSync(serviceAccountPath)) {
      try {
        const serviceAccountFile = fs.readFileSync(serviceAccountPath, 'utf8');
        serviceAccount = JSON.parse(serviceAccountFile);
        console.log('✅ Loaded Firebase service account from file');
      } catch (fileError) {
        console.warn('⚠️  Could not parse firebase-service-account.json:', fileError.message);
      }
    }
    
    // Method 2: Fall back to environment variable (if file doesn't exist)
    if (!serviceAccount && process.env.FIREBASE_SERVICE_ACCOUNT) {
      try {
        serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
        console.log('✅ Loaded Firebase service account from environment variable');
      } catch (envError) {
        console.warn('⚠️  Could not parse FIREBASE_SERVICE_ACCOUNT:', envError.message);
      }
    }

    if (serviceAccount) {
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
      firestore = admin.firestore();
      console.log('✅ Firebase Admin initialized for store payments');
    } else {
      console.warn('⚠️  Firebase Admin not configured.');
      console.warn('   Option 1: Place firebase-service-account.json in backend/ folder');
      console.warn('   Option 2: Set FIREBASE_SERVICE_ACCOUNT environment variable');
      console.warn('   Payment storage will use Firestore client SDK from Flutter app.');
    }
  } else {
    firestore = admin.firestore();
  }
} catch (error) {
  console.warn('⚠️  Firebase Admin not available. Payment storage will use Firestore client SDK from Flutter app.');
  console.warn('   To enable backend storage, install: npm install firebase-admin');
}

/**
 * Health check endpoint
 */
exports.healthCheck = async (req, res) => {
  res.json({
    success: true,
    message: 'Store payment service is up',
    firebaseConfigured: !!firestore,
  });
};

/**
 * Store payment transaction with order ID
 * This endpoint receives payment details after a successful wallet transaction
 * and stores them securely in the backend
 */
exports.storePaymentTransaction = async (req, res) => {
  try {
    const {
      orderId,
      transactionHash,
      amount,
      assetCode,
      recipientAddress,
      senderAddress,
      userId,
      storeId,
      storeName,
      additionalData,
    } = req.body;

    // Validate required fields
    if (!orderId || !transactionHash) {
      return res.status(400).json({
        success: false,
        error: 'orderId and transactionHash are required',
      });
    }

    if (!amount || amount <= 0) {
      return res.status(400).json({
        success: false,
        error: 'Valid amount is required',
      });
    }

    if (!assetCode) {
      return res.status(400).json({
        success: false,
        error: 'assetCode is required',
      });
    }

    // Validate transaction hash format (Stellar or blockchain)
    if (transactionHash.length < 32) {
      return res.status(400).json({
        success: false,
        error: 'Invalid transaction hash format',
      });
    }

    // Confirm transaction receipt on-chain before accepting payment
    const receiptCheck = await _confirmTransactionOnChain({
      transactionHash,
      assetCode,
    });
    if (!receiptCheck.confirmed) {
      return res.status(409).json({
        success: false,
        error: receiptCheck.error || 'Transaction not confirmed on-chain',
        status: receiptCheck.status || 'pending',
      });
    }

    // Create payment transaction document
    const paymentData = {
      orderId: orderId.trim(),
      transactionHash: transactionHash.trim(),
      amount: Number(amount),
      assetCode: assetCode.toUpperCase(),
      recipientAddress: recipientAddress || null,
      senderAddress: senderAddress || null,
      userId: userId || null,
      storeId: storeId || null,
      storeName: storeName || null,
      status: 'completed',
      paymentType: 'wallet',
      additionalData: {
        ...(additionalData || {}),
        txStatus: receiptCheck.status,
        blockNumber: receiptCheck.blockNumber,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    // Store in Firestore if available
    if (firestore) {
      try {
        // Store in main payment_transactions collection
        const paymentRef = await firestore
          .collection('store_payment_transactions')
          .add(paymentData);

        // Also store in user-specific collection if userId is provided
        if (userId) {
          await firestore
            .collection('users')
            .doc(userId)
            .collection('store_payments')
            .doc(paymentRef.id)
            .set({
              ...paymentData,
              paymentId: paymentRef.id,
            });
        }

        // Store in order-specific collection for easy lookup
        await firestore
          .collection('orders')
          .doc(orderId)
          .collection('payments')
          .doc(paymentRef.id)
          .set({
            ...paymentData,
            paymentId: paymentRef.id,
          });

        // Update order status if order document exists
        const orderRef = firestore.collection('orders').doc(orderId);
        const orderDoc = await orderRef.get();
        
        if (orderDoc.exists) {
          await orderRef.update({
            paymentStatus: 'completed',
            paymentTransactionId: paymentRef.id,
            paymentTransactionHash: transactionHash,
            paymentCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        // Send webhook notification to store (async, don't wait)
        if (storeId) {
          _notifyStoreWebhook(storeId, {
            orderId: orderId,
            paymentId: paymentRef.id,
            transactionHash: transactionHash,
            amount: amount,
            assetCode: assetCode.toUpperCase(),
            status: 'completed',
            timestamp: new Date().toISOString(),
          }).catch(err => {
            console.error('Webhook notification failed:', err);
          });
        }

        return res.json({
          success: true,
          paymentId: paymentRef.id,
          orderId: orderId,
          transactionHash: transactionHash,
          message: 'Payment transaction stored successfully',
        });
      } catch (firestoreError) {
        console.error('Firestore error:', firestoreError);
        return res.status(500).json({
          success: false,
          error: 'Payment transaction confirmed but storage failed',
          details: process.env.NODE_ENV === 'development' ? firestoreError.message : undefined,
        });
      }
    } else {
      return res.status(503).json({
        success: false,
        error: 'Firestore not configured. Backend storage unavailable.',
      });
    }
  } catch (error) {
    console.error('Store payment transaction error:', error);
    return res.status(500).json({
      success: false,
      error: 'Failed to store payment transaction',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined,
    });
  }
};

function _getRpcUrlForAsset(assetCode) {
  const normalizedAsset = (assetCode || '').toUpperCase();
  if (normalizedAsset === 'AKOFA') {
    return process.env.POLYGON_AMOY_RPC_URL || null;
  }
  return process.env.POLYGON_MAINNET_RPC_URL || null;
}

async function _confirmTransactionOnChain({ transactionHash, assetCode }) {
  const rpcUrl = _getRpcUrlForAsset(assetCode);
  if (!rpcUrl) {
    return {
      confirmed: false,
      status: 'unknown',
      error: 'RPC URL not configured for on-chain verification',
    };
  }

  try {
    const provider = new JsonRpcProvider(rpcUrl);
    const receipt = await provider.getTransactionReceipt(transactionHash);
    if (!receipt) {
      return { confirmed: false, status: 'pending' };
    }
    if (receipt.status !== 1) {
      return { confirmed: false, status: 'failed' };
    }
    return {
      confirmed: true,
      status: 'success',
      blockNumber: receipt.blockNumber,
    };
  } catch (error) {
    return {
      confirmed: false,
      status: 'unknown',
      error: error.message || 'On-chain verification failed',
    };
  }
}

/**
 * Get payment transaction by order ID
 */
exports.getPaymentByOrderId = async (req, res) => {
  try {
    const { orderId } = req.params;

    if (!orderId) {
      return res.status(400).json({
        success: false,
        error: 'orderId is required',
      });
    }

    if (!firestore) {
      return res.status(503).json({
        success: false,
        error: 'Firestore not configured',
      });
    }

    // Query payment transactions by order ID
    const paymentsSnapshot = await firestore
      .collection('store_payment_transactions')
      .where('orderId', '==', orderId)
      .orderBy('createdAt', 'desc')
      .limit(1)
      .get();

    if (paymentsSnapshot.empty) {
      return res.status(404).json({
        success: false,
        error: 'Payment transaction not found for this order',
      });
    }

    const paymentDoc = paymentsSnapshot.docs[0];
    const paymentData = paymentDoc.data();

    return res.json({
      success: true,
      payment: {
        id: paymentDoc.id,
        ...paymentData,
        createdAt: paymentData.createdAt?.toDate?.()?.toISOString() || null,
        updatedAt: paymentData.updatedAt?.toDate?.()?.toISOString() || null,
      },
    });
  } catch (error) {
    console.error('Get payment by order ID error:', error);
    return res.status(500).json({
      success: false,
      error: 'Failed to retrieve payment transaction',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined,
    });
  }
};

/**
 * Get payment transactions by user ID
 */
exports.getUserPayments = async (req, res) => {
  try {
    const { userId } = req.params;
    const { limit = 50 } = req.query;

    if (!userId) {
      return res.status(400).json({
        success: false,
        error: 'userId is required',
      });
    }

    if (!firestore) {
      return res.status(503).json({
        success: false,
        error: 'Firestore not configured',
      });
    }

    // Query user's payment transactions
    const paymentsSnapshot = await firestore
      .collection('store_payment_transactions')
      .where('userId', '==', userId)
      .orderBy('createdAt', 'desc')
      .limit(Number(limit))
      .get();

    const payments = paymentsSnapshot.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        ...data,
        createdAt: data.createdAt?.toDate?.()?.toISOString() || null,
        updatedAt: data.updatedAt?.toDate?.()?.toISOString() || null,
      };
    });

    return res.json({
      success: true,
      payments: payments,
      count: payments.length,
    });
  } catch (error) {
    console.error('Get user payments error:', error);
    return res.status(500).json({
      success: false,
      error: 'Failed to retrieve user payments',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined,
    });
  }
};

/**
 * Verify payment transaction
 */
exports.verifyPayment = async (req, res) => {
  try {
    const { orderId, transactionHash } = req.body;

    if (!orderId || !transactionHash) {
      return res.status(400).json({
        success: false,
        error: 'orderId and transactionHash are required',
      });
    }

    if (!firestore) {
      return res.status(503).json({
        success: false,
        error: 'Firestore not configured',
      });
    }

    // Query payment transaction
    const paymentsSnapshot = await firestore
      .collection('store_payment_transactions')
      .where('orderId', '==', orderId)
      .where('transactionHash', '==', transactionHash)
      .limit(1)
      .get();

    if (paymentsSnapshot.empty) {
      return res.json({
        success: false,
        verified: false,
        message: 'Payment transaction not found',
      });
    }

    const paymentDoc = paymentsSnapshot.docs[0];
    const paymentData = paymentDoc.data();

    return res.json({
      success: true,
      verified: true,
      payment: {
        id: paymentDoc.id,
        orderId: paymentData.orderId,
        transactionHash: paymentData.transactionHash,
        amount: paymentData.amount,
        assetCode: paymentData.assetCode,
        status: paymentData.status,
        createdAt: paymentData.createdAt?.toDate?.()?.toISOString() || null,
      },
    });
  } catch (error) {
    console.error('Verify payment error:', error);
    return res.status(500).json({
      success: false,
      error: 'Failed to verify payment',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined,
    });
  }
};

/**
 * Notify store via webhook when payment is completed
 */
async function _notifyStoreWebhook(storeId, paymentData) {
  if (!firestore) {
    console.warn('Cannot send webhook: Firestore not configured');
    return;
  }

  try {
    // Get store configuration
    const storeDoc = await firestore.collection('stores').doc(storeId).get();
    if (!storeDoc.exists) {
      console.warn(`Store ${storeId} not found for webhook notification`);
      return;
    }

    const storeData = storeDoc.data();
    const webhookUrl = storeData.webhookUrl;
    const webhookSecret = storeData.webhookSecret;

    if (!webhookUrl) {
      console.log(`Store ${storeId} has no webhook URL configured`);
      return;
    }

    // Create webhook payload
    const payload = {
      event: 'payment.completed',
      data: paymentData,
      timestamp: new Date().toISOString(),
    };

    // Sign payload if secret is available
    let signature = null;
    if (webhookSecret) {
      const payloadString = JSON.stringify(payload);
      signature = crypto
        .createHmac('sha256', webhookSecret)
        .update(payloadString)
        .digest('hex');
    }

    // Send webhook
    const url = new URL(webhookUrl);
    const isHttps = url.protocol === 'https:';
    const client = isHttps ? https : http;

    const options = {
      hostname: url.hostname,
      port: url.port || (isHttps ? 443 : 80),
      path: url.pathname + url.search,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'AzixFlutter-StorePayment/1.0',
        ...(signature && { 'X-Webhook-Signature': `sha256=${signature}` }),
      },
      timeout: 10000, // 10 seconds
    };

    return new Promise((resolve, reject) => {
      const req = client.request(options, (res) => {
        let data = '';
        res.on('data', (chunk) => {
          data += chunk;
        });
        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            console.log(`✅ Webhook sent to store ${storeId}: ${res.statusCode}`);
            resolve({ success: true, statusCode: res.statusCode });
          } else {
            console.warn(`⚠️  Webhook to store ${storeId} returned ${res.statusCode}`);
            resolve({ success: false, statusCode: res.statusCode });
          }
        });
      });

      req.on('error', (error) => {
        console.error(`❌ Webhook error for store ${storeId}:`, error.message);
        reject(error);
      });

      req.on('timeout', () => {
        req.destroy();
        reject(new Error('Webhook request timeout'));
      });

      req.write(JSON.stringify(payload));
      req.end();
    });
  } catch (error) {
    console.error('Webhook notification error:', error);
    throw error;
  }
}

/**
 * Register or update store webhook configuration
 * POST /api/store-payment/stores/:storeId/webhook
 */
exports.registerStoreWebhook = async (req, res) => {
  try {
    const { storeId } = req.params;
    const { webhookUrl, webhookSecret, storeName, apiKey } = req.body;

    if (!storeId) {
      return res.status(400).json({
        success: false,
        error: 'storeId is required',
      });
    }

    if (!webhookUrl) {
      return res.status(400).json({
        success: false,
        error: 'webhookUrl is required',
      });
    }

    // Validate URL format
    try {
      new URL(webhookUrl);
    } catch (e) {
      return res.status(400).json({
        success: false,
        error: 'Invalid webhook URL format',
      });
    }

    if (!firestore) {
      return res.status(503).json({
        success: false,
        error: 'Firestore not configured',
      });
    }

    // Generate API key if not provided
    const finalApiKey = apiKey || crypto.randomBytes(32).toString('hex');

    // Store or update store configuration
    const storeData = {
      storeId: storeId,
      webhookUrl: webhookUrl,
      webhookSecret: webhookSecret || null,
      storeName: storeName || null,
      apiKey: finalApiKey,
      active: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await firestore.collection('stores').doc(storeId).set(storeData, { merge: true });

    return res.json({
      success: true,
      storeId: storeId,
      apiKey: finalApiKey, // Return API key for first-time registration
      message: 'Store webhook registered successfully',
    });
  } catch (error) {
    console.error('Register store webhook error:', error);
    return res.status(500).json({
      success: false,
      error: 'Failed to register store webhook',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined,
    });
  }
};

/**
 * Verify payment for external stores (public endpoint with API key)
 * GET /api/store-payment/verify/:orderId
 * Headers: X-API-Key: <store-api-key>
 */
exports.verifyPaymentForStore = async (req, res) => {
  try {
    const { orderId } = req.params;
    const apiKey = req.headers['x-api-key'] || req.headers['authorization']?.replace('Bearer ', '');

    if (!orderId) {
      return res.status(400).json({
        success: false,
        error: 'orderId is required',
      });
    }

    if (!apiKey) {
      return res.status(401).json({
        success: false,
        error: 'API key required. Include X-API-Key header or Authorization: Bearer <key>',
      });
    }

    if (!firestore) {
      return res.status(503).json({
        success: false,
        error: 'Firestore not configured',
      });
    }

    // Verify API key and get store info
    const storesSnapshot = await firestore
      .collection('stores')
      .where('apiKey', '==', apiKey)
      .where('active', '==', true)
      .limit(1)
      .get();

    if (storesSnapshot.empty) {
      return res.status(401).json({
        success: false,
        error: 'Invalid API key',
      });
    }

    // Query payment transaction by order ID
    const paymentsSnapshot = await firestore
      .collection('store_payment_transactions')
      .where('orderId', '==', orderId)
      .orderBy('createdAt', 'desc')
      .limit(1)
      .get();

    if (paymentsSnapshot.empty) {
      return res.json({
        success: true,
        verified: false,
        orderId: orderId,
        message: 'No payment found for this order',
      });
    }

    const paymentDoc = paymentsSnapshot.docs[0];
    const paymentData = paymentDoc.data();

    return res.json({
      success: true,
      verified: true,
      payment: {
        id: paymentDoc.id,
        orderId: paymentData.orderId,
        transactionHash: paymentData.transactionHash,
        amount: paymentData.amount,
        assetCode: paymentData.assetCode,
        status: paymentData.status,
        recipientAddress: paymentData.recipientAddress,
        senderAddress: paymentData.senderAddress,
        createdAt: paymentData.createdAt?.toDate?.()?.toISOString() || null,
      },
    });
  } catch (error) {
    console.error('Verify payment for store error:', error);
    return res.status(500).json({
      success: false,
      error: 'Failed to verify payment',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined,
    });
  }
};

/**
 * Get store webhook configuration
 * GET /api/store-payment/stores/:storeId
 * Headers: X-API-Key: <store-api-key>
 */
exports.getStoreConfig = async (req, res) => {
  try {
    const { storeId } = req.params;
    const apiKey = req.headers['x-api-key'] || req.headers['authorization']?.replace('Bearer ', '');

    if (!storeId) {
      return res.status(400).json({
        success: false,
        error: 'storeId is required',
      });
    }

    if (!apiKey) {
      return res.status(401).json({
        success: false,
        error: 'API key required',
      });
    }

    if (!firestore) {
      return res.status(503).json({
        success: false,
        error: 'Firestore not configured',
      });
    }

    const storeDoc = await firestore.collection('stores').doc(storeId).get();

    if (!storeDoc.exists) {
      return res.status(404).json({
        success: false,
        error: 'Store not found',
      });
    }

    const storeData = storeDoc.data();

    // Verify API key
    if (storeData.apiKey !== apiKey) {
      return res.status(401).json({
        success: false,
        error: 'Invalid API key',
      });
    }

    // Return config (without sensitive data)
    return res.json({
      success: true,
      store: {
        storeId: storeData.storeId,
        storeName: storeData.storeName,
        webhookUrl: storeData.webhookUrl,
        active: storeData.active,
        createdAt: storeData.createdAt?.toDate?.()?.toISOString() || null,
        updatedAt: storeData.updatedAt?.toDate?.()?.toISOString() || null,
      },
    });
  } catch (error) {
    console.error('Get store config error:', error);
    return res.status(500).json({
      success: false,
      error: 'Failed to get store configuration',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined,
    });
  }
};

