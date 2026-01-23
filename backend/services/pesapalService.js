/**
 * PesaPal Payment Service
 * 
 * Handles card payments via PesaPal API 3.0
 * Documentation: https://developer.pesapal.com/
 */

const crypto = require('crypto');

// Environment configuration
const PESAPAL_ENV = process.env.PESAPAL_ENV || 'sandbox';
const PESAPAL_CONSUMER_KEY = process.env.PESAPAL_CONSUMER_KEY;
const PESAPAL_CONSUMER_SECRET = process.env.PESAPAL_CONSUMER_SECRET;
const PESAPAL_IPN_ID = process.env.PESAPAL_IPN_ID; // IPN ID from PesaPal dashboard
const PESAPAL_CALLBACK_URL = process.env.PESAPAL_CALLBACK_URL;
const PESAPAL_IPN_URL = process.env.PESAPAL_IPN_URL;

// API Base URLs
const BASE_URL = PESAPAL_ENV === 'production'
  ? 'https://pay.pesapal.com/v3'
  : 'https://cybqa.pesapal.com/pesapalv3';

// Token cache
let accessToken = null;
let tokenExpiresAt = null;

/**
 * Validate required environment variables
 */
function requireEnv(name, value) {
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
}

/**
 * Get PesaPal access token
 * Tokens are cached until expiry
 */
async function getAccessToken() {
  requireEnv('PESAPAL_CONSUMER_KEY', PESAPAL_CONSUMER_KEY);
  requireEnv('PESAPAL_CONSUMER_SECRET', PESAPAL_CONSUMER_SECRET);

  // Return cached token if still valid
  if (accessToken && tokenExpiresAt && Date.now() < tokenExpiresAt) {
    console.log('🔑 Using cached PesaPal access token');
    return accessToken;
  }

  console.log('🔐 Requesting new PesaPal access token...');

  const url = `${BASE_URL}/api/Auth/RequestToken`;
  const body = {
    consumer_key: PESAPAL_CONSUMER_KEY.trim(),
    consumer_secret: PESAPAL_CONSUMER_SECRET.trim(),
  };

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: JSON.stringify(body),
  });

  const data = await response.json();

  if (!response.ok || data.error) {
    console.error('❌ PesaPal auth failed:', data);
    throw new Error(data.error?.message || data.message || 'Failed to get PesaPal access token');
  }

  accessToken = data.token;
  // Token expires in 5 minutes, cache for 4 minutes to be safe
  tokenExpiresAt = Date.now() + (4 * 60 * 1000);

  console.log('✅ PesaPal access token obtained successfully');
  return accessToken;
}

/**
 * Register IPN (Instant Payment Notification) URL
 * This should be called once during setup
 */
async function registerIPN(ipnUrlOverride) {
  const ipnUrl = ipnUrlOverride || PESAPAL_IPN_URL;
  requireEnv('PESAPAL_IPN_URL', ipnUrl);

  const token = await getAccessToken();
  const url = `${BASE_URL}/api/URLSetup/RegisterIPN`;

  const body = {
    url: ipnUrl,
    ipn_notification_type: 'POST',
  };

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: JSON.stringify(body),
  });

  const data = await response.json();

  if (!response.ok || data.error) {
    console.error('❌ IPN registration failed:', data);
    throw new Error(data.error?.message || 'Failed to register IPN URL');
  }

  console.log('✅ IPN URL registered:', data);
  return {
    ipnId: data.ipn_id,
    url: data.url,
    createdDate: data.created_date,
    status: data.status,
  };
}

/**
 * Get registered IPN endpoints
 */
async function getRegisteredIPNs() {
  const token = await getAccessToken();
  const url = `${BASE_URL}/api/URLSetup/GetIpnList`;

  const response = await fetch(url, {
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Accept': 'application/json',
    },
  });

  const data = await response.json();

  if (!response.ok) {
    throw new Error('Failed to get IPN list');
  }

  return data;
}

/**
 * Submit a payment order request
 * Returns a redirect URL for the user to complete payment
 */
async function submitOrderRequest({
  merchantReference,
  amount,
  currency = 'KES',
  description,
  callbackUrl,
  cancellationUrl,
  notificationId,
  billingAddress,
}) {
  requireEnv('PESAPAL_CALLBACK_URL', PESAPAL_CALLBACK_URL);

  const token = await getAccessToken();
  const url = `${BASE_URL}/api/Transactions/SubmitOrderRequest`;

  // Use provided IPN ID or fallback to env variable
  // If no IPN ID, we'll auto-register one
  let ipnId = notificationId || PESAPAL_IPN_ID;
  
  if (!ipnId) {
    console.log('⚠️ No IPN ID configured. Attempting to auto-register IPN URL...');
    try {
      const ipnResult = await registerIPN();
      ipnId = ipnResult.ipnId;
      console.log(`✅ Auto-registered IPN ID: ${ipnId}`);
      console.log(`💡 Add this to your .env: PESAPAL_IPN_ID=${ipnId}`);
    } catch (ipnError) {
      console.error('❌ Failed to auto-register IPN:', ipnError.message);
      throw new Error('IPN ID is required. Please register an IPN endpoint first via POST /api/pesapal/register-ipn');
    }
  }

  const body = {
    id: merchantReference,
    currency: currency,
    amount: parseFloat(amount).toFixed(2),
    description: description || 'AKOFA Token Purchase',
    callback_url: callbackUrl || PESAPAL_CALLBACK_URL,
    cancellation_url: cancellationUrl || `${PESAPAL_CALLBACK_URL}?status=cancelled`,
    notification_id: ipnId,
    billing_address: {
      email_address: billingAddress?.email || '',
      phone_number: billingAddress?.phone || '',
      country_code: billingAddress?.countryCode || 'KE',
      first_name: billingAddress?.firstName || '',
      middle_name: billingAddress?.middleName || '',
      last_name: billingAddress?.lastName || '',
      line_1: billingAddress?.line1 || '',
      line_2: billingAddress?.line2 || '',
      city: billingAddress?.city || '',
      state: billingAddress?.state || '',
      postal_code: billingAddress?.postalCode || '',
      zip_code: billingAddress?.zipCode || '',
    },
  };

  console.log('📤 Submitting PesaPal order request:', {
    merchantReference,
    amount,
    currency,
    description,
  });

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: JSON.stringify(body),
  });

  const data = await response.json();

  if (!response.ok || data.error) {
    console.error('❌ Order submission failed:', data);
    throw new Error(data.error?.message || data.message || 'Failed to submit order');
  }

  console.log('✅ Order submitted successfully:', {
    orderTrackingId: data.order_tracking_id,
    merchantReference: data.merchant_reference,
  });

  return {
    orderTrackingId: data.order_tracking_id,
    merchantReference: data.merchant_reference,
    redirectUrl: data.redirect_url,
    status: data.status,
  };
}

/**
 * Get transaction status
 */
async function getTransactionStatus(orderTrackingId) {
  const token = await getAccessToken();
  const url = `${BASE_URL}/api/Transactions/GetTransactionStatus?orderTrackingId=${orderTrackingId}`;

  console.log('🔍 Checking transaction status:', orderTrackingId);

  const response = await fetch(url, {
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Accept': 'application/json',
    },
  });

  const data = await response.json();

  if (!response.ok) {
    console.error('❌ Status check failed:', data);
    throw new Error(data.error?.message || 'Failed to get transaction status');
  }

  console.log('📊 Transaction status:', data);

  // Map PesaPal status codes to readable status
  const statusMap = {
    '0': 'INVALID',
    '1': 'COMPLETED',
    '2': 'FAILED',
    '3': 'REVERSED',
  };

  return {
    paymentMethod: data.payment_method,
    amount: data.amount,
    createdDate: data.created_date,
    confirmationCode: data.confirmation_code,
    paymentStatusDescription: data.payment_status_description,
    description: data.description,
    message: data.message,
    paymentAccount: data.payment_account,
    callBackUrl: data.call_back_url,
    statusCode: data.status_code,
    merchantReference: data.merchant_reference,
    paymentStatusCode: data.payment_status_code,
    currency: data.currency,
    status: statusMap[data.status_code] || 'PENDING',
    isCompleted: data.status_code === '1',
    isFailed: data.status_code === '2',
  };
}

/**
 * Verify IPN callback signature (for webhook security)
 */
function verifyIPNSignature(payload, signature) {
  // PesaPal IPN verification
  // The signature is typically the OrderTrackingId + MerchantReference
  // hashed with your consumer secret
  const expectedSignature = crypto
    .createHmac('sha256', PESAPAL_CONSUMER_SECRET)
    .update(`${payload.OrderTrackingId}${payload.OrderMerchantReference}`)
    .digest('hex');

  return signature === expectedSignature;
}

/**
 * Generate unique merchant reference
 */
function generateMerchantReference(prefix = 'AKOFA') {
  const timestamp = Date.now();
  const random = Math.random().toString(36).substring(2, 8).toUpperCase();
  return `${prefix}_${timestamp}_${random}`;
}

/**
 * Calculate AKOFA amount from currency amount
 * Exchange rate: 1 AKOFA = 5.52 KES
 */
function calculateAkofaAmount(amount, currency = 'KES') {
  // For non-KES currencies, you would need to convert to KES first
  // For now, we assume KES
  const kesAmount = currency === 'KES' ? amount : amount; // Add conversion logic for other currencies
  return kesAmount / 5.52;
}

/**
 * Health check for PesaPal API
 */
async function healthCheck() {
  try {
    await getAccessToken();
    return {
      status: 'ok',
      environment: PESAPAL_ENV,
      baseUrl: BASE_URL,
      hasCredentials: !!(PESAPAL_CONSUMER_KEY && PESAPAL_CONSUMER_SECRET),
      hasIpnId: !!PESAPAL_IPN_ID,
    };
  } catch (error) {
    return {
      status: 'error',
      error: error.message,
      environment: PESAPAL_ENV,
    };
  }
}

module.exports = {
  getAccessToken,
  registerIPN,
  getRegisteredIPNs,
  submitOrderRequest,
  getTransactionStatus,
  verifyIPNSignature,
  generateMerchantReference,
  calculateAkofaAmount,
  healthCheck,
  BASE_URL,
  PESAPAL_ENV,
};

