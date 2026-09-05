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
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

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
    String tax = '0.00',
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
  // final notesController = TextEditingController();

  final LayerLink _clientLayer = LayerLink();
  final LayerLink _clientLayerLink = LayerLink();
OverlayEntry? _clientOverlay;

  
// Checkboxes for Print inclusion
  bool _includeNotes = false;
  bool _includeTerms = false;

  final notesController = TextEditingController(
    text: "All the prices mentioned above are:\n"
          "• Excluding GST\n"
          "• Above the price are one month maintenance",
  );
  
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
          // discountController.text = double.tryParse(data['discount'].toString())?.toStringAsFixed(2) ?? '0.00';
          discountController.text = '0.00';
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

//   double _rowAmount(_InvoiceItemRow row) {
//   final rate = _parseAmount(row.rateCtrl.text);
//   final qty = int.tryParse(row.qtyCtrl.text) ?? 1;
//   final taxPct = _parseAmount(row.taxCtrl.text);

//   // Discount is Amount (₹), NOT %
//   final discountAmt = _parseAmount(row.discountCtrl.text);

//   final base = rate * qty;
//   final taxAmt = base * (taxPct / 100);

//   double amount = base + taxAmt - discountAmt;

//   if (amount < 0) amount = 0;

//   return amount;
// }

// double _rowAmount(_InvoiceItemRow row) {
//   final rate = _parseAmount(row.rateCtrl.text);
//   final qty = int.tryParse(row.qtyCtrl.text) ?? 1;
//   final taxPct = _parseAmount(row.taxCtrl.text);
//   //final discountAmt = _parseAmount(row.discountCtrl.text);

//   final base = rate * qty;
//   final taxAmt = includeGST ? (base * (taxPct / 100)) : 0.0;

//   // double amount = base + taxAmt - discountAmt;
//   // if (amount < 0) amount = 0;

//   // return amount;

//    return base + taxAmt;
// }

double _rowAmount(_InvoiceItemRow row) {
  final rate = _parseAmount(row.rateCtrl.text);
  final qty = int.tryParse(row.qtyCtrl.text) ?? 1;
  final taxPct = _parseAmount(row.taxCtrl.text);

  final base = rate * qty;
  final taxAmt = includeGST ? (base * (taxPct / 100)) : 0.0;

  return base + taxAmt;
}

  // double _rowPending(_InvoiceItemRow row) {
  //   final amount = _rowAmount(row);
  //   final paid = _parseAmount(row.paidCtrl.text);
  //   final pending = amount - paid;
  //   return pending < 0 ? 0 : pending;
  // }

double _rowPending(_InvoiceItemRow row) {
  final amount = _rowAmount(row);
  final discount = _parseAmount(row.discountCtrl.text);
  final paid = _parseAmount(row.paidCtrl.text);

  final pending = amount - discount - paid;

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
    // ✅ AuthService-il irundhu token-ah edukavum
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.token;

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
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token', // ✅ Add token here
              },
              body: jsonEncode(payload),
            )
          : await http.post(
              Uri.parse('$_baseUrl/invoices'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token', // ✅ Add token here
              },
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
                    padding: const pw.EdgeInsets.fromLTRB(20, 10, 20, 10),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          width: 140,
                          height: 50,
                          child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                        ),

                        pw.SizedBox(height: 3),

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

                        // pw.SizedBox(height: 8),
                        
                        pw.Table(
                          border: pw.TableBorder.all(color: black, width: 1),
                            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,

                          columnWidths: {
                            0: const pw.FixedColumnWidth(30),
                            1: const pw.FlexColumnWidth(2),
                            2: const pw.FixedColumnWidth(40),
                            3: const pw.FixedColumnWidth(60),
                            4: const pw.FixedColumnWidth(65),
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
                            1: const pw.FixedColumnWidth(125),
                          },
                          children: [

                            pw.TableRow(children: [
                              pw.Container(
                                padding: const pw.EdgeInsets.all(4),
                                alignment: pw.Alignment.center,
                                child: pw.Text('TOTAL AMOUNT', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                              ),
                              pw.Container(
                                padding: const pw.EdgeInsets.all(4),
                                alignment: pw.Alignment.center,
                                child: pw.Text('₹ ${subtotal.toStringAsFixed(0)} /-', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                              ),
                            ]),

                            if (discount > 0)
                              pw.TableRow(children: [
                                pw.Container(
                                  padding: const pw.EdgeInsets.all(4),
                                  alignment: pw.Alignment.center,
                                  child: pw.Text('DISCOUNT', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                                ),
                                pw.Container(
                                  padding: const pw.EdgeInsets.all(4),
                                  alignment: pw.Alignment.center,
                                  child: pw.Text('₹ ${discount.toStringAsFixed(0)} /-', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                                ),
                              ]),

                            if (tax > 0)
                              pw.TableRow(children: [
                                pw.Container(
                                  padding: const pw.EdgeInsets.all(4),
                                  alignment: pw.Alignment.center,
                                  child: pw.Text('TAX (18% GST)', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                                ),
                                pw.Container(
                                  padding: const pw.EdgeInsets.all(4),
                                  alignment: pw.Alignment.center,
                                  child: pw.Text('₹ ${tax.toStringAsFixed(0)} /-', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                                ),
                              ]),

                            // pw.TableRow(children: [
                            //   pw.Container(
                            //     padding: const pw.EdgeInsets.all(4),
                            //     alignment: pw.Alignment.center,
                            //     child: pw.Text('GRAND TOTAL', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                            //   ),
                            //   pw.Container(
                            //     padding: const pw.EdgeInsets.all(4),
                            //     alignment: pw.Alignment.center,
                            //     child: pw.Text('₹ ${total.toStringAsFixed(0)} /-', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                            //   ),
                            // ]),

                            if (total != subtotal)
  pw.TableRow(
    children: [
      pw.Container(
        padding: const pw.EdgeInsets.all(4),
        alignment: pw.Alignment.center,
        child: pw.Text(
          'GRAND TOTAL',
          style: pw.TextStyle(font: fontBold, fontSize: 12),
        ),
      ),
      pw.Container(
        padding: const pw.EdgeInsets.all(4),
        alignment: pw.Alignment.center,
        child: pw.Text(
          '₹ ${total.toStringAsFixed(0)} /-',
          style: pw.TextStyle(font: fontBold, fontSize: 12),
        ),
      ),
    ],
  ),

                            // pw.TableRow(children: [
                            //   pw.Container(
                            //     padding: const pw.EdgeInsets.all(4),
                            //     alignment: pw.Alignment.center,
                            //     child: pw.Text('PAID AMOUNT', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                            //   ),
                            //   pw.Container(
                            //     padding: const pw.EdgeInsets.all(4),
                            //     alignment: pw.Alignment.center,
                            //     child: pw.Text('₹ ${paid.toStringAsFixed(0)} /-', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                            //   ),
                            // ]),

                            if (paid > 0 && balance > 0)
  pw.TableRow(
    children: [
      pw.Container(
        padding: const pw.EdgeInsets.all(4),
        alignment: pw.Alignment.center,
        child: pw.Text(
          'PAID AMOUNT',
          style: pw.TextStyle(font: fontBold, fontSize: 12),
        ),
      ),
      pw.Container(
        padding: const pw.EdgeInsets.all(4),
        alignment: pw.Alignment.center,
        child: pw.Text(
          '₹ ${paid.toStringAsFixed(0)} /-',
          style: pw.TextStyle(font: fontBold, fontSize: 12),
        ),
      ),
    ],
  ),

                            if (paid > 0 && balance > 0)
  pw.TableRow(children: [
    pw.Container(
      padding: const pw.EdgeInsets.all(4),
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
      padding: const pw.EdgeInsets.all(4),
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
                        
                        pw.SizedBox(height: 10),

                        // if (notesController.text.isNotEmpty) ...[
                        //   pw.Text('Notes', style: pw.TextStyle(font: fontBold, fontSize: 8)),
                        //   pw.SizedBox(height: 2),
                        //   pw.Text(
                        //     notesController.text,
                        //     style: pw.TextStyle(font: font, fontSize: 9),
                        //   ),
                        //   pw.SizedBox(height: 6),
                        // ],

                        // ✅ NOTES PRINT CONDITION
                        if (_includeNotes && notesController.text.isNotEmpty) ...[
                          pw.Text('Notes', style: pw.TextStyle(font: fontBold, fontSize: 8)),
                          pw.SizedBox(height: 2),
                          ...notesController.text.split('\n').map((note) {
                            return pw.Padding(
                              padding: const pw.EdgeInsets.only(bottom: 2),
                              child: pw.Text(
                                note.trim().isEmpty ? '' : note.trim(),
                                style: pw.TextStyle(font: font, fontSize: 9),
                              ),
                            );
                          }),
                          pw.SizedBox(height: 6),
                        ],

                        // if (agreedToTerms) ...[
                          // pw.Text('Terms & Conditions', style: pw.TextStyle(font: fontBold, fontSize: 8)),
                          // pw.SizedBox(height: 2),
                          // ...termsController.text.split('\n').map((term) {
                          //   return pw.Padding(
                          //     padding: const pw.EdgeInsets.only(bottom: 2),
                          //     child: pw.Text(
                          //       term.trim().isEmpty ? '' : term.trim(),
                          //       style: pw.TextStyle(font: font, fontSize: 9),
                          //     ),
                          //   );
                          // }),
                          // pw.SizedBox(height: 12),
                        // ],

                        // ✅ TERMS & CONDITIONS PRINT CONDITION
                        if (_includeTerms && termsController.text.isNotEmpty) ...[
                          pw.Text('Terms & Conditions', style: pw.TextStyle(font: fontBold, fontSize: 8)),
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
                        ],

                        // pw.Spacer(),

                        // pw.SizedBox(height: 15),

                        // pw.Row(
                        //   mainAxisAlignment: pw.MainAxisAlignment.end,
                        //   children: [
                        //     pw.SizedBox(width: 10),
                        //     pw.Container(
                        //       width: 80,
                        //       height: 80,
                        //       child: pw.Image(sealImage, fit: pw.BoxFit.contain),
                        //     ),
                        //   ],
                        // ),

                        // pw.Row(
                        //   crossAxisAlignment: pw.CrossAxisAlignment.end,
                        //   children: [
                        //     pw.Expanded(
                        //       child: pw.Column(
                        //         crossAxisAlignment: pw.CrossAxisAlignment.start,
                        //         children: [
                        //           pw.Text('BANK ACCOUNT DETAILS',
                        //               style: pw.TextStyle(
                        //                 font: fontBold,
                        //                 fontSize: 15,
                        //                 decoration: pw.TextDecoration.underline,
                        //               )),
                        //           pw.SizedBox(height: 3),
                        //           pw.Text('NAME: GO DIGITAL | BANK: IDFC FIRST BANK | A/C NO: 10075087276 | BRANCH: KILPAUK | IFSC: IDFB0080121',
                        //               style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: blue)),
                        //           pw.SizedBox(height: 3),
                        //           pw.Text('Office: +91 94449 43094 | Email: godigitalindaras@gmail.com | Website: www.godigital.ind.in',
                        //               style: pw.TextStyle(font: font, fontSize: 12),
                        //               textAlign: pw.TextAlign.center),
                        //         ],
                        //       ),
                        //     ),
                        //   ],
                        // ),
                     
                      ],
                    ),
                  ),
                ),

                // pw.Container(
                //   color: blue,
                //   width: double.infinity,
                //   padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                //   child: pw.Column(
                //     mainAxisSize: pw.MainAxisSize.min,
                //     children: [
                //       pw.Text('GO DIGITAL', style: pw.TextStyle(font: fontBold, fontSize: 14, color: white)),
                //       pw.SizedBox(height: 2),
                //       pw.Text('No:14, Udaya Suriyan Nagar, Guduvanchery 603202 Near Olala Cafe',
                //           style: pw.TextStyle(font: font, fontSize: 10, color: white),
                //           textAlign: pw.TextAlign.center),
                //     ],
                //   ),
                // ),
              
              pw.Column(
  mainAxisSize: pw.MainAxisSize.min,
  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
  children: [
    // SEAL
    pw.Padding(
  padding: const pw.EdgeInsets.symmetric(horizontal: 20),
  child: 
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 80,
          height: 80,
          child: pw.Image(
            sealImage,
            fit: pw.BoxFit.contain,
          ),
        ),
      ],
    ),
    ),

    // BANK DETAILS - immediately below seal
    pw.Padding(
  padding: const pw.EdgeInsets.symmetric(horizontal: 20),
  child: 
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'BANK ACCOUNT DETAILS',
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 15,
            decoration: pw.TextDecoration.underline,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          'NAME: GO DIGITAL | BANK: IDFC FIRST BANK | A/C NO: 10075087276 | BRANCH: KILPAUK | IFSC: IDFB0080121',
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 9.5,
            color: blue,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          'Office: +91 94449 43094 | Email: godigitalindaras@gmail.com | Website: www.godigital.ind.in',
          style: pw.TextStyle(
            font: font,
            fontSize: 12,
          ),
          textAlign: pw.TextAlign.left,
        ),
      ],
    ),
    ),

    // FOOTER - immediately after bank details
    pw.Container(
      color: blue,
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 8,
      ),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            'GO DIGITAL',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 14,
              color: white,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'No:14, Udaya Suriyan Nagar, Guduvanchery 603202 Near Olala Cafe',
            style: pw.TextStyle(
              font: font,
              fontSize: 10,
              color: white,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    ),
  ],
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
      final rate = _parseAmount(row.rateCtrl.text);
      final qty = double.tryParse(row.qtyCtrl.text) ?? 1.0;
      final taxPct = _parseAmount(row.taxCtrl.text);
      double discountAmt = _parseAmount(row.discountCtrl.text);

      final base = rate * qty;
      final itemTax = includeGST ? (base * taxPct / 100) : 0.0;
      final amountBeforeDiscount = base + itemTax;

      if (discountAmt > amountBeforeDiscount) {
        discountAmt = amountBeforeDiscount;
      }

      subtotal += base;
      calculatedItemTaxes += itemTax;
      calculatedItemDiscounts += discountAmt;
      overallPaid += _parseAmount(row.paidCtrl.text);
    }

    final totalAmount = subtotal + calculatedItemTaxes;
    final totalDiscount = calculatedItemDiscounts;
    final taxTotal = calculatedItemTaxes;

    double grandTotal = totalAmount - totalDiscount;
    if (grandTotal < 0) grandTotal = 0;

    double balanceAmount = grandTotal - overallPaid;
    if (balanceAmount < 0) balanceAmount = 0;

    if (_loadingExisting) {
      return AdminLayout(
        pageTitle: "Invoice",
        currentRoute: "/invoice",
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF0052CC)),
        ),
      );
    }

    final pageTitle = _viewOnly
        ? "View Invoice"
        : (_invoiceId != null ? "Edit Invoice" : "Add Invoice");

    Future<void> saveInvoice() async {
      setState(() => _isSaving = true);
      final ok = await _saveInvoice(
        subtotal,
        0.0,
        taxTotal,
        grandTotal,
        overallPaid,
        balanceAmount,
      );
      if (!mounted) return;
      setState(() => _isSaving = false);
      if (ok) _showSavedSuccessDialog();
    }

    Future<void> saveAndPrint() async {
      setState(() => _isPrinting = true);

      if (_viewOnly) {
        await _printInvoice(
          subtotal,
          totalDiscount,
          taxTotal,
          grandTotal,
          overallPaid,
          balanceAmount,
        );
      } else {
        final saved = await _saveInvoice(
          subtotal,
          0.0,
          taxTotal,
          grandTotal,
          overallPaid,
          balanceAmount,
        );

        await _printInvoice(
          subtotal,
          totalDiscount,
          taxTotal,
          grandTotal,
          overallPaid,
          balanceAmount,
        );

        if (mounted && saved) {
          _showSavedSuccessDialog();
        }
      }

      if (mounted) setState(() => _isPrinting = false);
    }

    return AdminLayout(
      pageTitle: pageTitle,
      currentRoute: "/invoice",
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 700;
          final isTablet = constraints.maxWidth >= 700 && constraints.maxWidth < 1050;

          return SingleChildScrollView(
            padding: EdgeInsets.only(
              left: isMobile ? 0 : 2,
              right: isMobile ? 0 : 2,
              bottom: 30,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─────────────────────────────────────────────
                // PAGE HERO
                // ─────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isMobile ? 16 : 22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0052CC),
                    borderRadius: BorderRadius.circular(isMobile ? 18 : 20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0052CC).withValues(alpha: .14),
                        blurRadius: 24,
                        offset: const Offset(0, 9),
                      ),
                    ],
                  ),
                  child: isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .14),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.receipt_long_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pageTitle.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _viewOnly
                                            ? "Review invoice details"
                                            : "Create and manage invoice",
                                        style: const TextStyle(
                                          color: Color(0xFFDCE8FF),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _heroActionButton(
                                    icon: Icons.arrow_back_rounded,
                                    label: "Back",
                                    onTap: () => Navigator.pop(context),
                                    outlined: true,
                                  ),
                                ),
                                if (!_viewOnly) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _heroActionButton(
                                      icon: Icons.save_rounded,
                                      label: _isSaving ? "Saving..." : "Save",
                                      onTap: _isSaving ? null : saveInvoice,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .14),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.receipt_long_rounded,
                                color: Colors.white,
                                size: 25,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "INVOICE CENTER",
                                    style: TextStyle(
                                      color: Color(0xFFBFD5FF),
                                      fontSize: 10,
                                      letterSpacing: 1.2,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    pageTitle,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _viewOnly
                                        ? "Review invoice details and print"
                                        : "Create, update and print professional invoices",
                                    style: const TextStyle(
                                      color: Color(0xFFDCE8FF),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _heroActionButton(
                              icon: Icons.arrow_back_rounded,
                              label: "Back",
                              onTap: () => Navigator.pop(context),
                              outlined: true,
                            ),
                            if (!_viewOnly) ...[
                              const SizedBox(width: 10),
                              _heroActionButton(
                                icon: Icons.save_rounded,
                                label: _isSaving ? "Saving..." : "Save Invoice",
                                onTap: _isSaving ? null : saveInvoice,
                              ),
                            ],
                          ],
                        ),
                ),

                SizedBox(height: isMobile ? 14 : 18),

                // ─────────────────────────────────────────────
                // INVOICE INFORMATION
                // ─────────────────────────────────────────────
                _sectionCard(
                  title: "Invoice Information",
                  icon: Icons.info_outline_rounded,
                  isMobile: isMobile,
                  child: isMobile
                      ? Column(
                          children: [
                            _buildInlineFormInput(
                              "Invoice No",
                              invoiceNoController,
                              readOnly: true,
                              fillColor: const Color(0xFFEFF6FF),
                            ),
                            const SizedBox(height: 12),
                            _buildDatePickerFormInput("Invoice Date", dateController),
                            const SizedBox(height: 12),
                            _buildClientNameDropdown(),
                            const SizedBox(height: 12),
                            _buildDatePickerFormInput(
                              "Maintenance Date",
                              maintenanceDateController,
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: _buildInlineFormInput(
                                "Invoice No",
                                invoiceNoController,
                                readOnly: true,
                                fillColor: const Color(0xFFEFF6FF),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildDatePickerFormInput(
                                "Invoice Date",
                                dateController,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: _buildClientNameDropdown()),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildDatePickerFormInput(
                                "Maintenance Date",
                                maintenanceDateController,
                              ),
                            ),
                          ],
                        ),
                ),

                
                const SizedBox(height: 16),

                // ─────────────────────────────────────────────
                // LINE ITEMS
                // ─────────────────────────────────────────────
                _sectionCard(
                  title: "Invoice Items",
                  icon: Icons.list_alt_rounded,
                  isMobile: isMobile,
                  trailing: !_viewOnly
                      ? TextButton.icon(
                          onPressed: _addSection,
                          icon: const Icon(
                            Icons.add_rounded,
                            size: 17,
                            color: Color(0xFF0052CC),
                          ),
                          label: const Text(
                            "Add Item",
                            style: TextStyle(
                              color: Color(0xFF0052CC),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      : null,
                  child: isMobile
                      ? Column(
                          children: [
                            for (int i = 0; i < _items.length; i++)
                              _buildMobileInvoiceItemCard(
                                _items[i],
                                i,
                              ),
                          ],
                        )
                      : _buildDesktopInvoiceItems(),
                ),

                if (!isMobile && !isTablet)
                  const SizedBox(height: 18)
                else
                  const SizedBox(height: 14),

                // ─────────────────────────────────────────────
                // NOTES + TERMS
                // ─────────────────────────────────────────────
                _sectionCard(
                  title: "Additional Information",
                  icon: Icons.notes_rounded,
                  isMobile: isMobile,
                  child: isMobile
                      ? Column(
                          children: [
                            _buildNotesEditor(),
                            const SizedBox(height: 14),
                            _buildTermsEditor(),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildNotesEditor()),
                            const SizedBox(width: 18),
                            Expanded(child: _buildTermsEditor()),
                          ],
                        ),
                ),

                const SizedBox(height: 16),

                // ─────────────────────────────────────────────
                // BOTTOM AREA: PAYMENT HISTORY + SUMMARY
                // ─────────────────────────────────────────────
                if (isMobile) ...[
                  _buildMobileSummary(
                    subtotal,
                    totalAmount,
                    totalDiscount,
                    taxTotal,
                    grandTotal,
                    overallPaid,
                    balanceAmount,
                    saveAndPrint,
                  ),
                  const SizedBox(height: 14),
                  _buildPaymentHistoryCard(isMobile: true),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: _buildPaymentHistoryCard(isMobile: false),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        flex: 3,
                        child: _buildDesktopSummary(
                          subtotal,
                          totalAmount,
                          totalDiscount,
                          taxTotal,
                          grandTotal,
                          overallPaid,
                          balanceAmount,
                          saveAndPrint,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 18),

                // Bottom action bar on mobile
                if (isMobile)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, size: 17),
                            label: const Text("Cancel"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF475569),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        if (!_viewOnly) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : saveInvoice,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save_rounded, size: 17),
                              label: const Text("Save Invoice"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0052CC),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _heroActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool outlined = false,
  }) {
    return SizedBox(
      height: 42,
      child: outlined
          ? OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 16),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: .38)),
                backgroundColor: Colors.white.withValues(alpha: .08),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            )
          : ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 16),
              label: Text(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0052CC),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    required bool isMobile,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 15 : 16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              isMobile ? 14 : 18,
              isMobile ? 13 : 15,
              isMobile ? 10 : 14,
              isMobile ? 12 : 15,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    icon,
                    size: 17,
                    color: const Color(0xFF0052CC),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: EdgeInsets.all(isMobile ? 14 : 18),
            child: child,
          ),
        ],
      ),
    );
  }

 Widget _buildDesktopInvoiceItems() {
    return Column(
      children: [
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            color: Color(0xFFF7F9FC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Row(
            children: const [
              SizedBox(
                width: 34,
                child: Text("S.No", style: _tableLabelStyle),
              ),
              Expanded(
                flex: 4,
                child: Text("Description", style: _tableLabelStyle),
              ),
              SizedBox(
                width: 78,
                child: Text("Rate", textAlign: TextAlign.center, style: _tableLabelStyle),
              ),
              SizedBox(
                width: 52,
                child: Text("QTY", textAlign: TextAlign.center, style: _tableLabelStyle),
              ),
              SizedBox(
                width: 62,
                child: Text("Tax %", textAlign: TextAlign.center, style: _tableLabelStyle),
              ),
              SizedBox(
                width: 76,
                child: Text("Discount", textAlign: TextAlign.center, style: _tableLabelStyle),
              ),
              SizedBox(
                width: 82,
                child: Text("Amount", textAlign: TextAlign.center, style: _tableLabelStyle),
              ),
              SizedBox(
                width: 86,
                child: Text("Paid", textAlign: TextAlign.center, style: _tableLabelStyle),
              ),
              SizedBox(
                width: 92,
                child: Text("Pending", textAlign: TextAlign.center, style: _tableLabelStyle),
              ),
              SizedBox(width: 28),
            ],
          ),
        ),
        for (int i = 0; i < _items.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 34,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      (i + 1).toString().padLeft(2, '0'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                      children: [
                        _buildBeautifulPackageDropdown(_items[i]),
                        const SizedBox(height: 6),
                        _buildDescriptionField(_items[i]),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 78,
                  child: _buildInnerNumInput(
                    _items[i].rateCtrl,
                    textAlign: TextAlign.center,
                    readOnly: _viewOnly,
                    onChanged: () => setState(() {}),
                  ),
                ),
                const SizedBox(width: 5),
                SizedBox(
                  width: 52,
                  child: _buildInnerNumInput(
                    _items[i].qtyCtrl,
                    textAlign: TextAlign.center,
                    readOnly: _viewOnly,
                    onChanged: () => setState(() {}),
                  ),
                ),
                const SizedBox(width: 5),
                SizedBox(
                  width: 62,
                  child: _buildInnerNumInput(
                    _items[i].taxCtrl,
                    textAlign: TextAlign.center,
                    readOnly: _viewOnly,
                    onChanged: () => setState(() {}),
                  ),
                ),
                const SizedBox(width: 5),
                SizedBox(
                  width: 76,
                  child: _buildInnerNumInput(
                    _items[i].discountCtrl,
                    textAlign: TextAlign.center,
                    readOnly: _viewOnly,
                    onChanged: () => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 82,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _amountChip(
                      "₹${_rowAmount(_items[i]).toStringAsFixed(2)}",
                    ),
                  ),
                ),
                SizedBox(
                  width: 86,
                  child: _buildPaidAmountField(_items[i]),
                ),
                SizedBox(
                  width: 92,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _amountChip(
                      "₹${_rowPending(_items[i]).toStringAsFixed(2)}",
                      color: const Color(0xFF0052CC),
                    ),
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _viewOnly
                        ? const SizedBox.shrink()
                        : IconButton(
                            onPressed: _items.length > 1
                                ? () => _removeRow(i)
                                : null,
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: _items.length > 1
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFFCBD5E1),
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: "Remove",
                          ),
                  ),
                ),
              ],
            ),
          ),
          if (i < _items.length - 1)
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
        ],
      ],
    );
  }

  
  Widget _buildMobileInvoiceItemCard(_InvoiceItemRow row, int index) {
    final amount = _rowAmount(row);
    final pending = _rowPending(row);

    return Container(
      margin: EdgeInsets.only(bottom: index == _items.length - 1 ? 0 : 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${index + 1}",
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0052CC),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  row.descriptionCtrl.text.isNotEmpty
                      ? row.descriptionCtrl.text.split('\n').first
                      : "Invoice Item ${index + 1}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (!_viewOnly)
                IconButton(
                  onPressed: _items.length > 1 ? () => _removeRow(index) : null,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: _items.length > 1
                        ? const Color(0xFFDC2626)
                        : const Color(0xFFCBD5E1),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          row.isPackageRow
              ? _buildBeautifulPackageDropdown(row)
              : _buildDescriptionField(row),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _mobileItemField(
                  "Rate",
                  _buildInnerNumInput(
                    row.rateCtrl,
                    textAlign: TextAlign.center,
                    readOnly: _viewOnly,
                    onChanged: () => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _mobileItemField(
                  "Qty",
                  _buildInnerNumInput(
                    row.qtyCtrl,
                    textAlign: TextAlign.center,
                    readOnly: _viewOnly,
                    onChanged: () => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _mobileItemField(
                  "Tax %",
                  _buildInnerNumInput(
                    row.taxCtrl,
                    textAlign: TextAlign.center,
                    readOnly: _viewOnly,
                    onChanged: () => setState(() {}),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _mobileItemField(
                  "Discount",
                  _buildInnerNumInput(
                    row.discountCtrl,
                    textAlign: TextAlign.center,
                    readOnly: _viewOnly,
                    onChanged: () => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _mobileValueBox(
                  "Amount",
                  "₹${amount.toStringAsFixed(2)}",
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _mobileValueBox(
                  "Pending",
                  "₹${pending.toStringAsFixed(2)}",
                  valueColor: const Color(0xFF0052CC),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _mobileItemField(
            "Paid Amount",
            _buildPaidAmountField(row),
          ),
        ],
      ),
    );
  }

  Widget _mobileItemField(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  Widget _mobileValueBox(
    String label,
    String value, {
    Color valueColor = const Color(0xFF0F172A),
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 38,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _amountChip(String text, {Color color = const Color(0xFF0F172A)}) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w900,
        color: color,
      ),
    );
  }

  Widget _buildNotesEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _toggleTitle(
          "Notes",
          Icons.sticky_note_2_outlined,
          _includeNotes,
          (value) => setState(() => _includeNotes = value),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: notesController,
          maxLines: 4,
          readOnly: _viewOnly,
          style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
          decoration: InputDecoration(
            hintText: "Add internal notes...",
            hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.all(11),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF0052CC)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _toggleTitle(
          "Terms & Conditions",
          Icons.gavel_outlined,
          _includeTerms,
          (value) => setState(() => _includeTerms = value),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: termsController,
          maxLines: 4,
          readOnly: _viewOnly,
          style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
          decoration: InputDecoration(
            hintText: "Enter terms & conditions...",
            hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.all(11),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF0052CC)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _toggleTitle(
    String label,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      children: [
        Checkbox(
          value: value,
          activeColor: const Color(0xFF0052CC),
          onChanged: _viewOnly ? null : (v) => onChanged(v ?? false),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        Icon(icon, size: 16, color: const Color(0xFF0052CC)),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF475569),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentHistoryCard({required bool isMobile}) {
    final table = Table(
      border: TableBorder.all(color: const Color(0xFFE2E8F0), width: .6),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: FixedColumnWidth(38),
        1: FixedColumnWidth(95),
        2: FixedColumnWidth(100),
        3: FixedColumnWidth(100),
        4: FixedColumnWidth(95),
        5: FixedColumnWidth(95),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFF7F9FC)),
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
                    padding: const EdgeInsets.all(9),
                    child: Text(
                      i == 0
                          ? '1'
                          : (i == 1
                              ? (dateController.text.isNotEmpty
                                  ? dateController.text
                                  : '-')
                              : '₹0.00'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
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
    );

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 15 : 16),
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
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  size: 17,
                  color: Color(0xFF16A34A),
                ),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  "Payment History",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Text(
                "${_paymentHistory.length} record${_paymentHistory.length == 1 ? '' : 's'}",
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isMobile)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: table,
            )
          else
            table,
        ],
      ),
    );
  }

  Widget _buildDesktopSummary(
    double subtotal,
    double totalAmount,
    double totalDiscount,
    double taxTotal,
    double grandTotal,
    double overallPaid,
    double balanceAmount,
    VoidCallback saveAndPrint,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _summaryHeader(balanceAmount),
          const SizedBox(height: 16),
          _buildSummaryLineItem("Subtotal", "₹${subtotal.toStringAsFixed(2)}"),
          const SizedBox(height: 11),
          _buildSummaryLineItem("Total Amount", "₹${totalAmount.toStringAsFixed(2)}"),
          const SizedBox(height: 11),
          _buildSummaryLineItem(
            "Discount Total",
            "₹${totalDiscount.toStringAsFixed(2)}",
            textColor: const Color(0xFFDC2626),
          ),
          const SizedBox(height: 11),
          _buildSummaryLineItem("Tax Total (GST)", "₹${taxTotal.toStringAsFixed(2)}"),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 13),
            child: Divider(height: 1),
          ),
          _buildSummaryLineItem(
            "Grand Total",
            "₹${grandTotal.toStringAsFixed(2)}",
            isBold: true,
            textColor: const Color(0xFF0052CC),
          ),
          const SizedBox(height: 11),
          _buildSummaryLineItem(
            "Total Paid",
            "₹${overallPaid.toStringAsFixed(2)}",
            textColor: const Color(0xFF16A34A),
          ),
          const SizedBox(height: 11),
          _buildSummaryLineItem(
            "Balance to be Paid",
            "₹${balanceAmount.toStringAsFixed(2)}",
            isBold: true,
            textColor: balanceAmount > 0
                ? const Color(0xFFDC2626)
                : const Color(0xFF16A34A),
          ),
          const SizedBox(height: 18),
          _savePrintButton(saveAndPrint),
        ],
      ),
    );
  }

  Widget _buildMobileSummary(
    double subtotal,
    double totalAmount,
    double totalDiscount,
    double taxTotal,
    double grandTotal,
    double overallPaid,
    double balanceAmount,
    VoidCallback saveAndPrint,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _summaryHeader(balanceAmount),
          const SizedBox(height: 14),
          _mobileSummaryTile(
            "Subtotal",
            "₹${subtotal.toStringAsFixed(2)}",
            Icons.calculate_outlined,
          ),
          _mobileSummaryTile(
            "Tax / GST",
            "₹${taxTotal.toStringAsFixed(2)}",
            Icons.percent_rounded,
          ),
          _mobileSummaryTile(
            "Discount",
            "₹${totalDiscount.toStringAsFixed(2)}",
            Icons.discount_outlined,
            valueColor: const Color(0xFFDC2626),
          ),
          _mobileSummaryTile(
            "Total Amount",
            "₹${totalAmount.toStringAsFixed(2)}",
            Icons.receipt_long_outlined,
          ),
          Container(
            margin: const EdgeInsets.only(top: 5, bottom: 8),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Column(
              children: [
                _buildSummaryLineItem(
                  "Grand Total",
                  "₹${grandTotal.toStringAsFixed(2)}",
                  isBold: true,
                  textColor: const Color(0xFF0052CC),
                ),
                const SizedBox(height: 10),
                _buildSummaryLineItem(
                  "Total Paid",
                  "₹${overallPaid.toStringAsFixed(2)}",
                  textColor: const Color(0xFF16A34A),
                ),
                const SizedBox(height: 10),
                _buildSummaryLineItem(
                  "Balance",
                  "₹${balanceAmount.toStringAsFixed(2)}",
                  isBold: true,
                  textColor: balanceAmount > 0
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF16A34A),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _savePrintButton(saveAndPrint),
        ],
      ),
    );
  }

  Widget _summaryHeader(double balance) {
    final paid = balance <= 0;
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: paid ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            paid ? Icons.check_circle_outline_rounded : Icons.payments_outlined,
            size: 18,
            color: paid ? const Color(0xFF16A34A) : const Color(0xFFD97706),
          ),
        ),
        const SizedBox(width: 9),
        const Expanded(
          child: Text(
            "Invoice Summary",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: paid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            paid ? "PAID" : "BALANCE",
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: paid ? const Color(0xFF15803D) : const Color(0xFFD97706),
            ),
          ),
        ),
      ],
    );
  }

  Widget _mobileSummaryTile(
    String label,
    String value,
    IconData icon, {
    Color valueColor = const Color(0xFF334155),
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(icon, size: 15, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _savePrintButton(VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton.icon(
        onPressed: _isPrinting ? null : onPressed,
        icon: _isPrinting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.print_rounded, size: 18),
        label: Text(
          _viewOnly ? "Print Invoice" : "Save & Print Invoice",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0052CC),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
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

  // Widget _buildPaidAmountField(_InvoiceItemRow row) {
  //   return SizedBox(
  //     height: 38,
  //     child: TextField(
  //       controller: row.paidCtrl,
  //       textAlign: TextAlign.right,
  //       readOnly: _viewOnly,
  //       keyboardType: const TextInputType.numberWithOptions(decimal: true),
  //       onChanged: (value) => setState(() {}),
  //       style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
  //       decoration: InputDecoration(
  //         contentPadding: const EdgeInsets.symmetric(horizontal: 8),
  //         enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
  //         focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF0052CC))),
  //       ),
  //     ),
  //   );
  // }
  Widget _buildPaidAmountField(_InvoiceItemRow row) {
  return SizedBox(
    height: 38,
    child: TextField(
      controller: row.paidCtrl,
      textAlign: TextAlign.right,
      readOnly: _viewOnly,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),

      onChanged: (value) {
        final entered = double.tryParse(value) ?? 0.0;

        // Maximum amount that can be paid
        final maxPaid = _rowAmount(row);

        if (entered > maxPaid) {
          row.paidCtrl.text = maxPaid.toStringAsFixed(2);
          row.paidCtrl.selection = TextSelection.fromPosition(
            TextPosition(offset: row.paidCtrl.text.length),
          );
        }

        setState(() {});
      },

      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF0052CC)),
        ),
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
    child: TextField(
      controller: row.descriptionCtrl,
      maxLines: null, // Multiple lines-ah expand aaga
      keyboardType: TextInputType.multiline,
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        hintText: "Description",
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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


