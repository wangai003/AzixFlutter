const THIRDWEB_API_BASE = 'https://bridge.thirdweb.com/v1';
const NATIVE_TOKEN_ADDRESS = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';

function normalizeStatus(status) {
  const normalized = (status || '').toString().toUpperCase();
  if (normalized === 'COMPLETED' || normalized === 'SUCCESS') {
    return 'SUCCESS';
  }
  if (normalized === 'FAILED') {
    return 'FAILED';
  }
  return 'PENDING';
}

async function prepareOnramp(req, res) {
  try {
    const { walletAddress, amount, chainId, tokenAddress, onramp } = req.body || {};

    if (!walletAddress || typeof walletAddress !== 'string') {
      return res.status(400).json({ success: false, error: 'walletAddress is required' });
    }
    if (!amount) {
      return res.status(400).json({ success: false, error: 'amount is required' });
    }
    if (!chainId) {
      return res.status(400).json({ success: false, error: 'chainId is required' });
    }

    if (!process.env.THIRDWEB_SECRET_KEY) {
      return res.status(500).json({
        success: false,
        error: 'THIRDWEB_SECRET_KEY is not configured on the backend',
      });
    }

    const response = await fetch(`${THIRDWEB_API_BASE}/onramp/prepare`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-secret-key': process.env.THIRDWEB_SECRET_KEY,
      },
      body: JSON.stringify({
        onramp: onramp || 'transak',
        chainId: Number(chainId),
        tokenAddress: tokenAddress || NATIVE_TOKEN_ADDRESS,
        amount: amount.toString(),
        receiver: walletAddress,
        currency: 'USD',
      }),
    });

    const data = await response.json();
    if (!response.ok) {
      return res.status(400).json({
        success: false,
        error: data,
      });
    }

    return res.json({
      success: true,
      link: data?.data?.link,
      quoteId: data?.data?.quoteId,
    });
  } catch (error) {
    console.error('❌ [THIRDWEB ONRAMP] prepareOnramp failed:', error);
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
}

async function getOnrampStatus(req, res) {
  try {
    const quoteId = req.params.quoteId;
    if (!quoteId) {
      return res.status(400).json({ success: false, error: 'quoteId is required' });
    }

    if (!process.env.THIRDWEB_SECRET_KEY) {
      return res.status(500).json({
        success: false,
        error: 'THIRDWEB_SECRET_KEY is not configured on the backend',
      });
    }

    const response = await fetch(
      `${THIRDWEB_API_BASE}/onramp/status?id=${encodeURIComponent(quoteId)}`,
      {
        headers: {
          'x-secret-key': process.env.THIRDWEB_SECRET_KEY,
        },
      }
    );

    const data = await response.json();
    if (!response.ok) {
      return res.status(400).json({
        success: false,
        error: data,
      });
    }

    const rawStatus = data?.data?.status;
    return res.json({
      success: true,
      status: normalizeStatus(rawStatus),
      rawStatus: rawStatus || null,
      txHash: data?.data?.txHash || null,
    });
  } catch (error) {
    console.error('❌ [THIRDWEB ONRAMP] getOnrampStatus failed:', error);
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
}

module.exports = {
  prepareOnramp,
  getOnrampStatus,
};

