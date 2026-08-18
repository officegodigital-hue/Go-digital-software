import 'package:flutter/material.dart';

class LeaveStatusChip extends StatelessWidget {
  const LeaveStatusChip({
    required this.status,
    super.key,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    final statusStyle = _getStatusStyle(
      status,
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: statusStyle.backgroundColor,
        borderRadius: BorderRadius.circular(
          30,
        ),
        border: Border.all(
          color: statusStyle.borderColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: statusStyle.textColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            statusStyle.label,
            style: TextStyle(
              color: statusStyle.textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  _LeaveStatusStyle _getStatusStyle(
    String value,
  ) {
    switch (value.trim().toLowerCase()) {
      case 'approved':
        return const _LeaveStatusStyle(
          label: 'Approved',
          backgroundColor: Color(
            0xFFE8F5E9,
          ),
          borderColor: Color(
            0xFFA5D6A7,
          ),
          textColor: Color(
            0xFF1B5E20,
          ),
        );

      case 'rejected':
        return const _LeaveStatusStyle(
          label: 'Rejected',
          backgroundColor: Color(
            0xFFFFEBEE,
          ),
          borderColor: Color(
            0xFFEF9A9A,
          ),
          textColor: Color(
            0xFFB71C1C,
          ),
        );

      case 'cancelled':
        return const _LeaveStatusStyle(
          label: 'Cancelled',
          backgroundColor: Color(
            0xFFF1F3F4,
          ),
          borderColor: Color(
            0xFFCFD8DC,
          ),
          textColor: Color(
            0xFF455A64,
          ),
        );

      case 'pending':
      default:
        return const _LeaveStatusStyle(
          label: 'Pending',
          backgroundColor: Color(
            0xFFFFF8E1,
          ),
          borderColor: Color(
            0xFFFFCC80,
          ),
          textColor: Color(
            0xFFE65100,
          ),
        );
    }
  }
}

class _LeaveStatusStyle {
  const _LeaveStatusStyle({
    required this.label,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
}