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