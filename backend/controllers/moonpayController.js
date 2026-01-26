const crypto = require('crypto');

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
        console.log('✅ [MOONPAY] Loaded Firebase service account from file');
      } catch (fileError) {
        console.warn('⚠️  [MOONPAY] Could not parse firebase-service-account.json:', fileError.message);
      }
    }

    if (!serviceAccount && process.env.FIREBASE_SERVICE_ACCOUNT) {
      try {
        serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
        console.log('✅ [MOONPAY] Loaded Firebase service account from environment variable');
      } catch (envError) {
        console.warn('⚠️  [MOONPAY] Could not parse FIREBASE_SERVICE_ACCOUNT:', envError.message);
      }
    }

    if (serviceAccount) {
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
      firestore = admin.firestore();
      console.log('✅ [MOONPAY] Firebase Admin initialized');
    } else {
      console.warn('⚠️  [MOONPAY] Firebase Admin not configured. Transaction storage may be limited.');
    }
  } else {
    firestore = admin.firestore();
  }
} catch (error) {
  console.warn('⚠️  [MOONPAY] Firebase Admin not available:', error.message);
  console.warn('   To enable backend storage, install: npm install firebase-admin');
}

// Verify MoonPay webhook signature (optional - webhook works without it but less secure)
function verifyMoonPaySignature(req) {
  const signature = req.headers['moonpay-signature'];
  const webhookSecret = process.env.MOONPAY_WEBHOOK_SECRET;

  // If no webhook secret configured, skip verification (webhook still works)
  if (!webhookSecret) {
    console.warn('⚠️ [MOONPAY] MOONPAY_WEBHOOK_SECRET not configured - webhook signature verification disabled');
    console.warn('   Webhook will still process requests but without signature verification');
    console.warn('   For production, set MOONPAY_WEBHOOK_SECRET in your .env file');
    return true; // Allow webhook to proceed without verification
  }

  // If secret is configured but no signature provided, reject
  if (!signature) {
    console.warn('⚠️ [MOONPAY] No signature header found but webhook secret is configured');
    return false;
  }

  try {
    const expected = crypto
      .createHmac('sha256', webhookSecret)
      .update(req.rawBody)
      .digest('hex');

    // Use timing-safe comparison to prevent timing attacks
    const isValid = crypto.timingSafeEqual(
      Buffer.from(signature),
      Buffer.from(expected)
    );

    if (isValid) {
      console.log('✅ [MOONPAY] Webhook signature verified');
    } else {
      console.warn('⚠️ [MOONPAY] Webhook signature verification failed');
    }

    return isValid;
  } catch (error) {
    console.error('❌ [MOONPAY] Signature verification error:', error);
    return false;
  }
}

/**
 * Generate MoonPay checkout URL
 * POST /api/get-moonpay-url
 */
async function getMoonPayUrl(req, res) {
  try {
    // Get wallet address from request body
    const { walletAddress, amountKES } = req.body;

    if (!walletAddress) {
      return res.status(400).json({ 
        error: 'walletAddress required'
      });
    }

    const apiKey = process.env.MOONPAY_API_KEY;
    if (!apiKey) {
      return res.status(500).json({ 
        error: 'MoonPay API key not configured' 
      });
    }

    const returnUrl = process.env.APP_RETURN_URL || 'myapp://moonpay-return';
    const amount = amountKES || 1000;

    const url =
      `https://buy.moonpay.com` +
      `?apiKey=${apiKey}` +
      `&currencyCode=USDT` +
      `&walletAddress=${walletAddress}` +
      `&baseCurrencyAmount=${amount}` +
      `&redirectURL=${encodeURIComponent(returnUrl)}`;

    console.log('✅ Generated MoonPay URL for wallet:', walletAddress);

    res.json({ url });
  } catch (error) {
    console.error('❌ Error generating MoonPay URL:', error);
    res.status(500).json({ 
      error: 'Failed to generate MoonPay URL',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
}

/**
 * Handle MoonPay webhook
 * POST /webhooks/moonpay
 * 
 * This webhook is OPTIONAL - MoonPay sends tokens directly on-chain.
 * The webhook is only for transaction record-keeping.
 * 
 * If MOONPAY_WEBHOOK_SECRET is not configured, webhook will still work
 * but without signature verification (less secure, but functional).
 */
async function moonPayWebhook(req, res) {
  try {
    // Verify webhook signature (optional - returns true if secret not configured)
    const isSignatureValid = verifyMoonPaySignature(req);
    
    // Only reject if signature verification was attempted and failed
    // (i.e., secret is configured but signature is invalid)
    const webhookSecret = process.env.MOONPAY_WEBHOOK_SECRET;
    if (webhookSecret && !isSignatureValid) {
      console.warn('⚠️ [MOONPAY] Invalid webhook signature - rejecting request');
      return res.status(401).json({ 
        error: 'Invalid signature',
        message: 'Webhook signature verification failed'
      });
    }

    const event = req.body;

    // Only process completed transactions
    if (event.type !== 'transaction.completed') {
      console.log('ℹ️ Ignoring webhook event type:', event.type);
      return res.status(200).send('Ignored');
    }

    const txn = event.data;
    const {
      id: transactionId,
      status,
      walletAddress,
      cryptoCurrency,
      cryptoAmount,
      network
    } = txn;

    if (status !== 'completed') {
      console.log('ℹ️ Transaction not completed:', transactionId, status);
      return res.status(200).send('Not completed');
    }

    // Check for duplicate (idempotency) in Firestore (optional)
    if (firestore) {
      try {
        const existingTx = await firestore
          .collection('moonpay_transactions')
          .where('transactionId', '==', transactionId)
          .limit(1)
          .get();

        if (!existingTx.empty) {
          console.log('ℹ️ [MOONPAY] Transaction already processed:', transactionId);
          return res.status(200).json({ 
            message: 'Already processed',
            transactionId 
          });
        }
      } catch (firestoreError) {
        console.warn('⚠️ [MOONPAY] Error checking for duplicates:', firestoreError.message);
        // Continue processing even if duplicate check fails
      }
    }

    // Store transaction in Firestore (optional - webhook works without it)
    if (firestore) {
      try {
        await firestore.collection('moonpay_transactions').add({
          transactionId,
          walletAddress,
          cryptoCurrency,
          cryptoAmount: Number(cryptoAmount),
          network,
          status,
          source: 'moonpay',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Also store in wallet-specific collection for easy lookup
        await firestore
          .collection('moonpay_wallet_transactions')
          .doc(walletAddress)
          .collection('transactions')
          .add({
            transactionId,
            cryptoCurrency,
            cryptoAmount: Number(cryptoAmount),
            network,
            status,
            source: 'moonpay',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

        console.log('✅ [MOONPAY] Transaction stored in Firestore:', transactionId);
      } catch (firestoreError) {
        console.warn('⚠️ [MOONPAY] Error storing transaction in Firestore:', firestoreError.message);
        console.warn('   Webhook will still return success - transaction record is optional');
        // Continue execution even if Firestore fails
      }
    } else {
      console.log('ℹ️ [MOONPAY] Firestore not available - transaction record not stored');
      console.log('   This is OK - MoonPay sends tokens directly on-chain');
    }

    // Note: Actual token crediting happens on-chain automatically by MoonPay
    // The tokens are sent directly to the walletAddress by MoonPay
    // This webhook just records the transaction for tracking purposes (optional)
    console.log('✅ [MOONPAY] Webhook processed successfully');
    console.log(`   Transaction: ${transactionId}`);
    console.log(`   Wallet: ${walletAddress}`);
    console.log(`   Amount: ${cryptoAmount} ${cryptoCurrency}`);

    res.status(200).json({ 
      success: true,
      message: 'Webhook processed',
      transactionId,
      note: 'Tokens are sent directly on-chain by MoonPay'
    });
  } catch (error) {
    console.error('❌ [MOONPAY] Webhook error:', error);
    // Return 200 to prevent MoonPay from retrying if it's a permanent error
    // Only return 500 for temporary errors that should be retried
    res.status(200).json({ 
      success: false,
      error: 'Webhook processing failed',
      message: 'Error logged but webhook acknowledged to prevent retries'
    });
  }
}

/**
 * Health check endpoint
 * GET /api/moonpay/health
 */
function healthCheck(req, res) {
  res.json({
    success: true,
    service: 'MoonPay Integration',
    timestamp: new Date().toISOString(),
    configured: {
      apiKey: !!process.env.MOONPAY_API_KEY,
      webhookSecret: !!process.env.MOONPAY_WEBHOOK_SECRET,
      firebase: !!firestore,
    },
    webhook: {
      enabled: true,
      signatureVerification: !!process.env.MOONPAY_WEBHOOK_SECRET,
      firestoreStorage: !!firestore,
      note: 'Webhook is optional - MoonPay sends tokens directly on-chain'
    }
  });
}

module.exports = {
  getMoonPayUrl,
  moonPayWebhook,
  healthCheck
};

