# CARDVERSE : architecture, direction artistique et plan de réalisation

Ce document répond à l'**étape 1** du cahier des charges : architecture complète, technologies, fonctionnement du jeu et direction artistique. Il sert aussi de référence pour les étapes suivantes. L'état réel de chaque fonctionnalité figure dans la section 9 ; rien n'y est annoncé comme terminé sans l'être.

---

## 1. Vision

Un jeu de cartes à collectionner mobile en **portrait**, construit autour de trois boucles :

1. **Collectionner** : ouvrir des boosters spectaculaires, découvrir des raretés de plus en plus folles, compléter l'album.
2. **Combattre** : des duels 1 contre 1 courts (environ 8 tours par joueur), lisibles, mais avec de la profondeur (éléments, mots-clés, évolutions, pouvoirs de leader).
3. **Progresser** : niveau de compte, missions, succès, événements, récompenses de collection.

Chaque boucle alimente les autres. Les combats rapportent des monnaies, les monnaies achètent des boosters, et les boosters renforcent les decks.

## 2. Choix technologique : Godot 4.3

| Critère | Godot 4.3 (retenu) | Phaser 3 / PWA |
|---|---|---|
| APK Android natif | Export direct, sans WebView | Nécessite Capacitor/TWA + WebView |
| Effets visuels | Shaders GPU (holo, faille cosmique, perspective 3D), particules | WebGL possible, mais plus de code maison |
| Performance mobile | Moteur natif, rendu *Compatibility* (OpenGL ES 3) adapté aux téléphones modestes | Dépend du navigateur et de la WebView |
| Interface riche | Système de Controls complet (conteneurs, scroll, thèmes, polices variables) | À construire soi-même |
| Cohérence du dépôt | Le dépôt utilise déjà Godot 4.3 (*Clash of Things*) | Nouvelle chaîne d'outils |
| Multijoueur futur | Client HTTP/WebSocket intégré, SDK Nakama disponible | Équivalent |

**Conclusion** : Godot donne un vrai jeu natif, des effets GPU de qualité et une seule base de code. Le rendu *GL Compatibility* maximise la compatibilité Android.

## 3. Architecture du projet

```
cardverse/
├── project.godot / export_presets.cfg     # portrait 720x1280, rendu Compatibility, export Android
├── data/                                  # CONTENU : indépendant du code
│   ├── cards/genesis.json                 # set 1 (64 cartes + jetons) — un fichier = un set
│   ├── rarities.json                      # 15 raretés, poids, variantes, pity
│   ├── elements.json                      # 10 éléments + avantages, 13 familles, mots-clés
│   ├── boosters.json                      # 7 boosters (prix, focus, chance)
│   ├── leaders.json                       # 4 leaders + pouvoirs
│   ├── progression.json                   # niveaux, missions, succès, calendrier, récompenses
│   ├── events.json                        # événements datés (monnaie, boss, booster)
│   └── card_layout.json                   # gabarit des cadres (généré)
├── scripts/
│   ├── autoload/  db.gd · profile.gd · sfx.gd       # données, sauvegarde/économie, audio
│   ├── logic/     booster_logic.gd · battle_engine.gd · battle_ai.gd   # règles PURES (sans affichage)
│   ├── ui/        ui.gd · card_view.gd · card_detail.gd · booster_open.gd · battle_view.gd · unit_view.gd
│   ├── screens/   home · collection · shop · battle_select · decks · missions · profile · events · settings
│   ├── tests/     logic_test.gd · shots.gd     # tests de logique, captures et partie automatique
│   └── main.gd                                 # coquille : barre, navigation, superpositions, retour Android
├── shaders/       card_fx · art_fx · tilt · menu_bg · rift · flash
├── assets/        cards/ (illustrations) · ui/ (cadres, boosters, icônes) · audio/ · fonts/ · icon.png
└── tools/         art/ (générateurs d'illustrations et d'interface) · gen_audio.py · sign_apk.py · build_apk.sh
```

**Principes :**

- **Données d'abord** : une carte se résume à une entrée JSON (statistiques, mots-clés, effets déclaratifs, lore, recette d'illustration). Les textes des capacités sont **générés à partir des effets**, ce qui garantit que l'affichage et les règles ne divergent jamais.
- **Règles séparées de l'affichage** : `BattleEngine` ne connaît pas l'interface. Chaque action produit une liste d'**événements** (`summon`, `attack`, `damage`, `evolve`, `death`…) que `battle_view.gd` anime un par un. Le même moteur pourra tourner **côté serveur** pour le multijoueur, et il est testé sans écran (200 parties IA contre IA).
- **Effets déclaratifs** : `{"on": "summon|death|turn_start|attack|cast", "do": "damage|heal|buff|freeze|draw|summon|shield|destroy|add_random", "target": "...", "value": n}`. On ajoute des cartes sans écrire de code. Un nouveau type d'effet demande une seule fonction dans le moteur.
- **Sauvegarde** : `user://cardverse_save.json`, versionnée, avec migration des clés manquantes et nettoyage des cartes retirées du catalogue. Sauvegarde à chaque achat ou ouverture, et quand l'application passe en arrière-plan.

## 4. Direction artistique

### Identité
**« Pixel art haut de gamme » rehaussé d'effets modernes.** Les illustrations sont en pixel art (grille 150x210, palette limitée par carte, tramage ordonné, contour d'un pixel). Les effets sont rendus en temps réel par shaders : reflets holographiques, scintillements, faille cosmique, auras, perspective 3D au doigt. Ce contraste entre une illustration artisanale et des effets lumineux premium fait la signature du jeu.

- **Typographie** : *Cinzel Decorative* pour le logo (gravure antique), *Cinzel* pour les noms de cartes, *Exo 2* pour l'interface et *Lilita One* pour les chiffres (lisibles en petit).
- **Fond** : une nébuleuse animée par shader, dont les couleurs changent selon le contexte (booster, plateau de combat, événement).
- **Interface** : panneaux sombres translucides, liserés violets, boutons en relief avec rebond élastique et son, badges de notification.

### Univers visuels par élément
| Élément | Décor | Palette |
|---|---|---|
| Feu | Volcan, rivière de lave | rouges, ambre |
| Eau | Profondeurs, rayons, algues | bleus, cyan |
| Terre | Canyons stratifiés | ocres, bruns |
| Foudre | Ciel d'orage, éclairs | jaune électrique, indigo |
| Glace | Toundra, aurore boréale | blancs bleutés |
| Nature | Forêt de conifères, lucioles | verts, jaune-vert |
| Ombre | Lune, arbres morts | violets profonds |
| Lumière | Temple, colonnes, rayons divins | or, crème |
| Cosmique | Nébuleuse, planète à anneau | magenta, indigo |
| Néant | Vide, faille lumineuse | noir, vert spectral |

Les hautes raretés reçoivent des rayons et des particules dans l'illustration, et certaines ont un décor dédié (*sanctuaire* doré, *abysses*).

### Hiérarchie des 15 raretés
| # | Rareté | Cadre | Effet animé (shader) | Révélation |
|---|---|---|---|---|
| 1 | Commune | Pierre | — | Retournement simple |
| 2 | Inhabituelle | Bronze vert | — | Retournement simple |
| 3 | Rare | Acier bleu | Reflet balayant | Lueur d'anticipation, carillon |
| 4 | Super Rare | Argent | Reflet balayant | Lueur, carillon |
| 5 | Épique | Améthyste | Holographique | Tremblement, flash coloré |
| 6 | Légendaire | Or | Holographique | Tremblement, flash, arpège |
| 7 | Mythique | Pourpre et or | Holo + scintillements, aura de particules | **Faille cosmique**, chœur |
| 8 | Antique | Jade runique | Holo + scintillements | Faille cosmique |
| 9 | Divine | Blanc et or | Holo + scintillements | Faille cosmique |
| 10 | Céleste | Bleu céleste étoilé | Cosmique (étoiles, nébuleuse) | Faille cosmique |
| 11 | Cosmique | Violet nébuleuse | Cosmique | Faille cosmique |
| 12 | Transcendante | Nacre irisée | Cosmique | Faille cosmique |
| 13 | Absolue | Obsidienne et or | Cosmique | Faille cosmique |
| 14 | Originelle | Blanc pur prismatique | Cosmique, **numérotée** (tirage de 500) | Faille cosmique |
| 15 | ??? | Glitch noir et blanc | Illustration glitchée (décalages RGB), numérotée | Faille cosmique |
| + | **Primitif** (entre Antique et Divine) | Os sculpté et ambre | Runes d'ambre pulsantes sur le cadre | Faille cosmique |
| + | **SWAP** (spéciale) | Coutures de puzzle irisées | Coutures arc-en-ciel animées | Jamais tirée : se reconstitue avec 9 pièces de puzzle |

**Variantes** (indépendantes de la rareté) : Holographique, Full Art (illustration plein cadre), Alternate Art (teinte alternative), Chromatique (couleurs saturées décalées et scintillements), Animée (illustration ondulante), Prismatique (arc-en-ciel intense), Secret Art (plein cadre et dorure). Les cartes Originelles et ??? sont **numérotées**.

## 5. Pipeline de production des illustrations

Produire à la main plus de 2000 illustrations uniques n'est pas réaliste dans un prototype. Recycler la même image l'est encore moins. Le projet utilise donc une **chaîne de production structurée** :

1. Chaque carte possède une **recette d'illustration** dans son JSON : archétype anatomique (quadrupède, serpent, bipède, oiseau, méduse, kraken, crabe, plante, insecte, orbe, esprit, gueule cosmique, œuf, larve, composition de sort), paramètres de silhouette (cou, ailes, cornes, têtes, taille des pattes, posture…), palette, décor et options.
2. `tools/art/gen_cards.py` peint la créature en vectoriel supersamplé (ombrage volumétrique, contours, lumière de bord, lueurs émissives), puis la convertit en pixel art. Un cache par carte (`.hash`) ne régénère que les recettes modifiées.
3. **Remplacement progressif** : une illustration dessinée à la main remplace simplement `assets/cards/<id>.png`, sans toucher au code. Le format est fixe (450x630 pixels, fenêtre d'illustration décrite dans `card_layout.json`).

Pour atteindre **2000+ cartes**, la mémoire et la taille de l'APK deviennent le sujet principal :
- l'APK embarque les sets de base, et les sets suivants sont téléchargés à la demande (paquets `.pck` par set, servis par CDN, versionnés) ;
- les illustrations sont chargées à la demande, avec cache LRU, et l'album pagine ses cartes au lieu de toutes les instancier ;
- les PNG indexés (64 couleurs) pèsent environ 25 Ko par carte, soit environ 50 Mo pour 2000 cartes, d'où le téléchargement par set.

## 6. Systèmes de jeu

### Boosters
- 5 cartes, dont la 5e est Rare ou mieux. Les probabilités par rareté sont calculées à partir des poids de `rarities.json`, ajustées par la « chance » du booster. Elles sont **affichées en jeu** (bouton i) et vérifiées par les tests (somme = 100 %).
- **Focus thématique** : les boosters Draconique, Abyssal, Cosmique, Divin et d'événement multiplient le poids des cartes de leur élément ou famille.
- **Protection anti-malchance** : chances accrues de Légendaire+ dès le 25e booster consécutif sans en obtenir, Légendaire+ **garanti** au 40e, Mythique+ garanti au 120e. Compteurs visibles dans la boutique.
- Le tirage est fait **avant** l'animation et sauvegardé immédiatement : fermer l'application pendant l'ouverture ne fait rien perdre.

### Économie
| Monnaie | Sources (gratuites) | Usages |
|---|---|---|
| Pièces | Combats, missions, niveaux, connexion | Boosters thématiques, cartes à l'unité, offres |
| Cristaux | Missions, succès, niveaux, collections, connexion | Boosters Cosmique/Divin, cosmétiques, jeton hebdo |
| Jetons spéciaux | Niveaux (tous les 3), succès, missions hebdo | Booster Secret (niveau 5) |
| Plumes ardentes (événement) | Combats, boss d'événement | Booster d'événement |
| Poussière d'étoile | Recyclage des doublons (au-delà de 3) | Réservée aux évolutions de collection (étape 3) |

Monétisation prévue : achat de cristaux uniquement, aucun avantage exclusif en combat. Dans le prototype, l'onglet est **désactivé et l'indique clairement**.

### Combat
- 25 PV par leader, decks de 20 cartes (2 exemplaires maximum, 1 pour Légendaire+), main de 9 cartes maximum, 5 créatures maximum par camp.
- **Énergie** : +1 par tour jusqu'à 10. Le premier joueur pioche 3 cartes, le second 4.
- **Créatures** : l'attaque provoque une riposte simultanée, avec un mal d'invocation sauf **Célérité**.
- **Mots-clés** : Garde, Célérité, Bouclier, Poison, Vol de vie, Furtif, Rage.
- **Statuts** : Gel (passe sa prochaine attaque).
- **Déclencheurs** : Invocation, Dernier souffle, Début de tour, Attaque.
- **Évolutions en combat** : Braiselet devient Salamandre Ardente, Pousse-Sourire devient Floraison Majestueuse, et l'Œuf de Cendre redevient Phénix.
- **Éléments** : chaque élément est « super efficace » (dégâts x1,5) contre deux autres. Six éléments forment un cycle (Feu, Glace, Nature, Terre, Foudre, Eau) ; Ombre, Lumière, Cosmique et Néant forment un carré de tensions. L'avantage s'applique aussi contre l'élément du leader adverse.

| Élément | Fort contre |
|---|---|
| Feu | Glace, Nature |
| Glace | Nature, Terre |
| Nature | Terre, Foudre |
| Terre | Foudre, Eau |
| Foudre | Eau, Feu |
| Eau | Feu, Glace |
| Ombre | Lumière, Cosmique |
| Lumière | Ombre, Néant |
| Cosmique | Lumière, Néant |
| Néant | Cosmique, Ombre |

- **Pouvoir de leader** (2 énergie, une fois par tour) : Pyra (dégâts), Thalassa (soin), Umbra (pioche contre PV), Sylva (renforcement).
- **Conditions de victoire** : PV du leader adverse à 0, ou épuisement du deck adverse (dégâts de fatigue croissants).
- **IA** : à chaque étape, elle détecte un létal, joue la carte de plus forte valeur (ciblage évalué), utilise son pouvoir si c'est utile, puis choisit les échanges favorables avant de frapper le leader. Trois niveaux de difficulté.

### Progression
Niveau de compte (XP des combats, boosters, missions), titres, 3 missions quotidiennes tirées d'un pool, 3 missions hebdomadaires, 10 succès, calendrier de connexion sur 7 jours, récompenses de collection (par élément complété, set complété), points de classement locaux.

### Événements
`events.json` décrit un événement daté : nom, couleur, monnaie, boss (leader, éléments, PV, difficulté) et booster dédié. Le jeu active automatiquement l'événement en cours (bannière d'accueil, écran dédié, booster en boutique).

## 7. Multijoueur et backend (conception ; **non implémenté**)

Le multijoueur en ligne **n'est pas simulé** dans le prototype : les modes Classé, Amical et Tournois sont affichés comme « bientôt ». Architecture prévue :

```
Client Godot ──HTTPS/WebSocket──► Passerelle (Nakama ou service Go)
                                     ├─ Auth (Google Play Games / e-mail), sessions JWT
                                     ├─ Matchmaking (MMR/ligues), salons amicaux (code), tournois
                                     ├─ Serveur de combat AUTORITAIRE : port de BattleEngine (mêmes règles, mêmes JSON)
                                     ├─ Économie : boosters tirés côté serveur (RNG serveur + pity), inventaire
                                     ├─ Boutique : vérification des reçus Google Play Billing
                                     └─ Contenu : versions de sets / événements, CDN des paquets .pck
                                  PostgreSQL (comptes, collections, transactions) · Redis (files, sessions)
```

- Le client n'envoie que des **intentions** (`play hid→cible`, `attack uid→cible`, `end`). Le serveur valide, résout et renvoie la **même liste d'événements** que le moteur local, et la vue actuelle sait déjà les animer.
- **Anti-triche** : aucun tirage ni aucune ressource n'est calculé sur le client en mode en ligne. La sauvegarde locale devient un cache.
- **Classement** : saisons de 4 semaines, ligues, récompenses de fin de saison.

## 8. Plan de réalisation

| Étape | Contenu | Statut |
|---|---|---|
| 1 | Architecture, technologie, direction artistique (ce document) | ✅ Fait |
| 2 | Prototype jouable : accueil, collection, 64 cartes originales, 15 raretés, boutique, boosters animés, combat contre l'IA, APK portrait | ✅ Fait (détails en section 9) |
| 3 | Systèmes avancés : set 2 Éclipse et nouvelles mécaniques, Atelier (évolutions de collection, secrets, création, variantes), passe de saison, tutoriel | 🟡 En cours, première partie livrée en 0.2 (section 10) |
| 4 | Contenu : sets 2 à N (objectif 2000+ cartes) via le pipeline, illustrations dessinées pour les cartes vedettes, chargement par set | À faire |
| 5 | En ligne : backend, comptes, PvP classé et amical, tournois, événements serveur, sauvegarde cloud, achats réels | À faire |
| 6 | Tests complets sur appareils Android, optimisation, accessibilité, version Play Store (AAB, clé de production) | À faire |

## 9. État réel du prototype (étape 2)

**Fonctionnel et testé :**
- 64 cartes collectionnables uniques (+2 jetons), chacune avec nom, illustration générée à partir de sa propre recette, lore, rareté, élément, famille, statistiques et capacités. Les 15 raretés sont représentées.
- Album : filtres par élément, rareté et famille, 6 tris, recherche, cartes manquantes en silhouette, favoris, comparaison de deux cartes, pourcentage de complétion, récompenses de collection, recyclage des doublons.
- Fiche de carte : inclinaison 3D au doigt, reflets, aura et particules selon la rareté, navigation, variantes possédées, chaîne d'évolution.
- Boutique : 7 boosters (dont un d'événement et un secret débloqué au niveau 5), probabilités affichées, pity, offres du jour et de la semaine en rotation, cartes à l'unité, dos de carte et plateaux de combat, onglet premium désactivé.
- Ouverture de booster : rotation au doigt, déchirure en glissant (ou bouton), flash et particules, révélation carte par carte avec anticipation selon la rareté, **faille cosmique** pour Mythique et au-delà, badges « nouvelle », variantes et garanties, récapitulatif.
- Combat contre l'IA (3 niveaux et un boss d'événement) : règles complètes de la section 6, animations d'invocation, d'attaque, de projectile, de dégâts (« super efficace »), de gel, de bouclier, d'évolution et de mort, écran de victoire avec récompenses.
- Decks : 6 emplacements, éditeur (leader, ajout et retrait, courbe de coût, remplissage automatique, validation).
- Progression : niveaux, titres, missions quotidiennes et hebdomadaires, succès, connexion quotidienne, événement daté.
- Sauvegarde locale, bouton retour Android, sauvegarde lors de la mise en arrière-plan.

**Vérifications automatisées** (`--logic-test`) : intégrité des 66 cartes (illustration, lore, effets, évolutions, noms uniques), 4000 boosters simulés (distribution, pity respectée), 200 combats IA contre IA menés à terme avec vérification des invariants. Une partie complète a aussi été jouée dans l'interface réelle (`--shots=…:battle_auto`) sans erreur.

**Limites actuelles, annoncées honnêtement :**
- Les illustrations sont du **pixel art procédural**, produit par recette. Chaque carte a sa silhouette et sa palette, mais ce ne sont pas des peintures faites main. Le pipeline permet de les remplacer une à une.
- 289 cartes (6 sets), pas 2000 : l'architecture est prête, le contenu sera ajouté par sets (étape 4).
- Pas de multijoueur ni de paiement réel (étape 5).
- L'APK est signé avec une clé de développement (schéma v2, Android 7.0 minimum). Elle n'a pas été testée sur un appareil physique depuis cet environnement.

## 10. Version 0.2 (étape 3, première partie)

- **Set 2 « Éclipse »** (`data/cards/eclipse.json`) : 37 cartes et 1 jeton, avec 2 nouvelles chaînes d'évolution (Chauvelin devient Nyctalis, Gemmelin devient Colosse Prismatique) et une nouvelle carte Céleste (Noctaris). Le **Booster Éclipse** ne contient que ce set, et le Booster Genèse uniquement le set 1 (champ `sets` des boosters).
- **Nouvelles mécaniques**, intégrées au moteur, à l'IA et aux textes générés :
  - **Envol** (mot-clé) : attaque en ignorant les créatures avec Garde.
  - **Silence** (effet) : retire les mots-clés et les effets, et bloque l'évolution.
  - **Renvoi** (effet) : la créature retourne dans la main de son propriétaire ; un jeton disparaît.
  - **Énergie** (effet) : énergie supplémentaire pour le tour en cours.
- **Atelier** (`data/forge.json`, écran `forge.gd`) :
  - **Évolutions de collection** : 3 exemplaires et de la Poussière donnent la forme évoluée, avec sa propre illustration.
  - **5 transformations secrètes** : seul un indice est visible ; les ingrédients se révèlent quand on les possède tous.
  - **Création** de toute carte déjà découverte (jusqu'à Mythique).
  - **Application de variantes** : Holographique, Full Art, Alternate Art.
- **Passe de saison** (`data/season.json`, écran `season.gd`) : 30 paliers alimentés par l'XP du compte, voie gratuite et voie Élite (400 Cristaux gagnés en jeu), dos de carte exclusif au palier 30.
- **Boosters gratuits par type** (récompenses du passe), **Poussière d'étoile** gagnée en combat, 3 nouveaux succès.
- **Tutoriel** en 5 étapes au premier lancement, fenêtre **Nouveautés** pour les joueurs existants, filtre **par set** dans l'album.
- **Corrections** : retournement des cartes au toucher (0.1.1) ; créature « fantôme » affichée quand une action en invoquait plusieurs.
- **Tests ajoutés** : Envol, Garde, Silence, Renvoi, Énergie, exclusivité des boosters de set, recettes de l'Atelier, passe, et une partie automatique jouée uniquement avec des cartes Éclipse.

## 11. Version 0.3

- **Set 3 « Âge Primitif »** (`data/cards/primal.json`) : 45 cartes collectionnables (dont 9 Super Rares, 4 Primitives, 1 Mythique) et 3 SWAP, plus un jeton. Booster Âge Primitif dédié.
- **Rareté Primitif** : tirable normalement (poids 0,15), avec son propre cadre et ses runes animées.
- **Rareté SWAP** : exclue des tirages. Chaque booster a 12 % de chances (ajustées par la chance du booster) de contenir une **pièce de puzzle**, avec une garantie tous les 10 boosters. Les pièces manquantes sont privilégiées ; un doublon rapporte 120 Poussières. L'album affiche les cartes SWAP partiellement révélées, et l'ouverture de booster montre la pièce qui vient se placer puis l'assemblage final.
- **Mécaniques** :
  - **Piétinement** : l'excédent de dégâts touche le leader.
  - **Vol de contrôle** d'une créature ennemie.
  - **Échange ATQ et PV**.
  - **Échange des PV des deux leaders**.
- **Effets visuels** (shader `card_fx`) :
  - particules propres à l'élément dans l'illustration pour toutes les cartes Rares et plus ;
  - lumière qui court autour du cadre à partir d'Épique ;
  - relief de l'illustration qui suit l'inclinaison ;
  - **entrée spectaculaire en combat** des cartes Super Rares et plus (rayons, éclats, titre, tremblement pour Légendaire et plus).
- **Défilement tactile global** de toutes les listes, sans clic parasite.
- **Tests** : Piétinement, vol, échanges, fréquence et garantie des pièces, exclusion des raretés spéciales des tirages.

## 12. Version 0.4 : produits scellés

- **Boosters par génération** (`group: "gen"`) : Gén. 1 Genèse, Gén. 2 Éclipse, Gén. 3 Âge Primitif, et le Booster Multivers (toutes générations). **Boosters par type** (`group: "type"`, champ `elements`) : 10 boosters ne contenant que les cartes d'un élément.
- **Displays** (`data/products.json`, écran `display_open.gd`) : une caisse de 12 boosters (18 pour le Multivers) à prix réduit, ouverts un par un. La rareté garantie (Légendaire, ou Mythique pour le Multivers) est forcée au dernier booster si elle n'est pas encore sortie, via le mécanisme de pity. Les displays en cours sont sauvegardés et peuvent être repris.
- **Coffrets** (écran `box_open.gd`) : une **carte promo précise** dans une variante exclusive, des boosters ajoutés à la réserve (boosters gratuits par type) et des jetons spéciaux. Le contenu est crédité dès l'ouverture de l'écran.
- L'ouverture d'un booster est centralisée (`shop.gd::open_pack`) et partagée par la boutique, les displays et les coffrets.
- **Tests** : exclusivité des boosters de type, 30 displays simulés par type de display (garantie toujours obtenue), validité des coffrets. Les parcours display et coffret ont été joués avec de vrais événements tactiles, ce qui a permis de corriger un coffret qui ne s'ouvrait pas au toucher.

## 13. Version 0.5

- **Set 4 « Mécanica »** (`data/cards/mecanica.json`, Gén. 4) : 46 cartes collectionnables, dont 9 Super Rares, 1 Primitive, 1 Divine et 1 SWAP (Transformax), ainsi qu'un jeton (Noyau Ardent, qui redevient Phénix Mécanique). Nouvel effet **Recyclage** (`add_card`) : la carte revient en main à sa mort. Booster, Display et Coffret Mécanica (promo Colosse Atlas-9 en Full Art).
- **Visibilité des nouvelles cartes** :
  - les sets sont ordonnés par génération (champ `gen`), ce qui place la numérotation de l'album dans l'ordre Gén. 1 → Gén. 4 ;
  - bouton **Aperçu** dans l'album : il affiche les cartes non possédées en couleurs atténuées, et la fiche d'une carte non possédée montre son contenu ;
  - **bannière « Nouveau »** sur l'accueil avec les meilleures cartes de la dernière génération ;
  - **cadeau de mise à jour** : 1 Booster Éclipse, 2 Âge Primitif et 3 Mécanica pour les joueurs existants. Les nouveaux joueurs reçoivent un Booster Multivers et un Booster Mécanica.
- Total : **196 cartes collectionnables** sur 4 générations.

## 14. Version 0.6

- **Génération 5 « Royaume des Songes »** (`data/cards/songes.json`) : 46 cartes collectionnables (dont 9 Super Rares, 1 Cosmique, 1 Transcendante et la carte SWAP Somnus & Lucidia), plus un jeton. Nouvelle mécanique **Sommeil** (effet `sleep`) : la cible ne peut plus attaquer pendant 2 tours de son propriétaire. Le compteur `frozen` est décrémenté à chaque fin de tour (Gel = 1, Sommeil = 2). Booster, Display et Coffret dédiés.
- **Displays en 3D** (`display_open.gd`) : scène 3D dans un `SubViewport`.
  - Caisse modélisée (parois, face avant illustrée et générée par `tools/art/gen_display3d.py`), couvercle articulé, boosters debout en rangées, éclairage directionnel et lumière intérieure.
  - Rotation au doigt ; au premier toucher, le scellé se déchire et le couvercle s'ouvre.
  - Sélection d'un booster par projection écran (`Camera3D.unproject_position`) : le booster s'extrait de la caisse puis s'ouvre, et la caisse se vide au fur et à mesure.
  - L'état « couvercle ouvert » est sauvegardé avec le display en cours.
- **Tests** : Sommeil (bloque 2 tours puis se réveille), parcours du display 3D en touchers réels.
- Total : **242 cartes collectionnables** sur 5 générations.

## 15. Version 0.7 : l'ère des Dieux

- **Rareté GOD** (`G`), la plus haute de toutes (poids 0,0004, uniquement dans les boosters qui contiennent ses cartes) :
  - cadre en or poli avec filigrane gravé, couronne solaire et quatre gemmes ;
  - shader `card_fx` en mode surface 7 (lustre doré, irisation, scintillements) et en contour 4 :
    - bande d'or liquide épaisse qui ondule tout autour de la carte ;
    - deux comètes de lumière qui en font le tour ;
    - éclats scintillants sur le cadre, liseré intérieur pulsant et rayons divins qui balaient la carte ;
  - poussière d'or ascendante dans l'illustration (élément spécial 10) et halo doré pulsant derrière la carte ;
  - **révélation dédiée** à l'ouverture d'un booster : voile doré, colonne de lumière, pluie d'or, titre « G O D » géant, puis la faille cosmique.
- **Génération 6 « Panthéon Céleste »** (`data/cards/pantheon.json`) : 47 cartes collectionnables (9 Super Rares, 4 Épiques, 3 Légendaires, 1 Mythique, 1 Divine, 1 Absolue) dont **3 cartes GOD** (Zeus, Solaris, Æther). Nouvelle mécanique **Résurrection** (effet `revive`) : chaque joueur a un cimetière (`grave`), et l'effet ramène la ou les dernières créatures alliées mortes, jetons exclus. Booster, Display 3D et Coffret dédiés (promo Héra en Secret Art).
- **La Tour des Dieux** (`data/tower.json`, écran `tower.gd`) : 20 étages de combat contre l'IA.
  - La difficulté, la rareté maximale des decks adverses et les PV du leader adverse augmentent à chaque étage.
  - Des **modificateurs** s'appliquent dans le moteur (`BattleEngine.setup(..., mods)`) : créatures adverses avec +ATQ ou Bouclier, énergie de départ bonus, pioche adverse supplémentaire.
  - Des **boss** gardent les étages 5, 10, 15 et 20.
  - Récompenses au premier passage (pièces, poussière, XP, booster à l'étage 5, cristaux à l'étage 10, jetons à l'étage 15) et **carte GOD garantie à l'étage 20**, choisie de préférence parmi celles qu'on ne possède pas. Rejouer un étage rapporte des pièces.
- **Tests** : étages valides, modificateurs appliqués, PV du boss, cimetière et Résurrection, GOD absente du booster Genèse et présente dans le booster Panthéon, carte GOD remise au sommet.
- Total : **289 cartes collectionnables** sur 6 générations, 18 raretés.

## 16. Version 0.8 : Corsaires, Jungle et nouvelle boutique

- **3 nouvelles raretés** (`data/rarities.json`, 21 raretés au total) :
  - **Néon** (`NE`, entre Super Rare et Épique, poids 3) : cadre à tubes lumineux, contour shader 5 (tubes cyan/magenta qui clignotent, reflets) ;
  - **Infernale** (`IN`, entre Mythique et Ancestrale, poids 0,3) : cadre de roche et de braises, contour shader 6 (flammes animées qui montent des bords) ;
  - **Mirage** (`MI`, entre Céleste et Transcendante, poids 0,04) : cadre nacré, contour shader 7 (reflets ondulants et chromatiques).
- **Génération 7 « Corsaires Astraux »** (`data/cards/corsaires.json`) : 46 cartes collectionnables et un jeton (Crapaud Astral, cible de la Métamorphose).
- **Génération 8 « Jungle Sauvage »** (`data/cards/jungle.json`) : 45 cartes collectionnables, 3 jetons, et la 4e carte GOD (Gaïarugh).
- Chaque génération a son booster, son Display 3D et son Coffret.
- **Nouveaux effets** dans le moteur :
  - `burn` (Brûlure) : 1 dégât au début de chaque tour du propriétaire, pendant N tours. L'événement s'appelle `ignite`, car `burn` désigne déjà une carte détruite quand la main est pleine. Une icône de flamme s'affiche sur la créature.
  - `polymorph` (Métamorphose) : la créature devient le jeton `card` (Crapaud Astral par défaut), avec ses statistiques et sans ses mots-clés.
  - `copy` (Copie) : une copie de la créature ciblée arrive dans la main.
- **Nouvelle édition de paquets** (groupe `edition` de `boosters.json`) :
  - **Booster Prestige** : 8 cartes des Gén. 6 à 8. Les 2 derniers emplacements sont Rare ou mieux (`rare_slots`) et une variante est garantie (`guaranteed_variant`) ; les deux sont gérés dans `BoosterLogic.open`. Il existe aussi un Display Prestige (Mythique garanti).
  - **Mini-Booster** : 3 cartes pour 45 pièces.
- **Boutique** (9 onglets sur 2 rangées), règles dans `scripts/logic/shop_logic.gd` :
  - **Roue de la Fortune** (`wheel_view.gd`, dessinée et animée) : 9 cases pondérées dont les chances sont affichées, 1 tour gratuit par jour et 3 tours bonus à 25 cristaux.
  - **Marché Noir** : 4 cartes, de l'Épique à la Mythique, payables en Poussière ou en Cristaux. Le stock tourne toutes les 6 heures, avec au moins une Légendaire ou mieux, et chaque carte n'est vendue qu'une fois par rotation.
  - **Packs groupés** (`products.json` → `bundles`) : boosters et ressources, limités à 1 par semaine ou à 1 achat unique. La Malle du Légendaire contient une Légendaire Gén. 7/8 au hasard et un dos exclusif.
- **Saison 2 « Corsaires des Étoiles »** (`season.json`, id `s2`) : 30 nouveaux paliers. Le palier 15 de la voie Élite donne le plateau « Pont du Vaisseau Astral », et le palier 30 le dos « Corsaire ». La progression de la saison 1 est remise à zéro, comme pour tout changement de saison.
- **Cosmétiques** : dos Néon, Corsaire et Nébuleuse Pourpre, plateau Jungle.
- **Cadeau de mise à jour** : 2 boosters Corsaires, 2 boosters Jungle et 1 booster Prestige.
- **Tests** :
  - raretés NE, IN et MI présentes et tirables ; GOD possible dans le booster Jungle ;
  - Brûlure (application, dégât par tour, extinction), Métamorphose, Copie ;
  - 300 boosters Prestige (8 cartes, variante et 2 Rares+ toujours présentes), Mini-Booster ;
  - roue (toutes les cases sortent, total 100 %, tour gratuit quotidien) ;
  - marché (stable par rotation, raretés autorisées, Légendaire+ présente) ;
  - validité des packs groupés et des displays.
- Total : **380 cartes collectionnables** sur 8 générations, 21 raretés.

## 17. Version 0.9 : Formes Ultimes

Un nouveau style de carte, en deux formes (champ `form` d'une carte), dans l'extension Gén. 9 « Formes Ultimes » (`data/cards/ultime.json`, 26 cartes) :

- **Ω Oméga** (`form: "omega"`) : logo Ω à côté du nom.
  - Le logo, comme celui des Titans, est généré par `gen_ui.py` dans `assets/ui/badges/` ; il pulse légèrement sur la carte et apparaît aussi sur la créature en combat.
  - Le champ `omega` liste les effets du **Déchaînement Ω**. Ils se déclenchent automatiquement à la première attaque d'une créature Ω, **une seule fois par partie et par joueur** (`pl[i].omega_used`, `BattleEngine._omega`).
  - Le Déchaînement a son animation (bannière, explosion, secousse) et fonctionne aussi pour l'IA.
- **Titan** (`form: "titan"`) : **illustration grand format**.
  - L'illustration occupe toute la carte, avec un cadre spécifique `frames/titan_<rareté>.png` : liseré à coins biseautés, bandeau de nom vitré, ligne de type et zone de texte plus basses (`titan_type`, `titan_text` dans `card_layout.json`).
  - Logo TITAN à côté du nom.
  - Insensible au Gel, au Sommeil, à la Métamorphose et au Vol (`DB.TITAN_IMMUNE`, événement `immune`). L'IA ne gaspille pas ces effets sur un Titan.
- **Contrecoup** : quand une forme ultime est détruite, son leader subit des dégâts (`DB.FORM_BACKLASH` : 2 pour Ω, 3 pour un Titan). C'est le prix de leur puissance.
- Le nom du logo s'ajoute à la ligne de type (« Divinité Ω », « Robot Titan »).
- Le texte de capacité affiche le Déchaînement et les règles de forme.
- Booster, Display 3D et Coffret dédiés. L'extension est aussi incluse dans le Booster Prestige.
- Cadeau de mise à jour : 3 boosters Formes Ultimes.
- **Tests** :
  - Déchaînement déclenché à la première attaque et une seule fois par partie ;
  - immunités du Titan ;
  - Contrecoup Ω (2) et Titan (3) ;
  - un combat réel où l'animation du Déchaînement et l'insensibilité sont jouées.
- Total : **406 cartes collectionnables** sur 9 générations.

## 18. Version 0.10 : Sables Éternels

- **Génération 10 « Sables Éternels »** (`data/cards/sables.json`) : 48 cartes collectionnables sur le thème des pharaons, des momies, des djinns, des sphinx et des scarabées, plus 2 jetons (Momie Errante, Scarabée Maudit).
  - **Raretés** :
    - 12 Communes, 8 Peu communes, 8 Rares, 6 Super Rares ;
    - 2 Néon, 4 Épiques, 1 Infernale ;
    - 1 Légendaire, 1 Mythique, 1 Mirage et 1 Divine (Solkhet, Dieu-Soleil des Sables).
  - **Formes ultimes** : 2 cartes Ω (Anoukhet, Ifrahim) et 1 Titan (Sphinxar).
  - Aucun nouvel effet : le set combine les mécaniques existantes (momies qui se relèvent en jetons, Résurrection, Métamorphose en scarabée, Brûlure, Sommeil, Copie).
- Booster, Display 3D et Coffret dédiés (promo Ramessh en Secret Art). Le set est aussi inclus dans le Booster Prestige.
- Cadeau de mise à jour : 3 boosters Sables Éternels.
- **Tests** : 48 cartes, jetons référencés valides, raretés Divine, Néon et Mirage tirables dans le booster.
- Total : **454 cartes collectionnables** sur 10 générations.
