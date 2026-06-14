import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qrpruf/core/providers/wassit_provider.dart';
import 'package:qrpruf/core/services/proof_service.dart';
import 'package:qrpruf/features/proofs/data/models/draft.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class WassitResultPage extends ConsumerStatefulWidget {
  final String proofUrl;
  final LatLng? location;
  final List<Map<String, dynamic>> uploadQueue;
  final encrypt.Key encryptionKey;

  const WassitResultPage({
    super.key,
    required this.proofUrl,
    required this.uploadQueue,
    required this.encryptionKey,
    this.location,
  });

  @override
  ConsumerState<WassitResultPage> createState() => _WassitResultPageState();
}

class _WassitResultPageState extends ConsumerState<WassitResultPage> {
  List<String> _uploadErrors = [];
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.uploadQueue.isNotEmpty) {
      _isUploading = true;
      _startBackgroundUpload();
    }
  }

  void _clearSubmitted() {
    final submittedIds = widget.uploadQueue
        .map((item) => (item['draft'] as Draft).id)
        .toList();
    ref.read(wassitProvider.notifier).clearSubmittedDrafts(submittedIds);
  }

  Future<void> _startBackgroundUpload() async {
    setState(() { _uploadErrors = []; _isUploading = true; });

    try {
      final errors = await ProofService().processBackgroundUploadQueue(
        widget.uploadQueue,
        widget.encryptionKey,
        (current, total) {},
      );
      if (mounted) setState(() { _uploadErrors = errors; _isUploading = false; });
    } catch (e) {
      if (mounted) setState(() { _uploadErrors = [e.toString()]; _isUploading = false; });
    }
  }

  Widget _buildLocationText(BuildContext context) {
    final hasLocation = widget.location != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: hasLocation
            ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
            : Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasLocation
              ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)
              : Colors.orange.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasLocation ? Icons.location_on : Icons.location_off,
            size: 20,
            color: hasLocation ? Theme.of(context).primaryColor : Colors.orange,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              hasLocation
                  ? '${widget.location!.latitude.toStringAsFixed(5)}, ${widget.location!.longitude.toStringAsFixed(5)}'
                  : 'الموقع الجغرافي غير متاح',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                fontFamily: 'Cairo',
                color: hasLocation ? null : Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Future<void> _shareAsPdf() async {
    try {
      // 1. Render QR code to PNG bytes
      final qrPainter = QrPainter(
        data: widget.proofUrl,
        version: QrVersions.auto,
        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF000000)),
        dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF000000)),
      );
      const qrSize = 300.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      qrPainter.paint(canvas, const Size(qrSize, qrSize));
      final picture = recorder.endRecording();
      final qrImage = await picture.toImage(qrSize.toInt(), qrSize.toInt());
      final qrByteData = await qrImage.toByteData(format: ui.ImageByteFormat.png);
      final qrPngBytes = qrByteData!.buffer.asUint8List();

      // 2. Load Cairo font for Arabic text
      final fontData = await rootBundle.load('assets/fonts/cairo.ttf');
      final cairoFont = pw.Font.ttf(fontData);

      // 3. Build PDF
      final doc = pw.Document();
      final pdfQrImage = pw.MemoryImage(qrPngBytes);

      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              'QRpruf',
              style: pw.TextStyle(font: cairoFont, fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('5BBDB1')),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'توثيق رقمي موثوق',
              style: pw.TextStyle(font: cairoFont, fontSize: 15),
            ),
            pw.SizedBox(height: 30),
            pw.Center(child: pw.Image(pdfQrImage, width: 220, height: 220)),
            pw.SizedBox(height: 20),
            pw.Text(
              widget.proofUrl,
              style: pw.TextStyle(font: cairoFont, fontSize: 8),
              textAlign: pw.TextAlign.center,
            ),
            if (widget.location != null) ...[
              pw.SizedBox(height: 12),
              pw.Text(
                'الموقع: ${widget.location!.latitude.toStringAsFixed(5)}, ${widget.location!.longitude.toStringAsFixed(5)}',
                style: pw.TextStyle(font: cairoFont, fontSize: 11),
              ),
            ],
          ],
        ),
      ));

      // 4. Save to temp dir and share
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/qrpruf_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await doc.save());
      await Share.shareXFiles([XFile(file.path)], subject: 'توثيق QRpruf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إنشاء PDF: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildSyncBanner() {
    if (_isUploading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: const Row(
          children: [
            SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'جاري رفع الملفات... يرجى الانتظار قبل المغادرة',
                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'تم رفع جميع الملفات بنجاح! يمكنك الآن العودة للرئيسية.',
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'إصدار رمز QR',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF111111),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.home_rounded, color: Color(0xFF5BBDB1)),
          onPressed: () {
            _clearSubmitted();
            context.go('/selection');
          },
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE0E0E0)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 12),

              // Background Sync Banner
              if (widget.uploadQueue.isNotEmpty) ...[
                 _buildSyncBanner(),
                 const SizedBox(height: 24),
              ],

              if (_uploadErrors.isNotEmpty) ...[
                 Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                       color: Colors.red.shade50,
                       border: Border.all(color: Colors.red.shade200),
                       borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                       crossAxisAlignment: CrossAxisAlignment.stretch,
                       children: [
                          const Text(
                             'خطأ في الرفع (يرجى أخذ لقطة شاشة) :',
                             style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo'),
                          ),
                          const SizedBox(height: 8),
                          for (var err in _uploadErrors)
                             Text('- $err', style: const TextStyle(color: Colors.red, fontSize: 11, fontFamily: 'Cairo')),
                       ]
                    )
                 ),
                 const SizedBox(height: 24),
              ],

              // 📍 Plain Location Text instead of Map
              _buildLocationText(context),

              const SizedBox(height: 24),

              // QR Code Container
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: QrImageView(
                  data: widget.proofUrl,
                  size: 220,
                ),
              ),
              
              const SizedBox(height: 16),
              SelectableText(
                widget.proofUrl,
                style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: _buildActionBtn(
                      icon: Icons.picture_as_pdf_outlined,
                      label: 'مشاركة',
                      color: const Color(0xFF5BBDB1),
                      onTap: _shareAsPdf,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildActionBtn(
                      icon: Icons.copy_outlined,
                      label: 'نسخ الرابط',
                      color: const Color(0xFF4B4B4B),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: widget.proofUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم نسخ الرابط', style: TextStyle(fontFamily: 'Cairo')),
                            duration: Duration(seconds: 2),
                            backgroundColor: Color(0xFF5BBDB1),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildActionBtn(
                      icon: Icons.open_in_browser_outlined,
                      label: 'فتح القرينة',
                      color: const Color(0xFF2B7FFF),
                      onTap: () async {
                        final uri = Uri.parse(widget.proofUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Return Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _clearSubmitted();
                    context.go('/selection');
                  },
                  icon: const Icon(Icons.home),
                  label: const Text('العودة للقائمة الرئيسية'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
