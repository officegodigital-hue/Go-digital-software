import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:godigital_portal/services/hrms_employees_api.dart';
import 'package:godigital_portal/services/hrms_tracking_api.dart';
import 'package:godigital_portal/services/hrms_payroll_api.dart';
import 'package:godigital_portal/services/hrms_approvals_api.dart';
import 'package:godigital_portal/services/hrms_payslip_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'HRMS clients send authenticated requests with backend field names',
    () async {
      SharedPreferences.setMockInitialValues({'auth_token': 'wiring-test'});
      final requests = <http.Request>[];
      await http.runWithClient(
        () async {
          await HrmsEmployeesApi.createRole('Designer');
          await HrmsTrackingApi.updateOfficeLocation(
            officeName: 'Office',
            officeAddress: 'Address',
            officeLatitude: 13,
            officeLongitude: 80,
            officeRadiusMeters: 150,
          );
          await HrmsPayrollApi.generate(year: 2026, month: 10);
          await HrmsPayrollApi.markPaid(7);
          await HrmsApprovalsApi.review(8, 'Approved');
          await HrmsPayslipApi.summary();
          await HrmsPayslipApi.request(7);
        },
        () => MockClient((request) async {
          requests.add(request);
          expect(request.headers['Authorization'], 'Bearer wiring-test');
          return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
        }),
      );
      expect(requests.map((r) => '${r.method} ${r.url.path}').toList(), [
        'POST /api/employees/user-roles',
        'PUT /api/hrms/tracking/settings',
        'POST /api/hrms/payroll/generate',
        'PATCH /api/hrms/payroll/7',
        'PATCH /api/hrms/approvals/8',
        'GET /api/hrms/payslips/my/summary',
        'POST /api/hrms/payslips/7/request',
      ]);
      expect(jsonDecode(requests[0].body), {
        'roleName': 'Designer',
        'userType': 'employee',
      });
      expect(jsonDecode(requests[1].body)['officeRadiusMeters'], 150);
      expect(jsonDecode(requests[2].body), {'year': 2026, 'month': 10});
      expect(jsonDecode(requests[3].body), {
        'status': 'paid',
        'reviewedSettlement': false,
      });
      expect(jsonDecode(requests[4].body), {'status': 'approved'});
    },
  );
  test('payroll and approval clients surface backend failures', () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'wiring-test'});
    await http.runWithClient(
      () async {
        await expectLater(HrmsPayrollApi.markPaid(7), throwsException);
        await expectLater(
          HrmsApprovalsApi.review(8, 'Approved'),
          throwsException,
        );
      },
      () => MockClient(
        (_) async => http.Response(
          jsonEncode({
            'success': false,
            'message': 'Request cannot be processed',
          }),
          409,
        ),
      ),
    );
  });
}
