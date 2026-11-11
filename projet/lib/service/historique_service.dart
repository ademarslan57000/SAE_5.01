import 'dart:async';
import 'base_donnees.dart';
import '../modele/decision.dart';
import '../modele/equipement.dart';

class HistoriqueService {
  
  // Enregistrement d'un passage en base (transaction)
  static Future<void> enregistrerPassage(
    ResultatDecision resultat, 
    List<Equipement> equipementsRequis,
    int chantierId,
    double seuilConfiance,
    String versionModele,
    {String? cheminImage, int? utilisateurId}
  ) async {
    final db = await BaseDonnees.instance;

    await db.transaction((txn) async {
      final scanId = await txn.insert('scan', {
        'date_heure': DateTime.now().toIso8601String(),
        'chantier_id': chantierId,
        'utilisateur_id': utilisateurId, 
        'autorise': resultat.accesAutorise ? 1 : 0,
        'image_chemin': cheminImage,
        'seuil': seuilConfiance,
        'version_modele': versionModele,
      });

      for (final e in equipementsRequis) {
        final detection = resultat.detectes[e.id];
        
        await txn.insert('scan_equipement', {
          'scan_id': scanId,
          'equipement_id': e.idBase ?? 1, 
          'detecte': detection != null ? 1 : 0,
          'confiance': detection?.confidence,
        });
      }
    });
  }

  // Requête A3 : Lister l'historique des passages
  static Future<List> listerPassages() async {
    final db = await BaseDonnees.instance;

    final resultats = await db.rawQuery('''
      SELECT s.id, s.date_heure, s.autorise,
      COALESCE(u.prenom || ' ' || u.nom, 'Visiteur') AS personne,
      eq.nom AS equipe,
      GROUP_CONCAT(CASE WHEN se.detecte = 0 THEN e.nom_affiche END, ', ') AS manquants
      FROM scan s
      LEFT JOIN utilisateur u ON u.id = s.utilisateur_id
      LEFT JOIN equipe eq ON eq.id = u.equipe_id
      LEFT JOIN scan_equipement se ON se.scan_id = s.id
      LEFT JOIN equipement e ON e.id = se.equipement_id
      GROUP BY s.id
      ORDER BY s.date_heure DESC
      LIMIT 50;
    ''');

    return resultats;
  }
}