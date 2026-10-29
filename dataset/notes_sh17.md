# Notes : ajout éventuel du dataset SH17

État : **étude documentaire** à partir de l'article et du dépôt officiel. L'inspection visuelle des images reste à faire (voir « Prochaines étapes »).

## Fiche

| | |
|---|---|
| Nom | SH17 : *A Dataset for Human Safety and Personal Protective Equipment Detection in Manufacturing Industry* (Ahmad et al., 2024) |
| Contenu | 8 099 images, 75 994 boîtes, 17 classes |
| Origine des images | Pexels + environnements industriels |
| Résolution | Haute : de 1 920×1 002 à 8 192×5 462 px (prévoir un redimensionnement avant fusion) |
| Licence | CC BY-NC-SA 4.0 : usage non commercial, attribution, partage dans les mêmes conditions. Compatible avec la SAE, à citer dans le rapport |
| Téléchargement | Kaggle (images + labels), dépôt GitHub `ahmadmughees/SH17dataset` |

## Ce qui nous intéresse

SH17 contient deux des trois équipements absents de notre dataset : **le casque anti-bruit (`Earmuffs`)** et **le masque (`Face-mask-medical`)**. Il ne contient pas de harnais.

## Correspondance proposée

D'après les définitions de l'article :

| Classe SH17 | Boîtes | Définition (article) | → Notre classe | Verdict |
|---|---|---|---|---|
| Person | — | Personne | `person` | Direct |
| Helmet | 927 | Casque (couleur en attribut) | `helmet` | À vérifier : casques de chantier uniquement ? |
| Safety-vest | — | Gilet de sécurité | `vest` | Direct |
| Gloves | 2 790 | « Detection of gloves », attribut porté / non porté | `gloves` | À vérifier : l'attribut « non porté » (gant tenu à la main) est-il perdu dans l'export YOLO ? |
| Glasses | 1 945 | « Detection of safety glasses » | `goggles` | Probablement direct (lunettes de sécurité seulement), à confirmer visuellement |
| Earmuffs | 318 | « Over-Ear-Headphones are labelled as earmufs » | nouvelle classe `hearing_protection` | **Attention** : les casques audio sont inclus. Peu d'exemples, et classe difficile (mAP50 de 57,1 dans l'article) |
| Face-mask-medical | 669 | « Detection of medical face masks » | nouvelle classe `mask` | Masques chirurgicaux, pas des masques respiratoires FFP : à décider |
| Shoes | 4 560 | « slippers, sneakers, or other types of footwear » (attribut sécurité / autre) | — | **Non mappable** tel quel : baskets et chaussures de sécurité sont mélangées |
| Foot | 796 | Pied visible sans chaussure | (`no_boots` si 11 classes) | Seulement avec le schéma à 11 classes |
| Head | 11 985 | Toute vue de la tête | (base pour déduire `no_helmet`) | Seulement avec le schéma à 11 classes, via un script |
| Hands | 15 850 | Mains | (base pour déduire `no_gloves`) | Idem |
| Face, Ear, Face-guard, Tools, Medical-suit, Safety-suit | — | — | supprimées | Hors périmètre |

## Les deux pièges à régler avant toute fusion

1. **Les chaussures.** Si on retire `Shoes`, les chaussures de sécurité présentes dans SH17 deviennent du fond, alors qu'elles sont annotées `boots` dans Construction-PPE. Le modèle recevrait des signaux contradictoires, comme pour Helmet-Vest et CHV. Solutions possibles :
    - si l'export contient l'attribut « safety », ne garder que ces chaussures, mappées en `boots` ;
    - sinon, ne garder que des images SH17 où les pieds ne sont pas visibles, ou renoncer à SH17 pour les chaussures.
2. **Les nouvelles classes.** Si on ajoute `hearing_protection` et `mask`, il faut s'assurer qu'aucune image de Construction-PPE ni du dataset maison ne contient ces équipements sans annotation. Sinon, ils y seront appris comme du fond.

## Recommandation provisoire

- Prendre un **sous-ensemble de 1 500 à 2 000 images**, et non les 8 099 : sinon SH17 écraserait Construction-PPE (1 416 images).
- Prioriser les images contenant `Earmuffs`, `Face-mask-medical`, `Glasses`, `Helmet` et `Safety-vest`.
- Décider du sort de `Shoes` (piège 1) avant d'écrire le mapping.
- Attendre la décision **6 classes / 11 classes** : avec 6 classes, seules les lignes « Direct » et les deux nouvelles classes comptent. Avec 11 classes, il faut en plus un script qui déduit les classes négatives à partir de `Head`, `Hands` et `Foot`.

## Repères de performance (article)

Score global sur SH17 : YOLOv8n 58,0 de mAP50 ; YOLOv9-e 70,9.

Par classe, avec YOLOv9-e : Helmet 77,0 ; Glasses 76,4 ; Face-mask 75,5 ; Shoes 70,8 ; Gloves 66,5 ; Ear-muffs 57,1.

## Prochaines étapes

- [ ] Télécharger SH17 depuis Kaggle et regarder le format exact des labels (les attributs porté / non porté et sécurité / autre sont-ils conservés ?)
- [ ] Inspecter visuellement environ 50 images par classe : `Helmet`, `Glasses`, `Earmuffs`, `Gloves`
- [ ] Trancher le cas `Shoes`
- [ ] Écrire le mapping dans `outils/config.yaml` une fois le schéma 6 / 11 classes décidé

## Sources

- Dépôt officiel : https://github.com/ahmadmughees/SH17dataset
- Article : https://arxiv.org/pdf/2407.04590v1
