import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qrpruf/providers/theme_provider.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isDarkMode {
    final themeMode = ref.watch(themeProvider);
    if (themeMode == ThemeMode.dark) return true;
    if (themeMode == ThemeMode.light) return false;
    return MediaQuery.of(context).platformBrightness == Brightness.dark;
  }

  bool get _fieldsNotEmpty =>
      _passwordController.text.isNotEmpty &&
      _confirmController.text.isNotEmpty;

  Future<void> _onSubmit() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    // Validation: at least 8 chars, one digit, one special char
    if (password.length < 8) {
      setState(() => _errorMessage = 'كلمة المرور يجب أن تكون 8 أحرف على الأقل');
      return;
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      setState(() => _errorMessage = 'كلمة المرور يجب أن تحتوي على رقم واحد على الأقل');
      return;
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      setState(() => _errorMessage = 'كلمة المرور يجب أن تحتوي على رمز خاص واحد على الأقل');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = 'كلمة المرور غير متطابقة');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم تحديث كلمة المرور بنجاح ✅',
            textAlign: TextAlign.right,
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );

      context.go('/login');
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'حدث خطأ: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'حدث خطأ غير متوقع. يرجى المحاولة لاحقاً');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final double s = screenWidth / 360;

    // ── Theme colors ──
    final bgColor = isDarkMode ? const Color(0xFF191919) : Colors.white;
    final headingColor = isDarkMode ? const Color(0xFFF9F9F9) : const Color(0xFF111111);
    final placeholderColor = isDarkMode ? const Color(0xFF6E6E6E) : const Color(0xFFB8B8B8);
    final actionColor = isDarkMode ? const Color(0xFF319B8F) : const Color(0xFF5BBDB1);
    final borderColor = isDarkMode ? const Color(0xFF909090) : const Color(0xFF858585);
    final separatorColor = isDarkMode ? const Color(0xFF2B2B2B) : const Color(0xFFE0E0E0);

    // Disabled button colors
    final disabledBtnColor = isDarkMode ? const Color(0xFF16443F) : const Color(0xFFCFE7E4);
    final disabledBtnTextColor = isDarkMode ? const Color(0xFF071513) : const Color(0xFFF5FAF9);
    final activeBtnTextColor = isDarkMode ? Colors.black : Colors.white;

    final isActive = _fieldsNotEmpty;

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: false,
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            // ── Back arrow ──
            Positioned(
              right: 20 * s,
              top: statusBarHeight + 8 * s,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 24 * s,
                  height: 24 * s,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.chevron_right,
                    color: headingColor,
                    size: 24 * s,
                  ),
                ),
              ),
            ),

            // ── CONTENT ──
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
                    // Title
                    SizedBox(
                      width: 268 * s,
                      child: Text(
                        'إعادة تعيين كلمة المرور',
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

                    SizedBox(height: 20 * s),

                    // Password field
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
                        ),
                      ),
                    ),

                    SizedBox(height: 8 * s),

                    // Password rules hint
                    SizedBox(
                      width: 272 * s,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '8 أحرف ',
                                    style: TextStyle(
                                      color: headingColor,
                                      fontSize: 12 * s,
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.w700,
                                      height: 1.17,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'على الأقل، مع ',
                                    style: TextStyle(
                                      color: headingColor,
                                      fontSize: 12 * s,
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.w400,
                                      height: 1.17,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'رقم',
                                    style: TextStyle(
                                      color: headingColor,
                                      fontSize: 12 * s,
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.w700,
                                      height: 1.17,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' و',
                                    style: TextStyle(
                                      color: headingColor,
                                      fontSize: 12 * s,
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.w400,
                                      height: 1.17,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'رمز خاص',
                                    style: TextStyle(
                                      color: headingColor,
                                      fontSize: 12 * s,
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.w700,
                                      height: 1.17,
                                    ),
                                  ),
                                  TextSpan(
                                    text: r' (مثل !@#$%^&*)',
                                    style: TextStyle(
                                      color: headingColor,
                                      fontSize: 12 * s,
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.w400,
                                      height: 1.17,
                                    ),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16 * s),

                    // Confirm password field
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
                                _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: placeholderColor,
                                size: 20 * s,
                              ),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ),

                    // Error message
                    if (_errorMessage != null)
                      Padding(
                        padding: EdgeInsets.only(top: 8 * s),
                        child: SizedBox(
                          width: 300 * s,
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12 * s,
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── BOTTOM: "إنهاء" button ──
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
                    onTap: (isActive && !_isLoading) ? _onSubmit : null,
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
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isLoading
                            ? SizedBox(
                                width: 20 * s,
                                height: 20 * s,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: isActive ? activeBtnTextColor : disabledBtnTextColor,
                                ),
                              )
                            : Text(
                                'إنهاء',
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
