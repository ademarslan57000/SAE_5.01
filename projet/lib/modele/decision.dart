  //résultat d'une décision d'accès : équipements détectés et manquants.

import 'detection.dart';
import 'equipement.dart';

class ResultatDecision {
  //détections retenues (confiance suffisante), indexées par id d'équipement.
  final Map<String, Detection> detectes;

  //équipements obligatoires qui n'ont pas été détectés.
  final List<Equipement> manquants;

  const ResultatDecision({
    required this.detectes,
    required this.manquants,
  });

  bool get accesAutorise => manquants.isEmpty;
}

