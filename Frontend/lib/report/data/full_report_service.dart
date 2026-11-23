// lib/report/data/full_report_service.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/auth/auth_session.dart';
import 'package:godigital_portal/shared/utils/download.dart';
import 'package:godigital_portal/services/api_config.dart';

class FullReportException implements Exception {
  const FullReportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FullReportService {
  const FullReportService();

  String get _apiBaseUrl => ApiConfig.baseUrl;

  Future<LiveFullReportData> load(
    String businessId, {
    String period = '30d',
  }) async {
    if (businessId.trim().isEmpty) {
      throw const FullReportException(
        'A business is required to load the report.',
      );
    }

    final token = AuthSession.requireToken();

    final reportPath = AuthSession.isEmployee
        ? '/employee/workspace/businesses/$businessId/full-report'
        : AuthSession.isAdmin
        ? '/admin/businesses/$businessId/full-report'
        : '/owner/full-report/$businessId';

    final uri = Uri.parse(
      '$_apiBaseUrl$reportPath',
    ).replace(queryParameters: <String, String>{'period': period});
    final response = await http.get(
      uri,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    final body = _decodeMap(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        body['message']?.toString() ?? 'Unable to load the Full Report.',
      );
    }

    if (body['success'] != true) {
      throw FullReportException(
        body['message']?.toString() ?? 'Unable to load the Full Report.',
      );
    }

    return LiveFullReportData.fromJson(body);
  }

  Map<String, dynamic> createExportPayload({
    required String businessId,
    required LiveFullReportData report,
    required String period,
  }) {
    final periodLabel = switch (period) {
      'today' => 'Today',
      '7d' => 'Last 7 Days',
      '30d' => 'Last 30 Days',
      '90d' => 'Last 90 Days',
      '1y' => 'Last 1 Year',
      _ => 'Overall',
    };
    String date(DateTime? value) => value == null
        ? 'Unavailable'
        : '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

    const periodDays = <String, int>{
      'today': 1,
      '7d': 7,
      '30d': 30,
      '90d': 90,
      '1y': 365,
    };
    final selectedDays = periodDays[period];
    final today = DateTime.now();
    final currentDate = DateTime(today.year, today.month, today.day);
    final rangeEnd = selectedDays == null
        ? report.reportingPeriodEnd
        : currentDate.subtract(const Duration(days: 1));
    final rangeStart = selectedDays == null
        ? report.reportingPeriodStart
        : currentDate.subtract(Duration(days: selectedDays));
    final range = '${date(rangeStart)} – ${date(rangeEnd)}';
    return <String, dynamic>{
      'businessId': businessId,
      'clientName': report.businessName,
      'periodLabel': periodLabel,
      'filePeriod': rangeStart == null || rangeEnd == null
          ? periodLabel.replaceAll(' ', '_')
          : '${date(rangeStart)}_to_${date(rangeEnd)}',
      'dateRange': range,
      'providers': report.providers
          .map(
            (provider) => <String, dynamic>{
              'provider': provider.provider,
              'connectionStatus': provider.connectionStatus,
            },
          )
          .toList(),
      'snapshots': report.performanceSnapshots
          .map(
            (snapshot) => <String, dynamic>{
              'provider': snapshot.provider,
              'metric_date': date(snapshot.metricDate),
              'source_connection_id': snapshot.sourceConnectionId,
              'metrics': snapshot.metrics,
            },
          )
          .toList(),
    };
  }

  Future<void> downloadDocument({
    required Map<String, dynamic> payload,
    required String format,
  }) async {
    if (format != 'pptx' && format != 'docx' && format != 'pdf') {
      throw const FullReportException(
        'Choose PDF, PowerPoint, or Word for this download.',
      );
    }
    final token = AuthSession.requireToken();
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/report-export/full-report/$format'),
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': format == 'pdf'
            ? 'application/pdf'
            : format == 'docx'
            ? 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
            : 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      },
      body: jsonEncode(payload),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = _decodeMap(response.body);
      throw FullReportException(
        body['message']?.toString() ??
            'Unable to generate the Full Report document.',
      );
    }
    final client = (payload['clientName']?.toString() ?? 'Business')
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final name = '${client}_Full_Report_${payload['filePeriod']}.$format';
    final contentType = format == 'pdf'
        ? 'application/pdf'
        : format == 'docx'
        ? 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
        : 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    downloadFile(Uint8List.fromList(response.bodyBytes), name, contentType);
  }

  /// Renders the current (unsaved) report payload to a PDF for on-screen
  /// preview, without downloading or requiring admin approval.
  Future<Uint8List> previewReportBytes(Map<String, dynamic> payload) async {
    final token = AuthSession.requireToken();
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/report-export/preview'),
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/pdf',
      },
      body: jsonEncode(payload),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        _decodeMap(response.body)['message']?.toString() ??
            'Unable to generate the report preview.',
      );
    }
    return Uint8List.fromList(response.bodyBytes);
  }

  Future<void> downloadDraft({
    required int draftId,
    required String clientName,
    required String filePeriod,
    required String format,
  }) async {
    if (format != 'pptx' && format != 'docx' && format != 'pdf') {
      throw const FullReportException(
        'Choose PDF, PowerPoint, or Word for this download.',
      );
    }
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/report-workflow/drafts/$draftId/export/$format'),
      headers: {
        'Authorization': 'Bearer ${AuthSession.requireToken()}',
        'Content-Type': 'application/json',
      },
      body: '{}',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        _decodeMap(response.body)['message']?.toString() ??
            'Unable to generate the report document.',
      );
    }
    final safeClient = clientName
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final contentType = format == 'pdf'
        ? 'application/pdf'
        : format == 'docx'
        ? 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
        : 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    downloadFile(
      Uint8List.fromList(response.bodyBytes),
      '${safeClient}_Full_Report_$filePeriod.$format',
      contentType,
    );
  }

  Future<int> submitDraftForApproval(int draftId) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/report-workflow/drafts/$draftId/submit'),
      headers: {
        'Authorization': 'Bearer ${AuthSession.requireToken()}',
        'Content-Type': 'application/json',
      },
      body: '{}',
    );
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['success'] != true) {
      throw FullReportException(
        body['message']?.toString() ??
            'Unable to submit the report for approval.',
      );
    }
    return (body['submissionId'] as num?)?.toInt() ?? 0;
  }

  Future<int> openReportDraft({
    int? clientId,
    required String clientName,
    required int templateId,
    required String reportingMonth,
    required String reportName,
  }) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/report-workflow/drafts'),
      headers: {
        'Authorization': _authHeader,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        if (clientId != null && clientId > 0) 'clientId': clientId,
        'clientName': clientName,
        'templateId': templateId,
        'reportingMonth': reportingMonth,
        'reportName': reportName,
      }),
    );
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        body['message']?.toString() ?? 'Unable to open the report draft.',
      );
    }
    final id = (body['id'] as num?)?.toInt();
    if (id == null || id < 1) {
      throw const FullReportException('The report draft ID is invalid.');
    }
    return id;
  }

  Future<List<Map<String, dynamic>>> reportDraftFields(int draftId) async {
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/report-workflow/drafts/$draftId/fields'),
      headers: {'Authorization': _authHeader},
    );
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        body['message']?.toString() ?? 'Unable to load saved report fields.',
      );
    }
    return body['fields'] is List
        ? List<Map<String, dynamic>>.from(
            (body['fields'] as List).map(
              (item) => Map<String, dynamic>.from(item as Map),
            ),
          )
        : <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>?> reportDraftData(int draftId) async {
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/report-workflow/drafts/$draftId/data'),
      headers: {'Authorization': _authHeader},
    );
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        body['message']?.toString() ?? 'Unable to load the report draft.',
      );
    }
    final data = body['reportData'];
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  Future<void> saveReportDraftData({
    required int draftId,
    required Map<String, dynamic> reportData,
  }) async {
    final response = await http.put(
      Uri.parse('$_apiBaseUrl/report-workflow/drafts/$draftId/data'),
      headers: {
        'Authorization': _authHeader,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'reportData': reportData}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        _decodeMap(response.body)['message']?.toString() ??
          'Unable to save the report draft.',
      );
    }
  }

  Future<void> saveReportDraftFields({
    required int draftId,
    required List<Map<String, dynamic>> fields,
  }) async {
    final response = await http.put(
      Uri.parse('$_apiBaseUrl/report-workflow/drafts/$draftId/fields'),
      headers: {
        'Authorization': _authHeader,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'fields': fields}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        _decodeMap(response.body)['message']?.toString() ??
            'Unable to save report template fields.',
      );
    }
  }

  Future<int> addReportDraftField({
    required int draftId,
    required String label,
    required String value,
    int? templatePageId,
  }) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/report-workflow/drafts/$draftId/fields'),
      headers: {
        'Authorization': _authHeader,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'label': label,
        'value': value,
        if (templatePageId != null) 'templatePageId': templatePageId,
      }),
    );
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        body['message']?.toString() ?? 'Unable to add a report field.',
      );
    }
    return (body['id'] as num).toInt();
  }

  Future<void> updateReportDraftField({
    required int draftId,
    required int fieldId,
    required String label,
    required String value,
  }) async {
    final response = await http.patch(
      Uri.parse('$_apiBaseUrl/report-workflow/drafts/$draftId/fields/$fieldId'),
      headers: {
        'Authorization': _authHeader,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'label': label, 'value': value}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        _decodeMap(response.body)['message']?.toString() ??
            'Unable to save a report field.',
      );
    }
  }

  Future<void> deleteReportDraftField({
    required int draftId,
    required int fieldId,
  }) async {
    final response = await http.delete(
      Uri.parse('$_apiBaseUrl/report-workflow/drafts/$draftId/fields/$fieldId'),
      headers: {'Authorization': _authHeader},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        _decodeMap(response.body)['message']?.toString() ??
            'Unable to delete a report field.',
      );
    }
  }

  // ---- Approval workflow ---------------------------------------------------
  Future<int> submitForApproval(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/report-export/submit'),
      headers: {
        'Authorization': 'Bearer ${AuthSession.requireToken()}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['success'] != true) {
      throw FullReportException(
        body['message']?.toString() ??
            'Unable to submit the report for approval.',
      );
    }
    return (body['submissionId'] as num?)?.toInt() ?? 0;
  }

  Future<Map<String, dynamic>?> submissionStatus({
    required String company,
    required int month,
    required int year,
  }) async {
    final uri = Uri.parse('$_apiBaseUrl/report-export/submissions/status')
        .replace(
          queryParameters: {
            'company': company,
            'month': '$month',
            'year': '$year',
          },
        );
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer ${AuthSession.requireToken()}'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final body = _decodeMap(response.body);
    return body['submission'] is Map
        ? Map<String, dynamic>.from(body['submission'] as Map)
        : null;
  }

  Future<List<Map<String, dynamic>>> listSubmissions({
    String? status,
    String? company,
  }) async {
    final uri = Uri.parse('$_apiBaseUrl/report-export/submissions').replace(
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (company != null && company.isNotEmpty) 'company': company,
      },
    );
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer ${AuthSession.requireToken()}'},
    );
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        body['message']?.toString() ?? 'Unable to load submissions.',
      );
    }
    return body['submissions'] is List
        ? List<Map<String, dynamic>>.from(
            (body['submissions'] as List).map(
              (e) => Map<String, dynamic>.from(e as Map),
            ),
          )
        : <Map<String, dynamic>>[];
  }

  Future<void> reviewSubmission(
    int id, {
    required bool approve,
    String? note,
  }) async {
    final response = await http.post(
      Uri.parse(
        '$_apiBaseUrl/report-export/submissions/$id/${approve ? 'approve' : 'reject'}',
      ),
      headers: {
        'Authorization': 'Bearer ${AuthSession.requireToken()}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'note': note ?? ''}),
    );
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['success'] != true) {
      throw FullReportException(
        body['message']?.toString() ?? 'Unable to update the submission.',
      );
    }
  }

  /// Downloads a submission's rendered PDF (used for an approved report).
  Future<void> downloadSubmissionPdf({
    required int id,
    required String fileName,
  }) async {
    final bytes = await submissionPreviewBytes(id);
    downloadFile(bytes, fileName, 'application/pdf');
  }

  String submissionPreviewUrl(int id) =>
      '$_apiBaseUrl/report-export/submissions/$id/preview.pdf';

  Future<Uint8List> submissionPreviewBytes(int id) async {
    final response = await http.get(
      Uri.parse(submissionPreviewUrl(id)),
      headers: {'Authorization': 'Bearer ${AuthSession.requireToken()}'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        _decodeMap(response.body)['message']?.toString() ??
            'Unable to load the preview.',
      );
    }
    return Uint8List.fromList(response.bodyBytes);
  }

  Future<List<Map<String, dynamic>>> savedClients() async {
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/report-export/clients'),
      headers: {'Authorization': 'Bearer ${AuthSession.requireToken()}'},
    );
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        body['message']?.toString() ?? 'Unable to load clients.',
      );
    }
    return body['clients'] is List
        ? List<Map<String, dynamic>>.from(
            (body['clients'] as List).map(
              (e) => Map<String, dynamic>.from(e as Map),
            ),
          )
        : <Map<String, dynamic>>[];
  }

  Future<void> saveClientProfile(
    String companyName, {
    String? logoBase64,
    String? logoMimeType,
  }) async {
    final response = await http.put(
      Uri.parse('$_apiBaseUrl/report-export/client-profile'),
      headers: {
        'Authorization': 'Bearer ${AuthSession.requireToken()}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'companyName': companyName,
        if (logoBase64 != null) 'logoBase64': logoBase64,
        if (logoMimeType != null) 'logoMimeType': logoMimeType,
      }),
    );
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        body['message']?.toString() ?? 'Unable to save the client.',
      );
    }
  }

  Future<List<dynamic>> clientReportHistory({
    required String companyName,
    int? month,
    int? year,
  }) async {
    final uri = Uri.parse('$_apiBaseUrl/report-export/client-history').replace(
      queryParameters: {
        'companyName': companyName,
        if (month != null && year != null) 'month': '$month',
        if (month != null && year != null) 'year': '$year',
      },
    );
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer ${AuthSession.requireToken()}'},
    );
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300)
      throw FullReportException(
        body['message']?.toString() ?? 'Unable to load report history.',
      );
    return body['reports'] is List
        ? List<dynamic>.from(body['reports'] as List)
        : <dynamic>[];
  }

  Future<void> downloadClientHistoryItem(Map<String, dynamic> item) async {
    final id = item['id'];
    final response = await _clientHistoryItemResponse(id);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const FullReportException('Unable to download the saved report.');
    }
    final format = item['file_format']?.toString().toLowerCase() ?? 'pdf';
    final type = format == 'pdf'
        ? 'application/pdf'
        : format == 'docx'
        ? 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
        : 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    downloadFile(
      Uint8List.fromList(response.bodyBytes),
      item['file_name']?.toString() ?? 'Client_Full_Report.$format',
      type,
    );
  }

  Future<Uint8List> clientHistoryItemBytes(Map<String, dynamic> item) async {
    if (item['file_format']?.toString().toLowerCase() != 'pdf') {
      throw const FullReportException('Only PDF reports can be previewed.');
    }
    final response = await _clientHistoryItemResponse(item['id']);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        _decodeMap(response.body)['message']?.toString() ??
            'Unable to load the saved report preview.',
      );
    }
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    if (!contentType.contains('application/pdf')) {
      throw const FullReportException('The saved report is not a PDF.');
    }
    return Uint8List.fromList(response.bodyBytes);
  }

  Future<http.Response> _clientHistoryItemResponse(Object? id) async {
    return http.get(
      Uri.parse('$_apiBaseUrl/report-export/client-history/$id/download'),
      headers: {'Authorization': 'Bearer ${AuthSession.requireToken()}'},
    );
  }

  Future<void> deleteClientHistoryItem(Map<String, dynamic> item) async {
    final response = await http.delete(
      Uri.parse('$_apiBaseUrl/report-export/client-history/${item['id']}'),
      headers: {'Authorization': 'Bearer ${AuthSession.requireToken()}'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300)
      throw const FullReportException('Unable to delete the saved report.');
  }

  Future<void> uploadSharedReportTemplate(
    Uint8List bytes,
    String fileName,
  ) async {
    await uploadReportTemplate(
      bytes: bytes,
      fileName: fileName,
      activate: true,
    );
  }

  Future<Map<String, dynamic>?> sharedReportTemplate() async {
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/report-export/template'),
      headers: {'Authorization': 'Bearer ${AuthSession.requireToken()}'},
    );
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        body['message']?.toString() ?? 'Unable to load the report template.',
      );
    }
    return body['template'] is Map
        ? Map<String, dynamic>.from(body['template'] as Map)
        : null;
  }

  Future<Map<String, dynamic>?> activeReportTemplate() async {
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/report-export/templates/active'),
      headers: {'Authorization': _authHeader},
    );
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        body['message']?.toString() ??
            'Unable to load the active report template.',
      );
    }
    return body['template'] is Map
        ? Map<String, dynamic>.from(body['template'] as Map)
        : null;
  }

  Future<Uint8List> previewReportTemplateBytes(int id) async {
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/report-export/templates/$id/preview.pdf'),
      headers: {
        'Authorization': _authHeader,
        'Accept': 'application/pdf',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        _decodeMap(response.body)['message']?.toString() ??
            'Unable to render the report template.',
      );
    }
    return Uint8List.fromList(response.bodyBytes);
  }

  Future<void> downloadReportTemplate({
    required int id,
    required String fileName,
  }) async {
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/report-export/templates/$id/download'),
      headers: {'Authorization': _authHeader},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = _decodeMap(response.body);
      throw FullReportException(
        body['message']?.toString() ?? 'Unable to download the report template.',
      );
    }
    final name = fileName.toLowerCase().endsWith('.pptx')
        ? fileName
        : '$fileName.pptx';
    downloadFile(
      Uint8List.fromList(response.bodyBytes),
      name,
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    );
  }

  Future<List<Map<String, dynamic>>> reportTemplateFields(int id) async {
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/report-export/templates/$id/fields'),
      headers: {'Authorization': _authHeader},
    );
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        body['message']?.toString() ?? 'Unable to load template fields.',
      );
    }
    return body['fields'] is List
        ? List<Map<String, dynamic>>.from(
            (body['fields'] as List).map(
              (item) => Map<String, dynamic>.from(item as Map),
            ),
          )
        : <Map<String, dynamic>>[];
  }

  // ---- Report-module clients & assignments (admin) -------------------------
  String get _authHeader => 'Bearer ${AuthSession.requireToken()}';

  Future<List<Map<String, dynamic>>> taskManagerClientCards() async {
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/workspace-tasks/admin/cards'),
      headers: {'Authorization': _authHeader},
    );
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        body['message']?.toString() ??
            'Unable to load Task Manager client assignments.',
      );
    }
    return body['data'] is List
        ? List<Map<String, dynamic>>.from(
            (body['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
          )
        : <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> reportClients() async {
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/report-export/report-clients'),
      headers: {'Authorization': _authHeader},
    );
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        body['message']?.toString() ?? 'Unable to load clients.',
      );
    }
    return body['clients'] is List
        ? List<Map<String, dynamic>>.from(
            (body['clients'] as List).map((e) => Map<String, dynamic>.from(e as Map)))
        : <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> reportEmployees() async {
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/report-export/report-employees'),
      headers: {'Authorization': _authHeader},
    );
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        body['message']?.toString() ?? 'Unable to load employees.',
      );
    }
    return body['employees'] is List
        ? List<Map<String, dynamic>>.from(
            (body['employees'] as List).map((e) => Map<String, dynamic>.from(e as Map)))
        : <Map<String, dynamic>>[];
  }

  /// Create/update a client with category, logo and the full assignment set.
  Future<void> saveReportClient({
    required String companyName,
    String? businessCategory,
    String? logoBase64,
    String? logoMimeType,
    List<Map<String, dynamic>>? assignments,
  }) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/report-export/report-clients'),
      headers: {'Authorization': _authHeader, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'companyName': companyName,
        if (businessCategory != null) 'businessCategory': businessCategory,
        if (logoBase64 != null) 'logoBase64': logoBase64,
        if (logoMimeType != null) 'logoMimeType': logoMimeType,
        if (assignments != null) 'assignments': assignments,
      }),
    );
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        body['message']?.toString() ?? 'Unable to save the client.',
      );
    }
  }

  Future<void> assignReportEmployee({
    required String companyName,
    required int employeeId,
    required List<String> providers,
  }) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/report-export/report-clients/assign'),
      headers: {'Authorization': _authHeader, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'companyName': companyName,
        'employeeId': employeeId,
        'providers': providers,
      }),
    );
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        body['message']?.toString() ?? 'Unable to assign the employee.',
      );
    }
  }

  Future<void> revokeReportAssignment({
    required String companyName,
    required int employeeId,
    int? reassignToEmployeeId,
  }) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/report-export/report-clients/revoke'),
      headers: {'Authorization': _authHeader, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'companyName': companyName,
        'employeeId': employeeId,
        if (reassignToEmployeeId != null)
          'reassignToEmployeeId': reassignToEmployeeId,
      }),
    );
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        body['message']?.toString() ?? 'Unable to revoke the assignment.',
      );
    }
  }

  Future<void> deleteReportClient(String companyName) async {
    final response = await http.delete(
      Uri.parse(
        '$_apiBaseUrl/report-export/report-clients/${Uri.encodeComponent(companyName)}',
      ),
      headers: {'Authorization': _authHeader},
    );
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        body['message']?.toString() ?? 'Unable to delete the client.',
      );
    }
  }

  // ---- Report template library (admin) -------------------------------------
  Future<List<Map<String, dynamic>>> reportTemplates() async {
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/report-export/templates'),
      headers: {'Authorization': _authHeader},
    );
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        body['message']?.toString() ?? 'Unable to load report templates.',
      );
    }
    return body['templates'] is List
        ? List<Map<String, dynamic>>.from(
            (body['templates'] as List).map((e) => Map<String, dynamic>.from(e as Map)))
        : <Map<String, dynamic>>[];
  }

  Future<void> uploadReportTemplate({
    required Uint8List bytes,
    required String fileName,
    String? name,
    bool activate = false,
  }) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/report-export/templates'),
      headers: {'Authorization': _authHeader, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'bytesBase64': base64Encode(bytes),
        'fileName': fileName,
        if (name != null && name.isNotEmpty) 'name': name,
        'activate': activate,
      }),
    );
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        body['message']?.toString() ?? 'Unable to save the report template.',
      );
    }
  }

  Future<void> activateReportTemplate(int id) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/report-export/templates/$id/activate'),
      headers: {'Authorization': _authHeader},
    );
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        body['message']?.toString() ?? 'Unable to activate the template.',
      );
    }
  }

  Future<void> deactivateReportTemplate(int id) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/report-export/templates/$id/deactivate'),
      headers: {'Authorization': _authHeader},
    );
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        body['message']?.toString() ?? 'Unable to deactivate the template.',
      );
    }
  }

  Future<void> deleteReportTemplate(int id) async {
    final response = await http.delete(
      Uri.parse('$_apiBaseUrl/report-export/templates/$id'),
      headers: {'Authorization': _authHeader},
    );
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        body['message']?.toString() ?? 'Unable to delete the template.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> templatePages([int? id]) async {
    final uri = id == null
        ? '$_apiBaseUrl/report-export/templates/pages'
        : '$_apiBaseUrl/report-export/templates/$id/pages';
    final response = await http.get(
      Uri.parse(uri),
      headers: {'Authorization': _authHeader},
    );
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FullReportException(
        body['message']?.toString() ?? 'Unable to load template pages.',
      );
    }
    return body['pages'] is List
        ? List<Map<String, dynamic>>.from(
            (body['pages'] as List).map((e) => Map<String, dynamic>.from(e as Map)))
        : <Map<String, dynamic>>[];
  }

  Future<Map<String, String>> generateProviderInsights({
    required String businessId,
    required List<dynamic> snapshots,
  }) async {
    final token = AuthSession.requireToken();
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/ai/full-report-insights'),
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'businessId': businessId,
        'snapshots': snapshots,
      }),
    );
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['success'] != true) {
      throw FullReportException(
        body['message']?.toString() ?? 'Unable to generate AI dashboard notes.',
      );
    }
    final raw = body['provider_insights'];
    if (raw is! Map) return <String, String>{};
    return raw.map<String, String>(
      (key, value) => MapEntry(key.toString().toUpperCase(), value.toString()),
    );
  }

  Future<Map<String, dynamic>> generateNextMonthPlan({
    required String businessId,
    required List<dynamic> snapshots,
  }) async {
    final token = AuthSession.requireToken();
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/ai/next-month-plan'),
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'businessId': businessId,
        'snapshots': snapshots,
      }),
    );
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['success'] != true) {
      throw FullReportException(
        body['message']?.toString() ??
            'Unable to generate the Next Month Plan.',
      );
    }
    final plan = body['next_month_plan'];
    return plan is Map ? Map<String, dynamic>.from(plan) : <String, dynamic>{};
  }

  Future<void> syncLinkedIn(String businessId) async {
    final token = AuthSession.requireToken();
    final response = await http.post(
      Uri.parse(
        '$_apiBaseUrl/owner/performance-snapshots/$businessId/linkedin/sync',
      ),
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['success'] != true) {
      throw FullReportException(
        body['message']?.toString() ?? 'Unable to refresh LinkedIn data.',
      );
    }
  }

  Future<void> syncMeta(String businessId) async {
    final token = AuthSession.requireToken();
    final response = await http.post(
      Uri.parse(
        '$_apiBaseUrl/owner/performance-snapshots/$businessId/meta/sync',
      ),
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['success'] != true) {
      throw FullReportException(
        body['message']?.toString() ?? 'Unable to refresh Meta data.',
      );
    }
  }

  Future<List<String>> syncGoogleSources(
    String businessId,
    Iterable<String> providers,
  ) async {
    const paths = <String, String>{
      'GOOGLE_ANALYTICS': 'google-analytics',
      'GOOGLE_SEARCH_CONSOLE': 'google-search-console',
      'GOOGLE_ADS': 'google-ads',
      'GOOGLE_BUSINESS_PROFILE': 'google-business-profile',
      'YOUTUBE': 'youtube',
    };

    final token = AuthSession.requireToken();
    var refreshed = 0;
    final failures = <String>[];
    for (final provider in providers.toSet()) {
      final path = paths[provider];
      if (path == null && provider != 'LOCAL_SEO') continue;

      final response = await http.post(
        Uri.parse(
          provider == 'LOCAL_SEO'
              ? '$_apiBaseUrl/audits/$businessId/run'
              : '$_apiBaseUrl/owner/performance-snapshots/$businessId/$path/sync',
        ),
        headers: <String, String>{
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      final body = _decodeMap(response.body);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          body['success'] == true) {
        refreshed += 1;
      } else {
        failures.add(
          '$provider: ${body['message']?.toString() ?? 'Unable to refresh the selected Google data.'}',
        );
      }
    }

    if (refreshed == 0 && failures.isNotEmpty) {
      throw FullReportException(failures.join('\n'));
    }
    return failures;
  }

  Map<String, dynamic> _decodeMap(String value) {
    if (value.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(value);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    return <String, dynamic>{};
  }
}

class LiveFullReportData {
  const LiveFullReportData({
    required this.businessName,
    required this.businessAddress,
    required this.website,
    required this.auditScore,
    required this.websiteScore,
    required this.googleRating,
    required this.googleReviewCount,
    required this.napStatus,
    required this.phoneMonitorStatus,
    required this.issues,
    required this.opportunities,
    required this.category,
    required this.categorySource,
    required this.categoryConfirmationStatus,
    required this.competitorStatus,
    required this.competitorMessage,
    required this.averageRating,
    required this.averageReviewCount,
    required this.ratingDifference,
    required this.reviewCountDifference,
    required this.ratingRank,
    required this.reviewCountRank,
    required this.competitors,
    required this.dataLimitations,
    required this.providers,
    required this.auditTimeline,
    required this.phoneMonitorChecks,
    required this.performanceSnapshots,
    required this.keywordActiveCount,
    required this.generatedAt,
    required this.reportingPeriodStart,
    required this.reportingPeriodEnd,
    required this.connectedPlatforms,
  });

  final String businessName;
  final String? businessAddress;
  final String? website;
  final int? auditScore;
  final int? websiteScore;
  final double? googleRating;
  final int? googleReviewCount;
  final String? napStatus;
  final String? phoneMonitorStatus;

  final List<LiveReportIssue> issues;
  final List<LiveReportIssue> opportunities;

  final String? category;
  final String? categorySource;
  final String? categoryConfirmationStatus;

  final String competitorStatus;
  final String competitorMessage;
  final double? averageRating;
  final double? averageReviewCount;
  final double? ratingDifference;
  final double? reviewCountDifference;
  final int? ratingRank;
  final int? reviewCountRank;
  final List<LiveCompetitor> competitors;
  final List<String> dataLimitations;

  final List<LiveProviderStatus> providers;
  final List<LiveAuditTimelineItem> auditTimeline;
  final List<LivePhoneMonitorCheck> phoneMonitorChecks;
  final List<LivePerformanceSnapshot> performanceSnapshots;

  final int keywordActiveCount;
  final DateTime? generatedAt;
  final DateTime? reportingPeriodStart;
  final DateTime? reportingPeriodEnd;
  final List<String> connectedPlatforms;

  bool get hasCompetitorData => competitorStatus == 'DATA_AVAILABLE';

  List<LivePerformanceSnapshot> snapshotsFor(String provider) =>
      performanceSnapshots
          .where((snapshot) => snapshot.provider == provider)
          .toList();

  LivePerformanceSnapshot? latestSnapshotFor(String provider) {
    final snapshots = snapshotsFor(provider);

    return snapshots.isEmpty ? null : snapshots.last;
  }

  factory LiveFullReportData.fromJson(Map<String, dynamic> json) {
    final business = _map(json['business']);
    final overview = _map(json['overview']);
    final history = _map(json['history']);
    final latestAudit = _map(overview['latest_audit']);
    final localSeo = _map(overview['local_seo']);
    final nap = _map(localSeo['nap_consistency']);
    final phoneMonitor = _map(localSeo['phone_monitor']);
    final keywords = _map(localSeo['keywords']);
    final categoryInfo = _map(overview['category']);
    final reportMetadata = _map(json['report_metadata']);
    final reportingPeriod = _map(reportMetadata['reporting_period']);

    final benchmarkEnvelope = _map(json['benchmark']);
    final benchmark = _map(benchmarkEnvelope['data']);
    final benchmarkCategory = _map(benchmark['category']);
    final categoryAverage = _map(benchmark['category_average']);
    final comparison = _map(benchmark['comparison']);

    return LiveFullReportData(
      businessName: business['name']?.toString() ?? 'Business',
      businessAddress: _text(business['address']),
      website: _text(business['website']),
      auditScore: _int(latestAudit['audit_score']),
      websiteScore: _int(latestAudit['website_score']),
      googleRating: _double(latestAudit['google_rating']),
      googleReviewCount: _int(latestAudit['google_review_count']),
      napStatus: _text(nap['status']),
      phoneMonitorStatus: _text(phoneMonitor['status']),
      issues: _issues(overview['issues']),
      opportunities: _issues(overview['opportunities']),
      category:
          _text(categoryInfo['label']) ?? _text(benchmarkCategory['label']),
      categorySource:
          _text(categoryInfo['source']) ?? _text(benchmarkCategory['source']),
      categoryConfirmationStatus: _text(categoryInfo['confirmation_status']),
      competitorStatus:
          benchmarkEnvelope['status']?.toString() ?? 'UNAVAILABLE',
      competitorMessage:
          benchmarkEnvelope['message']?.toString() ??
          'Competitor comparison is unavailable.',
      averageRating: _double(categoryAverage['google_rating']),
      averageReviewCount: _double(categoryAverage['google_review_count']),
      ratingDifference: _double(comparison['rating_difference']),
      reviewCountDifference: _double(comparison['review_count_difference']),
      ratingRank: _int(comparison['rating_rank_by_public_data']),
      reviewCountRank: _int(comparison['review_count_rank_by_public_data']),
      competitors: _list(benchmark['competitors'])
          .whereType()
          .map(
            (value) =>
                LiveCompetitor.fromJson(Map<String, dynamic>.from(value)),
          )
          .toList(),
      dataLimitations: _list(benchmark['data_limitations'])
          .map((value) => value.toString())
          .where((value) => value.isNotEmpty)
          .toList(),
      providers: _list(json['providers'])
          .whereType()
          .map(
            (value) =>
                LiveProviderStatus.fromJson(Map<String, dynamic>.from(value)),
          )
          .toList(),
      auditTimeline: _list(history['audit_score_timeline'])
          .whereType()
          .map(
            (value) => LiveAuditTimelineItem.fromJson(
              Map<String, dynamic>.from(value),
            ),
          )
          .toList(),
      phoneMonitorChecks: _list(history['phone_monitor_checks'])
          .whereType()
          .map(
            (value) => LivePhoneMonitorCheck.fromJson(
              Map<String, dynamic>.from(value),
            ),
          )
          .toList(),
      performanceSnapshots: _list(history['provider_metric_snapshots'])
          .whereType()
          .map(
            (value) => LivePerformanceSnapshot.fromJson(
              Map<String, dynamic>.from(value),
            ),
          )
          .toList(),
      keywordActiveCount: _int(keywords['active_count']) ?? 0,
      generatedAt: DateTime.tryParse(json['generated_at']?.toString() ?? ''),
      reportingPeriodStart: DateTime.tryParse(
        reportingPeriod['start_date']?.toString() ?? '',
      ),
      reportingPeriodEnd: DateTime.tryParse(
        reportingPeriod['end_date']?.toString() ?? '',
      ),
      connectedPlatforms: _list(reportMetadata['connected_platforms'])
          .map((value) => value.toString())
          .where((value) => value.isNotEmpty)
          .toList(),
    );
  }

  static List<LiveReportIssue> _issues(dynamic value) => _list(value)
      .whereType()
      .map((item) => LiveReportIssue.fromJson(Map<String, dynamic>.from(item)))
      .toList();

  static List<dynamic> _list(dynamic value) =>
      value is List ? value : const <dynamic>[];

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  static String? _text(dynamic value) {
    final text = value?.toString().trim() ?? '';

    return text.isEmpty ? null : text;
  }

  static int? _int(dynamic value) {
    if (value is num) {
      return value.round();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  static double? _double(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }
}

class LiveReportIssue {
  const LiveReportIssue({
    required this.key,
    required this.title,
    required this.description,
    required this.severity,
  });

  final String key;
  final String title;
  final String description;
  final String severity;

  factory LiveReportIssue.fromJson(Map<String, dynamic> json) {
    return LiveReportIssue(
      key: json['key']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Report item',
      description: json['description']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'low',
    );
  }
}

class LiveCompetitor {
  const LiveCompetitor({
    required this.name,
    required this.address,
    required this.googleRating,
    required this.googleReviewCount,
    required this.distanceKm,
    required this.googleMapUrl,
  });

  final String name;
  final String? address;
  final double? googleRating;
  final int? googleReviewCount;
  final double? distanceKm;
  final String? googleMapUrl;

  factory LiveCompetitor.fromJson(Map<String, dynamic> json) {
    return LiveCompetitor(
      name: json['name']?.toString() ?? 'Nearby business',
      address: _text(json['address']),
      googleRating: _double(json['google_rating']),
      googleReviewCount: _int(json['google_review_count']),
      distanceKm: _double(json['distance_km']),
      googleMapUrl: _text(json['google_map_url']),
    );
  }

  static String? _text(dynamic value) {
    final text = value?.toString().trim() ?? '';

    return text.isEmpty ? null : text;
  }

  static int? _int(dynamic value) {
    if (value is num) {
      return value.round();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  static double? _double(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }
}

class LiveProviderStatus {
  const LiveProviderStatus({
    required this.provider,
    required this.connectionStatus,
    required this.connectionCount,
    required this.snapshotCount,
    required this.latestSnapshot,
  });

  final String provider;
  final String connectionStatus;
  final int connectionCount;
  final int snapshotCount;
  final LivePerformanceSnapshot? latestSnapshot;

  bool get isConnected =>
      connectionStatus == 'CONNECTED' ||
      connectionStatus == 'DATA_AVAILABLE' ||
      connectionStatus == 'AVAILABLE';

  factory LiveProviderStatus.fromJson(Map<String, dynamic> json) {
    final rawSnapshot = json['latest_snapshot'];

    return LiveProviderStatus(
      provider: json['provider']?.toString() ?? 'Provider',
      connectionStatus:
          json['connection_status']?.toString() ?? 'CONNECTION_REQUIRED',
      connectionCount: _int(json['connection_count']) ?? 0,
      snapshotCount: _int(json['snapshot_count']) ?? 0,
      latestSnapshot: rawSnapshot is Map
          ? LivePerformanceSnapshot.fromJson(
              Map<String, dynamic>.from(rawSnapshot),
            )
          : null,
    );
  }

  static int? _int(dynamic value) {
    if (value is num) {
      return value.round();
    }

    return int.tryParse(value?.toString() ?? '');
  }
}

class LiveAuditTimelineItem {
  const LiveAuditTimelineItem({
    required this.id,
    required this.auditScore,
    required this.websiteScore,
    required this.socialScore,
    required this.googleRating,
    required this.googleReviewCount,
    required this.createdAt,
  });

  final int? id;
  final int? auditScore;
  final int? websiteScore;
  final int? socialScore;
  final double? googleRating;
  final int? googleReviewCount;
  final DateTime? createdAt;

  factory LiveAuditTimelineItem.fromJson(Map<String, dynamic> json) {
    return LiveAuditTimelineItem(
      id: _int(json['id']),
      auditScore: _int(json['audit_score']),
      websiteScore: _int(json['website_score']),
      socialScore: _int(json['social_score']),
      googleRating: _double(json['google_rating']),
      googleReviewCount: _int(json['google_review_count']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  static int? _int(dynamic value) {
    if (value is num) {
      return value.round();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  static double? _double(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }
}

class LivePhoneMonitorCheck {
  const LivePhoneMonitorCheck({
    required this.id,
    required this.status,
    required this.expectedPhone,
    required this.observedPhone,
    required this.source,
    required this.checkedAt,
  });

  final int? id;
  final String status;
  final String? expectedPhone;
  final String? observedPhone;
  final String? source;
  final DateTime? checkedAt;

  factory LivePhoneMonitorCheck.fromJson(Map<String, dynamic> json) {
    return LivePhoneMonitorCheck(
      id: _int(json['id']),
      status: json['status']?.toString() ?? 'UNKNOWN',
      expectedPhone: _text(json['expected_phone']),
      observedPhone: _text(json['observed_phone']),
      source: _text(json['source']),
      checkedAt: DateTime.tryParse(json['checked_at']?.toString() ?? ''),
    );
  }

  static String? _text(dynamic value) {
    final text = value?.toString().trim() ?? '';

    return text.isEmpty ? null : text;
  }

  static int? _int(dynamic value) {
    if (value is num) {
      return value.round();
    }

    return int.tryParse(value?.toString() ?? '');
  }
}

class LivePerformanceSnapshot {
  const LivePerformanceSnapshot({
    required this.id,
    required this.provider,
    required this.metricDate,
    required this.metrics,
    required this.sourceConnectionId,
    required this.createdAt,
  });

  final int? id;
  final String provider;
  final DateTime? metricDate;
  final Map<String, dynamic> metrics;
  final int? sourceConnectionId;
  final DateTime? createdAt;

  num? number(String key) {
    final value = metrics[key];

    if (value is num) {
      return value;
    }

    return num.tryParse(value?.toString() ?? '');
  }

  factory LivePerformanceSnapshot.fromJson(Map<String, dynamic> json) {
    return LivePerformanceSnapshot(
      id: _int(json['id']),
      provider: json['provider']?.toString() ?? 'UNKNOWN',
      metricDate: _parseSnapshotDate(json['metric_date']),
      metrics: _map(json['metrics']),
      sourceConnectionId: _int(json['source_connection_id']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  static DateTime? _parseSnapshotDate(dynamic value) {
    final text = value?.toString().trim() ?? '';
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(text);
    if (match != null) {
      return DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
    }
    return DateTime.tryParse(text);
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  static int? _int(dynamic value) {
    if (value is num) {
      return value.round();
    }

    return int.tryParse(value?.toString() ?? '');
  }
}
