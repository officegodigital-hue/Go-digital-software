// name=client_history_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../layouts/admin_layout.dart';
import 'client_details_screen.dart';
import '../../services/api_config.dart';
import '../../services/auth_service.dart';

class ClientHistoryScreen extends StatefulWidget {
  const ClientHistoryScreen({super.key});

  @override
  State<ClientHistoryScreen> createState() => _ClientHistoryScreenState();
}

class _ClientHistoryScreenState extends State<ClientHistoryScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;
  List<Map<String, dynamic>> filteredClients = [];
  List<Map<String, dynamic>> _clients = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';

  String activeFilter = 'Active';
  bool _isFilterMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  Future<void> _fetchClients() async {
    setState(() { _loading = true; _error = null; });
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
        final clients = List<Map<String, dynamic>>.from(body['data'] ?? []);

        setState(() {
          _clients = clients;
          _loading = false;
        });

        _applyClientFilter();
      } else {
        setState(() { _error = 'Server returned ${response.statusCode}'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Cannot connect to server'; _loading = false; });
    }
  }

  void _applyClientFilter() {
    setState(() {
      filteredClients = _clients.where((client) {
        final bool isActive =
            client['is_active'] == 1 ||
            client['is_active'] == true;

        if (activeFilter == 'Active' && !isActive) {
          return false;
        }

        if (activeFilter == 'Inactive' && isActive) {
          return false;
        }

        if (_searchQuery.isEmpty) {
          return true;
        }

        final companyName =
            client['company_name']?.toString().toLowerCase() ?? '';
        final industry =
            client['industry']?.toString().toLowerCase() ?? '';
        final contactPerson =
            client['contact_person']?.toString().toLowerCase() ?? '';
        final email =
            client['email']?.toString().toLowerCase() ?? '';
        final status =
            client['status']?.toString().toLowerCase() ?? '';
        final phone =
            client['phone']?.toString().toLowerCase() ?? '';

        return companyName.contains(_searchQuery) ||
            industry.contains(_searchQuery) ||
            contactPerson.contains(_searchQuery) ||
            email.contains(_searchQuery) ||
            status.contains(_searchQuery) ||
            phone.contains(_searchQuery);
      }).toList();
    });
  }

  void _filterClients(String query) {
    _searchQuery = query.trim().toLowerCase();
    _applyClientFilter();
  }

  Future<void> _updateStatus(int id, String status) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/clients/$id'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'status': status,
        }),
      );

      if (response.statusCode == 200) {
        _fetchClients();
        _showSnack('Status updated to $status', success: true);
      } else {
        _showSnack('Failed to update status');
      }
    } catch (e) {
      _showSnack('Cannot connect to server');
    }
  }

  Future<void> _deleteClient(int id) async {
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/clients/$id'));
      if (response.statusCode == 200) {
        await _fetchClients();
        _showSnack('Client deleted', success: true);
      } else {
        _showSnack('Failed to delete client');
      }
    } catch (e) {
      _showSnack('Cannot connect to server');
    }
  }

  Future<bool> _confirmReorder(int oldNo, int newNo) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text("Change Order", style: TextStyle(fontWeight: FontWeight.w900)),
            content: Text(
              "Move this row from $oldNo to position $newNo?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052CC)),
                child: const Text("OK", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _updateOrder(int clientId, int newPosition) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/clients/$clientId/order'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'position': newPosition,
        }),
      );

      if (response.statusCode == 200) {
        await _fetchClients();
        _showSnack(
          'Client order updated',
          success: true,
        );
      } else {
        _showSnack(response.body);
      }
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  Future<void> _toggleClientStatus(
    int id,
    bool currentStatus,
  ) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/clients/$id'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'isActive': !currentStatus,
        }),
      );

      if (response.statusCode == 200) {
        _fetchClients();
      } else {
        _showSnack('Failed to update status');
      }
    } catch (e) {
      _showSnack('Cannot connect to server');
    }
  }

  void _confirmDelete(int id, String companyName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Client', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('Remove "$companyName" and all of its credentials? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteClient(id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? const Color(0xFF16A34A) : Colors.redAccent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Map<String, Color> _statusColors(String status) {
    switch (status) {
      case 'complete':
        return {'bg': const Color(0xFFDCFCE7), 'fg': const Color(0xFF16A34A)};
      case 'verified':
        return {'bg': const Color(0xFFDBEAFE), 'fg': const Color(0xFF2563EB)};
      case 'pending':
        return {'bg': const Color(0xFFFEF3C7), 'fg': const Color(0xFFD97706)};
      default:
        return {'bg': const Color(0xFFF1F5F9), 'fg': const Color(0xFF64748B)};
    }
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final dt = DateTime.parse(isoDate);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  Future<void> _openOnboarding({int? clientId}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClientDetailsScreen(clientId: clientId)),
    );
    _fetchClients();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.user;
    
    final bool isMainAdmin = user?['isMainAdmin'] == true || 
                             user?['isMainAdmin'] == 1 || 
                             user?['isMainAdmin'].toString() == '1' ||
                             user?['is_main_admin'] == true || 
                             user?['is_main_admin'] == 1 || 
                             user?['is_main_admin'].toString() == '1';

    return AdminLayout(
      pageTitle: 'Client Onboarding',
      currentRoute: '/client',
      onSearch: _filterClients,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isMobile = constraints.maxWidth < 750;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── HERO BANNER HEADER ──────────────────────────────────────
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isMobile ? 20 : 28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF003B95),
                      Color(0xFF0052CC),
                      Color(0xFF1267E8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(isMobile ? 22 : 28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0052CC).withValues(alpha: 0.25),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _heroText(isMobile),
                          const SizedBox(height: 18),
                          SizedBox(width: double.infinity, child: _createButton()),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: _heroText(isMobile)),
                          _createButton(),
                        ],
                      ),
              ),
              const SizedBox(height: 20),

              // ── FILTER CONTROL BAR ──────────────────────────────────────
              Container(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.025),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Clients Directory',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF172033),
                                ),
                              ),
                              _filterToggleButton(),
                            ],
                          ),
                          if (_isFilterMenuOpen) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _buildFilterTab('All'),
                                _buildFilterTab('Active'),
                                _buildFilterTab('Inactive'),
                              ],
                            ),
                          ],
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Clients Directory',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF172033),
                            ),
                          ),
                          Row(
                            children: [
                              AnimatedVisibility(
                                visible: _isFilterMenuOpen,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildFilterTab('All'),
                                    _buildFilterTab('Active'),
                                    _buildFilterTab('Inactive'),
                                    const SizedBox(width: 8),
                                  ],
                                ),
                              ),
                              _filterToggleButton(),
                            ],
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 20),

              // ── WORKSPACE TABLE / CARD CONTAINER ───────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.025),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isMobile)
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFF7F9FC),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(children: [
                          const Expanded(flex: 1, child: Text('S.NO', style: _th)),
                          const Expanded(flex: 3, child: Text('COMPANY', style: _th)),
                          const Expanded(flex: 2, child: Text('CONTACT', style: _th)),
                          const Expanded(flex: 2, child: Text('CREATED', style: _th)),
                          const Expanded(flex: 3, child: Text('COMPLETION', style: _th)),
                          const Expanded(flex: 2, child: Text('STATUS', style: _th)),
                          const Expanded(flex: 2, child: Text('ACTIVE', style: _th)),
                          
                          // ✅ CREATED BY COLUMN PLACED BETWEEN ACTIVE AND ACTIONS (Only for Main Admin)
                          if (isMainAdmin)
                            const Expanded(flex: 2, child: Text('CREATED BY', style: _th)),

                          const Expanded(flex: 4, child: Align(alignment: Alignment.centerRight, child: Text('ACTIONS', style: _th))),
                        ]),
                      ),
                    if (!isMobile) const Divider(height: 1, color: Color(0xFFE2E8F0)),

                    SizedBox(
                      height: 500,
                      child: _loading
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0052CC)))
                          : _error != null
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_error!, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                      const SizedBox(height: 12),
                                      ElevatedButton(
                                        onPressed: _fetchClients,
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052CC)),
                                        child: const Text('Retry', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                )
                              : filteredClients.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No clients found.',
                                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    )
                                  : isMobile
                                      ? ListView.builder(
                                          itemCount: filteredClients.length,
                                          padding: const EdgeInsets.all(14),
                                          itemBuilder: (context, index) {
                                            final c = filteredClients[index];
                                            return _buildMobileClientCard(index + 1, c, isMainAdmin);
                                          },
                                        )
                                      : ListView.separated(
                                          itemCount: filteredClients.length,
                                          physics: const BouncingScrollPhysics(),
                                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                                          itemBuilder: (context, index) {
                                            final c = filteredClients[index];
                                            final int displayOrder =
                                                (c['display_order'] == null || c['display_order'] == 0)
                                                    ? (index + 1)
                                                    : int.tryParse(c['display_order'].toString()) ?? (index + 1);
                                            return _buildRow(displayOrder, c, isMainAdmin);
                                          },
                                        ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _heroText(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CLIENT ONBOARDING CENTER',
          style: TextStyle(
            color: Color(0xFFBFD5FF),
            fontSize: 10,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Client History',
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 22 : 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Track onboarding progress, verification, and registration status for every client.',
          style: TextStyle(
            color: Color(0xFFDCE8FF),
            fontSize: 11,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _createButton() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _fetchClients,
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: 'Refresh',
          style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.15)),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => _openOnboarding(),
          icon: const Icon(Icons.add, size: 16, color: Color(0xFF0052CC)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            elevation: 0,
          ),
          label: const Text(
            'Client Onboarding',
            style: TextStyle(color: Color(0xFF0052CC), fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _filterToggleButton() {
    return InkWell(
      onTap: () {
        setState(() {
          _isFilterMenuOpen = !_isFilterMenuOpen;
          if (!_isFilterMenuOpen) {
            activeFilter = 'Active';
          }
        });
        if (!_isFilterMenuOpen) {
          _applyClientFilter();
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _isFilterMenuOpen ? const Color(0xFFF1F5F9) : Colors.transparent,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              _isFilterMenuOpen ? Icons.filter_list_off_rounded : Icons.filter_list_rounded,
              size: 15,
              color: const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              _isFilterMenuOpen ? 'Hide Filters' : 'Filters',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileClientCard(int serialNo, Map<String, dynamic> c, bool isMainAdmin) {
    final int id = c['id'];
    final String status = c['status'] ?? 'draft';
    final int percent = c['completion_percent'] ?? 0;
    final colors = _statusColors(status);
    final bool active = c['is_active'] == 1 || c['is_active'] == true;
    final String createdByName = c['created_by_name'] ?? 'Main Admin';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#$serialNo',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF0052CC)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: colors['bg'],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors['fg']!.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: colors['fg'], letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              c['company_name'] ?? '',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 3),
            Text(
              c['industry'] ?? 'General Industry',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
            if (isMainAdmin) ...[
              const SizedBox(height: 6),
              Text(
                'Created by: $createdByName',
                style: const TextStyle(fontSize: 11, color: Color(0xFF0052CC), fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Text(c['contact_person']?.toString().isEmpty ?? true ? '—' : c['contact_person'], style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.email_outlined, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(child: Text(c['email']?.toString().isEmpty ?? true ? '—' : c['email'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text("Completion: ", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                Text('$percent%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                const Spacer(),
                Text(_formatDate(c['created_at']?.toString()), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent / 100,
                minHeight: 6,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(
                  percent == 100 ? const Color(0xFF16A34A) : const Color(0xFF0052CC),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _toggleClientStatus(id, active),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: active ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        active ? 'ACTIVE' : 'IN-ACTIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: active ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _openOnboarding(clientId: id),
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0052CC)),
                  tooltip: 'Edit',
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFFEAF2FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => _confirmDelete(id, c['company_name'] ?? 'this client'),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                  tooltip: 'Delete',
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFFFEE2E2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(int index, Map<String, dynamic> c, bool isMainAdmin) {
    final int    id      = c['id'];
    final String status  = c['status'] ?? 'draft';
    final int    percent = c['completion_percent'] ?? 0;
    final colors = _statusColors(status);
    final bool active = c['is_active'] == 1 || c['is_active'] == true;
    final String createdByName = c['created_by_name'] ?? 'Main Admin';

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 40,
                height: 30,
                child: TextFormField(
                  initialValue: index.toString(),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: EdgeInsets.zero,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFFD1D5DB),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFF0052CC),
                        width: 2,
                      ),
                    ),
                  ),
                  onFieldSubmitted: (value) async {
                    final newPosition = int.tryParse(value);
                    if (newPosition == null) return;
                    if (newPosition == index) return;

                    final ok = await _confirmReorder(index, newPosition);
                    if (!ok) {
                      await _fetchClients();
                      return;
                    }

                    await _updateOrder(id, newPosition);
                  },
                ),
              ),
            ),
          ),
          
          // Company
          Expanded(flex: 3, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(c['company_name'] ?? '',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
              const SizedBox(height: 2),
              Text(c['industry'] ?? '',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ],
          )),

          // Contact
          Expanded(flex: 2, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(c['contact_person']?.toString().isEmpty ?? true ? '—' : c['contact_person'],
                  style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
              const SizedBox(height: 2),
              Text(c['email']?.toString().isEmpty ?? true ? '—' : c['email'],
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ],
          )),

          // Created date
          Expanded(flex: 2, child: Text(_formatDate(c['created_at']?.toString()),
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)))),

          // Completion %
          Expanded(flex: 3, child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$percent%',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent / 100,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      percent == 100 ? const Color(0xFF16A34A) : const Color(0xFF0052CC),
                    ),
                  ),
                ),
              ],
            ),
          )),

          // Status badge
          Expanded(flex: 2, child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: colors['bg'], borderRadius: BorderRadius.circular(4)),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: colors['fg'], letterSpacing: 0.4),
              ),
            ),
          )),

          // Active Button
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _toggleClientStatus(id, active),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: active
                              ? const Color(0xFFBBF7D0)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        active ? 'ACTIVE' : 'IN-ACTIVE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: active
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ✅ CREATED BY COLUMN PLACED BETWEEN ACTIVE AND ACTIONS (Only for Main Admin)
          if (isMainAdmin)
            Expanded(
              flex: 2,
              child: Text(
                createdByName,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0052CC)),
              ),
            ),

          // Actions
          Expanded(flex: 4, child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _openOnboarding(clientId: id),
                icon: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF475569)),
                label: const Text('', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(width: 8),
 
              if (status == 'draft' || status == 'pending')
                ElevatedButton(
                  onPressed: () => _updateStatus(id, status == 'draft' ? 'pending' : 'verified'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: status == 'draft' ? const Color(0xFFD97706) : const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    elevation: 0,
                  ),
                  child: Text(
                    status == 'draft' ? 'Mark Pending' : 'Verify',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                )
              else if (status == 'verified')
                ElevatedButton(
                  onPressed: () => _updateStatus(id, 'complete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    elevation: 0,
                  ),
                  child: const Text('Mark Complete',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(children: [
                    Icon(Icons.check_circle, size: 14, color: Color(0xFF16A34A)),
                    SizedBox(width: 7),
                    Text('Done', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                  ]),
                ),

              const SizedBox(width: 8),

              IconButton(
                onPressed: () => _confirmDelete(id, c['company_name'] ?? 'this client'),
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                tooltip: 'Delete client',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFFEE2E2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  padding: const EdgeInsets.all(10),
                ),
              ),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label) {
    final bool isActive =
        activeFilter.toLowerCase() == label.toLowerCase();

    return Container(
      margin: const EdgeInsets.only(right: 4),
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            activeFilter = label;
          });
          _applyClientFilter();
        },
        style: OutlinedButton.styleFrom(
          backgroundColor:
              isActive ? const Color(0xFF0052CC) : Colors.transparent,
          side: BorderSide(
            color: isActive
                ? const Color(0xFF0052CC)
                : const Color(0xFFE2E8F0),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight:
                isActive ? FontWeight.bold : FontWeight.w600,
            color: isActive
                ? Colors.white
                : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  static const TextStyle _th = TextStyle(
      fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5);
}

class AnimatedVisibility extends StatelessWidget {
  final bool visible;
  final Widget child;

  const AnimatedVisibility({super.key, required this.visible, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: visible ? child : const SizedBox.shrink(),
    );
  }
}