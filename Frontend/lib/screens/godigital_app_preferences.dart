import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:godigital_portal/services/auth_service.dart';
import 'package:godigital_portal/widgets/godigital_support_button.dart';

class GoDigitalAppPreferences extends StatefulWidget {
  const GoDigitalAppPreferences({super.key});

  @override
  State<GoDigitalAppPreferences> createState() =>
      _GoDigitalAppPreferencesState();
}

class _GoDigitalAppPreferencesState extends State<GoDigitalAppPreferences> {
  static const Color blue = Color(0xFF0757D5);
  static const Color ink = Color(0xFF14213D);
  static const Color gray = Color(0xFF718096);

  bool notificationsEnabled = true;
  String dateFormat = 'dd/MM/yyyy';
  String timeFormat = '12-hour';
  String preferencePrefix = 'godigital_admin_';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userId = context.read<AuthService>().userId;
      preferencePrefix = 'godigital_admin_${userId ?? "unknown"}_';
      _loadPreferences();
    });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      notificationsEnabled =
          prefs.getBool('${preferencePrefix}notifications') ?? true;
      dateFormat =
          prefs.getString('${preferencePrefix}dateFormat') ?? 'dd/MM/yyyy';
      timeFormat =
          prefs.getString('${preferencePrefix}timeFormat') ?? '12-hour';
    });
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _info(String title, String description) async {
    if (!mounted) return;

    IconData dialogIcon = Icons.info_outline_rounded;

    if (title.contains('Privacy')) {
      dialogIcon = Icons.shield_outlined;
    } else if (title.contains('Location')) {
      dialogIcon = Icons.location_on_outlined;
    } else if (title.contains('Help')) {
      dialogIcon = Icons.support_agent_rounded;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(dialogIcon, color: blue),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: SingleChildScrollView(
            child: Text(
              description,
              style: const TextStyle(fontSize: 13.5, color: gray, height: 1.6),
            ),
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _notifications() async {
    var enabled = notificationsEnabled;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          titleTextStyle: const TextStyle(
            color: Color(0xFF14213D),
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
          contentTextStyle: const TextStyle(
            color: Color(0xFF718096),
            fontSize: 13.5,
            height: 1.5,
          ),
          title: const Text('Notifications'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                // GD_WHITE_NOTIFICATION_SWITCH
                contentPadding: EdgeInsets.zero,
                thumbColor: WidgetStateProperty.resolveWith<Color>(
                  (states) => states.contains(WidgetState.selected)
                      ? const Color(0xFF0757D5)
                      : const Color(0xFF94A3B8),
                ),
                trackColor: WidgetStateProperty.all(Colors.white),
                trackOutlineColor: WidgetStateProperty.resolveWith<Color>(
                  (states) => states.contains(WidgetState.selected)
                      ? const Color(0xFF0757D5)
                      : const Color(0xFFCBD5E1),
                ),
                title: const Text('Enable notifications'),
                subtitle: const Text('Save your preference for notifications.'),
                value: enabled,
                activeThumbColor: blue,
                onChanged: (value) => refresh(() => enabled = value),
              ),
              const SizedBox(height: 10),
              const Text(
                'This saves your preference. Push notification delivery '
                'requires integration with the notification service.',
                style: TextStyle(fontSize: 12, color: gray),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool(
                  '${preferencePrefix}notifications',
                  enabled,
                );
                if (!mounted) return;
                setState(() => notificationsEnabled = enabled);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                _message('Notification preference saved');
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _location() async {
    try {
      final available = await Geolocator.isLocationServiceEnabled();

      if (!available) {
        await _info(
          'Location',
          'Location services are disabled on this device. '
              'Enable location services in your device settings.',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (!mounted) return;

      if (permission == LocationPermission.deniedForever) {
        await _info(
          'Location Permission',
          'Location access is permanently denied. '
              'Use your device or browser settings to change it.',
        );
        return;
      }

      if (permission == LocationPermission.denied) {
        await _info(
          'Location Permission',
          'Location permission was not granted.',
        );
        return;
      }

      await _info(
        'Location Permission',
        'Location permission is granted.\n\n'
            'This screen does not track or upload your location.',
      );
    } catch (error) {
      await _info(
        'Location',
        'Location permissions could not be checked on this device.\n$error',
      );
    }
  }

  Future<void> _dateTime() async {
    var selectedDate = dateFormat;
    var selectedTime = timeFormat;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('Date & Time'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Date format'),
              DropdownButton<String>(
                isExpanded: true,
                value: selectedDate,
                items: const [
                  DropdownMenuItem(
                    value: 'dd/MM/yyyy',
                    child: Text('DD/MM/YYYY'),
                  ),
                  DropdownMenuItem(
                    value: 'MM/dd/yyyy',
                    child: Text('MM/DD/YYYY'),
                  ),
                  DropdownMenuItem(
                    value: 'yyyy-MM-dd',
                    child: Text('YYYY-MM-DD'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    refresh(() => selectedDate = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              const Text('Time format'),
              DropdownButton<String>(
                isExpanded: true,
                value: selectedTime,
                items: const [
                  DropdownMenuItem(value: '12-hour', child: Text('12-hour')),
                  DropdownMenuItem(value: '24-hour', child: Text('24-hour')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    refresh(() => selectedTime = value);
                  }
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'These preferences are saved here. Other screens '
                'will use their existing formats until integrated.',
                style: TextStyle(fontSize: 12, color: gray),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString(
                  '${preferencePrefix}dateFormat',
                  selectedDate,
                );
                await prefs.setString(
                  '${preferencePrefix}timeFormat',
                  selectedTime,
                );
                if (!mounted) return;
                setState(() {
                  dateFormat = selectedDate;
                  timeFormat = selectedTime;
                });
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                _message('Date and time preferences saved');
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _storage() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: const TextStyle(
          color: Color(0xFF14213D),
          fontSize: 19,
          fontWeight: FontWeight.w900,
        ),
        contentTextStyle: const TextStyle(
          color: Color(0xFF718096),
          fontSize: 13.5,
          height: 1.5,
        ),
        title: const Text('Storage & Cache'),
        content: const Text(
          'Clear temporary Flutter image cache?\n\n'
          'This does not delete your profile, login session, '
          'database records, saved preferences or downloaded files.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear Image Cache'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    _message('Temporary image cache cleared');
  }

  // GD_SETTINGS_CARD_V2
  Widget _item(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback action,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: action,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 126,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE4EAF3)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0757D5).withValues(alpha: 0.035),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 39,
                    height: 39,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2FF),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: blue, size: 21),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: gray),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Keep existing grouping in code but hide section headings.
  Widget _group(String name, List<Widget> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 14.0;
        final columns = constraints.maxWidth >= 960
            ? 3
            : constraints.maxWidth >= 600
            ? 2
            : 1;

        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: items
                .map((card) => SizedBox(width: cardWidth, child: card))
                .toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _group('App Preferences', [
          _item(
            Icons.notifications_outlined,
            'Notifications',
            'Notification preferences',
            _notifications,
          ),
          _item(
            Icons.location_on_outlined,
            'Location',
            'Check or request location permission',
            _location,
          ),
          // GD_UNIFIED_SETTINGS_GRID
          _item(
            Icons.privacy_tip_outlined,
            'Privacy & Permissions',
            'Review app permissions',
            () => _info(
              'Privacy & Permissions',
              'Location access is requested only when you use '
                  'the Location setting.\n\n'
                  'Photo selection uses the existing profile '
                  'photo upload feature.\n\n'
                  'Other permissions depend on your device '
                  'and browser settings.',
            ),
          ),

          _item(
            Icons.storage_outlined,
            'Storage & Cache',
            'Clear temporary image cache',
            _storage,
          ),
          GoDigitalSupportButton(
            triggerBuilder: (openMenu) => _item(
              Icons.help_outline_rounded,
              'Help & Support',
              'Call or WhatsApp our support team',
              openMenu,
            ),
          ),
          _item(
            Icons.info_outline_rounded,
            'About GoDigital',
            'Application information',
            () => _info(
              'About GoDigital',
              'GoDigital Portal\n\n'
                  'Employee, client and workspace management '
                  'application.\n\n'
                  'The installed app version can be found in '
                  'your application package metadata.',
            ),
          ),
        ]),
      ],
    );
  }
}
