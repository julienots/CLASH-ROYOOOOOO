extends Node
## Outil de développement : parcourt le jeu et enregistre des captures.
## Lancement : godot --path godot -- --shots=/chemin/dossier

var main: Node
var out := ""

func run(m: Node, dir: String) -> void:
	main = m
	out = dir
	DirAccess.make_dir_recursive_absolute(out)
	await _wait(1.0)
	await _shot("0_title")
	while not main.booted:
		await _wait(0.3)
	await _wait(1.5)
	await _shot("1_home")
	if OS.get_environment("SHOT_SEQ") == "chest":
		main._buy_chest(main.CHESTS[0])
		await _wait(2.4)
		print("STEP chest done")
		if OS.get_environment("PRESS_OK") != "":
			for b in main.root.find_children("*", "Button", true, false):
				if b.text == "OK":
					b.pressed.emit()
			await _wait(1.0)
			print("STEP ok pressed")
		main.tab = "clan"
		main._show_menu()
		print("STEP menu shown")
		await _wait(1.5)
		print("STEP waited")
		await _shot("seq")
		get_tree().quit()
		return
	if OS.get_environment("SHOT_ONLY") != "":
		main.tab = OS.get_environment("SHOT_ONLY")
		main.clan_sub = OS.get_environment("CLAN_SUB") if OS.get_environment("CLAN_SUB") != "" else "clan"
		main._show_menu()
		await _wait(1.5)
		await _shot("only_" + main.tab)
		get_tree().quit()
		return
	main.tab = "cards"
	main._show_menu()
	await _wait(1.2)
	await _shot("2_cards")
	main._card_popup("storm")
	await _wait(1.0)
	await _shot("3_popup")
	main.tab = "shop"
	main._show_menu()
	await _wait(1.0)
	await _shot("4_shop")
	Data.save.gems = 500
	main._buy_chest(main.CHESTS[2])
	await _wait(1.3)
	await _shot("5_chest_drop")
	_tap()
	await _wait(1.0)
	await _shot("5_chest_open")
	for i in 3:
		await _wait(0.6)
		await _shot("5_chest_reward%d" % i)
		_tap()
		await _wait(0.5)
	await _wait(0.8)
	await _shot("5_chest_end")
	for bt in main.root.find_children("*", "Button", true, false):
		if bt.text == "OK":
			bt.pressed.emit()
	await _wait(0.8)
	main.tab = "clan"
	main._show_menu()
	await _wait(1.0)
	await _shot("5b_clan")
	main.tab = "events"
	main._show_menu()
	await _wait(1.0)
	await _shot("5c_events")
	main.tab = "battle"
	Data.save.chests = [{"type": "gold", "state": "locked", "end": 0}, {"type": "wood", "state": "ready", "end": 0}, null, null]
	Data.save.crown_progress = 7
	main._show_menu()
	await _wait(1.5)
	await _shot("5d_home")
	main._quests_popup()
	await _wait(1.0)
	await _shot("5e_quests")
	main._show_menu()
	main._profile_popup()
	await _wait(1.0)
	await _shot("5f_profile")
	main.tab = "battle"
	main._build_menu_world()
	main._show_menu()
	await _wait(0.5)
	main._matchmaking()
	await _wait(3.2)
	await _shot("6_vs")
	while main.battle == null:
		await _wait(0.2)
	await _wait(1.0)
	await _shot("7_intro")
	var b: Battle = main.battle
	while not b.started:
		await _wait(0.2)
	b.essence[0] = 10.0
	b.deploy(0, "golem", -5.0, 8.0)
	await _wait(0.4)
	await _shot("8_deploy")
	b.essence[0] = 10.0
	b.deploy(0, "champion", 5.0, 4.0)
	b.deploy(0, "drake", -4.0, 3.0)
	b.essence[0] = 10.0
	b.deploy(0, "necro", 3.0, 6.0)
	b.deploy(0, "catapult", 0.0, 7.0)
	b.essence[1] = 10.0
	b.deploy(1, "warriors", 5.0, -4.0)
	b.deploy(1, "berserker", -5.0, -5.0)
	await _wait(9.0)
	await _shot("9_fight")
	b.essence[0] = 10.0
	b.deploy(0, "arrows", 5.0, -4.0)
	b.essence[0] = 10.0
	b.deploy(0, "rage", -4.0, 1.0)
	b.essence[0] = 10.0
	b.deploy(0, "meteor", 5.5, -10.5)
	await _wait(1.05)
	await _shot("10_meteor")
	for t in b.entities:
		if t.kind == "tower" and t.team == 1 and not t.core and t.alive:
			b._damage(t, 99999.0, true)
			break
	await _wait(0.5)
	await _shot("11_tower")
	await _wait(5.0)
	await _shot("12_fight2")
	for t in b.entities:
		if t.kind == "tower" and t.team == 1 and t.core and t.alive:
			b._damage(t, 99999.0, true)
	await _wait(6.0)
	await _shot("13_result")
	get_tree().quit()

func _tap() -> void:
	var taps = main.root.find_children("*", "Button", true, false).filter(func(b): return b.flat and b.text == "" and b.is_visible_in_tree())
	if taps.size() > 0:
		taps[-1].pressed.emit()

func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
