extends Node
## Données du jeu : cartes, tours, îles, sauvegarde. (Autoload « Data »)

const SAVE_PATH := "user://save.json"
const MAX_LEVEL := 9

const RARITY := {
	"common": {"label": "Commune", "color": Color("9fb4c8"), "bg": [Color("5f86b8"), Color("2b4a78")]},
	"rare": {"label": "Rare", "color": Color("ffb02e"), "bg": [Color("f0a43a"), Color("9a4d12")]},
	"epic": {"label": "Épique", "color": Color("c55cff"), "bg": [Color("b25cf0"), Color("4b1f86")]},
	"legendary": {"label": "Légendaire", "color": Color("4ff0d2"), "bg": [Color("43d8c4"), Color("1b4e7a")]},
}

const CARDS := {
	"blade": {"name": "Lame Spectrale", "type": "unit", "cost": 3, "rarity": "rare",
		"desc": "Assassin fantôme très rapide. Sa première frappe inflige le double de dégâts.",
		"hp": 720, "dmg": 165, "hit_speed": 1.0, "speed": 2.3, "range": 0.9, "radius": 0.45,
		"targets": "ground", "attack": "melee", "first_strike": 2.0},
	"golem": {"name": "Colosse Barbare", "type": "unit", "cost": 6, "rarity": "epic",
		"desc": "Géant à la hache qui ne vise que les bâtiments. À sa mort, 2 Barbares enragés surgissent.",
		"hp": 3600, "dmg": 230, "hit_speed": 1.6, "speed": 0.85, "range": 1.0, "radius": 0.95,
		"targets": "buildings", "attack": "melee", "on_death": "shard", "death_count": 2, "heavy": true},
	"shard": {"name": "Barbare enragé", "type": "unit", "cost": 0, "rarity": "common", "hidden": true,
		"hp": 700, "dmg": 70, "hit_speed": 1.2, "speed": 1.1, "range": 0.8, "radius": 0.5,
		"targets": "buildings", "attack": "melee"},
	"archers": {"name": "Arbalétrières", "type": "unit", "cost": 3, "rarity": "common", "count": 2,
		"desc": "Duo d'arbalétrières agiles. Touchent les unités aériennes et terrestres.",
		"hp": 300, "dmg": 95, "hit_speed": 1.0, "speed": 1.4, "range": 5.2, "radius": 0.4,
		"targets": "both", "attack": "arrow"},
	"pyro": {"name": "Pyromancien", "type": "unit", "cost": 5, "rarity": "rare",
		"desc": "Lance des boules de feu qui explosent en zone.",
		"hp": 640, "dmg": 210, "hit_speed": 1.7, "speed": 1.2, "range": 5.0, "radius": 0.45,
		"targets": "both", "attack": "fireball", "splash": 1.5},
	"swarm": {"name": "Horde de Squelettes", "type": "unit", "cost": 2, "rarity": "common", "count": 6,
		"desc": "Six squelettes surgissent du sol. Fragiles mais nombreux.",
		"hp": 85, "dmg": 70, "hit_speed": 0.9, "speed": 2.1, "range": 0.6, "radius": 0.3,
		"targets": "ground", "attack": "melee"},
	"storm": {"name": "Liche de l'Orage", "type": "unit", "cost": 7, "rarity": "legendary",
		"desc": "Sorcier mort-vivant géant dont la foudre rebondit sur 3 cibles.",
		"hp": 2900, "dmg": 250, "hit_speed": 1.9, "speed": 0.9, "range": 4.5, "radius": 0.9,
		"targets": "both", "attack": "chain", "heavy": true},
	"shield": {"name": "Chevalier d'Airain", "type": "unit", "cost": 4, "rarity": "common",
		"desc": "Chevalier robuste protégé par un bouclier de 450 PV.",
		"hp": 1450, "shield": 450, "dmg": 175, "hit_speed": 1.2, "speed": 1.25, "range": 1.0, "radius": 0.5,
		"targets": "ground", "attack": "melee"},
	"sapper": {"name": "Sapeur Squelette", "type": "unit", "cost": 2, "rarity": "rare",
		"desc": "Squelette pyromane qui fonce sur un bâtiment et explose avec son tonneau.",
		"hp": 320, "dmg": 480, "hit_speed": 0.1, "speed": 2.6, "range": 0.8, "radius": 0.4,
		"targets": "buildings", "attack": "kamikaze", "splash": 2.0},
	"drake": {"name": "Chevaucheur de Drake", "type": "unit", "cost": 5, "rarity": "epic", "flying": true,
		"desc": "Monture volante qui crache un souffle de feu en zone.",
		"hp": 1050, "dmg": 140, "hit_speed": 1.5, "speed": 1.5, "range": 3.0, "radius": 0.7,
		"targets": "both", "attack": "breath", "splash": 1.3},
	"totem": {"name": "Totem Arcanique", "type": "building", "cost": 4, "rarity": "rare",
		"desc": "Obélisque défensif qui tire un rayon d'essence. Dure 30 s.",
		"hp": 1150, "dmg": 125, "hit_speed": 0.9, "range": 6.0, "radius": 0.8, "lifetime": 30.0,
		"targets": "both", "attack": "beam"},
	"meteor": {"name": "Météore", "type": "spell", "cost": 4, "rarity": "rare",
		"desc": "Un rocher en fusion s'écrase sur la zone ciblée.",
		"radius": 2.5, "dmg": 560, "tower_mult": 0.35, "delay": 1.0},
	"frost": {"name": "Nova de Givre", "type": "spell", "cost": 3, "rarity": "epic",
		"desc": "Explosion glaciale qui gèle tout pendant 3 s.",
		"radius": 3.0, "dmg": 110, "tower_mult": 0.4, "freeze": 3.0, "delay": 0.0},
	"champion": {"name": "Champion Royal", "type": "unit", "cost": 5, "rarity": "legendary",
		"desc": "Maître d'armes à l'épée géante. Son attaque tournoyante frappe tout autour de lui.",
		"hp": 1900, "dmg": 230, "hit_speed": 1.5, "speed": 1.2, "range": 1.2, "radius": 0.6,
		"targets": "ground", "attack": "melee", "splash": 1.6},
	"berserker": {"name": "Berserker", "type": "unit", "cost": 4, "rarity": "epic",
		"desc": "Barbare aux deux haches. Sous 50 % de vie, il entre en rage et frappe deux fois plus vite.",
		"hp": 1250, "dmg": 120, "hit_speed": 0.9, "speed": 1.6, "range": 0.9, "radius": 0.5,
		"targets": "ground", "attack": "melee", "enrage": true},
	"healer": {"name": "Enchanteresse", "type": "unit", "cost": 4, "rarity": "epic",
		"desc": "Mage guérisseuse : soigne les alliés proches et frappe les ennemis de projectiles d'arcane.",
		"hp": 620, "dmg": 80, "hit_speed": 1.2, "speed": 1.2, "range": 4.5, "radius": 0.45,
		"targets": "both", "attack": "arcane", "heal": 90, "heal_radius": 3.2},
	"knives": {"name": "Lanceuse de Couteaux", "type": "unit", "cost": 3, "rarity": "rare",
		"desc": "Voleuse agile qui lance une volée de couteaux rapides. Touche l'air et le sol.",
		"hp": 420, "dmg": 55, "hit_speed": 0.55, "speed": 1.6, "range": 4.2, "radius": 0.4,
		"targets": "both", "attack": "knife"},
	"warriors": {"name": "Squelettes Guerriers", "type": "unit", "cost": 4, "rarity": "common", "count": 3,
		"desc": "Trois guerriers squelettes armés de haches et de boucliers.",
		"hp": 380, "shield": 120, "dmg": 105, "hit_speed": 1.1, "speed": 1.3, "range": 0.8, "radius": 0.45,
		"targets": "ground", "attack": "melee"},
	"necro": {"name": "Nécromancien", "type": "unit", "cost": 5, "rarity": "legendary",
		"desc": "Invoque 2 squelettes toutes les 7 s et lance des éclairs d'ombre.",
		"hp": 760, "dmg": 110, "hit_speed": 1.6, "speed": 1.0, "range": 5.0, "radius": 0.5,
		"targets": "both", "attack": "shadow", "summon": "minion", "summon_count": 2, "summon_every": 7.0},
	"minion": {"name": "Squelette", "type": "unit", "cost": 0, "rarity": "common", "hidden": true,
		"hp": 85, "dmg": 70, "hit_speed": 0.9, "speed": 2.1, "range": 0.6, "radius": 0.3,
		"targets": "ground", "attack": "melee"},
	"catapult": {"name": "Tour Catapulte", "type": "building", "cost": 6, "rarity": "epic",
		"desc": "Bâtiment qui lance des rochers à très longue portée. Dégâts de zone. Dure 40 s.",
		"hp": 1400, "dmg": 190, "hit_speed": 3.0, "range": 9.5, "radius": 1.0, "lifetime": 40.0,
		"targets": "ground", "attack": "boulder", "splash": 1.6, "min_range": 2.5},
	"arrows": {"name": "Pluie de Flèches", "type": "spell", "cost": 3, "rarity": "common",
		"desc": "Une nuée de flèches s'abat sur une large zone.",
		"radius": 3.6, "dmg": 230, "tower_mult": 0.3, "delay": 0.6},
	"rage": {"name": "Rage", "type": "spell", "cost": 2, "rarity": "epic",
		"desc": "Tes troupes dans la zone deviennent 40 % plus rapides pendant 7 s.",
		"radius": 3.5, "dmg": 0, "tower_mult": 0.0, "rage": 7.0, "delay": 0.0},

	"titan": {"name": "Gardien Titanesque", "type": "unit", "cost": 6, "rarity": "epic",
		"desc": "Chevalier colossal au bouclier rond. Encaisse énormément de coups.",
		"hp": 4200, "dmg": 140, "hit_speed": 1.4, "speed": 0.8, "range": 1.1, "radius": 0.9,
		"targets": "ground", "attack": "melee", "heavy": true},
	"bomber": {"name": "Artificière", "type": "unit", "cost": 4, "rarity": "rare",
		"desc": "Lance des bombes qui explosent en zone sur les troupes au sol.",
		"hp": 380, "dmg": 160, "hit_speed": 1.6, "speed": 1.3, "range": 4.6, "radius": 0.4,
		"targets": "ground", "attack": "bomb", "splash": 1.6},
	"icemage": {"name": "Archimage de Givre", "type": "unit", "cost": 5, "rarity": "legendary",
		"desc": "Ses éclats de glace ralentissent les ennemis touchés de 35 %.",
		"hp": 700, "dmg": 120, "hit_speed": 1.4, "speed": 1.2, "range": 5.0, "radius": 0.45,
		"targets": "both", "attack": "ice", "splash": 1.0, "chill": 2.0},
	"army": {"name": "Armée de Squelettes", "type": "unit", "cost": 4, "rarity": "epic", "count": 12,
		"desc": "Douze squelettes surgissent d'un coup. Submerge n'importe quelle unité seule.",
		"hp": 85, "dmg": 70, "hit_speed": 0.9, "speed": 2.1, "range": 0.6, "radius": 0.3,
		"targets": "ground", "attack": "melee"},
	"giant_skel": {"name": "Squelette Colossal", "type": "unit", "cost": 6, "rarity": "epic",
		"desc": "Fonce sur les bâtiments. À sa mort, il explose violemment.",
		"hp": 3000, "dmg": 200, "hit_speed": 1.5, "speed": 0.9, "range": 1.0, "radius": 0.95,
		"targets": "buildings", "attack": "melee", "heavy": true, "death_bomb": 520, "death_radius": 3.0},
	"lumber": {"name": "Bûcheron Enragé", "type": "unit", "cost": 4, "rarity": "legendary",
		"desc": "Frappe très vite. À sa mort, il libère un nuage de Rage sur ses alliés.",
		"hp": 1050, "dmg": 190, "hit_speed": 0.8, "speed": 1.9, "range": 0.9, "radius": 0.5,
		"targets": "ground", "attack": "melee", "death_rage": 6.0},
	"babydrake": {"name": "Dragonnet", "type": "unit", "cost": 4, "rarity": "epic", "flying": true,
		"desc": "Jeune dragon volant qui crache de petites flammes en zone.",
		"hp": 900, "dmg": 115, "hit_speed": 1.5, "speed": 1.6, "range": 3.0, "radius": 0.6,
		"targets": "both", "attack": "breath", "splash": 1.2},
	"ghost": {"name": "Voleuse Fantôme", "type": "unit", "cost": 3, "rarity": "legendary",
		"desc": "Invisible tant qu'elle n'attaque pas : impossible à cibler entre deux coups.",
		"hp": 620, "dmg": 210, "hit_speed": 1.1, "speed": 1.7, "range": 0.9, "radius": 0.45,
		"targets": "ground", "attack": "melee", "invisible": true},
	"guards": {"name": "Gardes Royaux", "type": "unit", "cost": 5, "rarity": "epic", "count": 4,
		"desc": "Quatre gardes en armure, chacun protégé par un bouclier.",
		"hp": 360, "shield": 200, "dmg": 95, "hit_speed": 1.1, "speed": 1.3, "range": 1.0, "radius": 0.45,
		"targets": "ground", "attack": "melee"},
	"xbow": {"name": "Tour d'Arbalète", "type": "building", "cost": 6, "rarity": "epic",
		"desc": "Tour défensive qui crible les troupes au sol de carreaux à très longue portée. Dure 40 s.",
		"hp": 1300, "dmg": 70, "hit_speed": 0.35, "range": 8.5, "radius": 1.0, "lifetime": 40.0,
		"targets": "ground", "attack": "arrow"},
	"tomb": {"name": "Tombeau Hanté", "type": "building", "cost": 3, "rarity": "rare",
		"desc": "Fait surgir un squelette toutes les 3,5 s pendant 30 s.",
		"hp": 650, "dmg": 0, "hit_speed": 1.0, "range": 0.0, "radius": 0.8, "lifetime": 30.0,
		"targets": "ground", "attack": "none", "summon": "minion", "summon_count": 1, "summon_every": 3.5},
	"barracks": {"name": "Caserne Barbare", "type": "building", "cost": 6, "rarity": "rare",
		"desc": "Forme un Barbare enragé toutes les 8 s pendant 40 s.",
		"hp": 1250, "dmg": 0, "hit_speed": 1.0, "range": 0.0, "radius": 1.1, "lifetime": 40.0,
		"targets": "ground", "attack": "none", "summon": "shard", "summon_count": 1, "summon_every": 8.0},
	"lightning": {"name": "Éclair Royal", "type": "spell", "cost": 6, "rarity": "epic",
		"desc": "Foudroie les 3 ennemis les plus robustes de la zone.",
		"radius": 3.6, "dmg": 720, "tower_mult": 0.3, "delay": 0.0, "strikes": 3},
	"tornado": {"name": "Tornade", "type": "spell", "cost": 3, "rarity": "epic",
		"desc": "Aspire les troupes ennemies vers son centre pendant 2 s.",
		"radius": 3.8, "dmg": 110, "tower_mult": 0.0, "delay": 0.0, "pull": 2.0},
	"heal": {"name": "Bénédiction", "type": "spell", "cost": 3, "rarity": "rare",
		"desc": "Soigne tes troupes de 450 PV dans la zone.",
		"radius": 3.5, "dmg": 0, "heal": 450, "tower_mult": 0.0, "delay": 0.0},
	"poison": {"name": "Poison", "type": "spell", "cost": 4, "rarity": "epic",
		"desc": "Nuage toxique : 600 dégâts sur 7 s et ralentit les ennemis.",
		"radius": 3.4, "dmg": 600, "tower_mult": 0.35, "delay": 0.0, "duration": 7.0},

	"ancient_dragon": {"name": "Dragon Ancestral", "type": "unit", "cost": 7, "rarity": "legendary", "flying": true,
		"desc": "Dragon colossal au souffle infernal : plus il brûle la même cible, plus les dégâts augmentent (jusqu'à x4).",
		"hp": 2600, "dmg": 60, "hit_speed": 0.4, "speed": 1.1, "range": 3.6, "radius": 1.0,
		"targets": "both", "attack": "inferno", "heavy": true},
	"crystal_golem": {"name": "Golem de Cristal", "type": "unit", "cost": 7, "rarity": "legendary",
		"desc": "Géant de roche et de cristal qui vise les bâtiments. À sa mort, il gèle les ennemis proches et se brise en 3 éclats.",
		"hp": 4400, "dmg": 250, "hit_speed": 1.7, "speed": 0.8, "range": 1.1, "radius": 1.0,
		"targets": "buildings", "attack": "melee", "heavy": true, "on_death": "crystal_shard", "death_count": 3, "death_freeze": 2.0},
	"crystal_shard": {"name": "Éclat de Cristal", "type": "unit", "cost": 0, "rarity": "common", "hidden": true,
		"hp": 650, "dmg": 90, "hit_speed": 1.2, "speed": 1.2, "range": 0.8, "radius": 0.5,
		"targets": "buildings", "attack": "melee"},
	"phoenix": {"name": "Phénix", "type": "unit", "cost": 5, "rarity": "legendary", "flying": true,
		"desc": "Oiseau de feu volant. À sa mort, il laisse un œuf : s'il n'est pas détruit en 3 s, le Phénix renaît.",
		"hp": 1000, "dmg": 170, "hit_speed": 1.3, "speed": 1.6, "range": 3.4, "radius": 0.7,
		"targets": "both", "attack": "fireball", "splash": 1.2, "on_death": "phoenix_egg", "death_count": 1},
	"phoenix_egg": {"name": "Œuf de Phénix", "type": "building", "cost": 0, "rarity": "legendary", "hidden": true,
		"hp": 350, "dmg": 0, "hit_speed": 1.0, "range": 0.0, "radius": 0.6, "lifetime": 3.0,
		"targets": "ground", "attack": "none", "hatch": "phoenix_reborn"},
	"phoenix_reborn": {"name": "Phénix", "type": "unit", "cost": 0, "rarity": "legendary", "flying": true, "hidden": true,
		"hp": 800, "dmg": 170, "hit_speed": 1.3, "speed": 1.6, "range": 3.4, "radius": 0.7,
		"targets": "both", "attack": "fireball", "splash": 1.2},
	"skeleton_king": {"name": "Roi Squelette", "type": "unit", "cost": 6, "rarity": "legendary",
		"desc": "Souverain mort-vivant couronné : frappe en zone et relève 3 squelettes toutes les 8 s.",
		"hp": 2300, "dmg": 180, "hit_speed": 1.4, "speed": 1.0, "range": 1.1, "radius": 0.7,
		"targets": "ground", "attack": "melee", "splash": 1.2, "summon": "minion", "summon_count": 3, "summon_every": 8.0},
	"shadow_witch": {"name": "Sorcière des Ombres", "type": "unit", "cost": 4, "rarity": "epic",
		"desc": "Se téléporte vers sa cible toutes les 5 s et lance des éclairs d'ombre.",
		"hp": 650, "dmg": 140, "hit_speed": 1.2, "speed": 1.2, "range": 4.2, "radius": 0.45,
		"targets": "both", "attack": "shadow", "blink": 5.0},
	"sky_knight": {"name": "Chevalier Céleste", "type": "unit", "cost": 5, "rarity": "legendary",
		"desc": "Bondit sur les cibles éloignées (2,5 à 6 cases) et frappe à double dégâts à l'atterrissage.",
		"hp": 1550, "dmg": 210, "hit_speed": 1.3, "speed": 1.4, "range": 1.1, "radius": 0.55,
		"targets": "ground", "attack": "melee", "dash": 4.0},
	"comets": {"name": "Pluie de Comètes", "type": "spell", "cost": 6, "rarity": "legendary",
		"desc": "Six comètes s'abattent au hasard sur une très large zone.",
		"radius": 4.0, "dmg": 260, "tower_mult": 0.35, "delay": 0.0, "count": 6},
	"clone": {"name": "Clone", "type": "spell", "cost": 3, "rarity": "epic",
		"desc": "Crée une copie de chacune de tes troupes dans la zone. Les copies n'ont qu'1 PV.",
		"radius": 3.0, "dmg": 0, "tower_mult": 0.0, "delay": 0.0},
	"aegis": {"name": "Bouclier Arcanique", "type": "spell", "cost": 2, "rarity": "rare",
		"desc": "Donne un bouclier de 300 PV à tes troupes dans la zone.",
		"radius": 3.2, "dmg": 0, "tower_mult": 0.0, "delay": 0.0, "shield": 300},
	"cannon": {"name": "Canon Royal", "type": "building", "cost": 3, "rarity": "common",
		"desc": "Canon défensif qui tire des boulets sur les troupes au sol. Dure 30 s.",
		"hp": 900, "dmg": 165, "hit_speed": 0.9, "range": 5.6, "radius": 0.9, "lifetime": 30.0,
		"targets": "ground", "attack": "cannonball"},
}

const DEFAULT_DECK := ["blade", "golem", "archers", "pyro", "swarm", "shield", "meteor", "frost"]

const TOWER := {
	"side": {"hp": 2100, "dmg": 85, "hit_speed": 0.8, "range": 7.5, "radius": 1.3},
	"core": {"hp": 3600, "dmg": 105, "hit_speed": 1.0, "range": 7.2, "radius": 1.8},
}

const ISLANDS := [
	{"id": 0, "name": "Île des Brumes", "trophies": 0, "grass": Color("58b847"), "grass2": Color("4ea83f"), "tile": Color("d8c9a3"), "water": Color("2ab7e8"), "sky": Color("8fd8ff"), "cliff": Color("8a6b4a"), "leaf": Color("3f9e3a")},
	{"id": 1, "name": "Île de Braise", "trophies": 200, "grass": Color("7a8a3c"), "grass2": Color("6d7c33"), "tile": Color("c9a98a"), "water": Color("ff6a1a"), "sky": Color("ffb27a"), "cliff": Color("5a3a2a"), "leaf": Color("d9661f")},
	{"id": 2, "name": "Marais Maudit", "trophies": 450, "grass": Color("5f7a3a"), "grass2": Color("546d33"), "tile": Color("a89a7a"), "water": Color("6bbf59"), "sky": Color("9fc2a0"), "cliff": Color("4d4a3a"), "leaf": Color("4f6b2a")},
	{"id": 3, "name": "Île Givrée", "trophies": 750, "grass": Color("cfe7f2"), "grass2": Color("bcdbea"), "tile": Color("a7b8c9"), "water": Color("4fd2ff"), "sky": Color("b7d6ff"), "cliff": Color("7a8ca6"), "leaf": Color("e8f6ff")},
	{"id": 4, "name": "Dunes Dorées", "trophies": 1100, "grass": Color("e2c47a"), "grass2": Color("d6b66a"), "tile": Color("c99a62"), "water": Color("2fc7c9"), "sky": Color("ffd89a"), "cliff": Color("b07a45"), "leaf": Color("7fae3a")},
	{"id": 5, "name": "Forêt Ancienne", "trophies": 1500, "grass": Color("3f8f4a"), "grass2": Color("378241"), "tile": Color("9a8a6a"), "water": Color("3a9ad9"), "sky": Color("7fc7a8"), "cliff": Color("5e4a32"), "leaf": Color("2f7a35")},
	{"id": 6, "name": "Île Céleste", "trophies": 2000, "grass": Color("8f6cd8"), "grass2": Color("7f5ec9"), "tile": Color("e6d7a8"), "water": Color("ffd84f"), "sky": Color("9a7bff"), "cliff": Color("5a4a8a"), "leaf": Color("ff9ad5")},
	{"id": 7, "name": "Citadelle d'Essence", "trophies": 2600, "grass": Color("39466e"), "grass2": Color("323e63"), "tile": Color("c9b27a"), "water": Color("d24bff"), "sky": Color("5a4a9a"), "cliff": Color("2c2a44"), "leaf": Color("8a5ad9")},
]

## Île à atteindre pour débloquer chaque carte.
const UNLOCK := {
	"blade": 0, "golem": 0, "archers": 0, "pyro": 0, "swarm": 0, "shield": 0, "meteor": 0, "frost": 0, "arrows": 0,
	"sapper": 1, "knives": 1, "totem": 1, "warriors": 1, "bomber": 1, "tomb": 1,
	"rage": 2, "drake": 2, "army": 2, "babydrake": 2, "healer": 2, "titan": 2,
	"berserker": 3, "icemage": 3, "xbow": 3, "heal": 3,
	"champion": 4, "giant_skel": 4, "guards": 4, "lightning": 4,
	"storm": 5, "lumber": 5, "barracks": 5, "tornado": 5, "catapult": 5,
	"necro": 6, "poison": 6,
	"ghost": 7,
	"cannon": 1, "aegis": 2, "shadow_witch": 3, "clone": 4, "sky_knight": 5, "crystal_golem": 5,
	"comets": 6, "skeleton_king": 6, "phoenix": 7, "ancient_dragon": 7,
}

## Récompenses de la route des trophées.
const ROAD := [
	{"t": 50, "gold": 150}, {"t": 100, "chest": "silver"}, {"t": 150, "gems": 10}, {"t": 250, "gold": 300}, {"t": 350, "chest": "gold"},
	{"t": 500, "gems": 20}, {"t": 600, "gold": 600}, {"t": 700, "chest": "magic"}, {"t": 850, "gems": 30}, {"t": 1000, "chest": "gold"},
	{"t": 1250, "gold": 1200}, {"t": 1400, "chest": "magic"}, {"t": 1700, "gems": 50}, {"t": 1850, "chest": "crown"}, {"t": 2200, "gold": 2500},
	{"t": 2400, "chest": "magic"}, {"t": 2800, "gems": 100}, {"t": 3000, "chest": "crown"},
]

## Pass Essence : 20 paliers, 3 points par palier (1 point par couronne gagnée).
const PASS_STEP := 3
const PASS := [
	{"gold": 100}, {"chest": "wood"}, {"gems": 5}, {"gold": 200}, {"chest": "silver"}, {"gems": 8}, {"gold": 300}, {"chest": "gold"},
	{"gems": 12}, {"gold": 450}, {"chest": "silver"}, {"gems": 15}, {"gold": 600}, {"chest": "magic"}, {"gems": 20}, {"gold": 800},
	{"chest": "gold"}, {"gems": 30}, {"gold": 1200}, {"chest": "crown"},
]

## Succès : [id, texte, statistique, objectif, gemmes]
const ACHIEVEMENTS := [
	["win1", "Première victoire", "wins", 1, 10], ["win10", "Gagne 10 combats", "wins", 10, 25], ["win50", "Gagne 50 combats", "wins", 50, 80],
	["three1", "Victoire 3 couronnes", "three_crowns", 1, 15], ["three10", "10 victoires 3 couronnes", "three_crowns", 10, 50],
	["tow10", "Détruis 10 tours", "towers", 10, 15], ["tow100", "Détruis 100 tours", "towers", 100, 60],
	["dep100", "Déploie 100 unités", "deployed", 100, 15], ["dep1000", "Déploie 1000 unités", "deployed", 1000, 60],
	["troph500", "Atteins 500 trophées", "best_trophies", 500, 25], ["troph1500", "Atteins 1500 trophées", "best_trophies", 1500, 60],
	["troph3000", "Atteins 3000 trophées", "best_trophies", 3000, 150], ["lvl5", "Atteins le niveau 5", "level", 5, 30],
	["lvl10", "Atteins le niveau 10", "level", 10, 80], ["chests10", "Ouvre 10 coffres", "chests_opened", 10, 20],
	["chests50", "Ouvre 50 coffres", "chests_opened", 50, 70],
]

## Cadeaux de connexion (7 jours, puis on recommence).
const LOGIN := [{"gold": 100}, {"gems": 5}, {"chest": "silver"}, {"gold": 300}, {"gems": 10}, {"chest": "gold"}, {"chest": "magic"}]

const MODES := [
	{"id": "classic", "name": "1c1 Classique", "desc": "Le duel standard : 3 minutes pour tout raser.", "essence": 1.0, "start": 5.0, "time": 180.0, "trophies": true, "color": Color("2f86ff")},
	{"id": "double", "name": "Essence x2", "desc": "L'essence se recharge deux fois plus vite tout le match.", "essence": 2.0, "start": 7.0, "time": 180.0, "trophies": false, "color": Color("c23cf0")},
	{"id": "triple", "name": "Folie x3", "desc": "Essence x3 et 10 au départ. Chaos garanti !", "essence": 3.0, "start": 10.0, "time": 120.0, "trophies": false, "color": Color("ff8a1f")},
	{"id": "sudden", "name": "Mort subite", "desc": "La première tour détruite gagne la partie.", "essence": 1.0, "start": 5.0, "time": 120.0, "trophies": false, "sudden": true, "color": Color("f2384a")},
	{"id": "training", "name": "Entraînement", "desc": "Un adversaire plus calme pour tester tes decks.", "essence": 1.0, "start": 5.0, "time": 180.0, "trophies": false, "easy": true, "color": Color("4fc22a")},
]

const CHEST_TYPES := {
	"wood": {"name": "Coffre de Bois", "time": 30, "gold": [60, 120], "gems": [0, 2], "tint": Color("a0642a"), "weight": 60},
	"silver": {"name": "Coffre d'Argent", "time": 180, "gold": [200, 350], "gems": [1, 4], "tint": Color("aab4c8"), "weight": 28},
	"gold": {"name": "Coffre d'Or", "time": 480, "gold": [500, 800], "gems": [3, 8], "tint": Color("f4c542"), "weight": 9},
	"magic": {"name": "Coffre Magique", "time": 900, "gold": [1000, 1600], "gems": [8, 20], "tint": Color("b25cf0"), "weight": 3},
	"crown": {"name": "Coffre Couronne", "time": 0, "gold": [300, 500], "gems": [5, 10], "tint": Color("ffd23f"), "weight": 0},
}

const QUEST_POOL := [
	{"id": "win", "text": "Gagne %d combats", "goal": 2, "gold": 200, "gems": 3},
	{"id": "deploy", "text": "Déploie %d unités", "goal": 30, "gold": 150, "gems": 2},
	{"id": "towers", "text": "Détruis %d tours", "goal": 3, "gold": 250, "gems": 4},
	{"id": "spells", "text": "Lance %d sorts", "goal": 8, "gold": 150, "gems": 2},
	{"id": "crowns", "text": "Gagne %d couronnes", "goal": 6, "gold": 200, "gems": 3},
	{"id": "play", "text": "Joue %d combats", "goal": 3, "gold": 120, "gems": 2},
]

const TEAM_COLORS := [Color("2f86ff"), Color("ff3d4f")]
const TEAM_GLOW := [Color("6fd0ff"), Color("ff7a5c")]

var save = {}
var card_textures = {}
var chest_textures = {}

func _ready() -> void:
	load_save()

func unlocked(id: String) -> bool:
	return int(save.get("best_island", 0)) >= UNLOCK.get(id, 0) or island_for(int(save.trophies)).id >= UNLOCK.get(id, 0)

func playable() -> Array:
	var out = []
	for id in CARDS:
		if not CARDS[id].get("hidden", false):
			out.append(id)
	return out

func island_for(trophies: int) -> Dictionary:
	var isl: Dictionary = ISLANDS[0]
	for i in ISLANDS:
		if trophies >= i.trophies:
			isl = i
	return isl

func next_island(trophies: int):
	for i in ISLANDS:
		if i.trophies > trophies:
			return i
	return null

func xp_needed(level: int) -> int:
	return 100 + 60 * (level - 1)

## Ajoute de l'XP ; renvoie true si le joueur monte de niveau.
func add_xp(amount: int) -> bool:
	save.xp = int(save.xp) + amount
	var up = false
	while save.xp >= xp_needed(int(save.level)):
		save.xp -= xp_needed(int(save.level))
		save.level = int(save.level) + 1
		up = true
	return up

func roll_chest() -> String:
	var total = 0
	for k in CHEST_TYPES:
		total += CHEST_TYPES[k].weight
	var r = randi() % total
	for k in CHEST_TYPES:
		r -= CHEST_TYPES[k].weight
		if r < 0:
			return k
	return "wood"

func refresh_quests() -> void:
	var day = int(Time.get_unix_time_from_system() / 86400)
	if int(save.get("quest_day", -1)) == day and save.quests.size() == 3:
		return
	save.quest_day = day
	var pool = QUEST_POOL.duplicate()
	pool.shuffle()
	save.quests = []
	for q in pool.slice(0, 3):
		save.quests.append({"id": q.id, "progress": 0, "claimed": false})
	persist()

func quest_def(id: String) -> Dictionary:
	for q in QUEST_POOL:
		if q.id == id:
			return q
	return QUEST_POOL[0]

func quest_event(id: String, amount := 1) -> void:
	for q in save.quests:
		if q.id == id and not q.claimed:
			q.progress = min(quest_def(id).goal, int(q.progress) + amount)

func upgrade_cost(lvl: int) -> int:
	return 80 * lvl * lvl

func level_mult(lvl: int) -> float:
	return 1.0 + 0.1 * (lvl - 1)

func load_save() -> void:
	var levels = {}
	for id in playable():
		levels[id] = 1
	save = {"name": "Joueur", "trophies": 0, "gold": 500, "gems": 50, "deck": DEFAULT_DECK.duplicate(),
		"levels": levels, "wins": 0, "losses": 0, "muted": false, "music": true, "welcome": false, "last_free": 0,
		"level": 1, "xp": 0, "best_trophies": 0, "three_crowns": 0, "towers": 0, "deployed": 0, "chests": [null, null, null, null],
		"crown_progress": 0, "quests": [], "quest_day": -1, "mode": "classic", "clan_chat": [], "favorite": {},
		"best_island": 0, "road_claimed": [], "pass_points": 0, "pass_claimed": [], "ach_claimed": [], "chests_opened": 0,
		"login_day": -1, "login_index": 0, "deal_day": -1, "deals": [], "deals_bought": []}
	if FileAccess.file_exists(SAVE_PATH):
		var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			for k in parsed:
				if k == "levels":
					for c in parsed.levels:
						if levels.has(c):
							levels[c] = int(parsed.levels[c])
				else:
					save[k] = parsed[k]
			save.levels = levels
			save.trophies = int(save.trophies)
			save.gold = int(save.gold)
			save.gems = int(save.gems)
			var valid = []
			for id in save.deck:
				if CARDS.has(id) and not id in valid:
					valid.append(id)
			for id in DEFAULT_DECK:
				if valid.size() < 8 and not id in valid:
					valid.append(id)
			save.deck = valid.slice(0, 8)

func persist() -> void:
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(save))

func reset_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	load_save()
