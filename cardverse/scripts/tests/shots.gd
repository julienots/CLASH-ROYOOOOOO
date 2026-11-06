extends Node
## Captures d'écran automatiques pour vérifier le rendu : godot --path . -- --shots=/dossier[:liste]
## liste = noms séparés par des virgules (home,collection,detail,shop,booster,battle,decks,missions,profile,events,settings)

func run(main: Control, arg: String) -> void:
	var parts := arg.split(":")
	var dir := parts[0]
	var only: Array = parts[1].split(",") if parts.size() > 1 else []
	DirAccess.make_dir_recursive_absolute(dir)
	Profile.claim_login()
	await _wait(0.3)
	_clear(main)
	await _wait(0.7)
	var steps := [
		["home", func(): main.goto("home")],
		["collection", func(): main.goto("collection")],
		["detail", func(): main.show_card("f004", "holo", [])],
		["shop", func(): _clear(main); main.goto("shop")],
		["booster", func(): _clear(main); main.goto("shop"); await _wait(0.4); main.current.open_booster(DB.booster("classic"), true)],
		["booster_tear", func(): await _wait(0.8)],
		["booster_reveal", func(): _ov(main)._advance()],
		["booster_reveal2", func():
			var o = _ov(main)
			for k in 3:
				o._advance()
				await _wait(1.0)
			o._advance()],
		["booster_summary", func():
			var o = _ov(main)
			for k in 12:
				o._advance()
				await _wait(0.9)],
		["touch_booster", func():
			_clear(main)
			await _wait(0.3)
			main.goto("shop")
			await _wait(0.4)
			main.current.open_booster(DB.booster("classic"), true)
			await _wait(1.2)
			var o = _ov(main)
			var r: Rect2 = o._pack_rect()
			await _drag(main, r.position + Vector2(10, 30), r.position + Vector2(r.size.x - 10, 30))
			await _wait(2.5)
			print("toucher : phase après déchirure = ", o.phase)
			var c := main.get_viewport_rect().size / 2
			for k in 14:
				await _tap(main, c)
				await _wait(1.6 if k % 2 == 0 else 0.5)
			print("toucher : phase finale = ", o.phase, ", cartes rangées = ", o._done_cards.size())],
		["touch_battle", func():
			_clear(main)
			await _wait(0.3)
			main.goto("battle_select")
			await _wait(0.4)
			main.current.start_battle(0)
			var b = _ov(main)
			var guard := 0
			while b.g.current != 0 or b.busy:
				await _wait(0.5)
				guard += 1
				if guard > 40: break
			var played := false
			for h in b.g.pl[0].hand:
				if b.g.can_play(0, int(h.hid)) == "" and b.g.needs_target(h.id) == "":
					var cv = b.hand_views[int(h.hid)]
					await _tap(main, cv.global_position + Vector2(60, 60))
					await _wait(0.6)
					var btn: Button = b.preview.get_child(1)
					await _tap(main, btn.global_position + btn.size / 2)
					await _wait(1.5)
					played = true
					break
			print("toucher combat : carte jouée=", played, " créatures sur le terrain=", b.g.pl[0].board.size(), " main=", b.g.pl[0].hand.size())],
		["touch_scroll", func():
			_clear(main)
			await _wait(0.3)
			main.goto("collection")
			await _wait(0.8)
			var sc: ScrollContainer = main._scroll_at(Vector2(360, 900))
			print("scroll trouvé : ", sc, " max=", sc.get_v_scroll_bar().max_value if sc else -1, " h=", sc.size.y if sc else -1)
			var before: int = sc.scroll_vertical
			# glisser vers le haut en partant d'une carte
			await _drag(main, Vector2(200, 1000), Vector2(200, 500), 16)
			await _wait(0.8)
			var opened: int = main.overlay.get_child_count()
			print("toucher défilement : avant=", before, " après=", sc.scroll_vertical, " fiches ouvertes=", opened)
			# un simple toucher sur une carte doit toujours ouvrir sa fiche
			await _tap(main, Vector2(200, 900))
			await _wait(0.6)
			print("toucher simple : fiches ouvertes=", main.overlay.get_child_count())
			_clear(main)
			await _wait(0.3)
			main.goto("shop", {"tab": "boosters"})
			await _wait(0.8)
			var sc2: ScrollContainer = main._scroll_at(Vector2(360, 900))
			var b2: int = sc2.scroll_vertical if sc2 else -1
			var coins: int = Profile.get_cur("coins")
			await _drag(main, Vector2(500, 1050), Vector2(500, 600), 16)
			await _wait(0.8)
			print("boutique : défilement ", b2, " -> ", sc2.scroll_vertical if sc2 else -1, ", achat parasite=", Profile.get_cur("coins") != coins, ", superpositions=", main.overlay.get_child_count())],
		["battle_select", func(): _clear(main); await _wait(0.3); main.goto("battle_select")],
		["battle", func(): main.current.start_battle(1)],
		["battle2", func():
			await _wait(3.0)
			var b = _ov(main)
			for h in b.g.pl[0].hand:
				if b.g.can_play(0, int(h.hid)) == "":
					b._on_hand_tap(int(h.hid))
					break],
		["battle3", func():
			var b = _ov(main)
			if b.sel_hid >= 0:
				b._try_play(b.sel_hid)
			await _wait(1.5)
			if b.targeting != "":
				b._confirm_target(b.valid_targets[0])
			await _wait(1.0)
			b._on_end_turn()
			await _wait(9.0)],
		["battle_auto", func():
			_clear(main)
			await _wait(0.3)
			Profile.d.settings.fast = true
			main.goto("battle_select")
			await _wait(0.5)
			main.current.start_battle(2)
			var b = _ov(main)
			var tmax := 400.0
			while is_instance_valid(b) and not b._finished and tmax > 0:
				b.autoplay_step()
				await _wait(0.25)
				tmax -= 0.25
			print("partie auto terminée : vainqueur=", b.g.winner if is_instance_valid(b) else "?", " tours=", b.g.turn if is_instance_valid(b) else 0)
			Profile.d.settings.fast = false
			await _wait(2.0)],
		["battle_eclipse", func():
			_clear(main)
			await _wait(0.3)
			Profile.d.settings.fast = true
			var ec := []
			for id in DB.sets[1].cards:
				for k in DB.rarity(DB.card(id).rarity).deck_max:
					ec.append(id)
			ec.shuffle()
			var bv = load("res://scripts/ui/battle_view.gd").new()
			bv.setup({"deck": ec.slice(0, 20), "leader": "umbra", "enemy_deck": ec.slice(20, 40), "enemy_leader": "sylva", "enemy_hp": 25, "difficulty": 2, "rewards_mult": 1.0, "event": false, "board_colors": ["0b0716", "3a1466", "0d4070"]})
			main.open_overlay(bv, true)
			var b = bv
			var seen := {}
			var tmax := 400.0
			while is_instance_valid(b) and not b._finished and tmax > 0:
				for e in b.g.events:
					seen[e.t] = true
				b.autoplay_step()
				await _wait(0.25)
				tmax -= 0.25
			print("partie Éclipse : vainqueur=", b.g.winner, " tours=", b.g.turn, " événements animés=", b.anim_seen)
			Profile.d.settings.fast = false
			await _wait(1.5)],
		["battle_mech", func():
			_clear(main)
			await _wait(0.3)
			main.goto("battle_select")
			await _wait(0.4)
			main.current.start_battle(0)
			var b = _ov(main)
			await _wait(4.0)
			while b.busy:
				await _wait(0.3)
			var u1: Dictionary = b.g.summon(1, "w007")
			var u2: Dictionary = b.g.summon(1, "e001")
			await b._play(b.g.take_events())
			b.g.resolve({"do": "silence", "target": "choose_enemy_creature"}, 0, {}, {"chosen": {"k": "unit", "uid": u1.uid}})
			await b._play(b.g.take_events())
			b.g.resolve({"do": "bounce", "target": "choose_enemy_creature"}, 0, {}, {"chosen": {"k": "unit", "uid": u2.uid}})
			await b._play(b.g.take_events())
			b.g.resolve({"do": "energy", "value": 1}, 0, {}, {})
			await b._play(b.g.take_events())
			b._sync()
			print("mécaniques animées : ", b.anim_seen)],
		["fx_detail", func(): _clear(main); main.show_card("pr12", "", [])],
		["fx_detail2", func(): _clear(main); main.show_card("pr42", "", [])],
		["fx_grid", func():
			_clear(main)
			for id in ["pr12", "pr06", "pr21", "pr45", "pr37", "sw01", "ec14", "pr27", "pr31"]:
				Profile.add_card(id, "", false)
			Profile.d.puzzles["sw02"] = [0, 2, 4, 6, 8]
			main.goto("collection")
			await _wait(0.5)
			main.current.filt.set = "primal"
			main.current.filt.sort = 1
			main.current.rebuild()],
		["puzzle", func():
			_clear(main)
			Profile.d.puzzles["sw03"] = [0, 1, 2, 3, 4, 5, 6, 7]
			var rng := RandomNumberGenerator.new()
			var b := DB.booster("primal")
			var res := BoosterLogic.open(b, {}, rng)
			for r in res:
				r["new"] = Profile.add_card(r.id, r.variant, false)
			var pc := {"id": "sw03", "piece": 8}
			pc.merge(Profile.add_piece("sw03", 8))
			var o = load("res://scripts/ui/booster_open.gd").new()
			o.setup(b, res, pc)
			main.open_overlay(o, true)
			await _wait(1.2)
			o.auto_tear()
			await _wait(2.5)
			for k in 10:
				o._advance()
				await _wait(1.3 if k % 2 == 0 else 0.4)
			await _wait(1.8)],
		["puzzle_done", func(): await _wait(2.0)],
		["splash", func():
			_clear(main)
			await _wait(0.3)
			main.goto("battle_select")
			await _wait(0.4)
			main.current.start_battle(0)
			var b = _ov(main)
			await _wait(4.0)
			while b.busy:
				await _wait(0.3)
			print("splash : rapide=", Profile.d.settings.get("fast", false))
			Profile.d.settings.fast = false
			b._splash("pr45")
			await _wait(0.9)
			main.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/shots/splash_mid.png")
			print("splash : fx_layer enfants pendant=", b.fx_layer.get_child_count(), " overlay=", main.overlay.get_child_count(), " top=", main.overlay.get_child(main.overlay.get_child_count() - 1))],
		["shop_types", func():
			_clear(main)
			main.goto("shop", {"tab": "boosters"})
			await _wait(0.6)
			var sc: ScrollContainer = main._scroll_at(Vector2(360, 900))
			sc.scroll_vertical = 1250],
		["products", func(): main.goto("shop", {"tab": "products"})],
		["display", func():
			Profile.d.coins = 5000
			Profile.d.crystals = 2000
			main.goto("shop", {"tab": "products"})
			await _wait(0.5)
			Profile.d.displays.append({"id": "display_songes", "left": 12, "hit": false})
			main.current.open_display(Profile.d.displays.size() - 1)
			await _wait(1.2)],
		["display_lid", func():
			var d = _ov(main)
			await _tap(main, Vector2(360, 600))
			await _wait(2.2)
			print("display 3D : couvercle ouvert = ", d.dsp.get("lid", false), ", boosters visibles = ", d.packs.size())],
		["display_pack", func():
			var d = _ov(main)
			var p: Node3D = d.packs[3]
			var sp: Vector2 = d.vpc.position + d.cam.unproject_position(p.global_position + Vector3(0, 0.1, 0))
			await _tap(main, sp)
			await _wait(0.35)
			main.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/shots/display_pull.png")
			await _wait(1.6)
			var o = _ov(main)
			print("display 3D : écran au-dessus = ", o.get_script().resource_path.get_file())
			o.auto_tear()
			await _wait(2.5)
			var guard := 0
			while o.phase != "summary" and guard < 40:
				guard += 1
				if o.phase == "puzzle":
					var pc := _find_button(o, "Continuer")
					if pc:
						await _tap(main, pc.global_position + pc.size / 2)
				else:
					await _tap(main, main.get_viewport_rect().size / 2)
				await _wait(1.0)
			await _wait(1.0)
			var cont := _find_button(o, "Continuer")
			if cont:
				await _tap(main, cont.global_position + cont.size / 2)
			await _wait(1.2)
			var top = _ov(main)
			print("display 3D : retour = ", top.get_script().resource_path.get_file(), " restants=", top.dsp.left, " boosters dans la caisse=", top.packs.size())],
		["box", func():
			_clear(main)
			await _wait(0.3)
			var free_before := Profile.free_count("dragons")
			main.current.open_box(DB.product("boxes", "box_dragon"))
			await _wait(1.3)
			print("coffret : boosters Draconique crédités = ", Profile.free_count("dragons") - free_before, " promo possédée = ", Profile.entry("f004").get("variants", {}).has("secret"))
			await _tap(main, Vector2(360, 700))
			await _wait(3.2)],
		["box_done", func(): await _wait(3.5)],
		["gift", func():
			_clear(main)
			Profile.d.erase("pending_gift")
			Profile.d.gifts = []
			Profile._migrate()
			main.goto("home", {"r": 9})
			await _wait(0.8)],
		["home_new", func():
			_clear(main)
			Profile.d.pending_gift = false
			main.goto("home", {"r": 10})
			await _wait(0.5)
			var sc: ScrollContainer = main._scroll_at(Vector2(360, 700))
			if sc:
				sc.scroll_vertical = 520],
		["album_preview", func():
			_clear(main)
			main.goto("collection")
			await _wait(0.5)
			main.current.filt.preview = true
			main.current.filt.set = "mecanica"
			main.current.rebuild()],
		["god_detail", func(): _clear(main); Profile.add_card("pg01", "", false); main.show_card("pg01", "", [])],
		["god_reveal", func():
			_clear(main)
			var b := DB.booster("pantheon")
			var res := [{"id": "pc01", "variant": "", "new": false}, {"id": "pc02", "variant": "", "new": false}, {"id": "pc03", "variant": "", "new": false}, {"id": "pc10", "variant": "", "new": false}, {"id": "pg02", "variant": "", "new": true}]
			for r in res:
				Profile.add_card(r.id, "", false)
			var o = load("res://scripts/ui/booster_open.gd").new()
			o.setup(b, res, {})
			main.open_overlay(o, true)
			await _wait(1.2)
			o.auto_tear()
			await _wait(2.5)
			for k in 8:
				o._advance()
				await _wait(1.0 if k % 2 == 0 else 0.4)
			o._advance()
			await _wait(4.6)
			main.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/shots/god_reveal_mid.png")
			await _wait(4.5)],
		["tower", func(): _clear(main); Profile.d.tower = {"floor": 4, "best": 3}; main.goto("battle_select"); await _wait(0.5); main.goto("tower")],
		["tower_win", func():
			Profile.d.settings.fast = true
			main.current._fight(DB.tower.floors[int(Profile.d.tower.best)])
			var b = _ov(main)
			var tmax := 300.0
			while is_instance_valid(b) and not b._finished and tmax > 0:
				b.autoplay_step()
				await _wait(0.25)
				tmax -= 0.25
			print("tour : vainqueur=", b.g.winner, " étage=", b.cfg.tower_floor, " meilleur=", Profile.d.tower.best, " mods=", b.g.mods)
			Profile.d.settings.fast = false
			await _wait(2.5)],
		["gift8", func(): _clear(main); Profile.d.tutorial_done = true; Profile.d.pending_gift8 = true; main.goto("home", {"r": 11})],
		["shop_edition", func(): _clear(main); main.goto("shop", {"tab": "boosters"})],
		["shop_bundles", func(): main.goto("shop", {"tab": "bundles"})],
		["shop_market", func(): Profile.d.dust = 5000; main.goto("shop", {"tab": "market"})],
		["shop_wheel", func():
			Profile.d.erase("wheel")
			main.goto("shop", {"tab": "wheel"})
			await _wait(0.8)
			var target: Button = null
			for n in main.current.find_children("*", "Button", true, false):
				if n.text.begins_with("TOURNER"):
					target = n
			print("bouton roue : ", target != null)
			if target:
				_tap(main, target.get_global_rect().get_center())
			await _wait(1.5)
			main.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/shots/shop_wheel_spin.png")
			await _wait(4.5)
			var rot: float = main.current._wheel_view.disc.rotation
			var n := ShopLogic.WHEEL.size()
			var under := int(floor(fposmod(-rot, TAU) / (TAU / n)))
			print("roue : ", Profile.d.wheel, " tiré=", main.current.wheel_last, " case sous le pointeur=", under, " ", ShopLogic.WHEEL[under].reward)],
		["rar_ne", func(): _clear(main); Profile.add_card("cx16", "", false); main.show_card("cx16", "", [])],
		["rar_in", func(): _clear(main); Profile.add_card("jg34", "", false); main.show_card("jg34", "", [])],
		["rar_mi", func(): _clear(main); Profile.add_card("cx45", "", false); main.show_card("cx45", "", [])],
		["god_jungle", func(): _clear(main); Profile.add_card("jg45", "", false); main.show_card("jg45", "", [])],
		["prestige_open", func():
			_clear(main)
			var o = load("res://scripts/screens/shop.gd").open_pack(main, DB.booster("prestige"))
			await _wait(1.2)
			o.auto_tear()
			await _wait(2.5)
			for k in 40:
				if not is_instance_valid(o) or o.get("phase") == "summary":
					break
				if o.phase == "puzzle":
					var pc := _find_button(o, "Continuer")
					if pc:
						await _tap(main, pc.global_position + pc.size / 2)
				else:
					await _tap(main, main.get_viewport_rect().size / 2)
				await _wait(0.6)
			print("prestige : ", o.get_meta("results").map(func(x): return x.id + ":" + x.variant))
			await _wait(1.5)],
		["gift11", func(): _clear(main); Profile.d.tutorial_done = true; Profile.d.pending_gift11 = true; main.goto("home", {"r": 14})],
		["album_givre", func(): _clear(main); main.goto("collection"); await _wait(0.5); main.current.filt.preview = true; main.current.filt.set = "givre"; main.current.rebuild()],
		["album_carnaval", func(): _clear(main); main.goto("collection"); await _wait(0.5); main.current.filt.preview = true; main.current.filt.set = "carnaval"; main.current.rebuild()],
		["detail_cv50", func(): _clear(main); main.show_card("cv50", "", [])],
		["detail_gv49", func(): _clear(main); main.show_card("gv49", "", [])],
		["gift10", func(): _clear(main); Profile.d.tutorial_done = true; Profile.d.pending_gift10 = true; main.goto("home", {"r": 13})],
		["album_sables", func():
			_clear(main)
			main.goto("collection")
			await _wait(0.5)
			main.current.filt.preview = true
			main.current.filt.set = "sables"
			main.current.rebuild()],
		["sables_open", func():
			_clear(main)
			var o = load("res://scripts/screens/shop.gd").open_pack(main, DB.booster("sables"))
			await _wait(1.2)
			o.auto_tear()
			await _wait(2.5)
			for k in 30:
				if not is_instance_valid(o) or o.get("phase") == "summary":
					break
				if o.phase == "puzzle":
					var pc := _find_button(o, "Continuer")
					if pc:
						await _tap(main, pc.global_position + pc.size / 2)
				else:
					await _tap(main, main.get_viewport_rect().size / 2)
				await _wait(0.6)
			await _wait(1.5)],
		["detail_sb48", func(): _clear(main); main.show_card("sb48", "", [])],
		["detail_sb44", func(): _clear(main); main.show_card("sb44", "", [])],
		["gift9", func(): _clear(main); Profile.d.tutorial_done = true; Profile.d.pending_gift9 = true; main.goto("home", {"r": 12})],
		["omega_detail", func(): _clear(main); Profile.add_card("ux11", "", false); main.show_card("ux11", "", [])],
		["titan_detail", func(): _clear(main); Profile.add_card("ty12", "", false); main.show_card("ty12", "", [])],
		["titan_detail2", func(): _clear(main); Profile.add_card("ty09", "", false); main.show_card("ty09", "", [])],
		["album_ultime", func():
			_clear(main)
			main.goto("collection")
			await _wait(0.5)
			main.current.filt.preview = true
			main.current.filt.set = "ultime"
			main.current.rebuild()],
		["battle_omega", func():
			_clear(main)
			await _wait(0.3)
			main.goto("battle_select")
			await _wait(0.4)
			main.current.start_battle(0)
			var b = _ov(main)
			await _wait(4.0)
			while b.busy:
				await _wait(0.3)
			b.g.current = 0
			var e1: Dictionary = b.g.summon(1, "w007")
			var e2: Dictionary = b.g.summon(1, "ty02")
			var om: Dictionary = b.g.summon(0, "ux11")
			var ti: Dictionary = b.g.summon(0, "ty08")
			om.sleep = false
			await b._play(b.g.take_events())
			b._sync()
			await _wait(0.6)
			main.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/shots/battle_omega_board.png")
			b.g.attack(om.uid, {"k": "unit", "uid": e1.uid})
			var evs: Array = b.g.take_events()
			main.get_tree().create_timer(0.9).timeout.connect(func(): main.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/shots/battle_omega_fx.png"))
			await b._play(evs)
			b.g.resolve({"do": "freeze", "target": "choose_enemy_creature"}, 1, {}, {"chosen": {"k": "unit", "uid": ti.uid}})
			await b._play(b.g.take_events())
			b._sync()
			print("Ω combat : événements=", evs.map(func(x): return x.t), " Ω utilisé=", b.g.pl[0].get("omega_used", false), " animés=", b.anim_seen)],
		["shop_offers", func(): _clear(main); main.goto("shop", {"tab": "offers"})],
		["shop_singles", func(): main.goto("shop", {"tab": "singles"})],
		["shop_style", func(): main.goto("shop", {"tab": "cosmetics"})],
		["shop_premium", func(): main.goto("shop", {"tab": "premium"})],
		["odds", func(): main.goto("shop"); await _wait(0.3); main.current._show_odds(DB.booster("divine"))],
		["forge", func():
			_clear(main)
			Profile.d.dust = 3000
			for k in 3:
				Profile.add_card("f001", "", false)
			main.goto("forge")],
		["forge_evolve", func(): main.current._do_evolve("f001", 3, 60, "f002")],
		["forge_secret", func(): _clear(main); main.goto("forge", {"tab": "secret"})],
		["forge_craft", func(): main.goto("forge", {"tab": "craft"})],
		["forge_variant", func(): main.goto("forge", {"tab": "variant"})],
		["season", func(): Profile.add_xp(400); main.goto("season")],
		["news", func(): Profile.d.seen_version = "0.1"; main.goto("home", {"r": 2})],
		["tuto", func(): _clear(main); Profile.d.tutorial_done = false; main.goto("home", {"r": 3})],
		["album_eclipse", func(): _clear(main); Profile.d.tutorial_done = true; Profile.d.seen_version = "0.2"; main.goto("collection"); await _wait(0.5); main.current.filt.set = "eclipse"; main.current.rebuild()],
		["decks", func(): _clear(main); await _wait(0.3); main.goto("decks")],
		["deck_edit", func(): main.goto("decks", {"edit": 0})],
		["missions", func(): main.goto("missions")],
		["profile", func(): main.goto("profile")],
		["events", func(): main.goto("events")],
		["settings", func(): main.goto("settings")],
	]
	for s in steps:
		if not only.is_empty() and not (s[0] in only):
			continue
		await s[1].call()
		await _wait(1.6 if s[0].begins_with("booster") or s[0].begins_with("battle") else 0.9)
		if s[0] == "booster":
			_drive_booster(main)
		if s[0] == "battle":
			_drive_battle(main)
		var img := main.get_viewport().get_texture().get_image()
		img.save_png("%s/%s.png" % [dir, s[0]])
		print("capture ", s[0])
	main.get_tree().quit()

func _clear(main: Control) -> void:
	for c in main.overlay.get_children():
		c.queue_free()

func _wait(t: float) -> void:
	await Engine.get_main_loop().create_timer(t).timeout

func _drive_booster(main: Control) -> void:
	for c in main.overlay.get_children():
		if c.has_method("auto_tear"):
			c.auto_tear()

func _drive_battle(_main: Control) -> void:
	pass

## Simule un vrai toucher (appui + relâchement) à l'écran.
func _tap(main: Control, pos: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		main.get_viewport().push_input(e)
		await _wait(0.05)

## Simule un glissement du doigt.
func _drag(main: Control, a: Vector2, b: Vector2, steps := 12) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = a
	e.global_position = a
	main.get_viewport().push_input(e)
	var prev := a
	for i in steps + 1:
		var m := InputEventMouseMotion.new()
		m.position = a.lerp(b, float(i) / steps)
		m.relative = m.position - prev
		prev = m.position
		m.global_position = m.position
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		main.get_viewport().push_input(m)
		await _wait(0.03)
	var r := InputEventMouseButton.new()
	r.button_index = MOUSE_BUTTON_LEFT
	r.pressed = false
	r.position = b
	r.global_position = b
	main.get_viewport().push_input(r)

func _find_button(n: Node, text: String) -> Button:
	if n is Button and n.text == text:
		return n
	for c in n.get_children():
		var r := _find_button(c, text)
		if r:
			return r
	return null

func _ov(main: Control):
	var c: Array = main.overlay.get_children()
	return c[-1] if not c.is_empty() else null
