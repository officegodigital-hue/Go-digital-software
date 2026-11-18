// lib/report/report_approvals_screen.dart
//
// Admin screen: review reports employees have "passed" for approval. Admins can
// preview the rendered PDF and approve or reject (with a note). Approval unlocks
// download for the employee.
import 'package:flutter/material.dart';

import 'data/full_report_service.dart';
import 'package:godigital_portal/shared/utils/download.dart';

const _navy = Color(0xFF142F61);
const _bg = Color(0xFFF4F7FC);
const _muted = Color(0xFF64748B);

const _months = <String>[
  '', 'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
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
  const ReportApprovalsScreen({super.key});

  @override
  State<ReportApprovalsScreen> createState() => _ReportApprovalsScreenState();
}

class _ReportApprovalsScreenState extends State<ReportApprovalsScreen> {
  final _service = const FullReportService();
  String _filter = 'pending';
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _service.listSubmissions(status: _filter == 'all' ? null : _filter);
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _future.catchError((_) => <Map<String, dynamic>>[]);
  }

  void _toast(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _preview(Map<String, dynamic> s) async {
    final id = (s['id'] as num?)?.toInt() ?? 0;
    _toast('Rendering preview…');
    try {
      final bytes = await _service.submissionPreviewBytes(id);
      final name = '${s['company_name'] ?? 'Report'}_${_period(s['report_month'], s['report_year']).replaceAll(' ', '_')}_preview.pdf';
      downloadFile(bytes, name, 'application/pdf');
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
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${s['company_name']} • ${_period(s['report_month'], s['report_year'])}'),
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
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: approve ? const Color(0xFF16A34A) : Colors.red),
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    noteController.dispose();
    if (confirmed != true) return;
    try {
      await _service.reviewSubmission(id, approve: approve, note: noteController.text.trim());
      _toast(approve ? 'Report approved.' : 'Report rejected.');
      _refresh();
    } catch (error) {
      _toast(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: _navy,
        elevation: 0.5,
        title: const Text('Report Approvals', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Row(children: [
            for (final f in const [['pending', 'Pending'], ['approved', 'Approved'], ['all', 'All']])
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ChoiceChip(
                  label: Text(f[1]),
                  selected: _filter == f[0],
                  onSelected: (_) => setState(() { _filter = f[0]; _reload(); }),
                ),
              ),
          ]),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _centerMessage('Could not load submissions', '${snapshot.error}', _refresh);
                }
                final items = snapshot.data ?? const <Map<String, dynamic>>[];
                if (items.isEmpty) {
                  return _centerMessage('Nothing here', _filter == 'pending' ? 'No reports are waiting for approval.' : 'No submissions found.', _refresh);
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  itemCount: items.length,
                  itemBuilder: (context, i) => _SubmissionCard(
                    submission: items[i],
                    onPreview: () => _preview(items[i]),
                    onApprove: () => _decide(items[i], true),
                    onReject: () => _decide(items[i], false),
                  ),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }

  Widget _centerMessage(String title, String subtitle, VoidCallback onRetry) {
    return ListView(children: [
      const SizedBox(height: 120),
      Center(child: Column(children: [
        const Icon(Icons.inbox_rounded, size: 52, color: _muted),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 6),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: _muted))),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: onRetry, child: const Text('Refresh')),
      ])),
    ]);
  }
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({required this.submission, required this.onPreview, required this.onApprove, required this.onReject});
  final Map<String, dynamic> submission;
  final VoidCallback onPreview;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final status = (submission['status']?.toString() ?? 'pending').toLowerCase();
    final company = submission['company_name']?.toString() ?? 'Client';
    final period = _period(submission['report_month'], submission['report_year']);
    final by = submission['submitted_by_name']?.toString() ?? 'Employee';
    final note = submission['review_note']?.toString() ?? '';
    final created = _date(submission['created_at']);
    final (statusColor, statusLabel) = switch (status) {
      'approved' => (const Color(0xFF16A34A), 'Approved'),
      'rejected' => (Colors.red, 'Rejected'),
      _ => (const Color(0xFFD97706), 'Pending'),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE6ECF6))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(company, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _navy))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 4),
        Text('$period  •  by $by${created.isEmpty ? '' : '  •  $created'}', style: const TextStyle(color: _muted, fontSize: 12.5)),
        if (note.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF1F5FB), borderRadius: BorderRadius.circular(10)),
            child: Text('Note: $note', style: const TextStyle(fontSize: 12.5, color: _navy)),
          ),
        ],
        const SizedBox(height: 12),
        Row(children: [
          OutlinedButton.icon(onPressed: onPreview, icon: const Icon(Icons.visibility_outlined, size: 18), label: const Text('Preview')),
          const Spacer(),
          if (status == 'pending') ...[
            TextButton(onPressed: onReject, style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Reject')),
            const SizedBox(width: 8),
            FilledButton(onPressed: onApprove, style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)), child: const Text('Approve')),
          ],
        ]),
      ]),
    );
  }
}
