// lib/screens/profile_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:godigital_portal/services/auth_service.dart';
import 'package:godigital_portal/services/api_config.dart';

const List<String> _avatarColorOptions = [
  '#4F46E5', '#0EA5E9', '#16A34A', '#D97706',
  '#DC2626', '#7C3AED', '#0891B2', '#334155',
];

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static String get _baseUrl => ApiConfig.baseUrl;

  late TextEditingController _firstNameCtrl;
  late TextEditingController _middleNameCtrl; // 🟢 Added Middle Name Controller
  late TextEditingController _lastNameCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _aadharCtrl;
  late TextEditingController _panCtrl;
  late TextEditingController _bankAccountNameCtrl;
  late TextEditingController _bankAccountNumberCtrl;
  late TextEditingController _bankIfscCtrl;
  late TextEditingController _bankNameCtrl;
  late TextEditingController _permAddressCtrl;
  late TextEditingController _tempAddressCtrl;

  String _staffId = '';
  String _role = '';
  String _avatarColorHex = _avatarColorOptions.first;
  String? _profilePhotoDataUrl;
  bool _photoChanged = false;
  bool _loadingProfile = true;
  bool _saving = false;

  static const Color primary = Color(0xFF075EF7);
  static const Color dark = Color(0xFF061457);
  static const Color textDark = Color(0xFF14213D);
  static const Color muted = Color(0xFF718096);
  static const Color border = Color(0xFFE4EAF3);
  static const Color bg = Color(0xFFF5F8FC);

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController();
    _middleNameCtrl = TextEditingController();
    _lastNameCtrl = TextEditingController();
    _usernameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _aadharCtrl = TextEditingController();
    _panCtrl = TextEditingController();
    _bankAccountNameCtrl = TextEditingController();
    _bankAccountNumberCtrl = TextEditingController();
    _bankIfscCtrl = TextEditingController();
    _bankNameCtrl = TextEditingController();
    _permAddressCtrl = TextEditingController();
    _tempAddressCtrl = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _aadharCtrl.dispose();
    _panCtrl.dispose();
    _bankAccountNameCtrl.dispose();
    _bankAccountNumberCtrl.dispose();
    _bankIfscCtrl.dispose();
    _bankNameCtrl.dispose();
    _permAddressCtrl.dispose();
    _tempAddressCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final auth = context.read<AuthService>();
    final id = auth.userId;
    setState(() => _loadingProfile = true);

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/employees/$id'),
        headers: {'Authorization': 'Bearer ${auth.token}'},
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = Map<String, dynamic>.from(body['data'] ?? {});

        _firstNameCtrl.text = data['first_name'] ?? '';
        _middleNameCtrl.text = data['middle_name'] ?? '';
        _lastNameCtrl.text = data['last_name'] ?? '';
        _usernameCtrl.text = data['username'] ?? '';
        _emailCtrl.text = data['email'] ?? '';
        _phoneCtrl.text = data['phone_number'] ?? '';
        _aadharCtrl.text = data['aadhar_number'] ?? '';
        _panCtrl.text = data['pan_card_number'] ?? '';
        _bankAccountNameCtrl.text = data['bank_account_name'] ?? '';
        _bankAccountNumberCtrl.text = data['bank_account_number'] ?? '';
        _bankIfscCtrl.text = data['bank_ifsc_code'] ?? '';
        _bankNameCtrl.text = data['bank_name'] ?? '';
        _permAddressCtrl.text = data['permanent_address'] ?? '';
        _tempAddressCtrl.text = data['temporary_address'] ?? '';

        _staffId = data['staff_id'] ?? '';
        _role = data['role'] ?? '';
        _avatarColorHex = (data['avatar_color'] ?? '').toString().isNotEmpty
            ? data['avatar_color']
            : _avatarColorOptions.first;
        _profilePhotoDataUrl = (data['profile_photo'] ?? '').toString().isNotEmpty
            ? data['profile_photo']
            : null;
      }
    } catch (_) {}

    if (mounted) setState(() => _loadingProfile = false);
  }

  Color _color(String h) {
    try {
      final s = h.replaceAll('#', '');
      return Color(int.parse('FF$s', radix: 16));
    } catch (_) {
      return primary;
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (pickedFile == null) return;
      final bytes = await pickedFile.readAsBytes();
      final mime = pickedFile.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
      setState(() {
        _profilePhotoDataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
        _photoChanged = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick photo: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _removePhoto() => setState(() {
        _profilePhotoDataUrl = null;
        _photoChanged = true;
      });

  Future<void> _saveProfile({String? passwordOverride}) async {
    if (_firstNameCtrl.text.trim().isEmpty ||
        _lastNameCtrl.text.trim().isEmpty ||
        _usernameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('First name, last name, username and email are required'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final auth = context.read<AuthService>();
    final id = auth.userId;
    setState(() => _saving = true);

    try {
      final body = {
        'firstName': _firstNameCtrl.text.trim(),
        'middleName': _middleNameCtrl.text.trim(), // 🟢 Included Middle Name
        'lastName': _lastNameCtrl.text.trim(),
        'username': _usernameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phoneNumber': _phoneCtrl.text.trim(),
        'aadharNumber': _aadharCtrl.text.trim(),
        'panCardNumber': _panCtrl.text.trim(),
        'bankAccountName': _bankAccountNameCtrl.text.trim(),
        'bankAccountNumber': _bankAccountNumberCtrl.text.trim(),
        'bankIfscCode': _bankIfscCtrl.text.trim(),
        'bankName': _bankNameCtrl.text.trim(),
        'permanentAddress': _permAddressCtrl.text.trim(),
        'temporaryAddress': _tempAddressCtrl.text.trim(),
        'avatarColor': _avatarColorHex,
        if (passwordOverride != null && passwordOverride.trim().isNotEmpty) 'password': passwordOverride.trim(),
        if (_photoChanged) 'profilePhoto': _profilePhotoDataUrl,
      };

      final response = await http.put(
        Uri.parse('$_baseUrl/employees/$id/profile'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${auth.token}'},
        body: jsonEncode(body),
      );

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200 && decoded['success'] == true) {
        _photoChanged = false;
        await auth.refreshUserData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Color(0xFF00A854)),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(decoded['message'] ?? 'Could not save profile'), backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // 🟢 Change Password Dialog Popup
  void _changePassword() {
    final curCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final conCtrl = TextEditingController();
    bool obscureCur = true;
    bool obscureNew = true;
    bool obscureCon = true;

    showDialog(
      context: context,
      builder: (dc) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: const Color(0xFFD97706).withValues(alpha: 0.09), borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.lock_reset_rounded, color: Color(0xFFD97706), size: 21),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Change Password', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: textDark))),
            ]),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: curCtrl,
                    obscureText: obscureCur,
                    decoration: InputDecoration(
                      hintText: 'Current Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19, color: muted),
                      suffixIcon: IconButton(
                        icon: Icon(obscureCur ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 19, color: muted),
                        onPressed: () => setStateDialog(() => obscureCur = !obscureCur),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFFBFCFE),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: border)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newCtrl,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      hintText: 'New Password',
                      prefixIcon: const Icon(Icons.password_rounded, size: 19, color: muted),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 19, color: muted),
                        onPressed: () => setStateDialog(() => obscureNew = !obscureNew),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFFBFCFE),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: border)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: conCtrl,
                    obscureText: obscureCon,
                    decoration: InputDecoration(
                      hintText: 'Confirm New Password',
                      prefixIcon: const Icon(Icons.verified_user_outlined, size: 19, color: muted),
                      suffixIcon: IconButton(
                        icon: Icon(obscureCon ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 19, color: muted),
                        onPressed: () => setStateDialog(() => obscureCon = !obscureCon),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFFBFCFE),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: border)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dc),
                child: const Text('Cancel', style: TextStyle(color: muted, fontWeight: FontWeight.w700)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (curCtrl.text.trim().isEmpty || newCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(dc).showSnackBar(const SnackBar(content: Text('All password fields are required'), backgroundColor: Colors.redAccent));
                    return;
                  }
                  if (newCtrl.text != conCtrl.text) {
                    ScaffoldMessenger.of(dc).showSnackBar(const SnackBar(content: Text('New passwords do not match'), backgroundColor: Colors.redAccent));
                    return;
                  }
                  Navigator.pop(dc);
                  await _saveProfile(passwordOverride: newCtrl.text);
                },
                style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
                child: const Text('Update Password'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: _loadingProfile
                  ? const Center(child: CircularProgressIndicator())
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final mobile = constraints.maxWidth < 700;
                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(mobile ? 16 : 30, mobile ? 14 : 24, mobile ? 16 : 30, 40),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1180),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildHeader(mobile),
                                  const SizedBox(height: 20),
                                  _buildProfileCard(mobile),
                                  const SizedBox(height: 18),
                                  _buildSection(
                                    Icons.person_outline_rounded,
                                    primary,
                                    'Personal Information',
                                    'Update your first, middle, and last name details.',
                                    _buildPersonalFields(mobile),
                                  ),
                                  const SizedBox(height: 18),
                                  _buildSection(
                                    Icons.badge_outlined,
                                    const Color(0xFF0891B2),
                                    'Identification & Contact',
                                    'Phone, Aadhaar, and PAN card details.',
                                    _buildIdFields(mobile),
                                  ),
                                  const SizedBox(height: 18),
                                  _buildSection(
                                    Icons.account_balance_outlined,
                                    const Color(0xFFD97706),
                                    'Bank Details (For Pay Slip)',
                                    'Bank account and branch IFSC info for salary processing.',
                                    _buildBankFields(mobile),
                                  ),
                                  const SizedBox(height: 18),
                                  _buildSection(
                                    Icons.location_on_outlined,
                                    const Color(0xFF7C3AED),
                                    'Address Details',
                                    'Permanent and temporary residential addresses.',
                                    _buildAddressFields(mobile),
                                  ),
                                  const SizedBox(height: 18),
                                  _buildSection(
                                    Icons.shield_outlined,
                                    const Color(0xFFD97706),
                                    'Password & Security',
                                    'Keep your account secure with a strong password.',
                                    _buildSecuritySection(mobile),
                                  ),
                                  const SizedBox(height: 18),
                                  _buildSection(
                                    Icons.work_outline_rounded,
                                    const Color(0xFF10B981),
                                    'Work Information (Managed by Admin)',
                                    'Staff ID and assigned role.',
                                    _buildWorkFields(mobile),
                                  ),
                                  const SizedBox(height: 24),
                                  _buildActions(mobile),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final authService = context.read<AuthService>();
    final user = authService.user ?? {};
    final firstName = (user['first_name'] ?? user['firstName'] ?? _firstNameCtrl.text).toString();
    final lastName = (user['last_name'] ?? user['lastName'] ?? _lastNameCtrl.text).toString();
    final initials = ((firstName.isNotEmpty ? firstName[0] : '') + (lastName.isNotEmpty ? lastName[0] : '')).toUpperCase();
    final avatarColor = user['avatar_color'] ?? user['avatarColor'] ?? _avatarColorHex;
    final profilePhoto = user['profile_photo'] ?? user['profilePhoto'] ?? _profilePhotoDataUrl;

    return Container(
      margin: EdgeInsets.fromLTRB(compact ? 12 : 24, 10, compact ? 12 : 24, 0),
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 22, vertical: compact ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(color: const Color(0xFF5E8FD8).withValues(alpha: 0.08), blurRadius: 28, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: dark),
            tooltip: 'Back',
          ),
          const SizedBox(width: 8),
          Text(
            'Profile Settings',
            style: TextStyle(fontSize: compact ? 15 : 17, fontWeight: FontWeight.w800, color: textDark),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(children: [
                  Icon(Icons.person_outline_rounded, color: primary, size: 20),
                  SizedBox(width: 10),
                  Text('Profile', style: TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ),
              const PopupMenuItem(
                value: 'workspace',
                child: Row(children: [
                  Icon(Icons.grid_view_rounded, color: primary, size: 20),
                  SizedBox(width: 10),
                  Text('Workspace', style: TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(children: [
                  Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
                  SizedBox(width: 10),
                  Text('Logout', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700)),
                ]),
              ),
            ],
            onSelected: (value) {
              if (value == 'workspace') {
                Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/home', (route) => false);
              } else if (value == 'logout') {
                authService.logout();
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: primary.withValues(alpha: 0.3), width: 2),
              ),
              child: CircleAvatar(
                radius: compact ? 16 : 19,
                backgroundColor: _color(avatarColor.toString()),
                backgroundImage: profilePhoto != null && profilePhoto.toString().isNotEmpty
                    ? MemoryImage(base64Decode(profilePhoto.toString().split(',').last))
                    : null,
                child: profilePhoto == null || profilePhoto.toString().isEmpty
                    ? Text(
                        initials.isEmpty ? '?' : initials,
                        style: TextStyle(color: Colors.white, fontSize: compact ? 12 : 14, fontWeight: FontWeight.w900),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool m) => Container(
        padding: EdgeInsets.symmetric(horizontal: m ? 18 : 26, vertical: m ? 20 : 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [dark, primary]),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: Row(
          children: [
            Container(
              width: m ? 46 : 54,
              height: m ? 46 : 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(Icons.person_rounded, color: Colors.white, size: 25),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Profile Management', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                  SizedBox(height: 4),
                  Text('View and edit your complete profile and payroll details.', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildProfileCard(bool m) {
    final initials = ((_firstNameCtrl.text.isNotEmpty ? _firstNameCtrl.text[0] : '') +
            (_lastNameCtrl.text.isNotEmpty ? _lastNameCtrl.text[0] : ''))
        .toUpperCase();
    final name = [_firstNameCtrl.text.trim(), _middleNameCtrl.text.trim(), _lastNameCtrl.text.trim()]
        .where((x) => x.isNotEmpty)
        .join(' ');

    ImageProvider? photoProvider;
    if (_profilePhotoDataUrl != null) {
      try {
        photoProvider = MemoryImage(base64Decode(_profilePhotoDataUrl!.split(',').last));
      } catch (_) {}
    }

    final infoColumn = Column(
      crossAxisAlignment: m ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(name.isEmpty ? 'Employee Profile' : name,
            style: TextStyle(fontSize: m ? 20 : 22, fontWeight: FontWeight.w900, color: textDark)),
        const SizedBox(height: 5),
        Text(_emailCtrl.text.trim().isEmpty ? 'Add email address' : _emailCtrl.text.trim(),
            style: const TextStyle(fontSize: 12.5, color: muted, fontWeight: FontWeight.w500)),
        if (_role.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 9),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFEAF2FF), borderRadius: BorderRadius.circular(30)),
              child: Text(_role, style: const TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ),
      ],
    );

    final toolsColumn = Column(
      crossAxisAlignment: m ? CrossAxisAlignment.center : CrossAxisAlignment.end,
      children: [
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.cloud_upload_outlined, size: 17),
              label: Text(_profilePhotoDataUrl != null ? 'Change Photo' : 'Upload Photo'),
              style: OutlinedButton.styleFrom(foregroundColor: primary),
            ),
            if (_profilePhotoDataUrl != null)
              TextButton.icon(
                onPressed: _removePhoto,
                icon: const Icon(Icons.delete_outline_rounded, size: 17),
                label: const Text('Remove'),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          children: _avatarColorOptions.map((h) {
            final selected = h == _avatarColorHex;
            return GestureDetector(
              onTap: () => setState(() => _avatarColorHex = h),
              child: Container(
                width: selected ? 26 : 22,
                height: selected ? 26 : 22,
                decoration: BoxDecoration(
                  color: _color(h),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: selected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
              ),
            );
          }).toList(),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.all(m ? 18 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.035), blurRadius: 18, offset: const Offset(0, 7))],
      ),
      child: m
          ? Column(children: [
              CircleAvatar(radius: 46, backgroundColor: _color(_avatarColorHex), backgroundImage: photoProvider,
                  child: photoProvider == null ? Text(initials, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)) : null),
              const SizedBox(height: 14),
              infoColumn,
              const SizedBox(height: 16),
              toolsColumn,
            ])
          : Row(children: [
              CircleAvatar(radius: 48, backgroundColor: _color(_avatarColorHex), backgroundImage: photoProvider,
                  child: photoProvider == null ? Text(initials, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)) : null),
              const SizedBox(width: 20),
              Expanded(child: infoColumn),
              const SizedBox(width: 20),
              SizedBox(width: 380, child: toolsColumn),
            ]),
    );
  }

  Widget _buildSection(IconData icon, Color color, String title, String sub, Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(13)),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: textDark, fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(sub, style: const TextStyle(color: muted, fontSize: 11.5)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 20),
            child,
          ],
        ),
      );

  // 🟢 Personal fields with First Name, Middle Name, and Last Name
  Widget _buildPersonalFields(bool m) => m
      ? Column(
          children: [
            _textField('First Name', _firstNameCtrl, Icons.person_outline_rounded),
            const SizedBox(height: 14),
            _textField('Middle Name', _middleNameCtrl, Icons.person_outline_rounded, required: false),
            const SizedBox(height: 14),
            _textField('Last Name', _lastNameCtrl, Icons.person_outline_rounded),
          ],
        )
      : Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _textField('First Name', _firstNameCtrl, Icons.person_outline_rounded)),
            const SizedBox(width: 16),
            Expanded(child: _textField('Middle Name', _middleNameCtrl, Icons.person_outline_rounded, required: false)),
            const SizedBox(width: 16),
            Expanded(child: _textField('Last Name', _lastNameCtrl, Icons.person_outline_rounded)),
          ],
        );

  Widget _buildIdFields(bool m) => Column(
        children: [
          _row(
            m,
            _textField('Phone Number', _phoneCtrl, Icons.phone_outlined, required: false),
            _textField('PAN Card Number', _panCtrl, Icons.credit_card_outlined, required: false),
          ),
          const SizedBox(height: 16),
          _textField('Aadhaar Number', _aadharCtrl, Icons.badge_outlined, required: false),
        ],
      );

  Widget _buildBankFields(bool m) => Column(
        children: [
          _row(
            m,
            _textField('Account Holder Name', _bankAccountNameCtrl, Icons.person_outline, required: false),
            _textField('Account Number', _bankAccountNumberCtrl, Icons.numbers_outlined, required: false),
          ),
          const SizedBox(height: 16),
          _row(
            m,
            _textField('IFSC Code', _bankIfscCtrl, Icons.code_outlined, required: false),
            _textField('Bank Name & Branch', _bankNameCtrl, Icons.account_balance_wallet_outlined, required: false),
          ),
        ],
      );

  Widget _buildAddressFields(bool m) => _row(
        m,
        _textField('Permanent Address', _permAddressCtrl, Icons.home_outlined, required: false),
        _textField('Temporary Address', _tempAddressCtrl, Icons.location_city_outlined, required: false),
      );

  Widget _buildSecuritySection(bool m) => OutlinedButton.icon(
        onPressed: _changePassword,
        icon: const Icon(Icons.lock_reset_rounded, size: 18),
        label: const Text('Change Account Password'),
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

  Widget _buildWorkFields(bool m) => _row(
        m,
        _lockedField('Staff ID', _staffId.isEmpty ? '—' : _staffId, Icons.badge_outlined),
        _lockedField('Role', _role.isEmpty ? '—' : _role, Icons.work_outline_rounded),
      );

  Widget _row(bool m, Widget a, Widget b) => m
      ? Column(children: [a, const SizedBox(height: 14), b])
      : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 16), Expanded(child: b)]);

  Widget _textField(String label, TextEditingController controller, IconData icon, {bool required = true}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: textDark)),
            if (required) const Text(' *', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 7),
          TextField(
            controller: controller,
            style: const TextStyle(fontSize: 13.5, color: textDark, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Enter $label',
              prefixIcon: Icon(icon, size: 19, color: const Color(0xFF8995AA)),
              filled: true,
              fillColor: const Color(0xFFFBFCFE),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: primary, width: 1.5)),
            ),
          ),
        ],
      );

  Widget _lockedField(String label, String value, IconData icon) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: textDark)),
            const SizedBox(width: 6),
            const Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF9AA5B5)),
          ]),
          const SizedBox(height: 7),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(color: const Color(0xFFF2F5F9), borderRadius: BorderRadius.circular(13), border: Border.all(color: border)),
            child: Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF8995AA)),
                const SizedBox(width: 10),
                Expanded(child: Text(value, style: const TextStyle(fontSize: 13.5, color: muted, fontWeight: FontWeight.w700))),
                const Icon(Icons.lock_rounded, size: 14, color: Color(0xFFB3BCC9)),
              ],
            ),
          ),
        ],
      );

  Widget _buildActions(bool m) => m
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _saving ? null : _saveProfile,
              icon: _saving
                  ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: Text(_saving ? 'Saving...' : 'Save Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              ),
            ),
          ],
        )
      : Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              onPressed: _saving ? null : _saveProfile,
              icon: _saving
                  ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: Text(_saving ? 'Saving...' : 'Save Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
}