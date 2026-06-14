import 'dart:io';
import 'package:video_compress/video_compress.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class VideoCompressionResult {
  final File file;
  final String sha256Hash;
  final int originalSize;
  final int compressedSize;

  VideoCompressionResult({
    required this.file, 
    required this.sha256Hash,
    required this.originalSize,
    required this.compressedSize,
  });
}

class VideoCompressor {
  static Future<VideoCompressionResult?> compressVideo(File inputFile) async {
    try {
      // Max compression: 720p (legal requirement) and 10 FPS
      final info = await VideoCompress.compressVideo(
        inputFile.path,
        quality: VideoQuality.Res1280x720Quality,
        frameRate: 24,
        includeAudio: true,
      );

      if (info != null && info.file != null) {
        final outputFile = info.file!;
        
        // Calculate SHA-256 for legal integrity
        final bytes = await outputFile.readAsBytes();
        final digest = sha256.convert(bytes);
        
        debugPrint('Video Compression Success. Original: ${inputFile.lengthSync()} -> Compressed: ${info.filesize}');
        
        return VideoCompressionResult(
          file: outputFile,
          sha256Hash: digest.toString(),
          originalSize: inputFile.lengthSync(),
          compressedSize: info.filesize ?? outputFile.lengthSync(),
        );
      } else {
        debugPrint('Video Compression returned null');
        return null; // Return null to fallback to original
      }
    } catch (e) {
      debugPrint('Error during video compression: $e');
      return null;
    }
  }
}
