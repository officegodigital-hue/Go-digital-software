import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/admin_text_styles.dart';
import '../../data/models/company_employee.dart';
import '../controllers/company_employee_controller.dart';
import '../widgets/company_employee_form_dialog.dart';

class CompanyEmployeeManagementScreen extends StatefulWidget {
  const CompanyEmployeeManagementScreen({
    this.onAddEmployee,
    this.onEditEmployee,
    super.key,
  });

  final VoidCallback? onAddEmployee;
  final ValueChanged<CompanyEmployee>? onEditEmployee;

  @override
  State<CompanyEmployeeManagementScreen> createState() {
    return _CompanyEmployeeManagementScreenState();
  }
}

class _CompanyEmployeeManagementScreenState
    extends State<CompanyEmployeeManagementScreen> {
  late final CompanyEmployeeController _controller;
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;
  bool _isExporting = false;
  String? _lastDisplayedMessage;

  @override
  void initState() {
    super.initState();

    _controller = CompanyEmployeeController();
    _controller.addListener(_handleControllerChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.initialize();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();

    _controller
      ..removeListener(_handleControllerChanged)
      ..dispose();

    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});

    final String? errorMessage = _controller.errorMessage?.trim();
    final String? successMessage = _controller.successMessage?.trim();

    final String? message = errorMessage?.isNotEmpty == true
        ? errorMessage
        : successMessage?.isNotEmpty == true
        ? successMessage
        : null;

    if (message == null || message == _lastDisplayedMessage) {
      return;
    }

    _lastDisplayedMessage = message;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: errorMessage?.isNotEmpty == true
                ? AdminColors.danger
                : AdminColors.navy,
            content: Text(message),
          ),
        );

      _controller.clearMessages(notify: false);
    });
  }

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      _controller.searchEmployees(value.trim());
    });
  }

  Future<void> _clearSearch() async {
    _searchDebounce?.cancel();
    _searchController.clear();
    await _controller.clearSearch();
  }

  Future<void> _handleAddEmployee() async {
    if (widget.onAddEmployee != null) {
      widget.onAddEmployee!();
      return;
    }

    final CompanyEmployee? savedEmployee = await showCompanyEmployeeFormDialog(
      context: context,
      controller: _controller,
    );

    if (!mounted || savedEmployee == null) {
      return;
    }

    await _controller.refreshEmployees();
  }

  Future<void> _handleEditEmployee(CompanyEmployee employee) async {
    if (widget.onEditEmployee != null) {
      widget.onEditEmployee!(employee);
      return;
    }

    CompanyEmployee employeeToEdit = employee;
    final int? employeeId = employee.employeeId;

    if (employeeId != null && employeeId > 0) {
      final CompanyEmployee? employeeDetails = await _controller
          .loadEmployeeDetails(employeeId);

      if (!mounted) {
        return;
      }

      if (employeeDetails != null) {
        employeeToEdit = employeeDetails;
      }
    }

    final CompanyEmployee? updatedEmployee =
        await showCompanyEmployeeFormDialog(
          context: context,
          controller: _controller,
          employee: employeeToEdit,
        );

    if (!mounted || updatedEmployee == null) {
      return;
    }

    await _controller.refreshEmployees();
  }

  Future<void> _deleteEmployee(CompanyEmployee employee) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: <Widget>[
              CircleAvatar(
                backgroundColor: AdminColors.dangerBackground,
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: AdminColors.danger,
                ),
              ),
              SizedBox(width: 12),
              Expanded(child: Text('Delete Employee')),
            ],
          ),
          content: SizedBox(
            width: 430,
            child: Text(
              'Delete ${employee.displayName}? '
              'This action cannot be undone.',
            ),
          ),
          actions: <Widget>[
            OutlinedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AdminColors.danger,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              label: const Text('Delete Employee'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await _controller.deleteEmployee(employee);
  }

  Future<void> _exportEmployees() async {
    if (_isExporting || _controller.employees.isEmpty) {
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      final String csv = <String>[
        'Employee Code,Employee Name,Role,Email,Mobile,'
            'Company,Branch,Shift,Username,Status',
        ..._controller.employees.map((CompanyEmployee employee) {
          return <String>[
            _csv(_EmployeeFields.employeeCode(employee)),
            _csv(employee.displayName),
            _csv(_EmployeeFields.role(employee)),
            _csv(employee.email),
            _csv(employee.phone),
            _csv(_EmployeeFields.companyName(employee)),
            _csv(_EmployeeFields.branchName(employee)),
            _csv(_EmployeeFields.shiftName(employee)),
            _csv(employee.username),
            _csv(employee.isActive ? 'Active' : 'Inactive'),
          ].join(',');
        }),
      ].join('\n');

      await Clipboard.setData(ClipboardData(text: csv));

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Employee CSV copied to clipboard.'),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  String _csv(String value) {
    final String escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _PageHeader(
              compact: constraints.maxWidth < 760,
              totalEmployees: _controller.totalItems,
              isExporting: _isExporting,
              onRefresh: _controller.refreshEmployees,
              onExport: _exportEmployees,
              onAddEmployee: _handleAddEmployee,
            ),
            const SizedBox(height: 16),
            _SummaryCards(employees: _controller.employees),
            const SizedBox(height: 14),
            _SearchBar(
              controller: _searchController,
              onChanged: _handleSearchChanged,
              onClear: _clearSearch,
            ),
            const SizedBox(height: 14),
            Expanded(child: _buildEmployeeContent()),
          ],
        );
      },
    );
  }

  Widget _buildEmployeeContent() {
    if (_controller.isLoading && _controller.employees.isEmpty) {
      return const _LoadingState();
    }

    if (_controller.hasError && _controller.employees.isEmpty) {
      return _ErrorState(
        message: _controller.errorMessage ?? 'Unable to load employees.',
        onRetry: _controller.loadEmployees,
      );
    }

    if (_controller.employees.isEmpty) {
      return _EmptyState(
        searchText: _searchController.text.trim(),
        onClearSearch: _clearSearch,
        onAddEmployee: _handleAddEmployee,
      );
    }

    return Column(
      children: <Widget>[
        const _EmployeeListHeader(),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: _controller.employees.length,
            separatorBuilder: (BuildContext context, int index) {
              return const SizedBox(height: 9);
            },
            itemBuilder: (BuildContext context, int index) {
              final CompanyEmployee employee = _controller.employees[index];

              return _EmployeeListItem(
                employee: employee,
                isBusy: _controller.isEmployeeBusy(employee.employeeId),
                onEdit: () {
                  _handleEditEmployee(employee);
                },
                onDelete: () {
                  _deleteEmployee(employee);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        _PaginationBar(
          currentPage: _controller.currentPage,
          totalPages: _controller.totalPages,
          totalItems: _controller.totalItems,
          hasPreviousPage: _controller.hasPreviousPage,
          hasNextPage: _controller.hasNextPage,
          isLoading: _controller.isLoading,
          onPrevious: _controller.goToPreviousPage,
          onNext: _controller.goToNextPage,
        ),
      ],
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.compact,
    required this.totalEmployees,
    required this.isExporting,
    required this.onRefresh,
    required this.onExport,
    required this.onAddEmployee,
  });

  final bool compact;
  final int totalEmployees;
  final bool isExporting;
  final VoidCallback onRefresh;
  final VoidCallback onExport;
  final VoidCallback onAddEmployee;

  @override
  Widget build(BuildContext context) {
    final Widget title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Employee Management', style: AdminTextStyles.pageTitle),
        const SizedBox(height: 4),
        Text(
          'Manage GoDigital employees, work roles and mobile app access. '
          '$totalEmployees employee records.',
          style: AdminTextStyles.pageSubtitle,
        ),
      ],
    );

    final Widget actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded, size: 17),
          label: const Text('Refresh'),
        ),
        OutlinedButton.icon(
          onPressed: isExporting ? null : onExport,
          icon: isExporting
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_rounded, size: 17),
          label: Text(isExporting ? 'Exporting' : 'Export'),
        ),
        FilledButton.icon(
          onPressed: onAddEmployee,
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
          label: const Text('Add Employee'),
        ),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[title, const SizedBox(height: 12), actions],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: title),
        const SizedBox(width: 14),
        actions,
      ],
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.employees});

  final List<CompanyEmployee> employees;

  @override
  Widget build(BuildContext context) {
    final int activeCount = employees.where((CompanyEmployee employee) {
      return employee.isActive;
    }).length;

    final int inactiveCount = employees.length - activeCount;

    final int loginCount = employees.where((CompanyEmployee employee) {
      return employee.username.trim().isNotEmpty && employee.isLoginEnabled;
    }).length;

    final List<_SummaryData> items = <_SummaryData>[
      _SummaryData(
        label: 'CURRENT RECORDS',
        value: employees.length.toString(),
        icon: Icons.groups_rounded,
        color: AdminColors.primary,
        background: AdminColors.primaryLight,
      ),
      _SummaryData(
        label: 'ACTIVE',
        value: activeCount.toString(),
        icon: Icons.check_circle_outline_rounded,
        color: AdminColors.success,
        background: AdminColors.successBackground,
      ),
      _SummaryData(
        label: 'INACTIVE',
        value: inactiveCount.toString(),
        icon: Icons.person_off_outlined,
        color: AdminColors.danger,
        background: AdminColors.dangerBackground,
      ),
      _SummaryData(
        label: 'MOBILE LOGIN',
        value: loginCount.toString(),
        icon: Icons.phone_android_rounded,
        color: AdminColors.info,
        background: AdminColors.infoBackground,
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 850
            ? 4
            : constraints.maxWidth >= 460
            ? 2
            : 1;

        const double gap = 10;
        final double width =
            (constraints.maxWidth - ((columns - 1) * gap)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items.map((_SummaryData item) {
            return SizedBox(
              width: width,
              child: Container(
                height: 78,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AdminColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AdminColors.border),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: item.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(item.icon, color: item.color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.value,
                            style: TextStyle(
                              color: item.color,
                              fontSize: 21,
                              height: 1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AdminTextStyles.tableCaption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AdminColors.border),
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (BuildContext context, TextEditingValue value, Widget? child) {
          return TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText:
                  'Search employee name, code, role, email, mobile or username...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: value.text.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: onClear,
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _EmployeeListHeader extends StatelessWidget {
  const _EmployeeListHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AdminColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AdminColors.border),
      ),
      child: const Row(
        children: <Widget>[
          Icon(Icons.people_alt_outlined, color: AdminColors.primary, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'SAVED EMPLOYEE DETAILS',
              style: AdminTextStyles.tableHeader,
            ),
          ),
          Text('EDIT / DELETE', style: AdminTextStyles.tableHeader),
        ],
      ),
    );
  }
}

class _EmployeeListItem extends StatelessWidget {
  const _EmployeeListItem({
    required this.employee,
    required this.isBusy,
    required this.onEdit,
    required this.onDelete,
  });

  final CompanyEmployee employee;
  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 860;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AdminColors.surface,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: AdminColors.border),
          ),
          child: compact ? _buildCompactLayout() : _buildWideLayout(),
        );
      },
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: <Widget>[
        SizedBox(width: 235, child: _EmployeeIdentity(employee: employee)),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _DetailBlock(
            label: 'ROLE',
            value: _EmployeeFields.role(employee),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: _DetailBlock(
            label: 'CONTACT',
            value: employee.email.trim(),
            secondary: employee.phone.trim(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: _DetailBlock(
            label: 'COMPANY / SHIFT',
            value:
                '${_EmployeeFields.companyName(employee)} / '
                '${_EmployeeFields.branchName(employee)}',
            secondary: _EmployeeFields.shiftName(employee),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _DetailBlock(
            label: 'MOBILE LOGIN',
            value: employee.username.trim().isEmpty
                ? 'Not Created'
                : employee.username.trim(),
            secondary: employee.isLoginEnabled
                ? 'Login Enabled'
                : 'Login Disabled',
          ),
        ),
        const SizedBox(width: 12),
        _StatusBadge(isActive: employee.isActive),
        const SizedBox(width: 12),
        _ActionButtons(isBusy: isBusy, onEdit: onEdit, onDelete: onDelete),
      ],
    );
  }

  Widget _buildCompactLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: _EmployeeIdentity(employee: employee)),
            const SizedBox(width: 8),
            _StatusBadge(isActive: employee.isActive),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columns = constraints.maxWidth >= 560 ? 3 : 2;
            const double gap = 12;
            final double width =
                (constraints.maxWidth - ((columns - 1) * gap)) / columns;

            final List<Widget> items = <Widget>[
              _DetailBlock(
                label: 'ROLE',
                value: _EmployeeFields.role(employee),
              ),
              _DetailBlock(label: 'EMAIL', value: employee.email.trim()),
              _DetailBlock(label: 'MOBILE', value: employee.phone.trim()),
              _DetailBlock(
                label: 'COMPANY',
                value:
                    '${_EmployeeFields.companyName(employee)} / '
                    '${_EmployeeFields.branchName(employee)}',
              ),
              _DetailBlock(
                label: 'SHIFT',
                value: _EmployeeFields.shiftName(employee),
              ),
              _DetailBlock(
                label: 'USERNAME',
                value: employee.username.trim().isEmpty
                    ? 'Not Created'
                    : employee.username.trim(),
              ),
            ];

            return Wrap(
              spacing: gap,
              runSpacing: 14,
              children: items.map((Widget item) {
                return SizedBox(width: width, child: item);
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: _ActionButtons(
            isBusy: isBusy,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
        ),
      ],
    );
  }
}

class _EmployeeIdentity extends StatelessWidget {
  const _EmployeeIdentity({required this.employee});

  final CompanyEmployee employee;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _ProfileImage(employee: employee),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                employee.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AdminTextStyles.employeeName,
              ),
              const SizedBox(height: 4),
              Text(
                _EmployeeFields.employeeCode(employee),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AdminTextStyles.employeeCode,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileImage extends StatelessWidget {
  const _ProfileImage({required this.employee});

  final CompanyEmployee employee;

  @override
  Widget build(BuildContext context) {
    final String imageUrl = employee.profileImageUrl.trim();

    final Widget fallback = ColoredBox(
      color: AdminColors.avatarBlue,
      child: Center(
        child: Text(
          _EmployeeFields.initials(employee.displayName),
          style: const TextStyle(
            color: AdminColors.avatarBlueText,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );

    return Container(
      width: 44,
      height: 44,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: imageUrl.isEmpty
          ? fallback
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) {
                    return fallback;
                  },
            ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({
    required this.label,
    required this.value,
    this.secondary,
  });

  final String label;
  final String value;
  final String? secondary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AdminTextStyles.tableCaption,
        ),
        const SizedBox(height: 5),
        Text(
          value.isEmpty ? '—' : value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AdminTextStyles.tableBodyStrong,
        ),
        if (secondary != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            secondary!.isEmpty ? '—' : secondary!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AdminTextStyles.tableCaption,
          ),
        ],
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final Color color = isActive ? AdminColors.success : AdminColors.danger;

    final Color background = isActive
        ? AdminColors.successBackground
        : AdminColors.dangerBackground;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.isBusy,
    required this.onEdit,
    required this.onDelete,
  });

  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    if (isBusy) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('Edit'),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Delete Employee',
          onPressed: onDelete,
          style: IconButton.styleFrom(
            foregroundColor: AdminColors.danger,
            backgroundColor: AdminColors.dangerBackground,
            side: const BorderSide(color: AdminColors.dangerBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          icon: const Icon(Icons.delete_outline_rounded, size: 19),
        ),
      ],
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.hasPreviousPage,
    required this.hasNextPage,
    required this.isLoading,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentPage;
  final int totalPages;
  final int totalItems;
  final bool hasPreviousPage;
  final bool hasNextPage;
  final bool isLoading;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '$totalItems employee records',
              style: AdminTextStyles.tableCaption,
            ),
          ),
          OutlinedButton(
            onPressed: hasPreviousPage && !isLoading ? onPrevious : null,
            child: const Text('Previous'),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: AdminColors.primaryLight,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              'Page $currentPage of ${totalPages < 1 ? 1 : totalPages}',
              style: const TextStyle(
                color: AdminColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: hasNextPage && !isLoading ? onNext : null,
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircularProgressIndicator(),
          SizedBox(height: 14),
          Text('Loading employees...', style: AdminTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 470),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            decoration: BoxDecoration(
              color: AdminColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AdminColors.dangerBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const CircleAvatar(
                  radius: 25,
                  backgroundColor: AdminColors.dangerBackground,
                  child: Icon(
                    Icons.error_outline_rounded,
                    color: AdminColors.danger,
                    size: 25,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Unable to Load Employees',
                  textAlign: TextAlign.center,
                  style: AdminTextStyles.emptyStateTitle,
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AdminTextStyles.emptyStateBody,
                ),
                const SizedBox(height: 15),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.searchText,
    required this.onClearSearch,
    required this.onAddEmployee,
  });

  final String searchText;
  final VoidCallback onClearSearch;
  final VoidCallback onAddEmployee;

  @override
  Widget build(BuildContext context) {
    final bool hasSearch = searchText.isNotEmpty;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Container(
          width: 460,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: AdminColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AdminColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 62,
                height: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AdminColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.groups_outlined,
                  color: AdminColors.primary,
                  size: 31,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                hasSearch ? 'No Matching Employees' : 'No Employees Saved',
                style: AdminTextStyles.emptyStateTitle,
              ),
              const SizedBox(height: 7),
              Text(
                hasSearch
                    ? 'No employee matches "$searchText".'
                    : 'Saved employee details will appear here.',
                textAlign: TextAlign.center,
                style: AdminTextStyles.emptyStateBody,
              ),
              const SizedBox(height: 18),
              if (hasSearch)
                OutlinedButton.icon(
                  onPressed: onClearSearch,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Clear Search'),
                )
              else
                FilledButton.icon(
                  onPressed: onAddEmployee,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Add Employee'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryData {
  const _SummaryData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.background,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color background;
}

class _EmployeeFields {
  const _EmployeeFields._();

  static String employeeCode(CompanyEmployee employee) {
    final String value = employee.employeeCode.trim();

    if (value.isNotEmpty) {
      return value;
    }

    final int? id = employee.employeeId;

    return id == null ? '—' : 'EMP-${id.toString().padLeft(4, '0')}';
  }

  static String role(CompanyEmployee employee) {
    final String value = employee.role.trim();
    return value.isEmpty ? 'Employee' : value;
  }

  static String companyName(CompanyEmployee employee) {
    final String value = employee.companyName.trim();

    return value.isEmpty ? fixedEmployeeCompanyName : value;
  }

  static String branchName(CompanyEmployee employee) {
    final String value = employee.branchName.trim();

    return value.isEmpty ? fixedEmployeeBranchName : value;
  }

  static String shiftName(CompanyEmployee employee) {
    final String value = employee.shiftName.trim();

    return value.isEmpty ? fixedEmployeeShiftName : value;
  }

  static String initials(String name) {
    final List<String> words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) {
      return 'E';
    }

    if (words.length == 1) {
      final String word = words.first;
      return word.substring(0, word.length >= 2 ? 2 : 1).toUpperCase();
    }

    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }
}
