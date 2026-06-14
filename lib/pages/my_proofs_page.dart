import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:video_compress/video_compress.dart';
import 'package:qrpruf/models/proof.dart';
import 'package:qrpruf/pages/proof_view_page.dart';
import 'package:qrpruf/core/theme/colors.dart';
import 'package:qrpruf/core/providers/wassit_provider.dart';
import 'package:qrpruf/features/proofs/data/models/draft.dart';

class MyProofsPage extends ConsumerStatefulWidget {
  const MyProofsPage({super.key});

  @override
  ConsumerState<MyProofsPage> createState() => _MyProofsPageState();
}

class _MyProofsPageState extends ConsumerState<MyProofsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Proof> _proofs = [];
  Map<String, String?> _signedUrls = {};    // fallback: signed URL for old proofs
  Map<String, Uint8List?> _thumbBytes = {}; // primary: inline base64 from media_assets
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchProofs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchProofs() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('غير مسجل الدخول');

      final data = await Supabase.instance.client
          .from('proofs')
          .select()
          .eq('subject_id', user.id)
          .order('created_at', ascending: false);

      final proofs = (data as List).map((j) => Proof.fromJson(j)).toList();

      // Build thumbnail map: primary=base64 from DB, fallback=signed URL
      final Map<String, Uint8List?> thumbBytes = {};
      final Map<String, String?> signedUrls = {};
      for (final proof in proofs) {
        final assets = proof.mediaAssets;
        if (assets == null) {
          debugPrint('⚠️ proof ${proof.proofId.substring(0,8)}: media_assets is null');
          continue;
        }
        for (final asset in assets) {
          final type = asset['type']?.toString().toLowerCase() ?? '';
          if (!type.contains('image') && !type.contains('video')) continue;

          // Primary: inline base64 thumbnail stored in the asset
          final b64 = asset['thumb_b64']?.toString();
          if (b64 != null && b64.isNotEmpty) {
            try {
              thumbBytes[proof.proofId] = base64Decode(b64);
              debugPrint('✅ thumb_b64 decoded for ${proof.proofId.substring(0,8)}');
            } catch (e) {
              debugPrint('⚠️ base64Decode failed: $e');
            }
            break;
          }

          // Fallback: signed URL for older proofs (no thumb_b64)
          final assetUrl = asset['url']?.toString() ?? '';
          if (assetUrl.isNotEmpty) {
            final lastSlash = assetUrl.lastIndexOf('/');
            if (lastSlash >= 0) {
              final file = assetUrl.substring(lastSlash + 1);
              final thumbFileName = 'thumb_$file.jpg';
              try {
                final signedUrl = await Supabase.instance.client.storage
                    .from('proof-media')
                    .createSignedUrl(thumbFileName, 3600);
                signedUrls[proof.proofId] = signedUrl;
                debugPrint('✅ signedUrl OK for ${proof.proofId.substring(0,8)}: $thumbFileName');
              } catch (e) {
                debugPrint('⚠️ createSignedUrl failed for $thumbFileName: $e');
              }
            }
          }
          break;
        }
      }

      if (mounted) {
        setState(() {
          _proofs = proofs;
          _thumbBytes = thumbBytes;
          _signedUrls = signedUrls;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'تعذر تحميل السجل: $e'; _isLoading = false; });
    }
  }

  String _formatDate(DateTime dt) =>
      DateFormat('yyyy/MM/dd HH:mm', 'en_US').format(dt.toLocal());

  String _proofTitle(Proof proof) {
    if (proof.selectedType != null && proof.selectedType!.isNotEmpty) {
      return proof.selectedType!;
    }
    if (proof.purposes.isNotEmpty) {
      final p = proof.purposes.last.toUpperCase();
      if (p.contains('VIDEO')) return 'توثيق فيديو';
      if (p.contains('IMAGE')) return 'توثيق صور';
      if (p.contains('AUDIO')) return 'توثيق صوتي';
      return 'توثيق وسيط (${proof.purposes.last})';
    }
    return 'توثيق وسيط';
  }

  // ── Thumbnails ──────────────────────────────────────────────

  Widget _proofThumb(Proof proof, bool isDark) {
    final assets = proof.mediaAssets;
    IconData fallback = Icons.qr_code_2;
    if (assets != null && assets.isNotEmpty) {
      final t = assets[0]['type']?.toString().toLowerCase() ?? '';
      if (t.contains('image')) fallback = Icons.photo_camera_outlined;
      else if (t.contains('video')) fallback = Icons.videocam_outlined;
      else if (t.contains('audio')) fallback = Icons.audiotrack_outlined;
    }

    // Priority 1: inline base64 bytes (new proofs)
    final bytes = _thumbBytes[proof.proofId];
    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(bytes, width: 54, height: 54, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _iconThumb(fallback, isDark)),
      );
    }

    // Priority 2: signed URL (older proofs)
    final url = _signedUrls[proof.proofId];
    if (url != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(url, width: 54, height: 54, fit: BoxFit.cover,
          errorBuilder: (_, e, ___) {
            debugPrint('⚠️ Image.network error for ${proof.proofId.substring(0,8)}: $e');
            return _iconThumb(fallback, isDark);
          }),
      );
    }
    return _iconThumb(fallback, isDark);
  }

  Widget _draftThumb(Draft draft, bool isDark) {
    if (draft.type == MediaType.image) {
      final file = File(draft.transformedPath);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(file, width: 54, height: 54, fit: BoxFit.cover),
        );
      }
    }
    if (draft.type == MediaType.video) {
      return _videoThumb(draft.transformedPath, isDark);
    }
    final icon = draft.type == MediaType.audio
        ? Icons.audiotrack_outlined
        : draft.type == MediaType.text
            ? Icons.text_snippet_outlined
            : Icons.image_outlined;
    return _iconThumb(icon, isDark);
  }

  Widget _videoThumb(String path, bool isDark) {
    return FutureBuilder<Uint8List?>(
      future: VideoCompress.getByteThumbnail(path, quality: 60, position: 0),
      builder: (context, snap) {
        if (snap.hasData && snap.data != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.memory(snap.data!, width: 54, height: 54, fit: BoxFit.cover),
                const Icon(Icons.play_circle_outline, color: Colors.white, size: 22),
              ],
            ),
          );
        }
        return _iconThumb(Icons.videocam_outlined, isDark);
      },
    );
  }

  Widget _iconThumb(IconData icon, bool isDark) => Container(
    width: 54,
    height: 54,
    decoration: BoxDecoration(
      color: isDark ? AppColors.scaffoldBackgroundDark : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(icon, color: isDark ? AppColors.actionHoverDark : const Color(0xFF319B8F)),
  );

  // ── Card builders ────────────────────────────────────────────

  Widget _proofCard(Proof proof, bool isDark) {
    return InkWell(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ProofViewPage(proof: proof))),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 8, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            _proofThumb(proof, isDark),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_proofTitle(proof),
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF111111),
                      fontSize: 13, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(
                    'المعرّف: ${proof.proofId.substring(0, 8).toUpperCase()} • المرفقات: ${proof.itemsCount}',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 11, fontFamily: 'Cairo')),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_formatDate(proof.createdAt),
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 10, fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: proof.status == 'valid'
                        ? (isDark ? AppColors.actionLightDark : const Color(0xFFD4F3EC))
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    proof.status == 'valid' ? 'صحيح' : 'غير صالح',
                    style: TextStyle(
                      color: proof.status == 'valid'
                          ? (isDark ? AppColors.actionHoverDark : const Color(0xFF319B8F))
                          : Colors.red,
                      fontSize: 9, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _draftCard(Draft draft, bool isDark) {
    final typeLabel = draft.type == MediaType.video ? 'فيديو'
        : draft.type == MediaType.audio ? 'صوت'
        : draft.type == MediaType.text  ? 'نص'
        : 'صورة';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 8, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _draftThumb(draft, isDark),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(draft.role ?? 'توثيق وسيط',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF111111),
                    fontSize: 13, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text('نوع: $typeLabel',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 11, fontFamily: 'Cairo')),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('مسودة',
              style: TextStyle(
                color: Colors.orange, fontSize: 9,
                fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final drafts = ref.watch(wassitProvider).drafts;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('سجل إثباتاتي',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
            indicatorColor: const Color(0xFF5BBDB1),
            labelColor: const Color(0xFF5BBDB1),
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'مكتملة (${_proofs.length})'),
              Tab(text: 'مسودات (${drafts.length})'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // ── Tab 1: Completed proofs ──
            _isLoading
                ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
                : _error != null
                    ? Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(_error!, style: const TextStyle(color: Colors.red, fontFamily: 'Cairo')),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchProofs,
                            child: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo'))),
                        ]),
                      )
                    : _proofs.isEmpty
                        ? const Center(
                            child: Text('لا توجد إثباتات مكتملة.',
                                style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 15)))
                        : RefreshIndicator(
                            onRefresh: _fetchProofs,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _proofs.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, i) => _proofCard(_proofs[i], isDark),
                            ),
                          ),

            // ── Tab 2: Drafts ──
            drafts.isEmpty
                ? const Center(
                    child: Text('لا توجد مسودات.',
                        style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 15)))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: drafts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _draftCard(drafts[i], isDark),
                  ),
          ],
        ),
      ),
    );
  }
}
