class_name BoosterLogic
## Tirage des boosters : probabilités par rareté, focus thématique, variantes et protection anti-malchance (pity).

## Probabilités affichées pour un emplacement (rareté -> pourcentage), en tenant compte du booster.
static func slot_odds(b: Dictionary, guaranteed_min := "") -> Dictionary:
	var weights := {}
	var total := 0.0
	var luck := float(b.get("luck", 1.0))
	var min_i := DB.rarity_index(guaranteed_min) if guaranteed_min != "" else 0
	for r in DB.rarity_order:
		var i := DB.rarity_index(r)
		if i < min_i or _pool(b, r).is_empty() or DB.rarity(r).get("special", false):
			continue
		var w := float(DB.rarity(r).weight)
		if i >= DB.rarity_index("L"):
			w *= luck
		elif i >= DB.rarity_index("R"):
			w *= sqrt(luck)
		weights[r] = w
		total += w
	var out := {}
	for r in weights:
		out[r] = weights[r] / total * 100.0
	return out

## Cartes tirables d'une rareté (hors jetons).
static func _pool(b: Dictionary, r: String) -> Array:
	var out := []
	var sets: Array = b.get("sets", [])
	var els: Array = b.get("elements", [])
	for id in DB.card_order:
		var c := DB.card(id)
		if c.rarity == r and (sets.is_empty() or c.set in sets) and (els.is_empty() or c.element in els):
			out.append(id)
	return out

static func _focus_weight(b: Dictionary, c: Dictionary) -> float:
	var f: Dictionary = b.get("focus", {})
	var w := 1.0
	if c.id in f.get("card", []):
		w *= 6.0
	if c.element in f.get("element", []):
		w *= 4.0
	if c.family in f.get("family", []):
		w *= 4.0
	return w

static func _roll_rarity(odds: Dictionary, rng: RandomNumberGenerator) -> String:
	var x := rng.randf() * 100.0
	var acc := 0.0
	var last := ""
	for r in DB.rarity_order:
		if not odds.has(r):
			continue
		acc += odds[r]
		last = r
		if x < acc:
			return r
	return last

static func _pick_card(b: Dictionary, r: String, rng: RandomNumberGenerator) -> String:
	var pool := _pool(b, r)
	var total := 0.0
	var ws := []
	for id in pool:
		var w := _focus_weight(b, DB.card(id))
		ws.append(w)
		total += w
	var x := rng.randf() * total
	for i in pool.size():
		x -= ws[i]
		if x <= 0:
			return pool[i]
	return pool[-1]

static func _roll_variant(rng: RandomNumberGenerator, luck: float) -> String:
	for v in ["secret", "prisma", "animated", "chroma", "alt", "fullart", "holo"]:
		if rng.randf() < float(DB.variants[v].chance) * sqrt(luck):
			return v
	return ""

## Ouvre un booster. pity = {"legendary_plus": n, "mythic_plus": n} (modifié).
## Renvoie un tableau de {id, variant, pity: bool} trié de la rareté la plus faible à la plus forte.
static func open(b: Dictionary, pity: Dictionary, rng: RandomNumberGenerator) -> Array:
	var n := int(b.get("cards", 5))
	var res := []
	var base_odds := slot_odds(b)
	var last_odds := slot_odds(b, "R")
	var pl: Dictionary = DB.pity.legendary_plus
	var pm: Dictionary = DB.pity.mythic_plus
	var got_l := false
	var got_m := false
	var rare_from := n - maxi(1, int(b.get("rare_slots", 1)))
	for i in n:
		var odds: Dictionary = last_odds if i >= rare_from else base_odds
		# pity douce : augmente progressivement les chances de Légendaire+ sur le dernier emplacement
		var pc := int(pity.get("legendary_plus", 0))
		if i == n - 1 and pc >= int(pl.soft):
			odds = _boost(odds, "L", 1.0 + (pc - int(pl.soft) + 1) * 0.6)
		var r := _roll_rarity(odds, rng)
		var forced := false
		if i == n - 1:
			if not got_m and int(pity.get("mythic_plus", 0)) + 1 >= int(pm.hard) and DB.rarity_index(r) < DB.rarity_index(pm.min):
				r = _roll_rarity(slot_odds(b, pm.min), rng)
				forced = true
			elif not got_l and pc + 1 >= int(pl.hard) and DB.rarity_index(r) < DB.rarity_index(pl.min):
				r = _roll_rarity(slot_odds(b, pl.min), rng)
				forced = true
		if DB.rarity_index(r) >= DB.rarity_index("L"):
			got_l = true
		if DB.rarity_index(r) >= DB.rarity_index("M"):
			got_m = true
		var id := _pick_card(b, r, rng)
		res.append({"id": id, "variant": _roll_variant(rng, float(b.get("luck", 1.0))), "pity": forced})
	# édition Prestige : au moins une variante garantie (sur la meilleure carte)
	if b.get("guaranteed_variant", false):
		var has_v := false
		for x in res:
			if x.variant != "":
				has_v = true
		if not has_v:
			var best := 0
			for k in res.size():
				if DB.rarity_index(DB.card(res[k].id).rarity) > DB.rarity_index(DB.card(res[best].id).rarity):
					best = k
			var vs := ["holo", "holo", "fullart", "alt", "chroma", "animated"]
			res[best].variant = vs[rng.randi_range(0, vs.size() - 1)]
	pity["legendary_plus"] = 0 if got_l else int(pity.get("legendary_plus", 0)) + 1
	pity["mythic_plus"] = 0 if got_m else int(pity.get("mythic_plus", 0)) + 1
	res.sort_custom(func(a, c): return DB.rarity_index(DB.card(a.id).rarity) < DB.rarity_index(DB.card(c.id).rarity))
	return res

static func _boost(odds: Dictionary, min_r: String, mult: float) -> Dictionary:
	var out := {}
	var total := 0.0
	for r in odds:
		out[r] = odds[r] * (mult if DB.rarity_index(r) >= DB.rarity_index(min_r) else 1.0)
		total += out[r]
	for r in out:
		out[r] = out[r] / total * 100.0
	return out

## Texte lisible des probabilités pour l'écran d'information.
static func odds_lines(b: Dictionary) -> Array:
	var a := slot_odds(b)
	var z := slot_odds(b, "R")
	var lines := []
	for r in DB.rarity_order:
		if a.has(r) or z.has(r):
			lines.append({"rarity": r, "slot": a.get(r, 0.0), "last": z.get(r, 0.0)})
	return lines

static func fmt_pct(p: float) -> String:
	if p <= 0.0:
		return "—"
	if p >= 1.0:
		return "%.1f %%" % p
	if p >= 0.01:
		return "%.2f %%" % p
	return "%.4f %%" % p


## Pièce de puzzle SWAP : chance par booster, garantie après `pity` boosters sans pièce.
## Renvoie {} ou {"id": carte, "piece": index}. `state` = {"pity": n, "puzzles": {id: [pièces]}} (pity modifié).
static func roll_piece(b: Dictionary, state: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var cfg: Dictionary = DB.puzzle_cfg()
	var swaps := []
	for id in DB.card_order:
		if DB.card(id).rarity == "SW":
			swaps.append(id)
	if swaps.is_empty():
		return {}
	var chance := float(cfg.chance) * sqrt(float(b.get("luck", 1.0)))
	var p := int(state.get("pity", 0))
	if rng.randf() >= chance and p + 1 < int(cfg.pity):
		state.pity = p + 1
		return {}
	state.pity = 0
	# privilégie les puzzles inachevés et les pièces manquantes
	var puzzles: Dictionary = state.get("puzzles", {})
	var n := int(DB.rarity("SW").pieces)
	var open := swaps.filter(func(id): return puzzles.get(id, []).size() < n)
	var id: String = (open if not open.is_empty() else swaps)[rng.randi_range(0, (open if not open.is_empty() else swaps).size() - 1)]
	var have: Array = puzzles.get(id, [])
	var missing := []
	for k in n:
		if not k in have:
			missing.append(k)
	var piece: int = missing[rng.randi_range(0, missing.size() - 1)] if (not missing.is_empty() and rng.randf() < 0.75) else rng.randi_range(0, n - 1)
	return {"id": id, "piece": piece}
