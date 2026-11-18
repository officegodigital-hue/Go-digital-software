import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/auth/auth_session.dart';
import '../../shared/utils/dashboard_image_validation.dart';
// ✅ Correct package import
import 'package:godigital_portal/report/data/full_report_service.dart';

class ClientsFullReportScreen extends StatefulWidget {
  const ClientsFullReportScreen({super.key, required this.business});
  final Map<String, dynamic> business;
  @override State<ClientsFullReportScreen> createState() => _ClientsFullReportScreenState();
}

class _ClientsFullReportScreenState extends State<ClientsFullReportScreen> {
  bool _continueFromHistory = false;
  List<dynamic> _historyReports = <dynamic>[];
  static const previewPageNames = <String>[
    'Client Monthly Report (Cover Page)', 'Channel Summary',
    'Google Business Profile', 'Google Business Profile Dashboard',
    'Google Ads', 'Google Ads Dashboard', 'YouTube', 'YouTube Dashboard',
    'Facebook', 'Facebook Dashboard', 'Meta Ads', 'Meta Ads Dashboard',
    'Instagram', 'Instagram Dashboard', 'LinkedIn', 'LinkedIn Dashboard',
    'LinkedIn Ads', 'LinkedIn Ads Dashboard', 'Twitter / X',
    'Twitter / X Dashboard', 'Creatives Published', 'Creative Showcase',
    'Next Month Plan',
  ];
  static const providers = <String>['Google Business Profile Dashboard', 'Google Business Profile Ranking by GMB Dashboard', 'Google Ads Dashboard', 'YouTube Dashboard', 'Facebook Dashboard', 'Meta Ads Dashboard', 'Instagram Dashboard', 'LinkedIn Dashboard', 'LinkedIn Ads Dashboard', 'Twitter Dashboard', 'Creatives Published', 'Creative Showcase', 'Next Month Plan'];
  static const creativeShowcaseSlots = <String>[
    'Poster 1', 'Poster 2', 'Poster 3', 'Poster 4',
    'Video 1', 'Video 2', 'Video 3', 'Video 4',
  ];
  static const labels = <String, String>{'search_impressions':'Search impressions','maps_impressions':'Maps impressions','calls':'Calls','website_clicks':'Website clicks','est_conversion_leads':'Est. conversion leads','bookings':'Bookings','posts_published':'Posts published','photos_added':'Photos added','new_reviews':'New reviews','review_replies':'Review replies','top_search_keyword':'Top search keyword','searches':'Searches','optimization_done':'Optimization done','impressions':'Impressions','clicks':'Clicks','cost':'Cost','spend':'Spend','conversions':'Conversions','ctr':'CTR','cpc':'CPC','watch_time':'Watch time','subscribers':'Subscribers','likes':'Likes','comments':'Comments','reach':'Reach','engagements':'Engagements','followers':'Followers','link_clicks':'Link clicks','leads':'Leads','profile_visits':'Profile visits'};
  static const providerFields = <String, List<String>>{
    'Google Business Profile Dashboard': ['search_impressions','maps_impressions','calls','website_clicks','est_conversion_leads','bookings','posts_published','photos_added','new_reviews','review_replies'],
    'Google Business Profile Ranking by GMB Dashboard': ['top_search_keyword','searches','optimization_done'],
    'Google Ads Dashboard': ['active_campaigns','impressions','clicks','ctr','spend','conversions_leads','cost_per_lead','calls','keywords_optimized','campaign','impr','conv','cpl'],
    'YouTube Dashboard': ['subscribers','new_subscribers','impressions','impression_ctr','watch_time_hours','avg_view_duration','videos_published','shorts_published','likes_shares','top_video_views','insights_next_actions'],
    'Facebook Dashboard': ['page_followers','new_followers','impressions_reach_views','engagement','posts_published','videos_reels','stories','insights_next_actions'],
    'Meta Ads Dashboard': ['active_campaigns','reach_impressions','frequency','est_conversion_leads','ctr','cpm','spend','leads','cost_per_lead','whatsapp_messages','video_views','campaign_ad_set','clicks','cpl'],
    'Instagram Dashboard': ['followers','new_followers','impressions_reach_views','engagement','posts_published','reels_published','stories','insights_next_actions'],
    'LinkedIn Dashboard': ['followers','new_followers','impressions','engagement_rate','reposts','clicks','posts_published','insights_next_actions'],
    'LinkedIn Ads Dashboard': ['active_campaigns','leads','impressions','cost_per_lead','clicks','est_conversion_leads','ctr','engagements','avg_cpc','video_views','cpm','spend','campaign_group_campaign','impr','conv','cpl'],
    'Twitter Dashboard': ['followers','posts_published','new_followers','impressions','engagement_rate','engagements','profile_visits','link_clicks','insights_next_actions'],
    'Creatives Published': ['posters_static_posts','posters_static_posts_vs_last_month','carousels','carousels_vs_last_month','reels_short_videos','reels_short_videos_vs_last_month','long_videos','long_videos_vs_last_month','ad_creatives','ad_creatives_vs_last_month','stories','stories_vs_last_month','best_creative_platform','best_creative_reach_views','best_creative_engagement'],
    // Showcase entries are image slots in the PowerPoint template, not data fields.
    'Creative Showcase': [],
    'Next Month Plan': ['gmb_gbp_action','google_ads_action','meta_ads_action','linkedin_ads_action','instagram_action','facebook_action','youtube_action','linkedin_organic_action','twitter_x_action','creatives_action','approvals_inputs','remarks'],
  };
  // A dashboard image unlocks its exact report-template pages. Values never
  // sit under the image page unless that page itself is a dashboard table.
  static const previewPagesForDashboard = <String, List<String>>{
    'Google Business Profile Dashboard': ['Google Business Profile', 'Google Business Profile Dashboard'],
    'Google Business Profile Ranking by GMB Dashboard': ['Google Business Profile Ranking by GMB Dashboard'],
    'Google Ads Dashboard': ['Google Ads', 'Google Ads Dashboard'],
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
    'Client Monthly Report (Cover Page)': ['client_brand','report_month','date_range','prepared_by'],
    'Channel Summary': ['gmb_impressions','gmb_clicks','gmb_leads_calls','gmb_spend','gmb_estimated_conversion_leads','google_ads_impressions','google_ads_clicks','google_ads_leads_calls','google_ads_spend','google_ads_estimated_conversion_leads','meta_ads_impressions','meta_ads_clicks','meta_ads_leads_calls','meta_ads_spend','meta_ads_estimated_conversion_leads','linkedin_ads_impressions','linkedin_ads_clicks','linkedin_ads_leads_calls','linkedin_ads_spend','linkedin_ads_estimated_conversion_leads','instagram_impressions','instagram_clicks','instagram_leads_calls','instagram_spend','instagram_estimated_conversion_leads','facebook_impressions','facebook_clicks','facebook_leads_calls','facebook_spend','facebook_estimated_conversion_leads','youtube_impressions','youtube_clicks','youtube_leads_calls','youtube_spend','youtube_estimated_conversion_leads','linkedin_organic_impressions','linkedin_organic_clicks','linkedin_organic_leads_calls','linkedin_organic_spend','linkedin_organic_estimated_conversion_leads','twitter_x_impressions','twitter_x_clicks','twitter_x_leads_calls','twitter_x_spend','twitter_x_estimated_conversion_leads'],
    'Google Business Profile': ['search_impressions','maps_impressions','calls','website_clicks','est_conversion_leads','bookings','posts_published','photos_added','new_reviews','review_replies'],
    'Google Business Profile Dashboard': ['top_search_keyword_1','searches_1','optimization_done_1','top_search_keyword_2','searches_2','optimization_done_2','top_search_keyword_3','searches_3','optimization_done_3','top_search_keyword_4','searches_4','optimization_done_4','top_search_keyword_5','searches_5','optimization_done_5','top_search_keyword_6','searches_6','optimization_done_6'],
    'Google Ads': ['active_campaigns','impressions','clicks','ctr','spend','conversions_leads','cost_per_lead','avg_cpc','calls','keywords_optimized'],
    'Google Ads Dashboard': ['campaign','impr','clicks','conv','spend','cpl'],
    'YouTube': ['subscribers','new_subscribers','impressions','impression_ctr','watch_time_hours','avg_view_duration','videos_published','shorts_published','likes_shares','top_video_views'],
    'YouTube Dashboard': ['insights_next_actions'],
    'Facebook': ['page_followers','new_followers','impressions_reach_views','three_second_views','one_minute_views','watch_time','engagement','posts_published','videos_reels','stories'],
    'Facebook Dashboard': ['insights_next_actions'],
    'Meta Ads': ['active_campaigns','reach_impressions','frequency','est_conversion_leads','ctr','cpm','spend','leads','cost_per_lead','whatsapp_messages','video_views'],
    'Meta Ads Dashboard': ['campaign_ad_set','reach','clicks','leads','spend','cpl'],
    'Instagram': ['followers','new_followers','views','interactions','accounts_engaged','followers_percentage','non_followers_percentage','impressions_reach_views','engagement','posts_published','reels_published','stories'],
    'Instagram Dashboard': ['insights_next_actions'],
    'LinkedIn': ['followers','new_followers','impressions','engagement_rate','reposts','clicks','posts_published'],
    'LinkedIn Dashboard': ['insights_next_actions'],
    'LinkedIn Ads': ['active_campaigns','leads','impressions','cost_per_lead','clicks','est_conversion_leads','ctr','engagements','avg_cpc','video_views','cpm','spend'],
    'LinkedIn Ads Dashboard': ['campaign_group_campaign','impr','clicks','leads','spend','cpl'],
    'Twitter / X': ['followers','posts_published','new_followers','impressions','engagement_rate','engagements','profile_visits','link_clicks'],
    'Twitter / X Dashboard': ['insights_next_actions'],
    'Creatives Published': ['posters_static_posts','posters_static_posts_vs_last_month','carousels','carousels_vs_last_month','reels_short_videos','reels_short_videos_vs_last_month','long_videos','long_videos_vs_last_month','ad_creatives','ad_creatives_vs_last_month','stories','stories_vs_last_month','best_creative_platform','best_creative_reach_views','best_creative_engagement'],
    'Next Month Plan': ['gmb_gbp_action','gmb_gbp_owner','gmb_gbp_due','google_ads_action','google_ads_owner','google_ads_due','meta_ads_action','meta_ads_owner','meta_ads_due','linkedin_ads_action','linkedin_ads_owner','linkedin_ads_due','instagram_action','instagram_owner','instagram_due','facebook_action','facebook_owner','facebook_due','youtube_action','youtube_owner','youtube_due','linkedin_organic_action','linkedin_organic_owner','linkedin_organic_due','twitter_x_action','twitter_x_owner','twitter_x_due','creatives_action','creatives_owner','creatives_due','approvals_inputs','remarks'],
  };
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3000');
  final picker = ImagePicker();
  final Map<String, List<XFile>> uploads = {};
  final Map<String, XFile> creativeShowcaseUploads = {};
  final Map<String, Map<String, String>> metrics = {};
  final Map<String, Map<String, String>> ocrMetrics = {};
  final Map<String, Set<String>> hiddenFields = {};
  final Map<String, Set<String>> manualFields = {};
  final Map<String, String> notes = {};
  final Map<String, String> coverEdits = {};
  // Table dashboard pages start with one row. Employees add further rows only
  // when they need them; the template itself allows up to six.
  final Map<String, int> visibleTableRows = {};
  final reportService = const FullReportService();
  bool review = false, extracting = false;
  String? extractingProvider;
  String _selectedCreativeShowcaseSlot = 'Poster 1';

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
      items.removeAt(index);
      if (items.isEmpty) uploads.remove(provider);
    });
  }

  Future<void> _uploadTemplate() async {
    final selected = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pptx'], withData: true);
    final file = selected?.files.single;
    if (file?.bytes == null || file == null) return;
    try { await reportService.uploadSharedReportTemplate(file.bytes!, file.name); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shared report template saved.'))); } catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()))); }
  }

  Future<void> _addManualField(String provider, String source) async {
    final name = TextEditingController();
    final value = TextEditingController();
    final result = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Add field'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Field name', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: value, decoration: const InputDecoration(labelText: 'Value', border: OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, name.text.trim().isNotEmpty), child: const Text('Add field')),
      ],
    ));
    if (result == true && mounted) setState(() {
      final field = name.text.trim();
      manualFields.putIfAbsent(provider, () => <String>{}).add(field);
      metrics.putIfAbsent(source, () => <String, String>{})[field] = value.text;
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
      final validation = DashboardImageValidation.check(await file.readAsBytes());
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
    if (mounted && (rejectedTooSmall > 0 || rejectedTooLarge > 0 || rejectedUnsupported > 0)) {
      final notices = <String>[
        if (rejectedTooSmall > 0) 'Please re-upload images that are at least 1 MB.',
        if (rejectedTooLarge > 0) 'Each dashboard image must be 10 MB or smaller.',
        if (rejectedUnsupported > 0) 'Unsupported image files were not added.',
      ];
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(notices.join(' '))));
    }
    if (accepted.isNotEmpty) setState(() => uploads.update(provider, (items) => [...items, ...accepted], ifAbsent: () => accepted));
  }

  Future<void> addCreativeShowcaseImage(String slot) async {
    if (creativeShowcaseUploads.containsKey(slot)) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Image already uploaded'),
          content: Text('$slot already has an image. Do you want to replace it?'),
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
      DashboardImageValidationIssue.tooSmall => 'Please re-upload an image that is at least 1 MB.',
      DashboardImageValidationIssue.tooLarge => 'Each creative showcase image must be 10 MB or smaller.',
      DashboardImageValidationIssue.unsupported => 'Upload a JPEG, PNG, or WebP image.',
      null => null,
    };
    if (message != null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    setState(() => creativeShowcaseUploads[slot] = file);
  }

  Future<void> extractAndPreview() async {
    final active = uploads.entries
        .where((item) => item.key != 'Creative Showcase' && item.value.isNotEmpty)
        .toList();
    setState(() => extracting = true);
    final failures = <String>[];
    final failureReasons = <String, String>{};
    for (final entry in active) {
      if (mounted) setState(() => extractingProvider = entry.key);
      try {
        final images = <Map<String, String>>[];
        for (final file in entry.value) {
          images.add({'base64': base64Encode(await file.readAsBytes()), 'mimeType': file.mimeType ?? 'image/jpeg'});
        }
        final response = await http.post(Uri.parse('$apiBaseUrl/api/dashboard-ocr/read'), headers: {'Authorization':'Bearer ${AuthSession.requireToken()}', 'Content-Type':'application/json'}, body: jsonEncode({'provider':entry.key,'images':images})).timeout(const Duration(seconds: 75));
        final body = response.body.isEmpty ? <String,dynamic>{} : jsonDecode(response.body) as Map<String,dynamic>;
        if (response.statusCode >= 200 && response.statusCode < 300 && body['success'] == true) {
          final raw = body['metrics'];
          metrics[entry.key] = raw is Map ? raw.map<String,String>((key, value) => MapEntry(key.toString(), value.toString())) : <String,String>{};
          ocrMetrics[entry.key] = Map<String, String>.from(metrics[entry.key]!);
          notes[entry.key] = body['unmapped_text']?.toString() ?? '';
        } else { failures.add(entry.key); failureReasons[entry.key] = body['message']?.toString() ?? 'The dashboard-reading service did not return data.'; metrics.putIfAbsent(entry.key, () => {}); }
      } catch (error) { failures.add(entry.key); failureReasons[entry.key] = error.toString(); metrics.putIfAbsent(entry.key, () => {}); }
    }
    if (!mounted) return;
    setState(() { extracting=false; extractingProvider=null; review=failures.isEmpty; });
    if (failures.isNotEmpty && mounted) {
      final continueToPreview = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('Upload a clearer dashboard image'),
        content: Text('We could not read ${failures.join(', ')}. ${failureReasons.values.isEmpty ? '' : failureReasons.values.first}\n\nUpload a clearer dashboard image, or continue to Preview/Edit and complete the report values there.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Upload new image')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Continue to preview')),
        ],
      ));
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
          content: Text('These values no longer match the uploaded image OCR: ${changedValues.take(8).join(', ')}${changedValues.length > 8 ? ' and more' : ''}. Continue with the edited Preview/Edit values?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Go back')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Use edited values')),
          ],
        ),
      );
      if (proceed != true) return null;
    }
    final now = DateTime.now();
    final businessId = widget.business['id'] ?? widget.business['businessId'] ?? 0;
    String providerName(String value) {
      final name = value.toUpperCase().replaceAll(' DASHBOARD', '');
      if (name.contains('RANKING BY GMB')) return 'LOCAL_SEO';
      if (name == 'META ADS') return 'META_ADS';
      if (name == 'LINKEDIN ADS') return 'LINKEDIN_ADS';
      return name.replaceAll(' ', '_');
    }
    final populated = metrics.entries.where((entry) => entry.value.values.any((value) => value.trim().isNotEmpty)).toList();
    if (populated.isEmpty && uploads.values.every((images) => images.isEmpty)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter at least one report value or add a dashboard image before downloading.')));
      return null;
    }
    final screenshots = <Map<String, String>>[];
    for (final entry in uploads.entries) {
      // These uploads are OCR sources only. Their template pages have no
      // image placeholder, so never export their original screenshots.
      if (entry.key == 'Creatives Published' || entry.key == 'Next Month Plan') continue;
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
          .where((entry) => entry.key != 'Creatives Published' && entry.key != 'Next Month Plan' && entry.value.isNotEmpty)
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
      final insight = metrics[entry.key]?['insights_next_actions']?.trim() ?? '';
      if (insight.isNotEmpty) {
        slideEdits[entry.value.toString()] = {'Insights & next actions': insight};
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
      'campaign': 'Campaign', 'impr': 'Impr.', 'clicks': 'Clicks',
      'conv': 'Conv.', 'spend': 'Spend (₹)', 'cpl': 'CPL (₹)',
    });
    addTableEdits('Meta Ads Dashboard', 15, {
      'campaign_ad_set': 'Campaign / Ad set', 'reach': 'Reach',
      'clicks': 'Clicks', 'leads': 'Leads', 'spend': 'Spend (₹)',
      'cpl': 'CPL (₹)',
    });
    addTableEdits('LinkedIn Ads Dashboard', 22, {
      'campaign_group_campaign': 'Campaign group / Campaign',
      'impr': 'Impr.', 'clicks': 'Clicks', 'leads': 'Leads',
      'spend': 'Spend (₹)', 'cpl': 'CPL (₹)',
    });
    addTableEdits('Creatives Published', 26, {
      'best_creative': 'Best creative', 'platform': 'Platform',
      'reach_views': 'Reach / Views', 'engagement': 'Engagement',
    });
    // Mandatory, non-dashboard pages use friendly field ids in the editor;
    // translate them to the exact template labels before exporting.
    const channelNames = <String, String>{
      'gmb': 'GMB / GBP', 'google_ads': 'Google Ads', 'meta_ads': 'Meta Ads',
      'linkedin_ads': 'LinkedIn Ads', 'instagram': 'Instagram',
      'facebook': 'Facebook', 'youtube': 'YouTube',
      'linkedin_organic': 'LinkedIn', 'twitter_x': 'Twitter / X',
    };
    const channelFields = <String, String>{
      'impressions': 'impressions', 'clicks': 'clicks',
      'leads_calls': 'leads / calls', 'spend': 'spend (₹)',
      'estimated_conversion_leads': 'estimated conversion leads',
    };
    final summaryEdits = <String, String>{};
    (metrics['Channel Summary'] ?? const <String, String>{}).forEach((key, value) {
      for (final channel in channelNames.entries) {
        final prefix = '${channel.key}_';
        if (!key.startsWith(prefix)) continue;
        final field = channelFields[key.substring(prefix.length)];
        if (field != null && value.trim().isNotEmpty) summaryEdits['${channel.value} $field'] = value;
      }
    });
    if (summaryEdits.isNotEmpty) slideEdits['2'] = summaryEdits;
    const creativeCards = <String, String>{
      'posters_static_posts': 'POSTERS / STATIC POSTS', 'carousels': 'CAROUSELS',
      'reels_short_videos': 'REELS / SHORT VIDEOS', 'long_videos': 'LONG VIDEOS',
      'ad_creatives': 'AD CREATIVES', 'stories': 'STORIES',
    };
    final creativeEdits = <String, String>{};
    (metrics['Creatives Published'] ?? const <String, String>{}).forEach((key, value) {
      final label = creativeCards[key];
      if (label != null && value.trim().isNotEmpty) creativeEdits[label] = value;
    });
    if (creativeEdits.isNotEmpty) slideEdits['26'] = {...(slideEdits['26'] ?? {}), ...creativeEdits};
    const planNames = <String, String>{
      'gmb_gbp': 'GMB / GBP', 'google_ads': 'Google Ads', 'meta_ads': 'Meta Ads',
      'linkedin_ads': 'LinkedIn Ads', 'instagram': 'Instagram', 'facebook': 'Facebook',
      'youtube': 'YouTube', 'linkedin_organic': 'LinkedIn', 'twitter_x': 'Twitter / X',
      'creatives': 'Creatives',
    };
    final planEdits = <String, String>{};
    (metrics['Next Month Plan'] ?? const <String, String>{}).forEach((key, value) {
      for (final plan in planNames.entries) {
        if (!key.startsWith('${plan.key}_') || value.trim().isEmpty) continue;
        final suffix = key.substring(plan.key.length + 1);
        if (suffix == 'action') planEdits['${plan.value} action planned'] = value;
        if (suffix == 'owner') planEdits['${plan.value} owner'] = value;
        if (suffix == 'due') planEdits['${plan.value} due'] = value;
      }
      if (key == 'approvals_inputs' && value.trim().isNotEmpty) planEdits['Approvals & inputs needed'] = value;
      if (key == 'remarks' && value.trim().isNotEmpty) planEdits['Remarks'] = value;
    });
    if (planEdits.isNotEmpty) slideEdits['28'] = planEdits;
    final payload = <String, dynamic>{
      'businessId': businessId.toString(), 'clientName': widget.business['name']?.toString() ?? 'Client',
      if ((coverEdits['FILE NAME'] ?? '').trim().isNotEmpty) 'fileName': coverEdits['FILE NAME']!.trim(),
      'periodLabel': '${now.year}-${now.month.toString().padLeft(2, '0')}', 'filePeriod': '${now.year}-${now.month.toString().padLeft(2, '0')}', 'dateRange': 'Overall', 'reportMonth': now.month, 'reportYear': now.year, 'reportTemplate': 'EMPLOYEE_ADMIN',
      // A provider can be reviewed on screen without being exported. Only
      // providers with at least one entered value get report pages.
      'providers': includedProviders.map((provider) => {'provider': provider, 'connectionStatus': 'SCREENSHOT'}).toList(),
      // Keep the exact Preview/Edit values as explicit overrides. The
      // exporter applies these after OCR/source metrics, so an employee edit
      // can never be replaced by an older extracted value.
      'snapshots': populated.map((entry) => {
        'provider': providerName(entry.key),
        'metrics': {
          ...entry.value,
          'export_overrides': Map<String, String>.from(entry.value),
        },
      }).toList(),
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

  Future<void> downloadReport(String format) async {
    final payload = await _assembleReportPayload();
    if (payload == null || !mounted) return;
    try {
      await reportService.downloadDocument(payload: payload, format: format);
      await _refreshHistory();
      if (mounted) setState(() { review = false; _continueFromHistory = false; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${format.toUpperCase()} report downloaded and saved to history.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
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
            content: const Text('The report has been passed to an admin for approval. You will be able to download it once it is approved.'),
            actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  /// Returns the exact editable cells present on the report-template page.
  /// Table pages have six available rows; blank rows are simply omitted when
  /// the report is generated.
  List<String> _fieldsForPage(String page) {
    List<String> tableRows(List<String> columns, {int maximum = 6}) => [
          for (var row = 1;
              row <= (visibleTableRows[page] ?? 1).clamp(1, maximum);
              row++)
            for (final column in columns) '${column}_$row',
        ];
    switch (page) {
      case 'Google Business Profile Dashboard':
        return tableRows(['top_search_keyword', 'searches', 'optimization_done']);
      case 'Google Ads Dashboard':
        return tableRows(['campaign', 'impr', 'clicks', 'conv', 'spend', 'cpl']);
      case 'Meta Ads Dashboard':
        return tableRows(['campaign_ad_set', 'reach', 'clicks', 'leads', 'spend', 'cpl']);
      case 'LinkedIn Ads Dashboard':
        return tableRows(['campaign_group_campaign', 'impr', 'clicks', 'leads', 'spend', 'cpl']);
      case 'Creatives Published':
        return [
          'posters_static_posts', 'posters_static_posts_vs_last_month',
          'carousels', 'carousels_vs_last_month',
          'reels_short_videos', 'reels_short_videos_vs_last_month',
          'long_videos', 'long_videos_vs_last_month',
          'ad_creatives', 'ad_creatives_vs_last_month',
          'stories', 'stories_vs_last_month',
          for (var row = 1;
              row <= (visibleTableRows[page] ?? 1).clamp(1, 3);
              row++) ...[
            'best_creative_$row', 'platform_$row',
            'reach_views_$row', 'engagement_$row',
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
    ImageProvider<Object>? logo;
    try {
      final encoded = widget.business['companyLogoBase64']?.toString();
      if (encoded != null && encoded.isNotEmpty) logo = MemoryImage(base64Decode(encoded));
    } catch (_) {
      // A broken optional image must not block the report workspace.
    }
    return Card(
      elevation: 0,
      color: const Color(0xFFE9F1FF),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Row(children: [
          CircleAvatar(radius: 42, backgroundColor: Colors.white, backgroundImage: logo, child: logo == null ? const Icon(Icons.business_rounded, size: 42) : null),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('CLIENT WORKSPACE', style: TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w700, color: Color(0xFF405B8E))),
            const SizedBox(height: 5),
            Text(clientName, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF142F61))),
            const SizedBox(height: 4),
            Text('Reports for ${widget.business['reportMonth']}/${widget.business['reportYear']}', style: const TextStyle(color: Color(0xFF405B8E))),
          ])),
          IconButton(
            tooltip: 'Edit client profile',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final controller = TextEditingController(text: clientName);
              XFile? newLogo;
              final saved = await showDialog<String>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (_, setDialogState) => AlertDialog(title: const Text('Edit client profile'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Company name', border: OutlineInputBorder())), const SizedBox(height: 12), Row(children: [Expanded(child: Text(newLogo == null ? 'Company logo' : 'New logo selected')), TextButton.icon(onPressed: () async { final image = await picker.pickImage(source: ImageSource.gallery); if (image != null) setDialogState(() => newLogo = image); }, icon: const Icon(Icons.upload_outlined), label: Text(newLogo == null ? 'Upload logo' : 'Change logo'))])]), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Save'))])));
              controller.dispose();
              if (saved != null && saved.isNotEmpty && mounted) { if (newLogo != null) { final bytes = base64Encode(await newLogo!.readAsBytes()); final mime = newLogo!.mimeType ?? 'image/png'; final response = await http.put(Uri.parse('$apiBaseUrl/api/report-export/client-profile'), headers: {'Authorization': 'Bearer ${AuthSession.requireToken()}', 'Content-Type': 'application/json'}, body: jsonEncode({'companyName': saved, 'logoBase64': bytes, 'logoMimeType': mime})); if (response.statusCode < 200 || response.statusCode >= 300) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to save the company logo.'))); return; } widget.business['companyLogoBase64'] = bytes; widget.business['companyLogoMimeType'] = mime; } setState(() => widget.business['name'] = saved); }
            },
          ),
        ]),
      ),
    );
  }

  Widget _historyReportTile(dynamic report) {
    final item = Map<String, dynamic>.from(report as Map);
    return Card(child: ListTile(
      leading: const Icon(Icons.description_outlined),
      title: Text(item['file_name']?.toString() ?? 'Client report'),
      subtitle: Text((item['file_format']?.toString() ?? '').toUpperCase()),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(icon: const Icon(Icons.download_outlined), tooltip: 'Download report', onPressed: () async { try { await reportService.downloadClientHistoryItem(item); } catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()))); } }),
        IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Delete report', onPressed: () async {
          final remove = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Delete report?'), content: const Text('This permanently deletes the saved report.'), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete'))]));
          if (remove != true) return;
          try { await reportService.deleteClientHistoryItem(item); await _refreshHistory(); if (mounted) setState(() {}); } catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()))); }
        }),
      ]),
    ));
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
      String value(List<String> keys) => keys.map((key) => values[key] ?? '').firstWhere((item) => item.trim().isNotEmpty, orElse: () => '');
      result['${entry.key}_impressions'] = value(['search_impressions', 'impressions', 'reach', 'views']);
      result['${entry.key}_clicks'] = value(['website_clicks', 'clicks', 'link_clicks']);
      result['${entry.key}_leads_calls'] = value(['calls', 'leads', 'conversions']);
      result['${entry.key}_spend'] = value(['spend', 'cost']);
      result['${entry.key}_estimated_conversion_leads'] = value(['est_conversion_leads', 'estimated_conversion_leads', 'leads', 'conversions']);
    }
    return result;
  }

  @override Widget build(BuildContext context) {
    final appBar = AppBar(title: const Text('Clients Full Report'), actions: [TextButton.icon(onPressed: _uploadTemplate, icon: const Icon(Icons.upload_file_outlined), label: const Text('Report template')), const SizedBox(width: 12)]);
    if (!_continueFromHistory && _historyReports.isNotEmpty) return Scaffold(appBar: appBar, body: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_clientWorkspaceHeader(), const SizedBox(height: 28), Text('Client reports', style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 6), const Text('Download or delete a saved report, or create a new one for this client.'), const SizedBox(height: 12), Expanded(child: ListView(children: _historyReports.map(_historyReportTile).toList())), Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => setState(() => _continueFromHistory = true), icon: const Icon(Icons.add), label: const Text('Create client report')))])));
    final active = <String>[
      ...uploads.entries.where((item) => item.value.isNotEmpty).map((item) => item.key),
      if (creativeShowcaseUploads.isNotEmpty) 'Creative Showcase',
    ];
    // The preview is intentionally image-driven: only the page(s) belonging
    // to an uploaded dashboard are shown. This avoids exposing unrelated
    // template fields for an employee to complete.
    // Cover is rendered separately, then Channel Summary, then only the
    // selected provider pages. Mandatory creative/plan pages come last.
    final previewPages = <String>['Channel Summary'];
    for (final dashboard in active) {
      for (final page in previewPagesForDashboard[dashboard] ?? const <String>[]) {
        if (!previewPages.contains(page)) previewPages.add(page);
      }
    }
    for (final page in mandatoryPreviewPages.where((page) => page != 'Channel Summary')) {
      if (!previewPages.contains(page)) previewPages.add(page);
    }
    return Scaffold(appBar: appBar, body: Padding(padding: const EdgeInsets.all(24), child: review ? SingleChildScrollView(child: preview(previewPages)) : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.business['name']?.toString() ?? 'Client', style: const TextStyle(fontSize:28,fontWeight:FontWeight.w800)), const SizedBox(height:8),
      const Text('Add only provider dashboards wanted in this report. Their visible values will be extracted and prefilled in Preview/Edit. Providers without a dashboard will not appear in the final report.'), const SizedBox(height:20),
      Expanded(child: ListView(children: providers.map((provider) {
        if (provider == 'Creative Showcase') return Card(child: ListTile(title: const Text('Creative Showcase'), subtitle: Text('${creativeShowcaseUploads.length} of 8 template slots filled • Upload JPEG, PNG, or WebP images between 1 MB and 10 MB'), trailing: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [DropdownButton<String>(value: _selectedCreativeShowcaseSlot, items: creativeShowcaseSlots.map((slot) => DropdownMenuItem(value: slot, child: Text(slot))).toList(), onChanged: extracting ? null : (slot) => setState(() => _selectedCreativeShowcaseSlot = slot ?? _selectedCreativeShowcaseSlot)), OutlinedButton.icon(onPressed: extracting ? null : () => addCreativeShowcaseImage(_selectedCreativeShowcaseSlot), icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('Add image'))] )));
        final images = uploads[provider] ?? const <XFile>[];
        return Card(
          child: ExpansionTile(
            initiallyExpanded: images.isNotEmpty,
            title: Text(provider),
            subtitle: Text('${images.length} dashboard image(s) added • Upload JPEG, PNG, or WebP images between 1 MB and 10 MB'),
            trailing: OutlinedButton.icon(
              onPressed: extracting ? null : () => add(provider),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Add dashboard'),
            ),
            children: [
              for (var index = 0; index < images.length; index += 1)
                ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: Text(images[index].name),
                  subtitle: const Text('Included in this dashboard section'),
                  trailing: IconButton(
                    tooltip: 'Remove image',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: extracting ? null : () => _removeDashboardImage(provider, index),
                  ),
                ),
            ],
          ),
        );
      }).toList())),
      Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: extracting ? null : extractAndPreview, icon: extracting ? const SizedBox.square(dimension:18,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.arrow_forward), label: Text(extracting ? 'Reading ${extractingProvider ?? 'dashboards'}...' : 'Continue to preview'))),
    ])));
  }

  Widget preview(List<String> active) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review Full Report — ${widget.business['name'] ?? 'Client'}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Enter or edit the required values. Mandatory report pages are available even without a dashboard image; only fields with a value will be included in the exported report.'),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xfff4f8ff),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Client Monthly Report', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  SizedBox(width: 190, child: TextFormField(initialValue: widget.business['name']?.toString() ?? 'Client', onChanged: (value) => coverEdits['CLIENT / BRAND'] = value, decoration: const InputDecoration(labelText: 'CLIENT / BRAND', border: OutlineInputBorder()))),
                  SizedBox(width: 170, child: TextField(onChanged: (value) => coverEdits['REPORT MONTH'] = value, decoration: const InputDecoration(labelText: 'REPORT MONTH', hintText: 'Enter month', border: OutlineInputBorder()))),
                  SizedBox(width: 210, child: TextField(onChanged: (value) => coverEdits['DATE RANGE'] = value, decoration: const InputDecoration(labelText: 'DATE RANGE', hintText: 'Enter date range', border: OutlineInputBorder()))),
                  SizedBox(width: 190, child: TextField(onChanged: (value) => coverEdits['PREPARED BY'] = value, decoration: const InputDecoration(labelText: 'PREPARED BY', hintText: 'Employee name', border: OutlineInputBorder()))),
                  SizedBox(width: 230, child: TextField(onChanged: (value) => coverEdits['FILE NAME'] = value, decoration: const InputDecoration(labelText: 'DOWNLOAD FILE NAME', hintText: 'Optional custom name', border: OutlineInputBorder()))),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          ...active.map((provider) {
                final dashboardSource = <String, String>{
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
                }[provider] ?? provider;
                final extracted = provider == 'Channel Summary' ? _channelSummaryValues() : (metrics[dashboardSource] ?? <String, String>{});
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
                  fieldNames.removeWhere((field) =>
                      field != 'approvals_inputs' &&
                      field != 'remarks' &&
                      !enabledPrefixes.any(field.startsWith));
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
                  fieldNames.removeWhere((field) =>
                      !enabledPrefixes.any(field.startsWith));
                }
                const tableOnly = <String>{'campaign','impr','conv','cpl','campaign_ad_set','campaign_group_campaign','top_search_keyword','searches','optimization_done'};
                const comparisonPages = <String>{
                  'Google Business Profile', 'Google Ads', 'YouTube',
                  'Facebook', 'Meta Ads', 'Instagram', 'LinkedIn',
                  'LinkedIn Ads', 'Twitter / X',
                };
                // Materialize before mutating fieldNames. Iterating lazily over
                // a Set while adding to it crashes Flutter web at render time.
                final comparisonFields = comparisonPages.contains(provider)
                    ? fieldNames.where((key) => !tableOnly.contains(key) && !key.endsWith('_vs_last_month')).map((key) => '${key}_vs_last_month').toList()
                    : const <String>[];
                fieldNames.addAll(comparisonFields);
                final fields = <String, String>{
                  for (final key in fieldNames.where((key) => !(hiddenFields[provider]?.contains(key) ?? false))) key: extracted[key] ?? '',
                };
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(provider, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        Align(alignment: Alignment.centerRight, child: Wrap(children: [TextButton.icon(onPressed: () => _addManualField(provider, dashboardSource), icon: const Icon(Icons.add_box_outlined), label: const Text('Add field')), if ((hiddenFields[provider]?.isNotEmpty ?? false)) PopupMenuButton<String>(
                          tooltip: 'Add field',
                          icon: const Icon(Icons.add_box_outlined),
                          onSelected: (field) => setState(() => hiddenFields[provider]!.remove(field)),
                          itemBuilder: (_) => hiddenFields[provider]!.map((field) => PopupMenuItem(value: field, child: Text('Add ${_fieldLabel(field)}'))).toList(),
                        )])),
                        if ((notes[provider] ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(notes[provider]!, style: const TextStyle(color: Colors.black54))),
                        if (_isExpandableTablePage(provider)) Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: (visibleTableRows[provider] ?? 1) >= _maximumRowsForPage(provider)
                                ? null
                                : () => setState(() => visibleTableRows[provider] = (visibleTableRows[provider] ?? 1) + 1),
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Add row'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (!previewPageFields.containsKey(provider)) const Text('Image-only dashboard section: the uploaded dashboard image will be placed on this report page. No data entry is required here.'),
                        if (provider == 'Creative Showcase') ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: creativeShowcaseSlots
                                .map((slot) => SizedBox(width: 190, child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(creativeShowcaseUploads.containsKey(slot) ? '$slot — image selected' : '$slot — no image selected')))) )
                                .toList(),
                          ),
                        ],
                        Wrap(
                          spacing: 12,
                          runSpacing: 0,
                          children: fields.entries.map((item) => SizedBox(
                          width: _isExpandableTablePage(provider)
                              ? (MediaQuery.sizeOf(context).width - 112) / 3
                              : MediaQuery.sizeOf(context).width - 80,
                          child: Stack(
                          children: [
                          Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: item.key.startsWith('optimization_done_')
                              ? DropdownButtonFormField<String>(
                                  initialValue: item.value.isEmpty ? null : item.value,
                                  decoration: InputDecoration(labelText: 'Optimization done — row ${item.key.split('_').last}', border: const OutlineInputBorder()),
                                  items: const ['Completed', 'In progress', 'Not started'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                                  onChanged: (value) => metrics.putIfAbsent(dashboardSource, () => <String, String>{})[item.key] = value ?? '',
                                )
                              : TextFormField(
                                  initialValue: item.value,
                                  minLines: item.key == 'insights_next_actions' ? 5 : 1,
                                  maxLines: item.key == 'insights_next_actions' ? 8 : 1,
                                  onChanged: (value) => metrics.putIfAbsent(dashboardSource, () => <String, String>{})[item.key] = value,
                                  decoration: InputDecoration(labelText: item.key == 'insights_next_actions' ? 'Insights & next actions' : (item.key.endsWith('_vs_last_month') ? '${_fieldLabel(item.key.substring(0, item.key.length - 14))} (vs last month)' : _fieldLabel(item.key)), border: const OutlineInputBorder()),
                                ),
                          ),
                          Positioned(top: 0, right: 0, child: IconButton(icon: const Icon(Icons.delete_outline, size: 18), tooltip: 'Remove field', onPressed: () async {
                            final remove = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
                              title: const Text('Remove field?'),
                              content: Text('Remove ${_fieldLabel(item.key)} from Preview/Edit and the exported report?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
                                FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Remove')),
                              ],
                            ));
                            if (remove != true || !mounted) return;
                            setState(() {
                              hiddenFields.putIfAbsent(provider, () => <String>{}).add(item.key);
                              metrics.putIfAbsent(dashboardSource, () => <String, String>{})[item.key] = '';
                            });
                          })),
                          ],
                        ))).toList(),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(onPressed: () => setState(() => review = false), child: const Text('Back to dashboards')),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: passReport,
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Pass report'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Choose download format'),
                    content: const Text('The reviewed Preview/Edit values will be used in the downloaded report.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
                      FilledButton(onPressed: () { Navigator.pop(context); downloadReport('pdf'); }, child: const Text('PDF')),
                      FilledButton(onPressed: () { Navigator.pop(context); downloadReport('docx'); }, child: const Text('Word')),
                      FilledButton(onPressed: () { Navigator.pop(context); downloadReport('pptx'); }, child: const Text('PowerPoint')),
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
