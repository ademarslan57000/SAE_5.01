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
