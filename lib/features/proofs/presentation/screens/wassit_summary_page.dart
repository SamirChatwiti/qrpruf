import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/providers/wassit_provider.dart';
import '../../../../core/providers/gharad_provider.dart';
import '../../../../core/security/device_integrity_service.dart';
import '../../../../core/services/proof_service.dart';
import '../../data/models/draft.dart';
import 'package:qrpruf/pages/wassit_result_page.dart';
import 'package:qrpruf/features/identity/presentation/id_scanner_screen.dart';

class WassitSummaryPage extends ConsumerStatefulWidget {
  const WassitSummaryPage({super.key});

  @override
  ConsumerState<WassitSummaryPage> createState() => _WassitSummaryPageState();
}

class _WassitSummaryPageState extends ConsumerState<WassitSummaryPage> {
  bool _isGenerating = false;
  String? _error;

  Position? _currentPosition;
  StreamSubscription<Position>? _locationSub;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _fmtTime(DateTime d) => DateFormat('HH:mm:ss').format(d);

  double _fileSizeMB(String path) {
    try {
      return File(path).lengthSync() / (1024 * 1024);
    } catch (_) {
      return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _showGpsDisabledDialog() async {
    if (!mounted) return;
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.location_off, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'الموقع الجغرافي معطل',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'يجب تفعيل خدمة الموقع (GPS) على جهازك لربط التوثيق بموقعك الجغرافي.\n\nيمكنك الاستمرار بدون موقع، لكن لن يتم تسجيل الإحداثيات.',
          style: TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.6),
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تخطي', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5BBDB1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('فتح الإعدادات', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      ),
    );

    if (openSettings == true) {
      await Geolocator.openLocationSettings();
      await _initLocation();
    }
  }

  Future<void> _initLocation() async {
    try {
      final svcEnabled = await Geolocator.isLocationServiceEnabled();
      if (!svcEnabled) {
        if (mounted) _showGpsDisabledDialog();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        return;
      }

      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        setState(() => _currentPosition = lastKnown);
      }

      _locationSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 0,
        ),
      ).listen(
        (pos) { if (mounted) setState(() => _currentPosition = pos); },
        onError: (_) {},
      );
    } catch (_) {}
  }

  Future<void> _validateAndGenerate() async {
    // Block QR generation on rooted/jailbroken devices
    final integrity = await DeviceIntegrityService().check();
    if (integrity.isCompromised) {
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.gpp_bad_outlined, color: Colors.red),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'جهاز غير آمن',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Text(
            'تم اكتشاف تعديلات على نظام هذا الجهاز (Root / Jailbreak).\n\nلا يمكن إصدار توثيق رقمي من جهاز مُعرَّض للخطر للحفاظ على سلامة الإثبات.',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.6),
            textAlign: TextAlign.right,
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('حسناً', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    // Block QR generation if identity not verified
    final user = Supabase.instance.client.auth.currentUser;
    final bool isIdentityVerified = user?.userMetadata?['identity_verified'] == true;
    if (!isIdentityVerified) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.badge_outlined, color: Colors.red),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'التحقق من الهوية مطلوب',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Text(
            'يجب مسح بطاقتك الوطنية للتحقق من هويتك قبل إصدار أي توثيق رقمي.\n\nيمكنك الاستمرار في التقاط الوسائط، لكن لن يتم إنشاء رمز QR حتى يتم التحقق.',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.6),
            textAlign: TextAlign.right,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('لاحقاً', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5BBDB1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const IdScannerScreen(isOnboarding: false)),
                );
              },
              child: const Text('مسح الهوية الآن', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {

      final gharadState = ref.read(gharadProvider);
      final isAssistant = gharadState.isAssistantMode;
      final selectedFunction = gharadState.selectedFunction;
      final String effectiveContext = (selectedFunction == 'مفوض قضائي' && isAssistant) 
          ? 'مساعد مفوض' 
          : (selectedFunction ?? '');

      final allDrafts = ref.read(wassitProvider).drafts;
      final filtered = allDrafts.where((d) {
          final String draftRole = d.role ?? '';
          return draftRole == effectiveContext || (d.intentions?.contains(effectiveContext) ?? false);
       }).toList();
      final drafts = filtered.isEmpty ? allDrafts : filtered;
      final usedDraftIds = drafts.map((d) => d.id).toList();

      if (drafts.isEmpty) {
        throw Exception('لم تتم إضافة أي وسائط. يرجى العودة وإضافة وسيط واحد على الأقل.');
      }

      Map<String, double>? locData;
      if (_currentPosition != null) {
          locData = {
              'latitude': _currentPosition!.latitude,
              'longitude': _currentPosition!.longitude,
              'accuracy': _currentPosition!.accuracy,
          };
      }

      final summaryText = StringBuffer();
      if (_titleController.text.isNotEmpty) {
        summaryText.writeln('العنوان: ${_titleController.text}');
      }
      summaryText.writeln('توثيق جلسة وسيط ($effectiveContext)');
      summaryText.writeln("الغرض: ${gharadState.selectedGharad.join(', ')}");
      if (_notesController.text.isNotEmpty) {
        summaryText.writeln('ملاحظات: ${_notesController.text}');
      }

      setState(() => _error = '... جاري تشفير ورفع الملفات');

      final resultPayload = await ProofService().generateProofPayloadImmediate(
        drafts,
        locationData: locData,
        customDescription: summaryText.toString(),
        selectedType: effectiveContext,
        extraChoices: gharadState.selectedGharad.toList(),
        onProgress: (msg) {
           if (mounted) setState(() => _error = msg); 
        }
      );

      final String url = resultPayload['url'];
      final key = resultPayload['key']; // encrypt.Key
      final List<Map<String, dynamic>> queue = resultPayload['queue'];

      setState(() => _error = '... تم استلام الدليل بنجاح'); 

      if (!mounted) return;

      final notifier = ref.read(wassitProvider.notifier);
      for (final id in usedDraftIds) {
        notifier.removeDraft(id);
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WassitResultPage(
              proofUrl: url,
              uploadQueue: queue,
              encryptionKey: key,
              location: _currentPosition != null 
                ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                : null,
          ),
        ),
      );

    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _error = 'خطأ تقني: ${e.message}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allDrafts = ref.watch(wassitProvider).drafts;


    final Map<String, List<Draft>> groupedDrafts = {};
    for (var draft in allDrafts) {
      final key = "${draft.role ?? ''}|${(draft.intentions ?? []).join(',')}";
      groupedDrafts.putIfAbsent(key, () => []).add(draft);
    }

    final sortedKeys = groupedDrafts.keys.toList()
      ..sort((a, b) {
        final lastA = groupedDrafts[a]!.map((d) => d.timestamp).reduce((m, e) => e.isAfter(m) ? e : m);
        final lastB = groupedDrafts[b]!.map((d) => d.timestamp).reduce((m, e) => e.isAfter(m) ? e : m);
        return lastB.compareTo(lastA);
      });

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: SafeArea(
        child: Column(
          children: [
            Directionality(
              textDirection: TextDirection.rtl,
              child: _buildAppBar(context),
            ),
            Expanded(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 40),
                  children: [
                    _buildCustomStepIndicator(),
                    const SizedBox(height: 16),
                    if (allDrafts.isEmpty)
                      _buildEmptyDraftsState()
                    else
                      ...sortedKeys.map((key) {
                        final groupDrafts = groupedDrafts[key]!;
                        final parts = key.split('|');
                        final role = parts[0];
                        final intentions = parts[1].isEmpty ? <String>[] : parts[1].split(',');

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(role.isEmpty ? 'التوثيق' : 'أغراض التوثيق: $role'),
                            _buildContextCard(role, intentions),
                            const SizedBox(height: 12),
                            _buildMediaSection(context, groupDrafts),
                            const SizedBox(height: 24),
                          ],
                        );
                      }),
                    if (allDrafts.isNotEmpty) _buildGlobalSizeQuota(allDrafts),
                    if (allDrafts.isNotEmpty) const SizedBox(height: 16),
                    _buildFormSection(),
                    const SizedBox(height: 16),
                    _buildWarningSection(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            Directionality(
              textDirection: TextDirection.rtl,
              child: _buildBottomActionBar(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(width: 0.50, color: Color(0xFFE0E0E0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const IconButton(
            icon: Icon(Icons.close, color: Colors.transparent),
            onPressed: null,
          ),
          const Text(
            'مراجعة التوثيقات',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Color(0xFF111111),
              fontSize: 18,
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 18, color: Color(0xFF111111)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomStepIndicator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(color: Color(0xFFF4F4F4)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _stepNode(1, 'الخطوة 1', active: false),
          _stepDivider(),
          _stepNode(2, 'الخطوة 2', active: false),
          _stepDivider(),
          _stepNode(3, 'الخطوة 3', active: true),
        ],
      ),
    );
  }

  Widget _stepNode(int step, String label, {required bool active}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: ShapeDecoration(
            color: active ? const Color(0xFF5BBDB1) : const Color(0xFFF7F7F7),
            shape: const CircleBorder(
              side: BorderSide(width: 0.25, color: Color(0xFFB8B8B8)),
            ),
            shadows: const [BoxShadow(color: Color(0x1A000000), blurRadius: 4, offset: Offset(0, 1))],
          ),
          child: Center(
            child: Text(
              '$step',
              style: TextStyle(
                color: active ? Colors.white : const Color(0xFF111111),
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
            color: active ? const Color(0xFF111111) : const Color(0xFF929292),
            fontSize: 10,
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _stepDivider() {
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.only(left: 4, right: 4, bottom: 16),
      color: const Color(0xFFB8B8B8),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Text(
        title,
        textAlign: TextAlign.right,
        style: const TextStyle(
          color: Color(0xFF111111),
          fontSize: 16,
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildContextCard(String role, List<String> intentions) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        shadows: const [BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF5BBDB1), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  role,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 14,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  intentions.join('، '),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Color(0xFF4B4B4B),
                    fontSize: 12,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const ShapeDecoration(
              color: Color(0xFFD4F3EC),
              shape: CircleBorder(),
            ),
            child: const Icon(Icons.description_outlined, color: Color(0xFF319B8F), size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaSection(BuildContext context, List<Draft> drafts) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => context.push('/capture-hub'),
                child: const Text(
                  '+ إضافة المزيد',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: Color(0xFF5BBDB1), fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                'الوسائط الملتقطة (${drafts.length})',
                textAlign: TextAlign.right,
                style: const TextStyle(color: Color(0xFF111111), fontSize: 14, fontFamily: 'Cairo', fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (drafts.isEmpty)
            const Text('لا توجد وسائط ملتقطة بعد.', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo', fontSize: 12))
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: drafts.map((d) => _buildMediaCard(d)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildMediaCard(Draft draft) {
    return GestureDetector(
      onTap: () {
        if (draft.type == MediaType.video) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => _VideoPlayerScreen(path: draft.originalPath)));
        } else if (draft.type == MediaType.audio) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => _AudioPlayerScreen(path: draft.originalPath)));
        } else if (draft.type == MediaType.image) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => _FullScreenImageViewer(path: draft.originalPath)));
        }
      },
      child: Container(
      width: 155,
      height: 155,
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 0.50, color: Color(0xFFB8B8B8)),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          _buildPreviewContent(draft),
          Positioned(
            left: 8,
            bottom: 8,
            child: GestureDetector(
              onTap: () => ref.read(wassitProvider.notifier).removeDraft(draft.id),
              child: Container(
                width: 24,
                height: 24,
                decoration: const ShapeDecoration(color: Color(0xFFC9514B), shape: CircleBorder()),
                child: const Icon(Icons.delete_outline, color: Colors.white, size: 14),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: ShapeDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(1024)),
              ),
              child: Row(
                children: [
                  Text(
                    _fmtTime(draft.timestamp),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'Cairo'),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.access_time, color: Colors.white, size: 10),
                ],
              ),
            ),
          ),
          if (draft.type != MediaType.image)
            Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: ShapeDecoration(color: Colors.black.withValues(alpha: 0.5), shape: const CircleBorder()),
                child: Icon(
                  draft.type == MediaType.video ? Icons.play_arrow : (draft.type == MediaType.audio ? Icons.mic : Icons.text_snippet),
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          if (draft.type != MediaType.text)
            Positioned(
              right: 8,
              bottom: 8,
              child: _buildCardSizeBadge(draft),
            ),
        ],
      ),
    ));
  }

  Widget _buildCardSizeBadge(Draft draft) {
    final sizeMB = _fileSizeMB(draft.originalPath);
    final Color textColor;
    if (draft.type == MediaType.image) {
      textColor = const Color(0xFF5BBDB1);
    } else {
      final limitMB = draft.type == MediaType.video ? 50.0 : 2.0;
      textColor = sizeMB <= limitMB ? const Color(0xFF27AE60) : Colors.red;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        '${sizeMB.toStringAsFixed(1)} MB',
        style: TextStyle(color: textColor, fontSize: 9, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPreviewContent(Draft draft) {
    if (draft.type == MediaType.image) {
      return Image.file(File(draft.originalPath), fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    } else if (draft.type == MediaType.video) {
      return Container(
        color: Colors.black87,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_fill, color: Colors.white70, size: 44),
            SizedBox(height: 4),
            Text('اضغط للمشاهدة', style: TextStyle(fontSize: 10, fontFamily: 'Cairo', color: Colors.white54)),
          ],
        ),
      );
    } else if (draft.type == MediaType.text) {
      return Container(
        padding: const EdgeInsets.all(8),
        color: Colors.white,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             Icon(Icons.text_snippet, color: Color(0xFF319B8F), size: 30),
             SizedBox(height: 4),
             Text('ملاحظة نصية', style: TextStyle(fontSize: 10, fontFamily: 'Cairo', color: Color(0xFF4B4B4B))),
          ],
        ),
      );
    } else if (draft.type == MediaType.audio) {
      return Container(
        color: const Color(0xFF0D2137),
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.graphic_eq, color: Colors.white70, size: 44),
            SizedBox(height: 4),
            Text('اضغط للاستماع', style: TextStyle(fontSize: 10, fontFamily: 'Cairo', color: Colors.white54)),
          ],
        ),
      );
    } else {
      return Container(color: Colors.black12);
    }
  }

  Widget _buildFormSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'بيانات التوثيق',
            textAlign: TextAlign.right,
            style: TextStyle(color: Color(0xFF111111), fontSize: 14, fontFamily: 'Cairo', fontWeight: FontWeight.w700),
          ),
          const Text(
            'هذه البيانات سترافق الملف المشفر ولا يمكن تعديلها لاحقاً.',
            textAlign: TextAlign.right,
            style: TextStyle(color: Color(0xFF4B4B4B), fontSize: 11, fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 16),
          _buildTextField('عنوان التوثيق (اختياري)', _titleController, 'مثال: حادث سير في شارع الجيش الملكي...'),
          const SizedBox(height: 16),
          _buildTextField('ملاحظات إضافية', _notesController, 'اكتب وصفاً دقيقاً لما تم توثيقه...', maxLines: 3),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 4),
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Color(0xFF111111), fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.w500),
          ),
        ),
        Container(
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 0.25, color: Color(0xFFB8B8B8)),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, fontFamily: 'Cairo'),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF6E6E6E), fontSize: 10, fontFamily: 'Cairo'),
              contentPadding: const EdgeInsets.all(12),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWarningSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFFBEDBFF)),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFF2B7FFF), size: 16),
              SizedBox(width: 8),
              Text(
                'تنبيه هام:',
                style: TextStyle(color: Color(0xFF2B7FFF), fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'بالضغط على "تأكيد وإصدار"، سيتم تشفير الملفات وربطها بهويتك والموقع الحالي بصورة نهائية.',
            textAlign: TextAlign.right,
            style: TextStyle(color: Color(0xFF4B4B4B), fontSize: 10, fontFamily: 'Cairo', height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDraftsState() {
    final gharadState = ref.watch(gharadProvider);
    final function = gharadState.selectedFunction ?? '';
    final gharads = gharadState.selectedGharad.toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          if (function.isNotEmpty || gharads.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: ShapeDecoration(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                shadows: const [BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 1))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('السياق المحدد في الخطوة 1',
                          style: TextStyle(color: Color(0xFF5BBDB1), fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
                      SizedBox(width: 6),
                      Icon(Icons.info_outline, color: Color(0xFF5BBDB1), size: 16),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (function.isNotEmpty)
                    Text(function,
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: Color(0xFF111111), fontSize: 14, fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
                  if (gharads.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(gharads.join('، '),
                          textAlign: TextAlign.right,
                          style: const TextStyle(color: Color(0xFF4B4B4B), fontSize: 12, fontFamily: 'Cairo')),
                    ),
                ],
              ),
            ),
          const Icon(Icons.add_photo_alternate_outlined, size: 60, color: Colors.grey),
          const SizedBox(height: 12),
          const Text(
            'لم تتم إضافة أي وسائط بعد.\nيرجى العودة وإضافة صورة أو فيديو أو صوت.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontFamily: 'Cairo', fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/capture-hub'),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('إضافة وسائط (الخطوة 2)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5BBDB1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalSizeQuota(List<Draft> drafts) {
    final images = drafts.where((d) => d.type == MediaType.image).toList();
    final videos = drafts.where((d) => d.type == MediaType.video).toList();
    final audios = drafts.where((d) => d.type == MediaType.audio).toList();

    if (images.isEmpty && videos.isEmpty && audios.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('إجمالي حجم هذه الجلسة',
                  style: TextStyle(color: Color(0xFF111111), fontSize: 13, fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
              SizedBox(width: 6),
              Icon(Icons.data_usage, color: Color(0xFF5BBDB1), size: 16),
            ],
          ),
          const SizedBox(height: 10),
          if (images.isNotEmpty) _buildImageSizeRow(images),
          if (images.isNotEmpty && (videos.isNotEmpty || audios.isNotEmpty)) const SizedBox(height: 8),
          if (videos.isNotEmpty) _buildMediaSizeRow(Icons.videocam, 'فيديو', videos, 50.0),
          if (videos.isNotEmpty && audios.isNotEmpty) const SizedBox(height: 8),
          if (audios.isNotEmpty) _buildMediaSizeRow(Icons.mic, 'صوت', audios, 2.0),
        ],
      ),
    );
  }

  Widget _buildImageSizeRow(List<Draft> images) {
    final count = images.length;
    final totalRawMB = images.fold(0.0, (sum, d) => sum + _fileSizeMB(d.originalPath));
    const Color color = Color(0xFF5BBDB1);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_size_select_large, color: color, size: 12),
            const SizedBox(width: 4),
            Text(
              '${totalRawMB.toStringAsFixed(1)} MB',
              style: const TextStyle(color: color, fontSize: 11, fontFamily: 'Cairo'),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('صور ($count)', style: const TextStyle(color: Color(0xFF4B4B4B), fontSize: 11, fontFamily: 'Cairo')),
            const SizedBox(width: 6),
            const Icon(Icons.photo_camera, color: Color(0xFF4B4B4B), size: 14),
          ],
        ),
      ],
    );
  }

  Widget _buildMediaSizeRow(IconData icon, String label, List<Draft> items, double limitMB) {
    final totalMB = items.fold(0.0, (sum, d) => sum + _fileSizeMB(d.originalPath));
    final frac = (totalMB / limitMB).clamp(0.0, 1.0);
    final bool ok = totalMB <= limitMB;
    final Color color = ok ? const Color(0xFF27AE60) : Colors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(ok ? Icons.check_circle_outline : Icons.warning_amber_rounded, color: color, size: 12),
                const SizedBox(width: 4),
                Text(
                  ok
                      ? 'الحجم مناسب — ${totalMB.toStringAsFixed(1)} MB'
                      : 'الحجم كبير! ${totalMB.toStringAsFixed(1)} / ${limitMB.toInt()} MB',
                  style: TextStyle(color: color, fontSize: 11, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$label (${items.length})', style: const TextStyle(color: Color(0xFF4B4B4B), fontSize: 11, fontFamily: 'Cairo')),
                const SizedBox(width: 6),
                Icon(icon, color: const Color(0xFF4B4B4B), size: 14),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: frac,
          backgroundColor: const Color(0xFFE0E0E0),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 5,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }

  Widget _buildBottomActionBar(BuildContext context) {
    final hasNoDrafts = ref.watch(wassitProvider).drafts.isEmpty;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
             Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                  textAlign: TextAlign.center,
                ),
             ),
          if (_isGenerating)
             Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  'جاري إنشاء الدليل الرقمي المشفر...',
                  style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                ),
             ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: hasNoDrafts || _isGenerating ? null : _validateAndGenerate,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5BBDB1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isGenerating ? 'جاري الإصدار...' : 'تأكيد وإصدار',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 16, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.check_circle_outline, size: 24),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.push('/capture-hub'),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('عودة لتعديل الوسائط', style: TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Cairo')),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios, size: 10, color: Colors.grey),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen video player for summary page preview
class _VideoPlayerScreen extends StatefulWidget {
  final String path;
  const _VideoPlayerScreen({required this.path});

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.path))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _initialized = true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('معاينة الفيديو', style: TextStyle(fontFamily: 'Cairo')),
      ),
      body: Center(
        child: _initialized
            ? GestureDetector(
                onTap: () => _controller.value.isPlaying ? _controller.pause() : _controller.play(),
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              )
            : const CircularProgressIndicator(color: Color(0xFF5BBDB1)),
      ),
    );
  }
}

/// Full-screen audio player for summary page preview
class _AudioPlayerScreen extends StatefulWidget {
  final String path;
  const _AudioPlayerScreen({required this.path});

  @override
  State<_AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<_AudioPlayerScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state == PlayerState.playing);
    });
    _player.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('معاينة الصوت', style: TextStyle(fontFamily: 'Cairo')),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.graphic_eq, color: Color(0xFF5BBDB1), size: 80),
              const SizedBox(height: 32),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF5BBDB1),
                  thumbColor: const Color(0xFF5BBDB1),
                  inactiveTrackColor: Colors.white24,
                ),
                child: Slider(
                  value: progress,
                  onChanged: (val) {
                    final seek = Duration(
                      milliseconds: (_duration.inMilliseconds * val).round(),
                    );
                    _player.seek(seek);
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(_position), style: const TextStyle(color: Colors.white54, fontFamily: 'Cairo')),
                  Text(_fmt(_duration), style: const TextStyle(color: Colors.white54, fontFamily: 'Cairo')),
                ],
              ),
              const SizedBox(height: 24),
              IconButton(
                onPressed: () async {
                  if (_isPlaying) {
                    await _player.pause();
                  } else {
                    if (_position >= _duration && _duration > Duration.zero) {
                      await _player.seek(Duration.zero);
                    }
                    await _player.play(DeviceFileSource(widget.path));
                  }
                },
                icon: Icon(
                  _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  color: const Color(0xFF5BBDB1),
                  size: 72,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen image viewer for summary page preview
class _FullScreenImageViewer extends StatelessWidget {
  final String path;
  const _FullScreenImageViewer({required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('معاينة الصورة', style: TextStyle(fontFamily: 'Cairo')),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.file(File(path), fit: BoxFit.contain),
        ),
      ),
    );
  }
}
