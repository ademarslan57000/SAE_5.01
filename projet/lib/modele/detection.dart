import 'dart:ui';

class Detection {
  final String idEquipement;
  final String label;
  final double confidence;
  final Rect boundingBox;

  Detection({
    required this.idEquipement,
    required this.label,
    required this.confidence,
    required this.boundingBox,
  });
}