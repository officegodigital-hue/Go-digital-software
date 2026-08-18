import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../data/repositories/auth_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthRepository _authRepository = AuthRepository();

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  bool _hidePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

 Future<void> _signIn() async {
  FocusScope.of(context).unfocus();

  if (_isLoading) {
    return;
  }

  final String email = _emailController.text.trim();
  final String password = _passwordController.text.trim();

  if (email.isEmpty) {
    _showError('Enter your email address.');
    return;
  }

  if (!_isValidEmail(email)) {
    _showError('Enter a valid email address.');
    return;
  }

  if (password.isEmpty) {
    _showError('Enter your password.');
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    final loginResponse = await _authRepository.login(
      email: email,
      password: password,
    );

    if (!mounted) {
      return;
    }


    // Token already saved inside AuthRepository
    // Navigate after successful login

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) {
          return HomeScreen(
            employeeName: loginResponse.user.name,
          );
        },
      ),
    );

  } on AuthRepositoryException catch (error) {

    if (!mounted) {
      return;
    }

    _showError(error.message);

  } catch (error) {

    if (!mounted) {
      return;
    }

    _showError(
      'Unable to login. Please try again.',
    );

  } finally {

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

  bool _isValidEmail(String email) {
    final RegExp emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    return emailPattern.hasMatch(email);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFD93542),
        ),
      );
  }

  void _forgotPassword() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Forgot-password feature will be added later.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _signUp() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Employee signup will be added later.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool desktopPreview = constraints.maxWidth >= 700;

        if (desktopPreview) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: _PhoneFrame(
                    child: SizedBox(
                      width: 390,
                      height: 844,
                      child: _buildLoginPage(previewMode: true),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(child: _buildLoginPage()),
        );
      },
    );
  }

  Widget _buildLoginPage({bool previewMode = false}) {
    return ColoredBox(
      color: Colors.white,
      child: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, previewMode ? 70 : 55, 24, 18),
              child: AutofillGroup(
                child: Column(
                  children: [
                    const _LogoHeader(),
                    const SizedBox(height: 18),
                    const Text(
                      'Welcome back',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Manage your workforce with precision.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 42),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: _buildLoginCard(),
                    ),
                    const SizedBox(height: 31),
                    _buildSignupRow(),
                    const Spacer(),
                    const _Footer(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(27, 28, 27, 27),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _FieldLabel(text: 'Email Address'),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: TextField(
              controller: _emailController,
              enabled: !_isLoading,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [
                AutofillHints.email,
                AutofillHints.username,
              ],
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11.5,
              ),
              decoration: _inputDecoration(
                hintText: 'name@company.com',
                prefixIcon: Icons.mail_outline_rounded,
              ),
            ),
          ),
          const SizedBox(height: 19),
          Row(
            children: [
              const Expanded(child: _FieldLabel(text: 'Password')),
              InkWell(
                onTap: _isLoading ? null : _forgotPassword,
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                  child: Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: TextField(
              controller: _passwordController,
              enabled: !_isLoading,
              obscureText: _hidePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) {
                _signIn();
              },
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.4,
              ),
              decoration: _inputDecoration(
                hintText: '••••••••',
                prefixIcon: Icons.lock_outline_rounded,
                suffixWidget: IconButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _hidePassword = !_hidePassword;
                          });
                        },
                  padding: EdgeInsets.zero,
                  splashRadius: 18,
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 17,
                    color: AppColors.hintText,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildRememberMe(),
          const SizedBox(height: 23),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _signIn,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withValues(
                  alpha: 0.65,
                ),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 7),
                        Icon(Icons.arrow_forward_rounded, size: 17),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRememberMe() {
    return InkWell(
      onTap: _isLoading
          ? null
          : () {
              setState(() {
                _rememberMe = !_rememberMe;
              });
            },
      borderRadius: BorderRadius.circular(4),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: Checkbox(
              value: _rememberMe,
              onChanged: _isLoading
                  ? null
                  : (bool? value) {
                      setState(() {
                        _rememberMe = value ?? false;
                      });
                    },
              activeColor: AppColors.primary,
              checkColor: Colors.white,
              side: const BorderSide(color: AppColors.checkboxBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Remember me for 30 days',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildSignupRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Don\'t have an account? ',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5),
        ),
        InkWell(
          onTap: _isLoading ? null : _signUp,
          borderRadius: BorderRadius.circular(4),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2, vertical: 3),
            child: Text(
              'SignUp',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixWidget,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: AppColors.hintText,
        fontSize: 10.5,
        letterSpacing: 0,
      ),
      filled: true,
      fillColor: AppColors.inputBackground,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      prefixIcon: Icon(prefixIcon, size: 16, color: AppColors.hintText),
      prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 40),
      suffixIcon: suffixWidget,
      suffixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 40),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.3),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: Color(0xFFD93542)),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    );
  }
}

class _LogoHeader extends StatelessWidget {
  const _LogoHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 45,
          height: 45,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.schedule_rounded, size: 44, color: AppColors.primary),
              Positioned(
                right: 0,
                top: 1,
                child: Icon(
                  Icons.check_rounded,
                  size: 19,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 5),
        Text(
          'TimeTrack Pro',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 9.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          '© 2026 TimeTrack Pro Enterprise',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 9.5),
        ),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Privacy Policy',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 9.5),
            ),
            SizedBox(width: 18),
            Text(
              'Terms',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 9.5),
            ),
          ],
        ),
      ],
    );
  }
}

class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 402,
      height: 856,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(49),
        border: Border.all(color: const Color(0xFF4B4B4B), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(42),
        child: Stack(
          children: [
            Positioned.fill(child: child),
            const Positioned(
              top: 10,
              left: 18,
              child: Text(
                '9:41',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Positioned(
              top: 11,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF15243B),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            const Positioned(
              top: 9,
              right: 16,
              child: Row(
                children: [
                  Icon(
                    Icons.signal_cellular_alt_rounded,
                    size: 11,
                    color: Colors.black,
                  ),
                  SizedBox(width: 3),
                  Icon(Icons.wifi_rounded, size: 11, color: Colors.black),
                  SizedBox(width: 3),
                  Icon(
                    Icons.battery_full_rounded,
                    size: 12,
                    color: Colors.black,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
