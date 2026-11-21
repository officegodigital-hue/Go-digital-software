import 'package:godigital_portal/core/widgets/notification_robot.dart';

bool isReportWorkflowNotification(String? message) {
  final preview = parseNotificationMessage(message ?? '').preview.trim();
  return RegExp(
        r'^Report for .+ is ready for your approval\.',
        caseSensitive: false,
      ).hasMatch(preview) ||
      RegExp(
        r'^Your report for .+ was (approved|rejected)\.',
        caseSensitive: false,
      ).hasMatch(preview);
}
