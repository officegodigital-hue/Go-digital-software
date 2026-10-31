import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godigital_portal/hrms_admin/features/dashboard/widgets/attendance_grid.dart';

AttendanceRowData employee(int dayCount) => AttendanceRowData(
  name: 'Ravi Kumar',
  designation: 'Designer',
  days: List.generate(
    dayCount,
    (i) => AttendanceDayMark(['P', 'LT', 'A', 'OFF', 'H', 'H', '–'][i % 7]),
  ),
  present: 20,
  late: 2,
  excused: 0,
  unexcused: 20,
  halfLeave: 0,
  earnedLeave: 0,
  approvedLeave: 1,
  salaryPerMonth: '₹50,000',
  salaryPerDay: '₹2,083.33',
  totalSalaryAfterLeaves: '₹43,750',
  deductedDays: 21,
  updatedSalary: '₹6,250',
  creditedDays: 3,
);

Widget table(
  double width,
  int dayCount,
  ScrollController body,
  ScrollController header,
) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        height: 400,
        child: CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: AttendanceHeaderDelegate(
                days: List.generate(dayCount, (i) => i + 8),
                dayLabels: List.filled(dayCount, 'Mon'),
                showSummary: true,
                horizontalController: header,
              ),
            ),
            SliverToBoxAdapter(
              child: AttendanceGrid(
                days: List.generate(dayCount, (i) => i + 8),
                dayLabels: List.filled(dayCount, 'Mon'),
                rows: [employee(dayCount)],
                showHeader: false,
                horizontalController: body,
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  for (final width in [1920.0, 1600.0, 1472.0, 1366.0, 1280.0]) {
    for (final dayCount in [3, 7]) {
      testWidgets('$dayCount days and salary columns fit $width px', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final body = ScrollController();
        final header = ScrollController();
        addTearDown(body.dispose);
        addTearDown(header.dispose);
        await tester.pumpWidget(table(width, dayCount, body, header));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(body.position.maxScrollExtent, closeTo(0, .01));
        expect(header.position.maxScrollExtent, closeTo(0, .01));
        expect(find.text('21 days'), findsOneWidget);
        expect(find.text('3 days credited'), findsOneWidget);
        expect(
          tester.getCenter(find.text('3 days credited')).dy,
          greaterThan(tester.getCenter(find.text('₹6,250')).dy),
        );
        expect(
          tester.getCenter(find.text('21 days')).dy,
          greaterThan(tester.getCenter(find.text('₹43,750')).dy),
        );
        for (var day = 8; day < 8 + dayCount; day++) {
          final dateCell = find
              .ancestor(of: find.text('$day'), matching: find.byType(Container))
              .first;
          expect(tester.getSize(dateCell).width, greaterThanOrEqualTo(56));
        }
        for (final pair in [
          ['Salary / Month', '₹50,000'],
          ['Per Day Salary', '₹2,083.33'],
          ['Deduction', '₹43,750'],
          ['Updated Salary', '₹6,250'],
        ]) {
          final heading = tester.getCenter(find.text(pair.first));
          final value = tester.getCenter(find.text(pair.last));
          expect(heading.dx, closeTo(value.dx, .01));
          expect(
            tester.getRect(find.text(pair.last)).right,
            lessThanOrEqualTo(width),
          );
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('Narrow table keeps header aligned when moving to final salary', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final body = ScrollController();
    final header = ScrollController();
    addTearDown(body.dispose);
    addTearDown(header.dispose);
    body.addListener(() {
      if (header.hasClients) header.jumpTo(body.offset);
    });
    await tester.pumpWidget(table(900, 7, body, header));
    await tester.pumpAndSettle();
    body.jumpTo(body.position.maxScrollExtent);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(body.position.maxScrollExtent, greaterThan(0));
    expect(header.offset, closeTo(body.offset, .01));
    expect(
      tester.getCenter(find.text('Updated Salary')).dx,
      closeTo(tester.getCenter(find.text('₹6,250')).dx, .01),
    );
    expect(tester.getRect(find.text('₹6,250')).right, lessThanOrEqualTo(900));
    await tester.pumpWidget(const SizedBox());
  });
}
