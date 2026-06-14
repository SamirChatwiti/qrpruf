import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeVideoRecorder {
  static const _channel = MethodChannel('com.qrpruf/video_recorder');

  /// Launches the native 720p camera activity (2.5 Mbps, H264, no post-compression).
  /// [maxSeconds] caps the recording duration (quota-aware).
  /// Returns the local file path, or null if the user cancelled.
  static Future<String?> recordVideo({int maxSeconds = 300}) async {
    try {
      final path = await _channel.invokeMethod<String>(
        'recordVideo',
        {'maxSeconds': maxSeconds},
      );
      return path;
    } catch (e) {
      debugPrint('NativeVideoRecorder error: $e');
      return null;
    }
  }
}
