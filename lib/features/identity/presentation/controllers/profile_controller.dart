import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileState {
  final bool isPhoneVerified;
  final bool isIdVerified;
  final String? phone;

  ProfileState({
    required this.isPhoneVerified,
    required this.isIdVerified,
    this.phone,
  });

  ProfileState copyWith({
    bool? isPhoneVerified,
    bool? isIdVerified,
    String? phone,
  }) {
    return ProfileState(
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      isIdVerified: isIdVerified ?? this.isIdVerified,
      phone: phone ?? this.phone,
    );
  }
}

class ProfileController extends AsyncNotifier<ProfileState> {
  @override
  FutureOr<ProfileState> build() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return ProfileState(isPhoneVerified: false, isIdVerified: false);
    }

    // On récupère les infos depuis les métadonnées de l'utilisateur Supabase
    // Dans un vrai projet, on pourrait utiliser une table 'profiles' dédiée.
    final metadata = user.userMetadata ?? {};
    
    return ProfileState(
      isPhoneVerified: metadata['phone_verified'] == true,
      isIdVerified: metadata['id_verified'] == true,
      phone: user.phone,
    );
  }

  Future<void> setPhoneVerified(bool verified) async {
    state = const AsyncValue.loading();
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'phone_verified': verified}),
      );
      ref.invalidateSelf();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> setIdVerified(bool verified) async {
    state = const AsyncValue.loading();
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'id_verified': verified}),
      );
      ref.invalidateSelf();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

final profileControllerProvider = AsyncNotifierProvider<ProfileController, ProfileState>(() {
  return ProfileController();
});
