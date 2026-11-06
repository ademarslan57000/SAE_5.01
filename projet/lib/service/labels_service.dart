// Service de chargement asynchrone des classes depuis le fichier assets/labels.txt
// et mappage avec le dictionnaire d'équipements (noms conviviaux et icônes).
import 'package:flutter/services.dart' show rootBundle;
import '../modele/equipement.dart';

class LabelsService {
  // Dictionnaire de correspondance pour enrichir les classes brutes de l'IA
  static const Map<String, (String nom, String icon)> _dictionnaireEPI = {
    'helmet': ('Casque de chantier', '🪖'),
    'vest': ('Gilet haute visibilité', '🦺'),
    'gloves': ('Gants de protection', '🧤'),
    'boots': ('Chaussures de sécurité', '🥾'),
    'goggles': ('Lunettes de protection', '🥽'),
    'ears': ('Protection auditive', '🎧'),
    'person': ('Personne', '👷'),
  };

  /// Lit le fichier assets/labels.txt et retourne la liste des équipements configurés
  static Future<List<Equipement>> chargerEquipements() async {
    try {
      final String contenu = await rootBundle.loadString('assets/labels.txt');
      final List<String> lignes = contenu
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      return lignes.map((labelId) {
        final idClean = labelId.toLowerCase();
        final meta = _dictionnaireEPI[idClean];

        return Equipement(
          id: idClean,
          nom: meta?.$1 ?? labelId,
          icon: meta?.$2 ?? '🛡️',
          isRequired: idClean == 'helmet' || idClean == 'vest' || idClean == 'boots',
        );
      }).toList();
    } catch (e) {
      // Liste de secours si le fichier est introuvable
      return [
        Equipement(id: 'helmet', nom: "Casque de chantier", icon: "🪖", isRequired: true),
        Equipement(id: 'vest', nom: "Gilet haute visibilité", icon: "🦺", isRequired: true),
        Equipement(id: 'boots', nom: "Chaussures de sécurité", icon: "🥾", isRequired: true),
      ];
    }
  }
}