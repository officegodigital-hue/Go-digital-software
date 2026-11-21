// lib/report/report_providers.dart
//
// Canonical provider registry for the Client Report Management module.
// One source of truth for provider names, brand logos (bundled SVGs under
// assets/report_providers/), brand colors, and the mapping to the PPTX
// dashboard-page title used by the report builder. Facebook and Meta Ads are
// intentionally SEPARATE providers and must never be merged.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

@immutable
class ReportProvider {
  const ReportProvider({
    required this.key,
    required this.label,
    required this.asset,
    required this.color,
    required this.dashboardPage,
    this.aliases = const <String>[],
  });

  /// Stable machine key (e.g. 'meta_ads').
  final String key;

  /// Human label shown in the UI (e.g. 'Meta Ads').
  final String label;

  /// Bundled SVG logo asset path.
  final String asset;

  /// Brand color, used for chip backgrounds / accents.
  final Color color;

  /// The report builder's dashboard page title this provider maps to.
  final String dashboardPage;

  /// Lowercase fragments used to match assignment task names and OCR output.
  final List<String> aliases;
}

const List<ReportProvider> kReportProviders = <ReportProvider>[
  ReportProvider(
    key: 'google_business_profile',
    label: 'Google Business Profile',
    asset: 'assets/report_providers/google_business_profile.svg',
    color: Color(0xff4285F4),
    dashboardPage: 'Google Business Profile Dashboard',
    aliases: ['google business', 'business profile', 'gbp', 'google my business', 'google maps'],
  ),
  ReportProvider(
    key: 'google_ads',
    label: 'Google Ads',
    asset: 'assets/report_providers/google_ads.svg',
    color: Color(0xff4285F4),
    dashboardPage: 'Google Ads Dashboard',
    aliases: ['google ads', 'adwords', 'google ad'],
  ),
  ReportProvider(
    key: 'google_analytics',
    label: 'Google Analytics',
    asset: 'assets/report_providers/google_analytics.svg',
    color: Color(0xffE37400),
    dashboardPage: 'Google Analytics Dashboard',
    aliases: ['google analytics', 'ga4', 'analytics'],
  ),
  ReportProvider(
    key: 'google_search_console',
    label: 'Google Search Console',
    asset: 'assets/report_providers/google_search_console.svg',
    color: Color(0xff458CF5),
    dashboardPage: 'Google Search Console Dashboard',
    aliases: ['search console', 'gsc', 'search performance'],
  ),
  ReportProvider(
    key: 'meta_ads',
    label: 'Meta Ads',
    asset: 'assets/report_providers/meta_ads.svg',
    color: Color(0xff0866FF),
    dashboardPage: 'Meta Ads Dashboard',
    aliases: ['meta ads', 'ads manager', 'adsmanager', 'meta business ads'],
  ),
  ReportProvider(
    key: 'facebook',
    label: 'Facebook',
    asset: 'assets/report_providers/facebook.svg',
    color: Color(0xff1877F2),
    dashboardPage: 'Facebook Dashboard',
    aliases: ['facebook', 'professional dashboard', 'facebook insights'],
  ),
  ReportProvider(
    key: 'instagram',
    label: 'Instagram',
    asset: 'assets/report_providers/instagram.svg',
    color: Color(0xffE4405F),
    dashboardPage: 'Instagram Dashboard',
    aliases: ['instagram', 'instagram insights', 'account insights'],
  ),
  ReportProvider(
    key: 'youtube',
    label: 'YouTube',
    asset: 'assets/report_providers/youtube.svg',
    color: Color(0xffFF0000),
    dashboardPage: 'YouTube Dashboard',
    aliases: ['youtube', 'youtube studio', 'youtube analytics'],
  ),
  ReportProvider(
    key: 'linkedin',
    label: 'LinkedIn',
    asset: 'assets/report_providers/linkedin.svg',
    color: Color(0xff0A66C2),
    dashboardPage: 'LinkedIn Dashboard',
    aliases: ['linkedin', 'linkedin page', 'linkedin analytics'],
  ),
  ReportProvider(
    key: 'linkedin_ads',
    label: 'LinkedIn Ads',
    asset: 'assets/report_providers/linkedin_ads.svg',
    color: Color(0xff0A66C2),
    dashboardPage: 'LinkedIn Ads Dashboard',
    aliases: ['linkedin ads', 'campaign manager', 'linkedin campaign'],
  ),
  ReportProvider(
    key: 'twitter_x',
    label: 'Twitter/X',
    asset: 'assets/report_providers/twitter_x.svg',
    color: Color(0xff000000),
    dashboardPage: 'Twitter Dashboard',
    aliases: ['twitter', 'x.com', 'x analytics', 'twitter/x'],
  ),
];

String _normalize(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Resolve a provider from any label, assignment task name, OCR provider name,
/// or dashboard-page title. Returns null when nothing matches.
ReportProvider? providerForName(String? raw) {
  if (raw == null) return null;
  final norm = _normalize(raw);
  if (norm.isEmpty) return null;

  // Exact key / label match first.
  for (final p in kReportProviders) {
    if (_normalize(p.key) == norm ||
        _normalize(p.label) == norm ||
        _normalize(p.dashboardPage) == norm) {
      return p;
    }
  }
  // Longest-alias-first so 'meta ads' beats 'meta', 'linkedin ads' beats
  // 'linkedin', and Facebook never collapses into Meta Ads.
  ReportProvider? best;
  var bestLen = 0;
  for (final p in kReportProviders) {
    for (final alias in p.aliases) {
      final a = _normalize(alias);
      if (a.isNotEmpty && norm.contains(a) && a.length > bestLen) {
        best = p;
        bestLen = a.length;
      }
    }
  }
  return best;
}

/// Resolves a de-duplicated list of providers from a client's assigned task
/// names (e.g. 'GOOGLE ADS (1)', 'INSTAGRAM POSTER (12)'). Unrecognized tasks
/// are skipped. Order follows the task list, keeping the first occurrence.
List<ReportProvider> providersFromTaskNames(Iterable<dynamic> tasks) {
  final seen = <String>{};
  final out = <ReportProvider>[];
  for (final task in tasks) {
    final name = task is Map
        ? (task['task']?.toString() ?? '')
        : task.toString();
    final provider = providerForName(name);
    if (provider != null && seen.add(provider.key)) out.add(provider);
  }
  return out;
}

ReportProvider? providerByKey(String key) {
  for (final p in kReportProviders) {
    if (p.key == key) return p;
  }
  return null;
}

ReportProvider? providerByDashboardPage(String page) {
  final norm = _normalize(page);
  for (final p in kReportProviders) {
    if (_normalize(p.dashboardPage) == norm) return p;
  }
  return providerForName(page);
}

/// A bundled brand logo (not a Material icon), optionally on a soft brand chip.
class ProviderLogo extends StatelessWidget {
  const ProviderLogo({
    super.key,
    required this.provider,
    this.size = 24,
    this.padded = false,
  });

  /// Create from any name; renders a neutral public-globe fallback if unknown.
  factory ProviderLogo.fromName(
    String? name, {
    Key? key,
    double size = 24,
    bool padded = false,
  }) =>
      ProviderLogo(
        key: key,
        provider: providerForName(name),
        size: size,
        padded: padded,
      );

  final ReportProvider? provider;
  final double size;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final logo = provider == null
        ? Icon(Icons.public, size: size, color: const Color(0xff7c8db5))
        : SvgPicture.asset(
            provider!.asset,
            width: size,
            height: size,
            placeholderBuilder: (_) =>
                Icon(Icons.public, size: size, color: const Color(0xff7c8db5)),
          );
    if (!padded) return logo;
    final accent = provider?.color ?? const Color(0xff7c8db5);
    return Container(
      padding: EdgeInsets.all(size * 0.34),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(size * 0.5),
      ),
      child: logo,
    );
  }
}
