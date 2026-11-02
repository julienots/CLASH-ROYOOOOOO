# CARDVERSE : Ultimate TCG Collection

Jeu mobile de cartes à collectionner en **portrait** (Godot 4.3). Il propose 149 cartes originales en 3 sets (Genèse, Éclipse, Âge Primitif) réparties sur 17 raretés, dont Primitif et SWAP, une rareté à reconstituer avec des pièces de puzzle,, des boosters spectaculaires, un album complet, des combats stratégiques contre l'IA, un Atelier d'évolutions, un passe de saison, des missions et un événement.

📄 Architecture, direction artistique et feuille de route : [ARCHITECTURE.md](ARCHITECTURE.md)

## 📲 Installer sur Android

1. Télécharge **[`dist/Cardverse.apk`](../dist/Cardverse.apk)** (sur GitHub : *Download raw file*).
2. Ouvre le fichier et autorise l'installation depuis des « sources inconnues » si Android le demande.
3. Lance **Cardverse**. Android 7.0 minimum, processeur ARM 32 ou 64 bits.

> L'APK est signé avec une clé de développement. Si une future version est signée avec une autre clé, il faudra désinstaller l'ancienne avant d'installer la nouvelle.

## 🎮 Comment jouer

- **Accueil** : récompense quotidienne, ta carte la plus précieuse, accès rapide aux boosters, aux combats, aux missions et à l'événement.
- **Boutique → Boosters** : touche le prix (ou GRATUIT), fais tourner le paquet, **glisse le doigt le long du haut** pour le déchirer, puis touche chaque carte pour la retourner. Le bouton **i** affiche les probabilités exactes.
- **Boutique → Displays** : achète une caisse de boosters et ouvre-les un par un (Légendaire garanti). Les **Coffrets** contiennent une carte promo exclusive, des boosters et des jetons.
- **Album** : filtre par élément (icônes), rareté ou famille ; recherche, tri, favoris, comparaison, recyclage des doublons, récompenses de collection. Touche une carte pour l'inspecter et incline-la du doigt.
- **Combat** : touche une carte de ta main pour l'agrandir, puis **JOUER** (choisis une cible si besoin). Touche une de tes créatures prêtes (contour vert), puis une cible ennemie pour attaquer. Les créatures avec **Garde** doivent être attaquées en premier. Un élément favorable inflige des dégâts x1,5. Le pouvoir du leader coûte 2 énergie.
- **Atelier** (accueil) : fais évoluer tes créatures (3 exemplaires et de la Poussière d'étoile), découvre les transformations secrètes, crée des cartes ou applique des variantes.
- **Passe** (accueil) : 30 paliers de récompenses gagnés en jouant, voie Élite débloquable avec des Cristaux.
- **Decks** : choisis ton leader, ajoute ou retire des cartes (20 exactement) ou utilise *Remplir auto*.

## 🛠️ Développement

| Commande (depuis `cardverse/`) | Rôle |
|---|---|
| `godot --path .` | Lancer le jeu (ouvrir le dossier dans Godot 4.3, rendu *Compatibility*) |
| `godot --headless --path . -- --logic-test` | Tests de logique : données, 4000 boosters, 200 combats IA contre IA |
| `godot --path . -- --shots=/dossier:home,collection,battle_select,battle_auto` | Captures d'écran automatiques, partie jouée automatiquement |
| `python3 tools/art/gen_cards.py [ids] [--force] [--sheet planche.jpg]` | (Re)générer les illustrations depuis les recettes JSON |
| `python3 tools/art/gen_ui.py` | Cadres de rareté, dos de carte, boosters, icônes |
| `python3 tools/gen_audio.py` | Effets sonores et musiques (synthèse) |
| `tools/build_apk.sh` | Export Android et signature v2, résultat dans `dist/Cardverse.apk` |

### Ajouter une carte
Ajoute une entrée dans `data/cards/<set>.json` :

```json
{"id": "f010", "name": "Nom unique", "type": "creature", "family": "dragons", "element": "feu", "rarity": "E",
 "cost": 5, "atk": 5, "hp": 4, "keywords": ["celerite"],
 "effects": [{"on": "summon", "do": "damage", "target": "random_enemy", "value": 2}],
 "lore": "Une phrase d'histoire.",
 "art": {"arch": "quadruped", "wings": true, "horns": "back", "c1": [200, 60, 30]}}
```

Lance ensuite `python3 tools/art/gen_cards.py f010`. Le texte de la carte est généré à partir des effets. Pour une illustration dessinée à la main, remplace `assets/cards/f010.png` (450x630 pixels).

## Crédits
Code, données, illustrations pixel art, cadres, icônes, sons et musiques : créés pour le projet, à l'aide des outils de `tools/`. Polices **Cinzel**, **Cinzel Decorative**, **Exo 2** et **Lilita One** : licence SIL Open Font License (`assets/fonts/OFL.txt`).
