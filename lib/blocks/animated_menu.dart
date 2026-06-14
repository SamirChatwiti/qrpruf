import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrpruf/providers/theme_provider.dart';
import 'dart:math' as math;

class AnimatedMenu extends ConsumerStatefulWidget {
  final int selectedIndex;
  final VoidCallback? onHomeTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onFunctionsTap; // Was Phone
  final VoidCallback? onContractsTap; // Was Clock
  final VoidCallback? onMomentTap; // Was Message
  final ValueChanged<bool>? onMenuToggle;

  const AnimatedMenu({
    super.key,
    required this.selectedIndex,
    this.onHomeTap,
    this.onProfileTap,
    this.onFunctionsTap,
    this.onContractsTap,
    this.onMomentTap,
    this.onMenuToggle,
  });

  @override
  ConsumerState<AnimatedMenu> createState() => _AnimatedMenuState();
}

class _AnimatedMenuState extends ConsumerState<AnimatedMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.easeIn),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    if (_controller.isDismissed) {
      _controller.forward();
      widget.onMenuToggle?.call(true);
    } else {
      _controller.reverse();
      widget.onMenuToggle?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double safeBottom = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      height: 220 + safeBottom,
      width: size.width,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // Background/Navigation Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 70 + safeBottom,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: EdgeInsets.only(bottom: safeBottom),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                   // Profile Button (Right in RTL, but Row is LTR by default unless localized)
                   // We will stick to the visual order in the design:
                   // Left: Home, Right: Profile.
                   // But User wants Arabic, so RTL.
                   // In RTL: Right is Start.
                   // So in RTL Row: First Child is Right.
                   
                   // Let's assume Directionality is RTL in parent.
                   // Child 1 (Right): Profile (حسابي)
                   // Child 2 (Left): Home (الرئيسية)
                   
                   // Wait, usually Home is first.
                   // Let's stick to: Home (Right/Start), Profile (Left/End) for Arabic?
                   // No, usually default is Right to Left.
                   // So First element = Right.
                   
                   // Element 1 (Right): Home
                  _NavButton(
                    icon: widget.selectedIndex == 0 ? Icons.home_filled : Icons.home_outlined,
                    label: 'الرئيسية',
                    isActive: widget.selectedIndex == 0,
                    onTap: widget.onHomeTap,
                  ),
                  
                  const SizedBox(width: 60), // Space for FAB
                  
                  // Element 2 (Left): Profile
                   _NavButton(
                    icon: widget.selectedIndex == 1 ? Icons.person : Icons.person_outline,
                    label: 'حسابي',
                    isActive: widget.selectedIndex == 1,
                    onTap: widget.onProfileTap,
                  ),

                  // Theme Toggle
                  _buildThemeToggle(context),
                ],
              ),
            ),
          ),

          // Satellite Buttons (Animated)
          // Icon 1 (Right - 45 deg): Functions (الوظائف)
          _SatelliteButton(
            angle: math.pi / 4, 
            distance: 90,
            color: Theme.of(context).colorScheme.secondary,
            icon: Icons.business_center, // Filled Bag
            tooltip: 'الوظائف',
            animation: _expandAnimation,
            fade: _fadeAnimation,
            onTap: () {
               FocusScope.of(context).unfocus();
               _toggleMenu();
               widget.onFunctionsTap?.call();
            },
          ),
          // Icon 2 (Center - 90 deg/Up): Contracts (العقود)
          _SatelliteButton(
            angle: 0, 
            distance: 100,
            color: Theme.of(context).colorScheme.secondary, 
            icon: Icons.assignment, // Filled Document
            tooltip: 'العقود',
            animation: _expandAnimation,
            fade: _fadeAnimation,
             onTap: () {
               FocusScope.of(context).unfocus();
               _toggleMenu();
               widget.onContractsTap?.call();
            },
          ),
          // Icon 3 (Left - 135 deg): Moment (لحظة)
          _SatelliteButton(
            angle: -math.pi / 4, 
            distance: 90,
            color: Theme.of(context).colorScheme.secondary,
            icon: Icons.camera_alt, // Filled Camera
            tooltip: 'لحظة',
            animation: _expandAnimation,
            fade: _fadeAnimation,
             onTap: () {
               FocusScope.of(context).unfocus();
               _toggleMenu();
               widget.onMomentTap?.call();
            },
          ),

          // Main Toggle Button (FAB)
          Positioned(
            bottom: 45 + safeBottom, 
            child: GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
                _toggleMenu();
              },
              child: RotationTransition(
                turns: _rotateAnimation,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return IconButton(
      icon: Icon(
        isDark ? Icons.light_mode : Icons.dark_mode,
        color: Theme.of(context).primaryColor,
      ),
      onPressed: () {
        ref.read(themeProvider.notifier).toggle();
      },
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Active Color: Blue, Inactive: Grey
    final color = isActive ? Theme.of(context).primaryColor : Theme.of(context).disabledColor;
    
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SatelliteButton extends StatelessWidget {
  final double angle;
  final double distance;
  final Color color;
  final IconData icon;
  final String tooltip;
  final Animation<double> animation;
  final Animation<double> fade;
  final VoidCallback? onTap;

  const _SatelliteButton({
    required this.angle,
    required this.distance,
    required this.color,
    required this.icon,
    required this.tooltip,
    required this.animation,
    required this.fade,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double safeBottom = MediaQuery.of(context).padding.bottom;
    final double fabCenterY = 45 + safeBottom + 28; 

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final double dist = distance * animation.value;
        final double dx = dist * math.sin(angle);
        final double dy = dist * math.cos(angle);

        return Positioned(
          bottom: fabCenterY - 24 + dy, 
          left: 0, 
          right: 0, 
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Transform.translate(
              offset: Offset(dx, 0),
              child: Opacity(
                opacity: fade.value,
                child: Tooltip(
                  message: tooltip,
                  child: GestureDetector(
                    onTap: onTap,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
