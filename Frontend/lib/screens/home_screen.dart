import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:godigital_portal/services/auth_service.dart';
import 'package:godigital_portal/screens/Attentance_admin/attendance_dashboard.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color primaryColor = Color(0xFF1A3A8F);
  static const Color secondaryColor = Color(0xFF2A52BE);
  static const Color darkColor = Color(0xFF1A1A2E);
  static const Color backgroundColor = Color(0xFFF7F8FC);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onAfterLogin();
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // AFTER LOGIN
  // ═══════════════════════════════════════════════════════════════

  Future<void> _onAfterLogin() async {
    if (!mounted) return;

    final authService = context.read<AuthService>();

    debugPrint('✅ HomeScreen Initialized');
    debugPrint('👤 User Type: ${authService.userType}');
    debugPrint('👤 User Role: ${authService.userRole}');
  }

  // ═══════════════════════════════════════════════════════════════
  // TASK MANAGER
  // ═══════════════════════════════════════════════════════════════

  void _openTaskManager() {
    final authService = context.read<AuthService>();

    final userType =
        authService.userType?.toLowerCase().trim() ?? '';

    final role =
        authService.userRole?.toLowerCase().trim() ?? '';

    debugPrint('User Type: $userType');
    debugPrint('Role: $role');

    // ADMIN
    if (userType == 'admin') {
      Navigator.pushNamed(context, '/admin');
      return;
    }

    // DESIGNER / WEB
    if (role.contains('ui') ||
        role.contains('ux') ||
        role.contains('graphic') ||
        role.contains('designer') ||
        role.contains('web')) {
      Navigator.pushNamed(context, '/designer');
      return;
    }

    // VIDEO
    if (role.contains('video') ||
        role.contains('editor')) {
      Navigator.pushNamed(context, '/videographer');
      return;
    }

    // ADS / DIGITAL
    if (role.contains('ads') ||
        role.contains('digital')) {
      Navigator.pushNamed(context, '/adsHandler');
      return;
    }

    // PAGE
    if (role.contains('page')) {
      Navigator.pushNamed(context, '/pageHandler');
      return;
    }

    // DEFAULT EMPLOYEE
    Navigator.pushNamed(context, '/employee');
  }

  // ═══════════════════════════════════════════════════════════════
  // ATTENDANCE
  // ═══════════════════════════════════════════════════════════════

  void _openAttendance() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AttendanceDashboard(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // CLIENT REPOSITORY
  // ═══════════════════════════════════════════════════════════════

  void _openClientRepository() {
    debugPrint('📁 Opening Client Work Repository');

    Navigator.pushNamed(
      context,
      '/client-work-repository',
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            if (width >= 1000) {
              return _buildDesktopLayout();
            }

            if (width >= 650) {
              return _buildTabletLayout();
            }

            return _buildMobileLayout();
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // DESKTOP
  // ═══════════════════════════════════════════════════════════════

  Widget _buildDesktopLayout() {
    return Column(
      children: [
        _buildTopBar(),

        const Divider(
          height: 1,
          thickness: 1,
          color: Color(0xFFE5E7EB),
        ),

        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 1150,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 45,
                  vertical: 35,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: _buildWelcomeSection(),
                    ),

                    const SizedBox(width: 60),

                    Expanded(
                      flex: 6,
                      child: _buildMenuSection(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        _buildFooter(),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TABLET
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTabletLayout() {
    return Column(
      children: [
        _buildTopBar(),

        const Divider(
          height: 1,
          thickness: 1,
          color: Color(0xFFE5E7EB),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 35,
              vertical: 30,
            ),
            child: Column(
              children: [
                _buildWelcomeSection(),

                const SizedBox(height: 35),

                _buildMenuSection(),
              ],
            ),
          ),
        ),

        _buildFooter(),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // MOBILE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildTopBar(),

        const Divider(
          height: 1,
          thickness: 1,
          color: Color(0xFFE5E7EB),
        ),

        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              20,
              28,
              20,
              25,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMobileWelcome(),

                const SizedBox(height: 30),

                _buildMenuSection(),
              ],
            ),
          ),
        ),

        _buildFooter(),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TOP BAR
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 14,
      ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.asset(
              'assets/images/godigital_logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) {
                return const Icon(
                  Icons.grid_view_rounded,
                  color: primaryColor,
                );
              },
            ),
          ),

          const SizedBox(width: 11),

          const Text(
            'GoDigital Portal',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: darkColor,
            ),
          ),

          const Spacer(),

          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Support clicked'),
                ),
              );
            },
            child: const Text(
              'Support',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF555555),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // DESKTOP WELCOME
  // ═══════════════════════════════════════════════════════════════

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(38),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE2E5EC),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLogo(),

          const SizedBox(height: 28),

          const Text(
            'Welcome to',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF777777),
            ),
          ),

          const SizedBox(height: 5),

          const Text(
            'GO DIGITAL',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: darkColor,
              letterSpacing: 1,
            ),
          ),

          const SizedBox(height: 10),

          const Text(
            'WE BUILD TECHNOLOGIES',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: secondaryColor,
              letterSpacing: 1.8,
            ),
          ),

          const SizedBox(height: 25),

          Container(
            height: 1,
            width: 70,
            color: const Color(0xFFD9DDE8),
          ),

          const SizedBox(height: 22),

          const Text(
            'Access your workspace, manage tasks,\nand stay connected with your team.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: Color(0xFF777777),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // MOBILE WELCOME
  // ═══════════════════════════════════════════════════════════════

  Widget _buildMobileWelcome() {
    return Column(
      children: [
        _buildLogo(size: 110),

        const SizedBox(height: 18),

        const Text(
          'Welcome to GoDigital',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: darkColor,
          ),
        ),

        const SizedBox(height: 7),

        const Text(
          'Your workspace at one place',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF777777),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // LOGO
  // ═══════════════════════════════════════════════════════════════

  Widget _buildLogo({
    double size = 145,
  }) {
    return Container(
      height: size,
      width: size,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Image.asset(
        'assets/images/godigital_logo.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) {
          return const Icon(
            Icons.business,
            size: 70,
            color: secondaryColor,
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // MENU SECTION
  // ═══════════════════════════════════════════════════════════════

  Widget _buildMenuSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Workspace',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: darkColor,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'Choose where you want to continue.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF888888),
          ),
        ),

        const SizedBox(height: 20),

        _MenuButton(
          icon: Icons.people_alt_outlined,
          label: 'Attendance',
          description: 'Manage attendance and employee records',
          onPressed: _openAttendance,
        ),

        const SizedBox(height: 14),

        _MenuButton(
          icon: Icons.assignment_outlined,
          label: 'Task Manager',
          description: 'View and manage your assigned tasks',
          onPressed: _openTaskManager,
        ),

        const SizedBox(height: 14),

        _MenuButton(
          icon: Icons.folder_open_outlined,
          label: 'Client Work Repository',
          description: 'Access client projects and work files',
          onPressed: _openClientRepository,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FOOTER
  // ═══════════════════════════════════════════════════════════════

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 14,
      ),
      child: Text(
        '© ${DateTime.now().year} GoDigital Portal',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF999999),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// MENU BUTTON
// ═════════════════════════════════════════════════════════════════

class _MenuButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onPressed;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.description,
    required this.onPressed,
  });

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          isHovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          isHovered = false;
        });
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 17,
          ),
          decoration: BoxDecoration(
            color: isHovered
                ? const Color(0xFFF3F6FF)
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isHovered
                  ? const Color(0xFF2A52BE)
                  : const Color(0xFFE1E4EA),
              width: isHovered ? 1.5 : 1,
            ),
            boxShadow: isHovered
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.025),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // ICON
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: isHovered
                      ? const Color(0xFFE3EAFF)
                      : const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  widget.icon,
                  size: 24,
                  color: const Color(0xFF2A52BE),
                ),
              ),

              const SizedBox(width: 15),

              // TEXT
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isHovered
                            ? const Color(0xFF1A3A8F)
                            : const Color(0xFF222222),
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      widget.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.3,
                        color: Color(0xFF888888),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // ARROW
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 30,
                width: 30,
                decoration: BoxDecoration(
                  color: isHovered
                      ? const Color(0xFF2A52BE)
                      : const Color(0xFFF3F4F7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: isHovered
                      ? Colors.white
                      : const Color(0xFF777777),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}