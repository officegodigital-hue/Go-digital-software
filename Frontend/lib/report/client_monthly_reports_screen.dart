// lib/report/client_monthly_reports_screen.dart
//
// Opened when a client card is tapped. Shows that client's reports as
// month-wise cards for saved reports and assigned tasks, plus a create card.
// Tapping a PDF report opens an on-screen, view-only preview (no download);
// tapping the new-report card opens the full report builder workspace.
import 'dart:convert';

import 'package:flutter/material.dart';

import 'clients_full_report_screen.dart';
import 'report_brand.dart';
import 'report_preview_screen.dart';
import 'report_providers.dart';
import 'data/full_report_service.dart';

const _navy = Color(0xFF142F61);
const _accent = Color(0xFF2563EB);
const _muted = Color(0xFF64748B);

const _months = <String>[
  '',
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _monthLabel(dynamic month, dynamic year) {
  final m = int.tryParse('${month ?? ''}') ?? 0;
  final name = (m >= 1 && m <= 12) ? _months[m] : '';
  return [name, '$year'].where((p) => p.trim().isNotEmpty).join(' ');
}

String _dateLabel(dynamic value) {
  final text = value?.toString() ?? '';
  final dt = DateTime.tryParse(text.replaceFirst(' ', 'T'));
  if (dt == null) return '';
  final d = dt.toLocal();
  return '${d.day.toString().padLeft(2, '0')} ${_months[d.month].substring(0, 3)} ${d.year}';
}

String _dateTimeLabel(dynamic value) {
  final text = value?.toString() ?? '';
  final dt = DateTime.tryParse(text.replaceFirst(' ', 'T'));
  if (dt == null) return '';
  final d = dt.toLocal();
  final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ampm = d.hour < 12 ? 'AM' : 'PM';
  final minute = d.minute.toString().padLeft(2, '0');
  return '${d.day.toString().padLeft(2, '0')} ${_months[d.month].substring(0, 3)} '
      '${d.year} · $hour12:$minute $ampm';
}

class ClientMonthlyReportsScreen extends StatefulWidget {
  const ClientMonthlyReportsScreen({
    super.key,
    required this.client,
    this.canManageReports = false,
    this.embedded = false,
  });

  /// The client row map: expects `name`, optionally `assignedTasks`,
  /// `assignedHandlers`, `logoBase64`/`companyLogoBase64`.
  final Map<String, dynamic> client;
  final bool canManageReports;

  /// True when opened inside the report shell (which provides the top bar and
  /// back button), so this screen omits its own AppBar.
  final bool embedded;

  @override
  State<ClientMonthlyReportsScreen> createState() =>
      _ClientMonthlyReportsScreenState();
}

class _ClientMonthlyReportsScreenState
    extends State<ClientMonthlyReportsScreen> {
  final _service = const FullReportService();
  late Future<List<Map<String, dynamic>>> _reportsFuture;
  late Future<List<Map<String, dynamic>>> _submissionsFuture;

  String get _name => widget.client['name']?.toString() ?? 'Client';

  List<dynamic> get _assignedTasks {
    final tasks = widget.client['assignedTasks'];
    return tasks is List ? tasks : const <dynamic>[];
  }

  List<({int month, int year, List<dynamic> tasks})> get _assignmentMonths {
    final grouped = <String, ({int month, int year, List<dynamic> tasks})>{};
    void addTask(dynamic task, Object? rawDate) {
      final deadline = DateTime.tryParse('${rawDate ?? ''}');
      if (deadline == null) return;
      final key =
          '${deadline.year}-${deadline.month.toString().padLeft(2, '0')}';
      final group = grouped.putIfAbsent(
        key,
        () => (month: deadline.month, year: deadline.year, tasks: <dynamic>[]),
      );
      group.tasks.add(task);
    }

    for (final task in _assignedTasks) {
      if (task is Map) addTask(task, task['deadline']);
    }
    final taskManagerCards = widget.client['taskManagerCards'];
    if (taskManagerCards is List) {
      for (final card in taskManagerCards.whereType<Map>()) {
        final date = card['submission_date'];
        for (final task
            in (card['tasks'] as List? ?? const []).whereType<Map>()) {
          final normalized = Map<String, dynamic>.from(task);
          normalized['task'] ??= task['name'];
          normalized['deadline'] ??= date;
          addTask(normalized, date);
        }
      }
    }
    return grouped.values.toList()..sort((a, b) {
      final byYear = b.year.compareTo(a.year);
      return byYear != 0 ? byYear : b.month.compareTo(a.month);
    });
  }

  List<dynamic> _tasksForReportMonth(Map<String, dynamic> report) {
    final month = int.tryParse('${report['report_month'] ?? ''}');
    final year = int.tryParse('${report['report_year'] ?? ''}');
    if (month == null || year == null) return const [];
    for (final assignment in _assignmentMonths) {
      if (assignment.month == month && assignment.year == year) {
        return assignment.tasks;
      }
    }
    return const [];
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _reportsFuture = _service
        .clientReportHistory(companyName: _name)
        .then(
          (reports) => reports
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
        );
    // The employee's own submissions for this client: who passed what, when,
    // and whether an admin approved / rejected it (or it is still pending).
    _submissionsFuture = _service
        .listSubmissions(company: _name)
        .catchError((_) => <Map<String, dynamic>>[]);
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _reportsFuture.catchError((_) => <Map<String, dynamic>>[]);
  }

  void _toast(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  ImageProvider? get _logo {
    final encoded =
        widget.client['logoBase64']?.toString() ??
        widget.client['companyLogoBase64']?.toString();
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return MemoryImage(base64Decode(encoded));
    } catch (_) {
      return null;
    }
  }

  PreferredSizeWidget _clientReportAppBar() {
    final logo = _logo;
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: ReportBrand.navy,
      surfaceTintColor: Colors.white,
      elevation: .5,
      titleSpacing: 8,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xfff1f6ff),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xffdbe7f8)),
            ),
            clipBehavior: Clip.antiAlias,
            child: logo == null
                ? Center(
                    child: Text(
                      _name.isNotEmpty ? _name[0].toUpperCase() : 'C',
                      style: const TextStyle(
                        color: ReportBrand.blue,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                : Image(image: logo, fit: BoxFit.cover),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              _name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 12, left: 4),
          child: ReportProfileMenu(compact: true),
        ),
      ],
    );
  }

  Future<void> _openPreview(Map<String, dynamic> item) async {
    final format = (item['file_format']?.toString() ?? 'pdf').toLowerCase();
    if (format != 'pdf') {
      // The inline viewer renders PDF only; other formats fall back to a save.
      try {
        await _service.downloadClientHistoryItem(item);
      } catch (error) {
        _toast(error.toString());
      }
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ReportPreviewScreen(
          title: _name,
          subtitle: _monthLabel(item['report_month'], item['report_year']),
          loadBytes: () => _service.clientHistoryItemBytes(item),
          embedded: widget.embedded,
        ),
      ),
    );
  }

  Future<void> _previewSubmission(int id, String period) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ReportPreviewScreen(
          title: _name,
          subtitle: period,
          loadBytes: () => _service.submissionPreviewBytes(id),
          embedded: widget.embedded,
        ),
      ),
    );
  }

  Future<void> _downloadSubmission(int id, String period) async {
    try {
      final safe = _name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
      final suffix = period.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
      await _service.downloadSubmissionPdf(
        id: id,
        fileName: '${safe}_$suffix.pdf',
      );
      _toast('Report downloaded.');
    } catch (error) {
      _toast(error.toString());
    }
  }

  Future<void> _newReport({
    int? month,
    int? year,
    List<dynamic>? assignedTasks,
  }) async {
    final now = DateTime.now();
    final business = <String, dynamic>{
      if (widget.client['id'] != null) 'id': widget.client['id'],
      'name': _name,
      'reportMonth': month ?? now.month,
      'reportYear': year ?? now.year,
      'assignedTasks': assignedTasks ?? widget.client['assignedTasks'],
      'assignedHandlers': widget.client['assignedHandlers'],
      'existingReports': const <dynamic>[],
      'canManageReports': widget.canManageReports,
      if ((widget.client['logoBase64'] ?? widget.client['companyLogoBase64']) !=
          null)
        'companyLogoBase64':
            widget.client['logoBase64'] ?? widget.client['companyLogoBase64'],
      if (widget.client['logoMimeType'] != null)
        'companyLogoMimeType': widget.client['logoMimeType'],
    };
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ClientsFullReportScreen(business: business),
      ),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final providers = providersFromTaskNames(_assignedTasks);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: widget.embedded ? null : _clientReportAppBar(),
      body: DecoratedBox(
        decoration: ReportBrand.pageBackground,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              FadeSlideIn(child: _header(providers)),
              const SizedBox(height: 24),
              _submissionsSection(),
              const FadeSlideIn(
                delay: Duration(milliseconds: 60),
                child: SectionTitle(
                  title: 'Monthly reports',
                  icon: Icons.calendar_month_rounded,
                  subtitle:
                      'Open a month to view its report, or create a new one.',
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _reportsFuture,
                builder: (context, snapshot) {
                  final loading =
                      snapshot.connectionState == ConnectionState.waiting;
                  final reports =
                      snapshot.data ?? const <Map<String, dynamic>>[];
                  final reportMonths = reports
                      .map(
                        (report) =>
                            '${report['report_year']}-${(int.tryParse('${report['report_month'] ?? ''}') ?? 0).toString().padLeft(2, '0')}',
                      )
                      .toSet();
                  final assignmentMonths = _assignmentMonths
                      .where(
                        (month) => !reportMonths.contains(
                          '${month.year}-${month.month.toString().padLeft(2, '0')}',
                        ),
                      )
                      .toList();
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = constraints.maxWidth > 1100
                          ? 4
                          : constraints.maxWidth > 760
                          ? 3
                          : constraints.maxWidth > 500
                          ? 2
                          : 1;
                      return GridView.count(
                        crossAxisCount: cols,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        mainAxisExtent: 300,
                        children: [
                          FadeSlideIn(child: _NewReportCard(onTap: _newReport)),
                          if (loading)
                            const _LoadingCard()
                          else
                            for (var i = 0; i < reports.length; i++)
                              FadeSlideIn(
                                delay: Duration(milliseconds: 60 * (i + 1)),
                                child: _MonthReportCard(
                                  title: _monthLabel(
                                    reports[i]['report_month'],
                                    reports[i]['report_year'],
                                  ),
                                  format:
                                      (reports[i]['file_format']?.toString() ??
                                              'pdf')
                                          .toUpperCase(),
                                  created: _dateLabel(reports[i]['created_at']),
                                  tasks: _tasksForReportMonth(reports[i]),
                                  onTap: () => _openPreview(reports[i]),
                                ),
                              ),
                          if (!loading)
                            for (final assignmentMonth in assignmentMonths)
                              FadeSlideIn(
                                child: _AssignedMonthCard(
                                  month: assignmentMonth.month,
                                  year: assignmentMonth.year,
                                  tasks: assignmentMonth.tasks,
                                  onTap: () => _newReport(
                                    month: assignmentMonth.month,
                                    year: assignmentMonth.year,
                                    assignedTasks: assignmentMonth.tasks,
                                  ),
                                ),
                              ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _submissionsSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _submissionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final subs = snapshot.data ?? const <Map<String, dynamic>>[];
        if (subs.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(
              title: 'Submissions & approvals',
              icon: Icons.fact_check_rounded,
              subtitle: 'Reports you passed to admin, with status and time.',
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < subs.length; i++)
              FadeSlideIn(
                delay: Duration(milliseconds: 40 * i),
                child: Builder(
                  builder: (context) {
                    final sub = subs[i];
                    final id = (sub['id'] as num?)?.toInt();
                    final status =
                        (sub['status']?.toString() ?? 'pending').toLowerCase();
                    final period = _monthLabel(
                      sub['report_month'],
                      sub['report_year'],
                    );
                    return _SubmissionTile(
                      submission: sub,
                      onPreview:
                          id == null ? null : () => _previewSubmission(id, period),
                      onDownload: (id == null || status != 'approved')
                          ? null
                          : () => _downloadSubmission(id, period),
                    );
                  },
                ),
              ),
            const SizedBox(height: 26),
          ],
        );
      },
    );
  }

  Widget _header(List<ReportProvider> providers) {
    final logo = _logo;
    final handlerTasks = _assignmentMonths
        .expand((assignment) => assignment.tasks)
        .toList();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xfff3f8ff)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xffd9e7fb)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120b2850),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xffd7e5fb)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x160866e8),
                      blurRadius: 14,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: logo != null
                    ? Image(image: logo, fit: BoxFit.cover)
                    : Center(
                        child: Text(
                          _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: _accent,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CLIENT REPORT WORKSPACE',
                      style: TextStyle(
                        color: _accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _name,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        color: _navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Monthly performance and assigned deliverables',
                      style: TextStyle(color: _muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (providers.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'ASSIGNED PLATFORMS',
              style: TextStyle(
                color: _muted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: .9,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: providers
                  .map(
                    (p) => Tooltip(
                      message: p.label,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: p.color.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: p.color.withValues(alpha: .38),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: p.color.withValues(alpha: .10),
                              blurRadius: 9,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ProviderLogo(provider: p, size: 18),
                            const SizedBox(width: 7),
                            Text(
                              p.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: p.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (handlerTasks.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'PAGE & ADS HANDLERS',
              style: TextStyle(
                color: _muted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: .9,
              ),
            ),
            const SizedBox(height: 8),
            _HandlerAssignmentSummary(tasks: handlerTasks, maxRows: 4),
          ],
        ],
      ),
    );
  }
}

class _HandlerAssignmentSummary extends StatelessWidget {
  const _HandlerAssignmentSummary({required this.tasks, this.maxRows = 2});

  final List<dynamic> tasks;
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    final groups = <String, Map<String, dynamic>>{};
    for (final rawTask in tasks.whereType<Map>()) {
      final role = '${rawTask['role_key'] ?? ''} ${rawTask['role'] ?? ''}'
          .toLowerCase();
      final isPageHandler = role.contains('page');
      final isAdsHandler = role.contains('ads');
      if (!isPageHandler && !isAdsHandler) continue;

      final roleLabel = isPageHandler ? 'Page Handler' : 'Ads Handler';
      final employee = (rawTask['employee'] ?? rawTask['employeeName'] ?? '')
          .toString()
          .trim();
      final group = groups.putIfAbsent(
        roleLabel.toLowerCase(),
        () => {'role': roleLabel, 'employees': <String>{}, 'tasks': <String>{}},
      );
      if (employee.isNotEmpty) {
        (group['employees'] as Set<String>).add(employee);
      }
      final rawName =
          rawTask['name'] ?? rawTask['task'] ?? rawTask['deliverables'];
      final taskName = rawName?.toString().trim() ?? '';
      if (taskName.isNotEmpty) {
        (group['tasks'] as Set<String>).add(taskName);
      }
    }

    final rows = groups.values.toList();
    if (rows.isEmpty) return const SizedBox.shrink();
    final visible = rows.take(maxRows).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in visible) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: row['role'] == 'Page Handler'
                  ? const Color(0xffedf5ff)
                  : const Color(0xfffff5e8),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: row['role'] == 'Page Handler'
                    ? const Color(0xffc7ddff)
                    : const Color(0xffffdfb5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  row['role'] == 'Page Handler'
                      ? Icons.web_rounded
                      : Icons.campaign_rounded,
                  size: 17,
                  color: row['role'] == 'Page Handler'
                      ? const Color(0xff1769d2)
                      : const Color(0xffbd6900),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${row['role']} · '
                        '${(row['employees'] as Set<String>).isEmpty ? 'Unassigned' : (row['employees'] as Set<String>).join(', ')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _navy,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if ((row['tasks'] as Set<String>).isNotEmpty)
                        Text(
                          (row['tasks'] as Set<String>).join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 10.5),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (rows.length > visible.length)
          Text(
            '+${rows.length - visible.length} more Page/Ads handlers',
            style: const TextStyle(
              color: _muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

// One passed-to-admin submission: status, who passed it and when, and the
// admin's decision (approved / rejected with note) or that it is still pending.
class _SubmissionTile extends StatelessWidget {
  const _SubmissionTile({
    required this.submission,
    this.onPreview,
    this.onDownload,
  });
  final Map<String, dynamic> submission;
  final VoidCallback? onPreview;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final status =
        (submission['status']?.toString() ?? 'pending').toLowerCase();
    final period =
        _monthLabel(submission['report_month'], submission['report_year']);
    final submittedAt = _dateTimeLabel(submission['created_at']);
    final by = submission['submitted_by_name']?.toString() ?? 'You';
    final reviewer = submission['reviewed_by_name']?.toString() ?? '';
    final reviewedAt = _dateTimeLabel(submission['reviewed_at']);
    final note = submission['review_note']?.toString() ?? '';
    final color = switch (status) {
      'approved' => const Color(0xFF16A34A),
      'rejected' => const Color(0xFFE11D48),
      _ => const Color(0xFFD97706),
    };
    final icon = switch (status) {
      'approved' => Icons.verified_rounded,
      'rejected' => Icons.cancel_rounded,
      _ => Icons.hourglass_top_rounded,
    };
    final statusLine = switch (status) {
      'approved' => reviewer.isEmpty
          ? 'Approved'
          : 'Approved by $reviewer${reviewedAt.isEmpty ? '' : ' · $reviewedAt'}',
      'rejected' =>
        'Rejected${reviewer.isEmpty ? '' : ' by $reviewer'}${note.isEmpty ? '' : ' — $note'}',
      _ => 'Pending admin review',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffE6ECF6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0c082d61),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  period.isEmpty ? 'Report' : '$period report',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Passed by $by'
                  '${submittedAt.isEmpty ? '' : ' · $submittedAt'}',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  statusLine,
                  style: TextStyle(
                    color: color,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (onPreview != null || onDownload != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (onPreview != null)
                        OutlinedButton.icon(
                          onPressed: onPreview,
                          icon: const Icon(Icons.visibility_outlined, size: 16),
                          label: const Text('Preview'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _accent,
                            side: const BorderSide(color: Color(0xFFBFD6F7)),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                        ),
                      if (onDownload != null)
                        FilledButton.icon(
                          onPressed: onDownload,
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text('Download'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          StatusBadge(status),
        ],
      ),
    );
  }
}

class _MonthReportCard extends StatelessWidget {
  const _MonthReportCard({
    required this.title,
    required this.format,
    required this.created,
    required this.tasks,
    required this.onTap,
  });
  final String title;
  final String format;
  final String created;
  final List<dynamic> tasks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final providers = providersFromTaskNames(
      tasks.map(
        (task) => task is Map
            ? task['task']?.toString() ?? task['name']?.toString() ?? ''
            : task,
      ),
    );
    final color = format == 'PDF'
        ? const Color(0xFFE11D48)
        : format == 'DOCX'
        ? const Color(0xFF2563EB)
        : const Color(0xFFEA580C);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE6ECF6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      format,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    format == 'PDF'
                        ? Icons.visibility_outlined
                        : Icons.download_rounded,
                    color: _muted,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                title.isEmpty ? 'Report' : title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                created.isEmpty ? format : '$format  •  $created',
                style: const TextStyle(color: _muted, fontSize: 12.5),
              ),
              if (tasks.isNotEmpty) ...[
                const SizedBox(height: 8),
                _HandlerAssignmentSummary(tasks: tasks),
              ],
              if (providers.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: providers
                      .map(
                        (provider) => Tooltip(
                          message: provider.label,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: provider.color.withValues(alpha: .13),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: provider.color.withValues(alpha: .36),
                              ),
                            ),
                            child: ProviderLogo(provider: provider, size: 18),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              const Spacer(),
              const Text(
                'View report',
                style: TextStyle(
                  color: _accent,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssignedMonthCard extends StatelessWidget {
  const _AssignedMonthCard({
    required this.month,
    required this.year,
    required this.tasks,
    required this.onTap,
  });

  final int month;
  final int year;
  final List<dynamic> tasks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final providers = providersFromTaskNames(
      tasks.map(
        (task) => task is Map
            ? task['task']?.toString() ?? task['name']?.toString() ?? ''
            : task,
      ),
    );
    return Material(
      color: _accent.withValues(alpha: .06),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _accent.withValues(alpha: .4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: _accent,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_rounded, color: _accent),
                ],
              ),
              const Spacer(),
              Text(
                _monthLabel(month, year),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 4),
              const SizedBox(height: 8),
              _HandlerAssignmentSummary(tasks: tasks),
              if (providers.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 6,
                  children: providers
                      .map(
                        (provider) => Tooltip(
                          message: provider.label,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: provider.color.withValues(alpha: .13),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: provider.color.withValues(alpha: .36),
                              ),
                            ),
                            child: ProviderLogo(provider: provider, size: 18),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              const Spacer(),
              const Text(
                'Create report for this month',
                style: TextStyle(
                  color: _accent,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewReportCard extends StatelessWidget {
  const _NewReportCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _accent.withValues(alpha: .06),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _accent.withValues(alpha: .4),
              width: 1.4,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_rounded, color: _accent),
              ),
              const Spacer(),
              const Text(
                'Create new report',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Upload dashboards & build this month',
                style: TextStyle(color: _muted, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6ECF6)),
      ),
      child: const SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(strokeWidth: 2.4),
      ),
    );
  }
}
