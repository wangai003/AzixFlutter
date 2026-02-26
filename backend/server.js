const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const gaslessController = require('./controllers/gaslessController');
const mpesaController = require('./controllers/mpesaController');
const pesapalController = require('./controllers/pesapalController');
const storePaymentController = require('./controllers/storePaymentController');
const moonpayController = require('./controllers/moonpayController');
const thirdwebOnrampController = require('./controllers/thirdwebOnrampController');
const { authenticateWallet, getSignMessage } = require('./middleware/walletAuth');
const { userRateLimiter, getStats } = require('./middleware/userRateLimiter');
const walletMonitor = require('./services/walletMonitor');

const app = express();
const PORT = process.env.PORT || 3000;

// Trust proxy (Vercel/NGINX) for correct IP and rate limiting
app.set('trust proxy', 1);

// Security middleware
app.use(helmet());

// CORS configuration - allow all localhost origins in development
const corsOptions = {
  origin: function (origin, callback) {
    // Allow requests with no origin (like mobile apps, Postman, etc.)
    if (!origin) return callback(null, true);
    
    // In development, allow all localhost origins
    if (process.env.NODE_ENV === 'development') {
      if (origin.includes('localhost') || origin.includes('127.0.0.1')) {
        return callback(null, true);
      }
    }
    
    // In production, check allowed origins
    const allowedOrigins = process.env.ALLOWED_ORIGINS?.split(',') || [];
    if (allowedOrigins.includes(origin) || allowedOrigins.includes('*')) {
      return callback(null, true);
    }
    
    callback(new Error('Not allowed by CORS'));
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
};

// Raw body parser for MoonPay webhook signature verification
// Store raw body for all requests (needed for webhook signature verification)
app.use(
  express.json({
    verify: (req, res, buf) => {
      // Always store raw body for potential webhook signature verification
      req.rawBody = buf;
    }
  })
);

// Allow PesaPal IPN callbacks regardless of origin
app.use((req, res, next) => {
  if (req.path.startsWith('/api/pesapal/ipn-callback')) {
    return next();
  }
  return cors(corsOptions)(req, res, next);
});

// Rate limiting (IP-based - general protection)
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.'
});
app.use('/api/', limiter);

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    message: 'AzixFlutter Gasless Backend',
    timestamp: new Date().toISOString()
  });
});

// Lightweight payment status pages (avoid 404s on PesaPal redirects)
app.get('/payment/:status', (req, res) => {
  const { status } = req.params;
  const { trackingId, message } = req.query;
  const normalized = (status || '').toLowerCase();
  const titles = {
    success: 'Payment Successful',
    failed: 'Payment Failed',
    pending: 'Payment Pending',
    error: 'Payment Error',
  };
  const title = titles[normalized] || 'Payment Update';
  const description =
    message ||
    (normalized === 'success'
      ? 'Your payment was successful. You can return to the app.'
      : normalized === 'failed'
        ? 'Your payment failed. You can retry from the app.'
        : normalized === 'pending'
          ? 'Your payment is still processing. We are verifying the status.'
          : 'There was a problem processing your payment.');

  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.status(200).send(`<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>${title}</title>
    <style>
      body { font-family: Arial, sans-serif; background: #0f0f0f; color: #fff; margin: 0; }
      .wrap { max-width: 560px; margin: 40px auto; padding: 24px; text-align: center; }
      .card { background: #1c1c1c; padding: 20px; border-radius: 12px; }
      .muted { color: #aaa; font-size: 13px; margin-top: 8px; }
      .badge { display: inline-block; padding: 6px 10px; border-radius: 8px; background: #333; margin-bottom: 12px; }
    </style>
  </head>
  <body>
    <div class="wrap">
      <div class="card">
        <div class="badge">${normalized || 'update'}</div>
        <h2>${title}</h2>
        <p>${description}</p>
        ${trackingId ? `<p class="muted">Tracking ID: ${trackingId}</p>` : ''}
        <p class="muted">You can safely close this page and return to the app.</p>
      </div>
    </div>
    <script>
      try {
        if (window.parent && window.parent !== window) {
          window.parent.postMessage(window.location.href, '*');
        }
      } catch (e) {}
    </script>
  </body>
</html>`);
});

// Prevent favicon 404 noise
app.get('/favicon.ico', (req, res) => res.status(204).end());

// Monitoring endpoint - rate limiter stats
app.get('/api/monitor/stats', authenticateWallet, (req, res) => {
  const stats = getStats();
  res.json({
    success: true,
    stats,
  });
});

// Get message to sign for wallet verification (optional endpoint)
app.get('/api/auth/sign-message', getSignMessage);

// MEE Sponsorship - Health check
app.get('/api/sponsorship/health', gaslessController.healthCheck);

// M-Pesa Daraja 3.0
app.get('/api/mpesa/health', mpesaController.healthCheck);
app.post('/api/mpesa/stkpush', mpesaController.stkPush);
app.post('/api/mpesa/query', mpesaController.queryStatus);
app.post('/api/mpesa/callback', mpesaController.callback);
app.post('/api/mpesa/b2b', mpesaController.b2bPayment);
app.post('/api/mpesa/c2b/register', mpesaController.registerC2B);
app.post('/api/mpesa/c2b/simulate', mpesaController.simulateC2B);

// PesaPal Card Payments API 3.0
app.get('/api/pesapal/health', pesapalController.healthCheck);
app.post('/api/pesapal/register-ipn', pesapalController.registerIPN);
app.get('/api/pesapal/ipn-list', pesapalController.getIPNList);
app.post('/api/pesapal/initiate', pesapalController.initiatePayment);
app.post('/api/pesapal/query', pesapalController.queryStatus);
app.post('/api/pesapal/reconcile', pesapalController.reconcilePending);
app.post('/api/pesapal/claim', pesapalController.claimCompleted);
app.post('/api/pesapal/ipn-callback', pesapalController.ipnCallback);
app.post('/api/pesapal/ipn-callback/v2', pesapalController.ipnCallback);
app.get('/api/pesapal/ipn-callback', (req, res) => res.sendStatus(200));
app.get('/api/pesapal/ipn-callback/v2', (req, res) => res.sendStatus(200));
app.get('/api/pesapal/callback', pesapalController.userCallback);
app.get('/api/pesapal/transaction/:orderTrackingId', pesapalController.getTransaction);

// Store Payment API - Wallet payments with order IDs
app.get('/api/store-payment/health', storePaymentController.healthCheck);
app.post('/api/store-payment/store', storePaymentController.storePaymentTransaction);
app.get('/api/store-payment/order/:orderId', storePaymentController.getPaymentByOrderId);
app.get('/api/store-payment/user/:userId', storePaymentController.getUserPayments);
app.post('/api/store-payment/verify', storePaymentController.verifyPayment);

// Store Webhook & Verification API (for external stores)
app.post('/api/store-payment/stores/:storeId/webhook', storePaymentController.registerStoreWebhook);
app.get('/api/store-payment/verify/:orderId', storePaymentController.verifyPaymentForStore);
app.get('/api/store-payment/stores/:storeId', storePaymentController.getStoreConfig);

// MoonPay Onramp API
app.get('/api/moonpay/health', moonpayController.healthCheck);
app.post('/api/get-moonpay-url', moonpayController.getMoonPayUrl);
app.post('/api/get-moonpay-sell-url', moonpayController.getMoonPaySellUrl);
app.post('/webhooks/moonpay', moonpayController.moonPayWebhook);

// Thirdweb Onramp API
app.post('/api/onramp/prepare', thirdwebOnrampController.prepareOnramp);
app.get('/api/onramp/status/:quoteId', thirdwebOnrampController.getOnrampStatus);

// MEE Sponsorship - Get smart account address
app.get('/api/sponsorship/smart-account', gaslessController.getSmartAccountAddress);

// API Routes - Gasless Transactions (Sponsored by Biconomy MEE)
// Note: Per-wallet rate limiting applied AFTER authentication
app.post('/api/gasless/send-token', 
  authenticateWallet,
  userRateLimiter, // Per-wallet rate limiting (by wallet address)
  gaslessController.sendToken
);

app.post('/api/gasless/estimate-gas',
  authenticateWallet,
  gaslessController.estimateGas
);

app.get('/api/gasless/transaction-status/:txHash',
  gaslessController.getTransactionStatus // No auth needed - just lookup
);

app.post('/api/gasless/check-eligibility',
  authenticateWallet,
  userRateLimiter, // Check rate limit without blocking
  gaslessController.checkEligibility
);

// Admin/Monitoring endpoint - Backend wallet status
app.get('/api/gasless/wallet-status',
  gaslessController.getWalletStatus // Public endpoint in dev, should be protected in prod
);

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(err.status || 500).json({
    success: false,
    error: err.message || 'Internal server error',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: 'Endpoint not found'
  });
});

// Start server
app.listen(PORT, () => {
  console.log('');
  console.log('═════════════════════════════════════════════════════════');
  console.log('🚀 AzixFlutter Gasless Backend');
  console.log('═════════════════════════════════════════════════════════');
  console.log(`📍 Environment: ${process.env.NODE_ENV}`);
  console.log(`🌐 Port: ${PORT}`);
  console.log(`⛓️  Network: Polygon Amoy (Chain ID: ${process.env.CHAIN_ID})`);
  console.log(`🔑 Biconomy API Key: ${process.env.BICONOMY_API_KEY?.substring(0, 15)}...`);
  console.log('');
  console.log('🔒 Security Features:');
  console.log('   ✅ Wallet-Based Authentication');
  console.log('   ✅ Per-Wallet Rate Limiting (10 tx/day)');
  console.log('   ✅ IP-Based Rate Limiting');
  console.log('   ⚡ Optional Signature Verification');
  console.log('');
  console.log('💫 Gas Sponsorship:');
  console.log('   ✨ Biconomy MEE Sponsorship');
  console.log('   💰 Users pay: $0.00');
  console.log('   🎯 Method: Biconomy-hosted sponsorship via apiKey');
  console.log('   📚 Docs: https://docs.biconomy.io/new/getting-started/sponsor-gas-for-users');
  console.log('');
  console.log('💳 Payment Integrations:');
  console.log('   📱 M-Pesa (Daraja 3.0) - Mobile Money');
  console.log(`   💳 PesaPal (API 3.0) - Card Payments ${process.env.PESAPAL_CONSUMER_KEY ? '✅' : '⚠️ Not configured'}`);
  console.log('');
  
  // Start wallet monitoring
  walletMonitor.startMonitoring();
  
  console.log('═════════════════════════════════════════════════════════');
  console.log('✅ Server ready to accept requests');
  console.log('═════════════════════════════════════════════════════════');
  console.log('');
});

module.exports = app;

