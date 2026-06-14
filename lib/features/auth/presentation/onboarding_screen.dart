import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/providers/app_state_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<Map<String, String>> _slides = [
    {
      'line1': 'التطبيق الذي يمنحك',
      'line2': 'توثيق وحماية',
      'line3': 'الدليل',
      'subtitle': 'بشكل آمن وموثوق',
    },
    {
      'line1': 'التقط الأدلة بكل',
      'line2': 'سهولة وسرعة',
      'line3': 'وأمان',
      'subtitle': 'صور، فيديو، صوت ونصوص',
    },
    {
      'line1': 'تشفير متقدم',
      'line2': 'يحمي بياناتك',
      'line3': 'الرقمية',
      'subtitle': 'ختم زمني ومكاني معتمد',
    },
    {
      'line1': 'قوة إثبات',
      'line2': 'معترف بها',
      'line3': 'قانونياً',
      'subtitle': 'في جميع المحاكم المغربية',
    },
  ];

  Future<void> _completeOnboarding() async {
    await ref.read(onboardingCompletedProvider.notifier).completeOnboarding();
    if (mounted) {
      context.go('/signup');
    }
  }

  Future<void> _navigateToLogin() async {
    await ref.read(onboardingCompletedProvider.notifier).completeOnboarding();
    if (mounted) context.go('/login');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final double s = screenWidth / 360;

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final bgColor = theme.scaffoldBackgroundColor;
    final circleColor = isDarkMode ? const Color(0xFF2B2B2B) : const Color(0xFFDDDDDD);
    final logoBgColor = isDarkMode ? const Color(0xFF414141) : const Color(0xFFF4F4F4);
    final headingColor = isDarkMode ? const Color(0xFFF9F9F9) : const Color(0xFF111111);
    final actionColor = theme.primaryColor;
    final subtitleColor = isDarkMode ? const Color(0xFF6E6E6E) : const Color(0xFFB8B8B8);
    final dotInactiveColor = actionColor.withValues(alpha: 0.3);
    final buttonTextColor = isDarkMode ? Colors.black : Colors.white;
    final bodyTextColor = isDarkMode ? const Color(0xFF929292) : const Color(0xFF4B4B4B);

    return Scaffold(
      backgroundColor: bgColor,
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            // Decorative Circles
            Positioned(
              left: -55 * s,
              top: statusBarHeight + 20 * s,
              child: Container(
                width: 267 * s,
                height: 263 * s,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                  image: const DecorationImage(
                    image: AssetImage('assets/images/onboard/photo.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 272 * s,
              top: statusBarHeight + 110 * s,
              child: Container(
                width: 184 * s,
                height: 184 * s,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: 130 * s,
              top: statusBarHeight + 154 * s,
              child: Container(
                width: 100 * s,
                height: 100 * s,
                decoration: BoxDecoration(
                  color: logoBgColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/images/onboard/QRpruf primary.svg',
                    width: 70 * s,
                    height: 70 * s,
                  ),
                ),
              ),
            ),

            // Text Carousel
            Positioned(
              left: 0,
              right: 0,
              top: statusBarHeight + 286 * s,
              bottom: (170) * s + bottomPadding,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20 * s),
                    child: Column(
                      children: [
                        Text(
                          slide['line1']!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: headingColor,
                            fontSize: 28 * s,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          slide['line2']!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: headingColor,
                            fontSize: 28 * s,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          slide['line3']!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: actionColor,
                            fontSize: 28 * s,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: 12 * s),
                        Text(
                          slide['subtitle']!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: subtitleColor,
                            fontSize: 14 * s,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Section
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomPadding + 30 * s,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (index) {
                      final bool isActive = index == _currentPage;
                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4 * s),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: isActive ? 24 * s : 8 * s,
                          height: 8 * s,
                          decoration: BoxDecoration(
                            color: isActive ? actionColor : dotInactiveColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: 30 * s),
                  GestureDetector(
                    onTap: _completeOnboarding,
                    child: Container(
                      width: 280 * s,
                      height: 52 * s,
                      decoration: BoxDecoration(
                        color: actionColor,
                        borderRadius: BorderRadius.circular(1024),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'ابدأ الآن',
                          style: TextStyle(
                            color: buttonTextColor,
                            fontSize: 16 * s,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12 * s),
                  GestureDetector(
                    onTap: _navigateToLogin,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'لديك حساب؟ ',
                            style: TextStyle(
                              color: bodyTextColor,
                              fontSize: 14 * s,
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                            text: 'تسجيل الدخول',
                            style: TextStyle(
                              color: actionColor,
                              fontSize: 14 * s,
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w700,
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
