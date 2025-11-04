const functions = require('firebase-functions');

// MoonPay webhook handler
exports.moonpayWebhook = require('./moonpayWebhook').moonpayWebhook;

// Flutterwave MTN service functions removed - integration no longer available
// All MTN payment functions have been disabled

// Legacy functions can remain here if needed
// exports.processMpesaPayment = require('./services/mpesaService').processMpesaPayment;