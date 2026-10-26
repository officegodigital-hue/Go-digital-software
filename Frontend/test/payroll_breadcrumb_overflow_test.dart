import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godigital_portal/hrms_admin/shared/widgets/admin_top_nav.dart';

void main() {
  testWidgets('Payroll breadcrumb fits without moving or resizing Generate', (tester) async {
    tester.view.physicalSize = const Size(700, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Widget header(bool fit) => MaterialApp(home: Scaffold(body: Row(children: [
      SizedBox(width: 130, child: AdminPageHeader(title: 'Payroll', fitBreadcrumb: fit)),
      FilledButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.playlist_add_check_rounded),
        label: const Text('Generate month-end draft'),
      ),
    ])));
    await tester.pumpWidget(header(false));
    expect(tester.takeException(), isA<FlutterError>());
    final before = tester.getRect(find.byWidgetPredicate((w) => w is FilledButton));
    await tester.pumpWidget(header(true));
    expect(tester.takeException(), isNull);
    expect(tester.getRect(find.byWidgetPredicate((w) => w is FilledButton)), before);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Payroll'), findsNWidgets(2));
  });
}
