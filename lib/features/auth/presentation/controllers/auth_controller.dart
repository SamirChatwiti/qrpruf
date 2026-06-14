import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../device_binding/data/device_binding_service.dart';
import '../../../../core/security/biometric_service.dart';

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(() {
  return AuthController();
});

class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    // Initial state is just empty
  }

  Future<void> signInWithPassword(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user != null) {
        final isAuthorized = await DeviceBindingService().verifyOrRegisterDevice(user.id);
        
        if (!isAuthorized) {
           await Supabase.instance.client.auth.signOut();
           state = AsyncValue.error('غير مصرح. هذا الحساب مرتبط بجهاز آخر.', StackTrace.current);
           return;
        }
        
        // Save credentials for future biometric login if successful
        await BiometricService().saveCredentials(email, password);
        await BiometricService().setBiometricEnabled(true);
      }

      state = const AsyncValue.data(null);
    } on AuthException catch (e) {
      state = AsyncValue.error(_friendlyAuthError(e), StackTrace.current);
    } catch (e) {
      state = AsyncValue.error('حدث خطأ غير متوقع. يرجى المحاولة لاحقاً', StackTrace.current);
    }
  }

  Future<void> signUpWithPassword(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'qrpruf://login-callback/',
        data: {
          'id_verified': false,
          'phone_verified': false,
          'full_name': 'المستخدم الجديد',
        },
      );

      final user = response.user;
      // Supabase returns a user with empty identities when the email already exists
      if (user != null && (user.identities?.isEmpty ?? false)) {
        state = AsyncValue.error('هذا البريد الإلكتروني مستخدم بالفعل. يرجى تسجيل الدخول.', StackTrace.current);
        return;
      }
      if (user != null) {
        state = const AsyncValue.data(null);
      }
    } on AuthException catch (e) {
      state = AsyncValue.error(_friendlyAuthError(e), StackTrace.current);
    } catch (e) {
      state = AsyncValue.error('حدث خطأ غير متوقع. يرجى المحاولة لاحقاً', StackTrace.current);
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await Supabase.instance.client.auth.signOut();
      // Optional: don't clear biometric credentials on logout unless specifically requested
      // to allow easy re-login.
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error('خطأ أثناء تسجيل الخروج', StackTrace.current);
    }
  }

  String _friendlyAuthError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials')) return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
    if (msg.contains('email not confirmed')) return 'يرجى تأكيد بريدك الإلكتروني أولاً';
    return 'خطأ في المصادقة. يرجى المحاولة لاحقاً';
  }
}
