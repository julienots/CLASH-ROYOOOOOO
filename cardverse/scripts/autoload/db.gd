extends Node
## Base de données du jeu : charge tout le contenu JSON (cartes, raretés, éléments, boosters…).
## Le contenu est indépendant du code : ajouter un fichier dans data/cards/ ajoute un set.

var cards := {}            # id -> Dictionary
var card_order: Array = [] # ids collectionnables, ordre d'album
var sets := []             # [{id, name, cards:[ids]}]
var rarities := {}
var rarity_order: Array = []
var variants := {}
var numbered := {}
var pity := {}
var elements := {}
var element_order: Array = []
var families := {}
var keywords := {}
var boosters: Array = []
var leaders: Array = []
var progression := {}
var events: Array = []
var layout := {}
var forge := {}
var products := {}
var tower := {}
var season := {}

var _tex_cache := {}

func _ready() -> void:
	var r: Dictionary = _json("res://data/rarities.json")
	rarities = r.rarities
	rarity_order = r.order
	variants = r.variants
	numbered = r.numbered
	pity = r.pity
	var e: Dictionary = _json("res://data/elements.json")
	elements = e.elements
	element_order = e.order
	families = e.families
	keywords = e.keywords
	boosters = _json("res://data/boosters.json").boosters
	leaders = _json("res://data/leaders.json").leaders
	progression = _json("res://data/progression.json")
	events = _json("res://data/events.json").events
	layout = _json("res://data/card_layout.json")
	forge = _json("res://data/forge.json")
	products = _json("res://data/products.json")
	tower = _json("res://data/tower.json")
	season = _json("res://data/season.json")
	var files := []
	for f in _list("res://data/cards", ".json"):
		files.append(_json("res://data/cards/" + f))
	files.sort_custom(func(a, b): return int(a.get("gen", 99)) < int(b.get("gen", 99)))
	for s in files:
		var ids := []
		for c in s.cards:
			c["set"] = s.set
			cards[c.id] = c
			if not c.get("token", false):
				ids.append(c.id)
		ids.sort_custom(_album_sort)
		sets.append({"id": s.set, "name": s.name, "gen": int(s.get("gen", 0)), "cards": ids})
		card_order.append_array(ids)
	print("CARDVERSE : %d cartes chargées (%d collectionnables, %d set(s))" % [cards.size(), card_order.size(), sets.size()])
	if card_order.is_empty():
		push_error("Aucune carte chargée : vérifier l'export de data/cards/*.json")

func _album_sort(a: String, b: String) -> bool:
	var ca: Dictionary = cards[a]
	var cb: Dictionary = cards[b]
	var ea := element_order.find(ca.element)
	var eb := element_order.find(cb.element)
	if ea != eb:
		return ea < eb
	var ra := rarity_order.find(ca.rarity)
	var rb := rarity_order.find(cb.rarity)
	if ra != rb:
		return ra < rb
	return a < b

func _json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Fichier introuvable : " + path)
		return {}
	var v = JSON.parse_string(f.get_as_text())
	if v == null:
		push_error("JSON invalide : " + path)
		return {}
	return v

func product(kind: String, id: String) -> Dictionary:
	for p in products.get(kind, []):
		if p.id == id:
			return p
	return {}

func puzzle_cfg() -> Dictionary:
	return _json_cache_get("puzzle")

var _rar_extra := {}

func _json_cache_get(k: String) -> Dictionary:
	if _rar_extra.is_empty():
		_rar_extra = _json("res://data/rarities.json")
	return _rar_extra.get(k, {})

func set_title(id: String) -> String:
	for s in sets:
		if s.id == id:
			return s.name
	return id

func _list(dir: String, ext: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d:
		for f in d.get_files():
			if f.ends_with(ext):
				out.append(f)
	out.sort()
	return out

# ---------------------------------------------------------------- accès
func card(id: String) -> Dictionary:
	return cards.get(id, {})

func rarity(r: String) -> Dictionary:
	return rarities.get(r, {})

func rarity_index(r: String) -> int:
	return rarity_order.find(r)

func rarity_color(r: String) -> Color:
	return Color(rarities.get(r, {}).get("color", "#ffffff"))

func element_color(e: String) -> Color:
	return Color(elements.get(e, {}).get("color", "#ffffff"))

func element_name(e: String) -> String:
	return elements.get(e, {}).get("name", e)

func family_name(f: String) -> String:
	return families.get(f, f)

func is_strong(att: String, def: String) -> bool:
	return def in elements.get(att, {}).get("strong", [])

func booster(id: String) -> Dictionary:
	for b in boosters:
		if b.id == id:
			return b
	return {}

func leader(id: String) -> Dictionary:
	for l in leaders:
		if l.id == id:
			return l
	return leaders[0]

func active_event() -> Dictionary:
	var today := Time.get_date_string_from_system()
	for ev in events:
		if ev.start <= today and today <= ev.end:
			return ev
	return {}

func power_of(id: String) -> int:
	var c := card(id)
	return int(c.get("atk", 0)) + int(c.get("hp", 0)) + rarity_index(c.get("rarity", "C")) * 2 + int(c.get("cost", 0))

# ---------------------------------------------------------------- textures
func tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex_cache[path] = t
	return t

func card_art(id: String) -> Texture2D:
	return tex("res://assets/cards/%s.png" % id)

func frame_tex(r: String) -> Texture2D:
	return tex("res://assets/ui/frames/%s.png" % r)

func icon(name: String) -> Texture2D:
	return tex("res://assets/ui/icons/%s.png" % name)

# ---------------------------------------------------------------- texte des capacités
func ability_text(c: Dictionary) -> String:
	var parts := []
	for k in c.get("keywords", []):
		parts.append("[b]%s[/b]" % keywords.get(k, {}).get("name", k))
	var line := ", ".join(parts)
	var lines := []
	if line != "":
		lines.append(line + ".")
	c_id_hint = c.get("id", "")
	for e in c.get("effects", []):
		lines.append(effect_text(e))
	if c.has("evolve"):
		var into := card(c.evolve.into)
		lines.append("[b]Évolution[/b] : après %d tours, devient %s." % [c.evolve.turns, into.get("name", "?")])
	return "\n".join(lines)

const TRIGGERS := {"summon": "Invocation", "death": "Dernier souffle", "turn_start": "Début de tour", "attack": "Attaque", "cast": ""}
const TARGETS := {
	"choose_enemy": "un ennemi", "choose_enemy_creature": "une créature ennemie", "choose_creature": "une créature",
	"choose_ally_creature": "une créature alliée", "enemy_leader": "le leader adverse", "ally_leader": "votre leader",
	"all_enemy_creatures": "toutes les créatures ennemies", "all_enemies": "tous les ennemis", "all_creatures": "toutes les créatures",
	"all_other_creatures": "toutes les autres créatures", "all_allies": "vos créatures", "all_enemy_creatures_silence": "toutes les créatures ennemies", "random_enemy": "un ennemi aléatoire",
	"random_enemy_creature": "une créature ennemie aléatoire", "random_ally_creature": "une créature alliée aléatoire",
	"self": "cette créature", "attack_target": "la cible", "strongest_enemy_creature": "la créature ennemie la plus puissante"}

var c_id_hint := ""

func effect_text(e: Dictionary) -> String:
	var trig: String = TRIGGERS.get(e.get("on", "cast"), "")
	var tgt: String = TARGETS.get(e.get("target", ""), "")
	var v := int(e.get("value", 0))
	var s := ""
	match e.do:
		"damage": s = "Inflige %d dégât%s à %s." % [v, "s" if v > 1 else "", tgt]
		"heal": s = ("Soigne entièrement %s." % tgt) if v >= 99 else ("Rend %d PV à %s." % [v, tgt])
		"buff": s = "Donne +%d/+%d à %s." % [v, int(e.get("value2", 0)), tgt]
		"freeze": s = "Gèle %s." % tgt
		"burn": s = "Brûle %s pendant %d tour%s (1 dégât par tour)." % [tgt, v, "s" if v > 1 else ""]
		"polymorph": s = "Métamorphose %s en %s." % [tgt, card(e.get("card", "cx90")).get("name", "Crapaud")]
		"copy": s = "Ajoute à votre main une copie de %s." % tgt
		"revive": s = ("Ressuscite votre dernière créature morte." if v <= 1 else "Ressuscite vos %d dernières créatures mortes." % v)
		"sleep": s = "Endort %s (ne peut pas attaquer pendant 2 tours)." % tgt
		"draw": s = "Piochez %d carte%s." % [v, "s" if v > 1 else ""]
		"summon": s = "Invoque %s." % card(e.card).get("name", "?")
		"shield": s = "Donne Bouclier à %s." % tgt
		"destroy": s = "Détruit %s." % tgt
		"add_card": s = ("Recyclage : ajoute une copie de cette carte à votre main." if e.card == c_id_hint else "Ajoute %s à votre main." % card(e.card).get("name", "?"))
		"swap_stats": s = "Échange l'ATQ et les PV de %s." % tgt
		"steal": s = "Prend le contrôle de %s." % tgt
		"swap_leaders": s = "Échange les PV des deux leaders."
		"silence": s = "Réduit au silence %s (perd mots-clés et effets)." % tgt
		"bounce": s = "Renvoie %s dans la main de son propriétaire." % tgt
		"energy": s = "Gagnez %d énergie ce tour-ci." % v
		"add_random": s = "Ajoute %d cartes %s ou mieux aléatoires à votre main." % [v, rarity(e.get("min_rarity", "L")).get("name", "")]
		_: s = e.do
	if trig != "":
		return "[b]%s[/b] : %s" % [trig, s.substr(0, 1).to_lower() + s.substr(1)]
	return s
