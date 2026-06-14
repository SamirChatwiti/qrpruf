import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class WassitAudioApi {
  static String get _signUrl =>
      dotenv.env['AUDIO_SIGN_URL'] ?? 'https://audio.qrpruf.com/sign';

  static Future<String> uploadAndSignWav(String rawPath) async {
    final uri = Uri.parse(_signUrl);

    final request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('file', rawPath));

    final response = await request.send();

    if (response.statusCode != 200) {
      throw Exception('Upload failed: ${response.statusCode}');
    }

    final dir = await getTemporaryDirectory();
    final outPath =
        '${dir.path}/audio_signed_${DateTime.now().millisecondsSinceEpoch}.wav';

    final file = File(outPath);
    await response.stream.pipe(file.openWrite());

    return outPath;
  }
}
