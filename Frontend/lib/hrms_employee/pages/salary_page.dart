import 'package:flutter/material.dart';

import '../shared/employee_ui.dart';

class EmployeeSalaryPage extends StatelessWidget {
  const EmployeeSalaryPage({super.key});

  @override
  Widget build(BuildContext context) => const EmployeeScaffold(
        route: '/employee/salary',
        title: 'Salary',
        subtitle: 'Payslips and salary details',
        desktop: _SalaryView(mobile: false, showPayslip: true),
        mobile: _SalaryView(mobile: true, showPayslip: true),
      );
}

class _SalaryView extends StatelessWidget {
  const _SalaryView({required this.mobile, required this.showPayslip});
  final bool mobile;
  final bool showPayslip;

  static void openPayslipSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(22, 4, 22, 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Icon(Icons.description_outlined, color: employeeBlue),
              SizedBox(width: 10),
              Text('July 2026 Payslip',
                  style: TextStyle(
                      color: employeeNavy,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
            ]),
            SizedBox(height: 18),
            LabeledValue('Gross Salary', '₹54,000'),
            Divider(height: 1, color: employeeLine),
            LabeledValue('PF & Tax', '−₹16,154'),
            Divider(height: 1, color: employeeLine),
            LabeledValue('Net Pay', '₹37,846', valueColor: employeeBlue),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewButton =
        _ViewPayslipButton(
          onPressed: () => _SalaryView.openPayslipSheet(context),
        );

    if (mobile) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const MobileEmployeeHeader(showGreeting: false),
        const SizedBox(height: 22),
        const Text('Hello, Arul  👋',
            style: TextStyle(color: employeeMuted, fontSize: 18)),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Expanded(
            child: Text('Salary',
                style: TextStyle(
                    color: employeeNavy,
                    fontSize: 34,
                    height: 1,
                    fontWeight: FontWeight.w800)),
          ),
          viewButton,
        ]),
        const SizedBox(height: 18),
        const _NetPayBanner(mobile: true),
        const SizedBox(height: 16),
        const _SalaryOverviewCard(),
        const SizedBox(height: 16),
        const _SalaryBreakdownCard(),
        const SizedBox(height: 16),
        const _RecentPayslipsCard(),
        const SizedBox(height: 18),
        const Center(
          child: Text(
            'Payslips are available for download after payroll processing.',
            textAlign: TextAlign.center,
            style: TextStyle(color: employeeMuted, fontSize: 12),
          ),
        ),
      ]);
    }

    if (!showPayslip) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: const [
          Expanded(flex: 6, child: _NetPayBanner(mobile: false)),
          SizedBox(width: 20),
          Expanded(
            flex: 5,
            child: Column(children: [
              _SalaryOverviewCard(),
              SizedBox(height: 18),
              _SalaryBreakdownCard(),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 20),
      const _RecentPayslipsCard(),
      const SizedBox(height: 14),
      const Center(
        child: Text(
          'Payslips are available for download after payroll processing.',
          style: TextStyle(color: employeeMuted, fontSize: 12),
        ),
      ),
    ]);
  }
}

class _ViewPayslipButton extends StatelessWidget {
  const _ViewPayslipButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.description_outlined, size: 21),
        label: const Text('View Payslip',
            style: TextStyle(fontWeight: FontWeight.w700)),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF052D70),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
}

class _NetPayBanner extends StatelessWidget {
  const _NetPayBanner({required this.mobile});
  final bool mobile;

  @override
  Widget build(BuildContext context) => Container(
        constraints: BoxConstraints(minHeight: mobile ? 190 : 285),
        padding: EdgeInsets.all(mobile ? 22 : 34),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF063B82), Color(0xFF031C54)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26002061),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Net Pay',
                    style: TextStyle(
                        color: Colors.white, fontSize: mobile ? 18 : 22)),
                const SizedBox(height: 10),
                Text('₹37,846',
                    maxLines: 1,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: mobile ? 38 : 50,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('July 2026',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: mobile ? 18 : 21,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 13),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF005A43),
                    border: Border.all(color: const Color(0xFF008F63)),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    CircleAvatar(radius: 5, backgroundColor: Color(0xFF1DDA83)),
                    SizedBox(width: 8),
                    Text('PAID',
                        style: TextStyle(
                            color: Color(0xFF2DE38E),
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              ],
            ),
          ),
          SizedBox(width: mobile ? 8 : 24),
          _WalletArtwork(size: mobile ? 118 : 190),
        ]),
      );
}

class _WalletArtwork extends StatelessWidget {
  const _WalletArtwork({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0x1F61A8FF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x33489EFF)),
            ),
          ),
          Icon(Icons.account_balance_wallet_rounded,
              color: const Color(0xFF9DBDE8), size: size * .56),
          Positioned(
            top: size * .10,
            right: size * .30,
            child: _Coin(size: size * .27),
          ),
          Positioned(
            top: size * .38,
            right: size * .02,
            child: _Coin(size: size * .25),
          ),
        ]),
      );
}

class _Coin extends StatelessWidget {
  const _Coin({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF789FD3),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFAEC7E8)),
        ),
        child: Text('₹',
            style: TextStyle(
                color: const Color(0xFF315C98),
                fontSize: size * .48,
                fontWeight: FontWeight.w800)),
      );
}

class _SalaryOverviewCard extends StatelessWidget {
  const _SalaryOverviewCard();

  @override
  Widget build(BuildContext context) => const EmployeeCard(
        padding: EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SalaryHeading('Salary Overview'),
          SizedBox(height: 10),
          LabeledValue('Gross Salary', '₹54,000'),
          Divider(height: 1, color: employeeLine),
          LabeledValue('Total Deductions', '−₹16,154'),
          Divider(height: 1, color: employeeLine),
          LabeledValue('Net Pay', '₹37,846', valueColor: employeeBlue),
        ]),
      );
}

class _SalaryBreakdownCard extends StatelessWidget {
  const _SalaryBreakdownCard();

  @override
  Widget build(BuildContext context) => const EmployeeCard(
        padding: EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SalaryHeading('Salary Breakdown'),
          SizedBox(height: 10),
          LabeledValue('Basic Salary', '₹36,000'),
          LabeledValue('HRA', '₹12,000'),
          LabeledValue('Allowances', '₹6,000'),
          Divider(height: 1, color: employeeLine),
          LabeledValue('PF & Tax', '−₹16,154'),
        ]),
      );
}

class _SalaryHeading extends StatelessWidget {
  const _SalaryHeading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: employeeNavy, fontSize: 20, fontWeight: FontWeight.w800));
}

class _RecentPayslipsCard extends StatelessWidget {
  const _RecentPayslipsCard();

  @override
  Widget build(BuildContext context) => const EmployeeCard(
        padding: EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SalaryHeading('Recent Payslips'),
          SizedBox(height: 10),
          _PayslipRow('July 2026', 'Paid on 31 Jul 2026', '₹37,846'),
          Divider(color: employeeLine),
          _PayslipRow('June 2026', 'Paid on 30 Jun 2026', '₹37,420'),
          Divider(color: employeeLine),
          _PayslipRow('May 2026', 'Paid on 31 May 2026', '₹36,980'),
        ]),
      );
}

class _PayslipRow extends StatelessWidget {
  const _PayslipRow(this.month, this.date, this.value);
  final String month;
  final String date;
  final String value;

  void download(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$month payslip download started.')),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(month,
                  style: const TextStyle(
                      color: employeeNavy, fontWeight: FontWeight.w800)),
              Text(date,
                  style: const TextStyle(color: employeeMuted, fontSize: 12)),
            ]),
          ),
          Text(value,
              style: const TextStyle(
                  color: employeeNavy, fontWeight: FontWeight.w700)),
          const SizedBox(width: 7),
          IconButton(
            tooltip: 'Download $month payslip',
            onPressed: () => download(context),
            icon: const Icon(Icons.download_rounded, color: employeeBlue),
          ),
        ]),
      );
}
