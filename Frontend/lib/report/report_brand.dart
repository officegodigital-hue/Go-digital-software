// lib/report/report_brand.dart
//
// GO DIGITAL brand kit for the Client Report Management module: palette, the
// "G" logo badge, the wordmark, and a profile menu (avatar + name/role +
// log out) wired to the app's AuthService. One source of truth so the report
// topbar, sidebar and workspace screens share a consistent brand identity.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:godigital_portal/services/auth_service.dart';

class ReportBrand {
  const ReportBrand._();

  static const navy = Color(0xFF08203F);
  static const navy2 = Color(0xFF0B2E63);
  static const blue = Color(0xFF0E63E6);
  static const blueBright = Color(0xFF2491FF);
  static const bg = Color(0xFFEFF4FE);
  static const mutedOnLight = Color(0xFF5C76A8);
  static const mutedOnDark = Color(0xFF9FC6FF);

  static const logoAsset = 'assets/branding/go_digital_logo.png';

  static const sidebarGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A2A5E), Color(0xFF071B38)],
  );
  static const brandGradient = LinearGradient(
    colors: [Color(0xFF2491FF), Color(0xFF0E63E6)],
  );

  /// Soft blue-white page wash used behind every report screen.
  static const pageBackground = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFF6F9FF), Color(0xFFEAF1FF)],
    ),
  );

  static const cardBorder = Color(0xFFE2EAF7);
  static const cardShadow = Color(0x140B2850);

  static const premiumSurface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF3F8FF), Color(0xFFEAF3FF)],
  );

  static const surfaceHighlight = Color(0xFFF8FBFF);
  static const surfaceBorder = Color(0xFFCFE1FB);
}

/// A quiet, layered report workspace background. It deliberately belongs to
/// page bodies only; the application top bar and sidebar keep their existing
/// layout and behaviour.
class ReportWorkspace extends StatelessWidget {
  const ReportWorkspace({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ReportBrand.pageBackground,
      child: Stack(
        children: [
          const Positioned(
            right: -110,
            top: -145,
            child: _ReportHeaderWave(
              width: 360,
              height: 250,
              color: Color(0x142491FF),
            ),
          ),
          const Positioned(
            left: -135,
            bottom: -165,
            child: _ReportHeaderWave(
              width: 360,
              height: 250,
              color: Color(0x100E63E6),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Reusable glass-like white panel for lists, report cards and tables.
class ReportPanel extends StatelessWidget {
  const ReportPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.radius = 20,
    this.highlighted = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        gradient: highlighted ? ReportBrand.premiumSurface : null,
        color: highlighted ? null : Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: highlighted ? ReportBrand.surfaceBorder : ReportBrand.cardBorder,
        ),
        boxShadow: const [
          BoxShadow(
            color: ReportBrand.cardShadow,
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// A branded white report AppBar: GO DIGITAL logo + title, optional actions,
/// and the profile menu on the right. Used across every report screen so the
/// top bar is identical everywhere.
PreferredSizeWidget brandReportAppBar({
  required String title,
  List<Widget> actions = const <Widget>[],
  bool showProfile = true,
  Widget? leading,
}) {
  return AppBar(
    backgroundColor: Colors.white,
    foregroundColor: ReportBrand.navy,
    surfaceTintColor: Colors.white,
    elevation: 0.5,
    titleSpacing: 8,
    leading: leading,
    title: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const GoDigitalLogo(size: 34, radius: 9, padding: 5),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
    actions: [
      ...actions,
      if (showProfile)
        const Padding(
          padding: EdgeInsets.only(right: 12, left: 4),
          child: ReportProfileMenu(compact: true),
        ),
    ],
  );
}

/// Lightweight fade + slide-up entrance. Controller-free (two implicit
/// animations), so it is cheap and safe to use on list items with a per-index
/// [delay] for a gentle staggered reveal.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
    this.beginOffset = const Offset(0, 0.06),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset beginOffset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.delay > Duration.zero)
        await Future<void>.delayed(widget.delay);
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _shown ? Offset.zero : widget.beginOffset,
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: widget.duration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Section header: a gradient icon chip + title and optional subtitle, with an
/// optional trailing action — used to title every report section consistently.
class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final IconData? icon;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: ReportBrand.brandGradient,
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                  color: ReportBrand.blue.withValues(alpha: .28),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: ReportBrand.navy,
                ),
              ),
              if ((subtitle ?? '').isNotEmpty)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: ReportBrand.mutedOnLight,
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class ReportHeroHeader extends StatelessWidget {
  const ReportHeroHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.action,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        final heading = Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: ReportBrand.brandGradient,
                borderRadius: BorderRadius.circular(17),
                boxShadow: [
                  BoxShadow(
                    color: ReportBrand.blue.withValues(alpha: .22),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 15),
            Container(
              width: 1,
              height: 52,
              color: ReportBrand.blue.withValues(alpha: .2),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ReportBrand.navy,
                      fontSize: 24,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    maxLines: compact ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ReportBrand.mutedOnLight,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        return Container(
          decoration: BoxDecoration(
            gradient: ReportBrand.premiumSurface,
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: const Color(0xffcfe1fb)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x180B2850),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              const Positioned(
                right: -44,
                top: -72,
                child: _ReportHeaderWave(
                  width: 220,
                  height: 155,
                  color: Color(0x302491FF),
                ),
              ),
              const Positioned(
                right: 105,
                bottom: -112,
                child: _ReportHeaderWave(
                  width: 250,
                  height: 160,
                  color: Color(0x1C0E63E6),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(compact ? 17 : 22),
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          heading,
                          if (action != null) ...[
                            const SizedBox(height: 16),
                            action!,
                          ],
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: heading),
                          if (action != null) ...[
                            const SizedBox(width: 18),
                            action!,
                          ],
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReportHeaderWave extends StatelessWidget {
  const _ReportHeaderWave({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -.22,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(height),
        ),
      ),
    );
  }
}

/// Pill badge for an approval/report status. Returns brand-consistent colour +
/// icon for approved / rejected / pending / other.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    final (color, icon, label) = switch (s) {
      'approved' => (
        const Color(0xFF16A34A),
        Icons.check_circle_rounded,
        'Approved',
      ),
      'rejected' => (const Color(0xFFE11D48), Icons.cancel_rounded, 'Rejected'),
      'pending' => (const Color(0xFFD97706), Icons.schedule_rounded, 'Pending'),
      _ => (
        ReportBrand.blue,
        Icons.info_rounded,
        s.isEmpty ? 'Unknown' : s[0].toUpperCase() + s.substring(1),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// A gradient brand button (filled) that mirrors FilledButton's API shape but
/// carries the blue brand gradient + glow. [onPressed] null disables it.
class BrandButton extends StatelessWidget {
  const BrandButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Opacity(
      opacity: disabled ? .55 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: ReportBrand.brandGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                    color: ReportBrand.blue.withValues(alpha: .34),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Branded empty / error state with an icon halo and optional action button.
class BrandEmptyState extends StatelessWidget {
  const BrandEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final accent = isError ? const Color(0xFFE11D48) : ReportBrand.blue;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: FadeSlideIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: .10),
                  border: Border.all(color: accent.withValues(alpha: .18)),
                ),
                child: Icon(icon, size: 40, color: accent),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: ReportBrand.navy,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: ReportBrand.mutedOnLight),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 18),
                BrandButton(label: actionLabel!, onPressed: onAction),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Centered brand-blue loading spinner.
class BrandLoader extends StatelessWidget {
  const BrandLoader({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(ReportBrand.blue),
            ),
          ),
          if ((label ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              label!,
              style: const TextStyle(color: ReportBrand.mutedOnLight),
            ),
          ],
        ],
      ),
    );
  }
}

/// The GO DIGITAL "G" mark on a clean white badge so it reads clearly on any
/// background (dark sidebar, white topbar, coloured banners).
class GoDigitalLogo extends StatelessWidget {
  const GoDigitalLogo({
    super.key,
    this.size = 42,
    this.radius = 12,
    this.padding = 6,
  });

  final double size;
  final double radius;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0B2850),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Image.asset(
        ReportBrand.logoAsset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.bar_chart_rounded, color: ReportBrand.blue),
      ),
    );
  }
}

/// Logo + "GO DIGITAL" wordmark with tagline. [onDark] adapts the text colours
/// for the navy sidebar versus a light surface.
class GoDigitalWordmark extends StatelessWidget {
  const GoDigitalWordmark({super.key, this.onDark = true, this.logoSize = 44});

  final bool onDark;
  final double logoSize;

  @override
  Widget build(BuildContext context) {
    final titleColor = onDark ? Colors.white : ReportBrand.navy;
    final subColor = onDark
        ? ReportBrand.mutedOnDark
        : ReportBrand.mutedOnLight;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GoDigitalLogo(size: logoSize),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'GO DIGITAL',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                'We Build Technologies',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: subColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 10.5,
                  letterSpacing: .6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _roleLabel(String? role, String? userType) {
  final value = (role ?? '').trim().isNotEmpty
      ? role!.trim()
      : (userType ?? '').trim();
  if (value.isEmpty) return 'Member';
  final lower = value.toLowerCase();
  return lower[0].toUpperCase() + lower.substring(1);
}

/// Avatar + name/role that opens a menu with a Log out action. Reads the signed
/// in user from AuthService (via Provider) and logs out through it, then returns
/// to the app root (which renders the login screen).
class ReportProfileMenu extends StatelessWidget {
  const ReportProfileMenu({
    super.key,
    this.onDark = false,
    this.compact = false,
  });

  /// Text/icon colours for a dark surface (sidebar) vs a light one (topbar).
  final bool onDark;

  /// When true, shows only the avatar (no name/role text) — for tight topbars.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final name = (auth.user?['fullName'] ?? auth.user?['name'] ?? 'User')
        .toString();
    final email = (auth.user?['email'] ?? '').toString();
    final roleLabel = _roleLabel(auth.userRole, auth.userType);
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    final textColor = onDark ? Colors.white : ReportBrand.navy;
    final subColor = onDark ? ReportBrand.mutedOnDark : const Color(0xFF6B82AC);

    final avatar = Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: ReportBrand.brandGradient,
      ),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
    );

    return PopupMenuButton<String>(
      tooltip: 'Profile',
      offset: const Offset(0, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (value) async {
        if (value != 'logout') return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Log out?'),
            content: const Text('You will need to sign in again to continue.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Log out'),
              ),
            ],
          ),
        );
        if (confirm != true) return;
        if (!context.mounted) return;
        await context.read<AuthService>().logout();
        if (context.mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: ReportBrand.navy,
                ),
              ),
              Text(
                roleLabel + (email.isEmpty ? '' : '  •  $email'),
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B82AC)),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout_rounded, color: Color(0xFFE11D48)),
            title: Text('Log out'),
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          avatar,
          if (!compact) ...[
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  roleLabel,
                  style: TextStyle(color: subColor, fontSize: 11.5),
                ),
              ],
            ),
          ],
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down_rounded, color: subColor),
        ],
      ),
    );
  }
}
