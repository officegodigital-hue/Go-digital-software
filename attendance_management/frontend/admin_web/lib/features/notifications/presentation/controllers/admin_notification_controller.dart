import 'package:flutter/foundation.dart';

import '../../data/models/admin_notification_model.dart';
import '../../data/repositories/admin_notification_repository.dart';

class AdminNotificationController extends ChangeNotifier {
  AdminNotificationController({AdminNotificationRepository? repository})
    : _repository = repository ?? AdminNotificationRepository();

  final AdminNotificationRepository _repository;

  final List<AdminNotificationModel> _notifications =
      <AdminNotificationModel>[];

  bool _isLoading = false;

  String? _errorMessage;

  int _totalCount = 0;
  int _unreadCount = 0;

  List<AdminNotificationModel> get notifications =>
      List<AdminNotificationModel>.unmodifiable(_notifications);

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  int get totalCount => _totalCount;

  int get unreadCount => _unreadCount;

  bool get hasNotifications => _notifications.isNotEmpty;

  Future<void> initialize() async {
    await fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final AdminNotificationListResult result = await _repository
          .getNotifications();

      _notifications
        ..clear()
        ..addAll(result.notifications);

      _totalCount = result.totalCount;

      _unreadCount = result.unreadCount;
    } catch (error) {
      _errorMessage = _normalizeError(error);
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  Future<void> refresh() {
    return fetchNotifications();
  }

  Future<void> markAsRead(AdminNotificationModel notification) async {
    if (notification.isRead) {
      return;
    }

    try {
      await _repository.markAsRead(notification.id);

      await fetchNotifications();
    } catch (error) {
      _errorMessage = _normalizeError(error);

      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _repository.markAllAsRead();

      await fetchNotifications();
    } catch (error) {
      _errorMessage = _normalizeError(error);

      notifyListeners();
    }
  }

  Future<void> deleteNotification(AdminNotificationModel notification) async {
    try {
      await _repository.deleteNotification(notification.id);

      await fetchNotifications();
    } catch (error) {
      _errorMessage = _normalizeError(error);

      notifyListeners();
    }
  }

  String _normalizeError(Object error) {
    final String message = error.toString().trim();

    if (message.startsWith('Exception:')) {
      return message.substring('Exception:'.length).trim();
    }

    return message.isEmpty ? 'Unable to load notifications.' : message;
  }

  @override
  void dispose() {
    _repository.dispose();

    super.dispose();
  }
}
