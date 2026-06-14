import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'controllers/auth_controller.dart';
import 'package:qrpruf/pages/forgot_password_page.dart';
import '../../../core/providers/app_state_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  bool get _fieldsNotEmpty =>
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLogin() {
    FocusScope.of(context).unfocus();
    ref.read(authControllerProvider.notifier).signInWithPassword(
      _emailController.text.trim(),
      _passwordController.text,
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

    final isActive = _fieldsNotEmpty;
    final showActivationBanner = ref.watch(showActivationBannerProvider);

    // Listen to Auth State
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    ref.listen<AsyncValue<void>>(authControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stackTrace) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
          );
        },
        data: (_) {
           // GoRouter redirect handles moving to Dashboard when session becomes non-null
           // but we can actively push to be sure if redirect is cached.
           context.go('/dashboard');
        }
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
            Positioned(
              left: 12 * s,
              top: statusBarHeight + 8 * s,
              child: IconButton(
                icon: Icon(Icons.arrow_back_ios_new, size: 20 * s, color: headingColor),
                onPressed: () => context.go('/onboarding'),
              ),
            ),
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
                        'تسجيل الدخول',
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
                        'أدخل بيانات حسابك المسجّل أدناه',
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
                        textDirection: TextDirection.ltr,
                        child: TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: headingColor,
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
                          onChanged: (_) => setState(() {}),
                          onTap: () => ref.read(showActivationBannerProvider.notifier).hide(),
                        ),
                      ),
                    ),
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
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: placeholderColor,
                                size: 20 * s,
                              ),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                          onTap: () => ref.read(showActivationBannerProvider.notifier).hide(),
                        ),
                      ),
                    ),
                    if (showActivationBanner) ...[
                      SizedBox(height: 16 * s),
                      Container(
                        width: 300 * s,
                        padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 10 * s),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5BBDB1).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF5BBDB1), width: 1),
                        ),
                        child: Text(
                          'تم إرسال رابط التأكيد إلى بريدك الإلكتروني',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: const Color(0xFF2E9B8F),
                            fontSize: 12 * s,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: 20 * s),
                    GestureDetector(
                      onTap: (isActive && !isLoading) ? _onLogin : null,
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
                                    color: isActive ? activeBtnTextColor : disabledBtnTextColor,
                                  ),
                                )
                              : Text(
                                  'متابعة',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isActive ? activeBtnTextColor : disabledBtnTextColor,
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
                    GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage()));
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'نسيت كلمة المرور؟',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: actionColor,
                              fontSize: 14 * s,
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w700,
                              height: 1.43,
                            ),
                          ),
                          Container(
                            width: 130 * s,
                            height: 1,
                            color: actionColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: (keyboardHeight > 0 ? keyboardHeight + 8 * s : bottomPadding + 16 * s),
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
                    onTap: () {
                      context.push('/signup');
                    },
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
                          'إنشاء حساب جديد',
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
