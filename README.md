# Clash of Things

**Un jeu SuperEssence Studio, fait avec Godot 4.3.**

Jeu de cartes et de stratégie en temps réel en 3D : déploie tes unités, défends tes tours et détruis la Tour Cœur adverse avant la fin du chrono.

## 📲 Installer sur Android

1. Télécharge **[`dist/ClashOfThings.apk`](dist/ClashOfThings.apk)** sur ton téléphone (*Download raw file* sur GitHub).
2. Ouvre-le et autorise l'installation depuis des « sources inconnues » si Android le demande.
3. Lance **Clash of Things** 🎮

## 🎬 Animations

- Intro : la caméra plonge du ciel sur l'arène, compte à rebours « 3, 2, 1, COMBAT ! »
- Déploiement : les unités tombent du ciel, s'écrasent (squash & stretch) et soulèvent de la poussière ; le Golem fait trembler l'écran
- Combat : anticipation + frappe, flash blanc et rebond à l'impact, chiffres de dégâts, flèches en arc, boules de feu avec traînée, foudre en chaîne, rayons, explosions avec débris, cratères, gel des unités
- Mort : l'unité s'écrase et son âme s'envole
- Tours : tremblement à chaque coup, effondrement avec débris + ralenti, la couronne s'envole vers le score, réveil de la Tour Cœur
- Interface : cartes qui glissent depuis « Suivante », boutons élastiques, onglets qui glissent, écran VS, ouverture de coffre, écran de victoire avec couronnes une par une et compteurs animés

## 🃏 Cartes

| Carte | Coût | Modèle | Attaque |
|---|---|---|---|
| Lame Spectrale | 3 | Voleuse encapuchonnée, 2 dagues | Assassin rapide, première frappe x2 |
| Colosse Barbare | 6 | Barbare géant, hache à 2 mains | Vise les bâtiments, libère 2 Barbares enragés à sa mort |
| Arbalétrières | 3 | 2 voleuses à l'arbalète | Tir à distance, air et sol |
| Pyromancien | 5 | Mage au bâton | Boules de feu en zone |
| Horde de Squelettes | 2 | 6 squelettes qui sortent du sol | Essaim au corps à corps |
| Liche de l'Orage | 7 | Mage squelette géant | Foudre en chaîne sur 3 cibles |
| Chevalier d'Airain | 4 | Chevalier épée + bouclier | Bouclier de 450 PV |
| Sapeur Squelette | 2 | Squelette avec tonneau de poudre | Kamikaze explosif |
| Chevaucheur de Drake | 5 | Dragon (modèle maison) | Volant, souffle de feu |
| Totem Arcanique | 4 | Obélisque (modèle maison) | Bâtiment, rayon d'essence |
| Météore | 4 | Sort | Rocher en fusion |
| Nova de Givre | 3 | Sort | Dégâts + gel |

## 🏝️ Îles

Île des Brumes (0 🏆) → Île de Braise (300) → Île Givrée (700) → Île Céleste (1200)

## 🎨 Crédits des modèles 3D

Personnages, armes et décors animés : **KayKit** par Kay Lousberg ([kaylousberg.com](https://www.kaylousberg.com)) — licence **CC0** (domaine public, usage commercial autorisé).
Packs utilisés : Adventurers Character Pack, Character Pack Skeletons, Dungeon Remastered. Voir `godot/assets/models/LICENSE_KAYKIT.txt`.

## Développement

- Ouvre le dossier `godot/` dans **Godot 4.3** (rendu *Compatibility*).
- `godot/scripts/data.gd` : stats des cartes, îles, sauvegarde
- `godot/scripts/real.gd` : vrais modèles animés (KayKit) et leurs animations
- `godot/scripts/models.gd` : tours, arène, modèles maison (drake, totem, sorts)
- `godot/scripts/battle.gd` : moteur de combat, IA, HUD
- `godot/scripts/main.gd` : menus, boutique, écrans
- `tools/build-apk.sh` : exporte l'APK (nécessite les export templates Android de Godot 4.3)
- Captures automatiques : `godot --path godot -- --shots=/dossier`
