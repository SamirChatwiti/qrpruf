import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:qrpruf/core/services/i_proof_service.dart';
import 'package:qrpruf/core/services/storage_upload_policy.dart';
import 'package:qrpruf/features/proofs/data/models/draft.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';

// Top-level function — must not be a closure or instance method to work with compute()
Uint8List _stampImageInIsolate(Map<String, dynamic> p) {
  final baseBytes = p['base'] as Uint8List;
  final logoBytes = p['logo'] as Uint8List;
  final ts = (p['ts'] as String).substring(0, 19); // strip milliseconds
  final cc = p['cc'] as String;
  final rotAngle = p['rot'] as int;

  img.Image base =
      img.decodeImage(baseBytes) ?? (throw StateError('decodeImage failed: base'));
  base = img.bakeOrientation(base);

  if (rotAngle != 0) {
    base = img.copyRotate(base, angle: rotAngle.toDouble());
  }

  // Logo at top-left corner
  final img.Image? logo = img.decodeImage(logoBytes);
  if (logo != null) {
    final logoW = (base.width * 0.12).round().clamp(40, 100);
    final scaled = img.copyResize(logo, width: logoW);
    final margin = (base.width * 0.025).round();
    img.compositeImage(base, scaled, dstX: margin, dstY: margin);
  }

  // Semi-transparent metadata footer band
  const int bandH = 28;
  final band = img.Image(width: base.width, height: bandH, numChannels: 4);
  img.fill(band, color: img.ColorRgba8(0, 0, 0, 200));

  final parts = ['WITI CERTIFY', ts];
  if (cc.isNotEmpty) parts.add(cc);
  img.drawString(
    band,
    parts.join('  ·  '),
    font: img.arial14,
    x: 6,
    y: 7,
    color: img.ColorRgba8(255, 255, 255, 230),
  );

  img.compositeImage(base, band, dstX: 0, dstY: base.height - bandH);

  return Uint8List.fromList(img.encodeJpg(base, quality: 88));
}

class ProofService implements IProofService {
  static final ProofService _instance = ProofService._internal();
  factory ProofService() => _instance;
  ProofService._internal();

  static const String _proofBucket = 'proof-media';

  // ─────────────────────────────────────────────────────────────
  // Draft creation
  // ─────────────────────────────────────────────────────────────

  Future<Draft> createDraftFromMedia(
    File rawFile,
    MediaType type, {
    String? role,
    List<String>? intentions,
    int? knownDurationSeconds,
  }) async {
    final timestamp = DateTime.now();
    final appDir = await getApplicationDocumentsDirectory();
    final wassitDir = Directory('${appDir.path}/wassit_cache');
    if (!await wassitDir.exists()) await wassitDir.create(recursive: true);

    final fileName = 'qrpruf_${timestamp.millisecondsSinceEpoch}.${_ext(type)}';
    final transformedFile = await rawFile.copy('${wassitDir.path}/$fileName');

    int durationSeconds = knownDurationSeconds ?? 0;
    if (durationSeconds == 0 && (type == MediaType.video || type == MediaType.audio)) {
      try {
        final info = await VideoCompress.getMediaInfo(rawFile.path);
        final ms = info.duration;
        if (ms != null && ms > 0) {
          durationSeconds = (ms / 1000).ceil();
        }
      } catch (_) {}
    }

    return Draft(
      id: timestamp.millisecondsSinceEpoch.toString(),
      type: type,
      originalPath: rawFile.path,
      transformedPath: transformedFile.path,
      timestamp: timestamp,
      role: role,
      intentions: intentions,
      durationSeconds: durationSeconds,
      isCertified: false,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Daily quota check
  // ─────────────────────────────────────────────────────────────

  // Quotas par pack — source unique de vérité partagée avec home_screen et settings_page
  static const Map<int, Map<String, int>> _packQuotas = {
    0: {'photos': 5,   'audioMin': 2,   'videoMin': 0},
    1: {'photos': 10,  'audioMin': 10,  'videoMin': 5},
    2: {'photos': 90,  'audioMin': 40,  'videoMin': 20},
    3: {'photos': 999, 'audioMin': 999, 'videoMin': 999},
  };

  int _getPackId() {
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata ?? {};
    return (meta['pack_id'] as num?)?.toInt() ?? 0;
  }

  int get _maxImages       => (_packQuotas[_getPackId()] ?? _packQuotas[0]!)['photos']!;
  int get _maxVideoSeconds => (_packQuotas[_getPackId()] ?? _packQuotas[0]!)['videoMin']! * 60;
  int get _maxAudioSeconds => (_packQuotas[_getPackId()] ?? _packQuotas[0]!)['audioMin']! * 60;

  /// Returns null if quota is OK, or an Arabic error message if exceeded.
  Future<String?> checkDailyQuota(MediaType type, {int durationSeconds = 0}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    final today = DateTime.now().toUtc().toIso8601String().split('T')[0];
    final rows = await Supabase.instance.client
        .from('evidence_media')
        .select('media_type, duration_seconds')
        .eq('user_id', user.id)
        .gte('created_at', '${today}T00:00:00Z');

    final items = rows as List<dynamic>;

    if (type == MediaType.image) {
      final count = items.where((i) => i['media_type'] == 'image').length;
      if (count >= _maxImages) {
        return 'لقد وصلت إلى الحد اليومي للصور ($_maxImages صورة). يتجدد الحد غداً.';
      }
    } else if (type == MediaType.video) {
      final usedSeconds = items
          .where((i) => i['media_type'] == 'video')
          .fold<int>(0, (sum, i) => sum + ((i['duration_seconds'] as int?) ?? 0));
      if (usedSeconds + durationSeconds > _maxVideoSeconds) {
        final remaining = (_maxVideoSeconds - usedSeconds).clamp(0, _maxVideoSeconds);
        return 'الحد اليومي للفيديو هو دقيقة واحدة. متبقي: $remaining ثانية.';
      }
    } else if (type == MediaType.audio) {
      final usedSeconds = items
          .where((i) => i['media_type'] == 'audio')
          .fold<int>(0, (sum, i) => sum + ((i['duration_seconds'] as int?) ?? 0));
      if (usedSeconds + durationSeconds > _maxAudioSeconds) {
        final remaining = (_maxAudioSeconds - usedSeconds).clamp(0, _maxAudioSeconds);
        return 'الحد اليومي للصوت هو دقيقتان. متبقي: $remaining ثانية.';
      }
    }
    return null;
  }

  /// Returns remaining seconds/count. [sessionSecondsUsed] = local session already consumed.
  Future<int> getRemainingQuota(MediaType type, {int sessionSecondsUsed = 0}) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return _fallback(type, sessionSecondsUsed);

      final today = DateTime.now().toUtc().toIso8601String().split('T')[0];
      final rows = await Supabase.instance.client
          .from('evidence_media')
          .select('media_type, duration_seconds')
          .eq('user_id', user.id)
          .gte('created_at', '${today}T00:00:00Z');

      final items = rows as List<dynamic>;

      if (type == MediaType.image) {
        final used = items.where((i) => i['media_type'] == 'image').length;
        return (_maxImages - used - sessionSecondsUsed).clamp(0, _maxImages);
      } else if (type == MediaType.video) {
        final used = items
            .where((i) => i['media_type'] == 'video')
            .fold<int>(0, (s, i) => s + ((i['duration_seconds'] as int?) ?? 0));
        return (_maxVideoSeconds - used - sessionSecondsUsed).clamp(0, _maxVideoSeconds);
      } else if (type == MediaType.audio) {
        final used = items
            .where((i) => i['media_type'] == 'audio')
            .fold<int>(0, (s, i) => s + ((i['duration_seconds'] as int?) ?? 0));
        return (_maxAudioSeconds - used - sessionSecondsUsed).clamp(0, _maxAudioSeconds);
      }
      return 0;
    } catch (e) {
      debugPrint('getRemainingQuota error: $e');
      return _fallback(type, sessionSecondsUsed);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Size-based daily quota (mirrors duration quota)
  // ─────────────────────────────────────────────────────────────

  // Size limits derived from pack time limits — keeps bySize and byDuration in sync
  // Rates: video ≈ 333 333 bytes/s, audio ≈ 16 667 bytes/s, image = 1 MB each
  int get _maxImageTotalBytes => _maxImages * 1024 * 1024;
  int get _maxVideoTotalBytes => _maxVideoSeconds * 333333;
  int get _maxAudioTotalBytes => _maxAudioSeconds * 16667;

  int _maxBytesFor(MediaType type) {
    switch (type) {
      case MediaType.image: return _maxImageTotalBytes;
      case MediaType.video: return _maxVideoTotalBytes;
      case MediaType.audio: return _maxAudioTotalBytes;
      case MediaType.text:  return 0;
    }
  }

  /// Returns remaining bytes for [type] today.
  /// [sessionBytesUsed] = bytes already consumed this session (not yet uploaded).
  Future<int> getRemainingQuotaBySize(MediaType type, {int sessionBytesUsed = 0}) async {
    final maxBytes = _maxBytesFor(type);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return (maxBytes - sessionBytesUsed).clamp(0, maxBytes);
      final today = DateTime.now().toUtc().toIso8601String().split('T')[0];
      final rows = await Supabase.instance.client
          .from('evidence_media')
          .select('media_type, size_bytes')
          .eq('user_id', user.id)
          .gte('created_at', '${today}T00:00:00Z');
      final items = rows as List<dynamic>;
      final usedBytes = items
          .where((i) => i['media_type'] == type.name)
          .fold<int>(0, (sum, i) => sum + ((i['size_bytes'] as int?) ?? 0));
      return (maxBytes - usedBytes - sessionBytesUsed).clamp(0, maxBytes);
    } catch (e) {
      debugPrint('getRemainingQuotaBySize error: $e');
      return (maxBytes - sessionBytesUsed).clamp(0, maxBytes);
    }
  }

  /// Remaining video seconds constrained by BOTH duration AND size quotas.
  /// Rate: 20 MB/min ≈ 333 333 bytes/s
  Future<int> getRemainingVideoSeconds({int sessionSecondsUsed = 0, int sessionBytesUsed = 0}) async {
    final byDuration = await getRemainingQuota(MediaType.video, sessionSecondsUsed: sessionSecondsUsed);
    final remainingBytes = await getRemainingQuotaBySize(MediaType.video, sessionBytesUsed: sessionBytesUsed);
    final bySize = (remainingBytes / 333333).floor();
    return min(byDuration, bySize).clamp(0, _maxVideoSeconds);
  }

  /// Remaining audio seconds constrained by BOTH duration AND size quotas.
  /// Rate: 2 MB/2 min ≈ 16 667 bytes/s
  Future<int> getRemainingAudioSeconds({int sessionSecondsUsed = 0, int sessionBytesUsed = 0}) async {
    final byDuration = await getRemainingQuota(MediaType.audio, sessionSecondsUsed: sessionSecondsUsed);
    final remainingBytes = await getRemainingQuotaBySize(MediaType.audio, sessionBytesUsed: sessionBytesUsed);
    final bySize = (remainingBytes / 16667).floor();
    return min(byDuration, bySize).clamp(0, _maxAudioSeconds);
  }

  static const _trimChannel = MethodChannel('com.qrpruf/media_trim');

  /// Trim video or audio to [maxSeconds] using Android MediaMuxer (no re-encoding).
  /// Returns trimmed file path, or original if trim fails.
  Future<String> trimMedia(String inputPath, int maxSeconds) async {
    try {
      final dir = await getTemporaryDirectory();
      final ext = inputPath.split('.').last;
      final outputPath = '${dir.path}/trimmed_${DateTime.now().millisecondsSinceEpoch}.$ext';

      final result = await _trimChannel.invokeMethod<String>('trimMedia', {
        'inputPath': inputPath,
        'outputPath': outputPath,
        'maxSeconds': maxSeconds,
      });

      if (result != null && File(result).existsSync()) return result;
    } catch (e) {
      debugPrint('trimMedia error: $e');
    }
    // Fallback: return original (never lose the recording)
    return inputPath;
  }

  int _fallback(MediaType type, int sessionUsed) {
    if (type == MediaType.video) return (_maxVideoSeconds - sessionUsed).clamp(0, _maxVideoSeconds);
    if (type == MediaType.audio) return (_maxAudioSeconds - sessionUsed).clamp(0, _maxAudioSeconds);
    return (_maxImages - sessionUsed).clamp(0, _maxImages);
  }

  @override
  Future<Draft> applySignatureToDraft(Draft draft, dynamic placemark, {int rotationAngle = 0}) async {
    if (draft.type != MediaType.image) return draft;

    try {
      final rawBytes = await File(draft.transformedPath).readAsBytes();
      final logoData = await rootBundle.load('assets/images/logomain.png');
      final logoBytes = logoData.buffer.asUint8List();

      String isoCountryCode = '';
      if (placemark != null) {
        try {
          isoCountryCode = (placemark.isoCountryCode as String?) ?? '';
        } catch (_) {}
      }

      final branded = await compute<Map<String, dynamic>, Uint8List>(
        _stampImageInIsolate,
        {
          'base': rawBytes,
          'logo': logoBytes,
          'ts': draft.timestamp.toUtc().toIso8601String(),
          'cc': isoCountryCode,
          'rot': rotationAngle,
        },
      );

      final appDir = await getApplicationDocumentsDirectory();
      final signedPath = '${appDir.path}/wassit_cache/signed_${draft.id}.jpg';
      await File(signedPath).writeAsBytes(branded);

      return draft.copyWith(transformedPath: signedPath);
    } catch (e) {
      debugPrint('applySignatureToDraft error: $e');
      return draft;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Proof payload generation
  // ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> generateProofPayloadImmediate(
    List<Draft> drafts, {
    Map<String, double>? locationData,
    String? customDescription,
    String? selectedType,
    List<String>? extraChoices,
    Function(String)? onProgress,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    onProgress?.call('... إعداد المفاتيح والمعرفات');

    final key = encrypt.Key.fromSecureRandom(32);
    final keyBase64 = key.base64;
    final timestampUtc = DateTime.now().toUtc().toIso8601String();

    final List<Map<String, dynamic>> mediaAssets = [];
    final List<Map<String, dynamic>> uploadQueue = [];
    final String storageBaseUrl = Supabase.instance.client.storage.url;

    // Map to cache thumb bytes so we don't generate them twice (once for base64, once for bucket upload)
    final Map<String, Uint8List> thumbBytesCache = {};

    for (var draft in drafts) {
      if (draft.type == MediaType.image || draft.type == MediaType.video || draft.type == MediaType.audio) {
        final fileName = '${user.id.substring(0, 8)}_${draft.id}.${_ext(draft.type)}';
        final predictableUrl = '$storageBaseUrl/object/public/$_proofBucket/$fileName';

        // Generate thumbnail bytes inline — stored as base64 in the DB asset so the listing
        // pages can display thumbnails without any bucket permission requirements.
        Uint8List? thumbBytes;
        if (draft.type == MediaType.image) {
          try {
            thumbBytes = await FlutterImageCompress.compressWithFile(
              draft.transformedPath, minWidth: 200, minHeight: 200, quality: 55);
          } catch (e) {
            debugPrint('⚠️ Thumb compress (image): $e');
          }
        } else if (draft.type == MediaType.video) {
          try {
            thumbBytes = await VideoCompress.getByteThumbnail(
              draft.transformedPath, quality: 55, position: 0);
          } catch (e) {
            debugPrint('⚠️ Thumb compress (video): $e');
          }
        }

        final asset = <String, dynamic>{
          'type': draft.type.name,
          'url': predictableUrl,
          'name': fileName,
          'timestamp': draft.timestamp.toIso8601String(),
          'encrypted': true,
        };
        if (thumbBytes != null && thumbBytes.isNotEmpty) {
          asset['thumb_b64'] = base64Encode(thumbBytes);
          thumbBytesCache[fileName] = thumbBytes;
          debugPrint('✅ Thumbnail base64 generated (${thumbBytes.length} bytes) for $fileName');
        }

        mediaAssets.add(asset);
        uploadQueue.add({'draft': draft, 'fileName': fileName});
      }
    }

    // Upload thumbnails BEFORE creating the proof record — uses cached bytes, no re-generation
    onProgress?.call('... تحضير الصور المصغرة');
    await _ensureFreshSession();
    for (final item in uploadQueue) {
      final Draft draft = item['draft'];
      final String fileName = item['fileName'];
      if (draft.type != MediaType.image && draft.type != MediaType.video) continue;
      final Uint8List? thumbBytes = thumbBytesCache[fileName];
      if (thumbBytes == null) continue;
      try {
        final thumbFileName = 'thumb_$fileName.jpg';
        final tempDir = await getTemporaryDirectory();
        final thumbTmpPath = '${tempDir.path}/$thumbFileName';
        await File(thumbTmpPath).writeAsBytes(thumbBytes);
        await _uploadFile(thumbTmpPath, thumbFileName);
        try { File(thumbTmpPath).deleteSync(); } catch (_) {}
        debugPrint('✅ Thumbnail bucket-uploaded: $thumbFileName');
      } catch (e) {
        debugPrint('⚠️ Thumbnail bucket-upload (non-fatal): $e');
      }
    }

    final body = <String, dynamic>{
      'timestamp_utc': timestampUtc,
      'subject_id': user.id,
      'items_count': drafts.length,
      'selected_type': selectedType ?? 'استعمال شخصي',
      'description': customDescription ?? '',
      'media_assets': mediaAssets,
      'location': locationData ?? {'latitude': 0.0, 'longitude': 0.0, 'accuracy': 0.0},
    };

    onProgress?.call('... استلام المعرف الرقمي، جاري المعالجة');

    FunctionResponse? res;
    for (int retry = 0; retry < 3; retry++) {
      try {
        await _ensureFreshSession();
        res = await Supabase.instance.client.functions.invoke('create_proof', body: body);
        break;
      } catch (e) {
        if (retry == 2) rethrow;
        await Future.delayed(Duration(seconds: (retry + 1) * 2));
      }
    }

    if (res == null) throw Exception('Failed to invoke create_proof after 3 attempts');

    final map = res.data;
    String? proofId;
    if (map is Map) {
      proofId = map['proof']?['proof_id'] ?? map['proof_id'];
    }

    if (proofId != null && proofId.isNotEmpty) {
      // Persist media_assets + selected_type — edge function may not save these fields
      try {
        await Supabase.instance.client
            .from('proofs')
            .update({'media_assets': mediaAssets})
            .eq('proof_id', proofId);
        debugPrint('✅ media_assets saved for $proofId (${mediaAssets.length} assets)');
      } catch (e) {
        debugPrint('⚠️ media_assets DB update (non-fatal): $e');
      }

      final safeKey = Uri.encodeComponent(keyBase64);
      for (var item in uploadQueue) {
        item['proofId'] = proofId;
      }
      return {
        'url': 'https://www.qrpruf.com/p/proof.html?id=$proofId#key=$safeKey',
        'key': key,
        'queue': uploadQueue,
      };
    }
    throw Exception('Invalid response from server: $map');
  }

  // ─────────────────────────────────────────────────────────────
  // Background upload queue
  // ─────────────────────────────────────────────────────────────

  Future<List<String>> processBackgroundUploadQueue(
    List<Map<String, dynamic>> queue,
    encrypt.Key key,
    Function(int current, int total) onProgressUpdate,
  ) async {
    final List<String> errors = [];
    int current = 0;

    for (var item in queue) {
      current++;
      onProgressUpdate(current, queue.length);
      try {
        final Draft draft = item['draft'];
        final String fileName = item['fileName'];
        final String? proofId = item['proofId'];

        final file = File(draft.transformedPath);
        if (!file.existsSync()) {
          debugPrint('⚠️ Skip: file not found at ${draft.transformedPath}');
          continue;
        }

        // Compress images before upload
        String uploadPath = draft.transformedPath;
        if (draft.type == MediaType.image) {
          uploadPath = await _compressImageIfNeeded(draft.transformedPath);
        }

        // Encrypt file bytes (AES-256-CBC, IV prepended)
        final rawBytes = await File(uploadPath).readAsBytes();
        final iv = encrypt.IV.fromSecureRandom(16);
        final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
        final encData = encrypter.encryptBytes(rawBytes, iv: iv);
        final tempDir = await getTemporaryDirectory();
        final encFile = File('${tempDir.path}/enc_${draft.id}.bin');
        await encFile.writeAsBytes(Uint8List.fromList([...iv.bytes, ...encData.bytes]));
        uploadPath = encFile.path;

        // Hash the encrypted file
        final hashData = await _hashFile(uploadPath);
        if (hashData == null) {
          errors.add('Failed to hash file: $fileName');
          continue;
        }

        final String sha256Hash = hashData['sha256'];
        final int sizeBytes = hashData['size'];
        final int originalSize = await _fileSize(draft.originalPath);

        // Upload with retry
        await _ensureFreshSession();
        String? publicUrl;
        Exception? lastError;
        for (int attempt = 1; attempt <= 3; attempt++) {
          try {
            publicUrl = await _uploadFile(uploadPath, fileName);
            if (publicUrl != null) break;
          } catch (e) {
            lastError = e is Exception ? e : Exception(e.toString());
            if (attempt < 3) await Future.delayed(Duration(seconds: attempt * 3));
          }
        }
        if (publicUrl == null && lastError != null) throw lastError;

        // Record in evidence_media table
        final user = Supabase.instance.client.auth.currentUser;
        if (proofId != null && user != null) {
          try {
            await Supabase.instance.client.from('evidence_media').insert({
              'proof_id': proofId,
              'user_id': user.id,
              'r2_key': fileName,
              'media_type': draft.type.name,
              'storage_location': 'R2',
              'sha256_hash': sha256Hash,
              'original_size_bytes': originalSize,
              'size_bytes': sizeBytes,
              'duration_seconds': draft.durationSeconds,
              'migration_status': 'UPLOADED',
            });
          } catch (e) {
            debugPrint('⚠️ evidence_media insert (non-fatal): $e');
          }
        }

        // Upload unencrypted thumbnail (image or video first-frame), best-effort
        if (draft.type == MediaType.image || draft.type == MediaType.video) {
          try {
            debugPrint('🖼️ Generating thumbnail for ${draft.type}: ${draft.transformedPath}');
            Uint8List? thumbBytes;
            if (draft.type == MediaType.image) {
              thumbBytes = await FlutterImageCompress.compressWithFile(
                draft.transformedPath,
                minWidth: 300,
                minHeight: 300,
                quality: 60,
              );
            } else {
              thumbBytes = await VideoCompress.getByteThumbnail(
                draft.transformedPath, quality: 70, position: 0);
            }
            debugPrint('🖼️ thumbBytes = ${thumbBytes?.length ?? 'null'}');
            if (thumbBytes != null) {
              final thumbFileName = 'thumb_$fileName.jpg';
              final thumbTmpPath = '${tempDir.path}/$thumbFileName';
              await File(thumbTmpPath).writeAsBytes(thumbBytes);
              final thumbUrl = await _uploadFile(thumbTmpPath, thumbFileName);
              debugPrint('✅ Thumbnail uploaded: $thumbUrl');
              try { File(thumbTmpPath).deleteSync(); } catch (_) {}
            }
          } catch (e) {
            debugPrint('⚠️ Thumbnail upload (non-fatal): $e');
          }
        }
      } catch (e) {
        debugPrint('❌ Upload error for ${item['fileName']}: $e');
        errors.add(e.toString());
      } finally {
        // Clean up encrypted temp file
        try {
          final encFile = File('${(await getTemporaryDirectory()).path}/enc_${(item['draft'] as Draft).id}.bin');
          if (encFile.existsSync()) encFile.deleteSync();
        } catch (_) {}
      }
    }

    try {
      await VideoCompress.deleteAllCache().timeout(const Duration(seconds: 15));
    } catch (_) {}

    return errors;
  }

  // ─────────────────────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────────────────────

  String _ext(MediaType type) {
    switch (type) {
      case MediaType.image: return 'jpg';
      case MediaType.video: return 'mp4';
      case MediaType.audio: return 'm4a';
      case MediaType.text: return 'txt';
    }
  }

  Future<void> _ensureFreshSession() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null || session.isExpired) {
        await Supabase.instance.client.auth.refreshSession();
      }
    } catch (e) {
      debugPrint('⚠️ Session refresh failed: $e');
    }
  }

  static const int _maxImageBytes = 1 * 1024 * 1024; // 1 MB

  // Garantit ≤ 20 MB/min. Compression uniquement si le fichier brut dépasse le seuil.
  Future<String> _compressImageIfNeeded(String inputPath) async {
    try {
      final file = File(inputPath);
      if (await file.length() <= _maxImageBytes) return inputPath;

      final appDir = await getApplicationDocumentsDirectory();
      final base = '${appDir.path}/wassit_cache/c_${DateTime.now().millisecondsSinceEpoch}';

      // Try progressively lower quality until under 1 MB
      for (final quality in [70, 50, 30]) {
        final out = '${base}_q$quality.jpg';
        final result = await FlutterImageCompress.compressAndGetFile(
          inputPath, out, quality: quality, minWidth: 1080, minHeight: 1080,
        );
        if (result != null) {
          final compressed = File(result.path);
          if (await compressed.exists() && await compressed.length() <= _maxImageBytes) {
            return result.path;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Compression failed, using original: $e');
    }
    return inputPath;
  }

  Future<Map<String, dynamic>?> _hashFile(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      return {
        'sha256': crypto.sha256.convert(bytes).toString(),
        'size': bytes.length,
      };
    } catch (e) {
      debugPrint('⚠️ Hash error: $e');
      return null;
    }
  }

  Future<int> _fileSize(String path) async {
    try {
      return await File(path).length();
    } catch (_) {
      return 0;
    }
  }

  /// Delegates to [StorageUploadPolicy] which tries SDK then HTTP fallback.
  Future<String?> _uploadFile(String filePath, String fileName) async {
    return StorageUploadPolicy().upload(filePath, fileName);
  }
}
