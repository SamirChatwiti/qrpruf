import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qrpruf/providers/theme_provider.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  bool _isLoading = false;

  bool get isDarkMode {
    final themeMode = ref.watch(themeProvider);
    if (themeMode == ThemeMode.dark) return true;
    if (themeMode == ThemeMode.light) return false;
    return MediaQuery.of(context).platformBrightness == Brightness.dark;
  }

  Future<void> _allowNotifications() async {
    setState(() => _isLoading = true);
    await Permission.notification.request();
    if (mounted) {
      setState(() => _isLoading = false);
      context.go('/pack');
    }
  }

  void _skip() {
    context.go('/pack');
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final double s = screenWidth / 360;

    final bgColor = isDarkMode ? const Color(0xFF191919) : Colors.white;
    final headingColor = isDarkMode ? const Color(0xFFF9F9F9) : const Color(0xFF111111);
    final bodyColor = isDarkMode ? const Color(0xFF929292) : const Color(0xFF4B4B4B);
    final actionColor = isDarkMode ? const Color(0xFF319B8F) : const Color(0xFF5BBDB1);
    final progressBgColor = isDarkMode ? const Color(0x4C387D78) : const Color(0x4CADE1D6);
    final chevronColor = isDarkMode ? const Color(0xFFF9F9F9) : const Color(0xFF111111);
    final iconBgColor = isDarkMode ? const Color(0xFF2B2B2B) : const Color(0xFFE6EAED);
    final buttonTextColor = isDarkMode ? Colors.black : Colors.white;
    final separatorColor = isDarkMode ? const Color(0xFF2B2B2B) : const Color(0xFFE0E0E0);

    return Scaffold(
      backgroundColor: bgColor,
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            // ── PROGRESS BAR (step 3/4 = 75%) ──
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
                        width: 225 * s,
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

            // ── BACK ARROW ──
            Positioned(
              right: 20 * s,
              top: statusBarHeight + 66 * s,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.go('/avatar'),
                child: SizedBox(
                  width: 44 * s,
                  height: 44 * s,
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/images/avatar/Chevron Right.svg',
                      width: 24 * s,
                      height: 24 * s,
                      colorFilter: ColorFilter.mode(chevronColor, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
            ),

            // ── TITLE + ICON ──
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
                    SizedBox(
                      width: 268 * s,
                      child: Text(
                        'تفعيل الإشعارات',
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
                        'ابقَ على اطّلاع بآخر مستجدات إثباتاتك',
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
                    SizedBox(height: 40 * s),
                    Container(
                      width: 110 * s,
                      height: 110 * s,
                      decoration: ShapeDecoration(
                        color: iconBgColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(77),
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.notifications_outlined,
                          size: 56 * s,
                          color: actionColor,
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
                  Container(
                    width: 360 * s,
                    height: 0.5,
                    color: separatorColor,
                  ),
                  SizedBox(height: 16 * s),
                  GestureDetector(
                    onTap: _isLoading ? null : _skip,
                    child: Container(
                      width: 300 * s,
                      height: 52 * s,
                      padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 16 * s),
                      decoration: ShapeDecoration(
                        shape: RoundedRectangleBorder(
                          side: BorderSide(width: 1, color: actionColor),
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
                          'لاحقًا',
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
                  SizedBox(height: 8 * s),
                  GestureDetector(
                    onTap: _isLoading ? null : _allowNotifications,
                    child: Container(
                      width: 300 * s,
                      height: 52 * s,
                      padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 16 * s),
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
                                  color: buttonTextColor,
                                ),
                              )
                            : Text(
                                'تفعيل الإشعارات',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: buttonTextColor,
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
