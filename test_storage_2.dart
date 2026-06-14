import 'dart:io';
import 'package:supabase/supabase.dart';

void main() async {
  final url = 'https://zfymvplcumibsjmkvejf.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpmeW12cGxjdW1pYnNqbWt2ZWpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjczNzQ3NjksImV4cCI6MjA4Mjk1MDc2OX0.VxpvdVgd933bbwIz4pveNJOqMwZEBi46NGFtADtzYoo';

  final supabase = SupabaseClient(url, anonKey);
  
  // 1. Sign up a dummy user
  final email = 'test${DateTime.now().millisecondsSinceEpoch}@qrpruf.com';
  final password = 'Password123!';
  
  final res = await supabase.auth.signUp(email: email, password: password);
  final token = res.session?.accessToken;
  print('token: $token');
  
  final file = File('test_123.txt');
  file.writeAsStringSync('hello world');
  
  try {
    final response = await supabase.storage.from('proof-media').upload('test_supabase_pkg.txt', file);
    print('SUCCESS: $response');
  } catch (e) {
    print('ERROR UPLOAD: $e');
  }
}
