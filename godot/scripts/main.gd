extends Node
## Clash of Things — SuperEssence Studio. Écrans, menus, transitions et rendu des cartes.

const ENEMY_NAMES := ["Kraken_Lord", "Mira la Rusée", "ToxicPanda", "Sir Boulon", "LunaFlash", "Gromak", "NeoVortex", "Pixelion", "Zéphyr77", "La Taupe"]
const TIPS := ["Place le Colosse Barbare derrière ta Tour Cœur pour accumuler de l'essence.",
	"La Nova de Givre stoppe net une poussée ennemie.",
	"Le Totem Arcanique attire les unités qui visent les bâtiments.",
	"Les Arbalétrières touchent le Chevaucheur de Drake.",
	"La première frappe de la Lame Spectrale inflige le double de dégâts."]
const CHESTS := [
	{"id": "wood", "name": "Coffre de Bois", "price": 0, "gold": [60, 120], "gems": [0, 2], "tint": Color("a0642a")},
	{"id": "silver", "name": "Coffre d'Argent", "price": 30, "gold": [250, 400], "gems": [0, 5], "tint": Color("aab4c8")},
	{"id": "magic", "name": "Coffre Magique", "price": 90, "gold": [900, 1400], "gems": [5, 15], "tint": Color("b25cf0")},
]
const TABS := [["shop", "shop", "Boutique"], ["cards", "cards", "Cartes"], ["battle", "swords", "Combat"], ["islands", "island", "Îles"], ["settings", "gear", "Options"]]

var ui: CanvasLayer
var root: Control
var world: Node3D
var menu_pivot: Node3D
var battle: Battle
var tab = "battle"
var sel_card = ""
var res_labels = {}
var content: Control

func _ready() -> void:
	ui = CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	root = Control.new()
	UI.full_rect(root)
	root.theme = UI.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	_boot()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			var t = load("res://scripts/autotest.gd").new()
			add_child(t)
			t.run(self, a.substr(8))

# ================= Démarrage =================
func _boot() -> void:
	var title = _title_screen()
	await get_tree().process_frame
	var bar: ProgressBar = title.get_meta("bar")
	await _render_cards(bar)
	var tw = create_tween()
	tw.tween_property(bar, "value", 100.0, 0.4)
	await tw.finished
	await get_tree().create_timer(0.3).timeout
	_build_menu_world()
	var fade = create_tween()
	fade.tween_property(title, "modulate:a", 0.0, 0.4)
	fade.tween_callback(title.queue_free)
	_show_menu()

func _title_screen() -> Control:
	var c = ColorRect.new()
	c.color = Color("1756c9")
	UI.full_rect(c)
	root.add_child(c)
	var rays = Rays.new()
	UI.full_rect(rays)
	c.add_child(rays)
	var v = VBoxContainer.new()
	UI.full_rect(v)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	c.add_child(v)
	var l1 = UI.label("CLASH", 150, Color.WHITE, 26)
	var l2 = UI.label("OF THINGS", 110, UI.GOLD, 24)
	for l in [l1, l2]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_constant_override("shadow_offset_y", 10)
		l.add_theme_color_override("font_shadow_color", UI.INK)
		v.add_child(l)
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 260
	v.add_child(spacer)
	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(480, 40)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", UI.panel(UI.INK, 16))
	var fill = StyleBoxFlat.new()
	fill.bg_color = UI.GOLD
	fill.set_corner_radius_all(12)
	bar.add_theme_stylebox_override("fill", fill)
	v.add_child(bar)
	var hint = UI.label("Les îles flottantes se réveillent…", 26)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	var by = UI.label("SuperEssence Studio", 26, Color(1, 1, 1, 0.85), 6)
	by.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	by.grow_horizontal = Control.GROW_DIRECTION_BOTH
	by.position.y -= 70
	c.add_child(by)
	c.set_meta("bar", bar)
	# le logo tombe et rebondit
	for l in [l1, l2]:
		l.pivot_offset = Vector2(360, 80)
	l1.scale = Vector2(3, 3)
	l1.modulate.a = 0
	l2.scale = Vector2(3, 3)
	l2.modulate.a = 0
	var tw = create_tween()
	tw.tween_property(l1, "modulate:a", 1.0, 0.1)
	tw.parallel().tween_property(l1, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(l2, "modulate:a", 1.0, 0.1)
	tw.parallel().tween_property(l2, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): l1.rotation = -0.05; l2.rotation = 0.04)
	return c

## Rend chaque carte à partir de son vrai modèle 3D.
func _render_cards(bar: ProgressBar) -> void:
	var vp = SubViewport.new()
	vp.size = Vector2i(256, 320)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	vp.add_child(env)
	var key = DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-35), deg_to_rad(25), 0)
	key.light_energy = 1.4
	vp.add_child(key)
	var rim = DirectionalLight3D.new()
	rim.rotation = Vector3(deg_to_rad(-20), deg_to_rad(200), 0)
	rim.light_color = Color("9fd8ff")
	rim.light_energy = 1.2
	vp.add_child(rim)
	var cam = Camera3D.new()
	cam.fov = 30
	vp.add_child(cam)
	cam.current = true
	var framing = {"drake": [5.4, 0.2, 1.0], "totem": [5.4, 1.3, 0.4],
		"meteor": [4.2, 0.0, 0.3], "frost": [3.8, 0.6, 0.3], "swarm": [2.6, 0.45, 0.4], "sapper": [3.4, 0.75, 0.5], "pyro": [4.0, 0.85, 0.4], "storm": [6.4, 1.3, 0.8], "golem": [6.6, 1.3, 0.8]}
	var ids = Data.playable()
	var n = 0
	for id in ids:
		var model = Models.build(id, 0)
		if id == "archers":
			var b = Models.build(id, 0)
			b.position = Vector3(0.6, 0, -0.5)
			model.add_child(b)
			model.position.x = -0.25
		elif id == "swarm":
			for k in 2:
				var b = Models.build(id, 0)
				b.position = Vector3(0.5 if k else -0.5, 0, -0.5)
				model.add_child(b)
		model.rotation.y = 0.5
		vp.add_child(model)
		_pose_card_model(model)
		var f: Array = framing.get(id, [3.6, 0.85, 0.4])
		cam.position = Vector3(0, f[1] + f[2] + 0.3, f[0])
		cam.look_at(Vector3(0, f[1], 0))
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img = vp.get_texture().get_image()
		Data.card_textures[id] = ImageTexture.create_from_image(_compose_card(img, Data.CARDS[id]))
		model.queue_free()
		n += 1
		bar.value = 90.0 * n / ids.size()
	vp.queue_free()

func _pose_card_model(n: Node) -> void:
	if n.has_meta("real"):
		RealModels.pose(n)
	for c in n.get_children():
		if c is Node3D:
			_pose_card_model(c)

func _compose_card(art: Image, c: Dictionary) -> Image:
	var W = art.get_width()
	var H = art.get_height()
	art.convert(Image.FORMAT_RGBA8)
	var out = Image.create(W, H, false, Image.FORMAT_RGBA8)
	var rar: Dictionary = Data.RARITY[c.rarity]
	var top: Color = rar.bg[0]
	var bot: Color = rar.bg[1]
	for y in H:
		var row = top.lerp(bot, float(y) / H)
		out.fill_rect(Rect2i(0, y, W, 1), row)
	# halo central
	var center = Vector2(W / 2.0, H * 0.45)
	for y in range(0, H, 2):
		for x in range(0, W, 2):
			var d = Vector2(x, y).distance_to(center) / (W * 0.7)
			if d < 1.0:
				var col = out.get_pixel(x, y).lerp(Color.WHITE, (1.0 - d) * 0.3)
				out.fill_rect(Rect2i(x, y, 2, 2), col)
	out.blend_rect(art, Rect2i(0, 0, W, H), Vector2i.ZERO)
	if c.type == "spell":
		out.fill_rect(Rect2i(0, H - 44, W, 44), Color(0, 0, 0, 0.35))
	# bordure de rareté + coins arrondis
	var bc: Color = rar.color
	var R = 22
	var bw = 9
	for y in H:
		for x in W:
			var cx: float = clamp(x, R, W - 1 - R)
			var cy: float = clamp(y, R, H - 1 - R)
			var dist = Vector2(x - cx, y - cy).length()
			if dist > R:
				out.set_pixel(x, y, Color(0, 0, 0, 0))
			elif dist > R - bw or x < bw or y < bw or x >= W - bw or y >= H - bw:
				out.set_pixel(x, y, bc)
			elif dist > R - bw - 3 or x < bw + 3 or y < bw + 3 or x >= W - bw - 3 or y >= H - bw - 3:
				out.set_pixel(x, y, out.get_pixel(x, y).lerp(Color.WHITE, 0.45))
	return out

# ================= Monde 3D du menu =================
func _build_menu_world() -> void:
	if world:
		world.queue_free()
	var isl = Data.island_for(Data.save.trophies)
	world = Node3D.new()
	add_child(world)
	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = isl.sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.9, 1)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	world.add_child(env)
	var sun = DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(-35), 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	world.add_child(sun)
	menu_pivot = Node3D.new()
	world.add_child(menu_pivot)
	var arena = Models.arena(isl)
	menu_pivot.add_child(arena)
	for team in [0, 1]:
		var s = 1.0 if team == 0 else -1.0
		for x in [-5.5, 5.5]:
			var t = Models.tower(team, false)
			t.position = Vector3(x, 0, 10.5 * s)
			if team:
				t.rotation.y = PI
			menu_pivot.add_child(t)
		var c = Models.tower(team, true)
		c.position = Vector3(0, 0, 13.6 * s)
		if team:
			c.rotation.y = PI
		menu_pivot.add_child(c)
	var heroes = [["archers", "Cheer"], ["pyro", "Spellcasting"], ["golem", "Cheer"], ["shield", "Cheer"], ["blade", "Cheer"]]
	for i in heroes.size():
		var m = Models.build(heroes[i][0], 0)
		m.position = Vector3((i - 2) * 2.6, 0.0, 3.5 + abs(i - 2) * 0.8)
		m.scale = Vector3.ONE * (1.3 if heroes[i][0] == "golem" else 1.7)
		menu_pivot.add_child(m)
		var ap: AnimationPlayer = m.get_meta("ap")
		ap.get_animation(heroes[i][1]).loop_mode = Animation.LOOP_LINEAR
		ap.play(heroes[i][1])
		ap.seek(i * 0.37, true)
	menu_pivot.scale = Vector3.ONE * 0.75
	var cam = Camera3D.new()
	cam.fov = 42
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.position = Vector3(0, 21, 27)
	world.add_child(cam)
	cam.look_at(Vector3(0, -1, 0))
	cam.current = true

func _process(_dt: float) -> void:
	if world and menu_pivot:
		var t = Time.get_ticks_msec() / 1000.0
		menu_pivot.rotation.y = t * 0.12
		for c in menu_pivot.get_children():
			if c.has_meta("seed"):
				Models.animate(c, t, true, 0.0, c.get_meta("seed"))
				c.rotation.y = 0.0

# ================= Menus =================
func _show_menu() -> void:
	for c in root.get_children():
		c.queue_free()
	var page = VBoxContainer.new()
	UI.full_rect(page)
	page.add_theme_constant_override("separation", 0)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(page)
	page.add_child(_top_bar())
	content = Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.clip_contents = true
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(content)
	page.add_child(_nav_bar())
	_show_tab(tab, 0)

func _top_bar() -> Control:
	var p = PanelContainer.new()
	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.03, 0.08, 0.22, 0.85)
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 18
	st.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", st)
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	var av = PanelContainer.new()
	av.add_theme_stylebox_override("panel", UI.panel(UI.GOLD, 14))
	av.custom_minimum_size = Vector2(64, 64)
	var al = UI.label(str(Data.save.name).substr(0, 1).to_upper(), 36)
	al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	av.add_child(al)
	h.add_child(av)
	var nv = VBoxContainer.new()
	nv.add_theme_constant_override("separation", -6)
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nv.add_child(UI.label(Data.save.name, 28))
	nv.add_child(UI.label(Data.island_for(Data.save.trophies).name, 20, Color("9fd6ff"), 5))
	h.add_child(nv)
	for k in [["trophies", "trophy", Color("ffd54a")], ["gold", "coin", Color.WHITE], ["gems", "gem", Color("7cf27a")]]:
		var b = PanelContainer.new()
		var bs = UI.panel(Color(0, 0, 0, 0.5), 30)
		bs.content_margin_top = 4
		bs.content_margin_bottom = 4
		bs.content_margin_left = 6
		b.add_theme_stylebox_override("panel", bs)
		var bh = HBoxContainer.new()
		bh.add_theme_constant_override("separation", 4)
		b.add_child(bh)
		bh.add_child(UI.icon(k[1], 38))
		var l = UI.label(str(Data.save[k[0]]), 24, k[2], 6)
		bh.add_child(l)
		res_labels[k[0]] = l
		h.add_child(b)
	return p

func _refresh_resources() -> void:
	for k in res_labels:
		var l: Label = res_labels[k]
		var from = int(l.text)
		var to = int(Data.save[k])
		if from == to:
			continue
		var tw = create_tween()
		tw.tween_method(func(v: float): l.text = str(int(v)), float(from), float(to), 0.6)
		UI.squash(l.get_parent().get_parent(), 1.0)

func _nav_bar() -> Control:
	var p = PanelContainer.new()
	var st = StyleBoxFlat.new()
	st.bg_color = Color("1b3f8a")
	st.border_width_top = 5
	st.border_color = UI.INK
	st.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", st)
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	p.add_child(h)
	for t in TABS:
		var on: bool = tab == t[0]
		var b = Button.new()
		b.flat = not on
		b.custom_minimum_size = Vector2(0, 118)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_stretch_ratio = 1.5 if on else 1.0
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color("3f7cf0") if on else Color(0, 0, 0, 0)
		sb.corner_radius_top_left = 18
		sb.corner_radius_top_right = 18
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var v = VBoxContainer.new()
		UI.full_rect(v)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 0)
		var ic = UI.icon(t[1], 66 if on else 54)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(ic)
		var l = UI.label(t[2], 22 if on else 18, Color.WHITE, 6)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		b.add_child(v)
		if on:
			ic.pivot_offset = Vector2(33, 33)
			var tw = ic.create_tween().set_loops()
			tw.tween_property(ic, "rotation", 0.08, 0.6).set_trans(Tween.TRANS_SINE)
			tw.tween_property(ic, "rotation", -0.08, 0.6).set_trans(Tween.TRANS_SINE)
		var id: String = t[0]
		b.pressed.connect(func():
			Sfx.play("click")
			if id == tab:
				return
			var dir = 1 if _tab_index(id) > _tab_index(tab) else -1
			tab = id
			sel_card = ""
			var nav = p.get_parent()
			var idx = p.get_index()
			p.queue_free()
			var nb = _nav_bar()
			nav.add_child(nb)
			nav.move_child(nb, idx)
			_show_tab(id, dir))
		h.add_child(b)
	return p

func _tab_index(id: String) -> int:
	for i in TABS.size():
		if TABS[i][0] == id:
			return i
	return 0

## Change d'onglet avec un glissement latéral.
func _show_tab(id: String, dir: int) -> void:
	var old = content.get_children()
	var page = _build_tab(id)
	content.add_child(page)
	if dir != 0:
		var w = content.size.x
		page.position.x = w * dir
		var tw = create_tween().set_parallel()
		tw.tween_property(page, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		for o in old:
			tw.tween_property(o, "position:x", -w * dir, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.chain().tween_callback(func():
			for o in old:
				o.queue_free())
	else:
		for o in old:
			o.queue_free()
	_bg_dim(id != "battle")

func _bg_dim(on: bool) -> void:
	var dim: ColorRect = root.get_node_or_null("Dim")
	if dim == null:
		dim = ColorRect.new()
		dim.name = "Dim"
		dim.color = Color("173f9a")
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UI.full_rect(dim)
		root.add_child(dim)
		root.move_child(dim, 0)
		dim.modulate.a = 0.0
	create_tween().tween_property(dim, "modulate:a", 1.0 if on else 0.0, 0.25)

func _build_tab(id: String) -> Control:
	var page: Control
	match id:
		"battle": page = _tab_home()
		"cards": page = _tab_cards()
		"shop": page = _tab_shop()
		"islands": page = _tab_islands()
		_: page = _tab_settings()
	return page

func _scroll(inner: Control) -> ScrollContainer:
	var s = ScrollContainer.new()
	s.size = content.size
	UI.full_rect(s)
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var m = MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 20)
	m.add_child(inner)
	s.add_child(m)
	return s

func _ribbon(text: String) -> Control:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(Color("3f8cf0"), 10, 4, 4))
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var l = UI.label(text, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = 360
	p.add_child(l)
	UI.pop_in(p, 0.1)
	return p

# ---------- Accueil ----------
func _tab_home() -> Control:
	var page = Control.new()
	page.size = content.size
	UI.full_rect(page)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var isl = Data.island_for(Data.save.trophies)
	var nxt = Data.next_island(Data.save.trophies)
	var head = PanelContainer.new()
	head.add_theme_stylebox_override("panel", UI.panel(Color(0.03, 0.08, 0.22, 0.75), 22))
	head.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	head.grow_horizontal = Control.GROW_DIRECTION_BOTH
	head.position.y = 24
	head.custom_minimum_size.x = 560
	var hv = VBoxContainer.new()
	hv.add_theme_constant_override("separation", 4)
	head.add_child(hv)
	var cap = UI.label("Arène actuelle", 22, Color("bcd4ff"), 6)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hv.add_child(cap)
	var nm = UI.label(isl.name, 52, UI.GOLD, 12)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hv.add_child(nm)
	var road = ProgressBar.new()
	road.custom_minimum_size.y = 34
	road.show_percentage = false
	road.add_theme_stylebox_override("background", UI.panel(UI.INK, 14))
	var rf = StyleBoxFlat.new()
	rf.bg_color = Color("ffb300")
	rf.set_corner_radius_all(10)
	road.add_theme_stylebox_override("fill", rf)
	var pct = 100.0
	if nxt:
		pct = 100.0 * (Data.save.trophies - isl.trophies) / float(nxt.trophies - isl.trophies)
	road.value = 0
	create_tween().tween_property(road, "value", pct, 0.8).set_delay(0.3).set_trans(Tween.TRANS_CUBIC)
	var rl = UI.label("%d / %d → %s" % [Data.save.trophies, nxt.trophies, nxt.name] if nxt else "Île maximale atteinte !", 20, Color.WHITE, 6)
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.full_rect(rl)
	road.add_child(rl)
	hv.add_child(road)
	page.add_child(head)
	UI.slide_in(head, Vector2(0, -300), 0.0, 0.5)

	var bottom = VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.position.y -= 24
	bottom.add_theme_constant_override("separation", 14)
	bottom.alignment = BoxContainer.ALIGNMENT_END
	var deck = HBoxContainer.new()
	deck.add_theme_constant_override("separation", 6)
	deck.alignment = BoxContainer.ALIGNMENT_CENTER
	var i = 0
	for id in Data.save.deck:
		var t = TextureRect.new()
		t.texture = Data.card_textures[id]
		t.custom_minimum_size = Vector2(76, 96)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		deck.add_child(t)
		UI.pop_in(t, 0.15 + i * 0.05)
		i += 1
	bottom.add_child(deck)
	var go = UI.button("Combat", UI.GOLD, 64)
	go.custom_minimum_size = Vector2(420, 130)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(_matchmaking)
	bottom.add_child(go)
	var shine = Shine.new()
	UI.full_rect(shine)
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	go.add_child(shine)
	go.clip_contents = true
	var rec = UI.label("%d victoires · %d défaites" % [Data.save.wins, Data.save.losses], 22, Color.WHITE, 6)
	rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(rec)
	page.add_child(bottom)
	UI.pop_in(go, 0.2)
	get_tree().create_timer(0.9).timeout.connect(func():
		if is_instance_valid(go):
			UI.pulse(go, 1.05, 1.3))
	return page

# ---------- Cartes ----------
func _card_tile(id: String, show_name := false) -> Control:
	var c: Dictionary = Data.CARDS[id]
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btn = TextureButton.new()
	btn.texture_normal = Data.card_textures[id]
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.custom_minimum_size = Vector2(140, 175)
	var cost = UI.icon("drop", 48)
	cost.position = Vector2(-6, -8)
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cl = UI.label(str(c.cost), 26)
	UI.full_rect(cl)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cl.position.y += 4
	cost.add_child(cl)
	btn.add_child(cost)
	var lv = UI.label("Niv. %d" % Data.save.levels[id], 20, Color.WHITE, 6)
	lv.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	lv.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lv.position.y -= 34
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lv)
	v.add_child(btn)
	if show_name:
		var nl = UI.label(c.name, 18, Color.WHITE, 5)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD
		nl.custom_minimum_size.x = 140
		v.add_child(nl)
	if sel_card == id:
		btn.pivot_offset = Vector2(70, 88)
		var tw = btn.create_tween().set_loops()
		tw.tween_property(btn, "rotation", 0.05, 0.12)
		tw.tween_property(btn, "rotation", -0.05, 0.12)
		btn.scale = Vector2(1.06, 1.06)
	btn.pressed.connect(_on_card_tap.bind(id))
	btn.button_down.connect(func(): Sfx.play("click"); btn.pivot_offset = btn.size / 2; btn.scale = Vector2(0.94, 0.94))
	btn.button_up.connect(func(): btn.create_tween().tween_property(btn, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT))
	return v

func _on_card_tap(id: String) -> void:
	if sel_card != "" and sel_card != id:
		var a: int = Data.save.deck.find(sel_card)
		var b: int = Data.save.deck.find(id)
		if (a >= 0) != (b >= 0):
			if a >= 0:
				Data.save.deck[a] = id
			else:
				Data.save.deck[b] = sel_card
			Data.persist()
			sel_card = ""
			Sfx.play("pop")
			_rebuild_tab()
			return
	sel_card = ""
	_card_popup(id)

func _rebuild_tab() -> void:
	for o in content.get_children():
		o.queue_free()
	content.add_child(_build_tab(tab))

func _tab_cards() -> Control:
	var v = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 14)
	v.add_child(_ribbon("Deck de combat"))
	var dp = PanelContainer.new()
	dp.add_theme_stylebox_override("panel", UI.panel(Color(0.02, 0.06, 0.18, 0.55), 22))
	var g = GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	dp.add_child(g)
	var i = 0
	for id in Data.save.deck:
		var t = _card_tile(id)
		g.add_child(t)
		UI.pop_in(t, i * 0.035)
		i += 1
	v.add_child(dp)
	var total = 0.0
	for id in Data.save.deck:
		total += Data.CARDS[id].cost
	var info = HBoxContainer.new()
	info.add_child(UI.icon("drop", 36))
	info.add_child(UI.label("Coût moyen : %.1f" % (total / 8.0), 24, Color("f2a5ff"), 6))
	var sp = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(sp)
	var hint = "Touche une carte du deck pour l'échanger" if sel_card in Data.save.deck else ("Touche une carte du deck à remplacer" if sel_card != "" else "Touche une carte pour la voir")
	info.add_child(UI.label(hint, 18, Color(1, 1, 1, 0.8), 5))
	v.add_child(info)
	v.add_child(UI.label("Collection", 34))
	var cp = PanelContainer.new()
	cp.add_theme_stylebox_override("panel", UI.panel(Color(0.02, 0.06, 0.18, 0.55), 22))
	var g2 = GridContainer.new()
	g2.columns = 4
	g2.add_theme_constant_override("h_separation", 12)
	g2.add_theme_constant_override("v_separation", 12)
	cp.add_child(g2)
	for id in Data.playable():
		if not id in Data.save.deck:
			var t = _card_tile(id, true)
			g2.add_child(t)
			UI.pop_in(t, 0.2 + i * 0.035)
			i += 1
	v.add_child(cp)
	return _scroll(v)

func _modal() -> Array:
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.0)
	UI.full_rect(bg)
	root.add_child(bg)
	create_tween().tween_property(bg, "color:a", 0.6, 0.2)
	var center = CenterContainer.new()
	UI.full_rect(center)
	bg.add_child(center)
	var box = PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.panel(Color("2457c4"), 26))
	box.custom_minimum_size.x = 620
	center.add_child(box)
	await get_tree().process_frame
	UI.pop_in(box, 0.0, 0.5)
	return [bg, box]

func _close_modal(bg: Control) -> void:
	var tw = create_tween()
	tw.tween_property(bg, "modulate:a", 0.0, 0.15)
	tw.tween_callback(bg.queue_free)

func _card_popup(id: String) -> void:
	var m = await _modal()
	var bg: Control = m[0]
	var box: Control = m[1]
	var c: Dictionary = Data.CARDS[id]
	var lvl: int = Data.save.levels[id]
	var mult = Data.level_mult(lvl)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	box.add_child(v)
	var t = UI.label(c.name, 46)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var r = UI.label("%s · Niveau %d" % [Data.RARITY[c.rarity].label, lvl], 24, Data.RARITY[c.rarity].color, 6)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(r)
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var img = TextureRect.new()
	img.texture = Data.card_textures[id]
	img.custom_minimum_size = Vector2(170, 212)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(img)
	var d = UI.label(c.desc, 24)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(d)
	v.add_child(h)
	var stats = []
	if c.has("hp"):
		stats.append(["Points de vie", str(int(c.hp * mult)) + (" + %d bouclier" % int(c.shield * mult) if c.has("shield") else "")])
	if c.has("dmg"):
		stats.append(["Dégâts de zone" if c.type == "spell" else "Dégâts", str(int(c.dmg * mult))])
	if c.has("hit_speed") and c.attack != "kamikaze":
		stats.append(["Vitesse d'attaque", "%.1f s" % c.hit_speed])
	if c.has("speed"):
		var s: float = c.speed
		stats.append(["Vitesse", "Très rapide" if s >= 2 else ("Rapide" if s >= 1.4 else ("Moyenne" if s >= 1.1 else "Lente"))])
	if c.has("range"):
		stats.append(["Portée", "Mêlée" if c.range < 1.5 else "%.1f" % c.range])
	if c.has("targets"):
		stats.append(["Cibles", {"ground": "Terrestres", "both": "Air & sol", "buildings": "Bâtiments"}[c.targets]])
	if c.has("count"):
		stats.append(["Nombre", "x%d" % c.count])
	if c.type == "spell":
		stats.append(["Rayon", str(c.radius)])
	if c.has("lifetime"):
		stats.append(["Durée", "%d s" % c.lifetime])
	if c.has("freeze"):
		stats.append(["Gel", "%d s" % c.freeze])
	var g = GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	var k = 0
	for s in stats:
		var sp = PanelContainer.new()
		var ss = UI.panel(Color(0, 0, 0, 0.3), 12)
		ss.border_width_left = 0
		ss.border_width_right = 0
		ss.border_width_top = 0
		ss.border_width_bottom = 0
		ss.set_content_margin_all(8)
		sp.add_theme_stylebox_override("panel", ss)
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sv = VBoxContainer.new()
		sv.add_theme_constant_override("separation", -4)
		sv.add_child(UI.label(s[0], 18, Color("bcd4ff"), 5))
		sv.add_child(UI.label(s[1], 26))
		sp.add_child(sv)
		g.add_child(sp)
		UI.pop_in(sp, 0.15 + k * 0.04)
		k += 1
	v.add_child(g)
	var acts = HBoxContainer.new()
	acts.add_theme_constant_override("separation", 12)
	var cost = Data.upgrade_cost(lvl)
	var up = UI.button("Améliorer · %d or" % cost if lvl < Data.MAX_LEVEL else "Niveau max", UI.GREEN, 26)
	up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	up.disabled = lvl >= Data.MAX_LEVEL or Data.save.gold < cost
	up.pressed.connect(func():
		Data.save.gold -= cost
		Data.save.levels[id] += 1
		Data.persist()
		Sfx.play("win")
		_refresh_resources()
		_level_up_fx(img)
		await get_tree().create_timer(0.9).timeout
		_close_modal(bg)
		_rebuild_tab())
	acts.add_child(up)
	var use = UI.button("Échanger" if id in Data.save.deck else "Utiliser", UI.BLUE, 26)
	use.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	use.pressed.connect(func():
		sel_card = id
		_close_modal(bg)
		_rebuild_tab())
	acts.add_child(use)
	v.add_child(acts)
	var close = UI.button("Fermer", UI.RED, 24)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_close_modal.bind(bg))
	v.add_child(close)

func _level_up_fx(img: Control) -> void:
	img.pivot_offset = img.size / 2
	var tw = img.create_tween()
	tw.tween_property(img, "scale", Vector2(1.35, 1.35), 0.15).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(img, "rotation", TAU, 0.5)
	tw.tween_property(img, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var l = UI.label("NIVEAU +1 !", 44, UI.GOLD, 12)
	img.add_child(l)
	l.position = Vector2(-20, 60)
	var t2 = l.create_tween()
	t2.tween_property(l, "position:y", -40.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t2.parallel().tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.5)

# ---------- Boutique ----------
func _tab_shop() -> Control:
	var v = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 16)
	v.add_child(_ribbon("Boutique"))
	var offer = PanelContainer.new()
	offer.add_theme_stylebox_override("panel", UI.panel(Color("ff9f1f"), 24))
	var oh = HBoxContainer.new()
	oh.add_theme_constant_override("separation", 16)
	offer.add_child(oh)
	var gem = UI.icon("gem", 130)
	oh.add_child(gem)
	gem.pivot_offset = Vector2(65, 65)
	var gt = gem.create_tween().set_loops()
	gt.tween_property(gem, "position:y", -10.0, 0.9).set_trans(Tween.TRANS_SINE).as_relative()
	gt.tween_property(gem, "position:y", 10.0, 0.9).set_trans(Tween.TRANS_SINE).as_relative()
	var ov = VBoxContainer.new()
	ov.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ov.add_child(UI.label("Offre de bienvenue", 36))
	var od = UI.label("100 gemmes et 1000 pièces d'or, gratuites !", 22)
	od.autowrap_mode = TextServer.AUTOWRAP_WORD
	ov.add_child(od)
	var claimed: bool = Data.save.welcome
	var wb = UI.button("Récupérée" if claimed else "Récupérer", UI.GREEN, 28)
	wb.disabled = claimed
	wb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	wb.pressed.connect(func():
		Data.save.welcome = true
		Data.save.gems += 100
		Data.save.gold += 1000
		Data.persist()
		_reward_burst(wb.global_position + wb.size / 2, ["gem", "coin"])
		_refresh_resources()
		wb.disabled = true
		wb.text = "Récupérée")
	ov.add_child(wb)
	oh.add_child(ov)
	v.add_child(offer)
	UI.pop_in(offer, 0.1)
	v.add_child(UI.label("Coffres", 34))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var free_ready = Time.get_unix_time_from_system() - float(Data.save.get("last_free", 0)) > 4 * 3600
	var k = 0
	for c in CHESTS:
		var p = PanelContainer.new()
		p.add_theme_stylebox_override("panel", UI.panel(Color("2f63cf"), 20))
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv = VBoxContainer.new()
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		var ic = UI.icon("chest", 110)
		ic.tint = c.tint
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cv.add_child(ic)
		var nl = UI.label(c.name, 22)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(nl)
		var gl = UI.label("%d–%d or" % c.gold, 18, Color("ffd84a"), 5)
		gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(gl)
		var label = ("Gratuit" if free_ready else "Bientôt") if c.price == 0 else "%d gemmes" % c.price
		var b = UI.button(label, UI.GREEN if c.price == 0 else UI.BLUE, 22)
		b.disabled = c.price == 0 and not free_ready
		b.pressed.connect(_buy_chest.bind(c))
		cv.add_child(b)
		p.add_child(cv)
		row.add_child(p)
		UI.pop_in(p, 0.2 + k * 0.08)
		k += 1
	v.add_child(row)
	v.add_child(UI.label("Or", 34))
	var row2 = HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	for pack in [[1000, 60], [5000, 250], [20000, 900]]:
		var p = PanelContainer.new()
		p.add_theme_stylebox_override("panel", UI.panel(Color("2f63cf"), 20))
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv = VBoxContainer.new()
		var ic = UI.icon("coin", 90)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cv.add_child(ic)
		var nl = UI.label("%d or" % pack[0], 24)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(nl)
		var b = UI.button("%d gemmes" % pack[1], UI.BLUE, 22)
		b.pressed.connect(func():
			if Data.save.gems < pack[1]:
				Sfx.play("no")
				_toast("Pas assez de gemmes")
				return
			Data.save.gems -= pack[1]
			Data.save.gold += pack[0]
			Data.persist()
			_reward_burst(b.global_position + b.size / 2, ["coin"])
			_refresh_resources())
		cv.add_child(b)
		p.add_child(cv)
		row2.add_child(p)
		UI.pop_in(p, 0.45 + k * 0.08)
		k += 1
	v.add_child(row2)
	return _scroll(v)

func _buy_chest(c: Dictionary) -> void:
	if c.price > 0 and Data.save.gems < c.price:
		Sfx.play("no")
		_toast("Pas assez de gemmes")
		return
	if c.price > 0:
		Data.save.gems -= c.price
	else:
		Data.save.last_free = Time.get_unix_time_from_system()
	var gold = randi_range(c.gold[0], c.gold[1])
	var gems = randi_range(c.gems[0], c.gems[1])
	Data.save.gold += gold
	Data.save.gems += gems
	Data.persist()
	_open_chest(c, gold, gems)

## Ouverture de coffre : il tremble, saute, explose en lumière, puis le butin apparaît.
func _open_chest(c: Dictionary, gold: int, gems: int) -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.02, 0.05, 0.15, 0.0)
	UI.full_rect(bg)
	root.add_child(bg)
	create_tween().tween_property(bg, "color:a", 0.92, 0.25)
	var rays = Rays.new()
	UI.full_rect(rays)
	rays.color = Color(1, 0.85, 0.3, 0.0)
	bg.add_child(rays)
	var chest = UI.icon("chest", 260)
	chest.tint = c.tint
	chest.size = Vector2(260, 260)
	bg.add_child(chest)
	var vp = get_viewport().get_visible_rect().size
	chest.position = Vector2(vp.x / 2 - 130, -300)
	chest.pivot_offset = Vector2(130, 200)
	var tw = create_tween()
	tw.tween_property(chest, "position:y", vp.y / 2 - 200, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): Sfx.play("hit", 0.6))
	for i in 6:
		tw.tween_property(chest, "rotation", 0.12 * (1 if i % 2 else -1) * (1 + i * 0.3), 0.07)
	tw.tween_property(chest, "rotation", 0.0, 0.05)
	tw.tween_property(chest, "scale", Vector2(1.2, 0.75), 0.12)
	tw.tween_property(chest, "scale", Vector2(0.9, 1.25), 0.1)
	tw.parallel().tween_property(chest, "position:y", vp.y / 2 - 280, 0.1)
	tw.tween_callback(func():
		Sfx.play("win")
		var flash = ColorRect.new()
		flash.color = Color.WHITE
		UI.full_rect(flash)
		bg.add_child(flash)
		flash.create_tween().tween_property(flash, "color:a", 0.0, 0.5)
		rays.create_tween().tween_property(rays, "color:a", 0.35, 0.3))
	tw.tween_property(chest, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(chest, "position:y", vp.y / 2 - 380, 0.4)
	await tw.finished
	var loot = HBoxContainer.new()
	loot.add_theme_constant_override("separation", 40)
	loot.position = Vector2(vp.x / 2 - 220, vp.y / 2)
	loot.custom_minimum_size.x = 440
	loot.alignment = BoxContainer.ALIGNMENT_CENTER
	bg.add_child(loot)
	var items = [["coin", gold, Color("ffd84a")]]
	if gems > 0:
		items.append(["gem", gems, Color("7cf27a")])
	var k = 0
	for it in items:
		var col = VBoxContainer.new()
		var ic = UI.icon(it[0], 120)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(ic)
		var l = UI.label("+0", 54, it[2], 12)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
		loot.add_child(col)
		UI.pop_in(col, k * 0.25)
		var amount: int = it[1]
		var ct = l.create_tween()
		ct.tween_interval(0.2 + k * 0.25)
		ct.tween_method(func(v: float): l.text = "+%d" % int(v), 0.0, float(amount), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		ct.tween_callback(func(): Sfx.play("coin"))
		k += 1
	var ok = UI.button("OK", UI.GOLD, 40)
	ok.custom_minimum_size = Vector2(260, 100)
	ok.position = Vector2(vp.x / 2 - 130, vp.y / 2 + 300)
	bg.add_child(ok)
	UI.pop_in(ok, 0.8)
	ok.pressed.connect(func():
		_close_modal(bg)
		_refresh_resources()
		_rebuild_tab())

func _reward_burst(from: Vector2, kinds: Array) -> void:
	Sfx.play("coin")
	for i in 12:
		var ic = UI.icon(kinds[i % kinds.size()], 50)
		root.add_child(ic)
		ic.position = from - Vector2(25, 25)
		var target_label: Label = res_labels["gold" if ic.kind == "coin" else "gems"]
		var dest = target_label.global_position
		var mid = from + Vector2(randf_range(-160, 160), randf_range(-200, -60))
		var tw = create_tween()
		tw.tween_property(ic, "position", mid, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(i * 0.03)
		tw.tween_property(ic, "position", dest, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(ic, "scale", Vector2(0.5, 0.5), 0.4)
		tw.tween_callback(ic.queue_free)

func _toast(text: String) -> void:
	var l = UI.label(text, 34)
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.panel(Color(0, 0, 0, 0.8), 16))
	p.add_child(l)
	root.add_child(p)
	p.position = Vector2(get_viewport().get_visible_rect().size.x / 2 - 200, 260)
	p.custom_minimum_size.x = 400
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.pop_in(p)
	var tw = create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)

# ---------- Îles ----------
func _tab_islands() -> Control:
	var v = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 14)
	v.add_child(_ribbon("Route des Îles"))
	var cur = Data.island_for(Data.save.trophies)
	var arr = Data.ISLANDS.duplicate()
	arr.reverse()
	var k = 0
	for isl in arr:
		var unlocked: bool = Data.save.trophies >= isl.trophies
		var p = PanelContainer.new()
		var st = UI.panel(isl.sky.darkened(0.25) if unlocked else Color("3a4458"), 22)
		if isl.id == cur.id:
			st.border_color = UI.GOLD
			st.set_border_width_all(6)
		p.add_theme_stylebox_override("panel", st)
		var h = HBoxContainer.new()
		h.add_theme_constant_override("separation", 16)
		var ic = UI.icon("island", 110)
		h.add_child(ic)
		var tw = ic.create_tween().set_loops()
		tw.tween_property(ic, "position:y", -8.0, 1.2 + k * 0.2).set_trans(Tween.TRANS_SINE).as_relative()
		tw.tween_property(ic, "position:y", 8.0, 1.2 + k * 0.2).set_trans(Tween.TRANS_SINE).as_relative()
		var tv = VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.add_child(UI.label(isl.name, 38))
		var th = HBoxContainer.new()
		th.add_child(UI.icon("trophy", 32))
		th.add_child(UI.label("%d+" % isl.trophies, 24, Color("ffd54a"), 6))
		tv.add_child(th)
		h.add_child(tv)
		if isl.id == cur.id:
			h.add_child(UI.label("Actuelle", 28, UI.GOLD))
		elif not unlocked:
			h.add_child(UI.icon("lock", 60))
		p.add_child(h)
		if not unlocked:
			p.modulate = Color(0.75, 0.75, 0.8)
		v.add_child(p)
		UI.pop_in(p, 0.1 + k * 0.08)
		k += 1
	return _scroll(v)

# ---------- Options ----------
func _tab_settings() -> Control:
	var v = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 18)
	v.add_child(_ribbon("Options"))
	v.add_child(UI.label("Nom du joueur", 28))
	var le = LineEdit.new()
	le.text = Data.save.name
	le.max_length = 14
	le.custom_minimum_size.y = 70
	le.add_theme_font_size_override("font_size", 32)
	le.text_submitted.connect(func(t: String):
		Data.save.name = t.strip_edges() if t.strip_edges() != "" else "Joueur"
		Data.persist()
		_show_menu())
	le.focus_exited.connect(func():
		if le.text.strip_edges() != "" and le.text != Data.save.name:
			Data.save.name = le.text.strip_edges()
			Data.persist())
	v.add_child(le)
	var mute = UI.button("Son : désactivé" if Sfx.muted else "Son : activé", UI.BLUE, 30)
	mute.pressed.connect(func():
		Sfx.set_muted(not Sfx.muted)
		mute.text = "Son : désactivé" if Sfx.muted else "Son : activé")
	v.add_child(mute)
	var reset = UI.button("Réinitialiser la progression", UI.RED, 28)
	reset.pressed.connect(func():
		if reset.get_meta("armed", false):
			Data.reset_save()
			_build_menu_world()
			_show_menu()
		else:
			reset.set_meta("armed", true)
			reset.text = "Touche encore pour confirmer")
	v.add_child(reset)
	var logo = TextureRect.new()
	logo.texture = load("res://assets/superessence_logo.jpg")
	logo.custom_minimum_size = Vector2(0, 300)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v.add_child(logo)
	var cr = UI.label("Clash of Things · v1.0\nUn jeu SuperEssence Studio", 24)
	cr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cr)
	return _scroll(v)

# ================= Recherche d'adversaire + VS =================
func _matchmaking() -> void:
	var isl = Data.island_for(Data.save.trophies)
	for c in root.get_children():
		c.queue_free()
	var bg = ColorRect.new()
	bg.color = Color("1453c4")
	UI.full_rect(bg)
	root.add_child(bg)
	var rays = Rays.new()
	UI.full_rect(rays)
	bg.add_child(rays)
	var vp = get_viewport().get_visible_rect().size
	var title = UI.label("Recherche d'adversaire", 50, UI.GOLD, 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(vp.x, 80)
	title.position = Vector2(0, 160)
	bg.add_child(title)
	var dots = create_tween().set_loops()
	for d in ["", ".", "..", "..."]:
		dots.tween_callback(func(): title.text = "Recherche d'adversaire" + d)
		dots.tween_interval(0.3)
	var loupe = Spinner.new()
	loupe.size = Vector2(200, 200)
	loupe.position = Vector2(vp.x / 2 - 100, vp.y / 2 - 260)
	bg.add_child(loupe)
	var tip = PanelContainer.new()
	tip.add_theme_stylebox_override("panel", UI.panel(Color(1, 1, 1, 0.92), 18))
	tip.size = Vector2(vp.x - 80, 0)
	tip.position = Vector2(40, vp.y - 360)
	var tl = UI.label("Conseil : " + TIPS[randi() % TIPS.size()], 24, Color("1b2c55"), 0)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD
	tl.custom_minimum_size.x = vp.x - 120
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_child(tl)
	bg.add_child(tip)
	var cancelled = [false]
	var cancel = UI.button("Annuler", UI.RED, 32)
	cancel.position = Vector2(vp.x / 2 - 120, vp.y - 520)
	cancel.custom_minimum_size = Vector2(240, 90)
	cancel.pressed.connect(func():
		cancelled[0] = true
		dots.kill()
		_build_menu_world()
		_show_menu())
	bg.add_child(cancel)
	await get_tree().create_timer(randf_range(1.6, 2.6)).timeout
	if cancelled[0]:
		return
	dots.kill()
	var enemy: String = ENEMY_NAMES[randi() % ENEMY_NAMES.size()]
	var et: int = maxi(0, Data.save.trophies + randi_range(-60, 60))
	# Écran VS : les deux joueurs arrivent des côtés, « VS » s'écrase au centre
	for c in [title, loupe, tip, cancel]:
		c.queue_free()
	Sfx.play("whoosh")
	var red = _vs_banner(enemy, et, UI.RED, true)
	var blue = _vs_banner(Data.save.name, Data.save.trophies, UI.BLUE, false)
	bg.add_child(red)
	bg.add_child(blue)
	red.position = Vector2(vp.x, vp.y * 0.28)
	blue.position = Vector2(-vp.x, vp.y * 0.58)
	var tw = create_tween()
	tw.tween_property(red, "position:x", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(blue, "position:x", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	var vs = UI.label("VS", 200, UI.GOLD, 30)
	vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs.size = Vector2(vp.x, 240)
	vs.position = Vector2(0, vp.y * 0.43 - 30)
	vs.pivot_offset = Vector2(vp.x / 2, 120)
	vs.scale = Vector2(4, 4)
	vs.modulate.a = 0
	bg.add_child(vs)
	var t2 = create_tween()
	t2.tween_property(vs, "modulate:a", 1.0, 0.05)
	t2.parallel().tween_property(vs, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t2.tween_callback(func():
		Sfx.play("boom", 1.2)
		var sh = create_tween()
		for i in 6:
			sh.tween_property(bg, "position", Vector2(randf_range(-14, 14), randf_range(-14, 14)), 0.03)
		sh.tween_property(bg, "position", Vector2.ZERO, 0.03))
	await get_tree().create_timer(1.6).timeout
	var flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	UI.full_rect(flash)
	root.add_child(flash)
	var ft = create_tween()
	ft.tween_property(flash, "color:a", 1.0, 0.2)
	await ft.finished
	bg.queue_free()
	_start_battle(enemy, isl)
	var ft2 = create_tween()
	ft2.tween_property(flash, "color:a", 0.0, 0.4)
	ft2.tween_callback(flash.queue_free)

func _vs_banner(name: String, trophies: int, color: Color, top: bool) -> Control:
	var vp = get_viewport().get_visible_rect().size
	var p = PanelContainer.new()
	var st = UI.panel(color, 0)
	st.border_width_left = 0
	st.border_width_right = 0
	st.content_margin_left = 60
	st.content_margin_right = 60
	st.content_margin_top = 30
	st.content_margin_bottom = 30
	p.add_theme_stylebox_override("panel", st)
	p.size = Vector2(vp.x, 0)
	p.custom_minimum_size.x = vp.x
	var h = HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_END if top else BoxContainer.ALIGNMENT_BEGIN
	h.add_theme_constant_override("separation", 16)
	var v = VBoxContainer.new()
	v.add_child(UI.label(name, 54))
	var th = HBoxContainer.new()
	th.add_child(UI.icon("trophy", 40))
	th.add_child(UI.label(str(trophies), 34, Color("ffd54a")))
	v.add_child(th)
	h.add_child(v)
	p.add_child(h)
	return p

# ================= Combat =================
func _start_battle(enemy: String, isl: Dictionary) -> void:
	if world:
		world.queue_free()
		world = null
		menu_pivot = null
	var pool = Data.playable()
	pool.shuffle()
	var e_lvl = {}
	var tot = 0
	for id in Data.save.levels:
		tot += int(Data.save.levels[id])
	var avg = int(round(float(tot) / Data.save.levels.size()))
	for id in Data.playable():
		e_lvl[id] = clampi(avg + isl.id - (1 if randf() < 0.5 else 0), 1, Data.MAX_LEVEL)
	battle = Battle.new()
	battle.setup({"deck": Data.save.deck, "enemy_deck": pool.slice(0, 8), "island": isl, "enemy_name": enemy, "levels": [Data.save.levels, e_lvl]})
	battle.finished.connect(_on_battle_end.bind(enemy))
	add_child(battle)

func _on_battle_end(res: Dictionary, enemy: String) -> void:
	var winner: int = res.winner
	var crowns: Array = res.crowns
	var win = winner == 0
	var draw = winner == -1
	var dt = 0 if draw else (randi_range(28, 33) if win else -randi_range(16, 21))
	var gold = 20 if draw else (60 + crowns[0] * 20 if win else 10)
	var before = Data.island_for(Data.save.trophies)
	var old_trophies: int = Data.save.trophies
	Data.save.trophies = maxi(0, Data.save.trophies + dt)
	Data.save.gold += gold
	if win:
		Data.save.wins += 1
	elif not draw:
		Data.save.losses += 1
	Data.persist()
	var after = Data.island_for(Data.save.trophies)
	Sfx.play("win" if win else "lose")
	var bg = ColorRect.new()
	bg.color = Color(0.02, 0.06, 0.18, 0.0)
	UI.full_rect(bg)
	root.add_child(bg)
	create_tween().tween_property(bg, "color:a", 0.8, 0.3)
	if win:
		var rays = Rays.new()
		UI.full_rect(rays)
		rays.color = Color(1, 0.85, 0.3, 0.25)
		bg.add_child(rays)
	var v = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.custom_minimum_size.x = 620
	v.add_theme_constant_override("separation", 24)
	bg.add_child(v)
	var title = UI.label("VICTOIRE !" if win else ("ÉGALITÉ" if draw else "DÉFAITE"), 110, UI.GOLD if win else (Color("dddddd") if draw else Color("ff6a6a")), 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var panels = []
	for team in [1, 0]:
		var p = PanelContainer.new()
		p.add_theme_stylebox_override("panel", UI.panel(UI.RED if team == 1 else UI.BLUE, 22))
		var pv = VBoxContainer.new()
		var nl = UI.label(enemy if team == 1 else Data.save.name, 40)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pv.add_child(nl)
		var ch = HBoxContainer.new()
		ch.alignment = BoxContainer.ALIGNMENT_CENTER
		ch.add_theme_constant_override("separation", 14)
		var icons = []
		for i in 3:
			var ic = UI.icon("crown", 96)
			ic.modulate = Color(0.25, 0.25, 0.32)
			ch.add_child(ic)
			icons.append(ic)
		pv.add_child(ch)
		p.add_child(pv)
		v.add_child(p)
		panels.append([p, icons, crowns[team]])
	var rw = HBoxContainer.new()
	rw.alignment = BoxContainer.ALIGNMENT_CENTER
	rw.add_theme_constant_override("separation", 30)
	var tl = UI.label(str(old_trophies), 50, Color("ffd54a"))
	var trow = HBoxContainer.new()
	trow.add_child(UI.icon("trophy", 60))
	trow.add_child(tl)
	rw.add_child(trow)
	var dl = UI.label("%s%d" % ["+" if dt >= 0 else "", dt], 44, Color("7cf27a") if dt >= 0 else Color("ff8a8a"))
	rw.add_child(dl)
	var grow = HBoxContainer.new()
	grow.add_child(UI.icon("coin", 56))
	grow.add_child(UI.label("+%d" % gold, 44))
	rw.add_child(grow)
	v.add_child(rw)
	if after.id > before.id:
		var un = UI.label("Nouvelle île débloquée : %s !" % after.name, 32, UI.GOLD)
		un.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(un)
		UI.pop_in(un, 2.6)
	var ok = UI.button("OK", UI.GOLD, 44)
	ok.custom_minimum_size = Vector2(260, 100)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(func():
		battle.queue_free()
		battle = null
		bg.queue_free()
		_build_menu_world()
		tab = "battle"
		_show_menu())
	v.add_child(ok)
	await get_tree().process_frame
	# titre qui s'écrase, panneaux, couronnes une par une, compteur de trophées
	title.pivot_offset = title.size / 2
	title.scale = Vector2(3, 3)
	title.modulate.a = 0
	var tw = create_tween()
	tw.tween_property(title, "modulate:a", 1.0, 0.1)
	tw.parallel().tween_property(title, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	for i in panels.size():
		UI.pop_in(panels[i][0], 0.35 + i * 0.15)
	ok.modulate.a = 0
	rw.modulate.a = 0
	var delay = 0.9
	for pi in panels:
		for i in mini(pi[2], 3):
			var ic: Icon = pi[1][i]
			get_tree().create_timer(delay).timeout.connect(func():
				ic.modulate = Color.WHITE
				ic.pivot_offset = ic.size / 2
				ic.scale = Vector2(2.5, 2.5)
				ic.create_tween().tween_property(ic, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
				Sfx.play("crown"))
			delay += 0.3
	await get_tree().create_timer(delay).timeout
	UI.pop_in(rw)
	var ct = create_tween()
	ct.tween_method(func(x: float): tl.text = str(int(x)), float(old_trophies), float(Data.save.trophies), 0.9).set_delay(0.3)
	UI.pop_in(ok, 1.0)

# ================= Petits contrôles décoratifs =================
class Rays extends Control:
	var color = Color(1, 1, 1, 0.08)
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var c = size / 2
		var r = size.length()
		var t = Time.get_ticks_msec() / 1000.0 * 0.15
		for i in 18:
			var a = t + i * TAU / 18.0
			draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a), sin(a)) * r, c + Vector2(cos(a + 0.17), sin(a + 0.17)) * r]), color)

class Shine extends Control:
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var t = fmod(Time.get_ticks_msec() / 1000.0, 2.6) / 1.0
		if t > 1.0:
			return
		var x = -120.0 + (size.x + 240.0) * t
		draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 60, 0), Vector2(x + 10, size.y), Vector2(x - 50, size.y)]), Color(1, 1, 1, 0.35))

class Spinner extends Control:
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var t = Time.get_ticks_msec() / 1000.0
		var c = size / 2 + Vector2(cos(t * 3.0), sin(t * 3.0)) * 30.0
		draw_circle(c, 62, UI.INK)
		draw_circle(c, 50, Color("bfe6ff"))
		draw_circle(c + Vector2(-16, -16), 14, Color(1, 1, 1, 0.8))
		var d = Vector2(0.7, 0.7)
		draw_line(c + d * 56, c + d * 120, UI.INK, 34)
		draw_line(c + d * 60, c + d * 116, Color("8b5a2b"), 20)
