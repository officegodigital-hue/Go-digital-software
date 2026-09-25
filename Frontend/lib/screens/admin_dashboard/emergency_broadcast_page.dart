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

class _EmergencyBroadcastPageState extends State<EmergencyBroadcastPage>
    with TickerProviderStateMixin {
  bool _isBroadcastActive = true;
  bool _newClientAlertActive = true;
  bool _inactiveClientAlertActive = true;
  String _selectedSeverity = 'Warning';
  final TextEditingController _messageController = TextEditingController();
  
  bool _isClientTaskTargeted = false;
  String? _selectedEmployeeId;
  List<Map<String, dynamic>> _employees = [];
  bool _isLoading = false;
  late AnimationController _pageController;
  late AnimationController _pulseController;
  late Animation<double> _pageFade;
  late Animation<Offset> _pageSlide;

  @override
  void initState() {
    super.initState();

    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pageFade = CurvedAnimation(
      parent: _pageController,
      curve: Curves.easeOutCubic,
    );
    _pageSlide = Tween<Offset>(
      begin: const Offset(0, 0.035),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _pageController,
      curve: Curves.easeOutCubic,
    ));

    _pageController.forward();
    _fetchEmployees();
    _fetchBroadcastSettings();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
    _messageController.dispose();
    super.dispose();
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 700;
          final horizontal = isMobile ? 14.0 : 28.0;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 30),
            child: FadeTransition(
              opacity: _pageFade,
              child: SlideTransition(
                position: _pageSlide,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHero(isMobile),
                    const SizedBox(height: 18),
                    _buildControlGrid(isMobile),
                    const SizedBox(height: 18),
                    _buildBroadcastComposer(isMobile),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHero(bool isMobile) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glow = 8 + (_pulseController.value * 10);
        return Container(
          padding: EdgeInsets.all(isMobile ? 18 : 26),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF062B73),
                Color(0xFF0757D5),
                Color(0xFF2D8CFF),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1476FF).withValues(alpha: .20),
                blurRadius: glow,
                spreadRadius: 1,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -35,
                top: -45,
                child: _glowOrb(110, Colors.white.withValues(alpha: .09)),
              ),
              Positioned(
                right: 45,
                bottom: -65,
                child: _glowOrb(130, Colors.cyanAccent.withValues(alpha: .08)),
              ),
              child!,
            ],
          ),
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: isMobile ? 52 : 64,
            height: isMobile ? 52 : 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: .25),
              ),
            ),
            child: const Icon(
              Icons.campaign_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          SizedBox(width: isMobile ? 14 : 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BROADCAST CONTROL',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .72),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Broadcast & Automation Master',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 21 : 28,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Control employee alerts, client triggers and manual announcements from one place.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .82),
                    fontSize: isMobile ? 12 : 13.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  Widget _buildControlGrid(bool isMobile) {
    final cards = [
      _buildToggleCard(
        icon: Icons.public_rounded,
        title: 'General Broadcast',
        subtitle: 'Master switch for manual popup messages.',
        value: _isBroadcastActive,
        accent: const Color(0xFF0757D5),
        onChanged: (v) => setState(() => _isBroadcastActive = v),
      ),
      _buildToggleCard(
        icon: Icons.assignment_turned_in_rounded,
        title: 'New Client Task',
        subtitle: 'Show information popup for newly assigned tasks.',
        value: _newClientAlertActive,
        accent: const Color(0xFF1687FF),
        onChanged: (v) => setState(() => _newClientAlertActive = v),
      ),
      _buildToggleCard(
        icon: Icons.domain_disabled_rounded,
        title: 'Inactive Client',
        subtitle: 'Notify employees when an assigned client becomes inactive.',
        value: _inactiveClientAlertActive,
        accent: const Color(0xFF0A67C7),
        onChanged: (v) => setState(() => _inactiveClientAlertActive = v),
      ),
    ];

    return isMobile
        ? Column(
            children: [
              cards[0],
              const SizedBox(height: 12),
              cards[1],
              const SizedBox(height: 12),
              cards[2],
            ],
          )
        : Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 14),
              Expanded(child: cards[1]),
              const SizedBox(width: 14),
              Expanded(child: cards[2]),
            ],
          );
  }

  Widget _buildToggleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Color accent,
    required ValueChanged<bool> onChanged,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: value ? accent.withValues(alpha: .35) : const Color(0xFFE2EAF5),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B4EA2).withValues(alpha: .06),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: .16),
                  accent.withValues(alpha: .06),
                ],
              ),
            ),
            child: Icon(icon, color: accent, size: 24),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      color: Color(0xFF0B1F3A),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(height: 4),
                Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF718096),
                      fontSize: 11.5,
                      height: 1.3,
                    )),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Switch.adaptive(
            value: value,
            activeTrackColor: const Color(0xFF1476FF),
            activeThumbColor: Colors.white,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildBroadcastComposer(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 17 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE0E9F5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B4EA2).withValues(alpha: .07),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            Icons.tune_rounded,
            'Message Composer',
            'Create a manual broadcast and choose exactly who should receive it.',
          ),
          const SizedBox(height: 22),
          Text(
            'ALERT SEVERITY',
            style: TextStyle(
              color: const Color(0xFF31527A).withValues(alpha: .75),
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildSeverityChip('Emergency', Icons.error_outline_rounded,
                  const Color(0xFF0757D5)),
              _buildSeverityChip('Warning', Icons.warning_amber_rounded,
                  const Color(0xFF1476FF)),
              _buildSeverityChip('Important', Icons.info_outline_rounded,
                  const Color(0xFF0B66C3)),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _messageController,
            maxLines: isMobile ? 5 : 4,
            style: const TextStyle(
              color: Color(0xFF102A43),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'Type your announcement or custom notification...',
              hintStyle: const TextStyle(
                color: Color(0xFF9AAAC0),
                fontWeight: FontWeight.w500,
              ),
              filled: true,
              fillColor: const Color(0xFFF7FAFF),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 14, right: 10, top: 13),
                child: Icon(Icons.edit_note_rounded,
                    color: Color(0xFF1476FF)),
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 52, minHeight: 52),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFDCE7F5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFDCE7F5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: Color(0xFF1476FF), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F9FF),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: const Color(0xFFDCE9F8)),
            ),
            child: Column(
              children: [
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'Target a specific employee',
                    style: TextStyle(
                      color: Color(0xFF16365F),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: const Text(
                    'When enabled, the broadcast is limited to the selected employee.',
                    style: TextStyle(
                      color: Color(0xFF718096),
                      fontSize: 11,
                    ),
                  ),
                  value: _isClientTaskTargeted,
                  activeColor: const Color(0xFF0757D5),
                  onChanged: (val) => setState(
                    () => _isClientTaskTargeted = val ?? false,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) =>
                      SizeTransition(sizeFactor: animation, child: child),
                  child: _isClientTaskTargeted
                      ? Padding(
                          key: const ValueKey('employee-selector'),
                          padding: const EdgeInsets.only(top: 8),
                          child: DropdownButtonFormField<String>(
                            value: _selectedEmployeeId,
                            hint: const Text('Select Target Employee'),
                            items: _employees.map((emp) {
                              return DropdownMenuItem<String>(
                                value: emp['id']?.toString(),
                                child: Text(
                                  emp['full_name'] ??
                                      emp['name'] ??
                                      'Employee',
                                ),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setState(() => _selectedEmployeeId = val),
                            decoration: InputDecoration(
                              labelText: 'Employee',
                              prefixIcon: const Icon(
                                Icons.person_outline_rounded,
                                color: Color(0xFF1476FF),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: Color(0xFFDCE7F5)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: Color(0xFFDCE7F5)),
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(
                          key: ValueKey('no-employee-selector'),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: isMobile ? 54 : 56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF043A91), Color(0xFF1476FF)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1476FF).withValues(alpha: .25),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _isLoading ? null : _saveAndSendBroadcast,
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.rocket_launch_rounded,
                              color: Colors.white, size: 20),
                          SizedBox(width: 9),
                          Text(
                            'SAVE & APPLY SETTINGS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .7,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [Color(0xFFEAF3FF), Color(0xFFD8EAFF)],
            ),
          ),
          child: const Icon(Icons.tune_rounded,
              color: Color(0xFF0757D5), size: 23),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                    color: Color(0xFF0B1F3A),
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  )),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(
                    color: Color(0xFF718096),
                    fontSize: 12,
                    height: 1.35,
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSeverityChip(String label, IconData icon, Color color) {
    final isSelected = _selectedSeverity == label;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: isSelected
            ? const LinearGradient(
                colors: [Color(0xFF043A91), Color(0xFF1476FF)],
              )
            : null,
        color: isSelected ? null : const Color(0xFFF5F9FF),
        border: Border.all(
          color: isSelected ? const Color(0xFF1476FF) : const Color(0xFFDCE7F5),
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFF1476FF).withValues(alpha: .18),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ]
            : [],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _selectedSeverity = label),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 19,
                color: isSelected ? Colors.white : color,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF24415F),
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}