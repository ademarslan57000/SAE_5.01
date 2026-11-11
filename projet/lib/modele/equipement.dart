// Modèle de données décrivant un équipement de protection (identifiant, libellé, icône)
// et son statut obligatoire ou optionnel paramétré par le responsable.

class Equipement {
  final String id;
  final int? idBase;
  final String nom;
  final String icon;
  bool isRequired;

  Equipement({
    required this.id,
    required this.nom,
    this.idBase,
    required this.icon,
    this.isRequired = false,
  });
}