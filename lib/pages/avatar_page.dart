import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qrpruf/providers/theme_provider.dart';
import 'package:go_router/go_router.dart';

class AvatarPage extends ConsumerStatefulWidget {
  const AvatarPage({super.key});

  @override
  ConsumerState<AvatarPage> createState() => _AvatarPageState();
}

class _AvatarPageState extends ConsumerState<AvatarPage> {
  File? _selectedImage;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  bool get isDarkMode {
    final themeMode = ref.watch(themeProvider);
    if (themeMode == ThemeMode.dark) return true;
    if (themeMode == ThemeMode.light) return false;
    return MediaQuery.of(context).platformBrightness == Brightness.dark;
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );

    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<void> _uploadAndContinue() async {
    if (_selectedImage == null) {
      _navigateNext();
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _navigateNext();
        return;
      }

      final fileExt = _selectedImage!.path.split('.').last;
      final fileName = '${user.id}/avatar.$fileExt';

      // Upload to Supabase Storage
      await Supabase.instance.client.storage
          .from('avatars')
          .upload(
            fileName,
            _selectedImage!,
            fileOptions: const FileOptions(upsert: true),
          );

      // Get public URL
      final avatarUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(fileName);

      // Update user metadata
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {'avatar_url': avatarUrl},
        ),
      );

      if (!mounted) return;
      _navigateNext();
    } catch (e) {
      debugPrint('AVATAR UPLOAD ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ أثناء رفع الصورة، يمكنك تغييرها لاحقاً',
              textAlign: TextAlign.right,
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
        // Continue anyway
        _navigateNext();
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _navigateNext() {
    context.go('/notifications');
  }

  void _onSkip() {
    _navigateNext();
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
    final progressBgColor = isDarkMode ? const Color(0x4C387D78) : const Color(0x4CADE1D6);
    final chevronColor = isDarkMode ? const Color(0xFFF9F9F9) : const Color(0xFF111111);
    final avatarBgColor = isDarkMode ? const Color(0xFF2B2B2B) : const Color(0xFFE6EAED);
    final buttonTextColor = isDarkMode ? Colors.black : Colors.white;
    final separatorColor = isDarkMode ? const Color(0xFF2B2B2B) : const Color(0xFFE0E0E0);
    final editBadgeBg = isDarkMode ? const Color(0xFF3A3A3A) : const Color(0xFFE6EAED);
    final editBadgeBorder = isDarkMode ? const Color(0xFF191919) : Colors.white;

    final bool hasImage = _selectedImage != null;

    return Scaffold(
      backgroundColor: bgColor,
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            // ═══════════════════════════════════════════
            // ── PROGRESS BAR (step 6/7 = 257.14) ──
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
                        width: 257.14 * s,
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
                onTap: () => Navigator.pop(context),
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

            // ═══════════════════════════════════════════
            // ── TITLE + SUBTITLE + AVATAR ──
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
                        'اختر صورة شخصية',
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
                        'هل لديك صورة مفضلة؟ أضفها الآن',
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

                    // Avatar circle
                    GestureDetector(
                      onTap: _pickImage,
                      child: SizedBox(
                        width: (hasImage ? 140 : 110) * s,
                        height: (hasImage ? 140 : 110) * s,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Avatar container
                            Container(
                              width: (hasImage ? 140 : 110) * s,
                              height: (hasImage ? 140 : 110) * s,
                              decoration: ShapeDecoration(
                                color: hasImage ? null : avatarBgColor,
                                image: hasImage
                                    ? DecorationImage(
                                        image: FileImage(_selectedImage!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(77),
                                ),
                              ),
                              child: hasImage
                                  ? null
                                  : Center(
                                      child: SvgPicture.asset(
                                        'assets/images/avatar/user.svg',
                                        width: 74 * s,
                                        height: 74 * s,
                                        colorFilter: ColorFilter.mode(
                                          isDarkMode ? const Color(0xFF6E6E6E) : Colors.white,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    ),
                            ),

                            // Edit badge (only when image selected)
                            if (hasImage)
                              Positioned(
                                right: 0,
                                top: 8 * s,
                                child: Container(
                                  width: 28 * s,
                                  height: 28 * s,
                                  decoration: ShapeDecoration(
                                    color: editBadgeBg,
                                    shape: RoundedRectangleBorder(
                                      side: BorderSide(
                                        width: 1.5,
                                        strokeAlign: BorderSide.strokeAlignOutside,
                                        color: editBadgeBorder,
                                      ),
                                      borderRadius: BorderRadius.circular(77),
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.edit,
                                      size: 14 * s,
                                      color: isDarkMode
                                          ? const Color(0xFFF9F9F9)
                                          : const Color(0xFF4B4B4B),
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
            ),

            // ═══════════════════════════════════════════
            // ── BOTTOM BUTTONS ──
            // ═══════════════════════════════════════════
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomPadding + 16 * s,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Separator
                  Container(
                    width: 360 * s,
                    height: 0.5,
                    color: separatorColor,
                  ),

                  SizedBox(height: 16 * s),

                  // ── Top button (Skip / Change photo) ──
                  GestureDetector(
                    onTap: _isUploading
                        ? null
                        : (hasImage ? _pickImage : _onSkip),
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
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          hasImage ? 'تغيير الصورة' : 'لاحقًا',
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

                  // ── Bottom button (Add photo / Finish) ──
                  GestureDetector(
                    onTap: _isUploading
                        ? null
                        : (hasImage ? _uploadAndContinue : _pickImage),
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
                        child: _isUploading
                            ? SizedBox(
                                width: 20 * s,
                                height: 20 * s,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: buttonTextColor,
                                ),
                              )
                            : Text(
                                hasImage ? 'إنهاء' : 'إضافة صورة شخصية',
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
