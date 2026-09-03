import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../layouts/admin_layout.dart';
import '../../services/api_config.dart';
import '../../services/auth_service.dart';

class ClientCredentialsScreen extends StatefulWidget {
  final int? clientId;

  const ClientCredentialsScreen({
    super.key,
    this.clientId,
  });

  @override
  State<ClientCredentialsScreen> createState() =>
      _ClientCredentialsScreenState();
}

class _ClientCredentialsScreenState extends State<ClientCredentialsScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  // ---------------------------------------------------------------------------
  // DATA
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _credentials = [];

  bool _loadingClients = true;
  bool _loadingCredentials = false;
  bool _savingCredential = false;

  int? _selectedClientId;
  String? _selectedClientName;

  Map<String, dynamic>? _selectedClient;

  // ---------------------------------------------------------------------------
  // FORM
  // ---------------------------------------------------------------------------

  final TextEditingController _clientNameController =
      TextEditingController();

  final TextEditingController _otherPlatformController =
      TextEditingController();

  final TextEditingController _usernameController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  final TextEditingController _contactController =
      TextEditingController();

  final TextEditingController _emailController =
      TextEditingController();

  String _selectedPlatform = 'Select';
  bool _showPassword = false;

  int? _editingCredentialId;

// Each credential row password visibility
final Map<int, bool> _visiblePasswords = {};
  // ---------------------------------------------------------------------------
  // SEARCH
  // ---------------------------------------------------------------------------

  String _searchQuery = '';

  // ---------------------------------------------------------------------------
  // SCROLL
  // ---------------------------------------------------------------------------

  final ScrollController _clientScrollController = ScrollController();
  final ScrollController _credentialVerticalController = ScrollController();
  final ScrollController _credentialHorizontalController =
      ScrollController();

  // ---------------------------------------------------------------------------
  // PLATFORM LIST
  // ---------------------------------------------------------------------------

  static const List<String> _basePlatforms = [
    'Facebook',
    'Instagram',
    'YouTube',
    'Google Ads',
    'Meta Ads',
    'LinkedIn',
    'WhatsApp Business',
    'Mail id',
    'Google Business Profile',
    'Server Login',
  ];

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _otherPlatformController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _contactController.dispose();
    _emailController.dispose();

    _clientScrollController.dispose();
    _credentialVerticalController.dispose();
    _credentialHorizontalController.dispose();

    super.dispose();
  }

  // ===========================================================================
  // API
  // ===========================================================================

  Future<Map<String, String>> _headers() async {
    final authService = Provider.of<AuthService>(
      context,
      listen: false,
    );

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${authService.token}',
    };
  }

  Future<void> _fetchClients() async {
    if (!mounted) return;

    setState(() {
      _loadingClients = true;
    });

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/clients'),
        headers: await _headers(),
      );

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final body = jsonDecode(response.body);

      final clients = List<Map<String, dynamic>>.from(
        body['data'] ?? [],
      );

      if (!mounted) return;

      setState(() {
        _clients = clients;
        _loadingClients = false;
      });

      // Open directly when clientId was passed.
      if (widget.clientId != null) {
        final match = clients.cast<Map<String, dynamic>?>().firstWhere(
          (client) => _toInt(client?['id']) == widget.clientId,
          orElse: () => null,
        );

        if (match != null) {
          _selectClient(match);
        }
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingClients = false;
      });

      _showSnack('Unable to load clients');
    }
  }

  Future<void> _fetchCredentials(int clientId) async {
    if (!mounted) return;

    setState(() {
      _loadingCredentials = true;
      _credentials = [];
    });

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/credentials?clientId=$clientId'),
        headers: await _headers(),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load credentials');
      }

      final body = jsonDecode(response.body);

      final credentials = List<Map<String, dynamic>>.from(
        body['data'] ?? [],
      );

      if (!mounted) return;

     setState(() {
  _credentials = credentials;
  _loadingCredentials = false;

  // Remove visibility state for credentials
  // which are no longer present.
  final validIds = credentials
      .map((e) => _toInt(e['id']))
      .whereType<int>()
      .toSet();

  _visiblePasswords.removeWhere(
    (id, _) => !validIds.contains(id),
  );
});

    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingCredentials = false;
      });

      _showSnack('Unable to load credentials');
    }
  }

  Future<String?> _createCredential() async {
    if (_selectedClientId == null) {
      return 'Please select a client';
    }

    final platform = _selectedPlatform == 'Others'
        ? _otherPlatformController.text.trim()
        : _selectedPlatform;

    if (platform.isEmpty || platform == 'Select') {
      return 'Please select a platform';
    }

    if (_usernameController.text.trim().isEmpty) {
      return 'Please enter username';
    }

    if (_passwordController.text.trim().isEmpty) {
      return 'Please enter password';
    }

    setState(() {
      _savingCredential = true;
    });

    try {
      final payload = {
        'clientId': _selectedClientId,
        'username': _usernameController.text.trim(),
        'password': _passwordController.text.trim(),
        'platform': platform,
        'contactNumber': _contactController.text.trim(),
        'email': _emailController.text.trim(),
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/credentials'),
        headers: await _headers(),
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201) {
        await _fetchCredentials(_selectedClientId!);

        _clearForm();

        if (mounted) {
          _showSnack(
            'Credential added successfully',
            success: true,
          );
        }

        return null;
      }

      final body = jsonDecode(response.body);

      return body['message']?.toString() ??
          'Failed to add credential';
    } catch (e) {
      return 'Cannot connect to server';
    } finally {
      if (mounted) {
        setState(() {
          _savingCredential = false;
        });
      }
    }
  }

  Future<String?> _updateCredential() async {
    if (_editingCredentialId == null) {
      return 'Invalid credential';
    }

    final platform = _selectedPlatform == 'Others'
        ? _otherPlatformController.text.trim()
        : _selectedPlatform;

    if (platform.isEmpty || platform == 'Select') {
      return 'Please select a platform';
    }

    if (_usernameController.text.trim().isEmpty) {
      return 'Please enter username';
    }

    if (_passwordController.text.trim().isEmpty) {
      return 'Please enter password';
    }

    setState(() {
      _savingCredential = true;
    });

    try {
      final payload = {
        'username': _usernameController.text.trim(),
        'password': _passwordController.text.trim(),
        'platform': platform,
        'contactNumber': _contactController.text.trim(),
        'email': _emailController.text.trim(),
      };

      final response = await http.put(
        Uri.parse(
          '$_baseUrl/credentials/$_editingCredentialId',
        ),
        headers: await _headers(),
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        await _fetchCredentials(_selectedClientId!);

        _clearForm();

        if (mounted) {
          _showSnack(
            'Credential updated successfully',
            success: true,
          );
        }

        return null;
      }

      final body = jsonDecode(response.body);

      return body['message']?.toString() ??
          'Failed to update credential';
    } catch (e) {
      return 'Cannot connect to server';
    } finally {
      if (mounted) {
        setState(() {
          _savingCredential = false;
        });
      }
    }
  }

  Future<void> _deleteCredential(
    int credentialId,
    String username,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'Delete Credential',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
              content: Text(
                'Remove credential for "$username"?',
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                  ),
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    try {
      final response = await http.delete(
        Uri.parse(
          '$_baseUrl/credentials/$credentialId',
        ),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        await _fetchCredentials(_selectedClientId!);

        _clearForm();

        _showSnack(
          'Credential deleted',
          success: true,
        );
      } else {
        _showSnack('Failed to delete credential');
      }
    } catch (e) {
      _showSnack('Cannot connect to server');
    }
  }

  // ===========================================================================
  // CLIENT SELECTION
  // ===========================================================================

  void _selectClient(Map<String, dynamic> client) {
    final id = _toInt(client['id']);

    if (id == null) return;

    final name = _clientName(client);

    setState(() {
      _selectedClientId = id;
      _selectedClientName = name;
      _selectedClient = client;
    });

    _clientNameController.text = name;

    _clearCredentialOnlyForm();

    _fetchCredentials(id);
  }

  void _backToClientList() {
    setState(() {
      _selectedClientId = null;
      _selectedClientName = null;
      _selectedClient = null;
      _credentials = [];
    });

    _clearForm();
  }

  // ===========================================================================
  // FORM
  // ===========================================================================

  void _clearCredentialOnlyForm() {
    _editingCredentialId = null;

    _otherPlatformController.clear();
    _usernameController.clear();
    _passwordController.clear();
    _contactController.clear();
    _emailController.clear();
    _visiblePasswords.clear();

    _selectedPlatform = 'Select';
    _showPassword = false;
    
  }

  void _clearForm() {
    setState(() {
      _editingCredentialId = null;

      _otherPlatformController.clear();
      _usernameController.clear();
      _passwordController.clear();
      _contactController.clear();
      _emailController.clear();

      _selectedPlatform = 'Select';
      _showPassword = false;
    });
  }

  void _editCredential(Map<String, dynamic> credential) {
    final platform =
        credential['platform']?.toString() ?? '';

    final isCustom =
        platform.isNotEmpty &&
        !_basePlatforms.contains(platform);

    setState(() {
      _editingCredentialId = _toInt(credential['id']);

      _usernameController.text =
          credential['username']?.toString() ?? '';

      _passwordController.text =
          credential['password']?.toString() ?? '';

      _contactController.text =
          credential['contact_number']?.toString() ?? '';

      _emailController.text =
          credential['email']?.toString() ?? '';

      _selectedPlatform =
          isCustom ? 'Others' : platform;

      _otherPlatformController.text =
          isCustom ? platform : '';

      _showPassword = false;
    });
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  int? _toInt(dynamic value) {
    if (value == null) return null;

    if (value is int) return value;

    return int.tryParse(value.toString());
  }

  String _clientName(Map<String, dynamic> client) {
    return client['company_name']?.toString().trim().isNotEmpty == true
        ? client['company_name'].toString()
        : client['client_name']?.toString() ?? 'Unknown Client';
  }

  String _clientPackage(Map<String, dynamic> client) {
    final possibleFields = [
      'package_name',
      'packageName',
      'package',
      'package_type',
      'packageType',
      'packages',
      'industry',
    ];

    for (final field in possibleFields) {
      final value = client[field]?.toString().trim();

      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    return '—';
  }

  String _clientMaintenanceDate(Map<String, dynamic> client) {
    final possibleFields = [
      'maintenance_date',
      'maintenanceDate',
      'maintain_date',
      'maintainDate',
      'maintenance',
    ];

    for (final field in possibleFields) {
      final value = client[field]?.toString().trim();

      if (value != null && value.isNotEmpty) {
        return _formatDate(value);
      }
    }

    return '—';
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    try {
      final clean = value.trim();

      if (clean.contains('/')) {
        final parts = clean.split('/');

        if (parts.length == 3) {
          final day = int.tryParse(parts[0]);
          final month = int.tryParse(parts[1]);
          final year = int.tryParse(parts[2]);

          if (day != null &&
              month != null &&
              year != null) {
            return DateTime(year, month, day);
          }
        }
      }

      return DateTime.parse(
        clean.replaceFirst(' ', 'T'),
      ).toLocal();
    } catch (_) {
      return null;
    }
  }

  String _formatDate(String? value) {
    final date = _parseDate(value);

    if (date == null) {
      return value ?? '—';
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[date.month - 1]} '
        '${date.day}, ${date.year}';
  }

  String _formatDateTime(String? value) {
    final date = _parseDate(value);

    if (date == null) return '—';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final hour =
        date.hour % 12 == 0 ? 12 : date.hour % 12;

    final minute =
        date.minute.toString().padLeft(2, '0');

    final amPm =
        date.hour >= 12 ? 'PM' : 'AM';

    return '${months[date.month - 1]} '
        '${date.day}, ${date.year}\n'
        '$hour:$minute $amPm';
  }

  bool _isActive(Map<String, dynamic> client) {
    return client['is_active'] == 1 ||
        client['is_active'] == true ||
        client['is_active']?.toString() == '1';
  }

  void _showSnack(
    String message, {
    bool success = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            success
                ? const Color(0xFF16A34A)
                : const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      pageTitle: 'Client Credentials',
      currentRoute: '/client-credentials',
      onSearch: (query) {
        setState(() {
          _searchQuery = query.trim().toLowerCase();
        });
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 850;

          if (_selectedClientId == null) {
            return _buildClientDirectory(isMobile);
          }

          return _buildCredentialWorkspace(isMobile);
        },
      ),
    );
  }

  // ===========================================================================
  // CLIENT DIRECTORY
  // ===========================================================================

  Widget _buildClientDirectory(bool isMobile) {
    final visibleClients = _clients.where((client) {
      if (_searchQuery.isEmpty) {
        return true;
      }

      final name =
          _clientName(client).toLowerCase();

      final package =
          _clientPackage(client).toLowerCase();

      return name.contains(_searchQuery) ||
          package.contains(_searchQuery);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHero(
          title: 'Client Credentials',
          subtitle:
              'Manage client account credentials and platform access from one secure workspace.',
          isMobile: isMobile,
          showBack: false,
        ),

        const SizedBox(height: 20),

        // ---------------------------------------------------------------------
        // DIRECTORY HEADER
        // ---------------------------------------------------------------------

        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.business_center_outlined,
                color: Color(0xFF0052CC),
                size: 21,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Clients Directory',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF172033),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _fetchClients,
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ---------------------------------------------------------------------
        // TABLE
        // ---------------------------------------------------------------------

        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.025),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              if (!isMobile)
                _buildClientTableHeader(),

              const Divider(
                height: 1,
                color: Color(0xFFE2E8F0),
              ),

              SizedBox(
                height: 520,
                child: _loadingClients
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF0052CC),
                        ),
                      )
                    : visibleClients.isEmpty
                        ? const Center(
                            child: Text(
                              'No clients found.',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : isMobile
                            ? ListView.builder(
                                controller:
                                    _clientScrollController,
                                padding:
                                    const EdgeInsets.all(14),
                                itemCount:
                                    visibleClients.length,
                                itemBuilder:
                                    (context, index) {
                                  return _buildMobileClientCard(
                                    index + 1,
                                    visibleClients[index],
                                  );
                                },
                              )
                            : ListView.separated(
                                controller:
                                    _clientScrollController,
                                itemCount:
                                    visibleClients.length,
                                separatorBuilder:
                                    (_, __) =>
                                        const Divider(
                                  height: 1,
                                  color: Color(0xFFE2E8F0),
                                ),
                                itemBuilder:
                                    (context, index) {
                                  return _buildClientRow(
                                    index + 1,
                                    visibleClients[index],
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildClientTableHeader() {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(
        horizontal: 22,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F9FC),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 1,
            child: Text('S.NO', style: _tableHeader),
          ),
          Expanded(
            flex: 4,
            child: Text('CLIENT NAME', style: _tableHeader),
          ),
          Expanded(
            flex: 3,
            child: Text('PACKAGES', style: _tableHeader),
          ),
          Expanded(
            flex: 3,
            child: Text('MAINTAIN DATE', style: _tableHeader),
          ),
          Expanded(
            flex: 2,
            child: Text('CREDENTIAL', style: _tableHeader),
          ),
        ],
      ),
    );
  }

  Widget _buildClientRow(
    int index,
    Map<String, dynamic> client,
  ) {
    final name = _clientName(client);
    final package = _clientPackage(client);
    final maintenance =
        _clientMaintenanceDate(client);

    final active = _isActive(client);

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(
        horizontal: 22,
      ),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              '$index',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
          ),

          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.business_outlined,
                    color: Color(0xFF0052CC),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: active
                                  ? const Color(
                                      0xFF16A34A,
                                    )
                                  : const Color(
                                      0xFF94A3B8,
                                    ),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            active
                                ? 'Active'
                                : 'Inactive',
                            style:
                                const TextStyle(
                              fontSize: 10,
                              color:
                                  Color(0xFF94A3B8),
                              fontWeight:
                                  FontWeight.w600,
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

          Expanded(
            flex: 3,
            child: Text(
              package,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
              ),
            ),
          ),

          Expanded(
            flex: 3,
            child: Text(
              maintenance,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),

          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: () => _selectClient(client),
                icon: const Icon(
                  Icons.visibility_outlined,
                  size: 15,
                ),
                label: const Text(
                  'View',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF0052CC),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 10,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(9),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileClientCard(
    int index,
    Map<String, dynamic> client,
  ) {
    final name = _clientName(client);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius:
                      BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.business_outlined,
                  color: Color(0xFF0052CC),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$index. $name',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF172033),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _clientPackage(client),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          Row(
            children: [
              Expanded(
                child: _mobileInfo(
                  'Maintain Date',
                  _clientMaintenanceDate(client),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _selectClient(client),
                icon: const Icon(
                  Icons.visibility_outlined,
                  size: 15,
                ),
                label: const Text(
                  'View',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF0052CC),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(9),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mobileInfo(
    String title,
    String value,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 9,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF475569),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // CREDENTIAL WORKSPACE
  // ===========================================================================

  Widget _buildCredentialWorkspace(bool isMobile) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _buildHero(
          title:
              'Credentials — ${_selectedClientName ?? 'Client'}',
          subtitle:
              'View existing credentials and add or update platform access details.',
          isMobile: isMobile,
          showBack: true,
        ),

        const SizedBox(height: 20),

        if (isMobile)
          Column(
            children: [
              _buildCredentialTable(),
              const SizedBox(height: 16),
              _buildCredentialForm(),
            ],
          )
        else
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: _buildCredentialTable(),
              ),
              const SizedBox(width: 18),
              SizedBox(
                width: 390,
                child: _buildCredentialForm(),
              ),
            ],
          ),

        const SizedBox(height: 32),
      ],
    );
  }

  // ===========================================================================
  // LEFT — CREDENTIAL TABLE
  // ===========================================================================

  Widget _buildCredentialTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.025),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(
              20,
              18,
              20,
              16,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius:
                        BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: Color(0xFF0052CC),
                    size: 19,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Client Credentials',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF172033),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_credentials.length} credential${_credentials.length == 1 ? '' : 's'} saved',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _selectedClientId == null
                      ? null
                      : () => _fetchCredentials(
                            _selectedClientId!,
                          ),
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Color(0xFF64748B),
                    size: 19,
                  ),
                ),
              ],
            ),
          ),

          const Divider(
            height: 1,
            color: Color(0xFFE2E8F0),
          ),

          if (_loadingCredentials)
            const SizedBox(
              height: 450,
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF0052CC),
                ),
              ),
            )
          else if (_credentials.isEmpty)
            SizedBox(
              height: 450,
              child: _buildEmptyCredentialState(),
            )
          else
            _buildCredentialTableContent(),
        ],
      ),
    );
  }

  Widget _buildCredentialTableContent() {
    return Scrollbar(
      controller: _credentialHorizontalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller:
            _credentialHorizontalController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 900,
          child: Column(
            children: [
              Container(
                height: 48,
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 20,
                ),
                color: const Color(0xFFF8FAFC),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'PLATFORM',
                        style: _tableHeader,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'USERNAME',
                        style: _tableHeader,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'PASSWORD',
                        style: _tableHeader,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'CONTACT / EMAIL',
                        style: _tableHeader,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'UPDATED',
                        style: _tableHeader,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment:
                            Alignment.centerRight,
                        child: Text(
                          'ACTION',
                          style: _tableHeader,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(
                height: 1,
                color: Color(0xFFE2E8F0),
              ),

              SizedBox(
                height: 450,
                child: Scrollbar(
                  controller:
                      _credentialVerticalController,
                  thumbVisibility: true,
                  child: ListView.separated(
                    controller:
                        _credentialVerticalController,
                    itemCount:
                        _credentials.length,
                    separatorBuilder:
                        (_, __) =>
                            const Divider(
                      height: 1,
                      color: Color(0xFFE2E8F0),
                    ),
                    itemBuilder:
                        (context, index) {
                      return _buildCredentialRow(
                        _credentials[index],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCredentialRow(
  Map<String, dynamic> credential,
) {
  final credentialId = _toInt(credential['id']);

  final platform =
      credential['platform']?.toString() ?? '—';

  final username =
      credential['username']?.toString() ?? '';

  final password =
      credential['password']?.toString() ?? '';

  final phone =
      credential['contact_number']?.toString() ?? '';

  final email =
      credential['email']?.toString() ?? '';

  final updated =
      credential['updated_at']?.toString();

  final bool showPassword =
      credentialId != null &&
          (_visiblePasswords[credentialId] ?? false);

  return Container(
    height: 78,
    padding: const EdgeInsets.symmetric(
      horizontal: 20,
    ),
    color: Colors.white,
    child: Row(
      children: [
        // =========================================================
        // PLATFORM
        // =========================================================

        Expanded(
          flex: 3,
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius:
                      BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.public_outlined,
                  size: 16,
                  color: Color(0xFF0052CC),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  platform,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
        ),

        // =========================================================
        // USERNAME
        // =========================================================

        Expanded(
          flex: 3,
          child: Text(
            username.isEmpty ? '—' : username,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
        ),

        // =========================================================
        // PASSWORD
        // =========================================================

        Expanded(
          flex: 3,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  password.isEmpty
                      ? '—'
                      : showPassword
                          ? password
                          : _maskedPassword(password),
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: password.isEmpty
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                    fontWeight:
                        FontWeight.w700,
                    letterSpacing:
                        showPassword ? 0 : 2,
                  ),
                ),
              ),

              // 👁 REAL WORKING EYE BUTTON
              if (password.isNotEmpty)
                IconButton(
                  tooltip: showPassword
                      ? 'Hide password'
                      : 'Show password',
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: credentialId == null
                      ? null
                      : () {
                          setState(() {
                            _visiblePasswords[
                                    credentialId] =
                                !showPassword;
                          });
                        },
                  icon: Icon(
                    showPassword
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    size: 17,
                    color: const Color(0xFF64748B),
                  ),
                ),
            ],
          ),
        ),

        // =========================================================
        // CONTACT / EMAIL
        // =========================================================

        Expanded(
          flex: 3,
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                phone.isEmpty ? '—' : phone,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                email.isEmpty ? '—' : email,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),

        // =========================================================
        // UPDATED
        // =========================================================

        Expanded(
          flex: 2,
          child: Text(
            _formatDateTime(updated),
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // =========================================================
        // ACTION
        // =========================================================

        Expanded(
          flex: 2,
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Edit',
                splashRadius: 18,
                onPressed: () {
                  _editCredential(
                    credential,
                  );
                },
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 17,
                  color: Color(0xFF0052CC),
                ),
              ),

              IconButton(
                tooltip: 'Delete',
                splashRadius: 18,
                onPressed: () {
                  _deleteCredential(
                    credentialId ?? 0,
                    username,
                  );
                },
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}


  String _maskedPassword(String password) {
    if (password.isEmpty) return '—';

    final length =
        password.length > 12
            ? 12
            : password.length;

    return '•' * length;
  }

  Widget _buildEmptyCredentialState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius:
                  BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              size: 30,
              color: Color(0xFF0052CC),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No credentials yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Use the form on the right to add the first credential.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // RIGHT — ADD / EDIT FORM
  // ===========================================================================

Widget _buildCredentialForm() {
  final isEditing = _editingCredentialId != null;

  final usedPlatforms = _credentials
      .map(
        (credential) =>
            credential['platform']?.toString().trim().toLowerCase(),
      )
      .whereType<String>()
      .where((platform) => platform.isNotEmpty)
      .toSet();

  String? editingPlatform;

  if (isEditing) {
    final currentCredential =
        _credentials.cast<Map<String, dynamic>?>().firstWhere(
              (credential) =>
                  _toInt(credential?['id']) ==
                  _editingCredentialId,
              orElse: () => null,
            );

    editingPlatform =
        currentCredential?['platform']?.toString().trim();
  }

  final availablePlatforms = <String>[
    'Select',

    ..._basePlatforms.where((platform) {
      final normalized = platform.toLowerCase();

      // While editing, keep the current platform available.
      if (editingPlatform != null &&
          normalized == editingPlatform!.toLowerCase()) {
        return true;
      }

      // Don't show platforms already used by this client.
      return !usedPlatforms.contains(normalized);
    }),

    'Others',
  ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.025),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          // FORM HEADER
          Container(
            padding: const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              18,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF003B95),
                  Color(0xFF0052CC),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white
                        .withOpacity(.14),
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isEditing
                        ? Icons.edit_outlined
                        : Icons.add_link_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing
                            ? 'Edit Credential'
                            : 'Add Credential',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _selectedClientName ??
                            'Select Client',
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFDCE8FF),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // FORM BODY
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _formSectionTitle(
                  'ACCOUNT INFORMATION',
                ),

                const SizedBox(height: 13),

                _buildFormField(
                  label: 'Client Name',
                  controller:
                      _clientNameController,
                  icon:
                      Icons.business_outlined,
                  enabled: false,
                ),

                const SizedBox(height: 14),

                _buildPlatformDropdown(
                  availablePlatforms,
                ),

                if (_selectedPlatform ==
                    'Others') ...[
                  const SizedBox(height: 14),
                  _buildFormField(
                    label:
                        'Specify Platform Name',
                    hint:
                        'e.g. Pinterest, Twitter/X',
                    controller:
                        _otherPlatformController,
                    icon:
                        Icons.language_outlined,
                  ),
                ],

                const SizedBox(height: 14),

                _buildFormField(
                  label: 'User Name *',
                  hint: 'Enter username / ID',
                  controller:
                      _usernameController,
                  icon: Icons.person_outline,
                ),

                const SizedBox(height: 14),

                _buildPasswordField(),

                const SizedBox(height: 14),

                _formSectionTitle(
                  'CONTACT INFORMATION',
                ),

                const SizedBox(height: 13),

                _buildFormField(
                  label: 'Contact Number',
                  hint: '+91 ...',
                  controller:
                      _contactController,
                  icon: Icons.phone_outlined,
                  keyboardType:
                      TextInputType.phone,
                ),

                const SizedBox(height: 14),

                _buildFormField(
                  label: 'Email',
                  hint: 'client@email.com',
                  controller:
                      _emailController,
                  icon: Icons.email_outlined,
                  keyboardType:
                      TextInputType.emailAddress,
                ),

                const SizedBox(height: 22),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _savingCredential
                                ? null
                                : _clearForm,
                        style:
                            OutlinedButton.styleFrom(
                          minimumSize:
                              const Size(
                            0,
                            46,
                          ),
                          side:
                              const BorderSide(
                            color:
                                Color(0xFFCBD5E1),
                          ),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              11,
                            ),
                          ),
                        ),
                        child: Text(
                          isEditing
                              ? 'Cancel Edit'
                              : 'Clear',
                          style:
                              const TextStyle(
                            fontSize: 12,
                            fontWeight:
                                FontWeight.w800,
                            color:
                                Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed:
                            _savingCredential
                                ? null
                                : _saveCredential,
                        icon: _savingCredential
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color:
                                      Colors.white,
                                ),
                              )
                            : Icon(
                                isEditing
                                    ? Icons
                                        .save_outlined
                                    : Icons
                                        .add_rounded,
                                size: 17,
                              ),
                        label: Text(
                          isEditing
                              ? 'Save Changes'
                              : 'Save Credential',
                          style:
                              const TextStyle(
                            fontSize: 12,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(
                            0xFF0052CC,
                          ),
                          foregroundColor:
                              Colors.white,
                          minimumSize:
                              const Size(
                            0,
                            46,
                          ),
                          elevation: 0,
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              11,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCredential() async {
    String? error;

    if (_editingCredentialId != null) {
      error = await _updateCredential();
    } else {
      error = await _createCredential();
    }

    if (error != null && mounted) {
      _showSnack(error);
    }
  }

  Widget _formSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 14,
          decoration: BoxDecoration(
            color: const Color(0xFF0052CC),
            borderRadius:
                BorderRadius.circular(5),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: .8,
            fontWeight: FontWeight.w900,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildFormField({
    required String label,
    String hint = '',
    required TextEditingController controller,
    required IconData icon,
    bool enabled = true,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 7),
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: enabled
                ? const Color(0xFFF8FAFC)
                : const Color(0xFFF1F5F9),
            borderRadius:
                BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFCBD5E1),
            ),
          ),
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: keyboardType,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: enabled
                  ? const Color(0xFF1E293B)
                  : const Color(0xFF64748B),
            ),
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(
                icon,
                size: 17,
                color: const Color(0xFF94A3B8),
              ),
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Password *',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 7),
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius:
                BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFCBD5E1),
            ),
          ),
          child: TextField(
            controller: _passwordController,
            obscureText: !_showPassword,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.lock_outline_rounded,
                size: 17,
                color: Color(0xFF94A3B8),
              ),
              hintText: 'Enter password',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 13,
              ),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _showPassword =
                        !_showPassword;
                  });
                },
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  size: 18,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlatformDropdown(
    List<String> items,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Platform *',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 7),
        Container(
          height: 46,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 10,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius:
                BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFCBD5E1),
            ),
          ),
          child:
              DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(
                _selectedPlatform,
              )
                  ? _selectedPlatform
                  : 'Select',
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF64748B),
              ),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
              items: items.map(
                (item) {
                  return DropdownMenuItem<
                      String>(
                    value: item,
                    child: Row(
                      children: [
                        Icon(
                          _platformIcon(item),
                          size: 16,
                          color:
                              const Color(
                            0xFF64748B,
                          ),
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        Text(item),
                      ],
                    ),
                  );
                },
              ).toList(),
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _selectedPlatform = value;

                  if (value != 'Others') {
                    _otherPlatformController
                        .clear();
                  }
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  IconData _platformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'facebook':
      case 'instagram':
      case 'linkedin':
        return Icons.public_outlined;

      case 'youtube':
        return Icons.play_circle_outline;

      case 'google ads':
      case 'meta ads':
        return Icons.campaign_outlined;

      case 'whatsapp business':
        return Icons.chat_outlined;

      case 'mail id':
        return Icons.email_outlined;

      case 'google business profile':
        return Icons.location_on_outlined;

      case 'server login':
        return Icons.dns_outlined;

      case 'others':
        return Icons.language_outlined;

      default:
        return Icons.public_outlined;
    }
  }

  // ===========================================================================
  // HERO
  // ===========================================================================

  Widget _buildHero({
    required String title,
    required String subtitle,
    required bool isMobile,
    required bool showBack,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        isMobile ? 20 : 26,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF003B95),
            Color(0xFF0052CC),
            Color(0xFF1267E8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
            BorderRadius.circular(
          isMobile ? 20 : 24,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF0052CC,
            ).withOpacity(.20),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _heroContent(
                  title,
                  subtitle,
                  isMobile,
                ),
                if (showBack) ...[
                  const SizedBox(height: 15),
                  _backButton(),
                ],
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: _heroContent(
                    title,
                    subtitle,
                    isMobile,
                  ),
                ),
                if (showBack) _backButton(),
              ],
            ),
    );
  }

  Widget _heroContent(
    String title,
    String subtitle,
    bool isMobile,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'CLIENT CREDENTIALS CENTER',
          style: TextStyle(
            color: Color(0xFFBFD5FF),
            fontSize: 10,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 21 : 25,
            fontWeight: FontWeight.w900,
            letterSpacing: -.4,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFFDCE8FF),
            fontSize: 11,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _backButton() {
    return OutlinedButton.icon(
      onPressed: _backToClientList,
      icon: const Icon(
        Icons.arrow_back_rounded,
        size: 16,
      ),
      label: const Text(
        'Back to Clients',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(
          color: Colors.white38,
        ),
        padding:
            const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 13,
        ),
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(11),
        ),
      ),
    );
  }

  // ===========================================================================
  // STYLES
  // ===========================================================================

  static const TextStyle _tableHeader =
      TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w900,
    color: Color(0xFF64748B),
    letterSpacing: .6,
  );
}

