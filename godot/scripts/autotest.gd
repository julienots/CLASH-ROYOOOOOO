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
	await _wait(5.0)
	await _shot("1_home")
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
	main._buy_chest(main.CHESTS[0])
	await _wait(2.4)
	await _shot("5_chest")
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
	b.deploy(0, "storm", 5.0, 4.0)
	b.deploy(0, "drake", -4.0, 3.0)
	b.deploy(0, "archers", 3.0, 6.0)
	await _wait(9.0)
	await _shot("9_fight")
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

func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
