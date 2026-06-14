import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:qrpruf/providers/theme_provider.dart';
import 'package:qrpruf/core/theme/app_theme.dart';
import 'package:qrpruf/l10n/app_localizations.dart';
import 'package:qrpruf/core/routing/app_router.dart';
import 'package:qrpruf/core/providers/app_state_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  await dotenv.load();

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    authOptions: const FlutterAuthClientOptions(
      detectSessionInUri: false,
    ),
  );

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  final _appLinks = AppLinks();
  late StreamSubscription<Uri> _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _checkColdStartDeepLink();
  }

  bool _isAuthDeepLink(Uri uri) {
    final url = uri.toString();
    // Custom scheme deep links (qrpruf://)
    if (uri.host == 'reset-password' || uri.host == 'login-callback') return true;
    // HTTPS Supabase verification URLs (intercepted before Chrome on Android)
    if (uri.scheme == 'https' && uri.host.contains('supabase.co') && uri.path.contains('/auth/v1/verify')) return true;
    // Token-type markers in any URL
    return url.contains('type=recovery') ||
        url.contains('type=signup') ||
        url.contains('type=invite');
  }

  void _initDeepLinks() {
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      if (_isAuthDeepLink(uri)) {
        ref.read(goRouterProvider).go('/confirm-mail', extra: uri);
      }
    });
  }

  Future<void> _checkColdStartDeepLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null && _isAuthDeepLink(uri)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(goRouterProvider).go('/confirm-mail', extra: uri);
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _linkSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      routerConfig: router,
      title: 'QRpruf',
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: DefaultTextStyle.merge(
              textAlign: TextAlign.right,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ref.watch(themeProvider),
    );
  }
}
