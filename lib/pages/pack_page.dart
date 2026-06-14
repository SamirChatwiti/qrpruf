import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qrpruf/providers/theme_provider.dart';
import 'package:go_router/go_router.dart';

class PackPage extends ConsumerStatefulWidget {
  const PackPage({super.key});

  @override
  ConsumerState<PackPage> createState() => _PackPageState();
}

class _PackPageState extends ConsumerState<PackPage> {
  int _selectedPack = 0; // 0=free, 1=standard, 2=pro, 3=enterprise
  bool _isYearly = false; // false=monthly, true=yearly
  final Set<int> _expandedPacks = {};

  // ── Feature data per pack ──
  static const List<List<String>> _packFeatures = [
    // Pack 0: Free
    [
      '5 صور يوميًا',
      '2 دقائق للتسجيل الصوتي يوميًا',
      'التحقق برمز QR',
      'حفظ و أرشفة البيانات لمدة 3 أشهر',
    ],
    // Pack 1: Standard
    [
      '5 دقائق لتسجيل الفيديو يوميًا',
      '10 صور يوميًا',
      '10 دقائق للتسجيل الصوتي يوميًا',
      'التحقق برمز QR',
      'حفظ و أرشفة البيانات لمدة 10 سنوات',
    ],
    // Pack 2: Pro
    [
      '20 دقيقة لتسجيل الفيديو يوميًا',
      '90 صورة يوميًا',
      '40 دقيقة للتسجيل الصوتي يوميًا',
      'التحقق برمز QR + وثيقة الإثبات',
      'حفظ و أرشفة البيانات لمدة 10 سنوات',
    ],
    // Pack 3: Enterprise
    [
      'تكامل عبر API',
      'إدارة متعددة للمستخدمين والصلاحيات',
      'تقارير وتتبع مهيكل',
      'قاعدة بيانات مخصصة',
      'دعم تقني مستمر',
      'اتفاقية مستوى خدمة (SLA)',
      'تخصيص حسب احتياجات المؤسسة',
    ],
  ];

  bool get isDarkMode {
    final themeMode = ref.watch(themeProvider);
    if (themeMode == ThemeMode.dark) return true;
    if (themeMode == ThemeMode.light) return false;
    return MediaQuery.of(context).platformBrightness == Brightness.dark;
  }

  Future<void> _onContinue() async {
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'pack_id': _selectedPack, 'subscribed': true, 'profile_complete': true}),
      );
    } catch (_) {}

    if (!mounted) return;
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final double s = screenWidth / 360;

    // ── Theme colors ──
    final bgColor = isDarkMode ? const Color(0xFF191919) : Colors.white;
    final headingColor =
        isDarkMode ? const Color(0xFFF9F9F9) : const Color(0xFF111111);
    final bodyColor =
        isDarkMode ? const Color(0xFF929292) : const Color(0xFF4B4B4B);
    final actionColor =
        isDarkMode ? const Color(0xFF319B8F) : const Color(0xFF5BBDB1);
    final borderDefault =
        isDarkMode ? const Color(0xFF6E6E6E) : const Color(0xFFB8B8B8);
    final cardBg = isDarkMode ? const Color(0xFF191919) : Colors.white;
    final selectedCardBg =
        isDarkMode ? const Color(0x4C387D78) : const Color(0x4CADE1D6);
    final toggleBg =
        isDarkMode ? Colors.black : const Color(0xFFF4F4F4);
    final toggleActiveBg = isDarkMode ? const Color(0xFF191919) : Colors.white;
    final toggleActiveBorder =
        isDarkMode ? Colors.transparent : const Color(0xFFB8B8B8);
    final buttonTextColor = isDarkMode ? Colors.black : Colors.white;
    final bottomBarBg = isDarkMode ? const Color(0xFF191919) : Colors.white;
    final bottomBarBorder =
        isDarkMode ? const Color(0xFF6E6E6E) : const Color(0xFFB8B8B8);
    final checkIconColor = actionColor;

    // ── Dynamic Bottom Bar Data ──
    String ctaText = 'متابعة';
    String? currentDue;
    String? originalDue;

    if (_selectedPack == 1) {
      ctaText = 'اشترك في الخطة القياسية';
      if (_isYearly) {
        currentDue = '499 درهم';
        originalDue = '588 درهم';
      } else {
        currentDue = '49 درهم';
      }
    } else if (_selectedPack == 2) {
      ctaText = 'اشترك في الخطة المهنية';
      if (_isYearly) {
        currentDue = '2.499 درهم';
        originalDue = '2.988 درهم';
      } else {
        currentDue = '249 درهم';
      }
    } else if (_selectedPack == 3) {
      ctaText = 'تواصل معنا'; // Enterprise pack
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        body: Stack(
          children: [
            // ═══════════════════════════════════════════
            // ── SCROLLABLE CONTENT ──
            // ═══════════════════════════════════════════
            SingleChildScrollView(
              padding: EdgeInsets.only(bottom: 136 * s),
              child: Column(
                children: [
                  // ── Hero image ──
                  SizedBox(
                    width: screenWidth,
                    height: 316 * s,
                    child: Stack(
                      children: [
                        Positioned(
                          left: -110 * s,
                          top: 0,
                          child: Image.asset(
                            isDarkMode 
                                ? 'assets/images/img_drk.png'
                                : 'assets/images/pack/pack_sans_preuve.png',
                            width: 580 * s,
                            height: 316 * s,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Title ──
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 39 * s),
                    child: SizedBox(
                      width: 282 * s,
                      child: Text(
                        'ارتقِ بتوثيقك إلى مستوى احترافي',
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
                  ),

                  SizedBox(height: 9 * s),

                  // ═══════════════════════════════════════════
                  // ── TOGGLE: Monthly / Yearly ──
                  // ═══════════════════════════════════════════
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8 * s),
                    child: Container(
                      width: 260 * s,
                      height: 48 * s,
                      padding: EdgeInsets.all(4 * s),
                      decoration: ShapeDecoration(
                        color: toggleBg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(1024),
                        ),
                      ),
                      child: Row(
                        children: [
                          // ── RIGHT tab (first in RTL): Monthly ──
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _isYearly = false),
                              child: Container(
                                height: double.infinity,
                                decoration: ShapeDecoration(
                                  color: !_isYearly
                                      ? toggleActiveBg
                                      : null,
                                  shape: RoundedRectangleBorder(
                                    side: !_isYearly
                                        ? BorderSide(
                                            width: 0.25,
                                            color: toggleActiveBorder,
                                          )
                                        : BorderSide.none,
                                    borderRadius:
                                        BorderRadius.circular(1024),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'شهري',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: headingColor,
                                      fontSize: 14 * s,
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.w700,
                                      height: 1.43,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // ── LEFT tab (second in RTL): Yearly with -15% badge ──
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isYearly = true),
                              child: Container(
                                height: double.infinity,
                                decoration: ShapeDecoration(
                                  color:
                                      _isYearly ? toggleActiveBg : null,
                                  shape: RoundedRectangleBorder(
                                    side: _isYearly
                                        ? BorderSide(
                                            width: 0.25,
                                            color: toggleActiveBorder,
                                          )
                                        : BorderSide.none,
                                    borderRadius:
                                        BorderRadius.circular(1024),
                                  ),
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        'سنوي',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          color: headingColor,
                                          fontSize: 14 * s,
                                          fontFamily: 'Cairo',
                                          fontWeight: FontWeight.w700,
                                          height: 1.43,
                                        ),
                                      ),
                                      SizedBox(width: 4 * s),
                                      // -15% badge
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8 * s,
                                          vertical: 2 * s,
                                        ),
                                        decoration: ShapeDecoration(
                                          color: _isYearly
                                              ? (isDarkMode 
                                                  ? const Color(0xFF319B8F) 
                                                  : const Color(0x4C5BBDB1))
                                              : actionColor,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(1024),
                                          ),
                                        ),
                                        child: Text(
                                          '-15%',
                                          textDirection: TextDirection.ltr,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: _isYearly
                                                ? (isDarkMode 
                                                    ? Colors.black 
                                                    : const Color(0xB25BBDB1))
                                                : Colors.white,
                                            fontSize: 10 * s,
                                            fontFamily: 'Cairo',
                                            fontWeight: FontWeight.w700,
                                            height: 1.40,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ═══════════════════════════════════════════
                  // ── PACK CARDS ──
                  // ═══════════════════════════════════════════
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 20 * s, vertical: 16 * s),
                    child: Column(
                      children: [
                        // ── Pack 0: Free ──
                        _buildPackCard(
                          s: s,
                          index: 0,
                          title: 'الخطة المجانية',
                          description:
                              'للاستخدام العرضي بسعة يومية محدودة',
                          price: null,
                          isDarkMode: isDarkMode,
                          headingColor: headingColor,
                          bodyColor: bodyColor,
                          actionColor: actionColor,
                          borderDefault: borderDefault,
                          cardBg: cardBg,
                          selectedCardBg: selectedCardBg,
                          checkIconColor: checkIconColor,
                        ),

                        SizedBox(height: 16 * s),

                        // ── Pack 1: Standard ──
                        _buildPackCard(
                          s: s,
                          index: 1,
                          title: 'الخطة القياسية',
                          description:
                              'للاستخدام المنتظم. سعة يومية أكبر مع جميع خصائص التحقق المتقدمة',
                          price: '49',
                          annualBilled: _isYearly ? '499 درهم تُدفع سنويًا' : null,
                          annualDiscount: _isYearly ? '(-15%)' : null,
                          annualOriginal: _isYearly ? '588 درهم' : null,
                          isDarkMode: isDarkMode,
                          headingColor: headingColor,
                          bodyColor: bodyColor,
                          actionColor: actionColor,
                          borderDefault: borderDefault,
                          cardBg: cardBg,
                          selectedCardBg: selectedCardBg,
                          checkIconColor: checkIconColor,
                        ),

                        SizedBox(height: 16 * s),

                        // ── Pack 2: Pro ──
                        _buildPackCard(
                          s: s,
                          index: 2,
                          title: 'الخطة المهنية',
                          description:
                              'مخصصة للمهنيين والتوثيق اليومي بسعة أعلى وإدارة متقدمة',
                          price: '249',
                          annualBilled: _isYearly ? '2.499 درهم تُدفع سنويًا' : null,
                          annualDiscount: _isYearly ? '(-16%)' : null,
                          annualOriginal: _isYearly ? '2.988 درهم' : null,
                          bestValue: true,
                          isDarkMode: isDarkMode,
                          headingColor: headingColor,
                          bodyColor: bodyColor,
                          actionColor: actionColor,
                          borderDefault: borderDefault,
                          cardBg: cardBg,
                          selectedCardBg: selectedCardBg,
                          checkIconColor: checkIconColor,
                        ),

                        SizedBox(height: 16 * s),

                        // ── Pack 3: Enterprise ──
                        _buildPackCard(
                          s: s,
                          index: 3,
                          title: 'الخطة المؤسسية',
                          description:
                              'للمؤسسات والجهات الكبرى بحلول مخصصة وقابلة للتوسع',
                          price: null,
                          isDarkMode: isDarkMode,
                          headingColor: headingColor,
                          bodyColor: bodyColor,
                          actionColor: actionColor,
                          borderDefault: borderDefault,
                          cardBg: cardBg,
                          selectedCardBg: selectedCardBg,
                          checkIconColor: checkIconColor,
                        ),

                        SizedBox(height: 16 * s),

                        // ── Terms & Privacy ──
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: (currentDue != null ? 68 : 28) * s,
                          ),
                          child: SizedBox(
                            width: 320 * s,
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'شروط الاستخدام',
                                    style: TextStyle(
                                      color: bodyColor,
                                      fontSize: 14 * s,
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                      height: 1.43,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' و ',
                                    style: TextStyle(
                                      color: bodyColor,
                                      fontSize: 14 * s,
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.w600,
                                      height: 1.43,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'سياسة الخصوصية',
                                    style: TextStyle(
                                      color: bodyColor,
                                      fontSize: 14 * s,
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                      height: 1.43,
                                    ),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ═══════════════════════════════════════════
            // ── BOTTOM CTA BAR ──
            // ═══════════════════════════════════════════
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.only(
                  left: 20 * s,
                  right: 20 * s,
                  top: 20 * s,
                  bottom: bottomPadding + 20 * s,
                ),
                decoration: ShapeDecoration(
                  color: bottomBarBg,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      width: 0.25,
                      color: bottomBarBorder,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(36),
                      topRight: Radius.circular(36),
                    ),
                  ),
                  shadows: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 2,
                      offset: Offset(0, -1),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (currentDue != null) ...[
                      Padding(
                        padding: EdgeInsets.only(bottom: 16 * s),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'المستحق اليوم',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: headingColor,
                                fontSize: 14 * s,
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.w700,
                                height: 1.43,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  currentDue!,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: headingColor,
                                    fontSize: 14 * s,
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.w700,
                                    height: 1.43,
                                  ),
                                ),
                                if (originalDue != null) ...[
                                  SizedBox(width: 8 * s),
                                  Text(
                                    originalDue!,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      color: const Color(0xFF929292),
                                      fontSize: 14 * s,
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.lineThrough,
                                      height: 1.43,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    GestureDetector(
                      onTap: _onContinue,
                      child: Container(
                        width: 320 * s,
                        height: 52 * s,
                        decoration: ShapeDecoration(
                          color: _selectedPack == 3 ? Colors.transparent : actionColor,
                          shape: RoundedRectangleBorder(
                            side: _selectedPack == 3
                                ? BorderSide(width: 1, color: actionColor)
                                : BorderSide.none,
                            borderRadius: BorderRadius.circular(1024),
                          ),
                          shadows: _selectedPack == 3
                              ? null
                              : const [
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
                            ctaText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _selectedPack == 3
                                  ? actionColor
                                  : buttonTextColor,
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
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ── Pack card builder ──
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildPackCard({
    required double s,
    required int index,
    required String title,
    required String description,
    required String? price,
    bool bestValue = false,
    required bool isDarkMode,
    String? annualBilled,
    String? annualDiscount,
    String? annualOriginal,
    required Color headingColor,
    required Color bodyColor,
    required Color actionColor,
    required Color borderDefault,
    required Color cardBg,
    required Color selectedCardBg,
    required Color checkIconColor,
  }) {
    final bool isSelected = _selectedPack == index;
    final bool isExpanded = _expandedPacks.contains(index);

    return GestureDetector(
      onTap: () => setState(() => _selectedPack = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 320 * s,
        padding: EdgeInsets.all(24 * s),
        decoration: ShapeDecoration(
          color: isSelected ? selectedCardBg : cardBg,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: isSelected ? 2 : 1,
              color: isSelected ? actionColor : borderDefault,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Content (RIGHT side in RTL) ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row + optional "Best value" badge
                  Row(
                    mainAxisAlignment: bestValue
                        ? MainAxisAlignment.spaceBetween
                        : MainAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: headingColor,
                          fontSize: 16 * s,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                          height: 1.50,
                        ),
                      ),
                      if (bestValue)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8 * s,
                            vertical: 4 * s,
                          ),
                          decoration: ShapeDecoration(
                            color: isDarkMode ? const Color(0xFF05DF72) : const Color(0xFF00C950),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(1024),
                            ),
                          ),
                          child: Text(
                            'أفضل قيمة',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDarkMode ? Colors.black : Colors.white,
                              fontSize: 10 * s,
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w600,
                              height: 1.40,
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Price row (if applicable)
                  if (price != null) ...[
                    SizedBox(height: 4 * s),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          price,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: headingColor,
                            fontSize: 20 * s,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w700,
                            height: 1.40,
                          ),
                        ),
                        SizedBox(width: 4 * s),
                        Text(
                          'درهم',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: headingColor,
                            fontSize: 16 * s,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w700,
                            height: 1.50,
                          ),
                        ),
                        SizedBox(width: 2 * s),
                        Text(
                          '/ الشهر',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: bodyColor,
                            fontSize: 10 * s,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w500,
                            height: 1.40,
                          ),
                        ),
                      ],
                    ),
                    if (annualBilled != null &&
                        annualDiscount != null &&
                        annualOriginal != null) ...[
                      SizedBox(height: 4 * s),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: annualBilled,
                                    style: TextStyle(
                                      color: const Color(0xFF929292),
                                      fontSize: 16 * s, // using 16 instead of 20 to fit better, though Figma says 20
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.w700,
                                      height: 1.40,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' ',
                                    style: TextStyle(
                                      color: const Color(0xFFB8B8B8),
                                      fontSize: 16 * s,
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.w700,
                                      height: 1.40,
                                    ),
                                  ),
                                  TextSpan(
                                    text: annualDiscount,
                                    style: TextStyle(
                                      color: actionColor,
                                      fontSize: 14 * s,
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.w700,
                                      height: 1.43,
                                    ),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            annualOriginal,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: const Color(0xFFB8B8B8),
                              fontSize: 14 * s,
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.lineThrough,
                              height: 1.50,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],

                  SizedBox(height: 8 * s),

                  // Description
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      description,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: bodyColor,
                        fontSize: 14 * s,
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w500,
                        height: 1.43,
                      ),
                    ),
                  ),

                  SizedBox(height: 8 * s),

                  // "Show/Hide features" link
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedPacks.remove(index);
                        } else {
                          _expandedPacks.add(index);
                        }
                      });
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          isExpanded ? 'إخفاء المزايا' : 'عرض المزايا',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: headingColor,
                            fontSize: 14 * s,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w700,
                            height: 1.43,
                          ),
                        ),
                        SizedBox(width: 8 * s),
                        Transform.rotate(
                          angle: isExpanded
                              ? 1.5708 // 90° → points UP
                              : -1.5708, // -90° → points DOWN
                          child: SvgPicture.asset(
                            'assets/images/avatar/chevron-down.svg',
                            width: 20 * s,
                            height: 20 * s,
                            colorFilter: ColorFilter.mode(
                              headingColor,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Expanded feature list ──
                  if (isExpanded) ...[
                    SizedBox(height: 8 * s),
                    ..._packFeatures[index].map(
                      (feature) => Padding(
                        padding: EdgeInsets.only(bottom: 8 * s),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check,
                              size: 20 * s,
                              color: checkIconColor,
                            ),
                            SizedBox(width: 8 * s),
                            Expanded(
                              child: Text(
                                feature,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: bodyColor,
                                  fontSize: 14 * s,
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w500,
                                  height: 1.43,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            SizedBox(width: 16 * s),

            // ── Checkbox (LEFT side in RTL) ──
            Container(
              width: 22 * s,
              height: 22 * s,
              decoration: ShapeDecoration(
                color: isSelected
                    ? actionColor
                    : (isDarkMode
                        ? const Color(0xFF232323)
                        : Colors.white),
                shape: RoundedRectangleBorder(
                  side: isSelected
                      ? BorderSide.none
                      : BorderSide(
                          width: 1,
                          color: isDarkMode
                              ? const Color(0xFF6E6E6E)
                              : Colors.black,
                        ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      size: 14 * s,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
