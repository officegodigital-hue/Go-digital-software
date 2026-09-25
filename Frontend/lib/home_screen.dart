// lib/home_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:godigital_portal/services/auth_service.dart';
import 'package:godigital_portal/services/api_config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  static const Color primaryColor = Color(0xFF0A5BFF);
  static const Color secondaryColor = Color(0xFF2D8CFF);
  static const Color darkColor = Color(0xFF101936);
  static const Color backgroundColor = Color(0xFFF6F9FF);
  static const Color borderBlue = Color(0xFFD8E7FF);

  late final AnimationController _pageController;
  late final AnimationController _pulseController;
  late final Animation<double> _pageFade;
  late final Animation<Offset> _pageSlide;
  late final Animation<double> _pulse;

  bool? _hasRepoAccess;

  @override
  void initState() {
    super.initState();

    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _pageFade = CurvedAnimation(
      parent: _pageController,
      curve: Curves.easeOutCubic,
    );
    _pageSlide = Tween<Offset>(
      begin: const Offset(0, 0.025),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _pageController,
      curve: Curves.easeOutCubic,
    ));
    _pulse = Tween<double>(begin: 0.975, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pageController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onAfterLogin();
      _checkRepoAccess();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkRepoAccess() async {
    final auth = context.read<AuthService>();
    final userType = auth.userType?.toLowerCase().trim() ?? '';

    if (userType == 'admin') {
      if (mounted) setState(() => _hasRepoAccess = true);
      return;
    }

    final token = auth.token;
    if (token == null || token.isEmpty) {
      if (mounted) setState(() => _hasRepoAccess = false);
      return;
    }

    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/client-repository/permissions/me'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>? ?? {};
        final canView = data['can_view'] == true || data['can_view'] == 1;
        setState(() => _hasRepoAccess = canView);
      } else {
        setState(() => _hasRepoAccess = false);
      }
    } catch (_) {
      if (mounted) setState(() => _hasRepoAccess = false);
    }
  }

  Future<void> _onAfterLogin() async {
    if (!mounted) return;
    final authService = context.read<AuthService>();
    debugPrint('✅ HomeScreen Initialized');
    debugPrint('👤 User Type: ${authService.userType}');
    debugPrint('👤 User Role: ${authService.userRole}');
  }

  void _openTaskManager() {
    final authService = context.read<AuthService>();
    final userType = authService.userType?.toLowerCase().trim() ?? '';
    final role = authService.userRole?.toLowerCase().trim() ?? '';

    if (userType == 'admin') {
      Navigator.pushNamed(context, '/admin');
      return;
    }

    if (role.contains('ui') ||
        role.contains('ux') ||
        role.contains('graphic') ||
        role.contains('designer') ||
        role.contains('web')) {
      Navigator.pushNamed(context, '/designer');
      return;
    }

    if (role.contains('video') || role.contains('editor')) {
      Navigator.pushNamed(context, '/videographer');
      return;
    }

    if (role.contains('ads') || role.contains('digital')) {
      Navigator.pushNamed(context, '/adsHandler');
      return;
    }

    if (role.contains('page')) {
      Navigator.pushNamed(context, '/pageHandler');
      return;
    }

    Navigator.pushNamed(context, '/employee');
  }

  void _openAttendance() {
    final userType =
        context.read<AuthService>().userType?.toLowerCase().trim() ?? '';

    Navigator.pushNamed(
      context,
      userType == 'admin' ? '/attendance' : '/employee/dashboard',
    );
  }

  void _openClientRepository() {
    if (_hasRepoAccess == false) return;
    Navigator.pushNamed(context, '/client-work-repository');
  }

  Future<void> _logout() async {
    await context.read<AuthService>().logout();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: _HomeBackground()),
            Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: FadeTransition(
                    opacity: _pageFade,
                    child: SlideTransition(
                      position: _pageSlide,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          return SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              width < 650 ? 18 : 32,
                              width < 650 ? 12 : 18,
                              width < 650 ? 18 : 32,
                              12,
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 1040),
                                child: _buildMainContent(width),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                _buildFooter(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final compact = MediaQuery.sizeOf(context).width < 600;

    return Container(
      margin: EdgeInsets.fromLTRB(compact ? 12 : 24, 10, compact ? 12 : 24, 0),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 22,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderBlue),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5E8FD8).withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: compact ? 38 : 42,
            width: compact ? 38 : 42,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset(
              'assets/images/godigital_logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.grid_view_rounded,
                color: primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GoDigital Portal',
                style: TextStyle(
                  fontSize: compact ? 14 : 16,
                  fontWeight: FontWeight.w800,
                  color: darkColor,
                  letterSpacing: -0.3,
                ),
              ),
              if (!compact)
                const Text(
                  'WORKSPACE CONTROL CENTER',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                    letterSpacing: 1.5,
                  ),
                ),
            ],
          ),
          const Spacer(),
          if (!compact)
            TextButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Support clicked')),
                );
              },
              icon: const Icon(Icons.support_agent_rounded, size: 17),
              label: const Text('Support'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1D4FA5),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, size: 16),
            label: compact ? const SizedBox.shrink() : const Text('Logout'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1D4FA5),
              side: const BorderSide(color: Color(0xFFD2E2FF)),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: Size(compact ? 42 : 0, 40),
              padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(double width) {
    final mobile = width < 650;
    final tablet = width >= 650 && width < 980;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHero(mobile: mobile, tablet: tablet),
        SizedBox(height: mobile ? 16 : tablet ? 20 : 18),
        _buildWorkspace(mobile: mobile, tablet: tablet),
      ],
    );
  }

  Widget _buildHero({required bool mobile, required bool tablet}) {
    final logoSize = mobile ? 95.0 : tablet ? 115.0 : 130.0;
    final titleSize = mobile ? 30.0 : tablet ? 38.0 : 42.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _pulse,
          child: Container(
            height: logoSize,
            width: logoSize,
            padding: EdgeInsets.all(mobile ? 8 : 10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFB8D4FF),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2D8CFF).withValues(alpha: 0.14),
                  blurRadius: 28,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/godigital_logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(
                Icons.business_rounded,
                size: logoSize * 0.46,
                color: primaryColor,
              ),
            ),
          ),
        ),
        SizedBox(height: mobile ? 8 : 10),
        Text(
          'GoDigital',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.w800,
            color: darkColor,
            letterSpacing: -1.8,
            height: 0.98,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'WORKSPACE CONTROL CENTER',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: mobile ? 8 : 9.5,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF72A8FF),
            letterSpacing: mobile ? 2.0 : 3.2,
          ),
        ),
        SizedBox(height: mobile ? 10 : 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 1,
              width: mobile ? 24 : 40,
              color: const Color(0xFFBCD4FF),
            ),
            const SizedBox(width: 8),
            Text(
              'Welcome to Go Digital',
              style: TextStyle(
                fontSize: mobile ? 14 : 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF173A7A),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 1,
              width: mobile ? 24 : 40,
              color: const Color(0xFFBCD4FF),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Access your workspace, manage tasks, and stay connected with your team.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: mobile ? 10.5 : 12,
            height: 1.35,
            color: const Color(0xFF7084A5),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkspace({required bool mobile, required bool tablet}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final gap = mobile ? 10.0 : 14.0;
            final cardWidth = mobile
                ? constraints.maxWidth
                : tablet
                    ? (constraints.maxWidth - gap) / 2
                    : (constraints.maxWidth - (gap * 2)) / 3;

            return Wrap(
              alignment: WrapAlignment.center,
              spacing: gap,
              runSpacing: gap,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _MenuButton(
                    icon: Icons.assignment_outlined,
                    label: 'Task Manager',
                    description: 'View and manage your assigned tasks.',
                    onPressed: _openTaskManager,
                    accent: const Color(0xFF1769E0),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _MenuButton(
                    icon: Icons.people_alt_outlined,
                    label: 'Attendance',
                    description: 'Manage attendance and employee records.',
                    onPressed: _openAttendance,
                    accent: const Color(0xFF0A5BFF),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _MenuButton(
                    icon: Icons.folder_open_outlined,
                    label: 'Client Work Repository',
                    description: _hasRepoAccess == false
                        ? 'You don\'t have access — contact admin.'
                        : 'Access client projects and files.',
                    onPressed: _openClientRepository,
                    locked: _hasRepoAccess == false,
                    loading: _hasRepoAccess == null,
                    accent: const Color(0xFF2D8CFF),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 4,
            width: 4,
            decoration: const BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '© ${DateTime.now().year} GoDigital Portal  •  Secure Workspace',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8995A8),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onPressed;
  final bool locked;
  final bool loading;
  final Color accent;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.description,
    required this.onPressed,
    this.locked = false,
    this.loading = false,
    this.accent = const Color(0xFF0A5BFF),
  });

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool isHovered = false;
  bool isPressed = false;

  @override
  Widget build(BuildContext context) {
    final interactive = !widget.locked && !widget.loading;

    return MouseRegion(
      cursor: widget.locked
          ? SystemMouseCursors.forbidden
          : widget.loading
              ? SystemMouseCursors.wait
              : SystemMouseCursors.click,
      onEnter: (_) {
        if (interactive) setState(() => isHovered = true);
      },
      onExit: (_) {
        setState(() {
          isHovered = false;
          isPressed = false;
        });
      },
      child: GestureDetector(
        onTapDown: interactive
            ? (_) => setState(() => isPressed = true)
            : null,
        onTapCancel: interactive
            ? () => setState(() => isPressed = false)
            : null,
        onTap: interactive
            ? () {
                setState(() => isPressed = false);
                widget.onPressed();
              }
            : null,
        child: AnimatedScale(
          scale: isPressed ? 0.975 : 1,
          duration: const Duration(milliseconds: 110),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: 165,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: widget.locked ? 0.78 : 0.92),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.locked
                    ? const Color(0xFFE1E6EF)
                    : isHovered
                        ? widget.accent.withValues(alpha: 0.48)
                        : const Color(0xFFD5E5FF),
                width: isHovered && interactive ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.accent.withValues(
                    alpha: isHovered && interactive ? 0.12 : 0.05,
                  ),
                  blurRadius: isHovered && interactive ? 22 : 14,
                  offset: Offset(0, isHovered && interactive ? 8 : 5),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.locked
                        ? const Color(0xFFF0F2F6)
                        : const Color(0xFFE9F2FF),
                    border: Border.all(
                      color: widget.locked
                          ? const Color(0xFFE0E5ED)
                          : const Color(0xFFC9DDFF),
                    ),
                  ),
                  child: Icon(
                    widget.locked ? Icons.lock_outline_rounded : widget.icon,
                    size: 22,
                    color: widget.locked
                        ? const Color(0xFFAEB7C5)
                        : widget.accent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: widget.locked
                        ? const Color(0xFFAAB2C0)
                        : isHovered
                            ? widget.accent
                            : const Color(0xFF17213D),
                  ),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 26,
                  child: Text(
                    widget.description,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.25,
                      color: widget.locked
                          ? const Color(0xFFB4BCC8)
                          : const Color(0xFF7585A0),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                if (widget.loading)
                  SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      color: widget.accent,
                    ),
                  )
                else
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: 25,
                    width: 25,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: widget.locked
                          ? const LinearGradient(
                              colors: [Color(0xFFE9EDF3), Color(0xFFDDE3EC)],
                            )
                          : isHovered
                              ? LinearGradient(
                                  colors: [widget.accent, const Color(0xFF2D8CFF)],
                                )
                              : const LinearGradient(
                                  colors: [Color(0xFFF0F6FF), Color(0xFFE4EEFF)],
                                ),
                    ),
                    child: Icon(
                      widget.locked
                          ? Icons.lock_rounded
                          : Icons.arrow_forward_rounded,
                      size: widget.locked ? 11 : 14,
                      color: widget.locked
                          ? const Color(0xFFAAB2C0)
                          : isHovered
                              ? Colors.white
                              : widget.accent,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeBackground extends StatelessWidget {
  const _HomeBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _HomeBackgroundPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _HomeBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF8FBFF), Color(0xFFF1F6FF), Color(0xFFF9FBFF)],
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
    paint.shader = null;

    final wavePaint = Paint()
      ..color = const Color(0xFF2D8CFF).withValues(alpha: 0.055)
      ..style = PaintingStyle.fill;

    final left = Path()
      ..moveTo(0, size.height * 0.58)
      ..cubicTo(
        size.width * 0.10,
        size.height * 0.48,
        size.width * 0.15,
        size.height * 0.82,
        size.width * 0.30,
        size.height,
      )
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(left, wavePaint);

    final right = Path()
      ..moveTo(size.width, 0)
      ..cubicTo(
        size.width * 0.82,
        size.height * 0.03,
        size.width * 0.88,
        size.height * 0.20,
        size.width,
        size.height * 0.25,
      )
      ..lineTo(size.width, 0)
      ..close();
    wavePaint.color = const Color(0xFF2D8CFF).withValues(alpha: 0.045);
    canvas.drawPath(right, wavePaint);

    _circle(canvas, Offset(size.width * 0.10, size.height * 0.23), 62);
    _circle(canvas, Offset(size.width * 0.86, size.height * 0.22), 72);
  }

  void _circle(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = const Color(0xFF2D8CFF).withValues(alpha: 0.055);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}