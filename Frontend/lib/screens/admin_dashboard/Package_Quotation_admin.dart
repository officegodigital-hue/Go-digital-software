import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../layouts/admin_layout.dart';
import '../../services/api_config.dart';

class PackageQuotationAdmin extends StatefulWidget {
  const PackageQuotationAdmin({super.key});

  @override
  State<PackageQuotationAdmin> createState() => _PackageQuotationAdminState();
}

class _PackageQuotationAdminState extends State<PackageQuotationAdmin> {
  static String get _baseUrl => ApiConfig.baseUrl;
 
  bool _showAllPackages = true;
  List<Map<String, dynamic>> packagesData = [];
  bool _loadingPackages = true;
  String? _packagesError;
  String _searchQuery = '';

  final ScrollController _quotationScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchPackages();
    _fetchQuotations();
  }

  @override
  void dispose() {
    _quotationScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchPackages() async {
    setState(() { _loadingPackages = true; _packagesError = null; });
    try {
      final response = await http.get(Uri.parse('$_baseUrl/packages'));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          packagesData = List<Map<String, dynamic>>.from(body['data'] as List);
          _loadingPackages = false;
        });
      } else {
        setState(() { _packagesError = 'Server returned ${response.statusCode}'; _loadingPackages = false; });
      }
    } catch (e) {
      setState(() { _packagesError = 'Cannot connect to server'; _loadingPackages = false; });
    }
  }

  Future<String?> _createPackage(Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/packages'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode == 201) {
        await _fetchPackages();
        return null;
      } else {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['message'] as String? ?? 'Failed to create package';
      }
    } catch (e) {
      return 'Cannot connect to server';
    }
  }

  Future<String?> _updatePackage(int id, Map<String, dynamic> payload) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/packages/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200) {
        await _fetchPackages();
        return null;
      } else {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['message'] as String? ?? 'Failed to update package';
      }
    } catch (e) {
      return 'Cannot connect to server';
    }
  }

  Future<void> _deletePackage(int id) async {
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/packages/$id'));
      if (response.statusCode == 200) {
        await _fetchPackages();
        if (packagesData.length <= 3) _showAllPackages = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Package deleted'),
          backgroundColor: Color(0xFFDC2626),
        ));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to delete package'),
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

  String activeFilter = "All";
  bool _isFilterMenuOpen = false;

  List<Map<String, dynamic>> quotationsData = [];
  bool _loadingQuotations = true;
  String? _quotationsError;

  static const int _quotationsPerPage = 999;
  int _currentPage = 1;

  Future<void> _fetchQuotations() async {
    setState(() { _loadingQuotations = true; _quotationsError = null; });
    try {
      final response = await http.get(Uri.parse('$_baseUrl/quotations'));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          quotationsData = List<Map<String, dynamic>>.from(body['data'] as List);
          _loadingQuotations = false;
        });
      } else {
        setState(() { _quotationsError = 'Server returned ${response.statusCode}'; _loadingQuotations = false; });
      }
    } catch (e) {
      setState(() { _quotationsError = 'Cannot connect to server'; _loadingQuotations = false; });
    }
  }

  Future<void> _updateQuotationStatus(int id, String status) async {
    try {
      final response = await http.patch(
        Uri.parse("$_baseUrl/quotations/$id/status"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"status": "ACCEPTED"}),
      );

      if (response.statusCode == 200) {
        await _fetchQuotations();
        final body = jsonDecode(response.body) as Map<String, dynamic>;

        if (status.toUpperCase() == 'ACCEPTED' && body['data'] != null) {
          final invoiceData = body['data'] as Map<String, dynamic>;
          final invoiceNo  = invoiceData['invoiceNo'] as String? ?? '';
          final invoiceId  = invoiceData['invoiceId'] as int?;
          final alreadyEx  = invoiceData['alreadyExists'] as bool? ?? false;

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

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> filteredQuotations = _buildFilteredQuotations();
    final int totalQuotations = filteredQuotations.length;
    final int totalPages = totalQuotations == 0 ? 1 : (totalQuotations / _quotationsPerPage).ceil();
    
    if (_currentPage > totalPages) _currentPage = totalPages;
    if (_currentPage < 1) _currentPage = 1;

    final int startIndex = (_currentPage - 1) * _quotationsPerPage;
    final int endIndex = (startIndex + _quotationsPerPage > totalQuotations) ? totalQuotations : startIndex + _quotationsPerPage;
    final List<Map<String, dynamic>> pagedQuotations = filteredQuotations.sublist(startIndex < totalQuotations ? startIndex : 0, endIndex);

    final List<Map<String, dynamic>> visiblePackages = _showAllPackages ? packagesData : packagesData.take(3).toList();
    final bool hasMorePackages = packagesData.length > 3;

    return AdminLayout(
      pageTitle: "Package & Quotation",
      currentRoute: "/quotation",
      onSearch: (query) {
        setState(() {
          _searchQuery = query;
          _currentPage = 1;     
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("Package & Quotation", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                  SizedBox(height: 4),
                  Text("Manage service tiers and track pending client proposals.", style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showPackageFormDialog(context),
                    icon: const Icon(Icons.add, size: 16, color: Color(0xFF0052CC)),
                    label: const Text("Create New Package", style: TextStyle(color: Color(0xFF0052CC), fontWeight: FontWeight.w600, fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF0052CC)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/create-quotation'),
                    icon: const Icon(Icons.add, size: 16, color: Colors.white),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0052CC),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      elevation: 0,
                    ),
                    label: const Text("Create New Quotation", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Available Service Packages", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
              if (hasMorePackages)
                GestureDetector(
                  onTap: () => setState(() => _showAllPackages = !_showAllPackages),
                  child: Text(_showAllPackages ? " " : "View All Packages (${packagesData.length}) >",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loadingPackages)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF0052CC))),
            )
          else if (_packagesError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Column(children: [
                Text(_packagesError!, style: const TextStyle(color: Color(0xFF64748B))),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _fetchPackages, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052CC)),
                  child: const Text('Retry', style: TextStyle(color: Colors.white))),
              ])),
            )
          else if (packagesData.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('No packages yet. Click "Create New Package" to add one.', style: TextStyle(color: Color(0xFF94A3B8)))),
            )
          else
            _buildPackagesGrid(visiblePackages),
          const SizedBox(height: 40),
          _buildQuotationsTable(pagedQuotations, totalQuotations, startIndex, endIndex, totalPages),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

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

      if (!_isFilterMenuOpen || activeFilter == "All") return true;
      final dynamic statusDynamic = row["status"];
      if (statusDynamic == null) return false;
      final String status = statusDynamic.toString().toUpperCase();
      return status == activeFilter.toUpperCase();
    }).toList();
  }

  Widget _buildPackagesGrid(List<Map<String, dynamic>> visiblePackages) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double cardWidth = (constraints.maxWidth - 18 * 2) / 3;

        Widget buildCard(int globalIndex) {
          if (globalIndex >= packagesData.length) return const SizedBox.shrink();
          final Map<String, dynamic> pkg = packagesData[globalIndex];
          final String tierLabel = "TIER ${(globalIndex + 1).toString().padLeft(2, '0')}";
          return (pkg["is_popular"] == true)
              ? _buildPopularPackageCard(
                  tier: tierLabel,
                  title: pkg["title"] as String? ?? '',
                  subtitle: pkg["subtitle"] as String? ?? '',
                  price: pkg["price"] as String? ?? '',
                  period: pkg["period"] as String? ?? '',
                  features: List<String>.from((pkg["features"] as List?) ?? []),
                  onEdit: () => _showPackageFormDialog(context, editIndex: globalIndex),
                )
              : _buildStandardPackageCard(
                  tier: tierLabel,
                  title: pkg["title"] as String? ?? '',
                  subtitle: pkg["subtitle"] as String? ?? '',
                  price: pkg["price"] as String? ?? '',
                  period: pkg["period"] as String? ?? '',
                  features: List<String>.from((pkg["features"] as List?) ?? []),
                  isGoogle: (pkg["is_google"] as bool?) ?? false,
                  onEdit: () => _showPackageFormDialog(context, editIndex: globalIndex),
                );
        }

        if (!_showAllPackages || packagesData.length <= 3) {
          final List<Widget> cards = <Widget>[];
          for (int j = 0; j < visiblePackages.length; j++) {
            cards.add(WidgetCardWrapper(child: buildCard(j)));
            if (j < visiblePackages.length - 1) cards.add(const SizedBox(width: 18));
          }
          while (cards.length < 5) {
            cards.add(const SizedBox(width: 18));
            cards.add(const Expanded(child: SizedBox()));
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: cards);
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List<Widget>.generate(packagesData.length, (int j) {
              return Padding(
                padding: EdgeInsets.only(right: j < packagesData.length - 1 ? 18 : 0),
                child: SizedBox(width: cardWidth, child: buildCard(j)),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildQuotationsTable(List<Map<String, dynamic>> pagedQuotations, int totalQuotations, int startIndex, int endIndex, int totalPages) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Recent Quotations", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                Row(
                  children: [
                    AnimatedVisibility(
                      visible: _isFilterMenuOpen,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildFilterTab("All"),
                          _buildFilterTab("Draft"),
                          _buildFilterTab("Sent"),
                          _buildFilterTab("Accepted"),
                          _buildFilterTab("Expired"),
                          const SizedBox(width: 12),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() {
                        _isFilterMenuOpen = !_isFilterMenuOpen;
                        if (!_isFilterMenuOpen) activeFilter = "All";
                      }),
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
                            Icon(_isFilterMenuOpen ? Icons.filter_list_off_rounded : Icons.filter_list_rounded, size: 14, color: const Color(0xFF475569)),
                            const SizedBox(width: 6),
                            Text(_isFilterMenuOpen ? "Hide Filters" : "Filters", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
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
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: const [
                Expanded(flex: 1, child: Text("S.NO", style: _tableHeaderStyle)),
                Expanded(flex: 3, child: Text("QUOTATION ID", style: _tableHeaderStyle)),
                Expanded(flex: 3, child: Text("CLIENT NAME", style: _tableHeaderStyle)),
                Expanded(flex: 2, child: Text("PACKAGE TYPE", style: _tableHeaderStyle)),
                Expanded(flex: 2, child: Text("AMOUNT", style: _tableHeaderStyle)),
                Expanded(flex: 3, child: Text("STATUS", style: _tableHeaderStyle)),
                Expanded(flex: 3, child: Text("DATE", style: _tableHeaderStyle)),
                Expanded(flex: 2, child: Text("PDF", style: _tableHeaderStyle)),
                Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text("ACTIONS", style: _tableHeaderStyle))),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
          if (_loadingQuotations)
            const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator(color: Color(0xFF0052CC))))
          else if (_quotationsError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Column(children: [
                Text(_quotationsError!, style: const TextStyle(color: Color(0xFF64748B))),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _fetchQuotations, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052CC)),
                  child: const Text('Retry', style: TextStyle(color: Colors.white))),
              ])),
            )
          else if (pagedQuotations.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text("No proposals found in this group category.", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11))),
            )
          else
            SizedBox(
              height: 420,
              child: Scrollbar(
                controller: _quotationScrollController,
                thumbVisibility: true,
                child: ListView.separated(
                  controller: _quotationScrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: pagedQuotations.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFE2E8F0),
                  ),
                  itemBuilder: (context, index) {
                    return _buildQuotationRow(
                      pagedQuotations[index],
                      startIndex + index + 1,
                    );
                  },
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: const BoxDecoration(color: Color(0xFFF8FAFC), borderRadius: BorderRadius.vertical(bottom: Radius.circular(8))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(totalQuotations == 0 ? "Showing 0 of 0 quotations" : "Showing ${startIndex + 1} to $endIndex of $totalQuotations quotations",
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                Row(
                  children: [
                    _buildPageButton("<", false, onTap: _currentPage > 1 ? () => setState(() => _currentPage--) : null),
                    for (int p = 1; p <= totalPages; p++)
                      _buildPageButton("$p", p == _currentPage, onTap: () => setState(() => _currentPage = p)),
                    _buildPageButton(">", false, onTap: _currentPage < totalPages ? () => setState(() => _currentPage++) : null),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

// ── EXTRA ADD TASK SUB-DIALOG PICKER ─────────────────────────────────────
  void _showExtraAddTaskPopup(StateSetter setDialogState, List<TextEditingController> taskCtrls) async {
    try {
      final taskMasterResponse = await http.get(Uri.parse('$_baseUrl/task-master'));
      if (taskMasterResponse.statusCode != 200) return;
      final taskMasterList = List<Map<String, dynamic>>.from(jsonDecode(taskMasterResponse.body)['data'] ?? []);

      if (!mounted) return;

      final Map<String, String> roleMapping = {
        'ads_handler_task': 'Ads Handler',
        'page_handler_task': 'Page Handler',
        'graphic_designer_task': 'Designer',
        'videographer_task': 'Videographer',
        'video_editor_task': 'Video Editor',
        'ui_ux_designer_task': 'UI/UX Designer',
        'developer_task': 'Developer',
      };

      List<String> availableRoleKeys = taskMasterList
          .map((t) => t['role_key']?.toString() ?? '')
          .where((k) => k.isNotEmpty)
          .toSet()
          .toList();

      if (availableRoleKeys.isEmpty) return;

      String? selectedRoleKey = availableRoleKeys.first;
      Map<int, int> selectedTaskCounts = {}; // taskId -> count

      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setSubState) {
              final filteredTasks = taskMasterList.where((t) => t['role_key'] == selectedRoleKey).toList();

              return AlertDialog(
                title: const Text('Select Tasks from Task Master', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                content: SizedBox(
                  width: 400,
                  height: 400,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Select Role:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedRoleKey,
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        items: availableRoleKeys.map((rKey) {
                          String displayName = roleMapping[rKey] ?? rKey.replaceAll('_', ' ').toUpperCase();
                          return DropdownMenuItem<String>(
                            value: rKey,
                            child: Text(displayName, style: const TextStyle(fontSize: 12)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setSubState(() {
                            selectedRoleKey = val;
                            selectedTaskCounts.clear();
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text('Select Task Names & Counts:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Expanded(
                        child: filteredTasks.isEmpty
                            ? const Center(child: Text('No tasks found for this role.', style: TextStyle(color: Colors.grey, fontSize: 12)))
                            : ListView.builder(
                                itemCount: filteredTasks.length,
                                itemBuilder: (context, index) {
                                  final task = filteredTasks[index];
                                  final int taskId = task['id'];
                                  final String taskName = task['task_name'] ?? '';
                                  final bool isSelected = selectedTaskCounts.containsKey(taskId);

                                  return CheckboxListTile(
                                    title: Text(taskName, style: const TextStyle(fontSize: 12)),
                                    value: isSelected,
                                    dense: true,
                                    controlAffinity: ListTileControlAffinity.leading,
                                    contentPadding: EdgeInsets.zero,
                                    onChanged: (bool? checked) {
                                      setSubState(() {
                                        if (checked == true) {
                                          selectedTaskCounts[taskId] = 1;
                                        } else {
                                          selectedTaskCounts.remove(taskId);
                                        }
                                      });
                                    },
                                    secondary: isSelected
                                        ? SizedBox(
                                            width: 70,
                                            height: 32,
                                            child: TextField(
                                              keyboardType: TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText: 'Count',
                                                labelStyle: TextStyle(fontSize: 10),
                                                contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                                border: OutlineInputBorder(),
                                              ),
                                              style: const TextStyle(fontSize: 12),
                                              controller: TextEditingController(text: selectedTaskCounts[taskId].toString()),
                                              onChanged: (val) {
                                                int? parsed = int.tryParse(val);
                                                if (parsed != null && parsed > 0) {
                                                  selectedTaskCounts[taskId] = parsed;
                                                }
                                              },
                                            ),
                                          )
                                        : null,
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052CC)),
                    onPressed: () {
                      setDialogState(() {
                        for (var entry in selectedTaskCounts.entries) {
                          final taskObj = taskMasterList.firstWhere((t) => t['id'] == entry.key);
                          final name = taskObj['task_name'];
                          final rKey = taskObj['role_key']; 
                          final count = entry.value;
                          
                          // Format including role key: e.g. "GOOGLE ADS (1) [ads_handler_task]"
                          taskCtrls.add(TextEditingController(text: '$name ($count) [$rKey]'));
                        }
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Add Package Tasks', style: TextStyle(color: Colors.white)),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      debugPrint('Error loading task master roles: $e');
    }
  }

  
  void _showPackageFormDialog(BuildContext context, {int? editIndex}) {
    final bool isEdit = editIndex != null;
    final Map<String, dynamic>? existing = isEdit ? packagesData[editIndex] : null;

    final TextEditingController titleCtrl = TextEditingController(text: existing?["title"] as String? ?? "");
    final TextEditingController subtitleCtrl = TextEditingController(text: existing?["subtitle"] as String? ?? "");
    final TextEditingController priceCtrl = TextEditingController(text: existing?["price"] as String? ?? "");
    final TextEditingController periodCtrl = TextEditingController(text: existing?["period"] as String? ?? "/Month");

    bool isPopular = (existing?["is_popular"] as bool?) ?? false;

    // Regular features controllers list
    final List<TextEditingController> featureCtrls = existing != null
        ? (List<String>.from((existing["features"] as List?) ?? []))
            .map((String f) => TextEditingController(text: f)).toList()
        : [TextEditingController()];

    // Package tasks controllers list mapping from package_tasks column
    final List<TextEditingController> packageTaskCtrls = existing != null && existing["package_tasks"] != null
        ? (List<dynamic>.from(existing["package_tasks"])).map((t) {
            if (t is Map) {
              return TextEditingController(text: "${t['task_name']} (${t['count']}) [${t['role_key']}]");
            }
            return TextEditingController(text: t.toString());
          }).toList()
        : [];

    String? dialogError;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          void addFeatureRow() {
            setDialogState(() => featureCtrls.add(TextEditingController()));
          }

          void removeFeatureRow(int idx) {
            setDialogState(() => featureCtrls.removeAt(idx));
          }

          void addPackageTaskRow() {
            setDialogState(() => packageTaskCtrls.add(TextEditingController()));
          }

          void removePackageTaskRow(int idx) {
            setDialogState(() => packageTaskCtrls.removeAt(idx));
          }

          Future<void> handleSubmit() async {
            final String title = titleCtrl.text.trim();
            final String subtitle = subtitleCtrl.text.trim();
            final String price = priceCtrl.text.trim();
            final String period = periodCtrl.text.trim();

            final List<String> features = featureCtrls
                .map((c) => c.text.trim())
                .where((f) => f.isNotEmpty)
                .toList();

            // Structure package_tasks into JSON objects to save in the package_tasks column
            final List<Map<String, dynamic>> packageTasksPayload = [];
            for (var ctrl in packageTaskCtrls) {
              final text = ctrl.text.trim();
              if (text.isNotEmpty) {
                final match = RegExp(r'^(.*?)\s*\((\d+)\)\s*\[(.*?)\]$').firstMatch(text);
                if (match != null) {
                  packageTasksPayload.add({
                    "task_name": match.group(1)?.trim(),
                    "count": int.tryParse(match.group(2) ?? '1') ?? 1,
                    "role_key": match.group(3)?.trim(),
                  });
                } else {
                  packageTasksPayload.add({
                    "task_name": text,
                    "count": 1,
                    "role_key": "general_task",
                  });
                }
              }
            }

            if (title.isEmpty || price.isEmpty || (features.isEmpty && packageTasksPayload.isEmpty)) {
              setDialogState(() => dialogError = 'Please fill Package Title, Price, and at least one feature or task');
              return;
            }

            setDialogState(() {
              isSubmitting = true;
              dialogError = null;
            });

            final Map<String, dynamic> payload = {
              "title": title,
              "subtitle": subtitle,
              "price": price,
              "period": period.isEmpty ? "/Month" : period,
              "isPopular": isPopular,
              "features": features,
              "package_tasks": packageTasksPayload, // Sent to new package_tasks column
            };

            final String? error = isEdit
                ? await _updatePackage(existing!["id"] as int, payload)
                : await _createPackage(payload);

            if (error == null) {
              if (context.mounted) Navigator.pop(context);

              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(isEdit ? 'Package updated' : 'Package created'),
                    backgroundColor: const Color(0xFF16A34A),
                  ),
                );
              }
            } else {
              setDialogState(() {
                isSubmitting = false;
                dialogError = error;
              });
            }
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEdit ? "Edit Package" : "Create New Package",
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 20),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12.0), child: Divider(color: Color(0xFFE2E8F0), height: 1)),
                  if (dialogError != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(dialogError!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _dialogField(label: "Package Title *", hint: "e.g. Kickstart Package", controller: titleCtrl),
                          const SizedBox(height: 14),
                          _dialogField(label: "Subtitle", hint: "e.g. SMART LAUNCH FOR GROWING BRANDS", controller: subtitleCtrl),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(child: _dialogField(label: "Price *", hint: "e.g. ₹8,000", controller: priceCtrl)),
                              const SizedBox(width: 14),
                              Expanded(child: _dialogField(label: "Period", hint: "e.g. /Month", controller: periodCtrl)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          CheckboxListTile(
                            value: isPopular,
                            onChanged: (bool? v) => setDialogState(() => isPopular = v ?? false),
                            title: const Text("Mark as 'Most Popular'", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                            subtitle: const Text("Highlights card in blue", style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            activeColor: const Color(0xFF0052CC),
                          ),
                          const SizedBox(height: 12),

                          // ── PACKAGE FEATURES SECTION ──────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Package Features *", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                              TextButton.icon(
                                onPressed: addFeatureRow,
                                icon: const Icon(Icons.add, size: 16, color: Color(0xFF0052CC)),
                                label: const Text("Add Feature", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0052CC))),
                                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...featureCtrls.asMap().entries.map((MapEntry<int, TextEditingController> entry) {
                            final int idx = entry.key;
                            final TextEditingController ctrl = entry.value;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF22C55E)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: SizedBox(
                                      height: 40,
                                      child: TextField(
                                        controller: ctrl,
                                        decoration: InputDecoration(
                                          hintText: "Feature description",
                                          filled: true,
                                          fillColor: const Color(0xFFF8FAFC),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF0052CC))),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  SizedBox(
                                    width: 34,
                                    child: IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
                                      splashRadius: 18,
                                      padding: EdgeInsets.zero,
                                      onPressed: featureCtrls.length > 1 ? () => removeFeatureRow(idx) : null,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                              ),
                            );
                          }),

                          const SizedBox(height: 16),
                          const Divider(color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 12),

                          // ── PACKAGE TASKS SECTION ─────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Package Tasks *", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _showExtraAddTaskPopup(setDialogState, packageTaskCtrls),
                                    icon: const Icon(Icons.playlist_add, size: 16, color: Color(0xFF16A34A)),
                                    label: const Text("Extra Add Task", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF16A34A))),
                                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                  ),
                                  const SizedBox(width: 12),
                                  TextButton.icon(
                                    onPressed: addPackageTaskRow,
                                    icon: const Icon(Icons.add, size: 16, color: Color(0xFF1E293B)),
                                    label: const Text("Add Task", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...packageTaskCtrls.asMap().entries.map((MapEntry<int, TextEditingController> entry) {
                            final int idx = entry.key;
                            final TextEditingController ctrl = entry.value;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  const Icon(Icons.task_alt_rounded, size: 16, color: Color(0xFF0052CC)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: SizedBox(
                                      height: 40,
                                      child: TextField(
                                        controller: ctrl,
                                        decoration: InputDecoration(
                                          hintText: "Task Name (Count) [role_key]",
                                          filled: true,
                                          fillColor: const Color(0xFFF0F6FF),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF93C5FD))),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF0052CC))),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  SizedBox(
                                    width: 34,
                                    child: IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
                                      splashRadius: 18,
                                      padding: EdgeInsets.zero,
                                      onPressed: () => removePackageTaskRow(idx),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isEdit) ...[
                        OutlinedButton.icon(
                          onPressed: isSubmitting ? null : () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Delete Package'),
                                content: Text('Remove "${existing!["title"]}"? This cannot be undone.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      Navigator.pop(context);
                                      _deletePackage(existing["id"] as int);
                                    },
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                                    child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                          label: const Text("Delete Package", style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          ),
                        ),
                        const Spacer(),
                      ],
                      OutlinedButton(
                        onPressed: isSubmitting ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                        child: const Text("Cancel", style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: isSubmitting ? null : handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0052CC),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          elevation: 0,
                        ),
                        child: isSubmitting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(isEdit ? "Save Changes" : "Create Package", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _dialogField({required String label, required String hint, required TextEditingController controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF0052CC))),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStandardPackageCard({
    required String tier,
    required String title,
    required String subtitle,
    required String price,
    required String period,
    required List<String> features,
    bool isGoogle = false,
    required VoidCallback onEdit,
  }) {
    return Container(
      height: 380,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: const Border(left: BorderSide(color: Color(0xFFCBD5E1), width: 1.5)),
        boxShadow: const [BoxShadow(color: Color(0xFFF1F5F9), blurRadius: 4, offset: Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tier, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(price, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
            Text(period, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ]),
          Text(isGoogle ? "(Ad Wallet & Domain Excluded)" : "(Ad Wallet Excluded)", style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: Color(0xFFF1F5F9))),
          Expanded(child: SingleChildScrollView(child: Column(
            children: features.map((String f) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF22C55E)),
                const SizedBox(width: 8),
                Expanded(child: Text(f, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF475569)))),
              ]),
            )).toList(),
          ))),
          SizedBox(width: double.infinity, child: OutlinedButton(
            onPressed: onEdit,
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFE2E8F0)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
            child: const Text("Edit Package", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          )),
        ],
      ),
    );
  }

  Widget _buildPopularPackageCard({
    required String tier,
    required String title,
    required String subtitle,
    required String price,
    required String period,
    required List<String> features,
    required VoidCallback onEdit,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 380,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: const Color(0xFF0052CC), borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(color: Color(0xFFDBE5F5), blurRadius: 8, offset: Offset(0, 4))]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tier, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.6))),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.8))),
              const SizedBox(height: 16),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text(price, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                Text(period, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6))),
              ]),
              Text("(Ad Wallet Excluded)", style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.6))),
              Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Divider(color: Colors.white.withValues(alpha: 0.1))),
              Expanded(child: SingleChildScrollView(child: Column(
                children: features.map((String f) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.9)))),
                  ]),
                )).toList(),
              ))),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: onEdit,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                child: const Text("Edit Package", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0052CC))),
              )),
            ],
          ),
        ),
        Positioned(
          top: -12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(4)),
            child: const Text("Most Popular", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
        )
      ],
    );
  }

  static const TextStyle _tableHeaderStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5);

  Widget _buildQuotationRow(Map<String, dynamic> row, int serialNo) {
    final int id = row["id"] as int? ?? 0;
    final String quotNo = row["quotation_no"] as String? ?? '';
    final String client = row["client_name"] as String? ?? '';
    final String type = row["package_type"] as String? ?? '-';
    final double total = double.tryParse(row["total_amount"]?.toString() ?? '0') ?? 0;
    final String amount = "₹${total.toStringAsFixed(0)}";
    final String status = (row["status"]?.toString() ?? 'DRAFT').toUpperCase();
    final String date = row["quotation_date"] as String? ?? '';
    final int? linkedInvId = row["linked_invoice_id"] as int?;
    final String linkedInvNo = row["linked_invoice_no"] as String? ?? '';

    final List<String> words = client.trim().split(RegExp(r'\s+'));
    final String initials = (words.isNotEmpty ? words[0].substring(0, 1) : '') + (words.length > 1 ? words[1].substring(0, 1) : '');

    final Color statusBg = _statusBg[status] ?? const Color(0xFFF1F5F9);
    final Color statusText = _statusText[status] ?? const Color(0xFF475569);

    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              serialNo.toString(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
          ),
          Expanded(flex: 3, child: Text(quotNo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
          Expanded(
            flex: 3,
            child: Row(children: [
              CircleAvatar(radius: 12, backgroundColor: const Color(0xFFE2E8F0), child: Text(initials.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
              const SizedBox(width: 10),
              Expanded(child: Text(client, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          ),
          Expanded(flex: 2, child: Text(type, style: const TextStyle(fontSize: 11, color: Color(0xFF475569)), maxLines: 1, overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Text(amount, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(4)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: status,
                    isDense: true,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: statusText),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusText),
                    dropdownColor: Colors.white,
                    items: _statusBg.keys.map((String s) => DropdownMenuItem(value: s, child: Text(s, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _statusText[s])))).toList(),
                    onChanged: (String? val) {
                      if (val != null && val != status) _updateQuotationStatus(id, val);
                    },
                  ),
                ),
              ),
            ),
          ),
          Expanded(flex: 3, child: Text(date, style: const TextStyle(fontSize: 11, color: Color(0xFF475569)))),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center, children: [
              Tooltip(message: 'View PDF', child: GestureDetector(
                onTap: () => _viewQuotationPDFPreview(context, id, quotNo),
                child: const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.preview_rounded, size: 18, color: Color(0xFF0052CC))),
              )),
            ]),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (linkedInvId != null)
                    Tooltip(message: 'View Invoice $linkedInvNo', child: GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/add-invoice', arguments: {'invoiceId': linkedInvId, 'viewOnly': false}),
                      child: const Padding(padding: EdgeInsets.symmetric(horizontal: 3), child: Icon(Icons.receipt_long_rounded, size: 18, color: Color(0xFF16A34A))),
                    )),
                  Tooltip(message: 'View', child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/create-quotation', arguments: {'quotationId': id, 'viewOnly': true}),
                    child: const Padding(padding: EdgeInsets.symmetric(horizontal: 3), child: Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF475569))),
                  )),
                  Tooltip(message: 'Edit', child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/create-quotation', arguments: {'quotationId': id, 'viewOnly': false}),
                    child: const Padding(padding: EdgeInsets.symmetric(horizontal: 3), child: Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0052CC))),
                  )),
                  Tooltip(message: 'Delete', child: GestureDetector(
                    onTap: () {
                      showDialog(context: context, builder: (_) => AlertDialog(
                        title: const Text('Delete Quotation'),
                        content: Text('Remove "$quotNo"? This cannot be undone.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                          ElevatedButton(
                            onPressed: () { Navigator.pop(context); _deleteQuotation(id); },
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                            child: const Text('Delete', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ));
                    },
                    child: const Padding(padding: EdgeInsets.symmetric(horizontal: 3), child: Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626))),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label) {
    final bool isActive = activeFilter.toUpperCase() == label.toUpperCase();
    return Container(
      margin: const EdgeInsets.only(right: 4),
      child: OutlinedButton(
        onPressed: () => setState(() {
          activeFilter = label;
          _currentPage = 1;
        }),
        style: OutlinedButton.styleFrom(
          backgroundColor: isActive ? const Color(0xFF0052CC) : Colors.transparent,
          side: BorderSide(color: isActive ? const Color(0xFF0052CC) : const Color(0xFFE2E8F0)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          elevation: 0,
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: isActive ? FontWeight.bold : FontWeight.w600, color: isActive ? Colors.white : const Color(0xFF64748B))),
      ),
    );
  }

  Widget _buildPageButton(String text, bool isActive, {VoidCallback? onTap}) {
    final bool isDisabled = onTap == null && !isActive;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0052CC) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: isActive ? null : Border.all(color: const Color(0xFFE2E8F0)),
        ),
        alignment: Alignment.center,
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isActive ? Colors.white : (isDisabled ? const Color(0xFFCBD5E1) : const Color(0xFF475569)))),
      ),
    );
  }
}

class WidgetCardWrapper extends StatelessWidget {
  final Widget child;
  const WidgetCardWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Expanded(child: child);
}

class AnimatedVisibility extends StatelessWidget {
  final bool visible;
  final Widget child;

  const AnimatedVisibility({super.key, required this.visible, required this.child});

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeInOut,
    child: visible ? child : const SizedBox.shrink(),
  );
}