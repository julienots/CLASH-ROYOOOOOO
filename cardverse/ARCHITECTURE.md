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
| 3 | Systèmes avancés : évolutions de collection (Poussière), capacités débloquables, passe de saison, decks IA thématiques, nouveaux mots-clés, tutoriel guidé, paramètres de langue | À faire |
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
- 64 cartes, pas 2000 : l'architecture est prête, le contenu sera ajouté par sets (étape 4).
- Pas de multijoueur, de paiement réel, de passe de saison ni d'évolution de collection (étapes 3 et 5).
- L'APK est signé avec une clé de développement (schéma v2, Android 7.0 minimum). Elle n'a pas été testée sur un appareil physique depuis cet environnement.
