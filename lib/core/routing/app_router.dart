import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import 'package:qrpruf/pages/home_screen.dart';
import '../../features/proofs/presentation/screens/loc_gharad.dart';
import '../../features/proofs/presentation/screens/dash_wassit.dart';
import '../../features/proofs/presentation/screens/wassit_summary_page.dart';
import 'package:qrpruf/pages/settings_page.dart';
import 'package:qrpruf/pages/confirm_mail.dart';
import 'package:qrpruf/pages/reset_password.dart';
import '../../features/identity/presentation/id_scanner_screen.dart';
import 'package:qrpruf/pages/phone_input_page.dart';
import '../providers/app_state_providers.dart';
import '../../models/proof.dart';
import 'package:qrpruf/pages/my_proofs_page.dart';
import 'package:qrpruf/pages/proof_view_page.dart';
import 'package:qrpruf/pages/avatar_page.dart';
import 'package:qrpruf/pages/pack_page.dart';
import 'package:qrpruf/pages/notifications_page.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  bool _passwordRecovery = false;

  RouterNotifier(this._ref) {
    _ref.listen(onboardingCompletedProvider, (_, __) => notifyListeners());

    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _passwordRecovery = true;
        notifyListeners();
      } else if (data.event == AuthChangeEvent.signedIn) {
        // If the sign-in came from an email confirmation link (OTP),
        // sign out immediately — user must log in manually.
        final token = data.session?.accessToken ?? '';
        if (_isOtpJwt(token)) {
          await Supabase.instance.client.auth.signOut();
          // SIGNED_OUT event will call notifyListeners.
        } else {
          notifyListeners();
        }
      } else {
        notifyListeners();
      }
    });
  }

  bool _isOtpJwt(String accessToken) {
    try {
      final parts = accessToken.split('.');
      if (parts.length != 3) return false;
      final payload = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final amr = payload['amr'] as List?;
      return amr?.any((e) => (e as Map)['method'] == 'otp') ?? false;
    } catch (_) {
      return false;
    }
  }

  String? redirectAction(BuildContext context, GoRouterState state) {
    final loc = state.matchedLocation;

    // Password recovery: redirect to reset-password from anywhere except confirm-mail
    if (_passwordRecovery && loc != '/confirm-mail' && loc != '/reset-password') {
      _passwordRecovery = false;
      return '/reset-password';
    }
    if (loc == '/confirm-mail' || loc == '/reset-password') {
      _passwordRecovery = false;
      return null;
    }

    final onboardingCompleted = _ref.read(onboardingCompletedProvider);
    final session = Supabase.instance.client.auth.currentSession;

    final isGoingToLogin = loc == '/login';
    final isGoingToSignup = loc == '/signup';
    final isGoingToOnboarding = loc == '/onboarding';
    final isSplash = loc == '/';

    if (isSplash) return null;

    if (!onboardingCompleted) {
      if (!isGoingToOnboarding) return '/onboarding';
      return null;
    }

    if (isGoingToOnboarding) {
      return (session != null) ? '/dashboard' : null;
    }

    final isLoggedIn = session != null;

    if (!isLoggedIn) {
      if (isGoingToLogin || isGoingToSignup) return null;
      return '/login';
    } else {
      final userMetadata = Supabase.instance.client.auth.currentUser?.userMetadata ?? {};
      final profileComplete = userMetadata['profile_complete'] == true || userMetadata['pack_id'] != null;

      if (isGoingToLogin || isGoingToSignup) {
        return profileComplete ? '/dashboard' : '/id-scan';
      }

      if (!profileComplete) {
        if (loc == '/id-scan' || loc == '/phone-validation' || loc == '/avatar' || loc == '/notifications' || loc == '/pack') return null;
        return '/id-scan';
      }

      return null;
    }
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final goRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: notifier.redirectAction,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
      GoRoute(path: '/dashboard', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/selection', builder: (context, state) => LocGharadPage(initialSection: state.extra is PageSection ? state.extra as PageSection : null)),
      GoRoute(path: '/capture-hub', builder: (context, state) => const DashWassitPage()),
      GoRoute(path: '/summary', builder: (context, state) => const WassitSummaryPage()),
      GoRoute(path: '/profile', builder: (context, state) => const SettingsPage()),
      GoRoute(path: '/phone-validation', builder: (context, state) => const PhoneInputPage()),
      GoRoute(path: '/id-scan', builder: (context, state) => const IdScannerScreen()),
      GoRoute(
        path: '/confirm-mail',
        builder: (context, state) => ConfirmMailPage(uri: state.extra as Uri?),
      ),
      GoRoute(path: '/reset-password', builder: (context, state) => const ResetPasswordPage()),
      GoRoute(path: '/my-proofs', builder: (context, state) => const MyProofsPage()),
      GoRoute(
        path: '/proof-view',
        builder: (context, state) => ProofViewPage(proof: state.extra as Proof),
      ),
      GoRoute(path: '/avatar', builder: (context, state) => const AvatarPage()),
      GoRoute(path: '/notifications', builder: (context, state) => const NotificationsPage()),
      GoRoute(path: '/pack', builder: (context, state) => const PackPage()),
    ],
  );
});
