import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AttendanceDashboard extends StatefulWidget {
  const AttendanceDashboard({super.key});

  @override
  State<AttendanceDashboard> createState() => _AttendanceDashboardState();
}

class _AttendanceDashboardState extends State<AttendanceDashboard> {
  DateTime selectedDate = DateTime(2026, 6, 15);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          // ── Left Sidebar ────────────────────────────────────────────────────
          _buildSidebar(),

          // ── Main Content ────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with date and export
                  _buildHeader(),
                  const SizedBox(height: 24),

                  // Metric Cards
                  _buildMetricCards(),
                  const SizedBox(height: 32),

                  // Charts and Activity Section
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Daily Attendance Chart
                      Expanded(
                        flex: 2,
                        child: _buildDailyAttendanceChart(),
                      ),
                      const SizedBox(width: 24),

                      // Department Status & Real-time Activity
                      Expanded(
                        child: Column(
                          children: [
                            _buildDepartmentStatus(),
                            const SizedBox(height: 24),
                            _buildRealTimeActivity(),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Pending Permissions
                  _buildPendingPermissions(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sidebar Widget ──────────────────────────────────────────────────────────

  Widget _buildSidebar() {
    final menuItems = [
      ('Dashboard', Icons.dashboard, true),
      ('Attendance', Icons.check_circle_outline, false),
      ('Calendar', Icons.calendar_today, false),
      ('Location Tracking', Icons.location_on_outlined, false),
      ('Permissions', Icons.shield_outlined, false),
      ('Payroll', Icons.receipt_outlined, false),
      ('Notifications', Icons.notifications_outlined, false),
      ('Reports', Icons.assessment_outlined, false),
      ('Settings', Icons.settings_outlined, false),
    ];

    return Container(
      width: 250,
      color: const Color(0xFF1A1F3A),
      child: Column(
        children: [
          // Logo/Title
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Attendance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Admin Panel',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Menu Items
          Expanded(
            child: ListView.builder(
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final (label, icon, isActive) = menuItems[index];
                return Container(
                  color: isActive ? Colors.blue[600] : Colors.transparent,
                  child: ListTile(
                    leading: Icon(
                      icon,
                      color: isActive ? Colors.white : Colors.grey,
                      size: 20,
                    ),
                    title: Text(
                      label,
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.grey,
                        fontSize: 13,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    onTap: () {
                      debugPrint('Tapped: $label');
                    },
                  ),
                );
              },
            ),
          ),

          // Log Out Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Log Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header with Date and Export ─────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard Overview',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Real-time enterprise attendance monitoring and analytics',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        Row(
          children: [
            // Date Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MMM dd, yyyy').format(selectedDate),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey[600]),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Export Button
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Export Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Metric Cards Widget ─────────────────────────────────────────────────────

  Widget _buildMetricCards() {
    final metrics = [
      {
        'label': 'TOTAL EMPLOYEES',
        'value': '100',
        'color': Colors.blue,
        'icon': Icons.people,
      },
      {
        'label': 'PRESENT TODAY',
        'value': '90',
        'color': Colors.green,
        'icon': Icons.check_circle,
      },
      {
        'label': 'LATE LOGINS',
        'value': '10',
        'color': Colors.orange,
        'icon': Icons.schedule,
      },
      {
        'label': 'ABSENT',
        'value': '5',
        'color': Colors.red,
        'icon': Icons.person_off,
      },
      {
        'label': 'WiFi',
        'value': '10',
        'color': Colors.purple,
        'icon': Icons.wifi,
      },
      {
        'label': 'PERMISSION PENDING',
        'value': '5',
        'color': Colors.grey,
        'icon': Icons.hourglass_empty,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: metrics.length,
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return _buildMetricCard(
          label: metric['label'] as String,
          value: metric['value'] as String,
          color: metric['color'] as Color,
          icon: metric['icon'] as IconData,
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Daily Attendance Chart ──────────────────────────────────────────────────

  Widget _buildDailyAttendanceChart() {
    final data = [
      {'day': 'Mon', 'height': 0.85},
      {'day': 'Tue', 'height': 0.90},
      {'day': 'Wed', 'height': 0.88},
      {'day': 'Thu', 'height': 0.92},
      {'day': 'Fri', 'height': 0.80},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Attendance Overview',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Weekly attendance trends across all departments',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          // Chart
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: data.map((d) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 40,
                    height: 120 * (d['height'] as double),
                    decoration: BoxDecoration(
                      color: Colors.blue[600],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    d['day'] as String,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Department Status ───────────────────────────────────────────────────────

  Widget _buildDepartmentStatus() {
    final departments = [
      {'name': 'Graphic Designer', 'percentage': 95, 'color': Colors.green},
      {'name': 'Sales & Marketing', 'percentage': 85, 'color': Colors.orange},
      {'name': 'Digital Marketing', 'percentage': 92, 'color': Colors.green},
      {'name': 'Videographer / Editor', 'percentage': 100, 'color': Colors.green},
      {'name': 'Web Designer / Developer', 'percentage': 78, 'color': Colors.red},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Department Status',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...departments.map((dept) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dept['name'] as String,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '${dept['percentage']}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: (dept['percentage'] as int) / 100,
                      minHeight: 6,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        dept['color'] as Color,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // ── Real-time Activity ──────────────────────────────────────────────────────

  Widget _buildRealTimeActivity() {
    final activities = [
      {
        'name': 'Sarah Smith',
        'action': 'requested Risk Leave',
        'time': '02:30 AM',
        'status': 'Pending',
        'icon': Icons.person,
        'color': Colors.red,
      },
      {
        'name': 'Michael Brown',
        'action': 'logged in (Late)',
        'time': '09:15 AM',
        'status': 'Log In',
        'icon': Icons.person,
        'color': Colors.green,
      },
      {
        'name': 'Rachel Miller',
        'action': 'Early Logged Out',
        'time': '06:15 AM',
        'status': 'Log Out',
        'icon': Icons.person,
        'color': Colors.blue,
      },
      {
        'name': 'John Davis',
        'action': 'logged in (WIFI)',
        'time': '01:50 AM',
        'status': 'Log In',
        'icon': Icons.person,
        'color': Colors.blue,
      },
      {
        'name': 'Sarah Smith',
        'action': 'requested Risk Leave',
        'time': '02:30 AM',
        'status': 'Pending',
        'icon': Icons.person,
        'color': Colors.red,
      },
      {
        'name': 'Michael Brown',
        'action': 'logged Out',
        'time': '06:45 PM',
        'status': 'Log Out',
        'icon': Icons.person,
        'color': Colors.grey,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Real-time Activity',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: Text(
                  'Filter ↓',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...activities.map((activity) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: (activity['color'] as Color).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      activity['icon'] as IconData,
                      size: 16,
                      color: activity['color'] as Color,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity['name'] as String,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          activity['action'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        activity['time'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        activity['status'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // ── Pending Permissions ─────────────────────────────────────────────────────

  Widget _buildPendingPermissions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pending Permissions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: Text(
                  'View All >',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Table headers
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Employee',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Type',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Date',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Table rows
          Divider(color: Colors.grey[200]),
          ...[
            {'emp': 'John Doe', 'type': 'Leave', 'date': '2026-06-15', 'status': 'Approved'},
            {'emp': 'Jane Smith', 'type': 'Late Entry', 'date': '2026-06-14', 'status': 'Pending'},
            {'emp': 'Mike Johnson', 'type': 'Early Exit', 'date': '2026-06-13', 'status': 'Rejected'},
          ].map((row) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      row['emp'] ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row['type'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row['date'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: row['status'] == 'Approved'
                            ? Colors.green.withValues(alpha: 0.1)
                            : row['status'] == 'Pending'
                                ? Colors.orange.withValues(alpha: 0.1)
                                : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        row['status'] ?? '',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: row['status'] == 'Approved'
                              ? Colors.green[700]
                              : row['status'] == 'Pending'
                                  ? Colors.orange[700]
                                  : Colors.red[700],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}