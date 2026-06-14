import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:qrpruf/providers/theme_provider.dart';

class CheckEmailPage extends ConsumerStatefulWidget {
  final String email;
  const CheckEmailPage({super.key, required this.email});

  @override
  ConsumerState<CheckEmailPage> createState() => _CheckEmailPageState();
}

class _CheckEmailPageState extends ConsumerState<CheckEmailPage> {
  bool _isResending = false;
  bool _resent = false;

  bool get isDarkMode {
    final themeMode = ref.watch(themeProvider);
    if (themeMode == ThemeMode.dark) return true;
    if (themeMode == ThemeMode.light) return false;
    return MediaQuery.of(context).platformBrightness == Brightness.dark;
  }

  Future<void> _resendLink() async {
    setState(() {
      _isResending = true;
      _resent = false;
    });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        widget.email,
        redirectTo: 'qrpruf://reset-password',
      );
      if (mounted) setState(() => _resent = true);
    } catch (_) {}

    if (mounted) setState(() => _isResending = false);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final double s = screenWidth / 360;

    // ── Theme colors ──
    final bgColor = isDarkMode ? const Color(0xFF191919) : Colors.white;
    final headingColor = isDarkMode ? const Color(0xFFF9F9F9) : const Color(0xFF111111);
    final bodyColor = isDarkMode ? const Color(0xFF929292) : const Color(0xFF4B4B4B);
    final actionColor = isDarkMode ? const Color(0xFF319B8F) : const Color(0xFF5BBDB1);
    final separatorColor = isDarkMode ? const Color(0xFF2B2B2B) : const Color(0xFFE0E0E0);
    final btnTextColor = isDarkMode ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
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
                      width: 290 * s,
                      child: Text(
                        'تحقق من بريدك الإلكتروني',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: headingColor,
                          fontSize: 24 * s,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                          height: 1.33,
                        ),
                      ),
                    ),

                    SizedBox(height: 8 * s),

                    // Subtitle with email highlighted
                    SizedBox(
                      width: 285 * s,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'استخدم الرابط الذي أرسلناه إلى ',
                              style: TextStyle(
                                color: bodyColor,
                                fontSize: 14 * s,
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.w600,
                                height: 1.43,
                              ),
                            ),
                            TextSpan(
                              text: widget.email,
                              style: TextStyle(
                                color: bodyColor,
                                fontSize: 14 * s,
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.w700,
                                height: 1.43,
                              ),
                            ),
                            TextSpan(
                              text: ' لإعادة تعيين كلمة المرور. لم يصلك؟ تحقق من مجلد غير الهامة أو أعد إرسال الرابط.',
                              style: TextStyle(
                                color: bodyColor,
                                fontSize: 14 * s,
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.w600,
                                height: 1.43,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),

                    // Resent confirmation
                    if (_resent)
                      Padding(
                        padding: EdgeInsets.only(top: 12 * s),
                        child: Text(
                          'تم إعادة إرسال الرابط ✅',
                          style: TextStyle(
                            color: actionColor,
                            fontSize: 13 * s,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── BOTTOM BUTTONS ──
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomPadding + 16 * s,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Separator line
                  Container(
                    width: 360 * s,
                    height: 0.5,
                    color: separatorColor,
                  ),

                  SizedBox(height: 8 * s),

                  // "العودة إلى تسجيل الدخول" button
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
                        color: actionColor,
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
                        child: Text(
                          'العودة إلى تسجيل الدخول',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: btnTextColor,
                            fontSize: 16 * s,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // "إعادة إرسال الرابط" text button
                  GestureDetector(
                    onTap: _isResending ? null : _resendLink,
                    child: Container(
                      width: 300 * s,
                      height: 52 * s,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12 * s,
                        vertical: 16 * s,
                      ),
                      child: Center(
                        child: _isResending
                            ? SizedBox(
                                width: 20 * s,
                                height: 20 * s,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: actionColor,
                                ),
                              )
                            : Text(
                                'إعادة إرسال الرابط',
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
