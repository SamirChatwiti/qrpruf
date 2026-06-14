import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Data class to pass all necessary ingredients to the Isolate
class ProcessRequest {
  final String rawPath;
  final Uint8List logoBytes;
  final Uint8List? textOverlayBytes; // Pre-rendered text as PNG
  final int rotationAngle;
  final String outputPath;

  ProcessRequest({
    required this.rawPath,
    required this.logoBytes,
    this.textOverlayBytes,
    this.rotationAngle = 0,
    required this.outputPath,
  });
}

/// The heavy lifting function to run in Isolate
Future<String?> processImageInIsolate(ProcessRequest req) async {
  debugPrint('ISOLATE: Starting processing for ${req.rawPath}');
  try {
    // 1. Decode Image
    final bytes = await File(req.rawPath).readAsBytes();
    debugPrint('ISOLATE: File read. Bytes: ${bytes.lengthInBytes}');
    
    // Use standard image decoding (sync)
    img.Image? original = img.decodeImage(bytes);
    
    if (original == null) {
      debugPrint('ISOLATE ERROR: Failed to decode original image.');
      return null; // Failed to decode
    }
    debugPrint('ISOLATE: Decoded. ${original.width}x${original.height}');

    // 2. Decode Logo
    img.Image? logo;
    logo = img.decodeImage(req.logoBytes);
    debugPrint('ISOLATE: Logo Decoded? ${logo != null}');
  
    // 3. Decode Text Overlay
    img.Image? textOverlay;
    if (req.textOverlayBytes != null) {
      textOverlay = img.decodePng(req.textOverlayBytes!);
      debugPrint('ISOLATE: Text Overlay Decoded? ${textOverlay != null}');
    }
    
    // Handle Orientation
    original = img.bakeOrientation(original);

    // MANUAL ROTATION logic
    if (req.rotationAngle != 0) {
       debugPrint('ISOLATE: Applying Manual Rotation (${req.rotationAngle} deg).');
       original = img.copyRotate(original, angle: req.rotationAngle);
    } 

    // 4. Processing
    // a. Resize logo to ~15% of width
    if (logo != null) {
      final logoWidth = (original.width * 0.15).toInt();
      logo = img.copyResize(logo, width: logoWidth);
      
      // Composite Logo (Top Left: 40, 40)
      img.compositeImage(original, logo, dstX: 40, dstY: 40);
    }

    // b. Composite Footer (Text Overlay contains Background now)
    if (textOverlay != null) {
      // The footer is generated at width=2000. 
      // We should resize it to match the main image width to ensure it spans full width.
      
      final targetWidth = original.width;
      final scaledFooter = img.copyResize(
        textOverlay, 
        width: targetWidth,
        interpolation: img.Interpolation.linear
      );
      
      // Position at very bottom
      final footerY = original.height - scaledFooter.height;
      debugPrint('ISOLATE: Compositing footer at y=$footerY');
      img.compositeImage(original, scaledFooter, dstX: 0, dstY: footerY);
    }

    // 5. Save
    debugPrint('ISOLATE: Encoding JPEG to ${req.outputPath}...');
    final encoded = img.encodeJpg(original, quality: 90);
    
    final f = File(req.outputPath);
    await f.writeAsBytes(encoded);
    debugPrint('ISOLATE: Saved successfully.');
    
    return req.outputPath;

  } catch (e, stack) {
    debugPrint('ISOLATE EXCEPTION: $e');
    debugPrint(stack.toString());
    return null;
  }
}
