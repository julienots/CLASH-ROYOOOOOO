class_name BattleEngine extends RefCounted
## Moteur de règles du combat 1 contre 1 (indépendant de l'affichage).
## Chaque action ajoute des événements à `events` ; la vue les dépile pour animer.

const MAX_BOARD := 5
const MAX_HAND := 9
const MAX_ENERGY := 10

var pl := [{}, {}]
var current := 0
var turn := 0
var winner := -1          # -1 en cours, 0/1 vainqueur, 2 égalité
var events: Array = []
var rng := RandomNumberGenerator.new()
var _uid := 0
var _hid := 0
var stats := {"cards_played": 0, "creatures_summoned": 0, "spells_cast": 0, "leader_damage": 0, "evolutions": 0}

# ======================================================================= mise en place
func setup(deck0: Array, leader0: String, deck1: Array, leader1: String, seed_v := 0, enemy_hp := 0) -> void:
	rng.seed = seed_v if seed_v != 0 else randi()
	for i in 2:
		var ld: Dictionary = DB.leader(leader0 if i == 0 else leader1)
		var hp := int(ld.hp) if (i == 0 or enemy_hp <= 0) else enemy_hp
		var deck: Array = (deck0 if i == 0 else deck1).duplicate()
		_shuffle(deck)
		pl[i] = {"leader": {"id": ld.id, "name": ld.name, "element": ld.element, "hp": hp, "max_hp": hp, "power": ld.power, "power_used": false},
			"deck": deck, "hand": [], "board": [], "energy": 0, "max_energy": 0, "fatigue": 0}
	current = rng.randi_range(0, 1)
	for i in 2:
		draw(i, 3 if i == current else 4)
	start_turn()

func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

func ev(e: Dictionary) -> void:
	events.append(e)

func take_events() -> Array:
	var e := events
	events = []
	return e

func opp(i: int) -> int:
	return 1 - i

# ======================================================================= tours
func start_turn() -> void:
	turn += 1
	var P: Dictionary = pl[current]
	P.max_energy = mini(MAX_ENERGY, int(P.max_energy) + 1)
	P.energy = P.max_energy
	P.leader.power_used = false
	ev({"t": "turn", "p": current, "turn": turn})
	for u in P.board.duplicate():
		u.sleep = false
		u.attacked = false
		u.age = int(u.age) + 1
	# évolutions
	for u in P.board.duplicate():
		var c := DB.card(u.id)
		if c.has("evolve") and int(u.age) >= int(c.evolve.turns) and u.hp > 0:
			_evolve(u, c.evolve.into)
	# effets de début de tour
	for u in P.board.duplicate():
		if u.hp > 0:
			_trigger(u, "turn_start", {})
	cleanup()
	if winner < 0:
		draw(current, 1)
	cleanup()

func end_turn() -> void:
	if winner >= 0:
		return
	for u in pl[current].board:
		u.frozen = 0
	ev({"t": "end", "p": current})
	current = opp(current)
	start_turn()

func _evolve(u: Dictionary, into: String) -> void:
	var c := DB.card(into)
	var from: String = u.id
	u.id = into
	u.atk = int(c.atk)
	u.hp = int(c.hp)
	u.max_hp = int(c.hp)
	u.age = 0
	u.kw = _kw(c)
	u.sleep = false
	stats.evolutions += 1 if u.owner == 0 else 0
	ev({"t": "evolve", "uid": u.uid, "from": from, "to": into, "unit": u.duplicate(true)})

# ======================================================================= pioche
func draw(i: int, n: int) -> void:
	for k in n:
		var P: Dictionary = pl[i]
		if P.deck.is_empty():
			P.fatigue = int(P.fatigue) + 1
			ev({"t": "fatigue", "p": i, "amount": P.fatigue})
			damage({"k": "leader", "p": i}, int(P.fatigue), null)
			continue
		var id: String = P.deck.pop_back()
		if P.hand.size() >= MAX_HAND:
			ev({"t": "burn", "p": i, "id": id})
			continue
		_hid += 1
		var h := {"hid": _hid, "id": id}
		P.hand.append(h)
		ev({"t": "draw", "p": i, "card": h})

func add_to_hand(i: int, id: String) -> void:
	if pl[i].hand.size() >= MAX_HAND:
		return
	_hid += 1
	var h := {"hid": _hid, "id": id}
	pl[i].hand.append(h)
	ev({"t": "draw", "p": i, "card": h, "generated": true})

# ======================================================================= requêtes
func find_hand(i: int, hid: int) -> Dictionary:
	for h in pl[i].hand:
		if int(h.hid) == hid:
			return h
	return {}

func find_unit(uid: int) -> Dictionary:
	for i in 2:
		for u in pl[i].board:
			if int(u.uid) == uid:
				return u
	return {}

func unit_slot(uid: int) -> int:
	for i in 2:
		for k in pl[i].board.size():
			if int(pl[i].board[k].uid) == uid:
				return k
	return -1

## Type de cible à choisir pour jouer la carte ("" si aucune).
func needs_target(id: String) -> String:
	for e in DB.card(id).get("effects", []):
		var on: String = e.get("on", "cast")
		if (on == "cast" or on == "summon") and str(e.get("target", "")).begins_with("choose_"):
			return e.target
	return ""

func targets_for(i: int, ttype: String) -> Array:
	var out := []
	var o := opp(i)
	match ttype:
		"choose_enemy":
			for u in pl[o].board:
				if not u.kw.get("furtif", false):
					out.append({"k": "unit", "uid": u.uid})
			out.append({"k": "leader", "p": o})
		"choose_enemy_creature":
			for u in pl[o].board:
				if not u.kw.get("furtif", false):
					out.append({"k": "unit", "uid": u.uid})
		"choose_ally_creature":
			for u in pl[i].board:
				out.append({"k": "unit", "uid": u.uid})
		"choose_creature":
			for u in pl[i].board + pl[o].board:
				if u.owner == i or not u.kw.get("furtif", false):
					out.append({"k": "unit", "uid": u.uid})
	return out

func can_play(i: int, hid: int) -> String:
	if winner >= 0 or i != current:
		return "Ce n'est pas ton tour."
	var h := find_hand(i, hid)
	if h.is_empty():
		return "Carte introuvable."
	var c := DB.card(h.id)
	if int(c.cost) > int(pl[i].energy):
		return "Pas assez d'énergie."
	if c.type == "creature" and pl[i].board.size() >= MAX_BOARD:
		return "Ton terrain est plein."
	var t := needs_target(h.id)
	if t != "" and c.type == "spell" and targets_for(i, t).is_empty():
		return "Aucune cible valide."
	return ""

func can_attack(uid: int) -> bool:
	var u := find_unit(uid)
	if u.is_empty() or winner >= 0 or u.owner != current:
		return false
	if u.attacked or int(u.frozen) > 0 or int(u.atk) <= 0:
		return false
	if u.sleep and not u.kw.get("celerite", false):
		return false
	return true

func attack_targets(uid: int) -> Array:
	var u := find_unit(uid)
	if u.is_empty():
		return []
	var o := opp(u.owner)
	var guards := []
	var all := []
	for e in pl[o].board:
		if e.kw.get("furtif", false):
			continue
		all.append({"k": "unit", "uid": e.uid})
		if e.kw.get("garde", false):
			guards.append({"k": "unit", "uid": e.uid})
	if not guards.is_empty():
		return guards
	all.append({"k": "leader", "p": o})
	return all

func can_use_power(i: int) -> bool:
	var L: Dictionary = pl[i].leader
	return winner < 0 and i == current and not L.power_used and int(pl[i].energy) >= int(L.power.cost)

# ======================================================================= actions
func play(i: int, hid: int, target = null) -> bool:
	if can_play(i, hid) != "":
		return false
	var h := find_hand(i, hid)
	var c := DB.card(h.id)
	pl[i].hand.erase(h)
	pl[i].energy = int(pl[i].energy) - int(c.cost)
	if i == 0:
		stats.cards_played += 1
	ev({"t": "play", "p": i, "hid": hid, "id": h.id, "target": target})
	if c.type == "creature":
		var u := summon(i, h.id)
		if not u.is_empty():
			_trigger(u, "summon", {"chosen": target})
	else:
		if i == 0:
			stats.spells_cast += 1
		ev({"t": "spell", "p": i, "id": h.id, "target": target})
		for e in c.get("effects", []):
			if e.get("on", "cast") == "cast":
				resolve(e, i, {}, {"chosen": target})
				cleanup()
	cleanup()
	return true

func summon(i: int, id: String) -> Dictionary:
	if pl[i].board.size() >= MAX_BOARD:
		return {}
	var c := DB.card(id)
	_uid += 1
	var u := {"uid": _uid, "id": id, "owner": i, "atk": int(c.atk), "hp": int(c.hp), "max_hp": int(c.hp), "kw": _kw(c),
		"frozen": 0, "sleep": true, "attacked": false, "age": 0}
	pl[i].board.append(u)
	if i == 0:
		stats.creatures_summoned += 1
	ev({"t": "summon", "p": i, "unit": u.duplicate(true), "slot": pl[i].board.size() - 1})
	return u

func _kw(c: Dictionary) -> Dictionary:
	var k := {}
	for w in c.get("keywords", []):
		k[w] = true
	return k

func attack(uid: int, target: Dictionary) -> bool:
	if not can_attack(uid):
		return false
	var valid := false
	for t in attack_targets(uid):
		if t.k == target.k and t.get("uid", -1) == target.get("uid", -1) and t.get("p", -1) == target.get("p", -1):
			valid = true
	if not valid:
		return false
	var a := find_unit(uid)
	a.attacked = true
	a.kw.erase("furtif")
	ev({"t": "attack", "uid": uid, "target": target})
	if target.k == "unit":
		var d := find_unit(target.uid)
		var dmg_a := calc(int(a.atk), DB.card(a.id).element, DB.card(d.id).element)
		var dmg_d := calc(int(d.atk), DB.card(d.id).element, DB.card(a.id).element)
		damage(target, dmg_a, a, DB.is_strong(DB.card(a.id).element, DB.card(d.id).element))
		if dmg_d > 0:
			damage({"k": "unit", "uid": uid}, dmg_d, d, DB.is_strong(DB.card(d.id).element, DB.card(a.id).element))
	else:
		var lel: String = pl[target.p].leader.element
		damage(target, calc(int(a.atk), DB.card(a.id).element, lel), a, DB.is_strong(DB.card(a.id).element, lel))
	if a.hp > 0 or true:
		_trigger(a, "attack", {"attack_target": target})
	cleanup()
	return true

func calc(atk: int, att_el: String, def_el: String) -> int:
	return int(ceil(atk * 1.5)) if DB.is_strong(att_el, def_el) else atk

func use_power(i: int) -> bool:
	if not can_use_power(i):
		return false
	var L: Dictionary = pl[i].leader
	L.power_used = true
	pl[i].energy = int(pl[i].energy) - int(L.power.cost)
	ev({"t": "power", "p": i})
	for e in L.power.effects:
		resolve(e, i, {}, {})
		cleanup()
	return true

# ======================================================================= effets
func _trigger(u: Dictionary, on: String, ctx: Dictionary) -> void:
	for e in DB.card(u.id).get("effects", []):
		if e.get("on", "") == on:
			resolve(e, int(u.owner), u, ctx)

func _units(i: int) -> Array:
	return pl[i].board.duplicate()

func resolve_targets(e: Dictionary, i: int, src: Dictionary, ctx: Dictionary) -> Array:
	var o := opp(i)
	var out := []
	match str(e.get("target", "")):
		"choose_enemy", "choose_enemy_creature", "choose_creature", "choose_ally_creature":
			var t = ctx.get("chosen")
			if t is Dictionary and not t.is_empty():
				out.append(t)
		"enemy_leader":
			out.append({"k": "leader", "p": o})
		"ally_leader":
			out.append({"k": "leader", "p": i})
		"all_enemy_creatures":
			for u in _units(o):
				out.append({"k": "unit", "uid": u.uid})
		"all_enemies":
			for u in _units(o):
				out.append({"k": "unit", "uid": u.uid})
			out.append({"k": "leader", "p": o})
		"all_creatures":
			for u in _units(i) + _units(o):
				out.append({"k": "unit", "uid": u.uid})
		"all_other_creatures":
			for u in _units(i) + _units(o):
				if src.is_empty() or u.uid != src.uid:
					out.append({"k": "unit", "uid": u.uid})
		"all_allies":
			for u in _units(i):
				out.append({"k": "unit", "uid": u.uid})
		"random_enemy":
			var pool := []
			for u in _units(o):
				pool.append({"k": "unit", "uid": u.uid})
			pool.append({"k": "leader", "p": o})
			out.append(pool[rng.randi_range(0, pool.size() - 1)])
		"random_enemy_creature":
			var us := _units(o)
			if not us.is_empty():
				out.append({"k": "unit", "uid": us[rng.randi_range(0, us.size() - 1)].uid})
		"random_ally_creature":
			var us2 := _units(i)
			if not us2.is_empty():
				out.append({"k": "unit", "uid": us2[rng.randi_range(0, us2.size() - 1)].uid})
		"self":
			if not src.is_empty():
				out.append({"k": "unit", "uid": src.uid})
		"attack_target":
			if ctx.has("attack_target"):
				out.append(ctx.attack_target)
		"strongest_enemy_creature":
			var best := {}
			for u in _units(o):
				if best.is_empty() or int(u.atk) + int(u.hp) > int(best.atk) + int(best.hp):
					best = u
			if not best.is_empty():
				out.append({"k": "unit", "uid": best.uid})
	# retirer les unités mortes ou disparues
	var alive := []
	for t in out:
		if t.k == "leader" or (not find_unit(t.uid).is_empty() and find_unit(t.uid).hp > 0):
			alive.append(t)
	return alive

func resolve(e: Dictionary, i: int, src: Dictionary, ctx: Dictionary) -> void:
	var v := int(e.get("value", 0))
	var src_ref := {"k": "unit", "uid": src.uid} if not src.is_empty() else {"k": "leader", "p": i}
	match e.do:
		"draw":
			draw(i, v)
			return
		"summon":
			if pl[i].board.size() < MAX_BOARD:
				ev({"t": "fx", "kind": "summon_fx", "src": src_ref})
				summon(i, e.card)
			return
		"add_random":
			var min_i := DB.rarity_index(e.get("min_rarity", "L"))
			var pool := []
			for id in DB.card_order:
				if DB.rarity_index(DB.card(id).rarity) >= min_i and id != "x001":
					pool.append(id)
			for k in v:
				add_to_hand(i, pool[rng.randi_range(0, pool.size() - 1)])
			return
	var targets := resolve_targets(e, i, src, ctx)
	if targets.is_empty():
		return
	ev({"t": "fx", "kind": e.do, "src": src_ref, "targets": targets, "element": DB.card(src.id).element if not src.is_empty() else pl[i].leader.element})
	for t in targets:
		match e.do:
			"damage":
				damage(t, v, null)
			"heal":
				heal(t, v)
			"buff":
				if t.k == "unit":
					var u := find_unit(t.uid)
					u.atk = int(u.atk) + v
					u.hp = int(u.hp) + int(e.get("value2", 0))
					u.max_hp = int(u.max_hp) + int(e.get("value2", 0))
					ev({"t": "buff", "uid": u.uid, "atk": u.atk, "hp": u.hp, "max_hp": u.max_hp})
			"freeze":
				if t.k == "unit":
					find_unit(t.uid).frozen = 1
					ev({"t": "freeze", "uid": t.uid})
			"shield":
				if t.k == "unit":
					find_unit(t.uid).kw["bouclier"] = true
					ev({"t": "shield", "uid": t.uid, "on": true})
			"destroy":
				if t.k == "unit":
					var u2 := find_unit(t.uid)
					u2.hp = 0
					ev({"t": "destroy", "uid": t.uid})

func damage(t: Dictionary, amount: int, source, adv := false) -> int:
	if amount <= 0:
		return 0
	if t.k == "leader":
		var L: Dictionary = pl[t.p].leader
		L.hp = int(L.hp) - amount
		if t.p == 1:
			stats.leader_damage += amount
		ev({"t": "damage", "target": t, "amount": amount, "hp": L.hp, "adv": adv})
		_lifesteal(source, amount)
		if L.hp <= 0 and winner < 0:
			_check_winner()
		return amount
	var u := find_unit(t.uid)
	if u.is_empty() or u.hp <= 0:
		return 0
	if u.kw.get("bouclier", false):
		u.kw.erase("bouclier")
		ev({"t": "shield", "uid": u.uid, "on": false})
		return 0
	u.hp = int(u.hp) - amount
	ev({"t": "damage", "target": t, "amount": amount, "hp": u.hp, "adv": adv})
	_lifesteal(source, amount)
	if source is Dictionary and not source.is_empty() and source.kw.get("poison", false) and u.hp > 0:
		u.hp = 0
		ev({"t": "poison", "uid": u.uid})
	if u.hp > 0 and u.kw.get("rage", false):
		u.atk = int(u.atk) + 1
		ev({"t": "buff", "uid": u.uid, "atk": u.atk, "hp": u.hp, "max_hp": u.max_hp, "rage": true})
	return amount

func _lifesteal(source, amount: int) -> void:
	if source is Dictionary and not source.is_empty() and source.kw.get("vol_de_vie", false):
		heal({"k": "leader", "p": int(source.owner)}, amount)

func heal(t: Dictionary, v: int) -> void:
	if t.k == "leader":
		var L: Dictionary = pl[t.p].leader
		var before := int(L.hp)
		L.hp = mini(int(L.max_hp), int(L.hp) + v)
		if L.hp != before:
			ev({"t": "heal", "target": t, "amount": int(L.hp) - before, "hp": L.hp})
	else:
		var u := find_unit(t.uid)
		if u.is_empty():
			return
		var b := int(u.hp)
		u.hp = mini(int(u.max_hp), int(u.hp) + v)
		if u.hp != b:
			ev({"t": "heal", "target": t, "amount": int(u.hp) - b, "hp": u.hp})

## Retire les créatures mortes (déclenche les Derniers souffles) et vérifie la victoire.
func cleanup() -> void:
	var guard := 0
	while guard < 20:
		guard += 1
		var dead := []
		for i in 2:
			for u in pl[i].board:
				if int(u.hp) <= 0:
					dead.append(u)
		if dead.is_empty():
			break
		for u in dead:
			pl[u.owner].board.erase(u)
			ev({"t": "death", "uid": u.uid, "p": u.owner, "id": u.id})
		for u in dead:
			_trigger(u, "death", {})
	_check_winner()

func _check_winner() -> void:
	if winner >= 0:
		return
	var d0 := int(pl[0].leader.hp) <= 0
	var d1 := int(pl[1].leader.hp) <= 0
	if d0 and d1:
		winner = 2
	elif d0:
		winner = 1
	elif d1:
		winner = 0
	if winner >= 0:
		ev({"t": "win", "p": winner})

# ======================================================================= évaluation
func unit_value(u: Dictionary) -> float:
	var v := float(u.atk) * 1.2 + float(u.hp)
	for k in u.kw:
		v += 1.5
	return v

func board_value(i: int) -> float:
	var s := 0.0
	for u in pl[i].board:
		s += unit_value(u)
	return s
