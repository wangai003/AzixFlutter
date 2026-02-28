const THIRDWEB_API_BASE = 'https://bridge.thirdweb.com/v1';
const NATIVE_TOKEN_ADDRESS = '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
const POLYGON_USDC_TOKEN_ADDRESS = '0x3c499c542cef5e3811e1192ce70d8cc03d5c3359';
const ETHEREUM_USDC_TOKEN_ADDRESS = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48';
const USDC_DECIMALS = 6n;
const USDC_MIN_USD = 1n;
const USDC_MAX_USD = 30000n;
const USDC_MIN_UNITS = USDC_MIN_USD * (10n ** USDC_DECIMALS); // 1 USDC => 1,000,000
const USDC_MAX_UNITS = USDC_MAX_USD * (10n ** USDC_DECIMALS); // 30,000 USDC => 30,000,000,000

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

function pickFirstString(candidates) {
  for (const value of candidates) {
    if (typeof value === 'string' && value.trim().length > 0) {
      return value.trim();
    }
  }
  return null;
}

function getDefaultTokenAddress(chainId) {
  if (chainId === 137) return POLYGON_USDC_TOKEN_ADDRESS;
  if (chainId === 1) return ETHEREUM_USDC_TOKEN_ADDRESS;
  return NATIVE_TOKEN_ADDRESS;
}

function isUsdcTokenAddress(tokenAddress) {
  const normalized = (tokenAddress || '').toLowerCase();
  return (
    normalized === POLYGON_USDC_TOKEN_ADDRESS ||
    normalized === ETHEREUM_USDC_TOKEN_ADDRESS
  );
}

function normalizeOnrampAmount(amount, tokenAddress) {
  const amountString = (amount ?? '').toString().trim();
  if (!/^\d+$/.test(amountString)) return null;

  const parsed = BigInt(amountString);
  if (parsed <= 0n) return null;

  // For USDC, treat amount as token base units and enforce [$1, $30,000] bounds.
  if (isUsdcTokenAddress(tokenAddress)) {
    if (parsed < USDC_MIN_UNITS) return USDC_MIN_UNITS.toString();
    if (parsed > USDC_MAX_UNITS) return USDC_MAX_UNITS.toString();
    return parsed.toString();
  }

  return parsed.toString();
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

    const requestedChainId = Number(chainId);
    // Thirdweb onramp providers generally support mainnet chains for fiat onramp.
    // If the app is in Amoy testnet mode, transparently map to Polygon mainnet.
    const effectiveChainId = requestedChainId === 80002 ? 137 : requestedChainId;
    const effectiveTokenAddress = (
      tokenAddress || getDefaultTokenAddress(effectiveChainId)
    ).toLowerCase();
    const normalizedAmount = normalizeOnrampAmount(amount, effectiveTokenAddress);

    if (!normalizedAmount) {
      return res.status(400).json({
        success: false,
        error: 'amount must be a positive integer string (token base units)',
      });
    }

    const response = await fetch(`${THIRDWEB_API_BASE}/onramp/prepare`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-secret-key': process.env.THIRDWEB_SECRET_KEY,
      },
      body: JSON.stringify({
        onramp: onramp || 'coinbase',
        chainId: effectiveChainId,
        tokenAddress: effectiveTokenAddress,
        amount: normalizedAmount,
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

    const link = pickFirstString([
      data?.data?.link,
      data?.link,
      data?.result?.link,
      data?.result?.checkoutLink,
      data?.checkoutLink,
      data?.url,
    ]);

    const quoteId = pickFirstString([
      data?.data?.quoteId,
      data?.data?.id,
      data?.quoteId,
      data?.id,
      data?.result?.quoteId,
      data?.result?.id,
    ]);

    if (!link || !quoteId) {
      console.error('❌ [THIRDWEB ONRAMP] Missing link/quoteId in prepare response:', {
        hasLink: Boolean(link),
        hasQuoteId: Boolean(quoteId),
        topLevelKeys: Object.keys(data || {}),
      });
      return res.status(502).json({
        success: false,
        error: 'Thirdweb prepare response missing checkout link or quote id',
        details: process.env.NODE_ENV === 'development' ? data : undefined,
      });
    }

    return res.json({
      success: true,
      link,
      quoteId,
      id: quoteId, // compatibility for clients that expect "id"
      chainId: effectiveChainId,
      amountUSD: normalizedAmount,
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

