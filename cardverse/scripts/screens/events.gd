extends Control
## Événement en cours : présentation, monnaie, boss, booster dédié.

var main: Control

func setup(_p: Dictionary) -> void:
	main = get_meta("main")
	var ev := DB.active_event()
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 20)
	sc.add_child(m)
	var v := UI.vbox(16)
	m.add_child(v)
	if ev.is_empty():
		v.add_child(UI.label("Aucun événement en cours.", 28, UI.MUTED, "body", 700))
		return
	var col := Color(ev.color)
	var hero := Control.new()
	hero.custom_minimum_size = Vector2(0, 420)
	var bg := ColorRect.new()
	bg.size = Vector2(680, 420)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/menu_bg.gdshader")
	mat.set_shader_parameter("c1", Color("1a0604"))
	mat.set_shader_parameter("c2", col.darkened(0.3))
	mat.set_shader_parameter("c3", Color("ffb040").darkened(0.4))
	mat.set_shader_parameter("res", Vector2(680, 420))
	bg.material = mat
	hero.add_child(bg)
	var glow := UI.glow_rect(Color(col, 0.6), Vector2(600, 600), 1.6, 12.0)
	glow.position = Vector2(40, -90)
	hero.add_child(glow)
	var card := CardView.make("f006", 0.52, "holo")
	card.position = Vector2(340 - CardView.W * 0.26, 40)
	card.tapped.connect(func(_c): main.show_card("f006", "holo"))
	hero.add_child(card)
	v.add_child(hero)
	var t := UI.label(ev.name, 42, Color.WHITE, "serif", 800, HORIZONTAL_ALIGNMENT_CENTER)
	UI.outline(t, 8)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	v.add_child(UI.label("Du %s au %s" % [UI.date_fr(ev.start), UI.date_fr(ev.end)], 20, col.lightened(0.3), "body", 700, HORIZONTAL_ALIGNMENT_CENTER))
	var d := UI.label(ev.desc, 21, UI.TEXT, "body", 600)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	var bal := UI.hbox(10)
	bal.alignment = BoxContainer.ALIGNMENT_CENTER
	bal.add_child(UI.icon_rect("event", 54))
	bal.add_child(UI.label("%d %s" % [Profile.get_cur("event"), ev.currency], 30, Color.WHITE, "num", 400))
	v.add_child(bal)
	var boss := UI.button("Affronter : %s" % ev.boss.name, col.darkened(0.2), 26, Vector2(0, 96), "ui_battle")
	boss.pressed.connect(func():
		main.goto("battle_select"))
	v.add_child(boss)
	var b := DB.booster(ev.booster)
	var ob := UI.button("Booster de l'événement (%d %s)" % [int(b.price.event), ev.currency], Color("b8562a"), 24, Vector2(0, 96), "ui_gift")
	ob.pressed.connect(func():
		main.goto("shop", {"tab": "boosters"}))
	v.add_child(ob)
	var info := UI.label("Chaque combat rapporte des %s (davantage en cas de victoire, et encore plus contre le boss)." % ev.currency, 18, UI.MUTED, "body", 600)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(info)
