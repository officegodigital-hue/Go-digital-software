import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../layouts/admin_layout.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import '../../services/api_config.dart';
import 'dart:async';

class _InvoiceItemRow {
  int? packageId;
  bool isPackageRow;
  final TextEditingController descriptionCtrl;
  final TextEditingController rateCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController taxCtrl;
  final TextEditingController discountCtrl;
  final TextEditingController paidCtrl;

  _InvoiceItemRow({
    this.packageId,
    required this.isPackageRow,
    String description = '',
    String rate = '0.00',
    String qty = '1',
    String tax = '18.00',
    String discount = '0.00',
    String paid = '0.00',
  })  : descriptionCtrl = TextEditingController(text: description),
        rateCtrl = TextEditingController(text: rate),
        qtyCtrl = TextEditingController(text: qty),
        taxCtrl = TextEditingController(text: tax),
        discountCtrl = TextEditingController(text: discount),
        paidCtrl = TextEditingController(text: paid);

  void dispose() {
    descriptionCtrl.dispose();
    rateCtrl.dispose();
    qtyCtrl.dispose();
    taxCtrl.dispose();
    discountCtrl.dispose();
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
  static String get _baseUrl => ApiConfig.baseUrl;

  final invoiceNoController = TextEditingController(text: "Loading...");
  final dateController = TextEditingController();
  final maintenanceDateController = TextEditingController();
  final clientNameController = TextEditingController(text: "");
  final discountController = TextEditingController(text: "0.00");
  final notesController = TextEditingController();

  final LayerLink _clientLayer = LayerLink();
  final LayerLink _clientLayerLink = LayerLink();
OverlayEntry? _clientOverlay;

  
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

  bool _isSelectingClient = false;

  List<Map<String, dynamic>> _clients = [];
  bool _showClientDropdown = false;
  bool _loadingClients = false;
  Timer? _debounce;

  // Partial Payment History List
  List<Map<String, dynamic>> _paymentHistory = [];

  late List<_InvoiceItemRow> _items;


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
     _clientOverlay?.remove();
  _clientOverlay = null;
    super.dispose();
  }

  void _showClientOverlay() {
  _clientOverlay?.remove();

  _clientOverlay = OverlayEntry(
    builder: (context) => Positioned(
      width: 320, // TextField width
      child: CompositedTransformFollower(
        link: _clientLayerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 52),
        child: Material(
          elevation: 12,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Color(0xFFE2E8F0)),
            ),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _clients.length,
              itemBuilder: (context, index) {
                final client = _clients[index];

                return ListTile(
                  title: Text(client['company_name'] ?? ''),
                  onTap: () {
                    _selectClient(client);
                    _hideClientOverlay();
                  },
                );
              },
            ),
          ),
        ),
      ),
    ),
  );

  Overlay.of(context).insert(_clientOverlay!);
}

void _hideClientOverlay() {
  _clientOverlay?.remove();
  _clientOverlay = null;
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
      final response = await http.get(Uri.parse('$_baseUrl/invoices/next-number'));
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
            rate: double.tryParse(it['rate'].toString())?.toStringAsFixed(2) ?? '0.00',
            qty: (it['qty'] ?? 1).toString(),
            // tax: double.tryParse(it['tax']?.toString() ?? '18.00')?.toStringAsFixed(2) ?? '18.00',
            tax: double.tryParse(
  it['tax_percent']?.toString() ?? '0.00'
)?.toStringAsFixed(2) ?? '0.00',
            // discount: double.tryParse(it['discount']?.toString() ?? '0.00')?.toStringAsFixed(2) ?? '0.00',
            discount: double.tryParse(
  it['discount_amount']?.toString() ?? '0.00'
)?.toStringAsFixed(2) ?? '0.00',
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
          _paymentHistory = List<Map<String, dynamic>>.from(data['payments'] ?? []);
          _loadingExisting = false;
        });
      } else {
        setState(() => _loadingExisting = false);
      }
    } catch (e) {
      setState(() => _loadingExisting = false);
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

  // Calculation per row considering Rate, Qty, Tax %, Discount %
  // double _rowAmount(_InvoiceItemRow row) {
  //   final rate = _parseAmount(row.rateCtrl.text);
  //   final qty = int.tryParse(row.qtyCtrl.text) ?? 1;
  //   final taxPct = _parseAmount(row.taxCtrl.text);
  //   final discPct = _parseAmount(row.discountCtrl.text);

  //   double base = rate * qty;
  //   double discAmt = base * (discPct / 100);
  //   double taxable = base - discAmt;
  //   double taxAmt = taxable * (taxPct / 100);
  //   return taxable + taxAmt;
  // }

  double _rowAmount(_InvoiceItemRow row) {
  final rate = _parseAmount(row.rateCtrl.text);
  final qty = int.tryParse(row.qtyCtrl.text) ?? 1;
  final taxPct = _parseAmount(row.taxCtrl.text);

  // Discount is Amount (₹), NOT %
  final discountAmt = _parseAmount(row.discountCtrl.text);

  final base = rate * qty;
  final taxAmt = base * (taxPct / 100);

  double amount = base + taxAmt - discountAmt;

  if (amount < 0) amount = 0;

  return amount;
}

  double _rowPending(_InvoiceItemRow row) {
    final amount = _rowAmount(row);
    final paid = _parseAmount(row.paidCtrl.text);
    final pending = amount - paid;
    return pending < 0 ? 0 : pending;
  }

  double _calculateTotalPending() {
    double totalPending = 0;
    for (final row in _items) {
      totalPending += _rowPending(row);
    }
    return totalPending;
  }

  Future<bool> _saveInvoice(double subtotal, double discount, double tax, double total, double paid, double balance) async {
    final items = _items.map((row) => {
      "packageId": row.packageId,
      "description": row.descriptionCtrl.text.trim(),
      "qty": int.tryParse(row.qtyCtrl.text) ?? 1,
      "rate": _parseAmount(row.rateCtrl.text),
      "tax": _parseAmount(row.taxCtrl.text),
      "discount": _parseAmount(row.discountCtrl.text),
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
    );

    if (pickedDate != null) {
      setState(() {
        controller.text = DateFormat('dd/MM/yyyy').format(pickedDate);
      });
    }
  }

 void _onClientSearchChanged(String value) {
  if (_isSelectingClient) return;

  if (_debounce?.isActive ?? false) _debounce!.cancel();

  _debounce = Timer(const Duration(milliseconds: 500), () {
    if (mounted) {
      _searchClients(value);
    }
  });

  setState(() {
    _showClientDropdown = true;
  });
}

  Future<void> _searchClients(String query) async {
    if (query.isEmpty) {
      setState(() {
  _clients = [];
});

_hideClientOverlay();
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
  _clients = List<Map<String, dynamic>>.from(body['data'] ?? []);
  _loadingClients = false;
});

if (_clients.isNotEmpty) {
  _showClientOverlay();
} else {
  _hideClientOverlay();
}
      } else {
        setState(() => _loadingClients = false);
      }
    } catch (e) {
      setState(() => _loadingClients = false);
    }
  }

void _selectClient(Map<String, dynamic> client) {
  clientNameController.text =
      (client['company_name'] ?? '').toUpperCase();

  _hideClientOverlay();
}

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
                                tableCell('QTY', bold: true, align: pw.Alignment.center, ), 
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
                                            }),
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

                            if (tax > 0)
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

                            if (balance > 0)
  pw.TableRow(children: [
    pw.Container(
      padding: const pw.EdgeInsets.all(8),
      alignment: pw.Alignment.center,
      child: pw.Text(
        'BALANCE TO BE PAID',
        style: pw.TextStyle(
          font: fontBold,
          fontSize: 12,
        ),
      ),
    ),
    pw.Container(
      padding: const pw.EdgeInsets.all(8),
      alignment: pw.Alignment.center,
      child: pw.Text(
        '₹ ${balance.toStringAsFixed(0)} /-',
        style: pw.TextStyle(
          font: fontBold,
          fontSize: 12,
        ),
      ),
    ),
  ]),
                          ],
                        ),
                        
                        pw.SizedBox(height: 12),

                        if (notesController.text.isNotEmpty) ...[
                          pw.Text('Notes', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            notesController.text,
                            style: pw.TextStyle(font: font, fontSize: 9),
                          ),
                          pw.SizedBox(height: 12),
                        ],

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
                          }),
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
double calculatedItemDiscounts = 0;
double calculatedItemTaxes = 0;

for (final row in _items) {
  final double rate = _parseAmount(row.rateCtrl.text);
  final double qty = double.tryParse(row.qtyCtrl.text) ?? 1.0;

  final double taxPct = _parseAmount(row.taxCtrl.text);
  double discountAmt = _parseAmount(row.discountCtrl.text);

  // Base Amount
  final double base = rate * qty;

  // GST on Base Amount
  final double itemTax =
      includeGST ? (base * taxPct / 100) : 0.0;

  // Total before Discount
  final double amountBeforeDiscount = base + itemTax;

  // Discount should not exceed Amount
  if (discountAmt > amountBeforeDiscount) {
    discountAmt = amountBeforeDiscount;
  }

  subtotal += base;
  calculatedItemTaxes += itemTax;
  calculatedItemDiscounts += discountAmt;
  overallPaid += _parseAmount(row.paidCtrl.text);
}
// Overall Discount
double globalDiscount = _parseAmount(discountController.text);

final double totalAmount = subtotal + calculatedItemTaxes;

if (globalDiscount > totalAmount) {
  globalDiscount = totalAmount;
}

final double totalDiscount =
    calculatedItemDiscounts + globalDiscount;

final double taxTotal = calculatedItemTaxes;

// Grand Total
double grandTotal = totalAmount - totalDiscount;

if (grandTotal < 0) {
  grandTotal = 0;
}

// Balance
double balanceAmount = grandTotal - overallPaid;

if (balanceAmount < 0) {
  balanceAmount = 0;
}

  if (_loadingExisting) {
    return AdminLayout(
      pageTitle: "Invoice",
      currentRoute: "/invoice",
      child: const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF0052CC),
        ),
      ),
    );
  }

  final pageTitle = _viewOnly
      ? "View Invoice"
      : (_invoiceId != null
            ? "Edit Invoice"
            : "Add Invoice");


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
                Text(pageTitle, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
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
                          final ok = await _saveInvoice(subtotal, totalDiscount, taxTotal, grandTotal, overallPaid, balanceAmount);
                          setState(() => _isSaving = false);
                          if (ok && mounted) _showSavedSuccessDialog();
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

            // Top Header Info
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
                   Expanded(
                  child: _buildClientNameDropdown(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: _buildDatePickerFormInput("Maintenance Date", maintenanceDateController)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Line Items Table (Columns: Description, Rate, Qty, Tax, Discount, Amount, Paid, Pending, Action)
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: const [
                        SizedBox(width: 35, child: Text("S.No", style: _tableLabelStyle)),
                        Expanded(flex: 4, child: Text("Description", style: _tableLabelStyle)),
                        SizedBox(width: 80, child: Text("Rate", textAlign: TextAlign.left, style: _tableLabelStyle)),
                        SizedBox(width: 55, child: Text("QTY", textAlign: TextAlign.left, style: _tableLabelStyle)),
                        SizedBox(width: 65, child: Text("Tax %", textAlign: TextAlign.left, style: _tableLabelStyle)),
                        SizedBox(width: 75, child: Text("Discount", textAlign: TextAlign.left, style: _tableLabelStyle)),
                        SizedBox(width: 85, child: Text("Amount", textAlign: TextAlign.center, style: _tableLabelStyle)),
                        SizedBox(width: 90, child: Text("Paid", textAlign: TextAlign.center, style: _tableLabelStyle)),
                        SizedBox(width: 95, child: Text("Pending", textAlign: TextAlign.center, style: _tableLabelStyle)),
                        SizedBox(width: 30, child: Text("")),
                      ],
                    ),
                  ),
                  for (int i = 0; i < _items.length; i++) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          SizedBox(width: 35, child: Text((i + 1).toString().padLeft(2, '0'), style: const TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(
                            flex: 4,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: _items[i].isPackageRow
                                  ? _buildBeautifulPackageDropdown(_items[i])
                                  : _buildDescriptionField(_items[i]),
                            ),
                          ),
                          // Rate
                          SizedBox(
                            width: 80,
                            child: _items[i].isPackageRow
                                ? _buildReadOnlyRateField(_items[i].rateCtrl)
                                : _buildInnerNumInput(_items[i].rateCtrl, textAlign: TextAlign.center, onChanged: () => setState(() {})),
                          ),
                          const SizedBox(width: 6),
                          // QTY
                          SizedBox(
                            width: 55,
                            child: _buildInnerNumInput(_items[i].qtyCtrl, textAlign: TextAlign.center, onChanged: () => setState(() {})),
                          ),
                          const SizedBox(width: 6),
                          // Tax % (Default 18%)
                          SizedBox(
                            width: 65,
                            child: _buildInnerNumInput(_items[i].taxCtrl, textAlign: TextAlign.center, onChanged: () => setState(() {})),
                          ),
                          const SizedBox(width: 6),
                          // Discount % (Default 0%)
                          SizedBox(
                            width: 85,
                            child: _buildInnerNumInput(_items[i].discountCtrl, textAlign: TextAlign.center, onChanged: () => setState(() {})),
                          ),
                          const SizedBox(width: 6),
                          // Amount
                          // SizedBox(
                          //   width: 85,
                          //   child: Text(
                          //     "₹${_rowAmount(_items[i]).toStringAsFixed(2)}",
                          //     textAlign: TextAlign.right,
                          //     style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          //   ),
                          // ),

                          SizedBox(
  width: 85,
  child: MouseRegion(
    cursor: SystemMouseCursors.basic,
    child: Text(
      "₹${_rowAmount(_items[i]).toStringAsFixed(2)}",
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Color(0xFF0F172A),
      ),
    ),
  ),
),
                          // Paid Amount
                          SizedBox(
                            width: 90,
                            child: _buildPaidAmountField(_items[i]),
                          ),
                          // Pending Amount
                          // SizedBox(
                          //   width: 95,
                          //   child: Text(
                          //     "₹${_rowPending(_items[i]).toStringAsFixed(2)}",
                          //     textAlign: TextAlign.right,
                          //     style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0052CC)),
                          //   ),
                          // ),
                          SizedBox(
  width: 95,
  child: MouseRegion(
    cursor: SystemMouseCursors.basic,
    child: Text(
      "₹${_rowPending(_items[i]).toStringAsFixed(2)}",
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Color(0xFF0052CC),
      ),
    ),
  ),
),
                          // SizedBox(
                          //   width: 30,
                          //   child: Align(
                          //     alignment: Alignment.centerRight,
                          //     child: _viewOnly ? const SizedBox.shrink() : GestureDetector(
                          //       onTap: () => _removeRow(i),
                          //       child: Icon(Icons.delete_outline_rounded, size: 18, color: _items.length > 1 ? Colors.red : Colors.grey.shade300),
                          //     ),
                          //   ),
                          // ),
                          SizedBox(
  width: 30,
  child: Align(
    alignment: Alignment.center,
    child: _viewOnly
        ? const SizedBox.shrink()
        : MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _removeRow(i),
              child: Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: _items.length > 1
                    ? Colors.red
                    : Colors.grey.shade300,
              ),
            ),
          ),
  ),
),
                        ],
                      ),
                    ),
                    if (i < _items.length - 1) const Divider(height: 1, color: Color(0xFFF1F5F9)),
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

            // Notes, Terms & Conditions AND Partial Payment History Table below
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      Container(
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
                                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                                      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF0052CC))),
                                    ),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Partial Payment History Tracking Table
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Partial Payment History", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            const SizedBox(height: 12),
                            Table(
                              border: TableBorder.all(color: const Color(0xFFCBD5E1), width: 0.5),
                              columnWidths: const {
                                0: FixedColumnWidth(35),
                                1: FlexColumnWidth(2),
                                2: FlexColumnWidth(2),
                                3: FlexColumnWidth(2),
                                4: FlexColumnWidth(2),
                                5: FlexColumnWidth(2),
                              },
                              children: [
                                TableRow(
                                  decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                                  children: [
                                    _paymentTableHeader('S.No'),
                                    _paymentTableHeader('Paid Date'),
                                    _paymentTableHeader('Total Amt'),
                                    _paymentTableHeader('Paid Total'),
                                    _paymentTableHeader('Paid Amt'),
                                    _paymentTableHeader('Balance'),
                                  ],
                                ),
                                if (_paymentHistory.isEmpty)
                                  TableRow(
                                    children: [
                                      for (int i = 0; i < 6; i++)
                                        TableCell(
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(i == 0 ? '1' : (i == 1 ? (dateController.text.isNotEmpty ? dateController.text : '-') : '₹0.00'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                          ),
                                        ),
                                    ],
                                  )
                                else
                                  for (int i = 0; i < _paymentHistory.length; i++)
                                    TableRow(
                                      children: [
                                        _paymentTableCell((i + 1).toString(), align: TextAlign.center),
                                        _paymentTableCell(_paymentHistory[i]['paid_date'] ?? ''),
                                        _paymentTableCell('₹${_paymentHistory[i]['total_amount']}'),
                                        _paymentTableCell('₹${_paymentHistory[i]['paid_total_amount']}'),
                                        _paymentTableCell('₹${_paymentHistory[i]['paid_amount']}'),
                                        _paymentTableCell('₹${_paymentHistory[i]['balanced_amount']}'),
                                      ],
                                    ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),

                // Summary Panel in requested precise sequence:
                // Subtotal -> Total Amount -> Discount Total -> Tax Total -> Grand Total -> Total Paid -> Balance to be paid
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
                        const SizedBox(height: 12),
                        _buildSummaryLineItem("Total Amount", "₹${totalAmount.toStringAsFixed(2)}"),
                        const SizedBox(height: 12),
                        _buildSummaryLineItem("Discount Total", "₹${totalDiscount.toStringAsFixed(2)}", textColor: Colors.redAccent),
                        const SizedBox(height: 12),
                        _buildSummaryLineItem("Tax Total (GST)", "₹${taxTotal.toStringAsFixed(2)}"),
                        const SizedBox(height: 12),
                        _buildSummaryLineItem("Grand Total", "₹${grandTotal.toStringAsFixed(2)}", isBold: true, textColor: const Color(0xFF0052CC)),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                        _buildSummaryLineItem("Total Paid", "₹${overallPaid.toStringAsFixed(2)}", textColor: const Color(0xFF16A34A)),
                        const SizedBox(height: 12),
                        _buildSummaryLineItem("Balance to be Paid", "₹${balanceAmount.toStringAsFixed(2)}", isBold: true, textColor: balanceAmount > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A)),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            // onPressed: _isPrinting ? null : () async {
                            //   setState(() => _isPrinting = true);
                            //   await _printInvoice(subtotal, totalDiscount, taxTotal, grandTotal, overallPaid, balanceAmount);
                            //   setState(() => _isPrinting = false);
                            // },
                           onPressed: _isPrinting ? null : () async {
                              setState(() => _isPrinting = true);
         
                              if (_viewOnly) {
                                await _printInvoice(subtotal, totalDiscount, totalAmount, taxTotal, overallPaid, balanceAmount);
                                if (!mounted) return;
                                setState(() => _isPrinting = false);
                                return;
                              }
         
                              final saved = await _saveInvoice(subtotal, totalDiscount, totalAmount, totalAmount, overallPaid, balanceAmount);
                              await _printInvoice(subtotal, totalDiscount, totalAmount, totalAmount, overallPaid, balanceAmount);
         
                              if (!mounted) return;
                              setState(() => _isPrinting = false);
         
                              if (saved) {
                                _showSavedSuccessDialog();
                              }
                            },

                            icon: const Icon(Icons.print, size: 16, color: Colors.white),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0052CC),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            label: const Text("Save & Print Invoice", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
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

  Widget _paymentTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
    );
  }

  Widget _paymentTableCell(String text, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: Text(text, textAlign: align, style: const TextStyle(fontSize: 11, color: Color(0xFF334155))),
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
        onChanged: (value) => setState(() {}),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
          focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF0052CC))),
        ),
      ),
    );
  }

 Widget _buildBeautifulPackageDropdown(_InvoiceItemRow row) {
  final validValue =
      _packages.any((p) => p['id'] == row.packageId)
          ? row.packageId
          : null;

  return MouseRegion(
    cursor: SystemMouseCursors.click,
    child: Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCBD5E1)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: validValue,
          isExpanded: true,
          hint: const Text(
            "Select Package",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          items: _packages.map((pkg) {
            return DropdownMenuItem<int>(
              value: pkg['id'] as int,
              child: Text(
                pkg['title'] ?? '',
                style: const TextStyle(fontSize: 12),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              _onPackageSelected(row, val);
            }
          },
        ),
      ),
    ),
  );
}

Widget _buildClientNameDropdown() {
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

      CompositedTransformTarget(
        link: _clientLayerLink,
        child: SizedBox(
          height: 38,
          child: TextField(
            controller: clientNameController,
            inputFormatters: [UpperCaseTextFormatter()],
            onChanged: _onClientSearchChanged,
            decoration: InputDecoration(
              hintText: "Search client...",
              suffixIcon: _loadingClients
                  ? const Padding(
                      padding: EdgeInsets.all(10),
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
        ),
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
            onTap: () => _selectCalendarDate(context, controller),
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              suffixIcon: const Icon(Icons.calendar_today_rounded, size: 14),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInlineFormInput(
  String label,
  TextEditingController controller, {
  bool readOnly = false,
  Color? fillColor,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF475569),
        ),
      ),
      const SizedBox(height: 6),
      SizedBox(
        height: 38,
        child: MouseRegion(
          cursor: readOnly
              ? SystemMouseCursors.basic
              : SystemMouseCursors.text,
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              filled: fillColor != null,
              fillColor: fillColor,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
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
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          hintText: "Description",
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
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
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
    );
  }

 Widget _buildInnerNumInput(
  TextEditingController controller, {
  required TextAlign textAlign,
  VoidCallback? onChanged,
  bool readOnly = false,
}) {
  return SizedBox(
    height: 38,
    child: MouseRegion(
      cursor: readOnly
          ? SystemMouseCursors.basic
          : SystemMouseCursors.text,
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        textAlign: textAlign,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => onChanged?.call(),
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildSummaryLineItem(String label, String value, {bool isBold = false, Color? textColor}) {
    final style = TextStyle(
      fontSize: isBold ? 14 : 13,
      fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
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
}


