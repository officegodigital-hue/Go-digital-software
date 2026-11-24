import 'package:flutter/material.dart';

import '../role_sop_viewer_dialog.dart';

/// Employee-facing SOP dashboard.
/// Shows a view-only list of PDF cards for the roles assigned to the
/// signed-in employee. No add / edit / delete — employees can only view.
class EmployeeSopDashboardScreen extends StatelessWidget {
  const EmployeeSopDashboardScreen({super.key, required this.documents});

  final List<Map<String, dynamic>> documents;

  static const Color _blue = Color(0xFF0A5BFF);
  static const Color _blueDark = Color(0xFF0742B8);
  static const Color _navy = Color(0xFF0D1B4C);
  static const Color _slate = Color(0xFF64748B);

  IconData _iconFor(String roleName) {
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

  Future<void> _view(BuildContext context, Map<String, dynamic> document) {
    return showDialog<void>(
      context: context,
      builder: (_) => RoleSopViewerDialog(documents: [document]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      body: SafeArea(
        child: Column(
          children: [
            // Blue + white header.
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_blue, _blueDark],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(22),
                  bottomRight: Radius.circular(22),
                ),
              ),
              child: Row(
                children: [
                  _CircleIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SOP & Rules',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Standard procedures for your assigned roles.',
                          style: TextStyle(
                            color: Color(0xFFD7E5FF),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: documents.isEmpty
                  ? _buildEmptyState()
                  : _buildGrid(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFEAF1FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.folder_open_rounded,
              size: 42,
              color: _blue,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No SOP is available yet',
            style: TextStyle(
              color: _navy,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Procedures for your roles will appear here once uploaded.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _slate, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _cardFor(BuildContext context, Map<String, dynamic> document) {
    final roleName = '${document['role_name'] ?? 'Assigned role'}';
    final title = '${document['title'] ?? document['role_name'] ?? 'SOP'}';
    return _SopViewCard(
      icon: _iconFor(roleName),
      title: title,
      roleName: roleName,
      fileName: '${document['file_name'] ?? 'PDF document'}',
      onView: () => _view(context, document),
    );
  }

  Widget _buildGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 3
            : constraints.maxWidth >= 640
            ? 2
            : 1;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${documents.length} ${documents.length == 1 ? 'procedure' : 'procedures'} available',
                    style: const TextStyle(
                      color: _slate,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (columns == 1)
                    // Phone: let each card size to its own content so nothing is
                    // clipped and there is no wasted vertical space from a fixed
                    // aspect ratio.
                    Column(
                      children: [
                        for (var index = 0; index < documents.length; index++)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: index == documents.length - 1 ? 0 : 14,
                            ),
                            child: _cardFor(context, documents[index]),
                          ),
                      ],
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: documents.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.5,
                      ),
                      itemBuilder: (context, index) =>
                          _cardFor(context, documents[index]),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SopViewCard extends StatelessWidget {
  const _SopViewCard({
    required this.icon,
    required this.title,
    required this.roleName,
    required this.fileName,
    required this.onView,
  });

  final IconData icon;
  final String title;
  final String roleName;
  final String fileName;
  final VoidCallback onView;

  static const Color _blue = Color(0xFF0A5BFF);
  static const Color _blueDark = Color(0xFF0742B8);
  static const Color _navy = Color(0xFF0D1B4C);
  static const Color _slate = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Highlighted blue logo.
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
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF4FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.picture_as_pdf_rounded,
                      color: _blue,
                      size: 14,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'PDF',
                      style: TextStyle(
                        color: _blue,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _navy,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Role: $roleName',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _blue,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _slate, fontSize: 11.5),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onView,
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.visibility_rounded, size: 18),
              label: const Text(
                'View PDF',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
