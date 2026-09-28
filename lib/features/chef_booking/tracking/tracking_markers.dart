import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/theme/app_colors.dart';

/// Custom map markers for live tracking, drawn at device pixel ratio so they
/// stay crisp. Sizes are logical pixels.
class TrackingMarkers {
  TrackingMarkers._();

  /// Top-down chef marker with a heading arrow. Use with `flat: true` and
  /// `rotation: bearing` so the arrow points along the direction of travel.
  static Future<BitmapDescriptor> chef(double dpr) async {
    const size = 60.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(dpr);
    const c = Offset(size / 2, size / 2);

    canvas.drawCircle(
      c.translate(0, 1.5),
      23,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(c, 22, Paint()..color = Colors.white);
    canvas.drawCircle(c, 18, Paint()..color = AppColors.primary);

    final arrow = Path()
      ..moveTo(c.dx, c.dy - 10)
      ..lineTo(c.dx + 8, c.dy + 9)
      ..lineTo(c.dx, c.dy + 4.5)
      ..lineTo(c.dx - 8, c.dy + 9)
      ..close();
    canvas.drawPath(arrow, Paint()..color = Colors.white);

    return _encode(recorder, dpr, size, size);
  }

  /// Destination pin with an optional callout bubble above it (e.g. "12 min").
  /// Anchor at (0.5, 1.0) so the pin tip sits on the address.
  static Future<BitmapDescriptor> home(double dpr, {String? label}) async {
    const pinW = 44.0, pinH = 54.0, gap = 6.0, bubbleH = 30.0;

    TextPainter? tp;
    if (label != null) {
      tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }
    final bubbleW = tp == null ? 0.0 : tp.width + 24;
    final w = math.max(pinW, bubbleW) + 8;
    final top = tp == null ? 0.0 : bubbleH + gap;
    final h = top + pinH;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(dpr);

    // Callout bubble
    if (tp != null) {
      final left = (w - bubbleW) / 2;
      final rect = RRect.fromRectAndRadius(Rect.fromLTWH(left, 0, bubbleW, bubbleH), const Radius.circular(15));
      canvas.drawRRect(rect.shift(const Offset(0, 1.5)),
          Paint()..color = Colors.black.withValues(alpha: 0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      canvas.drawRRect(rect, Paint()..color = AppColors.slate900);
      final tail = Path()
        ..moveTo(w / 2 - 6, bubbleH - 0.5)
        ..lineTo(w / 2 + 6, bubbleH - 0.5)
        ..lineTo(w / 2, bubbleH + 5)
        ..close();
      canvas.drawPath(tail, Paint()..color = AppColors.slate900);
      tp.paint(canvas, Offset((w - tp.width) / 2, (bubbleH - tp.height) / 2));
    }

    // Teardrop pin
    final cx = w / 2, cy = top + 20;
    const r = 18.0;
    final pin = Path()
      ..moveTo(cx, h)
      ..quadraticBezierTo(cx - r * 0.35, cy + r * 1.35, cx - r * 0.93, cy + r * 0.38)
      ..arcToPoint(Offset(cx + r * 0.93, cy + r * 0.38), radius: const Radius.circular(r), largeArc: true)
      ..quadraticBezierTo(cx + r * 0.35, cy + r * 1.35, cx, h)
      ..close();
    canvas.drawPath(pin.shift(const Offset(0, 1.5)),
        Paint()..color = Colors.black.withValues(alpha: 0.25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawPath(pin, Paint()..color = AppColors.accent);
    canvas.drawCircle(Offset(cx, cy), 12.5, Paint()..color = Colors.white);

    final icon = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.home_rounded.codePoint),
        style: TextStyle(
          fontSize: 17,
          fontFamily: Icons.home_rounded.fontFamily,
          package: Icons.home_rounded.fontPackage,
          color: AppColors.amber700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    icon.paint(canvas, Offset(cx - icon.width / 2, cy - icon.height / 2));

    return _encode(recorder, dpr, w, h);
  }

  static Future<BitmapDescriptor> _encode(ui.PictureRecorder recorder, double dpr, double w, double h) async {
    final image = await recorder.endRecording().toImage((w * dpr).ceil(), (h * dpr).ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), width: w, height: h);
  }
}

/// Clean map styles that keep attention on the route (hide business POIs).
class TrackingMapStyles {
  TrackingMapStyles._();

  static const light = '''
[
  {"featureType":"poi.business","stylers":[{"visibility":"off"}]},
  {"featureType":"poi","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"featureType":"landscape","elementType":"geometry","stylers":[{"color":"#f4f6f5"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#d9f0df"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#c6e3f0"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#fde8b0"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#6b7280"}]}
]''';

  static const dark = '''
[
  {"elementType":"geometry","stylers":[{"color":"#1d2330"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8b95a7"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#1d2330"}]},
  {"featureType":"poi.business","stylers":[{"visibility":"off"}]},
  {"featureType":"poi","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#1f3329"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#2c3446"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3d4760"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0f1a2b"}]}
]''';
}
