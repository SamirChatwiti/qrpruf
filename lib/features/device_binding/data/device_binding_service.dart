import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class DeviceBindingService {
  static final DeviceBindingService _instance = DeviceBindingService._internal();
  factory DeviceBindingService() => _instance;
  DeviceBindingService._internal();

  final _secureStorage = const FlutterSecureStorage();
  final _deviceInfo = DeviceInfoPlugin();

  /// Retrieves a unique, hashed hardware identifier for this device
  Future<String> _getUniqueDeviceHash() async {
    String deviceIdentifier = '';
    
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      // Using Android ID which persists across app installs but resets on factor reset
      deviceIdentifier = androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      deviceIdentifier = iosInfo.identifierForVendor ?? 'unknown_ios_device';
    } else {
      deviceIdentifier = 'unsupported_platform';
    }

    // Hash it for privacy
    final bytes = utf8.encode(deviceIdentifier + 'qrpruf_salt_2026');
    return sha256.convert(bytes).toString();
  }

  /// Called immediately after a successful authentication (during the loading state)
  /// Returns `true` if device is authorized or successfully registered.
  /// Returns `false` if the account is bound to another device.
  Future<bool> verifyOrRegisterDevice(String userId) async {
    try {
      final currentDeviceHash = await _getUniqueDeviceHash();

      // 1. Fetch user's assigned device from Supabase
      // Assuming a 'profiles' table with a 'bound_device_hash' column
      final response = await Supabase.instance.client
          .from('profiles')
          .select('bound_device_hash')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        // Warning: profile doesn't exist yet, we might need to create it
        // For now, let's assume registration handles profile creation, and it's null originally
        await _registerDevice(userId, currentDeviceHash);
        return true;
      }

      final boundDeviceHash = response['bound_device_hash'];

      // 2. First login ever on this account -> Bind the current device
      if (boundDeviceHash == null || boundDeviceHash.toString().isEmpty) {
        await _registerDevice(userId, currentDeviceHash);
        return true;
      }

      // 3. User is already bound. Verify against current device.
      if (boundDeviceHash == currentDeviceHash) {
        // Authorized. Keep a local flag for offline checks if needed.
        await _secureStorage.write(key: 'is_device_bound', value: 'true');
        return true;
      }

      // 4. Unauthorized device
      return false;

    } catch (e) {
      debugPrint('Device binding error: $e');
      // In a strict legal app, fail secure: deny access if error occurs
      throw Exception('فشل التحقق من الجهاز (أمان)');
    }
  }

  Future<void> _registerDevice(String userId, String deviceHash) async {
    await Supabase.instance.client
        .from('profiles')
        .update({'bound_device_hash': deviceHash})
        .eq('id', userId);
        
    await _secureStorage.write(key: 'is_device_bound', value: 'true');
  }
}
