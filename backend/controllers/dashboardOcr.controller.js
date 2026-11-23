const { recognize } = require('tesseract.js');
const axios = require('axios');

function metricValue(text, label) {
  const match = text.match(new RegExp(`${label}[\\s\\S]{0,80}?([0-9][0-9,]*(?:\\.[0-9]+)?%?)`, 'i'));
  return match ? match[1] : undefined;
}

function extractMetrics(text) {
  const metrics = {};
  // The Google Business Profile dashboard has its card values above their
  // labels, so a generic "label then number" match pairs values incorrectly.
  // Prefer the explicit Key Takeaways and the ordered card sequence.
  const takeaways = {
    total_impressions: /total\s+impressions[^\n]*\(([\d,]+)\)/i,
    calls: /total\s+calls[^\n]*\(([\d,]+)\)/i,
    estimated_leads: /estimated\s+leads[^\n]*\(([\d,]+)\)/i,
    top_search_keyword: /top\s+keyword:\s*[“"]?([^”"\n]+)[”"]?\s+with/i,
    searches: /top\s+keyword:[\s\S]*?with\s+([d,]+)\s+searches/i,
    posts_published: /(?:published\s+)(\d+)\s+new\s+posts/i,
    photos_added: /(?:added\s+new\s+photos\s*\()(\d+)/i,
    review_replies: /review\s+response\s+rate:\s*([\d.]+%)/i,
  };
  for (const [key, pattern] of Object.entries(takeaways)) {
    const match = text.match(pattern);
    if (match?.[1]) metrics[key] = match[1].trim();
  }
  const keywordSearches = text.match(/top\s+keyword:[\s\S]{0,160}?with\s+([\d,]+)\s+searches/i);
  if (keywordSearches?.[1]) metrics.searches = keywordSearches[1];
  const cardSequence = text.match(/Total\s+Impressions\s*([\d,]+)\s*↑?\s*\+?[\d.]+%\s*([\d,]+)\s*↑?\s*\+?[\d.]+%\s*Total\s+Calls\s*Website\s+Clicks\s*([\d,]+)\s*Estimated\s+Leads/i);
  if (cardSequence) {
    metrics.calls = cardSequence[1];
    metrics.website_clicks = cardSequence[2];
    metrics.estimated_leads = cardSequence[3];
  }
  const labels = {
    total_impressions: 'total\\s+impressions?',
    search_impressions: 'search\\s+impressions?',
    maps_impressions: 'maps?\\s+impressions?',
    calls: 'total\\s+calls?|calls?',
    website_clicks: 'website\\s+clicks?',
    estimated_leads: 'estimated\\s+leads?',
    searches: 'searches?',
    bookings: 'bookings?',
    posts_published: 'posts?\\s+published?',
    photos_added: 'photos?\\s+added?',
    review_replies: 'review\\s+repl(?:y|ies)',
  };
  for (const [key, label] of Object.entries(labels)) {
    const value = metricValue(text, label);
    if (value && metrics[key] === undefined) metrics[key] = value;
  }
  const explicitTotals = {
    total_impressions: /total\s+impressions\s+increased\s+by\s+[\d.]+%\s*\(([\d,]+)\)/i,
    calls: /total\s+calls\s+are\s+up\s+by\s+[\d.]+%\s*\(([\d,]+)\)/i,
    estimated_leads: /estimated\s+leads\s+grew\s+by\s+[\d.]+%\s*\(([\d,]+)\)/i,
  };
  for (const [key, pattern] of Object.entries(explicitTotals)) {
    const match = text.match(pattern);
    if (match?.[1]) metrics[key] = match[1];
  }
  return metrics;
}

function extractProviderMetrics(text, provider) {
  const key = String(provider || '').toUpperCase();
  const valueAfter = (label) => text.match(new RegExp(`${label}\\s*\\n?\\s*(?:[₹$€£]\\s*)?(\\d[\\d,.]*%?K?)`, 'i'))?.[1];
  if (key === 'GOOGLE ANALYTICS DASHBOARD' || key === 'GOOGLE ANALYTICS') {
    return {
      active_users: valueAfter('Active users'),
      new_users: valueAfter('New users'),
      sessions: valueAfter('Sessions'),
      engaged_sessions: valueAfter('Engaged sessions'),
      engagement_rate: valueAfter('Engagement rate'),
      conversions: valueAfter('Conversions'),
      event_count: valueAfter('Event count'),
      total_revenue: valueAfter('Total revenue'),
    };
  }
  if (key === 'GOOGLE SEARCH CONSOLE DASHBOARD' || key === 'GOOGLE SEARCH CONSOLE') {
    return {
      clicks: valueAfter('Total clicks'),
      impressions: valueAfter('Total impressions'),
      average_ctr: valueAfter('Average CTR'),
      average_position: valueAfter('Average position'),
    };
  }
  if (key === 'GOOGLE ADS DASHBOARD') {
    return {
      clicks: valueAfter('Clicks'),
      conversions_leads: valueAfter('Page view website'),
      avg_cpc: valueAfter('Avg\\.? CPC'),
      spend: valueAfter('Cost'),
    };
  }
  if (key === 'INSTAGRAM DASHBOARD') {
    return {
      views: valueAfter('Views'),
      interactions: text.match(/Last\s+90\s+days\s*\n(\d+)\s*\nBy\s+content\s+interactions/i)?.[1] ?? valueAfter('Interactions'),
      accounts_engaged: valueAfter('Accounts engaged'),
      // "Followers" must not match inside "Non-followers".
      followers_percentage: text.match(/(?<!Non-)Followers\s*\n?\s*([\d.]+%)/i)?.[1],
      non_followers_percentage: text.match(/Non-followers\s*\n?\s*([\d.]+%)/i)?.[1],
    };
  }
  if (key === 'FACEBOOK DASHBOARD') {
    return {
      impressions_reach_views: text.match(/Views[\s\S]{0,40}?([\d,]+)\s*\+\s*[\d.]+%/i)?.[1],
      three_second_views: text.match(/([\d,]+)\s*\+\s*[\d.]+%\s*\n?3-second views/i)?.[1],
      one_minute_views: text.match(/([\d,]+)\s*[+-]\s*[\d.]+%\s*\n?1-minute views/i)?.[1],
      watch_time: text.match(/([\d]+h\s*[\d]+m)\s*\+\s*[\d.]+%\s*\n?Watch time/i)?.[1],
    };
  }
  return {};
}

// The client report uses template-specific field IDs. Cloud Vision returns
// semantic names, so normalize them here before the app prefills Preview/Edit.
function mapToPreviewFields(metrics, provider) {
  const key = String(provider || '').toUpperCase().replaceAll('_', ' ');
  const result = { ...metrics };
  if (key === 'GOOGLE BUSINESS PROFILE DASHBOARD' || key === 'GOOGLE BUSINESS PROFILE') {
    if (result.total_impressions && !result.search_impressions) result.search_impressions = result.total_impressions;
    if (result.estimated_leads && !result.est_conversion_leads) result.est_conversion_leads = result.estimated_leads;
    if (result.total_impressions && !result.views) result.views = result.total_impressions;
    if (result.search_impressions && !result.search_views) result.search_views = result.search_impressions;
    if (result.maps_impressions && !result.maps_views) result.maps_views = result.maps_impressions;
    if (result.top_search_keyword) result.top_search_keyword_1 = result.top_search_keyword;
    if (result.searches) result.searches_1 = result.searches;
  }
  if (key === 'GOOGLE ADS DASHBOARD' || key === 'GOOGLE ADS') {
    if (result.avg_cpc && !result.average_cpc) result.average_cpc = result.avg_cpc;
    if (result.conversions_leads && !result.conversions) result.conversions = result.conversions_leads;
  }
  return result;
}

function detectProvider(text, logos = []) {
  const corpus = `${text || ''} ${logos.join(' ')}`.toLowerCase();
  const logoNames = (logos || []).map((l) => String(l || '').toLowerCase().trim());
  const hasLogo = (name) => logoNames.some((ln) => ln === name || ln.includes(name));

  // A brand logo in the screenshot is the strongest signal. Unambiguous brands
  // map straight to a provider; ambiguous ones (Google, Meta) are disambiguated
  // by the surrounding text.
  if (logoNames.length) {
    if (hasLogo('instagram')) return { name: 'Instagram', confidence: 0.97 };
    if (hasLogo('youtube')) return { name: 'YouTube', confidence: 0.97 };
    if (hasLogo('linkedin')) {
      return corpus.includes('campaign manager') || corpus.includes('linkedin ads')
        ? { name: 'LinkedIn Ads', confidence: 0.95 }
        : { name: 'LinkedIn', confidence: 0.95 };
    }
    if (hasLogo('twitter') || hasLogo('x corp')) return { name: 'Twitter/X', confidence: 0.95 };
    if (hasLogo('meta') || hasLogo('facebook')) {
      return corpus.includes('ads manager') || corpus.includes('ad set') || corpus.includes('campaigns')
        ? { name: 'Meta Ads', confidence: 0.95 }
        : { name: 'Facebook', confidence: 0.95 };
    }
    if (hasLogo('google')) {
      if (corpus.includes('google ads') || corpus.includes('ad groups')) return { name: 'Google Ads', confidence: 0.95 };
      if (corpus.includes('analytics') || corpus.includes('ga4')) return { name: 'Google Analytics', confidence: 0.95 };
      if (corpus.includes('search console') || corpus.includes('search performance')) return { name: 'Google Search Console', confidence: 0.95 };
      if (corpus.includes('business profile') || corpus.includes('my business') || corpus.includes('maps')) return { name: 'Google Business Profile', confidence: 0.95 };
    }
  }

  const rules = [
    ['Google Business Profile', ['google business profile', 'google my business', 'google maps', 'gbp insights']],
    ['Google Ads', ['google ads', 'google adwords', 'ads.google.com', 'ad groups']],
    ['Google Analytics', ['google analytics', 'google analytics 4', 'ga4']],
    ['Google Search Console', ['search console', 'google search performance']],
    ['Meta Ads', ['meta ads', 'ads manager', 'campaign ad set', 'facebook ads manager']],
    ['Instagram', ['instagram insights', 'instagram.com', 'instagram']],
    ['Facebook', ['facebook insights', 'facebook page', 'facebook']],
    ['YouTube', ['youtube studio', 'youtube analytics', 'youtube']],
    ['LinkedIn Ads', ['linkedin campaign manager', 'linkedin ads']],
    ['LinkedIn', ['linkedin page analytics', 'linkedin']],
    ['Twitter/X', ['twitter analytics', 'x analytics', 'twitter', 'x.com']],
  ];

  for (const [provider, terms] of rules) {
    if (terms.some((term) => corpus.includes(term))) {
      return { name: provider, confidence: 0.9 };
    }
  }
  return { name: null, confidence: 0 };
}

async function analyzeDashboardImages(images, providerOverride) {
  const safeImages = Array.isArray(images)
    ? images.slice(0, 12).filter((image) =>
        typeof image?.base64 === 'string' && image.base64.length > 20)
    : [];
  if (!safeImages.length) {
    const error = new Error('Add a valid dashboard image first.');
    error.status = 400;
    throw error;
  }
  // Only use a dedicated Cloud Vision key. A Google Maps key is NOT authorized
  // for the Vision API and makes Vision reply "Permission denied on the
  // service", so it must never be used here. When Vision is unavailable or the
  // call fails (no key, disabled API, billing/permission error, network), we
  // fall back to the bundled Tesseract engine (eng.traineddata) so OCR keeps
  // working — the user can still correct values in Preview/Edit.
  // Accept any of the dedicated Vision key names used in .env. A Google Maps /
  // Geocoding key must NEVER be used here — it is not authorized for the Vision
  // API and makes Vision reply "Permission denied on the service".
  const visionKey = process.env.GOOGLE_CLOUD_VISION_API_KEY
    || process.env.GOOGLE_VISION_API_KEY
    || process.env.OCR_API_KEY;
  const visionUrl = process.env.OCR_API_URL || 'https://vision.googleapis.com/v1/images:annotate';
  const visionTimeout = Number(process.env.OCR_TIMEOUT_MS) > 0
    ? Number(process.env.OCR_TIMEOUT_MS)
    : 60000;
  const texts = [];
  const logos = [];

  let usedVision = false;
  if (visionKey) {
    try {
      const response = await axios.post(
        `${visionUrl}?key=${encodeURIComponent(visionKey)}`,
        { requests: safeImages.map((image) => ({ image: { content: image.base64 }, features: [{ type: 'TEXT_DETECTION', maxResults: 50 }, { type: 'LOGO_DETECTION', maxResults: 10 }] })) },
        { timeout: visionTimeout }
      );
      for (const item of response.data?.responses || []) {
        const text = item.fullTextAnnotation?.text || item.textAnnotations?.[0]?.description;
        if (text) texts.push(text);
        logos.push(...(item.logoAnnotations || []).map((logo) => logo.description).filter(Boolean));
      }
      usedVision = true;
    } catch (visionError) {
      const detail = visionError?.response?.data?.error?.message || visionError?.message || 'unknown error';
      console.error('Dashboard OCR: Cloud Vision failed, falling back to Tesseract:', detail);
      texts.length = 0;
      logos.length = 0;
    }
  }

  if (!usedVision) {
    for (const image of safeImages) {
      try {
        const result = await recognize(Buffer.from(image.base64, 'base64'), 'eng', {}, { tessedit_pageseg_mode: '11', preserve_interword_spaces: '1' });
        if (result?.data?.text) texts.push(result.data.text);
      } catch (tessError) {
        console.error('Dashboard OCR: Tesseract failed for one image:', tessError?.message || tessError);
      }
    }
  }

  const text = texts.join('\n').trim();
  if (!text) {
    const error = new Error('No readable text was found in this dashboard image.');
    error.status = 422;
    throw error;
  }
  const detected = detectProvider(text, logos);
  const provider = String(providerOverride || detected.name || '');
  const rawMetrics = Object.fromEntries(Object.entries({
    ...extractMetrics(text),
    ...extractProviderMetrics(text, provider),
  }).filter(([, value]) =>
    value !== undefined && value !== null && String(value).trim()));
  return {
    metrics: mapToPreviewFields(rawMetrics, provider),
    raw_text: text.slice(0, 8000),
    detected_provider: detected.name,
    provider_confidence: detected.confidence,
  };
}

async function readDashboardOcr(req, res) {
  try {
    const result = await analyzeDashboardImages(
      req.body?.images,
      req.body?.provider,
    );
    return res.json({ success: true, ...result });
  } catch (error) {
    const detail = error?.response?.data?.error?.message || error?.message || 'Unknown OCR error';
    console.error('Dashboard OCR error:', detail);
    const status = error.status || 502;
    return res.status(status).json({ success: false, message: `Dashboard OCR could not read this image: ${detail}` });
  }
}

module.exports = { analyzeDashboardImages, detectProvider, readDashboardOcr };
