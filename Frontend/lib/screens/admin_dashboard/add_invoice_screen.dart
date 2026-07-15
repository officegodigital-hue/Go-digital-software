import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../layouts/admin_layout.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';

import 'dart:async';

class _InvoiceItemRow {
  int? packageId;
  bool isPackageRow;
  final TextEditingController descriptionCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController rateCtrl;
  final TextEditingController paidCtrl;

  _InvoiceItemRow({
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

class AddInvoiceScreen extends StatefulWidget {
  final int? invoiceId;
  final bool viewOnly;

  const AddInvoiceScreen({super.key, this.invoiceId, this.viewOnly = false});

  @override
  State<AddInvoiceScreen> createState() => _AddInvoiceScreenState();
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
    );
  }
}

class _AddInvoiceScreenState extends State<AddInvoiceScreen> {
  static const String _baseUrl = '/api';

  final invoiceNoController = TextEditingController(text: "Loading...");
  final dateController = TextEditingController();
  final maintenanceDateController = TextEditingController();
  final clientNameController = TextEditingController(text: "");
  final discountController = TextEditingController(text: "0.00");
  final notesController = TextEditingController();
  
  final termsController = TextEditingController(
    text: '• Project development only\n• 50% advance required\n• No refund after approval',
  );

  bool agreedToTerms = false;
  bool includeGST = true;
  bool _isSaving = false;
  bool _isPrinting = false;

  int? _invoiceId;
  bool _viewOnly = false;
  bool _loadingExisting = false;
  bool _argsProcessed = false;

  List<Map<String, dynamic>> _packages = [];
  bool _loadingPackages = true;

  List<Map<String, dynamic>> _clientsList = [];
bool _showClientDropdown = false;
String _clientSearchQuery = '';
bool _loadingClients = false;

  // ✅ Calculate total pending amount across all items
  double _calculateTotalPending() {
    double totalPending = 0;
    for (final row in _items) {
      totalPending += _rowPending(row);
    }
    return totalPending;
  }

  late List<_InvoiceItemRow> _items;

Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _items = [_InvoiceItemRow(isPackageRow: true)];
    final now = DateTime.now();
    dateController.text = DateFormat('dd/MM/yyyy').format(now);
    maintenanceDateController.text = DateFormat('dd/MM/yyyy').format(now.add(const Duration(days: 30)));
    _fetchPackages();

    _invoiceId = widget.invoiceId;
    _viewOnly = widget.viewOnly;
    if (_invoiceId != null) {
      _loadExistingInvoice(_invoiceId!);
    } else {
      _fetchNextInvoiceNumber();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsProcessed) return;
    _argsProcessed = true;

    if (widget.invoiceId == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        final id = args['invoiceId'];
        final view = args['viewOnly'] == true;
        if (id is int) {
          setState(() {
            _invoiceId = id;
            _viewOnly = view;
          });
          _loadExistingInvoice(id);
        }
      }
    }
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    invoiceNoController.dispose();
    dateController.dispose();
    maintenanceDateController.dispose();
    clientNameController.dispose();
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

  Future<void> _fetchNextInvoiceNumber() async {
  try {
    final response = await http.get(
      Uri.parse('$_baseUrl/invoices/next-number'),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);

      setState(() {
        invoiceNoController.text = body['data']['invoiceNo'];
      });
    } else {
      _setDefaultInvoiceNumber();
    }
  } catch (e) {
    _setDefaultInvoiceNumber();
  }
}

void _setDefaultInvoiceNumber() {
  final now = DateTime.now();

  final yyyy = now.year.toString();
  final mm = now.month.toString().padLeft(2, '0');
  final dd = now.day.toString().padLeft(2, '0');

  setState(() {
    invoiceNoController.text = 'INV-$yyyy$mm${dd}301';
  });
}

  Future<void> _loadExistingInvoice(int id) async {
    setState(() => _loadingExisting = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/invoices/$id'));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'];

        for (final item in _items) {
          item.dispose();
        }

        final List<_InvoiceItemRow> loadedItems = [];
        for (final it in (data['items'] as List)) {
          loadedItems.add(_InvoiceItemRow(
            isPackageRow: it['package_id'] != null,
            packageId: it['package_id'],
            description: it['description'] ?? '',
            qty: (it['qty'] ?? 1).toString(),
            rate: double.tryParse(it['rate'].toString())?.toStringAsFixed(2) ?? '0.00',
            paid: double.tryParse(it['paid_amount'].toString())?.toStringAsFixed(2) ?? '0.00',
          ));
        }

        setState(() {
          invoiceNoController.text = data['invoice_no'] ?? '';
          clientNameController.text = data['client_name'] ?? '';
          dateController.text = data['invoice_date'] ?? '';
          maintenanceDateController.text = data['maintenance_date'] ?? '';
          discountController.text = double.tryParse(data['discount'].toString())?.toStringAsFixed(2) ?? '0.00';
          notesController.text = data['notes'] ?? '';
          termsController.text = data['terms'] ?? termsController.text;
          includeGST = data['include_gst'] == 1 || data['include_gst'] == true;
          _items = loadedItems.isNotEmpty ? loadedItems : [_InvoiceItemRow(isPackageRow: true)];
          _loadingExisting = false;
        });
      } else {
        setState(() => _loadingExisting = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to load invoice'),
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

  double _parseAmount(String text) => double.tryParse(text.replaceAll(',', '')) ?? 0.0;

  String _extractRateFromPrice(String price) {
    final digits = price.replaceAll(RegExp(r'[^0-9.]'), '');
    final value = double.tryParse(digits) ?? 0.0;
    return value.toStringAsFixed(2);
  }

  void _onPackageSelected(_InvoiceItemRow row, int packageId) {
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
      _items.add(_InvoiceItemRow(isPackageRow: false));
    });
  }

  void _removeRow(int index) {
    if (_items.length <= 1) return;
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  double _rowAmount(_InvoiceItemRow row) {
    final qty = int.tryParse(row.qtyCtrl.text) ?? 1;
    final rate = _parseAmount(row.rateCtrl.text);
    return qty * rate;
  }

  double _rowPending(_InvoiceItemRow row) {
    final amount = _rowAmount(row);
    final paid = _parseAmount(row.paidCtrl.text);
    final pending = amount - paid;
    return pending < 0 ? 0 : pending;
  }

  Future<bool> _saveInvoice(double subtotal, double discount, double tax, double total, double paid, double balance) async {
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
      "invoiceNo": invoiceNoController.text,
      "clientName": clientNameController.text,
      "invoiceDate": dateController.text,
      "maintenanceDate": maintenanceDateController.text,
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
      final isEdit = _invoiceId != null;
      final response = isEdit
          ? await http.put(
              Uri.parse('$_baseUrl/invoices/$_invoiceId'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
          : await http.post(
              Uri.parse('$_baseUrl/invoices'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        final body = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(body['message'] ?? 'Failed to save invoice'),
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
                const Text("Invoice Saved Successfully",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                const SizedBox(height: 8),
                Text("${invoiceNoController.text} has been saved.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamedAndRemoveUntil(context, '/invoice', (route) => false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0052CC),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: const Text("Go to Invoices",
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

void _onClientSearchChanged(String value) {
  if (_debounce?.isActive ?? false) _debounce!.cancel();

  _debounce = Timer(const Duration(milliseconds: 500), () {
    if (mounted) _searchClients(value);
  });

  setState(() {
    _showClientDropdown = true;
  });
}

Future<void> _searchClients(String query) async {
  if (query.isEmpty) {
    setState(() {
      _clientsList = [];
      _showClientDropdown = false;
    });
    return;
  }

  setState(() => _loadingClients = true);
  try {
    final response = await http.get(
      Uri.parse('$_baseUrl/clients/search/query?query=${Uri.encodeComponent(query)}'),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      setState(() {
        _clientsList = List<Map<String, dynamic>>.from(body['data'] ?? []);
        _showClientDropdown = _clientsList.isNotEmpty;
        _loadingClients = false;
      });
    } else {
      setState(() => _loadingClients = false);
    }
  } catch (e) {
    setState(() => _loadingClients = false);
  }
}

// ✅ ADD THIS METHOD (When user selects a client from dropdown)
void _selectClientFromDropdown(Map<String, dynamic> client) {
  setState(() {
    clientNameController.text = (client['company_name'] ?? '').toUpperCase();
    _showClientDropdown = false;
    _clientsList = [];
    _clientSearchQuery = '';
  });
}


  // ✅ FULLY CORRECTED: Professional PDF print with all fixes
  Future<void> _printInvoice(double subtotal, double discount, double tax, double total, double paid, double balance) async {
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

      const PdfColor blue = PdfColor.fromInt(0xFF0052CC);
      const PdfColor white = PdfColor.fromInt(0xFFFFFFFF);
      const PdfColor grey = PdfColor.fromInt(0xFFF0F0F0);
      const PdfColor black = PdfColor.fromInt(0xFF000000);

      final validItems = _items.where((item) {
        final desc = item.descriptionCtrl.text.trim();
        final qty = item.qtyCtrl.text.trim();
        return desc.isNotEmpty && qty.isNotEmpty;
      }).toList();

      if (validItems.isEmpty) {
        return;
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
                                            pw.Text('Invoice No.', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                                            pw.SizedBox(height: 2),
                                            pw.Text(invoiceNoController.text, style: pw.TextStyle(font: font, fontSize: 10)),
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
                                            pw.Text('Invoice Date', style: pw.TextStyle(font: fontBold, fontSize: 9)),
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
                        
                        // ✅ Items table with CENTERED QTY, RATE, AMOUNT
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
                                tableCell('QTY', bold: true, align: pw.Alignment.center, ), // ✅ CENTERED
                                tableCell('RATE', bold: true, align: pw.Alignment.center), // ✅ CENTERED
                                tableCell('AMOUNT', bold: true, align: pw.Alignment.center), // ✅ CENTERED
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
                                
                                // ✅ CENTERED QTY
                                tableCell(
                                  (int.tryParse(validItems[i].qtyCtrl.text) ?? 1).toString(),
                                  align: pw.Alignment.center,
                                ),
                                
                                // ✅ CENTERED RATE
                                tableCell(
                                  _parseAmount(validItems[i].rateCtrl.text).toStringAsFixed(0),
                                  align: pw.Alignment.center,
                                ),
                                
                                // ✅ CENTERED AMOUNT
                                tableCell(
                                  _rowAmount(validItems[i]).toStringAsFixed(0),
                                  align: pw.Alignment.center,
                                ),
                              ]),
                          ],
                        ),

                        // ✅ Summary table with CONDITIONAL DISCOUNT & TAX
                        pw.Table(
                          border: pw.TableBorder.all(color: black, width: 1),
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

                            // ✅ FIX #3: Only show DISCOUNT if discount > 0
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

                            // ✅ FIX #4: Only show TAX if tax > 0
                            if (total > 0)
                              pw.TableRow(children: [
                                pw.Container(
                                  padding: const pw.EdgeInsets.all(8),
                                  alignment: pw.Alignment.center,
                                  child: pw.Text('TAX (18% GST)', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                                ),
                                pw.Container(
                                  padding: const pw.EdgeInsets.all(8),
                                  alignment: pw.Alignment.center,
                                  child: pw.Text('₹ ${total.toStringAsFixed(0)} /-', style: pw.TextStyle(font: fontBold, fontSize: 12)),
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
                                child: pw.Text('₹ ${tax.toStringAsFixed(0)} /-', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                              ),
                            ]),

                            pw.TableRow(children: [
                              pw.Container(
                                padding: const pw.EdgeInsets.all(8),
                                alignment: pw.Alignment.center,
                                child: pw.Text('PAID AMOUNT', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                              ),
                              pw.Container(
                                padding: const pw.EdgeInsets.all(8),
                                alignment: pw.Alignment.center,
                                child: pw.Text('₹ ${paid.toStringAsFixed(0)} /-', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                              ),
                            ]),

                            pw.TableRow(children: [
                              pw.Container(
                                padding: const pw.EdgeInsets.all(8),
                                alignment: pw.Alignment.center,
                                child: pw.Text('BALANCE TO BE PAID', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                              ),
                              pw.Container(
                                padding: const pw.EdgeInsets.all(8),
                                alignment: pw.Alignment.center,
                                child: pw.Text('₹ ${balance.toStringAsFixed(0)} /-', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                              ),
                            ]),
                          ],
                        ),
                        
                        pw.SizedBox(height: 12),

                        // Notes section
                        if (notesController.text.isNotEmpty) ...[
                          pw.Text('Notes', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            notesController.text,
                            style: pw.TextStyle(font: font, fontSize: 9),
                          ),
                          pw.SizedBox(height: 12),
                        ],

                        // ✅ FIX #5: Only show Terms & Conditions if agreedToTerms is TRUE
                        if (agreedToTerms) ...[
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
                          pw.SizedBox(height: 12),
                        ],

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

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Invoice_${invoiceNoController.text}',
        format: PdfPageFormat.a4,
      );
    } catch (e) {
      print('Error generating PDF: $e');
    }
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
        pageTitle: "Add Invoice",
        currentRoute: "/invoice",
        child: const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: CircularProgressIndicator(color: Color(0xFF0052CC)),
          ),
        ),
      );
    }

    final pageTitle = _viewOnly
        ? "View Invoice"
        : (_invoiceId != null ? "Edit Invoice" : "Add Invoice");

    return AdminLayout(
      pageTitle: pageTitle,
      currentRoute: "/invoice",
      child: SingleChildScrollView(
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
                          final ok = await _saveInvoice(subtotal, discount, tax, totalAmount, overallPaid, balanceAmount);
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
                            : const Text("Save Invoice", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
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
                  Expanded(child: _buildInlineFormInput("Invoice No", invoiceNoController, readOnly: true, fillColor: const Color(0xFFEFF6FF))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildDatePickerFormInput("Date", dateController)),
                  const SizedBox(width: 16),
                  // ✅ FIX #1: Client name read-only when editing invoice
                  // Expanded(
                  //   child: _buildInlineFormInput(
                  //     "Client Name",
                  //     clientNameController,
                  //     readOnly: _viewOnly || _invoiceId != null, // ✅ Read-only when editing
                  //   ),
                  // ),
                  Expanded(
  child: _buildClientNameFieldWithDropdown(),
),
                  const SizedBox(width: 16),
                  Expanded(child: _buildDatePickerFormInput("Maintenance Date", maintenanceDateController)),
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
                        SizedBox(width: 60, child: Text("QTY", textAlign: TextAlign.center, style: _tableLabelStyle)),
                        SizedBox(width: 90, child: Text("Rate", textAlign: TextAlign.right, style: _tableHeaderStyleRight)),
                        SizedBox(width: 100, child: Text("Amount", textAlign: TextAlign.right, style: _tableHeaderStyleRight)),
                        SizedBox(width: 110, child: Text("Paid Amount", textAlign: TextAlign.right, style: _tableHeaderStyleRight)),
                        SizedBox(width: 120, child: Text("Pending Amount", textAlign: TextAlign.right, style: _tableHeaderStyleRight)),
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
                            width: 60,
                            child: _buildInnerNumInput(
                              _items[i].qtyCtrl,
                              textAlign: TextAlign.center,
                              readOnly: _viewOnly,
                              onChanged: () => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 90,
                            child: _items[i].isPackageRow
                                ? _buildReadOnlyRateField(_items[i].rateCtrl)
                                : _buildInnerNumInput(_items[i].rateCtrl, textAlign: TextAlign.right, readOnly: _viewOnly, onChanged: () => setState(() {})),
                          ),
                          SizedBox(
                            width: 100,
                            child: Text(
                              "₹${_rowAmount(_items[i]).toStringAsFixed(2)}",
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            ),
                          ),
                          SizedBox(
                            width: 110,
                            child: _buildPaidAmountField(_items[i]),
                          ),
                          SizedBox(
                            width: 120,
                            child: Text(
                              "₹${_rowPending(_items[i]).toStringAsFixed(2)}",
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0052CC),
                              ),
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
                              TextField(
                                controller: notesController,
                                maxLines: 3,
                                readOnly: _viewOnly,
                                decoration: InputDecoration(
                                  hintText: "Add internal notes...",
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
         
                        _buildSummaryLineItem(
                          "Total Paid",
                          "₹${overallPaid.toStringAsFixed(2)}",
                          textColor: const Color(0xFF16A34A),
                        ),
                        const SizedBox(height: 14),
         
                        _buildSummaryLineItem(
                          "Total Pending",
                          "₹${_calculateTotalPending().toStringAsFixed(2)}",
                          textColor: const Color(0xFFFB923C),
                        ),
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
                        
                        const SizedBox(height: 12),
                        _buildSummaryLineItem(
                          "Balance to be Paid",
                          "₹${balanceAmount.toStringAsFixed(2)}",
                          isBold: true,
                          textColor: balanceAmount > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                        ),
                        
                        const SizedBox(height: 24),
         
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isPrinting ? null : () async {
                              setState(() => _isPrinting = true);
         
                              if (_viewOnly) {
                                await _printInvoice(subtotal, discount, totalAmount, tax, overallPaid, balanceAmount);
                                if (!mounted) return;
                                setState(() => _isPrinting = false);
                                return;
                              }
         
                              final saved = await _saveInvoice(subtotal, discount, tax, totalAmount, overallPaid, balanceAmount);
                              await _printInvoice(subtotal, discount, totalAmount, tax, overallPaid, balanceAmount);
         
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
                            label: Text(_viewOnly ? "Print Invoice" : "Save & Print Invoice",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
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
      ),
    );
  }

  Widget _buildPaidAmountField(_InvoiceItemRow row) {
    return SizedBox(
      height: 38,
      child: TextField(
        controller: row.paidCtrl,
        textAlign: TextAlign.right,
        readOnly: _viewOnly,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (value) {
          final rowAmount = _rowAmount(row);
          final paidAmount = _parseAmount(value);
          
          if (paidAmount > rowAmount) {
            row.paidCtrl.text = rowAmount.toStringAsFixed(2);
          }
          setState(() {});
        },
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF334155),
        ),
        decoration: InputDecoration(
          prefixText: "₹ ",
          prefixStyle: const TextStyle(color: Color(0xFF475569), fontSize: 12),
          hintText: "0.00",
          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFF0052CC)),
          ),
        ),
      ),
    );
  }
  
  Widget _buildBeautifulPackageDropdown(_InvoiceItemRow row) {
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

  Widget _buildPackageFeatureCard(_InvoiceItemRow row) {
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

  Widget _buildPackageDisplayCard(_InvoiceItemRow row) {
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

 
Widget _buildClientNameFieldWithDropdown() {
  if (_viewOnly || _invoiceId != null) {
    return _buildInlineFormInput(
      "Client Name",
      clientNameController,
      readOnly: true,
      fillColor: const Color(0xFFEFF6FF),
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        "Client Name",
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF475569),
        ),
      ),
      const SizedBox(height: 6),
      Stack(
        clipBehavior: Clip.none, 
        children: [
          SizedBox(
            height: 38,
            child: TextField(
              controller: clientNameController,
              inputFormatters: [UpperCaseTextFormatter()],
              onChanged: _onClientSearchChanged,
              decoration: InputDecoration(
                hintText: "SEARCH CLIENT...",
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                suffixIcon: _loadingClients
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ),

          if (_showClientDropdown && _clientsList.isNotEmpty)
            Positioned(
              top: 40, 
              left: 0,
              right: 0,
              child: Material(
                elevation: 4, 
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _clientsList.length,
                    itemBuilder: (context, index) {
                      final client = _clientsList[index];
                      return ListTile(
                        title: Text(
                          (client['company_name'] ?? '').toUpperCase(),
                          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                        ),
                        onTap: () => _selectClientFromDropdown(client),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    ],
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

  Widget _buildDescriptionField(_InvoiceItemRow row) {
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