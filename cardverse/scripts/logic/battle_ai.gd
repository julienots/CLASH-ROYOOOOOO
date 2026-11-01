class_name BattleAI extends RefCounted
## IA adverse : choisit une action à la fois (pour que la vue puisse l'animer).
## difficulty : 0 facile, 1 normal, 2 difficile.

var difficulty := 1
var rng := RandomNumberGenerator.new()

func _init(diff := 1) -> void:
	difficulty = diff
	rng.randomize()

func _sloppy() -> bool:
	return difficulty == 0 and rng.randf() < 0.35

## Renvoie {"type": "play"/"attack"/"power"/"end", ...}
func next_action(g: BattleEngine) -> Dictionary:
	var me := g.current
	var o := g.opp(me)
	# 1) létal immédiat
	var lethal := _lethal_attack(g, me, o)
	if not lethal.is_empty():
		return lethal
	# 2) jouer des cartes
	var play := _best_play(g, me, o)
	if not play.is_empty():
		return play
	# 3) pouvoir du leader
	if g.can_use_power(me) and _power_useful(g, me):
		return {"type": "power"}
	# 4) attaques
	var atk := _best_attack(g, me, o)
	if not atk.is_empty():
		return atk
	return {"type": "end"}

func _attackers(g: BattleEngine, me: int) -> Array:
	var out := []
	for u in g.pl[me].board:
		if g.can_attack(u.uid):
			out.append(u)
	out.sort_custom(func(a, b): return int(a.atk) > int(b.atk))
	return out

func _lethal_attack(g: BattleEngine, me: int, o: int) -> Dictionary:
	var atks := _attackers(g, me)
	if atks.is_empty():
		return {}
	for e in g.pl[o].board:
		if e.kw.get("garde", false):
			return {}
	var total := 0
	for u in atks:
		total += g.calc(int(u.atk), DB.card(u.id).element, g.pl[o].leader.element)
	if total >= int(g.pl[o].leader.hp):
		return {"type": "attack", "uid": atks[0].uid, "target": {"k": "leader", "p": o}}
	return {}

func _best_play(g: BattleEngine, me: int, o: int) -> Dictionary:
	var best := {}
	var best_score := 0.0
	for h in g.pl[me].hand:
		if g.can_play(me, h.hid) != "":
			continue
		var c := DB.card(h.id)
		var score := float(c.cost) * 2.0 + DB.rarity_index(c.rarity) * 0.3
		var target = null
		var tt := g.needs_target(h.id)
		if tt != "":
			var pick := _pick_target(g, me, o, h.id, tt)
			if pick.is_empty():
				if c.type == "spell":
					continue
			else:
				target = pick.target
				score += float(pick.score)
		if c.type == "spell":
			var s := _spell_value(g, me, o, c)
			if s <= 0.0 and tt == "":
				continue
			score += s
		if _sloppy():
			score *= rng.randf_range(0.3, 1.2)
		if score > best_score:
			best_score = score
			best = {"type": "play", "hid": h.hid, "target": target}
	return best

func _spell_value(g: BattleEngine, me: int, o: int, c: Dictionary) -> float:
	var v := 0.0
	for e in c.get("effects", []):
		var t: String = e.get("target", "")
		match e.do:
			"damage":
				if t == "all_enemy_creatures" or t == "all_enemies":
					var kills := 0
					for u in g.pl[o].board:
						if int(u.hp) <= int(e.value):
							kills += 1
					v += kills * 3.0 + g.pl[o].board.size() - 2.0
				elif t == "all_creatures":
					var mine := 0.0
					var theirs := 0.0
					for u in g.pl[o].board:
						if int(u.hp) <= int(e.value):
							theirs += g.unit_value(u)
					for u in g.pl[me].board:
						if int(u.hp) <= int(e.value):
							mine += g.unit_value(u)
					v += (theirs - mine) * 0.6
				elif t == "ally_leader":
					v -= float(e.value) * (0.3 if int(g.pl[me].leader.hp) > 12 else 2.0)
				elif t == "enemy_leader":
					v += float(e.value) * 0.6
			"destroy":
				if t == "all_creatures":
					v += (g.board_value(o) - g.board_value(me) - 6.0) * 0.5
			"heal":
				var miss := int(g.pl[me].leader.max_hp) - int(g.pl[me].leader.hp)
				v += min(miss, int(e.value)) * 0.5 - 1.0
			"buff":
				v += g.pl[me].board.size() * 1.5 - 1.0
			"freeze":
				if t == "all_enemy_creatures":
					v += g.pl[o].board.size() * 1.0 - 1.0
			"draw":
				v += float(e.value) * (1.5 if g.pl[me].hand.size() < 5 else 0.3)
	return v

func _pick_target(g: BattleEngine, me: int, o: int, id: String, tt: String) -> Dictionary:
	var c := DB.card(id)
	var dmg := 0
	var harmful := false
	for e in c.get("effects", []):
		if str(e.get("target", "")) == tt:
			if e.do == "damage":
				dmg = int(e.value)
				harmful = true
			elif e.do in ["freeze", "destroy"]:
				harmful = true
	var options := g.targets_for(me, tt)
	var best := {}
	var best_s := -INF
	for t in options:
		var s := 0.0
		if t.k == "leader":
			if t.p == o and harmful:
				s = float(dmg) * 0.7 + (20.0 if dmg >= int(g.pl[o].leader.hp) else 0.0)
			else:
				continue
		else:
			var u := g.find_unit(t.uid)
			if harmful and u.owner == o:
				if dmg > 0:
					s = (g.unit_value(u) + 2.0) if dmg >= int(u.hp) and not u.kw.get("bouclier", false) else float(dmg) * 0.4
				else:
					s = float(u.atk) * 1.2
			elif not harmful and u.owner == me:
				s = g.unit_value(u) * 0.5
			else:
				continue
		if s > best_s:
			best_s = s
			best = {"target": t, "score": s}
	return best

func _power_useful(g: BattleEngine, me: int) -> bool:
	var L: Dictionary = g.pl[me].leader
	for e in L.power.effects:
		if e.do == "heal" and int(L.max_hp) - int(L.hp) < 2:
			return false
		if e.do == "draw" and int(L.hp) < 6:
			return false
		if e.do == "buff" and g.pl[me].board.is_empty():
			return false
	return true

func _best_attack(g: BattleEngine, me: int, o: int) -> Dictionary:
	for a in _attackers(g, me):
		var targets := g.attack_targets(a.uid)
		var best := {}
		var best_s := -INF
		for t in targets:
			var s := 0.0
			if t.k == "leader":
				s = float(a.atk) * 0.9 + (2.0 if g.pl[o].board.is_empty() else 0.0)
				if int(g.pl[me].leader.hp) < 8 and g.board_value(o) > 6:
					s -= 2.0  # en danger : mieux vaut nettoyer le terrain
			else:
				var d := g.find_unit(t.uid)
				var my_dmg := g.calc(int(a.atk), DB.card(a.id).element, DB.card(d.id).element)
				var their := g.calc(int(d.atk), DB.card(d.id).element, DB.card(a.id).element)
				var kills: bool = (my_dmg >= int(d.hp) or a.kw.get("poison", false)) and not d.kw.get("bouclier", false)
				var dies: bool = (their >= int(a.hp) or d.kw.get("poison", false)) and not a.kw.get("bouclier", false)
				if kills and not dies:
					s = g.unit_value(d) + 3.0
				elif kills and dies:
					s = g.unit_value(d) - g.unit_value(a) + 1.0
				elif not dies:
					s = float(my_dmg) * 0.3
				else:
					s = -g.unit_value(a)
			if _sloppy():
				s += rng.randf_range(-3, 3)
			if s > best_s:
				best_s = s
				best = t
		if not best.is_empty() and (best_s > -1.0 or targets.size() == 1 and best.k == "unit" and best_s > -4.0):
			return {"type": "attack", "uid": a.uid, "target": best}
	return {}

## Construit un deck IA de 20 cartes à partir d'éléments donnés.
static func build_deck(elements: Array, rng: RandomNumberGenerator, max_rarity := "L") -> Array:
	var pool := []
	var mi := DB.rarity_index(max_rarity)
	for id in DB.card_order:
		var c := DB.card(id)
		if DB.rarity_index(c.rarity) > mi:
			continue
		if c.element in elements or rng.randf() < 0.12:
			pool.append(id)
	var all := []
	for id in DB.card_order:
		if DB.rarity_index(DB.card(id).rarity) <= mi:
			all.append(id)
	var deck := []
	var guard := 0
	while deck.size() < 20 and guard < 2000:
		guard += 1
		# 70 % des tirages dans les éléments du deck, le reste dans tout le catalogue
		var src: Array = pool if (rng.randf() < 0.7 and not pool.is_empty()) else all
		var id: String = src[rng.randi_range(0, src.size() - 1)]
		var c := DB.card(id)
		var mx := int(DB.rarity(c.rarity).deck_max)
		if deck.count(id) < mx and (int(c.cost) <= 6 or rng.randf() < 0.5):
			deck.append(id)
	return deck
