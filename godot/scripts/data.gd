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
		"crown_progress": 0, "quests": [], "quest_day": -1, "mode": "classic", "clan_chat": [], "favorite": {}}
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
