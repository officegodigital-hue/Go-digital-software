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
  final Set<int> _expanded = {};

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
        final state = _stateOf(client);

        if (activeFilter == 'Active' && state != 'active') return false;
        if (activeFilter == 'On Hold' && state != 'hold') return false;
        if (activeFilter == 'Inactive' && state != 'inactive') return false;

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
      // Onboarding step only — does not change Active / On Hold.
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

  /// Tap the S.No → choose the new S.No. Other clients shift to make room.
  Future<void> _askNewPosition(Map<String, dynamic> c, int current) async {
    final ctrl = TextEditingController(text: '$current');
    final total = _clients.length;
    final picked = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        String? error;
        return StatefulBuilder(
          builder: (context, setD) {
            void submit() {
              final v = int.tryParse(ctrl.text.trim());
              if (v == null || v < 1 || v > total) {
                setD(() => error = 'Enter a number from 1 to $total');
                return;
              }
              Navigator.pop(dialogContext, v);
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Change S.No', style: TextStyle(fontWeight: FontWeight.w900)),
              content: SizedBox(
                width: 340,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${c['company_name'] ?? 'This client'} is S.No $current. Move it to:',
                      style: const TextStyle(color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ctrl,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      onSubmitted: (_) => submit(),
                      decoration: InputDecoration(
                        labelText: 'New S.No (1 – $total)',
                        errorText: error,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Active, On Hold and In-Active clients keep their own blocks, so a client moves inside its block.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: submit,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052CC)),
                  child: const Text('Move', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
    ctrl.dispose();
    if (picked == null || picked == current) return;
    await _updateOrder(c['id'] as int, picked);
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

  // ── Active / On Hold / Inactive ──────────────────────────────────────────
  // On Hold hides the client everywhere (Employee Workspace, Task Assign …)
  // until it is set back to Active.
  static String _stateOf(Map<String, dynamic> c) {
    final st = '${c['client_state'] ?? ''}'.toLowerCase();
    if (st == 'active' || st == 'hold' || st == 'inactive') return st;
    if (c['is_on_hold'] == 1 || c['is_on_hold'] == true || '${c['is_on_hold']}' == '1') return 'hold';
    return c['is_active'] == 1 || c['is_active'] == true || c['is_active'] == null ? 'active' : 'inactive';
  }

  static const Map<String, ({String label, IconData icon, Color fg, Color bg, Color border})> _stateStyle = {
    'active': (
      label: 'ACTIVE',
      icon: Icons.check_circle_rounded,
      fg: Color(0xFF159447),
      bg: Color(0xFFE8F8EF),
      border: Color(0xFF9BE3B8),
    ),
    'hold': (
      label: 'ON HOLD',
      icon: Icons.pause_circle_filled_rounded,
      fg: Color(0xFFB45309),
      bg: Color(0xFFFFF4E0),
      border: Color(0xFFF8C77A),
    ),
    'inactive': (
      label: 'IN-ACTIVE',
      icon: Icons.remove_circle_outline_rounded,
      fg: Color(0xFF64748B),
      bg: Color(0xFFF1F5F9),
      border: Color(0xFFD3DCE7),
    ),
  };

  Future<void> _setClientState(int id, String state, String companyName) async {
    if (state != 'active') {
      final hold = state == 'hold';
      final ok = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              icon: Icon(
                hold ? Icons.pause_circle_filled_rounded : Icons.remove_circle_outline_rounded,
                color: hold ? const Color(0xFFB45309) : const Color(0xFF64748B),
                size: 34,
              ),
              title: Text(hold ? 'Put client on hold?' : 'Mark client inactive?',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              content: Text(
                hold
                    ? '"$companyName" will be hidden from Employee Workspace, Task Assign and other active-client lists until you set it back to Active.'
                    : '"$companyName" will be marked In-Active and hidden from active-client lists.',
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hold ? const Color(0xFFE88900) : const Color(0xFF475569),
                  ),
                  child: Text(hold ? 'Put on hold' : 'Mark inactive', style: const TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ) ??
          false;
      if (!ok) return;
    }
    try {
      final token = Provider.of<AuthService>(context, listen: false).token;
      final response = await http.patch(
        Uri.parse('$_baseUrl/clients/$id'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'state': state}),
      );
      if (response.statusCode == 200) {
        await _fetchClients();
        final label = {'active': 'Active', 'hold': 'On Hold', 'inactive': 'In-Active'}[state];
        _showSnack('$companyName set to $label', success: true);
      } else {
        _showSnack('Failed to update status');
      }
    } catch (e) {
      _showSnack('Cannot connect to server');
    }
  }

  /// Status chip that opens Active / On Hold / Inactive.
  Widget _stateMenu(Map<String, dynamic> c, {bool expand = false}) {
    final int id = c['id'];
    final name = '${c['company_name'] ?? 'Client'}';
    final current = _stateOf(c);
    final style = _stateStyle[current]!;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      alignment: expand ? Alignment.center : null,
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(expand ? 10 : 7),
        border: Border.all(color: style.border),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(style.icon, size: 13, color: style.fg),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              style.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: expand ? 10 : 9, fontWeight: FontWeight.w900, color: style.fg),
            ),
          ),
          const SizedBox(width: 2),
          Icon(Icons.arrow_drop_down_rounded, size: 16, color: style.fg),
        ],
      ),
    );
    return PopupMenuButton<String>(
      tooltip: 'Change status',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) {
        if (v != current) _setClientState(id, v, name);
      },
      itemBuilder: (_) => [
        for (final key in const ['active', 'hold', 'inactive'])
          PopupMenuItem<String>(
            value: key,
            child: Row(
              children: [
                Icon(_stateStyle[key]!.icon, size: 18, color: _stateStyle[key]!.fg),
                const SizedBox(width: 10),
                Text(
                  {'active': 'Active', 'hold': 'On Hold', 'inactive': 'In-Active'}[key]!,
                  style: TextStyle(
                    fontWeight: key == current ? FontWeight.w900 : FontWeight.w600,
                    color: _stateStyle[key]!.fg,
                  ),
                ),
                if (key == current) ...[
                  const Spacer(),
                  const Icon(Icons.check_rounded, size: 16, color: Color(0xFF0052CC)),
                ],
              ],
            ),
          ),
      ],
      child: chip,
    );
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
      currentRoute: '/client-history',
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
                                _buildFilterTab('On Hold'),
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
                                    _buildFilterTab('On Hold'),
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

              // ── CLIENT CARDS ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text(
                  _loading ? 'Loading clients…' : '${filteredClients.length} client${filteredClients.length == 1 ? '' : 's'} · tap a card for details · tap the number to change S.No',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF0052CC))),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Center(
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
                  ),
                )
              else if (filteredClients.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: Text(
                      'No clients found.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                )
              else
                for (var i = 0; i < filteredClients.length; i++)
                  _buildClientCard(i, filteredClients[i], isMainAdmin, isMobile),
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



  // ─────────────────────────────────────────────────────────────
  // CLIENT CARDS (collapsed header + expandable details, like Invoices)
  // ─────────────────────────────────────────────────────────────

  static const _tileColors = [
    (Color(0xFFEAF2FF), Color(0xFF2563EB)),
    (Color(0xFFF3E8FF), Color(0xFF7C3AED)),
    (Color(0xFFDCFCE7), Color(0xFF16A34A)),
    (Color(0xFFFFE4E6), Color(0xFFE11D48)),
    (Color(0xFFFFF4E0), Color(0xFFD97706)),
  ];

  int _serialOf(Map<String, dynamic> c, int index) {
    final d = int.tryParse('${c['display_order'] ?? ''}') ?? 0;
    return d > 0 ? d : index + 1;
  }

  String _text(dynamic v, [String fallback = '—']) {
    final t = '${v ?? ''}'.trim();
    return t.isEmpty || t == 'null' ? fallback : t;
  }

  Widget _buildClientCard(int index, Map<String, dynamic> c, bool isMainAdmin, bool isMobile) {
    final int id = c['id'];
    final serial = _serialOf(c, index);
    final open = _expanded.contains(id);
    final status = '${c['status'] ?? 'draft'}';
    final colors = _statusColors(status);
    final percent = (int.tryParse('${c['completion_percent'] ?? 0}') ?? 0).clamp(0, 100);
    final tile = _tileColors[id % _tileColors.length];
    final industry = _text(c['industry'], '');
    final created = _formatDate(c['created_at']?.toString());

    final serialBox = Tooltip(
      message: 'Change S.No',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _askNewPosition(c, serial),
        child: Container(
          width: 46,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFDCE6F2)),
          ),
          child: Text('$serial',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
        ),
      ),
    );

    final iconBox = Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(color: tile.$1, borderRadius: BorderRadius.circular(12)),
      child: Icon(Icons.apartment_rounded, color: tile.$2, size: 24),
    );

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _text(c['company_name'], ''),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 3),
        Text(
          [if (industry.isNotEmpty) industry, if (created.isNotEmpty) created].join('   |   '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
        ),
      ],
    );

    final statusChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors['bg'],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors['fg']!.withValues(alpha: .25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_rounded, size: 13, color: colors['fg']),
          const SizedBox(width: 5),
          Text(status.toUpperCase(),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: colors['fg'])),
        ],
      ),
    );

    final completion = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$percent%',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: percent >= 100 ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
            )),
        const SizedBox(height: 4),
        SizedBox(
          width: 90,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 5,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation(
                percent >= 100 ? const Color(0xFF16A34A) : const Color(0xFF0052CC),
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        const Text('Completion', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
      ],
    );

    final chevron = AnimatedRotation(
      turns: open ? .5 : 0,
      duration: const Duration(milliseconds: 200),
      child: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF0F172A)),
    );

    final header = InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => open ? _expanded.remove(id) : _expanded.add(id)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: open ? const Color(0xFFF4F8FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      serialBox,
                      const SizedBox(width: 10),
                      iconBox,
                      const SizedBox(width: 10),
                      Expanded(child: title),
                      chevron,
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [statusChip, _stateMenu(c)],
                        ),
                      ),
                      completion,
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  serialBox,
                  const SizedBox(width: 14),
                  iconBox,
                  const SizedBox(width: 14),
                  Expanded(flex: 5, child: title),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [statusChip, _stateMenu(c)],
                    ),
                  ),
                  const SizedBox(width: 12),
                  completion,
                  const SizedBox(width: 18),
                  chevron,
                ],
              ),
      ),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: open ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
          width: open ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: open ? .05 : .025),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            if (open) _buildDetails(c, isMainAdmin, isMobile, percent),
          ],
        ),
      ),
    );
  }

  Widget _buildDetails(Map<String, dynamic> c, bool isMainAdmin, bool isMobile, int percent) {
    final int id = c['id'];
    final status = '${c['status'] ?? 'draft'}';
    final tiles = <Widget>[
      _infoTile(Icons.phone_rounded, 'Phone No', _text(c['client_phone'] ?? c['phone']), const Color(0xFF2563EB)),
      _infoTile(Icons.person_rounded, 'Contact Person', _text(c['contact_person']), const Color(0xFF7C3AED)),
      _infoTile(Icons.email_rounded, 'Email', _text(c['email']), const Color(0xFF0891B2)),
      _infoTile(Icons.category_rounded, 'Industry', _text(c['industry']), const Color(0xFFD97706)),
      _infoTile(Icons.receipt_long_rounded, 'GST Number', _text(c['gst_number']), const Color(0xFF475569)),
      _infoTile(Icons.vpn_key_rounded, 'Credentials', '${c['credential_count'] ?? 0}', const Color(0xFF16A34A),
          soft: const Color(0xFFF0FDF4)),
      _infoTile(Icons.event_rounded, 'Created On', _text(_formatDate(c['created_at']?.toString())),
          const Color(0xFF2563EB)),
      if (isMainAdmin)
        _infoTile(Icons.badge_rounded, 'Created By', _text(c['created_by_name'], 'Main Admin'), const Color(0xFF0052CC)),
    ];

    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.end,
      children: [
        OutlinedButton.icon(
          onPressed: () => _openOnboarding(clientId: id),
          icon: const Icon(Icons.edit_rounded, size: 17),
          label: const Text('Edit'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0052CC),
            side: const BorderSide(color: Color(0xFF93B4EC)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        if (status == 'draft' || status == 'pending' || status == 'verified')
          ElevatedButton.icon(
            onPressed: () => _updateStatus(
              id,
              status == 'draft' ? 'pending' : status == 'pending' ? 'verified' : 'complete',
            ),
            icon: Icon(
              status == 'verified' ? Icons.task_alt_rounded : Icons.arrow_forward_rounded,
              size: 17,
              color: Colors.white,
            ),
            label: Text(
              status == 'draft' ? 'Mark Pending' : status == 'pending' ? 'Verify' : 'Mark Complete',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'draft'
                  ? const Color(0xFFE88900)
                  : status == 'pending'
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF16A34A),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(color: const Color(0xFFE1F7E9), borderRadius: BorderRadius.circular(10)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 16, color: Color(0xFF159447)),
                SizedBox(width: 6),
                Text('Onboarding done', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF159447))),
              ],
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => _confirmDelete(id, c['company_name'] ?? 'this client'),
          icon: const Icon(Icons.delete_outline_rounded, size: 17),
          label: const Text('Delete'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFDC2626),
            side: const BorderSide(color: Color(0xFFFCA5A5)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final cols = w >= 1100 ? 4 : w >= 700 ? 3 : 2;
          const gap = 10.0;
          final tw = (w - gap * (cols - 1)) / cols;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [for (final t in tiles) SizedBox(width: tw, child: t)],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFD),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [_addressBlock(c), const SizedBox(height: 12), actions],
                      )
                    : Row(
                        children: [
                          Expanded(child: _addressBlock(c)),
                          const SizedBox(width: 12),
                          actions,
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _addressBlock(Map<String, dynamic> c) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_on_rounded, size: 20, color: Color(0xFF60A5FA)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Address', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                const SizedBox(height: 3),
                Text(
                  _text(c['address']),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _infoTile(IconData icon, String label, String value, Color color, {Color? soft}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: soft ?? const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
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