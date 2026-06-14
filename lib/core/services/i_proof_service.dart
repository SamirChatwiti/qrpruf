import 'dart:io';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:qrpruf/features/proofs/data/models/draft.dart';

/// Abstract contract for the proof generation pipeline.
///
/// Depend on this interface in widgets and business logic; inject a concrete
/// [ProofService] in production and a mock in tests.
///
/// ```dart
/// // Production
/// final IProofService svc = ProofService();
///
/// // Test
/// class MockProofService extends IProofService {
///   @override
///   Future<String?> checkDailyQuota(MediaType type, {int durationSeconds = 0}) async => null;
///   // ...
/// }
/// ```
abstract class IProofService {
  // ── Draft creation ────────────────────────────────────────────────────────

  Future<Draft> createDraftFromMedia(
    File rawFile,
    MediaType type, {
    String? role,
    List<String>? intentions,
    int? knownDurationSeconds,
  });

  // ── Quota ─────────────────────────────────────────────────────────────────

  /// Returns `null` if within quota, or a localised error message if exceeded.
  Future<String?> checkDailyQuota(MediaType type, {int durationSeconds = 0});

  /// Returns remaining capacity: image count, or seconds for video/audio.
  Future<int> getRemainingQuota(MediaType type, {int sessionSecondsUsed = 0});

  // ── Media trim ────────────────────────────────────────────────────────────

  /// Trims [inputPath] to [maxSeconds] via the native MediaMuxer channel.
  /// Falls back to [inputPath] unchanged if the platform channel fails.
  Future<String> trimMedia(String inputPath, int maxSeconds);

  // ── Proof generation ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> generateProofPayloadImmediate(
    List<Draft> drafts, {
    Map<String, double>? locationData,
    String? customDescription,
    String? selectedType,
    List<String>? extraChoices,
    Function(String)? onProgress,
  });

  // ── Background upload ─────────────────────────────────────────────────────

  Future<List<String>> processBackgroundUploadQueue(
    List<Map<String, dynamic>> queue,
    encrypt.Key key,
    Function(int current, int total) onProgressUpdate,
  );

  // ── Signature overlay (no-op in base impl) ────────────────────────────────

  Future<Draft> applySignatureToDraft(Draft draft, dynamic placemark,
      {int rotationAngle = 0});
}
