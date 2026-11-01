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
	for i in steps + 1:
		var m := InputEventMouseMotion.new()
		m.position = a.lerp(b, float(i) / steps)
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

func _ov(main: Control):
	var c: Array = main.overlay.get_children()
	return c[-1] if not c.is_empty() else null
