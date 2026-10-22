// Calque transparent utilisant un CustomPainter pour projeter les boîtes englobantes (bounding boxes)
// et les étiquettes de score sur l'écran en convertissant les coordonnées normalisées du modèle en pixels.

import 'package:flutter/material.dart';
import '../../modele/detection.dart';

class DetectionOverlay extends StatelessWidget {
  final List<Detection> detections;
  final Set<String> idsRequis;

  const DetectionOverlay({
    super.key,
    required this.detections,
    required this.idsRequis,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DetectionPainter(
        detections: detections,
        idsRequis: idsRequis,
      ),
      child: Container(),
    );
  }
}

class _DetectionPainter extends CustomPainter {
  final List<Detection> detections;
  final Set<String> idsRequis;

  _DetectionPainter({
    required this.detections,
    required this.idsRequis,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final det in detections) {
      final bool estRequis = idsRequis.contains(det.idEquipement);
      final Color boxColor = estRequis ? Colors.greenAccent : Colors.lightBlueAccent;
      final Rect rect = Rect.fromLTWH(
        det.boundingBox.left * size.width,
        det.boundingBox.top * size.height,
        det.boundingBox.width * size.width,
        det.boundingBox.height * size.height,
      );

      final Paint boxPaint = Paint()
        ..color = boxColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        boxPaint,
      );

      final int pourcentage = (det.confidence * 100).round();
      final TextSpan span = TextSpan(
        text: ' ${det.label} ($pourcentage%) ',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      );

      final TextPainter tp = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
      )..layout();

      final Rect labelBgRect = Rect.fromLTWH(
        rect.left,
        (rect.top - tp.height - 4).clamp(0.0, size.height),
        tp.width + 6,
        tp.height + 4,
      );

      final Paint bgPaint = Paint()
        ..color = boxColor
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(labelBgRect, const Radius.circular(4)),
        bgPaint,
      );
      tp.paint(
        canvas,
        Offset(labelBgRect.left + 3, labelBgRect.top + 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DetectionPainter oldDelegate) {
    return oldDelegate.detections != detections ||
        oldDelegate.idsRequis != idsRequis;
  }
}