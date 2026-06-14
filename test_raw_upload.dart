import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final url = 'https://zfymvplcumibsjmkvejf.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpmeW12cGxjdW1pYnNqbWt2ZWpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjczNzQ3NjksImV4cCI6MjA4Mjk1MDc2OX0.VxpvdVgd933bbwIz4pveNJOqMwZEBi46NGFtADtzYoo';

  final fileName = 'b168336a-c8c4-45a4-a6e6-d54b4b005885_1775380468204_1775380468204.jpg';
  
  final endpoint = '$url/storage/v1/object/proof-media/$fileName';
  
  var response = await http.post(
    Uri.parse(endpoint),
    headers: {
      'apikey': anonKey,
      'Authorization': 'Bearer $anonKey',
      'Content-Type': 'application/octet-stream', // Try the exact content type from the app
    },
    body: [1, 2, 3], // Tiny dummy payload
  );

  print('Status: ${response.statusCode}');
  print('Body: ${response.body}');
}
