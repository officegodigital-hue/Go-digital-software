// lib/report/report_approvals_screen.dart
//
// Admin screen: review reports employees have "passed" for approval. Admins can
// preview the rendered PDF and approve or reject (with a note). Approval unlocks
// download for the employee.
import 'package:flutter/material.dart';

import 'data/full_report_service.dart';
import 'report_admin_shell.dart';
import 'report_brand.dart';
import 'report_preview_screen.dart';
import 'package:godigital_portal/core/widgets/notification_robot.dart';

const _navy = Color(0xFF142F61);
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

String _period(dynamic month, dynamic year) {
  final m = int.tryParse('${month ?? ''}') ?? 0;
  final name = (m >= 1 && m <= 12) ? _months[m] : '';
  return [name, '$year'].where((p) => p.trim().isNotEmpty).join(' ');
}

String _date(dynamic value) {
  final dt = DateTime.tryParse('${value ?? ''}'.replaceFirst(' ', 'T'));
  if (dt == null) return '';
  final d = dt.toLocal();
  return '${d.day.toString().padLeft(2, '0')} ${_months[d.month].substring(0, 3)} ${d.year}';
}

class ReportApprovalsScreen extends StatefulWidget {
  const ReportApprovalsScreen({super.key, this.initialFilter = 'pending'});

  final String initialFilter;

  @override
  State<ReportApprovalsScreen> createState() => _ReportApprovalsScreenState();
}

class _ReportApprovalsScreenState extends State<ReportApprovalsScreen> {
  final _service = const FullReportService();
  late String _filter = widget.initialFilter;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _service.listSubmissions(
      status: _filter == 'all' ? null : _filter,
    );
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _future.catchError((_) => <Map<String, dynamic>>[]);
  }

  void _toast(String message) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _preview(Map<String, dynamic> s) async {
    final id = (s['id'] as num?)?.toInt() ?? 0;
    _toast('Rendering preview…');
    try {
      final bytes = await _service.submissionPreviewBytes(id);
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ReportPreviewScreen(
            title: s['company_name']?.toString() ?? 'Report',
            subtitle: _period(s['report_month'], s['report_year']),
            loadBytes: () async => bytes,
          ),
        ),
      );
    } catch (error) {
      _toast(error.toString());
    }
  }

  Future<void> _decide(Map<String, dynamic> s, bool approve) async {
    final id = (s['id'] as num?)?.toInt() ?? 0;
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Approve report?' : 'Reject report?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${s['company_name']} • ${_period(s['report_month'], s['report_year'])}',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: approve ? 'Note (optional)' : 'Reason for rejection',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: approve ? const Color(0xFF16A34A) : Colors.red,
            ),
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    noteController.dispose();
    if (confirmed != true) return;
    try {
      await _service.reviewSubmission(
        id,
        approve: approve,
        note: noteController.text.trim(),
      );
      if (mounted) {
        final company = s['company_name']?.toString() ?? 'the client';
        ReportRobotScope.of(context)?.play(
          approve ? RobotEvent.taskApproved : RobotEvent.taskRejected,
          approve
              ? 'Report approved for $company.'
              : 'Report rejected for $company.',
        );
      }
      _toast(approve ? 'Report approved.' : 'Report rejected.');
      _refresh();
    } catch (error) {
      _toast(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ReportWorkspace(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 4),
              child: const ReportHeroHeader(
                title: 'Report Approvals',
                subtitle: 'Review and approve reports submitted by your team.',
                icon: Icons.fact_check_rounded,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 6),
              child: Row(
                children: [
                  for (final f in const [
                    ['pending', 'Pending', 'schedule'],
                    ['approved', 'Approved', 'check'],
                    ['all', 'All', 'all'],
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label: Text(f[1]),
                        selected: _filter == f[0],
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _filter == f[0]
                              ? Colors.white
                              : ReportBrand.navy,
                        ),
                        selectedColor: ReportBrand.blue,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: _filter == f[0]
                              ? ReportBrand.blue
                              : ReportBrand.cardBorder,
                        ),
                        onSelected: (_) => setState(() {
                          _filter = f[0];
                          _reload();
                        }),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const BrandLoader(label: 'Loading submissions…');
                    }
                    if (snapshot.hasError) {
                      return _stateList(
                        BrandEmptyState(
                          icon: Icons.cloud_off_rounded,
                          title: 'Could not load submissions',
                          subtitle: '${snapshot.error}',
                          actionLabel: 'Refresh',
                          onAction: _refresh,
                          isError: true,
                        ),
                      );
                    }
                    final items =
                        snapshot.data ?? const <Map<String, dynamic>>[];
                    if (items.isEmpty) {
                      return _stateList(
                        BrandEmptyState(
                          icon: Icons.inbox_rounded,
                          title: 'Nothing here',
                          subtitle: _filter == 'pending'
                              ? 'No reports are waiting for approval.'
                              : 'No submissions found.',
                          actionLabel: 'Refresh',
                          onAction: _refresh,
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                      itemCount: items.length,
                      itemBuilder: (context, i) => FadeSlideIn(
                        delay: Duration(milliseconds: 50 * i),
                        child: _SubmissionCard(
                          submission: items[i],
                          onPreview: () => _preview(items[i]),
                          onApprove: () => _decide(items[i], true),
                          onReject: () => _decide(items[i], false),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Keeps pull-to-refresh working while showing a full-height state widget.
  Widget _stateList(Widget child) =>
      ListView(children: [SizedBox(height: 90), child]);
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({
    required this.submission,
    required this.onPreview,
    required this.onApprove,
    required this.onReject,
  });
  final Map<String, dynamic> submission;
  final VoidCallback onPreview;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final status = (submission['status']?.toString() ?? 'pending')
        .toLowerCase();
    final company = submission['company_name']?.toString() ?? 'Client';
    final period = _period(
      submission['report_month'],
      submission['report_year'],
    );
    final by = submission['submitted_by_name']?.toString() ?? 'Employee';
    final note = submission['review_note']?.toString() ?? '';
    final created = _date(submission['created_at']);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              company,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: _navy,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                _SubmissionDetail(
                  icon: Icons.calendar_month_rounded,
                  label: period,
                ),
                _SubmissionDetail(
                  icon: Icons.person_outline_rounded,
                  label: by,
                ),
                if (created.isNotEmpty)
                  _SubmissionDetail(
                    icon: Icons.schedule_rounded,
                    label: created,
                  ),
              ],
            ),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Review note: $note',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: status == 'rejected'
                      ? const Color(0xffc53045)
                      : const Color(0xff526b91),
                  fontSize: 11.5,
                ),
              ),
            ],
          ],
        );
        final actions = Wrap(
          spacing: 7,
          runSpacing: 7,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: onPreview,
              icon: const Icon(Icons.visibility_outlined, size: 17),
              label: const Text('Preview'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ReportBrand.blue,
                side: const BorderSide(color: Color(0xffd1e2fb)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (status == 'pending') ...[
              TextButton(
                onPressed: onReject,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xffd9364f),
                ),
                child: const Text('Reject'),
              ),
              FilledButton.icon(
                onPressed: onApprove,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff109b65),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.check_rounded, size: 17),
                label: const Text('Approve'),
              ),
            ],
          ],
        );

        return ReportPanel(
          margin: const EdgeInsets.only(bottom: 13),
          padding: const EdgeInsets.all(17),
          highlighted: status == 'pending',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xffeaf3ff), Color(0xfff7faff)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xffdce9fa)),
                    ),
                    child: Text(
                      company.isEmpty ? '?' : company[0].toUpperCase(),
                      style: const TextStyle(
                        color: ReportBrand.blue,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(child: details),
                  if (!compact) ...[
                    const SizedBox(width: 14),
                    StatusBadge(status),
                  ],
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  if (compact) ...[
                    StatusBadge(status),
                    const SizedBox(width: 8),
                  ],
                  const Spacer(),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: actions,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SubmissionDetail extends StatelessWidget {
  const _SubmissionDetail({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xff7890b2)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: _muted, fontSize: 11.5)),
      ],
    );
  }
}
