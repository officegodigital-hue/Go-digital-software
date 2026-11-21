import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:godigital_portal/core/widgets/notification_robot.dart';
import 'package:godigital_portal/services/api_config.dart';
import 'package:godigital_portal/services/auth_service.dart';
import 'package:godigital_portal/services/authenticated_http.dart' as http;

import 'report_notification_filter.dart';
import 'report_brand.dart';

class ReportNotificationsScreen extends StatefulWidget {
  const ReportNotificationsScreen({super.key});

  @override
  State<ReportNotificationsScreen> createState() =>
      _ReportNotificationsScreenState();
}

class _ReportNotificationsScreenState extends State<ReportNotificationsScreen> {
  List<Map<String, dynamic>> _notifications = const [];
  final Set<int> _updatingIds = {};
  bool _loading = true;
  bool _markingAll = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthService>();
      final user = auth.user ?? const <String, dynamic>{};
      final name =
          (user['fullName'] ?? user['full_name'] ?? user['name'])
              ?.toString()
              .trim() ??
          '';
      if (name.isEmpty) {
        throw Exception('Unable to identify the signed-in user.');
      }

      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/notifications/${Uri.encodeComponent(name)}',
        ),
        headers: const {'Accept': 'application/json'},
      );
      final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = decoded is Map ? decoded['message']?.toString() : null;
        throw Exception(message ?? 'Unable to load notifications.');
      }
      final rows = decoded is Map ? decoded['data'] : null;
      if (rows is! List) {
        throw Exception('The notifications response was invalid.');
      }
      if (!mounted) return;
      setState(() {
        _notifications = rows
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .where(
              (row) => isReportWorkflowNotification(row['message']?.toString()),
            )
            .toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  bool _isSeen(Map<String, dynamic> row) {
    final value = row['isSeen'];
    return value == true || value == 1 || value?.toString() == 'true';
  }

  int get _unreadCount => _notifications
      .where((row) => row['type'] != 'SENT' && !_isSeen(row))
      .length;

  Future<void> _markAllSeen() async {
    if (_markingAll || _unreadCount == 0) return;
    setState(() => _markingAll = true);
    try {
      for (final row in List<Map<String, dynamic>>.from(_notifications)) {
        if (row['type'] != 'SENT' && !_isSeen(row)) {
          await _markSeen(row);
        }
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _markSeen(Map<String, dynamic> row) async {
    final id = int.tryParse(row['id']?.toString() ?? '');
    if (id == null || _isSeen(row) || _updatingIds.contains(id)) return;

    setState(() => _updatingIds.add(id));
    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/notifications/$id'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'isSeen': true}),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final decoded = response.body.isEmpty
            ? null
            : jsonDecode(response.body);
        final message = decoded is Map ? decoded['message']?.toString() : null;
        throw Exception(message ?? 'Unable to update this notification.');
      }
      if (!mounted) return;
      setState(() {
        _notifications = _notifications.map((item) {
          if (item['id']?.toString() == id.toString()) {
            return {...item, 'isSeen': true};
          }
          return item;
        }).toList();
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _updatingIds.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
          child: ReportHeroHeader(
            title: 'Notifications',
            subtitle: 'Stay updated with report activity and approvals.',
            icon: Icons.notifications_active_rounded,
            action: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_unreadCount > 0)
                  FilledButton.icon(
                    onPressed: _loading || _markingAll ? null : _markAllSeen,
                    icon: _markingAll
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.done_all_rounded, size: 17),
                    label: const Text('Mark all as read'),
                    style: FilledButton.styleFrom(
                      backgroundColor: ReportBrand.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: 'Refresh notifications',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: ReportBrand.blue,
                    side: const BorderSide(color: ReportBrand.cardBorder),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _loading
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(
                        height: 260,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ],
                  )
                : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: 260,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xffb42318),
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: _load,
                                child: const Text('Try again'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : _notifications.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(
                        height: 260,
                        child: Center(
                          child: Text(
                            'No notifications yet.',
                            style: TextStyle(color: Color(0xff64748b)),
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final row = _notifications[index];
                      final isReceived = row['type'] != 'SENT';
                      final seen = _isSeen(row);
                      final message = row['message']?.toString() ?? '';
                      final parsed = parseNotificationMessage(message);
                      final preview = parsed.preview.trim().isEmpty
                          ? message
                          : parsed.preview;
                      final createdAt = DateTime.tryParse(
                        row['createdAt']?.toString() ?? '',
                      )?.toLocal();
                      final when = createdAt == null
                          ? row['time']?.toString() ?? ''
                          : '${createdAt.day}/${createdAt.month}/${createdAt.year} '
                                '${createdAt.hour.toString().padLeft(2, '0')}:'
                                '${createdAt.minute.toString().padLeft(2, '0')}';
                      final otherParty = isReceived
                          ? row['senderName']?.toString() ?? 'Someone'
                          : row['recipientName']?.toString() ?? 'Someone';
                      final lowerPreview = preview.toLowerCase();
                      final messageColor = lowerPreview.contains('rejected')
                          ? const Color(0xffe11d48)
                          : lowerPreview.contains('approved')
                          ? const Color(0xff0f9f6e)
                          : const Color(0xff0e63e6);
                      final messageIcon = lowerPreview.contains('rejected')
                          ? Icons.cancel_rounded
                          : lowerPreview.contains('approved')
                          ? Icons.check_circle_rounded
                          : isReceived
                          ? Icons.fact_check_rounded
                          : Icons.send_rounded;

                      return Card(
                        elevation: 0,
                        color: seen ? Colors.white : const Color(0xffeff6ff),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: seen
                                ? const Color(0xffe2e8f0)
                                : const Color(0xffbfdbfe),
                          ),
                        ),
                        child: ListTile(
                          onTap: isReceived && !seen
                              ? () => _markSeen(row)
                              : null,
                          leading: CircleAvatar(
                            radius: 25,
                            backgroundColor: messageColor.withValues(
                              alpha: .12,
                            ),
                            child: Icon(
                              messageIcon,
                              color: messageColor,
                              size: 23,
                            ),
                          ),
                          title: Text(
                            isReceived
                                ? 'From $otherParty'
                                : 'Sent to $otherParty',
                            style: const TextStyle(
                              color: Color(0xff142f61),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                              preview,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                when,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xff64748b),
                                ),
                              ),
                              if (isReceived && !seen) ...[
                                const SizedBox(height: 6),
                                _updatingIds.contains(
                                      int.tryParse(row['id']?.toString() ?? ''),
                                    )
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.circle,
                                        size: 9,
                                        color: Color(0xff0866e8),
                                      ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
