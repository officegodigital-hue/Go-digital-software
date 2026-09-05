// name=quotations.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../layouts/admin_layout.dart';
import '../../services/api_config.dart';
import '../../services/auth_service.dart';

class QuotationsScreen extends StatefulWidget {
  const QuotationsScreen({super.key});

  @override
  State<QuotationsScreen> createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends State<QuotationsScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  String _searchQuery = '';
  String activeFilter = "All";
  bool _isFilterMenuOpen = false;

  List<Map<String, dynamic>> quotationsData = [];
  bool _loadingQuotations = true;
  String? _quotationsError;

  static const int _quotationsPerPage = 999;
  int _currentPage = 1;

  final ScrollController _quotationScrollController = ScrollController();
  final ScrollController _quotationHorizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchQuotations();
  }

  @override
  void dispose() {
    _quotationScrollController.dispose();
    _quotationHorizontalController.dispose();
    super.dispose();
  }

  Future<void> _fetchQuotations() async {
    setState(() {
      _loadingQuotations = true;
      _quotationsError = null;
    });
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = authService.token;

      final response = await http.get(
        Uri.parse('$_baseUrl/quotations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          quotationsData = List<Map<String, dynamic>>.from(body['data'] as List);
          _loadingQuotations = false;
        });
      } else {
        setState(() {
          _quotationsError = 'Server returned ${response.statusCode}';
          _loadingQuotations = false;
        });
      }
    } catch (e) {
      setState(() {
        _quotationsError = 'Cannot connect to server';
        _loadingQuotations = false;
      });
    }
  }

  Future<void> _updateQuotationStatus(int id, String status) async {
    try {

      final authService = Provider.of<AuthService>(context, listen: false);
      final token = authService.token; // 🟢 Retrieve auth token

      final response = await http.patch(
        Uri.parse("$_baseUrl/quotations/$id/status"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"status": status}),
      );

      if (response.statusCode == 200) {
        await _fetchQuotations();
        final body = jsonDecode(response.body) as Map<String, dynamic>;

        if (status.toUpperCase() == 'ACCEPTED' && body['data'] != null) {
          final invoiceData = body['data'] as Map<String, dynamic>;
          final invoiceNo = invoiceData['invoiceNo'] as String? ?? '';
          final invoiceId = invoiceData['invoiceId'] as int?;
          final alreadyEx = invoiceData['alreadyExists'] as bool? ?? false;

          if (mounted && invoiceId != null) {
            showDialog(
              context: context,
              builder: (_) => Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 300, maxWidth: 420),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 56, height: 56,
                        decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                        child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF16A34A), size: 28),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        alreadyEx ? "Invoice Already Exists" : "Invoice Created!",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        alreadyEx
                            ? "Invoice $invoiceNo was already linked to this quotation."
                            : "Invoice $invoiceNo has been created automatically from this quotation.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 24),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text("Stay Here", style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, '/add-invoice',
                                  arguments: {'invoiceId': invoiceId, 'viewOnly': false});
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0052CC),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                            ),
                            child: const Text("View Invoice", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ]),
                    ]),
                  ),
                ),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to update status'),
            backgroundColor: Colors.redAccent,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Cannot connect to server'),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  Future<void> _deleteQuotation(int id) async {
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/quotations/$id'));
      if (response.statusCode == 200) {
        await _fetchQuotations();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Quotation deleted'),
            backgroundColor: Color(0xFFDC2626),
          ));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to delete quotation'),
            backgroundColor: Colors.redAccent,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Cannot connect to server'),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  Future<void> _viewQuotationPDFPreview(BuildContext context, int quotationId, String quotationNo) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/quotations/$quotationId'));
      if (response.statusCode != 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to load quotation details'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final quotationData = body['data'] as Map<String, dynamic>;
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 1000),
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
                        SizedBox(
                          width: 140,
                          height: 50,
                          child: Image.asset('assets/images/godigital_logo.png', fit: BoxFit.contain),
                        ),
                        const SizedBox(height: 14),
                        _buildHeaderTable(quotationData),
                        const SizedBox(height: 8),
                        _buildItemsTable(quotationData),
                        _buildSummaryTable(quotationData),
                        const SizedBox(height: 20),
                        _buildNotesSection(quotationData),
                        const SizedBox(height: 12),
                        _buildTermsSection(quotationData),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: 100,
                              height: 100,
                              child: Image.asset('assets/images/office_seal.png', fit: BoxFit.contain),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildBankDetailsSection(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                Container(
                  color: const Color(0xFF1F4E9E),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('GO DIGITAL', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 2),
                      const Text('No:14, Udaya Suriyan Nagar, Guduvanchery 603202 Near Olala Cafe',
                        style: TextStyle(fontSize: 14, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Widget _buildHeaderTable(Map<String, dynamic> data) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1)),
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black, width: 1))),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.black, width: 1))),
                    child: const Text('GO DIGITAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.black, width: 1))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Quotation No.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8)),
                        const SizedBox(height: 2),
                        Text(data['quotation_no']?.toString() ?? '', style: const TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Quotation Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8)),
                        const SizedBox(height: 2),
                        Text(data['quotation_date']?.toString() ?? '', style: const TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                const SizedBox(height: 2),
                Text(data['client_name']?.toString() ?? '', style: const TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTable(Map<String, dynamic> data) {
    final itemsList = data['items'] as List<dynamic>? ?? [];
    final validItems = itemsList.whereType<Map<String, dynamic>>().toList();

    return Table(
      border: TableBorder.all(color: Colors.black, width: 1),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: FixedColumnWidth(45),
        1: FlexColumnWidth(2),
        2: FixedColumnWidth(45),
        3: FixedColumnWidth(65),
        4: FixedColumnWidth(70)
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
        ...validItems.asMap().entries.map((MapEntry<int, Map<String, dynamic>> entry) {
          final int i = entry.key;
          final Map<String, dynamic> item = entry.value;
          final int qty = int.tryParse(item['qty'].toString()) ?? 0;
          final double rate = _parseAmount(item['rate']);
          final double amount = qty * rate;
          return TableRow(children: [
            _tableCell('${i + 1}', align: TextAlign.center),
            _descriptionCell(item['description'] as String? ?? ''),
            _tableCell(qty.toString(), align: TextAlign.center),
            _tableCell(rate.toStringAsFixed(0), align: TextAlign.right),
            _tableCell(amount.toStringAsFixed(0), align: TextAlign.right),
          ]);
        }),
      ],
    );
  }

  Widget _buildSummaryTable(Map<String, dynamic> data) {
    final double discount = _parseAmount(data['discount']);
    final bool includeGST = data['include_gst'] == 1 || data['include_gst'] == true;
    final double subtotal = _parseAmount(data['subtotal']);
    final double taxableAmount = subtotal - discount;
    final double tax = includeGST ? (taxableAmount * 0.18) : 0.0;
    final double total = _parseAmount(data['total_amount']);

    return Table(
      border: TableBorder.all(color: Colors.black, width: 1),
      columnWidths: const {0: FlexColumnWidth(3), 1: FixedColumnWidth(135)},
      children: [
        if (discount > 0)
          TableRow(children: [
            _tableCell('DISCOUNT', bold: true, align: TextAlign.center),
            _tableCell('₹ ${discount.toStringAsFixed(0)} /-', bold: true, align: TextAlign.center),
          ]),
        TableRow(children: [
          _tableCell('TAX (18% GST)', bold: true, align: TextAlign.center),
          _tableCell('₹ ${tax.toStringAsFixed(0)} /-', bold: true, align: TextAlign.center),
        ]),
        TableRow(children: [
          _tableCell('TOTAL AMOUNT', bold: true, align: TextAlign.center),
          _tableCell('₹ ${total.toStringAsFixed(0)} /-', bold: true, align: TextAlign.center),
        ]),
      ],
    );
  }

  Widget _buildNotesSection(Map<String, dynamic> data) {
    final String expiry = data['expiry_date'] as String? ?? '';
    final String notes = data['notes'] as String? ?? '';

    if (expiry.isEmpty && notes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
        const SizedBox(height: 2),
        if (expiry.isNotEmpty)
          Text('Valid until: $expiry', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF1F4E9E))),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(notes, style: const TextStyle(fontSize: 9, color: Color(0xFF475569))),
        ],
      ],
    );
  }

  Widget _buildTermsSection(Map<String, dynamic> data) {
    final String terms = data['terms'] as String? ?? '';
    if (terms.isEmpty) return const SizedBox.shrink();

    final List<String> termsList = terms.split('\n').where((String t) => t.trim().isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Terms & Conditions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
        const SizedBox(height: 2),
        ...termsList.map((String term) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(term.trim(), style: const TextStyle(fontSize: 9, color: Color(0xFF475569))),
        )),
      ],
    );
  }

  Widget _buildBankDetailsSection() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('BANK ACCOUNT DETAILS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, decoration: TextDecoration.underline)),
        SizedBox(height: 3),
        Text('NAME: GO DIGITAL | BANK: IDFC FIRST BANK | A/C NO: 10075087276 | BRANCH: KILPAUK | IFSC: IDFB0080121',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1F4E9E))),
        SizedBox(height: 3),
        Text('Office: +91 94449 43094 | Email: godigitalindaras@gmail.com | Website: www.godigital.ind.in',
          style: TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
          textAlign: TextAlign.center),
      ],
    );
  }

  Widget _tableCell(String text, {bool bold = false, TextAlign align = TextAlign.left, double fontSize = 10}) {
    return Container(
      padding: const EdgeInsets.all(8),
      alignment: Alignment.centerLeft,
      child: Text(text, textAlign: align, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: fontSize)),
    );
  }

  Widget _descriptionCell(String text) {
    if (text.isEmpty) return Container(padding: const EdgeInsets.all(8), alignment: Alignment.centerLeft, child: const Text('-', style: TextStyle(fontSize: 10)));
    final List<String> lines = text.split('\n');
    final String firstLine = lines[0];
    final List<String> remainingLines = lines.skip(1).toList();

    return Container(
      padding: const EdgeInsets.all(8),
      alignment: Alignment.topLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(firstLine, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
          ...remainingLines.map((String line) => Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(line.trim(), style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 10)),
          )),
        ],
      ),
    );
  }

  double _parseAmount(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static const Map<String, Color> _statusBg = {
    'DRAFT': Color(0xFFF1F5F9),
    'SENT': Color(0xFFE0F2FE),
    'ACCEPTED': Color(0xFFDCFCE7),
    'EXPIRED': Color(0xFFFEE2E2),
  };
  static const Map<String, Color> _statusText = {
    'DRAFT': Color(0xFF475569),
    'SENT': Color(0xFF0369A1),
    'ACCEPTED': Color(0xFF15803D),
    'EXPIRED': Color(0xFFB91C1C),
  };

  List<Map<String, dynamic>> _buildFilteredQuotations() {
    return quotationsData.where((Map<String, dynamic> row) {
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final quotNo = (row['quotation_no'] ?? '').toString().toLowerCase();
        final clientName = (row['client_name'] ?? '').toString().toLowerCase();
        final packageType = (row['package_type'] ?? '').toString().toLowerCase();

        if (!quotNo.contains(query) && !clientName.contains(query) && !packageType.contains(query)) {
          return false;
        }
      }

      if (activeFilter == "All") return true;
      final dynamic statusDynamic = row["status"];
      if (statusDynamic == null) return false;
      final String status = statusDynamic.toString().toUpperCase();
      return status == activeFilter.toUpperCase();
    }).toList();
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

    final filteredQuotations = _buildFilteredQuotations();
    final totalQuotations = filteredQuotations.length;
    final totalPages = totalQuotations == 0
        ? 1
        : (totalQuotations / _quotationsPerPage).ceil();

    if (_currentPage > totalPages) _currentPage = totalPages;
    if (_currentPage < 1) _currentPage = 1;

    final startIndex = (_currentPage - 1) * _quotationsPerPage;
    final endIndex = (startIndex + _quotationsPerPage > totalQuotations)
        ? totalQuotations
        : startIndex + _quotationsPerPage;

    final pagedQuotations = filteredQuotations.sublist(
      startIndex < totalQuotations ? startIndex : 0,
      endIndex,
    );

    final acceptedCount = quotationsData
        .where((row) => (row['status'] ?? '').toString().toUpperCase() == 'ACCEPTED')
        .length;
    final pendingCount = quotationsData
        .where((row) {
          final status = (row['status'] ?? 'DRAFT').toString().toUpperCase();
          return status == 'DRAFT' || status == 'SENT';
        })
        .length;

    // 🟢 Add Draft count calculation here:
final draftCount = quotationsData
    .where((row) => (row['status'] ?? 'DRAFT').toString().toUpperCase() == 'DRAFT')
    .length;

    return AdminLayout(
      pageTitle: "Quotations Management",
      currentRoute: "/quotation",
      onSearch: (query) {
        setState(() {
          _searchQuery = query;
          _currentPage = 1;
        });
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 700;
          final isTablet =
              constraints.maxWidth >= 700 && constraints.maxWidth < 1100;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPageHero(isMobile),
              const SizedBox(height: 18),
              _buildQuickStats(
                isMobile: isMobile,
                isTablet: isTablet,
                total: quotationsData.length,
                accepted: acceptedCount,
                pending: pendingCount,
                draft: draftCount,
              ),
              const SizedBox(height: 18),
              _buildQuotationWorkspace(
                isMobile: isMobile,
                quotations: pagedQuotations,
                totalQuotations: totalQuotations,
                startIndex: startIndex,
                endIndex: endIndex,
                totalPages: totalPages,
                isMainAdmin: isMainAdmin,
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
          'QUOTATION CENTER',
          style: TextStyle(
            color: Color(0xFFBFD5FF),
            fontSize: 10,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'Quotations Management',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'Track proposals, update client status, preview PDFs and generate invoices.',
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
      onPressed: () => Navigator.pushNamed(context, '/create-quotation'),
      icon: const Icon(Icons.add_rounded, color: Color(0xFF0052CC)),
      label: const Text(
        'Create Quotation',
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
    required int accepted,
    required int pending,
    required int draft,
  }) {
    final stats = [
      {
        'label': 'Total Quotations',
        'value': total.toString(),
        'icon': Icons.description_outlined,
        'color': const Color(0xFF0052CC),
      },
      {
        'label': 'Accepted',
        'value': accepted.toString(),
        'icon': Icons.verified_rounded,
        'color': const Color(0xFF16A34A),
      },
      {
        'label': 'In Progress',
        'value': pending.toString(),
        'icon': Icons.hourglass_top_rounded,
        'color': const Color(0xFFF59E0B),
      },
      {
        'label': 'Draft',
        'value': draft.toString(),
        'icon': Icons.drafts_rounded,
        'color': const Color(0xFF64748B),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 2 : 4,
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

  Widget _buildQuotationWorkspace({
    required bool isMobile,
    required List<Map<String, dynamic>> quotations,
    required int totalQuotations,
    required int startIndex,
    required int endIndex,
    required int totalPages,
    required bool isMainAdmin,
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
                      _workspaceTitle(totalQuotations),
                      const SizedBox(height: 14),
                      _buildStatusFilter(fullWidth: true),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: _workspaceTitle(totalQuotations)),
                      _buildStatusFilter(),
                    ],
                  ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          if (_loadingQuotations)
            _buildLoadingState()
          else if (_quotationsError != null)
            _buildErrorState()
          else if (quotations.isEmpty)
            _buildEmptyState()
          else if (isMobile)
            _buildMobileQuotationList(quotations, startIndex, isMainAdmin)
          else
            _buildDesktopQuotationTable(quotations, startIndex, isMainAdmin),
          _buildPagination(
            totalQuotations: totalQuotations,
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
          'Recent Quotations',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Color(0xFF172033),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '$total quotation${total == 1 ? '' : 's'} available',
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusFilter({bool fullWidth = false}) {
    return Container(
      constraints: fullWidth ? null : const BoxConstraints(minWidth: 165),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: activeFilter,
          isExpanded: fullWidth,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF64748B),
          ),
          items: const ['All', 'Draft', 'Sent', 'Accepted', 'Expired']
              .map(
                (status) => DropdownMenuItem<String>(
                  value: status,
                  child: Text(
                    status == 'All' ? 'All Status' : status,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              activeFilter = value;
              _isFilterMenuOpen = true;
              _currentPage = 1;
            });
          },
        ),
      ),
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
      padding: EdgeInsets.symmetric(vertical: 54),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 34,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 10),
            Text(
              _quotationsError ?? 'Unable to load quotations',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _fetchQuotations,
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
            Icon(
              Icons.description_outlined,
              size: 42,
              color: Color(0xFF94A3B8),
            ),
            SizedBox(height: 10),
            Text(
              'No quotations found',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF334155),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Try changing the status filter or create a new quotation.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopQuotationTable(
    List<Map<String, dynamic>> quotations,
    int startIndex,
    bool isMainAdmin,
  ) {
    const double tableMinWidth = 1600;

    return Scrollbar(
      controller: _quotationHorizontalController,
      thumbVisibility: true,
      interactive: true,
      notificationPredicate: (notification) =>
          notification.metrics.axis == Axis.horizontal,
      child: SingleChildScrollView(
        controller: _quotationHorizontalController,
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
                    const Expanded(flex: 1, child: Text('S.NO', style: _tableHeaderStyle)),
                    const Expanded(flex: 3, child: Text('QUOTATION ID', style: _tableHeaderStyle)),
                    const Expanded(flex: 3, child: Text('CLIENT', style: _tableHeaderStyle)),
                    const Expanded(flex: 2, child: Text('PACKAGE', style: _tableHeaderStyle)),
                    const Expanded(flex: 2, child: Text('AMOUNT', style: _tableHeaderStyle)),
                    const Expanded(flex: 3, child: Text('STATUS', style: _tableHeaderStyle)),
                    const Expanded(flex: 2, child: Text('DATE', style: _tableHeaderStyle)),
                    // ✅ CREATED BY COLUMN PLACED BETWEEN DATE AND PDF (Only for Main Admin)
                    if (isMainAdmin)
                      const Expanded(flex: 2, child: Text('CREATED BY', style: _tableHeaderStyle)),
                    const Expanded(
                      flex: 1,
                      child: Center(child: Text('PDF', style: _tableHeaderStyle)),
                    ),
                    const Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.center,
                        child: Text('ACTIONS', style: _tableHeaderStyle),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              SizedBox(
                height: 460,
                child: Scrollbar(
                  controller: _quotationScrollController,
                  thumbVisibility: true,
                  interactive: true,
                  notificationPredicate: (notification) =>
                      notification.metrics.axis == Axis.vertical,
                  child: ListView.separated(
                    controller: _quotationScrollController,
                    primary: false,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    itemCount: quotations.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    itemBuilder: (context, index) => _buildQuotationRow(
                      quotations[index],
                      startIndex + index + 1,
                      isMainAdmin,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileQuotationList(
    List<Map<String, dynamic>> quotations,
    int startIndex,
    bool isMainAdmin,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: quotations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) =>
          _buildMobileQuotationCard(quotations[index], startIndex + index + 1, isMainAdmin),
    );
  }

  Widget _buildMobileQuotationCard(
    Map<String, dynamic> row,
    int serialNo,
    bool isMainAdmin,
  ) {
    final id = row['id'] as int? ?? 0;
    final quotNo = row['quotation_no']?.toString() ?? '';
    final client = row['client_name']?.toString() ?? '';
    final type = row['package_type']?.toString() ?? '-';
    final total = _parseAmount(row['total_amount']);
    final status = (row['status']?.toString() ?? 'DRAFT').toUpperCase();
    final date = row['quotation_date']?.toString() ?? '';
    final createdByName = row['created_by_name'] ?? 'Main Admin';
    final linkedInvId = row['linked_invoice_id'] as int?;
    final linkedInvNo = row['linked_invoice_no']?.toString() ?? '';
    final statusBg = _statusBg[status] ?? const Color(0xFFF1F5F9);
    final statusText = _statusText[status] ?? const Color(0xFF475569);

    final words = client.trim().isEmpty
        ? <String>[]
        : client.trim().split(RegExp(r'\s+'));
    final initials = words.isEmpty
        ? '?'
        : words.take(2).map((word) => word.substring(0, 1)).join();

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
                  style: const TextStyle(
                    color: Color(0xFF0052CC),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  quotNo,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF172033),
                  ),
                ),
              ),
              _mobileStatusBadge(id, status, statusBg, statusText),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: const Color(0xFFE2E8F0),
                child: Text(
                  initials.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  client.isEmpty ? '-' : client,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF172033),
                  ),
                ),
              ),
            ],
          ),
          if (isMainAdmin) ...[
            const SizedBox(height: 6),
            Text(
              'Created by: $createdByName',
              style: const TextStyle(fontSize: 11, color: Color(0xFF0052CC), fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: _mobileInfoTile(
                  icon: Icons.inventory_2_outlined,
                  label: 'Package',
                  value: type,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _mobileInfoTile(
                  icon: Icons.currency_rupee_rounded,
                  label: 'Amount',
                  value: '₹${total.toStringAsFixed(0)}',
                  valueBold: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                date.isEmpty ? '-' : date,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _mobileActionButton(
                icon: Icons.preview_rounded,
                color: const Color(0xFF0052CC),
                tooltip: 'View PDF',
                onTap: () => _viewQuotationPDFPreview(context, id, quotNo),
              ),
              _mobileActionButton(
                icon: Icons.visibility_outlined,
                color: const Color(0xFF475569),
                tooltip: 'View',
                onTap: () => Navigator.pushNamed(
                  context,
                  '/create-quotation',
                  arguments: {'quotationId': id, 'viewOnly': true},
                ),
              ),
              _mobileActionButton(
                icon: Icons.edit_outlined,
                color: const Color(0xFF0052CC),
                tooltip: 'Edit',
                onTap: () => Navigator.pushNamed(
                  context,
                  '/create-quotation',
                  arguments: {'quotationId': id, 'viewOnly': false},
                ),
              ),
              if (linkedInvId != null)
                _mobileActionButton(
                  icon: Icons.receipt_long_rounded,
                  color: const Color(0xFF16A34A),
                  tooltip: 'Invoice $linkedInvNo',
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/add-invoice',
                    arguments: {'invoiceId': linkedInvId, 'viewOnly': false},
                  ),
                ),
              _mobileActionButton(
                icon: Icons.delete_outline_rounded,
                color: const Color(0xFFDC2626),
                tooltip: 'Delete',
                onTap: () => _showDeleteDialog(id, quotNo),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mobileStatusBadge(
    int id,
    String status,
    Color bg,
    Color text,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: status,
          isDense: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 14,
            color: text,
          ),
          style: TextStyle(
            color: text,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
          items: _statusBg.keys
              .map(
                (s) => DropdownMenuItem<String>(
                  value: s,
                  child: Text(
                    s,
                    style: TextStyle(
                      color: _statusText[s],
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null && value != status) {
              _updateQuotationStatus(id, value);
            }
          },
        ),
      ),
    );
  }

  Widget _mobileInfoTile({
    required IconData icon,
    required String label,
    required String value,
    bool valueBold = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 8,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: const Color(0xFF334155),
                    fontWeight:
                        valueBold ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
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

  void _showDeleteDialog(int id, String quotNo) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Delete Quotation',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text('Remove "$quotNo"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteQuotation(id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination({
    required int totalQuotations,
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
                  totalQuotations == 0
                      ? 'Showing 0 of 0 quotations'
                      : 'Showing ${startIndex + 1}–$endIndex of $totalQuotations',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                _paginationControls(totalPages),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Text(
                    totalQuotations == 0
                        ? 'Showing 0 of 0 quotations'
                        : 'Showing ${startIndex + 1} to $endIndex of $totalQuotations quotations',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
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
        _buildPageButton(
          '<',
          false,
          onTap: _currentPage > 1
              ? () => setState(() => _currentPage--)
              : null,
        ),
        if (totalPages <= 5)
          for (int p = 1; p <= totalPages; p++)
            _buildPageButton(
              '$p',
              p == _currentPage,
              onTap: () => setState(() => _currentPage = p),
            )
        else ...[
          _buildPageButton(
            '1',
            _currentPage == 1,
            onTap: () => setState(() => _currentPage = 1),
          ),
          if (_currentPage > 3)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('...'),
            ),
          for (final p in <int>{
            (_currentPage - 1).clamp(2, totalPages - 1) as int,
            _currentPage.clamp(2, totalPages - 1) as int,
            (_currentPage + 1).clamp(2, totalPages - 1) as int,
          })
            _buildPageButton(
              '$p',
              p == _currentPage,
              onTap: () => setState(() => _currentPage = p),
            ),
          if (_currentPage < totalPages - 2)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('...'),
            ),
          _buildPageButton(
            '$totalPages',
            _currentPage == totalPages,
            onTap: () => setState(() => _currentPage = totalPages),
          ),
        ],
        _buildPageButton(
          '>',
          false,
          onTap: _currentPage < totalPages
              ? () => setState(() => _currentPage++)
              : null,
        ),
      ],
    );
  }

  static const TextStyle _tableHeaderStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w800,
    color: Color(0xFF64748B),
    letterSpacing: 0.5,
  );

  Widget _buildQuotationRow(Map<String, dynamic> row, int serialNo, bool isMainAdmin) {
    final int id = row["id"] as int? ?? 0;
    final String quotNo = row["quotation_no"]?.toString() ?? '';
    final String client = row["client_name"]?.toString() ?? '';
    final String type = row["package_type"]?.toString() ?? '-';
    final double total = _parseAmount(row["total_amount"]);
    final String amount = "₹${total.toStringAsFixed(0)}";
    final String status =
        (row["status"]?.toString() ?? 'DRAFT').toUpperCase();
    final String date = row["quotation_date"]?.toString() ?? '';
    final String createdByName = row["created_by_name"] ?? 'Main Admin';
    final int? linkedInvId = row["linked_invoice_id"] as int?;
    final String linkedInvNo = row["linked_invoice_no"]?.toString() ?? '';

    final List<String> words = client.trim().isEmpty
        ? []
        : client.trim().split(RegExp(r'\s+'));
    final String initials = words.isEmpty
        ? '?'
        : words.take(2).map((word) => word.substring(0, 1)).join();

    final Color statusBg =
        _statusBg[status] ?? const Color(0xFFF1F5F9);
    final Color statusText =
        _statusText[status] ?? const Color(0xFF475569);

    return Container(
      height: 65,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              serialNo.toString(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF475569),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              quotNo,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Color(0xFF172033),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFFEAF2FF),
                  child: Text(
                    initials.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0052CC),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    client,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF172033),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              type,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              amount,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Color(0xFF172033),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: status,
                    isDense: true,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 14,
                      color: statusText,
                    ),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: statusText,
                    ),
                    items: _statusBg.keys
                        .map(
                          (String s) => DropdownMenuItem(
                            value: s,
                            child: Text(
                              s,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _statusText[s],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (String? val) {
                      if (val != null && val != status) {
                        _updateQuotationStatus(id, val);
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              date,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // ✅ CREATED BY COLUMN PLACED BETWEEN DATE AND PDF (Only for Main Admin)
          if (isMainAdmin)
            Expanded(
              flex: 2,
              child: Text(
                createdByName,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0052CC)),
              ),
            ),
          Expanded(
            flex: 1,
            child: Center(
              child: Tooltip(
                message: 'View PDF',
                child: IconButton(
                  onPressed: () =>
                      _viewQuotationPDFPreview(context, id, quotNo),
                  icon: const Icon(
                    Icons.preview_rounded,
                    size: 19,
                    color: Color(0xFF0052CC),
                  ),
                  splashRadius: 20,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (linkedInvId != null)
                    _desktopActionIcon(
                      icon: Icons.receipt_long_rounded,
                      color: const Color(0xFF16A34A),
                      tooltip: 'View Invoice $linkedInvNo',
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/add-invoice',
                        arguments: {
                          'invoiceId': linkedInvId,
                          'viewOnly': false,
                        },
                      ),
                    ),
                  _desktopActionIcon(
                    icon: Icons.visibility_outlined,
                    color: const Color(0xFF475569),
                    tooltip: 'View',
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/create-quotation',
                      arguments: {'quotationId': id, 'viewOnly': true},
                    ),
                  ),
                  _desktopActionIcon(
                    icon: Icons.edit_outlined,
                    color: const Color(0xFF0052CC),
                    tooltip: 'Edit',
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/create-quotation',
                      arguments: {'quotationId': id, 'viewOnly': false},
                    ),
                  ),
                  _desktopActionIcon(
                    icon: Icons.delete_outline_rounded,
                    color: const Color(0xFFDC2626),
                    tooltip: 'Delete',
                    onTap: () => _showDeleteDialog(id, quotNo),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopActionIcon({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
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
    final bool isActive =
        activeFilter.toUpperCase() == label.toUpperCase();

    return OutlinedButton(
      onPressed: () => setState(() {
        activeFilter = label;
        _isFilterMenuOpen = true;
        _currentPage = 1;
      }),
      style: OutlinedButton.styleFrom(
        backgroundColor:
            isActive ? const Color(0xFF0052CC) : Colors.transparent,
        side: BorderSide(
          color: isActive
              ? const Color(0xFF0052CC)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.white : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildPageButton(
    String text,
    bool isActive, {
    VoidCallback? onTap,
  }) {
    final bool isDisabled = onTap == null && !isActive;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF0052CC)
              : Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: isActive
                ? const Color(0xFF0052CC)
                : const Color(0xFFE2E8F0),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isActive
                ? Colors.white
                : (isDisabled
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }
}

class _AnimatedVisibility extends StatelessWidget {
  final bool visible;
  final Widget child;

  const _AnimatedVisibility({required this.visible, required this.child});

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeInOut,
    child: visible ? child : const SizedBox.shrink(),
  );
}