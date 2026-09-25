// lib/screens/admin_dashboard/emergency_broadcast_page.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/api_config.dart';
import '../../layouts/admin_layout.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

class EmergencyBroadcastPage extends StatefulWidget {
  const EmergencyBroadcastPage({super.key});

  @override
  State<EmergencyBroadcastPage> createState() => _EmergencyBroadcastPageState();
}

class _EmergencyBroadcastPageState extends State<EmergencyBroadcastPage> {
  bool _isBroadcastActive = true;
  bool _newClientAlertActive = true;
  bool _inactiveClientAlertActive = true;
  String _selectedSeverity = 'Warning';
  final TextEditingController _messageController = TextEditingController();
  
  bool _isClientTaskTargeted = false;
  String? _selectedEmployeeId;
  List<Map<String, dynamic>> _employees = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
    _fetchBroadcastSettings();
  }

  Future<Map<String, String>> _authHeaders() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${authService.token}',
    };
  }

  Future<void> _fetchEmployees() async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/employees'), headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _employees = List<Map<String, dynamic>>.from(data['data'] ?? []);
        });
      }
    } catch (e) {
      debugPrint("Error fetching employees: $e");
    }
  }

  Future<void> _fetchBroadcastSettings() async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/broadcast/settings'), headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isBroadcastActive = data['isActive'] ?? true;
          _newClientAlertActive = data['newClientEnabled'] ?? true;
          _inactiveClientAlertActive = data['inactiveClientEnabled'] ?? true;
          _messageController.text = data['message'] ?? '';
          _selectedSeverity = data['severity'] ?? 'Warning';
        });
      }
    } catch (e) {
      debugPrint("Error fetching settings: $e");
    }
  }

  Future<void> _saveAndSendBroadcast() async {
    setState(() => _isLoading = true);
    try {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/broadcast/send'),
        headers: headers,
        body: jsonEncode({
          'isActive': _isBroadcastActive,
          'newClientEnabled': _newClientAlertActive,
          'inactiveClientEnabled': _inactiveClientAlertActive,
          'message': _messageController.text,
          'severity': _selectedSeverity,
          'targetEmployeeId': _isClientTaskTargeted ? _selectedEmployeeId : null,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Broadcast and triggers updated successfully!'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update broadcast settings'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      pageTitle: 'Emergency & Broadcast Master',
      currentRoute: '/emergency-broadcast',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Broadcast & Automation Master',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Control global popups, new client task alerts, and inactive client popups for employees.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 24),

              SwitchListTile(
                title: const Text('Enable General Popup Broadcast', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Global master toggle to turn off all popups if needed'),
                value: _isBroadcastActive,
                activeColor: Colors.green,
                onChanged: (val) => setState(() => _isBroadcastActive = val),
              ),
              const Divider(height: 20),

              SwitchListTile(
                title: const Text('New Client Task Assignment Popup', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('When ON, assigned employees get a mandatory popup for new client tasks'),
                value: _newClientAlertActive,
                activeColor: Colors.blue,
                onChanged: (val) => setState(() => _newClientAlertActive = val),
              ),
              const Divider(height: 20),

              SwitchListTile(
                title: const Text('Inactive Client Warning Popup', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('When ON, employees linked to an inactive client receive a warning popup'),
                value: _inactiveClientAlertActive,
                activeColor: Colors.orange,
                onChanged: (val) => setState(() => _inactiveClientAlertActive = val),
              ),
              const Divider(height: 30),

              const Text('Select Alert Severity & Icon', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildSeverityChip('Emergency', Icons.error_outline, Colors.red),
                  const SizedBox(width: 12),
                  _buildSeverityChip('Warning', Icons.warning_amber_rounded, Colors.orange),
                  const SizedBox(width: 12),
                  _buildSeverityChip('Important', Icons.info_outline, Colors.blue),
                ],
              ),
              const SizedBox(height: 24),

              const Text('Manual Broadcast Message', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 10),
              TextField(
                controller: _messageController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Type announcement or custom notification...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),

              CheckboxListTile(
                title: const Text('Target specific employee for New Client / Task assignment'),
                subtitle: const Text('If checked, message will only be sent to the selected employee'),
                value: _isClientTaskTargeted,
                onChanged: (val) => setState(() => _isClientTaskTargeted = val ?? false),
              ),

              if (_isClientTaskTargeted) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _selectedEmployeeId,
                  hint: const Text('Select Target Employee'),
                  items: _employees.map((emp) {
                    return DropdownMenuItem<String>(
                      value: emp['id']?.toString(),
                      child: Text(emp['full_name'] ?? emp['name'] ?? 'Employee'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedEmployeeId = val),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],

              const SizedBox(height: 35),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0757D5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _saveAndSendBroadcast,
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save & Apply Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeverityChip(String label, IconData icon, Color color) {
    bool isSelected = _selectedSeverity == label;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: isSelected ? Colors.white : color),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      selectedColor: color,
      onSelected: (selected) {
        if (selected) setState(() => _selectedSeverity = label);
      },
    );
  }
}