import 'package:flutter_test/flutter_test.dart';
import '../lib/services/hrms_dashboard_api.dart';

void main() {
  test('Year totals use every month and match employees by account ID', () {
    final months = List.generate(
      12,
      (index) => <String, dynamic>{
        'kpis': {'workingDays': 20, 'present': 99},
        'employees': [
          {
            'employeeUserId': 1,
            'id': null,
            'name': 'Alex',
            'present': index + 1,
            'unexcused': 2,
            'late': 1,
            'approvedLeave': 1,
            'halfLeave': 0.5,
            'earnedLeave': 1,
            'salary': '₹10,000',
          },
          {'employeeUserId': 2, 'id': null, 'name': 'Sam', 'present': 1},
        ],
      },
    );
    final result = HrmsDashboardApi.aggregateYear(months);
    final rows = result['employees'] as List;
    expect(rows.length, 2);
    expect(rows.first['present'], 78);
    expect(rows.first['unexcused'], 24);
    expect(rows.first['late'], 12);
    expect(rows.first['halfLeave'], 6);
    expect(rows.first['earnedLeave'], 12);
    expect(rows.first['salary'], '₹10,000');
    expect(result['kpis']['present'], 90);
    expect(result['kpis']['workingDays'], 240);
  });
}
