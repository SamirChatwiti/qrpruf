import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qrpruf/providers/theme_provider.dart';
import 'package:qrpruf/pages/check_email_page.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  bool get isDarkMode {
    final themeMode = ref.watch(themeProvider);
    if (themeMode == ThemeMode.dark) return true;
    if (themeMode == ThemeMode.light) return false;
    return MediaQuery.of(context).platformBrightness == Brightness.dark;
  }

  Future<void> _onSendLink() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال بريدك الإلكتروني');
      return;
    }

    // Basic email validation
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      setState(() => _errorMessage = 'يرجى إدخال بريد إلكتروني صحيح');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'qrpruf://reset-password',
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CheckEmailPage(email: email),
        ),
      );
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _friendlyAuthError(e);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'حدث خطأ غير متوقع. يرجى المحاولة لاحقاً';
          _isLoading = false;
        });
      }
    }
  }

  String _friendlyAuthError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('rate limit')) {
      return 'عدد كبير من المحاولات. يرجى الانتظار قليلاً';
    }
    if (msg.contains('user not found')) {
      return 'لا يوجد حساب بهذا البريد الإلكتروني';
    }
    return 'حدث خطأ: ${e.message}';
  }

  @override
  void dispose() {
    _emailController.dispose();
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
    final bodyColor = isDarkMode ? const Color(0xFF929292) : const Color(0xFF4B4B4B);
    final placeholderColor = isDarkMode ? const Color(0xFF6E6E6E) : const Color(0xFFB8B8B8);
    final actionColor = isDarkMode ? const Color(0xFF319B8F) : const Color(0xFF5BBDB1);
    final borderColor = isDarkMode ? const Color(0xFF909090) : const Color(0xFF858585);
    final separatorColor = isDarkMode ? const Color(0xFF2B2B2B) : const Color(0xFFE0E0E0);
    final btnTextColor = isDarkMode ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: false,
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            // ═══════════════════════════════════════════
            // ── Back arrow ──
            // ═══════════════════════════════════════════
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

            // ═══════════════════════════════════════════
            // ── CONTENT ──
            // ═══════════════════════════════════════════
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
                        'هل نسيت كلمة المرور؟',
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

                    // Subtitle
                    SizedBox(
                      width: 285 * s,
                      child: Text(
                        'يرجى تأكيد بريدك الإلكتروني، وسنرسل لك رابطًا لإنشاء كلمة مرور جديدة',
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

                    // Email field
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
                            hintText: 'بريدك الإلكتروني',
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

            // ═══════════════════════════════════════════
            // ── BOTTOM: "إرسال الرابط" button ──
            // ═══════════════════════════════════════════
            Positioned(
              left: 0,
              right: 0,
              bottom: (keyboardHeight > 0 ? keyboardHeight + 8 * s : bottomPadding + 16 * s),
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

                  // "إرسال الرابط" button
                  GestureDetector(
                    onTap: _isLoading ? null : _onSendLink,
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
                        child: _isLoading
                            ? SizedBox(
                                width: 20 * s,
                                height: 20 * s,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: btnTextColor,
                                ),
                              )
                            : Text(
                                'إرسال الرابط',
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
