import 'package:flutter/material.dart';

abstract final class RecordStyle {
  static const blue = Color(0xFF075EF7);
  static const navy = Color(0xFF061457);
  static const muted = Color(0xFF657590);
  static const line = Color(0xFFE2E9F5);
  static const page = Color(0xFFF7F9FD);
  static const pale = Color(0xFFEEF4FF);
}

class RecordSurface extends StatelessWidget {
  const RecordSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: RecordStyle.line),
      boxShadow: const [
        BoxShadow(
          color: Color(0x04061457),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: child,
  );
}

class RecordAction extends StatelessWidget {
  const RecordAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: primary ? Colors.white : RecordStyle.blue,
      backgroundColor: primary ? RecordStyle.blue : Colors.white,
      disabledBackgroundColor: RecordStyle.pale,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: primary ? RecordStyle.blue : RecordStyle.line),
      ),
      textStyle: TextStyle(
        fontFamily: Theme.of(context).textTheme.labelLarge?.fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 17), const SizedBox(width: 7)],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    ),
  );
}

class RecordPill extends StatelessWidget {
  const RecordPill(this.text, {super.key, this.color = RecordStyle.blue});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}

class RecordTabs extends StatelessWidget {
  const RecordTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelect,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: List.generate(
        labels.length,
        (i) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Semantics(
            selected: selected == i,
            button: true,
            child: TextButton(
              onPressed: () => onSelect(i),
              style: TextButton.styleFrom(
                foregroundColor: selected == i
                    ? RecordStyle.blue
                    : RecordStyle.muted,
                backgroundColor: selected == i
                    ? RecordStyle.pale
                    : Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected == i ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class RecordEmpty extends StatelessWidget {
  const RecordEmpty({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.history_rounded,
  });
  final String title, message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 45, horizontal: 24),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(17),
          decoration: const BoxDecoration(
            color: RecordStyle.pale,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: RecordStyle.blue, size: 26),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: RecordStyle.navy,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: RecordStyle.muted,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}
