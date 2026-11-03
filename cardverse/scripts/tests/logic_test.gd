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
	print("== Mécaniques Éclipse")
	_mechanics()
	print("== Booster Éclipse")
	var rng3 := RandomNumberGenerator.new()
	rng3.seed = 7
	var pity3 := {}
	var only_eclipse := true
	for i in 300:
		for x in BoosterLogic.open(DB.booster("eclipse"), pity3, rng3):
			if DB.card(x.id).set != "eclipse":
				only_eclipse = false
		for x in BoosterLogic.open(DB.booster("classic"), pity3, rng3):
			if DB.card(x.id).set != "genesis":
				only_eclipse = false
	check(only_eclipse, "les boosters de set ne donnent que leur set")
	print("== Puzzles SWAP")
	var rng4 := RandomNumberGenerator.new()
	rng4.seed = 11
	var st := {"pity": 0, "puzzles": {}}
	var pgot := 0
	var pgap := 0
	var maxgap_p := 0
	for i in 1000:
		var pc := BoosterLogic.roll_piece(DB.booster("classic"), st, rng4)
		if pc.is_empty():
			pgap += 1
		else:
			pgot += 1
			pgap = 0
			check(DB.card(pc.id).rarity == "SW" and int(pc.piece) >= 0 and int(pc.piece) < 9, "pièce valide")
			var have: Array = st.puzzles.get(pc.id, [])
			if not int(pc.piece) in have:
				have.append(int(pc.piece))
			st.puzzles[pc.id] = have
		maxgap_p = maxi(maxgap_p, pgap)
	var pdone := 0
	for id in st.puzzles:
		if st.puzzles[id].size() == 9:
			pdone += 1
	print("  1000 boosters -> %d pièces, écart max %d, puzzles complets %d" % [pgot, maxgap_p, pdone])
	check(maxgap_p < int(DB.puzzle_cfg().pity), "garantie de pièce respectée")
	check(pgot > 100 and pgot < 250, "fréquence des pièces plausible")
	for r in DB.rarity_order:
		if DB.rarity(r).get("special", false):
			for b in DB.boosters:
				check(not BoosterLogic.slot_odds(b).has(r), "rareté spéciale absente des tirages " + b.id)
	print("== Boosters de type, displays et coffrets")
	var rng5 := RandomNumberGenerator.new()
	rng5.seed = 21
	for b in DB.boosters:
		if b.has("elements"):
			for i in 40:
				for x in BoosterLogic.open(b, {}, rng5):
					check(DB.card(x.id).element in b.elements, b.id + " ne donne que son élément")
	for dd in DB.products.displays:
		check(not DB.booster(dd.booster).is_empty(), "display -> booster existant " + dd.id)
		# simule 30 displays : la garantie doit toujours être obtenue
		for run in 30:
			var pity5 := {"legendary_plus": 0, "mythic_plus": 0}
			var hit := false
			for k in int(dd.count):
				if k == int(dd.count) - 1 and not hit:
					var key := "mythic_plus" if DB.rarity_index(dd.guarantee) >= DB.rarity_index("M") else "legendary_plus"
					pity5[key] = int(DB.pity[key].hard) - 1
				for x in BoosterLogic.open(DB.booster(dd.booster), pity5, rng5):
					if DB.rarity_index(DB.card(x.id).rarity) >= DB.rarity_index(dd.guarantee):
						hit = true
			check(hit, "garantie du display " + dd.id)
	for bx in DB.products.boxes:
		check(DB.cards.has(bx.promo.card) and DB.variants.has(bx.promo.variant), "promo valide " + bx.id)
		for k in bx.boosters:
			check(not DB.booster(k).is_empty(), "booster du coffret existant " + k)
	print("== Tour des Dieux, GOD et Résurrection")
	check(DB.tower.floors.size() == 20, "20 étages")
	for fl in DB.tower.floors:
		check(not DB.leader(fl.leader).is_empty() and fl.elements.size() > 0, "étage valide %d" % fl.floor)
	var rng6 := RandomNumberGenerator.new()
	rng6.seed = 5
	var gt := BattleEngine.new()
	var fill2 := []
	for i in 20:
		fill2.append("w007")
	gt.setup(fill2, "pyra", fill2, "thalassa", 9, 30, {"enemy_atk": 2, "enemy_shield": true, "player_energy": 1})
	var eu := gt.summon(1, "w007")
	check(int(eu.atk) == int(DB.card("w007").atk) + 2 and eu.kw.get("bouclier", false), "modificateurs de la Tour appliqués")
	check(int(gt.pl[1].leader.hp) == 30, "PV du boss")
	# Résurrection
	var mine := gt.summon(0, "f004")
	mine.hp = 0
	gt.cleanup()
	check(gt.pl[0].grave.has("f004"), "cimetière")
	gt.resolve({"do": "revive", "value": 1}, 0, {}, {})
	var back := false
	for u in gt.pl[0].board:
		if u.id == "f004":
			back = true
	check(back, "Résurrection ramène la créature")
	# GOD : uniquement dans les boosters qui en contiennent
	var gods := 0
	for id in DB.card_order:
		if DB.card(id).rarity == "G":
			gods += 1
	check(gods >= 3, "au moins 3 cartes GOD")
	check(not BoosterLogic.slot_odds(DB.booster("classic")).has("G"), "pas de GOD dans le booster Genèse")
	check(BoosterLogic.slot_odds(DB.booster("pantheon")).has("G"), "GOD possible dans le booster Panthéon")
	# sommet de la tour
	var saved_best := int(Profile.d.tower.best)
	Profile.d.tower.best = 19
	var res: Dictionary = Profile.tower_win(20)
	check(res.has("god_card") and DB.card(res.god_card).rarity == "G", "carte GOD au sommet")
	Profile.d.tower.best = saved_best
	Profile.d.tower.floor = saved_best + 1
	Profile.save_game()
	print("== Atelier et passe")
	for r in DB.forge.evolutions:
		check(DB.cards.has(r.from) and DB.cards.has(r.to), "recette d'évolution valide " + r.from)
	for r in DB.forge.secrets:
		check(DB.cards.has(r.to), "secret valide " + r.id)
		for id in r.inputs:
			check(DB.cards.has(id), "ingrédient valide " + id)
	check(DB.season.tiers.size() == 30, "30 paliers de passe")
	var pd: Dictionary = Profile.pass_data()
	var xp0 := int(pd.xp)
	Profile.add_xp(int(DB.season.xp_per_tier))
	check(int(Profile.pass_data().xp) == xp0 + int(DB.season.xp_per_tier), "l'XP alimente le passe")
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

func _mechanics() -> void:
	var g := BattleEngine.new()
	var filler := []
	for i in 20:
		filler.append("w007")
	g.setup(filler, "pyra", filler, "thalassa", 5)
	g.current = 0
	var garde := g.summon(1, "w007")
	var flyer := g.summon(0, "ec24")
	flyer.sleep = false
	var t := g.attack_targets(flyer.uid)
	var has_leader := false
	for x in t:
		if x.k == "leader":
			has_leader = true
	check(has_leader, "Envol : peut viser le leader malgré une Garde")
	var walker := g.summon(0, "e004")
	walker.sleep = false
	var t2 := g.attack_targets(walker.uid)
	check(t2.size() == 1 and t2[0].k == "unit", "Garde : sans Envol, seule la Garde est ciblable")
	g.resolve({"do": "silence", "target": "choose_enemy_creature"}, 0, {}, {"chosen": {"k": "unit", "uid": garde.uid}})
	check(not garde.kw.get("garde", false) and garde.get("silenced", false), "Silence retire les mots-clés")
	var hand_before: int = g.pl[1].hand.size()
	g.resolve({"do": "bounce", "target": "choose_enemy_creature"}, 0, {}, {"chosen": {"k": "unit", "uid": garde.uid}})
	check(g.find_unit(garde.uid).is_empty(), "Renvoi : la créature quitte le terrain")
	check(g.pl[1].hand.size() == mini(hand_before + 1, BattleEngine.MAX_HAND), "Renvoi : la carte revient en main")
	# Piétinement
	var g2 := BattleEngine.new()
	g2.setup(filler, "pyra", filler, "thalassa", 6)
	g2.current = 0
	var rex := g2.summon(0, "pr15")
	rex.sleep = false
	var small := g2.summon(1, "f001")
	var hp1 := int(g2.pl[1].leader.hp)
	g2.attack(rex.uid, {"k": "unit", "uid": small.uid})
	check(int(g2.pl[1].leader.hp) < hp1, "Piétinement : l'excédent touche le leader")
	# Sommeil : bloque deux tours du propriétaire
	var dz := g2.summon(1, "w007")
	dz.sleep = false
	g2.resolve({"do": "sleep", "target": "choose_enemy_creature"}, 0, {}, {"chosen": {"k": "unit", "uid": dz.uid}})
	g2.current = 1
	check(not g2.can_attack(dz.uid), "Sommeil : ne peut pas attaquer (tour 1)")
	g2.end_turn()
	g2.end_turn()
	check(g2.current == 1 and not g2.can_attack(dz.uid), "Sommeil : ne peut pas attaquer (tour 2)")
	g2.end_turn()
	g2.end_turn()
	check(g2.current == 1 and g2.can_attack(dz.uid), "Sommeil : réveillée au 3e tour")
	# Vol de contrôle, échange de stats, échange des PV
	var victim := g2.summon(1, "w007")
	g2.resolve({"do": "steal", "target": "choose_enemy_creature"}, 0, {}, {"chosen": {"k": "unit", "uid": victim.uid}})
	check(int(victim.owner) == 0 and g2.pl[0].board.has(victim), "Vol : la créature change de camp")
	var sw := g2.summon(1, "e001")
	var a0 := int(sw.atk)
	var h0 := int(sw.hp)
	g2.resolve({"do": "swap_stats", "target": "all_enemy_creatures"}, 0, {}, {})
	check(int(sw.atk) == h0 and int(sw.hp) == a0, "SWAP : ATQ et PV échangés")
	g2.pl[0].leader.hp = 5
	g2.pl[1].leader.hp = 20
	g2.resolve({"do": "swap_leaders"}, 0, {}, {})
	check(int(g2.pl[0].leader.hp) == 20 and int(g2.pl[1].leader.hp) == 5, "Échange des PV des leaders")
	var e0 := int(g.pl[0].energy)
	g.resolve({"do": "energy", "value": 1}, 0, {}, {})
	check(int(g.pl[0].energy) == mini(e0 + 1, 10), "Gain d'énergie")
