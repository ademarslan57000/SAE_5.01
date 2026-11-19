import 'base_donnees.dart';
import '../modele/utilisateur.dart';

import 'package:flutter/foundation.dart';

class AuthService {
  static Utilisateur? utilisateurCourant;
  static Future<List<Utilisateur>> getComptes() async {
    final db = await BaseDonnees.instance;

    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS utilisateur (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nom TEXT NOT NULL,
          prenom TEXT NOT NULL,
          role TEXT NOT NULL,
          equipe_id INTEGER,
          pin_hash TEXT,
          actif INTEGER NOT NULL DEFAULT 1
        )
      ''');

      var res = await db.query('utilisateur', where: 'actif = 1');

      if (res.isEmpty) {
        await db.insert('utilisateur', {
          'nom': 'Admin',
          'prenom': 'Super',
          'role': 'admin',
          'pin_hash': '1234',
          'actif': 1,
        });
        await db.insert('utilisateur', {
          'nom': 'Dupont',
          'prenom': 'Jean',
          'role': 'ouvrier',
          'pin_hash': '0000',
          'actif': 1,
        });
        res = await db.query('utilisateur', where: 'actif = 1');
      }

      return res.map((m) => Utilisateur.fromMap(m)).toList();
    } catch (e) {
      debugPrint("Erreur BDD : $e");
      return [
        Utilisateur(
          id: 1,
          nom: 'Admin',
          prenom: 'Super',
          role: 'admin',
          pin: '1234',
        ),
      ];
    }
  }

  /// Retourne l'utilisateur actif du rôle donné correspondant au prénom, au nom
  /// (sans tenir compte de la casse ni des espaces autour) et au PIN, sinon null.
  static Future<Utilisateur?> connecterParIdentite({
    required String prenom,
    required String nom,
    required String pin,
    required String role,
  }) async {
    String norm(String t) => t.trim().toLowerCase();
    final comptes = await getComptes();
    for (final c in comptes) {
      if (c.role == role &&
          norm(c.prenom) == norm(prenom) &&
          norm(c.nom) == norm(nom) &&
          c.pin == pin) {
        return c;
      }
    }
    return null;
  }

  static Future<void> inscrireUtilisateur({
    required String nom,
    required String prenom,
    required String role,
    required String pin,
  }) async {
    final db = await BaseDonnees.instance;
    await db.insert('utilisateur', {
      'nom': nom.trim(),
      'prenom': prenom.trim(),
      'role': role, // 'ouvrier' ou 'admin'
      'pin_hash': pin,
      'actif': 1,
    });
  }
}
