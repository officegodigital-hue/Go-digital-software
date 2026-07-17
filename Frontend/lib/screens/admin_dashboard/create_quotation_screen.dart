import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../layouts/admin_layout.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../widgets/client_dropdown.dart';
import '../../services/api_config.dart';

import 'dart:io';
import 'dart:typed_data';
import 'dart:async';

class _QuotationItemRow {
  int? packageId;
  bool isPackageRow;
  final TextEditingController descriptionCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController rateCtrl;
  final TextEditingController paidCtrl;

  _QuotationItemRow({
    this.packageId,
    required this.isPackageRow,
    String description = '',
    String qty = '1',
    String rate = '0.00',
    String paid = '0.00',
  })  : descriptionCtrl = TextEditingController(text: description),
        qtyCtrl = TextEditingController(text: qty),
        rateCtrl = TextEditingController(text: rate),
        paidCtrl = TextEditingController(text: paid);

  void dispose() {
    descriptionCtrl.dispose();
    qtyCtrl.dispose();
    rateCtrl.dispose();
    paidCtrl.dispose();
  }
}

class CreateQuotationScreen extends StatefulWidget {
  final int? quotationId;
  final bool viewOnly;
 
  const CreateQuotationScreen({
    super.key,
    this.quotationId,
    this.viewOnly = false,
  });
 
  @override
  State<CreateQuotationScreen> createState() => _CreateQuotationScreenState();
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
      composing: newValue.composing,
    );
  }
}

class _CreateQuotationScreenState extends State<CreateQuotationScreen> {
  // static const String _baseUrl = '/api';
  static String get _baseUrl => ApiConfig.baseUrl;

  final quotationNoController = TextEditingController(text: "Loading...");
  final clientNameController = TextEditingController(text: "");
  final dateController = TextEditingController();
  final expiryController = TextEditingController();
  final discountController = TextEditingController(text: "0.00");
  final notesController = TextEditingController();
  
  final termsController = TextEditingController(
    text: '• Project development only\n• 50% advance required\n• No refund after approval',
  );

  late TextEditingController quotationDateController;
  late TextEditingController expiryDateController;

List<Map<String, dynamic>> items = [];
  bool includeGST = false;

  double subtotal = 0;
  double tax = 0;
  double totalAmount = 0;
  double paidAmount = 0;
  double balanceAmount = 0;


  bool agreedToTerms = false;
  bool _isSaving = false;
  bool _isPrinting = false;
  bool isLoading = false;
  bool isSaving = false;
  bool isSaved = false; 

  int? _quotationId;
  bool _viewOnly = false;
  bool _loadingExisting = false;
  bool _argsProcessed = false;
  

  // ✅ NEW: Client list for dropdown
  List<Map<String, dynamic>> _clients = [];
  bool _loadingClients = false;
  bool _isSearching = false;
  int? _selectedClientId;
  String _clientSearchQuery = '';
  bool _showClientDropdown = false;
  int? _debounceTimerId;

  List<Map<String, dynamic>> _packages = [];
  bool _loadingPackages = true;

  late List<_QuotationItemRow> _items;

  

  @override
  void initState() {
    super.initState();
    _items = [_QuotationItemRow(isPackageRow: true)];
    final now = DateTime.now();
    dateController.text = DateFormat('dd/MM/yyyy').format(now);
    expiryController.text = DateFormat('dd/MM/yyyy').format(now.add(const Duration(days: 5)));
    _fetchPackages();
    _fetchClients(); // ✅ NEW: Fetch clients on init
 
    _quotationId = widget.quotationId;
    _viewOnly = widget.viewOnly;
    
    if (_quotationId != null) {
      _loadExistingQuotation(_quotationId!);
    } else {
      _fetchNextQuotationNumber();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsProcessed) return;
    _argsProcessed = true;

    if (widget.quotationId == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        final id = args['quotationId'];
        final view = args['viewOnly'] == true;
        if (id is int) {
          setState(() {
            _quotationId = id;
            _viewOnly = view;
          });
          _loadExistingQuotation(id);
        }
      }
    }
  }

Future<void> _searchClients(String query) async {
  if (query.isEmpty) {
    setState(() {
      _clients = [];
      _showClientDropdown = false;
    });
    return;
  }

  setState(() => _loadingClients = true);
  try {
    // API URL உங்கள் quotation-ல் உள்ளது போலவே இருக்கட்டும்
    final response = await http.get(
      Uri.parse('$_baseUrl/clients/search/query?query=${Uri.encodeComponent(query)}'),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      setState(() {
        _clients = List<Map<String, dynamic>>.from(body['data'] ?? []);
        _showClientDropdown = _clients.isNotEmpty;
        _loadingClients = false;
      });
    } else {
      setState(() => _loadingClients = false);
    }
  } catch (e) {
    setState(() => _loadingClients = false);
  }
}

void _onClientSearchChanged(String value) {
  if (_debounce?.isActive ?? false) _debounce!.cancel();
  
  _debounce = Timer(const Duration(milliseconds: 500), () {
    if (mounted) _searchClients(value);
  });

  setState(() {
    _showClientDropdown = true;
  });
}

void _selectClient(Map<String, dynamic> client) {
  setState(() {
    clientNameController.text = (client['company_name'] ?? '').toUpperCase();
    _showClientDropdown = false;
  });
}

Timer? _debounce;
  // ✅ NEW: Debounced search to avoid too many API calls

  // ✅ NEW: Get filtered clients based on current results
  List<Map<String, dynamic>> _getFilteredClients() {
    return _clients;
  }

  // ✅ OLD: Fetch clients from API (deprecated - keeping for reference)
  Future<void> _fetchClients() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/clients'));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          _clients = List<Map<String, dynamic>>.from(body['data']);
          _loadingClients = false;
        });
      } else {
        setState(() => _loadingClients = false);
      }
    } catch (e) {
      setState(() => _loadingClients = false);
    }
  }

  // ✅ OLD: Select client from dropdown (deprecated - use new one)
  void _selectClientOld(Map<String, dynamic> client) {
    setState(() {
      _selectedClientId = client['id'];
      clientNameController.text = (client['company_name'] ?? '').toUpperCase();
      _showClientDropdown = false;
      _clientSearchQuery = '';
    });
  }

  // ✅ OLD: Get filtered clients based on search query (deprecated)
  List<Map<String, dynamic>> _getFilteredClientsOld() {
    if (_clientSearchQuery.isEmpty) {
      return _clients;
    } 
    return _clients
        .where((c) => (c['company_name'] ?? '')
            .toUpperCase()
            .contains(_clientSearchQuery.toUpperCase()))
        .toList();
  }

  Future<void> _loadExistingQuotation(int id) async {
    setState(() => _loadingExisting = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/quotations/$id'));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'];

        for (final item in _items) {
          item.dispose();
        }

        final List<_QuotationItemRow> loadedItems = [];
        for (final it in (data['items'] as List)) {
          loadedItems.add(_QuotationItemRow(
            isPackageRow: it['package_id'] != null,
            packageId: it['package_id'],
            description: it['description'] ?? '',
            qty: (it['qty'] ?? 1).toString(),
            rate: double.tryParse(it['rate'].toString())?.toStringAsFixed(2) ?? '0.00',
            paid: double.tryParse(it['paid_amount'].toString())?.toStringAsFixed(2) ?? '0.00',
          ));
        }

        setState(() {
          quotationNoController.text = data['quotation_no'] ?? '';
          clientNameController.text = (data['client_name'] ?? '').toUpperCase();
          dateController.text = data['quotation_date'] ?? '';
          expiryController.text = data['expiry_date'] ?? '';
          discountController.text = double.tryParse(data['discount'].toString())?.toStringAsFixed(2) ?? '0.00';
          notesController.text = data['notes'] ?? '';
          termsController.text = data['terms'] ?? termsController.text;
          includeGST = data['include_gst'] == 1 || data['include_gst'] == true;
          _items = loadedItems.isNotEmpty ? loadedItems : [_QuotationItemRow(isPackageRow: true)];
          _loadingExisting = false;
        });
      } else {
        setState(() => _loadingExisting = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to load quotation'),
            backgroundColor: Colors.redAccent,
          ));
        }
      }
    } catch (e) {
      setState(() => _loadingExisting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Cannot connect to server'),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  Future<void> _selectCalendarDate(BuildContext context, TextEditingController controller) async {
    DateTime initialDate = DateTime.now();

    try {
      if (controller.text.isNotEmpty) {
        initialDate = DateFormat('dd/MM/yyyy').parse(controller.text);
      }
    } catch (_) {}

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
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
        controller.text = DateFormat('dd/MM/yyyy').format(pickedDate);
      });
    }
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    quotationNoController.dispose();
    clientNameController.dispose();
    dateController.dispose();
    expiryController.dispose();
    discountController.dispose();
    notesController.dispose();
    termsController.dispose();
    super.dispose();
  }

  Future<void> _fetchPackages() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/packages'));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          _packages = List<Map<String, dynamic>>.from(body['data']);
          _loadingPackages = false;
        });
      } else {
        setState(() => _loadingPackages = false);
      }
    } catch (e) {
      setState(() => _loadingPackages = false);
    }
  }

Future<void> _fetchNextQuotationNumber() async {
  try {
    final response = await http.get(
      Uri.parse('$_baseUrl/quotations/next-number'),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);

      setState(() {
        quotationNoController.text = body['data']['quotationNo'];
      });
    } else {
      _setDefaultQuotationNumber();
    }
  } catch (e) {
    print(e);
    _setDefaultQuotationNumber();
  }
}

void _setDefaultQuotationNumber() {
  final now = DateTime.now();

  final yyyy = now.year.toString();
  final mm = now.month.toString().padLeft(2, '0');
  final dd = now.day.toString().padLeft(2, '0');

  setState(() {
    quotationNoController.text = 'QT-$yyyy$mm${dd}301';
  });

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Using default quotation number. Check connection.'),
        backgroundColor: Colors.orangeAccent,
      ),
    );
  }
}

  double _parseAmount(String text) => double.tryParse(text.replaceAll(',', '')) ?? 0.0;

  String _extractRateFromPrice(String price) {
    final digits = price.replaceAll(RegExp(r'[^0-9.]'), '');
    final value = double.tryParse(digits) ?? 0.0;
    return value.toStringAsFixed(2);
  }

  void _onPackageSelected(_QuotationItemRow row, int packageId) {
    final pkg = _packages.firstWhere((p) => p['id'] == packageId, orElse: () => {});
    if (pkg.isEmpty) return;
 
    final features = (pkg['features'] as List?)?.cast<String>() ?? [];
    final featuresList = features.isNotEmpty ? features.join('\n• ') : '';
 
    setState(() {
      row.packageId = packageId;
      final packageTitle = pkg['title'] ?? '';
      row.descriptionCtrl.text = featuresList.isEmpty 
          ? packageTitle 
          : '$packageTitle\n• $featuresList';
      row.rateCtrl.text = _extractRateFromPrice(pkg['price']?.toString() ?? '0');
    });
  }

  void _addSection() {
    setState(() {
      _items.add(_QuotationItemRow(isPackageRow: false));
    });
  }

  void _removeRow(int index) {
    if (_items.length <= 1) return;
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  double _rowAmount(_QuotationItemRow row) {
    final qty = int.tryParse(row.qtyCtrl.text) ?? 1;
    final rate = _parseAmount(row.rateCtrl.text);
    return qty * rate;
  }

  double _rowPending(_QuotationItemRow row) {
    final amount = _rowAmount(row);
    final paid = _parseAmount(row.paidCtrl.text);
    final pending = amount - paid;
    return pending < 0 ? 0 : pending;
  }

  Future<bool> _saveQuotation(double subtotal, double discount, double tax, double total, double paid, double balance) async {
    final items = _items.map((row) => {
      "packageId": row.packageId,
      "description": row.descriptionCtrl.text.trim(),
      "qty": int.tryParse(row.qtyCtrl.text) ?? 1,
      "rate": _parseAmount(row.rateCtrl.text),
      "amount": _rowAmount(row),
      "paidAmount": _parseAmount(row.paidCtrl.text),
      "pendingAmount": _rowPending(row),
    }).toList();

    final payload = {
      "quotationNo": quotationNoController.text,
      "clientName": clientNameController.text,
      "quotationDate": dateController.text,
      "expiryDate": expiryController.text,
      "includeGST": includeGST,
      "discount": discount,
      "notes": notesController.text,
      "terms": termsController.text,
      "subtotal": subtotal,
      "tax": tax,
      "totalAmount": total,
      "paidAmount": paid,
      "balanceAmount": balance,
      "items": items,
    };

    try {
      final isEdit = _quotationId != null;
      final response = isEdit
          ? await http.put(
              Uri.parse('$_baseUrl/quotations/$_quotationId'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
          : await http.post(
              Uri.parse('$_baseUrl/quotations'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        final body = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(body['message'] ?? 'Failed to save quotation'),
            backgroundColor: Colors.redAccent,
          ));
        }
        return false;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Cannot connect to server'),
          backgroundColor: Colors.redAccent,
        ));
      }
      return false;
    }
  }

  Future<Uint8List?> _generateQuotationPDFBytes(double subtotal, double discount, double total, double tax, double paid, double balance) async {
    try {
      final logoImage = pw.MemoryImage(
        (await rootBundle.load('assets/images/godigital_logo.png')).buffer.asUint8List(),
      );
      final sealImage = pw.MemoryImage(
        (await rootBundle.load('assets/images/office_seal.png')).buffer.asUint8List(),
      );

      final font = await PdfGoogleFonts.notoSansRegular();
      final fontBold = await PdfGoogleFonts.notoSansBold();

      final pdf = pw.Document();

      const PdfColor blue = PdfColor.fromInt(0xFF1F4E9E);
      const PdfColor white = PdfColor.fromInt(0xFFFFFFFF);
      const PdfColor grey = PdfColor.fromInt(0xFFF0F0F0);
      const PdfColor black = PdfColor.fromInt(0xFF000000);

      final validItems = _items.where((item) {
        final desc = item.descriptionCtrl.text.trim();
        final qty = item.qtyCtrl.text.trim();
        return desc.isNotEmpty && qty.isNotEmpty;
      }).toList();

      if (validItems.isEmpty) {
        return null;
      }

      pw.Widget tableCell(String text, {
        bool bold = false,
        pw.Alignment align = pw.Alignment.centerLeft,
        double fontSize = 10,
      }) {
        return pw.Container(
          padding: const pw.EdgeInsets.all(8),
          alignment: align,
          child: pw.Text(
            text,
            style: pw.TextStyle(
              font: bold ? fontBold : font,
              fontSize: fontSize,
            ),
          ),
        );
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Container(
                  color: blue,
                  height: 28,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Container(width: 10, height: 10, color: white, margin: const pw.EdgeInsets.only(left: 5)),
                      pw.Container(width: 10, height: 10, color: white, margin: const pw.EdgeInsets.only(left: 5)),
                      pw.Container(width: 10, height: 10, color: white, margin: const pw.EdgeInsets.only(left: 5)),
                      pw.Container(width: 10, height: 10, color: white, margin: const pw.EdgeInsets.only(left: 5)),
                    ],
                  ),
                ),

                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.fromLTRB(30, 16, 30, 10),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          width: 140,
                          height: 50,
                          child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                        ),

                        pw.SizedBox(height: 14),

                        pw.Container(
                          decoration: pw.BoxDecoration(border: pw.Border.all(color: black, width: 1)),
                          child: pw.Column(
                            children: [
                              pw.Container(
                                decoration: pw.BoxDecoration(
                                  border: pw.Border(bottom: pw.BorderSide(color: black, width: 1)),
                                ),
                                child: pw.Row(
                                  children: [
                                    pw.Expanded(
                                      flex: 2,
                                      child: pw.Container(
                                        padding: const pw.EdgeInsets.all(10),
                                        decoration: pw.BoxDecoration(
                                          border: pw.Border(right: pw.BorderSide(color: black, width: 1)),
                                        ),
                                        alignment: pw.Alignment.center,
                                        child: pw.Text('GO DIGITAL', style: pw.TextStyle(font: fontBold, fontSize: 11)),
                                      ),
                                    ),
                                    pw.Expanded(
                                      flex: 2,
                                      child: pw.Container(
                                        padding: const pw.EdgeInsets.all(8),
                                        decoration: pw.BoxDecoration(
                                          border: pw.Border(right: pw.BorderSide(color: black, width: 1)),
                                        ),
                                        child: pw.Column(
                                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                                          children: [
                                            pw.Text('Quotation No.', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                                            pw.SizedBox(height: 2),
                                            pw.Text(quotationNoController.text, style: pw.TextStyle(font: font, fontSize: 10)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    pw.Expanded(
                                      flex: 2,
                                      child: pw.Container(
                                        padding: const pw.EdgeInsets.all(8),
                                        child: pw.Column(
                                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                                          children: [
                                            pw.Text('Quotation Date', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                                            pw.SizedBox(height: 2),
                                            pw.Text(dateController.text, style: pw.TextStyle(font: font, fontSize: 10)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              pw.Container(
                                padding: const pw.EdgeInsets.all(10),
                                alignment: pw.Alignment.centerLeft,
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text('TO', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                                    pw.SizedBox(height: 2),
                                    // pw.Text(clientNameController.text, style: pw.TextStyle(font: font, fontSize: 10)),
                                    pw.Container(
  padding: const pw.EdgeInsets.only(left: 10),
  child: pw.Text(
    clientNameController.text,
    style: pw.TextStyle(
      font: font,
      fontSize: 10,
    ),
  ),
),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        pw.SizedBox(height: 8),
                        
                        pw.Table(
                          border: pw.TableBorder.all(color: black, width: 1),
                          defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                          columnWidths: {
                            0: const pw.FixedColumnWidth(30),
                            1: const pw.FlexColumnWidth(2),
                            2: const pw.FixedColumnWidth(45),
                            3: const pw.FixedColumnWidth(65),
                            4: const pw.FixedColumnWidth(70),
                          },
                          children: [
                            pw.TableRow(
                              decoration: pw.BoxDecoration(color: grey),
                              children: [
                                tableCell('S.No', bold: true, align: pw.Alignment.center),
                                tableCell('DESCRIPTIONS', bold: true, align: pw.Alignment.center),
                                tableCell('QTY', bold: true, align: pw.Alignment.center),
                                tableCell('RATE', bold: true, align: pw.Alignment.center),
                                tableCell('AMOUNT', bold: true, align: pw.Alignment.center),
                              ],
                            ),

                            for (int i = 0; i < validItems.length; i++)
                              pw.TableRow(children: [
                                tableCell((i + 1).toString(), align: pw.Alignment.center),
                                pw.Container(
                                  padding: const pw.EdgeInsets.all(8),
                                  alignment: pw.Alignment.centerLeft,
                                  child: validItems[i].descriptionCtrl.text.isEmpty 
                                      ? pw.Text('-', style: pw.TextStyle(font: font, fontSize: 10))
                                      : pw.Column(
                                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                                          children: [
                                            pw.Text(
                                              validItems[i].descriptionCtrl.text.split('\n')[0],
                                              style: pw.TextStyle(font: fontBold, fontSize: 10, color: black),
                                            ),
                                            ...validItems[i].descriptionCtrl.text.split('\n').skip(1).map((line) {
                                              return pw.Padding(
                                                padding: const pw.EdgeInsets.only(top: 2),
                                                child: pw.Text(
                                                  line.trim(),
                                                  style: pw.TextStyle(font: font, fontSize: 10, color: black),
                                                ),
                                              );
                                            }).toList(),
                                          ],
                                        ),
                                ),
                                tableCell(
                                  (int.tryParse(validItems[i].qtyCtrl.text) ?? 1).toString(),
                                  align: pw.Alignment.center,
                                ),
                                tableCell(
                                  _parseAmount(validItems[i].rateCtrl.text).toStringAsFixed(0),
                                  align: pw.Alignment.center,
                                ),
                                tableCell(
                                  _rowAmount(validItems[i]).toStringAsFixed(0),
                                  align: pw.Alignment.center,
                                ),
                              ]),

                            

                            
                          ],
                        ),

                        

                        pw.Table(
                          border: pw.TableBorder.all(color: black, width: 1),
                           defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,

                          columnWidths: {
                            0: const pw.FlexColumnWidth(3),
                            1: const pw.FixedColumnWidth(135),
                          },
                          children: [

                            pw.TableRow(children: [
                              pw.Container(
                                padding: const pw.EdgeInsets.all(8),
                                alignment: pw.Alignment.center,
                                child: pw.Text('TOTAL AMOUNT', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                              ),
                              pw.Container(
                                padding: const pw.EdgeInsets.all(8),
                                alignment: pw.Alignment.center,
                                child: pw.Text('₹ ${subtotal.toStringAsFixed(0)} /-', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                              ),
                            ]),


                            
                            if (discount > 0)
                              pw.TableRow(children: [
                                pw.Container(
                                  padding: const pw.EdgeInsets.all(8),
                                  alignment: pw.Alignment.center,
                                  child: pw.Text('DISCOUNT', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                                ),
                                pw.Container(
                                  padding: const pw.EdgeInsets.all(8),
                                  alignment: pw.Alignment.center,
                                  child: pw.Text('₹ ${discount.toStringAsFixed(0)} /-', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                                ),
                              ]),

                            pw.TableRow(children: [
                              pw.Container(
                                padding: const pw.EdgeInsets.all(8),
                                alignment: pw.Alignment.center,
                                child: pw.Text('TAX (18% GST)', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                              ),
                              pw.Container(
                                padding: const pw.EdgeInsets.all(8),
                                alignment: pw.Alignment.center,
                                child: pw.Text('₹ ${tax.toStringAsFixed(0)} /-', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                              ),
                            ]),

                            pw.TableRow(children: [
                              pw.Container(
                                padding: const pw.EdgeInsets.all(8),
                                alignment: pw.Alignment.center,
                                child: pw.Text('GRAND TOTAL', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                              ),
                              pw.Container(
                                padding: const pw.EdgeInsets.all(8),
                                alignment: pw.Alignment.center,
                                child: pw.Text('₹ ${total.toStringAsFixed(0)} /-', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                              ),
                            ]),
                          ],
                        ),
                        
                        pw.SizedBox(height: 12),

                        if (notesController.text.isNotEmpty || expiryController.text.isNotEmpty) ...[
                          pw.Text('Notes', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                          pw.SizedBox(height: 2),
                          
                          pw.Text(
                            'Valid until: ${expiryController.text}',
                            style: pw.TextStyle(font: fontBold, fontSize: 9, color: blue),
                          ),
                          
                          pw.SizedBox(height: 4),
                          
                          if (notesController.text.isNotEmpty)
                            pw.Text(
                              notesController.text,
                              style: pw.TextStyle(font: font, fontSize: 9),
                            ),
                          
                          pw.SizedBox(height: 12),
                        ],

                        pw.Text('Terms & Conditions', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                        pw.SizedBox(height: 2),
                        ...termsController.text.split('\n').map((term) {
                          return pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 2),
                            child: pw.Text(
                              term.trim().isEmpty ? '' : term.trim(),
                              style: pw.TextStyle(font: font, fontSize: 9),
                            ),
                          );
                        }).toList(),

                        pw.Spacer(),

                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.end,
                          children: [
                            pw.SizedBox(width: 10),
                            pw.Container(
                              width: 80,
                              height: 80,
                              child: pw.Image(sealImage, fit: pw.BoxFit.contain),
                            ),
                          ],
                        ),

                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('BANK ACCOUNT DETAILS',
                                      style: pw.TextStyle(
                                        font: fontBold,
                                        fontSize: 15,
                                        decoration: pw.TextDecoration.underline,
                                      )),
                                  pw.SizedBox(height: 3),
                                  pw.Text('NAME: GO DIGITAL | BANK: IDFC FIRST BANK | A/C NO: 10075087276 | BRANCH: KILPAUK | IFSC: IDFB0080121',
                                      style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: blue)),
                                  pw.SizedBox(height: 3),
                                  pw.Text('Office: +91 94449 43094 | Email: godigitalindaras@gmail.com | Website: www.godigital.ind.in',
                                      style: pw.TextStyle(font: font, fontSize: 12),
                                      textAlign: pw.TextAlign.center),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                pw.Container(
                  color: blue,
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: pw.Column(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text('GO DIGITAL', style: pw.TextStyle(font: fontBold, fontSize: 14, color: white)),
                      pw.SizedBox(height: 2),
                      pw.Text('No:14, Udaya Suriyan Nagar, Guduvanchery 603202 Near Olala Cafe',
                          style: pw.TextStyle(font: font, fontSize: 10, color: white),
                          textAlign: pw.TextAlign.center),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      return pdf.save();
    } catch (e) {
      print('Error generating PDF: $e');
      return null; 
    }
  }

  Future<void> _shareQuotationPDF(double subtotal, double discount, double total, double tax, double paid, double balance) async {
    try {
      final pdfBytes = await _generateQuotationPDFBytes(subtotal, discount, total, tax, paid, balance);
      
      if (pdfBytes == null || pdfBytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Could not generate PDF'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/QT_${quotationNoController.text}.pdf');
      await file.writeAsBytes(pdfBytes);

      final result = await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Please find the quotation attached: ${quotationNoController.text}',
        subject: 'Quotation: ${quotationNoController.text}',
      );

      if (result.status == ShareResultStatus.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Quotation shared successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
  
  Future<void> _printQuotation(double subtotal, double discount, double total, double tax, double paid, double balance) async {
    if (expiryController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Please set Expire Date before printing'),
            backgroundColor: Colors.orangeAccent,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    try {
      print('📄 Generating PDF...');
      final pdfBytes = await _generateQuotationPDFBytes(subtotal, discount, total, tax, paid, balance);

      if (pdfBytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Failed to generate PDF - PDF bytes are null'),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 3),
            ),
          );
        }
        print('❌ PDF generation failed: pdfBytes is null');
        return;
      }

      if (pdfBytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Failed to generate PDF - PDF is empty'),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 3),
            ),
          );
        }
        print('❌ PDF generation failed: pdfBytes is empty');
        return;
      }

      print('✅ PDF generated successfully! Size: ${pdfBytes.length} bytes');
      print('🖨️ Opening print dialog...');

      final result = await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          print('📐 PDF format: $format');
          return pdfBytes;
        },
        name: 'Quotation_${quotationNoController.text}',
        format: PdfPageFormat.a4,
      );

      print('✅ Print dialog result: $result');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ PDF Generated Successfully! Click Share to send.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

    } catch (e, stackTrace) {
      print('❌ Print error: $e');
      print('📋 Stack trace: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Print error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showSavedSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 300, maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, color: Color(0xFF16A34A), size: 32),
                ),
                const SizedBox(height: 16),
                const Text("Quotation Saved Successfully",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                const SizedBox(height: 8),
                Text("${quotationNoController.text} has been saved.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamedAndRemoveUntil(context, '/quotation', (route) => false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0052CC),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: const Text("Go to Package & Quotation",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double subtotal = 0;
    double overallPaid = 0;
    for (final row in _items) {
      subtotal += _rowAmount(row);
      overallPaid += _parseAmount(row.paidCtrl.text);
    }

    double discount = _parseAmount(discountController.text);
    double taxableAmount = subtotal - discount;
    if (taxableAmount < 0) taxableAmount = 0;

    double tax = includeGST ? (taxableAmount * 0.18) : 0.00;
    double totalAmount = taxableAmount + tax;

    double balanceAmount = totalAmount - overallPaid;
    if (balanceAmount < 0) balanceAmount = 0;

    if (_loadingExisting) {
      return AdminLayout(
        pageTitle: "Create Quotation",
        currentRoute: "/quotation",
        child: const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: CircularProgressIndicator(color: Color(0xFF0052CC)),
          ),
        ),
      );
    }

    final pageTitle = _viewOnly
        ? "View Quotation"
        : (_quotationId != null ? "Edit Quotation" : "Create Quotation");

    return AdminLayout(
      pageTitle: pageTitle,
      currentRoute: "/quotation",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                pageTitle,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    child: const Text("Discard", style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  const SizedBox(width: 12),
                  if (!_viewOnly)
                    ElevatedButton(
                      onPressed: _isSaving ? null : () async {
                        setState(() => _isSaving = true);
                        final ok = await _saveQuotation(subtotal, discount, tax, totalAmount, overallPaid, balanceAmount);
                        setState(() => _isSaving = false);
                        if (ok && mounted) {
                          _showSavedSuccessDialog();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0052CC),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text("Save Quotation", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(child: _buildInlineFormInput("Quotation No", quotationNoController, readOnly: true, fillColor: const Color(0xFFEFF6FF))),
                const SizedBox(width: 16),
                // ✅ NEW: Client name dropdown with search
                Expanded(
                  child: _buildClientNameDropdown(),
                ),
                const SizedBox(width: 16),
                Expanded(child: _buildDatePickerFormInput("Quotation Date", dateController)),
                const SizedBox(width: 16),
                Expanded(child: _buildDatePickerFormInput("Expire Date", expiryController)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: const Color(0xFFEAEFF8),
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: const [
                      SizedBox(width: 40, child: Text("S.No", style: _tableLabelStyle)),
                      Expanded(flex: 5, child: Text("Description", style: _tableLabelStyle)),
                      SizedBox(width: 70, child: Text("QTY", textAlign: TextAlign.center, style: _tableLabelStyle)),
                      SizedBox(width: 100, child: Text("Rate", textAlign: TextAlign.right, style: _tableHeaderStyleRight)),
                      SizedBox(width: 110, child: Text("Amount", textAlign: TextAlign.right, style: _tableHeaderStyleRight)),
                      SizedBox(width: 30, child: Text("", style: _tableLabelStyle)),
                    ],
                  ),
                ),

                for (int i = 0; i < _items.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    child: Row(
                      children: [
                        SizedBox(width: 40, child: Text((i + 1).toString().padLeft(2, '0'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)))),
                        Expanded(
                          flex: 5,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: _items[i].isPackageRow
                                ? _buildBeautifulPackageDropdown(_items[i])
                                : _buildDescriptionField(_items[i]),
                          ),
                        ),
                        SizedBox(
                          width: 70,
                          child: _buildInnerNumInput(
                            _items[i].qtyCtrl,
                            textAlign: TextAlign.center,
                            readOnly: _viewOnly,
                            onChanged: () => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 100,
                          child: _items[i].isPackageRow
                              ? _buildReadOnlyRateField(_items[i].rateCtrl)
                              : _buildInnerNumInput(_items[i].rateCtrl, textAlign: TextAlign.right, readOnly: _viewOnly, onChanged: () => setState(() {})),
                        ),
                        SizedBox(
                          width: 110,
                          child: Text(
                            "₹${_rowAmount(_items[i]).toStringAsFixed(2)}",
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                        ),
                        SizedBox(
                          width: 30,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _viewOnly
                                ? const SizedBox.shrink()
                                : GestureDetector(
                                    onTap: () => _removeRow(i),
                                    child: Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: _items.length > 1 ? const Color(0xFFDC2626) : Colors.grey.shade300,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < _items.length - 1)
                    const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (!_viewOnly)
            GestureDetector(
              onTap: _addSection,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.add_circle_outline_rounded, size: 16, color: Color(0xFF0052CC)),
                  SizedBox(width: 6),
                  Text("Add Section", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0052CC))),
                ],
              ),
            ),
          const SizedBox(height: 24),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Notes", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                            const SizedBox(height: 8),
                            
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F5FF),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Valid until: ${expiryController.text}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0052CC),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 8),
                            
                            TextField(
                              controller: notesController,
                              maxLines: 3,
                              readOnly: _viewOnly,
                              decoration: InputDecoration(
                                hintText: "Add extra notes or comments...",
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF0052CC))),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Terms & Conditions", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                            const SizedBox(height: 8),
                            TextField(
                              controller: termsController,
                              maxLines: 4,
                              readOnly: _viewOnly,
                              decoration: InputDecoration(
                                hintText: "Edit terms & conditions...",
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF0052CC))),
                              ),
                              style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: agreedToTerms,
                                    onChanged: _viewOnly ? null : (val) => setState(() => agreedToTerms = val!),
                                    activeColor: const Color(0xFF0052CC),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text("Agree to defined terms", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                              ],
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),

              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryLineItem("Subtotal", "₹${subtotal.toStringAsFixed(2)}"),
                      const SizedBox(height: 14),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Discount", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                          SizedBox(
                            width: 100,
                            height: 36,
                            child: TextField(
                              controller: discountController,
                              textAlign: TextAlign.right,
                              readOnly: _viewOnly,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                              onChanged: (value) => setState(() {}),
                              decoration: const InputDecoration(
                                prefixText: "₹ ",
                                prefixStyle: TextStyle(color: Color(0xFF475569), fontSize: 15),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10),
                                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF0052CC))),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Include 18% GST", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                          Switch(
                            value: includeGST,
                            activeTrackColor: const Color(0xFF0052CC),
                            onChanged: _viewOnly ? null : (bool value) {
                              setState(() {
                                includeGST = value;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      _buildSummaryLineItem(
                        "Tax (18% GST)",
                        "₹${tax.toStringAsFixed(2)}",
                        textColor: includeGST ? const Color(0xFF0F172A) : Colors.grey,
                      ),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider(color: Color(0xFFF1F5F9), height: 1)),
                      
                      _buildSummaryLineItem("Total Amount", "₹${totalAmount.toStringAsFixed(2)}", isBold: true, textColor: const Color(0xFF0052CC)),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isPrinting ? null : () async {
                            setState(() => _isPrinting = true);

                            if (_viewOnly) {
                              await _printQuotation(subtotal, discount, totalAmount, tax, overallPaid, balanceAmount);
                              if (!mounted) return;
                              setState(() => _isPrinting = false);
                              return;
                            }

                            final saved = await _saveQuotation(subtotal, discount, tax, totalAmount, overallPaid, balanceAmount);
                            await _printQuotation(subtotal, discount, totalAmount, tax, overallPaid, balanceAmount);

                            if (!mounted) return;
                            setState(() => _isPrinting = false);

                            if (saved) {
                              _showSavedSuccessDialog();
                            }
                          },
                          icon: _isPrinting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.print, size: 16, color: Colors.white),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0052CC),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                          ),
                          label: Text(_viewOnly ? "Print Quotation" : "Save & Print Quotation",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),

                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isPrinting ? null : () => _shareQuotationPDF(subtotal, discount, totalAmount, tax, overallPaid, balanceAmount),
                          icon: const Icon(Icons.share, size: 16, color: Color(0xFF0052CC)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF0052CC), width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          label: const Text("Share as PDF",
                              style: TextStyle(color: Color(0xFF0052CC), fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),

                      const SizedBox(height: 12),
                      const Text(
                        "A PDF copy will be generated and sent\nto the client.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.4, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ✅ NEW: Client name dropdown widget with search
Widget _buildClientNameDropdown() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text("Client Name", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
      const SizedBox(height: 6),
     SizedBox(
  height: 50,   // 38 -> 50
  child: TextField(
    controller: clientNameController,
    inputFormatters: [UpperCaseTextFormatter()],
    readOnly: _quotationId != null,
    onChanged: (value) => _onClientSearchChanged(value),
    style: const TextStyle(
      fontSize: 14,
      height: 1.3,
      color: Colors.black,
    ),
    textAlignVertical: TextAlignVertical.center, // ✅ Center the text
    decoration: InputDecoration(
      hintText: "Search client...",
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 14,
      ),
      suffixIcon: _isSearching
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : const Icon(Icons.arrow_drop_down),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
      ),
    ),
  ),
), // Dropdown List
      if (_showClientDropdown && _clients.isNotEmpty)
        Container(
          height: 150,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
          child: ListView.builder(
            itemCount: _clients.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(_clients[index]['company_name'] ?? ''),
                onTap: () {
                  _selectClient(_clients[index]);
                },
              );
            },
          ),
        ),
    ],
  );
}

  Widget _buildBeautifulPackageDropdown(_QuotationItemRow row) {
    if (_viewOnly) {
      return _buildPackageDisplayCard(row);
    }

    final validValue = _packages.any((p) => p['id'] == row.packageId) ? row.packageId : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: _loadingPackages
              ? const Row(children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0052CC))),
                  SizedBox(width: 10),
                  Text("Loading packages...", style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                ])
              : DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: validValue,
                    isExpanded: true,
                    hint: const Text("Select Package", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                    items: _packages.map((pkg) {
                      return DropdownMenuItem<int>(
                        value: pkg['id'] as int,
                        child: Text(pkg['title'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) _onPackageSelected(row, val);
                    },
                  ),
                ),
        ),
        if (row.packageId != null && row.descriptionCtrl.text.contains('\n'))
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _buildPackageFeatureCard(row),
          ),
      ],
    );
  }

  Widget _buildPackageFeatureCard(_QuotationItemRow row) {
    final parts = row.descriptionCtrl.text.split('\n');
    final title = parts[0];
    final features = parts.skip(1).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0052CC),
            ),
          ),
          const SizedBox(height: 12),
          ...features.map((feature) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '✓ ',
                    style: TextStyle(
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      feature.replaceFirst('• ', ''),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildPackageDisplayCard(_QuotationItemRow row) {
    final parts = row.descriptionCtrl.text.split('\n');
    final title = parts[0];
    final features = parts.skip(1).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0052CC),
            ),
          ),
          const SizedBox(height: 12),
          ...features.map((feature) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '✓ ',
                    style: TextStyle(
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      feature.replaceFirst('• ', ''),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDatePickerFormInput(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
        const SizedBox(height: 6),
        SizedBox(
          height: 38,
          child: TextField(
            controller: controller,
            readOnly: true,
            onTap: _viewOnly ? null : () => _selectCalendarDate(context, controller),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              suffixIcon: const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF0052CC))),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInlineFormInput(String label, TextEditingController controller, {bool readOnly = false, Color? fillColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
        const SizedBox(height: 6),
        SizedBox(
          height: 38,
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              filled: fillColor != null,
              fillColor: fillColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF0052CC))),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionField(_QuotationItemRow row) {
    return SizedBox(
      height: 38,
      child: TextField(
        controller: row.descriptionCtrl,
        readOnly: _viewOnly,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
        decoration: InputDecoration(
          hintText: "Enter description",
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.w400),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF0052CC))),
        ),
      ),
    );
  }

  Widget _buildReadOnlyRateField(TextEditingController controller) {
    return SizedBox(
      height: 38,
      child: TextField(
        controller: controller,
        textAlign: TextAlign.right,
        readOnly: true,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF0052CC))),
        ),
      ),
    );
  }

  Widget _buildInnerNumInput(TextEditingController controller, {required TextAlign textAlign, bool readOnly = false, VoidCallback? onChanged}) {
    return SizedBox(
      height: 38,
      child: TextField(
        controller: controller,
        textAlign: textAlign,
        readOnly: readOnly,
        keyboardType: TextInputType.number,
        onChanged: (_) => onChanged?.call(),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF0052CC))),
        ),
      ),
    );
  }

  Widget _buildSummaryLineItem(String label, String value, {bool isBold = false, Color? textColor}) {
    final style = TextStyle(
      fontSize: isBold ? 15 : 14,
      fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
      color: textColor ?? (isBold ? const Color(0xFF0F172A) : const Color(0xFF475569)),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }

  static const TextStyle _tableLabelStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569));
  static const TextStyle _tableHeaderStyleRight = TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569));
}

// ✅ NEW: Custom TextInputFormatter to convert text to uppercase
