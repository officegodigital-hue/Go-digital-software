import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/widgets/premium_ui.dart';
import '../../services/api_service.dart';

/// Shared desktop navigation for every Admin Assets screen.
class NavbarWidget extends StatefulWidget {
  final VoidCallback? onMenu;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onLogout;
  final int selectedIndex;
  final ValueChanged<int>? onNavigate;

  const NavbarWidget({
    super.key,
    this.onMenu,
    this.onSearch,
    this.onLogout,
    this.selectedIndex = 0,
    this.onNavigate,
  });

  @override
  State<NavbarWidget> createState() => _NavbarWidgetState();
}

class _NavbarWidgetState extends State<NavbarWidget> {
  final TextEditingController _searchController = TextEditingController();

  Timer? _notificationTimer;

  int _unreadNotificationCount = 0;

  bool _loadingNotifications = false;

  List<dynamic> _notifications = [];

  String _adminName = '';
  String _adminEmail = '';
  String _adminRole = 'Administrator';
  String? _adminPhotoUrl;
  Uint8List? _adminPhotoBytes;
  bool _isUploadingAdminPhoto = false;

  @override
  void initState() {
    super.initState();

    _loadLoggedInAdminProfile();
    _loadUnreadNotificationCount();

    _notificationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadUnreadNotificationCount();
    });
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();

    _searchController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD LOGGED-IN ADMIN PROFILE
  // ============================================================

  Future<void> _loadLoggedInAdminProfile() async {
    try {
      // Show the authenticated session data immediately, then replace it with
      // the current database record below.
      final cachedName = await ApiService.getLoggedInUserName();
      final cachedEmail = await ApiService.getLoggedInUserEmail();
      final cachedRole = await ApiService.getLoggedInUserRole();
      if (mounted) {
        setState(() {
          if (cachedName != null && cachedName.trim().isNotEmpty)
            _adminName = cachedName.trim();
          if (cachedEmail != null && cachedEmail.trim().isNotEmpty)
            _adminEmail = cachedEmail.trim();
          if (cachedRole != null && cachedRole.trim().isNotEmpty)
            _adminRole = cachedRole.trim();
        });
      }
      final profile = await ApiService.getMyProfile();
      final photoUrl = profile['profile_photo_url']?.toString().trim();
      final name = profile['name']?.toString().trim();
      final email = profile['email']?.toString().trim();
      final role = profile['role']?.toString().trim();

      if (!mounted) {
        return;
      }

      setState(() {
        if (name != null && name.isNotEmpty) {
          _adminName = name;
        }

        if (email != null && email.isNotEmpty) {
          _adminEmail = email;
        }

        if (role != null && role.isNotEmpty) {
          _adminRole = role == 'Admin' ? 'Administrator' : role;
        }

        _adminPhotoUrl = photoUrl != null && photoUrl.isNotEmpty
            ? photoUrl
            : null;
      });
    } catch (_) {
      // Retain the most recently loaded profile if the API is temporarily unavailable.
    }
  }

  // ============================================================
  // LOAD UNREAD NOTIFICATION COUNT
  // ============================================================

  Future<void> _loadUnreadNotificationCount() async {
    try {
      final count = await ApiService.getUnreadNotificationCount();

      if (!mounted) {
        return;
      }

      setState(() {
        _unreadNotificationCount = count;
      });
    } catch (_) {
      // Do not interrupt the Admin UI if the notification
      // endpoint temporarily fails.
    }
  }

  // ============================================================
  // LOAD NOTIFICATIONS
  // ============================================================

  Future<void> _loadNotifications() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _loadingNotifications = true;
    });

    try {
      final notifications = await ApiService.getNotifications();

      if (!mounted) {
        return;
      }

      setState(() {
        _notifications = List<dynamic>.from(notifications);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load notifications: '
              '${error.toString().replaceFirst('Exception: ', '')}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _loadingNotifications = false;
        });
      }
    }
  }

  // ============================================================
  // SHOW NOTIFICATIONS
  // ============================================================

  Future<void> _showNotifications() async {
    await _loadNotifications();

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.all(20),
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 560,
                  maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.82,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DialogBanner(
                      icon: Icons.notifications_rounded,
                      title: 'Notifications',
                      subtitle: _unreadNotificationCount > 0
                          ? '$_unreadNotificationCount unread'
                          : 'You are all caught up',
                      onClose: () {
                        Navigator.of(dialogContext).pop();
                      },
                      action: _notifications.isEmpty
                          ? null
                          : TextButton.icon(
                              onPressed: () async {
                                try {
                                  await ApiService.markAllNotificationsAsRead();

                                  if (!mounted) {
                                    return;
                                  }

                                  setState(() {
                                    _unreadNotificationCount = 0;

                                    for (
                                      var index = 0;
                                      index < _notifications.length;
                                      index++
                                    ) {
                                      final item = _notifications[index];

                                      if (item is Map) {
                                        _notifications[index] = {
                                          ...item,
                                          'is_read': true,
                                        };
                                      }
                                    }
                                  });

                                  setDialogState(() {});

                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'All notifications marked as read.',
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                } catch (error) {
                                  if (!mounted) {
                                    return;
                                  }

                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to mark notifications as read: '
                                          '${error.toString().replaceFirst('Exception: ', '')}',
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                }
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: const Color(0x26FFFFFF),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.done_all_rounded, size: 17),
                              label: const Text(
                                'Mark all as read',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                    ),
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 460),
                        child: _loadingNotifications
                            ? const SizedBox(
                                height: 240,
                                child: PremiumLoading(
                                  label: 'Loading notifications...',
                                ),
                              )
                            : _notifications.isEmpty
                            ? SizedBox(
                                height: 260,
                                child: _buildEmptyNotifications(),
                              )
                            : _buildNotificationList(
                                dialogContext,
                                setDialogState,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    await _loadUnreadNotificationCount();
  }

  // ============================================================
  // EMPTY NOTIFICATIONS
  // ============================================================

  Widget _buildEmptyNotifications() {
    return const Center(
      child: PremiumEmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'No notifications',
        message: 'There are no notifications to show.',
      ),
    );
  }

  // ============================================================
  // NOTIFICATION LIST
  // ============================================================

  Widget _buildNotificationList(
    BuildContext dialogContext,
    StateSetter setDialogState,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.all(14),
      itemCount: _notifications.length,
      separatorBuilder: (_, _) {
        return const SizedBox(height: 8);
      },
      itemBuilder: (context, index) {
        final item = _notifications[index];

        if (item is! Map) {
          return const SizedBox.shrink();
        }

        final title = item['title']?.toString().trim() ?? 'Notification';

        final message = _notificationPreview(item['message']);

        final isRead = item['is_read'] == true;

        final id = item['id'];

        final createdAt = _formatNotificationTime(
          item['created_at']?.toString().trim() ?? '',
        );

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isRead ? Colors.white : PremiumColors.soft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isRead ? PremiumColors.line : const Color(0xFFCFE0FF),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PremiumIconTile(
                icon: isRead
                    ? Icons.notifications_none_rounded
                    : Icons.notifications_active_rounded,
                accent: isRead ? PremiumAccent.slate : PremiumAccent.blue,
                size: 38,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                              color: PremiumColors.ink,
                            ),
                          ),
                        ),

                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8, top: 6),
                            decoration: const BoxDecoration(
                              gradient: PremiumColors.heroGradient,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: PremiumColors.body,
                      ),
                    ),

                    if (createdAt.isNotEmpty) ...[
                      const SizedBox(height: 6),

                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: PremiumColors.faint,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            createdAt,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: PremiumColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (!isRead && id != null) ...[
                      const SizedBox(height: 6),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () async {
                            try {
                              await ApiService.markNotificationAsRead(
                                id.toString(),
                              );

                              if (!mounted) {
                                return;
                              }

                              setState(() {
                                _notifications[index] = {
                                  ...item,
                                  'is_read': true,
                                };

                                if (_unreadNotificationCount > 0) {
                                  _unreadNotificationCount--;
                                }
                              });

                              setDialogState(() {});
                            } catch (error) {
                              if (!mounted) {
                                return;
                              }

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to mark notification as read: '
                                    '${error.toString().replaceFirst('Exception: ', '')}',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: PremiumColors.blue,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: const Text('Mark as read'),
                        ),
                      ),
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

  String _notificationPreview(dynamic rawMessage) {
    final message = rawMessage?.toString().trim() ?? '';
    if (message.isEmpty) return '';

    // Try full JSON decode first
    try {
      final decoded = jsonDecode(message);
      if (decoded is Map) {
        final preview = decoded['preview']?.toString().trim() ?? '';
        if (preview.isNotEmpty) return preview;
        final payload = decoded['payload'];
        if (payload is Map) {
          final content = payload['content']?.toString().trim() ?? '';
          if (content.isNotEmpty) return content;
        }
      }
    } catch (_) {}

    // Fallback: regex-extract "preview":"..." even if JSON is malformed
    final previewMatch = RegExp(
      r'"preview"\s*:\s*"([^"]+)"',
    ).firstMatch(message);
    if (previewMatch != null) {
      final val = previewMatch.group(1)?.trim() ?? '';
      if (val.isNotEmpty) return val;
    }

    // Last resort: return plain text as-is (old notifications)
    return message;
  }

  String _formatNotificationTime(String value) {
    final timestamp = DateTime.tryParse(value)?.toLocal();
    if (timestamp == null) {
      return value;
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = timestamp.hour % 12 == 0 ? 12 : timestamp.hour % 12;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = timestamp.hour >= 12 ? 'PM' : 'AM';

    return '${timestamp.day} ${months[timestamp.month - 1]} '
        '${timestamp.year}, $hour:$minute $period';
  }

  // ============================================================
  // ADMIN PROFILE
  // ============================================================

  Future<void> _showAdminProfile() async {
    await _loadLoggedInAdminProfile();

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.all(20),
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Gradient cover with the avatar overlapping it.
                      SizedBox(
                        height: 150,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              height: 96,
                              decoration: const BoxDecoration(
                                gradient: PremiumColors.heroGradient,
                              ),
                              child: const Align(
                                alignment: Alignment.centerRight,
                                child: SizedBox(
                                  width: 180,
                                  child: PremiumDots(color: Color(0x4DFFFFFF)),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                tooltip: 'Close',
                                onPressed: () {
                                  Navigator.of(dialogContext).pop();
                                },
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              top: 50,
                              child: Center(
                                child: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Color(0x331B5FE8),
                                            blurRadius: 16,
                                            offset: Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: _buildAdminProfileAvatar(size: 88),
                                    ),
                                    Material(
                                      color: Colors.white,
                                      shape: const CircleBorder(
                                        side: BorderSide(
                                          color: PremiumColors.line,
                                        ),
                                      ),
                                      elevation: 2,
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: _isUploadingAdminPhoto
                                            ? null
                                            : () async {
                                                await _pickAndUploadAdminPhoto(
                                                  setDialogState,
                                                );
                                              },
                                        child: Padding(
                                          padding: const EdgeInsets.all(7),
                                          child: _isUploadingAdminPhoto
                                              ? const SizedBox(
                                                  width: 17,
                                                  height: 17,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color:
                                                            PremiumColors.blue,
                                                      ),
                                                )
                                              : const Icon(
                                                  Icons.camera_alt_outlined,
                                                  size: 17,
                                                  color: PremiumColors.blue,
                                                ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
                        child: Column(
                          children: [
                            Text(
                              _adminName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: PremiumColors.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            PremiumBadge(
                              label: _adminRole,
                              icon: Icons.admin_panel_settings_outlined,
                            ),
                            if (_adminEmail.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: PremiumColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: PremiumColors.line),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.email_outlined,
                                      size: 18,
                                      color: PremiumColors.blue,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _adminEmail,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: PremiumColors.ink,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            PremiumButton(
                              label: 'Change Photo',
                              icon: Icons.upload_outlined,
                              iconLeading: true,
                              expand: true,
                              variant: PremiumButtonVariant.outlined,
                              onPressed: _isUploadingAdminPhoto
                                  ? null
                                  : () async {
                                      await _pickAndUploadAdminPhoto(
                                        setDialogState,
                                      );
                                    },
                            ),
                            const SizedBox(height: 10),
                            PremiumButton(
                              label: 'Change Password',
                              icon: Icons.lock_outline,
                              iconLeading: true,
                              expand: true,
                              onPressed: () {
                                Navigator.of(dialogContext).pop();
                                _showChangeAdminPasswordDialog();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAdminProfileAvatar({required double size}) {
    if (_adminPhotoBytes != null) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: PremiumColors.blue,
        backgroundImage: MemoryImage(_adminPhotoBytes!),
      );
    }

    if (_adminPhotoUrl != null && _adminPhotoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: PremiumColors.blue,
        backgroundImage: NetworkImage(_profilePhotoNetworkUrl(_adminPhotoUrl!)),
      );
    }

    return _initialsAvatar(size);
  }

  Widget _buildAdminTopBarAvatar({required double size}) {
    if (_adminPhotoBytes != null) {
      return Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: _avatarRing,
        child: Image.memory(
          _adminPhotoBytes!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    if (_adminPhotoUrl != null && _adminPhotoUrl!.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: _avatarRing,
        child: Image.network(
          _profilePhotoNetworkUrl(_adminPhotoUrl!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) {
            return Center(
              child: Text(
                _initialsFromName(_adminName),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.40,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          },
        ),
      );
    }

    return _initialsAvatar(size);
  }

  BoxDecoration get _avatarRing => BoxDecoration(
    gradient: PremiumColors.heroGradient,
    shape: BoxShape.circle,
    border: Border.all(color: Colors.white, width: 2),
    boxShadow: const [
      BoxShadow(color: Color(0x331B5FE8), blurRadius: 8, offset: Offset(0, 3)),
    ],
  );

  Widget _initialsAvatar(double size) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: _avatarRing,
      child: Text(
        _initialsFromName(_adminName),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _initialsFromName(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'A';
    }

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  String _profilePhotoNetworkUrl(String value) {
    final trimmed = value.trim();

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    final apiUri = Uri.parse(ApiService.baseUrl);

    final origin = Uri(
      scheme: apiUri.scheme,
      host: apiUri.host,
      port: apiUri.hasPort ? apiUri.port : null,
    );

    final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';

    return origin.resolve(path).toString();
  }

  Future<void> _pickAndUploadAdminPhoto(StateSetter setDialogState) async {
    if (_isUploadingAdminPhoto) {
      return;
    }

    try {
      final selection = await FilePicker.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        withData: true,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      );

      final file = selection != null && selection.files.isNotEmpty
          ? selection.files.first
          : null;
      final bytes = file?.bytes;
      if (file == null || bytes == null) {
        return;
      }

      if (bytes.isEmpty) {
        _showTopBarMessage('Unable to read the selected photo.');
        return;
      }

      if (bytes.length > 5 * 1024 * 1024) {
        _showTopBarMessage('Profile photo must be 5 MB or smaller.');
        return;
      }

      setState(() {
        _isUploadingAdminPhoto = true;
        _adminPhotoBytes = bytes;
      });

      setDialogState(() {});

      final updatedUser = await ApiService.uploadProfilePhoto(
        photoBytes: bytes,
        fileName: file.name,
      );

      final returnedUrl = updatedUser['profile_photo_url']?.toString().trim();

      if (returnedUrl == null || returnedUrl.isEmpty) {
        throw Exception(
          'Photo uploaded, but the server did not return a photo URL.',
        );
      }

      final email = await ApiService.getLoggedInUserEmail();

      if (email != null && email.trim().isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();

        await prefs.setString(
          'profile_photo_url_${email.trim().toLowerCase()}',
          returnedUrl,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _adminPhotoUrl = returnedUrl;
        _adminPhotoBytes = null;
        _isUploadingAdminPhoto = false;
      });

      setDialogState(() {});

      _showTopBarMessage('Profile photo updated successfully.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _adminPhotoBytes = null;
        _isUploadingAdminPhoto = false;
      });

      setDialogState(() {});

      _showTopBarMessage(
        error.toString().replaceFirst('Exception: ', '').trim(),
      );
    }
  }

  InputDecoration _passwordDecoration({
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    OutlineInputBorder outline(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: PremiumColors.muted),
      prefixIcon: const Icon(Icons.lock_outline, color: PremiumColors.blue),
      suffixIcon: IconButton(
        onPressed: onToggle,
        icon: Icon(
          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: PremiumColors.muted,
        ),
      ),
      filled: true,
      fillColor: PremiumColors.surface,
      border: outline(PremiumColors.line),
      enabledBorder: outline(PremiumColors.line),
      focusedBorder: outline(PremiumColors.blue, 1.4),
    );
  }

  Future<void> _showChangeAdminPasswordDialog() async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();

    var obscurePassword = true;
    var obscureConfirm = true;
    var saving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return Dialog(
                backgroundColor: Colors.white,
                insetPadding: const EdgeInsets.all(20),
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DialogBanner(
                        icon: Icons.lock_reset_rounded,
                        title: 'Change Password',
                        subtitle: 'Use at least 8 characters',
                        onClose: saving
                            ? null
                            : () {
                                Navigator.of(dialogContext).pop();
                              },
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: passwordController,
                              obscureText: obscurePassword,
                              decoration: _passwordDecoration(
                                label: 'New Password',
                                obscure: obscurePassword,
                                onToggle: () {
                                  setDialogState(() {
                                    obscurePassword = !obscurePassword;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: confirmController,
                              obscureText: obscureConfirm,
                              decoration: _passwordDecoration(
                                label: 'Confirm New Password',
                                obscure: obscureConfirm,
                                onToggle: () {
                                  setDialogState(() {
                                    obscureConfirm = !obscureConfirm;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: PremiumButton(
                                    label: 'Cancel',
                                    icon: Icons.close_rounded,
                                    iconLeading: true,
                                    expand: true,
                                    variant: PremiumButtonVariant.outlined,
                                    onPressed: saving
                                        ? null
                                        : () {
                                            Navigator.of(dialogContext).pop();
                                          },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: PremiumButton(
                                    label: 'Change',
                                    icon: Icons.check_rounded,
                                    iconLeading: true,
                                    expand: true,
                                    loading: saving,
                                    onPressed: saving
                                        ? null
                                        : () async {
                                            final newPassword =
                                                passwordController.text;
                                            final confirmation =
                                                confirmController.text;

                                            if (newPassword.length < 8) {
                                              _showTopBarMessage(
                                                'Password must be at least 8 characters.',
                                              );
                                              return;
                                            }

                                            if (newPassword != confirmation) {
                                              _showTopBarMessage(
                                                'Passwords do not match.',
                                              );
                                              return;
                                            }

                                            setDialogState(() {
                                              saving = true;
                                            });

                                            try {
                                              final users =
                                                  await ApiService.getUsers();

                                              dynamic adminUser;

                                              for (final item in users) {
                                                if (item is! Map) {
                                                  continue;
                                                }

                                                final email =
                                                    item['email']
                                                        ?.toString()
                                                        .trim() ??
                                                    '';

                                                if (_adminEmail
                                                        .trim()
                                                        .isNotEmpty &&
                                                    email.toLowerCase() ==
                                                        _adminEmail
                                                            .trim()
                                                            .toLowerCase()) {
                                                  adminUser = item;
                                                  break;
                                                }
                                              }

                                              if (adminUser == null) {
                                                throw Exception(
                                                  'Logged-in Admin account was not found.',
                                                );
                                              }

                                              await ApiService.updateUser(
                                                userId: adminUser['id']
                                                    .toString(),
                                                name:
                                                    adminUser['name']
                                                        ?.toString() ??
                                                    _adminName,
                                                email:
                                                    adminUser['email']
                                                        ?.toString() ??
                                                    _adminEmail,
                                                mobile: adminUser['mobile']
                                                    ?.toString(),
                                                role:
                                                    adminUser['role']
                                                        ?.toString() ??
                                                    'Admin',
                                                password: newPassword,
                                              );

                                              if (!mounted) {
                                                return;
                                              }

                                              Navigator.of(dialogContext).pop();

                                              _showTopBarMessage(
                                                'Password changed successfully.',
                                              );
                                            } catch (error) {
                                              if (!mounted) {
                                                return;
                                              }

                                              setDialogState(() {
                                                saving = false;
                                              });

                                              _showTopBarMessage(
                                                error
                                                    .toString()
                                                    .replaceFirst(
                                                      'Exception: ',
                                                      '',
                                                    )
                                                    .trim(),
                                              );
                                            }
                                          },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      // Wait for the dialog's closing animation before disposing, otherwise
      // the fading TextFields touch disposed controllers.
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        passwordController.dispose();
        confirmController.dispose();
      });
    }
  }

  void _showTopBarMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message.isEmpty ? 'Request failed.' : message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PremiumIconTile(icon: Icons.logout_rounded, size: 52),
                  const SizedBox(height: 14),
                  const Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: PremiumColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Are you sure you want to logout?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: PremiumColors.muted),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: PremiumButton(
                          label: 'Cancel',
                          icon: Icons.close_rounded,
                          iconLeading: true,
                          expand: true,
                          variant: PremiumButtonVariant.outlined,
                          onPressed: () {
                            Navigator.of(dialogContext).pop(false);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PremiumButton(
                          label: 'Logout',
                          icon: Icons.logout_rounded,
                          iconLeading: true,
                          expand: true,
                          onPressed: () {
                            Navigator.of(dialogContext).pop(true);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirmed == true && mounted) {
      widget.onLogout?.call();
    }
  }

  // ============================================================
  // NAV ITEMS
  // ============================================================

  static const _navItems = [
    _NavItem(
      icon: Icons.folder_outlined,
      activeIcon: Icons.folder_rounded,
      label: 'Assets',
    ),
    _NavItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person_rounded,
      label: 'Users',
    ),
    _NavItem(
      icon: Icons.shield_outlined,
      activeIcon: Icons.shield_rounded,
      label: 'Permissions',
    ),
    _NavItem(
      icon: Icons.download_outlined,
      activeIcon: Icons.download_rounded,
      label: 'Downloads',
    ),
  ];

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    // Mobile navigation is supplied by AdminLayout's bottom bar. Keep this
    // header compact so every Admin Assets page remains usable on a phone
    // without losing notifications or profile access.
    if (widget.onMenu != null) {
      return _buildMobileBar();
    }

    return LayoutBuilder(
      builder: (context, box) {
        // Narrow laptops drop the portal label and the name next to the
        // avatar so the bar never overflows.
        final wide = box.maxWidth >= 1240;
        final compactTabs = box.maxWidth < 1120;

        return Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: PremiumColors.line)),
            boxShadow: [
              BoxShadow(
                color: Color(0x0D1E40AF),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Left: Logo + brand + divider + portal label ───────
              _buildLogo(38),
              const SizedBox(width: 10),
              const Text(
                'Go Digital',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: PremiumColors.blueDeep,
                ),
              ),
              if (wide) ...[
                Container(
                  width: 1,
                  height: 22,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  color: PremiumColors.line,
                ),
                const Text(
                  'Admin Portal',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: PremiumColors.muted,
                  ),
                ),
              ],

              // ── Center: Nav items in a pill track ─────────────────
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: PremiumColors.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: PremiumColors.line),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int i = 0; i < _navItems.length; i++)
                            _buildNavItem(i, compact: compactTabs),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // ── Right: bell | workspace | logout | avatar ──────────
              _buildSquareButton(
                icon: Icons.notifications_none_rounded,
                tooltip: 'Notifications',
                onTap: _showNotifications,
                badge: _unreadNotificationCount,
              ),
              const SizedBox(width: 8),
              _buildSquareButton(
                icon: Icons.grid_view_rounded,
                tooltip: 'Workspace',
                onTap: () => Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/home', (route) => false),
              ),
              const SizedBox(width: 8),
              _buildSquareButton(
                icon: Icons.logout_rounded,
                tooltip: 'Logout',
                onTap: _handleLogout,
              ),

              Container(
                width: 1,
                height: 24,
                color: PremiumColors.line,
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),

              // Avatar + name + chevron
              HoverBuilder(
                cursor: SystemMouseCursors.click,
                builder: (context, hovered) => GestureDetector(
                  onTap: _showAdminProfile,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
                    decoration: BoxDecoration(
                      color: hovered ? PremiumColors.soft : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildAdminTopBarAvatar(size: 34),
                        if (wide) ...[
                          const SizedBox(width: 8),
                          Text(
                            _adminName.isEmpty
                                ? 'Admin'
                                : _adminName.split(' ').first,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: PremiumColors.ink,
                            ),
                          ),
                        ],
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: PremiumColors.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: PremiumColors.line)),
      ),
      child: Row(
        children: [
          _buildLogo(34),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Go Digital',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: PremiumColors.blueDeep,
                  ),
                ),
                Text(
                  'Admin Portal',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: PremiumColors.muted,
                  ),
                ),
              ],
            ),
          ),
          _buildSquareButton(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Notifications',
            onTap: _showNotifications,
            badge: _unreadNotificationCount,
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _showAdminProfile,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: _buildAdminTopBarAvatar(size: 34),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.asset(
        'assets/images/godigital_logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: PremiumColors.heroGradient,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.view_in_ar_rounded,
            color: Colors.white,
            size: size * 0.55,
          ),
        ),
      ),
    );
  }

  Widget _buildSquareButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    return Tooltip(
      message: tooltip,
      child: HoverBuilder(
        cursor: SystemMouseCursors.click,
        builder: (context, hovered) => GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: hovered ? PremiumColors.soft : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hovered ? const Color(0xFFCFE0FF) : PremiumColors.line,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(child: Icon(icon, size: 19, color: PremiumColors.blue)),
                if (badge > 0)
                  Positioned(
                    right: -5,
                    top: -5,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: PremiumColors.heroGradient,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, {bool compact = false}) {
    final item = _navItems[index];
    final isActive = widget.selectedIndex == index;

    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        onTap: () => widget.onNavigate?.call(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            gradient: isActive ? PremiumColors.heroGradient : null,
            color: isActive
                ? null
                : hovered
                ? Colors.white
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              if (isActive)
                const BoxShadow(
                  color: Color(0x401B5FE8),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                isActive ? item.activeIcon : item.icon,
                size: 16,
                color: isActive
                    ? Colors.white
                    : hovered
                    ? PremiumColors.blue
                    : PremiumColors.muted,
              ),
              const SizedBox(width: 7),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  color: isActive
                      ? Colors.white
                      : hovered
                      ? PremiumColors.blue
                      : PremiumColors.body,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Blue gradient header used by the top bar's dialogs.
class _DialogBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onClose;
  final Widget? action;

  const _DialogBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onClose,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: PremiumColors.heroGradient),
      child: Stack(
        children: [
          const Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 180,
            child: PremiumDots(color: Color(0x40FFFFFF)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0x26FFFFFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x33FFFFFF)),
                  ),
                  child: Icon(icon, color: Colors.white, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xD9FFFFFF),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (action != null) ...[action!, const SizedBox(width: 4)],
                if (onClose != null)
                  IconButton(
                    tooltip: 'Close',
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
