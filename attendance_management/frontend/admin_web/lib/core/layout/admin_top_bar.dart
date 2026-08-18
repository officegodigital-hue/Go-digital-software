import 'package:flutter/material.dart';

class AdminTopBar extends StatelessWidget {
  const AdminTopBar({
    required this.adminName,
    required this.adminRole,
    required this.onNotificationsPressed,
    required this.onHelpPressed,
    required this.onProfilePressed,
    this.searchController,
    this.onSearchChanged,
    this.onMenuPressed,
    this.profileImageUrl,
    this.notificationCount = 0,
    this.showMenuButton = false,
    this.height = 67,
    super.key,
  });

  final String adminName;
  final String adminRole;

  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;

  final VoidCallback onNotificationsPressed;
  final VoidCallback onHelpPressed;
  final VoidCallback onProfilePressed;
  final VoidCallback? onMenuPressed;

  final String? profileImageUrl;

  final int notificationCount;
  final bool showMenuButton;
  final double height;

  static const Color _topBarColor = Color(0xFF03233D);
  static const Color _searchBackground = Color(0xFFF4F5FF);
  static const Color _searchTextColor = Color(0xFF25272D);
  static const Color _searchHintColor = Color(0xFF6D7280);
  static const Color _mutedWhite = Color(0xFFD5DEE7);
  static const Color _profileBackground = Color(0xFFF1F3F6);
  static const Color _primary = Color(0xFF1919EC);
  static const Color _danger = Color(0xFFCF2028);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: _topBarColor,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 760;
          final bool veryCompact = constraints.maxWidth < 520;

          return Row(
            children: <Widget>[
              if (showMenuButton) ...<Widget>[
                _TopBarIconButton(
                  tooltip: 'Open Menu',
                  icon: Icons.menu_rounded,
                  onPressed: onMenuPressed,
                ),
                const SizedBox(width: 8),
              ],
              if (!veryCompact)
                const Text(
                  'Attendance Tracker',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.15,
                  ),
                ),
              if (!veryCompact) const SizedBox(width: 18),
              if (!compact)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 310),
                      child: _SearchField(
                        controller: searchController,
                        onChanged: onSearchChanged,
                      ),
                    ),
                  ),
                )
              else
                const Spacer(),
              if (!compact) const SizedBox(width: 14),
              _NotificationButton(
                count: notificationCount,
                onPressed: onNotificationsPressed,
              ),
              const SizedBox(width: 7),
              _TopBarIconButton(
                tooltip: 'Help',
                icon: Icons.help_outline_rounded,
                onPressed: onHelpPressed,
              ),
              const SizedBox(width: 12),
              Container(
                width: 1,
                height: 27,
                color: Colors.white.withValues(alpha: 0.32),
              ),
              const SizedBox(width: 12),
              _ProfileButton(
                adminName: adminName,
                adminRole: adminRole,
                profileImageUrl: profileImageUrl,
                compact: veryCompact,
                onPressed: onProfilePressed,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 31,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(
          color: AdminTopBar._searchTextColor,
          fontSize: 10,
          height: 1.15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Search employees, records, or settings...',
          hintStyle: const TextStyle(
            color: AdminTopBar._searchHintColor,
            fontSize: 9,
            height: 1.15,
            fontWeight: FontWeight.w400,
          ),
          filled: true,
          fillColor: AdminTopBar._searchBackground,
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 16,
            color: Color(0xFF555B68),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 34,
            minHeight: 31,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: const BorderSide(
              color: AdminTopBar._primary,
              width: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        _TopBarIconButton(
          tooltip: 'Notifications',
          icon: Icons.notifications_none_rounded,
          onPressed: onPressed,
        ),
        if (count > 0)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              constraints: const BoxConstraints(minWidth: 15),
              height: 15,
              padding: const EdgeInsets.symmetric(horizontal: 3),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AdminTopBar._danger,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AdminTopBar._topBarColor, width: 1.3),
              ),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 7,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TopBarIconButton extends StatefulWidget {
  const _TopBarIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  State<_TopBarIconButton> createState() {
    return _TopBarIconButtonState();
  }
}

class _TopBarIconButtonState extends State<_TopBarIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: widget.onPressed == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) {
          setState(() {
            _isHovered = true;
          });
        },
        onExit: (_) {
          setState(() {
            _isHovered = false;
          });
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(5),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _isHovered
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Icon(widget.icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileButton extends StatefulWidget {
  const _ProfileButton({
    required this.adminName,
    required this.adminRole,
    required this.profileImageUrl,
    required this.compact,
    required this.onPressed,
  });

  final String adminName;
  final String adminRole;
  final String? profileImageUrl;
  final bool compact;
  final VoidCallback onPressed;

  @override
  State<_ProfileButton> createState() {
    return _ProfileButtonState();
  }
}

class _ProfileButtonState extends State<_ProfileButton> {
  bool _isHovered = false;

  String get _initials {
    final List<String> words = widget.adminName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) {
      return 'A';
    }

    if (words.length == 1) {
      final String word = words.first;

      if (word.length >= 2) {
        return word.substring(0, 2).toUpperCase();
      }

      return word.toUpperCase();
    }

    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _isHovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _isHovered = false;
        });
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(5),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            decoration: BoxDecoration(
              color: _isHovered
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _ProfileAvatar(
                  imageUrl: widget.profileImageUrl,
                  initials: _initials,
                ),
                if (!widget.compact) ...<Widget>[
                  const SizedBox(width: 9),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 112),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.adminName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            height: 1.1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.adminRole,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AdminTopBar._mutedWhite,
                            fontSize: 8,
                            height: 1.1,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.imageUrl, required this.initials});

  final String? imageUrl;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final String normalizedUrl = imageUrl?.trim() ?? '';

    return Container(
      width: 40,
      height: 40,
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: normalizedUrl.isEmpty
            ? _buildFallback()
            : Image.network(
                normalizedUrl,
                fit: BoxFit.cover,
                errorBuilder:
                    (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) {
                      return _buildFallback();
                    },
              ),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      color: AdminTopBar._profileBackground,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: AdminTopBar._primary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
