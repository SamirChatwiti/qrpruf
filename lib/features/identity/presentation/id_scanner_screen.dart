import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart'; // Needed for XFile used in OCR processing
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/ocr_service.dart';
import 'package:go_router/go_router.dart';

class IdScannerScreen extends ConsumerStatefulWidget {
  final bool isOnboarding;
  const IdScannerScreen({super.key, this.isOnboarding = true});

  @override
  ConsumerState<IdScannerScreen> createState() => _IdScannerScreenState();
}

enum ScannerPhase { intro, initializing, processing, review, error }

class _IdScannerScreenState extends ConsumerState<IdScannerScreen> {
  ScannerPhase _phase = ScannerPhase.intro;
  String? _frontPath;
  String? _backPath;
  String? _errorMessage;

  final Map<String, String> _extractedData = {
    'idNum': '',
    'firstName': '',
    'lastName': '',
    'address': '',
    'birthDate': '',
    'expiryDate': '',
  };

  final OcrService _ocrService = OcrService();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Do not launch scanner on startup, wait for user in intro phase
  }

  Future<void> _startDocumentScanner({bool? targetFront}) async {
    setState(() {
      _phase = ScannerPhase.initializing;
      _errorMessage = null;
    });
    
    try {
      final options = DocumentScannerOptions(
        documentFormats: {DocumentFormat.jpeg},
        mode: ScannerMode.full,
        pageLimit: (targetFront == null) ? 2 : 1,
        isGalleryImport: true,
      );

      final documentScanner = DocumentScanner(options: options);
      final DocumentScanningResult result = await documentScanner.scanDocument();

      final List<String> imagesPaths = result.images ?? [];
      
      if (imagesPaths.isEmpty) {
        if (_frontPath == null) {
           if (mounted) Navigator.pop(context);
        } else {
           if (mounted) setState(() => _phase = ScannerPhase.review);
        }
        return;
      }

      setState(() => _phase = ScannerPhase.processing);

      if (targetFront == true) {
        _frontPath = imagesPaths[0];
      } else if (targetFront == false) {
        _backPath = imagesPaths[0];
      } else {
        _frontPath = imagesPaths[0];
        if (imagesPaths.length >= 2) {
          _backPath = imagesPaths[1];
        }
      }

      // Process Front Side
      if (targetFront == true || targetFront == null) {
        if (_frontPath != null) {
          final dataFront = await _ocrService.processImage(XFile(_frontPath!));
          dataFront.forEach((key, value) {
            if (value.isNotEmpty) _extractedData[key] = value;
          });
        }
      }

      // Process Back Side
      if (targetFront == false || targetFront == null) {
        if (_backPath != null) {
          final dataBack = await _ocrService.processImage(XFile(_backPath!));
          dataBack.forEach((key, value) {
            if (value.isNotEmpty) _extractedData[key] = value;
          });
        }
      }

      // Validate CIN only on the initial two-sided scan
      if (targetFront == null && !_isValidCinScan()) {
        if (mounted) {
          setState(() {
            _phase = ScannerPhase.error;
            _errorMessage = 'لم يتم التعرف على بطاقة وطنية مغربية صالحة.\nيرجى التأكد من مسح بطاقة التعريف الوطنية (CIN) فقط.';
          });
        }
        return;
      }

      if (mounted) {
        setState(() => _phase = ScannerPhase.review);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = ScannerPhase.error;
          _errorMessage = e.toString();
        });
      }
    }
  }

  bool _isValidCinScan() {
    final idNum = (_extractedData['idNum'] ?? '').trim();
    final rawText = (_extractedData['rawText'] ?? '').toUpperCase();

    final hasCinNumber = RegExp(r'^[A-Z]{1,2}[0-9]{4,8}$').hasMatch(idNum);

    // Identifiants propres au Maroc — doivent figurer sur toute CIN marocaine
    final hasMoroccoId = rawText.contains('MAROC') ||
        rawText.contains('ROYAUME') ||
        rawText.contains('KINGDOM OF MOROCCO');

    // Mots-clés secondaires de la carte
    const cardKeywords = ['NATIONALE', 'CARTE', 'VALABLE', 'NE LE', 'ADRESSE'];
    final cardKeywordCount = cardKeywords.where((k) => rawText.contains(k)).length;

    // Cas principal : identifiant Maroc + numéro CIN
    if (hasMoroccoId && hasCinNumber) return true;
    // Carte partiellement illisible : identifiant Maroc + 2 mots-clés carte
    if (hasMoroccoId && cardKeywordCount >= 2) return true;
    // Dernier recours : carte très abîmée (pas de "MAROC" lisible)
    return hasCinNumber && cardKeywordCount >= 3;
  }

  Future<void> _saveAndFinish() async {
    if (_frontPath == null || _backPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى مسح الوجه والخلف معاً قبل المتابعة', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate required fields
    const requiredFields = {
      'رقم البطاقة (CIN)': 'idNum',
      'الاسم الشخصي': 'firstName',
      'الاسم العائلي': 'lastName',
      'تاريخ الازدياد': 'birthDate',
    };
    final missing = requiredFields.entries
        .where((e) => (_extractedData[e.value] ?? '').trim().isEmpty)
        .map((e) => e.key)
        .toList();
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'يرجى ملء الحقول التالية: ${missing.join('، ')}',
          textAlign: TextAlign.right,
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // Validate CIN format: 1-2 uppercase letters + 4-8 digits
    final cinValue = (_extractedData['idNum'] ?? '').trim();
    if (!RegExp(r'^[A-Z]{1,2}[0-9]{4,8}$').hasMatch(cinValue)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('رقم البطاقة غير صالح. يجب أن يكون أحرفاً وأرقاماً (مثال: AB123456)',
          textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // Validate names: letters and spaces only, at least 2 non-space characters
    final namePattern = RegExp(r'^[A-Za-z\s\-]+$');
    final fnVal = (_extractedData['firstName'] ?? '').trim();
    final lnVal = (_extractedData['lastName'] ?? '').trim();
    if (!namePattern.hasMatch(fnVal) || fnVal.replaceAll(' ', '').length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('الاسم الشخصي يبدو غير صحيح. يرجى تصحيحه يدوياً',
          textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: Colors.red,
      ));
      return;
    }
    if (!namePattern.hasMatch(lnVal) || lnVal.replaceAll(' ', '').length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('الاسم العائلي يبدو غير صحيح. يرجى تصحيحه يدوياً',
          textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // Validate birth date format (DD/MM/YYYY or DD.MM.YYYY or DD-MM-YYYY)
    final bdVal = (_extractedData['birthDate'] ?? '').trim();
    if (!RegExp(r'^\d{1,2}[\/\.\-]\d{1,2}[\/\.\-]\d{4}$').hasMatch(bdVal)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تنسيق تاريخ الازدياد غير صحيح. يجب أن يكون: يوم/شهر/سنة (مثال: 15/03/1990)',
          textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final firstName = _extractedData['firstName'] ?? '';
      final lastName = _extractedData['lastName'] ?? '';
      final cin = _extractedData['idNum'] ?? '';
      final birthDate = _extractedData['birthDate'] ?? '';

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            'first_name': firstName,
            'last_name': lastName,
            'full_name': '$firstName $lastName',
            'cin': cin,
            'birth_date': birthDate,
            'identity_verified': true,
          },
        ),
      );

      if (!mounted) return;
      if (widget.isOnboarding) {
        context.go('/phone-validation');
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Save error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _skip() async {
    setState(() => _isSaving = true);
    
    // Afficher immédiatement pour prouver que le bouton marche
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('جارٍ التخطي...', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: Colors.blueAccent,
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: {'identity_skip': true}),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تحذير: لم نتمكن من حفظ إعداد التخطي', style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
        if (widget.isOnboarding) {
          context.go('/phone-validation');
        } else {
          Navigator.pop(context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == ScannerPhase.review) return _buildReviewScreen();
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('مسح البطاقة (جديد)', style: TextStyle(color: Colors.black, fontFamily: 'Cairo')),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _skip,
            child: const Text('تخطي', style: TextStyle(color: Color(0xFF5BBDB1), fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Center(
        child: _buildStateContent(),
      ),
    );
  }

  Widget _buildStateContent() {
    if (_phase == ScannerPhase.intro) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.badge_outlined, size: 80, color: Color(0xFF5BBDB1)),
            const SizedBox(height: 24),
            const Text(
              'توثيق الهوية (اختياري)',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
            ),
            const SizedBox(height: 16),
            const Text(
              'يرجى مسح بطاقتك الوطنية لتأمين حسابك والاستفادة من كافة الخدمات.\nيمكنك تخطي هذه الخطوة حالياً باستخدام زر "تخطي" بالأعلى.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontFamily: 'Cairo', color: Colors.grey, height: 1.5),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => _startDocumentScanner(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5BBDB1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(1024)),
                ),
                child: const Text('ابدأ المسح الآن', style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
    }

    if (_phase == ScannerPhase.error) {
      String displayError = _errorMessage ?? 'حدث خطأ غير معروف';
      if (displayError.contains('Operation cancelled')) {
        displayError = 'تم إلغاء عملية المسح. يرجى المحاولة مرة أخرى.';
      }

      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, color: Colors.red, size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              'عذراً، حدث خطأ',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
            ),
            const SizedBox(height: 12),
            Text(
              displayError,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontFamily: 'Cairo', height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              height: 50,
              child: ElevatedButton(
                onPressed: () => _startDocumentScanner(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5BBDB1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('إعادة المحاولة', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
    }
    
    if (_phase == ScannerPhase.processing) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF5BBDB1)),
          const SizedBox(height: 24),
          const Text('جاري استخراج البيانات من البطاقة...', style: TextStyle(fontSize: 16, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('يرجى الانتظار قليلاً', style: TextStyle(color: Colors.grey.shade600, fontFamily: 'Cairo')),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.badge_outlined, size: 80, color: Color(0xFF5BBDB1)),
        const SizedBox(height: 24),
        const Text(
          'يرجى مسح وجهي البطاقة (الأمامي والخلفي)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'قم بتصوير الوجه أولاً ثم الظهر لضمان استخراج كافة المعلومات القانونية.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontFamily: 'Cairo', color: Colors.grey),
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => _startDocumentScanner(),
          style: ElevatedButton.styleFrom(
             backgroundColor: const Color(0xFF5BBDB1),
             padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(1024)),
          ),
          child: const Text('بدء المسح', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildReviewScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('تأكيد المعلومات', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => setState(() {
            _phase = ScannerPhase.intro;
            _frontPath = null;
            _backPath = null;
            _extractedData.updateAll((_, __) => '');
          }),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الصور الملتقطة:', style: TextStyle(fontSize: 14, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _frontPath != null
                      ? _buildImagePreviewWithRetake('الوجه', _frontPath!, true)
                      : _buildMissingSideButton('مسح الوجه', true),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _backPath != null
                      ? _buildImagePreviewWithRetake('الظهر', _backPath!, false)
                      : _buildMissingSideButton('مسح الظهر', false),
                ),
              ],
            ),
            const SizedBox(height: 30),
            const Text('البيانات المستخرجة:', style: TextStyle(fontSize: 14, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildEditField('رقم البطاقة (CIN)', 'idNum', readOnly: true),
            _buildEditField('الاسم الشخصي', 'firstName'),
            _buildEditField('الاسم العائلي', 'lastName'),
            _buildEditField('تاريخ الازدياد', 'birthDate'),
            _buildEditField('تاريخ انتهاء الصلاحية', 'expiryDate'),
            _buildEditField('العنوان', 'address'),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveAndFinish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5BBDB1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSaving 
                   ? const CircularProgressIndicator(color: Colors.white)
                   : const Text('تأكيد وحفظ البيانات', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: _isSaving ? null : _skip,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF5BBDB1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('تخطي للمرحلة القادمة', style: TextStyle(color: Color(0xFF5BBDB1), fontSize: 16, fontFamily: 'Cairo')),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreviewWithRetake(String label, String path, bool isFront) {
    return Column(
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(path), height: 120, width: double.infinity, fit: BoxFit.contain),
            ),
            Positioned(
              right: 4,
              top: 4,
              child: GestureDetector(
                onTap: () => _startDocumentScanner(targetFront: isFront),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.refresh, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, fontFamily: 'Cairo', color: Colors.grey)),
      ],
    );
  }

  Widget _buildMissingSideButton(String label, bool isFront) {
    return GestureDetector(
      onTap: () => _startDocumentScanner(targetFront: isFront),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo_outlined, color: Color(0xFF5BBDB1)),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, fontFamily: 'Cairo', color: Color(0xFF5BBDB1), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildEditField(String label, String key, {bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo', color: Colors.blueGrey)),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: _extractedData[key],
            onChanged: (val) => _extractedData[key] = val,
            readOnly: readOnly,
            style: TextStyle(fontSize: 15, color: readOnly ? Colors.grey : Colors.black87, fontWeight: readOnly ? FontWeight.w300 : FontWeight.normal),
            decoration: InputDecoration(
              filled: true,
              fillColor: readOnly ? Colors.grey.shade50 : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
