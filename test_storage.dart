import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final url = 'https://zfymvplcumibsjmkvejf.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpmeW12cGxjdW1pYnNqbWt2ZWpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjczNzQ3NjksImV4cCI6MjA4Mjk1MDc2OX0.VxpvdVgd933bbwIz4pveNJOqMwZEBi46NGFtADtzYoo';

  // 1. Sign up a dummy user
  final email = 'test${DateTime.now().millisecondsSinceEpoch}@qrpruf.com';
  final password = 'Password123!';
  
  print('signing up...');
  final signUpRes = await http.post(
    Uri.parse('$url/auth/v1/signup'),
    headers: {'apikey': anonKey, 'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': password}),
  );

  print('Signup status: ${signUpRes.statusCode}');
  
  String? token;
  if (signUpRes.statusCode == 200) {
    final body = jsonDecode(signUpRes.body);
    token = body['access_token'];
  } else {
    print('Failed to sign up/login: ${signUpRes.body}');
    return;
  }

  print('Token generated. Uploading test file to proof-media bucket...');
  // 2. Upload a file
  final req = http.MultipartRequest('POST', Uri.parse('$url/storage/v1/object/proof-media/test_123.txt'));
  req.headers.addAll({
    'apikey': anonKey,
    'Authorization': 'Bearer $token',
  });
  req.files.add(http.MultipartFile.fromString('file', 'test_data_hello_world', filename: 'test_123.txt'));

  final sendRes = await req.send();
  print('Upload status: ${sendRes.statusCode}');
  final bodyStr = await sendRes.stream.bytesToString();
  print('Upload body: $bodyStr');
}
