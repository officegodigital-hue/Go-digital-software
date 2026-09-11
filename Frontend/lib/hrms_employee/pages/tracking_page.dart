import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';



import '../../services/hrms_tracking_api.dart';
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
          : 'Live employee location and today’s field activity',
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
  Timer? _locationTimer;
  Timer? _waitingAlertTimer;
  Position? _lastPosition;
  Map<String, dynamic>? _homeLocation;
  bool _homeLoading = true;
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
    super.dispose();
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
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
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
      final session = await HrmsTrackingApi.fieldSession();

      final active = session['is_active'] == 1 ||
          session['is_active'] == true ||
          session['isActive'] == true;

      if (!mounted) return;

      setState(() {
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

    _locationTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) {
        _sendLocationPing(showMessage: false);
      },
    );
  }

  Future<void> _sendLocationPing({
    required bool showMessage,
  }) async {
    if (!trackingActive) return;

    try {
      final position = await _getCurrentPosition();

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Live location refreshed.')),
        );
      }
    } catch (error) {
      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.toString().replaceFirst('Exception: ', ''),
            ),
          ),
        );
      }
    }
  }

  Future<void> toggleTracking() async {
    try {
      final position = await _getCurrentPosition();

      if (!trackingActive) {
        await HrmsTrackingApi.startFieldSession(
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
              'activity_text': 'Started live Field tracking',
            },
          ];
        });

        _startLocationTimer();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Live tracking started.')),
        );
      } else {
        await HrmsTrackingApi.stopFieldSession(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
        );

        _locationTimer?.cancel();

        if (!mounted) return;

        setState(() {
          trackingActive = false;
          _lastPosition = position;
          updated = 'Live tracking stopped';
          activities = [
            {
              'activity_time': TimeOfDay.now().format(context),
              'activity_text': 'Stopped live Field tracking',
            },
            ...activities,
          ];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Live tracking stopped.')),
        );
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
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
        _WorkMode.field => 'Field',
      };

  String get address {
    if (mode == _WorkMode.office) {
      return 'No. 14, Udhayasuriyan Nagar\nGuduvancheri, Tamil Nadu 603202';
    }

    if (mode == _WorkMode.home) {
      if (_homeLoading) return 'Loading home location...';
      if (_homeError != null) return _homeError!;
      if (_homeLocation == null) return 'Register your home location for admin approval';
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

    return 'Field location will appear after live tracking starts';
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
      onChanged: (value) => setState(() => mode = value),
    );

    final status = _CurrentStatusCard(
      mode: modeLabel,
      address: address,
      color: activeColor,
      onRefresh: mode == _WorkMode.home ? _loadHomeLocation : refreshLocation,
    );

    final map = _RouteMap(
  mode: mode,
  position: _lastPosition,
  homeLocation: _homeLocation,);

    final homeAction = Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: _homeDialogOpen ? null : _openHomeLocation,
        icon: const Icon(Icons.add_home_outlined),
        label: Text(_homeLocation == null
            ? 'Register Home Location'
            : 'Manage Home Location'),
      ),
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
          if (mode == _WorkMode.home) ...[
            const SizedBox(height: 12),
            homeAction,
          ],
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
          live,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        modes,
        const SizedBox(height: 18),
        status,
        if (mode == _WorkMode.home) ...[
          const SizedBox(height: 12),
          homeAction,
        ],
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
                children: [
                  map,
                  const SizedBox(height: 14),
                  metrics,
                ],
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
                  live,
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
        title: const Text('Field waiting reason'),
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
                    const SnackBar(
                      content: Text('Waiting reason submitted'),
                    ),
                  );
                }
              } catch (error) {
                debugPrint('Waiting reason submit failed: $error');
                if (mounted) {
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error.toString())),
                  );
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

class _RouteHistoryView extends StatelessWidget {
  const _RouteHistoryView({required this.mobile});
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final history = const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Recent Routes',
          style: TextStyle(
              color: employeeNavy, fontSize: 20, fontWeight: FontWeight.w800)),
      SizedBox(height: 12),
      _RouteHistoryCard(
          'Today', 'Sector 62 → Sector 63 → Sector 62', '18.6 km', '01h 48m'),
      SizedBox(height: 12),
      _RouteHistoryCard('22 Aug 2026',
          'Noida Office → Sector 18 → Noida Office', '12.4 km', '01h 12m'),
      SizedBox(height: 12),
      _RouteHistoryCard(
          '21 Aug 2026', 'Noida Office → Greater Noida', '24.1 km', '02h 06m'),
    ]);
    return mobile
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const MobileEmployeeHeader(),
            const SizedBox(height: 14),
            const EmployeePageTitle(title: 'Route History'),
            const SizedBox(height: 20),
            history
          ])
        : history;
  }
}

class _RouteHistoryCard extends StatelessWidget {
  const _RouteHistoryCard(this.date, this.route, this.distance, this.duration);
  final String date, route, distance, duration;

  @override
  Widget build(BuildContext context) => EmployeeCard(
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
                color: const Color(0xFFE9F7F7),
                borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.route_outlined, color: Color(0xFF079B9B)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date,
                    style: const TextStyle(
                        color: employeeNavy, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(route,
                    style: const TextStyle(color: employeeMuted, fontSize: 13)),
              ],
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(distance,
                style: const TextStyle(
                    color: employeeNavy, fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text(duration,
                style: const TextStyle(color: employeeMuted, fontSize: 12)),
          ]),
        ]),
      );
}

class _ModeTabs extends StatelessWidget {
  const _ModeTabs({required this.selected, required this.onChanged});
  final _WorkMode selected;
  final ValueChanged<_WorkMode> onChanged;

  @override
  Widget build(BuildContext context) => Row(children: [
        _ModeTab(
          icon: Icons.business_outlined,
          label: 'Office',
          active: selected == _WorkMode.office,
          onTap: () => onChanged(_WorkMode.office),
        ),
        const SizedBox(width: 8),
        _ModeTab(
          icon: Icons.home_outlined,
          label: 'Home',
          active: selected == _WorkMode.home,
          onTap: () => onChanged(_WorkMode.home),
        ),
        const SizedBox(width: 8),
        _ModeTab(
          icon: Icons.person_outline_rounded,
          label: 'Field',
          active: selected == _WorkMode.field,
          onTap: () => onChanged(_WorkMode.field),
        ),
      ]);
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
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon,
                    color: active ? Colors.white : employeeMuted, size: 25),
                const SizedBox(width: 7),
                Text(label,
                    style: TextStyle(
                        color: active ? Colors.white : employeeNavy,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ]),
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
  });
  final String mode;
  final String address;
  final Color color;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => EmployeeCard(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Current Status',
                style: TextStyle(
                    color: employeeNavy,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(width: 12),
            CircleAvatar(radius: 5, backgroundColor: color),
            const SizedBox(width: 7),
            Text(mode,
                style: TextStyle(
                    color: color, fontSize: 18, fontWeight: FontWeight.w700)),
            const Spacer(),
            const Text('Since 09:20 AM',
                style: TextStyle(color: employeeMuted, fontSize: 13)),
          ]),
          const SizedBox(height: 22),
          Row(children: [
            const Icon(Icons.location_on_outlined,
                color: employeeMuted, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Text(address,
                  style: const TextStyle(color: employeeMuted, height: 1.4)),
            ),
            IconButton.outlined(
              tooltip: 'Refresh live location',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded,
                  color: employeeBlue, size: 27),
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(11),
                side: const BorderSide(color: employeeLine),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ]),
        ]),
      );
}

class _RouteMap extends StatelessWidget {
  const _RouteMap({
    required this.mode,
    required this.position,
    this.homeLocation,
  });

  final _WorkMode mode;
  final Position? position;
  final Map<String, dynamic>? homeLocation;

  static const _officePoint = LatLng(
    12.8542438,
    80.0699862,
  );

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

    final center = mode == _WorkMode.field && livePoint != null
        ? livePoint
        : mode == _WorkMode.home && homePoint != null
            ? homePoint
            : _officePoint;

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
          key: ValueKey('tracking-map-${mode.name}-${homePoint?.latitude}-${homePoint?.longitude}'),
          initialCameraPosition: CameraPosition(
            target: center,
            zoom: mode == _WorkMode.field && livePoint != null ? 16 : 15,
          ),
          mapToolbarEnabled: false,
          markers: {
            Marker(
              markerId: const MarkerId('office'),
              position: _officePoint,
              infoWindow: const InfoWindow(title: 'Go Digital Office'),
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
        child: Row(children: [
          Expanded(
            child: _TripMetric(
                Icons.route_outlined, 'Distance Travelled', distance, employeeGreen),
          ),
          const SizedBox(height: 66, child: VerticalDivider(color: employeeLine)),
          Expanded(
            child: _TripMetric(
                Icons.schedule_rounded, 'Duration', duration, employeeBlue),
          ),
          const SizedBox(height: 66, child: VerticalDivider(color: employeeLine)),
          Expanded(
            child: _TripMetric(
                Icons.speed_rounded, 'Avg Speed', avgSpeed, employeeGreen),
          ),
        ]),
      );
}

class _TripMetric extends StatelessWidget {
  const _TripMetric(this.icon, this.label, this.value, this.color);
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(children: [
        Icon(icon, color: color, size: 27),
        const SizedBox(height: 7),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: employeeMuted, fontSize: 10)),
        const SizedBox(height: 4),
        Text(value,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: employeeNavy,
                fontSize: 17,
                fontWeight: FontWeight.w800)),
      ]);
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
        child: Row(children: [
          const CircleAvatar(
            radius: 14,
            backgroundColor: employeeGreen,
            child: Icon(Icons.check, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 78,
            child: Text(time,
                style: const TextStyle(
                    color: employeeNavy, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Text(label, style: const TextStyle(color: employeeMuted)),
          ),
        ]),
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
        child: Column(children: [
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
              backgroundColor:
                  active ? const Color(0xFFD84343) : employeeGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
          ),
        ]),
      );
}
