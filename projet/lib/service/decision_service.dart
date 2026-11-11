//fonctions de décision : à partir des détections du modèle et des EPI
//obligatoires, détermine si l'accès est autorisé ou refusé.

import '../modele/decision.dart';
import '../modele/detection.dart';
import '../modele/equipement.dart';

const double seuilConfiance = 0.6;

//ne garde que les détections assez fiables. Si un même équipement est
//détecté plusieurs fois, on garde celle qui a la meilleure confiance.
Map<String, Detection> detectionsValides(
  List<Detection> detections, {
  double seuil = seuilConfiance,
}) {
  final Map<String, Detection> retenues = {};
  for (final d in detections) {
    if (d.confidence < seuil) continue;
    final existante = retenues[d.idEquipement];
    if (existante == null || d.confidence > existante.confidence) {
      retenues[d.idEquipement] = d;
    }
  }
  return retenues;
}

//compare les détections retenues aux équipements obligatoires.
ResultatDecision decider(
  List<Detection> detections,
  List<Equipement> equipementsRequis, {
  double seuil = seuilConfiance,
}) {
  final retenues = detectionsValides(detections, seuil: seuil);
  final manquants =
      equipementsRequis.where((e) => !retenues.containsKey(e.id)).toList();
  return ResultatDecision(detectes: retenues, manquants: manquants);
}

class StabilisateurDecision {
  final int maxFrames;
  final int minConfirmations;
  
  //historique des détections retenues pour les dernières frames
  final buffer = [];

  //par défaut : on analyse sur 5 images, il faut que l'EPI soit vu sur au moins 3 d'entre elles.
  StabilisateurDecision({this.maxFrames = 5, this.minConfirmations = 3});

  ResultatDecision deciderStable(
    List<Detection> detections,
    List<Equipement> equipementsRequis, {
    double seuil = seuilConfiance,
  }) {
    //filtrer les détections de la frame actuelle
    final retenues = detectionsValides(detections, seuil: seuil);

    //mettre à jour le buffer (ajouter la nouvelle, supprimer la plus ancienne)
    buffer.add(retenues);
    if (buffer.length > maxFrames) {
      buffer.removeAt(0);
    }

    //calculer le consensus sur l'ensemble du buffer
    Map<String, Detection> detectesStables = {};
    
    for (var equipement in equipementsRequis) {
      int apparitions = 0;
      Detection? derniereDetection;

      for (var frame in buffer) {
        if (frame.containsKey(equipement.id)) {
          apparitions++;
          derniereDetection = frame[equipement.id]; //on garde la dernière
        }
      }

      //si l'EPI est apparu suffisamment de fois dans les dernières frames, on le valide
      if (apparitions >= minConfirmations && derniereDetection != null) {
        detectesStables[equipement.id] = derniereDetection;
      }
    }

    //déduire ce qui manque réellement (de manière stable)
    final manquants = equipementsRequis
        .where((e) => !detectesStables.containsKey(e.id))
        .toList();

    return ResultatDecision(detectes: detectesStables, manquants: manquants);
  }
}