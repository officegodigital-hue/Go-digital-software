// services/reportHtml.service.js
// Builds the full branded "Client Monthly Report" deck as a single HTML string.
// Each .slide is a 1280x720 (16:9) page that Puppeteer renders to one PDF page /
// one PPTX slide image. The design mirrors the Go Digital template deck.

const fs = require('fs');
const path = require('path');

// ---- Brand logo (embedded as data URI so Puppeteer needs no network) ----
let LOGO_DATA_URI = '';
try {
  const logoPath = path.join(__dirname, '..', 'assets', 'godigital_logo.png');
  LOGO_DATA_URI = 'data:image/png;base64,' + fs.readFileSync(logoPath).toString('base64');
} catch (_) {
  LOGO_DATA_URI = '';
}

// The report shows the opened client's own company logo (set per report in
// buildReportHtml); it falls back to the Go Digital brand logo when the client
// has none. buildReportHtml runs synchronously, so this module-level value is
// never shared across concurrent reports.
let REPORT_LOGO_URI = '';
function clientLogoUri(payload) {
  const logo = payload && payload.companyLogo;
  const bytes = logo && logo.bytesBase64;
  if (typeof bytes === 'string' && bytes.length > 20) {
    const mime = (logo.mimeType || 'image/png');
    const raw = bytes.includes(',') ? bytes.split(',').pop() : bytes;
    return `data:${mime};base64,${raw}`;
  }
  return LOGO_DATA_URI;
}
function reportLogo() {
  return REPORT_LOGO_URI || LOGO_DATA_URI;
}

// ---- Small helpers --------------------------------------------------------
function esc(value) {
  return String(value == null ? '' : value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// First present, non-empty value among candidate keys; else the dash placeholder.
function mv(metrics, keys, fallback = '—') {
  for (const k of keys) {
    const val = metrics && metrics[k];
    if (val !== undefined && val !== null && String(val).trim() !== '') return esc(val);
  }
  return fallback;
}

// Normalise provider name to a lookup key.
function pk(provider) {
  return String(provider || '').toUpperCase().replace(/[^A-Z0-9]+/g, '_').replace(/^_+|_+$/g, '');
}

// Build provider -> merged metrics map from snapshots (later snapshots win).
function metricsByProvider(payload, field = 'snapshots') {
  const out = {};
  const snapshots = Array.isArray(payload[field]) ? payload[field] : [];
  for (const snap of snapshots) {
    const key = pk(snap && snap.provider);
    if (!key) continue;
    const metrics = (snap && typeof snap.metrics === 'object' && snap.metrics) || {};
    out[key] = Object.assign({}, out[key], metrics);
  }
  return out;
}

// Parse a human metric value ("1,24,680", "₹3,256", "96%") to a number.
function toNumber(raw) {
  if (raw == null) return null;
  const cleaned = String(raw).replace(/[^0-9.-]/g, '');
  if (cleaned === '' || cleaned === '-' || cleaned === '.') return null;
  const n = Number(cleaned);
  return Number.isFinite(n) ? n : null;
}

// vs-last-month change, as a signed string for the card's "vs last month: _ %".
//   ((this - last) / last) × 100   → e.g. 800 vs 1000 = "-20".
// Returns '____' when either value is missing or last month is zero.
function pctChange(thisRaw, lastRaw) {
  const a = toNumber(thisRaw);
  const b = toNumber(lastRaw);
  if (a == null || b == null || b === 0) return '____';
  const pct = ((a - b) / b) * 100;
  const rounded = Math.round(pct * 10) / 10;
  return (rounded > 0 ? '+' : '') + rounded;
}

// The frontend sends screenshots as a list of
//   { provider, bytesBase64, mimeType, slot? }
// where `provider` is the normalised provider name (e.g. GOOGLE_ADS) and `slot`
// is only set for CREATIVE_SHOWCASE items (poster/video tiles).
function shotDataUri(s) {
  if (!s || !s.bytesBase64) return null;
  return `data:${s.mimeType || 'image/png'};base64,${s.bytesBase64}`;
}

// Data URIs for a provider, matched by normalised key.
function shotsFor(payload, keys) {
  const list = Array.isArray(payload.screenshots) ? payload.screenshots : [];
  const want = new Set(keys.map((k) => pk(k)));
  const out = [];
  for (const s of list) {
    if (s && want.has(pk(s.provider))) {
      const uri = shotDataUri(s);
      if (uri) out.push(uri);
    }
  }
  return out;
}

// Map of showcase slot -> data URI (posters/videos on the Creative Showcase page).
function showcaseShots(payload) {
  const list = Array.isArray(payload.screenshots) ? payload.screenshots : [];
  const map = {};
  for (const s of list) {
    if (s && pk(s.provider) === 'CREATIVE_SHOWCASE' && s.slot) {
      const uri = shotDataUri(s);
      if (uri) map[String(s.slot)] = uri;
    }
  }
  return map;
}

// First non-empty value from any of the payload "edit" bags, by exact label.
function editVal(bag, label) {
  if (!bag || typeof bag !== 'object') return '';
  const v = bag[label];
  return v == null ? '' : String(v);
}

// ---- Reusable page chrome -------------------------------------------------
function slideHeader(opts) {
  const { icon, iconBg, title, subtitle } = opts;
  const logo = reportLogo() ? `<img class="brand-logo" src="${reportLogo()}" alt="Client logo"/>` : `<div class="brand-wordmark">GO DIGITAL</div>`;
  return `
    <div class="s-head">
      <div class="s-head-left">
        <div class="s-icon" style="background:${iconBg}">${icon || ''}</div>
        <div class="s-titles">
          <div class="s-title">${esc(title)}</div>
          ${subtitle ? `<div class="s-sub">${subtitle}</div>` : ''}
        </div>
      </div>
      ${logo}
    </div>`;
}

function slideFooter(payload, section) {
  const client = esc(payload.clientName || '[Client]');
  const month = esc(payload.periodLabel || payload.reportMonth || '[Month YYYY]');
  return `
    <div class="s-foot">
      <div class="s-foot-left">Go Digital &nbsp;&middot;&nbsp; ${client} &nbsp;&middot;&nbsp; ${month}</div>
      <div class="s-foot-right">${section ? esc(section) : ''}</div>
    </div>`;
}

// A grid of metric cards. cards = [{label, value, sub, pct, bg, fg}]
function cardGrid(cards, perRow = 4) {
  const items = cards.map((c) => `
    <div class="mcard" style="background:${c.bg};color:${c.fg || '#fff'}">
      <div class="mcard-label">${esc(c.label)}</div>
      <div class="mcard-value">${c.value}</div>
      <div class="mcard-foot">
        <div class="mcard-sub">${esc(c.sub || '')}</div>
        <div class="mcard-pct"><b>vs last month:</b> ${c.pct || '____'} %</div>
      </div>
      <div class="mcard-bubble"></div>
      <div class="mcard-bubble2"></div>
    </div>`).join('');
  return `<div class="mcard-grid cols-${perRow}">${items}</div>`;
}

// A simple header-row table with N empty (or filled) body rows.
function dataTable(headers, rows, emptyRows, headBg = '#2f55d4') {
  const head = headers.map((h, i) => `<th style="background:${headBg};${i === 0 ? 'text-align:left' : ''}">${esc(h)}</th>`).join('');
  const bodyRows = [];
  const filled = Array.isArray(rows) ? rows : [];
  const total = Math.max(emptyRows || 0, filled.length);
  for (let r = 0; r < total; r++) {
    const row = filled[r] || [];
    const tds = headers.map((_, c) => `<td class="${c === 0 ? 'tcell-first' : ''}">${row[c] != null ? esc(row[c]) : ''}</td>`).join('');
    bodyRows.push(`<tr class="${r % 2 ? 'alt' : ''}">${tds}</tr>`);
  }
  return `<table class="dtable"><thead><tr>${head}</tr></thead><tbody>${bodyRows.join('')}</tbody></table>`;
}

// A "paste screenshot here" drop zone that shows a real screenshot when available.
function screenshotZone(shots, caption, accent = '#eaf0ff') {
  if (shots && shots.length) {
    return `<div class="shot-zone filled"><img src="${shots[0]}" alt="dashboard"/></div>`;
  }
  return `
    <div class="shot-zone" style="background:${accent}">
      <div class="shot-plus">+</div>
      <div class="shot-cap">Paste dashboard screenshot here</div>
      <div class="shot-sub">${esc(caption || '')}</div>
    </div>`;
}

function insightsPanel(accent = '#2563eb', text) {
  const lines = (Array.isArray(text) ? text : []).slice(0, 6);
  const body = lines.length
    ? lines.map((l) => `<div class="ins-line filled">${esc(l)}</div>`).join('')
    : Array.from({ length: 6 }).map(() => `<div class="ins-line"></div>`).join('');
  return `
    <div class="ins-panel" style="border-color:${accent}">
      <div class="ins-head"><span class="ins-check" style="background:${accent}">✓</span> Insights &amp; next actions</div>
      ${body}
    </div>`;
}

// ---- Platform metric-card page configs -----------------------------------
// value: list of candidate metric keys; sub: template sublabel.
const PLATFORM_CARDS = {
  GMB: {
    providers: ['GOOGLE_BUSINESS_PROFILE', 'GMB', 'GBP', 'LOCAL_SEO'],
    icon: 'G', iconBg: '#4285F4', title: 'Google Business Profile', subtitle: 'GMB / GBP &middot; [Profile name] &middot; [Location] &middot; [Date range]', section: 'Section 03',
    palette: ['#3f51b5', '#3b63d6', '#6f78c9', '#2f6fe0', '#5a66c4', '#2f7de0', '#3f6fd6', '#5a7ad6', '#3f51b5', '#2f6fe0'],
    cards: [
      { label: 'SEARCH IMPRESSIONS', keys: ['search_impressions', 'search_views', 'total_impressions'], sub: 'Google Search' },
      { label: 'MAPS IMPRESSIONS', keys: ['maps_impressions', 'maps_views'], sub: 'Google Maps' },
      { label: 'CALLS', keys: ['calls'], sub: 'From profile' },
      { label: 'WEBSITE CLICKS', keys: ['website_clicks'], sub: 'To website' },
      { label: 'EST. CONVERSION LEADS', keys: ['est_conversion_leads', 'estimated_leads'], sub: 'Lead conversions' },
      { label: 'BOOKINGS', keys: ['bookings'], sub: 'If enabled' },
      { label: 'POSTS PUBLISHED', keys: ['posts_published'], sub: 'Updates / offers' },
      { label: 'PHOTOS ADDED', keys: ['photos_added'], sub: 'This month' },
      { label: 'NEW REVIEWS', keys: ['new_reviews'], sub: 'Avg rating: ___ ★' },
      { label: 'REVIEW REPLIES', keys: ['review_replies'], sub: 'Responded' },
    ],
  },
  GOOGLE_ADS: {
    providers: ['GOOGLE_ADS'],
    icon: 'A', iconBg: '#fff', iconFg: '#4285F4', title: 'Google Ads', subtitle: '[Account] &middot; [Primary conversion] &middot; [Date range]', section: 'Section 04',
    palette: ['#4285F4', '#EA4335', '#F9AB00', '#34A853', '#F9AB00', '#34A853', '#4285F4', '#F9AB00', '#EA4335'],
    cards: [
      { label: 'ACTIVE CAMPAIGNS', keys: ['active_campaigns'], sub: 'Search / PMax / Display' },
      { label: 'IMPRESSIONS', keys: ['impressions', 'total_impressions'], sub: 'Ad views' },
      { label: 'CLICKS', keys: ['clicks'], sub: 'Ad clicks' },
      { label: 'CTR %', keys: ['ctr'], sub: 'Click-through rate' },
      { label: 'SPEND (₹)', keys: ['spend', 'cost'], sub: 'Total cost' },
      { label: 'CONVERSIONS / LEADS', keys: ['conversions', 'conversions_leads', 'leads'], sub: 'Form + call' },
      { label: 'COST PER LEAD (₹)', keys: ['cost_per_lead', 'cpl'], sub: 'Cost / conversion' },
      { label: 'CALLS', keys: ['calls'], sub: 'Call ads / extensions' },
      { label: 'KEYWORDS OPTIMIZED', keys: ['keywords_optimized'], sub: 'Added / paused / negatives' },
    ],
  },
  GOOGLE_ANALYTICS: {
    providers: ['GOOGLE_ANALYTICS'],
    icon: 'A', iconBg: '#F9AB00', title: 'Google Analytics', subtitle: 'Google Analytics 4 &middot; [Property] &middot; [Date range]', section: 'Section 04A',
    palette: ['#F9AB00', '#E37400', '#4285F4', '#34A853', '#EA4335', '#F9AB00', '#4285F4', '#34A853'],
    cards: [
      { label: 'ACTIVE USERS', keys: ['active_users'], sub: 'Unique users' },
      { label: 'NEW USERS', keys: ['new_users'], sub: 'First-time users' },
      { label: 'SESSIONS', keys: ['sessions'], sub: 'Total sessions' },
      { label: 'ENGAGED SESSIONS', keys: ['engaged_sessions'], sub: 'Meaningful visits' },
      { label: 'ENGAGEMENT RATE', keys: ['engagement_rate'], sub: 'Sessions engaged' },
      { label: 'CONVERSIONS', keys: ['conversions'], sub: 'Key events' },
      { label: 'EVENT COUNT', keys: ['event_count'], sub: 'Tracked events' },
      { label: 'TOTAL REVENUE', keys: ['total_revenue'], sub: 'Property revenue' },
    ],
  },
  GOOGLE_SEARCH_CONSOLE: {
    providers: ['GOOGLE_SEARCH_CONSOLE'],
    icon: 'G', iconBg: '#4285F4', title: 'Google Search Console', subtitle: 'Search performance &middot; [Property] &middot; [Date range]', section: 'Section 04B',
    palette: ['#4285F4', '#34A853', '#EA4335', '#F9AB00'],
    cards: [
      { label: 'TOTAL CLICKS', keys: ['clicks'], sub: 'Search result clicks' },
      { label: 'TOTAL IMPRESSIONS', keys: ['impressions'], sub: 'Search result views' },
      { label: 'AVERAGE CTR', keys: ['average_ctr'], sub: 'Click-through rate' },
      { label: 'AVERAGE POSITION', keys: ['average_position'], sub: 'Search ranking' },
    ],
  },
  YOUTUBE: {
    providers: ['YOUTUBE'],
    icon: '▶', iconBg: '#FF0000', title: 'YouTube', subtitle: '[Channel name / URL] &middot; [Date range]', section: 'Section 09',
    palette: ['#FF0000', '#c62828', '#3a3a3a', '#c62828', '#2b2b2b', '#5a5a5a', '#FF0000', '#2b2b2b', '#5a5a5a', '#c62828'],
    cards: [
      { label: 'SUBSCRIBERS', keys: ['subscribers'], sub: 'Total' },
      { label: 'NEW SUBSCRIBERS', keys: ['new_subscribers'], sub: 'This month' },
      { label: 'IMPRESSIONS', keys: ['impressions'], sub: 'Thumbnail views' },
      { label: 'IMPRESSION CTR %', keys: ['impression_ctr', 'ctr'], sub: 'Click rate' },
      { label: 'WATCH TIME (HRS)', keys: ['watch_time_hours', 'watch_time'], sub: 'Total' },
      { label: 'AVG VIEW DURATION', keys: ['avg_view_duration'], sub: 'Per view' },
      { label: 'VIDEOS PUBLISHED', keys: ['videos_published'], sub: 'Long form' },
      { label: 'SHORTS PUBLISHED', keys: ['shorts_published'], sub: 'Shorts' },
      { label: 'LIKES/ SHARE', keys: ['likes_shares', 'likes'], sub: 'Total' },
      { label: 'TOP VIDEO VIEWS', keys: ['top_video_views'], sub: 'Best performer' },
    ],
  },
  FACEBOOK: {
    providers: ['FACEBOOK'],
    icon: 'f', iconBg: '#1877F2', title: 'Facebook', subtitle: '[Handle / page URL] &middot; [Date range]', section: 'Section 08',
    palette: ['#1877F2', '#1b63d0', '#15315f', '#2b6fe0', '#2f80ed', '#3a8bff', '#15315f'],
    cards: [
      { label: 'PAGE FOLLOWERS', keys: ['page_followers', 'followers'], sub: 'Total' },
      { label: 'NEW FOLLOWERS', keys: ['new_followers'], sub: 'This month' },
      { label: 'IMPRESSIONS / REACH/ VIEWS', keys: ['impressions_reach_views', 'views', 'impressions'], sub: 'Total views' },
      { label: 'ENGAGEMENT', keys: ['engagement'], sub: 'Reactions + comments + shares' },
      { label: 'POSTS PUBLISHED', keys: ['posts_published'], sub: 'Feed posts' },
      { label: 'VIDEOS / REELS', keys: ['videos_reels', 'reels'], sub: 'Published' },
      { label: 'STORIES', keys: ['stories'], sub: 'Stories posted' },
    ],
  },
  META_ADS: {
    providers: ['META_ADS', 'META'],
    icon: '∞', iconBg: '#fff', iconFg: '#1877F2', title: 'Meta Ads', subtitle: 'Facebook &amp; Instagram &middot; [Ad account] &middot; [Objective] &middot; [Date range]', section: 'Section 05',
    palette: ['#2f6fe0', '#3a8bff', '#5a7ad6', '#2f80ed', '#1b1f2a', '#4a66e0', '#2f6fe0', '#1b1f2a', '#2f6fe0', '#3a8bff', '#2f80ed'],
    cards: [
      { label: 'ACTIVE CAMPAIGNS', keys: ['active_campaigns'], sub: 'Leads / Traffic / Awareness' },
      { label: 'REACH / IMPRESSION', keys: ['reach_impressions', 'reach', 'impressions'], sub: 'Unique people' },
      { label: 'FREQUENCY', keys: ['frequency'], sub: 'Avg per person' },
      { label: 'EST. CONVERSION LEADS', keys: ['est_conversion_leads', 'estimated_leads'], sub: 'Conversion leads' },
      { label: 'CTR %', keys: ['ctr'], sub: 'Click-through rate' },
      { label: 'CPM (₹)', keys: ['cpm'], sub: 'Per 1,000 impr.' },
      { label: 'SPEND (₹)', keys: ['spend'], sub: 'Amount spent' },
      { label: 'LEADS', keys: ['leads'], sub: 'Lead forms' },
      { label: 'COST PER LEAD (₹)', keys: ['cost_per_lead', 'cpl'], sub: 'Spend / leads' },
      { label: 'WHATSAPP / MESSAGES', keys: ['whatsapp_messages', 'messages'], sub: 'Conversations' },
      { label: 'VIDEO VIEWS', keys: ['video_views'], sub: 'ThruPlays / 3-sec' },
    ],
  },
  INSTAGRAM: {
    providers: ['INSTAGRAM'],
    icon: '◉', iconBg: 'linear-gradient(135deg,#f58529,#dd2a7b,#8134af)', title: 'Instagram', subtitle: '[Handle / page URL] &middot; [Date range]', section: 'Section 07',
    palette: ['#8134af', '#dd2a7b', '#f56040', '#b02a84', '#8134af', '#dd2a7b', '#f56040'],
    cards: [
      { label: 'FOLLOWERS', keys: ['followers'], sub: 'Total' },
      { label: 'NEW FOLLOWERS', keys: ['new_followers'], sub: 'This month' },
      { label: 'IMPRESSIONS / REACH / VIEWS', keys: ['impressions_reach_views', 'views', 'impressions'], sub: 'Total views' },
      { label: 'ENGAGEMENT', keys: ['engagement', 'interactions'], sub: 'Likes + comments + shares' },
      { label: 'POSTS PUBLISHED', keys: ['posts_published'], sub: 'Feed posts' },
      { label: 'REELS PUBLISHED', keys: ['reels_published', 'reels'], sub: 'Reels' },
      { label: 'STORIES', keys: ['stories'], sub: 'Stories posted' },
    ],
  },
  LINKEDIN: {
    providers: ['LINKEDIN'],
    icon: 'in', iconBg: '#0A66C2', title: 'LinkedIn', subtitle: '[Company page URL] &middot; [Date range]', section: 'Section 10',
    palette: ['#0A66C2', '#0d4f94', '#2f80ed', '#0a3d6e', '#0A66C2', '#2f80ed', '#0d4f94'],
    cards: [
      { label: 'FOLLOWERS', keys: ['followers'], sub: 'Total' },
      { label: 'NEW FOLLOWERS', keys: ['new_followers'], sub: 'This month' },
      { label: 'IMPRESSIONS', keys: ['impressions'], sub: 'Post impressions' },
      { label: 'ENGAGEMENT RATE %', keys: ['engagement_rate'], sub: 'Avg' },
      { label: 'REPOSTS', keys: ['reposts'], sub: 'Shares' },
      { label: 'CLICKS', keys: ['clicks'], sub: 'Post clicks' },
      { label: 'POSTS PUBLISHED', keys: ['posts_published'], sub: 'Posts / articles' },
    ],
  },
  LINKEDIN_ADS: {
    providers: ['LINKEDIN_ADS'],
    icon: 'in', iconBg: '#0A66C2', title: 'LinkedIn Ads', subtitle: 'Campaign Manager &middot; [Ad account] &middot; [Objective] &middot; [Date range]', section: 'Section 06',
    palette: ['#0A66C2', '#0a3d6e', '#2f80ed', '#0d4f94', '#0A66C2', '#2f80ed', '#0d4f94', '#0a3d6e', '#0A66C2', '#2f80ed', '#0d4f94', '#0a3d6e'],
    cards: [
      { label: 'ACTIVE CAMPAIGNS', keys: ['active_campaigns'], sub: 'Sponsored / Lead gen / Message' },
      { label: 'IMPRESSIONS', keys: ['impressions'], sub: 'Ad views' },
      { label: 'CLICKS', keys: ['clicks'], sub: 'Ad clicks' },
      { label: 'CTR %', keys: ['ctr'], sub: 'Click-through rate' },
      { label: 'AVG CPC (₹)', keys: ['avg_cpc', 'average_cpc'], sub: 'Cost per click' },
      { label: 'CPM (₹)', keys: ['cpm'], sub: 'Per 1,000 impr.' },
      { label: 'SPEND (₹)', keys: ['spend'], sub: 'Amount spent' },
      { label: 'LEADS', keys: ['leads'], sub: 'Lead gen forms' },
      { label: 'COST PER LEAD (₹)', keys: ['cost_per_lead', 'cpl'], sub: 'Spend / leads' },
      { label: 'EST. CONVERSION LEADS', keys: ['est_conversion_leads', 'estimated_leads'], sub: 'Conversion leads' },
      { label: 'ENGAGEMENTS', keys: ['engagements', 'engagement'], sub: 'Reactions + comments + shares' },
      { label: 'VIDEO VIEWS', keys: ['video_views'], sub: 'Views / completions' },
    ],
  },
  TWITTER: {
    providers: ['TWITTER', 'X', 'TWITTER_X'],
    icon: 'X', iconBg: '#111', title: 'Twitter / X', subtitle: '[@handle / profile URL] &middot; [Date range]', section: 'Section 11',
    palette: ['#15202b', '#1b2a38', '#38495a', '#44566a', '#15202b', '#38495a', '#1b2a38', '#15202b'],
    cards: [
      { label: 'FOLLOWERS', keys: ['followers'], sub: 'Total' },
      { label: 'NEW FOLLOWERS', keys: ['new_followers'], sub: 'This month' },
      { label: 'IMPRESSIONS', keys: ['impressions'], sub: 'Post impressions' },
      { label: 'ENGAGEMENT RATE %', keys: ['engagement_rate'], sub: 'Avg' },
      { label: 'ENGAGEMENTS', keys: ['engagements', 'engagement'], sub: 'Likes + replies + reposts' },
      { label: 'PROFILE VISITS', keys: ['profile_visits'], sub: 'This month' },
      { label: 'LINK CLICKS', keys: ['link_clicks'], sub: 'Post link clicks' },
      { label: 'POSTS PUBLISHED', keys: ['posts_published'], sub: 'Posts / threads' },
    ],
  },
};

function statCardPage(payload, byProv, cfg) {
  const metrics = {};
  for (const p of cfg.providers) Object.assign(metrics, byProv[p] || {});
  // Last month's metrics for this platform, used to auto-compute the
  // "vs last month: _ %" on each card.
  const lastMetrics = {};
  const byProvLast = payload.__byProvLast || {};
  for (const p of cfg.providers) Object.assign(lastMetrics, byProvLast[p] || {});
  const cards = cfg.cards.map((c, i) => {
    // A manually entered "<key>_vs_last_month" wins; otherwise auto-compute
    // from last month's value with ((this - last) / last) × 100.
    const enteredVs = mv(metrics, c.keys.map((k) => `${k}_vs_last_month`), '');
    const pct = String(enteredVs).trim() !== ''
      ? String(enteredVs).trim().replace(/%$/, '')
      : pctChange(mv(metrics, c.keys, ''), mv(lastMetrics, c.keys, ''));
    return {
      label: c.label,
      value: `<span class="mcard-dash">${mv(metrics, c.keys)}</span>`,
      sub: c.sub,
      pct,
      bg: cfg.palette[i % cfg.palette.length],
      fg: '#fff',
    };
  });
  const icon = `<span style="${cfg.iconFg ? `color:${cfg.iconFg};` : 'color:#fff;'}font-weight:800">${cfg.icon}</span>`;
  return `<section class="slide">
    ${slideHeader({ icon, iconBg: cfg.iconBg, title: cfg.title, subtitle: cfg.subtitle })}
    ${cardGrid(cards, 4)}
    ${slideFooter(payload, cfg.section)}
  </section>`;
}

function tablePage(payload, byProv, cfg, headers, colKeys) {
  const metrics = {};
  for (const p of cfg.providers) Object.assign(metrics, byProv[p] || {});
  // Row fields are stored as `${col}_${row}` (rows 1..6). Keep only non-empty rows.
  const rows = [];
  for (let r = 1; r <= 6; r++) {
    const cells = colKeys.map((col) => mv(metrics, [`${col}_${r}`], ''));
    if (cells.some((c) => c && c !== '')) rows.push(cells);
  }
  return `<section class="slide">
    ${slideHeader({ icon: `<span style="color:#fff;font-weight:800">${cfg.icon}</span>`, iconBg: cfg.iconBg, title: cfg.title + ' — Dashboard', subtitle: cfg.subtitle })}
    ${dataTable(headers, rows, Math.max(6, rows.length))}
    ${slideFooter(payload, cfg.section)}
  </section>`;
}

function screenshotPage(payload, cfg, shots, caption, withInsights, insightsText) {
  const accent = cfg.iconBg === '#fff' ? '#2563eb' : cfg.iconBg;
  const body = withInsights
    ? `<div class="shot-row"><div class="shot-col">${screenshotZone(shots, caption)}</div><div class="ins-col">${insightsPanel(accent, insightsText)}</div></div>`
    : screenshotZone(shots, caption);
  return `<section class="slide">
    ${slideHeader({ icon: `<span style="color:#fff;font-weight:800">${cfg.icon}</span>`, iconBg: cfg.iconBg, title: cfg.title + ' — Dashboard', subtitle: cfg.subtitle })}
    ${body}
    ${slideFooter(payload, cfg.section)}
  </section>`;
}

function hasProviderContent(payload, byProv, providers) {
  const keys = new Set(providers.map(pk));
  const listed = (Array.isArray(payload.providers) ? payload.providers : [])
    .some((item) => item && keys.has(pk(typeof item === 'string' ? item : item.provider)));
  const hasMetrics = [...keys].some((key) =>
    Object.entries(byProv[key] || {}).some(([field, value]) =>
      field !== 'export_overrides' && value != null && String(value).trim() !== '',
    ),
  );
  const hasScreenshot = (Array.isArray(payload.screenshots) ? payload.screenshots : [])
    .some((shot) => shot && keys.has(pk(shot.provider)) && shot.bytesBase64);
  return listed || hasMetrics || hasScreenshot;
}

// ---- Fixed pages ----------------------------------------------------------
function coverPage(payload, byProv) {
  const logo = reportLogo() ? `<img class="cover-logo" src="${reportLogo()}" alt="Client logo"/>` : `<div class="brand-wordmark big">GO DIGITAL</div>`;
  const ce = payload.cover_edits || payload.coverEdits || {};
  const chips = [
    ['CLIENT / BRAND', editVal(ce, 'CLIENT / BRAND') || payload.clientName, '#2f55d4'],
    ['REPORT MONTH', editVal(ce, 'REPORT MONTH') || payload.periodLabel || payload.reportMonth, '#7c3aed'],
    ['DATE RANGE', editVal(ce, 'DATE RANGE') || payload.dateRange, '#0ea5a4'],
    ['PREPARED BY', editVal(ce, 'PREPARED BY') || payload.preparedBy, '#f59e0b'],
  ].map(([label, val, color]) => `
    <div class="cover-chip" style="background:${color}">
      <div class="cc-label">${esc(label)}</div>
      <div class="cc-val">${val ? esc(val) : '[Enter]'}</div>
    </div>`).join('');
  const channelOptions = [
    { label: 'GMB / GBP', providers: ['GOOGLE_BUSINESS_PROFILE', 'GMB', 'GBP', 'LOCAL_SEO'] },
    { label: 'Google Ads', providers: ['GOOGLE_ADS'] },
    { label: 'Google Analytics', providers: ['GOOGLE_ANALYTICS'] },
    { label: 'Google Search Console', providers: ['GOOGLE_SEARCH_CONSOLE'] },
    { label: 'Meta Ads', providers: ['META_ADS', 'META'] },
    { label: 'LinkedIn Ads', providers: ['LINKEDIN_ADS'] },
    { label: 'Instagram', providers: ['INSTAGRAM'] },
    { label: 'Facebook', providers: ['FACEBOOK'] },
    { label: 'YouTube', providers: ['YOUTUBE'] },
    { label: 'LinkedIn', providers: ['LINKEDIN'] },
    { label: 'Twitter / X', providers: ['TWITTER_X', 'TWITTER', 'X'] },
    { label: 'Creatives', providers: ['CREATIVES_PUBLISHED', 'CREATIVES'] },
    { label: 'Posters & Videos', providers: ['CREATIVE_SHOWCASE'] },
  ];
  const channels = channelOptions
    .filter((channel) => hasProviderContent(payload, byProv, channel.providers))
    .map(({ label }) => label);
  const channelCards = (channels.length ? channels : ['No provider dashboards selected'])
    .map((c) => `<div class="cover-channel">${esc(c)}</div>`).join('');
  return `<section class="slide cover">
    <div class="cover-left">
      ${logo}
      <div class="cover-kicker">CLIENT MONTHLY REPORT</div>
      <div class="cover-h1">Digital Marketing</div>
      <div class="cover-h1 accent">Performance Report</div>
      <div class="cover-chips">${chips}</div>
      <div class="cover-channels-label">CHANNELS COVERED</div>
      <div class="cover-channels">${channelCards}</div>
    </div>
    <div class="cover-right">
      <div class="cover-circle big"></div>
      <div class="cover-circle small"></div>
    </div>
  </section>`;
}

function channelSummaryPage(payload, byProv) {
  // Values entered on the Channel Summary page are stored under CHANNEL_SUMMARY
  // with prefixed keys (e.g. google_ads_impressions). Fall back to each
  // platform's own snapshot when the summary cell is blank.
  const cs = byProv['CHANNEL_SUMMARY'] || {};
  // Channels that are part of this report (assigned / uploaded) stay in the
  // summary even when their cells are blank; channels not covered are dropped.
  const covered = new Set(Object.keys(byProv));
  for (const p of (Array.isArray(payload.providers) ? payload.providers : [])) {
    const key = pk(typeof p === 'string' ? p : p && p.provider);
    if (key) covered.add(key);
  }
  const rows = [
    ['GMB / GBP', 'gmb', ['GOOGLE_BUSINESS_PROFILE']],
    ['Google Ads', 'google_ads', ['GOOGLE_ADS']],
    ['Google Analytics', 'google_analytics', ['GOOGLE_ANALYTICS']],
    ['Google Search Console', 'google_search_console', ['GOOGLE_SEARCH_CONSOLE']],
    ['Meta Ads', 'meta_ads', ['META_ADS']],
    ['LinkedIn Ads', 'linkedin_ads', ['LINKEDIN_ADS']],
    ['Instagram', 'instagram', ['INSTAGRAM']],
    ['Facebook', 'facebook', ['FACEBOOK']],
    ['YouTube', 'youtube', ['YOUTUBE']],
    ['LinkedIn (Organic)', 'linkedin_organic', ['LINKEDIN']],
    ['Twitter / X', 'twitter_x', ['TWITTER_X', 'TWITTER']],
  ].map(([name, prefix, provs]) => {
    const m = {};
    for (const p of provs) Object.assign(m, byProv[p] || {});
    if (prefix === 'google_analytics') {
      m.impressions = m.impressions || m.active_users;
      m.clicks = m.clicks || m.sessions;
      m.leads = m.leads || m.conversions;
    }
    const row = [
      name,
      mv(cs, [`${prefix}_impressions`], mv(m, ['impressions', 'impressions_reach_views', 'reach_impressions'], '')),
      mv(cs, [`${prefix}_clicks`], mv(m, ['clicks'], '')),
      mv(cs, [`${prefix}_leads_calls`], mv(m, ['leads', 'calls'], '')),
      mv(cs, [`${prefix}_spend`], mv(m, ['spend'], '')),
      mv(cs, [`${prefix}_estimated_conversion_leads`], mv(m, ['est_conversion_leads'], '')),
    ];
    return { row, isCovered: provs.some((p) => covered.has(pk(p))) };
  })
    // Keep a channel that is covered by this report, or that has any value.
    .filter(({ row, isCovered }) =>
      isCovered || row.slice(1).some((cell) => String(cell).trim() !== ''))
    .map(({ row }) => row);
  return `<section class="slide">
    ${slideHeader({ icon: '<span style="color:#fff;font-weight:800">∑</span>', iconBg: '#2f55d4', title: 'Channel Summary', subtitle: 'Performance by channel &middot; [Date range]' })}
    ${dataTable(['Channel', 'Impressions', 'Clicks', 'Leads / Calls', 'Spend (₹)', 'Estimated Conversion leads'], rows, rows.length)}
    ${slideFooter(payload, 'Section 02')}
  </section>`;
}

function creativesPublishedPage(payload, byProv) {
  const m = byProv['CREATIVES_PUBLISHED'] || byProv['CREATIVES'] || {};
  const cards = [
    { label: 'POSTERS / STATIC POSTS', keys: ['posters_static_posts'], pctKeys: ['posters_static_posts_vs_last_month'], sub: 'Designed', bg: '#8134af' },
    { label: 'CAROUSELS', keys: ['carousels'], pctKeys: ['carousels_vs_last_month'], sub: 'Designed', bg: '#f59e0b' },
    { label: 'REELS / SHORT VIDEOS', keys: ['reels_short_videos'], pctKeys: ['reels_short_videos_vs_last_month'], sub: 'Edited', bg: '#0ea5a4' },
    { label: 'LONG VIDEOS', keys: ['long_videos'], pctKeys: ['long_videos_vs_last_month'], sub: 'YouTube', bg: '#f59e0b' },
    { label: 'AD CREATIVES', keys: ['ad_creatives'], pctKeys: ['ad_creatives_vs_last_month'], sub: 'For campaigns', bg: '#0ea5a4' },
    { label: 'STORIES', keys: ['stories'], pctKeys: ['stories_vs_last_month'], sub: 'Designed', bg: '#e11d6b' },
  ].map((c) => ({ label: c.label, value: `<span class="mcard-dash">${mv(m, c.keys)}</span>`, sub: c.sub, pct: mv(m, c.pctKeys, '____'), bg: c.bg }));
  return `<section class="slide">
    ${slideHeader({ icon: '<span style="color:#fff;font-weight:800">✦</span>', iconBg: '#8134af', title: 'Creatives Published', subtitle: 'Posters &amp; videos &middot; Design &amp; content work completed this month' })}
    ${cardGrid(cards, 3)}
    <div style="height:14px"></div>
    ${dataTable(['Best creative', 'Platform', 'Reach / Views', 'Engagement'], [], 3, '#8134af')}
    ${slideFooter(payload, 'Section 12')}
  </section>`;
}

function creativeShowcasePage(payload) {
  const shots = showcaseShots(payload);
  const tile = (tag, color, slot, hint, play) => {
    const img = shots[slot];
    if (img) return `<div class="show-box filled"><div class="show-tag" style="background:${color}">${esc(tag)}</div><img src="${img}" alt="${esc(tag)}"/></div>`;
    return `<div class="show-box"><div class="show-tag" style="background:${color}">${esc(tag)}</div>${play ? '<div class="show-play">▶</div>' : ''}<div class="show-hint">${esc(hint)}</div></div>`;
  };
  const posters = [1, 2, 3, 4].map((n) => tile(`Poster ${n}`, ['#8134af', '#f59e0b', '#0ea5a4', '#e11d6b'][n - 1], `Poster ${n}`, 'Paste poster image', false)).join('');
  const videos = [1, 2, 3, 4].map((n) => tile(`Video ${n}`, ['#0ea5a4', '#e11d6b', '#2f55d4', '#c62828'][n - 1], `Video ${n}`, 'Paste video thumbnail', true)).join('');
  return `<section class="slide">
    ${slideHeader({ icon: '<span style="color:#fff;font-weight:800">✦</span>', iconBg: '#8134af', title: 'Creative Showcase', subtitle: 'Top posters &amp; videos of the month' })}
    <div class="show-grid">${posters}</div>
    <div class="show-grid">${videos}</div>
    ${slideFooter(payload, 'Section 12')}
  </section>`;
}

function nextMonthPlanPage(payload) {
  const channels = ['GMB / GBP', 'Google Ads', 'Meta Ads', 'LinkedIn Ads', 'Instagram', 'Facebook', 'YouTube', 'LinkedIn (Organic)', 'Twitter / X', 'Creatives'];
  // Next Month Plan edits arrive under slide_edits['28'] keyed by label, e.g.
  // 'Google Ads action planned', 'Google Ads owner', 'Google Ads due'.
  const se = (payload.slide_edits || payload.slideEdits || {})['28'] || {};
  const rows = channels.map((c) => [c, editVal(se, `${c} action planned`), editVal(se, `${c} owner`), editVal(se, `${c} due`)]);
  const table = dataTable(['Channel', 'Action planned', 'Owner', 'Due'], rows, rows.length, '#0ea5a4');
  const approvals = editVal(se, 'Approvals & inputs needed');
  const remarks = editVal(se, 'Remarks');
  const noteLines = (text) => (text ? String(text).split(/\r?\n/).filter((l) => l.trim()).map((l) => `<div class="ins-line filled">${esc(l)}</div>`).join('') : '<div class="ins-line"></div><div class="ins-line"></div><div class="ins-line"></div>');
  return `<section class="slide">
    ${slideHeader({ icon: '<span style="color:#fff;font-weight:800">→</span>', iconBg: '#0ea5a4', title: 'Next Month Plan', subtitle: 'Priorities &amp; actions' })}
    <div class="plan-row">
      <div class="plan-table">${table}</div>
      <div class="plan-side">
        <div class="ins-panel" style="border-color:#f59e0b"><div class="ins-head"><span class="ins-check" style="background:#f59e0b">✓</span> Approvals &amp; inputs needed</div>${noteLines(approvals)}</div>
        <div class="ins-panel" style="border-color:#8134af;margin-top:14px"><div class="ins-head"><span class="ins-check" style="background:#8134af">✓</span> Remarks</div>${noteLines(remarks)}</div>
      </div>
    </div>
    ${slideFooter(payload, 'Section 13')}
  </section>`;
}

// ---- CSS ------------------------------------------------------------------
const CSS = `
:root{--ink:#0f1e3d;--muted:#64748b;--line:#e6ebf4;}
*{box-sizing:border-box;margin:0;padding:0}
html,body{background:#fff;font-family:'Segoe UI',Arial,Helvetica,sans-serif;color:var(--ink);-webkit-print-color-adjust:exact;print-color-adjust:exact}
.slide{position:relative;width:1280px;height:720px;padding:40px 48px;overflow:hidden;background:#fff;page-break-after:always;border-bottom:1px solid #fff}
.slide:last-child{page-break-after:auto}
/* header */
.s-head{display:flex;align-items:center;justify-content:space-between;margin-bottom:22px}
.s-head-left{display:flex;align-items:center;gap:16px}
.s-icon{width:66px;height:66px;border-radius:16px;display:flex;align-items:center;justify-content:center;font-size:30px;box-shadow:0 6px 16px rgba(15,30,61,.12)}
.s-title{font-size:34px;font-weight:800;line-height:1.05}
.s-sub{font-size:14px;color:var(--muted);margin-top:4px}
.brand-logo{height:40px;object-fit:contain}
.brand-wordmark{font-weight:900;color:#13308a;letter-spacing:1px}
.brand-wordmark.big{font-size:40px;margin-bottom:10px}
/* footer */
.s-foot{position:absolute;left:48px;right:48px;bottom:22px;display:flex;justify-content:space-between;font-size:12px;color:var(--muted)}
/* metric cards */
.mcard-grid{display:grid;gap:16px}
.mcard-grid.cols-4{grid-template-columns:repeat(4,1fr)}
.mcard-grid.cols-3{grid-template-columns:repeat(3,1fr)}
.mcard{position:relative;border-radius:14px;padding:18px 18px 16px;height:182px;overflow:hidden;display:flex;flex-direction:column;box-shadow:0 8px 18px rgba(15,30,61,.10)}
.mcard-grid.cols-4 .mcard,.mcard-grid.cols-3 .mcard{height:auto;min-height:150px}
.mcard-label{font-size:13px;font-weight:800;letter-spacing:.6px;text-transform:uppercase;opacity:.95}
.mcard-value{margin:14px 0 auto;font-size:26px;font-weight:800}
.mcard-dash{display:inline-block;min-width:36px;border-bottom:3px solid rgba(255,255,255,.85);padding-bottom:2px}
.mcard-foot{margin-top:auto}
.mcard-sub{font-size:12px;opacity:.9}
.mcard-pct{font-size:12px;margin-top:4px;opacity:.95}
.mcard-bubble{position:absolute;right:-10px;top:24px;width:96px;height:96px;border-radius:50%;background:rgba(255,255,255,.14)}
.mcard-bubble2{position:absolute;right:16px;top:70px;width:52px;height:52px;border-radius:50%;background:rgba(255,255,255,.12)}
/* tables */
.dtable{width:100%;border-collapse:collapse;font-size:14px}
.dtable th{color:#fff;text-align:center;padding:16px 14px;font-weight:700}
.dtable td{border:1px solid var(--line);padding:16px 14px;height:44px;color:#17306b;font-weight:600}
.dtable tr.alt td{background:#f6f8fc}
.dtable .tcell-first{font-weight:700}
/* screenshot zone */
.shot-zone{height:460px;border:2px dashed #b9c6e6;border-radius:16px;display:flex;flex-direction:column;align-items:center;justify-content:center;color:#2b3f73}
.shot-zone.filled{border:1px solid var(--line);background:#fff;overflow:hidden;padding:10px}
.shot-zone.filled img{max-width:100%;max-height:100%;object-fit:contain}
.shot-plus{width:64px;height:64px;border-radius:50%;border:1px solid #b9c6e6;display:flex;align-items:center;justify-content:center;font-size:30px;color:#5b76b8;margin-bottom:14px}
.shot-cap{font-weight:800}
.shot-sub{font-size:13px;color:var(--muted);margin-top:4px}
.shot-row{display:grid;grid-template-columns:1fr 1fr;gap:20px}
.shot-row .shot-zone{height:440px}
/* insights */
.ins-panel{border:2px solid #2563eb;border-radius:16px;padding:18px;height:440px}
.ins-head{font-weight:800;display:flex;align-items:center;gap:10px;margin-bottom:16px}
.ins-check{width:26px;height:26px;border-radius:50%;color:#fff;display:inline-flex;align-items:center;justify-content:center;font-size:14px}
.ins-line{border-bottom:1px solid var(--line);height:52px}
.ins-line.filled{color:#17306b;font-weight:600;height:auto;padding:8px 0}
/* cover */
.slide.cover{padding:0;display:flex}
.cover-left{flex:1;padding:56px 60px}
.cover-logo{height:62px;object-fit:contain;margin-bottom:26px}
.cover-kicker{letter-spacing:4px;font-weight:800;color:#2f55d4;font-size:16px;margin-bottom:8px}
.cover-h1{font-size:58px;font-weight:900;line-height:1.02;color:#0f1e3d}
.cover-h1.accent{color:#2f55d4;margin-bottom:28px}
.cover-chips{display:grid;grid-template-columns:repeat(4,1fr);gap:16px;max-width:760px}
.cover-chip{border-radius:14px;padding:16px;color:#fff;min-height:92px}
.cc-label{font-size:11px;font-weight:800;letter-spacing:.8px;opacity:.95}
.cc-val{font-size:20px;font-weight:800;margin-top:10px}
.cover-channels-label{letter-spacing:3px;font-weight:800;color:#94a3b8;margin:30px 0 14px}
.cover-channels{display:flex;flex-wrap:wrap;gap:10px;max-width:760px}
.cover-channel{border:1px solid var(--line);border-radius:10px;padding:10px 14px;font-weight:700;font-size:13px;box-shadow:0 2px 6px rgba(15,30,61,.05)}
.cover-right{width:420px;position:relative;background:linear-gradient(160deg,#2f55d4,#4169e1);overflow:hidden}
.cover-circle{position:absolute;border-radius:50%}
.cover-circle.big{width:360px;height:360px;background:rgba(255,255,255,.12);right:-80px;top:-60px}
.cover-circle.small{width:300px;height:300px;background:rgba(255,255,255,.14);right:-40px;bottom:-110px}
/* creatives showcase */
.show-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:16px;margin-bottom:16px}
.show-box{position:relative;border:2px dashed #cbd5e1;border-radius:14px;height:230px;display:flex;flex-direction:column;align-items:center;justify-content:center;color:var(--muted);overflow:hidden}
.show-box.filled{border:1px solid var(--line);padding:0}
.show-box.filled img{width:100%;height:100%;object-fit:cover}
.show-tag{position:absolute;top:14px;left:14px;color:#fff;font-weight:800;font-size:12px;padding:6px 12px;border-radius:14px}
.show-play{font-size:34px;color:#1f6fe0;margin-bottom:8px}
.show-hint{font-size:13px}
/* next month plan */
.plan-row{display:grid;grid-template-columns:1.6fr 1fr;gap:20px}
.plan-side .ins-panel{height:auto}
.plan-side .ins-line{height:34px}
`;

// ---- Public API -----------------------------------------------------------
function buildReportHtml(payload = {}) {
  // Use the opened client's company logo across the whole report.
  REPORT_LOGO_URI = clientLogoUri(payload);
  const byProv = metricsByProvider(payload);
  // Previous month's metrics (attached by the controller) power the auto
  // "vs last month %" on every stat card.
  payload.__byProvLast = metricsByProvider(payload, 'lastMonthSnapshots');
  // Insights text for a platform's dashboard page (stored under the same key).
  const insLines = (cfg) => {
    const m = {};
    for (const p of cfg.providers) Object.assign(m, byProv[p] || {});
    const raw = m.insights_next_actions;
    if (!raw) return undefined;
    return String(raw).split(/\r?\n/).map((s) => s.trim()).filter(Boolean);
  };
  const pages = [];

  pages.push(coverPage(payload, byProv));
  pages.push(channelSummaryPage(payload, byProv));

  // Provider pages are included only when selected or populated in Preview/Edit.
  const gmb = PLATFORM_CARDS.GMB;
  if (hasProviderContent(payload, byProv, gmb.providers)) {
    pages.push(statCardPage(payload, byProv, gmb));
    pages.push(tablePage(payload, byProv, gmb, ['Top search keyword', 'Searches', 'Optimization done'], ['top_search_keyword', 'searches', 'optimization_done']));
    pages.push(screenshotPage(payload, gmb, shotsFor(payload, gmb.providers), 'Google Business Profile → Performance', false));
  }
  if (hasProviderContent(payload, byProv, ['GMB_RANKING', 'LOCAL_SEO'])) {
    pages.push(screenshotPage(payload, gmb, shotsFor(payload, ['GMB_RANKING', 'LOCAL_SEO']), 'Google Business Profile → Ranking in the GMB', false));
  }

  // Google Ads: cards, dashboard table, screenshot
  const gads = PLATFORM_CARDS.GOOGLE_ADS;
  if (hasProviderContent(payload, byProv, gads.providers)) {
    pages.push(statCardPage(payload, byProv, gads));
    pages.push(tablePage(payload, byProv, gads, ['Campaign', 'Impr.', 'Clicks', 'Conv.', 'Spend (₹)', 'CPL (₹)'], ['campaign', 'impr', 'clicks', 'conv', 'spend', 'cpl']));
    pages.push(screenshotPage(payload, gads, shotsFor(payload, gads.providers), 'Google Ads → Overview / Campaigns', false));
  }

  const analytics = PLATFORM_CARDS.GOOGLE_ANALYTICS;
  if (hasProviderContent(payload, byProv, analytics.providers)) {
    pages.push(statCardPage(payload, byProv, analytics));
    pages.push(screenshotPage(payload, analytics, shotsFor(payload, analytics.providers), 'Google Analytics → Reports overview', false));
  }

  const searchConsole = PLATFORM_CARDS.GOOGLE_SEARCH_CONSOLE;
  if (hasProviderContent(payload, byProv, searchConsole.providers)) {
    pages.push(statCardPage(payload, byProv, searchConsole));
    pages.push(screenshotPage(payload, searchConsole, shotsFor(payload, searchConsole.providers), 'Google Search Console → Search results', false));
  }

  // YouTube: cards, screenshot + insights
  const yt = PLATFORM_CARDS.YOUTUBE;
  if (hasProviderContent(payload, byProv, yt.providers)) {
    pages.push(statCardPage(payload, byProv, yt));
    pages.push(screenshotPage(payload, yt, shotsFor(payload, yt.providers), 'YouTube Studio → Analytics', true, insLines(yt)));
  }

  // Facebook: cards, screenshot + insights
  const fb = PLATFORM_CARDS.FACEBOOK;
  if (hasProviderContent(payload, byProv, fb.providers)) {
    pages.push(statCardPage(payload, byProv, fb));
    pages.push(screenshotPage(payload, fb, shotsFor(payload, fb.providers), 'Meta Business Suite → Insights', true, insLines(fb)));
  }

  // Meta Ads: cards, dashboard table, screenshot
  const meta = PLATFORM_CARDS.META_ADS;
  if (hasProviderContent(payload, byProv, meta.providers)) {
    pages.push(statCardPage(payload, byProv, meta));
    pages.push(tablePage(payload, byProv, meta, ['Campaign / Ad set', 'Reach', 'Clicks', 'Leads', 'Spend (₹)', 'CPL (₹)'], ['campaign_ad_set', 'reach', 'clicks', 'leads', 'spend', 'cpl']));
    pages.push(screenshotPage(payload, meta, shotsFor(payload, meta.providers), 'Meta Ads Manager → Campaigns', false));
  }

  // Instagram: cards, screenshot + insights
  const ig = PLATFORM_CARDS.INSTAGRAM;
  if (hasProviderContent(payload, byProv, ig.providers)) {
    pages.push(statCardPage(payload, byProv, ig));
    pages.push(screenshotPage(payload, ig, shotsFor(payload, ig.providers), 'Instagram → Professional dashboard / Insights', true, insLines(ig)));
  }

  // LinkedIn: cards, screenshot + insights
  const li = PLATFORM_CARDS.LINKEDIN;
  if (hasProviderContent(payload, byProv, li.providers)) {
    pages.push(statCardPage(payload, byProv, li));
    pages.push(screenshotPage(payload, li, shotsFor(payload, li.providers), 'LinkedIn Page → Analytics', true, insLines(li)));
  }

  // LinkedIn Ads: cards, dashboard table, screenshot
  const lia = PLATFORM_CARDS.LINKEDIN_ADS;
  if (hasProviderContent(payload, byProv, lia.providers)) {
    pages.push(statCardPage(payload, byProv, lia));
    pages.push(tablePage(payload, byProv, lia, ['Campaign group / Campaign', 'Impr.', 'Clicks', 'Leads', 'Spend (₹)', 'CPL (₹)'], ['campaign_group_campaign', 'impr', 'clicks', 'leads', 'spend', 'cpl']));
    pages.push(screenshotPage(payload, lia, shotsFor(payload, lia.providers), 'LinkedIn Campaign Manager → Campaigns', false));
  }

  // Twitter / X: cards, screenshot + insights
  const tw = PLATFORM_CARDS.TWITTER;
  if (hasProviderContent(payload, byProv, tw.providers)) {
    pages.push(statCardPage(payload, byProv, tw));
    pages.push(screenshotPage(payload, tw, shotsFor(payload, tw.providers), 'X Analytics → Account overview', true, insLines(tw)));
  }

  // Creatives + Next Month Plan
  pages.push(creativesPublishedPage(payload, byProv));
  pages.push(creativeShowcasePage(payload));
  pages.push(nextMonthPlanPage(payload));

  return `<!doctype html><html><head><meta charset="utf-8"><style>${CSS}</style></head><body>${pages.join('\n')}</body></html>`;
}

module.exports = { buildReportHtml };
