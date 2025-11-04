const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();

// MoonPay webhook secret (should be set in environment variables)
const MOONPAY_WEBHOOK_SECRET = functions.config().moonpay?.webhook_secret ||
  process.env.MOONPAY_WEBHOOK_SECRET;

if (!MOONPAY_WEBHOOK_SECRET) {
  console.error('MOONPAY_WEBHOOK_SECRET not configured');
}

/**
 * Verify MoonPay webhook signature
 */
function verifyWebhookSignature(payload, signature) {
  try {
    // MoonPay uses HMAC-SHA256 for webhook signatures
    const hmac = crypto.createHmac('sha256', MOONPAY_WEBHOOK_SECRET);
    hmac.update(JSON.stringify(payload));
    const expectedSignature = `sha256=${hmac.digest('hex')}`;

    return signature === expectedSignature;
  } catch (error) {
    console.error('Webhook signature verification failed:', error);
    return false;
  }
}

/**
 * Handle MoonPay webhook events
 */
exports.moonpayWebhook = functions.https.onRequest(async (req, res) => {
  // Only accept POST requests
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const payload = req.body;
    const signature = req.headers['moonpay-signature'];

    // Verify webhook signature
    if (!signature || !verifyWebhookSignature(payload, signature)) {
      console.error('Invalid webhook signature');
      return res.status(401).json({ error: 'Invalid signature' });
    }

    const eventType = payload.type;
    const data = payload.data;

    console.log(`Processing MoonPay webhook: ${eventType}`, { transactionId: data?.id });

    // Store webhook event in Firestore
    await admin.firestore().collection('moonpay_webhook_events').add({
      eventType,
      data,
      signature,
      receivedAt: admin.firestore.FieldValue.serverTimestamp(),
      processed: false,
    });

    // Process the webhook event
    const result = await processWebhookEvent(eventType, data);

    if (result.success) {
      // Mark as processed
      const eventRef = admin.firestore().collection('moonpay_webhook_events')
        .where('data.id', '==', data.id)
        .where('eventType', '==', eventType)
        .limit(1);

      const snapshot = await eventRef.get();
      if (!snapshot.empty) {
        await snapshot.docs[0].ref.update({
          processed: true,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      return res.status(200).json({ success: true, message: 'Webhook processed successfully' });
    } else {
      console.error('Webhook processing failed:', result.error);
      return res.status(500).json({ error: 'Webhook processing failed', details: result.error });
    }

  } catch (error) {
    console.error('Webhook processing error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Process different webhook event types
 */
async function processWebhookEvent(eventType, data) {
  try {
    switch (eventType) {
      case 'transaction_created':
        return await handleTransactionCreated(data);
      case 'transaction_updated':
        return await handleTransactionUpdated(data);
      case 'transaction_failed':
        return await handleTransactionFailed(data);
      default:
        console.log(`Unhandled webhook event type: ${eventType}`);
        return { success: true, message: 'Event type not handled' };
    }
  } catch (error) {
    console.error(`Error processing ${eventType}:`, error);
    return { success: false, error: error.message };
  }
}

/**
 * Handle transaction created event
 */
async function handleTransactionCreated(data) {
  try {
    const transactionId = data.id;
    const externalCustomerId = data.externalCustomerId;

    console.log(`Transaction created: ${transactionId}`);

    // Store transaction in global collection
    await admin.firestore().collection('moonpay_transactions').doc(transactionId).set({
      ...data,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      processed: false,
    });

    // Store in user's collection if externalCustomerId exists
    if (externalCustomerId) {
      await admin.firestore()
        .collection('users')
        .doc(externalCustomerId)
        .collection('moonpay_transactions')
        .doc(transactionId)
        .set({
          ...data,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          processed: false,
        });

      // Update user status
      await admin.firestore()
        .collection('users')
        .doc(externalCustomerId)
        .collection('moonpay_status')
        .doc(transactionId)
        .set({
          status: 'created',
          transactionId,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          transactionData: data,
        });
    }

    return { success: true, message: 'Transaction created webhook processed' };
  } catch (error) {
    console.error('Error handling transaction created:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Handle transaction updated event
 */
async function handleTransactionUpdated(data) {
  try {
    const transactionId = data.id;
    const status = data.status;
    const externalCustomerId = data.externalCustomerId;

    console.log(`Transaction updated: ${transactionId}, status: ${status}`);

    // Update transaction in global collection
    await admin.firestore().collection('moonpay_transactions').doc(transactionId).update({
      ...data,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Update in user's collection if externalCustomerId exists
    if (externalCustomerId) {
      await admin.firestore()
        .collection('users')
        .doc(externalCustomerId)
        .collection('moonpay_transactions')
        .doc(transactionId)
        .update({
          ...data,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      // Update user status
      await admin.firestore()
        .collection('users')
        .doc(externalCustomerId)
        .collection('moonpay_status')
        .doc(transactionId)
        .set({
          status,
          transactionId,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          transactionData: data,
        }, { merge: true });
    }

    // Handle completion
    if (status === 'completed' || status === 'paid') {
      await handleTransactionCompleted(data);
    } else if (status === 'failed' || status === 'cancelled') {
      await handleTransactionFailed(data);
    }

    return { success: true, message: 'Transaction updated webhook processed' };
  } catch (error) {
    console.error('Error handling transaction updated:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Handle transaction failed event
 */
async function handleTransactionFailed(data) {
  try {
    const transactionId = data.id;
    const externalCustomerId = data.externalCustomerId;
    const failureReason = data.failureReason;

    console.log(`Transaction failed: ${transactionId}, reason: ${failureReason}`);

    // Update transaction in global collection
    await admin.firestore().collection('moonpay_transactions').doc(transactionId).update({
      ...data,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      processed: true,
    });

    // Update in user's collection if externalCustomerId exists
    if (externalCustomerId) {
      await admin.firestore()
        .collection('users')
        .doc(externalCustomerId)
        .collection('moonpay_transactions')
        .doc(transactionId)
        .update({
          ...data,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          processed: true,
        });

      // Update user status
      await admin.firestore()
        .collection('users')
        .doc(externalCustomerId)
        .collection('moonpay_status')
        .doc(transactionId)
        .set({
          status: 'failed',
          transactionId,
          failureReason,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          transactionData: data,
        }, { merge: true });
    }

    return { success: true, message: 'Transaction failed webhook processed' };
  } catch (error) {
    console.error('Error handling transaction failed:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Handle transaction completion
 */
async function handleTransactionCompleted(data) {
  try {
    const transactionId = data.id;
    const externalCustomerId = data.externalCustomerId;
    const walletAddress = data.walletAddress;
    const currencyCode = data.currency?.code;
    const quoteCurrencyAmount = data.quoteCurrencyAmount;

    console.log(`Transaction completed: ${transactionId} for wallet ${walletAddress}`);

    // Record transaction in user's transaction history if externalCustomerId exists
    if (externalCustomerId) {
      const transaction = {
        id: `moonpay_${transactionId}`,
        userId: externalCustomerId,
        type: 'receive',
        status: 'completed',
        amount: quoteCurrencyAmount,
        assetCode: currencyCode.toUpperCase(),
        timestamp: new Date(),
        description: 'MoonPay Purchase',
        memo: `MoonPay transaction ${transactionId}`,
        transactionHash: transactionId,
        senderAddress: 'MoonPay',
        recipientAddress: walletAddress,
        metadata: {
          externalTransactionId: transactionId,
          provider: 'moonpay',
          baseCurrencyAmount: data.baseCurrencyAmount,
          baseCurrencyCode: data.currency?.code,
        },
      };

      // Store in user's transactions
      await admin.firestore()
        .collection('users')
        .doc(externalCustomerId)
        .collection('transactions')
        .doc(transaction.id)
        .set({
          ...transaction,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });

      // Mark transaction as processed
      await admin.firestore().collection('moonpay_transactions').doc(transactionId).update({
        processed: true,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      if (externalCustomerId) {
        await admin.firestore()
          .collection('users')
          .doc(externalCustomerId)
          .collection('moonpay_transactions')
          .doc(transactionId)
          .update({
            processed: true,
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
      }
    }

    return { success: true, message: 'Transaction completion processed' };
  } catch (error) {
    console.error('Error handling transaction completion:', error);
    return { success: false, error: error.message };
  }
}