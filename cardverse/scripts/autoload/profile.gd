extends Node
## Profil du joueur : monnaies, collection, decks, progression, missions, pity. Sauvegardé dans user://.

signal changed
signal toast(text: String, kind: String)

const SAVE_PATH := "user://cardverse_save.json"
const VERSION := 1

var d := {}  # toutes les données sauvegardées

func _ready() -> void:
	load_game()

# ---------------------------------------------------------------- sauvegarde
func new_game() -> void:
	var st: Dictionary = DB.progression.starter
	d = {
		"version": VERSION, "name": "Invocateur", "created": Time.get_unix_time_from_system(),
		"coins": int(st.coins), "crystals": int(st.crystals), "tokens": int(st.tokens), "event": int(st.event), "dust": 0,
		"free_boosters": int(st.free_boosters), "level": 1, "xp": 0,
		"collection": {}, "pity": {"legendary_plus": 0, "mythic_plus": 0},
		"serials": {}, "decks": [], "active_deck": 0, "stats": {},
		"daily": {}, "weekly": {}, "achievements": {}, "login": {"day": 0, "last": ""},
		"shop": {"date": "", "bought": []}, "cosmetics": {"owned": ["back_default", "board_default"], "back": "back_default", "board": "board_default"},
		"collection_rewards": [], "settings": {"sfx": true, "music": true, "fast": false},
		"rank": {"points": 0}, "title": "Novice",
		"free_packs": {}, "pass": {}, "forge_known": [], "tutorial_done": false, "seen_version": "0.5",
		"puzzles": {}, "puzzle_pity": 0, "displays": [], "gifts": ["v05", "v06", "v07", "v08"], "shop_once": [], "wheel": {}, "tower": {"floor": 1, "best": 0},
	}
	for id in st.cards:
		add_card(id, "", false)
	d.free_packs = {"multiverse": 1, "mecanica": 1}
	d.decks.append(_starter_deck())
	save_game()

func load_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var v = JSON.parse_string(f.get_as_text()) if f else null
		if v is Dictionary and v.get("version", 0) == VERSION:
			d = v
			_migrate()
			return
	new_game()

func _migrate() -> void:
	# compléter les clés absentes (sauvegardes d'anciennes versions du prototype)
	var defaults := {"dust": 0, "serials": {}, "collection_rewards": [], "rank": {"points": 0}, "title": "Novice", "event": 0,
		"free_packs": {}, "pass": {}, "forge_known": [], "tutorial_done": true, "seen_version": "0.1",
		"puzzles": {}, "puzzle_pity": 0, "displays": [], "gifts": []}
	for k in defaults:
		if not d.has(k):
			d[k] = defaults[k]
	# cadeau de mise à jour : boosters des nouvelles générations
	if not "v05" in d.gifts:
		d.gifts.append("v05")
		for k in {"eclipse": 1, "primal": 2, "mecanica": 3}:
			add_free(k, {"eclipse": 1, "primal": 2, "mecanica": 3}[k])
		d["pending_gift"] = true
	if not d.has("tower"):
		d.tower = {"floor": 1, "best": 0}
	if not "v07" in d.gifts:
		d.gifts.append("v07")
		add_free("pantheon", 3)
		d["pending_gift7"] = true
	if not "v08" in d.gifts:
		d.gifts.append("v08")
		add_free("corsaires", 2)
		add_free("jungle", 2)
		add_free("prestige", 1)
		d["pending_gift8"] = true
	if not d.has("shop_once"):
		d["shop_once"] = []
	if not "v06" in d.gifts:
		d.gifts.append("v06")
		add_free("songes", 3)
		d["pending_gift6"] = true
	# retirer les cartes qui n'existent plus dans le catalogue
	for id in d.collection.keys():
		if DB.card(id).is_empty():
			d.collection.erase(id)

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))
	changed.emit()

func reset() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	new_game()

# ---------------------------------------------------------------- monnaies
const CURRENCY_NAMES := {"coins": "Pièces", "crystals": "Cristaux", "tokens": "Jetons", "event": "Plumes", "dust": "Poussière"}

# ---------------------------------------------------------------- boosters gratuits
func free_count(bid: String) -> int:
	if bid == "classic":
		return int(d.free_boosters) + int(d.free_packs.get(bid, 0))
	return int(d.free_packs.get(bid, 0))

func add_free(bid: String, n: int) -> void:
	if bid == "classic":
		d.free_boosters = int(d.free_boosters) + n
	else:
		d.free_packs[bid] = int(d.free_packs.get(bid, 0)) + n

func use_free(bid: String) -> bool:
	if bid == "classic" and int(d.free_boosters) > 0:
		d.free_boosters = int(d.free_boosters) - 1
		return true
	if int(d.free_packs.get(bid, 0)) > 0:
		d.free_packs[bid] = int(d.free_packs[bid]) - 1
		return true
	return false

func total_free() -> int:
	var n := int(d.free_boosters)
	for k in d.free_packs:
		n += int(d.free_packs[k])
	return n

# ---------------------------------------------------------------- Tour des Dieux
## Valide un étage gagné : récompenses (premier passage complet, rejouer = pièces seulement). Renvoie {text, god_card?}.
func tower_win(n: int) -> Dictionary:
	var T: Array = DB.tower.floors
	var fl: Dictionary = T[clampi(n, 1, T.size()) - 1]
	var first: bool = n > int(d.tower.get("best", 0))
	var out := {}
	var parts := []
	if first:
		var rew: Dictionary = fl.reward.duplicate()
		var god := rew.has("god_card")
		rew.erase("god_card")
		give(rew, true)
		for k in rew:
			if k == "booster":
				parts.append("1 %s" % DB.booster(rew.booster).name)
			elif k != "xp":
				parts.append("+%d %s" % [int(rew[k]), cur_name(k, int(rew[k]))])
		if god:
			var gods := []
			for id in DB.card_order:
				if DB.card(id).rarity == "G":
					gods.append(id)
			var missing := gods.filter(func(x): return owned(x) == 0)
			var pick: String = (missing if not missing.is_empty() else gods).pick_random()
			add_card(pick)
			out.god_card = pick
			parts.append("CARTE GOD : %s !" % DB.card(pick).name)
		d.tower.best = n
		d.tower.floor = mini(n + 1, T.size())
		stat("tower_floors")
	else:
		give({"coins": 60 + 5 * n}, true)
		parts.append("+%d Pièces (étage déjà franchi)" % (60 + 5 * n))
	out.text = " · ".join(parts)
	save_game()
	return out

# ---------------------------------------------------------------- puzzles SWAP
func pieces(id: String) -> Array:
	return d.puzzles.get(id, [])

## Ajoute une pièce. Renvoie {"dup": bool, "complete": bool, "count": n, "total": n, "new_card": bool}.
func add_piece(id: String, piece: int) -> Dictionary:
	var total := int(DB.rarity("SW").pieces)
	var have: Array = d.puzzles.get(id, [])
	var res := {"dup": false, "complete": false, "count": 0, "total": total, "new_card": false}
	if piece in have:
		res.dup = true
		d.dust = get_cur("dust") + int(DB.puzzle_cfg().duplicate_dust)
	else:
		have.append(piece)
		d.puzzles[id] = have
		if have.size() >= total:
			res.complete = true
			res.new_card = add_card(id)
			stat("swap_completed")
	stat("puzzle_pieces")
	res.count = have.size()
	return res

# ---------------------------------------------------------------- passe de saison
func pass_data() -> Dictionary:
	if d.pass.get("season", "") != DB.season.get("id", ""):
		d.pass = {"season": DB.season.get("id", ""), "xp": 0, "elite": false, "free": [], "elite_claimed": []}
	return d.pass

func pass_tier() -> int:
	return mini(DB.season.tiers.size(), int(pass_data().xp) / int(DB.season.xp_per_tier))

func claim_pass(tier: int, elite: bool) -> bool:
	var pd := pass_data()
	var key := "elite_claimed" if elite else "free"
	if tier > pass_tier() or tier in pd[key] or (elite and not pd.elite):
		return false
	pd[key].append(tier)
	var t: Dictionary = DB.season.tiers[tier - 1]
	give(t.elite if elite else t.free)
	return true

func buy_elite() -> bool:
	var pd := pass_data()
	if pd.elite or not pay(DB.season.elite_price):
		return false
	pd.elite = true
	save_game()
	return true

func pass_pending() -> int:
	var pd := pass_data()
	var n := 0
	for t in range(1, pass_tier() + 1):
		if not t in pd.free:
			n += 1
		if pd.elite and not t in pd.elite_claimed:
			n += 1
	return n

func cur_name(k: String, n: int) -> String:
	var s: String = CURRENCY_NAMES.get(k, k)
	return s.trim_suffix("s") if n == 1 and k != "dust" else s

func get_cur(c: String) -> int:
	return int(d.get(c, 0))

func can_pay(price: Dictionary) -> bool:
	for c in price:
		if get_cur(c) < int(price[c]):
			return false
	return true

func pay(price: Dictionary) -> bool:
	if not can_pay(price):
		return false
	for c in price:
		d[c] = get_cur(c) - int(price[c])
	save_game()
	return true

var last_given_card := ""

func give(rew: Dictionary, silent := false) -> void:
	var parts := []
	for k in rew:
		match k:
			"xp":
				add_xp(int(rew.xp))
			"booster":
				var bid: String = rew.booster if rew.booster is String else "classic"
				add_free(bid, 1)
				parts.append("1 %s gratuit" % DB.booster(bid).get("name", "booster"))
			"boosters":
				for bid in rew.boosters:
					add_free(bid, int(rew.boosters[bid]))
					parts.append("%d %s" % [int(rew.boosters[bid]), DB.booster(bid).get("name", "booster")])
			"random_card":
				var pool := []
				for id in DB.card_order:
					var c := DB.card(id)
					if c.rarity == rew.random_card.rarity and (not rew.random_card.has("sets") or c.set in rew.random_card.sets):
						pool.append(id)
				if not pool.is_empty():
					var pick: String = pool[randi() % pool.size()]
					add_card(pick)
					last_given_card = pick
					parts.append(DB.card(pick).name)
			"cosmetic":
				if not rew.cosmetic in d.cosmetics.owned:
					d.cosmetics.owned.append(rew.cosmetic)
				parts.append("cosmétique exclusif")
			"coins", "crystals", "tokens", "event", "dust":
				d[k] = get_cur(k) + int(rew[k])
				parts.append("+%d %s" % [int(rew[k]), cur_name(k, int(rew[k]))])
	save_game()
	if not silent and parts.size() > 0:
		toast.emit(", ".join(parts), "reward")

# ---------------------------------------------------------------- niveau
func xp_needed(level: int) -> int:
	var t: Array = DB.progression.level_xp
	return int(t[min(level, t.size() - 1)]) if level < t.size() else int(t[-1]) + (level - t.size() + 1) * 4000

func add_xp(n: int) -> void:
	d.xp = int(d.xp) + n
	var pd := pass_data()
	var before := pass_tier()
	pd.xp = int(pd.xp) + n
	if pass_tier() > before:
		toast.emit("Passe de saison : palier %d atteint !" % pass_tier(), "level")
	while int(d.xp) >= xp_needed(int(d.level)):
		d.level = int(d.level) + 1
		var lr: Dictionary = DB.progression.level_rewards
		d.coins = get_cur("coins") + int(lr.coins)
		d.crystals = get_cur("crystals") + int(lr.crystals)
		if int(d.level) % int(lr.tokens_every) == 0:
			d.tokens = get_cur("tokens") + 1
		toast.emit("Niveau %d atteint ! +%d Pièces, +%d Cristaux" % [d.level, lr.coins, lr.crystals], "level")
		_update_title()

func _update_title() -> void:
	var lv := int(d.level)
	d.title = "Novice" if lv < 3 else ("Invocateur" if lv < 6 else ("Duelliste" if lv < 10 else ("Maître des Cartes" if lv < 15 else "Légende du Cardverse")))

# ---------------------------------------------------------------- collection
func owned(id: String) -> int:
	return int(d.collection.get(id, {}).get("count", 0))

func entry(id: String) -> Dictionary:
	return d.collection.get(id, {})

## Ajoute une carte ; renvoie true si c'est une nouveauté.
func add_card(id: String, variant := "", track := true) -> bool:
	var is_new: bool = not d.collection.has(id)
	if is_new:
		d.collection[id] = {"count": 0, "first": Time.get_unix_time_from_system(), "variants": {}, "fav": false}
	var e: Dictionary = d.collection[id]
	e.count = int(e.count) + 1
	if variant != "":
		e.variants[variant] = int(e.variants.get(variant, 0)) + 1
		if track:
			stat("variants_found")
	var r: String = DB.card(id).rarity
	if r in DB.numbered.rarities:
		var n := int(d.serials.get(id, 0)) + 1
		d.serials[id] = n
		e["serial"] = e.get("serial", randi_range(1, int(DB.numbered.print_run)))
	if track:
		if is_new:
			stat("new_cards")
		var ri := DB.rarity_index(r)
		if ri >= DB.rarity_index("L"):
			stat("legendary_pulls")
		if ri >= DB.rarity_index("M"):
			stat("mythic_pulls")
		d.stats["unique_cards"] = unique_count()
	return is_new

func toggle_fav(id: String) -> void:
	if d.collection.has(id):
		d.collection[id].fav = not d.collection[id].get("fav", false)
		save_game()

func discovered(id: String) -> bool:
	return d.collection.has(id)

func unique_count() -> int:
	var n := 0
	for id in d.collection:
		if int(d.collection[id].count) > 0:
			n += 1
	return n

func completion(set_id := "") -> float:
	var tot := 0
	var have := 0
	for id in DB.card_order:
		if set_id != "" and DB.card(id).set != set_id:
			continue
		tot += 1
		if owned(id) > 0:
			have += 1
	return float(have) / max(1, tot)

## Retire un exemplaire (Atelier). L'entrée reste : la carte reste « découverte ».
func remove_card(id: String, n := 1) -> bool:
	if owned(id) < n:
		return false
	d.collection[id].count = owned(id) - n
	d.stats["unique_cards"] = unique_count()
	return true

## Recycle les exemplaires au-delà de 3 (2 pour les raretés limitées à 1 en deck) contre de la poussière.
func recycle_duplicates() -> int:
	var total := 0
	for id in d.collection:
		var c := DB.card(id)
		var keep := 3
		var extra := int(d.collection[id].count) - keep
		if extra > 0:
			total += extra * int(DB.rarity(c.rarity).dust)
			d.collection[id].count = keep
	d.dust = get_cur("dust") + total
	save_game()
	return total

## Récompenses de complétion (élément complet, set complet).
func check_collection_rewards() -> void:
	var cr: Dictionary = DB.progression.collection_rewards
	for el in DB.element_order:
		var key: String = "el_" + el
		if key in d.collection_rewards:
			continue
		var all := true
		for id in DB.card_order:
			if DB.card(id).element == el and owned(id) == 0:
				all = false
				break
		if all:
			d.collection_rewards.append(key)
			give(cr.element, true)
			toast.emit("Collection %s complète ! +%d Cristaux" % [DB.element_name(el), cr.element.crystals], "reward")
	for s in DB.sets:
		var key2: String = "set_" + s.id
		if key2 in d.collection_rewards:
			continue
		var all2 := true
		for id in s.cards:
			if owned(id) == 0:
				all2 = false
				break
		if all2:
			d.collection_rewards.append(key2)
			give(cr.set, true)
			toast.emit("Set %s complet !" % s.name, "reward")

# ---------------------------------------------------------------- decks
const DECK_SIZE := 20

func _starter_deck() -> Dictionary:
	var ids := []
	for id in DB.progression.starter.cards:
		if ids.size() < DECK_SIZE:
			ids.append(id)
	return {"name": "Deck de départ", "leader": "pyra", "cards": ids}

func active_deck() -> Dictionary:
	var i: int = clampi(int(d.active_deck), 0, d.decks.size() - 1)
	return d.decks[i]

func deck_count(deck: Dictionary, id: String) -> int:
	return deck.cards.count(id)

func deck_max(id: String) -> int:
	return int(DB.rarity(DB.card(id).rarity).deck_max)

func can_add_to_deck(deck: Dictionary, id: String) -> String:
	if deck.cards.size() >= DECK_SIZE:
		return "Le deck est complet (%d cartes)." % DECK_SIZE
	if deck_count(deck, id) >= deck_max(id):
		return "Maximum %d exemplaire(s) de cette rareté." % deck_max(id)
	if deck_count(deck, id) >= owned(id):
		return "Tu ne possèdes pas assez d'exemplaires."
	return ""

func deck_valid(deck: Dictionary) -> bool:
	if deck.cards.size() != DECK_SIZE:
		return false
	for id in deck.cards:
		if deck_count(deck, id) > owned(id):
			return false
	return true

# ---------------------------------------------------------------- statistiques / missions
func stat(key: String, n := 1) -> void:
	d.stats[key] = int(d.stats.get(key, 0)) + n
	_progress_quests(key, n)

func _period_key(weekly: bool) -> String:
	var t := Time.get_datetime_dict_from_system()
	if not weekly:
		return Time.get_date_string_from_system()
	var unix := Time.get_unix_time_from_system()
	return "W%d" % int((unix / 86400.0 + 3) / 7)  # semaines commençant le lundi

func refresh_quests() -> void:
	var day := _period_key(false)
	if d.daily.get("key", "") != day:
		var pool: Array = DB.progression.daily_pool.duplicate()
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(day)
		var picks := []
		while picks.size() < 3 and pool.size() > 0:
			picks.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)).id)
		d.daily = {"key": day, "quests": picks, "progress": {}, "claimed": []}
	var wk := _period_key(true)
	if d.weekly.get("key", "") != wk:
		d.weekly = {"key": wk, "progress": {}, "claimed": []}

func _progress_quests(key: String, n: int) -> void:
	refresh_quests()
	for q in daily_quests():
		if q.stat == key:
			d.daily.progress[q.id] = int(d.daily.progress.get(q.id, 0)) + n
	for q in DB.progression.weekly:
		if q.stat == key:
			d.weekly.progress[q.id] = int(d.weekly.progress.get(q.id, 0)) + n

func daily_quests() -> Array:
	var out := []
	for q in DB.progression.daily_pool:
		if q.id in d.daily.get("quests", []):
			out.append(q)
	return out

func quest_progress(q: Dictionary, weekly: bool) -> int:
	var src: Dictionary = d.weekly if weekly else d.daily
	return int(src.get("progress", {}).get(q.id, 0))

func quest_claimed(q: Dictionary, weekly: bool) -> bool:
	return q.id in (d.weekly if weekly else d.daily).get("claimed", [])

func claim_quest(q: Dictionary, weekly: bool) -> bool:
	if quest_claimed(q, weekly) or quest_progress(q, weekly) < int(q.goal):
		return false
	(d.weekly if weekly else d.daily).claimed.append(q.id)
	give(q.reward)
	return true

func achievement_progress(a: Dictionary) -> int:
	return int(d.stats.get(a.stat, 0))

func claim_achievement(a: Dictionary) -> bool:
	if d.achievements.has(a.id) or achievement_progress(a) < int(a.goal):
		return false
	d.achievements[a.id] = Time.get_unix_time_from_system()
	give(a.reward)
	return true

func pending_rewards() -> int:
	refresh_quests()
	var n := 0
	for q in daily_quests():
		if not quest_claimed(q, false) and quest_progress(q, false) >= int(q.goal):
			n += 1
	for q in DB.progression.weekly:
		if not quest_claimed(q, true) and quest_progress(q, true) >= int(q.goal):
			n += 1
	for a in DB.progression.achievements:
		if not d.achievements.has(a.id) and achievement_progress(a) >= int(a.goal):
			n += 1
	return n

# ---------------------------------------------------------------- connexion quotidienne
func login_available() -> bool:
	return d.login.get("last", "") != Time.get_date_string_from_system()

func claim_login() -> Dictionary:
	if not login_available():
		return {}
	var cal: Array = DB.progression.login_calendar
	var day := int(d.login.get("day", 0)) % cal.size()
	var rew: Dictionary = cal[day]
	d.login.day = day + 1
	d.login.last = Time.get_date_string_from_system()
	give(rew)
	return rew
