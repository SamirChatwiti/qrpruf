import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'controllers/auth_controller.dart';
import '../../../core/providers/app_state_providers.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _onPasswordStep = false;
  String? _emailError;
  String? _passwordError;

  bool get _emailValid {
    final e = _emailController.text.trim();
    return e.isNotEmpty && e.contains('@') && e.contains('.');
  }

  bool get _passwordRulesValid {
    final p = _passwordController.text;
    return p.length >= 8 &&
        RegExp(r'[0-9]').hasMatch(p) &&
        RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(p);
  }

  bool get _passwordValid {
    return _passwordRulesValid &&
        _confirmController.text.isNotEmpty &&
        _passwordController.text == _confirmController.text;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _nextStep() {
    FocusScope.of(context).unfocus();
    setState(() {
      _emailError = null;
      _onPasswordStep = true;
    });
  }

  void _onSignup() {
    FocusScope.of(context).unfocus();
    final p = _passwordController.text;
    if (p.length < 8) {
      setState(() => _passwordError = 'كلمة المرور يجب أن تكون 8 أحرف على الأقل');
      return;
    }
    if (!RegExp(r'[0-9]').hasMatch(p)) {
      setState(() => _passwordError = 'يجب أن تحتوي على رقم واحد على الأقل');
      return;
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(p)) {
      setState(() => _passwordError = 'يجب أن تحتوي على رمز خاص (مثل !@#\$%)');
      return;
    }
    if (p != _confirmController.text) {
      setState(() => _passwordError = 'كلمة المرور غير متطابقة');
      return;
    }
    setState(() => _passwordError = null);
    ref.read(authControllerProvider.notifier).signUpWithPassword(
      _emailController.text.trim(),
      p,
    );
  }

  Widget _buildRules(double s, Color baseColor) {
    final p = _passwordController.text;
    final hasLength = p.length >= 8;
    final hasDigit = RegExp(r'[0-9]').hasMatch(p);
    final hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(p);

    TextStyle ruleStyle(bool done) => TextStyle(
          color: done ? baseColor.withValues(alpha: 0.35) : baseColor,
          fontSize: 11 * s,
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w600,
          decoration: done ? TextDecoration.lineThrough : TextDecoration.none,
          decorationColor: baseColor.withValues(alpha: 0.35),
          decorationThickness: 2,
        );

    final dotStyle = TextStyle(
      color: baseColor.withValues(alpha: 0.35),
      fontSize: 11 * s,
      fontFamily: 'Cairo',
      fontWeight: FontWeight.w400,
    );

    return SizedBox(
      width: 300 * s,
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: 'رمز خاص', style: ruleStyle(hasSpecial)),
          TextSpan(text: '  ·  ', style: dotStyle),
          TextSpan(text: 'رقم', style: ruleStyle(hasDigit)),
          TextSpan(text: '  ·  ', style: dotStyle),
          TextSpan(text: '8 أحرف على الأقل', style: ruleStyle(hasLength)),
        ]),
        textAlign: TextAlign.right,
        maxLines: 1,
        overflow: TextOverflow.clip,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final double s = screenWidth / 360;

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final bgColor = theme.scaffoldBackgroundColor;
    final headingColor = isDarkMode ? const Color(0xFFF9F9F9) : const Color(0xFF111111);
    final bodyColor = isDarkMode ? const Color(0xFF929292) : const Color(0xFF4B4B4B);
    final placeholderColor = isDarkMode ? const Color(0xFF6E6E6E) : const Color(0xFFB8B8B8);
    final actionColor = theme.primaryColor;
    final borderColor = isDarkMode ? const Color(0xFF909090) : const Color(0xFF858585);
    final separatorColor = theme.dividerColor;

    final disabledBtnColor = isDarkMode ? const Color(0xFF16443F) : const Color(0xFFCFE7E4);
    final disabledBtnTextColor = isDarkMode ? const Color(0xFF071513) : const Color(0xFFF5FAF9);
    final activeBtnTextColor = isDarkMode ? Colors.black : Colors.white;

    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;
    final isActive = _onPasswordStep ? _passwordValid : _emailValid;

    ref.listen<AsyncValue<void>>(authControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, _) {
          final msg = error.toString();
          if (msg.contains('مستخدم بالفعل') || msg.contains('already')) {
            setState(() {
              _onPasswordStep = false;
              _emailError = 'هذا البريد مسجل مسبقاً';
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg), backgroundColor: Colors.red),
            );
          }
        },
        data: (_) {
          ref.read(showActivationBannerProvider.notifier).show();
          context.go('/login');
        },
      );
    });

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: false,
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            // Back arrow
            Positioned(
              left: 12 * s,
              top: statusBarHeight + 8 * s,
              child: IconButton(
                icon: Icon(
                  _onPasswordStep ? Icons.arrow_back_ios_new : Icons.arrow_back_ios_new,
                  size: 20 * s,
                  color: headingColor,
                ),
                onPressed: () {
                  if (_onPasswordStep) {
                    setState(() {
                      _onPasswordStep = false;
                      _emailError = null;
                    });
                  } else {
                    context.go('/onboarding');
                  }
                },
              ),
            ),

            // Main content
            Positioned(
              left: 0,
              right: 0,
              top: statusBarHeight + 41 * s,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 30 * s, vertical: 8 * s),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 268 * s,
                      child: Text(
                        'إنشاء حساب جديد',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: headingColor,
                          fontSize: 24 * s,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                          height: 1.33,
                        ),
                      ),
                    ),
                    SizedBox(height: 4 * s),
                    SizedBox(
                      width: 285 * s,
                      child: Text(
                        _onPasswordStep
                            ? 'أنشئ كلمة مرور قوية لحماية حسابك'
                            : 'قم بإدخال بريدك الإلكتروني لتبدأ في حماية أدلتك',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: bodyColor,
                          fontSize: 14 * s,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w600,
                          height: 1.43,
                        ),
                      ),
                    ),
                    SizedBox(height: 20 * s),

                    // Email field (always visible, disabled on step 2)
                    Container(
                      width: 300 * s,
                      height: 52 * s,
                      decoration: ShapeDecoration(
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            width: 1,
                            strokeAlign: BorderSide.strokeAlignOutside,
                            color: _emailError != null
                                ? Colors.red
                                : borderColor,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textAlign: TextAlign.right,
                          enabled: !_onPasswordStep,
                          style: TextStyle(
                            color: _onPasswordStep ? placeholderColor : headingColor,
                            fontSize: 14 * s,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: 'البريد الإلكتروني',
                            hintStyle: TextStyle(
                              color: placeholderColor,
                              fontSize: 12 * s,
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w700,
                              height: 1.17,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16 * s,
                              vertical: 16 * s,
                            ),
                          ),
                          onChanged: (_) => setState(() => _emailError = null),
                        ),
                      ),
                    ),

                    // Inline error under email
                    if (_emailError != null) ...[
                      SizedBox(height: 8 * s),
                      SizedBox(
                        width: 300 * s,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _emailError!,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 12 * s,
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4 * s),
                            GestureDetector(
                              onTap: () => context.go('/login'),
                              child: Text(
                                'تسجيل الدخول بدلاً من ذلك ←',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: actionColor,
                                  fontSize: 12 * s,
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Password field (step 2 only)
                    if (_onPasswordStep) ...[
                      SizedBox(height: 12 * s),
                      Container(
                        width: 300 * s,
                        height: 52 * s,
                        decoration: ShapeDecoration(
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              width: 1,
                              strokeAlign: BorderSide.strokeAlignOutside,
                              color: borderColor,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textAlign: TextAlign.right,
                            autofocus: true,
                            style: TextStyle(
                              color: headingColor,
                              fontSize: 14 * s,
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: 'كلمة المرور',
                              hintStyle: TextStyle(
                                color: placeholderColor,
                                fontSize: 12 * s,
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.w700,
                                height: 1.17,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16 * s,
                                vertical: 16 * s,
                              ),
                              suffixIcon: GestureDetector(
                                onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                                child: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: placeholderColor,
                                  size: 20 * s,
                                ),
                              ),
                            ),
                            onChanged: (_) => setState(() => _passwordError = null),
                          ),
                        ),
                      ),
                      SizedBox(height: 6 * s),
                      _buildRules(s, headingColor),
                      SizedBox(height: 12 * s),
                      Container(
                        width: 300 * s,
                        height: 52 * s,
                        decoration: ShapeDecoration(
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              width: 1,
                              strokeAlign: BorderSide.strokeAlignOutside,
                              color: borderColor,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: TextField(
                            controller: _confirmController,
                            obscureText: _obscureConfirm,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: headingColor,
                              fontSize: 14 * s,
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: 'تأكيد كلمة المرور',
                              hintStyle: TextStyle(
                                color: placeholderColor,
                                fontSize: 12 * s,
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.w700,
                                height: 1.17,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16 * s,
                                vertical: 16 * s,
                              ),
                              suffixIcon: GestureDetector(
                                onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                child: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: placeholderColor,
                                  size: 20 * s,
                                ),
                              ),
                            ),
                            onChanged: (_) => setState(() => _passwordError = null),
                          ),
                        ),
                      ),
                      if (_passwordError != null) ...[
                        SizedBox(height: 4 * s),
                        SizedBox(
                          width: 300 * s,
                          child: Text(
                            _passwordError!,
                            textAlign: TextAlign.right,
                            style: TextStyle(color: Colors.red, fontSize: 12 * s, fontFamily: 'Cairo', fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],  // end if (_onPasswordStep)

                    SizedBox(height: 20 * s),

                    // Action button
                    GestureDetector(
                      onTap: (isActive && !isLoading)
                          ? (_onPasswordStep ? _onSignup : _nextStep)
                          : null,
                      child: Container(
                        width: 300 * s,
                        height: 52 * s,
                        padding: EdgeInsets.symmetric(
                          horizontal: 12 * s,
                          vertical: 16 * s,
                        ),
                        decoration: ShapeDecoration(
                          color: isActive ? actionColor : disabledBtnColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(1024),
                          ),
                          shadows: const [
                            BoxShadow(
                              color: Color(0x26000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Center(
                          child: isLoading
                              ? SizedBox(
                                  width: 20 * s,
                                  height: 20 * s,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: isActive
                                        ? activeBtnTextColor
                                        : disabledBtnTextColor,
                                  ),
                                )
                              : Text(
                                  _onPasswordStep ? 'إنشاء حساب' : 'تابع',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isActive
                                        ? activeBtnTextColor
                                        : disabledBtnTextColor,
                                    fontSize: 16 * s,
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.w700,
                                    height: 1.25,
                                  ),
                                ),
                        ),
                      ),
                    ),

                    SizedBox(height: 20 * s),
                  ],
                ),
              ),
            ),

            // Bottom link
            Positioned(
              left: 0,
              right: 0,
              bottom: (keyboardHeight > 0
                  ? keyboardHeight + 8 * s
                  : bottomPadding + 16 * s),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 360 * s,
                    height: 0.5,
                    color: separatorColor,
                  ),
                  SizedBox(height: 8 * s),
                  GestureDetector(
                    onTap: () => context.go('/login'),
                    child: Container(
                      width: 300 * s,
                      height: 52 * s,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12 * s,
                        vertical: 16 * s,
                      ),
                      decoration: ShapeDecoration(
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            width: 1,
                            color: actionColor,
                          ),
                          borderRadius: BorderRadius.circular(1024),
                        ),
                        shadows: const [
                          BoxShadow(
                            color: Color(0x26000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'تابع',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: actionColor,
                            fontSize: 16 * s,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ),
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
