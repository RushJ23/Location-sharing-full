import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Creates a person-pin marker icon at [sizeLogicalPixels] for use on the map.
/// Larger sizes make the pin easier to see when zoomed out.
Future<BitmapDescriptor> createPersonMarkerIcon(int sizeLogicalPixels) async {
  final pictureRecorder = ui.PictureRecorder();
  final canvas = Canvas(pictureRecorder);
  final size = sizeLogicalPixels.toDouble();

  // Pin circle background (teal/primary)
  final paint = Paint()
    ..color = const Color(0xFF00897B)
    ..style = PaintingStyle.fill;
  canvas.drawCircle(
    Offset(size / 2, size / 2),
    size / 2 - 2,
    paint,
  );
  // Border
  final borderPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  canvas.drawCircle(
    Offset(size / 2, size / 2),
    size / 2 - 2,
    borderPaint,
  );
  // Person icon (simplified: circle for head + arc for body)
  final iconPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;
  final centerX = size / 2;
  final centerY = size / 2;
  canvas.drawCircle(Offset(centerX, centerY - 2), size * 0.12, iconPaint);
  canvas.drawArc(
    Rect.fromCenter(
      center: Offset(centerX, centerY + 4),
      width: size * 0.5,
      height: size * 0.4,
    ),
    0,
    3.14159,
    true,
    iconPaint,
  );

  final picture = pictureRecorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = byteData!.buffer.asUint8List();
  return BitmapDescriptor.fromBytes(bytes);
}
