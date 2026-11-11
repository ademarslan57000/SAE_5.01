import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class BaseDonnees {
  static Database? _db;

  static Future<Database> get instance async {
    if (_db != null) return _db!;
    _db = await _initDB('portique.db');
    return _db!;
  }

  static Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
    );
  }

  static Future _onConfigure(Database db) async {
    //Activation des clés étrangères pour que ON DELETE CASCADE fonctionne
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future _onCreate(Database db, int version) async {
    //QUI : l'entreprise, ses chantiers, ses équipes, ses personnes
    await db.execute('''
      CREATE TABLE entreprise (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE TABLE chantier (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entreprise_id INTEGER NOT NULL REFERENCES entreprise(id),
        nom TEXT NOT NULL,
        actif INTEGER NOT NULL DEFAULT 1
      )
    ''');
    
    await db.execute('''
      CREATE TABLE equipe (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chantier_id INTEGER NOT NULL REFERENCES chantier(id),
        nom TEXT NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE TABLE utilisateur (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        prenom TEXT NOT NULL,
        role TEXT NOT NULL CHECK (role IN ('ouvrier', 'admin')),
        equipe_id INTEGER REFERENCES equipe(id),
        pin_hash TEXT,
        actif INTEGER NOT NULL DEFAULT 1
      )
    ''');

    //QUOI : les EPI, et ceux qui sont obligatoires sur chaque chantier
    await db.execute('''
      CREATE TABLE equipement (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code_classe TEXT NOT NULL UNIQUE,
        nom_affiche TEXT NOT NULL,
        icone TEXT,
        personnalise INTEGER NOT NULL DEFAULT 0,
        detectable INTEGER NOT NULL DEFAULT 1
      )
    ''');
    
    await db.execute('''
      CREATE TABLE chantier_equipement (
        chantier_id INTEGER NOT NULL REFERENCES chantier(id),
        equipement_id INTEGER NOT NULL REFERENCES equipement(id),
        PRIMARY KEY (chantier_id, equipement_id)
      )
    ''');

    //L'HISTORIQUE : un passage, puis une ligne par EPI obligatoire
    await db.execute('''
      CREATE TABLE scan (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date_heure TEXT NOT NULL,
        chantier_id INTEGER NOT NULL REFERENCES chantier (id),
        utilisateur_id INTEGER REFERENCES utilisateur (id),
        autorise INTEGER NOT NULL,
        image_chemin TEXT,
        seuil REAL NOT NULL,
        version_modele TEXT NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE TABLE scan_equipement (
        scan_id INTEGER NOT NULL REFERENCES scan (id) ON DELETE CASCADE,
        equipement_id INTEGER NOT NULL REFERENCES equipement(id),
        detecte INTEGER NOT NULL,
        confiance REAL,
        PRIMARY KEY (scan_id, equipement_id)
      )
    ''');

    //LA PERSONNALISATION (A6, A7)
    await db.execute('''
      CREATE TABLE photo_capture (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        equipement_id INTEGER NOT NULL REFERENCES equipement(id),
        chemin TEXT NOT NULL,
        date_heure TEXT NOT NULL,
        exportee INTEGER NOT NULL DEFAULT 0
      )
    ''');
    
    await db.execute('''
      CREATE TABLE modele (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        version TEXT NOT NULL,
        fichier_tflite TEXT NOT NULL,
        fichier_labels TEXT NOT NULL,
        date_installation TEXT NOT NULL,
        actif INTEGER NOT NULL DEFAULT 0
      )
    ''');

    //Données de départ, insérées au premier lancement
    await db.insert('entreprise', {'nom': 'BTP Démo'});
    await db.insert('chantier', {'entreprise_id': 1, 'nom': 'Chantier IUT Metz'});
    
    //Insertion des équipements de base
    final equipementsBase = [
      {'code_classe': 'helmet', 'nom_affiche': 'Casque de chantier', 'icone': '🪖'},
      {'code_classe': 'vest', 'nom_affiche': 'Gilet haute visibilité', 'icone': '🦺'},
      {'code_classe': 'gloves', 'nom_affiche': 'Gants de protection', 'icone': '🧤'},
      {'code_classe': 'boots', 'nom_affiche': 'Chaussures de sécurité', 'icone': '🥾'},
      {'code_classe': 'goggles', 'nom_affiche': 'Lunettes de protection', 'icone': '🥽'},
    ];
    
    for (var eq in equipementsBase) {
      await db.insert('equipement', eq);
    }
  }
}