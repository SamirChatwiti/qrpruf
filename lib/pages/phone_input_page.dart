import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qrpruf/providers/theme_provider.dart';

class PhoneInputPage extends ConsumerStatefulWidget {
  const PhoneInputPage({super.key});

  @override
  ConsumerState<PhoneInputPage> createState() => _PhoneInputPageState();
}

class _PhoneInputPageState extends ConsumerState<PhoneInputPage> {
  final TextEditingController _phoneController = TextEditingController();
  String? _errorMessage;
  String? _guidanceMessage;
  bool _isLoading = false;

  bool get isDarkMode {
    final themeMode = ref.watch(themeProvider);
    if (themeMode == ThemeMode.dark) return true;
    if (themeMode == ThemeMode.light) return false;
    return MediaQuery.of(context).platformBrightness == Brightness.dark;
  }

  /// Validates Moroccan phone number (9 digits, starts with 6 or 7)
  String? _validatePhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-]'), '');

    if (cleaned.isEmpty) {
      return 'يرجى إدخال رقم هاتفك';
    }

    if (!RegExp(r'^\d+$').hasMatch(cleaned)) {
      return 'يجب أن يحتوي الرقم على أرقام فقط';
    }

    // Check first digit BEFORE length — block invalid first digit immediately
    if (!cleaned.startsWith('6') && !cleaned.startsWith('7')) {
      return 'يجب أن يبدأ الرقم بـ 6 أو 7';
    }

    if (cleaned.length != 9) {
      return 'يجب أن يتكون الرقم من 9 أرقام';
    }

    return null;
  }

  /// Real-time guidance while typing
  void _updateGuidance(String value) {
    final cleaned = value.replaceAll(RegExp(r'[\s\-]'), '');
    setState(() {
      _errorMessage = null;
      if (cleaned.isEmpty) {
        _guidanceMessage = null;
      } else if (!RegExp(r'^\d+$').hasMatch(cleaned)) {
        _guidanceMessage = null;
        _errorMessage = 'يجب أن يحتوي الرقم على أرقام فقط';
      } else if (cleaned.length == 1 && !cleaned.startsWith('6') && !cleaned.startsWith('7')) {
        _errorMessage = 'يجب أن يبدأ الرقم بـ 6 أو 7';
        _guidanceMessage = null;
      } else if (cleaned.length < 9) {
        _errorMessage = null;
        _guidanceMessage = 'أدخل ${9 - cleaned.length} أرقام أخرى';
      } else if (cleaned.length == 9) {
        _guidanceMessage = '✓ الرقم صالح';
      }
    });
  }

  Future<void> _verifyViaWhatsApp() async {
    final error = _validatePhone(_phoneController.text);
    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      if (!mounted) return;
      context.go('/avatar');
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = _friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyViaSMS() async {
    final error = _validatePhone(_phoneController.text);
    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      if (!mounted) return;
      context.go('/avatar');
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = _friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('phone_provider_disabled') || msg.contains('unsupported phone provider')) {
      return 'خدمة التحقق عبر الهاتف غير مفعّلة حالياً. يرجى المحاولة لاحقاً';
    }
    if (msg.contains('rate_limit') || msg.contains('too many requests')) {
      return 'عدد كبير من المحاولات. يرجى الانتظار قليلاً';
    }
    if (msg.contains('invalid_phone') || msg.contains('invalid phone')) {
      return 'رقم الهاتف غير صالح';
    }
    return 'حدث خطأ غير متوقع. يرجى المحاولة لاحقاً';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
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
    final placeholderColor = isDarkMode ? const Color(0xFFB8B8B8) : const Color(0xFF929292);
    final actionColor = isDarkMode ? const Color(0xFF319B8F) : const Color(0xFF5BBDB1);
    final progressBgColor = isDarkMode ? const Color(0x4C387D78) : const Color(0x4CADE1D6);
    final borderColor = isDarkMode ? const Color(0xFF909090) : const Color(0xFF858585);
    final chevronColor = isDarkMode ? const Color(0xFFF9F9F9) : const Color(0xFF111111);
    final separatorColor = isDarkMode ? const Color(0xFF2B2B2B) : const Color(0xFFE0E0E0);
    const whatsappBtnColor = Color(0xFF25D366);
    final whatsappTextColor = isDarkMode ? Colors.black : Colors.white;
    final smsBtnBg = isDarkMode ? const Color(0xFF191919) : Colors.white;
    final smsBorderColor = isDarkMode ? const Color(0xFF319B8F) : const Color(0xFF5BBDB1);
    final smsTextColor = isDarkMode ? const Color(0xFF319B8F) : const Color(0xFF5BBDB1);

    return Scaffold(
      backgroundColor: bgColor,
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            // ═══════════════════════════════════════════
            // ── PROGRESS BAR (step 2/7) ──
            // ═══════════════════════════════════════════
            Positioned(
              left: 0,
              right: 0,
              top: statusBarHeight + 41 * s,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 30 * s, vertical: 10 * s),
                child: SizedBox(
                  width: 300 * s,
                  height: 5 * s,
                  child: Stack(
                    children: [
                      Container(
                        width: 300 * s,
                        height: 5 * s,
                        decoration: ShapeDecoration(
                          color: progressBgColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(1024),
                          ),
                        ),
                      ),
                      Container(
                        width: 85.71 * s,
                        height: 5 * s,
                        decoration: ShapeDecoration(
                          color: actionColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(1024),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ═══════════════════════════════════════════
            // ── BACK ARROW ──
            // ═══════════════════════════════════════════
            Positioned(
              right: 20 * s,
              top: statusBarHeight + 66 * s,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.go('/id-scan'),
                child: SizedBox(
                  width: 44 * s,
                  height: 44 * s,
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/images/tel/Chevron Right.svg',
                      width: 24 * s,
                      height: 24 * s,
                      colorFilter: ColorFilter.mode(chevronColor, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
            ),

            // ═══════════════════════════════════════════
            // ── TITLE + SUBTITLE + PHONE INPUT ──
            // ═══════════════════════════════════════════
            Positioned(
              left: 0,
              right: 0,
              top: statusBarHeight + 110 * s,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 30 * s),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Title
                    SizedBox(
                      width: 268 * s,
                      child: Text(
                        'أدخل رقم هاتفك',
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
                      width: 228 * s,
                      child: Text(
                        'سنرسل لك رمز تحقق — يساعدنا ذلك في حماية حسابك',
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

                    // Phone input field
                    Container(
                      width: 300 * s,
                      height: 52 * s,
                      decoration: ShapeDecoration(
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            width: 1,
                            strokeAlign: BorderSide.strokeAlignOutside,
                            color: _errorMessage != null
                                ? Colors.red
                                : borderColor,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Row(
                          children: [
                            // Country code (LEFT)
                            Padding(
                              padding: EdgeInsets.only(left: 16 * s),
                              child: Text(
                                '+212',
                                style: TextStyle(
                                  color: headingColor,
                                  fontSize: 14 * s,
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w700,
                                  height: 1.43,
                                ),
                              ),
                            ),
                            SizedBox(width: 10 * s),
                            // Phone number input (RIGHT)
                            Expanded(
                              child: TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                textDirection: TextDirection.ltr,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(9),
                                ],
                                style: TextStyle(
                                  color: headingColor,
                                  fontSize: 14 * s,
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w400,
                                  height: 1.43,
                                ),
                                decoration: InputDecoration(
                                  hintText: '652-832904',
                                  hintStyle: TextStyle(
                                    color: placeholderColor,
                                    fontSize: 14 * s,
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.w400,
                                    height: 1.43,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 16 * s,
                                  ),
                                ),
                                onChanged: (value) {
                                  _updateGuidance(value);
                                },
                              ),
                            ),
                          ],
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

                    // Guidance message
                    if (_errorMessage == null && _guidanceMessage != null)
                      Padding(
                        padding: EdgeInsets.only(top: 8 * s),
                        child: SizedBox(
                          width: 300 * s,
                          child: Text(
                            _guidanceMessage!,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: _guidanceMessage!.contains('✓')
                                  ? actionColor
                                  : bodyColor,
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
            // ── BOTTOM: WhatsApp + SMS buttons ──
            // ═══════════════════════════════════════════
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

                  SizedBox(height: 16 * s),

                  // WhatsApp button
                  GestureDetector(
                    onTap: _isLoading ? null : _verifyViaWhatsApp,
                    child: Container(
                      width: 300 * s,
                      padding: EdgeInsets.symmetric(vertical: 16 * s),
                      decoration: ShapeDecoration(
                        color: whatsappBtnColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(1024),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isLoading)
                            SizedBox(
                              width: 20 * s,
                              height: 20 * s,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: whatsappTextColor,
                              ),
                            )
                          else ...[
                            Text(
                              'التحقق عبر الواتساب',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: whatsappTextColor,
                                fontSize: 16 * s,
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.w500,
                                height: 1.25,
                              ),
                            ),
                            SizedBox(width: 8 * s),
                            SvgPicture.asset(
                              'assets/images/tel/whatsapp.svg',
                              width: 20 * s,
                              height: 20 * s,
                              colorFilter: ColorFilter.mode(
                                whatsappTextColor,
                                BlendMode.srcIn,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 8 * s),

                  // SMS button
                  GestureDetector(
                    onTap: _isLoading ? null : _verifyViaSMS,
                    child: Container(
                      width: 300 * s,
                      padding: EdgeInsets.symmetric(vertical: 16 * s),
                      decoration: ShapeDecoration(
                        color: smsBtnBg,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            width: 1,
                            color: smsBorderColor,
                          ),
                          borderRadius: BorderRadius.circular(1024),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'التحقق عبر SMS',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: smsTextColor,
                              fontSize: 16 * s,
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w500,
                              height: 1.25,
                            ),
                          ),
                        ],
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
