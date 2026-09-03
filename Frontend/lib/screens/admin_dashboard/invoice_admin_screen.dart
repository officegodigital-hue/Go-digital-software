// name=invoice_admin_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../layouts/admin_layout.dart';
import '../../services/api_config.dart';
import '../../services/auth_service.dart';

class InvoiceAdminScreen extends StatefulWidget {
  const InvoiceAdminScreen({super.key});

  @override
  State<InvoiceAdminScreen> createState() => _InvoiceAdminScreenState();
}

class _InvoiceAdminScreenState extends State<InvoiceAdminScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  String activeFilter = "All Logs";
  bool _isFilterMenuOpen = false;

  // 🟢 1. Default month set to 0 to show "All Months" data by default
  int _selectedMonth = 0; 
  final int _selectedYear = DateTime.now().year;

  DateTime? _fromMaintenanceDate;
  DateTime? _toMaintenanceDate;

  List<Map<String, dynamic>> invoiceLedger = [];
  bool _loadingInvoices = true;
  String? _invoicesError;

  double _totalInvoiced = 0;
  double _collectedAmount = 0;
  double _outstandingBalance = 0;
  bool _loadingMetrics = true;
  String _searchQuery = '';

  static const int _invoicesPerPage = 999;
  int _currentPage = 1;

  static const Map<String, Color> _statusBg = {
    'DRAFT':   Color(0xFFF1F5F9),
    'PARTIAL': Color(0xFFFEF3C7),
    'PAID':    Color(0xFFDCFCE7),
    'OVERDUE': Color(0xFFFEE2E2),
  };
  static const Map<String, Color> _statusText = {
    'DRAFT':   Color(0xFF475569),
    'PARTIAL': Color(0xFFD97706),
    'PAID':    Color(0xFF16A34A),
    'OVERDUE': Color(0xFFDC2626),
  };

  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _triggerRecurringCheck();
    _fetchInvoices();
    _fetchMetrics();
  }

  Future<void> _triggerRecurringCheck() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = authService.token;
      await http.post(
        Uri.parse('$_baseUrl/invoices/generate-recurring'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
    } catch (e) {
      debugPrint('Recurring check error: $e');
    }
  }

  Future<void> _fetchInvoices() async {
    setState(() { _loadingInvoices = true; _invoicesError = null; });
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = authService.token;

      final response = await http.get(
        Uri.parse('$_baseUrl/invoices'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          invoiceLedger = List<Map<String, dynamic>>.from(body['data']);
          _loadingInvoices = false;
        });
      } else {
        setState(() { _invoicesError = 'Server returned ${response.statusCode}'; _loadingInvoices = false; });
      }
    } catch (e) {
      setState(() { _invoicesError = 'Cannot connect to server'; _loadingInvoices = false; });
    }
  }

  Future<void> _fetchMetrics() async {
    setState(() => _loadingMetrics = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = authService.token;

      final monthParam = _selectedMonth > 0 ? 'month=$_selectedMonth&' : '';
      final response = await http.get(
        Uri.parse('$_baseUrl/invoices/metrics?${monthParam}year=$_selectedYear'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'];
        setState(() {
          _totalInvoiced = double.tryParse(data['total_invoiced'].toString()) ?? 0;
          _collectedAmount = double.tryParse(data['collected_amount'].toString()) ?? 0;
          _outstandingBalance = double.tryParse(data['outstanding_balance'].toString()) ?? 0;
          _loadingMetrics = false;
        });
      } else {
        setState(() => _loadingMetrics = false);
      }
    } catch (e) {
      setState(() => _loadingMetrics = false);
    }
  }

  Future<void> _updateInvoiceStatus(int id, String status) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = authService.token;

      final response = await http.patch(
        Uri.parse('$_baseUrl/invoices/$id/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': status}),
      );
      if (response.statusCode == 200) {
        await _fetchInvoices();
        await _fetchMetrics();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to update status'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cannot connect to server'),
        backgroundColor: Colors.redAccent,
      ));
    }
  }

  Future<void> _deleteInvoice(int id) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = authService.token;

      final response = await http.delete(
        Uri.parse('$_baseUrl/invoices/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        await _fetchInvoices();
        await _fetchMetrics();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Invoice deleted'),
          backgroundColor: Color(0xFFDC2626),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to delete invoice'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cannot connect to server'),
        backgroundColor: Colors.redAccent,
      ));
    }
  }

  bool _isInSelectedMonth(String invoiceDate) {
    if (_selectedMonth == 0) return true; // Show all months when 0 is selected
    try {
      final date = DateFormat('dd/MM/yyyy').parse(invoiceDate);
      return date.month == _selectedMonth && date.year == _selectedYear;
    } catch (e) {
      return false;
    }
  }

  // 🟢 2. CUSTOM SORTING & FILTERING LOGIC (Draft -> Partial -> Paid, and Date-wise Newest First)
  List<Map<String, dynamic>> _getFilteredAndSortedInvoices() {
    List<Map<String, dynamic>> filtered = invoiceLedger.where((row) {
      if (!_isInSelectedMonth(row['invoice_date'] ?? '')) {
        return false;
      }

      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final invNo = (row['invoice_no'] ?? '').toString().toLowerCase();
        final clientName = (row['client_name'] ?? '').toString().toLowerCase();
        final packageType = (row['package_type'] ?? '').toString().toLowerCase();

        if (!invNo.contains(query) && !clientName.contains(query) && !packageType.contains(query)) {
          return false;
        }
      }

      if (!_isFilterMenuOpen || activeFilter == "All Logs") return true;
      final status = (row["status"] ?? 'DRAFT').toString().toUpperCase();
      if (activeFilter.toUpperCase() == "PARTIAL") return status == "PARTIAL";
      if (activeFilter.toUpperCase() == "DRAFT") return status == "DRAFT";
      if (activeFilter.toUpperCase() == "PAID") return status == "PAID";
      if (activeFilter.toUpperCase() == "OVERDUE") return status == "OVERDUE";
      return status == activeFilter.toUpperCase();
    }).toList();

    filtered.sort((a, b) {
      final statusA = (a["status"] ?? 'DRAFT').toString().toUpperCase();
      final statusB = (b["status"] ?? 'DRAFT').toString().toUpperCase();
      
      // Priority: DRAFT (1) -> PARTIAL (2) -> OVERDUE (3) -> PAID (4)
      int getPriority(String status) {
        if (status == 'DRAFT') return 1;
        if (status == 'PARTIAL') return 2;
        if (status == 'OVERDUE') return 3;
        if (status == 'PAID') return 4;
        return 5;
      }

      final pA = getPriority(statusA);
      final pB = getPriority(statusB);

      if (pA != pB) {
        return pA.compareTo(pB);
      }
      
      // Date-wise: Newest data on top (Descending)
      try {
        final dateA = DateFormat('dd/MM/yyyy').parse(a['invoice_date'] ?? '');
        final dateB = DateFormat('dd/MM/yyyy').parse(b['invoice_date'] ?? '');
        int dateCmp = dateB.compareTo(dateA);
        if (dateCmp != 0) return dateCmp;
      } catch (_) {}

      final idA = int.tryParse(a['id'].toString()) ?? 0;
      final idB = int.tryParse(b['id'].toString()) ?? 0;
      return idB.compareTo(idA);
    });

    return filtered;
  }

  String _formatCurrency(double v) {
    final isNegative = v < 0;
    v = v.abs();
    final parts = v.toStringAsFixed(2).split('.');
    String intPart = parts[0];
    String result;
    if (intPart.length <= 3) {
      result = intPart;
    } else {
      final last3 = intPart.substring(intPart.length - 3);
      final rest = intPart.substring(0, intPart.length - 3);
      final restWithCommas = rest.replaceAllMapped(
        RegExp(r'(\d)(?=(\d{2})+$)'),
        (m) => '${m[1]},',
      );
      result = '$restWithCommas,$last3';
    }
    return '${isNegative ? '-' : ''}₹$result.${parts[1]}';
  }

  Future<void> _showPDFPreview(BuildContext context, Map<String, dynamic> invoice) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = authService.token;

      final response = await http.get(
        Uri.parse('$_baseUrl/invoices/${invoice['id']}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load invoice details'), backgroundColor: Colors.redAccent));
        return;
      }

      final body = jsonDecode(response.body);
      final invoiceData = body['data'];
      if (!mounted) return;

      final double subtotal = _parseAmount(invoiceData['subtotal']);
      final double discount = _parseAmount(invoiceData['discount']);
      final double tax = _parseAmount(invoiceData['tax']);
      final double total = _parseAmount(invoiceData['total_amount']);
      final double paid = _parseAmount(invoiceData['paid_amount']);
      final double balance = _parseAmount(invoiceData['balance_amount']);

      showDialog(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 850, maxHeight: 900),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 28,
                  color: const Color(0xFF0052CC),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(width: 10, height: 10, color: Colors.white, margin: const EdgeInsets.only(left: 5)),
                      Container(width: 10, height: 10, color: Colors.white, margin: const EdgeInsets.only(left: 5)),
                      Container(width: 10, height: 10, color: Colors.white, margin: const EdgeInsets.only(left: 5)),
                      Container(width: 10, height: 10, color: Colors.white, margin: const EdgeInsets.only(left: 5)),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 140,
                          height: 50,
                          child: Image.asset('assets/images/godigital_logo.png', fit: BoxFit.contain),
                        ),
                        const SizedBox(height: 3),

                        Container(
                          decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1)),
                          child: Column(
                            children: [
                              Container(
                                decoration: const BoxDecoration(
                                  border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: const BoxDecoration(
                                          border: Border(right: BorderSide(color: Colors.black, width: 1)),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Text('GO DIGITAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: const BoxDecoration(
                                          border: Border(right: BorderSide(color: Colors.black, width: 1)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            const Text('Invoice No.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9)),
                                            const SizedBox(height: 2),
                                            Text(invoiceData['invoice_no'] ?? '', style: const TextStyle(fontSize: 10)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            const Text('Invoice Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9)),
                                            const SizedBox(height: 2),
                                            Text(invoiceData['invoice_date'] ?? '', style: const TextStyle(fontSize: 10)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(10),
                                alignment: Alignment.centerLeft,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('TO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                                    const SizedBox(height: 2),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 10),
                                      child: Text(invoiceData['client_name'] ?? '', style: const TextStyle(fontSize: 10)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        Table(
                          border: TableBorder.all(color: Colors.black, width: 1),
                          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                          columnWidths: const {
                            0: FixedColumnWidth(30),
                            1: FlexColumnWidth(2),
                            2: FixedColumnWidth(40),
                            3: FixedColumnWidth(60),
                            4: FixedColumnWidth(65),
                          },
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(color: Color(0xFFF0F0F0)),
                              children: [
                                _tableCell('S.No', bold: true, align: TextAlign.center),
                                _tableCell('DESCRIPTIONS', bold: true, align: TextAlign.center),
                                _tableCell('QTY', bold: true, align: TextAlign.center),
                                _tableCell('RATE', bold: true, align: TextAlign.center),
                                _tableCell('AMOUNT', bold: true, align: TextAlign.center),
                              ],
                            ),
                            ...((invoiceData['items'] as List?) ?? []).asMap().entries.map((entry) {
                              final i = entry.key;
                              final item = entry.value;
                              final desc = item['description'] ?? '';
                              final qty = int.tryParse(item['qty'].toString()) ?? 1;
                              final rate = _parseAmount(item['rate']);
                              final amt = _parseAmount(item['amount']);

                              return TableRow(children: [
                                _tableCell((i + 1).toString(), align: TextAlign.center),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  alignment: Alignment.centerLeft,
                                  child: desc.isEmpty
                                      ? const Text('-', style: TextStyle(fontSize: 10))
                                      : Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              desc.split('\n')[0],
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black),
                                            ),
                                            ...desc.split('\n').skip(1).map((line) {
                                              return Padding(
                                                padding: const EdgeInsets.only(top: 2),
                                                child: Text(line.trim(), style: const TextStyle(fontSize: 10, color: Colors.black)),
                                              );
                                            }),
                                          ],
                                        ),
                                ),
                                _tableCell(qty.toString(), align: TextAlign.center),
                                _tableCell(rate.toStringAsFixed(0), align: TextAlign.center),
                                _tableCell(amt.toStringAsFixed(0), align: TextAlign.center),
                              ]);
                            }),
                          ],
                        ),

                        Table(
                          border: TableBorder.all(color: Colors.black, width: 1),
                          columnWidths: const {
                            0: FlexColumnWidth(3),
                            1: FixedColumnWidth(135),
                          },
                          children: [
                            TableRow(children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                alignment: Alignment.center,
                                child: Text(
                                  (subtotal == total && discount == 0 && tax == 0) ? 'GRAND TOTAL' : 'TOTAL AMOUNT',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(4),
                                alignment: Alignment.center,
                                child: Text('₹ ${subtotal.toStringAsFixed(0)} /-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ]),

                            if (!(subtotal == total && discount == 0 && tax == 0)) ...[
                              if (discount > 0)
                                TableRow(children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    alignment: Alignment.center,
                                    child: const Text('DISCOUNT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    alignment: Alignment.center,
                                    child: Text('₹ ${discount.toStringAsFixed(0)} /-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                ]),

                              if (tax > 0)
                                TableRow(children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    alignment: Alignment.center,
                                    child: const Text('TAX (GST)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    alignment: Alignment.center,
                                    child: Text('₹ ${tax.toStringAsFixed(0)} /-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                ]),

                              TableRow(children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  alignment: Alignment.center,
                                  child: const Text('GRAND TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  alignment: Alignment.center,
                                  child: Text('₹ ${total.toStringAsFixed(0)} /-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ]),
                            ],

                            if (paid > 0)
                              TableRow(children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  alignment: Alignment.center,
                                  child: const Text('PAID AMOUNT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  alignment: Alignment.center,
                                  child: Text('₹ ${paid.toStringAsFixed(0)} /-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ]),

                            if (balance > 0)
                              TableRow(children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  alignment: Alignment.center,
                                  child: const Text('BALANCE TO BE PAID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  alignment: Alignment.center,
                                  child: Text('₹ ${balance.toStringAsFixed(0)} /-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ]),
                          ],
                        ),
                        const SizedBox(height: 10),

                        if ((invoiceData['notes'] ?? '').toString().isNotEmpty) ...[
                          const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8)),
                          const SizedBox(height: 2),
                          Text(invoiceData['notes'], style: const TextStyle(fontSize: 9)),
                          const SizedBox(height: 6),
                        ],

                        if ((invoiceData['terms'] ?? '').toString().isNotEmpty) ...[
                          const Text('Terms & Conditions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8)),
                          const SizedBox(height: 2),
                          ...invoiceData['terms'].toString().split('\n').map((term) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(term.trim(), style: const TextStyle(fontSize: 9)),
                            );
                          }),
                        ],
                        const SizedBox(height: 10),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              SizedBox(
                                width: 80,
                                height: 80,
                                child: Image.asset('assets/images/office_seal.png', fit: BoxFit.contain),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 5),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'BANK ACCOUNT DETAILS',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'NAME: GO DIGITAL | BANK: IDFC FIRST BANK | A/C NO: 10075087276 | BRANCH: KILPAUK | IFSC: IDFB0080121',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9.5, color: Color(0xFF0052CC)),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Office: +91 94449 43094 | Email: godigitalindaras@gmail.com | Website: www.godigital.ind.in',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Container(
                  color: const Color(0xFF0052CC),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('GO DIGITAL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                      SizedBox(height: 2),
                      Text('No:14, Udaya Suriyan Nagar, Guduvanchery 603202 Near Olala Cafe',
                          style: TextStyle(fontSize: 10, color: Colors.white),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        ),
                        child: const Text('Close', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w600, fontSize: 12)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await Navigator.pushNamed(
                            context, '/add-invoice',
                            arguments: {'invoiceId': invoice['id'], 'viewOnly': true},
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0052CC),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          elevation: 0,
                        ),
                        label: const Text('Open & Print', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _tableCell(String text, {bool bold = false, TextAlign align = TextAlign.left, double fontSize = 10}) {
    return Container(
      padding: const EdgeInsets.all(8),
      alignment: align == TextAlign.center ? Alignment.center : Alignment.centerLeft,
      child: Text(text, textAlign: align, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: fontSize)),
    );
  }

  double _parseAmount(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  Future<void> _selectFromMaintenanceDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _fromMaintenanceDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (pickedDate != null) {
      setState(() {
        _fromMaintenanceDate = pickedDate;
        _currentPage = 1;
      });
    }
  }

  Future<void> _selectToMaintenanceDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _toMaintenanceDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (pickedDate != null) {
      setState(() {
        _toMaintenanceDate = pickedDate;
        _currentPage = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.user;
    final bool isMainAdmin = user?['isMainAdmin'] == true || 
                             user?['isMainAdmin'] == 1 || 
                             user?['isMainAdmin'].toString() == '1' ||
                             user?['is_main_admin'] == true || 
                             user?['is_main_admin'] == 1 || 
                             user?['is_main_admin'].toString() == '1';

    final filteredInvoices = _getFilteredAndSortedInvoices();

    final totalInvoices = filteredInvoices.length;
    final totalPages = totalInvoices == 0 ? 1 : (totalInvoices / _invoicesPerPage).ceil();
    if (_currentPage > totalPages) _currentPage = totalPages;
    if (_currentPage < 1) _currentPage = 1;
    final startIndex = (_currentPage - 1) * _invoicesPerPage;
    final endIndex = (startIndex + _invoicesPerPage > totalInvoices) ? totalInvoices : startIndex + _invoicesPerPage;
    final pagedInvoices = filteredInvoices.sublist(
      startIndex < totalInvoices ? startIndex : 0,
      endIndex,
    );

    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    return AdminLayout(
      pageTitle: "Invoice Management",
      currentRoute: "/invoice",
      onSearch: (query) {
        setState(() {
          _searchQuery = query;
          _currentPage = 1;
        });
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 700;
          final isTablet = constraints.maxWidth >= 700 && constraints.maxWidth < 1100;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPageHero(isMobile),
              const SizedBox(height: 18),
              _buildQuickStats(
                isMobile: isMobile,
                isTablet: isTablet,
                total: invoiceLedger.length,
                collected: _collectedAmount,
                outstanding: _outstandingBalance,
              ),
              const SizedBox(height: 18),
              _buildInvoiceWorkspace(
                isMobile: isMobile,
                invoices: pagedInvoices,
                totalInvoices: totalInvoices,
                startIndex: startIndex,
                endIndex: endIndex,
                totalPages: totalPages,
                isMainAdmin: isMainAdmin,
                monthNames: monthNames,
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPageHero(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 22),
      decoration: BoxDecoration(
        color: const Color(0xFF0052CC),
        borderRadius: BorderRadius.circular(isMobile ? 20 : 22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0052CC).withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heroText(),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: _createButton()),
              ],
            )
          : Row(
              children: [
                Expanded(child: _heroText()),
                _createButton(),
              ],
            ),
    );
  }

  Widget _heroText() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'INVOICE CENTER',
          style: TextStyle(
            color: Color(0xFFBFD5FF),
            fontSize: 10,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'Invoices Management',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'Track real-time customer billing statements, distributions, and accounts receivable collections.',
          style: TextStyle(
            color: Color(0xFFDCE8FF),
            fontSize: 11,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _createButton() {
    return ElevatedButton.icon(
      onPressed: () async {
        await Navigator.pushNamed(context, '/add-invoice');
        _fetchInvoices();
        _fetchMetrics();
      },
      icon: const Icon(Icons.add_rounded, color: Color(0xFF0052CC)),
      label: const Text(
        'Add Invoice',
        style: TextStyle(
          color: Color(0xFF0052CC),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildQuickStats({
    required bool isMobile,
    required bool isTablet,
    required int total,
    required double collected,
    required double outstanding,
  }) {
    final stats = [
      {
        'label': 'Total Invoiced',
        'value': _loadingMetrics ? '—' : _formatCurrency(_totalInvoiced),
        'icon': Icons.receipt_long_rounded,
        'color': const Color(0xFF2563EB),
      },
      {
        'label': 'Collected Amount',
        'value': _loadingMetrics ? '—' : _formatCurrency(collected),
        'icon': Icons.check_circle_outline_rounded,
        'color': const Color(0xFF16A34A),
      },
      {
        'label': 'Outstanding Balance',
        'value': _loadingMetrics ? '—' : _formatCurrency(outstanding),
        'icon': Icons.error_outline_rounded,
        'color': const Color(0xFFEA580C),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 2 : 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: isMobile ? 1.85 : (isTablet ? 2.5 : 3.0),
      ),
      itemBuilder: (context, index) {
        final item = stats[index];
        final color = item['color'] as Color;
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 14 : 18,
            vertical: isMobile ? 10 : 14,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: isMobile ? 38 : 44,
                height: isMobile ? 38 : 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  item['icon'] as IconData,
                  color: color,
                  size: isMobile ? 20 : 22,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['value'] as String,
                      style: TextStyle(
                        color: const Color(0xFF172033),
                        fontSize: isMobile ? 18 : 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item['label'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInvoiceWorkspace({
    required bool isMobile,
    required List<Map<String, dynamic>> invoices,
    required int totalInvoices,
    required int startIndex,
    required int endIndex,
    required int totalPages,
    required bool isMainAdmin,
    required List<String> monthNames,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 20 : 22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 14 : 18),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _workspaceTitle(totalInvoices),
                      const SizedBox(height: 14),
                      _buildFilterRow(monthNames, fullWidth: true),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: _workspaceTitle(totalInvoices)),
                      _buildFilterRow(monthNames),
                    ],
                  ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          if (_loadingInvoices)
            _buildLoadingState()
          else if (_invoicesError != null)
            _buildErrorState()
          else if (invoices.isEmpty)
            _buildEmptyState()
          else if (isMobile)
            _buildMobileInvoiceList(invoices, startIndex, isMainAdmin)
          else
            _buildDesktopInvoiceTable(invoices, startIndex, isMainAdmin),
          _buildPagination(
            totalInvoices: totalInvoices,
            startIndex: startIndex,
            endIndex: endIndex,
            totalPages: totalPages,
            isMobile: isMobile,
          ),
        ],
      ),
    );
  }

  Widget _workspaceTitle(int total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Invoice History',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Color(0xFF172033),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '$total ledger file${total == 1 ? '' : 's'} available',
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterRow(List<String> monthNames, {bool fullWidth = false}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedMonth,
              isDense: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
              items: [
                const DropdownMenuItem(value: 0, child: Text('All Months')),
                ...List.generate(12, (i) => i + 1).map((month) {
                  return DropdownMenuItem(
                    value: month,
                    child: Text(monthNames[month - 1]),
                  );
                }),
              ],
              onChanged: (month) {
                if (month != null) {
                  setState(() {
                    _selectedMonth = month;
                    _currentPage = 1;
                  });
                  _fetchMetrics();
                }
              },
            ),
          ),
        ),
        GestureDetector(
          onTap: () => _selectFromMaintenanceDate(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: _fromMaintenanceDate != null ? const Color(0xFF0052CC) : const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(12),
              color: _fromMaintenanceDate != null ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.date_range_rounded, size: 14, color: _fromMaintenanceDate != null ? const Color(0xFF0052CC) : const Color(0xFF64748B)),
                const SizedBox(width: 5),
                Text(
                  _fromMaintenanceDate != null ? DateFormat('dd/MM').format(_fromMaintenanceDate!) : 'From',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _fromMaintenanceDate != null ? const Color(0xFF0052CC) : const Color(0xFF334155)),
                ),
              ],
            ),
          ),
        ),
        GestureDetector(
          onTap: () => _selectToMaintenanceDate(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: _toMaintenanceDate != null ? const Color(0xFF0052CC) : const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(12),
              color: _toMaintenanceDate != null ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.date_range_rounded, size: 14, color: _toMaintenanceDate != null ? const Color(0xFF0052CC) : const Color(0xFF64748B)),
                const SizedBox(width: 5),
                Text(
                  _toMaintenanceDate != null ? DateFormat('dd/MM').format(_toMaintenanceDate!) : 'To',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _toMaintenanceDate != null ? const Color(0xFF0052CC) : const Color(0xFF334155)),
                ),
              ],
            ),
          ),
        ),
        if (_fromMaintenanceDate != null || _toMaintenanceDate != null)
          GestureDetector(
            onTap: () {
              setState(() {
                _fromMaintenanceDate = null;
                _toMaintenanceDate = null;
                _currentPage = 1;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFDC2626)),
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFFFEE2E2),
              ),
              child: const Icon(Icons.close, size: 12, color: Color(0xFFDC2626)),
            ),
          ),
        if (_isFilterMenuOpen) ...[
          _buildFilterTab("All Logs"),
          _buildFilterTab("Draft"), // 🟢 Added Draft filter tab option
          _buildFilterTab("Paid"),
          _buildFilterTab("Partial"),
          _buildFilterTab("Overdue"),
        ],
        InkWell(
          onTap: () {
            setState(() {
              _isFilterMenuOpen = !_isFilterMenuOpen;
              if (!_isFilterMenuOpen) {
                activeFilter = "All Logs";
                _currentPage = 1;
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _isFilterMenuOpen ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_isFilterMenuOpen ? Icons.filter_list_off_rounded : Icons.filter_list_rounded, size: 14, color: const Color(0xFF64748B)),
                const SizedBox(width: 5),
                Text(_isFilterMenuOpen ? "Hide Filter" : "Filter", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 54),
      child: Center(
        child: CircularProgressIndicator(color: Color(0xFF0052CC)),
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 54),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 34, color: Color(0xFF94A3B8)),
            const SizedBox(height: 10),
            Text(_invoicesError ?? 'Unable to load invoices', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _fetchInvoices,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 58, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 42, color: Color(0xFF94A3B8)),
            SizedBox(height: 10),
            Text('No invoices found', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF334155))),
            SizedBox(height: 4),
            Text('Try changing the filter or create a new invoice.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopInvoiceTable(
    List<Map<String, dynamic>> invoices,
    int startIndex,
    bool isMainAdmin,
  ) {
    const double tableMinWidth = 1600;

    return Scrollbar(
      controller: _horizontalController,
      thumbVisibility: true,
      interactive: true,
      notificationPredicate: (notification) => notification.metrics.axis == Axis.horizontal,
      child: SingleChildScrollView(
        controller: _horizontalController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: SizedBox(
          width: tableMinWidth,
          child: Column(
            children: [
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                color: const Color(0xFFF8FAFC),
                child: Row(
                  children: [
                    const Expanded(flex: 1, child: Text("S.NO", style: _tableHeadingStyle)),
                    const Expanded(flex: 2, child: Text("INVOICE DATE", style: _tableHeadingStyle)),
                    const Expanded(flex: 2, child: Text("INVOICE NO", style: _tableHeadingStyle)),
                    const Expanded(flex: 2, child: Text("CLIENT NAME", style: _tableHeadingStyle)),
                    const Expanded(flex: 2, child: Text("PACKAGE DETAILS", style: _tableHeadingStyle)),
                    const Expanded(flex: 2, child: Text("MAINTENANCE DATE", style: _tableHeadingStyle)),
                    const Expanded(flex: 2, child: Text("TOTAL AMOUNT", style: _tableHeadingStyle)),
                    const Expanded(flex: 2, child: Text("PAID AMOUNT", style: _tableHeadingStyle)),
                    const Expanded(flex: 2, child: Text("PENDING AMOUNT", style: _tableHeadingStyle)),
                    const Expanded(flex: 2, child: Text("STATUS", style: _tableHeadingStyle)),
                    if (isMainAdmin)
                      const Expanded(flex: 2, child: Text("CREATED BY", style: _tableHeadingStyle)),
                    const Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.center,
                        child: Text("ACTION", style: _tableHeadingStyle),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              SizedBox(
                height: 460,
                child: Scrollbar(
                  controller: _verticalController,
                  thumbVisibility: true,
                  interactive: true,
                  notificationPredicate: (notification) => notification.metrics.axis == Axis.vertical,
                  child: ListView.separated(
                    controller: _verticalController,
                    primary: false,
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    itemCount: invoices.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    itemBuilder: (context, index) => _buildInvoiceHistoryRow(invoices[index], isMainAdmin),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileInvoiceList(
    List<Map<String, dynamic>> invoices,
    int startIndex,
    bool isMainAdmin,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: invoices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _buildMobileInvoiceCard(invoices[index], startIndex + index + 1, isMainAdmin),
    );
  }

  Widget _buildMobileInvoiceCard(
    Map<String, dynamic> row,
    int serialNo,
    bool isMainAdmin,
  ) {
    final int id = row["id"];
    final String invNo = row["invoice_no"] ?? '';
    final String client = row["client_name"] ?? '';
    final String type = row["package_type"] ?? '-';
    final String invoiceDate = row["invoice_date"] ?? '';
    final double total = double.tryParse(row["total_amount"]?.toString() ?? '0') ?? 0;
    final String amount = _formatCurrency(total);
    final String status = (row["status"] ?? 'DRAFT').toString().toUpperCase();
    final String createdByName = row["created_by_name"] ?? 'Main Admin';
    final double paid = double.tryParse(row["paid_amount"]?.toString() ?? '0') ?? 0;
    final double pending = double.tryParse(row["balance_amount"]?.toString() ?? '0') ?? 0;

    final statusBg = _statusBg[status] ?? const Color(0xFFF1F5F9);
    final statusText = _statusText[status] ?? const Color(0xFF475569);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFDFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  serialNo.toString(),
                  style: const TextStyle(color: Color(0xFF0052CC), fontSize: 11, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  invNo,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF172033)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
                child: Text(status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: statusText)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(client, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF172033))),
          const SizedBox(height: 4),
          Text('Package: $type', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          if (isMainAdmin) ...[
            const SizedBox(height: 4),
            Text('Created by: $createdByName', style: const TextStyle(fontSize: 10, color: Color(0xFF0052CC), fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _mobileInfoTile(icon: Icons.currency_rupee_rounded, label: 'Total', value: amount, valueBold: true)),
              const SizedBox(width: 8),
              Expanded(child: _mobileInfoTile(icon: Icons.check_circle_outline_rounded, label: 'Paid', value: _formatCurrency(paid))),
              const SizedBox(width: 8),
              Expanded(child: _mobileInfoTile(icon: Icons.error_outline_rounded, label: 'Pending', value: _formatCurrency(pending))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(invoiceDate, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
              const Spacer(),
              _mobileActionButton(
                icon: Icons.picture_as_pdf_outlined,
                color: const Color(0xFFDC2626),
                tooltip: 'PDF Preview',
                onTap: () => _showPDFPreview(context, row),
              ),
              _mobileActionButton(
                icon: Icons.visibility_outlined,
                color: const Color(0xFF475569),
                tooltip: 'View',
                onTap: () async {
                  await Navigator.pushNamed(context, '/add-invoice', arguments: {'invoiceId': id, 'viewOnly': true});
                  _fetchInvoices();
                  _fetchMetrics();
                },
              ),
              _mobileActionButton(
                icon: Icons.edit_outlined,
                color: const Color(0xFF0052CC),
                tooltip: 'Edit',
                onTap: () async {
                  await Navigator.pushNamed(context, '/add-invoice', arguments: {'invoiceId': id, 'viewOnly': false});
                  _fetchInvoices();
                  _fetchMetrics();
                },
              ),
              _mobileActionButton(
                icon: Icons.delete_outline_rounded,
                color: const Color(0xFFDC2626),
                tooltip: 'Delete',
                onTap: () => _deleteInvoice(id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mobileInfoTile({required IconData icon, required String label, required String value, bool valueBold = false}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 8, color: Color(0xFF94A3B8), fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: const Color(0xFF334155), fontWeight: valueBold ? FontWeight.w900 : FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _mobileActionButton({required IconData icon, required Color color, required String tooltip, required VoidCallback onTap}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  Widget _buildPagination({
    required int totalInvoices,
    required int startIndex,
    required int endIndex,
    required int totalPages,
    required bool isMobile,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      child: isMobile
          ? Column(
              children: [
                Text(
                  totalInvoices == 0 ? 'Showing 0 of 0 ledger files' : 'Showing ${startIndex + 1}–$endIndex of $totalInvoices ledger files',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                _paginationControls(totalPages),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Text(
                    totalInvoices == 0 ? 'Showing 0 of 0 ledger files' : 'Showing ${startIndex + 1} to $endIndex of $totalInvoices ledger files',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ),
                _paginationControls(totalPages),
              ],
            ),
    );
  }

  Widget _paginationControls(int totalPages) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPageButton('<', false, onTap: _currentPage > 1 ? () => setState(() => _currentPage--) : null),
        if (totalPages <= 5)
          for (int p = 1; p <= totalPages; p++)
            _buildPageButton('$p', p == _currentPage, onTap: () => setState(() => _currentPage = p))
        else ...[
          _buildPageButton('1', _currentPage == 1, onTap: () => setState(() => _currentPage = 1)),
          if (_currentPage > 3) const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('...')),
          for (final p in <int>{
            (_currentPage - 1).clamp(2, totalPages - 1) as int,
            _currentPage.clamp(2, totalPages - 1) as int,
            (_currentPage + 1).clamp(2, totalPages - 1) as int,
          })
            _buildPageButton('$p', p == _currentPage, onTap: () => setState(() => _currentPage = p)),
          if (_currentPage < totalPages - 2) const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('...')),
          _buildPageButton('$totalPages', _currentPage == totalPages, onTap: () => setState(() => _currentPage = totalPages)),
        ],
        _buildPageButton('>', false, onTap: _currentPage < totalPages ? () => setState(() => _currentPage++) : null),
      ],
    );
  }

  Widget _buildPageButton(String text, bool isActive, {VoidCallback? onTap}) {
    final bool isDisabled = onTap == null && !isActive;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0052CC) : Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: isActive ? const Color(0xFF0052CC) : const Color(0xFFE2E8F0)),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isActive ? Colors.white : (isDisabled ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceHistoryRow(Map<String, dynamic> row, bool isMainAdmin) {
    final int id = row["id"];
    final String invNo = row["invoice_no"] ?? '';
    final String client = row["client_name"] ?? '';
    final String type = row["package_type"] ?? '-';
    final String invoiceDate = row["invoice_date"] ?? '';
    final String maintenanceDate = row["maintenance_date"] ?? '';
    final double total = double.tryParse(row["total_amount"]?.toString() ?? '0') ?? 0;
    final String amount = _formatCurrency(total);
    final String status = (row["status"] ?? 'DRAFT').toString().toUpperCase();
    final String linkedQuotNo = row["linked_quotation_no"] ?? '';
    final int? linkedQuotId = row["linked_quotation_id"];
    final String createdByName = row["created_by_name"] ?? 'Main Admin';
    
    final double paid = double.tryParse(row["paid_amount"]?.toString() ?? '0') ?? 0;
    final double pending = double.tryParse(row["balance_amount"]?.toString() ?? '0') ?? 0;

    final statusBg = _statusBg[status] ?? const Color(0xFFF1F5F9);
    final statusText = _statusText[status] ?? const Color(0xFF475569);

    return Container(
      height: 65,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(id.toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
          ),
          Expanded(
            flex: 2,
            child: Text(invoiceDate, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(invNo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF0052CC))),
                if (linkedQuotNo.isNotEmpty)
                  GestureDetector(
                    onTap: linkedQuotId != null
                        ? () => Navigator.pushNamed(context, '/create-quotation', arguments: {'quotationId': linkedQuotId, 'viewOnly': true})
                        : null,
                    child: Text('↗ $linkedQuotNo', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(client, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF172033))),
          ),
          Expanded(
            flex: 2,
            child: Text(type, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 2,
            child: Text(maintenanceDate, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 2,
            child: Text(amount, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF172033))),
          ),
          Expanded(
            flex: 2,
            child: Text(_formatCurrency(paid), style: const TextStyle(fontSize: 10, color: Color(0xFF16A34A), fontWeight: FontWeight.w700)),
          ),
          Expanded(
            flex: 2,
            child: Text(_formatCurrency(pending), style: const TextStyle(fontSize: 10, color: Color(0xFFDC2626), fontWeight: FontWeight.w700)),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
                child: Text(status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: statusText)),
              ),
            ),
          ),
          if (isMainAdmin)
            Expanded(
              flex: 2,
              child: Text(createdByName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0052CC))),
            ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _desktopActionIcon(
                    icon: Icons.picture_as_pdf_outlined,
                    color: const Color(0xFFDC2626),
                    tooltip: 'PDF Preview',
                    onTap: () => _showPDFPreview(context, row),
                  ),
                  _desktopActionIcon(
                    icon: Icons.visibility_outlined,
                    color: const Color(0xFF475569),
                    tooltip: 'View',
                    onTap: () async {
                      await Navigator.pushNamed(context, '/add-invoice', arguments: {'invoiceId': id, 'viewOnly': true});
                      _fetchInvoices();
                      _fetchMetrics();
                    },
                  ),
                  _desktopActionIcon(
                    icon: Icons.edit_outlined,
                    color: const Color(0xFF0052CC),
                    tooltip: 'Edit',
                    onTap: () async {
                      await Navigator.pushNamed(context, '/add-invoice', arguments: {'invoiceId': id, 'viewOnly': false});
                      _fetchInvoices();
                      _fetchMetrics();
                    },
                  ),
                  _desktopActionIcon(
                    icon: Icons.delete_outline_rounded,
                    color: const Color(0xFFDC2626),
                    tooltip: 'Delete',
                    onTap: () => _deleteInvoice(id),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopActionIcon({required IconData icon, required Color color, required String tooltip, required VoidCallback onTap}) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: color),
        splashRadius: 20,
      ),
    );
  }

  Widget _buildFilterTab(String label) {
    final bool isActive = activeFilter.toUpperCase() == label.toUpperCase();

    return OutlinedButton(
      onPressed: () => setState(() {
        activeFilter = label;
        _isFilterMenuOpen = true;
        _currentPage = 1;
      }),
      style: OutlinedButton.styleFrom(
        backgroundColor: isActive ? const Color(0xFF0052CC) : Colors.transparent,
        side: BorderSide(
          color: isActive ? const Color(0xFF0052CC) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.white : const Color(0xFF64748B),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static const TextStyle _tableHeadingStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w800,
    color: Color(0xFF64748B),
    letterSpacing: 0.5,
  );
}