const mpesaService = require('../services/mpesaService');

function validateAmount(amount) {
  const n = Number(amount);
  if (!Number.isFinite(n) || n <= 0) {
    throw new Error('Invalid amount');
  }
  return n;
}

exports.healthCheck = async (req, res) => {
  res.json({
    success: true,
    message: 'M-Pesa service is up',
    env: process.env.MPESA_ENV || 'sandbox',
  });
};

exports.stkPush = async (req, res) => {
  try {
    const { phoneNumber, amountKES, accountReference, description } = req.body;

    if (!phoneNumber) {
      return res.status(400).json({ success: false, error: 'phoneNumber required' });
    }

    const amount = validateAmount(amountKES);
    const reference =
      accountReference ||
      `AKOFA_${Date.now()}`;

    const result = await mpesaService.initiateStkPush({
      phoneNumber,
      amountKES: amount,
      accountReference: reference,
      description,
    });

    res.json({
      success: true,
      checkoutRequestId: result.checkoutRequestId,
      responseCode: result.responseCode,
      customerMessage: result.customerMessage,
      merchantRequestId: result.merchantRequestId,
    });
  } catch (err) {
    console.error('STK Push error:', err);
    res.status(500).json({
      success: false,
      error: err.message || 'Failed to initiate STK push',
    });
  }
};

exports.queryStatus = async (req, res) => {
  try {
    const { checkoutRequestId } = req.body;
    if (!checkoutRequestId) {
      return res.status(400).json({ success: false, error: 'checkoutRequestId required' });
    }

    const result = await mpesaService.queryStkStatus(checkoutRequestId);

    res.json({
      success: true,
      resultCode: result.resultCode,
      resultDesc: result.resultDesc,
      raw: result.response,
    });
  } catch (err) {
    console.error('Query error:', err);
    res.status(500).json({
      success: false,
      error: err.message || 'Failed to query STK status',
    });
  }
};

exports.b2bPayment = async (req, res) => {
  try {
    const {
      amount,
      partyB,
      accountReference,
      remarks,
      requester,
      commandId,
      senderIdentifierType,
      receiverIdentifierType,
    } = req.body;

    if (!partyB) {
      return res.status(400).json({ success: false, error: 'partyB (recipient shortcode) required' });
    }

    const amt = validateAmount(amount);

    const result = await mpesaService.initiateB2BPayment({
      amount: amt,
      partyB,
      accountReference: accountReference || `B2B_${Date.now()}`,
      remarks,
      requester,
      commandId,
      senderIdentifierType,
      receiverIdentifierType,
    });

    res.json({
      success: true,
      ...result,
    });
  } catch (err) {
    console.error('B2B payment error:', err);
    res.status(500).json({
      success: false,
      error: err.message || 'Failed to initiate B2B payment',
    });
  }
};

exports.registerC2B = async (_req, res) => {
  try {
    const result = await mpesaService.registerC2BUrls();
    res.json({
      success: true,
      ...result,
    });
  } catch (err) {
    console.error('Register C2B error:', err);
    res.status(500).json({
      success: false,
      error: err.message || 'Failed to register C2B URLs',
    });
  }
};

exports.simulateC2B = async (req, res) => {
  try {
    const { amount, msisdn, billRefNumber, commandId } = req.body;

    if (!amount || !msisdn) {
      return res.status(400).json({
        success: false,
        error: 'amount and msisdn are required',
      });
    }

    const result = await mpesaService.simulateC2B({
      amount,
      msisdn,
      billRefNumber,
      commandId,
    });

    res.json({
      success: true,
      ...result,
    });
  } catch (err) {
    console.error('Simulate C2B error:', err);
    res.status(500).json({
      success: false,
      error: err.message || 'Failed to simulate C2B payment',
    });
  }
};

// Safaricom callback handler
exports.callback = async (req, res) => {
  try {
    console.log('M-Pesa Callback:', JSON.stringify(req.body, null, 2));
    // TODO: persist to DB/Firestore if needed
    return res.json({
      ResultCode: 0,
      ResultDesc: 'Accepted',
    });
  } catch (err) {
    console.error('Callback error:', err);
    return res.json({
      ResultCode: 1,
      ResultDesc: 'Callback error',
    });
  }
};

