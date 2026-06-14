import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_compress/video_compress.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qrpruf/core/providers/wassit_provider.dart';
import 'package:qrpruf/models/proof.dart';
import 'package:qrpruf/features/proofs/data/models/draft.dart';
import 'package:qrpruf/features/proofs/presentation/screens/loc_gharad.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final PageController _statsPageController = PageController();
  int _currentStatsPage = 0;

  // Real Database Data
  int _verifiedCount = 0;
  int _totalCount = 0;
  int _todayImageCount = 0;
  int _todayVideoSeconds = 0;
  int _todayAudioSeconds = 0;
  List<Map<String, dynamic>> _recentProofs = [];
  Map<String, String?> _proofSignedUrls = {};      // fallback signed URLs
  Map<String, Uint8List?> _proofThumbBytes = {};   // primary: inline base64
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchDashboardData();
  }

  Future<void> fetchDashboardData() async {
    if (!mounted) return;
    setState(() {
       _isLoading = true;
       _recentProofs = []; // Clear for fresh look
    });
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Fetch Valid & Total Proofs from Supabase
      final proofsResponse = await supabase
          .from('proofs')
          .select('status')
          .eq('subject_id', user.id);
      
      final proofs = proofsResponse as List<dynamic>;
      _totalCount = proofs.length;
      _verifiedCount = proofs.where((p) => p['status'] == 'valid').length;

      // 3. Today's Media Usage (evidence_media table)
      final today = DateTime.now().toUtc().toIso8601String().split('T')[0];
      final mediaResponse = await supabase
          .from('evidence_media')
          .select('media_type, duration_seconds')
          .eq('user_id', user.id)
          .gte('created_at', '${today}T00:00:00Z');

      final mediaItems = mediaResponse as List<dynamic>;
      int imageCount = 0;
      int videoSeconds = 0;
      int audioSeconds = 0;

      for (var item in mediaItems) {
        final typeStr = item['media_type'] as String? ?? '';
        final dur = (item['duration_seconds'] as int?) ?? 0;
        if (typeStr == 'image') {
          imageCount++;
        } else if (typeStr == 'video') {
          videoSeconds += dur;
        } else if (typeStr == 'audio') {
          audioSeconds += dur;
        }
      }
      _todayImageCount = imageCount;
      _todayVideoSeconds = videoSeconds;
      _todayAudioSeconds = audioSeconds;

      // 4. Recent Proofs
      final recentResponse = await supabase
          .from('proofs')
          .select('*')
          .eq('subject_id', user.id)
          .order('created_at', ascending: false)
          .limit(3);
      
      _recentProofs = List<Map<String, dynamic>>.from(recentResponse);

      // Build thumbnail map: primary=base64 from DB, fallback=signed URL
      final Map<String, Uint8List?> thumbBytesMap = {};
      final Map<String, String?> signedUrls = {};
      for (final proof in _recentProofs) {
        final proofId = proof['proof_id']?.toString();
        if (proofId == null) continue;
        final raw = proof['media_assets'];
        final mediaAssets = raw is List ? raw : (raw is String ? ((){try{final d=jsonDecode(raw);return d is List?d:null;}catch(_){return null;}})() : null);
        if (mediaAssets == null) {
          debugPrint('⚠️ home: media_assets null for $proofId');
          continue;
        }
        for (final asset in mediaAssets) {
          final assetType = asset['type']?.toString().toLowerCase() ?? '';
          if (!assetType.contains('image') && !assetType.contains('video')) continue;

          // Primary: inline base64 thumbnail
          final b64 = asset['thumb_b64']?.toString();
          if (b64 != null && b64.isNotEmpty) {
            try {
              thumbBytesMap[proofId] = base64Decode(b64);
              debugPrint('✅ home: thumb_b64 decoded for ${proofId.substring(0,8)}');
            } catch (e) {
              debugPrint('⚠️ home: base64Decode failed: $e');
            }
            break;
          }

          // Fallback: signed URL for older proofs
          final assetUrl = asset['url']?.toString() ?? '';
          if (assetUrl.isNotEmpty) {
            final lastSlash = assetUrl.lastIndexOf('/');
            if (lastSlash >= 0) {
              final file = assetUrl.substring(lastSlash + 1);
              final thumbFileName = 'thumb_$file.jpg';
              try {
                final thumbUrl = await Supabase.instance.client.storage
                    .from('proof-media')
                    .createSignedUrl(thumbFileName, 3600);
                signedUrls[proofId] = thumbUrl;
                debugPrint('✅ home: signedUrl OK for ${proofId.substring(0,8)}');
              } catch (e) {
                debugPrint('⚠️ home: createSignedUrl failed for $thumbFileName: $e');
              }
            }
          }
          break;
        }
      }
      _proofThumbBytes = thumbBytesMap;
      _proofSignedUrls = signedUrls;

    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _statsPageController.dispose();
    super.dispose();
  }

  // Returns a valid display name, or the email if the stored name looks like OCR garbage
  String _resolveDisplayName(String? storedName, String? email) {
    if (storedName != null && storedName.trim().isNotEmpty) {
      final n = storedName.trim();
      final isValid = n.length <= 40 && RegExp(r'^[A-Za-z\s\-]+$').hasMatch(n);
      if (isValid) return n;
    }
    return email ?? 'مستخدم';
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata;
    final String? avatarUrl = metadata?['avatar_url'];
    final bool isVerified = metadata?['identity_verified'] == true;
    final String fullName = _resolveDisplayName(metadata?['full_name'] as String?, user?.email);

    // Reactively watch drafts
    final drafts = ref.watch(wassitProvider).drafts;
    final currentDraftsCount = drafts.length;

    // Combine Supabase usage + local drafts + session (wassit blocks)
    final wassitState = ref.watch(wassitProvider);
    final totalImageCount = _todayImageCount +
        drafts.where((d) => d.type == MediaType.image).length;
    final totalVideoSeconds = _todayVideoSeconds + wassitState.sessionVideoSeconds;
    final totalAudioSeconds = _todayAudioSeconds + wassitState.sessionAudioSeconds;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFFF4F4F4),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                color: Color(0xFFF4F4F4),
              ),
              child: Stack(
                children: [
                  // ── BACKGROUND GRADIENT & OVALS ──
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      width: MediaQuery.of(context).size.width,
                      height: 600,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFB9E5DD),
                            Color(0xFFF4F4F4),
                          ],
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: -100,
                            top: -150,
                            child: Container(
                              width: 560,
                              height: 400,
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: const Alignment(0.5, 0.5),
                                  radius: 0.6,
                                  colors: [
                                    const Color(0xFF5BBDB1).withValues(alpha: 0.3),
                                    Colors.transparent,
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
  
                  // ── MAIN CONTENT COLUMN ──
                  Column(
                    children: [
                      const SizedBox(height: 41),
  
                      // ── HEADER: SEARCH & AVATAR ──
                      _buildHeader(avatarUrl, isVerified),

                      // ── WELCOME MESSAGE ──
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '👋 مرحباً بك، $fullName',
                                style: const TextStyle(
                                  color: Color(0xFF111111),
                                  fontSize: 22,
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Text(
                                'إليك ملخص نشاطك لهذا الأسبوع',
                                style: TextStyle(
                                  color: Color(0xFF757575),
                                  fontSize: 12,
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // ── CIN VERIFICATION BANNER ──
                      if (!isVerified)
                        _buildVerificationBanner(),
  
                      if (_totalCount == 0 && currentDraftsCount == 0) ...[
                        _buildEmptyStateHero(context),
                      ] else ...[
                        const SizedBox(height: 48),
    
                        // ── STATS CAROUSEL ──
                        _buildStatsCarousel(currentDraftsCount),
    
                        const SizedBox(height: 28),
    
                        // ── PAGE DOTS ──
                        _buildPageDots(),
    
                        const SizedBox(height: 28),
    
                        // ── ACTION BUTTONS ──
                        _buildActionButtons(),
                      ],
  
                      const SizedBox(height: 24),
  
                      // ── DAILY CAPACITY ──
                      _buildDailyCapacityCard(
                        totalImageCount: totalImageCount,
                        totalVideoSeconds: totalVideoSeconds,
                        totalAudioSeconds: totalAudioSeconds,
                      ),
  
                      const SizedBox(height: 24),
  
                      // ── RECENT ACTIVITY ──
                      _buildRecentActivitySection(drafts),
  
                      const SizedBox(height: 50),
                    ],
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => context.push('/selection'),
            backgroundColor: const Color(0xFF5BBDB1),
            shape: const CircleBorder(),
            child: const Icon(Icons.add, color: Colors.white, size: 32),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: _buildBottomNavigationBar(),
        ),
      ),
    );
  }

  Widget _buildVerificationBanner() {
    return GestureDetector(
      onTap: () => context.push('/id-scan'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
        ),
        child: const Row(
          children: [
            Icon(Icons.badge_outlined, color: Colors.red, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تنبيه: مسح بطاقة التعريف (CIN)',
                    style: TextStyle(
                      color: Colors.red,
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'يرجى تأكيد هويتك لتفعيل حسابك بالكامل.',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontFamily: 'Cairo',
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.red, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String? avatarUrl, bool isVerified) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          // ── Profile (Right in visual, but FIRST in RTL Row) ──
          GestureDetector(
            onTap: () => context.push('/profile'),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    image: avatarUrl != null
                        ? DecorationImage(
                            image: NetworkImage(avatarUrl),
                            fit: BoxFit.cover,
                          )
                        : const DecorationImage(
                            image: AssetImage('assets/images/maquette1/img/Profile Picture.svg'),
                            fit: BoxFit.cover,
                          ),
                  ),
                  child: avatarUrl == null 
                    ? const Icon(Icons.person, color: Colors.grey, size: 20)
                    : null,
                ),
                if (!isVerified)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // ── Search Bar (Left in visual, but SECOND in RTL Row) ──
          Expanded(
            child: GestureDetector(
              onTap: () => context.push('/my-proofs'),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    const Text(
                      'ابحث في التوثيقات',
                      style: TextStyle(
                        color: Color(0xFF11645F),
                        fontSize: 14,
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const Spacer(),
                    SvgPicture.asset(
                      'assets/images/maquette1/img/Search.svg',
                      width: 18,
                      height: 18,
                      colorFilter: const ColorFilter.mode(Color(0xFF11645F), BlendMode.srcIn),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCarousel(int draftsCount) {
    return SizedBox(
      height: 220,
      child: PageView(
        controller: _statsPageController,
        onPageChanged: (index) {
          setState(() {
            _currentStatsPage = index;
          });
        },
        children: [
          _buildStatsPage(
            label: 'تم التحقق',
            count: _verifiedCount.toString(),
            status: 'مكتمل',
            onTap: () => context.push('/my-proofs'),
          ),
          _buildStatsPage(
            label: 'بانتظار الرفع',
            count: draftsCount.toString(),
            status: 'مسودة',
            onTap: () => context.push('/summary'),
          ),
          _buildStatsPage(
            label: 'إجمالي التوثيقات',
            count: (_totalCount + draftsCount).toString(),
            status: 'سجلنا',
            onTap: () => context.push('/my-proofs'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsPage({
    required String label,
    required String count,
    required String status,
    VoidCallback? onTap,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 16,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF5BBDB1), width: 2),
              ),
              child: Center(
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Color(0xFF5BBDB1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          count,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF111111),
            fontSize: 64,
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF5BBDB1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: const TextStyle(
                color: Color(0xFF11645F),
                fontSize: 14,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPageDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: ShapeDecoration(
            color: _currentStatsPage == index ? const Color(0xFF111111) : const Color(0xFFDDDDDD),
            shape: const OvalBorder(),
          ),
        );
      }),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildActionButton(
            icon: 'assets/images/maquette1/img/Document Outline.svg',
            label: 'عقود و إلتزامات',
            onTap: () => context.push('/selection', extra: PageSection.contracts),
          ),
          _buildActionButton(
            icon: 'assets/images/maquette1/img/Work Outline.svg',
            label: 'وثائق',
            onTap: () => context.push('/selection', extra: PageSection.functions),
          ),
          _buildActionButton(
            icon: 'assets/images/maquette1/img/Camera Outline.svg',
            label: 'حفظ اللحظة',
            onTap: () => context.push('/selection', extra: PageSection.moment),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFDDDDDD), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SvgPicture.asset(icon, colorFilter: const ColorFilter.mode(Color(0xFF111111), BlendMode.srcIn)),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF111111),
              fontSize: 12,
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyCapacityCard({
    required int totalImageCount,
    required int totalVideoSeconds,
    required int totalAudioSeconds,
  }) {
    final packId = (Supabase.instance.client.auth.currentUser?.userMetadata?['pack_id'] as num?)?.toInt() ?? 0;

    const Map<int, Map<String, int>> packQuotas = {
      0: {'photos': 5,   'audioMin': 2,   'videoMin': 0},
      1: {'photos': 10,  'audioMin': 10,  'videoMin': 5},
      2: {'photos': 90,  'audioMin': 40,  'videoMin': 20},
      3: {'photos': 999, 'audioMin': 999, 'videoMin': 999},
    };

    final q = packQuotas[packId] ?? packQuotas[0]!;
    final maxPhotos   = q['photos']!;
    final maxAudioMin = q['audioMin']!;
    final maxVideoMin = q['videoMin']!;
    final maxAudioSec = maxAudioMin * 60;
    final maxVideoSec = maxVideoMin * 60;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          shadows: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 20,
              offset: Offset(0, 4),
              spreadRadius: 0,
            )
          ],
        ),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: const Text(
                'سعه اليوم',
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 18,
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildCapacityItem(
              icon: 'assets/images/maquette1/img/Video.svg',
              label: 'الفيديو',
              value: maxVideoMin == 0
                  ? 'غير متاح'
                  : '${(totalVideoSeconds / 60).toStringAsFixed(1)}/$maxVideoMin دقيقة',
              progress: maxVideoSec == 0 ? 0.0 : (totalVideoSeconds / maxVideoSec).clamp(0.0, 1.0),
            ),
            const SizedBox(height: 20),
            _buildCapacityItem(
              icon: 'assets/images/maquette1/img/Microphone Outline.svg',
              label: 'الصوت',
              value: '${(totalAudioSeconds / 60).toStringAsFixed(1)}/$maxAudioMin دقيقة',
              progress: maxAudioSec == 0 ? 0.0 : (totalAudioSeconds / maxAudioSec).clamp(0.0, 1.0),
            ),
            const SizedBox(height: 20),
            _buildCapacityItem(
              icon: 'assets/images/maquette1/img/Camera Outline.svg',
              label: 'الصور',
              value: '$totalImageCount/$maxPhotos صورة',
              progress: maxPhotos == 0 ? 0.0 : (totalImageCount / maxPhotos).clamp(0.0, 1.0),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapacityItem({
    required String icon,
    required String label,
    required String value,
    required double progress,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F4F4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SvgPicture.asset(
                    icon,
                    colorFilter: const ColorFilter.mode(Color(0xFF111111), BlendMode.srcIn),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 16,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF929292),
                fontSize: 12,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w400,
                height: 1.17,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: const Color(0xFFE0E0E0),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5BBDB1)),
            minHeight: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivityHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => context.push('/my-proofs'),
            child: const Text(
              'عرض الكل >',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Color(0xFF5BBDB1),
                fontSize: 12,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w600,
                height: 1.17,
              ),
            ),
          ),
          const Text(
            'أحدث العمليات',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF111111),
              fontSize: 16,
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitySection(List<Draft> drafts) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRecentActivityHeader(),
        const SizedBox(height: 12),
        if (_isLoading)
          const Center(child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          ))
        else if (_recentProofs.isEmpty && drafts.isEmpty)
          _buildEmptyRecentActivitySkeleton(context)
        else
          Column(
            children: [
              // Prepend Local Drafts
              ...drafts.map((draft) {
                final bool isImg = draft.type == MediaType.image;
                final bool isVid = draft.type == MediaType.video;
                final File? localImg = isImg ? File(draft.transformedPath) : null;
                final bool imgExists = localImg != null && localImg.existsSync();
                final IconData draftIcon = isVid ? Icons.videocam_outlined
                    : draft.type == MediaType.audio ? Icons.audiotrack_outlined
                    : draft.type == MediaType.text  ? Icons.text_snippet_outlined
                    : Icons.image_outlined;
                return _buildFigmaActivityItem(
                  title: 'مسودة: ' + (draft.role ?? 'توثيق وسيط'),
                  subtitle: 'تاريخ المسودة: ${_getTimeAgo(draft.timestamp)}',
                  status: 'في الانتظار',
                  time: _getTimeAgo(draft.timestamp),
                  statusColor: const Color(0xFF929292),
                  localFile: imgExists ? localImg : null,
                  videoPath: isVid ? draft.transformedPath : null,
                  fallbackIcon: draftIcon,
                  onTap: () => context.push('/summary'),
                );
              }),
              // Then Database Proofs
              ..._recentProofs.map((proof) {
                final statusStr = proof['status'] == 'valid' ? 'مكتمل' : 'سجلنا';
                final DateTime createdAt = DateTime.parse(proof['created_at']);
                final timeAgo = _getTimeAgo(createdAt);
                
                // Use pre-generated thumbnail: base64 bytes first, signed URL as fallback
                final proofId = proof['proof_id']?.toString();
                final Uint8List? thumbBytes = proofId != null ? _proofThumbBytes[proofId] : null;
                final String? networkImageUrl = (thumbBytes == null && proofId != null) ? _proofSignedUrls[proofId] : null;
                IconData fallbackIcon = Icons.description_outlined;
                final rawAssets = proof['media_assets'];
                final mediaAssets = rawAssets is List ? rawAssets : (rawAssets is String ? ((){try{final d=jsonDecode(rawAssets);return d is List?d:null;}catch(_){return null;}})() : null);
                if (mediaAssets != null) {
                  for (final a in mediaAssets) {
                    final t = a['type']?.toString().toLowerCase() ?? '';
                    if (t.contains('image')) { fallbackIcon = Icons.photo_camera_outlined; break; }
                    if (t.contains('video')) { fallbackIcon = Icons.videocam_outlined; break; }
                    if (t.contains('audio')) { fallbackIcon = Icons.audiotrack_outlined; break; }
                  }
                }

                return Column(
                  children: [
                     _buildFigmaActivityItem(
                      title: _getProofTitle(proof),
                      subtitle: 'معرف التوثيق: ${proof['proof_id'].toString().substring(0, 8)}',
                      status: statusStr,
                      time: timeAgo,
                      statusColor: proof['status'] == 'valid' ? const Color(0xFF5BBDB1) : const Color(0xFFE0E0E0),
                      imageBytes: thumbBytes,
                      imageUrl: networkImageUrl,
                      fallbackIcon: fallbackIcon,
                      onTap: () => context.push('/proof-view', extra: Proof.fromJson(proof)),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              }),
            ],
          ),
      ],
    );
  }

  Widget _thumbFallback(IconData icon) => Container(
    width: 80, height: 80,
    color: const Color(0xFFF4F4F4),
    child: Icon(icon, color: Colors.grey),
  );

  String _getProofTitle(Map<String, dynamic> proof) {
    if (proof['selected_type'] != null && proof['selected_type'].toString().isNotEmpty) {
      return proof['selected_type'];
    }
    return 'توثيق وسيط';
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inMinutes < 60) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inHours < 24) {
      return 'منذ ${difference.inHours} ساعة';
    } else {
      return 'منذ ${difference.inDays} يوم';
    }
  }

  Widget _buildFigmaActivityItem({
    required String title,
    required String subtitle,
    required String status,
    required String time,
    required Color statusColor,
    Uint8List? imageBytes,
    String? imageUrl,
    File? localFile,
    String? videoPath,
    IconData fallbackIcon = Icons.image_outlined,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width - 40,
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // ── Teal Accent Line (FAR RIGHT in RTL Row) ──
              Container(
                width: 6,
                height: 100,
                decoration: const BoxDecoration(
                  color: Color(0xFF5BBDB1),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
              ),
              // ── Image (RIGHT side in RTL Row) ──
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageBytes != null
                    ? Image.memory(imageBytes, width: 80, height: 80, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _thumbFallback(fallbackIcon))
                    : imageUrl != null
                      ? Image.network(imageUrl, width: 80, height: 80, fit: BoxFit.cover,
                          errorBuilder: (_, e, ___) {
                            debugPrint('⚠️ home Image.network error: $e');
                            return _thumbFallback(fallbackIcon);
                          })
                      : localFile != null
                        ? Image.file(localFile, width: 80, height: 80, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _thumbFallback(fallbackIcon))
                        : videoPath != null
                          ? FutureBuilder<Uint8List?>(
                              future: VideoCompress.getByteThumbnail(videoPath, quality: 60, position: 0),
                              builder: (_, snap) => snap.hasData && snap.data != null
                                ? Stack(alignment: Alignment.center, children: [
                                    Image.memory(snap.data!, width: 80, height: 80, fit: BoxFit.cover),
                                    const Icon(Icons.play_circle_outline, color: Colors.white, size: 28),
                                  ])
                                : _thumbFallback(fallbackIcon),
                            )
                          : _thumbFallback(fallbackIcon),
                ),
              ),
              // ── Text Content (LEFT side in RTL Row) ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 14,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF757575),
                          fontSize: 12,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                time,
                                style: const TextStyle(color: Color(0xFF929292), fontSize: 10),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.access_time, size: 12, color: Color(0xFF929292)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: status == 'مكتمل' ? const Color(0xFFD4F3EC) : const Color(0xFFF0F0F0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  status == 'مكتمل' ? Icons.check_circle_outline : Icons.radio_button_unchecked,
                                  size: 12,
                                  color: status == 'مكتمل' ? const Color(0xFF319B8F) : const Color(0xFF929292),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  status,
                                  style: TextStyle(
                                    color: status == 'مكتمل' ? const Color(0xFF319B8F) : const Color(0xFF929292),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomAppBar(
      height: 80,
      color: Colors.white,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            icon: 'assets/images/maquette1/img/home.svg',
            label: 'الرئيسية',
            isActive: true,
            onTap: () {
               fetchDashboardData(); 
            },
          ),
          const SizedBox(width: 40), 
          _buildNavItem(
            icon: 'assets/images/maquette1/img/profile.svg',
            label: 'حساب',
            isActive: false,
            onTap: () => context.push('/profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required String icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final color = isActive ? const Color(0xFF5BBDB1) : const Color(0xFF929292);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              icon,
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateHero(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -21.77,
                top: 22,
                child: Image.asset(
                  isDarkMode 
                      ? 'assets/images/sans_preuve/Illustration(Dark).png'
                      : 'assets/images/sans_preuve/Illustration.png',
                  width: MediaQuery.of(context).size.width * 1.1,
                  height: 218,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(),
                ),
              ),
            ],
          ),
        ),
        Column(
          children: [
            Text(
              'كل توثيق يبدأ بخطوة',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDarkMode ? Colors.white : const Color(0xFF111111),
                fontSize: 24,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w700,
                height: 1.33,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 268,
              child: Text(
                'وثّق اللحظة واحفظها بأمان لتكون جاهزة عند الحاجة',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : const Color(0xFF111111),
                  fontSize: 16,
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w400,
                  height: 1.50,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEmptyStateActionItem(
                icon: 'assets/images/sans_preuve/Document Outline.svg',
                label: 'عقود و إلتزامات',
                isDarkMode: isDarkMode,
                onTap: () => context.push('/selection', extra: PageSection.contracts),
              ),
              _buildEmptyStateActionItem(
                icon: 'assets/images/sans_preuve/Work Outline.svg',
                label: 'توثيق',
                isDarkMode: isDarkMode,
                onTap: () => context.push('/selection', extra: PageSection.functions),
              ),
              _buildEmptyStateActionItem(
                icon: 'assets/images/sans_preuve/Camera Outline.svg',
                label: 'حفظ اللحظة',
                isDarkMode: isDarkMode,
                onTap: () => context.push('/selection', extra: PageSection.moment),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyStateActionItem({required String icon, required String label, required VoidCallback onTap, required bool isDarkMode}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 45,
            height: 45,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
              shape: BoxShape.circle,
              boxShadow: isDarkMode ? [] : [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))
              ]
            ),
            child: SvgPicture.asset(icon, colorFilter: ColorFilter.mode(isDarkMode ? Colors.white : const Color(0xFF111111), BlendMode.srcIn)),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: isDarkMode ? Colors.white : const Color(0xFF111111)
            )
          )
        ]
      )
    );
  }

  Widget _buildEmptyRecentActivitySkeleton(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    Color surfaceDefault = isDarkMode ? const Color(0xFF191919) : Colors.white;
    Color surfaceSkeleton = isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFE6E6E6);

    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildSkeletonCard(surfaceDefault, surfaceSkeleton),
          const SizedBox(height: 12),
          _buildSkeletonCard(surfaceDefault, surfaceSkeleton),
          const SizedBox(height: 12),
          _buildSkeletonCard(surfaceDefault, surfaceSkeleton),
          const SizedBox(height: 24),
          Text(
            'ستظهر توثيقاتك هنا عند إنشائها',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : const Color(0xFF929292),
              fontSize: 14,
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonCard(Color surfaceDefault, Color surfaceSkeleton) {
    return Container(
      width: 320,
      height: 110,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: surfaceDefault,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 312,
            top: 3,
            child: Container(
              width: 13,
              height: 105,
              decoration: ShapeDecoration(
                color: surfaceSkeleton,
                shape: RoundedRectangleBorder(
                  side: BorderSide(width: 1, color: surfaceSkeleton),
                ),
              ),
            ),
          ),
          Positioned(
            left: 18.50,
            top: 16,
            child: Container(
              width: 193,
              height: 78,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      width: 193,
                      height: 52,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            top: 0,
                            child: Container(
                              width: 193,
                              height: 20,
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: 42.50,
                                    top: 0,
                                    child: Container(
                                      width: 150,
                                      height: 12,
                                      decoration: ShapeDecoration(
                                        color: surfaceSkeleton,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(17.50),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            top: 24,
                            child: Container(
                              width: 193,
                              height: 28,
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: -0.50,
                                    top: 0,
                                    child: Container(
                                      width: 193,
                                      height: 10,
                                      decoration: ShapeDecoration(
                                        color: surfaceSkeleton,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(15),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 109.50,
                                    top: 15,
                                    child: Container(
                                      width: 83,
                                      height: 10,
                                      decoration: ShapeDecoration(
                                        color: surfaceSkeleton,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(15),
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
                  Positioned(
                    left: 0,
                    top: 56,
                    child: Container(
                      width: 193,
                      height: 22,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0.50,
                            top: -1,
                            child: Container(
                              width: 65,
                              height: 24,
                              decoration: ShapeDecoration(
                                color: surfaceSkeleton,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 119,
                            top: 0,
                            child: Container(
                              width: 74,
                              height: 22,
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: 0,
                                    top: 0,
                                    child: Container(
                                      width: 58,
                                      height: 22,
                                      child: Stack(
                                        children: [
                                          Positioned(
                                            left: 0,
                                            top: 4,
                                            child: Container(
                                              width: 58,
                                              height: 14,
                                              child: Stack(
                                                children: [
                                                  Positioned(
                                                    left: 19.50,
                                                    top: 3,
                                                    child: Container(
                                                      width: 38,
                                                      height: 9,
                                                      decoration: ShapeDecoration(
                                                        color: surfaceSkeleton,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(12.50),
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
                                  Positioned(
                                    left: 62,
                                    top: 5,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      clipBehavior: Clip.antiAlias,
                                      decoration: BoxDecoration(),
                                      child: Stack(
                                        children: [
                                          Positioned(
                                            left: 0.50,
                                            top: 0.50,
                                            child: Container(
                                              width: 11,
                                              height: 11,
                                              decoration: ShapeDecoration(
                                                color: surfaceSkeleton,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(11),
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
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 225,
            top: 18,
            child: Container(
              width: 74,
              height: 74,
              decoration: ShapeDecoration(
                color: surfaceSkeleton,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
