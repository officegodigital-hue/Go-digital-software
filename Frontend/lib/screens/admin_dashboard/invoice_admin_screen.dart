import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../layouts/admin_layout.dart';
import '../../services/api_config.dart';


class InvoiceAdminScreen extends StatefulWidget {
  const InvoiceAdminScreen({super.key});

  @override
  State<InvoiceAdminScreen> createState() => _InvoiceAdminScreenState();
}

class _InvoiceAdminScreenState extends State<InvoiceAdminScreen> {
  // static const String _baseUrl = '/api';
  static String get _baseUrl => ApiConfig.baseUrl;

  String activeFilter = "All Logs";
  bool _isFilterMenuOpen = false;

  int _selectedMonth = DateTime.now().month;
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
    _fetchInvoices();
    _fetchMetrics();
  }

  Future<void> _fetchInvoices() async {
    setState(() { _loadingInvoices = true; _invoicesError = null; });
    try {
      final response = await http.get(Uri.parse('$_baseUrl/invoices'));
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
      final response = await http.get(Uri.parse('$_baseUrl/invoices/metrics'));
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
      final response = await http.patch(
        Uri.parse('$_baseUrl/invoices/$id/status'),
        headers: {'Content-Type': 'application/json'},
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
      final response = await http.delete(Uri.parse('$_baseUrl/invoices/$id'));
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

  // bool _isInSelectedMonth(String invoiceDate) {
  //   try {
  //     final date = DateFormat('dd/MM/yyyy').parse(invoiceDate);
  //     return date.month == _selectedMonth && date.year == _selectedYear;
  //   } catch (e) {
  //     return false;
  //   }
  // }

bool _isInSelectedMonth(String invoiceDate) {
  try {
    final date = DateFormat('dd/MM/yyyy').parse(invoiceDate);
    return date.month == _selectedMonth && date.year == _selectedYear;
  } catch (e) {
    return false;
  }
}

  // bool _isInMaintenanceDateRange(String maintenanceDate) {
  bool _isInInvoiceDateRange(String invoiceDate) {
    try {
      // final date = DateFormat('dd/MM/yyyy').parse(maintenanceDate);
      final date = DateFormat('dd/MM/yyyy').parse(invoiceDate);

      if (_fromMaintenanceDate != null && _toMaintenanceDate != null) {
        return date.isAfter(_fromMaintenanceDate!) && date.isBefore(_toMaintenanceDate!.add(const Duration(days: 1)));
      }
      
      if (_fromMaintenanceDate != null) {
        return date.isAfter(_fromMaintenanceDate!);
      }
      
      if (_toMaintenanceDate != null) {
        return date.isBefore(_toMaintenanceDate!.add(const Duration(days: 1)));
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  

  List<Map<String, dynamic>> _getFilteredAndSortedInvoices() {
    List<Map<String, dynamic>> filtered = invoiceLedger.where((row) {
      if (!_isInSelectedMonth(row['invoice_date'] ?? '')) {
        return false;
      }

//       if (!_isInSelectedMonth(row['maintenance_date'] ?? '')) {
//   return false;
// }

      if (!_isFilterMenuOpen || activeFilter == "All Logs") return true;
      final status = (row["status"] ?? '').toString().toUpperCase();
      if (activeFilter == "Partial") return status == "PARTIAL";
      return status == activeFilter.toUpperCase();
    }).toList();

    filtered.sort((a, b) {
      final statusA = (a["status"] ?? 'DRAFT').toString().toUpperCase();
      final statusB = (b["status"] ?? 'DRAFT').toString().toUpperCase();
      
      if (statusA == 'PAID' && statusB != 'PAID') return 1;
      if (statusA != 'PAID' && statusB == 'PAID') return -1;
      
      try {
        // final dateA = DateFormat('dd/MM/yyyy').parse(a['maintenance_date'] ?? '');
        // final dateB = DateFormat('dd/MM/yyyy').parse(b['maintenance_date'] ?? '');

        final dateA = DateFormat('dd/MM/yyyy').parse(a['invoice_date'] ?? '');
final dateB = DateFormat('dd/MM/yyyy').parse(b['invoice_date'] ?? '');

        return dateA.compareTo(dateB);
      } catch (e) {
        return 0;
      }
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



// ✅ EXACT HEADER LAYOUT MATCHING YOUR PRINT

// ✅ EXACT PDF PREVIEW - CORRECTED LAYOUT ORDER

Future<void> _showPDFPreview(BuildContext context, Map<String, dynamic> invoice) async {
  try {
    
    final response = await http.get(Uri.parse('$_baseUrl/invoices/${invoice['id']}'));
    if (response.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load invoice details'), backgroundColor: Colors.redAccent));
      return;
    }

    final body = jsonDecode(response.body);
    final invoiceData = body['data'];
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 850, maxHeight: 900),
          color: Colors.white,
          
            margin: EdgeInsets.zero,
          child: Column(
            
              crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                  height: 28,
                  color: const Color(0xFF1F4E9E),
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
                  padding: const EdgeInsets.fromLTRB(30, 16, 30, 10),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo + Title
                      SizedBox(
                          width: 140,
                          height: 50,
                          // decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1)),
                          child: Image.asset('assets/images/godigital_logo.png', fit: BoxFit.contain),
                        ),
                      const SizedBox(height: 14),

                     // ================= HEADER (Same as PDF) =================
Container(
  decoration: BoxDecoration(
    border: Border.all(color: Colors.black, width: 1),
  ),
  child: Column(
    children: [
      Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.black, width: 1),
          ),
        ),
        child: Row(
          children: [
            // GO DIGITAL
            Expanded(
              flex: 2,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Colors.black, width: 1),
                  ),
                ),
                child: const Text(
                  'GO DIGITAL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),

            // Invoice Number
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Colors.black, width: 1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Invoice No.',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      invoiceData['invoice_no'] ?? '',
                      style: const TextStyle(
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Invoice Date
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Invoice Date',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      invoiceData['invoice_date'] ?? '',
                      style: const TextStyle(
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // ================= TO SECTION =================
      Container(
        width: double.infinity,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TO',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              invoiceData['client_name'] ?? '',
              style: const TextStyle(
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    ],
  ),
),

const SizedBox(height: 8),

                      // Items Table (Matches PDF Widths)
                      Table(
                        border: TableBorder.all(color: Colors.black, width: 1),
                              defaultVerticalAlignment: TableCellVerticalAlignment.middle,

                        columnWidths: const {
                          0: FixedColumnWidth(45),
                          1: FlexColumnWidth(2),
                          2: FixedColumnWidth(45),
                          3: FixedColumnWidth(65),
                          4: FixedColumnWidth(70),
                        },
                        children: [
                          TableRow(decoration: const BoxDecoration(color: Color(0xFFF0F0F0)), children: [
                            _tableCell('S.No', bold: true), _tableCell('DESCRIPTIONS', bold: true), _tableCell('QTY', bold: true), _tableCell('RATE', bold: true), _tableCell('AMOUNT', bold: true)
                          ]),
                          ...((invoiceData['items'] as List?) ?? []).asMap().entries.map((entry) {
                            final i = entry.key;
                            final item = entry.value;
                            return TableRow(children: [
                              _tableCell('${i + 1}'),
                              _tableCell(item['description'] ?? ''),
                              _tableCell(item['qty'].toString()),
                              _tableCell(_parseAmount(item['rate']).toStringAsFixed(0)),
                              _tableCell((int.parse(item['qty'].toString()) * _parseAmount(item['rate'])).toStringAsFixed(0)),
                            ]);
                          })
                        ],
                      ),

                      // Summary Table (Matches PDF)
                      Table(
                        border: TableBorder.all(color: Colors.black, width: 1),
                        children: [
                          _summaryRow('TOTAL AMOUNT', invoiceData['total_amount']),
                          _summaryRow('PAID AMOUNT', invoiceData['paid_amount']),
                          _summaryRow('BALANCE TO BE PAID', invoiceData['balance_amount']),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [SizedBox(width: 100, height: 100, child: Image.asset('assets/images/office_seal.png'))]),

                      // Footer Details (Matches PDF)
                     Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('BANK ACCOUNT DETAILS', 
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        decoration: TextDecoration.none,
                                      )),
                          const SizedBox(height: 3),
                          const Text(
                            'NAME: GO DIGITAL | BANK: IDFC FIRST BANK | A/C NO: 10075087276 | BRANCH: KILPAUK | IFSC: IDFB0080121',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0052CC)),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Office: +91 94449 43094 | Email: godigitalindaras@gmail.com | Website: www.godigital.ind.in',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

                      
Container(
                  color: const Color(0xFF0052CC),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  child:Column(
                    mainAxisSize:MainAxisSize.min,
                    children: [
                     Text('GO DIGITAL',    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 255, 255, 255)),
                         ),
                     SizedBox(height: 2),
                     Text('No:14, Udaya Suriyan Nagar, Guduvanchery 603202 Near Olala Cafe',
                           style: TextStyle(fontSize: 14, color: Color.fromARGB(255, 254, 255, 255)),
                      textAlign:TextAlign.center),
                    ],
                  ),
                ),



              // ✅ FOOTER BUTTONS
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
                      // icon: const Icon(Icons.print, size: 16),
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

              // Bottom Blue Strip
              // Container(padding: const EdgeInsets.all(8), color: const Color(0xFF0052CC), child: const Center(child: Text('GO DIGITAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
            ],
          ),
        ),
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
  }
}

// Helpers
  Widget _tableCell(String text, {bool bold = false, TextAlign align = TextAlign.left, double fontSize = 10}) {
    return Container(
      padding: const EdgeInsets.all(8),
      alignment: Alignment.centerLeft,
      child: Text(text, textAlign: align, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: fontSize)),
    );
  }
TableRow _summaryRow(String label, dynamic amount) => TableRow(children: [Container(padding: const EdgeInsets.all(8), child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))), Container(padding: const EdgeInsets.all(8), child: Text('₹ ${_parseAmount(amount).toStringAsFixed(0)} /-', textAlign: TextAlign.right))]);
// ✅ SUMMARY ROW BUILDER
Widget _buildSummaryRowExact(String label, String amount, {bool isBold = false}) {
  return Table(
    border: TableBorder.all(color: const Color(0xFF0F172A), width: 1.5),
    columnWidths: const {
      0: FlexColumnWidth(2),
      1: FlexColumnWidth(1),
    },
    children: [
      TableRow(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            child: Text(
              label,
              style: TextStyle(fontSize: 10, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: isBold ? const Color(0xFFDC2626) : const Color(0xFF0F172A)),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            child: Text(
              amount,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 10, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: isBold ? const Color(0xFFDC2626) : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    ],
  );
}

// ✅ PARSE AMOUNT HELPER
double _parseAmount(dynamic value) {
  if (value == null) return 0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

  
  Widget _buildTableCell(String text, {bool isHeader = false, TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: isHeader ? 11 : 12,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.w500,
          color: isHeader ? const Color(0xFF475569) : const Color(0xFF0F172A),
        ),
      ),
    );
  }

  // ✅ Helper: Format summary lines
  Widget _buildSummaryLine(String label, double amount, {bool isBold = false, Color color = const Color(0xFF0F172A)}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: const Color(0xFF64748B))),
        const SizedBox(width: 16),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: TextStyle(fontSize: 10, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color),
        ),
      ],
    );
  }

  Future<void> _selectFromMaintenanceDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _fromMaintenanceDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0052CC),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0052CC),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Invoices",
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Track real-time customer billing statements, distributions, and accounts receivable collections.",
                    style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.pushNamed(context, '/add-invoice');
                  _fetchInvoices();
                  _fetchMetrics();
                },
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0052CC),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  elevation: 0,
                ),
                label: const Text("Add Invoice", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 10)),
              ),
            ],
          ),

          const SizedBox(height: 28),

          Row(
            children: [
              _buildMetricCard("Total Invoiced", _loadingMetrics ? "—" : _formatCurrency(_totalInvoiced), Icons.receipt_long_rounded, const Color(0xFF2563EB)),
              const SizedBox(width: 16),
              _buildMetricCard("Collected Amount", _loadingMetrics ? "—" : _formatCurrency(_collectedAmount), Icons.check_circle_outline_rounded, const Color(0xFF16A34A)),
              const SizedBox(width: 16),
              _buildMetricCard("Outstanding Balance", _loadingMetrics ? "—" : _formatCurrency(_outstandingBalance), Icons.error_outline_rounded, const Color(0xFFEA580C)),
            ],
          ),

          const SizedBox(height: 32),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Invoice History",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _selectedMonth,
                                isDense: true,
                                icon: const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF475569)),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                items: List.generate(12, (i) => i + 1).map((month) {
                                  return DropdownMenuItem(
                                    value: month,
                                    child: Text(monthNames[month - 1]),
                                  );
                                }).toList(),
                                onChanged: (month) {
                                  if (month != null) {
                                    setState(() {
                                      _selectedMonth = month;
                                      _currentPage = 1;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          GestureDetector(
                            onTap: () => _selectFromMaintenanceDate(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: _fromMaintenanceDate != null ? const Color(0xFF0052CC) : const Color(0xFFCBD5E1)),
                                borderRadius: BorderRadius.circular(4),
                                color: _fromMaintenanceDate != null ? const Color(0xFFEFF6FF) : Colors.transparent,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.date_range_rounded,
                                    size: 14,
                                    color: _fromMaintenanceDate != null ? const Color(0xFF0052CC) : const Color(0xFF475569),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _fromMaintenanceDate != null 
                                        ? DateFormat('dd/MM').format(_fromMaintenanceDate!)
                                        : 'From',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _fromMaintenanceDate != null ? const Color(0xFF0052CC) : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          GestureDetector(
                            onTap: () => _selectToMaintenanceDate(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: _toMaintenanceDate != null ? const Color(0xFF0052CC) : const Color(0xFFCBD5E1)),
                                borderRadius: BorderRadius.circular(4),
                                color: _toMaintenanceDate != null ? const Color(0xFFEFF6FF) : Colors.transparent,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.date_range_rounded,
                                    size: 14,
                                    color: _toMaintenanceDate != null ? const Color(0xFF0052CC) : const Color(0xFF475569),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _toMaintenanceDate != null 
                                        ? DateFormat('dd/MM').format(_toMaintenanceDate!)
                                        : 'To',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _toMaintenanceDate != null ? const Color(0xFF0052CC) : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          if (_fromMaintenanceDate != null || _toMaintenanceDate != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _fromMaintenanceDate = null;
                                    _toMaintenanceDate = null;
                                    _currentPage = 1;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFFDC2626)),
                                    borderRadius: BorderRadius.circular(4),
                                    color: const Color(0xFFFEE2E2),
                                  ),
                                  child: const Icon(Icons.close, size: 14, color: Color(0xFFDC2626)),
                                ),
                              ),
                            ),

                          const SizedBox(width: 12),

                          AnimatedVisibility(
                            visible: _isFilterMenuOpen,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildFilterTab("All Logs"),
                                _buildFilterTab("Paid"),
                                _buildFilterTab("Partial"),
                                _buildFilterTab("Overdue"),
                                const SizedBox(width: 12),
                              ],
                            ),
                          ),

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
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: _isFilterMenuOpen ? const Color(0xFFF1F5F9) : Colors.transparent,
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _isFilterMenuOpen ? Icons.filter_list_off_rounded : Icons.filter_list_rounded,
                                    size: 14,
                                    color: const Color(0xFF475569)
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isFilterMenuOpen ? "Hide Filter" : "Filter",
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

                Container(
  color: const Color(0xFFF8FAFC),
  height: 44,
  padding: const EdgeInsets.symmetric(horizontal: 24),
  child: Row(
    children: const [
      Expanded(flex: 1, child: Text("S.NO", style: _tableHeadingStyle)),
      Expanded(flex: 2, child: Text("INVOICE DATE", style: _tableHeadingStyle)),
      Expanded(flex: 2, child: Text("INVOICE NO", style: _tableHeadingStyle)),
      Expanded(flex: 2, child: Text("CLIENT NAME", style: _tableHeadingStyle)),
      Expanded(flex: 2, child: Text("PACKAGE DETAILS", style: _tableHeadingStyle)),
      Expanded(flex: 2, child: Text("MAINTENANCE DATE", style: _tableHeadingStyle)),
      Expanded(flex: 2, child: Text("TOTAL AMOUNT", style: _tableHeadingStyle)),
      Expanded(flex: 2, child: Text("PAID AMOUNT", style: _tableHeadingStyle)),
      Expanded(flex: 2, child: Text("PENDING AMOUNT", style: _tableHeadingStyle)),
      Expanded(flex: 2, child: Text("STATUS", style: _tableHeadingStyle)),
      Expanded(
        flex: 2,
        child: Align(
          alignment: Alignment.center,
          child: Text("ACTION", style: _tableHeadingStyle),
        ),
      ),
    ],
  ),
),
                const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

                if (_loadingInvoices)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF0052CC))),
                  )
                else if (_invoicesError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Column(children: [
                      Text(_invoicesError!, style: const TextStyle(color: Color(0xFF64748B))),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchInvoices,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052CC)),
                        child: const Text('Retry', style: TextStyle(color: Colors.white)),
                      ),
                    ])),
                  )
                else if (filteredInvoices.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text("No invoice records match this filter criteria.", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                    ),
                  )
               else
  SizedBox(
    height: 420,
    child: Scrollbar(
      controller: _verticalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalController,
        child: Column(
          children: pagedInvoices.map((row) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInvoiceHistoryRow(row),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFE2E8F0),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    ),
  ),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        totalInvoices == 0
                            ? "Showing 0 of 0 ledger files"
                            : "Showing ${startIndex + 1} to $endIndex of $totalInvoices ledger files",
                        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                      ),
                      Row(
                        children: [
                          _buildPageControlKey("<", false, onTap: _currentPage > 1 ? () => setState(() => _currentPage--) : null),
                          for (int p = 1; p <= totalPages; p++)
                            _buildPageControlKey("$p", p == _currentPage, onTap: () => setState(() => _currentPage = p)),
                          _buildPageControlKey(">", false, onTap: _currentPage < totalPages ? () => setState(() => _currentPage++) : null),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String rawValue, IconData icon, Color badgeAccent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: badgeAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: badgeAccent, size: 22),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 4),
                Text(rawValue, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              ],
            )
          ],
        ),
      ),
    );
  }

  static const TextStyle _tableHeadingStyle = TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5);

  Widget _buildInvoiceHistoryRow(Map<String, dynamic> row) {
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
    
    final double paid = double.tryParse(row["paid_amount"]?.toString() ?? '0') ?? 0;
    final double pending = double.tryParse(row["balance_amount"]?.toString() ?? '0') ?? 0;

    final statusBg = _statusBg[status] ?? const Color(0xFFF1F5F9);
    final statusText = _statusText[status] ?? const Color(0xFF475569);

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: Colors.white,
      child: Row(
        children: [

           // S.NO
  Expanded(
    flex: 1,
    child: Text(
      id.toString(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),

   // Invoice Date
  Expanded(
    flex: 2,
    child: Text(
      invoiceDate,
      style: const TextStyle(fontSize: 10),
    ),
  ),

          Expanded(flex: 2, child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(invNo, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0052CC))),
              if (linkedQuotNo.isNotEmpty)
                GestureDetector(
                  onTap: linkedQuotId != null
                      ? () => Navigator.pushNamed(context, '/create-quotation',
                          arguments: {'quotationId': linkedQuotId, 'viewOnly': true})
                      : null,
                  child: Text(
                    '↗ $linkedQuotNo',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                ),
            ],
          )),
          Expanded(flex: 2, child: Text(client, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Text(type, style: const TextStyle(fontSize: 10, color: Color(0xFF475569)), maxLines: 1, overflow: TextOverflow.ellipsis)),
          
          Expanded(flex: 2, child: Text(maintenanceDate, style: const TextStyle(fontSize: 10, color: Color(0xFF475569)))),
          Expanded(flex: 2, child: Text(amount, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),

          // Paid Amount
  Expanded(
    flex: 2,
    child: Text(
      _formatCurrency(paid),
      style: const TextStyle(
        fontSize: 10,
        color: Colors.green,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),

  // Pending Amount
  Expanded(
    flex: 2,
    child: Text(
      _formatCurrency(pending),
      style: const TextStyle(
        fontSize: 10,
        color: Colors.red,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),

          // Expanded(
          //   flex: 2,
          //   child: Align(
          //     alignment: Alignment.centerLeft,
          //     child: Container(
          //       padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          //       decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(4)),
          //       child: DropdownButtonHideUnderline(
          //         child: DropdownButton<String>(
          //           value: status,
          //           isDense: true,
          //           icon: Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: statusText),
          //           style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusText),
          //           dropdownColor: Colors.white,
          //           items: _statusBg.keys.map((s) => DropdownMenuItem(
          //             value: s,
          //             child: Text(s, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _statusText[s])),
          //           )).toList(),
          //           onChanged: (val) {
          //             if (val != null && val != status) _updateInvoiceStatus(id, val);
          //           },
          //         ),
          //       ),
          //     ),
          //   ),
          // ),

          Expanded(
  flex: 2,
  child: Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusBg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: statusText,
        ),
      ),
    ),
  ),
),
          // ✅ ACTIONS COLUMN WITH PDF PREVIEW
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ✅ PDF PREVIEW BUTTON
                  Tooltip(
                    message: 'PDF Preview',
                    child: GestureDetector(
                      onTap: () => _showPDFPreview(context, row),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 3),
                        child: Icon(Icons.picture_as_pdf_outlined, size: 18, color: Color(0xFFDC2626)),
                      ),
                    ),
                  ),

                  // VIEW BUTTON
                  Tooltip(
                    message: 'View',
                    child: GestureDetector(
                      onTap: () async {
                        await Navigator.pushNamed(
                          context, '/add-invoice',
                          arguments: {'invoiceId': id, 'viewOnly': true},
                        );
                        _fetchInvoices();
                        _fetchMetrics();
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 3),
                        child: Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF475569)),
                      ),
                    ),
                  ),

                  // EDIT BUTTON
                  Tooltip(
                    message: 'Edit',
                    child: GestureDetector(
                      onTap: () async {
                        await Navigator.pushNamed(
                          context, '/add-invoice',
                          arguments: {'invoiceId': id, 'viewOnly': false},
                        );
                        _fetchInvoices();
                        _fetchMetrics();
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 3),
                        child: Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0052CC)),
                      ),
                    ),
                  ),

                  // DELETE BUTTON
                  Tooltip(
                    message: 'Delete',
                    child: GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete Invoice'),
                            content: Text('Remove "$invNo"? This cannot be undone.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _deleteInvoice(id);
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                                child: const Text('Delete', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 3),
                        child: Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label) {
    bool isActive = activeFilter.toUpperCase() == label.toUpperCase();
    return Container(
      margin: const EdgeInsets.only(right: 4),
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            activeFilter = label;
            _currentPage = 1;
          });
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: isActive ? const Color(0xFF0052CC) : Colors.transparent,
          side: BorderSide(color: isActive ? const Color(0xFF0052CC) : const Color(0xFFE2E8F0)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          elevation: 0,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
            color: isActive ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildPageControlKey(String text, bool isActive, {VoidCallback? onTap}) {
    final isDisabled = onTap == null && !isActive;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        width: 24, height: 24,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0052CC) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: isActive ? null : Border.all(color: const Color(0xFFE2E8F0)),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isActive
                ? Colors.white
                : (isDisabled ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }
}

class AnimatedVisibility extends StatelessWidget {
  final bool visible;
  final Widget child;

  const AnimatedVisibility({super.key, required this.visible, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: visible ? child : const SizedBox.shrink(),
    );
  }
}