import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConfirmMailPage extends StatefulWidget {
  final Uri? uri;
  const ConfirmMailPage({super.key, this.uri});

  @override
  State<ConfirmMailPage> createState() => _ConfirmMailPageState();
}

class _ConfirmMailPageState extends State<ConfirmMailPage> {
  bool _processing = true;
  String? _error;
  bool _handled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_handled) {
      _handled = true;
      _handleConfirmation();
    }
  }

  Future<void> _handleConfirmation() async {
    Uri? uri = widget.uri;

    // Fallback for cold start
    if (uri == null) {
      final defaultRoute = PlatformDispatcher.instance.defaultRouteName;
      if (defaultRoute.isNotEmpty && defaultRoute != '/') {
        uri = Uri.tryParse(defaultRoute);
      }
    }

    if (uri == null || !uri.hasScheme) {
      setState(() {
        _processing = false;
        _error = 'رابط التأكيد غير صالح.';
      });
      return;
    }

    try {
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
      if (!mounted) return;

      final type = uri.queryParameters['type'] ??
          uri.fragment
              .split('&')
              .firstWhere((e) => e.startsWith('type='), orElse: () => '')
              .split('=')
              .last;

      if (type == 'recovery') {
        context.go('/reset-password');
      } else {
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _processing = false;
          _error = 'فشل تأكيد الرابط. يرجى المحاولة مجدداً.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    if (_processing) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 24),
                Text(
                  _error ?? 'حدث خطأ غير متوقع.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('العودة إلى تسجيل الدخول', style: TextStyle(fontFamily: 'Cairo')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
