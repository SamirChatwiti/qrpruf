import 'package:flutter/material.dart';

class WassitStepIndicator extends StatelessWidget {
  final int activeStep;
  final Color? backgroundColor;
  final bool isDark;

  const WassitStepIndicator({
    super.key,
    required this.activeStep,
    this.backgroundColor,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor ?? (isDark ? Colors.black : Colors.transparent),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStep(1, 'الخطوة 1', activeStep >= 1),
          _buildDivider(activeStep >= 2),
          _buildStep(2, 'الخطوة 2', activeStep >= 2),
          _buildDivider(activeStep >= 3),
          _buildStep(3, 'الخطوة 3', activeStep >= 3),
        ],
      ),
    );
  }

  Widget _buildStep(int step, String label, bool isActive) {
    // Colors for the circle
    final Color circleColor;
    if (isActive) {
      circleColor = const Color(0xFF319B8F);
    } else {
      circleColor = isDark ? const Color(0xFF282828) : const Color(0xFFE0E0E0);
    }

    // Colors for the text inside the circle
    final Color textColor = isActive ? Colors.white : (isDark ? const Color(0xFFF9F9F9) : Colors.black54);

    // Color for the label below
    final Color labelColor;
    if (isActive) {
      labelColor = isDark ? const Color(0xFFF9F9F9) : const Color(0xFF319B8F);
    } else {
      labelColor = isDark ? const Color(0xFF6E6E6E) : Colors.black38;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: ShapeDecoration(
            color: circleColor,
            shape: RoundedRectangleBorder(
              side: isActive 
                ? BorderSide.none 
                : BorderSide(width: 0.25, color: isDark ? const Color(0xFF6E6E6E) : Colors.black26),
              borderRadius: BorderRadius.circular(1024),
            ),
            shadows: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              )
            ],
          ),
          child: Center(
            child: Text(
              step.toString(),
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: 11,
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(bool isActive) {
    return Container(
      width: 48,
      height: 2,
      margin: const EdgeInsets.only(left: 4, right: 4, bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF6E6E6E) : Colors.black12,
      ),
    );
  }
}
