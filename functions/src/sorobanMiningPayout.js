const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

admin.initializeApp();

// Soroban RPC endpoint
const SOROBAN_RPC_URL = 'https://soroban-testnet.stellar.org:443';

// Contract details - update with actual deployed contract ID
const CONTRACT_ID = 'CA7QYNF7SOWQ3GLR2BGMZEHXAVIRZA4KVWLTJJFC7MGXUA74P7UJVSGZ'; // Placeholder

// Distributor account for payouts
const DISTRIBUTOR_SECRET = 'SCB3ICTKZ3FQX6R6JRBV2427JVPGN7IELDUWQOKDFGT5BGKQKWBURPIR';

/**
 * Cloud Function to automatically process mining payouts
 * Triggered by Firestore document changes or scheduled calls
 */
exports.processMiningPayouts = functions
  .runWith({
    timeoutSeconds: 540, // 9 minutes
    memory: '1GB'
  })
  .pubsub.schedule('every 1 hours') // Check every hour
  .onRun(async (context) => {
    console.log('🔄 Starting automatic mining payout processing...');

    try {
      // Get all users with active mining sessions
      const usersSnapshot = await admin.firestore()
        .collection('users')
        .get();

      let processedCount = 0;
      let payoutCount = 0;

      for (const userDoc of usersSnapshot.docs) {
        const userId = userDoc.id;
        const userData = userDoc.data();

        try {
          // Check if user has a wallet
          const walletDoc = await admin.firestore()
            .collection('secure_wallets')
            .doc(userId)
            .get();

          if (!walletDoc.exists) {
            console.log(`⚠️ User ${userId} has no wallet, skipping`);
            continue;
          }

          const userPublicKey = walletDoc.data().publicKey;

          // Check for active mining sessions
          const sessionsSnapshot = await admin.firestore()
            .collection('users')
            .doc(userId)
            .collection('active_mining_sessions')
            .where('completed', '==', false)
            .get();

          for (const sessionDoc of sessionsSnapshot.docs) {
            const sessionData = sessionDoc.data();
            const sessionEnd = sessionData.sessionEnd.toDate();
            const now = new Date();

            // Check if session has expired
            if (now >= sessionEnd) {
              console.log(`⏰ Processing expired session for user ${userId}`);

              // Call contract to process payout
              const payoutResult = await processContractPayout(userPublicKey);

              if (payoutResult.success) {
                // Mark session as completed in Firestore
                await sessionDoc.ref.update({
                  completed: true,
                  payoutStatus: 'completed',
                  completedAt: admin.firestore.FieldValue.serverTimestamp(),
                  payoutTxHash: payoutResult.txHash,
                });

                payoutCount++;
                console.log(`✅ Payout completed for user ${userId}: ${payoutResult.txHash}`);
              } else {
                // Mark as failed
                await sessionDoc.ref.update({
                  payoutStatus: 'failed',
                  errorMessage: payoutResult.error,
                  completedAt: admin.firestore.FieldValue.serverTimestamp(),
                });

                console.log(`❌ Payout failed for user ${userId}: ${payoutResult.error}`);
              }
            }
          }

          processedCount++;
        } catch (error) {
          console.error(`❌ Error processing user ${userId}:`, error);
        }
      }

      console.log(`✅ Payout processing complete. Processed ${processedCount} users, ${payoutCount} payouts.`);

      return {
        success: true,
        processedUsers: processedCount,
        payoutsProcessed: payoutCount
      };

    } catch (error) {
      console.error('❌ Critical error in payout processing:', error);
      throw new functions.https.HttpsError('internal', 'Payout processing failed');
    }
  });

/**
 * Process payout via Soroban contract
 */
async function processContractPayout(userPublicKey) {
  try {
    // Build the contract call transaction
    const transactionXdr = await buildPayoutTransaction(userPublicKey);

    // Submit transaction via RPC
    const response = await axios.post(SOROBAN_RPC_URL, {
      jsonrpc: '2.0',
      id: 1,
      method: 'sendTransaction',
      params: {
        transaction: transactionXdr
      }
    });

    if (response.data.result && response.data.result.status === 'SUCCESS') {
      return {
        success: true,
        txHash: response.data.result.hash
      };
    } else {
      return {
        success: false,
        error: response.data.error || 'Transaction failed'
      };
    }

  } catch (error) {
    console.error('Contract payout error:', error);
    return {
      success: false,
      error: error.message
    };
  }
}

/**
 * Build payout transaction XDR (simplified - needs proper Soroban XDR building)
 */
async function buildPayoutTransaction(userPublicKey) {
  // This is a placeholder - in production you would:
  // 1. Build proper Soroban transaction XDR
  // 2. Include contract ID, function name, arguments
  // 3. Sign with distributor key

  // For now, return a placeholder XDR
  return 'AAAAAgAAAAA...'; // Replace with actual XDR building logic
}

/**
 * Manual trigger for testing payouts
 */
exports.manualMiningPayout = functions.https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const userId = context.auth.uid;
  const userPublicKey = data.userPublicKey;

  if (!userPublicKey) {
    throw new functions.https.HttpsError('invalid-argument', 'User public key required');
  }

  try {
    console.log(`🔄 Manual payout request for user ${userId}`);

    const result = await processContractPayout(userPublicKey);

    if (result.success) {
      // Update Firestore
      const sessionsSnapshot = await admin.firestore()
        .collection('users')
        .doc(userId)
        .collection('active_mining_sessions')
        .where('completed', '==', false)
        .get();

      for (const doc of sessionsSnapshot.docs) {
        await doc.ref.update({
          completed: true,
          payoutStatus: 'completed',
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
          payoutTxHash: result.txHash,
        });
      }

      return { success: true, txHash: result.txHash };
    } else {
      return { success: false, error: result.error };
    }

  } catch (error) {
    console.error('Manual payout error:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});