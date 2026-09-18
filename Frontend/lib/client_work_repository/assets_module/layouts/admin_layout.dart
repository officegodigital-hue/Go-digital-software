import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/company_model.dart';
import '../features/admin/company_detail/company_detail_page.dart';
import '../services/api_service.dart';
import '../widgets/navigation/sidebar.dart';
import '../widgets/navigation/top_bar.dart';

class AdminLayout extends StatefulWidget {
  final Widget Function(
    int index,
    void Function(int index) onNavigate,
  ) childBuilder;

  final VoidCallback onLogout;

  const AdminLayout({
    super.key,
    required this.childBuilder,
    required this.onLogout,
  });

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  int selectedIndex = 0;

  void _selectPage(int index) {
    if (!mounted) {
      return;
    }

    setState(() {
      selectedIndex = index;
    });
  }

  void _selectPageFromDrawer(
    BuildContext drawerContext,
    int index,
  ) {
    Navigator.of(drawerContext).pop();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _selectPage(index);
    });
  }


  Future<void> _handleGlobalSearch(String value) async {
    final query = value.trim();

    if (query.isEmpty) {
      return;
    }

    try {
      final results = await Future.wait([
        ApiService.getCompanies(),
        ApiService.getAssets(),
      ]);

      final companies = results[0];
      final assets = results[1];

      final q = query.toLowerCase();

      final matchingCompanies = companies.where((item) {
        if (item is! Map) return false;

        final name = item['name']?.toString().toLowerCase() ?? '';
        return name.contains(q);
      }).toList();

      final matchingAssets = assets.where((item) {
        if (item is! Map) return false;

        final name = item['name']?.toString().toLowerCase() ?? '';
        final type = item['type']?.toString().toLowerCase() ?? '';
        final company =
            item['company_name']?.toString().toLowerCase() ?? '';
        final link = item['link']?.toString().toLowerCase() ?? '';

        return name.contains(q) ||
            type.contains(q) ||
            company.contains(q) ||
            link.contains(q);
      }).toList();

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(
                  Icons.search,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Search results for "$query"',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 560,
              child: (matchingCompanies.isEmpty &&
                      matchingAssets.isEmpty)
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Text(
                          'No matching companies or assets found.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        if (matchingCompanies.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Companies',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          for (final company in matchingCompanies.take(10))
                            ListTile(
                              dense: true,
                              leading: const CircleAvatar(
                                radius: 18,
                                child: Icon(
                                  Icons.business_outlined,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                company['name']?.toString() ?? 'Company',
                              ),
                              subtitle: const Text('Company'),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 15),
                              onTap: () async {
                                Navigator.of(dialogContext).pop();
                                await Future<void>.delayed(const Duration(milliseconds: 120));
                                if (!mounted) return;
                                await _openSearchCompany(
                                  companyData: Map<dynamic, dynamic>.from(company),
                                  assets: assets,
                                );
                              },
                            ),
                        ],
                        if (matchingAssets.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Assets',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          for (final asset in matchingAssets.take(15))
                            ListTile(
                              dense: true,
                              leading: const CircleAvatar(
                                radius: 18,
                                child: Icon(
                                  Icons.insert_drive_file_outlined,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                asset['name']?.toString() ?? 'Asset',
                              ),
                              subtitle: Text(
                                '${asset['company_name'] ?? 'Company'} • ${asset['type'] ?? 'Asset'}',
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 15),
                              onTap: () async {
                                Navigator.of(dialogContext).pop();
                                await Future<void>.delayed(const Duration(milliseconds: 120));
                                if (!mounted) return;
                                await _openSearchAsset(
                                  assetData: Map<dynamic, dynamic>.from(asset),
                                  companies: companies,
                                  assets: assets,
                                );
                              },
                            ),
                        ],
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Search failed: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openSearchCompany({
    required Map companyData,
    required List<dynamic> assets,
  }) async {
    if (!mounted) return;

    final companyId = companyData['id']?.toString() ?? '';
    final companyName = companyData['name']?.toString().trim() ?? '';

    if (companyId.isEmpty || companyName.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final createdAt = DateTime.tryParse(
          companyData['created_at']?.toString() ?? '',
        ) ??
        now;
    final updatedAt = DateTime.tryParse(
          companyData['updated_at']?.toString() ?? '',
        ) ??
        createdAt;

    final sections = <String>[];
    final rawSections = companyData['sections'];
    if (rawSections is List) {
      for (final value in rawSections) {
        final section = value?.toString().trim() ?? '';
        if (section.isNotEmpty && !sections.contains(section)) {
          sections.add(section);
        }
      }
    }

    // Prefer the section from the matching asset. This makes an asset search
    // result open the same section where that asset is stored.
    String section = '';
    for (final item in assets) {
      if (item is! Map) continue;
      if (item['company_id']?.toString() != companyId) continue;

      final assetSection = item['section']?.toString().trim() ?? '';
      if (assetSection.isNotEmpty) {
        section = assetSection;
        break;
      }
    }

    if (section.isEmpty && sections.isNotEmpty) {
      section = sections.first;
    }

    // A company without existing assets/sections can still be opened.
    if (section.isEmpty) {
      section = 'Digital Marketing';
    }

    final company = CompanyModel(
      id: companyId,
      name: companyName,
      createdAt: createdAt,
      updatedAt: updatedAt,
      section: section,
    );

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 20,
          ),
          backgroundColor: AppColors.background,
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 1000,
              maxHeight: MediaQuery.sizeOf(dialogContext).height - 40,
            ),
            child: CompanyDetailPage(
              company: company,
              section: section,
              embedded: true,
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSearchAsset({
    required Map assetData,
    required List<dynamic> companies,
    required List<dynamic> assets,
  }) async {
    if (!mounted) return;

    final companyId = assetData['company_id']?.toString() ?? '';
    final companyName = assetData['company_name']?.toString().trim() ?? '';
    final assetSection = assetData['section']?.toString().trim() ?? '';

    if (companyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This asset is not linked to a company.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Map? companyData;
    for (final item in companies) {
      if (item is Map && item['id']?.toString() == companyId) {
        companyData = item;
        break;
      }
    }

    // Build a minimal company object if the company is not present in the
    // current company response.
    companyData ??= <String, dynamic>{
      'id': companyId,
      'name': companyName.isEmpty ? 'Company' : companyName,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'sections': assetSection.isEmpty ? <String>[] : <String>[assetSection],
    };

    if (assetSection.isNotEmpty) {
      companyData['sections'] = <String>[assetSection];
    }

    await _openSearchCompany(
      companyData: companyData,
      assets: assets,
    );
  }

  void _logoutFromDrawer(
    BuildContext drawerContext,
  ) {
    Navigator.of(drawerContext).pop();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      widget.onLogout();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = width >= 1024;

        if (isDesktop) {
          return _buildDesktopLayout();
        }

        return _buildMobileLayout();
      },
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 250,
            child: AdminSidebar(
              selectedIndex: selectedIndex,
              onItemSelected: _selectPage,
              onLogout: widget.onLogout,
            ),
          ),

          Expanded(
            child: Column(
              children: [
                AdminTopBar(
                  onSearch: _handleGlobalSearch,
                  onLogout: widget.onLogout,
                ),

                Expanded(
                  child: widget.childBuilder(
                    selectedIndex,
                    _selectPage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: AppColors.background,

      drawerEnableOpenDragGesture: true,

      drawer: Drawer(
        width: 280,
        elevation: 10,
        backgroundColor: Colors.white,

        child: SafeArea(
          child: Builder(
            builder: (drawerContext) {
              return AdminSidebar(
                selectedIndex: selectedIndex,
                onItemSelected: (index) {
                  _selectPageFromDrawer(
                    drawerContext,
                    index,
                  );
                },
                onLogout: () {
                  _logoutFromDrawer(
                    drawerContext,
                  );
                },
              );
            },
          ),
        ),
      ),

      appBar: const _MobileAdminAppBar(),

      body: widget.childBuilder(
        selectedIndex,
        _selectPage,
      ),
    );
  }
}

class _MobileAdminAppBar extends StatefulWidget
    implements PreferredSizeWidget {
  const _MobileAdminAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  State<_MobileAdminAppBar> createState() =>
      _MobileAdminAppBarState();
}

class _MobileAdminAppBarState extends State<_MobileAdminAppBar> {
  Timer? _notificationTimer;

  int _unreadNotificationCount = 0;

  bool _loadingNotifications = false;

  List<dynamic> _notifications = [];

  @override
  void initState() {
    super.initState();

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
    super.dispose();
  }

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
    } catch (_) {}
  }

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
        _notifications = notifications;
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
                20,
                18,
                12,
                10,
              ),
              contentPadding:
                  const EdgeInsets.fromLTRB(
                12,
                0,
                12,
                12,
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
                    icon: const Icon(Icons.close),
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

  Widget _buildEmptyNotifications() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
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

  Widget _buildNotificationList(
    BuildContext dialogContext,
    StateSetter setDialogState,
  ) {
    return ListView.separated(
      itemCount: _notifications.length,
      separatorBuilder: (_, __) {
        return const Divider(height: 1);
      },
      itemBuilder: (
        context,
        index,
      ) {
        final item = _notifications[index];

        if (item is! Map) {
          return const SizedBox.shrink();
        }

        final title =
            item['title']?.toString().trim() ?? 'Notification';

        final message =
            item['message']?.toString().trim() ?? '';

        final isRead =
            item['is_read'] == true;

        final id = item['id'];

        final createdAt =
            item['created_at']?.toString().trim() ?? '';

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: isRead
                ? Colors.white
                : AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isRead
                      ? const Color(0xFFF2F4F7)
                      : AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
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
                              fontWeight: isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(
                              left: 8,
                              top: 6,
                            ),
                            decoration:
                                const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (createdAt.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        createdAt,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (!isRead && id != null) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
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
                                _notifications[index] = {
                                  ...item,
                                  'is_read': true,
                                };

                                if (_unreadNotificationCount >
                                    0) {
                                  _unreadNotificationCount--;
                                }
                              });

                              setDialogState(() {});
                            } catch (error) {
                              if (!mounted) {
                                return;
                              }

                              ScaffoldMessenger.of(context)
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
                                      SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 30),
                            tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
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

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: true,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: Builder(
        builder: (context) {
          return IconButton(
            tooltip: 'Open menu',
            icon: const Icon(
              Icons.menu,
              size: 27,
              color: AppColors.textPrimary,
            ),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          );
        },
      ),
      titleSpacing: 0,
      title: const Text(
        'Go Digital',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      actions: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: 'Notifications',
              onPressed: _showNotifications,
              icon: const Icon(
                Icons.notifications_none_outlined,
                size: 27,
                color: AppColors.textPrimary,
              ),
            ),
            if (_unreadNotificationCount > 0)
              Positioned(
                right: 5,
                top: 3,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    _unreadNotificationCount > 99
                        ? '99+'
                        : _unreadNotificationCount.toString(),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 5),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: Container(
              width: 43,
              height: 43,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Text(
                'A',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(
          height: 1,
          thickness: 1,
          color: AppColors.border,
        ),
      ),
    );
  }
}
