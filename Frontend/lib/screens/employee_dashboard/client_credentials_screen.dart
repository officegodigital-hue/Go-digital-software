// name=client_credentials_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../layouts/admin_layout.dart';
import '../../services/api_config.dart';
import '../../services/auth_service.dart';

class ClientCredentialsScreen extends StatefulWidget {
  final int? clientId; // Nullable if viewing the master client list first

  const ClientCredentialsScreen({super.key, this.clientId});

  @override
  State<ClientCredentialsScreen> createState() => _ClientCredentialsScreenState();
}

class _ClientCredentialsScreenState extends State<ClientCredentialsScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _credentials = [];
  bool _loadingData = true;

  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  int? _selectedClientId;
  String? _selectedClientName;

  @override
  void initState() {
    super.initState();
    _selectedClientId = widget.clientId;
    if (_selectedClientId != null) {
      _fetchCredentialsForClient(_selectedClientId!);
    } else {
      _fetchClientsList();
    }
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? const Color(0xFF16A34A) : Colors.redAccent,
    ));
  }

  // Fetch all clients for the first selection page
  Future<void> _fetchClientsList() async {
    setState(() => _loadingData = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = authService.token;

      final response = await http.get(
        Uri.parse('$_baseUrl/clients'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          _clients = List<Map<String, dynamic>>.from(body['data'] ?? []);
          _loadingData = false;
        });
      } else {
        setState(() => _loadingData = false);
        _showSnack('Failed to load clients');
      }
    } catch (e) {
      setState(() => _loadingData = false);
      _showSnack('Cannot connect to server');
    }
  }

  // Fetch credentials for a specific client
  Future<void> _fetchCredentialsForClient(int clientId) async {
    setState(() => _loadingData = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = authService.token;

      final response = await http.get(
        Uri.parse('$_baseUrl/credentials?clientId=$clientId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          _credentials = List<Map<String, dynamic>>.from(body['data'] ?? []);
          _loadingData = false;
        });
      } else {
        setState(() => _loadingData = false);
        _showSnack('Failed to load credentials');
      }
    } catch (e) {
      setState(() => _loadingData = false);
      _showSnack('Cannot connect to server');
    }
  }

  Future<String?> _createCredential(Map<String, dynamic> data, int targetClientId) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = authService.token;

      final response = await http.post(
        Uri.parse('$_baseUrl/credentials'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({...data, 'clientId': targetClientId}),
      );
      if (response.statusCode == 201) {
        await _fetchCredentialsForClient(targetClientId);
        return null;
      } else {
        final body = jsonDecode(response.body);
        return body['message'] ?? 'Failed to add credential';
      }
    } catch (e) {
      return 'Cannot connect to server';
    }
  }

  Future<String?> _updateCredential(int id, Map<String, dynamic> data, int targetClientId) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = authService.token;

      final response = await http.put(
        Uri.parse('$_baseUrl/credentials/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );
      if (response.statusCode == 200) {
        await _fetchCredentialsForClient(targetClientId);
        return null;
      } else {
        final body = jsonDecode(response.body);
        return body['message'] ?? 'Failed to update credential';
      }
    } catch (e) {
      return 'Cannot connect to server';
    }
  }

  Future<void> _deleteCredential(int id, int targetClientId) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = authService.token;

      final response = await http.delete(
        Uri.parse('$_baseUrl/credentials/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        await _fetchCredentialsForClient(targetClientId);
        _showSnack('Credential deleted', success: true);
      } else {
        _showSnack('Failed to delete credential');
      }
    } catch (e) {
      _showSnack('Cannot connect to server');
    }
  }

  DateTime? _parseDate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      if (iso.contains('T')) {
        return DateTime.parse(iso).toLocal();
      }
      return DateTime.parse('${iso.replaceFirst(' ', 'T')}Z').toLocal();
    } catch (_) {
      return null;
    }
  }

  String _formatDate(String? isoDate) {
    final dt = _parseDate(isoDate);
    if (dt == null) return '';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatTime(String? isoDate) {
    final dt = _parseDate(isoDate);
    if (dt == null) return '';
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      pageTitle: "Client Credentials",
      currentRoute: "/client-credentials",
      child: _selectedClientId == null ? _buildClientListView() : _buildCredentialsDetailView(),
    );
  }

  // ── PART 1: FIRST PAGE - CLIENT NAMES LIST VIEW ──────────────────────────
  Widget _buildClientListView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF0052CC),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0052CC).withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'CREDENTIALS DIRECTORY',
                      style: TextStyle(color: Color(0xFFBFD5FF), fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'Select a Client',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Choose a client below to view and manage their account credentials securely.',
                      style: TextStyle(color: Color(0xFFDCE8FF), fontSize: 11, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.025), blurRadius: 22, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: const Color(0xFFF8FAFC),
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: const [
                    Expanded(flex: 1, child: Text("S.NO", style: _tableHeaderStyle)),
                    Expanded(flex: 6, child: Text("CLIENT NAME", style: _tableHeaderStyle)),
                    Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text("ACTION", style: _tableHeaderStyle))),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              _loadingData
                  ? const Padding(
                      padding: EdgeInsets.all(54),
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF0052CC))),
                    )
                  : _clients.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(54),
                          child: Center(child: Text('No active clients found.', style: TextStyle(color: Color(0xFF94A3B8)))),
                        )
                      : SizedBox(
                          height: 400,
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            itemCount: _clients.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            itemBuilder: (context, index) {
                              final client = _clients[index];
                              final cId = client['id'] is int ? client['id'] : int.tryParse(client['id'].toString()) ?? 0;
                              final cName = client['company_name'] ?? client['client_name'] ?? 'Unknown Client';

                              return Container(
                                height: 60,
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                color: Colors.white,
                                child: Row(
                                  children: [
                                    Expanded(flex: 1, child: Text((index + 1).toString(), style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600))),
                                    Expanded(flex: 6, child: Text(cName, style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B), fontWeight: FontWeight.w800))),
                                    Expanded(
                                      flex: 2,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            setState(() {
                                              _selectedClientId = cId;
                                              _selectedClientName = cName;
                                            });
                                            _fetchCredentialsForClient(cId);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF0052CC),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          ),
                                          child: const Text("View Credentials", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
            ],
          ),
        ),
      ],
    );
  }

  // ── PART 2: SECOND PAGE - CREDENTIALS DETAIL VIEW ────────────────────────
  Widget _buildCredentialsDetailView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF0052CC),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0052CC).withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CREDENTIALS CENTER',
                      style: TextStyle(color: Color(0xFFBFD5FF), fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _selectedClientName != null ? 'Credentials for: $_selectedClientName' : 'Client Credential Details',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Manage and securely store all account credentials for this client.',
                      style: TextStyle(color: Color(0xFFDCE8FF), fontSize: 11, height: 1.35),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 10,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedClientId = null;
                        _selectedClientName = null;
                      });
                      _fetchClientsList();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    ),
                    child: const Text("Back to Clients", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  OutlinedButton(
                    onPressed: () => _fetchCredentialsForClient(_selectedClientId!),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    ),
                    child: const Text("Refresh", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddCredentialDialog(context),
                    icon: const Icon(Icons.add, size: 16, color: Color(0xFF0052CC)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                    ),
                    label: const Text("Add Credential", style: TextStyle(color: Color(0xFF0052CC), fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Scrollbar(
                controller: _horizontalController,
                thumbVisibility: true,
                interactive: true,
                notificationPredicate: (notification) => notification.metrics.axis == Axis.horizontal,
                child: SingleChildScrollView(
                  controller: _horizontalController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: SizedBox(
                    width: 1200,
                    child: Column(
                      children: [
                        Container(
                          color: const Color(0xFFF8FAFC),
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: const [
                              Expanded(flex: 3, child: Text("USER NAME", style: _tableHeaderStyle)),
                              Expanded(flex: 3, child: Text("PASSWORD", style: _tableHeaderStyle)),
                              Expanded(flex: 3, child: Text("PLATFORM", style: _tableHeaderStyle)),
                              Expanded(flex: 4, child: Text("CONTACT NUMBER / EMAIL", style: _tableHeaderStyle)),
                              Expanded(flex: 3, child: Text("LAST UPDATED", style: _tableHeaderStyle)),
                              Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text("ACTIONS", style: _tableHeaderStyle))),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        _loadingData
                            ? const Padding(
                                padding: EdgeInsets.all(54),
                                child: Center(child: CircularProgressIndicator(color: Color(0xFF0052CC))),
                              )
                            : _credentials.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(54),
                                    child: Center(child: Text('No credentials yet for this client. Click "Add Credential" to create one.',
                                        style: TextStyle(color: Color(0xFF94A3B8)))),
                                  )
                                : SizedBox(
                                    height: 400,
                                    child: Scrollbar(
                                      controller: _verticalController,
                                      thumbVisibility: true,
                                      interactive: true,
                                      notificationPredicate: (notification) => notification.metrics.axis == Axis.vertical,
                                      child: SingleChildScrollView(
                                        controller: _verticalController,
                                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                        child: Column(
                                          children: _credentials.asMap().entries.expand((entry) {
                                            final i = entry.key;
                                            final c = entry.value;
                                            final row = _buildCredentialRow(
                                              c['id'],
                                              c['username'] ?? '',
                                              c['password'] ?? '',
                                              c['platform'] ?? '',
                                              c['contact_number'] ?? '',
                                              c['email'] ?? '',
                                              _formatDate(c['updated_at']?.toString()),
                                              _formatTime(c['updated_at']?.toString()),
                                            );
                                            if (i < _credentials.length - 1) {
                                              return [row, const Divider(height: 1, color: Color(0xFFE2E8F0))];
                                            }
                                            return [row];
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ── PART 3: PREMIUM MODERN REDESIGNED POPUP MODAL ────────────────────────
  void _showAddCredentialDialog(BuildContext context, {Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    const basePlatforms = [
      'Facebook', 'Instagram', 'YouTube', 'Google Ads', 'Meta Ads', 'LinkedIn', 'WhatsApp Business', 'Mail id',
      'Google Business Profile', 'Server Login',
    ];

    final usedPlatforms = _credentials
        .map((c) => c['platform']?.toString() ?? '')
        .where((p) => !isEdit || p != existing['platform'])
        .toSet();

    final availablePlatforms = [
      'Select',
      ...basePlatforms.where((p) => !usedPlatforms.contains(p)),
      'Others',
    ];

    final existingPlatform = existing?['platform'] ?? '';
    final isCustomPlatform = isEdit && existingPlatform.isNotEmpty && !basePlatforms.contains(existingPlatform);

    String dialogSelectedPlatform = isEdit
        ? (isCustomPlatform ? 'Others' : existingPlatform)
        : 'Select';

    final otherPlatformCtrl = TextEditingController(text: isCustomPlatform ? existingPlatform : '');
    
    // 🟢 Default Client Name set automatically based on current selected client
    final clientNameCtrl = TextEditingController(text: isEdit ? (existing?['client_name'] ?? _selectedClientName ?? '') : (_selectedClientName ?? ''));
    
    final userNameCtrl = TextEditingController(text: existing?['username'] ?? '');
    final passwordCtrl = TextEditingController(text: existing?['password'] ?? '');
    final contactCtrl = TextEditingController(text: existing?['contact_number'] ?? '');
    final emailCtrl = TextEditingController(text: existing?['email'] ?? '');

    bool isSubmitting = false;
    String? dialogError;
    bool showPassword = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> handleSubmit() async {
              final finalPlatform = dialogSelectedPlatform == 'Others'
                  ? otherPlatformCtrl.text.trim()
                  : dialogSelectedPlatform;

              if (userNameCtrl.text.trim().isEmpty ||
                  passwordCtrl.text.trim().isEmpty ||
                  dialogSelectedPlatform == 'Select' ||
                  finalPlatform.isEmpty) {
                setDialogState(() => dialogError = dialogSelectedPlatform == 'Others' && finalPlatform.isEmpty
                    ? 'Please specify the platform name'
                    : 'Please fill all required fields (*)');
                return;
              }

              setDialogState(() { isSubmitting = true; dialogError = null; });

              final payload = {
                'username': userNameCtrl.text.trim(),
                'password': passwordCtrl.text.trim(),
                'platform': finalPlatform,
                'contactNumber': contactCtrl.text.trim(),
                'email': emailCtrl.text.trim(),
              };

              final error = isEdit
                  ? await _updateCredential(existing['id'], payload, _selectedClientId!)
                  : await _createCredential(payload, _selectedClientId!);

              if (error == null) {
                if (context.mounted) Navigator.pop(context);
                _showSnack(isEdit ? 'Credential updated' : 'Credential added', success: true);
              } else {
                setDialogState(() { isSubmitting = false; dialogError = error; });
              }
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 620),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Premium Header Banner inside Modal
                    Container(
                      padding: const EdgeInsets.fromLTRB(26, 24, 20, 20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF003B95), Color(0xFF0052CC)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isEdit ? "Edit Account Credential" : "New Account Credential",
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.3),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _selectedClientName != null ? 'Client: $_selectedClientName' : 'Secure Vault Entry',
                                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                            onPressed: isSubmitting ? null : () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            splashRadius: 20,
                          ),
                        ],
                      ),
                    ),

                    // Modal Content Body
                    Padding(
                      padding: const EdgeInsets.fromLTRB(26, 22, 26, 26),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (dialogError != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: Text(dialogError!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                            ),
                            const SizedBox(height: 18),
                          ],
                          Row(
                            children: [
                              Expanded(child: _buildDialogInputField(label: "Client Name *", hint: "", controller: clientNameCtrl, enabled: false)),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildDialogDropdownField(
                                  label: "Platform *",
                                  value: dialogSelectedPlatform,
                                  items: availablePlatforms,
                                  onChanged: (val) => setDialogState(() => dialogSelectedPlatform = val!),
                                ),
                              ),
                            ],
                          ),
                          if (dialogSelectedPlatform == 'Others') ...[
                            const SizedBox(height: 16),
                            _buildDialogInputField(label: "Specify Platform Name *", hint: "e.g. Pinterest, Twitter/X", controller: otherPlatformCtrl),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildDialogInputField(label: "User Name *", hint: "Enter username/id", controller: userNameCtrl)),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Password *", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF334155))),
                                    const SizedBox(height: 7),
                                    Container(
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: TextField(
                                        controller: passwordCtrl,
                                        obscureText: !showPassword,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                        decoration: InputDecoration(
                                          hintText: 'Enter password',
                                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                          filled: false,
                                          contentPadding: const EdgeInsets.fromLTRB(14, 10, 0, 10),
                                          border: InputBorder.none,
                                          suffixIcon: IconButton(
                                            icon: Icon(showPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 18, color: const Color(0xFF64748B)),
                                            onPressed: () => setDialogState(() => showPassword = !showPassword),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildDialogInputField(label: "Contact Number *", hint: "+91 ...", controller: contactCtrl)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildDialogInputField(label: "Email *", hint: "client@email.com", controller: emailCtrl)),
                            ],
                          ),
                          const SizedBox(height: 28),
                          // Modal Footer Action Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              SizedBox(
                                height: 42,
                                child: OutlinedButton(
                                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF64748B),
                                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                  ),
                                  child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.w700)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                height: 42,
                                child: ElevatedButton(
                                  onPressed: isSubmitting ? null : handleSubmit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0052CC),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
                                  ),
                                  child: isSubmitting
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : Text(isEdit ? "Save Changes" : "Save Credential", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDialogInputField({required String label, required String hint, TextEditingController? controller, bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF334155))),
        const SizedBox(height: 7),
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: TextField(
            controller: controller,
            enabled: enabled,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: enabled ? const Color(0xFF1E293B) : const Color(0xFF64748B)),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              filled: false,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDialogDropdownField({required String label, required String value, required List<String> items, required ValueChanged<String?> onChanged}) {
    final safeItems = items.contains(value) ? items : [value, ...items];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF334155))),
        const SizedBox(height: 7),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 20),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              items: safeItems.map((item) => DropdownMenuItem(value: item, child: Text(item, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCredentialRow(int id, String username, String pass, String platform, String phone, String email, String date, String time) {
    bool showPassword = false;
    return StatefulBuilder(
      builder: (context, setRowState) {
        return Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(flex: 3, child: Text(username, style: const TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w600))),
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        showPassword ? pass : '•' * (pass.length > 12 ? 12 : pass.length),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), letterSpacing: 1.5),
                      ),
                    ),
                    IconButton(
                      icon: Icon(showPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 16, color: const Color(0xFF94A3B8)),
                      onPressed: () => setRowState(() => showPassword = !showPassword),
                    ),
                  ],
                ),
              ),
              Expanded(flex: 3, child: Text(platform, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(phone, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                    Text(email, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(date, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                    Text(time, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0052CC)),
                      onPressed: () => _showAddCredentialDialog(context, existing: {
                        'id': id, 'username': username, 'password': pass,
                        'platform': platform, 'contact_number': phone, 'email': email,
                      }),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete Credential'),
                          content: Text('Remove credential for "$username"?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _deleteCredential(id, _selectedClientId!);
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                              child: const Text('Delete', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
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

  static const TextStyle _tableHeaderStyle = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5,
  );
}

