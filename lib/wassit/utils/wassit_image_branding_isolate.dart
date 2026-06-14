import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Payload envoyé à l'isolate
class WassitBrandingPayload {
  final Uint8List baseBytes;
  final Uint8List overlayPngBytes;
  final Uint8List logoPngBytes;
  final int logoTargetWidth;
  final int logoDstX;
  final int logoDstY;

  const WassitBrandingPayload({
    required this.baseBytes,
    required this.overlayPngBytes,
    required this.logoPngBytes,
    required this.logoTargetWidth,
    required this.logoDstX,
    required this.logoDstY,
  });
}

/// Isolate: applique logo + overlay, puis encode PNG
Uint8List wassitBrandImageInIsolate(WassitBrandingPayload payload) {
  img.Image? baseImage = img.decodeImage(payload.baseBytes);
  if (baseImage == null) {
    throw StateError('decodeImage failed (base)');
  }
  baseImage = img.bakeOrientation(baseImage);

  img.Image? logoImage = img.decodeImage(payload.logoPngBytes);
  if (logoImage == null) {
    throw StateError('decodeImage failed (logo)');
  }
  logoImage = img.copyResize(logoImage, width: payload.logoTargetWidth);

  img.compositeImage(
    baseImage,
    logoImage,
    dstX: payload.logoDstX,
    dstY: payload.logoDstY,
  );

  final img.Image? overlayImage = img.decodeImage(payload.overlayPngBytes);
  if (overlayImage == null) {
    throw StateError('decodeImage failed (overlay)');
  }

  img.compositeImage(
    baseImage,
    overlayImage,
    dstX: 0,
    dstY: 0,
  );

  return Uint8List.fromList(img.encodePng(baseImage));
}
