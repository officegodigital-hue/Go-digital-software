import 'package:flutter_test/flutter_test.dart';
import 'package:godigital_portal/report/report_notification_filter.dart';

void main() {
  test('includes report approval workflow notifications', () {
    expect(
      isReportWorkflowNotification(
        'Report for Acme (November 2026) is ready for your approval.',
      ),
      isTrue,
    );
    expect(
      isReportWorkflowNotification(
        'Your report for Acme (November 2026) was rejected. Note: Please revise.',
      ),
      isTrue,
    );
  });

  test('excludes notifications outside the report workflow', () {
    expect(
      isReportWorkflowNotification('You have been assigned a new task.'),
      isFalse,
    );
    expect(
      isReportWorkflowNotification('Can we discuss the report today?'),
      isFalse,
    );
  });
}
