import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../services/hrms_tracking_api.dart';
import '../../services/attendance_api.dart';
import '../shared/employee_ui.dart';
import 'home_location_dialog.dart';

class EmployeeTrackingPage extends StatelessWidget {
  const EmployeeTrackingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final routeHistory =
        ModalRoute.of(context)?.settings.arguments == 'history';
    return EmployeeScaffold(
      route: '/employee/tracking',
      title: routeHistory ? 'Route History' : 'Live Tracking',
      subtitle: routeHistory
          ? 'Your recent travel routes'
          : 'Live employee location and today’s hybrid activity',
      desktop: _TrackingView(mobile: false, routeHistory: routeHistory),
      mobile: _TrackingView(mobile: true, routeHistory: routeHistory),
    );
  }
}

enum _WorkMode { office, home, field }

class _TrackingView extends StatefulWidget {
  const _TrackingView({required this.mobile, required this.routeHistory});
  final bool mobile;
  final bool routeHistory;

  @override
  State<_TrackingView> createState() => _TrackingViewState();
}

class _TrackingViewState extends State<_TrackingView> {
  _WorkMode mode = _WorkMode.office;
  String updated = 'Not tracking yet';
  bool trackingActive = false;
  bool _isHybridEmployee = false;
  Timer? _locationTimer;
  Timer? _waitingAlertTimer;
  Timer? _radiusHeartbeatTimer;
  StreamSubscription<Position>? _androidBackgroundLocationSubscription;
  Position? _lastPosition;
  Map<String, dynamic>? _homeLocation;
  Map<String, dynamic>? _officeSettings;
  bool _homeLoading = true;
  bool _officeLoading = true;
  bool _homeDialogOpen = false;
  String? _homeError;

  String distance = '—';
  String duration = '—';
  String avgSpeed = '—';

  List<dynamic> activities = [
    {
      'activity_time': '--:--',
      'activity_text': 'No live tracking activity yet',
    },
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFieldSession();
      _checkWaitingAlert();
      _loadHomeLocation();
      _loadOfficeSettings();
    });

    _waitingAlertTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkWaitingAlert(),
    );
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _waitingAlertTimer?.cancel();
    _radiusHeartbeatTimer?.cancel();
    _androidBackgroundLocationSubscription?.cancel();
    super.dispose();
  }

  void _startRadiusHeartbeat() {
    _radiusHeartbeatTimer?.cancel();
    final minutes = int.tryParse(
      '${_officeSettings?['field_ping_interval_minutes']}',
    );
    if (minutes == null || minutes < 1) return;
    _sendRadiusHeartbeat();
    _radiusHeartbeatTimer = Timer.periodic(
      Duration(minutes: minutes),
      (_) => _sendRadiusHeartbeat(),
    );
  }

  Future<void> _sendRadiusHeartbeat() async {
    try {
      final position = await _getCurrentPosition();
      await AttendanceApi.locationHeartbeat(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );
    } catch (_) {}
  }

  Future<void> _loadOfficeSettings() async {
    try {
      final settings = await HrmsTrackingApi.trackingSettings();
      if (!mounted) return;
      setState(() {
        _officeSettings = settings;
        _officeLoading = false;
      });
      _startRadiusHeartbeat();
      if (trackingActive) _startLocationTimer();
    } catch (_) {
      if (!mounted) return;
      setState(() => _officeLoading = false);
    }
  }

  Future<Position> _getCurrentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();

    if (!enabled) {
      throw Exception('Please turn on device location services.');
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission is required for live tracking.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<void> _loadHomeLocation() async {
    try {
      final home = await HrmsTrackingApi.myHomeLocation();
      if (!mounted) return;
      setState(() {
        _homeLocation = home;
        _homeLoading = false;
        _homeError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _homeLoading = false;
        _homeError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _openHomeLocation() async {
    if (_homeDialogOpen) return;
    setState(() => _homeDialogOpen = true);
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const HomeLocationDialog(),
      );
      if (mounted) await _loadHomeLocation();
    } finally {
      if (mounted) setState(() => _homeDialogOpen = false);
    }
  }

  Future<void> _loadFieldSession() async {
    try {
      final session = await HrmsTrackingApi.hybridSession();

      final active =
          session['is_active'] == 1 ||
          session['is_active'] == true ||
          session['isActive'] == true;

      if (!mounted) return;

      setState(() {
        _isHybridEmployee =
            session['isHybrid'] == true || session['is_hybrid'] == 1;
        trackingActive = active;

        if (active) {
          mode = _WorkMode.field;
          updated = 'Live tracking active';
        }
      });

      if (active) {
        _startLocationTimer();
        await _sendLocationPing(showMessage: false);
      }
    } catch (_) {
      // Office and Home employees may not have a Field tracking session.
    }
  }

  void _startLocationTimer() {
    _locationTimer?.cancel();

    final minutes = int.tryParse(
      '${_officeSettings?['field_ping_interval_minutes']}',
    );
    if (minutes == null || minutes < 1) return;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _startAndroidBackgroundTracking(minutes);
      return;
    }
    _locationTimer = Timer.periodic(Duration(minutes: minutes.clamp(1, 120)), (
      _,
    ) {
      _sendLocationPing(showMessage: false);
    });
  }

  Future<void> _sendLocationPing({required bool showMessage}) async {
    if (!trackingActive) return;

    try {
      final position = await _getCurrentPosition();
      await _sendPositionPing(position, showMessage: showMessage);
    } catch (error) {
      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  Future<void> _sendPositionPing(
    Position position, {
    required bool showMessage,
  }) async {
    if (!trackingActive) return;
    await HrmsTrackingApi.ping(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
    );
    if (!mounted) return;
    setState(() {
      _lastPosition = position;
      updated = 'Updated just now';
      activities = [
        {
          'activity_time': TimeOfDay.now().format(context),
          'activity_text': 'Live location updated',
        },
        ...activities.where(
          (item) => item['activity_text'] != 'No live tracking activity yet',
        ),
      ];
    });
    if (showMessage && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Live location refreshed.')));
    }
  }

  Future<void> _startAndroidBackgroundTracking(int intervalMinutes) async {
    await _androidBackgroundLocationSubscription?.cancel();
    if (!trackingActive ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.always) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Choose “Allow all the time” in Android location permission to keep Hybrid tracking active in the background.',
            ),
          ),
        );
      }
      return;
    }
    const notification = ForegroundNotificationConfig(
      notificationTitle: 'Go Digital HRMS tracking is active',
      notificationText: 'Your Hybrid work location is being updated.',
      enableWakeLock: true,
      setOngoing: true,
    );
    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      intervalDuration: Duration(minutes: intervalMinutes),
      foregroundNotificationConfig: notification,
    );
    _androidBackgroundLocationSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen((
          position,
        ) {
          _sendPositionPing(position, showMessage: false).catchError((_) {});
        });
  }

  Future<void> toggleTracking() async {
    try {
      final position = await _getCurrentPosition();

      if (!trackingActive) {
        await HrmsTrackingApi.startHybridSession(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
        );

        if (!mounted) return;

        setState(() {
          trackingActive = true;
          mode = _WorkMode.field;
          _lastPosition = position;
          updated = 'Updated just now';
          activities = [
            {
              'activity_time': TimeOfDay.now().format(context),
              'activity_text': 'Started live Hybrid tracking',
            },
          ];
        });

        _startLocationTimer();

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Live tracking started.')));
      } else {
        await HrmsTrackingApi.stopHybridSession(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
        );

        _locationTimer?.cancel();
        await _androidBackgroundLocationSubscription?.cancel();
        _androidBackgroundLocationSubscription = null;

        if (!mounted) return;

        setState(() {
          trackingActive = false;
          _lastPosition = position;
          updated = 'Live tracking stopped';
          activities = [
            {
              'activity_time': TimeOfDay.now().format(context),
              'activity_text': 'Stopped live Hybrid tracking',
            },
            ...activities,
          ];
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Live tracking stopped.')));
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  void refreshLocation() {
    _sendLocationPing(showMessage: true);
  }

  String get modeLabel => switch (mode) {
    _WorkMode.office => 'Office',
    _WorkMode.home => 'Home',
    _WorkMode.field => 'Hybrid',
  };

  String get address {
    if (mode == _WorkMode.office) {
      if (_officeLoading) return 'Loading office location...';
      final officeName = '${_officeSettings?['office_name'] ?? ''}'.trim();
      final officeAddress = '${_officeSettings?['office_address'] ?? ''}'
          .trim();
      if (officeName.isEmpty && officeAddress.isEmpty) {
        return 'Office location has not been configured by admin.';
      }
      return [
        officeName,
        officeAddress,
      ].where((value) => value.isNotEmpty).join('\n');
    }

    if (mode == _WorkMode.home) {
      if (_homeLoading) return 'Loading home location...';
      if (_homeError != null) return _homeError!;
      if (_homeLocation == null) {
        return 'Register your home location for admin approval';
      }
      final status = _homeLocation!['approval_status'];
      final description = switch (status) {
        'approved' => 'Approved home location',
        'pending' => 'Pending admin approval — Home Clock In unavailable',
        'rejected' => 'Home location rejected — update and resubmit',
        _ => 'Home location approval required',
      };
      return '$description\n'
          '${_homeLocation!['address'] ?? ''}\n'
          'GPS: ${_homeLocation!['latitude']}, ${_homeLocation!['longitude']}';
    }

    if (_lastPosition != null) {
      return 'Live GPS: '
          '${_lastPosition!.latitude.toStringAsFixed(6)}, '
          '${_lastPosition!.longitude.toStringAsFixed(6)}';
    }

    return 'Hybrid location will appear after live tracking starts';
  }

  Color get activeColor =>
      mode == _WorkMode.field ? employeeGreen : employeeBlue;

  @override
  Widget build(BuildContext context) {
    if (widget.routeHistory) {
      return _RouteHistoryView(mobile: widget.mobile);
    }

    final modes = _ModeTabs(
      selected: mode,
      homeEnabled: _officeSettings?['home_tracking_enabled'] != 0,
      onChanged: (value) => setState(() => mode = value),
    );

    final homeAction = OutlinedButton.icon(
      onPressed: _homeDialogOpen ? null : _openHomeLocation,
      icon: const Icon(Icons.add_home_outlined),
      label: Text(
        _homeLocation == null
            ? 'Register Home Location'
            : 'Manage Home Location',
      ),
    );

    final status = _CurrentStatusCard(
      mode: modeLabel,
      address: address,
      color: activeColor,
      onRefresh: mode == _WorkMode.office
          ? _loadOfficeSettings
          : mode == _WorkMode.home
          ? _loadHomeLocation
          : refreshLocation,
      action: mode == _WorkMode.home ? homeAction : null,
    );

    final map = _RouteMap(
      mode: mode,
      position: _lastPosition,
      homeLocation: _homeLocation,
      officeSettings: _officeSettings,
    );

    final metrics = _TripMetrics(
      distance: distance,
      duration: duration,
      avgSpeed: avgSpeed,
    );

    final timeline = _ActivityTimeline(activities: activities);

    final live = _LiveTrackingControl(
      active: trackingActive,
      onToggle: toggleTracking,
    );

    if (widget.mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MobileEmployeeHeader(),
          const SizedBox(height: 14),
          const EmployeePageTitle(title: 'Live Tracking'),
          const SizedBox(height: 18),
          modes,
          const SizedBox(height: 14),
          status,
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Live Location',
                  style: TextStyle(
                    color: employeeNavy,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(updated, style: const TextStyle(color: employeeMuted)),
            ],
          ),
          const SizedBox(height: 12),
          map,
          const SizedBox(height: 14),
          metrics,
          const SizedBox(height: 22),
          const Text(
            'Today’s Activity',
            style: TextStyle(
              color: employeeNavy,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          timeline,
          const SizedBox(height: 18),
          if (_isHybridEmployee) live,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        modes,
        const SizedBox(height: 18),
        status,
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Live Location',
                style: TextStyle(
                  color: employeeNavy,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(updated, style: const TextStyle(color: employeeMuted)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 7,
              child: Column(
                children: [map, const SizedBox(height: 14), metrics],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Today’s Activity',
                      style: TextStyle(
                        color: employeeNavy,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  timeline,
                  const SizedBox(height: 18),
                  if (_isHybridEmployee) live,
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _checkWaitingAlert() async {
    if (_homeDialogOpen) return;
    try {
      final alert = await HrmsTrackingApi.waitingAlert();

      debugPrint('Waiting alert response: $alert');

      if (!mounted || _homeDialogOpen || alert == null) return;

      final reasonId = int.tryParse('${alert['id']}');

      if (reasonId == null) {
        debugPrint('Waiting alert has no valid ID');
        return;
      }

      await _showWaitingReasonDialog(
        reasonId: reasonId,
        waitingMinutes: alert['waiting_minutes'] ?? 0,
      );
    } catch (error) {
      debugPrint('Waiting alert check failed: $error');
    }
  }

  Future<void> _showWaitingReasonDialog({
    required int reasonId,
    required dynamic waitingMinutes,
  }) async {
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hybrid waiting reason'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You have been at this location for $waitingMinutes minutes. '
                'Please enter the reason for waiting.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason for waiting',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                final reason = controller.text.trim();

                if (reason.isEmpty) return;

                try {
                  await HrmsTrackingApi.submitWaitingReason(
                    reasonId: reasonId,
                    reason: reason,
                  );

                  if (mounted) {
                    Navigator.of(context, rootNavigator: true).pop();
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Waiting reason submitted')),
                    );
                  }
                } catch (error) {
                  debugPrint('Waiting reason submit failed: $error');
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error.toString())));
                  }
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }
}

class _RouteHistoryView extends StatefulWidget {
  const _RouteHistoryView({required this.mobile});
  final bool mobile;

  @override
  State<_RouteHistoryView> createState() => _RouteHistoryViewState();
}

class _RouteHistoryViewState extends State<_RouteHistoryView> {
  DateTime _date = DateTime.now();
  bool _loading = true;
  Map<String, dynamic>? _route;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final route = await HrmsTrackingApi.myRoute(
        date: _date.toIso8601String().substring(0, 10),
      );
      if (mounted)
        setState(() {
          _route = route;
          _loading = false;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = error.toString().replaceFirst('Exception: ', '');
        });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = picked);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final raw = (_route?['routePoints'] as List? ?? [])
        .whereType<Map>()
        .map(
          (p) => LatLng(
            (p['latitude'] as num).toDouble(),
            (p['longitude'] as num).toDouble(),
          ),
        )
        .toList();
    final activities = (_route?['activities'] as List? ?? [])
        .whereType<Map>()
        .toList();
    final markers = <Marker>{
      if (raw.isNotEmpty)
        Marker(
          markerId: const MarkerId('start'),
          position: raw.first,
          infoWindow: const InfoWindow(title: 'S — Start'),
        ),
      if (raw.length > 1)
        Marker(
          markerId: const MarkerId('end'),
          position: raw.last,
          infoWindow: const InfoWindow(title: 'E — End'),
        ),
      ...raw
          .skip(1)
          .take(raw.length > 2 ? raw.length - 2 : 0)
          .map(
            (point) => Marker(
              markerId: MarkerId('${point.latitude},${point.longitude}'),
              position: point,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen,
              ),
            ),
          ),
    };
    final history = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Route History',
                style: TextStyle(
                  color: employeeNavy,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text('${_date.day}/${_date.month}/${_date.year}'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red))
        else if (raw.isEmpty)
          const EmployeeCard(
            padding: EdgeInsets.all(20),
            child: Text('No GPS route was recorded for the selected date'),
          )
        else ...[
          SizedBox(
            height: 280,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: raw.first,
                  zoom: 14,
                ),
                polylines: {
                  Polyline(
                    polylineId: const PolylineId('route'),
                    points: raw,
                    color: employeeBlue,
                    width: 5,
                  ),
                },
                markers: markers,
                mapToolbarEnabled: false,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _RouteHistoryCard(
            DateFormat('dd MMM yyyy').format(_date),
            '${((_route?['distanceMeters'] as num? ?? 0) / 1000).toStringAsFixed(2)} km · ${((_route?['averageSpeedKmh'] as num? ?? 0)).toStringAsFixed(1)} km/h',
            '${((_route?['durationSeconds'] as num? ?? 0) / 60).round()} min',
            '${activities.length} updates',
          ),
          for (final item in activities.take(8))
            ListTile(
              leading: const Icon(Icons.place_outlined, color: employeeBlue),
              title: Text('${item['placeName'] ?? 'Location pending'}'),
              subtitle: Text('${item['recordedAt'] ?? ''}'),
            ),
        ],
      ],
    );
    return widget.mobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MobileEmployeeHeader(),
              const SizedBox(height: 14),
              const EmployeePageTitle(title: 'Route History'),
              const SizedBox(height: 20),
              history,
            ],
          )
        : history;
  }
}

class _RouteHistoryCard extends StatelessWidget {
  const _RouteHistoryCard(this.date, this.route, this.distance, this.duration);
  final String date, route, distance, duration;

  @override
  Widget build(BuildContext context) => EmployeeCard(
    padding: const EdgeInsets.all(18),
    child: Row(
      children: [
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: const Color(0xFFE9F7F7),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(Icons.route_outlined, color: Color(0xFF079B9B)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                date,
                style: const TextStyle(
                  color: employeeNavy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                route,
                style: const TextStyle(color: employeeMuted, fontSize: 13),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              distance,
              style: const TextStyle(
                color: employeeNavy,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              duration,
              style: const TextStyle(color: employeeMuted, fontSize: 12),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ModeTabs extends StatelessWidget {
  const _ModeTabs({
    required this.selected,
    required this.homeEnabled,
    required this.onChanged,
  });
  final _WorkMode selected;
  final bool homeEnabled;
  final ValueChanged<_WorkMode> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _ModeTab(
        icon: Icons.business_outlined,
        label: 'Office',
        active: selected == _WorkMode.office,
        onTap: () => onChanged(_WorkMode.office),
      ),
      if (homeEnabled) ...[
        const SizedBox(width: 8),
        _ModeTab(
          icon: Icons.home_outlined,
          label: 'Home',
          active: selected == _WorkMode.home,
          onTap: () => onChanged(_WorkMode.home),
        ),
      ],
      const SizedBox(width: 8),
      _ModeTab(
        icon: Icons.person_outline_rounded,
        label: 'Hybrid',
        active: selected == _WorkMode.field,
        onTap: () => onChanged(_WorkMode.field),
      ),
    ],
  );
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Material(
      color: active ? employeeGreen : Colors.white,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: active ? employeeGreen : employeeLine),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: active ? Colors.white : employeeMuted,
                size: 25,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : employeeNavy,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CurrentStatusCard extends StatelessWidget {
  const _CurrentStatusCard({
    required this.mode,
    required this.address,
    required this.color,
    required this.onRefresh,
    this.action,
  });
  final String mode;
  final String address;
  final Color color;
  final VoidCallback onRefresh;
  final Widget? action;

  @override
  Widget build(BuildContext context) => EmployeeCard(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Current Status',
              style: TextStyle(
                color: employeeNavy,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(radius: 5, backgroundColor: color),
            const SizedBox(width: 7),
            Text(
              mode,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            const Text(
              'Since 09:20 AM',
              style: TextStyle(color: employeeMuted, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              color: employeeMuted,
              size: 30,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                address,
                style: const TextStyle(color: employeeMuted, height: 1.4),
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: 12),
              action!,
            ],
            IconButton.outlined(
              tooltip: 'Refresh live location',
              onPressed: onRefresh,
              icon: const Icon(
                Icons.refresh_rounded,
                color: employeeBlue,
                size: 27,
              ),
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(11),
                side: const BorderSide(color: employeeLine),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _RouteMap extends StatelessWidget {
  const _RouteMap({
    required this.mode,
    required this.position,
    this.homeLocation,
    this.officeSettings,
  });

  final _WorkMode mode;
  final Position? position;
  final Map<String, dynamic>? homeLocation;
  final Map<String, dynamic>? officeSettings;

  @override
  Widget build(BuildContext context) {
    final livePoint = position == null
        ? null
        : LatLng(position!.latitude, position!.longitude);

    final homeLat = double.tryParse('${homeLocation?['latitude']}');
    final homeLng = double.tryParse('${homeLocation?['longitude']}');
    final homePoint = homeLat != null && homeLng != null
        ? LatLng(homeLat, homeLng)
        : null;
    final officeLat = double.tryParse('${officeSettings?['office_latitude']}');
    final officeLng = double.tryParse('${officeSettings?['office_longitude']}');
    final officePoint = officeLat != null && officeLng != null
        ? LatLng(officeLat, officeLng)
        : const LatLng(20.5937, 78.9629);
    final officeName = '${officeSettings?['office_name'] ?? 'Office'}';

    final center = mode == _WorkMode.field && livePoint != null
        ? livePoint
        : mode == _WorkMode.home && homePoint != null
        ? homePoint
        : officePoint;

    final markerColor = mode == _WorkMode.field
        ? BitmapDescriptor.hueRed
        : mode == _WorkMode.home
        ? BitmapDescriptor.hueGreen
        : BitmapDescriptor.hueAzure;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 1.95,
        child: GoogleMap(
          key: ValueKey(
            'tracking-map-${mode.name}-${officePoint.latitude}-${officePoint.longitude}-${homePoint?.latitude}-${homePoint?.longitude}',
          ),
          initialCameraPosition: CameraPosition(
            target: center,
            zoom: mode == _WorkMode.field && livePoint != null ? 16 : 15,
          ),
          mapToolbarEnabled: false,
          markers: {
            Marker(
              markerId: const MarkerId('office'),
              position: officePoint,
              infoWindow: InfoWindow(title: officeName),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
            ),
            if (mode == _WorkMode.home && homePoint != null)
              Marker(
                markerId: const MarkerId('registered-home'),
                position: homePoint,
                infoWindow: InfoWindow(
                  title: 'Registered Home',
                  snippet: '${homeLocation?['approval_status'] ?? ''}',
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                ),
              ),
            if (mode == _WorkMode.field && livePoint != null)
              Marker(
                markerId: const MarkerId('live-location'),
                position: livePoint,
                infoWindow: const InfoWindow(title: 'Your Live Location'),
                icon: BitmapDescriptor.defaultMarkerWithHue(markerColor),
              ),
          },
        ),
      ),
    );
  }
}

class _TripMetrics extends StatelessWidget {
  const _TripMetrics({
    required this.distance,
    required this.duration,
    required this.avgSpeed,
  });

  final String distance;
  final String duration;
  final String avgSpeed;

  @override
  Widget build(BuildContext context) => EmployeeCard(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
    child: Row(
      children: [
        Expanded(
          child: _TripMetric(
            Icons.route_outlined,
            'Distance Travelled',
            distance,
            employeeGreen,
          ),
        ),
        const SizedBox(height: 66, child: VerticalDivider(color: employeeLine)),
        Expanded(
          child: _TripMetric(
            Icons.schedule_rounded,
            'Duration',
            duration,
            employeeBlue,
          ),
        ),
        const SizedBox(height: 66, child: VerticalDivider(color: employeeLine)),
        Expanded(
          child: _TripMetric(
            Icons.speed_rounded,
            'Avg Speed',
            avgSpeed,
            employeeGreen,
          ),
        ),
      ],
    ),
  );
}

class _TripMetric extends StatelessWidget {
  const _TripMetric(this.icon, this.label, this.value, this.color);
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: color, size: 27),
      const SizedBox(height: 7),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(color: employeeMuted, fontSize: 10),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        maxLines: 1,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: employeeNavy,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _ActivityTimeline extends StatelessWidget {
  const _ActivityTimeline({required this.activities});
  final List<dynamic> activities;

  @override
  Widget build(BuildContext context) => EmployeeCard(
    padding: const EdgeInsets.all(18),
    child: Column(
      children: activities.asMap().entries.map((entry) {
        final idx = entry.key;
        final item = entry.value;
        final timeStr = item['activity_time']?.toString() ?? '--:--';
        final textStr = item['activity_text']?.toString() ?? '';
        final isLast = idx == activities.length - 1;

        return Column(
          children: [
            _TimelineRow(timeStr, textStr),
            if (!isLast) const Divider(indent: 42, color: employeeLine),
          ],
        );
      }).toList(),
    ),
  );
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow(this.time, this.label);
  final String time;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        const CircleAvatar(
          radius: 14,
          backgroundColor: employeeGreen,
          child: Icon(Icons.check, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 78,
          child: Text(
            time,
            style: const TextStyle(
              color: employeeNavy,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(label, style: const TextStyle(color: employeeMuted)),
        ),
      ],
    ),
  );
}

class _LiveTrackingControl extends StatelessWidget {
  const _LiveTrackingControl({required this.active, required this.onToggle});
  final bool active;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: active ? const Color(0xFFEAF9F4) : const Color(0xFFF5F7FB),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: active ? const Color(0xFFCAEDE1) : employeeLine,
      ),
    ),
    child: Column(
      children: [
        Text(
          active ? '●  Live tracking active' : 'Live tracking is off',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? employeeGreen : employeeMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: onToggle,
          icon: Icon(
            active ? Icons.stop_circle_outlined : Icons.play_circle_outline,
          ),
          label: Text(active ? 'Stop Live Tracking' : 'Start Live Tracking'),
          style: FilledButton.styleFrom(
            backgroundColor: active ? const Color(0xFFD84343) : employeeGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
        ),
      ],
    ),
  );
}
