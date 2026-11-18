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
  const valueAfter = (label) => text.match(new RegExp(`${label}\\s*\\n?\\s*(?:₹\\s*)?(\\d[\\d,.]*K?)`, 'i'))?.[1];
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
      followers_percentage: text.match(/Followers\\s*\\n?([\\d.]+%)/i)?.[1],
      non_followers_percentage: text.match(/Non-followers\\s*\\n?([\\d.]+%)/i)?.[1],
    };
  }
  if (key === 'FACEBOOK DASHBOARD') {
    return {
      impressions_reach_views: text.match(/Views[\\s\\S]{0,40}?([\\d,]+)\\s*\\+\\s*[\\d.]+%/i)?.[1],
      three_second_views: text.match(/([\\d,]+)\\s*\\+\\s*[\\d.]+%\\s*\\n?3-second views/i)?.[1],
      one_minute_views: text.match(/([\\d,]+)\\s*[+-]\\s*[\\d.]+%\\s*\\n?1-minute views/i)?.[1],
      watch_time: text.match(/([\\d]+h\\s*[\\d]+m)\\s*\\+\\s*[\\d.]+%\\s*\\n?Watch time/i)?.[1],
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

async function readDashboardOcr(req, res) {
  try {
    const images = Array.isArray(req.body?.images) ? req.body.images.slice(0, 12) : [];
    if (!images.length) return res.status(400).json({ success: false, message: 'Add a dashboard image first.' });
    const safeImages = images.filter((image) => typeof image?.base64 === 'string' && image.base64.length > 20);
    const visionKey = process.env.GOOGLE_CLOUD_VISION_API_KEY || process.env.GOOGLE_MAPS_API_KEY;
    const texts = [];
    if (visionKey) {
      const response = await axios.post(
        `https://vision.googleapis.com/v1/images:annotate?key=${encodeURIComponent(visionKey)}`,
        { requests: safeImages.map((image) => ({ image: { content: image.base64 }, features: [{ type: 'TEXT_DETECTION', maxResults: 50 }] })) },
        { timeout: 60000 }
      );
      for (const item of response.data?.responses || []) {
        const text = item.fullTextAnnotation?.text || item.textAnnotations?.[0]?.description;
        if (text) texts.push(text);
      }
    } else {
      for (const image of safeImages) {
        const result = await recognize(Buffer.from(image.base64, 'base64'), 'eng', {}, { tessedit_pageseg_mode: '11', preserve_interword_spaces: '1' });
        if (result?.data?.text) texts.push(result.data.text);
      }
    }
    const text = texts.join('\n').trim();
    if (!text) return res.status(422).json({ success: false, message: 'No readable text was found in this dashboard image.' });
    const provider = String(req.body?.provider || '');
    const rawMetrics = Object.fromEntries(Object.entries({ ...extractMetrics(text), ...extractProviderMetrics(text, provider) }).filter(([, value]) => value !== undefined && value !== null && String(value).trim()));
    const metrics = mapToPreviewFields(rawMetrics, provider);
    return res.json({ success: true, metrics, raw_text: text.slice(0, 8000) });
  } catch (error) {
    const detail = error?.response?.data?.error?.message || error?.message || 'Unknown OCR error';
    console.error('Dashboard OCR error:', detail);
    return res.status(502).json({ success: false, message: `Dashboard OCR could not read this image: ${detail}` });
  }
}

module.exports = { readDashboardOcr };
