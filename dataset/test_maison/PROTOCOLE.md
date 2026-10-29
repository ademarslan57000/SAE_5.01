# Protocole du jeu de test maison (`test_maison/`)

## Objectif

Vérifier que le modèle fonctionne sur de vraies personnes, dans les conditions de la démonstration (une personne face au téléphone, en intérieur), et pas seulement sur les images d'internet de Construction-PPE.

Ce jeu de test sert à deux évaluations :

1. **Détection** : scores par classe avec `yolo val` (boîtes annotées).
2. **Décision d'accès** : pour chaque photo, l'application doit donner le bon verdict (autorisé / refusé) et la bonne liste d'équipements manquants (fichier `verite_terrain.csv`).

## Règle absolue

Ces photos ne servent **jamais** à l'entraînement, ni en train ni en val. Elles ne passent pas par `merge_datasets.py`. Sinon le modèle les aurait déjà vues et le score serait faussé.

## Matériel

- Un téléphone, appareil photo réglé en **JPG** (sur iPhone : Réglages > Appareil photo > Formats > « Le plus compatible »), orientation portrait.
- Les EPI disponibles : casque de chantier, gilet haute visibilité, gants de travail, lunettes de protection, chaussures de sécurité.
- Les objets « pièges » : casquette ou bonnet, lunettes de vue ou de soleil, gants ordinaires (laine, ménage), baskets.

## Prises de vue

Chaque membre (4 personnes) passe les 10 scénarios, puis on fait 4 photos de groupe : environ **44 photos**.

| # | Scénario | Cadrage | Ce que ça teste |
|---|---|---|---|
| S1 | Sans aucun EPI, de face | Plein pied, ~3 m | Fausses détections (gilet ou lunettes « vus » alors qu'absents) |
| S2 | Sans aucun EPI, de profil ou de trois quarts | Plein pied, ~3 m | Idem, sous un autre angle |
| S3 | Tenue complète disponible, de face | Plein pied, ~3 m | Détection de tous les EPI, cas « accès autorisé » |
| S4 | Tenue complète, de trois quarts | Plein pied, ~2 m | Idem, sous un autre angle |
| S5 | Tenue complète sauf le casque | Buste, ~1,5 m | Un seul manque : le casque |
| S6 | Tenue complète sauf le gilet | Plein pied, ~3 m | Un seul manque : le gilet |
| S7 | Piège tête : casquette ou bonnet | Buste, ~1,5 m | Confusion casque / couvre-chef |
| S8 | Piège yeux : lunettes de vue ou de soleil | Buste, ~1 m | Confusion lunettes de protection / ordinaires |
| S9 | Piège mains : gants ordinaires, mains bien visibles | Buste, ~1 m | Confusion gants de travail / ordinaires |
| S10 | Piège pieds : baskets, pieds visibles | Plein pied, ~3 m | Confusion chaussures de sécurité / baskets |
| G1–G4 | Deux personnes : une équipée, l'autre non | Plein pied, ~3 m | Plusieurs personnes dans l'image |

Variations à répartir entre les personnes, sans multiplier les photos :

- **Lumière** : la moitié près d'une fenêtre (lumière forte), l'autre moitié en lumière faible ou artificielle.
- **Fond** : au moins deux décors différents (salle, couloir, extérieur).

Si un EPI n'est pas disponible, on saute le scénario correspondant et on le note dans `verite_terrain.csv`.

## Règles de cadrage

- Pour les scénarios plein pied, la personne doit être visible **de la tête aux pieds**. Sinon les chaussures ne peuvent pas être évaluées.
- La personne regarde globalement vers le téléphone, comme devant le portique.
- Pas de flou de bougé, pas de filtre, pas de zoom numérique.
- Uniquement des membres de l'équipe sur les photos, avec leur accord. Pas de personne extérieure, même en arrière-plan.

## Nommage des fichiers

`tm_<prenom>_<scenario>.jpg`, par exemple `tm_chouaib_S7.jpg` ou `tm_groupe_G2.jpg`.

## Annotation (Label Studio, export YOLO)

- **Classes** : celles du schéma retenu après la comparaison 6 classes / 11 classes, dans le **même ordre** que le `data.yaml` du modèle évalué.
- **Mêmes règles de boîtes que Construction-PPE** :
    - `person` : toute la personne visible ;
    - `helmet` : le casque seul ;
    - `vest` : le gilet sur le torse ;
    - `gloves` : chaque main gantée ;
    - `boots` : chaque chaussure de sécurité ;
    - `goggles` : les lunettes de protection.
- **Annoter toutes les occurrences visibles**, même partiellement cachées.
- Les objets pièges (casquette, lunettes de vue, gants ordinaires, baskets) ne sont **pas** annotés comme EPI. Avec le schéma à 11 classes, ils sont annotés avec la classe négative correspondante (`no_helmet`, `no_goggle`, etc.).

Structure :

```
dataset/test_maison/
├── images/val/       ← les photos (split "val" pour que yolo val fonctionne)
├── labels/val/       ← les annotations YOLO
├── data.yaml         ← chemins relatifs, mêmes classes que le modèle évalué
├── verite_terrain.csv
└── PROTOCOLE.md
```

## Vérité terrain pour la décision d'accès (`verite_terrain.csv`)

Une ligne par personne et par photo :

```csv
fichier,personne,casque,gilet,gants,lunettes,chaussures,remarque
tm_chouaib_S5.jpg,chouaib,non,oui,oui,oui,oui,
tm_chouaib_S7.jpg,chouaib,non,non,non,non,non,casquette
```

Ce fichier permet de vérifier la chaîne complète (modèle, logique de décision, verdict) pour une configuration admin donnée, par exemple « casque + gilet obligatoires ».

## Évaluation

1. **Détection** :
   ```python
   YOLO("best.pt").val(data="dataset/test_maison/data.yaml")
   ```
   On relève le mAP50, la précision et le rappel par classe.
2. **Décision** : pour chaque photo, on compare le verdict de l'application à `verite_terrain.csv`. On compte les **faux accès** (accès autorisé alors qu'un EPI obligatoire manque, l'erreur la plus grave) et les **faux refus**.
3. **Captures** : on garde 3 à 5 exemples d'erreurs typiques pour le rapport (partie « limites »).

## Checklist le jour J

- [ ] Appareil en JPG, portrait
- [ ] EPI et objets pièges réunis
- [ ] 10 scénarios × 4 personnes + 4 photos de groupe
- [ ] Fichiers renommés selon la convention
- [ ] `verite_terrain.csv` rempli sur place, pendant la séance
- [ ] Annotation dans Label Studio et export YOLO
- [ ] Vérification : une image = un fichier de labels, aucune photo présente dans `dataset/`
