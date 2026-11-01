extends Node
## Tests de logique (sans affichage) : base de données, boosters, pity, combats IA vs IA.
## Lancement : godot --headless --path . -- --logic-test

var fails := 0

func check(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		printerr("ÉCHEC : ", msg)

func run() -> int:
	print("== Base de données")
	check(DB.card_order.size() >= 60, "au moins 60 cartes collectionnables (%d)" % DB.card_order.size())
	for id in DB.cards:
		var c: Dictionary = DB.card(id)
		check(DB.rarities.has(c.rarity), id + " rareté inconnue")
		check(DB.elements.has(c.element), id + " élément inconnu")
		check(DB.families.has(c.family), id + " famille inconnue")
		check(ResourceLoader.exists("res://assets/cards/%s.png" % id), id + " illustration manquante")
		check(c.get("lore", "") != "", id + " sans lore")
		for e in c.get("effects", []):
			if e.do == "summon":
				check(DB.cards.has(e.card), id + " invoque une carte inconnue")
			check(DB.effect_text(e) != "", id + " effet sans texte")
		if c.has("evolve"):
			check(DB.cards.has(c.evolve.into), id + " évolution inconnue")
	var names := {}
	for id in DB.cards:
		check(not names.has(DB.cards[id].name), "nom en double : " + DB.cards[id].name)
		names[DB.cards[id].name] = true
	for r in DB.rarity_order:
		var n := 0
		for id in DB.card_order:
			if DB.card(id).rarity == r:
				n += 1
		check(n > 0, "aucune carte de rareté " + r)
	print("== Boosters")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for b in DB.boosters:
		var odds := BoosterLogic.slot_odds(b)
		var tot := 0.0
		for r in odds:
			tot += odds[r]
		check(absf(tot - 100.0) < 0.01, b.id + " probabilités != 100 % (" + str(tot) + ")")
	var b0: Dictionary = DB.booster("classic")
	var counts := {}
	var pity := {"legendary_plus": 0, "mythic_plus": 0}
	var max_gap := 0
	var gap := 0
	var N := 4000
	var variants := 0
	for i in N:
		var res := BoosterLogic.open(b0, pity, rng)
		check(res.size() == 5, "booster de 5 cartes")
		check(DB.rarity_index(DB.card(res[-1].id).rarity) >= DB.rarity_index("R"), "dernière carte Rare ou mieux")
		var got := false
		for x in res:
			var r: String = DB.card(x.id).rarity
			counts[r] = counts.get(r, 0) + 1
			if DB.rarity_index(r) >= DB.rarity_index("L"):
				got = true
			if x.variant != "":
				variants += 1
		gap = 0 if got else gap + 1
		max_gap = maxi(max_gap, gap)
	check(max_gap < int(DB.pity.legendary_plus.hard), "pity Légendaire respectée (écart max %d)" % max_gap)
	var line := ""
	for r in DB.rarity_order:
		line += "%s:%d " % [r, counts.get(r, 0)]
	print("  %d boosters -> %s" % [N, line])
	print("  écart max sans Légendaire+ : %d (pity dure %d), variantes : %d" % [max_gap, DB.pity.legendary_plus.hard, variants])
	var common_share := float(counts.get("C", 0)) / (N * 5)
	check(common_share > 0.35 and common_share < 0.6, "part de Communes plausible (%.2f)" % common_share)
	print("== Combats IA contre IA")
	var wins := [0, 0, 0]
	var turns := 0
	var leaders := ["pyra", "thalassa", "umbra", "sylva"]
	for k in 200:
		var g := BattleEngine.new()
		var r2 := RandomNumberGenerator.new()
		r2.seed = 1000 + k
		var d0 := BattleAI.build_deck([DB.element_order[k % 10], DB.element_order[(k + 3) % 10]], r2, "X")
		var d1 := BattleAI.build_deck([DB.element_order[(k + 5) % 10]], r2, "X")
		check(d0.size() == 20 and d1.size() == 20, "decks IA de 20 cartes")
		g.setup(d0, leaders[k % 4], d1, leaders[(k + 1) % 4], 77 + k)
		var ais := [BattleAI.new(1), BattleAI.new(2)]
		var steps := 0
		while g.winner < 0 and steps < 3000:
			steps += 1
			var a: Dictionary = ais[g.current].next_action(g)
			match a.type:
				"play":
					check(g.play(g.current, a.hid, a.target), "action IA jouer valide")
				"attack":
					check(g.attack(a.uid, a.target), "action IA attaquer valide")
				"power":
					check(g.use_power(g.current), "pouvoir valide")
				"end":
					g.end_turn()
			g.take_events()
			_invariants(g)
		check(g.winner >= 0, "partie terminée (combat %d, %d étapes)" % [k, steps])
		wins[clampi(g.winner, 0, 2)] += 1
		turns += g.turn
	print("  victoires J1/J2/nul : %s, tours moyens : %.1f" % [str(wins), turns / 200.0])
	print("== Profil")
	var pr: Node = Profile
	var before: int = pr.unique_count()
	check(before > 0, "collection de départ non vide")
	check(pr.deck_valid(pr.active_deck()), "deck de départ valide (%d cartes)" % pr.active_deck().cards.size())
	print("RÉSULTAT : %s (%d échec(s))" % ["OK" if fails == 0 else "ÉCHEC", fails])
	return fails

func _invariants(g: BattleEngine) -> void:
	for i in 2:
		check(g.pl[i].board.size() <= BattleEngine.MAX_BOARD, "terrain <= 5")
		check(g.pl[i].hand.size() <= BattleEngine.MAX_HAND, "main <= 9")
		check(int(g.pl[i].energy) >= 0, "énergie >= 0")
		for u in g.pl[i].board:
			check(int(u.hp) > 0, "aucune créature morte sur le terrain")
