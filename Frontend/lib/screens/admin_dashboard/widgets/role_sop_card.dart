import 'package:flutter/material.dart';

/// Admin role card for the Role-Based SOP master.
/// Blue + white theme. Admin can View, Add/Update and Delete the role PDF.
class RoleSopCard extends StatelessWidget {
  const RoleSopCard({
    super.key,
    required this.roleName,
    required this.document,
    required this.colorIndex,
    required this.onAddOrEdit,
    required this.onView,
    this.onDelete,
  });

  final String roleName;
  final Map<String, dynamic>? document;
  final int colorIndex;
  final VoidCallback onAddOrEdit;
  final VoidCallback? onView;
  final VoidCallback? onDelete;

  // Blue + white palette.
  static const Color _blue = Color(0xFF0A5BFF);
  static const Color _blueDark = Color(0xFF0742B8);
  static const Color _navy = Color(0xFF0D1B4C);
  static const Color _slate = Color(0xFF64748B);

  IconData get _icon {
    final name = roleName.toLowerCase();
    if (name.contains('page')) return Icons.web_rounded;
    if (name.contains('video')) return Icons.movie_creation_rounded;
    if (name.contains('ads')) return Icons.campaign_rounded;
    if (name.contains('design')) return Icons.palette_rounded;
    if (name.contains('sales')) return Icons.trending_up_rounded;
    if (name.contains('bde')) return Icons.handshake_rounded;
    if (name.contains('manager')) return Icons.badge_rounded;
    if (name.contains('developer') || name.contains('web')) {
      return Icons.code_rounded;
    }
    return Icons.menu_book_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final hasDocument = document != null;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE7FF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140A5BFF),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Blue header band with the highlighted role logo.
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFEFF5FF), Colors.white],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_blue, _blueDark],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x4D0A5BFF),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(_icon, color: Colors.white, size: 26),
                ),
                const Spacer(),
                _StatusChip(hasDocument: hasDocument),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roleName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  hasDocument
                      ? '${document!['file_name'] ?? 'PDF uploaded'}'
                      : 'No SOP uploaded for this role yet.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _slate,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (hasDocument) ...[
                      _IconAction(
                        tooltip: 'View SOP PDF',
                        icon: Icons.visibility_rounded,
                        color: _blue,
                        onTap: onView,
                      ),
                      const SizedBox(width: 8),
                      _IconAction(
                        tooltip: 'Delete SOP PDF',
                        icon: Icons.delete_outline_rounded,
                        color: const Color(0xFFDC2626),
                        onTap: onDelete,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onAddOrEdit,
                        style: FilledButton.styleFrom(
                          backgroundColor: _blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(
                          hasDocument ? Icons.edit_rounded : Icons.add_rounded,
                          size: 18,
                        ),
                        label: Text(
                          hasDocument ? 'Edit / Update PDF' : 'Add PDF',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.hasDocument});

  final bool hasDocument;

  @override
  Widget build(BuildContext context) {
    final bg = hasDocument ? const Color(0xFFE6F6EC) : const Color(0xFFEFF4FF);
    final fg = hasDocument ? const Color(0xFF127A3A) : const Color(0xFF0A5BFF);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasDocument ? Icons.verified_rounded : Icons.upload_file_rounded,
            color: fg,
            size: 14,
          ),
          const SizedBox(width: 5),
          Text(
            hasDocument ? 'Uploaded' : 'No PDF',
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }
}
