import 'dart:io';
import 'package:flutter/foundation.dart';

/// Detects rooted (Android) or jailbroken (iOS) devices before proof generation.
///
/// In debug builds this always returns [CompromiseResult.safe] so development
/// is never blocked. All file-system probes run in an isolate-safe async
/// context and are non-destructive read-only checks, except the iOS sandbox
/// write probe which immediately cleans up after itself.
class DeviceIntegrityService {
  static final DeviceIntegrityService _instance =
      DeviceIntegrityService._internal();
  factory DeviceIntegrityService() => _instance;
  DeviceIntegrityService._internal();

  // ── Android root indicators ───────────────────────────────────────────────

  static const _androidSuPaths = [
    '/sbin/su',
    '/system/bin/su',
    '/system/xbin/su',
    '/data/local/xbin/su',
    '/data/local/bin/su',
    '/system/sd/xbin/su',
    '/system/bin/failsafe/su',
    '/data/local/su',
    '/su/bin/su',
  ];

  static const _androidRootApks = [
    '/system/app/Superuser.apk',
    '/system/app/SuperSU.apk',
    '/system/app/Magisk.apk',
  ];

  static const _magiskPaths = [
    '/sbin/.magisk',
    '/sbin/.core/mirror',
    '/sbin/.core/img',
    '/sbin/.core/db-0/magisk.db',
  ];

  // ── iOS jailbreak indicators ──────────────────────────────────────────────

  static const _iosJailbreakPaths = [
    '/Applications/Cydia.app',
    '/Applications/Sileo.app',
    '/Applications/Zebra.app',
    '/Library/MobileSubstrate/MobileSubstrate.dylib',
    '/bin/bash',
    '/usr/sbin/sshd',
    '/etc/apt',
    '/private/var/lib/apt',
    '/usr/bin/ssh',
  ];

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns [CompromiseResult.safe] or a [CompromiseResult] describing the
  /// detected threat.  Always returns [CompromiseResult.safe] in debug mode.
  Future<CompromiseResult> check() async {
    if (kDebugMode) return CompromiseResult.safe;

    try {
      if (Platform.isAndroid) return await _checkAndroid();
      if (Platform.isIOS) return await _checkIos();
    } catch (_) {
      // Never crash the app due to an integrity check error.
    }
    return CompromiseResult.safe;
  }

  // ── Android ───────────────────────────────────────────────────────────────

  Future<CompromiseResult> _checkAndroid() async {
    for (final path in _androidSuPaths) {
      if (await File(path).exists()) {
        return CompromiseResult._(
          isCompromised: true,
          reason: 'su binary detected at $path',
        );
      }
    }

    for (final path in _androidRootApks) {
      if (await File(path).exists()) {
        return CompromiseResult._(
          isCompromised: true,
          reason: 'root APK detected at $path',
        );
      }
    }

    for (final path in _magiskPaths) {
      if (await File(path).exists() || await Directory(path).exists()) {
        return CompromiseResult._(
          isCompromised: true,
          reason: 'Magisk artifact detected at $path',
        );
      }
    }

    return CompromiseResult.safe;
  }

  // ── iOS ───────────────────────────────────────────────────────────────────

  Future<CompromiseResult> _checkIos() async {
    for (final path in _iosJailbreakPaths) {
      if (await File(path).exists() || await Directory(path).exists()) {
        return CompromiseResult._(
          isCompromised: true,
          reason: 'jailbreak artifact detected at $path',
        );
      }
    }

    // Sandbox escape probe: a non-jailbroken device cannot write here.
    final probe =
        File('/private/qrpruf_probe_${DateTime.now().millisecondsSinceEpoch}');
    try {
      await probe.writeAsString('x');
      await probe.delete();
      return CompromiseResult._(
        isCompromised: true,
        reason: 'sandbox escape: write outside app container succeeded',
      );
    } on FileSystemException {
      // Expected on a healthy device — write is rejected by the OS.
    }

    return CompromiseResult.safe;
  }
}

/// The result of a [DeviceIntegrityService.check] call.
class CompromiseResult {
  final bool isCompromised;
  final String? reason;

  const CompromiseResult._({required this.isCompromised, this.reason});

  static const safe = CompromiseResult._(isCompromised: false);

  @override
  String toString() => isCompromised ? 'COMPROMISED: $reason' : 'SAFE';
}
