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

| Carte | Coût | Attaque |
|---|---|---|
| Lame Spectrale | 3 | Assassin rapide, première frappe x2 |
| Golem de Basalte | 6 | Tank anti-bâtiments, se brise en 2 Éclats |
| Archères Sylvaines | 3 | Duo d'archères, air et sol |
| Pyromancien | 5 | Boules de feu en zone |
| Nuée de Scarabées | 2 | Essaim de 6 |
| Titan de l'Orage | 7 | Foudre en chaîne sur 3 cibles |
| Gardienne d'Airain | 4 | Chevalière avec bouclier |
| Sapeur Fou | 2 | Kamikaze explosif |
| Chevaucheur de Drake | 5 | Volant, souffle de feu |
| Totem Arcanique | 4 | Bâtiment, rayon d'essence |
| Météore | 4 | Sort : rocher en fusion |
| Nova de Givre | 3 | Sort : dégâts + gel |

## 🏝️ Îles

Île des Brumes (0 🏆) → Île de Braise (300) → Île Givrée (700) → Île Céleste (1200)

## Développement

- Ouvre le dossier `godot/` dans **Godot 4.3** (rendu *Compatibility*).
- `godot/scripts/data.gd` : stats des cartes, îles, sauvegarde
- `godot/scripts/models.gd` : modèles 3D et animations des unités
- `godot/scripts/battle.gd` : moteur de combat, IA, HUD
- `godot/scripts/main.gd` : menus, boutique, écrans
- `tools/build-apk.sh` : exporte l'APK (nécessite les export templates Android de Godot 4.3)
- Captures automatiques : `godot --path godot -- --shots=/dossier`
