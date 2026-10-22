// Structure de données encapsulant une prédiction du modèle d'inférence :
// identifiant de classe reconnue, indice de confiance statistique et coordonnées spatiales du rectangle.

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