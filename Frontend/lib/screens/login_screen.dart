import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:godigital_portal/services/auth_service.dart';
import 'package:godigital_portal/shared/branding_assets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  int _selectedTab = 0; // 0 = Employee, 1 = Admin
  bool _rememberDevice = false;
  bool _obscurePassword = true;
  final bool _isLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late final AnimationController _pageController;
  late final AnimationController _floatController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scaleAnimation;

  static const Color _blue900 = Color(0xFF063B91);
  static const Color _blue800 = Color(0xFF0755C9);
  static const Color _blue600 = Color(0xFF1769FF);
  static const Color _blue500 = Color(0xFF2F80FF);
  static const Color _blue100 = Color(0xFFEAF2FF);
  static const Color _blue50 = Color(0xFFF5F9FF);
  static const Color _ink = Color(0xFF102A56);
  static const Color _muted = Color(0xFF7084A3);
  static const Color _line = Color(0xFFD8E6FF);

  @override
  void initState() {
    super.initState();

    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _pageController,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.045),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _pageController, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = Tween<double>(begin: 0.975, end: 1.0).animate(
      CurvedAnimation(parent: _pageController, curve: Curves.easeOutBack),
    );

    _pageController.forward();
    _loadRememberedUser();
  }

  Future<void> _loadRememberedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberedUser = prefs.getString('remembered_login_user');
    final rememberedPassword = prefs.getString('remembered_login_password');

    if (!mounted) return;

    if (rememberedUser != null && rememberedUser.isNotEmpty) {
      setState(() {
        _emailController.text = rememberedUser;
        _passwordController.text = rememberedPassword ?? '';
        _rememberDevice = true;
      });
      debugPrint('📥 Remembered login loaded');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _floatController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _blue50,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final isMobile = width < 700;
                  final isCompact = width < 1050;

                  return Stack(
                    children: [
                      _buildBackgroundDecorations(),
                      SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: width,
                            minHeight: constraints.maxHeight,
                          ),
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 16 : 28,
                                vertical: isMobile ? 22 : 34,
                              ),
                              child: FadeTransition(
                                opacity: _fadeAnimation,
                                child: SlideTransition(
                                  position: _slideAnimation,
                                  child: ScaleTransition(
                                    scale: _scaleAnimation,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: isMobile
                                            ? 520
                                            : isCompact
                                                ? 900
                                                : 1040,
                                      ),
                                      child: isMobile
                                          ? _buildMobileLayout()
                                          : _buildDesktopLayout(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundDecorations() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _floatController,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_floatController.value);
          return Stack(
            children: [
              Positioned(
                left: -90,
                top: 55 + (18 * t),
                child: _softCircle(220, _blue100.withValues(alpha: .55)),
              ),
              Positioned(
                right: -80,
                top: 15 + (24 * (1 - t)),
                child: _softCircle(260, _blue100.withValues(alpha: .72)),
              ),
              Positioned(
                left: 70 + (20 * t),
                bottom: 20,
                child: _softCircle(90, _blue500.withValues(alpha: .10)),
              ),
              Positioned(
                right: 100,
                bottom: 30 + (12 * t),
                child: _softCircle(55, _blue600.withValues(alpha: .10)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _softCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  // ── Top navigation bar ──────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: _blue800.withValues(alpha: .07),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_blue800, _blue500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: _blue600.withValues(alpha: .22),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.grid_view_rounded,
              size: 22,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 11),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'GoDigital Portal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  letterSpacing: -.2,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'WORKSPACE CONTROL CENTER',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.25,
                  color: _blue600,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: _blue50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _line),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.support_agent_rounded, size: 17, color: _blue800),
                SizedBox(width: 7),
                Text(
                  'Support',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _blue800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Desktop layout: existing logo-left / card-right structure preserved ─────

  Widget _buildDesktopLayout() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Center(
            child: _buildBrandPanel(),
          ),
        ),
        const SizedBox(width: 48),
        SizedBox(
          width: 410,
          child: _buildLoginCard(cardWidth: double.infinity),
        ),
      ],
    );
  }

  // ── Mobile layout: existing logo-top / card-bottom structure preserved ──────

  Widget _buildMobileLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildBrandPanel(compact: true),
        const SizedBox(height: 28),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: _buildLoginCard(cardWidth: double.infinity),
        ),
      ],
    );
  }

  Widget _buildBrandPanel({bool compact = false}) {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        final movement = compact
            ? 2.5 * Curves.easeInOut.transform(_floatController.value)
            : 5 * Curves.easeInOut.transform(_floatController.value);

        return Transform.translate(
          offset: Offset(0, -movement),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLogo(logoWidth: compact ? 190 : 285),
              SizedBox(height: compact ? 10 : 16),
              Text(
                'WORKSPACE CONTROL CENTER',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 9 : 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: compact ? 2.8 : 3.2,
                  color: _blue500,
                ),
              ),
              SizedBox(height: compact ? 8 : 12),
              Text(
                'Welcome to GoDigital',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 20 : 26,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  letterSpacing: -.4,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Access your workspace securely,\nmanaging tasks and staying connected with your team.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 11.5 : 13,
                  height: 1.5,
                  color: _muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Logo ────────────────────────────────────────────────────────────────────

  Widget _buildLogo({required double logoWidth}) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .92),
        shape: BoxShape.circle,
        border: Border.all(color: _blue500.withValues(alpha: .24), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _blue600.withValues(alpha: .13),
            blurRadius: 34,
            spreadRadius: 3,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Image.asset(
        brandingLogoAssetForRole(isAdmin: _selectedTab == 1),
        width: logoWidth,
        height: logoWidth * .52,
        fit: BoxFit.contain,
      ),
    );
  }

  // ── Login card ──────────────────────────────────────────────────────────────

  Widget _buildLoginCard({required double cardWidth}) {
    return Container(
      width: cardWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _blue800.withValues(alpha: .10),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: .95),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCardAccent(),
            _buildTabRow(),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 25, 26, 25),
              child: _buildFormContent(),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildCardAccent() {
    return Container(
      height: 5,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_blue900, _blue600, _blue500],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    );
  }

  // ── Tab switcher ────────────────────────────────────────────────────────────

  Widget _buildTabRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: Container(
        height: 50,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _blue50,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            _buildTab('Employee Login', 0),
            _buildTab('Admin Login', 1),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_selectedTab == index) return;
          setState(() => _selectedTab = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [_blue800, _blue500],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _blue600.withValues(alpha: .20),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : _muted,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }

  // ── Form body ───────────────────────────────────────────────────────────────

  Widget _buildFormContent() {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: Text(
                  _selectedTab == 1 ? 'Admin Welcome Back' : 'Welcome Back',
                  key: ValueKey(_selectedTab),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: -.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            const Center(
              child: Text(
                'Sign in with your corporate credentials to continue.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: _muted,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 22),

            if (authService.error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4F4),
                  border: Border.all(color: const Color(0xFFFFD2D2)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: Color(0xFFD63B3B),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        authService.error!,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: Color(0xFFB42318),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            _fieldLabel('Email or Username'),
            const SizedBox(height: 8),
            _textField(
              controller: _emailController,
              hint: 'name@company.com',
              prefixIcon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              enabled: !authService.isLoading,
            ),
            const SizedBox(height: 17),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _fieldLabel('Password'),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _blue600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _textField(
              controller: _passwordController,
              hint: 'Enter your password',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              enabled: !authService.isLoading,
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                onPressed: () => setState(
                  () => _obscurePassword = !_obscurePassword,
                ),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 19,
                  color: _muted,
                ),
              ),
            ),
            const SizedBox(height: 13),

            Row(
              children: [
                SizedBox(
                  width: 21,
                  height: 21,
                  child: Checkbox(
                    value: _rememberDevice,
                    onChanged: authService.isLoading
                        ? null
                        : (v) => setState(
                            () => _rememberDevice = v ?? false,
                          ),
                    activeColor: _blue600,
                    checkColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    side: const BorderSide(color: Color(0xFFB9CAE4)),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Remember this device',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: _muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 21),

            _buildSignInButton(authService),
          ],
        );
      },
    );
  }

  Widget _buildSignInButton(AuthService authService) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: authService.isLoading
              ? const LinearGradient(
                  colors: [Color(0xFF8AA7D7), Color(0xFF6E91CB)],
                )
              : const LinearGradient(
                  colors: [_blue900, _blue600, _blue500],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: authService.isLoading
              ? null
              : [
                  BoxShadow(
                    color: _blue600.withValues(alpha: .25),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: authService.isLoading ? null : _handleLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: authService.isLoading
              ? const SizedBox(
                  height: 21,
                  width: 21,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2.2,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .2,
                      ),
                    ),
                    SizedBox(width: 9),
                    Icon(Icons.arrow_forward_rounded, size: 19),
                  ],
                ),
        ),
      ),
    );
  }

  // ── Footer ──────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
      decoration: const BoxDecoration(
        color: _blue50,
        border: Border(top: BorderSide(color: _line)),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          const Text(
            'New to the organization?',
            style: TextStyle(
              fontSize: 11.5,
              color: _muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          GestureDetector(
            onTap: _handleCreateAccount,
            child: const Text(
              'Create an Admin Account',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: _blue600,
                decoration: TextDecoration.underline,
                decorationColor: _blue600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
        color: _ink,
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    bool enabled = true,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      enabled: enabled,
      cursorColor: _blue600,
      style: const TextStyle(
        fontSize: 13,
        color: _ink,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFFA0B0C7),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Container(
          margin: const EdgeInsets.only(left: 6, right: 2),
          child: Icon(prefixIcon, size: 19, color: _blue600),
        ),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _blue500, width: 1.6),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFFE2EAF6)),
        ),
        filled: true,
        fillColor: enabled ? const Color(0xFFFBFDFF) : const Color(0xFFF2F6FB),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 15,
          horizontal: 13,
        ),
      ),
    );
  }

  // ── Login handler ───────────────────────────────────────────────────────────

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter email and password.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final authService = context.read<AuthService>();
    final isAdmin = _selectedTab == 1;

    final success = await authService.login(
      email,
      password,
      isAdmin,
      _rememberDevice,
    );

    if (!mounted) return;

    if (success) {
      final prefs = await SharedPreferences.getInstance();

      if (_rememberDevice) {
        await prefs.setString('remembered_login_user', email);
        await prefs.setString('remembered_login_password', password);
      } else {
        await prefs.remove('remembered_login_user');
        await prefs.remove('remembered_login_password');
      }

      if (!mounted) return;

      await authService.refreshUserData();

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    }
  }

  void _handleCreateAccount() {
    debugPrint('Create Admin Account tapped');
  }
}
