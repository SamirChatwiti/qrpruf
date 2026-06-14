import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qrpruf/models/proof.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class ProofViewPage extends ConsumerStatefulWidget {
  const ProofViewPage({super.key, required this.proof});
  final Proof proof;

  @override
  ConsumerState<ProofViewPage> createState() => _ProofViewPageState();
}

class _ProofViewPageState extends ConsumerState<ProofViewPage> {
  late Proof _currentProof;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _mediaAssets = [];
  final Map<String, String> _signedUrls = {};

  @override
  void initState() {
    super.initState();
    _currentProof = widget.proof;
    _fetchProof();
  }

  Future<void> _fetchProof() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final data = await Supabase.instance.client
          .from('proofs')
          .select()
          .eq('proof_id', _currentProof.proofId)
          .maybeSingle();

      if (data == null) throw Exception('الإثبات غير موجود');

      final mediaData = await Supabase.instance.client
          .from('evidence_media')
          .select()
          .eq('proof_id', _currentProof.proofId);

      final assets = List<Map<String, dynamic>>.from(mediaData);

      final Map<String, String> signedUrls = {};
      for (final m in assets) {
        final r2Key = m['r2_key']?.toString();
        if (r2Key != null && r2Key.isNotEmpty) {
          try {
            signedUrls[r2Key] = await Supabase.instance.client.storage
                .from('proof-media')
                .createSignedUrl(r2Key, 3600);
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() {
          _currentProof = Proof.fromJson(data);
          _mediaAssets = assets;
          _signedUrls.addAll(signedUrls);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _errorMessage = 'تعذر تحميل الإثبات: $e'; _isLoading = false; });
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن فتح الرابط', style: TextStyle(fontFamily: 'Cairo'))));
    }
  }

  bool _verifyProof() => _currentProof.status == 'valid';

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'))),
          const SizedBox(width: 8),
          Expanded(flex: 5,
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم نسخ: $label', style: const TextStyle(fontFamily: 'Cairo'))));
              },
              child: Text(value, textAlign: TextAlign.left,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
            )),
        ],
      ),
    );
  }

  Widget _videoTile(String r2Key, Map<String, dynamic> m) {
    final signedUrl = _signedUrls[r2Key];
    final sha = m['sha256_hash']?.toString() ?? '';
    final shaShort = sha.length > 10 ? '${sha.substring(0, 10)}...' : sha;

    return Card(
      elevation: 0,
      color: Colors.grey.shade100,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: signedUrl != null ? () => _openUrl(signedUrl) : null,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Video preview tile with play button
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Container(
                height: 120,
                color: Colors.black87,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        signedUrl != null ? Icons.play_circle_fill : Icons.videocam_outlined,
                        color: signedUrl != null ? const Color(0xFF5BBDB1) : Colors.grey,
                        size: 52,
                      ),
                      if (signedUrl != null) ...[
                        const SizedBox(height: 6),
                        const Text('اضغط لمشاهدة الفيديو',
                          style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Cairo')),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Color(0xFF5BBDB1)),
              title: const Text('فيديو',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo')),
              subtitle: Text('SHA-256: $shaShort',
                  style: const TextStyle(fontSize: 12, fontFamily: 'Cairo')),
              trailing: signedUrl != null
                  ? const Icon(Icons.open_in_new, size: 18, color: Color(0xFF5BBDB1))
                  : const Icon(Icons.link_off, size: 18, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('جاري التحميل...')),
        body: Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor)),
      );
    }
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('خطأ')),
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _fetchProof, child: const Text('إعادة المحاولة')),
        ])),
      );
    }

    final bool isValid = _verifyProof();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('عرض الإثبات',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Validity banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isValid ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isValid ? Colors.green : Colors.red),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        isValid ? '✔️ الإثبات صالح ولم يتم التلاعب به'
                                : '❌ تم التلاعب ببيانات الإثبات',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(isValid ? Icons.verified : Icons.warning_amber_rounded,
                        color: isValid ? Colors.green : Colors.red),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              _row('معرّف الإثبات', _currentProof.proofId),
              _row('الإصدار', _currentProof.proofVersion),
              _row('الحالة', _currentProof.status),
              const Divider(),
              _row('تاريخ الإنشاء', _currentProof.createdAt.toIso8601String()),
              _row('التوقيت الأساسي', _currentProof.timestampPrimary.toIso8601String()),
              _row('المنطقة الزمنية', _currentProof.timezone),
              const Divider(),
              _row('المعرّف', _currentProof.subjectId),
              _row('عدد العناصر', _currentProof.itemsCount.toString()),
              const Divider(),
              _row('طريقة التحقق', _currentProof.authMethod),
              _row('مستوى الثقة', _currentProof.confidenceLevel),
              _row('نوع الغرض', _currentProof.purposeType),
              _row('الأغراض', _currentProof.purposes.join(', ')),
              const Divider(),
              _row('خوارزمية الهاش', _currentProof.hashAlgorithm),
              _row('خوارزمية التوقيع', _currentProof.signatureAlgorithm),
              _row('معرّف المفتاح', _currentProof.publicKeyId),
              const Divider(),
              _row('Proof Hash', _currentProof.proofHash),
              _row('Signature', _currentProof.signature.length > 20
                  ? '${_currentProof.signature.substring(0, 20)}...'
                  : _currentProof.signature),

              // ── Media assets ──
              if (_mediaAssets.isNotEmpty) ...[
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('المرفقات والأدلة',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo')),
                ),
                ..._mediaAssets.map((m) {
                  final type = m['media_type']?.toString().toLowerCase() ?? 'file';
                  final r2Key = m['r2_key']?.toString() ?? '';
                  final signedUrl = _signedUrls[r2Key];
                  final isImage = type.contains('image');
                  final isVideo = type.contains('video');
                  final isAudio = type.contains('audio');
                  final sha = m['sha256_hash']?.toString() ?? '';
                  final shaShort = sha.length > 10 ? '${sha.substring(0, 10)}...' : sha;

                  // Video: custom tile with play button to open URL
                  if (isVideo) return _videoTile(r2Key, m);

                  IconData icon = isImage ? Icons.image
                      : isAudio ? Icons.mic
                      : Icons.insert_drive_file;

                  return Card(
                    elevation: 0,
                    color: Colors.grey.shade100,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isImage && signedUrl != null)
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            child: Image.network(signedUrl, height: 200, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                          ),
                        ListTile(
                          leading: Icon(icon, color: Theme.of(context).primaryColor),
                          title: Text(m['media_type'] ?? 'ملف',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo')),
                          subtitle: Text('SHA-256: $shaShort',
                              style: const TextStyle(fontSize: 12, fontFamily: 'Cairo')),
                          trailing: signedUrl != null
                              ? const Icon(Icons.copy, size: 18)
                              : const Icon(Icons.hourglass_empty, size: 18, color: Colors.grey),
                          onTap: signedUrl != null ? () {
                            Clipboard.setData(ClipboardData(text: signedUrl));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم نسخ الرابط المؤقت!', style: TextStyle(fontFamily: 'Cairo'))));
                          } : null,
                        ),
                      ],
                    ),
                  );
                }),
              ],

              const SizedBox(height: 24),
              Center(
                child: OutlinedButton.icon(
                  onPressed: _fetchProof,
                  icon: const Icon(Icons.refresh),
                  label: const Text('تحديث البيانات', style: TextStyle(fontFamily: 'Cairo')),
                ),
              ),

              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))],
                ),
                child: Column(children: [
                  const Text('امسح الرمز للتحقق',
                      style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 16)),
                  const SizedBox(height: 16),
                  QrImageView(
                    data: 'https://www.qrpruf.com/p/proof.html?id=${_currentProof.proofId}',
                    size: 200,
                  ),
                ]),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
