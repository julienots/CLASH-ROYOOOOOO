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
		["shop_offers", func(): _clear(main); main.goto("shop", {"tab": "offers"})],
		["shop_singles", func(): main.goto("shop", {"tab": "singles"})],
		["shop_style", func(): main.goto("shop", {"tab": "cosmetics"})],
		["shop_premium", func(): main.goto("shop", {"tab": "premium"})],
		["odds", func(): main.goto("shop"); await _wait(0.3); main.current._show_odds(DB.booster("divine"))],
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

func _ov(main: Control):
	var c: Array = main.overlay.get_children()
	return c[-1] if not c.is_empty() else null
