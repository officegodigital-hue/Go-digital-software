class LeaveDashboardResponse {
  const LeaveDashboardResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  final bool success;
  final String message;
  final LeaveDashboardData data;

  factory LeaveDashboardResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return LeaveDashboardResponse(
      success: _toBool(json['success']),
      message: _toText(json['message']),
      data: LeaveDashboardData.fromJson(
        _toMap(json['data']),
      ),
    );
  }
}

class LeaveDashboardData {
  const LeaveDashboardData({
    required this.employee,
    required this.year,
    required this.requestSummary,
    required this.balances,
  });

  final LeaveEmployee employee;
  final int year;
  final LeaveRequestSummary requestSummary;
  final List<LeaveBalance> balances;

  factory LeaveDashboardData.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawBalances = json['balances'];

    return LeaveDashboardData(
      employee: LeaveEmployee.fromJson(
        _toMap(json['employee']),
      ),
      year: _toInt(json['year']),
      requestSummary:
          LeaveRequestSummary.fromJson(
        _toMap(json['request_summary']),
      ),
      balances: rawBalances is List
          ? rawBalances
              .whereType<Map>()
              .map(
                (item) => LeaveBalance.fromJson(
                  Map<String, dynamic>.from(
                    item,
                  ),
                ),
              )
              .toList()
          : const <LeaveBalance>[],
    );
  }
}

class LeaveEmployee {
  const LeaveEmployee({
    required this.employeeId,
    required this.employeeCode,
    required this.name,
    required this.companyName,
    required this.branchName,
    required this.timezone,
  });

  final int employeeId;
  final String employeeCode;
  final String name;
  final String companyName;
  final String branchName;
  final String timezone;

  factory LeaveEmployee.fromJson(
    Map<String, dynamic> json,
  ) {
    return LeaveEmployee(
      employeeId: _toInt(
        json['employee_id'],
      ),
      employeeCode: _toText(
        json['employee_code'],
      ),
      name: _toText(
        json['name'],
      ),
      companyName: _toText(
        json['company_name'],
      ),
      branchName: _toText(
        json['branch_name'],
      ),
      timezone: _toText(
        json['timezone'],
      ),
    );
  }
}

class LeaveRequestSummary {
  const LeaveRequestSummary({
    required this.totalRequests,
    required this.pendingRequests,
    required this.approvedRequests,
    required this.rejectedRequests,
    required this.cancelledRequests,
  });

  final int totalRequests;
  final int pendingRequests;
  final int approvedRequests;
  final int rejectedRequests;
  final int cancelledRequests;

  factory LeaveRequestSummary.fromJson(
    Map<String, dynamic> json,
  ) {
    return LeaveRequestSummary(
      totalRequests: _toInt(
        json['total_requests'],
      ),
      pendingRequests: _toInt(
        json['pending_requests'],
      ),
      approvedRequests: _toInt(
        json['approved_requests'],
      ),
      rejectedRequests: _toInt(
        json['rejected_requests'],
      ),
      cancelledRequests: _toInt(
        json['cancelled_requests'],
      ),
    );
  }
}

class LeaveBalance {
  const LeaveBalance({
    required this.leaveTypeId,
    required this.name,
    required this.code,
    required this.annualQuota,
    required this.isPaid,
    required this.requiresAttachment,
    required this.maxConsecutiveDays,
    required this.balanceYear,
    required this.openingBalance,
    required this.allocatedDays,
    required this.carriedForwardDays,
    required this.totalAllocated,
    required this.usedDays,
    required this.pendingDays,
    required this.availableDays,
  });

  final int leaveTypeId;
  final String name;
  final String code;

  final double annualQuota;

  final bool isPaid;
  final bool requiresAttachment;

  final int? maxConsecutiveDays;

  final int balanceYear;

  final double openingBalance;
  final double allocatedDays;
  final double carriedForwardDays;
  final double totalAllocated;
  final double usedDays;
  final double pendingDays;
  final double availableDays;

  factory LeaveBalance.fromJson(
    Map<String, dynamic> json,
  ) {
    return LeaveBalance(
      leaveTypeId: _toInt(
        json['leave_type_id'],
      ),
      name: _toText(
        json['name'],
      ),
      code: _toText(
        json['code'],
      ),
      annualQuota: _toDouble(
        json['annual_quota'],
      ),
      isPaid: _toBool(
        json['is_paid'],
      ),
      requiresAttachment: _toBool(
        json['requires_attachment'],
      ),
      maxConsecutiveDays:
          _toNullableInt(
        json['max_consecutive_days'],
      ),
      balanceYear: _toInt(
        json['balance_year'],
      ),
      openingBalance: _toDouble(
        json['opening_balance'],
      ),
      allocatedDays: _toDouble(
        json['allocated_days'],
      ),
      carriedForwardDays: _toDouble(
        json['carried_forward_days'],
      ),
      totalAllocated: _toDouble(
        json['total_allocated'],
      ),
      usedDays: _toDouble(
        json['used_days'],
      ),
      pendingDays: _toDouble(
        json['pending_days'],
      ),
      availableDays: _toDouble(
        json['available_days'],
      ),
    );
  }

  double get consumedDays {
    return usedDays + pendingDays;
  }

  double get usageProgress {
    if (totalAllocated <= 0) {
      return 0;
    }

    final progress =
        consumedDays / totalAllocated;

    return progress
        .clamp(0.0, 1.0)
        .toDouble();
  }

  bool get hasAvailableBalance {
    return availableDays > 0;
  }

  String get paymentLabel {
    return isPaid
        ? 'Paid Leave'
        : 'Unpaid Leave';
  }
}

Map<String, dynamic> _toMap(
  dynamic value,
) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return Map<String, dynamic>.from(
      value,
    );
  }

  return <String, dynamic>{};
}

String _toText(
  dynamic value,
) {
  if (value == null) {
    return '';
  }

  return value.toString();
}

int _toInt(
  dynamic value,
) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(
        value?.toString() ?? '',
      ) ??
      0;
}

int? _toNullableInt(
  dynamic value,
) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(
    value.toString(),
  );
}

double _toDouble(
  dynamic value,
) {
  if (value is double) {
    return value;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(
        value?.toString() ?? '',
      ) ??
      0;
}

bool _toBool(
  dynamic value,
) {
  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  final normalized =
      value?.toString().toLowerCase();

  return normalized == 'true' ||
      normalized == '1';
}