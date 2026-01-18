/**
 * PesaPal Payment Controller
 * 
 * Handles HTTP endpoints for PesaPal card payments
 */

const pesapalService = require('../services/pesapalService');

// In-memory transaction store (replace with database in production)
const pendingTransactions = new Map();

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
    const result = await pesapalService.registerIPN();
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
      callbackUrl,
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

    // Generate unique merchant reference
    const merchantReference = pesapalService.generateMerchantReference();
    
    // Calculate AKOFA amount
    const akofaAmount = pesapalService.calculateAkofaAmount(amount, currency);

    console.log('💳 Initiating PesaPal card payment:', {
      merchantReference,
      amount,
      currency,
      akofaAmount,
      email,
    });

    // Submit order to PesaPal
    const result = await pesapalService.submitOrderRequest({
      merchantReference,
      amount,
      currency,
      description: description || `Purchase ${akofaAmount.toFixed(2)} AKOFA tokens`,
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
      akofaAmount,
      email,
      userId,
      status: 'pending',
      createdAt: new Date().toISOString(),
    });

    console.log('✅ Payment order created:', result.orderTrackingId);

    res.json({
      success: true,
      orderTrackingId: result.orderTrackingId,
      merchantReference: result.merchantReference,
      redirectUrl: result.redirectUrl,
      akofaAmount,
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
    const storedTx = pendingTransactions.get(orderTrackingId);

    res.json({
      success: true,
      ...status,
      akofaAmount: storedTx?.akofaAmount,
      originalAmount: storedTx?.amount,
      originalCurrency: storedTx?.currency,
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
    const storedTx = pendingTransactions.get(OrderTrackingId);
    if (storedTx) {
      storedTx.status = status.isCompleted ? 'completed' : status.isFailed ? 'failed' : 'pending';
      storedTx.paymentStatus = status;
      storedTx.updatedAt = new Date().toISOString();
      pendingTransactions.set(OrderTrackingId, storedTx);
    }

    if (status.isCompleted) {
      console.log('✅ Payment completed:', {
        OrderTrackingId,
        confirmationCode: status.confirmationCode,
        amount: status.amount,
      });

      // TODO: Credit AKOFA tokens to user's wallet
      // This would integrate with your Stellar/Polygon service
      // await creditAkofaTokens(storedTx.userId, storedTx.akofaAmount, OrderTrackingId);
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
};

