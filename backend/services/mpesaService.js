const crypto = require('crypto');

const MPESA_ENV = process.env.MPESA_ENV || 'sandbox';
const MPESA_CONSUMER_KEY = process.env.MPESA_CONSUMER_KEY;
const MPESA_CONSUMER_SECRET = process.env.MPESA_CONSUMER_SECRET;
const MPESA_PASSKEY = process.env.MPESA_PASSKEY;
const MPESA_SHORTCODE = process.env.MPESA_SHORTCODE;
const MPESA_CALLBACK_URL = process.env.MPESA_CALLBACK_URL;
const MPESA_C2B_SHORTCODE = process.env.MPESA_C2B_SHORTCODE || MPESA_SHORTCODE;
const MPESA_C2B_RESPONSE_TYPE =
  process.env.MPESA_C2B_RESPONSE_TYPE || 'Completed';
const MPESA_C2B_CONFIRMATION_URL =
  process.env.MPESA_C2B_CONFIRMATION_URL || MPESA_CALLBACK_URL;
const MPESA_C2B_VALIDATION_URL = process.env.MPESA_C2B_VALIDATION_URL;
const MPESA_INITIATOR_NAME = process.env.MPESA_INITIATOR_NAME;
const MPESA_SECURITY_CREDENTIAL = process.env.MPESA_SECURITY_CREDENTIAL;
const MPESA_B2B_QUEUE_URL = process.env.MPESA_B2B_QUEUE_URL || MPESA_CALLBACK_URL;
const MPESA_B2B_RESULT_URL = process.env.MPESA_B2B_RESULT_URL || MPESA_CALLBACK_URL;

const BASE_URL =
  MPESA_ENV === 'production'
    ? 'https://api.safaricom.co.ke'
    : 'https://sandbox.safaricom.co.ke';

function requireEnv(name, value) {
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
}

function formatPhone(phone) {
  const digits = phone.replace(/[^\d]/g, '');
  if (digits.startsWith('254')) return digits;
  if (digits.startsWith('0')) return `254${digits.slice(1)}`;
  if (digits.startsWith('7') && digits.length === 9) return `254${digits}`;
  if (digits.startsWith('+254')) return digits.slice(1);
  return digits;
}

function timestamp() {
  const now = new Date();
  const pad = (n) => n.toString().padStart(2, '0');
  return (
    now.getFullYear().toString() +
    pad(now.getMonth() + 1) +
    pad(now.getDate()) +
    pad(now.getHours()) +
    pad(now.getMinutes()) +
    pad(now.getSeconds())
  );
}

function stkPassword(ts) {
  // Trim any whitespace that might sneak in from .env
  const shortcode = (MPESA_SHORTCODE || '').trim();
  const passkey = (MPESA_PASSKEY || '').trim();
  const data = `${shortcode}${passkey}${ts}`;
  
  // DEBUG: Log password generation
  console.log('🔐 Password Debug:', {
    shortcodeLen: shortcode.length,
    passkeyLen: passkey.length,
    tsLen: ts.length,
    totalLen: data.length,
    rawData: data.substring(0, 20) + '...',
  });
  
  return Buffer.from(data).toString('base64');
}

async function getAccessToken() {
  requireEnv('MPESA_CONSUMER_KEY', MPESA_CONSUMER_KEY);
  requireEnv('MPESA_CONSUMER_SECRET', MPESA_CONSUMER_SECRET);

  // Trim whitespace from env vars
  const consumerKey = (MPESA_CONSUMER_KEY || '').trim();
  const consumerSecret = (MPESA_CONSUMER_SECRET || '').trim();

  const auth = Buffer.from(
    `${consumerKey}:${consumerSecret}`
  ).toString('base64');

  const res = await fetch(
    `${BASE_URL}/oauth/v1/generate?grant_type=client_credentials`,
    {
      method: 'GET',
      headers: {
        Authorization: `Basic ${auth}`,
        Accept: 'application/json',
      },
    }
  );

  if (!res.ok) {
    const body = await res.text();
    throw new Error(
      `Failed to get access token (${res.status}): ${body || res.statusText}`
    );
  }

  const data = await res.json();
  
  // DEBUG: Log the FULL raw OAuth response - NO TRUNCATION
  console.log('🎫 RAW OAUTH RESPONSE:', JSON.stringify(data, null, 2));
  console.log('🎫 FULL ACCESS TOKEN:', data.access_token);
  console.log('🎫 TOKEN LENGTH:', data.access_token?.length);
  
  if (!data.access_token) {
    throw new Error('No access_token in OAuth response: ' + JSON.stringify(data));
  }
  
  // Verify token length - should be > 100 chars
  if (data.access_token.length < 100) {
    console.warn('⚠️ WARNING: Token seems too short! Expected > 100 chars, got:', data.access_token.length);
  }
  
  return data.access_token;
}

async function initiateStkPush({ phoneNumber, amountKES, accountReference, description }) {
  requireEnv('MPESA_PASSKEY', MPESA_PASSKEY);
  requireEnv('MPESA_SHORTCODE', MPESA_SHORTCODE);
  requireEnv('MPESA_CALLBACK_URL', MPESA_CALLBACK_URL);

  const formattedPhone = formatPhone(phoneNumber);
  const accessToken = await getAccessToken();
  const ts = timestamp();
  const password = stkPassword(ts);

  // DEBUG: Log credentials being used (remove in production)
  console.log('🔑 STK Push Debug:', {
    consumerKey: MPESA_CONSUMER_KEY ? MPESA_CONSUMER_KEY.substring(0, 10) + '...' : 'NOT SET',
    shortcode: MPESA_SHORTCODE,
    passkey: MPESA_PASSKEY ? MPESA_PASSKEY.substring(0, 10) + '...' : 'NOT SET',
    timestamp: ts,
    timestampLength: ts.length,
    passwordLength: password.length,
    tokenPrefix: accessToken ? accessToken.substring(0, 10) + '...' : 'NOT SET',
    phone: formattedPhone,
  });

  // Trim env vars to avoid whitespace issues
  const shortcode = (MPESA_SHORTCODE || '').trim();
  const callbackUrl = (MPESA_CALLBACK_URL || '').trim();

  const body = {
    BusinessShortCode: shortcode,
    Password: password,
    Timestamp: ts,
    TransactionType: 'CustomerPayBillOnline',
    Amount: Math.round(amountKES).toString(),
    PartyA: formattedPhone,
    PartyB: shortcode,
    PhoneNumber: formattedPhone,
    CallBackURL: callbackUrl,
    AccountReference: accountReference,
    TransactionDesc: description || 'AKOFA Purchase',
  };

  // Daraja 3.0 STK push endpoint (processrequest)
  const url = `${BASE_URL}/mpesa/stkpush/v1/processrequest`;
  
  // DEBUG: Log the actual Authorization header being sent
  const authHeader = `Bearer ${accessToken}`;
  console.log('🔒 FINAL TOKEN CHECK:', {
    fullTokenLength: accessToken.length,
    tokenValid: accessToken.length > 100 ? '✅ VALID' : '❌ TOO SHORT',
    fullToken: accessToken,  // Log full token for debugging
  });
  
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: authHeader,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify(body),
  });

  const raw = await res.text();
  let data = {};
  try {
    data = JSON.parse(raw);
  } catch (e) {
    // non-JSON response
  }

  if (!res.ok || data.ResponseCode !== '0') {
    console.error('STK push failed', {
      url,
      status: res.status,
      statusText: res.statusText,
      raw,
      data,
    });
    throw new Error(
      data.errorMessage ||
        data.errorCode ||
        data.ResponseDescription ||
        raw ||
        `STK push failed (${res.status})`
    );
  }

  return {
    checkoutRequestId: data.CheckoutRequestID,
    responseCode: data.ResponseCode,
    customerMessage: data.CustomerMessage,
    merchantRequestId: data.MerchantRequestID,
  };
}

async function queryStkStatus(checkoutRequestId) {
  requireEnv('MPESA_PASSKEY', MPESA_PASSKEY);
  requireEnv('MPESA_SHORTCODE', MPESA_SHORTCODE);

  const accessToken = await getAccessToken();
  const ts = timestamp();
  const password = stkPassword(ts);

  const body = {
    BusinessShortCode: MPESA_SHORTCODE,
    Password: password,
    Timestamp: ts,
    CheckoutRequestID: checkoutRequestId,
  };

  const res = await fetch(`${BASE_URL}/mpesa/stkpushquery/v1/query`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify(body),
  });

  const data = await res.json().catch(() => ({}));

  if (!res.ok) {
    throw new Error(
      data.errorMessage ||
        data.errorCode ||
        data.ResultDesc ||
        JSON.stringify(data) ||
        `Query failed (${res.status})`
    );
  }

  return {
    resultCode: data.ResultCode,
    resultDesc: data.ResultDesc,
    response: data,
  };
}

/**
 * Initiate a B2B payment (BusinessBuyGoods)
 * Moves funds from your business shortcode (PartyA) to another shortcode (PartyB).
 * SecurityCredential must be the encrypted initiator password from Safaricom.
 */
async function initiateB2BPayment({
  amount,
  partyB,
  accountReference,
  remarks,
  requester,
  commandId = 'BusinessBuyGoods',
  senderIdentifierType = '4',
  receiverIdentifierType = '4',
}) {
  requireEnv('MPESA_INITIATOR_NAME', MPESA_INITIATOR_NAME);
  requireEnv('MPESA_SECURITY_CREDENTIAL', MPESA_SECURITY_CREDENTIAL);
  requireEnv('MPESA_SHORTCODE', MPESA_SHORTCODE);

  const accessToken = await getAccessToken();

  const body = {
    Initiator: MPESA_INITIATOR_NAME,
    SecurityCredential: MPESA_SECURITY_CREDENTIAL,
    CommandID: commandId,
    SenderIdentifierType: senderIdentifierType,
    RecieverIdentifierType: receiverIdentifierType,
    Amount: Math.round(Number(amount)).toString(),
    PartyA: MPESA_SHORTCODE,
    PartyB: partyB,
    AccountReference: accountReference,
    Remarks: remarks || 'B2B Payment',
    QueueTimeOutURL: MPESA_B2B_QUEUE_URL,
    ResultURL: MPESA_B2B_RESULT_URL,
    ...(requester ? { Requester: requester } : {}),
  };

  const url = `${BASE_URL}/mpesa/b2b/v1/paymentrequest`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify(body),
  });

  const raw = await res.text();
  let data = {};
  try {
    data = JSON.parse(raw);
  } catch (e) {
    // non-JSON response
  }

  if (!res.ok || data.ResponseCode !== '0') {
    throw new Error(
      data.errorMessage ||
        data.errorCode ||
        data.ResponseDescription ||
        raw ||
        `B2B payment failed (${res.status})`
    );
  }

  return {
    originatorConversationId: data.OriginatorConversationID,
    conversationId: data.ConversationID,
    responseCode: data.ResponseCode,
    responseDescription: data.ResponseDescription,
  };
}

/**
 * Register C2B confirmation/validation URLs
 */
async function registerC2BUrls() {
  requireEnv('MPESA_C2B_SHORTCODE', MPESA_C2B_SHORTCODE);
  requireEnv('MPESA_C2B_RESPONSE_TYPE', MPESA_C2B_RESPONSE_TYPE);
  requireEnv('MPESA_C2B_CONFIRMATION_URL', MPESA_C2B_CONFIRMATION_URL);

  const accessToken = await getAccessToken();

  const body = {
    ShortCode: MPESA_C2B_SHORTCODE,
    ResponseType: MPESA_C2B_RESPONSE_TYPE, // "Completed" or "Cancelled"
    ConfirmationURL: MPESA_C2B_CONFIRMATION_URL,
    ...(MPESA_C2B_VALIDATION_URL ? { ValidationURL: MPESA_C2B_VALIDATION_URL } : {}),
  };

  const url = `${BASE_URL}/mpesa/c2b/v2/registerurl`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify(body),
  });

  const raw = await res.text();
  let data = {};
  try {
    data = JSON.parse(raw);
  } catch (_) {}

  if (!res.ok || data.ResponseCode !== '0') {
    throw new Error(
      data.errorMessage ||
        data.errorCode ||
        data.ResponseDescription ||
        raw ||
        `C2B register URL failed (${res.status})`
    );
  }

  return {
    originatorConversationId: data.OriginatorCoversationID || data.OriginatorConversationID,
    responseCode: data.ResponseCode,
    responseDescription: data.ResponseDescription,
  };
}

/**
 * Simulate a C2B transaction (sandbox only)
 */
async function simulateC2B({
  amount,
  msisdn,
  billRefNumber,
  commandId = 'CustomerPayBillOnline',
}) {
  requireEnv('MPESA_C2B_SHORTCODE', MPESA_C2B_SHORTCODE);

  const accessToken = await getAccessToken();

  const body = {
    ShortCode: Number(MPESA_C2B_SHORTCODE),
    CommandID: commandId, // CustomerPayBillOnline or CustomerBuyGoodsOnline
    Amount: Math.round(Number(amount)),
    Msisdn: msisdn,
    BillRefNumber: billRefNumber || '',
  };

  const url = `${BASE_URL}/mpesa/c2b/v2/simulate`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify(body),
  });

  const raw = await res.text();
  let data = {};
  try {
    data = JSON.parse(raw);
  } catch (_) {}

  if (!res.ok || data.ResponseCode !== '0') {
    throw new Error(
      data.errorMessage ||
        data.errorCode ||
        data.ResponseDescription ||
        raw ||
        `C2B simulate failed (${res.status})`
    );
  }

  return {
    originatorConversationId: data.OriginatorCoversationID || data.OriginatorConversationID,
    responseCode: data.ResponseCode,
    responseDescription: data.ResponseDescription,
  };
}

module.exports = {
  initiateStkPush,
  queryStkStatus,
  initiateB2BPayment,
  registerC2BUrls,
  simulateC2B,
};

