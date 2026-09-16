import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../services/api_config.dart';
import '../../services/auth_service.dart';
import '../shared/employee_ui.dart';

class EmployeeSalaryPage extends StatefulWidget {
  const EmployeeSalaryPage({super.key});

  @override
  State<EmployeeSalaryPage> createState() => _EmployeeSalaryPageState();
}

class _EmployeeSalaryPageState extends State<EmployeeSalaryPage> {
  Future<_SalaryData>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SalaryData> _load() async {
    final token = context.read<AuthService>().token;
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/attendance/salary'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 15));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message']?.toString() ?? 'Could not load salary details.');
    }
    return _SalaryData.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  void _retry() {
    // setState callbacks must be synchronous. _load() returns a Future, so
    // assign it inside a block rather than returning it from the callback.
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) => EmployeeScaffold(
        route: '/employee/salary',
        title: 'Salary',
        subtitle: 'Payslips and salary details',
        desktop: _SalaryBody(future: _future!, mobile: false, retry: _retry),
        mobile: _SalaryBody(future: _future!, mobile: true, retry: _retry),
      );
}

class _SalaryBody extends StatelessWidget {
  const _SalaryBody({required this.future, required this.mobile, required this.retry});
  final Future<_SalaryData> future;
  final bool mobile;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => FutureBuilder<_SalaryData>(
        future: future,
        builder: (_, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()));
          }
          if (snapshot.hasError) {
            return _MessageCard(
              title: 'Salary details unavailable',
              message: snapshot.error.toString().replaceFirst('Exception: ', ''),
              action: FilledButton(onPressed: retry, child: const Text('Retry')),
            );
          }
          final data = snapshot.data!;
          if (!data.hasSalary) {
            return const _MessageCard(
              title: 'Salary not configured',
              message: 'Your administrator has not set your monthly salary yet. Salary and payslips will appear here after payroll is generated.',
            );
          }
          final content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (mobile) ...[
              const MobileEmployeeHeader(showGreeting: false),
              const SizedBox(height: 20),
            ],
            if (mobile) Text('Hello, ${data.employeeName} 👋', style: const TextStyle(color: employeeMuted, fontSize: 18)),
            if (mobile) const SizedBox(height: 12),
            if (mobile) const Text('Salary', style: TextStyle(color: employeeNavy, fontSize: 34, fontWeight: FontWeight.w800)),
            if (mobile) const SizedBox(height: 18),
            if (mobile) _NetPayBanner(data: data, mobile: true),
            if (mobile) const SizedBox(height: 16),
            if (mobile) _Overview(data: data),
            if (mobile) const SizedBox(height: 16),
            if (mobile) _Breakdown(data: data),
            if (!mobile)
              IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(flex: 6, child: _NetPayBanner(data: data, mobile: false)),
                const SizedBox(width: 20),
                Expanded(flex: 5, child: Column(children: [
                  _Overview(data: data),
                  const SizedBox(height: 18),
                  _Breakdown(data: data),
                ])),
              ])),
            const SizedBox(height: 20),
            _RecentPayslips(items: data.payslips, salary: data, onRequestChanged: retry),
            const SizedBox(height: 14),
            const Center(child: Text('Payslips appear after an administrator generates payroll.', style: TextStyle(color: employeeMuted, fontSize: 12))),
          ]);
          return content;
        },
      );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.title, required this.message, this.action});
  final String title;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => EmployeeCard(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.account_balance_wallet_outlined, color: employeeBlue, size: 46),
        const SizedBox(height: 14), Text(title, style: const TextStyle(color: employeeNavy, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8), ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: employeeMuted))),
        if (action != null) ...[const SizedBox(height: 18), action!],
      ])),
    ),
  );
}

class _NetPayBanner extends StatelessWidget {
  const _NetPayBanner({required this.data, required this.mobile});
  final _SalaryData data;
  final bool mobile;
  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(minHeight: mobile ? 190 : 285), padding: EdgeInsets.all(mobile ? 22 : 34),
    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF063B82), Color(0xFF031C54)]), borderRadius: BorderRadius.circular(14)),
    child: Row(children: [Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Net Pay', style: TextStyle(color: Colors.white, fontSize: mobile ? 18 : 22)), const SizedBox(height: 10),
      Text(_money(data.netPay), style: TextStyle(color: Colors.white, fontSize: mobile ? 38 : 50, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8), Text(data.period.isEmpty ? 'Payroll pending' : data.period, style: TextStyle(color: Colors.white, fontSize: mobile ? 18 : 21, fontWeight: FontWeight.w600)),
      const SizedBox(height: 13), _StatusChip(status: data.status),
    ])), Icon(Icons.account_balance_wallet_rounded, color: const Color(0xFF9DBDE8), size: mobile ? 108 : 164)]),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final paid = status.toLowerCase() == 'paid';
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: paid ? const Color(0xFF005A43) : const Color(0xFF7B5B00), borderRadius: BorderRadius.circular(7)), child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)));
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.data}); final _SalaryData data;
  @override
  Widget build(BuildContext context) => EmployeeCard(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const _Heading('Salary Overview'), const SizedBox(height: 10), _Value('Gross Salary', _money(data.gross)), const Divider(height: 1, color: employeeLine), _Value('Loss of pay (attendance)', '−${_money(data.deductions)}'), const Divider(height: 1, color: employeeLine), _Value('Net Pay', _money(data.netPay), blue: true),
  ]));
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.data}); final _SalaryData data;
  @override
  Widget build(BuildContext context) => EmployeeCard(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const _Heading('Salary Breakdown'), const SizedBox(height: 10), _Value('Basic Salary', _money(data.basic)), _Value('HRA', _money(data.hra)), _Value('Allowances', _money(data.allowances)), const Divider(height: 1, color: employeeLine), _Value('Loss of pay (unpaid days)', '−${_money(data.deductions)}'),
  ]));
}

class _RecentPayslips extends StatelessWidget {
  const _RecentPayslips({required this.items, required this.salary, required this.onRequestChanged});
  final List<_Payslip> items;
  final _SalaryData salary;
  final VoidCallback onRequestChanged;
  @override
  Widget build(BuildContext context) => EmployeeCard(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Heading('Recent Payslips'),
        const SizedBox(height: 4),
        const Text(
          'Download your generated monthly salary statements.',
          style: TextStyle(color: employeeMuted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Text(
              'No payroll has been generated yet.',
              style: TextStyle(color: employeeMuted),
            ),
          ),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PayslipTile(salary: salary, payslip: item, onRequestChanged: onRequestChanged),
          ),
        ),
      ],
    ),
  );
}

class _PayslipTile extends StatelessWidget {
  const _PayslipTile({required this.salary, required this.payslip, required this.onRequestChanged});
  final _SalaryData salary;
  final _Payslip payslip;
  final VoidCallback onRequestChanged;

  Future<void> _requestDownload(BuildContext context) async {
    try {
      final token = context.read<AuthService>().token;
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/attendance/salary/payslips/${payslip.id}/request'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body);
      if (response.statusCode >= 400 || body is! Map || body['success'] != true) {
        throw Exception(body is Map ? body['message']?.toString() ?? 'Could not request payslip.' : 'Could not request payslip.');
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(body['message']?.toString() ?? 'Payslip request sent.')));
      onRequestChanged();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final paid = payslip.status.toLowerCase() == 'paid';
    final statusColor = paid ? const Color(0xFF138A20) : const Color(0xFF9A6700);
    final statusBackground = paid ? const Color(0xFFE9F7EA) : const Color(0xFFFFF4D6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFF),
        border: Border.all(color: employeeLine),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long_outlined, color: employeeBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payslip.period,
                  style: const TextStyle(
                    color: employeeNavy,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBackground,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    payslip.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('NET PAY', style: TextStyle(color: employeeMuted, fontSize: 11)),
              const SizedBox(height: 3),
              Text(
                _money(payslip.netPay),
                style: const TextStyle(
                  color: employeeNavy,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          const SizedBox(width: 12),
          if (payslip.downloadStatus == 'approved')
            IconButton.filled(
              tooltip: 'Download approved payslip PDF',
              style: IconButton.styleFrom(backgroundColor: const Color(0xFF138A20)),
              onPressed: () => _downloadPayslip(salary, payslip),
              icon: const Icon(Icons.download_rounded),
            )
          else
            FilledButton.icon(
              onPressed: payslip.downloadStatus == 'pending' ? null : () => _requestDownload(context),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD93025)),
              icon: Icon(payslip.downloadStatus == 'pending' ? Icons.hourglass_top_rounded : Icons.download_rounded),
              label: Text(payslip.downloadStatus == 'pending' ? 'Request pending' : 'Payslip'),
            ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget { const _Heading(this.text); final String text; @override Widget build(BuildContext context) => Text(text, style: const TextStyle(color: employeeNavy, fontSize: 20, fontWeight: FontWeight.w800)); }
class _Value extends StatelessWidget { const _Value(this.label, this.value, {this.blue = false}); final String label; final String value; final bool blue; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(children: [Expanded(child: Text(label, style: const TextStyle(color: employeeMuted))), Text(value, style: TextStyle(color: blue ? employeeBlue : employeeNavy, fontWeight: FontWeight.w700))])); }
String _money(num value) => '₹${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(?<!^)(?=(\d{3})+$)'), (_) => ',')}';

Future<void> _downloadPayslip(_SalaryData salary, _Payslip payslip) async {
  final pdf = pw.Document();
  final gross = payslip.grossSalary ?? salary.gross;
  final deductions = payslip.deductions ?? salary.deductions;
  final basic = gross * 2 / 3;
  final hra = gross * 2 / 9;
  final allowances = gross - basic - hra;
  pw.Text row(String label, num value, {bool highlight = false}) => pw.Text(
    '$label: Rs. ${value.toStringAsFixed(0)}',
    style: pw.TextStyle(fontWeight: highlight ? pw.FontWeight.bold : pw.FontWeight.normal),
  );
  pdf.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    build: (_) => pw.Padding(
      padding: const pw.EdgeInsets.all(36),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('GO DIGITAL', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text('PAYSLIP', style: const pw.TextStyle(fontSize: 16)),
        pw.Divider(),
        pw.SizedBox(height: 14),
        pw.Text('Employee: ${salary.employeeName}'),
        pw.Text('Pay period: ${payslip.period}'),
        pw.Text('Payment status: ${payslip.status.toUpperCase()}'),
        if (payslip.paidAt.isNotEmpty) pw.Text('Paid on: ${payslip.paidAt}'),
        pw.SizedBox(height: 22),
        pw.Text('Earnings', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        row('Basic salary', basic),
        row('HRA', hra),
        row('Allowances', allowances),
        pw.Divider(),
        row('Gross salary', gross, highlight: true),
        pw.SizedBox(height: 18),
        pw.Text('Deductions', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        row('Loss of pay / deductions', deductions),
        if (payslip.workingDays != null) pw.Text('Working days: ${payslip.workingDays} · Paid days: ${payslip.paidDays ?? 0}'),
        pw.Divider(),
        row('Net pay', payslip.netPay, highlight: true),
        pw.Spacer(),
        pw.Text('This is a system-generated payslip.', style: const pw.TextStyle(fontSize: 10)),
      ]),
    ),
  ));
  final filename = 'payslip-${payslip.period.replaceAll(' ', '-').toLowerCase()}.pdf';
  await Printing.sharePdf(bytes: await pdf.save(), filename: filename);
}

class _SalaryData {
  _SalaryData({required this.hasSalary, this.employeeName = 'Employee', this.gross = 0, this.deductions = 0, this.netPay = 0, this.basic = 0, this.hra = 0, this.allowances = 0, this.period = '', this.status = 'draft', this.payslips = const []});
  final bool hasSalary; final String employeeName; final num gross, deductions, netPay, basic, hra, allowances; final String period, status; final List<_Payslip> payslips;
  factory _SalaryData.fromJson(Map<String, dynamic> json) => _SalaryData(
    hasSalary: json['hasSalary'] == true, employeeName: '${json['employeeName'] ?? 'Employee'}', gross: _num(json['grossSalary']), deductions: _num(json['deductions']), netPay: _num(json['netPay']), basic: _num(json['basicSalary']), hra: _num(json['hra']), allowances: _num(json['allowances']), period: '${json['period'] ?? ''}', status: '${json['status'] ?? 'draft'}', payslips: ((json['payslips'] as List?) ?? []).whereType<Map>().map((v) => _Payslip.fromJson(Map<String, dynamic>.from(v))).toList(),
  );
}
num _num(dynamic value) => value is num ? value : num.tryParse('${value ?? 0}') ?? 0;
class _Payslip {
  _Payslip(this.period, this.netPay, this.status, {required this.id, this.downloadStatus = 'not_requested', this.grossSalary, this.deductions, this.workingDays, this.paidDays, this.paidAt = ''});
  final int id;
  final String period, status, paidAt, downloadStatus;
  final num netPay;
  final num? grossSalary, deductions, workingDays, paidDays;
  factory _Payslip.fromJson(Map<String, dynamic> v) => _Payslip(
    '${v['period'] ?? ''}', _num(v['netPay']), '${v['status'] ?? 'draft'}',
    id: _num(v['id']).toInt(), downloadStatus: '${v['downloadStatus'] ?? 'not_requested'}',
    grossSalary: v['grossSalary'] == null ? null : _num(v['grossSalary']),
    deductions: v['deductions'] == null ? null : _num(v['deductions']),
    workingDays: v['workingDays'] == null ? null : _num(v['workingDays']),
    paidDays: v['paidDays'] == null ? null : _num(v['paidDays']),
    paidAt: '${v['paidAt'] ?? ''}',
  );
}
