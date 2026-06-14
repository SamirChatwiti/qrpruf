import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:qrpruf/pages/my_proofs_page.dart';
import 'package:qrpruf/providers/theme_provider.dart';
import 'package:qrpruf/features/identity/presentation/id_scanner_screen.dart';
import 'package:qrpruf/core/providers/wassit_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _supabase = Supabase.instance.client;

  int _todayImageCount = 0;
  int _todayVideoSeconds = 0;
  int _todayAudioSeconds = 0;

  @override
  void initState() {
    super.initState();
    _fetchTodayUsage();
  }

  Future<void> _fetchTodayUsage() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final today = DateTime.now().toUtc().toIso8601String().split('T')[0];
      final response = await _supabase
          .from('evidence_media')
          .select('media_type, duration_seconds')
          .eq('user_id', user.id)
          .gte('created_at', '${today}T00:00:00Z');
      final items = response as List<dynamic>;
      int images = 0, videoSec = 0, audioSec = 0;
      for (final item in items) {
        final type = item['media_type'] as String? ?? '';
        final dur = (item['duration_seconds'] as num?)?.toInt() ?? 0;
        if (type == 'image') images++;
        else if (type == 'video') videoSec += dur;
        else if (type == 'audio') audioSec += dur;
      }
      if (mounted) setState(() {
        _todayImageCount = images;
        _todayVideoSeconds = videoSec;
        _todayAudioSeconds = audioSec;
      });
    } catch (_) {}
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(wassitProvider.notifier).clearSession(); // Clear drafts from RAM
      await _supabase.auth.signOut();
      if (mounted) context.go('/login');
    }
  }

  Future<void> _updatePassword() async {
     final passwordController = TextEditingController();
     final confirmController = TextEditingController();
     
     await showDialog(
       context: context,
       builder: (context) => AlertDialog(
         title: const Text('تغيير كلمة المرور'),
         content: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             TextField(
               controller: passwordController,
               obscureText: true,
               decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة'),
             ),
             TextField(
               controller: confirmController,
               obscureText: true,
               decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور'),
             ),
           ],
         ),
         actions: [
           TextButton(
             onPressed: () => Navigator.pop(context),
             child: const Text('إلغاء'),
           ),
           ElevatedButton(
             onPressed: () async {
               if (passwordController.text != confirmController.text) {
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('كلمات المرور غير متطابقة')),
                 );
                 return;
               }
               if (passwordController.text.length < 6) {
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('كلمة المرور قصيرة جداً')),
                 );
                 return;
               }
               
               try {
                 await _supabase.auth.updateUser(
                   UserAttributes(password: passwordController.text),
                 );
                 if (mounted) {
                   Navigator.pop(context);
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('تم تحديث كلمة المرور بنجاح')),
                   );
                 }
               } catch (e) {
                 ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text('حدث خطأ: $e')),
                 );
               }
             },
             child: const Text('تحديث'),
           ),
         ],
       ),
     );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الحساب'),
        content: const Text('هل أنت متأكد أنك تريد حذف حسابك؟ هذا الإجراء لا يمكن التراجع عنه.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف نهائي', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (_supabase.auth.currentUser == null) return;

        final response = await _supabase.functions.invoke('delete-account');

        if (response.status != 200) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('فشل حذف الحساب. يرجى المحاولة لاحقاً.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        ref.read(wassitProvider.notifier).clearSession();
        await _supabase.auth.signOut();
        if (mounted) context.go('/login');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فشل حذف الحساب. يرجى المحاولة لاحقاً.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildQuotaRow(String label, double used, double limit, String valueText, IconData icon) {
    final frac = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;
    final color = frac >= 1.0
        ? Colors.red
        : frac >= 0.8
            ? Colors.orange
            : Theme.of(context).primaryColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
            ]),
            Text(valueText, style: TextStyle(fontSize: 11, fontFamily: 'Cairo', color: color, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: frac,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 5,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final userMetadata = Supabase.instance.client.auth.currentUser?.userMetadata ?? {};
    final bool isIdentityVerified = userMetadata['identity_verified'] == true;
    final wassitState = ref.watch(wassitProvider);

    final packId = (userMetadata['pack_id'] as num?)?.toInt() ?? 0;
    const packQuotas = {
      0: {'photos': 5,   'audioMin': 2,   'videoMin': 0},
      1: {'photos': 10,  'audioMin': 10,  'videoMin': 5},
      2: {'photos': 90,  'audioMin': 40,  'videoMin': 20},
      3: {'photos': 999, 'audioMin': 999, 'videoMin': 999},
    };
    final q = packQuotas[packId] ?? packQuotas[0]!;

    final imageCount = _todayImageCount;
    final imageLimit = q['photos']!;
    final videoSec = _todayVideoSeconds + wassitState.sessionVideoSeconds;
    final videoLimitSec = q['videoMin']! * 60;
    final audioSec = _todayAudioSeconds + wassitState.sessionAudioSeconds;
    final audioLimitSec = q['audioMin']! * 60;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          if (!isIdentityVerified) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'لم يتم التحقق من هويتك بعد. يرجى مسح بطاقتك الوطنية لتفعيل كافة المميزات.',
                      style: TextStyle(color: Colors.red, fontFamily: 'Cairo', fontSize: 13, height: 1.4, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                       Navigator.push(
                         context, 
                         MaterialPageRoute(builder: (_) => const IdScannerScreen())
                       );
                    },
                    child: const Text('بدء المسح', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                  ),
                ],
              ),
            ),
          ],
          // Section: Daily Quota
          _buildSectionHeader('الحصة اليومية'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _buildQuotaRow(
                  'صور',
                  imageCount.toDouble(),
                  imageLimit.toDouble(),
                  '$imageCount/$imageLimit صورة',
                  Icons.photo_camera,
                ),
                const SizedBox(height: 12),
                _buildQuotaRow(
                  'فيديو',
                  videoSec.toDouble(),
                  videoLimitSec > 0 ? videoLimitSec.toDouble() : 1.0,
                  videoLimitSec > 0
                      ? '${(videoSec / 60).toStringAsFixed(1)}/${q['videoMin']!} دقيقة'
                      : 'غير متاح',
                  Icons.videocam,
                ),
                const SizedBox(height: 12),
                _buildQuotaRow(
                  'صوت',
                  audioSec.toDouble(),
                  audioLimitSec.toDouble(),
                  '${(audioSec / 60).toStringAsFixed(1)}/${q['audioMin']!} دقيقة',
                  Icons.mic,
                ),
                const SizedBox(height: 8),
                Text(
                  'تتجدد الحصة يومياً عند منتصف الليل',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor, fontFamily: 'Cairo'),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const Divider(),

          // Section: Appearance
          _buildSectionHeader('المظهر'),
          SwitchListTile(
            title: const Text('الوضع الليلي'),
            subtitle: const Text('تغميق الألوان لراحة العين'),
            value: isDark,
            onChanged: (val) {
              ref.read(themeProvider.notifier).toggle();
            },
            secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
          ),
          
          const Divider(),

          // Section: Account
          _buildSectionHeader('الحساب'),
          ListTile(
            leading: const Icon(Icons.history_outlined),
            title: const Text('سجل العمليات'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyProofsPage()),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('الإشعارات'),
            trailing: Switch(value: true, onChanged: (v) {}), // Mock
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('تغيير كلمة المرور'),
            onTap: _updatePassword,
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFF5BBDB1)),
            title: const Text('تسجيل الخروج'),
            onTap: _signOut,
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          ),
          
          const Divider(),
          
          _buildSectionHeader('منطقة الخطر'),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('حذف الحساب', style: TextStyle(color: Colors.red)),
            onTap: _deleteAccount,
          ),
          
          const Divider(),
          
          // Section: About
          _buildSectionHeader('حول التطبيق'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('الإصدار'),
            trailing: Text('1.0.0'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
