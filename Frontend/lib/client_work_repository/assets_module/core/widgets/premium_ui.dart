import 'dart:async';

import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════════════
// Premium blue & white UI kit, shared by the admin pages.
// Compact "task manager" density, sized to fit a 14" laptop screen.
// Flutter SDK only: no extra packages.
// ══════════════════════════════════════════════════════════════════════════

class PremiumColors {
  PremiumColors._();

  static const ink = Color(0xFF0B1B3F);
  static const body = Color(0xFF334155);
  static const muted = Color(0xFF64748B);
  static const faint = Color(0xFF94A3B8);
  static const blue = Color(0xFF2563EB);
  static const blueDeep = Color(0xFF1E40AF);
  static const line = Color(0xFFE3EAF6);
  static const rowLine = Color(0xFFEDF2FA);
  static const rowHover = Color(0xFFF5F9FF);
  static const soft = Color(0xFFEFF5FF);
  static const surface = Color(0xFFF6F9FF);
  static const headerText = Color(0xFF3B5B9A);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F2A6B), Color(0xFF1D4ED8), Color(0xFF3B82F6)],
  );

  static const pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFEAF1FF), Color(0xFFF6F9FF), Colors.white],
  );

  static const tableHeaderGradient = LinearGradient(
    colors: [Color(0xFFE8F0FF), Color(0xFFF5F9FF)],
  );

  /// Upper-case column label style for table headers.
  static const tableHeaderStyle = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
    color: headerText,
    letterSpacing: 0.7,
  );
}

/// A colour family: gradient start/end plus a soft tint for backgrounds.
class PremiumAccent {
  final Color start;
  final Color end;
  final Color soft;
  const PremiumAccent(this.start, this.end, this.soft);

  factory PremiumAccent.fromColor(Color color) => PremiumAccent(
    color,
    Color.lerp(color, Colors.white, 0.35)!,
    Color.lerp(color, Colors.white, 0.9)!,
  );

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [start, end],
  );

  static const blue = PremiumAccent(
    Color(0xFF2563EB),
    Color(0xFF38BDF8),
    Color(0xFFE8F1FF),
  );
  static const green = PremiumAccent(
    Color(0xFF059669),
    Color(0xFF34D399),
    Color(0xFFE3F8EF),
  );
  static const violet = PremiumAccent(
    Color(0xFF7C3AED),
    Color(0xFFC084FC),
    Color(0xFFF3EBFF),
  );
  static const amber = PremiumAccent(
    Color(0xFFF59E0B),
    Color(0xFFFB7185),
    Color(0xFFFFF4E0),
  );
  static const cyan = PremiumAccent(
    Color(0xFF0891B2),
    Color(0xFF22D3EE),
    Color(0xFFE0F7FB),
  );
  static const rose = PremiumAccent(
    Color(0xFFE11D48),
    Color(0xFFFB7185),
    Color(0xFFFFE8EC),
  );
  static const slate = PremiumAccent(
    Color(0xFF475569),
    Color(0xFF94A3B8),
    Color(0xFFF1F5F9),
  );

  static const all = [blue, violet, green, amber, cyan, rose];

  /// Stable accent picked from the first letter of [text].
  static PremiumAccent forText(String text) {
    final value = text.trim();
    if (value.isEmpty) return blue;
    return all[value.toUpperCase().codeUnitAt(0) % all.length];
  }
}

String formatCount(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return value < 0 ? '-$buffer' : buffer.toString();
}

// ── Page scaffolding ───────────────────────────────────────────────────────

class PremiumBreakpoint {
  final double width;
  const PremiumBreakpoint(this.width);

  bool get mobile => width < 600;
  bool get tablet => width < 1024;
  double get gutter => mobile ? 12 : (tablet ? 20 : 24);

  /// Vertical gap between page sections.
  double get gap => mobile ? 12 : 16;
}

/// Soft blue page background that fills the available space.
class PremiumBackground extends StatelessWidget {
  final Widget child;
  const PremiumBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(gradient: PremiumColors.pageGradient),
    child: SizedBox.expand(child: child),
  );
}

/// Scrollable, centred, max-width page with responsive gutters.
class PremiumPage extends StatelessWidget {
  final List<Widget> Function(BuildContext context, PremiumBreakpoint bp)
  builder;
  final double maxWidth;
  const PremiumPage({super.key, required this.builder, this.maxWidth = 1440});

  @override
  Widget build(BuildContext context) => PremiumBackground(
    child: DefaultTextStyle.merge(
      style: const TextStyle(color: PremiumColors.ink),
      child: LayoutBuilder(
        builder: (context, box) {
          final bp = PremiumBreakpoint(box.maxWidth);
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              bp.gutter,
              bp.mobile ? 12 : 16,
              bp.gutter,
              24,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: builder(context, bp),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

// ── Header banner ──────────────────────────────────────────────────────────

/// Slim gradient page header: title on the left, actions on the right.
class PremiumHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? eyebrow;
  final IconData eyebrowIcon;
  final List<Widget> actions;
  final Widget? trailing;
  final bool trailingOnNarrow;
  final bool compact;

  const PremiumHero({
    super.key,
    required this.title,
    required this.subtitle,
    this.eyebrow,
    this.eyebrowIcon = Icons.auto_awesome_rounded,
    this.actions = const [],
    this.trailing,
    this.trailingOnNarrow = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(compact ? 16 : 18);
    final chip = eyebrow == null
        ? null
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x26FFFFFF),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0x33FFFFFF)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(eyebrowIcon, size: 13, color: const Color(0xFFFDE68A)),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    eyebrow!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
    final titleText = Text(
      title,
      style: TextStyle(
        color: Colors.white,
        fontSize: compact ? 22 : 24,
        height: 1.15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Phones stack the chip above the title; wider screens keep it
        // inline so the banner stays short.
        if (chip != null && compact) ...[chip, const SizedBox(height: 8)],
        if (chip != null && !compact)
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [titleText, chip],
          )
        else
          titleText,
        const SizedBox(height: 4),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: const Color(0xD9FFFFFF),
            fontSize: compact ? 13 : 14,
            height: 1.4,
          ),
        ),
      ],
    );
    final actionBar = actions.isEmpty
        ? null
        : Wrap(spacing: 10, runSpacing: 10, children: actions);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: PremiumColors.heroGradient,
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x331D4ED8),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned(
              right: -50,
              top: -70,
              child: _blob(180, const Color(0x1AFFFFFF)),
            ),
            Positioned(
              right: 220,
              bottom: -90,
              child: _blob(150, const Color(0x2238BDF8)),
            ),
            Positioned(
              left: -40,
              bottom: -60,
              child: _blob(110, const Color(0x12FFFFFF)),
            ),
            Padding(
              padding: compact
                  ? const EdgeInsets.all(16)
                  : const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              child: LayoutBuilder(
                builder: (context, box) {
                  if (box.maxWidth >= 720) {
                    return Row(
                      children: [
                        Expanded(child: text),
                        if (actionBar != null) ...[
                          const SizedBox(width: 16),
                          actionBar,
                        ],
                        if (trailing != null) ...[
                          const SizedBox(width: 16),
                          trailing!,
                        ],
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      text,
                      if (actionBar != null) ...[
                        const SizedBox(height: 12),
                        actionBar,
                      ],
                      if (trailing != null && trailingOnNarrow) ...[
                        const SizedBox(height: 12),
                        trailing!,
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small glass card with an animated number, for a header's trailing slot.
class PremiumGlassStat extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  const PremiumGlassStat({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
    decoration: BoxDecoration(
      color: const Color(0x1FFFFFFF),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0x40FFFFFF)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: PremiumColors.blue, size: 20),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedCount(
                value: value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ── Surfaces ───────────────────────────────────────────────────────────────

class PremiumPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  const PremiumPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D1E40AF),
          blurRadius: 22,
          offset: Offset(0, 8),
        ),
      ],
    ),
    foregroundDecoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: PremiumColors.line),
    ),
    child: child,
  );
}

class PremiumIconTile extends StatelessWidget {
  final IconData icon;
  final PremiumAccent accent;
  final double size;
  final double? iconSize;
  const PremiumIconTile({
    super.key,
    required this.icon,
    this.accent = PremiumAccent.blue,
    this.size = 40,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: accent.gradient,
      borderRadius: BorderRadius.circular(size * 0.3),
      boxShadow: [
        BoxShadow(
          color: accent.start.withAlpha(60),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Icon(icon, size: iconSize ?? size * 0.5, color: Colors.white),
  );
}

class PremiumSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final PremiumAccent accent;
  final Widget? trailing;
  final bool compact;
  const PremiumSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.accent = PremiumAccent.blue,
    this.trailing,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      PremiumIconTile(icon: icon, accent: accent, size: compact ? 34 : 38),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 16 : 17,
                height: 1.25,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: PremiumColors.ink,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: PremiumColors.muted,
                ),
              ),
            ],
          ],
        ),
      ),
      if (trailing != null) ...[const SizedBox(width: 12), trailing!],
    ],
  );
}

// ── Stats ──────────────────────────────────────────────────────────────────

class PremiumStat {
  final String label;
  final int value;
  final IconData icon;
  final PremiumAccent accent;
  final String? caption;
  const PremiumStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.caption,
  });
}

class PremiumStatCard extends StatelessWidget {
  final PremiumStat stat;

  /// Small, centred, caption-less version for phones.
  final bool dense;
  const PremiumStatCard({super.key, required this.stat, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final accent = stat.accent;
    final label = Text(
      stat.label,
      maxLines: dense ? 2 : 1,
      textAlign: dense ? TextAlign.center : TextAlign.start,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: const Color(0xFF475569),
        fontSize: dense ? 11 : 12.5,
        height: 1.3,
        fontWeight: FontWeight.w600,
      ),
    );
    final count = AnimatedCount(
      value: stat.value,
      style: TextStyle(
        fontSize: dense ? 19 : 22,
        height: 1.15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        color: PremiumColors.ink,
      ),
    );

    final Widget body = dense
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PremiumIconTile(icon: stat.icon, accent: accent, size: 32),
              const SizedBox(height: 6),
              count,
              const SizedBox(height: 2),
              label,
            ],
          )
        : Row(
            children: [
              PremiumIconTile(icon: stat.icon, accent: accent, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    label,
                    const SizedBox(height: 2),
                    count,
                    if (stat.caption != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        stat.caption!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: PremiumColors.muted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );

    return HoverBuilder(
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, hovered ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hovered ? accent.start.withAlpha(90) : PremiumColors.line,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.start.withAlpha(hovered ? 40 : 12),
              blurRadius: hovered ? 22 : 14,
              offset: Offset(0, hovered ? 10 : 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned(
                right: -34,
                top: -34,
                child: AnimatedScale(
                  scale: hovered ? 1.3 : 1,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  child: _blob(dense ? 72 : 86, accent.soft),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedOpacity(
                  opacity: hovered ? 1 : 0.5,
                  duration: const Duration(milliseconds: 220),
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(gradient: accent.gradient),
                  ),
                ),
              ),
              Padding(
                padding: dense
                    ? const EdgeInsets.symmetric(horizontal: 8, vertical: 10)
                    : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: dense ? Center(child: body) : body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lays stat cards out responsively, with a staggered entrance.
class PremiumStatRow extends StatelessWidget {
  final List<PremiumStat> stats;
  final Duration startDelay;
  const PremiumStatRow({
    super.key,
    required this.stats,
    this.startDelay = const Duration(milliseconds: 100),
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final width = box.maxWidth;
      Widget reveal(int i, Widget child) => Reveal(
        delay: startDelay + Duration(milliseconds: i * 70),
        child: child,
      );

      if (width < 560) {
        final perRow = stats.length <= 3 ? stats.length : 2;
        final rows = <Widget>[];
        for (var start = 0; start < stats.length; start += perRow) {
          final end = (start + perRow).clamp(0, stats.length);
          if (rows.isNotEmpty) rows.add(const SizedBox(height: 10));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = start; i < end; i++) ...[
                    if (i > start) const SizedBox(width: 10),
                    Expanded(
                      child: reveal(
                        i,
                        PremiumStatCard(stat: stats[i], dense: true),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(children: rows);
      }

      const spacing = 12.0;
      final columns = width >= 760 ? stats.length : 2;
      final cardWidth = ((width - spacing * (columns - 1)) / columns)
          .floorToDouble();
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (var i = 0; i < stats.length; i++)
            reveal(
              i,
              SizedBox(
                width: cardWidth,
                child: PremiumStatCard(stat: stats[i]),
              ),
            ),
        ],
      );
    },
  );
}

// ── Tables ─────────────────────────────────────────────────────────────────

/// Fixed-height table: the header stays pinned while the rows scroll
/// inside it. Scrolls sideways when narrower than [minWidth].
class PremiumTable extends StatefulWidget {
  final Widget header;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Widget? footer;
  final double minWidth;

  /// Max height of the scrolling body. Defaults to what fits on screen.
  final double? maxBodyHeight;

  const PremiumTable({
    super.key,
    required this.header,
    required this.itemCount,
    required this.itemBuilder,
    this.footer,
    this.minWidth = 800,
    this.maxBodyHeight,
  });

  @override
  State<PremiumTable> createState() => _PremiumTableState();
}

class _PremiumTableState extends State<PremiumTable> {
  final _vertical = ScrollController();
  final _horizontal = ScrollController();

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final bodyMax =
        widget.maxBodyHeight ?? (screenHeight - 400).clamp(220.0, 600.0);
    final table = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        widget.header,
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: bodyMax),
          child: Scrollbar(
            controller: _vertical,
            thumbVisibility: true,
            child: ListView.builder(
              controller: _vertical,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: widget.itemCount,
              itemBuilder: widget.itemBuilder,
            ),
          ),
        ),
        if (widget.footer != null) widget.footer!,
      ],
    );
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth >= widget.minWidth) return table;
        return Scrollbar(
          controller: _horizontal,
          child: SingleChildScrollView(
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: widget.minWidth, child: table),
          ),
        );
      },
    );
  }
}

/// Gradient header bar for a [PremiumTable].
class PremiumTableHeader extends StatelessWidget {
  final Widget child;
  final double height;
  final EdgeInsetsGeometry padding;
  const PremiumTableHeader({
    super.key,
    required this.child,
    this.height = 42,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    padding: padding,
    decoration: const BoxDecoration(
      gradient: PremiumColors.tableHeaderGradient,
      border: Border(bottom: BorderSide(color: PremiumColors.line)),
    ),
    child: child,
  );
}

/// A table row that tints on hover.
class PremiumTableRow extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double minHeight;
  const PremiumTableRow({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: 10),
    this.minHeight = 0,
  });

  @override
  Widget build(BuildContext context) => HoverBuilder(
    builder: (context, hovered) => AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      constraints: BoxConstraints(minHeight: minHeight),
      padding: padding,
      decoration: BoxDecoration(
        color: hovered ? PremiumColors.rowHover : Colors.white,
        border: const Border(bottom: BorderSide(color: PremiumColors.rowLine)),
      ),
      child: child,
    ),
  );
}

/// Light footer strip under a table.
class PremiumTableFooter extends StatelessWidget {
  final Widget child;
  const PremiumTableFooter({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: const BoxDecoration(
      gradient: PremiumColors.tableHeaderGradient,
      border: Border(top: BorderSide(color: PremiumColors.line)),
    ),
    child: DefaultTextStyle.merge(
      style: const TextStyle(fontSize: 13, color: PremiumColors.muted),
      child: child,
    ),
  );
}

// ── Controls ───────────────────────────────────────────────────────────────

enum PremiumButtonVariant { filled, outlined, soft, light, glass, danger }

/// Gradient button with hover lift, press-scale and a sliding icon.
class PremiumButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool iconLeading;
  final PremiumButtonVariant variant;
  final Gradient? gradient;
  final bool small;
  final bool expand;
  final bool loading;

  const PremiumButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
    this.iconLeading = false,
    this.variant = PremiumButtonVariant.filled,
    this.gradient,
    this.small = false,
    this.expand = false,
    this.loading = false,
  });

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  void didUpdateWidget(covariant PremiumButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onPressed == null) {
      _hovered = false;
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    final hovered = _hovered && enabled;
    final variant = widget.variant;
    final filledLook =
        variant == PremiumButtonVariant.filled ||
        variant == PremiumButtonVariant.danger;
    final gradient =
        widget.gradient ??
        (variant == PremiumButtonVariant.danger
            ? PremiumAccent.rose.gradient
            : const LinearGradient(
                colors: [
                  PremiumColors.blueDeep,
                  PremiumColors.blue,
                  Color(0xFF3B82F6),
                ],
              ));
    final radius = BorderRadius.circular(widget.small ? 9 : 12);
    final foreground = switch (variant) {
      PremiumButtonVariant.filled ||
      PremiumButtonVariant.danger => Colors.white,
      PremiumButtonVariant.outlined ||
      PremiumButtonVariant.soft => PremiumColors.blue,
      PremiumButtonVariant.light => PremiumColors.blueDeep,
      PremiumButtonVariant.glass => Colors.white,
    };
    final background = switch (variant) {
      PremiumButtonVariant.filled || PremiumButtonVariant.danger => null,
      PremiumButtonVariant.outlined =>
        hovered ? PremiumColors.soft : Colors.white,
      PremiumButtonVariant.soft =>
        hovered ? const Color(0xFFDCE8FF) : PremiumColors.soft,
      PremiumButtonVariant.light =>
        hovered ? const Color(0xFFF0F6FF) : Colors.white,
      PremiumButtonVariant.glass =>
        hovered ? const Color(0x38FFFFFF) : const Color(0x1FFFFFFF),
    };
    final border = switch (variant) {
      PremiumButtonVariant.outlined => Border.all(
        color: hovered ? PremiumColors.blue : PremiumColors.line,
      ),
      PremiumButtonVariant.soft => Border.all(color: const Color(0xFFCFE0FF)),
      PremiumButtonVariant.glass => Border.all(color: const Color(0x40FFFFFF)),
      _ => null,
    };
    final hasShadow =
        enabled && (filledLook || variant == PremiumButtonVariant.light);
    final shadowColor = variant == PremiumButtonVariant.light
        ? PremiumColors.ink
        : gradient.colors.first;

    final iconSize = widget.small ? 15.0 : 17.0;
    Widget? iconWidget;
    if (widget.loading) {
      iconWidget = SizedBox(
        width: iconSize - 2,
        height: iconSize - 2,
        child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
      );
    } else if (widget.icon != null) {
      iconWidget = Icon(widget.icon, size: iconSize, color: foreground);
      if (!widget.iconLeading) {
        iconWidget = AnimatedSlide(
          offset: hovered ? const Offset(0.25, 0) : Offset.zero,
          duration: const Duration(milliseconds: 200),
          child: iconWidget,
        );
      }
    }
    final leading =
        iconWidget != null && (widget.iconLeading || widget.loading);
    final text = Flexible(
      child: Text(
        widget.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foreground,
          fontSize: widget.small ? 13 : 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return AnimatedOpacity(
      opacity: widget.onPressed == null && !widget.loading ? 0.55 : 1,
      duration: const Duration(milliseconds: 200),
      child: AnimatedScale(
        scale: _pressed && enabled ? 0.96 : (hovered ? 1.02 : 1),
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: filledLook ? gradient : null,
            color: background,
            borderRadius: radius,
            border: border,
            boxShadow: hasShadow
                ? [
                    BoxShadow(
                      color: shadowColor.withAlpha(hovered ? 70 : 36),
                      blurRadius: hovered ? 18 : 10,
                      offset: Offset(0, hovered ? 8 : 4),
                    ),
                  ]
                : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: enabled ? widget.onPressed : null,
              onHover: (value) => setState(() => _hovered = value),
              onHighlightChanged: (value) => setState(() => _pressed = value),
              borderRadius: radius,
              splashColor: foreground.withAlpha(40),
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.small ? 12 : 16,
                  vertical: widget.small ? 7 : 10,
                ),
                child: Row(
                  mainAxisSize: widget.expand
                      ? MainAxisSize.max
                      : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (leading) ...[iconWidget, const SizedBox(width: 6)],
                    text,
                    if (iconWidget != null && !leading) ...[
                      const SizedBox(width: 6),
                      iconWidget,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small square icon button with a tinted hover, for table actions.
class PremiumIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final PremiumAccent accent;
  const PremiumIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.accent = PremiumAccent.blue,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: HoverBuilder(
      cursor: onPressed == null ? MouseCursor.defer : SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: hovered && onPressed != null
                ? accent.soft
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: hovered && onPressed != null
                  ? accent.start.withAlpha(60)
                  : Colors.transparent,
            ),
          ),
          child: Icon(
            icon,
            size: 17,
            color: onPressed == null ? PremiumColors.faint : accent.start,
          ),
        ),
      ),
    ),
  );
}

/// Rounded search box with a clear button that appears while typing.
class PremiumSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  const PremiumSearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder outline(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
    return SizedBox(
      height: 42,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          controller: controller,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14, color: PremiumColors.ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 14,
              color: PremiumColors.faint,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 19,
              color: PremiumColors.blue,
            ),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      controller.clear();
                      onClear?.call();
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 17,
                      color: PremiumColors.muted,
                    ),
                  ),
            filled: true,
            fillColor: const Color(0xFFFAFCFF),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            border: outline(PremiumColors.line),
            enabledBorder: outline(PremiumColors.line),
            focusedBorder: outline(PremiumColors.blue, 1.6),
          ),
        ),
      ),
    );
  }
}

class PremiumFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final PremiumAccent accent;
  const PremiumFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent = PremiumAccent.blue,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: selected ? accent.gradient : null,
            color: selected ? null : (hovered ? accent.soft : Colors.white),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : (hovered ? accent.start.withAlpha(90) : PremiumColors.line),
            ),
            boxShadow: [
              BoxShadow(
                color: accent.start.withAlpha(selected ? 55 : 0),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: selected
                    ? const Padding(
                        padding: EdgeInsets.only(right: 5),
                        child: Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : PremiumColors.body,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Pill-shaped tab bar with a sliding gradient indicator.
class PremiumSegmentedTabs extends StatelessWidget {
  final List<String> labels;
  final List<int>? counts;
  final List<IconData>? icons;
  final int selected;
  final ValueChanged<int> onChanged;
  const PremiumSegmentedTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.counts,
    this.icons,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 46,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: PremiumColors.soft,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFDCE8FF)),
    ),
    child: LayoutBuilder(
      builder: (context, box) {
        final segment = box.maxWidth / labels.length;
        final showIcons = icons != null && segment >= 190;
        return Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              left: segment * selected,
              top: 0,
              bottom: 0,
              width: segment,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      PremiumColors.blueDeep,
                      PremiumColors.blue,
                      Color(0xFF3B82F6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x402563EB),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: i == selected,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onChanged(i),
                            child: _segment(i, showIcons),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _segment(int i, bool showIcons) {
    final active = i == selected;
    final color = active ? Colors.white : PremiumColors.muted;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showIcons) ...[
            Icon(icons![i], size: 17, color: color),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: color,
              ),
              child: Text(
                labels[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
              ),
            ),
          ),
          if (counts != null) ...[
            const SizedBox(width: 7),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: active ? const Color(0x33FFFFFF) : Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${counts![i]}',
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : PremiumColors.blue,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Animated on/off switch with a gradient track.
class PremiumToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final PremiumAccent accent;
  const PremiumToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.accent = PremiumAccent.blue,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: value,
    child: HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedScale(
          scale: hovered ? 1.06 : 1,
          duration: const Duration(milliseconds: 160),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 44,
            height: 24,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              gradient: value ? accent.gradient : null,
              color: value ? null : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: accent.start.withAlpha(value ? 55 : 0),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x290B1B3F),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: AnimatedOpacity(
                  opacity: value ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.check_rounded,
                    size: 12,
                    color: accent.start,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// ── Small pieces ───────────────────────────────────────────────────────────

class PremiumBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final PremiumAccent accent;
  final double maxWidth;
  const PremiumBadge({
    super.key,
    required this.label,
    this.icon,
    this.accent = PremiumAccent.blue,
    this.maxWidth = 240,
  });

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: accent.soft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.start.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: accent.start),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: accent.start,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class PremiumAvatar extends StatelessWidget {
  final String text;
  final PremiumAccent accent;
  final double size;
  const PremiumAvatar({
    super.key,
    required this.text,
    this.accent = PremiumAccent.blue,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      gradient: accent.gradient,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
      boxShadow: [
        BoxShadow(
          color: accent.start.withAlpha(50),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Text(
      text,
      style: TextStyle(
        color: Colors.white,
        fontSize: size * 0.36,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class PremiumInfoNote extends StatelessWidget {
  final String text;
  final IconData icon;
  const PremiumInfoNote({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFEFF5FF), Color(0xFFF8FBFF)],
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFDCE8FF)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 16, color: PremiumColors.blue),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: PremiumColors.body,
            ),
          ),
        ),
      ],
    ),
  );
}

class PremiumLoading extends StatelessWidget {
  final String label;
  const PremiumLoading({super.key, this.label = 'Loading...'});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 38,
          height: 38,
          child: CircularProgressIndicator(
            strokeWidth: 3.5,
            color: PremiumColors.blue,
            backgroundColor: Color(0xFFDCE8FF),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            color: PremiumColors.muted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

class PremiumEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final PremiumAccent accent;
  const PremiumEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.accent = PremiumAccent.blue,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PremiumFloat(
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: accent.soft,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: PremiumIconTile(icon: icon, accent: accent, size: 42),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: PremiumColors.ink,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: PremiumColors.muted,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class PremiumErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;
  const PremiumErrorState({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Retry',
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PremiumIconTile(
              icon: Icons.cloud_off_rounded,
              accent: PremiumAccent.rose,
              size: 50,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: PremiumColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: PremiumColors.muted,
              ),
            ),
            const SizedBox(height: 16),
            PremiumButton(
              label: retryLabel,
              icon: Icons.refresh_rounded,
              iconLeading: true,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Motion helpers ─────────────────────────────────────────────────────────

/// Fades and slides its child in after [delay].
class Reveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Offset offset;
  const Reveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 0.06),
  });

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _curve,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: widget.offset,
        end: Offset.zero,
      ).animate(_curve),
      child: widget.child,
    ),
  );
}

/// Gently bobs its child up and down forever.
class PremiumFloat extends StatefulWidget {
  final Widget child;
  final Duration duration;
  const PremiumFloat({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 3),
  });

  @override
  State<PremiumFloat> createState() => _PremiumFloatState();
}

class _PremiumFloatState extends State<PremiumFloat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) => Transform.translate(
      offset: Offset(
        0,
        (Curves.easeInOut.transform(_controller.value) - 0.5) * 8,
      ),
      child: child,
    ),
    child: widget.child,
  );
}

/// Rebuilds with the current mouse-hover state.
class HoverBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, bool hovered) builder;
  final MouseCursor cursor;
  const HoverBuilder({
    super.key,
    required this.builder,
    this.cursor = MouseCursor.defer,
  });

  @override
  State<HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<HoverBuilder> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: widget.cursor,
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: widget.builder(context, _hovered),
  );
}

/// Counts up to [value] whenever it changes.
class AnimatedCount extends StatelessWidget {
  final int value;
  final TextStyle style;
  const AnimatedCount({super.key, required this.value, required this.style});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: value.toDouble()),
    duration: const Duration(milliseconds: 1200),
    curve: Curves.easeOutCubic,
    builder: (context, current, _) =>
        Text(formatCount(current.round()), style: style),
  );
}

Widget _blob(double size, Color color) => Container(
  width: size,
  height: size,
  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
);
