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
	"golem": {"name": "Golem de Basalte", "type": "unit", "cost": 6, "rarity": "epic",
		"desc": "Colosse de roche en fusion qui ne vise que les bâtiments. Se brise en 2 Éclats.",
		"hp": 3600, "dmg": 230, "hit_speed": 1.6, "speed": 0.85, "range": 1.0, "radius": 0.95,
		"targets": "buildings", "attack": "melee", "on_death": "shard", "death_count": 2, "heavy": true},
	"shard": {"name": "Éclat de Basalte", "type": "unit", "cost": 0, "rarity": "common", "hidden": true,
		"hp": 700, "dmg": 70, "hit_speed": 1.2, "speed": 1.1, "range": 0.8, "radius": 0.5,
		"targets": "buildings", "attack": "melee"},
	"archers": {"name": "Archères Sylvaines", "type": "unit", "cost": 3, "rarity": "common", "count": 2,
		"desc": "Duo d'archères elfiques. Touchent les unités aériennes et terrestres.",
		"hp": 300, "dmg": 95, "hit_speed": 1.0, "speed": 1.4, "range": 5.2, "radius": 0.4,
		"targets": "both", "attack": "arrow"},
	"pyro": {"name": "Pyromancien", "type": "unit", "cost": 5, "rarity": "rare",
		"desc": "Lance des boules de feu qui explosent en zone.",
		"hp": 640, "dmg": 210, "hit_speed": 1.7, "speed": 1.2, "range": 5.0, "radius": 0.45,
		"targets": "both", "attack": "fireball", "splash": 1.5},
	"swarm": {"name": "Nuée de Scarabées", "type": "unit", "cost": 2, "rarity": "common", "count": 6,
		"desc": "Six scarabées-gemmes voraces. Fragiles mais nombreux.",
		"hp": 85, "dmg": 70, "hit_speed": 0.9, "speed": 2.1, "range": 0.6, "radius": 0.3,
		"targets": "ground", "attack": "melee"},
	"storm": {"name": "Titan de l'Orage", "type": "unit", "cost": 7, "rarity": "legendary",
		"desc": "Géant blindé dont la foudre rebondit sur 3 cibles.",
		"hp": 2900, "dmg": 250, "hit_speed": 1.9, "speed": 0.9, "range": 4.5, "radius": 0.9,
		"targets": "both", "attack": "chain", "heavy": true},
	"shield": {"name": "Gardienne d'Airain", "type": "unit", "cost": 4, "rarity": "common",
		"desc": "Chevalière robuste protégée par un bouclier de 450 PV.",
		"hp": 1450, "shield": 450, "dmg": 175, "hit_speed": 1.2, "speed": 1.25, "range": 1.0, "radius": 0.5,
		"targets": "ground", "attack": "melee"},
	"sapper": {"name": "Sapeur Fou", "type": "unit", "cost": 2, "rarity": "rare",
		"desc": "Fonce sur un bâtiment et explose avec son tonneau de poudre.",
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
}

const DEFAULT_DECK := ["blade", "golem", "archers", "pyro", "swarm", "shield", "meteor", "frost"]

const TOWER := {
	"side": {"hp": 2100, "dmg": 85, "hit_speed": 0.8, "range": 7.5, "radius": 1.3},
	"core": {"hp": 3600, "dmg": 105, "hit_speed": 1.0, "range": 7.2, "radius": 1.8},
}

const ISLANDS := [
	{"id": 0, "name": "Île des Brumes", "trophies": 0, "grass": Color("58b847"), "grass2": Color("4ea83f"), "tile": Color("d8c9a3"), "water": Color("2ab7e8"), "sky": Color("8fd8ff"), "cliff": Color("8a6b4a"), "leaf": Color("3f9e3a")},
	{"id": 1, "name": "Île de Braise", "trophies": 300, "grass": Color("7a8a3c"), "grass2": Color("6d7c33"), "tile": Color("c9a98a"), "water": Color("ff6a1a"), "sky": Color("ffb27a"), "cliff": Color("5a3a2a"), "leaf": Color("d9661f")},
	{"id": 2, "name": "Île Givrée", "trophies": 700, "grass": Color("cfe7f2"), "grass2": Color("bcdbea"), "tile": Color("a7b8c9"), "water": Color("4fd2ff"), "sky": Color("b7d6ff"), "cliff": Color("7a8ca6"), "leaf": Color("e8f6ff")},
	{"id": 3, "name": "Île Céleste", "trophies": 1200, "grass": Color("8f6cd8"), "grass2": Color("7f5ec9"), "tile": Color("e6d7a8"), "water": Color("ffd84f"), "sky": Color("9a7bff"), "cliff": Color("5a4a8a"), "leaf": Color("ff9ad5")},
]

const TEAM_COLORS := [Color("2f86ff"), Color("ff3d4f")]
const TEAM_GLOW := [Color("6fd0ff"), Color("ff7a5c")]

var save = {}
var card_textures = {}

func _ready() -> void:
	load_save()

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

func upgrade_cost(lvl: int) -> int:
	return 80 * lvl * lvl

func level_mult(lvl: int) -> float:
	return 1.0 + 0.1 * (lvl - 1)

func load_save() -> void:
	var levels = {}
	for id in playable():
		levels[id] = 1
	save = {"name": "Joueur", "trophies": 0, "gold": 500, "gems": 50, "deck": DEFAULT_DECK.duplicate(),
		"levels": levels, "wins": 0, "losses": 0, "muted": false, "welcome": false, "last_free": 0}
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

func persist() -> void:
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(save))

func reset_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	load_save()
