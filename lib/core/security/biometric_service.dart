import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _keyBiometricEnabled = 'biometric_enabled';
  static const String _keyUserEmail = 'saved_user_email';
  static const String _keyUserPassword = 'saved_user_password';

  /// Checks if the device supports biometric authentication
  Future<bool> isBiometricAvailable() async {
    final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
    final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
    return canAuthenticate;
  }

  /// Sets whether biometric login should beenabled
  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _keyBiometricEnabled, value: enabled.toString());
  }

  /// Checks if biometric login is enabled by the user
  Future<bool> isBiometricEnabled() async {
    final String? value = await _storage.read(key: _keyBiometricEnabled);
    return value == 'true';
  }

  /// Saves user credentials securely
  Future<void> saveCredentials(String email, String password) async {
    await _storage.write(key: _keyUserEmail, value: email);
    await _storage.write(key: _keyUserPassword, value: password);
  }

  /// Retrieves saved user credentials
  Future<Map<String, String>?> getSavedCredentials() async {
    final String? email = await _storage.read(key: _keyUserEmail);
    final String? password = await _storage.read(key: _keyUserPassword);
    
    if (email != null && password != null) {
      return {'email': email, 'password': password};
    }
    return null;
  }

  /// Clear saved credentials (e.g., on logout)
  Future<void> clearCredentials() async {
    await _storage.delete(key: _keyUserEmail);
    await _storage.delete(key: _keyUserPassword);
    await _storage.delete(key: _keyBiometricEnabled);
  }

  /// Authenticate user via biometrics
  Future<bool> authenticate() async {
    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'يرجى المصادقة للدخول إلى حسابك',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      return didAuthenticate;
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
      return false;
    }
  }
}
