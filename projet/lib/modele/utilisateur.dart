class Utilisateur {
  final int id;
  final String nom;
  final String prenom;
  final String role; // 'ouvrier' ou 'admin'
  final String pin; // Mot de passe / PIN

  Utilisateur({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.role,
    required this.pin,
  });

  factory Utilisateur.fromMap(Map<String, dynamic> map) {
    return Utilisateur(
      id: map['id'],
      nom: map['nom'],
      prenom: map['prenom'],
      role: map['role'],
      pin: map['pin_hash'] ?? '0000',
    );
  }

  String get nomComplet => '$prenom $nom';
}
