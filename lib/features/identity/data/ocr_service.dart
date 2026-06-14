import 'dart:io';
import 'dart:math' as math;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class OcrService {
  static final OcrService _instance = OcrService._internal();
  factory OcrService() => _instance;
  OcrService._internal();

  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  
  Future<Map<String, String>> processImage(XFile imageFile) async {
    final inputImage = InputImage.fromFilePath(imageFile.path);
    return processInputImage(inputImage);
  }

  Future<Map<String, String>> processInputImage(InputImage inputImage) async {
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
    return _extractMoroccanIdData(recognizedText.text);
  }

  Future<String> recognizeText(InputImage inputImage) async {
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
    return recognizedText.text;
  }

  Future<RecognizedText> recognizeTextFull(InputImage inputImage) async {
    return await _textRecognizer.processImage(inputImage);
  }

  CardDetectionResult detectCard(RecognizedText recognizedText, int imageWidth, int imageHeight) {
    final text = recognizedText.text;
    if (text.isEmpty || recognizedText.blocks.isEmpty) {
      return CardDetectionResult(detected: false, reason: 'لا يوجد نص', confidence: 0);
    }

    final upperText = text.toUpperCase();
    double confidence = 0;
    List<String> signals = [];

    // Signal 1: Keywords
    final moroccanKeywords = [
      'CARTE', 'NATIONALE', 'MAROC', 'ROYAUME', 'KINGDOM',
      'VALIDE', 'DATE', 'ADRESSE', 'CIN', 'NOM', 'PRENOM',
    ];
    int keywordCount = 0;
    for (final kw in moroccanKeywords) {
      if (upperText.contains(kw)) keywordCount++;
    }
    if (keywordCount >= 3) {
      confidence += 0.4;
      signals.add('$keywordCount mots-clés');
    } else if (keywordCount >= 1) {
      confidence += 0.15;
      signals.add('$keywordCount mot-clé');
    }

    // Signal 2: CIN pattern
    final hasIDPattern = RegExp(r'[A-Z]{1,2}\s*[0-9]{4,8}').hasMatch(upperText);
    if (hasIDPattern) {
      confidence += 0.25;
      signals.add('CIN détecté');
    }

    // Signal 3: Spatial
    double minX = double.infinity, minY = double.infinity;
    double maxX = 0, maxY = 0;
    for (final block in recognizedText.blocks) {
      for (final corner in block.cornerPoints) {
        minX = math.min(minX, corner.x.toDouble());
        minY = math.min(minY, corner.y.toDouble());
        maxX = math.max(maxX, corner.x.toDouble());
        maxY = math.max(maxY, corner.y.toDouble());
      }
    }
    
    final textWidth = maxX - minX;
    final textHeight = maxY - minY;
    
    if (textWidth > 0 && textHeight > 0) {
      final aspectRatio = textWidth / textHeight;
      if (aspectRatio > 1.2 && aspectRatio < 2.2) {
        confidence += 0.15;
        signals.add('ratio ${aspectRatio.toStringAsFixed(1)}');
      }
      
      final areaCoverage = (textWidth * textHeight) / (imageWidth * imageHeight);
      if (areaCoverage > 0.08 && areaCoverage < 0.85) {
        confidence += 0.1;
        signals.add('couverture ${(areaCoverage * 100).toStringAsFixed(0)}%');
      }
    }

    final detected = confidence >= 0.45;
    return CardDetectionResult(
      detected: detected,
      reason: signals.join(' | '),
      confidence: confidence,
      textBounds: detected ? _Rect(minX, minY, maxX, maxY) : null,
    );
  }

  bool isCardInFrame(String text) {
    if (text.isEmpty) return false;
    final upperText = text.toUpperCase();
    final hasIDPattern = RegExp(r'[A-Z]{1,2}\s*[0-9]{4,8}').hasMatch(upperText);
    final hasKeywords = upperText.contains('CARTE') || upperText.contains('NATIONALE') || upperText.contains('MAROC');
    final isDense = upperText.split('\n').length >= 2;
    return hasIDPattern || (hasKeywords && isDense);
  }

  Future<String> cropCardFromImage(String imagePath) async {
    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    img.Image? original = img.decodeImage(bytes);
    if (original == null) return imagePath;

    original = img.bakeOrientation(original);
    final int imgW = original.width;
    final int imgH = original.height;

    int cropW = (imgW * 0.90).round();
    int cropH = (cropW / 1.58).round();

    if (imgW > imgH) {
      cropH = (imgH * 0.90).round();
      cropW = (cropH * 1.58).round();
    }

    int cropX = (imgW - cropW) ~/ 2;
    int cropY = (imgH - cropH) ~/ 2 - (imgH * 0.02).round();

    if (cropX < 0) cropX = 0;
    if (cropY < 0) cropY = 0;
    if (cropX + cropW > imgW) cropW = imgW - cropX;
    if (cropY + cropH > imgH) cropH = imgH - cropY;

    final cropped = img.copyCrop(original, x: cropX, y: cropY, width: cropW, height: cropH);
    final String croppedPath = imagePath.replaceAll(RegExp(r'\.(jpg|jpeg|png)$', caseSensitive: false), '') + '_card.jpg';
    
    final croppedFile = File(croppedPath);
    await croppedFile.writeAsBytes(img.encodeJpg(cropped, quality: 92));
    return croppedPath;
  }

  Map<String, String> _extractMoroccanIdData(String rawText) {
    final String upperRaw = rawText.toUpperCase();
    final String normalizedText = _normalizeText(upperRaw);
    final List<String> lines = normalizedText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    final Map<String, String> extractedData = {
      'idNum': '',
      'firstName': '',
      'lastName': '',
      'address': '',
      'birthDate': '',
      'expiryDate': '',
      'rawText': upperRaw,
    };

    final idRegex = RegExp(r'([A-Z]{1,2})\s*([0-9]{4,8})');
    final dateRegex = RegExp(r'(\d{2})[\.\/\-\s](\d{2})[\.\/\-\s](\d{4})');

    // 1. MRZ ALGORITHM (BACK)
    for (final line in lines) {
      final cleanLine = line.replaceAll(' ', '');
      if (cleanLine.contains('<<')) {
        if (cleanLine.contains('MAR') && cleanLine.length > 15) {
          final cinMatch = RegExp(r'([A-Z]{1,2}[0-9]{4,8})<{2,}').firstMatch(cleanLine);
          if (cinMatch != null) extractedData['idNum'] = cinMatch.group(1)!;
        } else if (RegExp(r'([0-9]{6})[0-9][A-Z<]([0-9]{6})').hasMatch(cleanLine)) {
            final dateMatch = RegExp(r'([0-9]{6})[0-9][A-Z<]([0-9]{6})').firstMatch(cleanLine);
            if (dateMatch != null) {
               final b = dateMatch.group(1)!;
               extractedData['birthDate'] = '${b.substring(4,6)}/${b.substring(2,4)}/${int.parse(b.substring(0,2)) + (int.parse(b.substring(0,2)) > 25 ? 1900 : 2000)}';
               final e = dateMatch.group(2)!;
               extractedData['expiryDate'] = '${e.substring(4,6)}/${e.substring(2,4)}/${int.parse(e.substring(0,2)) + 2000}';
            }
        } else if (RegExp(r'([A-Z0-9]+)<<([A-Z0-9]+)').hasMatch(cleanLine)) {
            final n = RegExp(r'([A-Z0-9]+)<<([A-Z0-9]+)').firstMatch(cleanLine);
            if (n != null && !n.group(1)!.contains('MAR')) {
               extractedData['lastName'] = n.group(1)!;
               extractedData['firstName'] = n.group(2)!;
            }
        }
      }
    }

    // 2. RECTO (FRONT) REFINED
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (extractedData['idNum']!.isEmpty) {
        final m = idRegex.firstMatch(line);
        if (m != null) extractedData['idNum'] = m.group(0)!.replaceAll(' ', '');
      }
      if (line.contains('NOM') || line.contains('النسب') || line.contains('FAMILLE')) {
        String v = _cleanLine(line, ['NOM', 'النسب', 'FAMILLE', 'FAMILY', 'NAME', ':', 'DE', 'LA']);
        if (v.length > 2) extractedData['lastName'] = v;
      } 
      if (line.contains('PRENOM') || line.contains('PHOTO') || line.contains('الإاسم') || line.contains('FIRST NAME')) {
        String v = _cleanLine(line, ['PRENOM', 'PRÉNOM', 'الإاسم', 'اسم', 'FIRST', 'NAME', ':', 'AUTRE', 'PHOTO']);
        if (v.length > 2) extractedData['firstName'] = v;
      }

      final dMatch = dateRegex.firstMatch(line);
      if (dMatch != null) {
        final d = dMatch.group(0)!.replaceAll('.', '/').replaceAll('-', '/');
        if (line.contains('NE LE') || line.contains('NAISS') || line.contains('ولادة') || line.contains('BIRTH')) {
          extractedData['birthDate'] = d;
        } else if (line.contains('VALABLE') || line.contains('صلاحية') || line.contains('EXP') || line.contains('JUSQU')) {
          extractedData['expiryDate'] = d;
        } else {
          String ctx = (i > 0 ? lines[i-1] : "") + (i < lines.length - 1 ? lines[i+1] : "");
          if (ctx.contains('NE LE') || ctx.contains('NAISS')) extractedData['birthDate'] = d;
          else if (ctx.contains('VALABLE') || ctx.contains('JUSQU')) extractedData['expiryDate'] = d;
        }
      }

      if (line.contains('ADRESSE') || line.contains('العنوان') || line.contains('DEMEURE')) {
        String addr = _cleanLine(line, ['ADRESSE', 'العنوان', 'DEMEURE', 'RESIDENCE', ':']);
        int j = i + 1;
        while (j < lines.length && j < i + 3) {
          if (idRegex.hasMatch(lines[j]) || lines[j].contains('VALABLE') || lines[j].length < 3) break;
          addr += ' ${lines[j]}'; j++;
        }
        if (extractedData['address']!.isEmpty) extractedData['address'] = addr.trim();
      }
    }

    // Heuristic fallback for dates
    if (extractedData['birthDate']!.isEmpty || extractedData['expiryDate']!.isEmpty) {
      List<String> dates = [];
      for (var l in lines) {
        final m = dateRegex.firstMatch(l);
        if (m != null) dates.add(m.group(0)!.replaceAll('.', '/'));
      }
      if (dates.length >= 2) {
        dates.sort((a,b) => int.parse(a.split('/').last).compareTo(int.parse(b.split('/').last)));
        if (extractedData['birthDate']!.isEmpty) extractedData['birthDate'] = dates.first;
        if (extractedData['expiryDate']!.isEmpty) extractedData['expiryDate'] = dates.last;
      }
    }

    return extractedData;
  }

  String _normalizeText(String text) {
    return text.toUpperCase()
      .replaceAll('É', 'E').replaceAll('È', 'E').replaceAll('Ê', 'E')
      .replaceAll('À', 'A').replaceAll('Â', 'A')
      .replaceAll('Î', 'I').replaceAll('Ï', 'I')
      .replaceAll('Ô', 'O').replaceAll('Û', 'U');
  }

  String _cleanLine(String line, List<String> keywords) {
    String v = line;
    for (var k in keywords) { v = v.replaceAll(k, ''); }
    v = v.replaceAll(RegExp(r'[^\x00-\x7F]'), '').trim();
    v = v.replaceAll(RegExp(r'[^a-zA-Z\s0-9,\./]'), '').trim();
    if (v.startsWith('.') || v.startsWith('/') || v.startsWith(':')) v = v.substring(1).trim();
    return v;
  }

  void dispose() {
    _textRecognizer.close();
  }
}

class CardDetectionResult {
  final bool detected;
  final String reason;
  final double confidence;
  final _Rect? textBounds;
  CardDetectionResult({required this.detected, required this.reason, required this.confidence, this.textBounds});
}

class _Rect {
  final double left, top, right, bottom;
  _Rect(this.left, this.top, this.right, this.bottom);
}
