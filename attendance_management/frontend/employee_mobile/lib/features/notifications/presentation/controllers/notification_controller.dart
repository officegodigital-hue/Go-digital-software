import 'package:employee_mobile/features/notifications/data/models/notification_response.dart';
import 'package:employee_mobile/features/notifications/data/repositories/notification_repository.dart';
import 'package:flutter/foundation.dart';

enum NotificationFilter { all, unread }

class NotificationController extends ChangeNotifier {
  NotificationController({NotificationRepository? repository})
    : _repository = repository ?? NotificationRepository();

  final NotificationRepository _repository;

  List<AppNotification> _notifications = <AppNotification>[];

  NotificationFilter _selectedFilter = NotificationFilter.all;

  bool _isLoading = false;
  bool _isActionLoading = false;

  int _unreadCount = 0;

  String? _errorMessage;
  String? _successMessage;

  // ---------------------------------------------------------------------------
  // Main getters
  // ---------------------------------------------------------------------------

  List<AppNotification> get notifications {
    return List<AppNotification>.unmodifiable(_notifications);
  }

  List<AppNotification> get filteredNotifications {
    if (_selectedFilter == NotificationFilter.unread) {
      return List<AppNotification>.unmodifiable(
        _notifications.where((AppNotification notification) {
          return !notification.isRead;
        }),
      );
    }

    return notifications;
  }

  List<AppNotification> get unreadNotifications {
    return List<AppNotification>.unmodifiable(
      _notifications.where((AppNotification notification) {
        return !notification.isRead;
      }),
    );
  }

  List<AppNotification> get readNotifications {
    return List<AppNotification>.unmodifiable(
      _notifications.where((AppNotification notification) {
        return notification.isRead;
      }),
    );
  }

  NotificationFilter get selectedFilter {
    return _selectedFilter;
  }

  bool get isAllSelected {
    return _selectedFilter == NotificationFilter.all;
  }

  bool get isUnreadSelected {
    return _selectedFilter == NotificationFilter.unread;
  }

  bool get isLoading {
    return _isLoading;
  }

  bool get isActionLoading {
    return _isActionLoading;
  }

  bool get isBusy {
    return _isLoading || _isActionLoading;
  }

  int get unreadCount {
    return _unreadCount;
  }

  int get totalCount {
    return _notifications.length;
  }

  int get readCount {
    return _notifications.where((AppNotification notification) {
      return notification.isRead;
    }).length;
  }

  bool get hasNotifications {
    return _notifications.isNotEmpty;
  }

  bool get hasUnreadNotifications {
    return _unreadCount > 0;
  }

  String? get errorMessage {
    return _errorMessage;
  }

  String? get successMessage {
    return _successMessage;
  }

  // ---------------------------------------------------------------------------
  // Initial loading
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    await loadNotifications();
  }

  Future<void> refresh() async {
    await loadNotifications(showLoading: false);
  }

  Future<void> loadNotifications({bool showLoading = true}) async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;

    if (showLoading) {
      notifyListeners();
    }

    try {
      final response = await _repository.getNotifications();

      if (!response.success) {
        _errorMessage = response.message.trim().isEmpty
            ? 'Unable to load notifications.'
            : response.message.trim();

        return;
      }

      _notifications = List<AppNotification>.from(response.notifications);

      _sortNotifications();

      _unreadCount = response.unreadCount;

      final calculatedUnreadCount = _notifications.where((
        AppNotification notification,
      ) {
        return !notification.isRead;
      }).length;

      if (_unreadCount < calculatedUnreadCount) {
        _unreadCount = calculatedUnreadCount;
      }
    } on NotificationRepositoryException catch (error) {
      _errorMessage = error.message;
    } catch (error) {
      _errorMessage = 'Unable to load notifications: $error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Filter
  // ---------------------------------------------------------------------------

  void selectAllNotifications() {
    setFilter(NotificationFilter.all);
  }

  void selectUnreadNotifications() {
    setFilter(NotificationFilter.unread);
  }

  void setFilter(NotificationFilter filter) {
    if (_selectedFilter == filter) {
      return;
    }

    _selectedFilter = filter;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Mark one notification as read
  // ---------------------------------------------------------------------------

  Future<bool> markAsRead(AppNotification notification) async {
    if (notification.isRead) {
      return true;
    }

    final notificationId = notification.notificationId;

    if (notificationId == null) {
      _markNotificationLocallyAsRead(notification);

      return true;
    }

    return markNotificationAsRead(notificationId);
  }

  Future<bool> markNotificationAsRead(int notificationId) async {
    if (_isActionLoading) {
      return false;
    }

    final notificationIndex = _notifications.indexWhere((
      AppNotification notification,
    ) {
      return notification.notificationId == notificationId;
    });

    if (notificationIndex == -1) {
      _errorMessage = 'Notification could not be found.';

      notifyListeners();

      return false;
    }

    if (_notifications[notificationIndex].isRead) {
      return true;
    }

    _beginAction();

    try {
      final message = await _repository.markAsRead(notificationId);

      final notification = _notifications[notificationIndex];

      _notifications[notificationIndex] = notification.copyWith(isRead: true);

      _recalculateUnreadCount();

      _successMessage = message.trim().isEmpty
          ? 'Notification marked as read.'
          : message.trim();

      return true;
    } on NotificationRepositoryException catch (error) {
      _errorMessage = error.message;

      return false;
    } catch (error) {
      _errorMessage = 'Unable to mark notification as read: $error';

      return false;
    } finally {
      _finishAction();
    }
  }

  void _markNotificationLocallyAsRead(AppNotification notification) {
    final notificationIndex = _notifications.indexOf(notification);

    if (notificationIndex == -1) {
      return;
    }

    _notifications[notificationIndex] = notification.copyWith(isRead: true);

    _recalculateUnreadCount();

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Mark all notifications as read
  // ---------------------------------------------------------------------------

  Future<bool> markAllAsRead() async {
    if (_isActionLoading) {
      return false;
    }

    if (!hasUnreadNotifications) {
      _successMessage = 'All notifications are already read.';

      notifyListeners();

      return true;
    }

    _beginAction();

    try {
      final message = await _repository.markAllAsRead();

      _notifications = _notifications.map((AppNotification notification) {
        return notification.copyWith(isRead: true);
      }).toList();

      _unreadCount = 0;

      _successMessage = message.trim().isEmpty
          ? 'All notifications marked as read.'
          : message.trim();

      return true;
    } on NotificationRepositoryException catch (error) {
      _errorMessage = error.message;

      return false;
    } catch (error) {
      _errorMessage = 'Unable to mark all notifications as read: $error';

      return false;
    } finally {
      _finishAction();
    }
  }

  // ---------------------------------------------------------------------------
  // Delete notification
  // ---------------------------------------------------------------------------

  Future<bool> deleteNotification(AppNotification notification) async {
    final notificationId = notification.notificationId;

    if (notificationId == null) {
      _notifications.remove(notification);

      _recalculateUnreadCount();

      _successMessage = 'Notification deleted successfully.';

      notifyListeners();

      return true;
    }

    return deleteNotificationById(notificationId);
  }

  Future<bool> deleteNotificationById(int notificationId) async {
    if (_isActionLoading) {
      return false;
    }

    final notificationIndex = _notifications.indexWhere((
      AppNotification notification,
    ) {
      return notification.notificationId == notificationId;
    });

    if (notificationIndex == -1) {
      _errorMessage = 'Notification could not be found.';

      notifyListeners();

      return false;
    }

    _beginAction();

    try {
      final message = await _repository.deleteNotification(notificationId);

      _notifications.removeAt(notificationIndex);

      _recalculateUnreadCount();

      _successMessage = message.trim().isEmpty
          ? 'Notification deleted successfully.'
          : message.trim();

      return true;
    } on NotificationRepositoryException catch (error) {
      _errorMessage = error.message;

      return false;
    } catch (error) {
      _errorMessage = 'Unable to delete notification: $error';

      return false;
    } finally {
      _finishAction();
    }
  }

  // ---------------------------------------------------------------------------
  // Unread count
  // ---------------------------------------------------------------------------

  Future<void> loadUnreadCount() async {
    try {
      final unreadCount = await _repository.getUnreadCount();

      _unreadCount = unreadCount;

      notifyListeners();
    } on NotificationRepositoryException catch (error) {
      _errorMessage = error.message;

      notifyListeners();
    } catch (error) {
      _errorMessage = 'Unable to load unread count: $error';

      notifyListeners();
    }
  }

  void _recalculateUnreadCount() {
    _unreadCount = _notifications.where((AppNotification notification) {
      return !notification.isRead;
    }).length;
  }

  // ---------------------------------------------------------------------------
  // Action helpers
  // ---------------------------------------------------------------------------

  void _beginAction() {
    _isActionLoading = true;
    _errorMessage = null;
    _successMessage = null;

    notifyListeners();
  }

  void _finishAction() {
    _isActionLoading = false;

    notifyListeners();
  }

  void _sortNotifications() {
    _notifications.sort((AppNotification first, AppNotification second) {
      final firstDate = first.createdAt;
      final secondDate = second.createdAt;

      if (firstDate == null && secondDate == null) {
        return 0;
      }

      if (firstDate == null) {
        return 1;
      }

      if (secondDate == null) {
        return -1;
      }

      return secondDate.compareTo(firstDate);
    });
  }

  // ---------------------------------------------------------------------------
  // Messages
  // ---------------------------------------------------------------------------

  void clearErrorMessage() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;
    notifyListeners();
  }

  void clearSuccessMessage() {
    if (_successMessage == null) {
      return;
    }

    _successMessage = null;
    notifyListeners();
  }

  void clearMessages() {
    if (_errorMessage == null && _successMessage == null) {
      return;
    }

    _errorMessage = null;
    _successMessage = null;

    notifyListeners();
  }
}
