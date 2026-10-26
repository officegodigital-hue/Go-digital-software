// name=client_details_screen.dart
//
// Client Onboarding → Add / Edit client.
//  · Back (top) returns to Client History.
//  · Save        → saves the client and returns to Client History.
//  · Complete    → saves as "complete" (100%) and returns to Client History.
// Credentials are managed from the Client Credentials page, not from here.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../layouts/admin_layout.dart';
import '../../services/api_config.dart';
import '../../services/auth_service.dart';

class ClientDetailsScreen extends StatefulWidget {
  final int? clientId;

  const ClientDetailsScreen({super.key, this.clientId});

  @override
  State<ClientDetailsScreen> createState() => _ClientDetailsScreenState();
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase(), selection: newValue.selection);
  }
}

class _ClientDetailsScreenState extends State<ClientDetailsScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  // Palette (matches Client History).
  static const _blue = Color(0xFF0052CC);
  static const _blueDark = Color(0xFF003B95);
  static const _blueLight = Color(0xFF1267E8);
  static const _ink = Color(0xFF0F172A);
  static const _text = Color(0xFF334155);
  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFE2E8F0);
  static const _green = Color(0xFF16A34A);
  static const _amber = Color(0xFFB45309);
  static const _red = Color(0xFFDC2626);

  final _formKey = GlobalKey<FormState>();
  final companyNameController = TextEditingController();
  final contactPersonController = TextEditingController();
  final emailController = TextEditingController();
  final addressController = TextEditingController();
  final industryController = TextEditingController();
  final phoneController = TextEditingController();
  final gstController = TextEditingController();

  int? _clientId;
  String _currentStatus = 'draft';
  int _completionPercent = 0;
  bool _loadingClient = false;
  bool _saving = false;
  bool _completing = false;

  bool get _busy => _saving || _completing;
  bool get _isEdit => _clientId != null;

  List<TextEditingController> get _controllers => [
        companyNameController,
        contactPersonController,
        emailController,
        addressController,
        industryController,
        phoneController,
        gstController,
      ];

  // ─────────────────────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _clientId = widget.clientId;
    for (final c in _controllers) {
      c.addListener(_onFieldChanged);
    }
    if (_clientId != null) _loadClient();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.removeListener(_onFieldChanged);
      c.dispose();
    }
    super.dispose();
  }

  // Checklist / header update live while typing.
  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  Map<String, String> get _headers {
    final token = Provider.of<AuthService>(context, listen: false).token;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: success ? _green : _red,
        content: Row(
          children: [
            Icon(success ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(msg, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  /// Back to Client History (it reloads its list when this page closes).
  void _goBack({bool saved = false}) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(saved);
    } else {
      Navigator.of(context).pushReplacementNamed('/client-history');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // LOAD / SAVE
  // ─────────────────────────────────────────────────────────────

  Future<void> _loadClient() async {
    setState(() => _loadingClient = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/clients/$_clientId'), headers: _headers);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final c = jsonDecode(response.body)['data'] as Map;
        companyNameController.text = '${c['company_name'] ?? ''}';
        contactPersonController.text = '${c['contact_person'] ?? ''}';
        emailController.text = '${c['email'] ?? ''}';
        addressController.text = '${c['address'] ?? ''}';
        industryController.text = '${c['industry'] ?? ''}';
        phoneController.text = '${c['client_phone'] ?? ''}';
        gstController.text = '${c['gst_number'] ?? ''}';
        setState(() {
          _currentStatus = '${c['status'] ?? 'draft'}';
          _completionPercent = int.tryParse('${c['completion_percent'] ?? 0}') ?? 0;
          _loadingClient = false;
        });
      } else {
        setState(() => _loadingClient = false);
        _showSnack('Failed to load client details');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingClient = false);
      _showSnack('Cannot connect to server');
    }
  }

  Map<String, dynamic> _payload(String status) => {
        'companyName': companyNameController.text.trim(),
        'industry': industryController.text.trim(),
        'contactPerson': contactPersonController.text.trim(),
        'email': emailController.text.trim(),
        'address': addressController.text.trim(),
        'clientPhone': phoneController.text.trim(),
        'gstNumber': gstController.text.trim(),
        'status': status,
      };

  /// complete = false → Save (keeps the current onboarding step)
  /// complete = true  → Complete Registration (100%)
  Future<void> _submit({required bool complete}) async {
    FocusScope.of(context).unfocus();
    if (companyNameController.text.trim().isEmpty) {
      _formKey.currentState?.validate();
      _showSnack('Please enter the Company Name');
      return;
    }
    if (complete && !(_formKey.currentState?.validate() ?? false)) {
      _showSnack('Fill the required fields (*) to complete registration');
      return;
    }
    if (!complete && emailController.text.trim().isNotEmpty && _emailError(emailController.text) != null) {
      _formKey.currentState?.validate();
      _showSnack('Please check the email address');
      return;
    }

    setState(() {
      if (complete) {
        _completing = true;
      } else {
        _saving = true;
      }
    });
    try {
      final status = complete ? 'complete' : (_isEdit ? _currentStatus : 'draft');
      final body = jsonEncode(_payload(status));
      final response = _isEdit
          ? await http.put(Uri.parse('$_baseUrl/clients/$_clientId'), headers: _headers, body: body)
          : await http.post(Uri.parse('$_baseUrl/clients'), headers: _headers, body: body);

      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnack(
          complete
              ? 'Registration completed — ${companyNameController.text.trim()} is 100% complete'
              : (_isEdit ? 'Client updated' : 'Client saved'),
          success: true,
        );
        _goBack(saved: true);
      } else {
        String msg = 'Failed to save (${response.statusCode})';
        try {
          final m = jsonDecode(response.body)['message'];
          if (m != null) msg = '$m';
        } catch (_) {}
        _showSnack(msg);
      }
    } catch (e) {
      debugPrint('Client save error: $e');
      _showSnack('Cannot connect to server');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _completing = false;
        });
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // VALIDATION
  // ─────────────────────────────────────────────────────────────

  String? _required(String? v, String label) => (v ?? '').trim().isEmpty ? '$label is required' : null;

  String? _emailError(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Email is required';
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t) ? null : 'Enter a valid email';
  }

  String? _phoneError(String? v) {
    final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null; // optional
    return digits.length < 10 ? 'Enter a valid phone number' : null;
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      pageTitle: _isEdit ? 'Edit Client' : 'New Client',
      currentRoute: '/client-history',
      child: _loadingClient
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 120),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: _blue)),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final mobile = w < 700;
                final wide = w >= 1080;
                return Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _hero(mobile),
                      const SizedBox(height: 18),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _formColumn(mobile)),
                            const SizedBox(width: 18),
                            SizedBox(width: 330, child: _checklistCard()),
                          ],
                        )
                      else ...[
                        _formColumn(mobile),
                        const SizedBox(height: 16),
                        _checklistCard(),
                      ],
                      const SizedBox(height: 18),
                      _actionBar(mobile),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HERO (Back on top)
  // ─────────────────────────────────────────────────────────────

  Widget _hero(bool mobile) {
    final completed = _currentStatus == 'complete';
    final name = companyNameController.text.trim();
    final percent = _completionPercent.clamp(0, 100);

    final backButton = Material(
      color: Colors.white.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _busy ? null : () => _goBack(),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
              SizedBox(width: 6),
              Text('Client History',
                  style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );

    final statusPill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: completed ? _green : const Color(0xFFF59E0B), shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            _isEdit ? _currentStatus.toUpperCase() : 'NEW CLIENT',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: .5,
              color: completed ? const Color(0xFF15803D) : _amber,
            ),
          ),
        ],
      ),
    );

    final progress = Column(
      crossAxisAlignment: mobile ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$percent%', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        SizedBox(
          width: mobile ? double.infinity : 200,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: .22),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _isEdit ? 'Profile completion' : 'Saved profile completion',
          style: TextStyle(color: Colors.white.withValues(alpha: .8), fontSize: 11),
        ),
      ],
    );

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isEdit ? 'EDIT CLIENT' : 'CLIENT ONBOARDING',
          style: const TextStyle(color: Color(0xFFBFD5FF), fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          name.isEmpty ? (_isEdit ? 'Client Details' : 'New Client') : name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.white, fontSize: mobile ? 21 : 25, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        Text(
          _isEdit
              ? 'Update the client profile. Save returns you to Client History.'
              : 'Register a new client. Save returns you to Client History.',
          style: const TextStyle(color: Color(0xFFDCE8FF), fontSize: 11.5, height: 1.4),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.all(mobile ? 18 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_blueDark, _blue, _blueLight],
        ),
        borderRadius: BorderRadius.circular(mobile ? 20 : 24),
        boxShadow: [BoxShadow(color: _blue.withValues(alpha: .22), blurRadius: 26, offset: const Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              backButton,
              const Spacer(),
              statusPill,
            ],
          ),
          const SizedBox(height: 18),
          if (mobile) ...[
            titleBlock,
            const SizedBox(height: 16),
            progress,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: titleBlock),
                const SizedBox(width: 24),
                progress,
              ],
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FORM
  // ─────────────────────────────────────────────────────────────

  Widget _formColumn(bool mobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section(
          icon: Icons.apartment_rounded,
          title: 'Company',
          subtitle: 'Legal name and business details used on invoices and contracts.',
          children: [
            _field(
              label: 'Company Name',
              hint: 'e.g. ACME CORPORATION',
              icon: Icons.business_rounded,
              controller: companyNameController,
              upper: true,
              requiredField: true,
              validator: (v) => _required(v, 'Company name'),
            ),
            _field(
              label: 'Industry',
              hint: 'e.g. TECHNOLOGY',
              icon: Icons.category_rounded,
              controller: industryController,
              upper: true,
            ),
            _field(
              label: 'GST Number',
              hint: 'e.g. 29ABCDE1234F1Z5',
              icon: Icons.receipt_long_rounded,
              controller: gstController,
              upper: true,
            ),
          ],
          mobile: mobile,
        ),
        const SizedBox(height: 16),
        _section(
          icon: Icons.contact_phone_rounded,
          title: 'Contact',
          subtitle: 'Who we talk to at the client.',
          children: [
            _field(
              label: 'Contact Person',
              hint: 'e.g. JANE DOE',
              icon: Icons.person_rounded,
              controller: contactPersonController,
              upper: true,
              requiredField: true,
              validator: (v) => _required(v, 'Contact person'),
            ),
            _field(
              label: 'Phone Number',
              hint: 'e.g. +91 98765 43210',
              icon: Icons.phone_rounded,
              controller: phoneController,
              keyboard: TextInputType.phone,
              validator: _phoneError,
            ),
            _field(
              label: 'Email Address',
              hint: 'jane@company.com',
              icon: Icons.email_rounded,
              controller: emailController,
              keyboard: TextInputType.emailAddress,
              requiredField: true,
              validator: _emailError,
            ),
          ],
          mobile: mobile,
        ),
        const SizedBox(height: 16),
        _section(
          icon: Icons.location_on_rounded,
          title: 'Address',
          subtitle: 'Registered company address.',
          children: [
            _field(
              label: 'Company Address',
              hint: 'Street, City, State, PIN',
              icon: Icons.home_work_rounded,
              controller: addressController,
              maxLines: 3,
              full: true,
            ),
          ],
          mobile: mobile,
        ),
      ],
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
    required bool mobile,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .025), blurRadius: 16, offset: const Offset(0, 5))],
      ),
      padding: EdgeInsets.all(mobile ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: const Color(0xFFEAF2FF), borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, size: 19, color: _blue),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _ink)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 11.5, color: _muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 760 ? 3 : c.maxWidth >= 480 ? 2 : 1;
              const gap = 14.0;
              final fw = (c.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: 14,
                children: [
                  for (final f in children)
                    SizedBox(width: f is _FullWidth ? c.maxWidth : fw, child: f),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool upper = false,
    bool requiredField = false,
    bool full = false,
    int maxLines = 1,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    final field = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _text)),
            if (requiredField) const Text(' *', style: TextStyle(color: _red, fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          enabled: !_busy,
          maxLines: maxLines,
          keyboardType: keyboard ?? (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
          inputFormatters: upper ? [UpperCaseTextFormatter()] : null,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: validator,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _ink),
          cursorColor: _blue,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12.5, fontWeight: FontWeight.w400),
            prefixIcon: maxLines > 1
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Icon(icon, size: 19, color: const Color(0xFF94A3B8)),
                  )
                : Icon(icon, size: 19, color: const Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFFF8FAFD),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _blue, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _red, width: 1.5),
            ),
          ),
        ),
      ],
    );
    return full ? _FullWidth(child: field) : field;
  }

  // ─────────────────────────────────────────────────────────────
  // CHECKLIST (live)
  // ─────────────────────────────────────────────────────────────

  Widget _checklistCard() {
    final items = <(String, bool, bool)>[
      ('Company name', companyNameController.text.trim().isNotEmpty, true),
      ('Contact person', contactPersonController.text.trim().isNotEmpty, true),
      ('Valid email', _emailError(emailController.text) == null, true),
      ('Phone number', phoneController.text.trim().isNotEmpty && _phoneError(phoneController.text) == null, false),
      ('Industry', industryController.text.trim().isNotEmpty, false),
      ('GST number', gstController.text.trim().isNotEmpty, false),
      ('Address', addressController.text.trim().isNotEmpty, false),
    ];
    final done = items.where((i) => i.$2).length;
    final requiredDone = items.where((i) => i.$3).every((i) => i.$2);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .025), blurRadius: 16, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: const Color(0xFFEAF2FF), borderRadius: BorderRadius.circular(11)),
                child: const Icon(Icons.checklist_rounded, size: 19, color: _blue),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text('Profile checklist', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _ink)),
              ),
              Text('$done/${items.length}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _blue)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: done / items.length,
              minHeight: 6,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation(requiredDone ? _green : _blue),
            ),
          ),
          const SizedBox(height: 12),
          for (final i in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(
                    i.$2 ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: i.$2 ? _green : const Color(0xFFCBD5E1),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      i.$1,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: i.$2 ? _ink : _muted,
                      ),
                    ),
                  ),
                  if (i.$3)
                    const Text('Required', style: TextStyle(fontSize: 10, color: _red, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: requiredDone ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  requiredDone ? Icons.verified_rounded : Icons.info_outline_rounded,
                  size: 18,
                  color: requiredDone ? _green : _amber,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    requiredDone
                        ? 'Ready — you can Complete Registration.'
                        : 'Save any time as a draft. Fill the required fields to Complete Registration.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: requiredDone ? const Color(0xFF15803D) : _amber,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ACTIONS: Cancel · Save · Complete Registration
  // ─────────────────────────────────────────────────────────────

  Widget _actionBar(bool mobile) {
    final cancel = OutlinedButton(
      onPressed: _busy ? null : () => _goBack(),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(110, 48),
        foregroundColor: _text,
        side: const BorderSide(color: Color(0xFFD1D5DB)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      child: const Text('Cancel'),
    );

    final save = OutlinedButton.icon(
      onPressed: _busy ? null : () => _submit(complete: false),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(130, 48),
        foregroundColor: _blue,
        side: const BorderSide(color: Color(0xFF93B4EC), width: 1.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
      icon: _saving
          ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: _blue))
          : const Icon(Icons.save_rounded, size: 18),
      label: Text(_saving ? 'Saving…' : 'Save'),
    );

    final complete = ElevatedButton.icon(
      onPressed: _busy || _currentStatus == 'complete' ? null : () => _submit(complete: true),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(190, 48),
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFDCFCE7),
        disabledForegroundColor: const Color(0xFF15803D),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
      icon: _completing
          ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Icon(_currentStatus == 'complete' ? Icons.verified_rounded : Icons.task_alt_rounded, size: 18),
      label: Text(
        _completing
            ? 'Completing…'
            : _currentStatus == 'complete'
                ? 'Registration complete'
                : 'Complete Registration',
      ),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .03), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: mobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [complete, const SizedBox(height: 10), save, const SizedBox(height: 10), cancel],
            )
          : Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: _muted),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Saving takes you back to Client History.',
                    style: TextStyle(fontSize: 12, color: _muted, fontWeight: FontWeight.w600),
                  ),
                ),
                cancel,
                const SizedBox(width: 10),
                save,
                const SizedBox(width: 10),
                complete,
              ],
            ),
    );
  }
}

/// Marks a form field that should span the full row.
class _FullWidth extends StatelessWidget {
  final Widget child;
  const _FullWidth({required this.child});

  @override
  Widget build(BuildContext context) => child;
}
