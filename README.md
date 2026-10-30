# Essence Arena

**Un jeu SuperEssence Studio.**

Jeu de cartes et de stratégie en temps réel en 3D : déploie tes unités, défends tes tours et détruis la Tour Cœur adverse avant la fin du chrono.

## 📲 Installer sur Android

1. Télécharge **[`dist/EssenceArena.apk`](dist/EssenceArena.apk)** sur ton téléphone (bouton *Download raw file* sur GitHub).
2. Ouvre le fichier et autorise l'installation d'« applications de sources inconnues » si Android le demande.
3. Lance **Essence Arena** 🎮

À chaque push, l'APK est aussi reconstruit par GitHub Actions (onglet *Actions* → artefact `EssenceArena-apk`).

## 🃏 Les cartes

| Carte | Coût | Type | Attaque |
|---|---|---|---|
| Lame Spectrale | 3 | Unité | Assassin rapide, première frappe x2 |
| Golem de Basalte | 6 | Unité | Tank qui vise les bâtiments, se brise en 2 Éclats |
| Archères Sylvaines | 3 | Unité x2 | Flèches à distance, air et sol |
| Pyromancien | 5 | Unité | Boules de feu explosives |
| Nuée de Scarabées | 2 | Unité x6 | Essaim au corps à corps |
| Titan de l'Orage | 7 | Unité | Foudre en chaîne sur 3 cibles |
| Gardienne d'Airain | 4 | Unité | Chevalière avec bouclier |
| Sapeur Fou | 2 | Unité | Kamikaze explosif contre les bâtiments |
| Chevaucheur de Drake | 5 | Unité volante | Souffle de feu en zone |
| Totem Arcanique | 4 | Bâtiment | Rayon d'essence, dure 30 s |
| Météore | 4 | Sort | Rocher en fusion, gros dégâts de zone |
| Nova de Givre | 3 | Sort | Dégâts + gel de 3 s |

## 🏝️ Les îles

Île des Brumes (0 🏆) → Île de Braise (300 🏆) → Île Givrée (700 🏆) → Île Céleste (1200 🏆)

## Contenu du jeu

- Combat 3D temps réel contre une IA, 3 min + prolongation, essence x2 la dernière minute
- Modèles 3D animés pour chaque unité, tours et arènes, effets de particules, sons
- Deck de 8 cartes, collection, amélioration des cartes avec l'or (niveaux 1 à 9)
- Boutique (coffres, or, gemmes), route des îles, trophées, sauvegarde automatique

## Développement

```bash
npm install
npm run build              # génère www/game.js
npx esbuild --servedir=www # ou ouvre simplement www/index.html
./scripts/build-apk.sh     # construit dist/EssenceArena.apk
```

Code source : `src/` (Three.js). `src/cards.js` contient toutes les stats des cartes, `src/models.js` les modèles 3D, `src/battle.js` le moteur de combat.
