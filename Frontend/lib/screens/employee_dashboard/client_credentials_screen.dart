import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../layouts/admin_layout.dart';
import '../../services/api_config.dart';

class ClientCredentialsScreen extends StatefulWidget {
  final int clientId;

  const ClientCredentialsScreen({super.key, required this.clientId});

  @override
  State<ClientCredentialsScreen> createState() => _ClientCredentialsScreenState();
}

class _ClientCredentialsScreenState extends State<ClientCredentialsScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  List<Map<String, dynamic>> _credentials = [];
  bool _loadingCredentials = true;

  @override
  void initState() {
    super.initState();
    _fetchCredentials();
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? const Color(0xFF16A34A) : Colors.redAccent,
    ));
  }

  Future<void> _fetchCredentials() async {
    setState(() => _loadingCredentials = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/credentials?clientId=${widget.clientId}'));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          _credentials = List<Map<String, dynamic>>.from(body['data']);
          _loadingCredentials = false;
        });
      } else {
        setState(() => _loadingCredentials = false);
        _showSnack('Failed to load credentials');
      }
    } catch (e) {
      setState(() => _loadingCredentials = false);
      _showSnack('Cannot connect to server');
    }
  }

  Future<String?> _createCredential(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/credentials'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({...data, 'clientId': widget.clientId}),
      );
      if (response.statusCode == 201) {
        await _fetchCredentials();
        return null;
      } else {
        final body = jsonDecode(response.body);
        return body['message'] ?? 'Failed to add credential';
      }
    } catch (e) {
      return 'Cannot connect to server';
    }
  }

  Future<String?> _updateCredential(int id, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/credentials/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      if (response.statusCode == 200) {
        await _fetchCredentials();
        return null;
      } else {
        final body = jsonDecode(response.body);
        return body['message'] ?? 'Failed to update credential';
      }
    } catch (e) {
      return 'Cannot connect to server';
    }
  }

  Future<void> _deleteCredential(int id) async {
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/credentials/$id'));
      if (response.statusCode == 200) {
        await _fetchCredentials();
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
      currentRoute: "/client-history",
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
                    "Client Credential Details",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Manage and securely store all account credentials for this client.",
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    child: const Text("Back to Details", style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _fetchCredentials,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    child: const Text("Refresh", style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showAddCredentialDialog(context),
                    icon: const Icon(Icons.add, size: 16, color: Colors.white),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0052CC),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      elevation: 0,
                    ),
                    label: const Text("Add Credential", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
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
                if (_loadingCredentials)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF0052CC))),
                  )
                else if (_credentials.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No credentials yet for this client. Click "Add Credential" to create one.',
                        style: TextStyle(color: Color(0xFF94A3B8)))),
                  )
                else
                  ..._credentials.asMap().entries.expand((entry) {
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
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
    final clientNameCtrl = TextEditingController(text: existing?['username'] ?? '');
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
                  ? await _updateCredential(existing['id'], payload)
                  : await _createCredential(payload);

              if (error == null) {
                if (context.mounted) Navigator.pop(context);
                _showSnack(isEdit ? 'Credential updated' : 'Credential added', success: true);
              } else {
                setDialogState(() { isSubmitting = false; dialogError = error; });
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 650),
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
                          isEdit ? "Edit Client Credential" : "Client Credential",
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 20),
                          onPressed: isSubmitting ? null : () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Divider(color: Color(0xFFE2E8F0), height: 1),
                    ),
                    if (dialogError != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Text(dialogError!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      children: [
                        Expanded(child: _buildDialogInputField(label: "Client Name *", hint: "", controller: clientNameCtrl)),
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
                        Expanded(child: _buildDialogInputField(label: "User Name *", hint: "", controller: userNameCtrl)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Password *", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 40,
                                child: TextField(
                                  controller: passwordCtrl,
                                  obscureText: !showPassword,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                    suffixIcon: IconButton(
                                      icon: Icon(showPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 18),
                                      onPressed: () => setDialogState(() => showPassword = !showPassword),
                                    ),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF0052CC))),
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
                        Expanded(child: _buildDialogInputField(label: "Contact Number *", hint: "", controller: contactCtrl)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildDialogInputField(label: "Email *", hint: "", controller: emailCtrl)),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: isSubmitting ? null : () => Navigator.pop(context),
                          child: const Text("Cancel"),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: isSubmitting ? null : handleSubmit,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
                          child: isSubmitting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text("Submit", style: TextStyle(color: Colors.white)),
                        ),
                      ],
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

  Widget _buildDialogInputField({required String label, required String hint, TextEditingController? controller}) {
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

  Widget _buildDialogDropdownField({required String label, required String value, required List<String> items, required ValueChanged<String?> onChanged}) {
    final safeItems = items.contains(value) ? items : [value, ...items];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
        const SizedBox(height: 6),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFCBD5E1))),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
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
              Expanded(flex: 3, child: Text(username, style: const TextStyle(fontSize: 13, color: Color(0xFF475569)))),
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
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFFCBD5E1)),
                      onPressed: () => _showAddCredentialDialog(context, existing: {
                        'id': id, 'username': username, 'password': pass,
                        'platform': platform, 'contact_number': phone, 'email': email,
                      }),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFCBD5E1)),
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
                                _deleteCredential(id);
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