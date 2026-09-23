import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../services/api_service.dart';

class AdminTopBar extends StatefulWidget {
  final VoidCallback? onMenu;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onLogout;

  const AdminTopBar({
    super.key,
    this.onMenu,
    this.onSearch,
    this.onLogout,
  });

  @override
  State<AdminTopBar> createState() => _AdminTopBarState();
}

class _AdminTopBarState extends State<AdminTopBar> {
  final TextEditingController _searchController =
      TextEditingController();

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

    _notificationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        _loadUnreadNotificationCount();
      },
    );
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
          if (cachedName != null && cachedName.trim().isNotEmpty) _adminName = cachedName.trim();
          if (cachedEmail != null && cachedEmail.trim().isNotEmpty) _adminEmail = cachedEmail.trim();
          if (cachedRole != null && cachedRole.trim().isNotEmpty) _adminRole = cachedRole.trim();
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
          _adminRole =
              role == 'Admin'
                  ? 'Administrator'
                  : role;
        }

        _adminPhotoUrl =
            photoUrl != null && photoUrl.isNotEmpty
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
      final count =
          await ApiService.getUnreadNotificationCount();

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
      final notifications =
          await ApiService.getNotifications();

      if (!mounted) {
        return;
      }

      setState(() {
        _notifications = notifications.where((n) {
          final msg = n['message']?.toString() ?? '';
          // Exclude task planner and day planner notifications
          try {
            final decoded = jsonDecode(msg);
            if (decoded is Map) {
              final payload = decoded['payload'];
              if (payload is Map) {
                final type = payload['type']?.toString() ?? '';
                if (type.startsWith('TASK_PLANNER') ||
                    type.startsWith('DAY_PLANNER')) {
                  return false;
                }
              }
            }
          } catch (_) {
            // plain text — check for known non-asset keywords
            final lower = msg.toLowerCase();
            if (lower.contains('task planner') ||
                lower.contains('day planner') ||
                lower.contains('morning day planner')) {
              return false;
            }
          }
          return true;
        }).toList();
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
              '${error.toString().replaceFirst(
                'Exception: ',
                '',
              )}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingNotifications = false;
      });
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
          builder: (
            dialogContext,
            setDialogState,
          ) {
            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(
                24,
                20,
                16,
                12,
              ),
              contentPadding:
                  const EdgeInsets.fromLTRB(
                16,
                0,
                16,
                16,
              ),
              title: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),

                  if (_notifications.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        try {
                          await ApiService
                              .markAllNotificationsAsRead();

                          if (!mounted) {
                            return;
                          }

                          setState(() {
                            _unreadNotificationCount = 0;

                            for (
                              var index = 0;
                              index <
                                  _notifications.length;
                              index++
                            ) {
                              final item =
                                  _notifications[index];

                              if (item is Map) {
                                _notifications[index] =
                                    {
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
                                behavior:
                                    SnackBarBehavior.floating,
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
                                  '${error.toString().replaceFirst(
                                    'Exception: ',
                                    '',
                                  )}',
                                ),
                                behavior:
                                    SnackBarBehavior.floating,
                              ),
                            );
                        }
                      },
                      child: const Text(
                        'Mark all as read',
                      ),
                    ),

                  IconButton(
                    tooltip: 'Close',
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    icon: const Icon(
                      Icons.close,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 560,
                height: 520,
                child: _loadingNotifications
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : _notifications.isEmpty
                        ? _buildEmptyNotifications()
                        : _buildNotificationList(
                            dialogContext,
                            setDialogState,
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
    return Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(
                alpha: 0.08,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_outlined,
              size: 32,
              color: AppColors.primary,
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            'No notifications',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'There are no notifications to show.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
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
      itemCount: _notifications.length,
      separatorBuilder: (_, _) {
        return const Divider(
          height: 1,
        );
      },
      itemBuilder: (
        context,
        index,
      ) {
        final item =
            _notifications[index];

        if (item is! Map) {
          return const SizedBox.shrink();
        }

        final title =
            item['title']?.toString().trim() ??
                'Notification';

        final message = _notificationPreview(item['message']);

        final isRead =
            item['is_read'] == true;

        final id =
            item['id'];

        final createdAt = _formatNotificationTime(
          item['created_at']?.toString().trim() ?? '',
        );

        return Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: isRead
                ? Colors.white
                : AppColors.primary.withValues(
                    alpha: 0.05,
                  ),
            borderRadius:
                BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isRead
                      ? const Color(
                          0xFFF2F4F7,
                        )
                      : AppColors.primary
                          .withValues(
                          alpha: 0.10,
                        ),
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
                child: Icon(
                  Icons.notifications_outlined,
                  size: 21,
                  color: isRead
                      ? AppColors.textSecondary
                      : AppColors.primary,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  isRead
                                      ? FontWeight.w600
                                      : FontWeight.w800,
                              color:
                                  AppColors.textPrimary,
                            ),
                          ),
                        ),

                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin:
                                const EdgeInsets.only(
                              left: 8,
                              top: 6,
                            ),
                            decoration:
                                const BoxDecoration(
                              color:
                                  AppColors.primary,
                              shape:
                                  BoxShape.circle,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 5),

                    Text(
                      message,
                      style:
                          const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color:
                            AppColors.textSecondary,
                      ),
                    ),

                    if (createdAt.isNotEmpty) ...[
                      const SizedBox(height: 6),

                      Text(
                        createdAt,
                        style:
                            const TextStyle(
                          fontSize: 11,
                          color:
                              AppColors.textSecondary,
                        ),
                      ),
                    ],

                    if (!isRead &&
                        id != null) ...[
                      const SizedBox(height: 6),

                      Align(
                        alignment:
                            Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () async {
                            try {
                              await ApiService
                                  .markNotificationAsRead(
                                id.toString(),
                              );

                              if (!mounted) {
                                return;
                              }

                              setState(() {
                                _notifications[
                                    index] = {
                                  ...item,
                                  'is_read':
                                      true,
                                };

                                if (
                                  _unreadNotificationCount >
                                      0
                                ) {
                                  _unreadNotificationCount--;
                                }
                              });

                              setDialogState(() {});
                            } catch (error) {
                              if (!mounted) {
                                return;
                              }

                              ScaffoldMessenger.of(
                                context,
                              )
                                  .showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to mark notification as read: '
                                    '${error.toString().replaceFirst(
                                      'Exception: ',
                                      '',
                                    )}',
                                  ),
                                  behavior:
                                      SnackBarBehavior
                                          .floating,
                                ),
                              );
                            }
                          },
                          style:
                              TextButton.styleFrom(
                            padding:
                                EdgeInsets.zero,
                            minimumSize:
                                const Size(
                              0,
                              30,
                            ),
                            tapTargetSize:
                                MaterialTapTargetSize
                                    .shrinkWrap,
                          ),
                          child: const Text(
                            'Mark as read',
                          ),
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
    final previewMatch = RegExp(r'"preview"\s*:\s*"([^"]+)"').firstMatch(message);
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
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
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
            return AlertDialog(
              title: const Text(
                'Admin Profile',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 360,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          _buildAdminProfileAvatar(
                            size: 84,
                          ),
                          Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
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
                                padding:
                                    const EdgeInsets.all(7),
                                child: _isUploadingAdminPhoto
                                    ? const SizedBox(
                                        width: 17,
                                        height: 17,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.camera_alt_outlined,
                                        size: 17,
                                        color: AppColors.primary,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _adminName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _adminRole,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (_adminEmail.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.email_outlined,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _adminEmail,
                                maxLines: 2,
                                overflow:
                                    TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color:
                                      AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isUploadingAdminPhoto
                              ? null
                              : () async {
                                  await _pickAndUploadAdminPhoto(
                                    setDialogState,
                                  );
                                },
                          icon: const Icon(
                            Icons.upload_outlined,
                          ),
                          label: const Text(
                            'Change Photo',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            _showChangeAdminPasswordDialog();
                          },
                          icon: const Icon(
                            Icons.lock_outline,
                          ),
                          label: const Text(
                            'Change Password',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAdminProfileAvatar({
    required double size,
  }) {
    if (_adminPhotoBytes != null) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: AppColors.primary,
        backgroundImage: MemoryImage(_adminPhotoBytes!),
      );
    }

    if (_adminPhotoUrl != null &&
        _adminPhotoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: AppColors.primary,
        backgroundImage:
            NetworkImage(_profilePhotoNetworkUrl(_adminPhotoUrl!)),
      );
    }

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.primary,
      child: Text(
        _initialsFromName(_adminName),
        style: TextStyle(
          fontSize: size * 0.30,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildAdminTopBarAvatar({
    required double size,
  }) {
    if (_adminPhotoBytes != null) {
      return Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary,
        ),
        child: Image.memory(
          _adminPhotoBytes!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    if (_adminPhotoUrl != null &&
        _adminPhotoUrl!.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary,
        ),
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

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.primary,
      child: Text(
        _initialsFromName(_adminName),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.40,
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

    return (parts.first.substring(0, 1) +
            parts.last.substring(0, 1))
        .toUpperCase();
  }

  String _profilePhotoNetworkUrl(String value) {
    final trimmed = value.trim();

    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://')) {
      return trimmed;
    }

    final apiUri = Uri.parse(ApiService.baseUrl);

    final origin = Uri(
      scheme: apiUri.scheme,
      host: apiUri.host,
      port: apiUri.hasPort ? apiUri.port : null,
    );

    final path =
        trimmed.startsWith('/') ? trimmed : '/$trimmed';

    return origin.resolve(path).toString();
  }

  Future<void> _pickAndUploadAdminPhoto(
    StateSetter setDialogState,
  ) async {
    if (_isUploadingAdminPhoto) {
      return;
    }

    try {
      final selection = await FilePicker.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        withData: true,
        allowedExtensions: const [
          'jpg',
          'jpeg',
          'png',
          'webp',
        ],
      );

      final file = selection != null && selection.files.isNotEmpty
          ? selection.files.first
          : null;
      final bytes = file?.bytes;
      if (file == null || bytes == null) {
        return;
      }

      if (bytes.isEmpty) {
        _showTopBarMessage(
          'Unable to read the selected photo.',
        );
        return;
      }

      if (bytes.length > 5 * 1024 * 1024) {
        _showTopBarMessage(
          'Profile photo must be 5 MB or smaller.',
        );
        return;
      }

      setState(() {
        _isUploadingAdminPhoto = true;
        _adminPhotoBytes = bytes;
      });

      setDialogState(() {});

      final updatedUser =
          await ApiService.uploadProfilePhoto(
        photoBytes: bytes,
        fileName: file.name,
      );

      final returnedUrl =
          updatedUser['profile_photo_url']
              ?.toString()
              .trim();

      if (returnedUrl == null ||
          returnedUrl.isEmpty) {
        throw Exception(
          'Photo uploaded, but the server did not return a photo URL.',
        );
      }

      final email =
          await ApiService.getLoggedInUserEmail();

      if (email != null &&
          email.trim().isNotEmpty) {
        final prefs =
            await SharedPreferences.getInstance();

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

      _showTopBarMessage(
        'Profile photo updated successfully.',
      );
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
        error
            .toString()
            .replaceFirst('Exception: ', '')
            .trim(),
      );
    }
  }

  Future<void> _showChangeAdminPasswordDialog() async {
    final passwordController =
        TextEditingController();
    final confirmController =
        TextEditingController();

    var obscurePassword = true;
    var obscureConfirm = true;
    var saving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (
              dialogContext,
              setDialogState,
            ) {
              return AlertDialog(
                title: const Text(
                  'Change Password',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                content: SizedBox(
                  width: 360,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                          ),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setDialogState(() {
                                obscurePassword =
                                    !obscurePassword;
                              });
                            },
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons
                                      .visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: confirmController,
                        obscureText: obscureConfirm,
                        decoration: InputDecoration(
                          labelText:
                              'Confirm New Password',
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                          ),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setDialogState(() {
                                obscureConfirm =
                                    !obscureConfirm;
                              });
                            },
                            icon: Icon(
                              obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons
                                      .visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () {
                            Navigator.of(dialogContext).pop();
                          },
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            final newPassword =
                                passwordController.text;
                            final confirmation =
                                confirmController.text;

                            if (newPassword.length <
                                8) {
                              _showTopBarMessage(
                                'Password must be at least 8 characters.',
                              );
                              return;
                            }

                            if (newPassword !=
                                confirmation) {
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

                              for (final item
                                  in users) {
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

                              if (adminUser ==
                                  null) {
                                throw Exception(
                                  'Logged-in Admin account was not found.',
                                );
                              }

                              await ApiService.updateUser(
                                userId:
                                    adminUser['id']
                                        .toString(),
                                name:
                                    adminUser['name']
                                            ?.toString() ??
                                        _adminName,
                                email:
                                    adminUser['email']
                                            ?.toString() ??
                                        _adminEmail,
                                mobile:
                                    adminUser['mobile']
                                        ?.toString(),
                                role:
                                    adminUser['role']
                                            ?.toString() ??
                                        'Admin',
                                password:
                                    newPassword,
                              );

                              if (!mounted) {
                                return;
                              }

                              Navigator.of(
                                dialogContext,
                              ).pop();

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
                    child: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Change Password'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      passwordController.dispose();
      confirmController.dispose();
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
          content: Text(
            message.isEmpty
                ? 'Request failed.'
                : message,
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Logout',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      widget.onLogout?.call();
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
          ),
        ),
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 24,
      ),
      child: Row(
        children: [
          if (widget.onMenu != null)
            IconButton(
              onPressed:
                  widget.onMenu,
              icon: const Icon(
                Icons.menu,
              ),
            ),

          Expanded(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 465,
              ),
              child: TextField(
                onChanged: (value) {
                  setState(() {});
                },
                onSubmitted:
                    widget.onSearch,
                controller:
                    _searchController,
                textInputAction:
                    TextInputAction.search,
                decoration:
                    InputDecoration(
                  prefixIcon:
                      const Icon(
                    Icons.search,
                  ),
                  hintText:
                      'Search assets, companies, links...',
                  suffixIcon:
                      _searchController
                              .text
                              .isEmpty
                          ? null
                          : IconButton(
                              tooltip:
                                  'Clear search',
                              onPressed: () {
                                _searchController
                                    .clear();

                                setState(
                                  () {},
                                );

                                widget.onSearch
                                    ?.call(
                                  '',
                                );
                              },
                              icon:
                                  const Icon(
                                Icons.close,
                              ),
                            ),
                ),
              ),
            ),
          ),

          const Spacer(),

          // ======================================================
          // NOTIFICATION BELL
          // ======================================================

          Stack(
            clipBehavior:
                Clip.none,
            children: [
              IconButton(
                tooltip:
                    'Notifications',
                onPressed:
                    _showNotifications,
                icon:
                    const Icon(
                  Icons
                      .notifications_none,
                  size: 26,
                ),
              ),

              if (_unreadNotificationCount >
                  0)
                Positioned(
                  right: 5,
                  top: 4,
                  child: Container(
                    constraints:
                        const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 4,
                    ),
                    alignment:
                        Alignment.center,
                    decoration:
                        BoxDecoration(
                      color:
                          Colors.red,
                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),
                      border:
                          Border.all(
                        color:
                            Colors.white,
                        width: 1.5,
                      ),
                    ),
                    child:
                        Text(
                      _unreadNotificationCount >
                              99
                          ? '99+'
                          : _unreadNotificationCount
                              .toString(),
                      style:
                          const TextStyle(
                        fontSize: 9,
                        fontWeight:
                            FontWeight.w800,
                        color:
                            Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.help_outline,
              size: 26,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Container(
            width: 1,
            height: 38,
            color: AppColors.border,
          ),

          const SizedBox(
            width: 18,
          ),

          OutlinedButton.icon(
            onPressed: () => Navigator.of(
              context,
              rootNavigator: true,
            ).pushNamedAndRemoveUntil('/home', (route) => false),
            icon: const Icon(Icons.grid_view_rounded, size: 19),
            label: const Text('Workspace'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}
