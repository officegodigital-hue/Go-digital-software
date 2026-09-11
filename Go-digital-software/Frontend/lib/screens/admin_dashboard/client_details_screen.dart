// name=client_details_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../layouts/admin_layout.dart';
import 'client_history_screen.dart';
import '../../services/api_config.dart';
import 'client_credentials_screen.dart';
import '../../services/auth_service.dart';
import 'package:provider/provider.dart';

class ClientDetailsScreen extends StatefulWidget {
  final int? clientId;

  const ClientDetailsScreen({super.key, this.clientId});

  @override
  State<ClientDetailsScreen> createState() => _ClientDetailsScreenState();
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

class _ClientDetailsScreenState extends State<ClientDetailsScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

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
  bool _savingDraft = false;
  bool _completing = false;

  // ---------------------------------------------------------------------------
  // INIT
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _clientId = widget.clientId;

    if (_clientId != null) {
      _loadClient();
    }
  }

  @override
  void dispose() {
    companyNameController.dispose();
    contactPersonController.dispose();
    emailController.dispose();
    addressController.dispose();
    industryController.dispose();
    phoneController.dispose();
    gstController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // AUTH
  // ---------------------------------------------------------------------------

  bool _isMainAdmin() {
    final authService = Provider.of<AuthService>(
      context,
      listen: false,
    );

    final user = authService.user;

    return user?['is_main_admin'] == true ||
        user?['is_main_admin'] == 1 ||
        user?['is_main_admin'].toString() == '1';
  }

  // ---------------------------------------------------------------------------
  // SNACKBAR
  // ---------------------------------------------------------------------------

  void _showSnack(
    String msg, {
    bool success = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Row(
          children: [
            Icon(
              success
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor:
            success ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LOAD CLIENT
  // ---------------------------------------------------------------------------

  Future<void> _loadClient() async {
    setState(() => _loadingClient = true);

    try {
      final authService = Provider.of<AuthService>(
        context,
        listen: false,
      );

      final token = authService.token;

      final response = await http.get(
        Uri.parse('$_baseUrl/clients/$_clientId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final c = body['data'];

        setState(() {
          companyNameController.text = c['company_name'] ?? '';
          contactPersonController.text = c['contact_person'] ?? '';
          emailController.text = c['email'] ?? '';
          addressController.text = c['address'] ?? '';
          industryController.text = c['industry'] ?? '';
          phoneController.text = c['client_phone'] ?? '';
          gstController.text = c['gst_number'] ?? '';

          _currentStatus = c['status'] ?? 'draft';
          _completionPercent = c['completion_percent'] ?? 0;
          _loadingClient = false;
        });
      } else {
        setState(() => _loadingClient = false);
        _showSnack('Failed to load client details');
      }
    } catch (e) {
      setState(() => _loadingClient = false);
      _showSnack('Cannot connect to server');
    }
  }

  // ---------------------------------------------------------------------------
  // PAYLOAD
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _clientPayload(String status) {
    return {
      'companyName': companyNameController.text.trim(),
      'industry': industryController.text.trim(),
      'contactPerson': contactPersonController.text.trim(),
      'email': emailController.text.trim(),
      'address': addressController.text.trim(),
      'clientPhone': phoneController.text.trim(),
      'gstNumber': gstController.text.trim(),
      'status': status,
    };
  }

  // ---------------------------------------------------------------------------
  // SAVE DRAFT
  // ---------------------------------------------------------------------------

  Future<void> _saveDraft() async {
    if (companyNameController.text.trim().isEmpty) {
      _showSnack('Please enter the Company Legal Name first');
      return;
    }

    setState(() => _savingDraft = true);

    try {
      final authService = Provider.of<AuthService>(
        context,
        listen: false,
      );

      final token = authService.token;
      final bool mainAdmin = _isMainAdmin();

      http.Response response;

      final status =
          (_currentStatus == 'draft') ? 'draft' : _currentStatus;

      if (_clientId == null) {
        response = await http.post(
          Uri.parse('$_baseUrl/clients'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(_clientPayload('draft')),
        );
      } else {
        response = await http.put(
          Uri.parse('$_baseUrl/clients/$_clientId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(_clientPayload(status)),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);

        if (_clientId == null && body['data'] != null) {
          setState(() {
            _clientId = body['data']['id'];
            _currentStatus = 'draft';
            _completionPercent =
                body['data']['completion_percent'] ?? 30;
          });
        }

        _showSnack(
          'Draft saved successfully',
          success: true,
        );

        if (_clientId != null && mainAdmin) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClientCredentialsScreen(
                clientId: _clientId!,
              ),
            ),
          );
        } else {
          Navigator.pop(context);
        }
      } else {
        debugPrint(
          'Save failed: ${response.statusCode} - ${response.body}',
        );

        _showSnack(
          'Failed to save draft (${response.statusCode})',
        );
      }
    } catch (e) {
      debugPrint('Save error: $e');
      _showSnack('Cannot connect to server');
    } finally {
      setState(() => _savingDraft = false);
    }
  }

  // ---------------------------------------------------------------------------
  // COMPLETE REGISTRATION
  // ---------------------------------------------------------------------------

  Future<void> _completeRegistration() async {
    if (companyNameController.text.trim().isEmpty ||
        contactPersonController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty) {
      _showSnack(
        'Please fill Company Name, Contact Person and Email before completing registration',
      );
      return;
    }

    setState(() => _completing = true);

    try {
      final authService = Provider.of<AuthService>(
        context,
        listen: false,
      );

      final token = authService.token;
      final bool mainAdmin = _isMainAdmin();

      http.Response response;

      if (_clientId == null) {
        response = await http.post(
          Uri.parse('$_baseUrl/clients'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(_clientPayload('complete')),
        );
      } else {
        response = await http.put(
          Uri.parse('$_baseUrl/clients/$_clientId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(_clientPayload('complete')),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);

        if (_clientId == null && body['data'] != null) {
          _clientId = body['data']['id'];
        }

        setState(() {
          _currentStatus = 'complete';
          _completionPercent = 100;
        });

        _showSnack(
          'Registration completed — 100% complete',
          success: true,
        );

        if (_clientId != null && mainAdmin) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ClientCredentialsScreen(
                clientId: _clientId!,
              ),
            ),
          );
        } else {
          Navigator.pop(context);
        }
      } else {
        debugPrint(
          'Complete failed: ${response.statusCode} - ${response.body}',
        );

        _showSnack(
          'Failed to complete registration (${response.statusCode})',
        );
      }
    } catch (e) {
      debugPrint('Complete error: $e');
      _showSnack('Cannot connect to server');
    } finally {
      setState(() => _completing = false);
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bool mainAdmin = _isMainAdmin();

    return AdminLayout(
      pageTitle: "Client Details",
      currentRoute: "/client-history",
      child: _loadingClient
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(60),
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF2563EB),
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final bool isMobile = constraints.maxWidth < 700;
                final bool isTablet = constraints.maxWidth >= 700 &&
                    constraints.maxWidth < 1050;

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    left: isMobile ? 14 : 28,
                    right: isMobile ? 14 : 28,
                    top: isMobile ? 16 : 26,
                    bottom: 40,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPageHeader(
                        isMobile: isMobile,
                        mainAdmin: mainAdmin,
                      ),

                      const SizedBox(height: 24),

                      _buildProgressCard(
                        isMobile: isMobile,
                      ),

                      const SizedBox(height: 22),

                      if (isMobile)
                        Column(
                          children: [
                            _buildFormCard(
                              title: "Primary Company Details",
                              subtitle:
                                  "Legal information for billing and contract management.",
                              child: _buildFormContent(
                                isMobile: true,
                              ),
                            ),
                            const SizedBox(height: 18),
                            _buildPartnerCard(
                              mainAdmin: mainAdmin,
                              isMobile: true,
                            ),
                          ],
                        )
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: isTablet ? 5 : 3,
                              child: _buildFormCard(
                                title: "Primary Company Details",
                                subtitle:
                                    "Legal information for billing and contract management.",
                                child: _buildFormContent(
                                  isMobile: false,
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: isTablet ? 2 : 1,
                              child: _buildPartnerCard(
                                mainAdmin: mainAdmin,
                                isMobile: false,
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 22),

                      _buildBottomActions(
                        mainAdmin: mainAdmin,
                        isMobile: isMobile,
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // PAGE HEADER
  // ---------------------------------------------------------------------------

  Widget _buildPageHeader({
    required bool isMobile,
    required bool mainAdmin,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 18 : 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderTitle(),
                const SizedBox(height: 18),
                _buildStatusBadge(),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: _buildHeaderTitle(),
                ),
                _buildStatusBadge(),
              ],
            ),
    );
  }

  Widget _buildHeaderTitle() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.business_rounded,
            color: Color(0xFF2563EB),
            size: 23,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Client Details",
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _clientId == null
                    ? "Register a new enterprise partner and configure their profile."
                    : "Update and manage the registered client profile.",
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF6B7280),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STATUS BADGE
  // ---------------------------------------------------------------------------

  Widget _buildStatusBadge() {
    final bool completed = _currentStatus == 'complete';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: completed
            ? const Color(0xFFECFDF5)
            : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: completed
              ? const Color(0xFFBBF7D0)
              : const Color(0xFFFDE68A),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: completed
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFF59E0B),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            completed ? "REGISTRATION COMPLETE" : "DRAFT PROFILE",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: .5,
              color: completed
                  ? const Color(0xFF15803D)
                  : const Color(0xFFB45309),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PROGRESS CARD
  // ---------------------------------------------------------------------------

  Widget _buildProgressCard({
    required bool isMobile,
  }) {
    final double progress =
        (_completionPercent.clamp(0, 100)) / 100;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProgressText(),
                const SizedBox(height: 13),
                _buildProgressBar(progress),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: _buildProgressText(),
                ),
                const SizedBox(width: 30),
                SizedBox(
                  width: 250,
                  child: _buildProgressBar(progress),
                ),
              ],
            ),
    );
  }

  Widget _buildProgressText() {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.auto_graph_rounded,
            color: Color(0xFF2563EB),
            size: 19,
          ),
        ),
        const SizedBox(width: 11),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Profile completion",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _completionPercent == 100
                  ? "All required information completed"
                  : "Complete the required information to finish registration",
              style: const TextStyle(
                fontSize: 10.5,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressBar(double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          "$_completionPercent%",
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2563EB),
          ),
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: const Color(0xFFE5E7EB),
            color: const Color(0xFF2563EB),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // FORM CONTENT
  // ---------------------------------------------------------------------------

  Widget _buildFormContent({
    required bool isMobile,
  }) {
    if (isMobile) {
      return Column(
        children: [
          _buildInputField(
            label: "Company Name",
            hint: "e.g. Acme Corporation",
            controller: companyNameController,
            inputFormatters: [
              UpperCaseTextFormatter(),
            ],
          ),
          const SizedBox(height: 18),
          _buildInputField(
            label: "Industry Vertical",
            hint: "e.g. Technology",
            controller: industryController,
            inputFormatters: [
              UpperCaseTextFormatter(),
            ],
          ),
          const SizedBox(height: 18),
          _buildInputField(
            label: "Contact Person",
            hint: "Jane Doe",
            controller: contactPersonController,
            inputFormatters: [
              UpperCaseTextFormatter(),
            ],
          ),
          const SizedBox(height: 18),
          _buildInputField(
            label: "Phone Number",
            hint: "e.g. +91 98765 43210",
            controller: phoneController,
          ),
          const SizedBox(height: 18),
          _buildInputField(
            label: "GST Number",
            hint: "e.g. 29ABCDE1234F1Z5",
            controller: gstController,
            inputFormatters: [
              UpperCaseTextFormatter(),
            ],
          ),
          const SizedBox(height: 18),
          _buildInputField(
            label: "Email Address",
            hint: "jane@company.com",
            controller: emailController,
          ),
          const SizedBox(height: 18),
          _buildInputField(
            label: "Company Address",
            hint: "Street, City, Country, ZIP",
            controller: addressController,
            maxLines: 4,
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxWidth < 720;

        if (compact) {
          return Column(
            children: [
              _buildInputField(
                label: "Company Name",
                hint: "e.g. Acme Corporation",
                controller: companyNameController,
                inputFormatters: [
                  UpperCaseTextFormatter(),
                ],
              ),
              const SizedBox(height: 18),
              _buildInputField(
                label: "Industry Vertical",
                hint: "e.g. Technology",
                controller: industryController,
                inputFormatters: [
                  UpperCaseTextFormatter(),
                ],
              ),
              const SizedBox(height: 18),
              _buildInputField(
                label: "Contact Person",
                hint: "Jane Doe",
                controller: contactPersonController,
                inputFormatters: [
                  UpperCaseTextFormatter(),
                ],
              ),
              const SizedBox(height: 18),
              _buildInputField(
                label: "Phone Number",
                hint: "e.g. +91 98765 43210",
                controller: phoneController,
              ),
              const SizedBox(height: 18),
              _buildInputField(
                label: "GST Number",
                hint: "e.g. 29ABCDE1234F1Z5",
                controller: gstController,
                inputFormatters: [
                  UpperCaseTextFormatter(),
                ],
              ),
              const SizedBox(height: 18),
              _buildInputField(
                label: "Email Address",
                hint: "jane@company.com",
                controller: emailController,
              ),
              const SizedBox(height: 18),
              _buildInputField(
                label: "Company Address",
                hint: "Street, City, Country, ZIP",
                controller: addressController,
                maxLines: 4,
              ),
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    label: "Company Name",
                    hint: "e.g. Acme Corporation",
                    controller: companyNameController,
                    inputFormatters: [
                      UpperCaseTextFormatter(),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _buildInputField(
                    label: "Industry Vertical",
                    hint: "e.g. Technology",
                    controller: industryController,
                    inputFormatters: [
                      UpperCaseTextFormatter(),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    label: "Contact Person",
                    hint: "Jane Doe",
                    controller: contactPersonController,
                    inputFormatters: [
                      UpperCaseTextFormatter(),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _buildInputField(
                    label: "Phone Number",
                    hint: "e.g. +91 98765 43210",
                    controller: phoneController,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    label: "GST Number",
                    hint: "e.g. 29ABCDE1234F1Z5",
                    controller: gstController,
                    inputFormatters: [
                      UpperCaseTextFormatter(),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _buildInputField(
                    label: "Email Address",
                    hint: "jane@company.com",
                    controller: emailController,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildInputField(
              label: "Company Address",
              hint: "Street, City, Country, ZIP",
              controller: addressController,
              maxLines: 4,
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // FORM CARD
  // ---------------------------------------------------------------------------

  Widget _buildFormCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.025),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 18,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.domain_rounded,
                    size: 19,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: child,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PARTNER CARD
  // ---------------------------------------------------------------------------

  Widget _buildPartnerCard({
    required bool mainAdmin,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E3A8A),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withOpacity(.12),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.10),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: Colors.white.withOpacity(.12),
                  ),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  "Partner Excellence",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Text(
            "GoDigital partners represent the top 5% of digital-first enterprises.",
            style: TextStyle(
              color: Colors.white.withOpacity(.88),
              fontSize: 12,
              height: 1.55,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            "Accurate information at this stage helps streamline billing, contracts and the complete client lifecycle.",
            style: TextStyle(
              color: Colors.white.withOpacity(.65),
              fontSize: 11,
              height: 1.55,
            ),
          ),

          const SizedBox(height: 20),

          _buildInfoRow(
            Icons.verified_user_outlined,
            "Verified client profile",
          ),
          const SizedBox(height: 11),
          _buildInfoRow(
            Icons.receipt_long_outlined,
            "Billing-ready information",
          ),
          const SizedBox(height: 11),
          _buildInfoRow(
            Icons.account_tree_outlined,
            "Centralized client lifecycle",
          ),

          if (_clientId != null && mainAdmin) ...[
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1D4ED8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClientCredentialsScreen(
                        clientId: _clientId!,
                      ),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.key_rounded,
                  size: 17,
                ),
                label: const Text(
                  "Manage Credentials",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String text,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(.72),
          size: 16,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(.78),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // INPUT FIELD
  // ---------------------------------------------------------------------------

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF374151),
              ),
            ),
            if (label == "Company Name" ||
                label == "Contact Person" ||
                label == "Email Address") ...[
              const SizedBox(width: 3),
              const Text(
                "*",
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF111827),
          ),
          cursorColor: const Color(0xFF2563EB),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: maxLines > 1 ? 13 : 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFFE5E7EB),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFFE5E7EB),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFF2563EB),
                width: 1.5,
              ),
            ),
            hoverColor: Colors.transparent,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // BOTTOM ACTIONS
  // ---------------------------------------------------------------------------

  Widget _buildBottomActions({
    required bool mainAdmin,
    required bool isMobile,
  }) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_rounded,
              size: 17,
            ),
            style: _outlineButtonStyle(),
            label: const Text("Back"),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _savingDraft ? null : _saveDraft,
            style: _outlineButtonStyle(),
            child: _savingDraft
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF475569),
                    ),
                  )
                : Text(
                    mainAdmin
                        ? "Save & Next — Credentials"
                        : "Save Draft",
                  ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _completing ? null : _completeRegistration,
            style: _primaryButtonStyle(),
            child: _completing
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    mainAdmin
                        ? "Complete & View Credentials"
                        : "Complete Registration",
                  ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_rounded,
              size: 16,
            ),
            style: _outlineButtonStyle(),
            label: const Text("Back"),
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: _savingDraft ? null : _saveDraft,
            style: _outlineButtonStyle(),
            child: _savingDraft
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF475569),
                    ),
                  )
                : Text(
                    mainAdmin
                        ? "Save & Next — Credentials"
                        : "Save Draft",
                  ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _completing ? null : _completeRegistration,
            style: _primaryButtonStyle(),
            child: _completing
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    mainAdmin
                        ? "Complete & View Credentials"
                        : "Complete Registration",
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUTTON STYLES
  // ---------------------------------------------------------------------------

  ButtonStyle _outlineButtonStyle() {
    return OutlinedButton.styleFrom(
      minimumSize: const Size(120, 44),
      padding: const EdgeInsets.symmetric(
        horizontal: 17,
        vertical: 12,
      ),
      side: const BorderSide(
        color: Color(0xFFD1D5DB),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      foregroundColor: const Color(0xFF374151),
      textStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  ButtonStyle _primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      minimumSize: const Size(150, 44),
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 12,
      ),
      backgroundColor: const Color(0xFF2563EB),
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      textStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}