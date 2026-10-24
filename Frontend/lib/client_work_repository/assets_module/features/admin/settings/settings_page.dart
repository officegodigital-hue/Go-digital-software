import 'package:flutter/material.dart';

import '../../../core/widgets/premium_ui.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const _items = [
    (
      Icons.business_rounded,
      'Company settings',
      'Manage workspace information',
      PremiumAccent.blue,
      null,
    ),
    (
      Icons.security_rounded,
      'Security',
      'Authentication and account security',
      PremiumAccent.violet,
      null,
    ),
    (
      Icons.cloud_rounded,
      'Storage',
      'Google Drive integration will be connected later',
      PremiumAccent.cyan,
      'Coming soon',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return PremiumPage(
      builder: (context, bp) => [
        Reveal(
          child: PremiumHero(
            compact: bp.mobile,
            eyebrow: 'Workspace',
            eyebrowIcon: Icons.tune_rounded,
            title: 'Settings',
            subtitle: 'Configure your Go Digital workspace.',
          ),
        ),
        SizedBox(height: bp.gap),
        Reveal(
          delay: const Duration(milliseconds: 160),
          child: PremiumPanel(
            padding: EdgeInsets.all(bp.mobile ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PremiumSectionHeader(
                  title: 'Workspace preferences',
                  subtitle: 'Everything that shapes how your workspace runs.',
                  icon: Icons.settings_rounded,
                  compact: bp.mobile,
                ),
                const SizedBox(height: 14),
                for (var i = 0; i < _items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  Reveal(
                    delay: Duration(milliseconds: 260 + i * 90),
                    child: _SettingTile(
                      icon: _items[i].$1,
                      title: _items[i].$2,
                      subtitle: _items[i].$3,
                      accent: _items[i].$4,
                      badge: _items[i].$5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final PremiumAccent accent;
  final String? badge;
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    this.badge,
  });

  @override
  Widget build(BuildContext context) => HoverBuilder(
    builder: (context, hovered) => AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(hovered ? 4 : 0, 0, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            hovered ? accent.soft : const Color(0xFFFAFCFF),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hovered ? accent.start.withAlpha(90) : PremiumColors.line,
        ),
      ),
      child: Row(
        children: [
          AnimatedScale(
            scale: hovered ? 1.08 : 1,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutBack,
            child: PremiumIconTile(icon: icon, accent: accent, size: 40),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: PremiumColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: PremiumColors.muted,
                  ),
                ),
              ],
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 12),
            PremiumBadge(
              label: badge!,
              icon: Icons.schedule_rounded,
              accent: PremiumAccent.amber,
            ),
          ],
        ],
      ),
    ),
  );
}
