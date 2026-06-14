import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardData {
  final int totalProofs;
  final int verifiedProofs;
  final List<Map<String, dynamic>> recentProofs;

  DashboardData({
    required this.totalProofs,
    required this.verifiedProofs,
    required this.recentProofs,
  });
}

final dashboardControllerProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  
  if (user == null) {
    throw Exception('User disconnected');
  }

  // 1. Fetch all proofs for stats
  final proofsResponse = await supabase
      .from('proofs')
      .select('status')
      .eq('subject_id', user.id);
  
  final proofsList = proofsResponse as List<dynamic>;
  final totalCount = proofsList.length;
  final verifiedCount = proofsList.where((p) => p['status'] == 'valid').length;

  // 2. Fetch Recent proofs (last 5)
  // Note: We're doing parallel loading of data if we needed, 
  // but selecting proofs usually gives us the whole record. 
  // Let's do a separate query strictly for UI to get the heavy metadata.
  final recentResponse = await supabase
      .from('proofs')
      .select('*')
      .eq('subject_id', user.id)
      .order('created_at', ascending: false)
      .limit(5);

  final recentList = List<Map<String, dynamic>>.from(recentResponse);

  return DashboardData(
    totalProofs: totalCount,
    verifiedProofs: verifiedCount,
    recentProofs: recentList,
  );
});
