import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../constants/app_colors.dart';
import '../constants/employee_role.dart';
import '../../services/auth_service.dart';
import '../../services/api_config.dart'; // ApiConfig-ஐ இணைக்கவும்

class EmployeeTopbar extends StatefulWidget {
  // final EmployeeRole role;
  // final VoidCallback? onOpenNotifications;

  // const EmployeeTopbar({
  //   super.key,
  //   required this.role,
  //   this.onOpenNotifications,
  // });

  final EmployeeRole role;
final VoidCallback? onOpenNotifications;
final VoidCallback? onOpenAssignedTasks;

const EmployeeTopbar({
  super.key,
  required this.role,
  this.onOpenNotifications,
  this.onOpenAssignedTasks,
});

  @override
  State<EmployeeTopbar> createState() => _EmployeeTopbarState();
}

class _EmployeeTopbarState extends State<EmployeeTopbar> {
  Timer? _pollingTimer;
  int _unreadCount = 0;
  String? _latestMessage;
  bool _showPopup = false;
  Timer? _popupTimer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  Set<int> _knownNotificationIds = {};
  final TextEditingController _searchController = TextEditingController();
Timer? _searchDebounce;

List<Map<String, dynamic>> _searchResults = [];
bool _isSearching = false;
bool _showSearchResults = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _popupTimer?.cancel();
    _searchDebounce?.cancel();
  _searchController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

Future<void> _searchTasks(String query) async {
  final searchText = query.trim();

  if (searchText.isEmpty) {
    if (mounted) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
        _isSearching = false;
      });
    }
    return;
  }

  final authService = Provider.of<AuthService>(
    context,
    listen: false,
  );

  final employeeName =
      authService.user?['fullName']?.toString() ?? '';

  if (employeeName.isEmpty) return;

  setState(() {
    _isSearching = true;
    _showSearchResults = true;
  });

  try {
    final role = _getBackendRole();

    final url = Uri.parse(
      '${ApiConfig.baseUrl}/tasks/employee/'
      '${Uri.encodeComponent(employeeName)}/'
      '${Uri.encodeComponent(role)}',
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    final body = jsonDecode(response.body);

    final List rows = body['data'] ?? [];

    final results = rows
        .map<Map<String, dynamic>>(
          (e) => Map<String, dynamic>.from(e),
        )
        .where((row) {
          final client =
              (row['client_name'] ?? '').toString().toLowerCase();

          final task =
              (row['task'] ?? '').toString().toLowerCase();

          final deliverables =
              (row['deliverables'] ?? '').toString().toLowerCase();

          final search =
              searchText.toLowerCase();

          return client.contains(search) ||
              task.contains(search) ||
              deliverables.contains(search);
        })
        .take(8)
        .toList();

    if (!mounted) return;

    setState(() {
      _searchResults = results;
      _isSearching = false;
      _showSearchResults = true;
    });
  } catch (e) {
    debugPrint('Search error: $e');

    if (!mounted) return;

    setState(() {
      _searchResults = [];
      _isSearching = false;
    });
  }
}

void _onSearchChanged(String value) {
  _searchDebounce?.cancel();

  _searchDebounce = Timer(
    const Duration(milliseconds: 400),
    () {
      _searchTasks(value);
    },
  );
}

void _openSearchResult(Map<String, dynamic> result) {
  final clientName =
      result['client_name']?.toString() ?? '';

  debugPrint('Opening search result: $clientName');

  setState(() {
    _showSearchResults = false;
    _searchController.clear();
    _searchResults = [];
  });

  FocusScope.of(context).unfocus();

  if (widget.onOpenAssignedTasks != null) {
    widget.onOpenAssignedTasks!();
  }
}

Widget _buildSearchResults() {
  if (_isSearching) {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  if (_searchResults.isEmpty) {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(
            Icons.search_off,
            size: 20,
            color: AppColors.textGrey,
          ),
          SizedBox(width: 10),
          Text(
            'No tasks or clients found',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textGrey,
            ),
          ),
        ],
      ),
    );
  }

  return ListView.separated(
    shrinkWrap: true,
    padding: const EdgeInsets.symmetric(vertical: 6),
    itemCount: _searchResults.length,
    separatorBuilder: (_, __) => const Divider(
      height: 1,
      color: Color(0xFFE2E8F0),
    ),
    itemBuilder: (context, index) {
      final item = _searchResults[index];

      final client =
          item['client_name']?.toString() ?? '-';

      final task =
          item['task']?.toString() ?? '';

      final deliverables =
          item['deliverables']?.toString() ?? '';

      return InkWell(
        onTap: () => _openSearchResult(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 11,
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(
                    alpha: 0.08,
                  ),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(
                  Icons.business_center_outlined,
                  size: 17,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      client,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),

                    const SizedBox(height: 3),

                    if (task.isNotEmpty)
                      Text(
                        task,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textGrey,
                        ),
                      )
                    else if (deliverables.isNotEmpty)
                      Text(
                        deliverables,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textGrey,
                        ),
                      ),
                  ],
                ),
              ),

              const Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: AppColors.textGrey,
              ),
            ],
          ),
        ),
      );
    },
  );
}

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      await _checkNewNotifications();
    });
  }

  Future<void> _checkNewNotifications() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final employeeName = authService.user?['fullName'];
    
    if (employeeName == null || employeeName.isEmpty) return;

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/notifications/${Uri.encodeComponent(employeeName)}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List rows = body["data"] ?? [];

        int unread = 0;
        Set<int> currentIds = {};
        bool hasNewNotification = false;
        String? latestMsgText;

        for (var row in rows) {
          // ID-ah int-ka safely convert panrathuku
          int id = int.tryParse(row["id"]?.toString() ?? '0') ?? 0;
          currentIds.add(id);

          bool isSentByMe = row["type"] == "SENT";
          bool isSeen = row["isSeen"] == true || row["isSeen"] == 1 || row["isSeen"].toString() == "true";

          if (!isSentByMe && !isSeen) {
            unread++;
          }

          // 🌟 Fix: First load-l irukkura IDs-ah known list-kku add pannirum. 
          // Appuram varura pudhu IDs-kku mattum popup & sound varum.
          if (_knownNotificationIds.isNotEmpty && !_knownNotificationIds.contains(id) && !isSentByMe && !isSeen) {
            hasNewNotification = true;
            // latestMsgText = row["message"] ?? "New Notification received";
                        try {
  final decoded = jsonDecode(row["message"]);

  final preview = decoded["preview"] ?? "New Notification";

  latestMsgText = preview;
} catch (e) {
  latestMsgText = row["message"] ?? "New Notification";
}
          }
        }

        setState(() {
          _unreadCount = unread;
          // First time empty-ah iruntha, current IDs-ah athula load pannirurom
          if (_knownNotificationIds.isEmpty && currentIds.isNotEmpty) {
            _knownNotificationIds = currentIds;
          } else if (currentIds.isNotEmpty) {
            _knownNotificationIds = currentIds;
          }
        });

         if (hasNewNotification) {
          _playNotificationSound();
          _triggerTopRightPopup(latestMsgText ?? "You have a new notification");
        }
      }
    } catch (e) {
      debugPrint("Polling error: $e");
    }
  }

  void _playNotificationSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
    } catch (e) {
      debugPrint("Audio play error: $e");
    }
  }

  // Top-right பகுதியில் 3 வினாடிகள் மட்டும் Popup காட்ட வழிமுறை
  void _triggerTopRightPopup(String message) {
    setState(() {
      _latestMessage = message;
      _showPopup = true;
    });

    _popupTimer?.cancel();
    _popupTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _showPopup = false;
        });
      }
    });
  }

 @override
  Widget build(BuildContext context) {
    // 🌟 Overflow-ah avoid panna parent-ku unconstrained or Stack-ku proper bounds kuduthu irukku
    return SizedBox(
      height: 54,
      child: Stack(
        clipBehavior: Clip.none, // Popup veliya overflow aagi theriyuthu nu confirm panrathuku
        children: [
          Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              children: [
                // Container(
                //   width: 460,
                //   height: 34,
                //   padding: const EdgeInsets.symmetric(horizontal: 14),
                //   decoration: BoxDecoration(
                //     color: const Color(0xFFF1F5F9),
                //     borderRadius: BorderRadius.circular(4),
                //   ),
                //   child: const Row(
                //     children: [
                //       Icon(Icons.search, size: 17, color: AppColors.textGrey),
                //       SizedBox(width: 10),
                //       Text(
                //         'Search tasks, clients...',
                //         style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                //       ),
                //     ],
                //   ),
                // ),
                SizedBox(
  width: 460,
  height: 38,
  child: Stack(
    clipBehavior: Clip.none,
    children: [
      Container(
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
          ),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          onTap: () {
            if (_searchController.text.trim().isNotEmpty) {
              setState(() {
                _showSearchResults = true;
              });
            }
          },
          decoration: InputDecoration(
            hintText: 'Search clients, tasks...',
            hintStyle: const TextStyle(
              fontSize: 12,
              color: AppColors.textGrey,
            ),
            prefixIcon: const Icon(
              Icons.search,
              size: 18,
              color: AppColors.textGrey,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.textGrey,
                    ),
                    onPressed: () {
                      _searchController.clear();

                      setState(() {
                        _searchResults = [];
                        _showSearchResults = false;
                      });
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
          ),
        ),
      ),

      // SEARCH RESULTS
      if (_showSearchResults)
        Positioned(
          top: 44,
          left: 0,
          child: Material(
            elevation: 10,
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
            child: Container(
              width: 460,
              constraints: const BoxConstraints(
                maxHeight: 350,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                ),
              ),
              child: _buildSearchResults(),
            ),
          ),
        ),
    ],
  ),
),
                const Spacer(),
                
                // 🔔 Notification Icon with Red Badge Count
                Stack(
                  children: [
                    // IconButton(
                    //   icon: const Icon(Icons.notifications_none, size: 20, color: AppColors.textDark),
                    //   onPressed: () {
                    //     Navigator.pushNamed(context, '/notifications');
                    //   },
                    // ),
                    IconButton(
  icon: const Icon(
    Icons.notifications_none,
    size: 20,
    color: AppColors.textDark,
  ),
  onPressed: widget.onOpenNotifications,
),
                    if (_unreadCount > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$_unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(width: 24),
                const Icon(Icons.help_outline, size: 18, color: AppColors.textDark),
                const SizedBox(width: 24),
                Container(height: 30, width: 1, color: AppColors.border),
                const SizedBox(width: 14),
                
                Consumer<AuthService>(
                  builder: (context, authService, _) {
                    final employeeName = authService.user?['fullName'] ?? 'Employee';
                    final employeeRole = authService.user?['role'] ?? widget.role.title;
                    final initials = authService.user?['initials'] ?? _generateInitials(employeeName);

                    return Row(
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              employeeName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                            ),
                            Text(
                              employeeRole,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // 🌟 Top-Right Popup (Topbar-ku veliya correct-a render aaga Positioned)
          if (_showPopup)
            Positioned(
              top: 58, // Topbar height-ku keela கரெக்டா வர 58px
              right: 20,
              child: Material(
                color: Colors.transparent,
                elevation: 8,
                child: Container(
                  width: 300,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: const Color(0xFF0052CC), width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active, color: Color(0xFF0052CC), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              "New Notification",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _latestMessage ?? "",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        
        ],
      ),
    );
  }
  String _getBackendRole() {
  switch (widget.role) {
    case EmployeeRole.designer:
      return 'designer';

    case EmployeeRole.adsHandler:
      return 'ads handler';

    case EmployeeRole.videographer:
      return 'videographer';

    case EmployeeRole.pageHandler:
      return 'page handler';
  }
}

  String _generateInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return (parts.first[0] + parts.last[0]).toUpperCase();
    } else {
      return parts.first[0].toUpperCase();
    }
  }
}