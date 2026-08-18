import 'package:flutter/material.dart';

import '../../data/models/admin_holiday_models.dart';
import '../controllers/admin_calendar_controller.dart';

class AdminCalendarScreen extends StatefulWidget {
  const AdminCalendarScreen({
    super.key,
    this.controller,
  });

  final AdminCalendarController? controller;

  @override
  State<AdminCalendarScreen> createState() {
    return _AdminCalendarScreenState();
  }
}

class _AdminCalendarScreenState
    extends State<AdminCalendarScreen> {
  late final AdminCalendarController _controller;
  late final bool _ownsController;

  final TextEditingController _holidayNameController =
      TextEditingController();

  AdminHoliday? _editingHoliday;
  DateTime? _holidayDate;
  String? _holidayType;

  bool _weeklyView = true;
  String? _lastMessageKey;

  @override
  void initState() {
    super.initState();

    _ownsController = widget.controller == null;
    _controller =
        widget.controller ?? AdminCalendarController();

    _controller.addListener(_handleControllerChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.initialize();
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);

    if (_ownsController) {
      _controller.dispose();
    }

    _holidayNameController.dispose();

    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});

    final String? error = _controller.errorMessage;
    final String? success = _controller.successMessage;

    final String? message =
        error?.trim().isNotEmpty == true
            ? error
            : success?.trim().isNotEmpty == true
                ? success
                : null;

    if (message == null) {
      return;
    }

    final bool isError =
        error?.trim().isNotEmpty == true;

    final String messageKey =
        '${isError ? 'error' : 'success'}:$message';

    if (_lastMessageKey == messageKey) {
      return;
    }

    _lastMessageKey = messageKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: isError
                ? const Color(0xFFB42318)
                : const Color(0xFF176B3A),
            content: Text(message),
          ),
        );

      _controller.clearMessages(
        notify: false,
      );
    });
  }

  Future<void> _pickHolidayDate() async {
    final DateTime initialDate =
        _holidayDate ??
        _controller.selectedDate ??
        DateTime.now();

    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2200),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _holidayDate = DateTime(
        selected.year,
        selected.month,
        selected.day,
      );
    });
  }

  Future<void> _saveHoliday() async {
    final String name =
        _holidayNameController.text.trim();

    if (name.isEmpty) {
      _showMessage('Holiday name is required.');
      return;
    }

    if (_holidayDate == null) {
      _showMessage('Holiday date is required.');
      return;
    }

    if (_holidayType == null ||
        _holidayType!.trim().isEmpty) {
      _showMessage('Holiday type is required.');
      return;
    }

    final AdminHoliday? editingHoliday =
        _editingHoliday;

    final AdminHoliday? savedHoliday;

    if (editingHoliday == null) {
      savedHoliday = await _controller.createHoliday(
        holidayName: name,
        holidayDate: _holidayDate!,
        holidayType: _holidayType!,
      );
    } else {
      savedHoliday = await _controller.updateHoliday(
        holidayId: editingHoliday.id,
        holidayName: name,
        holidayDate: _holidayDate!,
        holidayType: _holidayType!,
        description: editingHoliday.description,
        isActive: editingHoliday.isActive,
      );
    }

    if (savedHoliday != null && mounted) {
      _discardForm();
    }
  }

  void _editHoliday(
    AdminHoliday holiday,
  ) {
    setState(() {
      _editingHoliday = holiday;
      _holidayNameController.text =
          holiday.holidayName;
      _holidayDate = holiday.holidayDate;
      _holidayType = holiday.holidayType;
    });
  }

  Future<void> _deleteHoliday(
    AdminHoliday holiday,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Holiday'),
          content: Text(
            'Delete "${holiday.holidayName}"?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                    const Color(0xFFB42318),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final bool deleted =
        await _controller.deleteHoliday(
      holidayId: holiday.id,
    );

    if (deleted &&
        _editingHoliday?.id == holiday.id &&
        mounted) {
      _discardForm();
    }
  }

  void _discardForm() {
    FocusScope.of(context).unfocus();

    setState(() {
      _editingHoliday = null;
      _holidayNameController.clear();
      _holidayDate = null;
      _holidayType = null;
    });
  }

  void _selectCalendarDate(
    DateTime date,
  ) {
    _controller.selectDate(date);

    setState(() {
      _holidayDate = date;
    });
  }

  void _showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(message),
        ),
      );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildHeader(),
          const SizedBox(height: 14),
          _buildMainLayout(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (
        BuildContext context,
        BoxConstraints constraints,
      ) {
        final Widget heading = const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Calendar & Leave Settings',
              style: TextStyle(
                color: Color(0xFF20242C),
                fontSize: 22,
                height: 1.15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Configure holiday calendars, leave types, and accrual policies for global teams. '
              'Changes will reflect in real-time on employee dashboards.',
              style: TextStyle(
                color: Color(0xFF667085),
                fontSize: 10.5,
                height: 1.35,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        );

        final Widget actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            OutlinedButton(
              onPressed:
                  _controller.isBusy ? null : _discardForm,
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    const Color(0xFF475467),
                side: const BorderSide(
                  color: Color(0xFF98A2B3),
                ),
                minimumSize: const Size(74, 36),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              child: const Text(
                'Discard',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            FilledButton(
              onPressed:
                  _controller.isSaving
                      ? null
                      : _saveHoliday,
              style: FilledButton.styleFrom(
                backgroundColor:
                    const Color(0xFF0D45A5),
                minimumSize: const Size(110, 36),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              child: Text(
                _controller.isSaving
                    ? 'Saving...'
                    : 'Save Changes',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );

        if (constraints.maxWidth < 780) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              heading,
              const SizedBox(height: 12),
              actions,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: heading),
            const SizedBox(width: 16),
            actions,
          ],
        );
      },
    );
  }

  Widget _buildMainLayout() {
    return LayoutBuilder(
      builder: (
        BuildContext context,
        BoxConstraints constraints,
      ) {
        if (constraints.maxWidth < 980) {
          return Column(
            children: <Widget>[
              _buildCompactCalendar(),
              const SizedBox(height: 12),
              _buildAutomaticImportCard(),
              const SizedBox(height: 12),
              _buildUpcomingHolidaysPanel(),
              const SizedBox(height: 12),
              _buildHolidayUpdatePanel(),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 220,
              child: Column(
                children: <Widget>[
                  _buildCompactCalendar(),
                  const SizedBox(height: 12),
                  _buildAutomaticImportCard(),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildUpcomingHolidaysPanel(),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 230,
              child: _buildHolidayUpdatePanel(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCompactCalendar() {
    final DateTime visibleMonth =
        _controller.visibleMonth;

    final DateTime firstCalendarDate =
        _calendarStartDate(visibleMonth);

    final List<DateTime> calendarDates =
        List<DateTime>.generate(
      42,
      (int index) => firstCalendarDate.add(
        Duration(days: index),
      ),
    );

    const List<String> weekdayLabels =
        <String>[
      'S',
      'M',
      'T',
      'W',
      'T',
      'F',
      'S',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        14,
        12,
        14,
        14,
      ),
      decoration: _CalendarDesign.panelDecoration,
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _monthYearLabel(visibleMonth),
                  style: const TextStyle(
                    color: Color(0xFF344054),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _SmallIconButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Previous month',
                onPressed:
                    _controller.isLoading
                        ? null
                        : _controller.goToPreviousMonth,
              ),
              const SizedBox(width: 2),
              _SmallIconButton(
                icon: Icons.chevron_right_rounded,
                tooltip: 'Next month',
                onPressed:
                    _controller.isLoading
                        ? null
                        : _controller.goToNextMonth,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: weekdayLabels.map(
              (String label) {
                return Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF98A2B3),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              },
            ).toList(),
          ),
          const SizedBox(height: 7),
          GridView.builder(
            itemCount: calendarDates.length,
            shrinkWrap: true,
            physics:
                const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemBuilder: (
              BuildContext context,
              int index,
            ) {
              final DateTime date =
                  calendarDates[index];

              final bool isCurrentMonth =
                  date.month == visibleMonth.month &&
                  date.year == visibleMonth.year;

              final bool isSelected = _sameDate(
                date,
                _controller.selectedDate,
              );

              final bool isToday = _sameDate(
                date,
                DateTime.now(),
              );

              final bool hasHoliday =
                  _controller.hasHolidayOnDate(date);

              return InkWell(
                onTap: () {
                  _selectCalendarDate(date);

                  if (!isCurrentMonth) {
                    _controller.setVisibleMonth(date);
                  }
                },
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _dayBackgroundColor(
                      isCurrentMonth: isCurrentMonth,
                      isSelected: isSelected,
                      isToday: isToday,
                      hasHoliday: hasHoliday,
                    ),
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color:
                                const Color(0xFF155EEF),
                            width: 1.3,
                          )
                        : hasHoliday
                            ? Border.all(
                                color:
                                    const Color(0xFFF04438),
                                width: 1,
                              )
                            : null,
                  ),
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      color: _dayTextColor(
                        isCurrentMonth:
                            isCurrentMonth,
                        isSelected: isSelected,
                        isToday: isToday,
                        hasHoliday: hasHoliday,
                      ),
                      fontSize: 9.5,
                      fontWeight:
                          isSelected || isToday
                              ? FontWeight.w800
                              : FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAutomaticImportCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FF),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: const Color(0xFFC9D7F5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(
                Icons.info_outline_rounded,
                color: Color(0xFF0D5BD1),
                size: 15,
              ),
              SizedBox(width: 7),
              Text(
                'Automatic Import',
                style: TextStyle(
                  color: Color(0xFF0D5BD1),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'You can synchronize this calendar with regional public holidays '
            'based on the registered office locations.',
            style: TextStyle(
              color: Color(0xFF31598F),
              fontSize: 8.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () {
              _showMessage(
                'Regional holiday synchronization will be connected later.',
              );
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Sync Region',
                  style: TextStyle(
                    color: Color(0xFF0D5BD1),
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 3),
                Icon(
                  Icons.open_in_new_rounded,
                  color: Color(0xFF0D5BD1),
                  size: 10,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingHolidaysPanel() {
    final List<AdminHoliday> holidays =
        List<AdminHoliday>.from(
      _controller.holidays,
    )
          ..sort(
            (
              AdminHoliday first,
              AdminHoliday second,
            ) {
              return first.holidayDate.compareTo(
                second.holidayDate,
              );
            },
          );

    return Container(
      width: double.infinity,
      height: 405,
      decoration: _CalendarDesign.panelDecoration,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              13,
              14,
              12,
            ),
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Upcoming Holidays',
                    style: TextStyle(
                      color: Color(0xFF1D2939),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(
                  width: 235,
                  height: 29,
                  child: _buildViewToggle(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_controller.isLoading)
            const LinearProgressIndicator(
              minHeight: 2,
            ),
          if (_controller.hasError &&
              holidays.isEmpty)
            Expanded(
              child: _buildHolidayError(),
            )
          else if (holidays.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'No holidays available',
                  style: TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 11,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 610,
                  ),
                  child: DataTable(
                    headingRowHeight: 38,
                    dataRowMinHeight: 50,
                    dataRowMaxHeight: 56,
                    horizontalMargin: 16,
                    columnSpacing: 25,
                    headingRowColor:
                        WidgetStateProperty.all(
                      const Color(0xFFF5F6FF),
                    ),
                    headingTextStyle:
                        const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                    dataTextStyle:
                        const TextStyle(
                      color: Color(0xFF344054),
                      fontSize: 9.5,
                    ),
                    columns: const <DataColumn>[
                      DataColumn(
                        label: Text('Holiday Name'),
                      ),
                      DataColumn(
                        label: Text('Date'),
                      ),
                      DataColumn(
                        label: Text('Type'),
                      ),
                      DataColumn(
                        label: Text('Actions'),
                      ),
                    ],
                    rows: holidays.map(
                      (AdminHoliday holiday) {
                        return DataRow(
                          cells: <DataCell>[
                            DataCell(
                              Text(
                                holiday.holidayName,
                                style: const TextStyle(
                                  color:
                                      Color(0xFF344054),
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                _tableDateLabel(
                                  holiday.holidayDate,
                                ),
                              ),
                            ),
                            DataCell(
                              _CompactTypeChip(
                                holidayType:
                                    holiday.holidayType,
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize:
                                    MainAxisSize.min,
                                children: <Widget>[
                                  IconButton(
                                    tooltip:
                                        'Edit holiday',
                                    constraints:
                                        const BoxConstraints(
                                      minWidth: 30,
                                      minHeight: 30,
                                    ),
                                    padding:
                                        EdgeInsets.zero,
                                    visualDensity:
                                        VisualDensity.compact,
                                    onPressed:
                                        _controller.isBusy
                                            ? null
                                            : () {
                                                _editHoliday(
                                                  holiday,
                                                );
                                              },
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 15,
                                      color:
                                          Color(0xFF475467),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip:
                                        'Delete holiday',
                                    constraints:
                                        const BoxConstraints(
                                      minWidth: 30,
                                      minHeight: 30,
                                    ),
                                    padding:
                                        EdgeInsets.zero,
                                    visualDensity:
                                        VisualDensity.compact,
                                    onPressed:
                                        _controller.isBusy
                                            ? null
                                            : () {
                                                _deleteHoliday(
                                                  holiday,
                                                );
                                              },
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 15,
                                      color:
                                          Color(0xFF475467),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ).toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2FF),
        borderRadius: BorderRadius.circular(7),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _ViewToggleButton(
              label: 'Weekly',
              isSelected: _weeklyView,
              onTap: () {
                setState(() {
                  _weeklyView = true;
                });
              },
            ),
          ),
          Expanded(
            child: _ViewToggleButton(
              label: 'Monthly',
              isSelected: !_weeklyView,
              onTap: () {
                setState(() {
                  _weeklyView = false;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHolidayUpdatePanel() {
    return Container(
      width: double.infinity,
      height: 405,
      decoration: _CalendarDesign.panelDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            height: 53,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFFD8DEE9),
                ),
              ),
            ),
            child: Text(
              _editingHoliday == null
                  ? 'Holidays Update'
                  : 'Edit Holiday',
              style: const TextStyle(
                color: Color(0xFF1D2939),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                14,
                14,
                14,
                16,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: <Widget>[
                  const _FormLabel(
                    label: 'HOLIDAY NAME',
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller:
                        _holidayNameController,
                    maxLength: 150,
                    style: const TextStyle(
                      color: Color(0xFF344054),
                      fontSize: 10,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Holiday name',
                      counterText: '',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 13),
                  const _FormLabel(
                    label: 'DATE',
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap:
                        _controller.isBusy
                            ? null
                            : _pickHolidayDate,
                    borderRadius:
                        BorderRadius.circular(6),
                    child: InputDecorator(
                      decoration:
                          const InputDecoration(
                        isDense: true,
                        suffixIcon: Icon(
                          Icons
                              .keyboard_arrow_down_rounded,
                          size: 17,
                        ),
                      ),
                      child: Text(
                        _holidayDate == null
                            ? 'mm / dd / yyyy'
                            : _formDateLabel(
                                _holidayDate!,
                              ),
                        style: TextStyle(
                          color:
                              _holidayDate == null
                                  ? const Color(
                                      0xFF667085,
                                    )
                                  : const Color(
                                      0xFF344054,
                                    ),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 13),
                  const _FormLabel(
                    label: 'HOLIDAY TYPE',
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _holidayType,
                    isExpanded: true,
                    style: const TextStyle(
                      color: Color(0xFF344054),
                      fontSize: 10,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Select..',
                      isDense: true,
                    ),
                    items:
                        const <
                          DropdownMenuItem<String>
                        >[
                      DropdownMenuItem<String>(
                        value: 'public',
                        child: Text('Public'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'optional',
                        child: Text('Optional'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'company',
                        child: Text('Company'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'regional',
                        child: Text('Regional'),
                      ),
                    ],
                    onChanged:
                        _controller.isBusy
                            ? null
                            : (String? value) {
                                setState(() {
                                  _holidayType =
                                      value;
                                });
                              },
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed:
                        _controller.isSaving
                            ? null
                            : _saveHoliday,
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          const Color(0xFF0D45A5),
                      minimumSize:
                          const Size.fromHeight(34),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(5),
                      ),
                    ),
                    child: Text(
                      _controller.isSaving
                          ? 'Saving...'
                          : 'Save',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_editingHoliday != null) ...<Widget>[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed:
                          _controller.isBusy
                              ? null
                              : _discardForm,
                      child: const Text(
                        'Cancel editing',
                        style: TextStyle(
                          fontSize: 9.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHolidayError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFB42318),
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              _controller.errorMessage ??
                  'Unable to load holidays.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF667085),
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 9),
            OutlinedButton(
              onPressed: _controller.loadMonth,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  static DateTime _calendarStartDate(
    DateTime visibleMonth,
  ) {
    final DateTime firstDay = DateTime(
      visibleMonth.year,
      visibleMonth.month,
      1,
    );

    return firstDay.subtract(
      Duration(days: firstDay.weekday % 7),
    );
  }

  static String _monthYearLabel(
    DateTime value,
  ) {
    const List<String> months =
        <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[value.month - 1]} ${value.year}';
  }

  static String _tableDateLabel(
    DateTime value,
  ) {
    const List<String> months =
        <String>[
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

    return '${months[value.month - 1]} '
        '${value.day.toString().padLeft(2, '0')}, '
        '${value.year}';
  }

  static String _formDateLabel(
    DateTime value,
  ) {
    final String month =
        value.month.toString().padLeft(2, '0');

    final String day =
        value.day.toString().padLeft(2, '0');

    return '$month / $day / ${value.year}';
  }

  static bool _sameDate(
    DateTime first,
    DateTime? second,
  ) {
    if (second == null) {
      return false;
    }

    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  static Color _dayBackgroundColor({
    required bool isCurrentMonth,
    required bool isSelected,
    required bool isToday,
    required bool hasHoliday,
  }) {
    if (isToday) {
      return const Color(0xFF155EEF);
    }

    if (isSelected) {
      return const Color(0xFFE9EEFF);
    }

    if (hasHoliday) {
      return const Color(0xFFFFEEEE);
    }

    if (!isCurrentMonth) {
      return Colors.transparent;
    }

    return const Color(0xFFE9EEFA);
  }

  static Color _dayTextColor({
    required bool isCurrentMonth,
    required bool isSelected,
    required bool isToday,
    required bool hasHoliday,
  }) {
    if (isToday) {
      return Colors.white;
    }

    if (hasHoliday) {
      return const Color(0xFFD92D20);
    }

    if (isSelected) {
      return const Color(0xFF155EEF);
    }

    if (!isCurrentMonth) {
      return const Color(0xFFC4C9D4);
    }

    return const Color(0xFF344054);
  }
}

class _ViewToggleButton extends StatelessWidget {
  const _ViewToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1769E0)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : const Color(0xFF344054),
            fontSize: 8.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _CompactTypeChip extends StatelessWidget {
  const _CompactTypeChip({
    required this.holidayType,
  });

  final String holidayType;

  @override
  Widget build(
    BuildContext context,
  ) {
    final String normalized =
        holidayType.trim().toLowerCase();

    final String label;

    switch (normalized) {
      case 'optional':
        label = 'Optional';
        break;
      case 'company':
        label = 'Company';
        break;
      case 'regional':
        label = 'Regional';
        break;
      case 'public':
      default:
        label = 'Public';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE4F2FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF1769E0),
          fontSize: 8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FormLabel extends StatelessWidget {
  const _FormLabel({
    required this.label,
  });

  final String label;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF475467),
        fontSize: 8.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  const _SmallIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(
    BuildContext context,
  ) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints(
        minWidth: 24,
        minHeight: 24,
      ),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      icon: Icon(
        icon,
        size: 16,
        color: const Color(0xFF344054),
      ),
    );
  }
}

class _CalendarDesign {
  const _CalendarDesign._();

  static BoxDecoration get panelDecoration {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(
        color: const Color(0xFFD8DEE9),
      ),
    );
  }
}