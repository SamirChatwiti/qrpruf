import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Encapsulates the ordered list of upload strategies for proof media.
///
/// Strategies are tried in sequence; the first one to return a non-null URL
/// wins. If all strategies fail, the last error is rethrown.
///
/// Default order: Supabase SDK → raw HTTP PUT/POST fallback.
class StorageUploadPolicy {
  static final StorageUploadPolicy _instance =
      StorageUploadPolicy._internal();
  factory StorageUploadPolicy() => _instance;
  StorageUploadPolicy._internal();

  static const String _bucket = 'proof-media';

  /// Attempt to upload [filePath] as [fileName], trying each strategy in turn.
  /// Returns the public URL of the uploaded file.
  Future<String?> upload(String filePath, String fileName) async {
    final strategies = [
      _supabaseSdkStrategy,
      _httpFallbackStrategy,
    ];

    Exception? lastError;
    for (final strategy in strategies) {
      try {
        final url = await strategy(filePath, fileName);
        if (url != null) return url;
      } on Exception catch (e) {
        lastError = e;
        debugPrint('StorageUploadPolicy: strategy failed → $e');
      }
    }

    if (lastError != null) throw lastError;
    return null;
  }

  // ── Strategy 1: Supabase SDK ──────────────────────────────────────────────

  Future<String?> _supabaseSdkStrategy(
      String filePath, String fileName) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    final contentType = _mimeType(fileName);

    try {
      await Supabase.instance.client.storage
          .from(_bucket)
          .upload(fileName, file,
              fileOptions: FileOptions(upsert: true, contentType: contentType));
      return Supabase.instance.client.storage
          .from(_bucket)
          .getPublicUrl(fileName);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('already exists') || msg.contains('Duplicate')) {
        return Supabase.instance.client.storage
            .from(_bucket)
            .getPublicUrl(fileName);
      }
      rethrow;
    }
  }

  // ── Strategy 2: Raw HTTP PUT → POST fallback ──────────────────────────────

  Future<String?> _httpFallbackStrategy(
      String filePath, String fileName) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    final token =
        Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) throw Exception('No auth token for HTTP upload');

    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    final url =
        Uri.parse('$supabaseUrl/storage/v1/object/$_bucket/$fileName');
    final contentType = _mimeType(fileName);
    final bytes = await file.readAsBytes();

    for (final method in ['PUT', 'POST']) {
      try {
        final request = http.Request(method, url);
        request.headers.addAll({
          'Authorization': 'Bearer $token',
          'apikey': anonKey,
          'Content-Type': contentType,
          'x-upsert': 'true',
        });
        request.bodyBytes = bytes;

        final response = await http.Response.fromStream(
          await request.send().timeout(const Duration(minutes: 5)),
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return '$supabaseUrl/storage/v1/object/public/$_bucket/$fileName';
        }
        if (response.statusCode == 409 ||
            response.body.contains('already exists')) {
          return '$supabaseUrl/storage/v1/object/public/$_bucket/$fileName';
        }
        debugPrint(
            'HTTP $method attempt: ${response.statusCode} ${response.body}');
      } catch (e) {
        if (method == 'POST') rethrow;
      }
    }
    return null;
  }

  // ── MIME helper ───────────────────────────────────────────────────────────

  String _mimeType(String fileName) {
    switch (fileName.split('.').last.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'mp4':
        return 'video/mp4';
      case 'm4a':
        return 'audio/m4a';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }
}
