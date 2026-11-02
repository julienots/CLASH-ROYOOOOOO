extends Control
## Display : une caisse de boosters à ouvrir un par un. La rareté garantie tombe au plus tard au dernier booster.

var idx := 0
var dsp: Dictionary       # entrée de Profile.d.displays (mise à jour en place)
var dd: Dictionary        # définition (data/products.json)
var booster: Dictionary
var grid: GridContainer
var info: Label
var busy := false
var _t := 0.0
var _box: Control

func setup(i: int) -> void:
	idx = i
	dsp = Profile.d.displays[i]
	dd = DB.product("displays", dsp.id)
	booster = DB.booster(dd.booster)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var col := Color(dd.color)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/menu_bg.gdshader")
	m.set_shader_parameter("c1", Color(0.03, 0.02, 0.06))
	m.set_shader_parameter("c2", col.darkened(0.6))
	m.set_shader_parameter("c3", col.darkened(0.4))
	m.set_shader_parameter("res", size)
	bg.material = m
	add_child(bg)
	var glow := UI.glow_rect(Color(col, 0.35), Vector2(1000, 1000), 1.6, 10.0)
	glow.position = size / 2 - Vector2(500, 450)
	add_child(glow)
	var title := UI.label(dd.name, 44, Color.WHITE, "serif", 800, HORIZONTAL_ALIGNMENT_CENTER)
	UI.outline(title, 10)
	title.position = Vector2(0, 50)
	title.size = Vector2(size.x, 60)
	add_child(title)
	info = UI.label("", 22, UI.GOLD, "body", 800, HORIZONTAL_ALIGNMENT_CENTER)
	UI.outline(info, 6)
	info.position = Vector2(0, 112)
	info.size = Vector2(size.x, 34)
	add_child(info)
	# la caisse
	_box = Control.new()
	_box.position = Vector2(30, 170)
	_box.size = Vector2(size.x - 60, 860)
	add_child(_box)
	var back := Panel.new()
	back.size = _box.size
	back.add_theme_stylebox_override("panel", UI.box(col.darkened(0.55), 26, col.lightened(0.25), 5, 14))
	_box.add_child(back)
	var stripe := Panel.new()
	stripe.position = Vector2(0, 0)
	stripe.size = Vector2(_box.size.x, 70)
	stripe.add_theme_stylebox_override("panel", UI.box(col.darkened(0.15), 26, col.lightened(0.3), 3))
	_box.add_child(stripe)
	var logo := UI.label("CARDVERSE · %s" % DB.rarity(dd.guarantee).name.to_upper() + " GARANTI", 24, Color.WHITE, "serif", 800, HORIZONTAL_ALIGNMENT_CENTER)
	UI.outline(logo, 6)
	logo.size = Vector2(_box.size.x, 70)
	logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_box.add_child(logo)
	var sc := ScrollContainer.new()
	sc.position = Vector2(14, 84)
	sc.size = Vector2(_box.size.x - 28, _box.size.y - 98)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box.add_child(sc)
	grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 14)
	sc.add_child(grid)
	var close := UI.icon_button("ui_close", 70)
	close.position = Vector2(size.x - 92, 20)
	close.pressed.connect(func():
		Sfx.play("back")
		queue_free())
	add_child(close)
	var hint := UI.label("Touche un booster pour l'ouvrir · tu peux reprendre plus tard", 19, UI.TEXT, "body", 600, HORIZONTAL_ALIGNMENT_CENTER)
	hint.position = Vector2(0, size.y - 220)
	hint.size = Vector2(size.x, 30)
	add_child(hint)
	var next := UI.button("Ouvrir le suivant", col.darkened(0.15), 26, Vector2(380, 92), "ui_gift")
	next.position = Vector2(size.x / 2 - 190, size.y - 170)
	next.pressed.connect(func():
		if grid.get_child_count() > 0:
			_open(grid.get_child(0)))
	add_child(next)
	Sfx.play("whoosh")
	_build()
	_box.position.y = size.y
	create_tween().tween_property(_box, "position:y", 170.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _build() -> void:
	for c in grid.get_children():
		c.queue_free()
	var left := int(dsp.left)
	info.text = "%d / %d boosters restants%s" % [left, int(dd.count), " · garantie obtenue !" if dsp.hit else ""]
	for k in left:
		var b := TextureButton.new()
		b.texture_normal = DB.tex("res://assets/ui/packs/%s.png" % booster.id)
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(140, 216)
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.pivot_offset = Vector2(70, 108)
		b.pressed.connect(func(): _open(b))
		grid.add_child(b)

func _process(delta: float) -> void:
	_t += delta
	var i := 0
	for b in grid.get_children():
		b.rotation = sin(_t * 1.6 + i * 0.7) * 0.03
		i += 1

func _open(b: Control) -> void:
	if busy or int(dsp.left) <= 0:
		return
	busy = true
	Sfx.play("whoosh", 1.2)
	var t := b.create_tween().set_parallel(true)
	t.tween_property(b, "scale", Vector2(1.5, 1.5), 0.25).set_trans(Tween.TRANS_BACK)
	t.tween_property(b, "modulate:a", 0.0, 0.3).set_delay(0.1)
	await t.finished
	dsp.left = int(dsp.left) - 1
	var opts := {}
	if int(dsp.left) == 0 and not dsp.hit:
		opts.force_min = dd.guarantee
	var main = get_tree().root.get_node("Main")
	var o: Control = load("res://scripts/screens/shop.gd").open_pack(main, booster, opts)
	o.set_meta("no_again", true)
	for r in o.get_meta("results"):
		if DB.rarity_index(DB.card(r.id).rarity) >= DB.rarity_index(dd.guarantee):
			dsp.hit = true
	if int(dsp.left) <= 0:
		Profile.d.displays.erase(dsp)
	Profile.save_game()
	await o.tree_exited
	busy = false
	if int(dsp.left) <= 0:
		_finished()
	else:
		_build()

func _finished() -> void:
	_build()
	info.text = "Display terminé !"
	Sfx.play("victory")
	for i in 3:
		UI.burst(self, Vector2(randf_range(150, size.x - 150), randf_range(300, 700)), Color(dd.color).lightened(0.3), 60, 600, 0.7, 1.2, 300)
	var main = get_tree().root.get_node("Main")
	var l := UI.label("Tu as ouvert les %d boosters de ce display. Retrouve tes nouvelles cartes dans l'Album !" % int(dd.count), 22, UI.TEXT, "body", 600)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main.modal("Display terminé", l, [["Fermer", UI.ACCENT, func(): queue_free()]])

func _close() -> void:
	if busy:
		return
	Sfx.play("back")
	queue_free()
