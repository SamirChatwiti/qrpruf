import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:path_provider/path_provider.dart';

class ProofCryptoService {
  static final ProofCryptoService _instance = ProofCryptoService._internal();
  factory ProofCryptoService() => _instance;
  ProofCryptoService._internal();

  /// Top Level Isolate function for streaming Hash only (For large videos)
  static Map<String, dynamic> _hashOnlyIsolate(Map<String, dynamic> args) {
     final String inputPath = args['inputPath'];
     final file = File(inputPath);
     if (!file.existsSync()) {
        throw Exception('File not found in isolate');
     }
     
     // Robust synchronous read & hash (safe for Isolates vs huge AES memory spikes)
     final bytes = file.readAsBytesSync();
     final sizeBytes = bytes.length;
     final digest = crypto.sha256.convert(bytes);
     
     return {
        'path': inputPath, 
        'sha256': digest.toString(),
        'size': sizeBytes,
     };
  }

  /// Top Level Isolate function for heavy AES-GCM encryption
  static Map<String, dynamic> _encryptIsolate(Map<String, dynamic> args) {
     final String inputPath = args['inputPath'];
     final String outputPath = args['outputPath'];
     final String keyBase64 = args['keyBase64'];
     
     final file = File(inputPath);
     if (!file.existsSync()) {
        throw Exception('File not found in isolate');
     }
     
     // 1. Read
     final bytes = file.readAsBytesSync();
     final sizeBytes = bytes.length;
     
     // 2. Hash Original
     final digest = crypto.sha256.convert(bytes);
     final sha256Hash = digest.toString();
     
     // 3. Encrypt AES-GCM
     final encrypt.Key key = encrypt.Key.fromBase64(keyBase64);
     final iv = encrypt.IV.fromSecureRandom(12); 
     final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));
     final encrypted = encrypter.encryptBytes(bytes, iv: iv);
     
     // 4. Write directly to file to prevent RAM duplication
     final fileOut = File(outputPath).openSync(mode: FileMode.write);
     fileOut.writeFromSync(iv.bytes);
     fileOut.writeFromSync(encrypted.bytes);
     fileOut.closeSync();
     
     return {
        'sha256': sha256Hash,
        'size': sizeBytes,
     };
  }

  /// Helper: Encrypt File (AES-GCM) dynamically dispatching to Isolates
  /// Returns [encryptedTempPath, sha256, sizeBytes]
  Future<Map<String, dynamic>?> encryptFile(String inputPath, encrypt.Key key, {bool skipEncryption = false}) async {
    try {
      if (skipEncryption) {
         // Videos are too gigantic for Dart's pure AES engine. Hash and bypass to prevent OOM.
         return await compute(_hashOnlyIsolate, {'inputPath': inputPath});
      }

      final appDir = await getApplicationDocumentsDirectory();
      final tempPath = '${appDir.path}/enc_${DateTime.now().microsecondsSinceEpoch}.bin';
      
      // Offload EVERYTHING to Background Isolate to avoid UI freeze
      final result = await compute(_encryptIsolate, {
         'inputPath': inputPath,
         'outputPath': tempPath,
         'keyBase64': key.base64,
      });
      
      return {
         'path': tempPath,
         'sha256': result['sha256'],
         'size': result['size'],
      };
    } catch (e) {
      debugPrint('🔒 Encryption Error: $e');
      throw Exception('Encryption Isolate Error: $e');
    }
  }
}
