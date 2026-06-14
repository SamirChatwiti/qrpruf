import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class KycRepository {
  static final KycRepository _instance = KycRepository._internal();
  factory KycRepository() => _instance;
  KycRepository._internal();

  /// Saves the physical identity information scanned from the ID card
  /// to the currently authenticated user's profile in Supabase.
  Future<void> saveIdentityVerification({
    required String idNum,
    required String firstName,
    required String lastName,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception('لا يوجد مستخدم مسجل الدخول لحفظ بيانات الهوية');
    }

    // Determine legal status theoretically - In production this might need manual admin validation
    // For now we assume if the data is extracted successfully, they passed level 1 KYC
    try {
      await Supabase.instance.client.from('profiles').update({
        'national_id': idNum.toUpperCase(),
        'first_name': firstName,
        'last_name': lastName,
        'kyc_status': 'verified_l1', // L1 = Automated Scan completed
        'legal_status': 'particulier', // Default
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
    } catch (e) {
      debugPrint('Failed to save KYC: $e');
      throw Exception('تعذر حفظ بيانات الهوية في الخادم');
    }
  }
}
