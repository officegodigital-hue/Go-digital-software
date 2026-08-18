import 'package:flutter/material.dart';

import '../../data/models/admin_permission_model.dart';
import '../controllers/admin_permission_controller.dart';

class AdminPermissionScreen extends StatefulWidget {
  const AdminPermissionScreen({super.key});

  @override
  State<AdminPermissionScreen> createState() => _AdminPermissionScreenState();
}

class _AdminPermissionScreenState extends State<AdminPermissionScreen> {
  late final AdminPermissionController _controller;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _controller = AdminPermissionController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.initialize();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF7F8FC),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildFilterBar(),
                  const SizedBox(height: 16),
                  _buildMessages(),
                  Expanded(
                    child: LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            if (constraints.maxWidth < 1120) {
                              return _buildMobileLayout();
                            }

                            return _buildDesktopLayout();
                          },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Permission Management',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E2027),
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Review and approve administrative overrides for employee attendance.',
                style: TextStyle(fontSize: 13, color: Color(0xFF777B86)),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: _controller.refresh,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Refresh'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF164FA7),
            side: const BorderSide(color: Color(0xFFD7DEEA)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 280,
          child: TextField(
            controller: _searchController,
            onChanged: _controller.updateSearchQuery,
            decoration: InputDecoration(
              hintText: 'Search employee or request...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFDDE3EC)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFDDE3EC)),
              ),
            ),
          ),
        ),
        _buildDropdown(
          value: _controller.selectedType,
          width: 180,
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem<String>(value: '', child: Text('All Types')),
            DropdownMenuItem<String>(
              value: 'leave_request',
              child: Text('Leave Request'),
            ),
            DropdownMenuItem<String>(
              value: 'late_login',
              child: Text('Late Login'),
            ),
            DropdownMenuItem<String>(
              value: 'early_logout',
              child: Text('Early Logout'),
            ),
          ],
          onChanged: (String? value) {
            if (value != null) {
              _controller.updateTypeFilter(value);
            }
          },
        ),
        _buildDropdown(
          value: _controller.selectedStatus,
          width: 160,
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem<String>(value: 'pending', child: Text('Pending')),
            DropdownMenuItem<String>(
              value: 'approved',
              child: Text('Approved'),
            ),
            DropdownMenuItem<String>(
              value: 'rejected',
              child: Text('Rejected'),
            ),
            DropdownMenuItem<String>(
              value: 'cancelled',
              child: Text('Cancelled'),
            ),
          ],
          onChanged: (String? value) {
            if (value != null) {
              _controller.updateStatusFilter(value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String value,
    required double width,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        items: items,
        onChanged: onChanged,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDDE3EC)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDDE3EC)),
          ),
        ),
      ),
    );
  }

  Widget _buildMessages() {
    final String? error = _controller.errorMessage;

    final String? success = _controller.successMessage;

    if (error == null && success == null) {
      return const SizedBox.shrink();
    }

    final bool isError = error != null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFF1F1) : const Color(0xFFEFFAF3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError ? const Color(0xFFF4B9B9) : const Color(0xFFA7DDB8),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline,
            color: isError ? const Color(0xFFC62828) : const Color(0xFF218A45),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error ?? success ?? '',
              style: TextStyle(
                color: isError
                    ? const Color(0xFFC62828)
                    : const Color(0xFF218A45),
              ),
            ),
          ),
          IconButton(
            onPressed: _controller.clearMessages,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(flex: 8, child: _buildPermissionPanel()),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: SingleChildScrollView(child: _buildSummarySection()),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return ListView(
      children: <Widget>[
        _buildSummarySection(),
        const SizedBox(height: 16),
        SizedBox(height: 620, child: _buildPermissionPanel()),
      ],
    );
  }

  Widget _buildPermissionPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDDE3EC)),
      ),
      child: Column(
        children: <Widget>[
          _buildPanelHeader(),
          const Divider(height: 1),
          Expanded(child: _buildPermissionContent()),
          const Divider(height: 1),
          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildPanelHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      child: Row(
        children: <Widget>[
          Text(
            '${_controller.selectedStatusLabel} Permissions',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Color(0xFF25314A),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_controller.pagination.total}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          const Icon(Icons.more_horiz_rounded, color: Color(0xFF6F7787)),
        ],
      ),
    );
  }

  Widget _buildPermissionContent() {
    if (_controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_controller.hasPermissions) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.inbox_outlined, size: 48, color: Color(0xFFABB2BF)),
            SizedBox(height: 12),
            Text(
              'No permission requests found.',
              style: TextStyle(color: Color(0xFF7D8492)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _controller.permissions.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (BuildContext context, int index) {
        return _buildPermissionRow(_controller.permissions[index]);
      },
    );
  }

  Widget _buildPermissionRow(AdminPermissionModel permission) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: <Widget>[
          _buildAvatar(permission),
          const SizedBox(width: 12),
          SizedBox(
            width: 145,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  permission.employeeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF24304A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  permission.employeeRole ?? permission.designationName ?? '-',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF777F90),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      _requestIcon(permission),
                      size: 14,
                      color: _requestColor(permission),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        permission.requestTitle,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _requestColor(permission),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  _buildRequestDetail(permission),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF737B8B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'REASON',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 0.5,
                    color: Color(0xFF949AA6),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  permission.reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF3D4555),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildActions(permission),
        ],
      ),
    );
  }

  Widget _buildAvatar(AdminPermissionModel permission) {
    final String? imageUrl = permission.profileImageUrl;

    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      return CircleAvatar(radius: 20, backgroundImage: NetworkImage(imageUrl));
    }

    final String initial = permission.employeeName.isNotEmpty
        ? permission.employeeName[0].toUpperCase()
        : 'E';

    return CircleAvatar(
      radius: 20,
      backgroundColor: const Color(0xFFE7EEF9),
      child: Text(
        initial,
        style: const TextStyle(
          color: Color(0xFF164FA7),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildActions(AdminPermissionModel permission) {
    if (!permission.isPending) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _statusColor(permission).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          permission.statusLabel,
          style: TextStyle(
            color: _statusColor(permission),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        OutlinedButton(
          onPressed: _controller.isUpdatingStatus
              ? null
              : () => _showRejectDialog(permission),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFE53935),
            side: const BorderSide(color: Color(0xFFE53935)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          ),
          child: const Text('Reject', style: TextStyle(fontSize: 11)),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _controller.isUpdatingStatus
              ? null
              : () => _showApproveDialog(permission),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0B4EB3),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          child: const Text('Approve', style: TextStyle(fontSize: 11)),
        ),  
      ],
    );
  }

  Widget _buildPagination() {
    final AdminPermissionPagination pagination = _controller.pagination;

    final int start = pagination.total == 0
        ? 0
        : ((pagination.page - 1) * pagination.limit) + 1;

    final int end = pagination.total == 0
        ? 0
        : (pagination.page * pagination.limit).clamp(0, pagination.total);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          Text(
            'Showing $start to $end of ${pagination.total} requests',
            style: const TextStyle(fontSize: 11, color: Color(0xFF747B88)),
          ),
          const Spacer(),
          IconButton(
            onPressed: _controller.hasPreviousPage
                ? _controller.goToPreviousPage
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Text(
            '${pagination.page} / ${pagination.totalPages}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
          IconButton(
            onPressed: _controller.hasNextPage
                ? _controller.goToNextPage
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    final AdminPermissionSummary summary = _controller.summary;

    return Column(
      children: <Widget>[
        _buildSummaryCard(
          title: 'LATE LOGINS',
          count: summary.pendingLateLogins,
          icon: Icons.schedule_rounded,
          color: const Color(0xFF8D2D00),
        ),
        const SizedBox(height: 10),
        _buildSummaryCard(
          title: 'LEAVE REQUEST',
          count: summary.pendingLeaveRequests,
          icon: Icons.event_busy_outlined,
          color: const Color(0xFFC51F27),
        ),
        const SizedBox(height: 10),
        _buildSummaryCard(
          title: 'EARLY LOGOUT REQUEST',
          count: summary.pendingEarlyLogoutRequests,
          icon: Icons.logout_rounded,
          color: const Color(0xFF4C505C),
        ),
        const SizedBox(height: 16),
        _buildAutomationCard(),
        const SizedBox(height: 16),
        _buildGuidelinesCard(),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            width: 38,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutomationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B4EB3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Automate Common Approvals',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Setup rules to automatically approve requests that meet your company policy criteria.',
            style: TextStyle(
              color: Color(0xFFD6E3FA),
              fontSize: 11,
              height: 1.4,
            ),
          ),
          SizedBox(height: 15),
          FilledButton(onPressed: null, child: Text('Configure Smart-Rules')),
        ],
      ),
    );
  }

  Widget _buildGuidelinesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E63D8)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.info_outline, color: Color(0xFF1E63D8), size: 20),
              SizedBox(width: 9),
              Text(
                'Administrative Guidelines',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
          SizedBox(height: 13),
          Text(
            '• Approve leave requests at least 48h in advance.',
            style: TextStyle(fontSize: 10, color: Color(0xFF565E6C)),
          ),
          SizedBox(height: 7),
          Text(
            '• Verify medical certificates for early exits over 2h.',
            style: TextStyle(fontSize: 10, color: Color(0xFF565E6C)),
          ),
          SizedBox(height: 7),
          Text(
            '• Late logins under 15m can be auto-cleared.',
            style: TextStyle(fontSize: 10, color: Color(0xFF565E6C)),
          ),
        ],
      ),
    );
  }

  Future<void> _showApproveDialog(AdminPermissionModel permission) async {
    final TextEditingController remarks = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Approve Permission'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Approve ${permission.requestTitle} for ${permission.employeeName}?',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: remarks,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Admin remarks (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Approve'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _controller.approvePermission(
        permissionId: permission.id,
        adminRemarks: remarks.text,
      );
    }

    remarks.dispose();
  }

  Future<void> _showRejectDialog(AdminPermissionModel permission) async {
    final TextEditingController remarks = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Reject Permission'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Reject ${permission.requestTitle} for ${permission.employeeName}?',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: remarks,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Rejection reason',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC62828),
              ),
              onPressed: () {
                if (remarks.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a rejection reason.'),
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext, true);
              },
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _controller.rejectPermission(
        permissionId: permission.id,
        adminRemarks: remarks.text,
      );
    }

    remarks.dispose();
  }

  IconData _requestIcon(AdminPermissionModel permission) {
    if (permission.isLeaveRequest) {
      return Icons.flight_takeoff_rounded;
    }

    if (permission.isLateLogin) {
      return Icons.schedule_rounded;
    }

    return Icons.logout_rounded;
  }

  Color _requestColor(AdminPermissionModel permission) {
    if (permission.isLeaveRequest) {
      return const Color(0xFF1B5EBE);
    }

    if (permission.isLateLogin) {
      return const Color(0xFFE43D3D);
    }

    return const Color(0xFF667085);
  }

  Color _statusColor(AdminPermissionModel permission) {
    if (permission.isApproved) {
      return const Color(0xFF208943);
    }

    if (permission.isRejected) {
      return const Color(0xFFC62828);
    }

    if (permission.isCancelled) {
      return const Color(0xFF757575);
    }

    return const Color(0xFFB26A00);
  }

  String _buildRequestDetail(AdminPermissionModel permission) {
    if (permission.isLeaveRequest) {
      final String start = _formatDate(permission.startDate);

      final String end = _formatDate(permission.endDate);

      final String days = permission.totalDays == null
          ? ''
          : ' (${permission.totalDays!.toStringAsFixed(0)} Days)';

      return '$start - $end$days';
    }

    final String requested = permission.requestedTime ?? '-';

    final String actual = permission.actualTime ?? '-';

    return 'Requested $requested • Actual $actual';
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '-';
    }

    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[date.month - 1]} '
        '${date.day}, ${date.year}';
  }
}

extension on AdminPermissionController {
  String get selectedStatusLabel {
    final String value = selectedStatus;

    if (value.isEmpty) {
      return 'All';
    }

    return '${value[0].toUpperCase()}'
        '${value.substring(1)}';
  }
}