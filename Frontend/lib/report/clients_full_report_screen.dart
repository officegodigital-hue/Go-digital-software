import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/auth/auth_session.dart';
import '../../shared/utils/dashboard_image_validation.dart';
import '../../services/api_config.dart';
// ✅ Correct package import
import 'package:godigital_portal/report/data/full_report_service.dart';
import 'package:godigital_portal/report/report_providers.dart';
import 'package:godigital_portal/report/report_brand.dart';
import 'package:godigital_portal/report/report_preview_screen.dart';

class ClientsFullReportScreen extends StatefulWidget {
  const ClientsFullReportScreen({super.key, required this.business});
  final Map<String, dynamic> business;
  @override
  State<ClientsFullReportScreen> createState() =>
      _ClientsFullReportScreenState();
}

class _ClientsFullReportScreenState extends State<ClientsFullReportScreen> {
  bool get _canManageReports =>
      AuthSession.isAdmin || widget.business['canManageReports'] == true;

  bool _continueFromHistory = false;
  List<dynamic> _historyReports = <dynamic>[];
  static const previewPageNames = <String>[
    'Client Monthly Report (Cover Page)',
    'Channel Summary',
    'Google Business Profile',
    'Google Business Profile Dashboard',
    'Google Ads',
    'Google Ads Dashboard',
    'YouTube',
    'YouTube Dashboard',
    'Google Analytics Dashboard',
    'Google Search Console Dashboard',
    'Facebook',
    'Facebook Dashboard',
    'Meta Ads',
    'Meta Ads Dashboard',
    'Instagram',
    'Instagram Dashboard',
    'LinkedIn',
    'LinkedIn Dashboard',
    'LinkedIn Ads',
    'LinkedIn Ads Dashboard',
    'Twitter / X',
    'Twitter / X Dashboard',
    'Creatives Published',
    'Creative Showcase',
    'Next Month Plan',
  ];
  static const providers = <String>[
    'Google Business Profile Dashboard',
    'Google Business Profile Ranking by GMB Dashboard',
    'Google Ads Dashboard',
    'Google Analytics Dashboard',
    'Google Search Console Dashboard',
    'YouTube Dashboard',
    'Facebook Dashboard',
    'Meta Ads Dashboard',
    'Instagram Dashboard',
    'LinkedIn Dashboard',
    'LinkedIn Ads Dashboard',
    'Twitter Dashboard',
    'Creatives Published',
    'Creative Showcase',
    'Next Month Plan',
  ];
  static const _needsProvider = 'Needs provider';
  static const creativeShowcaseSlots = <String>[
    'Poster 1',
    'Poster 2',
    'Poster 3',
    'Poster 4',
    'Video 1',
    'Video 2',
    'Video 3',
    'Video 4',
  ];
  static const labels = <String, String>{
    'search_impressions': 'Search impressions',
    'maps_impressions': 'Maps impressions',
    'calls': 'Calls',
    'website_clicks': 'Website clicks',
    'est_conversion_leads': 'Est. conversion leads',
    'bookings': 'Bookings',
    'posts_published': 'Posts published',
    'photos_added': 'Photos added',
    'new_reviews': 'New reviews',
    'review_replies': 'Review replies',
    'top_search_keyword': 'Top search keyword',
    'searches': 'Searches',
    'optimization_done': 'Optimization done',
    'impressions': 'Impressions',
    'clicks': 'Clicks',
    'cost': 'Cost',
    'spend': 'Spend',
    'conversions': 'Conversions',
    'ctr': 'CTR',
    'cpc': 'CPC',
    'watch_time': 'Watch time',
    'subscribers': 'Subscribers',
    'likes': 'Likes',
    'comments': 'Comments',
    'reach': 'Reach',
    'engagements': 'Engagements',
    'followers': 'Followers',
    'link_clicks': 'Link clicks',
    'leads': 'Leads',
    'profile_visits': 'Profile visits',
    'active_users': 'Active users',
    'new_users': 'New users',
    'sessions': 'Sessions',
    'engaged_sessions': 'Engaged sessions',
    'engagement_rate': 'Engagement rate',
    'event_count': 'Event count',
    'total_revenue': 'Total revenue',
    'average_ctr': 'Average CTR',
    'average_position': 'Average position',
  };
  static const providerFields = <String, List<String>>{
    'Google Business Profile Dashboard': [
      'search_impressions',
      'maps_impressions',
      'calls',
      'website_clicks',
      'est_conversion_leads',
      'bookings',
      'posts_published',
      'photos_added',
      'new_reviews',
      'review_replies',
    ],
    'Google Business Profile Ranking by GMB Dashboard': [
      'top_search_keyword',
      'searches',
      'optimization_done',
    ],
    'Google Ads Dashboard': [
      'active_campaigns',
      'impressions',
      'clicks',
      'ctr',
      'spend',
      'conversions_leads',
      'cost_per_lead',
      'calls',
      'keywords_optimized',
      'campaign',
      'impr',
      'conv',
      'cpl',
    ],
    'YouTube Dashboard': [
      'subscribers',
      'new_subscribers',
      'impressions',
      'impression_ctr',
      'watch_time_hours',
      'avg_view_duration',
      'videos_published',
      'shorts_published',
      'likes_shares',
      'top_video_views',
      'insights_next_actions',
    ],
    'Facebook Dashboard': [
      'page_followers',
      'new_followers',
      'impressions_reach_views',
      'engagement',
      'posts_published',
      'videos_reels',
      'stories',
      'insights_next_actions',
    ],
    'Meta Ads Dashboard': [
      'active_campaigns',
      'reach_impressions',
      'frequency',
      'est_conversion_leads',
      'ctr',
      'cpm',
      'spend',
      'leads',
      'cost_per_lead',
      'whatsapp_messages',
      'video_views',
      'campaign_ad_set',
      'clicks',
      'cpl',
    ],
    'Instagram Dashboard': [
      'followers',
      'new_followers',
      'impressions_reach_views',
      'engagement',
      'posts_published',
      'reels_published',
      'stories',
      'insights_next_actions',
    ],
    'LinkedIn Dashboard': [
      'followers',
      'new_followers',
      'impressions',
      'engagement_rate',
      'reposts',
      'clicks',
      'posts_published',
      'insights_next_actions',
    ],
    'LinkedIn Ads Dashboard': [
      'active_campaigns',
      'leads',
      'impressions',
      'cost_per_lead',
      'clicks',
      'est_conversion_leads',
      'ctr',
      'engagements',
      'avg_cpc',
      'video_views',
      'cpm',
      'spend',
      'campaign_group_campaign',
      'impr',
      'conv',
      'cpl',
    ],
    'Google Analytics Dashboard': [
      'active_users',
      'new_users',
      'sessions',
      'engaged_sessions',
      'engagement_rate',
      'conversions',
      'event_count',
      'total_revenue',
    ],
    'Google Search Console Dashboard': [
      'clicks',
      'impressions',
      'average_ctr',
      'average_position',
    ],
    'Twitter Dashboard': [
      'followers',
      'posts_published',
      'new_followers',
      'impressions',
      'engagement_rate',
      'engagements',
      'profile_visits',
      'link_clicks',
      'insights_next_actions',
    ],
    'Creatives Published': [
      'posters_static_posts',
      'posters_static_posts_vs_last_month',
      'carousels',
      'carousels_vs_last_month',
      'reels_short_videos',
      'reels_short_videos_vs_last_month',
      'long_videos',
      'long_videos_vs_last_month',
      'ad_creatives',
      'ad_creatives_vs_last_month',
      'stories',
      'stories_vs_last_month',
      'best_creative_platform',
      'best_creative_reach_views',
      'best_creative_engagement',
    ],
    // Showcase entries are image slots in the PowerPoint template, not data fields.
    'Creative Showcase': [],
    'Next Month Plan': [
      'gmb_gbp_action',
      'google_ads_action',
      'meta_ads_action',
      'linkedin_ads_action',
      'instagram_action',
      'facebook_action',
      'youtube_action',
      'linkedin_organic_action',
      'twitter_x_action',
      'creatives_action',
      'approvals_inputs',
      'remarks',
    ],
  };
  // A dashboard image unlocks its exact report-template pages. Values never
  // sit under the image page unless that page itself is a dashboard table.
  static const previewPagesForDashboard = <String, List<String>>{
    'Google Business Profile Dashboard': [
      'Google Business Profile',
      'Google Business Profile Dashboard',
    ],
    'Google Business Profile Ranking by GMB Dashboard': [
      'Google Business Profile Ranking by GMB Dashboard',
    ],
    'Google Ads Dashboard': ['Google Ads', 'Google Ads Dashboard'],
    'Google Analytics Dashboard': ['Google Analytics Dashboard'],
    'Google Search Console Dashboard': ['Google Search Console Dashboard'],
    'YouTube Dashboard': ['YouTube', 'YouTube Dashboard'],
    'Facebook Dashboard': ['Facebook', 'Facebook Dashboard'],
    'Meta Ads Dashboard': ['Meta Ads', 'Meta Ads Dashboard'],
    'Instagram Dashboard': ['Instagram', 'Instagram Dashboard'],
    'LinkedIn Dashboard': ['LinkedIn', 'LinkedIn Dashboard'],
    'LinkedIn Ads Dashboard': ['LinkedIn Ads', 'LinkedIn Ads Dashboard'],
    'Twitter Dashboard': ['Twitter / X', 'Twitter / X Dashboard'],
    'Creatives Published': ['Creatives Published'],
    'Creative Showcase': ['Creative Showcase'],
    'Next Month Plan': ['Next Month Plan'],
  };
  // These pages are the core report input areas. They must remain available
  // for manual entry even when a client did not supply a dashboard image.
  // Export filtering still omits every provider that has no entered value.
  static const mandatoryPreviewPages = <String>[
    'Channel Summary',
    'Creatives Published',
    'Creative Showcase',
    'Next Month Plan',
  ];
  static const previewPageFields = <String, List<String>>{
    'Client Monthly Report (Cover Page)': [
      'client_brand',
      'report_month',
      'date_range',
      'prepared_by',
    ],
    'Channel Summary': [
      'gmb_impressions',
      'gmb_clicks',
      'gmb_leads_calls',
      'gmb_spend',
      'gmb_estimated_conversion_leads',
      'google_ads_impressions',
      'google_ads_clicks',
      'google_ads_leads_calls',
      'google_ads_spend',
      'google_ads_estimated_conversion_leads',
      'meta_ads_impressions',
      'meta_ads_clicks',
      'meta_ads_leads_calls',
      'meta_ads_spend',
      'meta_ads_estimated_conversion_leads',
      'linkedin_ads_impressions',
      'linkedin_ads_clicks',
      'linkedin_ads_leads_calls',
      'linkedin_ads_spend',
      'linkedin_ads_estimated_conversion_leads',
      'instagram_impressions',
      'instagram_clicks',
      'instagram_leads_calls',
      'instagram_spend',
      'instagram_estimated_conversion_leads',
      'facebook_impressions',
      'facebook_clicks',
      'facebook_leads_calls',
      'facebook_spend',
      'facebook_estimated_conversion_leads',
      'youtube_impressions',
      'youtube_clicks',
      'youtube_leads_calls',
      'youtube_spend',
      'youtube_estimated_conversion_leads',
      'linkedin_organic_impressions',
      'linkedin_organic_clicks',
      'linkedin_organic_leads_calls',
      'linkedin_organic_spend',
      'linkedin_organic_estimated_conversion_leads',
      'twitter_x_impressions',
      'twitter_x_clicks',
      'twitter_x_leads_calls',
      'twitter_x_spend',
      'twitter_x_estimated_conversion_leads',
    ],
    'Google Business Profile': [
      'search_impressions',
      'maps_impressions',
      'calls',
      'website_clicks',
      'est_conversion_leads',
      'bookings',
      'posts_published',
      'photos_added',
      'new_reviews',
      'review_replies',
    ],
    'Google Business Profile Dashboard': [
      'top_search_keyword_1',
      'searches_1',
      'optimization_done_1',
      'top_search_keyword_2',
      'searches_2',
      'optimization_done_2',
      'top_search_keyword_3',
      'searches_3',
      'optimization_done_3',
      'top_search_keyword_4',
      'searches_4',
      'optimization_done_4',
      'top_search_keyword_5',
      'searches_5',
      'optimization_done_5',
      'top_search_keyword_6',
      'searches_6',
      'optimization_done_6',
    ],
    'Google Ads': [
      'active_campaigns',
      'impressions',
      'clicks',
      'ctr',
      'spend',
      'conversions_leads',
      'cost_per_lead',
      'avg_cpc',
      'calls',
      'keywords_optimized',
    ],
    'Google Ads Dashboard': [
      'campaign',
      'impr',
      'clicks',
      'conv',
      'spend',
      'cpl',
    ],
    'YouTube': [
      'subscribers',
      'new_subscribers',
      'impressions',
      'impression_ctr',
      'watch_time_hours',
      'avg_view_duration',
      'videos_published',
      'shorts_published',
      'likes_shares',
      'top_video_views',
    ],
    'YouTube Dashboard': ['insights_next_actions'],
    'Facebook': [
      'page_followers',
      'new_followers',
      'impressions_reach_views',
      'three_second_views',
      'one_minute_views',
      'watch_time',
      'engagement',
      'posts_published',
      'videos_reels',
      'stories',
    ],
    'Facebook Dashboard': ['insights_next_actions'],
    'Meta Ads': [
      'active_campaigns',
      'reach_impressions',
      'frequency',
      'est_conversion_leads',
      'ctr',
      'cpm',
      'spend',
      'leads',
      'cost_per_lead',
      'whatsapp_messages',
      'video_views',
    ],
    'Meta Ads Dashboard': [
      'campaign_ad_set',
      'reach',
      'clicks',
      'leads',
      'spend',
      'cpl',
    ],
    'Instagram': [
      'followers',
      'new_followers',
      'views',
      'interactions',
      'accounts_engaged',
      'followers_percentage',
      'non_followers_percentage',
      'impressions_reach_views',
      'engagement',
      'posts_published',
      'reels_published',
      'stories',
    ],
    'Instagram Dashboard': ['insights_next_actions'],
    'LinkedIn': [
      'followers',
      'new_followers',
      'impressions',
      'engagement_rate',
      'reposts',
      'clicks',
      'posts_published',
    ],
    'LinkedIn Dashboard': ['insights_next_actions'],
    'LinkedIn Ads': [
      'active_campaigns',
      'leads',
      'impressions',
      'cost_per_lead',
      'clicks',
      'est_conversion_leads',
      'ctr',
      'engagements',
      'avg_cpc',
      'video_views',
      'cpm',
      'spend',
    ],
    'LinkedIn Ads Dashboard': [
      'campaign_group_campaign',
      'impr',
      'clicks',
      'leads',
      'spend',
      'cpl',
    ],
    'Google Analytics Dashboard': [
      'active_users',
      'new_users',
      'sessions',
      'engaged_sessions',
      'engagement_rate',
      'conversions',
      'event_count',
      'total_revenue',
    ],
    'Google Search Console Dashboard': [
      'clicks',
      'impressions',
      'average_ctr',
      'average_position',
    ],
    'Twitter / X': [
      'followers',
      'posts_published',
      'new_followers',
      'impressions',
      'engagement_rate',
      'engagements',
      'profile_visits',
      'link_clicks',
    ],
    'Twitter / X Dashboard': ['insights_next_actions'],
    'Creatives Published': [
      'posters_static_posts',
      'posters_static_posts_vs_last_month',
      'carousels',
      'carousels_vs_last_month',
      'reels_short_videos',
      'reels_short_videos_vs_last_month',
      'long_videos',
      'long_videos_vs_last_month',
      'ad_creatives',
      'ad_creatives_vs_last_month',
      'stories',
      'stories_vs_last_month',
      'best_creative_platform',
      'best_creative_reach_views',
      'best_creative_engagement',
    ],
    'Next Month Plan': [
      'gmb_gbp_action',
      'gmb_gbp_owner',
      'gmb_gbp_due',
      'google_ads_action',
      'google_ads_owner',
      'google_ads_due',
      'meta_ads_action',
      'meta_ads_owner',
      'meta_ads_due',
      'linkedin_ads_action',
      'linkedin_ads_owner',
      'linkedin_ads_due',
      'instagram_action',
      'instagram_owner',
      'instagram_due',
      'facebook_action',
      'facebook_owner',
      'facebook_due',
      'youtube_action',
      'youtube_owner',
      'youtube_due',
      'linkedin_organic_action',
      'linkedin_organic_owner',
      'linkedin_organic_due',
      'twitter_x_action',
      'twitter_x_owner',
      'twitter_x_due',
      'creatives_action',
      'creatives_owner',
      'creatives_due',
      'approvals_inputs',
      'remarks',
    ],
  };
  static String get apiBaseUrl => ApiConfig.baseUrl;
  final picker = ImagePicker();
  final Map<String, List<XFile>> uploads = {};
  final Map<String, XFile> creativeShowcaseUploads = {};
  final Map<String, Map<String, String>> metrics = {};
  final Map<String, Map<String, String>> ocrMetrics = {};
  final Map<String, Set<String>> hiddenFields = {};
  final Map<String, Set<String>> manualFields = {};
  final Map<String, String> notes = {};
  final Map<String, String> coverEdits = {};
  final Set<XFile> manuallyAssignedImages = <XFile>{};
  // Table dashboard pages start with one row. Employees add further rows only
  // when they need them; the template itself allows up to six.
  final Map<String, int> visibleTableRows = {};
  final reportService = const FullReportService();
  bool review = false, extracting = false;
  // Preview/Edit view mode: false = form fields, true = the visual template
  // card layout (the PDF look) with inline-editable values.
  bool _templateView = true;
  String? extractingProvider;
  String _selectedCreativeShowcaseSlot = 'Poster 1';

  // Mandatory, non-provider sections that always appear regardless of what the
  // admin assigned.
  static const _alwaysShownSections = <String>{
    'Creatives Published',
    'Creative Showcase',
    'Next Month Plan',
  };

  // Provider dashboards the admin assigned to this client (step 3/8: only
  // assigned providers). Derived from business['assignedTasks'] — each entry's
  // platform name is mapped to a dashboard section.
  Set<String> get _assignedProviderDashboards {
    final tasks = widget.business['assignedTasks'];
    final result = <String>{};
    if (tasks is List) {
      for (final task in tasks) {
        final name = task is Map
            ? (task['task']?.toString() ?? '')
            : task.toString();
        final mapped = _providerForDetection(name);
        if (mapped != null) result.add(mapped);
      }
    }
    return result;
  }

  // Providers shown as upload areas. Restricted to the admin-assigned providers
  // when any are recognized; otherwise falls back to all providers so the
  // workflow is never blocked by an unmapped assignment.
  List<String> get _visibleProviders {
    final assigned = _assignedProviderDashboards;
    if (assigned.isEmpty) return providers;
    return providers
        .where((p) => assigned.contains(p) || _alwaysShownSections.contains(p))
        .toList();
  }

  List<String> get _dashboardProviders => _visibleProviders
      .where((provider) => !_alwaysShownSections.contains(provider))
      .toList();

  List<String> get _uploadProviderSections => <String>[
    ..._visibleProviders,
    if (uploads[_needsProvider]?.isNotEmpty == true) _needsProvider,
  ];

  String? _providerForDetection(dynamic detected) {
    final value = (detected?.toString() ?? '').toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    if (value.isEmpty) return null;
    if (value.contains('googlebusinessprofile') ||
        value == 'gbp' ||
        value.contains('googlemybusiness')) {
      return 'Google Business Profile Dashboard';
    }
    if (value.contains('googlesearchconsole') || value == 'gsc') {
      return 'Google Search Console Dashboard';
    }
    if (value.contains('googleanalytics') || value == 'ga4') {
      return 'Google Analytics Dashboard';
    }
    if (value.contains('googleads') || value.contains('adwords')) {
      return 'Google Ads Dashboard';
    }
    if (value.contains('metaads')) return 'Meta Ads Dashboard';
    if (value.contains('linkedinads')) return 'LinkedIn Ads Dashboard';
    if (value.contains('linkedin')) return 'LinkedIn Dashboard';
    if (value.contains('instagram')) return 'Instagram Dashboard';
    if (value.contains('facebook')) return 'Facebook Dashboard';
    if (value.contains('youtube')) return 'YouTube Dashboard';
    if (value.contains('twitter') ||
        value == 'x' ||
        value.contains('xanalytics')) {
      return 'Twitter Dashboard';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final reports = widget.business['existingReports'];
    if (reports is List) _historyReports = List<dynamic>.from(reports);
  }

  Future<void> _refreshHistory() async {
    // Report history is an optional feature; if its backend route is not
    // available, a failed refresh must never turn a successful download into
    // an error. Swallow the failure and keep any previously loaded list.
    try {
      _historyReports = await reportService.clientReportHistory(
        companyName: widget.business['name']?.toString() ?? 'Client',
      );
    } catch (_) {
      // Leave _historyReports unchanged.
    }
  }

  void _removeDashboardImage(String provider, int index) {
    setState(() {
      final items = uploads[provider];
      if (items == null || index < 0 || index >= items.length) return;
      manuallyAssignedImages.remove(items.removeAt(index));
      if (items.isEmpty) uploads.remove(provider);
    });
  }

  // Opens an uploaded screenshot full-screen so the employee can read it when
  // OCR could not identify or extract the provider, then pick the provider
  // manually from the dropdown.
  Future<void> _viewScreenshot(XFile file) async {
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              automaticallyImplyLeading: false,
              title: Text(file.name, overflow: TextOverflow.ellipsis),
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF142F61),
              actions: [
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ],
            ),
            Flexible(
              child: InteractiveViewer(
                maxScale: 5,
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _replaceDashboardImage(String provider, int index) async {
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (!mounted || file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final validation = DashboardImageValidation.check(bytes);
    final message = switch (validation.issue) {
      DashboardImageValidationIssue.tooSmall =>
        'Please re-upload an image that is at least 1 MB.',
      DashboardImageValidationIssue.tooLarge =>
        'Each dashboard image must be 10 MB or smaller.',
      DashboardImageValidationIssue.unsupported =>
        'Upload a JPEG, PNG, or WebP image.',
      null => null,
    };
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    setState(() {
      final items = uploads[provider];
      if (items == null || index < 0 || index >= items.length) return;
      final wasManuallyAssigned = manuallyAssignedImages.remove(items[index]);
      items[index] = file;
      if (wasManuallyAssigned) manuallyAssignedImages.add(file);
    });
  }

  void _moveDashboardImage(
    String source,
    String destination,
    int index, {
    bool manual = true,
  }) {
    if (source == destination) return;
    setState(() {
      final items = uploads[source];
      if (items == null || index < 0 || index >= items.length) return;
      final image = items.removeAt(index);
      if (items.isEmpty) uploads.remove(source);
      uploads.update(
        destination,
        (existing) => [...existing, image],
        ifAbsent: () => [image],
      );
      if (manual) {
        manuallyAssignedImages.add(image);
      } else {
        manuallyAssignedImages.remove(image);
      }
    });
  }

  Future<void> _uploadTemplate() async {
    final selected = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pptx'],
      withData: true,
    );
    final file = selected?.files.single;
    if (file?.bytes == null || file == null) return;
    try {
      await reportService.uploadSharedReportTemplate(file.bytes!, file.name);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shared report template saved.')),
        );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _addManualField(String provider, String source) async {
    final name = TextEditingController();
    final value = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add field'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Field name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: value,
              decoration: const InputDecoration(
                labelText: 'Value',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, name.text.trim().isNotEmpty),
            child: const Text('Add field'),
          ),
        ],
      ),
    );
    if (result == true && mounted)
      setState(() {
        final field = name.text.trim();
        manualFields.putIfAbsent(provider, () => <String>{}).add(field);
        metrics.putIfAbsent(source, () => <String, String>{})[field] =
            value.text;
      });
    name.dispose();
    value.dispose();
  }

  Future<void> add(String provider) async {
    // Preserve dashboard text for OCR. Resizing/compressing a dense dashboard
    // can make small labels unreadable even when the source image is HD.
    final files = await picker.pickMultiImage();
    if (!mounted || files.isEmpty) return;
    final accepted = <XFile>[];
    var rejectedTooSmall = 0;
    var rejectedTooLarge = 0;
    var rejectedUnsupported = 0;
    for (final file in files) {
      final validation = DashboardImageValidation.check(
        await file.readAsBytes(),
      );
      if (validation.isValid) {
        accepted.add(file);
      } else if (validation.issue == DashboardImageValidationIssue.tooSmall) {
        rejectedTooSmall += 1;
      } else if (validation.issue == DashboardImageValidationIssue.tooLarge) {
        rejectedTooLarge += 1;
      } else {
        rejectedUnsupported += 1;
      }
    }
    if (mounted &&
        (rejectedTooSmall > 0 ||
            rejectedTooLarge > 0 ||
            rejectedUnsupported > 0)) {
      final notices = <String>[
        if (rejectedTooSmall > 0)
          'Please re-upload images that are at least 1 MB.',
        if (rejectedTooLarge > 0)
          'Each dashboard image must be 10 MB or smaller.',
        if (rejectedUnsupported > 0) 'Unsupported image files were not added.',
      ];
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(notices.join(' '))));
    }
    if (accepted.isNotEmpty)
      setState(
        () => uploads.update(
          provider,
          (items) => [...items, ...accepted],
          ifAbsent: () => accepted,
        ),
      );
  }

  Future<void> addCreativeShowcaseImage(String slot) async {
    if (creativeShowcaseUploads.containsKey(slot)) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Image already uploaded'),
          content: Text(
            '$slot already has an image. Do you want to replace it?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Replace image'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (!mounted || file == null) return;
    final validation = DashboardImageValidation.check(await file.readAsBytes());
    final message = switch (validation.issue) {
      DashboardImageValidationIssue.tooSmall =>
        'Please re-upload an image that is at least 1 MB.',
      DashboardImageValidationIssue.tooLarge =>
        'Each creative showcase image must be 10 MB or smaller.',
      DashboardImageValidationIssue.unsupported =>
        'Upload a JPEG, PNG, or WebP image.',
      null => null,
    };
    if (message != null) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    setState(() => creativeShowcaseUploads[slot] = file);
  }

  Future<Map<String, dynamic>> _readDashboardImage(
    XFile file,
    String provider,
  ) async {
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/dashboard-ocr/read'),
          headers: {
            'Authorization': 'Bearer ${AuthSession.requireToken()}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'provider': provider,
            'images': [
              {
                'base64': base64Encode(await file.readAsBytes()),
                'mimeType': file.mimeType ?? 'image/jpeg',
              },
            ],
          }),
        )
        .timeout(const Duration(seconds: 75));
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    final body = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['success'] != true) {
      throw Exception(
        body['message']?.toString() ??
            'The dashboard-reading service did not return data.',
      );
    }
    return body;
  }

  // Brand logo for a dashboard-page provider name, or null when unknown.
  Widget? _providerLogo(String provider, {double size = 22}) {
    final match = providerByDashboardPage(provider);
    if (match == null) return null;
    return ProviderLogo(provider: match, size: size);
  }

  // Single multi-file upload: screenshots stage in "Needs provider", then
  // "Continue to preview" runs OCR to detect each provider and place it.
  Future<void> _uploadScreenshots() => add(_needsProvider);

  Widget _uploadBanner() {
    final assigned = _dashboardProviders
        .map((p) => providerByDashboardPage(p))
        .whereType<ReportProvider>()
        .toList();
    final staged = uploads[_needsProvider]?.length ?? 0;
    ImageProvider<Object>? clientLogo;
    try {
      final encoded =
          (widget.business['companyLogoBase64'] ??
                  widget.business['logoBase64'])
              ?.toString();
      if (encoded != null && encoded.isNotEmpty) {
        clientLogo = MemoryImage(base64Decode(encoded));
      }
    } catch (_) {}

    final handlerGroups = <String, Map<String, dynamic>>{};
    void addHandler(
      dynamic roleValue,
      dynamic employeeValue,
      dynamic taskValue,
    ) {
      final role = roleValue?.toString().toLowerCase() ?? '';
      final isPageHandler = role.contains('page');
      final isAdsHandler = role.contains('ads');
      if (!isPageHandler && !isAdsHandler) return;

      final roleLabel = isPageHandler ? 'Page Handler' : 'Ads Handler';
      final employee = employeeValue?.toString().trim() ?? '';
      final group = handlerGroups.putIfAbsent(
        roleLabel.toLowerCase(),
        () => {'role': roleLabel, 'employees': <String>{}, 'tasks': <String>{}},
      );
      if (employee.isNotEmpty) {
        (group['employees'] as Set<String>).add(employee);
      }
      final task = taskValue?.toString().trim() ?? '';
      if (task.isNotEmpty) (group['tasks'] as Set<String>).add(task);
    }

    for (final rawHandler
        in (widget.business['assignedHandlers'] as List? ?? const [])
            .whereType<Map>()) {
      addHandler(
        '${rawHandler['role_key'] ?? ''} ${rawHandler['role'] ?? ''}',
        rawHandler['employee'] ?? rawHandler['employeeName'],
        rawHandler['task'] ?? rawHandler['name'],
      );
    }
    for (final rawTask
        in (widget.business['assignedTasks'] as List? ?? const [])
            .whereType<Map>()) {
      addHandler(
        '${rawTask['role_key'] ?? ''} ${rawTask['role'] ?? ''}',
        rawTask['employee'] ?? rawTask['employeeName'],
        rawTask['name'] ?? rawTask['task'] ?? rawTask['deliverables'],
      );
    }

    final month = widget.business['reportMonth']?.toString() ?? '';
    final year = widget.business['reportYear']?.toString() ?? '';
    final period = '$month / $year';
    final clientName = widget.business['name']?.toString() ?? 'Client';
    final initial = clientName.isEmpty ? 'C' : clientName[0].toUpperCase();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xffdbe7f8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120b2850),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 5,
            decoration: const BoxDecoration(
              gradient: ReportBrand.brandGradient,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xfff1f6ff),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xffdbe7f8)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: clientLogo == null
                          ? Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: ReportBrand.blue,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            )
                          : Image(image: clientLogo, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CLIENT REPORT',
                            style: TextStyle(
                              color: ReportBrand.mutedOnLight,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            clientName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ReportBrand.navy,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Tooltip(
                      message: 'GoDigital Reports',
                      child: GoDigitalLogo(size: 38, radius: 11, padding: 5),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xfff2f7ff), Color(0xffeaf2ff)],
                    ),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: const Color(0xffe0eafa)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        color: ReportBrand.blue,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Reporting period  $period',
                          style: const TextStyle(
                            color: ReportBrand.navy,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'PAGE & ADS HANDLERS',
                  style: TextStyle(
                    color: ReportBrand.mutedOnLight,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .9,
                  ),
                ),
                const SizedBox(height: 7),
                if (handlerGroups.isEmpty)
                  const Text(
                    'No Page or Ads Handler assignments',
                    style: TextStyle(
                      color: ReportBrand.mutedOnLight,
                      fontSize: 11,
                    ),
                  )
                else
                  for (final group in handlerGroups.values)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 7),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: group['role'] == 'Page Handler'
                            ? const Color(0xfff0f6ff)
                            : const Color(0xfffff6ea),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: group['role'] == 'Page Handler'
                              ? const Color(0xffd6e6ff)
                              : const Color(0xffffe5c4),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            group['role'] == 'Page Handler'
                                ? Icons.web_rounded
                                : Icons.campaign_rounded,
                            size: 16,
                            color: group['role'] == 'Page Handler'
                                ? const Color(0xff1769d2)
                                : const Color(0xffbd6900),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${group['role']} · '
                                  '${(group['employees'] as Set<String>).isEmpty ? 'Unassigned' : (group['employees'] as Set<String>).join(', ')}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: ReportBrand.navy,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if ((group['tasks'] as Set<String>).isNotEmpty)
                                  Text(
                                    (group['tasks'] as Set<String>).join(' • '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: ReportBrand.mutedOnLight,
                                      fontSize: 10,
                                      height: 1.3,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                if (assigned.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  const Text(
                    'ASSIGNED PLATFORMS',
                    style: TextStyle(
                      color: ReportBrand.mutedOnLight,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .9,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: assigned
                        .map(
                          (provider) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: provider.color.withValues(alpha: .09),
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: provider.color.withValues(alpha: .35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ProviderLogo(provider: provider, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  provider.label,
                                  style: TextStyle(
                                    color: provider.color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: const Color(0xfff7faff),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: const Color(0xffe5edf9)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 17,
                        color: ReportBrand.blue,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Upload screenshots to add dashboard data. You can review and edit detected values before continuing.',
                          style: TextStyle(
                            color: ReportBrand.mutedOnLight,
                            fontSize: 10.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: ReportBrand.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: extracting ? null : _uploadScreenshots,
                    icon: const Icon(Icons.cloud_upload_rounded, size: 19),
                    label: const Text(
                      'Upload screenshots',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                if (staged > 0) ...[
                  const SizedBox(height: 9),
                  Center(
                    child: Text(
                      '$staged screenshot${staged == 1 ? '' : 's'} awaiting detection',
                      style: const TextStyle(
                        color: ReportBrand.mutedOnLight,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> extractAndPreview() async {
    final active = uploads.entries
        .where(
          (item) => item.key != 'Creative Showcase' && item.value.isNotEmpty,
        )
        .toList();
    setState(() => extracting = true);
    final failures = <String>[];
    final failureReasons = <String, String>{};
    for (final entry in active) {
      for (final file in List<XFile>.from(entry.value)) {
        if (mounted) setState(() => extractingProvider = entry.key);
        try {
          var selectedProvider = entry.key;
          // Single-upload flow: screenshots land in the "Needs provider" bucket
          // and are read with no hint so Google Vision identifies the provider,
          // then the image is moved into that provider's dashboard area.
          var body = await _readDashboardImage(
            file,
            entry.key == _needsProvider ? '' : selectedProvider,
          );
          final detectedProvider = _providerForDetection(
            body['detected_provider'],
          );
          if (manuallyAssignedImages.contains(file)) {
            selectedProvider = entry.key;
          } else if (detectedProvider == null) {
            final index = uploads[entry.key]?.indexOf(file) ?? -1;
            if (index >= 0) {
              _moveDashboardImage(
                entry.key,
                _needsProvider,
                index,
                manual: false,
              );
            }
            failures.add(file.name);
            failureReasons[file.name] =
                'Provider not recognized. Choose its provider from the dropdown.';
            continue;
          } else {
            selectedProvider = detectedProvider;
          }

          if (selectedProvider != entry.key) {
            final index = uploads[entry.key]?.indexOf(file) ?? -1;
            if (index >= 0) {
              _moveDashboardImage(
                entry.key,
                selectedProvider,
                index,
                manual: false,
              );
            }
            body = await _readDashboardImage(file, selectedProvider);
          }

          final raw = body['metrics'];
          final extracted = raw is Map
              ? raw.map<String, String>(
                  (key, value) => MapEntry(key.toString(), value.toString()),
                )
              : <String, String>{};
          metrics[selectedProvider] = {
            ...?metrics[selectedProvider],
            ...extracted,
          };
          ocrMetrics[selectedProvider] = {
            ...?ocrMetrics[selectedProvider],
            ...extracted,
          };
          final rawText = body['raw_text']?.toString() ?? '';
          if (rawText.isNotEmpty) {
            notes[selectedProvider] = [
              if ((notes[selectedProvider] ?? '').isNotEmpty)
                notes[selectedProvider],
              rawText,
            ].whereType<String>().join('\n');
          }
        } catch (error) {
          failures.add(file.name);
          failureReasons[file.name] = error.toString();
        }
      }
    }
    if (!mounted) return;
    if (uploads[_needsProvider]?.isNotEmpty == true) {
      setState(() {
        extracting = false;
        extractingProvider = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a provider for every unrecognized screenshot.'),
        ),
      );
      return;
    }
    setState(() {
      extracting = false;
      extractingProvider = null;
      review = failures.isEmpty;
    });
    if (failures.isNotEmpty && mounted) {
      final continueToPreview = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Upload a clearer dashboard image'),
          content: Text(
            'We could not read ${failures.join(', ')}. ${failureReasons.values.isEmpty ? '' : failureReasons.values.first}\n\nUpload a clearer dashboard image, or continue to Preview/Edit and complete the report values there.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Upload new image'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Continue to preview'),
            ),
          ],
        ),
      );
      if (continueToPreview == true && mounted) setState(() => review = true);
    }
  }

  /// Validates and assembles the full report payload shared by download and
  /// "Pass report" (approval submission). Returns null if the user aborts.
  Future<Map<String, dynamic>?> _assembleReportPayload() async {
    final changedValues = <String>[];
    for (final entry in ocrMetrics.entries) {
      final edited = metrics[entry.key] ?? const <String, String>{};
      for (final field in entry.value.keys) {
        final originalValue = entry.value[field]?.trim() ?? '';
        final previewValue = edited[field]?.trim() ?? '';
        if (originalValue != previewValue) {
          changedValues.add('${entry.key}: ${field.replaceAll('_', ' ')}');
        }
      }
    }
    if (changedValues.isNotEmpty && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Preview values changed'),
          content: Text(
            'These values no longer match the uploaded image OCR: ${changedValues.take(8).join(', ')}${changedValues.length > 8 ? ' and more' : ''}. Continue with the edited Preview/Edit values?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Go back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Use edited values'),
            ),
          ],
        ),
      );
      if (proceed != true) return null;
    }
    final now = DateTime.now();
    final businessId =
        widget.business['id'] ?? widget.business['businessId'] ?? 0;
    String providerName(String value) {
      final name = value.toUpperCase().replaceAll(' DASHBOARD', '');
      if (name.contains('RANKING BY GMB')) return 'LOCAL_SEO';
      if (name.contains('GOOGLE ANALYTICS')) return 'GOOGLE_ANALYTICS';
      if (name.contains('GOOGLE SEARCH CONSOLE'))
        return 'GOOGLE_SEARCH_CONSOLE';
      if (name == 'META ADS') return 'META_ADS';
      if (name == 'LINKEDIN ADS') return 'LINKEDIN_ADS';
      return name.replaceAll(' ', '_');
    }

    final populated = metrics.entries
        .where(
          (entry) => entry.value.values.any((value) => value.trim().isNotEmpty),
        )
        .toList();
    if (populated.isEmpty &&
        uploads.values.every((images) => images.isEmpty) &&
        creativeShowcaseUploads.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Enter at least one report value or add a dashboard image before downloading.',
            ),
          ),
        );
      return null;
    }
    final screenshots = <Map<String, String>>[];
    for (final entry in uploads.entries) {
      // These uploads are OCR sources only. Their template pages have no
      // image placeholder, so never export their original screenshots.
      if (entry.key == 'Creatives Published' || entry.key == 'Next Month Plan')
        continue;
      for (final image in entry.value) {
        screenshots.add(<String, String>{
          'provider': providerName(entry.key),
          'bytesBase64': base64Encode(await image.readAsBytes()),
          'mimeType': image.mimeType ?? 'image/jpeg',
        });
      }
    }
    for (final slot in creativeShowcaseSlots) {
      final image = creativeShowcaseUploads[slot];
      if (image == null) continue;
      screenshots.add(<String, String>{
        'provider': 'CREATIVE_SHOWCASE',
        'slot': slot,
        'bytesBase64': base64Encode(await image.readAsBytes()),
        'mimeType': image.mimeType ?? 'image/jpeg',
      });
    }
    // A dashboard image is report content in its own right. Keep its provider
    // in the request even when OCR could not extract any editable metrics;
    // otherwise the template filter would remove the dashboard page before
    // the image can be placed on it.
    final includedProviders = <String>{
      ...populated.map((entry) => providerName(entry.key)),
      ...uploads.entries
          .where(
            (entry) =>
                entry.key != 'Creatives Published' &&
                entry.key != 'Next Month Plan' &&
                entry.value.isNotEmpty,
          )
          .map((entry) => providerName(entry.key)),
      if (creativeShowcaseUploads.isNotEmpty) 'CREATIVE_SHOWCASE',
    };
    const insightSlides = <String, int>{
      'YouTube Dashboard': 11,
      'Facebook Dashboard': 13,
      'Instagram Dashboard': 18,
      'LinkedIn Dashboard': 20,
      'Twitter Dashboard': 25,
    };
    final slideEdits = <String, Map<String, String>>{};
    for (final entry in insightSlides.entries) {
      final insight =
          metrics[entry.key]?['insights_next_actions']?.trim() ?? '';
      if (insight.isNotEmpty) {
        slideEdits[entry.value.toString()] = {
          'Insights & next actions': insight,
        };
      }
    }
    // The dashboard-table pages have six editable rows. Preserve only cells
    // the employee actually filled, so blank rows stay blank in the export.
    void addTableEdits(
      String provider,
      int slide,
      Map<String, String> columns,
    ) {
      final values = metrics[provider] ?? const <String, String>{};
      final edits = <String, String>{};
      for (var row = 1; row <= 6; row++) {
        columns.forEach((metricKey, templateLabel) {
          final value = values['${metricKey}_$row']?.trim() ?? '';
          if (value.isNotEmpty) edits['$templateLabel $row'] = value;
        });
      }
      if (edits.isNotEmpty) slideEdits[slide.toString()] = edits;
    }

    addTableEdits('Google Business Profile Dashboard', 4, {
      'top_search_keyword': 'Top search keyword',
      'searches': 'Searches',
      'optimization_done': 'Optimization done',
    });
    addTableEdits('Google Ads Dashboard', 8, {
      'campaign': 'Campaign',
      'impr': 'Impr.',
      'clicks': 'Clicks',
      'conv': 'Conv.',
      'spend': 'Spend (₹)',
      'cpl': 'CPL (₹)',
    });
    addTableEdits('Meta Ads Dashboard', 15, {
      'campaign_ad_set': 'Campaign / Ad set',
      'reach': 'Reach',
      'clicks': 'Clicks',
      'leads': 'Leads',
      'spend': 'Spend (₹)',
      'cpl': 'CPL (₹)',
    });
    addTableEdits('LinkedIn Ads Dashboard', 22, {
      'campaign_group_campaign': 'Campaign group / Campaign',
      'impr': 'Impr.',
      'clicks': 'Clicks',
      'leads': 'Leads',
      'spend': 'Spend (₹)',
      'cpl': 'CPL (₹)',
    });
    addTableEdits('Creatives Published', 26, {
      'best_creative': 'Best creative',
      'platform': 'Platform',
      'reach_views': 'Reach / Views',
      'engagement': 'Engagement',
    });
    // Mandatory, non-dashboard pages use friendly field ids in the editor;
    // translate them to the exact template labels before exporting.
    const channelNames = <String, String>{
      'gmb': 'GMB / GBP',
      'google_ads': 'Google Ads',
      'meta_ads': 'Meta Ads',
      'linkedin_ads': 'LinkedIn Ads',
      'instagram': 'Instagram',
      'facebook': 'Facebook',
      'youtube': 'YouTube',
      'linkedin_organic': 'LinkedIn',
      'twitter_x': 'Twitter / X',
    };
    const channelFields = <String, String>{
      'impressions': 'impressions',
      'clicks': 'clicks',
      'leads_calls': 'leads / calls',
      'spend': 'spend (₹)',
      'estimated_conversion_leads': 'estimated conversion leads',
    };
    final summaryEdits = <String, String>{};
    (metrics['Channel Summary'] ?? const <String, String>{}).forEach((
      key,
      value,
    ) {
      for (final channel in channelNames.entries) {
        final prefix = '${channel.key}_';
        if (!key.startsWith(prefix)) continue;
        final field = channelFields[key.substring(prefix.length)];
        if (field != null && value.trim().isNotEmpty)
          summaryEdits['${channel.value} $field'] = value;
      }
    });
    if (summaryEdits.isNotEmpty) slideEdits['2'] = summaryEdits;
    const creativeCards = <String, String>{
      'posters_static_posts': 'POSTERS / STATIC POSTS',
      'carousels': 'CAROUSELS',
      'reels_short_videos': 'REELS / SHORT VIDEOS',
      'long_videos': 'LONG VIDEOS',
      'ad_creatives': 'AD CREATIVES',
      'stories': 'STORIES',
    };
    final creativeEdits = <String, String>{};
    (metrics['Creatives Published'] ?? const <String, String>{}).forEach((
      key,
      value,
    ) {
      final label = creativeCards[key];
      if (label != null && value.trim().isNotEmpty)
        creativeEdits[label] = value;
    });
    if (creativeEdits.isNotEmpty)
      slideEdits['26'] = {...(slideEdits['26'] ?? {}), ...creativeEdits};
    const planNames = <String, String>{
      'gmb_gbp': 'GMB / GBP',
      'google_ads': 'Google Ads',
      'meta_ads': 'Meta Ads',
      'linkedin_ads': 'LinkedIn Ads',
      'instagram': 'Instagram',
      'facebook': 'Facebook',
      'youtube': 'YouTube',
      'linkedin_organic': 'LinkedIn',
      'twitter_x': 'Twitter / X',
      'creatives': 'Creatives',
    };
    final planEdits = <String, String>{};
    (metrics['Next Month Plan'] ?? const <String, String>{}).forEach((
      key,
      value,
    ) {
      for (final plan in planNames.entries) {
        if (!key.startsWith('${plan.key}_') || value.trim().isEmpty) continue;
        final suffix = key.substring(plan.key.length + 1);
        if (suffix == 'action')
          planEdits['${plan.value} action planned'] = value;
        if (suffix == 'owner') planEdits['${plan.value} owner'] = value;
        if (suffix == 'due') planEdits['${plan.value} due'] = value;
      }
      if (key == 'approvals_inputs' && value.trim().isNotEmpty)
        planEdits['Approvals & inputs needed'] = value;
      if (key == 'remarks' && value.trim().isNotEmpty)
        planEdits['Remarks'] = value;
    });
    if (planEdits.isNotEmpty) slideEdits['28'] = planEdits;
    final payload = <String, dynamic>{
      'businessId': businessId.toString(),
      'clientName': widget.business['name']?.toString() ?? 'Client',
      if ((coverEdits['FILE NAME'] ?? '').trim().isNotEmpty)
        'fileName': coverEdits['FILE NAME']!.trim(),
      'periodLabel': '${now.year}-${now.month.toString().padLeft(2, '0')}',
      'filePeriod': '${now.year}-${now.month.toString().padLeft(2, '0')}',
      'dateRange': 'Overall',
      'reportMonth': now.month,
      'reportYear': now.year,
      'reportTemplate': 'EMPLOYEE_ADMIN',
      // A provider can be reviewed on screen without being exported. Only
      // providers with at least one entered value get report pages.
      'providers': includedProviders
          .map(
            (provider) => {
              'provider': provider,
              'connectionStatus': 'SCREENSHOT',
            },
          )
          .toList(),
      // Keep the exact Preview/Edit values as explicit overrides. The
      // exporter applies these after OCR/source metrics, so an employee edit
      // can never be replaced by an older extracted value.
      'snapshots': populated
          .map(
            (entry) => {
              'provider': providerName(entry.key),
              'metrics': {
                ...entry.value,
                'export_overrides': Map<String, String>.from(entry.value),
              },
            },
          )
          .toList(),
      'screenshots': screenshots,
      'slide_edits': slideEdits,
      'cover_edits': coverEdits,
      if (widget.business['companyLogoBase64'] != null)
        'companyLogo': {
          'bytesBase64': widget.business['companyLogoBase64'],
          'mimeType': widget.business['companyLogoMimeType'] ?? 'image/png',
        },
    };
    return payload;
  }

  /// Renders the current report to a PDF and shows it inline in the shared
  /// template format, so the values/screenshots can be reviewed before passing
  /// for approval or downloading. Nothing is saved.
  Future<void> previewReport() async {
    final payload = await _assembleReportPayload();
    if (payload == null || !mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ReportPreviewScreen(
          title: widget.business['name']?.toString() ?? 'Report preview',
          subtitle: 'Template preview',
          loadBytes: () => reportService.previewReportBytes(payload),
        ),
      ),
    );
  }

  Future<void> downloadReport(String format) async {
    final payload = await _assembleReportPayload();
    if (payload == null || !mounted) return;
    try {
      await reportService.downloadDocument(payload: payload, format: format);
      await _refreshHistory();
      if (mounted)
        setState(() {
          review = false;
          _continueFromHistory = false;
        });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${format.toUpperCase()} report downloaded and saved to history.',
            ),
          ),
        );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  /// Submits the report for admin approval. The employee cannot download until
  /// an admin approves it.
  Future<void> passReport() async {
    final payload = await _assembleReportPayload();
    if (payload == null || !mounted) return;
    try {
      await reportService.submitForApproval(payload);
      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Sent for approval'),
            content: const Text(
              'The report has been passed to an admin for approval. You will be able to download it once it is approved.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  /// Returns the exact editable cells present on the report-template page.
  /// Table pages have six available rows; blank rows are simply omitted when
  /// the report is generated.
  List<String> _fieldsForPage(String page) {
    List<String> tableRows(List<String> columns, {int maximum = 6}) => [
      for (
        var row = 1;
        row <= (visibleTableRows[page] ?? 1).clamp(1, maximum);
        row++
      )
        for (final column in columns) '${column}_$row',
    ];
    switch (page) {
      case 'Google Business Profile Dashboard':
        return tableRows([
          'top_search_keyword',
          'searches',
          'optimization_done',
        ]);
      case 'Google Ads Dashboard':
        return tableRows([
          'campaign',
          'impr',
          'clicks',
          'conv',
          'spend',
          'cpl',
        ]);
      case 'Meta Ads Dashboard':
        return tableRows([
          'campaign_ad_set',
          'reach',
          'clicks',
          'leads',
          'spend',
          'cpl',
        ]);
      case 'LinkedIn Ads Dashboard':
        return tableRows([
          'campaign_group_campaign',
          'impr',
          'clicks',
          'leads',
          'spend',
          'cpl',
        ]);
      case 'Creatives Published':
        return [
          'posters_static_posts',
          'posters_static_posts_vs_last_month',
          'carousels',
          'carousels_vs_last_month',
          'reels_short_videos',
          'reels_short_videos_vs_last_month',
          'long_videos',
          'long_videos_vs_last_month',
          'ad_creatives',
          'ad_creatives_vs_last_month',
          'stories',
          'stories_vs_last_month',
          for (
            var row = 1;
            row <= (visibleTableRows[page] ?? 1).clamp(1, 3);
            row++
          ) ...[
            'best_creative_$row',
            'platform_$row',
            'reach_views_$row',
            'engagement_$row',
          ],
        ];
      default:
        return previewPageFields[page] ?? const <String>[];
    }
  }

  String _fieldLabel(String key) {
    final rowMatch = RegExp(r'^(.*)_(\d+)$').firstMatch(key);
    final normalised = rowMatch?.group(1) ?? key;
    final readable = labels[normalised] ?? normalised.replaceAll('_', ' ');
    return rowMatch == null ? readable : '$readable — row ${rowMatch.group(2)}';
  }

  bool _isExpandableTablePage(String page) => const <String>{
    'Google Business Profile Dashboard',
    'Google Ads Dashboard',
    'Meta Ads Dashboard',
    'LinkedIn Ads Dashboard',
    'Creatives Published',
  }.contains(page);

  int _maximumRowsForPage(String page) => page == 'Creatives Published' ? 3 : 6;

  Widget _clientWorkspaceHeader() {
    final clientName = widget.business['name']?.toString() ?? 'Client';
    final handlers = (widget.business['assignedHandlers'] as List? ?? const [])
        .whereType<Map>()
        .map((handler) => Map<String, dynamic>.from(handler))
        .where((handler) {
          final role = '${handler['role_key'] ?? ''} ${handler['role'] ?? ''}'
              .toLowerCase();
          return role.contains('page') || role.contains('ads');
        })
        .toList();
    final tasks = (widget.business['assignedTasks'] as List? ?? const [])
        .whereType<Map>()
        .map((task) => Map<String, dynamic>.from(task))
        .where((task) {
          final role = '${task['role_key'] ?? ''} ${task['role'] ?? ''}'
              .toLowerCase();
          return role.contains('page') || role.contains('ads');
        })
        .toList();
    ImageProvider<Object>? logo;
    try {
      final encoded =
          (widget.business['companyLogoBase64'] ??
                  widget.business['logoBase64'])
              ?.toString();
      if (encoded != null && encoded.isNotEmpty) {
        logo = MemoryImage(base64Decode(encoded));
      }
    } catch (_) {
      // A broken optional image must not block the report workspace.
    }
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
        child: Row(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xffd7e5fb)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x180866e8),
                    blurRadius: 16,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: logo == null
                  ? const Icon(
                      Icons.business_rounded,
                      size: 36,
                      color: Color(0xff0866e8),
                    )
                  : Image(image: logo, fit: BoxFit.cover),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CLIENT WORKSPACE',
                    style: TextStyle(
                      letterSpacing: 1.2,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Color(0xff0866e8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    clientName,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF142F61),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reports for ${widget.business['reportMonth']}/${widget.business['reportYear']}',
                    style: const TextStyle(
                      color: Color(0xFF405B8E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (handlers.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 7,
                      children: handlers.map((handler) {
                        final role =
                            '${handler['role_key'] ?? ''} ${handler['role'] ?? ''}'
                                .toLowerCase();
                        final isPageHandler = role.contains('page');
                        final color = isPageHandler
                            ? const Color(0xff1769d2)
                            : const Color(0xffbd6900);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: .09),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: color.withValues(alpha: .25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPageHandler
                                    ? Icons.web_rounded
                                    : Icons.campaign_rounded,
                                size: 16,
                                color: color,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${isPageHandler ? 'Page Handler' : 'Ads Handler'}: '
                                '${handler['employee'] ?? handler['employeeName'] ?? ''}',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  if (tasks.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: tasks.map((task) {
                        final role =
                            '${task['role_key'] ?? ''} ${task['role'] ?? ''}'
                                .toLowerCase();
                        final isPageHandler = role.contains('page');
                        final color = isPageHandler
                            ? const Color(0xff1769d2)
                            : const Color(0xffbd6900);
                        final taskName =
                            (task['name'] ??
                                    task['task'] ??
                                    task['deliverables'])
                                ?.toString()
                                .trim();
                        if (taskName == null || taskName.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: color.withValues(alpha: .25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.checklist_rounded,
                                size: 15,
                                color: color,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${isPageHandler ? 'Page' : 'Ads'} · $taskName',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            if (_canManageReports)
              IconButton(
                tooltip: 'Edit client profile',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () async {
                  final controller = TextEditingController(text: clientName);
                  XFile? newLogo;
                  final saved = await showDialog<String>(
                    context: context,
                    builder: (dialogContext) => StatefulBuilder(
                      builder: (_, setDialogState) => AlertDialog(
                        title: const Text('Edit client profile'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: controller,
                              autofocus: true,
                              decoration: const InputDecoration(
                                labelText: 'Company name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    newLogo == null
                                        ? 'Company logo'
                                        : 'New logo selected',
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    final image = await picker.pickImage(
                                      source: ImageSource.gallery,
                                    );
                                    if (image != null)
                                      setDialogState(() => newLogo = image);
                                  },
                                  icon: const Icon(Icons.upload_outlined),
                                  label: Text(
                                    newLogo == null
                                        ? 'Upload logo'
                                        : 'Change logo',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(
                              dialogContext,
                              controller.text.trim(),
                            ),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ),
                  );
                  controller.dispose();
                  if (saved != null && saved.isNotEmpty && mounted) {
                    if (newLogo != null) {
                      final bytes = base64Encode(await newLogo!.readAsBytes());
                      final mime = newLogo!.mimeType ?? 'image/png';
                      final response = await http.put(
                        Uri.parse('$apiBaseUrl/report-export/client-profile'),
                        headers: {
                          'Authorization':
                              'Bearer ${AuthSession.requireToken()}',
                          'Content-Type': 'application/json',
                        },
                        body: jsonEncode({
                          'companyName': saved,
                          'logoBase64': bytes,
                          'logoMimeType': mime,
                        }),
                      );
                      if (response.statusCode < 200 ||
                          response.statusCode >= 300) {
                        if (mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Unable to save the company logo.'),
                            ),
                          );
                        return;
                      }
                      widget.business['companyLogoBase64'] = bytes;
                      widget.business['companyLogoMimeType'] = mime;
                    }
                    setState(() => widget.business['name'] = saved);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _historyReportTile(dynamic report) {
    final item = Map<String, dynamic>.from(report as Map);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.description_outlined),
        title: Text(item['file_name']?.toString() ?? 'Client report'),
        subtitle: Text((item['file_format']?.toString() ?? '').toUpperCase()),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Download report',
              onPressed: () async {
                try {
                  await reportService.downloadClientHistoryItem(item);
                } catch (error) {
                  if (mounted)
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              },
            ),
            if (_canManageReports)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete report',
                onPressed: () async {
                  final remove = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Delete report?'),
                      content: const Text(
                        'This permanently deletes the saved report.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (remove != true) return;
                  try {
                    await reportService.deleteClientHistoryItem(item);
                    await _refreshHistory();
                    if (mounted) setState(() {});
                  } catch (error) {
                    if (mounted)
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(error.toString())));
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Map<String, String> _channelSummaryValues() {
    const sources = <String, String>{
      'gmb': 'Google Business Profile Dashboard',
      'google_ads': 'Google Ads Dashboard',
      'meta_ads': 'Meta Ads Dashboard',
      'linkedin_ads': 'LinkedIn Ads Dashboard',
      'instagram': 'Instagram Dashboard',
      'facebook': 'Facebook Dashboard',
      'youtube': 'YouTube Dashboard',
      'linkedin_organic': 'LinkedIn Dashboard',
      'twitter_x': 'Twitter Dashboard',
    };
    final result = <String, String>{};
    for (final entry in sources.entries) {
      final values = metrics[entry.value] ?? const <String, String>{};
      String value(List<String> keys) => keys
          .map((key) => values[key] ?? '')
          .firstWhere((item) => item.trim().isNotEmpty, orElse: () => '');
      result['${entry.key}_impressions'] = value([
        'search_impressions',
        'impressions',
        'reach',
        'views',
      ]);
      result['${entry.key}_clicks'] = value([
        'website_clicks',
        'clicks',
        'link_clicks',
      ]);
      result['${entry.key}_leads_calls'] = value([
        'calls',
        'leads',
        'conversions',
      ]);
      result['${entry.key}_spend'] = value(['spend', 'cost']);
      result['${entry.key}_estimated_conversion_leads'] = value([
        'est_conversion_leads',
        'estimated_conversion_leads',
        'leads',
        'conversions',
      ]);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF142F61),
      surfaceTintColor: Colors.white,
      elevation: 0.5,
      titleSpacing: 8,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GoDigitalLogo(size: 34, radius: 9, padding: 5),
          const SizedBox(width: 12),
          const Flexible(
            child: Text(
              'Clients Full Report',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      actions: [
        if (_canManageReports)
          Tooltip(
            message:
                'The latest .pptx upload becomes the shared default. Use {{field_key}} and {{SCREENSHOT:provider}} placeholders.',
            child: TextButton.icon(
              onPressed: _uploadTemplate,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Report template'),
            ),
          ),
        const SizedBox(width: 12),
      ],
    );
    if (!_continueFromHistory && _historyReports.isNotEmpty)
      return Scaffold(
        appBar: appBar,
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _clientWorkspaceHeader(),
              const SizedBox(height: 28),
              Text(
                'Client reports',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              const Text(
                'Download or delete a saved report, or create a new one for this client.',
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: _historyReports.map(_historyReportTile).toList(),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => setState(() => _continueFromHistory = true),
                  icon: const Icon(Icons.add),
                  label: const Text('Create client report'),
                ),
              ),
            ],
          ),
        ),
      );
    final active = <String>[
      ...uploads.entries
          .where((item) => item.value.isNotEmpty)
          .map((item) => item.key),
      if (creativeShowcaseUploads.isNotEmpty) 'Creative Showcase',
    ];
    // The preview is intentionally image-driven: only the page(s) belonging
    // to an uploaded dashboard are shown. This avoids exposing unrelated
    // template fields for an employee to complete.
    // Cover is rendered separately, then Channel Summary, then only the
    // selected provider pages. Mandatory creative/plan pages come last.
    final previewPages = <String>['Channel Summary'];
    for (final dashboard in active) {
      for (final page
          in previewPagesForDashboard[dashboard] ?? const <String>[]) {
        if (!previewPages.contains(page)) previewPages.add(page);
      }
    }
    for (final page in mandatoryPreviewPages.where(
      (page) => page != 'Channel Summary',
    )) {
      if (!previewPages.contains(page)) previewPages.add(page);
    }
    return Scaffold(
      appBar: appBar,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: review
            ? SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _viewToggle(),
                    const SizedBox(height: 12),
                    _templateView
                        ? _templatePreview(previewPages)
                        : preview(previewPages),
                  ],
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final wideLayout = constraints.maxWidth >= 1000;
                  final dashboardList = ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (!wideLayout) ...[
                        _uploadBanner(),
                        const SizedBox(height: 18),
                        const SectionTitle(
                          title: 'Dashboard uploads',
                          subtitle:
                              'Add screenshots, then continue to review the report.',
                          icon: Icons.dashboard_customize_rounded,
                        ),
                        const SizedBox(height: 12),
                      ],
                      ..._uploadProviderSections.map((provider) {
                        if (provider == 'Creative Showcase')
                          return Card(
                            child: ListTile(
                              title: const Text('Creative Showcase'),
                              subtitle: Text(
                                '${creativeShowcaseUploads.length} of 8 template slots filled • Upload JPEG, PNG, or WebP images between 1 MB and 10 MB',
                              ),
                              trailing: Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  DropdownButton<String>(
                                    value: _selectedCreativeShowcaseSlot,
                                    items: creativeShowcaseSlots
                                        .map(
                                          (slot) => DropdownMenuItem(
                                            value: slot,
                                            child: Text(slot),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: extracting
                                        ? null
                                        : (slot) => setState(
                                            () => _selectedCreativeShowcaseSlot =
                                                slot ??
                                                _selectedCreativeShowcaseSlot,
                                          ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: extracting
                                        ? null
                                        : () => addCreativeShowcaseImage(
                                            _selectedCreativeShowcaseSlot,
                                          ),
                                    icon: const Icon(
                                      Icons.add_photo_alternate_outlined,
                                    ),
                                    label: const Text('Add image'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        if (provider == 'Creatives Published' ||
                            provider == 'Next Month Plan') {
                          return Card(
                            child: ListTile(
                              title: Text(provider),
                              subtitle: Text(
                                provider == 'Creatives Published'
                                    ? 'Enter completed creative work in Preview/Edit.'
                                    : 'Enter next month actions in Preview/Edit.',
                              ),
                              leading: const Icon(Icons.edit_note_rounded),
                            ),
                          );
                        }
                        final images = uploads[provider] ?? const <XFile>[];
                        return Card(
                          child: ExpansionTile(
                            initiallyExpanded: images.isNotEmpty,
                            leading: provider == _needsProvider
                                ? const Icon(
                                    Icons.help_outline_rounded,
                                    color: Colors.orange,
                                  )
                                : (_providerLogo(provider) ??
                                      const Icon(Icons.dashboard_outlined)),
                            title: Text(
                              provider,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              provider == _needsProvider
                                  ? '${images.length} screenshot(s) need a provider selection.'
                                  : '${images.length} dashboard image(s) added • Upload JPEG, PNG, or WebP images between 1 MB and 10 MB',
                            ),
                            trailing: provider == _needsProvider
                                ? const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.orange,
                                  )
                                : OutlinedButton.icon(
                                    onPressed: extracting
                                        ? null
                                        : () => add(provider),
                                    icon: const Icon(
                                      Icons.add_photo_alternate_outlined,
                                    ),
                                    label: const Text('Add dashboard'),
                                  ),
                            children: [
                              for (
                                var index = 0;
                                index < images.length;
                                index += 1
                              )
                                ListTile(
                                  leading: const Icon(Icons.image_outlined),
                                  title: Text(images[index].name),
                                  subtitle: Text(
                                    manuallyAssignedImages.contains(
                                          images[index],
                                        )
                                        ? 'Provider selected manually'
                                        : 'OCR will identify the provider',
                                  ),
                                  trailing: Wrap(
                                    spacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      IconButton(
                                        tooltip: 'View screenshot',
                                        icon: const Icon(
                                          Icons.visibility_outlined,
                                        ),
                                        onPressed: () =>
                                            _viewScreenshot(images[index]),
                                      ),
                                      IconButton(
                                        tooltip: 'Replace image',
                                        icon: const Icon(Icons.refresh_rounded),
                                        onPressed: extracting
                                            ? null
                                            : () => _replaceDashboardImage(
                                                provider,
                                                index,
                                              ),
                                      ),
                                      if (_dashboardProviders.contains(
                                            provider,
                                          ) ||
                                          provider == _needsProvider)
                                        DropdownButton<String>(
                                          value: provider == _needsProvider
                                              ? null
                                              : provider,
                                          hint: const Text('Move to provider'),
                                          items: _dashboardProviders
                                              .map(
                                                (option) =>
                                                    DropdownMenuItem<String>(
                                                      value: option,
                                                      child: Text(option),
                                                    ),
                                              )
                                              .toList(),
                                          onChanged: extracting
                                              ? null
                                              : (selected) {
                                                  if (selected == null) return;
                                                  _moveDashboardImage(
                                                    provider,
                                                    selected,
                                                    index,
                                                  );
                                                },
                                        ),
                                      IconButton(
                                        tooltip: 'Remove image',
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: extracting
                                            ? null
                                            : () => _removeDashboardImage(
                                                provider,
                                                index,
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                  );
                  final continueButton = FilledButton.icon(
                    onPressed: extracting ? null : extractAndPreview,
                    icon: extracting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward_rounded),
                    label: Text(
                      extracting
                          ? 'Reading ${extractingProvider ?? 'dashboards'}...'
                          : 'Continue to preview',
                    ),
                  );

                  if (wideLayout) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SectionTitle(
                                title: 'Dashboard uploads',
                                subtitle:
                                    'Add screenshots, then continue to review the report.',
                                icon: Icons.dashboard_customize_rounded,
                              ),
                              const SizedBox(height: 14),
                              Expanded(child: dashboardList),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: continueButton,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        SizedBox(
                          width: 360,
                          child: SingleChildScrollView(child: _uploadBanner()),
                        ),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: dashboardList),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: continueButton,
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  // Cover strip of the providers actually used (uploaded a dashboard or has
  // extracted/entered values), each with its brand logo and a green tick.
  Widget _providersUsedStrip() {
    final used = _dashboardProviders
        .where(
          (p) =>
              (uploads[p]?.isNotEmpty ?? false) ||
              (metrics[p]?.isNotEmpty ?? false),
        )
        .toList();
    if (used.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Providers used',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xff0a3fb0),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: used.map((p) {
              final rp = providerByDashboardPage(p);
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xffcfe0f7)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (rp != null) ...[
                      ProviderLogo(provider: rp, size: 16),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      rp?.label ?? p,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xff14b96b),
                      size: 16,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Template (visual) editor ───────────────────────────────────────────
  // Renders the report in its PDF card layout with every value inline-editable,
  // writing to the same `metrics` / `coverEdits` maps the form view uses.
  static const _templateDashboardSource = <String, String>{
    'Google Business Profile': 'Google Business Profile Dashboard',
    'Google Ads': 'Google Ads Dashboard',
    'YouTube': 'YouTube Dashboard',
    'Facebook': 'Facebook Dashboard',
    'Meta Ads': 'Meta Ads Dashboard',
    'Instagram': 'Instagram Dashboard',
    'LinkedIn': 'LinkedIn Dashboard',
    'LinkedIn Ads': 'LinkedIn Ads Dashboard',
    'Twitter / X': 'Twitter Dashboard',
    'Twitter / X Dashboard': 'Twitter Dashboard',
  };
  static const _templateComparisonPages = <String>{
    'Google Business Profile',
    'Google Ads',
    'YouTube',
    'Facebook',
    'Meta Ads',
    'Instagram',
    'LinkedIn',
    'LinkedIn Ads',
    'Twitter / X',
  };

  bool _isTemplateTextField(String key) =>
      key == 'insights_next_actions' ||
      key == 'approvals_inputs' ||
      key == 'remarks' ||
      key.endsWith('_action') ||
      key.endsWith('_owner') ||
      key.endsWith('_due') ||
      key.startsWith('top_search_keyword') ||
      key.startsWith('optimization_done') ||
      key == 'campaign' ||
      key == 'campaign_ad_set' ||
      key == 'campaign_group_campaign' ||
      key.startsWith('best_creative') ||
      key.startsWith('platform');

  Color _templateCardColor(Color base, int index) {
    final shades = <Color>[
      base,
      Color.lerp(base, Colors.black, .20)!,
      Color.lerp(base, const Color(0xff6d28d9), .32)!,
      Color.lerp(base, Colors.black, .34)!,
    ];
    return shades[index % shades.length];
  }

  Widget _viewToggle() {
    Widget chip(String label, IconData icon, bool selected, VoidCallback onTap) =>
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? const Color(0xff0866e8) : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon,
                  size: 16,
                  color: selected ? Colors.white : const Color(0xff52648a)),
              const SizedBox(width: 7),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color:
                          selected ? Colors.white : const Color(0xff52648a))),
            ]),
          ),
        );
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xffEFF4FE),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xffD6E5FB)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          chip('Template view', Icons.dashboard_customize_rounded, _templateView,
              () => setState(() => _templateView = true)),
          chip('Form view', Icons.list_alt_rounded, !_templateView,
              () => setState(() => _templateView = false)),
        ]),
      ),
    );
  }

  Widget _templatePreview(List<String> active) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review Full Report — ${widget.business['name'] ?? 'Client'}',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Edit values directly on the report cards below. Only fields with a '
            'value are included in the export.',
            style: TextStyle(color: Color(0xff5c6f93)),
          ),
          const SizedBox(height: 16),
          _coverTemplateCard(),
          const SizedBox(height: 18),
          ...active.map(_providerTemplateSection),
        ],
      );

  Widget _coverTemplateCard() {
    Widget field(String label, String labelKey, {String? initial}) => SizedBox(
          width: 200,
          child: TextFormField(
            initialValue: initial,
            onChanged: (value) => coverEdits[labelKey] = value,
            decoration: InputDecoration(
              labelText: label,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff0b2e63), Color(0xff0866e8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x330866e8), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CLIENT MONTHLY REPORT',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12)),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                field('CLIENT / BRAND', 'CLIENT / BRAND',
                    initial: widget.business['name']?.toString() ?? 'Client'),
                field('REPORT MONTH', 'REPORT MONTH'),
                field('DATE RANGE', 'DATE RANGE'),
                field('PREPARED BY', 'PREPARED BY'),
                field('DOWNLOAD FILE NAME', 'FILE NAME'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _providerTemplateSection(String provider) {
    final dashboardSource = _templateDashboardSource[provider] ?? provider;
    final extracted = provider == 'Channel Summary'
        ? _channelSummaryValues()
        : (metrics[dashboardSource] ?? const <String, String>{});
    final keys = <String>[
      ..._fieldsForPage(provider),
      ...?manualFields[provider],
    ]
        .where((k) =>
            !(hiddenFields[provider]?.contains(k) ?? false) &&
            !k.endsWith('_vs_last_month'))
        .toList();
    if (keys.isEmpty) return const SizedBox.shrink();
    final base = providerByDashboardPage(provider)?.color ??
        providerForName(provider)?.color ??
        const Color(0xff2563eb);
    final showVs = _templateComparisonPages.contains(provider);
    final cards = <Widget>[];
    for (var i = 0; i < keys.length; i++) {
      final key = keys[i];
      final value = metrics[dashboardSource]?[key] ?? extracted[key] ?? '';
      cards.add(_isTemplateTextField(key)
          ? _templateTextCard(dashboardSource, key, value)
          : _templateMetricCard(
              dashboardSource, key, value, _templateCardColor(base, i),
              showVs: showVs));
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffe2eaf7)),
        boxShadow: const [
          BoxShadow(color: Color(0x12082d61), blurRadius: 16, offset: Offset(0, 7)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (providerForName(provider) != null) ...[
              ProviderLogo.fromName(provider, size: 22, padded: true),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(provider,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xff142f61))),
            ),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 12, runSpacing: 12, children: cards),
        ],
      ),
    );
  }

  Widget _templateMetricCard(
      String source, String key, String value, Color color,
      {required bool showVs}) {
    final vsKey = '${key}_vs_last_month';
    return SizedBox(
      width: 232,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, Color.lerp(color, Colors.black, .26)!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: .30),
                blurRadius: 14,
                offset: const Offset(0, 7)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_fieldLabel(key).toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    letterSpacing: .6,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextFormField(
              key: ValueKey('tplval_${source}_$key'),
              initialValue: value,
              cursorColor: Colors.white,
              style: const TextStyle(
                  color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: '—',
                hintStyle: TextStyle(color: Colors.white60),
              ),
              onChanged: (v) =>
                  metrics.putIfAbsent(source, () => <String, String>{})[key] = v,
            ),
            const SizedBox(height: 10),
            if (showVs)
              Row(children: [
                const Text('vs last month:',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(width: 6),
                SizedBox(
                  width: 54,
                  child: TextFormField(
                    key: ValueKey('tplvs_${source}_$vsKey'),
                    initialValue: metrics[source]?[vsKey] ?? '',
                    textAlign: TextAlign.center,
                    cursorColor: Colors.white,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 2),
                      hintText: '____',
                      hintStyle: TextStyle(color: Colors.white54, fontSize: 12),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white38)),
                      focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white)),
                    ),
                    onChanged: (v) => metrics.putIfAbsent(
                        source, () => <String, String>{})[vsKey] = v,
                  ),
                ),
                const Text(' %',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _templateTextCard(String source, String key, String value) {
    final isLong = key == 'insights_next_actions' ||
        key == 'remarks' ||
        key == 'approvals_inputs';
    return SizedBox(
      width: isLong ? 480 : 232,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xfff6f9ff),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xffdce8fb)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_fieldLabel(key).toUpperCase(),
                style: const TextStyle(
                    color: Color(0xff52648a),
                    fontSize: 10.5,
                    letterSpacing: .6,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            TextFormField(
              key: ValueKey('tpltxt_${source}_$key'),
              initialValue: value,
              minLines: isLong ? 3 : 1,
              maxLines: isLong ? 6 : 2,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff142f61)),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: '—',
              ),
              onChanged: (v) =>
                  metrics.putIfAbsent(source, () => <String, String>{})[key] = v,
            ),
          ],
        ),
      ),
    );
  }

  Widget preview(List<String> active) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Review Full Report — ${widget.business['name'] ?? 'Client'}',
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      const Text(
        'Enter or edit the required values. Mandatory report pages are available even without a dashboard image; only fields with a value will be included in the exported report.',
      ),
      const SizedBox(height: 12),
      Card(
        color: const Color(0xfff4f8ff),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Client Monthly Report',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 190,
                    child: TextFormField(
                      initialValue:
                          widget.business['name']?.toString() ?? 'Client',
                      onChanged: (value) =>
                          coverEdits['CLIENT / BRAND'] = value,
                      decoration: const InputDecoration(
                        labelText: 'CLIENT / BRAND',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 170,
                    child: TextField(
                      onChanged: (value) => coverEdits['REPORT MONTH'] = value,
                      decoration: const InputDecoration(
                        labelText: 'REPORT MONTH',
                        hintText: 'Enter month',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 210,
                    child: TextField(
                      onChanged: (value) => coverEdits['DATE RANGE'] = value,
                      decoration: const InputDecoration(
                        labelText: 'DATE RANGE',
                        hintText: 'Enter date range',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 190,
                    child: TextField(
                      onChanged: (value) => coverEdits['PREPARED BY'] = value,
                      decoration: const InputDecoration(
                        labelText: 'PREPARED BY',
                        hintText: 'Employee name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 230,
                    child: TextField(
                      onChanged: (value) => coverEdits['FILE NAME'] = value,
                      decoration: const InputDecoration(
                        labelText: 'DOWNLOAD FILE NAME',
                        hintText: 'Optional custom name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              _providersUsedStrip(),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      ...active.map((provider) {
        final dashboardSource =
            <String, String>{
              'Google Business Profile': 'Google Business Profile Dashboard',
              'Google Ads': 'Google Ads Dashboard',
              'YouTube': 'YouTube Dashboard',
              'Facebook': 'Facebook Dashboard',
              'Meta Ads': 'Meta Ads Dashboard',
              'Instagram': 'Instagram Dashboard',
              'LinkedIn': 'LinkedIn Dashboard',
              'LinkedIn Ads': 'LinkedIn Ads Dashboard',
              'Twitter / X': 'Twitter Dashboard',
              'Twitter / X Dashboard': 'Twitter Dashboard',
            }[provider] ??
            provider;
        final extracted = provider == 'Channel Summary'
            ? _channelSummaryValues()
            : (metrics[dashboardSource] ?? <String, String>{});
        final templateFields = _fieldsForPage(provider);
        final fieldNames = <String>{
          ...templateFields,
          ...?manualFields[provider],
        };
        if (provider == 'Next Month Plan') {
          const planProviderPrefixes = <String, String>{
            'Google Business Profile Dashboard': 'gmb_gbp_',
            'Google Ads Dashboard': 'google_ads_',
            'Meta Ads Dashboard': 'meta_ads_',
            'LinkedIn Ads Dashboard': 'linkedin_ads_',
            'Instagram Dashboard': 'instagram_',
            'Facebook Dashboard': 'facebook_',
            'YouTube Dashboard': 'youtube_',
            'LinkedIn Dashboard': 'linkedin_organic_',
            'Twitter Dashboard': 'twitter_x_',
            'Creatives Published': 'creatives_',
          };
          final enabledPrefixes = planProviderPrefixes.entries
              .where((entry) => uploads[entry.key]?.isNotEmpty ?? false)
              .map((entry) => entry.value)
              .toSet();
          // Approvals and remarks are shared plan notes; all other
          // rows are shown only for a provider that was selected.
          fieldNames.removeWhere(
            (field) =>
                field != 'approvals_inputs' &&
                field != 'remarks' &&
                !enabledPrefixes.any(field.startsWith),
          );
        }
        if (provider == 'Channel Summary') {
          const summaryProviderPrefixes = <String, String>{
            'Google Business Profile Dashboard': 'gmb_',
            'Google Ads Dashboard': 'google_ads_',
            'Meta Ads Dashboard': 'meta_ads_',
            'LinkedIn Ads Dashboard': 'linkedin_ads_',
            'Instagram Dashboard': 'instagram_',
            'Facebook Dashboard': 'facebook_',
            'YouTube Dashboard': 'youtube_',
            'LinkedIn Dashboard': 'linkedin_organic_',
            'Twitter Dashboard': 'twitter_x_',
          };
          final enabledPrefixes = summaryProviderPrefixes.entries
              .where((entry) => uploads[entry.key]?.isNotEmpty ?? false)
              .map((entry) => entry.value)
              .toSet();
          fieldNames.removeWhere(
            (field) => !enabledPrefixes.any(field.startsWith),
          );
        }
        const tableOnly = <String>{
          'campaign',
          'impr',
          'conv',
          'cpl',
          'campaign_ad_set',
          'campaign_group_campaign',
          'top_search_keyword',
          'searches',
          'optimization_done',
        };
        const comparisonPages = <String>{
          'Google Business Profile',
          'Google Ads',
          'YouTube',
          'Facebook',
          'Meta Ads',
          'Instagram',
          'LinkedIn',
          'LinkedIn Ads',
          'Twitter / X',
        };
        // Materialize before mutating fieldNames. Iterating lazily over
        // a Set while adding to it crashes Flutter web at render time.
        final comparisonFields = comparisonPages.contains(provider)
            ? fieldNames
                  .where(
                    (key) =>
                        !tableOnly.contains(key) &&
                        !key.endsWith('_vs_last_month'),
                  )
                  .map((key) => '${key}_vs_last_month')
                  .toList()
            : const <String>[];
        fieldNames.addAll(comparisonFields);
        final fields = <String, String>{
          for (final key in fieldNames.where(
            (key) => !(hiddenFields[provider]?.contains(key) ?? false),
          ))
            key: extracted[key] ?? '',
        };
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (providerForName(provider) != null) ...[
                      ProviderLogo.fromName(provider, size: 22),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        provider,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    children: [
                      TextButton.icon(
                        onPressed: () =>
                            _addManualField(provider, dashboardSource),
                        icon: const Icon(Icons.add_box_outlined),
                        label: const Text('Add field'),
                      ),
                      if ((hiddenFields[provider]?.isNotEmpty ?? false))
                        PopupMenuButton<String>(
                          tooltip: 'Add field',
                          icon: const Icon(Icons.add_box_outlined),
                          onSelected: (field) => setState(
                            () => hiddenFields[provider]!.remove(field),
                          ),
                          itemBuilder: (_) => hiddenFields[provider]!
                              .map(
                                (field) => PopupMenuItem(
                                  value: field,
                                  child: Text('Add ${_fieldLabel(field)}'),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                ),
                if ((notes[provider] ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      notes[provider]!,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                if (_isExpandableTablePage(provider))
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed:
                          (visibleTableRows[provider] ?? 1) >=
                              _maximumRowsForPage(provider)
                          ? null
                          : () => setState(
                              () => visibleTableRows[provider] =
                                  (visibleTableRows[provider] ?? 1) + 1,
                            ),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Add row'),
                    ),
                  ),
                const SizedBox(height: 12),
                if (!previewPageFields.containsKey(provider))
                  const Text(
                    'Image-only dashboard section: the uploaded dashboard image will be placed on this report page. No data entry is required here.',
                  ),
                if (provider == 'Creative Showcase') ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: creativeShowcaseSlots
                        .map(
                          (slot) => SizedBox(
                            width: 190,
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  creativeShowcaseUploads.containsKey(slot)
                                      ? '$slot — image selected'
                                      : '$slot — no image selected',
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                Wrap(
                  spacing: 12,
                  runSpacing: 0,
                  children: fields.entries
                      .map(
                        (item) => SizedBox(
                          width: _isExpandableTablePage(provider)
                              ? (MediaQuery.sizeOf(context).width - 112) / 3
                              : MediaQuery.sizeOf(context).width - 80,
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: item.key.startsWith('optimization_done_')
                                    ? DropdownButtonFormField<String>(
                                        initialValue: item.value.isEmpty
                                            ? null
                                            : item.value,
                                        decoration: InputDecoration(
                                          labelText:
                                              'Optimization done — row ${item.key.split('_').last}',
                                          border: const OutlineInputBorder(),
                                        ),
                                        items:
                                            const [
                                                  'Completed',
                                                  'In progress',
                                                  'Not started',
                                                ]
                                                .map(
                                                  (value) => DropdownMenuItem(
                                                    value: value,
                                                    child: Text(value),
                                                  ),
                                                )
                                                .toList(),
                                        onChanged: (value) =>
                                            metrics.putIfAbsent(
                                              dashboardSource,
                                              () => <String, String>{},
                                            )[item.key] = value ?? '',
                                      )
                                    : TextFormField(
                                        initialValue: item.value,
                                        minLines:
                                            item.key == 'insights_next_actions'
                                            ? 5
                                            : 1,
                                        maxLines:
                                            item.key == 'insights_next_actions'
                                            ? 8
                                            : 1,
                                        onChanged: (value) =>
                                            metrics.putIfAbsent(
                                              dashboardSource,
                                              () => <String, String>{},
                                            )[item.key] = value,
                                        decoration: InputDecoration(
                                          labelText:
                                              item.key ==
                                                  'insights_next_actions'
                                              ? 'Insights & next actions'
                                              : (item.key.endsWith(
                                                      '_vs_last_month',
                                                    )
                                                    ? '${_fieldLabel(item.key.substring(0, item.key.length - 14))} (vs last month)'
                                                    : _fieldLabel(item.key)),
                                          border: const OutlineInputBorder(),
                                        ),
                                      ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                  tooltip: 'Remove field',
                                  onPressed: () async {
                                    final remove = await showDialog<bool>(
                                      context: context,
                                      builder: (dialogContext) => AlertDialog(
                                        title: const Text('Remove field?'),
                                        content: Text(
                                          'Remove ${_fieldLabel(item.key)} from Preview/Edit and the exported report?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(
                                              dialogContext,
                                              false,
                                            ),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.pop(
                                              dialogContext,
                                              true,
                                            ),
                                            child: const Text('Remove'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (remove != true || !mounted) return;
                                    setState(() {
                                      hiddenFields
                                          .putIfAbsent(
                                            provider,
                                            () => <String>{},
                                          )
                                          .add(item.key);
                                      metrics.putIfAbsent(
                                        dashboardSource,
                                        () => <String, String>{},
                                      )[item.key] = '';
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        );
      }),
      Wrap(
        alignment: WrapAlignment.end,
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton(
            onPressed: () => setState(() => review = false),
            child: const Text('Back to dashboards'),
          ),
          OutlinedButton.icon(
            onPressed: previewReport,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0757D5),
              side: const BorderSide(color: Color(0xFFBFD6F7)),
            ),
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('Preview'),
          ),
          FilledButton.icon(
            onPressed: passReport,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
            ),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Pass report'),
          ),
          FilledButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Choose download format'),
                content: const Text(
                  'The reviewed Preview/Edit values will be used in the downloaded report.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Back'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      downloadReport('pdf');
                    },
                    child: const Text('PDF'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      downloadReport('docx');
                    },
                    child: const Text('Word'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      downloadReport('pptx');
                    },
                    child: const Text('PowerPoint'),
                  ),
                ],
              ),
            ),
            child: const Text('Download report'),
          ),
        ],
      ),
    ],
  );
}
