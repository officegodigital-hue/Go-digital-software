import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';
import '../theme/admin_text_styles.dart';
import 'admin_auth_controller.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({
    required this.controller,
    required this.onLoginSuccess,
    super.key,
  });

  final AdminAuthController controller;
  final VoidCallback onLoginSuccess;

  @override
  State<AdminLoginPage> createState() {
    return _AdminLoginPageState();
  }
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();

    widget.controller.addListener(
      _handleControllerChanged,
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(
      _handleControllerChanged,
    );

    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    widget.controller.clearError(
      notify: false,
    );

    final bool valid =
        _formKey.currentState?.validate() ??
            false;

    if (!valid) {
      setState(() {});
      return;
    }

    final bool signedIn =
        await widget.controller.signIn(
      email:
          _emailController.text.trim(),
      password:
          _passwordController.text,
    );

    if (!mounted || !signedIn) {
      return;
    }

    widget.onLoginSuccess();
  }

  String? _emailValidator(
    String? value,
  ) {
    final String email =
        value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Email address is required.';
    }

    final RegExp emailPattern = RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    );

    if (!emailPattern.hasMatch(email)) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  String? _passwordValidator(
    String? value,
  ) {
    final String password =
        value ?? '';

    if (password.isEmpty) {
      return 'Password is required.';
    }

    if (password.length < 6) {
      return 'Password must contain at least 6 characters.';
    }

    return null;
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          AdminColors.surfaceSecondary,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (
            BuildContext context,
            BoxConstraints constraints,
          ) {
            final bool wideLayout =
                constraints.maxWidth >= 920;

            return SingleChildScrollView(
              padding:
                  const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      constraints.maxHeight -
                          48,
                ),
                child: Center(
                  child: Container(
                    width: double.infinity,
                    constraints:
                        const BoxConstraints(
                      maxWidth: 1120,
                    ),
                    decoration: BoxDecoration(
                      color:
                          AdminColors.surface,
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                      border: Border.all(
                        color:
                            AdminColors.border,
                      ),
                      boxShadow:
                          const <BoxShadow>[
                        BoxShadow(
                          color:
                              AdminColors.shadow,
                          blurRadius: 34,
                          offset:
                              Offset(0, 16),
                        ),
                      ],
                    ),
                    child: wideLayout
                        ? SizedBox(
                            height: 620,
                            child: Row(
                            children:
                                <Widget>[
                              const Expanded(
                                child:
                                    _BrandPanel(),
                              ),
                              Expanded(
                                child:
                                    _LoginPanel(
                                  formKey:
                                      _formKey,
                                  emailController:
                                      _emailController,
                                  passwordController:
                                      _passwordController,
                                  obscurePassword:
                                      _obscurePassword,
                                  isSigningIn:
                                      widget
                                          .controller
                                          .isSigningIn,
                                  errorMessage:
                                      widget
                                          .controller
                                          .errorMessage,
                                  emailValidator:
                                      _emailValidator,
                                  passwordValidator:
                                      _passwordValidator,
                                  onTogglePassword:
                                      () {
                                    setState(
                                      () {
                                        _obscurePassword =
                                            !_obscurePassword;
                                      },
                                    );
                                  },
                                  onSubmit:
                                      _submit,
                                ),
                              ),
                              ],
                            ),
                          )
                        : Column(
                            mainAxisSize:
                                MainAxisSize
                                    .min,
                            children:
                                <Widget>[
                              const _CompactBrandHeader(),
                              _LoginPanel(
                                formKey:
                                    _formKey,
                                emailController:
                                    _emailController,
                                passwordController:
                                    _passwordController,
                                obscurePassword:
                                    _obscurePassword,
                                isSigningIn:
                                    widget
                                        .controller
                                        .isSigningIn,
                                errorMessage:
                                    widget
                                        .controller
                                        .errorMessage,
                                emailValidator:
                                    _emailValidator,
                                passwordValidator:
                                    _passwordValidator,
                                onTogglePassword:
                                    () {
                                  setState(
                                    () {
                                      _obscurePassword =
                                          !_obscurePassword;
                                    },
                                  );
                                },
                                onSubmit:
                                    _submit,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      constraints:
          const BoxConstraints(
        minHeight: 620,
      ),
      padding:
          const EdgeInsets.all(46),
      decoration:
          const BoxDecoration(
        color: AdminColors.navy,
        borderRadius:
            BorderRadius.horizontal(
          left: Radius.circular(18),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          const _BrandLogo(),
          const Spacer(),
          Container(
            width: 64,
            height: 5,
            decoration: BoxDecoration(
              color:
                  AdminColors.primary,
              borderRadius:
                  BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Attendance Management',
            style: TextStyle(
              color: Colors.white,
              fontSize: 31,
              height: 1.15,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Manage employees, attendance, leave requests and business operations from one secure admin dashboard.',
            style: TextStyle(
              color:
                  AdminColors.textOnDarkMuted,
              fontSize: 14,
              height: 1.65,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
          const SizedBox(height: 30),
          const _BrandFeature(
            icon:
                Icons.groups_2_outlined,
            title:
                'Employee Management',
            subtitle:
                'Create, edit and maintain employee records.',
          ),
          const SizedBox(height: 18),
          const _BrandFeature(
            icon:
                Icons.schedule_outlined,
            title:
                'Attendance Monitoring',
            subtitle:
                'Review daily attendance and work schedules.',
          ),
          const SizedBox(height: 18),
          const _BrandFeature(
            icon:
                Icons.security_outlined,
            title:
                'Secure Admin Access',
            subtitle:
                'Protected using authenticated backend sessions.',
          ),
          const Spacer(),
          const Text(
            'GoDigital • Guduvanchery',
            style: TextStyle(
              color:
                  AdminColors.textOnDarkMuted,
              fontSize: 11,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactBrandHeader
    extends StatelessWidget {
  const _CompactBrandHeader();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.fromLTRB(
        24,
        24,
        24,
        22,
      ),
      decoration:
          const BoxDecoration(
        color: AdminColors.navy,
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(18),
        ),
      ),
      child: const Row(
        children: <Widget>[
          _BrandLogo(),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Attendance Management',
                  style: TextStyle(
                    color:
                        Colors.white,
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'GoDigital Admin Portal',
                  style: TextStyle(
                    color: AdminColors
                        .textOnDarkMuted,
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: 54,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white
            .withValues(
          alpha: 0.12,
        ),
        borderRadius:
            BorderRadius.circular(13),
        border: Border.all(
          color: Colors.white
              .withValues(
            alpha: 0.16,
          ),
        ),
      ),
      child: const Icon(
        Icons.admin_panel_settings_outlined,
        color: Colors.white,
        size: 29,
      ),
    );
  }
}

class _BrandFeature extends StatelessWidget {
  const _BrandFeature({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          alignment:
              Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white
                .withValues(
              alpha: 0.09,
            ),
            borderRadius:
                BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style:
                    const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style:
                    const TextStyle(
                  color: AdminColors
                      .textOnDarkMuted,
                  fontSize: 10,
                  height: 1.45,
                  fontWeight:
                      FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoginPanel extends StatelessWidget {
  const _LoginPanel({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isSigningIn,
    required this.errorMessage,
    required this.emailValidator,
    required this.passwordValidator,
    required this.onTogglePassword,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;

  final TextEditingController
      emailController;

  final TextEditingController
      passwordController;

  final bool obscurePassword;
  final bool isSigningIn;

  final String? errorMessage;

  final FormFieldValidator<String>
      emailValidator;

  final FormFieldValidator<String>
      passwordValidator;

  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 42,
        vertical: 48,
      ),
      child: Form(
        key: formKey,
        child: AutofillGroup(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                alignment:
                    Alignment.center,
                decoration:
                    BoxDecoration(
                  color: AdminColors
                      .primaryLight,
                  borderRadius:
                      BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.lock_person_outlined,
                  color:
                      AdminColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Admin Login',
                style:
                    AdminTextStyles.pageTitle,
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in with your registered admin email and password.',
                style: AdminTextStyles
                    .pageSubtitle,
              ),
              if (errorMessage != null &&
                  errorMessage!
                      .trim()
                      .isNotEmpty) ...<Widget>[
                const SizedBox(height: 20),
                _LoginErrorMessage(
                  message:
                      errorMessage!,
                ),
              ],
              const SizedBox(height: 26),
              const _LoginFieldLabel(
                label:
                    'Email Address',
              ),
              const SizedBox(height: 7),
              TextFormField(
                controller:
                    emailController,
                keyboardType:
                    TextInputType
                        .emailAddress,
                textInputAction:
                    TextInputAction.next,
                autofillHints:
                    const <String>[
                  AutofillHints.email,
                  AutofillHints.username,
                ],
                validator:
                    emailValidator,
                enabled:
                    !isSigningIn,
                decoration:
                    const InputDecoration(
                  hintText:
                      'admin@godigitalindia.co',
                  prefixIcon: Icon(
                    Icons
                        .email_outlined,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const _LoginFieldLabel(
                label: 'Password',
              ),
              const SizedBox(height: 7),
              TextFormField(
                controller:
                    passwordController,
                obscureText:
                    obscurePassword,
                textInputAction:
                    TextInputAction.done,
                autofillHints:
                    const <String>[
                  AutofillHints.password,
                ],
                validator:
                    passwordValidator,
                enabled:
                    !isSigningIn,
                onFieldSubmitted:
                    (_) {
                  if (!isSigningIn) {
                    onSubmit();
                  }
                },
                decoration:
                    InputDecoration(
                  hintText:
                      'Enter your password',
                  prefixIcon:
                      const Icon(
                    Icons
                        .lock_outline_rounded,
                  ),
                  suffixIcon:
                      IconButton(
                    tooltip:
                        obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                    onPressed:
                        isSigningIn
                            ? null
                            : onTogglePassword,
                    icon: Icon(
                      obscurePassword
                          ? Icons
                              .visibility_outlined
                          : Icons
                              .visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Row(
                children: <Widget>[
                  Icon(
                    Icons
                        .verified_user_outlined,
                    color:
                        AdminColors.success,
                    size: 15,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Your login is protected by the Attendance Management backend.',
                      style:
                          AdminTextStyles.helperText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed:
                      isSigningIn
                          ? null
                          : onSubmit,
                  icon: isSigningIn
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color:
                                Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons
                              .login_rounded,
                          size: 19,
                        ),
                  label: Text(
                    isSigningIn
                        ? 'Signing In...'
                        : 'Sign In',
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Divider(),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Authorized GoDigital administrators only',
                  textAlign:
                      TextAlign.center,
                  style: AdminTextStyles
                      .helperText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginFieldLabel
    extends StatelessWidget {
  const _LoginFieldLabel({
    required this.label,
  });

  final String label;

  @override
  Widget build(
    BuildContext context,
  ) {
    return RichText(
      text: TextSpan(
        style:
            AdminTextStyles.fieldLabel,
        children: <InlineSpan>[
          TextSpan(text: label),
          const TextSpan(
            text: ' *',
            style: TextStyle(
              color:
                  AdminColors.danger,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginErrorMessage
    extends StatelessWidget {
  const _LoginErrorMessage({
    required this.message,
  });

  final String message;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color:
            AdminColors.dangerBackground,
        borderRadius:
            BorderRadius.circular(7),
        border: Border.all(
          color:
              AdminColors.dangerBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.error_outline_rounded,
            color:
                AdminColors.danger,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style:
                  AdminTextStyles.dangerMessage,
            ),
          ),
        ],
      ),
    );
  }
}