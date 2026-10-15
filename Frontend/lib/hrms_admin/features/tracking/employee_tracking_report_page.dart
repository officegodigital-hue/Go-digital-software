import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../../services/hrms_tracking_api.dart';

// ── Palette ────────────────────────────────────────────────────────────────

const _navy    = Color(0xFF061457);
const _blue    = Color(0xFF075EF7);
const _page    = Color(0xFFF4F6FB);
const _surface = Color(0xFFFFFFFF);
const _border  = Color(0xFFDDE5F1);
const _muted   = Color(0xFF62708E);
const _green   = Color(0xFF12A150);
const _red     = Color(0xFFEF3340);
const _orange  = Color(0xFFF59E0B);

// ── Entry point ────────────────────────────────────────────────────────────

class EmployeeTrackingReportPage extends StatefulWidget {
  const EmployeeTrackingReportPage({
    super.key,
    required this.employeeUserId,
    required this.employeeName,
    required this.employeeCode,
  });

  final int employeeUserId;
  final String employeeName;
  final String employeeCode;

  @override
  State<EmployeeTrackingReportPage> createState() =>
      _EmployeeTrackingReportPageState();
}

class _EmployeeTrackingReportPageState
    extends State<EmployeeTrackingReportPage> {
  // ── monthly report state ──
  DateTime _month = DateTime.now();
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  // ── selected day + route state ──
  Map<String, dynamic>? _selectedDay;
  List<Map<String, dynamic>> _routePoints = [];
  bool _routeLoading = false;
  String? _routeError;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _loadMonth();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadMonth() async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedDay = null;
      _routePoints = [];
      _routeError = null;
    });
    try {
      final data = await HrmsTrackingApi.monthlyReport(
        employeeUserId: widget.employeeUserId,
        month: DateFormat('yyyy-MM').format(_month),
      );
      if (!mounted) return;
      final days = (data['days'] as List? ?? [])
          .whereType<Map>()
          .map((d) => Map<String, dynamic>.from(d))
          .toList();
      setState(() {
        _data = data;
        _loading = false;
        // auto-select first day that has pings or attendance
        if (days.isNotEmpty) {
          _selectedDay = days.first;
          _loadRoute(days.first);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadRoute(Map<String, dynamic> day) async {
    final date = '${day['date']}';
    setState(() {
      _routeLoading = true;
      _routeError = null;
      _routePoints = [];
    });
    try {
      final result = await HrmsTrackingApi.route(
        employeeUserId: widget.employeeUserId,
        date: date,
      );
      if (!mounted) return;
      final pts = (result['points'] as List? ?? [])
          .whereType<Map>()
          .map((p) => Map<String, dynamic>.from(p))
          .toList();
      setState(() {
        _routePoints = pts;
        _routeLoading = false;
      });
      _fitMapToPoints(pts);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _routeLoading = false;
        _routeError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _fitMapToPoints(List<Map<String, dynamic>> pts) {
    if (_mapController == null || pts.isEmpty) return;
    if (pts.length == 1) {
      final lat = double.tryParse('${pts.first['latitude']}') ?? 0;
      final lng = double.tryParse('${pts.first['longitude']}') ?? 0;
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(lat, lng), 15),
      );
      return;
    }
    double minLat = double.infinity, maxLat = -double.infinity;
    double minLng = double.infinity, maxLng = -double.infinity;
    for (final p in pts) {
      final lat = double.tryParse('${p['latitude']}') ?? 0;
      final lng = double.tryParse('${p['longitude']}') ?? 0;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        56,
      ),
    );
  }

  // ── Month navigation ──────────────────────────────────────────────────────

  void _prevMonth() {
    setState(() => _month = DateTime(_month.year, _month.month - 1));
    _loadMonth();
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_month.year, _month.month + 1);
    if (next.isAfter(DateTime(now.year, now.month))) return;
    setState(() => _month = next);
    _loadMonth();
  }

  bool get _canGoNext {
    final now = DateTime.now();
    return _month.year < now.year ||
        (_month.year == now.year && _month.month < now.month);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String get _workMode =>
      '${_data?['workMode'] ?? ''}';

  Map<String, dynamic> get _summary =>
      (_data?['summary'] as Map? ?? {}).cast<String, dynamic>();

  List<Map<String, dynamic>> get _days =>
      (_data?['days'] as List? ?? [])
          .whereType<Map>()
          .map((d) => Map<String, dynamic>.from(d))
          .toList();

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _page,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  // ── Unified navy header ───────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      color: _navy,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: back + avatar + name/code/badge
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.08),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: Colors.white.withOpacity(.18)),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Avatar
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _blue,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(.22), width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _initials(widget.employeeName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name + code + badge
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.employeeName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              widget.employeeCode,
                              style: TextStyle(
                                color: Colors.white.withOpacity(.55),
                                fontSize: 11,
                              ),
                            ),
                            if (_workMode.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _blue.withOpacity(.35),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _blue.withOpacity(.45),
                                  ),
                                ),
                                child: Text(
                                  _workMode,
                                  style: const TextStyle(
                                    color: Color(0xFFA5C4FF),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: .5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Row 2: month navigation (compact, centred)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _NavBtn(
                    icon: Icons.chevron_left_rounded,
                    onTap: _prevMonth,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      DateFormat('MMMM yyyy').format(_month),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _NavBtn(
                    icon: Icons.chevron_right_rounded,
                    onTap: _canGoNext ? _nextMonth : null,
                  ),
                ],
              ),
            ),

            // Row 3: summary stats tiles
            if (!_loading && _data != null)
              _buildSummaryTiles()
            else if (_loading)
              const SizedBox(height: 56),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTiles() {
    final isHybrid = _workMode == 'Hybrid';
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Row(
        children: [
          _StatTile(
            label: 'PRESENT',
            value: '${_summary['presentDays'] ?? 0}',
            valueColor: const Color(0xFF4AE08A),
          ),
          _StatTile(
            label: 'ABSENT',
            value: '${_summary['absentDays'] ?? 0}',
            valueColor: const Color(0xFFFF7B72),
          ),
          _StatTile(
            label: 'LATE',
            value: '${_summary['lateDays'] ?? 0}',
            valueColor: const Color(0xFFFFD166),
          ),
          if (isHybrid)
            _StatTile(
              label: 'GPS PINGS',
              value: '${_summary['totalPings'] ?? 0}',
              valueColor: const Color(0xFF7EB8FF),
            )
          else
            _StatTile(
              label: 'SESSIONS',
              value: '${_summary['totalSessions'] ?? _summary['fieldSessions'] ?? 0}',
              valueColor: const Color(0xFF7EB8FF),
            ),
        ],
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _blue));
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _loadMonth);
    }
    if (_days.isEmpty) {
      return Center(
        child: Text(
          'No records for ${DateFormat('MMMM yyyy').format(_month)}.',
          style: const TextStyle(color: _muted),
        ),
      );
    }

    // Responsive: mobile = stacked tabs, desktop = side by side
    final w = MediaQuery.of(context).size.width;
    if (w >= 700) {
      return _DesktopSplitLayout(
        days: _days,
        selectedDay: _selectedDay,
        routePoints: _routePoints,
        routeLoading: _routeLoading,
        routeError: _routeError,
        onDaySelected: (day) {
          setState(() => _selectedDay = day);
          _loadRoute(day);
        },
        onMapCreated: (ctrl) {
          _mapController = ctrl;
          _fitMapToPoints(_routePoints);
        },
      );
    }
    return _MobileLayout(
      days: _days,
      selectedDay: _selectedDay,
      routePoints: _routePoints,
      routeLoading: _routeLoading,
      routeError: _routeError,
      onDaySelected: (day) {
        setState(() => _selectedDay = day);
        _loadRoute(day);
      },
      onMapCreated: (ctrl) {
        _mapController = ctrl;
        _fitMapToPoints(_routePoints);
      },
    );
  }
}

// ── Desktop split layout ──────────────────────────────────────────────────

class _DesktopSplitLayout extends StatelessWidget {
  const _DesktopSplitLayout({
    required this.days,
    required this.selectedDay,
    required this.routePoints,
    required this.routeLoading,
    required this.routeError,
    required this.onDaySelected,
    required this.onMapCreated,
  });

  final List<Map<String, dynamic>> days;
  final Map<String, dynamic>? selectedDay;
  final List<Map<String, dynamic>> routePoints;
  final bool routeLoading;
  final String? routeError;
  final ValueChanged<Map<String, dynamic>> onDaySelected;
  final MapCreatedCallback onMapCreated;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left: day list (320 px)
        SizedBox(
          width: 320,
          child: _DayList(
            days: days,
            selectedDay: selectedDay,
            onDaySelected: onDaySelected,
          ),
        ),
        Container(width: 1, color: _border),
        // Right: map + ping timeline
        Expanded(
          child: _RoutePanel(
            selectedDay: selectedDay,
            routePoints: routePoints,
            routeLoading: routeLoading,
            routeError: routeError,
            onMapCreated: onMapCreated,
          ),
        ),
      ],
    );
  }
}

// ── Mobile layout (tabbed) ────────────────────────────────────────────────

class _MobileLayout extends StatefulWidget {
  const _MobileLayout({
    required this.days,
    required this.selectedDay,
    required this.routePoints,
    required this.routeLoading,
    required this.routeError,
    required this.onDaySelected,
    required this.onMapCreated,
  });

  final List<Map<String, dynamic>> days;
  final Map<String, dynamic>? selectedDay;
  final List<Map<String, dynamic>> routePoints;
  final bool routeLoading;
  final String? routeError;
  final ValueChanged<Map<String, dynamic>> onDaySelected;
  final MapCreatedCallback onMapCreated;

  @override
  State<_MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends State<_MobileLayout> {
  bool _showMap = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab switcher
        Container(
          color: _surface,
          child: Row(
            children: [
              _TabChip(
                label: 'Days',
                selected: !_showMap,
                onTap: () => setState(() => _showMap = false),
              ),
              _TabChip(
                label: 'GPS Route',
                selected: _showMap,
                onTap: () => setState(() => _showMap = true),
              ),
            ],
          ),
        ),
        Expanded(
          child: _showMap
              ? _RoutePanel(
                  selectedDay: widget.selectedDay,
                  routePoints: widget.routePoints,
                  routeLoading: widget.routeLoading,
                  routeError: widget.routeError,
                  onMapCreated: widget.onMapCreated,
                )
              : _DayList(
                  days: widget.days,
                  selectedDay: widget.selectedDay,
                  onDaySelected: (day) {
                    widget.onDaySelected(day);
                    setState(() => _showMap = true);
                  },
                ),
        ),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? _blue : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _blue : _muted,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ── Day list ──────────────────────────────────────────────────────────────

class _DayList extends StatelessWidget {
  const _DayList({
    required this.days,
    required this.selectedDay,
    required this.onDaySelected,
  });

  final List<Map<String, dynamic>> days;
  final Map<String, dynamic>? selectedDay;
  final ValueChanged<Map<String, dynamic>> onDaySelected;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      itemCount: days.length,
      itemBuilder: (_, i) => _DayCard(
        day: days[i],
        isSelected: selectedDay?['date'] == days[i]['date'],
        onTap: () => onDaySelected(days[i]),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.isSelected,
    required this.onTap,
  });

  final Map<String, dynamic> day;
  final bool isSelected;
  final VoidCallback onTap;

  Color get _accentColor {
    final s = '${day['status']}';
    if (s.startsWith('Present') || s.startsWith('Checked')) return _green;
    if (s.startsWith('Late')) return _orange;
    return _red;
  }

  IconData get _statusIcon {
    final s = '${day['status']}';
    if (s.startsWith('Present') || s.startsWith('Checked')) {
      return Icons.check_circle_outline_rounded;
    }
    if (s.startsWith('Late')) return Icons.schedule_rounded;
    return Icons.cancel_outlined;
  }

  String _fmt(int minutes) {
    if (minutes == 0) return '—';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h == 0 ? '${m}m' : '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  @override
  Widget build(BuildContext context) {
    final date = '${day['date']}';
    final weekday = '${day['weekday'] ?? ''}';
    final checkIn = day['checkIn'] as String?;
    final checkOut = day['checkOut'] as String?;
    final workingMinutes = day['workingMinutes'] as int? ?? 0;
    final pingCount = day['pingCount'] as int? ?? 0;
    final fieldSessions = day['fieldSessions'] as int? ?? 0;
    final isLate = day['isLate'] as bool? ?? false;

    final dateParsed = DateTime.tryParse(date);
    final dayNum = dateParsed != null ? '${dateParsed.day}' : '?';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? _blue : _border,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _blue.withOpacity(.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            children: [
              // Left accent strip
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 3, color: _accentColor),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 10, 12, 10),
                child: Row(
            children: [
              // Date column
              SizedBox(
                width: 36,
                child: Column(
                  children: [
                    Text(
                      dayNum,
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      weekday,
                      style: const TextStyle(color: _muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: _border,
                margin: const EdgeInsets.symmetric(horizontal: 10),
              ),
              // Status icon
              Icon(_statusIcon, color: _accentColor, size: 18),
              const SizedBox(width: 8),
              // Check-in/out
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${day['status']}',
                          style: TextStyle(
                            color: _accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (isLate) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Late',
                              style: TextStyle(color: _orange, fontSize: 9),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (checkIn != null)
                      Text(
                        'In: $checkIn${checkOut != null ? '  ·  Out: $checkOut' : ''}',
                        style: const TextStyle(color: _muted, fontSize: 10),
                      ),
                  ],
                ),
              ),
              // Duration + ping count
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _fmt(workingMinutes),
                    style: const TextStyle(
                      color: _navy,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  if (pingCount > 0)
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 10,
                          color: _blue.withOpacity(.7),
                        ),
                        Text(
                          ' $pingCount',
                          style: const TextStyle(color: _muted, fontSize: 10),
                        ),
                      ],
                    )
                  else if (fieldSessions > 0)
                    Text(
                      '$fieldSessions session${fieldSessions > 1 ? 's' : ''}',
                      style: const TextStyle(color: _muted, fontSize: 10),
                    ),
                ],
              ),
                ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Route panel (map + ping timeline) ────────────────────────────────────

class _RoutePanel extends StatelessWidget {
  const _RoutePanel({
    required this.selectedDay,
    required this.routePoints,
    required this.routeLoading,
    required this.routeError,
    required this.onMapCreated,
  });

  final Map<String, dynamic>? selectedDay;
  final List<Map<String, dynamic>> routePoints;
  final bool routeLoading;
  final String? routeError;
  final MapCreatedCallback onMapCreated;

  @override
  Widget build(BuildContext context) {
    if (selectedDay == null) {
      return const Center(
        child: Text('Select a day to view GPS route', style: TextStyle(color: _muted)),
      );
    }

    final date = '${selectedDay!['date']}';
    final dateParsed = DateTime.tryParse(date);
    final dateLabel = dateParsed != null
        ? DateFormat('EEE, d MMM yyyy').format(dateParsed)
        : date;

    return Column(
      children: [
        // Day header bar
        Container(
          color: _surface,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              const Icon(Icons.route_rounded, color: _blue, size: 16),
              const SizedBox(width: 6),
              Text(
                dateLabel,
                style: const TextStyle(
                  color: _navy,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              if (routeLoading)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: _blue,
                  ),
                )
              else
                Text(
                  '${routePoints.length} pings',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
            ],
          ),
        ),
        Container(height: 1, color: _border),

        // Map
        Expanded(child: _buildMap()),

        // Ping timeline
        if (!routeLoading && routePoints.isNotEmpty)
          _PingTimeline(points: routePoints),
      ],
    );
  }

  Widget _buildMap() {
    if (routeLoading) {
      return const Center(child: CircularProgressIndicator(color: _blue));
    }
    if (routeError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            routeError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted),
          ),
        ),
      );
    }
    if (routePoints.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_rounded, color: _border, size: 40),
            SizedBox(height: 10),
            Text('No GPS data for this day', style: TextStyle(color: _muted)),
          ],
        ),
      );
    }

    // Build polyline + markers from route points
    final latLngs = routePoints
        .map((p) {
          final lat = double.tryParse('${p['latitude']}');
          final lng = double.tryParse('${p['longitude']}');
          return (lat != null && lng != null) ? LatLng(lat, lng) : null;
        })
        .whereType<LatLng>()
        .toList();

    final polylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        points: latLngs,
        color: _blue,
        width: 3,
      ),
    };

    final markers = <Marker>{};
    if (latLngs.isNotEmpty) {
      markers.add(
        Marker(
          markerId: const MarkerId('start'),
          position: latLngs.first,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Start'),
        ),
      );
      if (latLngs.length > 1) {
        markers.add(
          Marker(
            markerId: const MarkerId('end'),
            position: latLngs.last,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: const InfoWindow(title: 'End'),
          ),
        );
      }
    }

    final initialTarget = latLngs.isNotEmpty ? latLngs.first : const LatLng(0, 0);

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: initialTarget, zoom: 14),
      onMapCreated: onMapCreated,
      polylines: polylines,
      markers: markers,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
      mapToolbarEnabled: false,
    );
  }
}

// ── Ping timeline strip ───────────────────────────────────────────────────

class _PingTimeline extends StatelessWidget {
  const _PingTimeline({required this.points});
  final List<Map<String, dynamic>> points;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      color: _surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 1, color: _border),
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6, bottom: 4),
            child: Text(
              'PING TIMELINE',
              style: TextStyle(
                color: _muted.withOpacity(.7),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: .8,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: points.length,
              itemBuilder: (_, i) {
                final p = points[i];
                final timeStr = _parseTime('${p['recorded_at'] ?? p['recordedAt'] ?? ''}');
                final isFirst = i == 0;
                final isLast = i == points.length - 1;
                final dotColor = isFirst
                    ? _green
                    : isLast
                        ? _red
                        : _blue;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: isFirst || isLast ? 12 : 8,
                          height: isFirst || isLast ? 12 : 8,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: isFirst || isLast ? 2 : 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: dotColor.withOpacity(.3),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          timeStr,
                          style: const TextStyle(color: _muted, fontSize: 9),
                        ),
                      ],
                    ),
                    if (!isLast)
                      Container(
                        width: 28,
                        height: 1.5,
                        color: _blue.withOpacity(.25),
                        margin: const EdgeInsets.only(bottom: 14),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _parseTime(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('h:mm a').format(dt);
    } catch (_) {
      return raw.length >= 5 ? raw.substring(11, 16) : raw;
    }
  }
}

// ── Small reusable widgets ────────────────────────────────────────────────

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.07),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: Colors.white.withOpacity(.15)),
        ),
        child: Icon(
          icon,
          color: onTap != null
              ? Colors.white.withOpacity(.85)
              : Colors.white.withOpacity(.25),
          size: 18,
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.valueColor,
  });
  final String label, value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        color: Colors.white.withOpacity(.06),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(.45),
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: .5,
              ),
            ),
          ],
        ),
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _red, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: _blue),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
