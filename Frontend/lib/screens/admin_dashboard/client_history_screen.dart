import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../layouts/admin_layout.dart';
import 'client_onboarding_screen.dart';
import '../../services/api_config.dart';


class ClientHistoryScreen extends StatefulWidget {
  const ClientHistoryScreen({super.key});

  @override
  State<ClientHistoryScreen> createState() => _ClientHistoryScreenState();
}

class _ClientHistoryScreenState extends State<ClientHistoryScreen> {
  // static const String _baseUrl = '/api';
  static String get _baseUrl => ApiConfig.baseUrl;

  List<Map<String, dynamic>> _clients = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  Future<void> _fetchClients() async {
    setState(() { _loading = true; _error = null; });
    try {
      final response = await http.get(Uri.parse('$_baseUrl/clients'));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          _clients = List<Map<String, dynamic>>.from(body['data']);
          _loading = false;
        });
      } else {
        setState(() { _error = 'Server returned ${response.statusCode}'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Cannot connect to server'; _loading = false; });
    }
  }

  // ── Update status via Verify / Pending buttons ────────────────────────────────
  Future<void> _updateStatus(int id, String status) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/clients/$id/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': status}),
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

  // ── DELETE client ──────────────────────────────────────────────────────────────
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

  void _confirmDelete(int id, String companyName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Client'),
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
    ));
  }

  // ── Status badge colors ────────────────────────────────────────────────────────
  Map<String, Color> _statusColors(String status) {
    switch (status) {
      case 'complete':
        return {'bg': const Color(0xFFDCFCE7), 'fg': const Color(0xFF16A34A)};
      case 'verified':
        return {'bg': const Color(0xFFDBEAFE), 'fg': const Color(0xFF2563EB)};
      case 'pending':
        return {'bg': const Color(0xFFFEF3C7), 'fg': const Color(0xFFD97706)};
      default: // draft
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
      MaterialPageRoute(builder: (_) => ClientOnboardingScreen(clientId: clientId)),
    );
    _fetchClients(); // refresh after returning
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      pageTitle: 'Client Onboarding',
      currentRoute: '/client',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header ─────────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Client History',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                  SizedBox(height: 4),
                  Text('Track onboarding progress, verification, and registration status for every client.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                ],
              ),
              Row(children: [
                IconButton(
                  onPressed: _fetchClients,
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0052CC)),
                  tooltip: 'Refresh',
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _openOnboarding(),
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0052CC),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    elevation: 0,
                  ),
                  label: const Text('Client Onboarding',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ]),
            ],
          ),

          const SizedBox(height: 24),

          // ── Table ──────────────────────────────────────────────────────────
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
                  child: Row(children: const [
                    Expanded(flex: 3, child: Text('COMPANY', style: _th)),
                    Expanded(flex: 2, child: Text('CONTACT', style: _th)),
                    Expanded(flex: 2, child: Text('CREATED', style: _th)),
                    Expanded(flex: 3, child: Text('COMPLETION', style: _th)),
                    Expanded(flex: 2, child: Text('STATUS', style: _th, )),
                    Expanded(flex: 3, child: Align(alignment: Alignment.centerRight, child: Text('ACTIONS', style: _th))),
                  ]),
                ),

                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF0052CC))),
                  )
                else if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(child: Column(children: [
                      Text(_error!, style: const TextStyle(color: Color(0xFF64748B))),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchClients,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052CC)),
                        child: const Text('Retry', style: TextStyle(color: Colors.white)),
                      ),
                    ])),
                  )
                else if (_clients.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: Text('No clients yet. Click "Client Onboarding" to add one.',
                        style: TextStyle(color: Color(0xFF94A3B8)))),
                  )
                else
                  ..._clients.asMap().entries.expand((entry) {
                    final i = entry.key;
                    final c = entry.value;
                    final row = _buildRow(c);
                    if (i < _clients.length - 1) {
                      return [row, const Divider(height: 1, color: Color(0xFFE2E8F0))];
                    }
                    return [row];
                  }),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildRow(Map<String, dynamic> c) {
    final int    id      = c['id'];
    final String status  = c['status'] ?? 'draft';
    final int    percent = c['completion_percent'] ?? 0;
    final colors = _statusColors(status);

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: Colors.white,
      child: Row(
        children: [
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

          // Actions
          Expanded(flex: 3, child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [

              // Edit / continue onboarding (with icon)
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

              // Pending / Verify toggle button
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

              // Delete client (icon-only)
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

  static const TextStyle _th = TextStyle(
      fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5);
}