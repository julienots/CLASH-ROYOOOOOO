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
const TABS := [["shop", "shop", "Boutique"], ["cards", "cards", "Cartes"], ["battle", "swords", "Combat"], ["clan", "shield", "Clan"], ["events", "trophy", "Événements"]]
const CLAN_NAMES := ["Arkos", "Lili_Blaze", "Doom'Patate", "Nyx", "Capitaine Bulle", "Sora77", "FlamboRex", "Mamie Hache", "Zorglub", "Kiwi", "Brumelune", "Toto_le_Héros"]
const CLAN_LINES := ["Bien joué tout le monde !", "Qui a un deck avec la Liche ?", "La Rage + Berserker c'est violent 😄", "Je monte sur l'Île de Braise !", "GG pour le coffre couronne",
	"Quelqu'un pour un entraînement ?", "Le Nécromancien est trop fort en défense", "Allez on vise le top 10 !", "Astuce : la Pluie de Flèches détruit les squelettes", "Merci pour les conseils !"]

var ui: CanvasLayer
var root: Control
var world: Node3D
var menu_pivot: Node3D
var battle: Battle
var tab = "battle"
var sel_card = ""
var res_labels = {}
var content: Control
var chest_timer: Timer
var clan_sub = "clan"
var booted = false


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
	await _studio_splash()
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
	booted = true
	if OS.get_cmdline_user_args().is_empty():
		_login_popup()

## Écran du studio : le logo SuperEssence complet, centré, avec un reflet lumineux.
func _studio_splash() -> void:
	var bg = ColorRect.new()
	bg.color = Color.BLACK
	UI.full_rect(bg)
	root.add_child(bg)
	var logo = TextureRect.new()
	logo.texture = load("res://assets/superessence_logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	UI.full_rect(logo)
	logo.offset_left = 30
	logo.offset_right = -30
	bg.add_child(logo)
	var shine = Shine.new()
	UI.full_rect(shine)
	shine.offset_top = 520
	shine.offset_bottom = -520
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shine.modulate.a = 0.6
	bg.add_child(shine)
	var vp = get_viewport().get_visible_rect().size
	logo.pivot_offset = vp / 2
	logo.scale = Vector2(0.85, 0.85)
	logo.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(logo, "modulate:a", 1.0, 0.6)
	tw.parallel().tween_property(logo, "scale", Vector2.ONE, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): Sfx.play("reward"))
	tw.tween_interval(1.3)
	tw.tween_property(bg, "modulate:a", 0.0, 0.5)
	await tw.finished
	bg.queue_free()

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
	var framing = {"drake": [6.2, 0.9, 1.4], "totem": [6.4, 1.5, 0.6], "champion": [4.6, 0.95, 0.4], "berserker": [4.4, 0.9, 0.4],
		"healer": [4.1, 0.85, 0.4], "knives": [3.9, 0.85, 0.4], "warriors": [3.6, 0.65, 0.5], "necro": [4.8, 1.0, 0.5],
		"catapult": [7.4, 1.6, 1.4], "arrows": [3.8, 0.45, 0.4], "rage": [3.6, 0.75, 0.3],
		"titan": [5.8, 1.3, 0.6], "bomber": [3.9, 0.85, 0.4], "icemage": [4.1, 0.85, 0.4], "army": [2.6, 0.45, 0.4],
		"giant_skel": [6.0, 1.3, 0.7], "lumber": [4.3, 0.9, 0.4], "babydrake": [4.6, 0.6, 1.0], "ghost": [3.9, 0.85, 0.4],
		"guards": [3.6, 0.7, 0.5], "xbow": [6.4, 1.9, 1.0], "tomb": [5.4, 1.4, 0.6], "barracks": [6.8, 1.4, 1.2],
		"lightning": [4.4, 1.1, 0.4], "tornado": [4.6, 1.0, 0.4], "heal": [3.6, 0.75, 0.3], "poison": [3.6, 0.75, 0.3],
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
		elif id in ["warriors", "guards", "army"]:
			for k in 2:
				var b = Models.build(id, 0)
				b.position = Vector3(0.55 if k else -0.55, 0, -0.45)
				model.add_child(b)
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
		Data.card_textures[id] = await _compose_card(ImageTexture.create_from_image(img), id)
		model.queue_free()
		n += 1
		bar.value = 85.0 * n / ids.size()
	# icônes 3D des coffres
	cam.fov = 32
	for type in Data.CHEST_TYPES:
		var ch = Models.blend("chest_" + type)
		ch.rotation.y = 0.45
		vp.add_child(ch)
		var cap: AnimationPlayer = ch.find_child("AnimationPlayer", false, false)
		cap.play("Idle")
		cap.seek(0.0, true)
		cap.pause()
		cam.position = Vector3(0, 2.1, 3.9)
		cam.look_at(Vector3(0, 0.6, 0))
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		Data.chest_textures[type] = ImageTexture.create_from_image(vp.get_texture().get_image())
		ch.queue_free()
	bar.value = 90.0
	vp.queue_free()

func _pose_card_model(n: Node) -> void:
	if n.has_meta("real"):
		RealModels.pose(n)
	for c in n.get_children():
		if c is Node3D:
			_pose_card_model(c)

## Compose la carte en 2D : fond rayonnant, illustration 3D, cadre orné selon la rareté, ruban avec le nom.
func _compose_card(art: Texture2D, id: String) -> Texture2D:
	var c: Dictionary = Data.CARDS[id]
	var rar: Dictionary = Data.RARITY[c.rarity]
	var W = 256
	var H = 340
	var vp = SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var card = CardFace.new()
	card.size = Vector2(W, H)
	card.art = art
	card.rarity = c.rarity
	card.card_name = c.name
	card.is_spell = c.type == "spell"
	card.is_building = c.type == "building"
	card.colors = rar
	vp.add_child(card)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var tex = ImageTexture.create_from_image(vp.get_texture().get_image())
	vp.queue_free()
	return tex

# ================= Monde 3D du menu =================
func _build_menu_world() -> void:
	if world:
		world.queue_free()
	var isl = Data.island_for(Data.save.trophies)
	world = Node3D.new()
	add_child(world)
	var env = WorldEnvironment.new()
	env.environment = Models.sky_environment(isl)
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
	world.set_meta("arena", arena)
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
		Models.animate_clouds(world.get_meta("arena", null), _dt)
		for c in menu_pivot.get_children():
			if c.has_meta("seed"):
				Models.animate(c, t, true, 0.0, c.get_meta("seed"))
				c.rotation.y = 0.0

# ================= Menus =================
func _show_menu() -> void:
	Sfx.music("menu")
	Data.refresh_quests()
	for c in root.get_children():
		if not c.has_meta("keep"):
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
	for c in root.get_children():
		if c.has_meta("keep"):
			root.move_child(c, -1)
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
	var av = Button.new()
	av.add_theme_stylebox_override("normal", UI.panel(Color("2f6fe0"), 14))
	av.add_theme_stylebox_override("hover", UI.panel(Color("3f7cf0"), 14))
	av.add_theme_stylebox_override("pressed", UI.panel(Color("2a5fc4"), 14))
	av.custom_minimum_size = Vector2(70, 70)
	var al = UI.label(str(int(Data.save.level)), 34, Color.WHITE)
	UI.full_rect(al)
	al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	al.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	al.mouse_filter = Control.MOUSE_FILTER_IGNORE
	av.add_child(al)
	av.pressed.connect(func(): Sfx.play("open"); _profile_popup())
	h.add_child(av)
	var nv = VBoxContainer.new()
	nv.add_theme_constant_override("separation", -4)
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nv.add_child(UI.label(Data.save.name, 26))
	var xp = ProgressBar.new()
	xp.custom_minimum_size = Vector2(110, 16)
	xp.show_percentage = false
	xp.max_value = Data.xp_needed(int(Data.save.level))
	xp.value = int(Data.save.xp)
	xp.add_theme_stylebox_override("background", UI.panel(UI.INK, 8))
	var xf = StyleBoxFlat.new()
	xf.bg_color = Color("6fc4ff")
	xf.set_corner_radius_all(6)
	xp.add_theme_stylebox_override("fill", xf)
	nv.add_child(xp)
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
	var gear = Button.new()
	gear.flat = true
	gear.custom_minimum_size = Vector2(60, 60)
	var gi = UI.icon("gear", 54)
	UI.full_rect(gi)
	gi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gear.add_child(gi)
	gear.pressed.connect(func(): Sfx.play("open"); _settings_popup())
	h.add_child(gear)
	return p

func _refresh_resources() -> void:
	for k in res_labels:
		var l: Label = res_labels[k]
		if not is_instance_valid(l) or not l.is_inside_tree():
			continue
		var from = int(l.text)
		var to = int(Data.save[k])
		if from == to:
			continue
		var tw = l.create_tween()
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
		"clan": page = _tab_clan()
		_: page = _tab_events()
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
	var road_btn = Button.new()
	road_btn.flat = true
	UI.full_rect(road_btn)
	road_btn.pressed.connect(func(): Sfx.play("open"); _road_popup())
	head.add_child(road_btn)
	# boutons latéraux : quêtes et mode de jeu
	var side = HBoxContainer.new()
	side.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	side.position.y = 220
	side.offset_left = 20
	side.offset_right = -20
	side.add_theme_constant_override("separation", 12)
	var claimable = 0
	for q in Data.save.quests:
		if not q.claimed and int(q.progress) >= Data.quest_def(q.id).goal:
			claimable += 1
	var qb = UI.button("Quêtes" + (" (%d)" % claimable if claimable else ""), UI.GREEN if claimable else Color("3f7cf0"), 26)
	qb.pressed.connect(_quests_popup)
	side.add_child(qb)
	if claimable:
		qb.ready.connect(func(): UI.pulse(qb, 1.08, 0.8))
	var pass_ready = _pass_claimable()
	var pb = UI.button("Pass" + (" (%d)" % pass_ready if pass_ready else ""), Color("c23cf0"), 24)
	pb.pressed.connect(_pass_popup)
	side.add_child(pb)
	var road_ready = _road_claimable()
	if road_ready:
		var rb = UI.button("Route (%d)" % road_ready, UI.GOLD, 24)
		rb.pressed.connect(_road_popup)
		side.add_child(rb)
	var spc = Control.new()
	spc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_child(spc)
	var md = _mode()
	var mb = UI.button(md.name, md.color, 24)
	mb.pressed.connect(func():
		tab = "events"
		_show_menu())
	side.add_child(mb)
	page.add_child(side)
	UI.slide_in(side, Vector2(0, -60), 0.15, 0.4)

	var bottom = VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.position.y -= 24
	bottom.add_theme_constant_override("separation", 14)
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_child(_crown_bar())
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
	bottom.add_child(_chest_slots())
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
	var found = Data.playable().filter(func(id): return Data.unlocked(id)).size()
	v.add_child(UI.label("Collection  ·  %d / %d cartes trouvées" % [found, Data.playable().size()], 30))
	var cp = PanelContainer.new()
	cp.add_theme_stylebox_override("panel", UI.panel(Color(0.02, 0.06, 0.18, 0.55), 22))
	var g2 = GridContainer.new()
	g2.columns = 4
	g2.add_theme_constant_override("h_separation", 12)
	g2.add_theme_constant_override("v_separation", 12)
	cp.add_child(g2)
	var ids = Data.playable().filter(func(id): return not id in Data.save.deck)
	ids.sort_custom(func(a, b): return [Data.UNLOCK.get(a, 0), Data.CARDS[a].cost] < [Data.UNLOCK.get(b, 0), Data.CARDS[b].cost])
	for id in ids:
		var t = _card_tile(id, true) if Data.unlocked(id) else _locked_tile(id)
		g2.add_child(t)
		UI.pop_in(t, 0.2 + mini(i, 20) * 0.03)
		i += 1
	v.add_child(cp)
	return _scroll(v)

func _locked_tile(id: String) -> Control:
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tr = TextureRect.new()
	tr.texture = Data.card_textures[id]
	tr.custom_minimum_size = Vector2(140, 175)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.modulate = Color(0.18, 0.2, 0.3)
	var lk = UI.icon("lock", 60)
	lk.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	lk.position -= Vector2(30, 40)
	tr.add_child(lk)
	v.add_child(tr)
	var isl = Data.ISLANDS[Data.UNLOCK.get(id, 0)]
	var l = UI.label(isl.name, 16, Color("ffd54a"), 5)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size.x = 140
	v.add_child(l)
	return v

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
	v.add_child(_daily_deals())
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
		var ic = _chest_icon(c.id, 120)
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
	_open_chest(c.id, gold, gems, _bonus_card(c.id))

## Les coffres d'Or, Magique et Couronne améliorent gratuitement une carte au hasard.
func _bonus_card(type: String) -> String:
	if not type in ["gold", "magic", "crown"]:
		return ""
	var pool = []
	for id in Data.playable():
		if int(Data.save.levels[id]) < Data.MAX_LEVEL:
			pool.append(id)
	if pool.is_empty():
		return ""
	var id: String = pool[randi() % pool.size()]
	Data.save.levels[id] = int(Data.save.levels[id]) + 1
	Data.persist()
	return id

func _chest_icon(type: String, s: float) -> Control:
	if Data.chest_textures.has(type):
		var t = TextureRect.new()
		t.texture = Data.chest_textures[type]
		t.custom_minimum_size = Vector2(s, s)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		return t
	var ic = UI.icon("chest", s)
	ic.tint = Data.CHEST_TYPES[type].tint
	return ic

## Ouverture de coffre en 3D : il tombe et rebondit, tremble au toucher, le couvercle saute
## dans un éclat de lumière, puis chaque récompense jaillit du coffre une par une.
func _open_chest(type: String, gold: int, gems: int, bonus: String = "") -> void:
	Data.save.chests_opened = int(Data.save.get("chests_opened", 0)) + 1
	Data.persist()
	var t: Dictionary = Data.CHEST_TYPES[type]
	var vp_size = get_viewport().get_visible_rect().size
	var bg = ColorRect.new()
	bg.color = Color(0.02, 0.05, 0.15, 0.0)
	bg.set_meta("keep", true)
	UI.full_rect(bg)
	root.add_child(bg)
	create_tween().tween_property(bg, "color:a", 0.94, 0.25)
	var rays = Rays.new()
	UI.full_rect(rays)
	rays.color = Color(t.tint.r, t.tint.g, t.tint.b, 0.0)
	bg.add_child(rays)
	var title = UI.label(t.name, 56, UI.GOLD, 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(vp_size.x, 90)
	title.position = Vector2(0, 120)
	bg.add_child(title)
	UI.pop_in(title, 0.2)
	# scène 3D du coffre
	var svc = SubViewportContainer.new()
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	svc.position = Vector2(0, vp_size.y * 0.18)
	svc.size = Vector2(vp_size.x, vp_size.y * 0.55)
	bg.add_child(svc)
	var sv = SubViewport.new()
	sv.transparent_bg = true
	sv.own_world_3d = true
	sv.msaa_3d = Viewport.MSAA_4X
	svc.add_child(sv)
	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.9, 0.92, 1.0)
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	sv.add_child(env)
	var key = DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-40), deg_to_rad(30), 0)
	key.light_energy = 1.3
	sv.add_child(key)
	var glow_light = OmniLight3D.new()
	glow_light.light_color = Color("ffd24a")
	glow_light.omni_range = 6.0
	glow_light.light_energy = 0.0
	glow_light.position = Vector3(0, 0.75, 0.1)
	glow_light.omni_range = 3.0
	sv.add_child(glow_light)
	var cam = Camera3D.new()
	cam.fov = 38
	cam.position = Vector3(0, 2.6, 5.2)
	sv.add_child(cam)
	cam.look_at(Vector3(0, 0.6, 0))
	var fx3 = FX.new()
	sv.add_child(fx3)
	var chest: Node3D = Models.blend("chest_" + type)
	chest.rotation.y = 0.0
	chest.position = Vector3(0, 7, 0)
	sv.add_child(chest)
	var ap: AnimationPlayer = chest.find_child("AnimationPlayer", false, false)
	for a in ["Idle", "Opened"]:
		ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	ap.play("Idle")
	# 1. chute + rebond
	var tw = create_tween()
	tw.tween_property(chest, "position:y", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		Sfx.play("hit", 0.7)
		fx3.dust(Vector3.ZERO, 16, 1.4)
		_shake_control(svc, 10.0))
	tw.tween_property(chest, "position:y", 0.5, 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_property(chest, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tw.finished
	if not is_instance_valid(bg):
		return
	# 2. on attend que le joueur touche le coffre
	var hint = UI.label("Touche pour ouvrir !", 40)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size = Vector2(vp_size.x, 60)
	hint.position = Vector2(0, vp_size.y * 0.76)
	bg.add_child(hint)
	UI.pulse(hint, 1.1, 0.9)
	var tap = Button.new()
	tap.flat = true
	UI.full_rect(tap)
	bg.add_child(tap)
	await tap.pressed
	tap.queue_free()
	hint.queue_free()
	# 3. tremblement qui monte en puissance + lueur
	ap.play("Shake")
	Sfx.play("tick", 0.8)
	create_tween().tween_property(glow_light, "light_energy", 2.5, 0.7)
	await get_tree().create_timer(0.35).timeout
	Sfx.play("tick", 1.1)
	await get_tree().create_timer(0.35).timeout
	# 4. ouverture : flash, faisceau de lumière, étincelles
	ap.play("Open")
	ap.queue("Opened")
	Sfx.play("chest")
	var flash = ColorRect.new()
	flash.color = Color(1, 0.97, 0.85, 0.75)
	UI.full_rect(flash)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(flash)
	flash.create_tween().tween_property(flash, "color:a", 0.0, 0.6)
	rays.create_tween().tween_property(rays, "color:a", 0.35, 0.4)
	glow_light.light_energy = 2.2
	create_tween().tween_property(glow_light, "light_energy", 1.0, 1.2)
	_beam(sv, t.tint.lightened(0.4))
	fx3.burst(Vector3(0, 1.0, 0), Color("ffd24a"), 40, 6.0, 0.35, 1.0, -6.0)
	fx3.burst(Vector3(0, 1.0, 0), t.tint.lightened(0.5), 24, 4.0, 0.5, 0.8, -3.0)
	fx3.ring(Vector3(0, 0.0, 0), 3.0, Color("ffd24a"), 0.6, 0.25)
	_shake_control(svc, 14.0)
	var sparkle = Timer.new()
	sparkle.wait_time = 0.12
	sv.add_child(sparkle)
	sparkle.timeout.connect(func(): fx3.burst(Vector3(randf_range(-0.5, 0.5), 1.1, 0), Color("ffe58a"), 2, 1.5, 0.25, 0.8, -1.0))
	sparkle.start()
	await get_tree().create_timer(0.7).timeout
	# 5. récompenses une par une, qui jaillissent du coffre
	var items = [["coin", gold, Color("ffd84a"), "Pièces d'or"]]
	if gems > 0:
		items.append(["gem", gems, Color("7cf27a"), "Gemmes"])
	if bonus != "":
		items.append(["card", int(Data.save.levels[bonus]), Color("6fc4ff"), Data.CARDS[bonus].name])
	var left = UI.label("", 30, Color.WHITE)
	left.position = Vector2(vp_size.x / 2 + 90, vp_size.y * 0.47)
	bg.add_child(left)
	var collected = HBoxContainer.new()
	collected.alignment = BoxContainer.ALIGNMENT_CENTER
	collected.add_theme_constant_override("separation", 30)
	collected.size = Vector2(vp_size.x, 160)
	collected.position = Vector2(0, vp_size.y * 0.74)
	bg.add_child(collected)
	for idx in items.size():
		var it = items[idx]
		left.text = "x%d" % (items.size() - idx)
		var card = PanelContainer.new()
		card.add_theme_stylebox_override("panel", UI.panel(Color(0.08, 0.15, 0.4, 0.95), 26))
		var cv = VBoxContainer.new()
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(cv)
		if it[0] == "card":
			var tr = TextureRect.new()
			tr.texture = Data.card_textures[bonus]
			tr.custom_minimum_size = Vector2(170, 225)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			cv.add_child(tr)
			var ll = UI.label("Niveau %d → %d !" % [it[1] - 1, it[1]], 34, Color("7cf27a"))
			ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cv.add_child(ll)
		else:
			var ic = UI.icon(it[0], 150)
			ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			cv.add_child(ic)
			var cnt = UI.label("x0", 64, it[2], 14)
			cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cv.add_child(cnt)
			var amount: int = it[1]
			var ct = cnt.create_tween()
			ct.tween_interval(0.25)
			ct.tween_method(func(v: float): cnt.text = "x%d" % int(v), 0.0, float(amount), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var nm = UI.label(it[3], 30)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(nm)
		card.custom_minimum_size = Vector2(360, 0)
		bg.add_child(card)
		await get_tree().process_frame
		var center = Vector2(vp_size.x / 2, vp_size.y * 0.45)
		card.pivot_offset = card.size / 2
		card.position = center - card.size / 2 + Vector2(0, 120)
		card.scale = Vector2(0.1, 0.1)
		card.rotation = -0.6
		var ft = card.create_tween().set_parallel()
		ft.tween_property(card, "position", center - card.size / 2 - Vector2(0, 40), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ft.tween_property(card, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ft.tween_property(card, "rotation", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		fx3.burst(Vector3(0, 1.3, 0), it[2], 18, 5.0, 0.4, 0.7, -5.0)
		Sfx.play("levelup" if it[0] == "card" else ("bonus" if it[0] == "gem" else "coin"))
		Sfx.play("whoosh")
		await get_tree().create_timer(0.5).timeout
		var tap2 = Button.new()
		tap2.flat = true
		UI.full_rect(tap2)
		bg.add_child(tap2)
		await tap2.pressed
		tap2.queue_free()
		# la récompense file se ranger en bas
		var mini_box = VBoxContainer.new()
		var mi = _chest_reward_icon(it, bonus)
		mini_box.add_child(mi)
		var ml = UI.label(("Niv. %d" % it[1]) if it[0] == "card" else ("x%d" % it[1]), 28, it[2])
		ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mini_box.add_child(ml)
		var gt = card.create_tween().set_parallel()
		gt.tween_property(card, "scale", Vector2(0.2, 0.2), 0.25).set_ease(Tween.EASE_IN)
		gt.tween_property(card, "position:y", vp_size.y * 0.74, 0.25).set_ease(Tween.EASE_IN)
		gt.chain().tween_callback(func():
			card.queue_free()
			collected.add_child(mini_box)
			UI.pop_in(mini_box, 0.0, 0.4)
			Sfx.play("pop"))
		await get_tree().create_timer(0.3).timeout
	left.queue_free()
	sparkle.stop()
	var ok = UI.button("OK", UI.GOLD, 44)
	ok.custom_minimum_size = Vector2(260, 100)
	ok.position = Vector2(vp_size.x / 2 - 130, vp_size.y - 240)
	bg.add_child(ok)
	UI.pop_in(ok, 0.2)
	ok.pressed.connect(func():
		_close_modal(bg)
		_refresh_resources()
		_rebuild_tab())

func _chest_reward_icon(it: Array, bonus: String) -> Control:
	if it[0] == "card":
		var tr = TextureRect.new()
		tr.texture = Data.card_textures[bonus]
		tr.custom_minimum_size = Vector2(80, 106)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		return tr
	var ic = UI.icon(it[0], 80)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return ic

## Faisceau de lumière vertical qui jaillit du coffre ouvert.
func _beam(sv: SubViewport, col: Color) -> void:
	for k in 2:
		var m = MeshInstance3D.new()
		var c = CylinderMesh.new()
		c.top_radius = 1.4 if k == 0 else 0.6
		c.bottom_radius = 0.5 if k == 0 else 0.25
		c.height = 9.0
		c.cap_top = false
		c.cap_bottom = false
		m.mesh = c
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = Color(col.r, col.g, col.b, 0.0)
		m.material_override = mat
		m.position = Vector3(0, 5.2, 0)
		m.scale = Vector3(0.2, 1, 0.2)
		sv.add_child(m)
		var tw = m.create_tween().set_parallel()
		tw.tween_property(m, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(mat, "albedo_color:a", 0.16 if k == 0 else 0.3, 0.2)
		var rot = m.create_tween().set_loops()
		rot.tween_property(m, "rotation:y", TAU, 4.0).as_relative()

func _shake_control(c: Control, amp: float) -> void:
	var base = c.position
	var tw = c.create_tween()
	for i in 6:
		tw.tween_property(c, "position", base + Vector2(randf_range(-amp, amp), randf_range(-amp, amp)), 0.035)
	tw.tween_property(c, "position", base, 0.05)

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
	var pool = Data.playable().filter(func(id): return Data.UNLOCK.get(id, 0) <= isl.id)
	pool.shuffle()
	var e_lvl = {}
	var tot = 0
	for id in Data.save.levels:
		tot += int(Data.save.levels[id])
	var avg = int(round(float(tot) / Data.save.levels.size()))
	for id in Data.playable():
		e_lvl[id] = clampi(avg + isl.id - (1 if randf() < 0.5 else 0), 1, Data.MAX_LEVEL)
	battle = Battle.new()
	if _mode().get("easy", false):
		for id in e_lvl:
			e_lvl[id] = maxi(1, e_lvl[id] - 2)
	battle.setup({"deck": Data.save.deck, "enemy_deck": pool.slice(0, 8), "island": isl, "enemy_name": enemy, "levels": [Data.save.levels, e_lvl], "mode": _mode()})
	battle.finished.connect(_on_battle_end.bind(enemy))
	add_child(battle)

func _on_battle_end(res: Dictionary, enemy: String) -> void:
	var winner: int = res.winner
	var crowns: Array = res.crowns
	var win = winner == 0
	var draw = winner == -1
	var md = _mode()
	var dt = 0 if draw or not md.trophies else (randi_range(28, 33) if win else -randi_range(16, 21))
	var gold = 20 if draw else (60 + crowns[0] * 20 if win else 10)
	var st: Dictionary = battle.stats
	Data.save.deployed = int(Data.save.deployed) + st.deployed
	Data.save.towers = int(Data.save.towers) + st.towers
	Data.quest_event("play")
	Data.quest_event("deploy", st.deployed)
	Data.quest_event("spells", st.spells)
	Data.quest_event("towers", st.towers)
	Data.quest_event("crowns", crowns[0])
	if win:
		Data.quest_event("win")
		if crowns[0] >= 3:
			Data.save.three_crowns = int(Data.save.three_crowns) + 1
	Data.save.crown_progress = mini(10, int(Data.save.crown_progress) + crowns[0])
	Data.save.pass_points = int(Data.save.pass_points) + crowns[0]
	var chest_won = ""
	if win:
		var slot = Data.save.chests.find(null)
		if slot >= 0:
			chest_won = Data.roll_chest()
			Data.save.chests[slot] = {"type": chest_won, "state": "locked", "end": 0}
	var leveled = Data.add_xp(20 if win else 8)
	Data.save.best_trophies = maxi(int(Data.save.get("best_trophies", 0)), Data.save.trophies + dt)
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
	var newly = []
	if after.id > int(Data.save.get("best_island", 0)):
		for id in Data.playable():
			if Data.UNLOCK.get(id, 0) > int(Data.save.get("best_island", 0)) and Data.UNLOCK.get(id, 0) <= after.id:
				newly.append(id)
		Data.save.best_island = after.id
		Data.persist()
	if not newly.is_empty():
		var nh = HBoxContainer.new()
		nh.alignment = BoxContainer.ALIGNMENT_CENTER
		nh.add_theme_constant_override("separation", 6)
		for id in newly:
			var tr = TextureRect.new()
			tr.texture = Data.card_textures[id]
			tr.custom_minimum_size = Vector2(84, 110)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			nh.add_child(tr)
		v.add_child(nh)
		UI.pop_in(nh, 2.8)
		get_tree().create_timer(2.8).timeout.connect(func(): Sfx.play("unlock"))
	if after.id > before.id:
		var un = UI.label("Nouvelle île débloquée : %s !" % after.name, 32, UI.GOLD)
		un.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(un)
		UI.pop_in(un, 2.6)
	if chest_won != "":
		var ch = HBoxContainer.new()
		ch.alignment = BoxContainer.ALIGNMENT_CENTER
		var ci = _chest_icon(chest_won, 100)
		ch.add_child(ci)
		ch.add_child(UI.label(Data.CHEST_TYPES[chest_won].name + " gagné !", 32, UI.GOLD))
		v.add_child(ch)
		UI.pop_in(ch, 2.3)
		get_tree().create_timer(2.3).timeout.connect(func(): Sfx.play("chest"))
	elif win:
		var full = UI.label("Emplacements de coffres pleins !", 26, Color("ffb3b3"))
		full.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(full)
	var xl = UI.label("+%d XP" % (20 if win else 8) + ("   NIVEAU %d !" % int(Data.save.level) if leveled else ""), 30, Color("6fc4ff"))
	xl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(xl)
	UI.pop_in(xl, 2.6)
	if leveled:
		get_tree().create_timer(2.7).timeout.connect(func(): Sfx.play("levelup"))
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


## Face de carte dessinée en 2D (utilisée une fois par carte au démarrage).
class CardFace extends Control:
	var art: Texture2D
	var rarity = "common"
	var card_name = ""
	var is_spell = false
	var is_building = false
	var colors = {}

	func _draw() -> void:
		var W = size.x
		var H = size.y
		var f: Font = load("res://assets/lilita_one.woff2")
		var frame: Color = colors.color
		var bg0: Color = colors.bg[0]
		var bg1: Color = colors.bg[1]
		var R = 26.0
		var outer = Rect2(Vector2.ZERO, size)
		# fond en dégradé vertical + rayons
		var inner = outer.grow(-10)
		var st = StyleBoxFlat.new()
		st.bg_color = bg1
		st.set_corner_radius_all(int(R))
		draw_style_box(st, outer)
		for i in 24:
			var t = float(i) / 24.0
			var band = Rect2(inner.position + Vector2(0, inner.size.y * t), Vector2(inner.size.x, inner.size.y / 24.0 + 1))
			draw_rect(band, bg0.lerp(bg1, t))
		var c = inner.get_center() - Vector2(0, 20)
		for i in 16:
			var a = i * TAU / 16.0
			draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a), sin(a)) * 260, c + Vector2(cos(a + 0.2), sin(a + 0.2)) * 260]), Color(1, 1, 1, 0.07))
		for k in 6:
			draw_circle(c, 110 - k * 16, Color(1, 1, 1, 0.035))
		# illustration
		if art:
			draw_texture_rect(art, Rect2(Vector2(0, 4), Vector2(W, W * 1.25)), false)
		# ruban du nom
		var rib = Rect2(Vector2(8, H - 82), Vector2(W - 16, 60))
		var rs = StyleBoxFlat.new()
		rs.bg_color = Color(0.04, 0.07, 0.18, 0.88)
		rs.set_corner_radius_all(14)
		rs.border_color = frame.darkened(0.15)
		rs.set_border_width_all(3)
		draw_style_box(rs, rib)
		var fs = 26 if card_name.length() <= 14 else 21
		var lines = [card_name]
		if card_name.length() > 16:
			var cut = card_name.rfind(" ", 16)
			if cut > 0:
				lines = [card_name.substr(0, cut), card_name.substr(cut + 1)]
				fs = 20
		for li in lines.size():
			var y = rib.position.y + (rib.size.y / 2.0) + 9 + (li - (lines.size() - 1) / 2.0) * 22
			draw_string_outline(f, Vector2(rib.position.x, y), lines[li], HORIZONTAL_ALIGNMENT_CENTER, rib.size.x, fs, 7, Color(0.02, 0.04, 0.1))
			draw_string(f, Vector2(rib.position.x, y), lines[li], HORIZONTAL_ALIGNMENT_CENTER, rib.size.x, fs, Color.WHITE)
		# étiquette de type
		if is_spell or is_building:
			var tag = "SORT" if is_spell else "BÂTIMENT"
			var tr = Rect2(Vector2(W / 2 - 52, H - 104), Vector2(104, 26))
			var ts = StyleBoxFlat.new()
			ts.bg_color = frame
			ts.set_corner_radius_all(10)
			draw_style_box(ts, tr)
			draw_string(f, Vector2(tr.position.x, tr.position.y + 20), tag, HORIZONTAL_ALIGNMENT_CENTER, tr.size.x, 18, Color(0.05, 0.05, 0.1))
		# cadre orné : liseré sombre, bande de rareté, filet clair intérieur, coins
		var fr = StyleBoxFlat.new()
		fr.draw_center = false
		fr.set_corner_radius_all(int(R))
		fr.set_border_width_all(12)
		fr.border_color = frame
		draw_style_box(fr, outer)
		var ink = StyleBoxFlat.new()
		ink.draw_center = false
		ink.set_corner_radius_all(int(R))
		ink.set_border_width_all(3)
		ink.border_color = Color(0.02, 0.04, 0.1)
		draw_style_box(ink, outer)
		var hi = StyleBoxFlat.new()
		hi.draw_center = false
		hi.set_corner_radius_all(int(R - 10))
		hi.set_border_width_all(2)
		hi.border_color = Color(1, 1, 1, 0.65)
		draw_style_box(hi, outer.grow(-12))
		draw_rect(Rect2(Vector2(14, 2), Vector2(W - 28, 4)), Color(1, 1, 1, 0.35))
		for corner in [Vector2(18, 18), Vector2(W - 18, 18), Vector2(18, H - 18), Vector2(W - 18, H - 18)]:
			_diamond(corner, 9, frame.lightened(0.35))
		# gemme de rareté en haut
		var gem_col = {"common": Color("c8d4e0"), "rare": Color("ffb02e"), "epic": Color("d56bff"), "legendary": Color("4ff0d2")}[rarity]
		_diamond(Vector2(W / 2, 8), 16, Color(0.02, 0.04, 0.1))
		_diamond(Vector2(W / 2, 8), 12, gem_col)
		_diamond(Vector2(W / 2 - 3, 5), 4, Color(1, 1, 1, 0.8))
		if rarity == "legendary":
			# liseré arc-en-ciel animé figé
			var cols = [Color("ff6a8a"), Color("ffd23f"), Color("4ff0d2"), Color("6f8bff"), Color("d56bff")]
			for i in 40:
				var t = float(i) / 40.0
				var col = cols[int(t * cols.size()) % cols.size()]
				draw_rect(Rect2(Vector2(R + (W - 2 * R) * t, 0), Vector2((W - 2 * R) / 40.0 + 1, 3)), col)
				draw_rect(Rect2(Vector2(R + (W - 2 * R) * t, H - 3), Vector2((W - 2 * R) / 40.0 + 1, 3)), col)

	func _diamond(c: Vector2, r: float, col: Color) -> void:
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), col)


# ================= Modes, coffres, quêtes, popups =================
func _mode() -> Dictionary:
	for m in Data.MODES:
		if m.id == Data.save.get("mode", "classic"):
			return m
	return Data.MODES[0]

func _now() -> int:
	return int(Time.get_unix_time_from_system())

func _fmt_time(sec: int) -> String:
	if sec >= 3600:
		return "%dh%02d" % [sec / 3600, (sec % 3600) / 60]
	if sec >= 60:
		return "%dm%02d" % [sec / 60, sec % 60]
	return "%ds" % sec

func _crown_bar() -> Control:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.panel(Color(0.03, 0.08, 0.22, 0.8), 18))
	p.custom_minimum_size.x = 560
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	var ci = _chest_icon("crown", 70)
	h.add_child(ci)
	var prog = int(Data.save.crown_progress)
	if prog >= 10:
		var b = UI.button("Ouvrir le Coffre Couronne !", UI.GREEN, 24)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			Data.save.crown_progress = 0
			_give_chest("crown"))
		h.add_child(b)
		b.ready.connect(func(): UI.pulse(b, 1.04, 0.9))
	else:
		var v = VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UI.label("Coffre Couronne", 22, UI.GOLD, 6))
		var row = HBoxContainer.new()
		for i in 10:
			var c = UI.icon("crown", 32)
			if i >= prog:
				c.modulate = Color(0.25, 0.25, 0.32)
			row.add_child(c)
		v.add_child(row)
		h.add_child(v)
	return p

func _chest_slots() -> Control:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var unlocking = false
	for c in Data.save.chests:
		if c and c.state == "unlocking" and int(c.end) > _now():
			unlocking = true
	for i in 4:
		var c = Data.save.chests[i]
		var b = Button.new()
		b.custom_minimum_size = Vector2(150, 150)
		var col = Color(0.03, 0.08, 0.22, 0.75)
		var label = "Emplacement\nlibre"
		var ready = false
		if c:
			var t: Dictionary = Data.CHEST_TYPES[c.type]
			if c.state == "unlocking" and int(c.end) <= _now():
				c.state = "ready"
			match c.state:
				"locked":
					col = Color("2f63cf")
					label = ("Débloquer\n" if not unlocking else "Verrouillé\n") + _fmt_time(t.time)
				"unlocking":
					col = Color("1f3f8a")
					label = "Ouverture\n" + _fmt_time(int(c.end) - _now())
				"ready":
					col = Color("4fc22a")
					label = "OUVRIR !"
					ready = true
		var st = UI.panel(col, 18)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", st)
		b.add_theme_stylebox_override("pressed", st)
		var v = VBoxContainer.new()
		UI.full_rect(v)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", -4)
		if c:
			var ic = _chest_icon(c.type, 92)
			ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(ic)
			if ready:
				ic.ready.connect(func():
					ic.pivot_offset = ic.size / 2
					var tw = ic.create_tween().set_loops()
					tw.tween_property(ic, "rotation", 0.12, 0.12)
					tw.tween_property(ic, "rotation", -0.12, 0.12)
					tw.tween_property(ic, "rotation", 0.0, 0.12)
					tw.tween_interval(0.8))
		var l = UI.label(label, 18 if c else 20, Color.WHITE, 5)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		b.add_child(v)
		b.pressed.connect(_tap_chest.bind(i))
		h.add_child(b)
	# minuterie : rafraîchit l'affichage chaque seconde tant qu'un coffre s'ouvre
	if chest_timer == null:
		chest_timer = Timer.new()
		chest_timer.wait_time = 1.0
		add_child(chest_timer)
		chest_timer.timeout.connect(func():
			if tab == "battle" and battle == null and content and is_instance_valid(content):
				for c in Data.save.chests:
					if c and c.state == "unlocking":
						var slots = content.find_children("ChestSlots", "", true, false)
						if slots.size() > 0:
							var parent = slots[0].get_parent()
							var idx = slots[0].get_index()
							slots[0].queue_free()
							var n = _chest_slots()
							parent.add_child(n)
							parent.move_child(n, idx)
						break)
		chest_timer.start()
	h.name = "ChestSlots"
	return h

func _tap_chest(i: int) -> void:
	var c = Data.save.chests[i]
	if c == null:
		Sfx.play("no")
		_toast("Gagne des combats pour obtenir des coffres !")
		return
	var t: Dictionary = Data.CHEST_TYPES[c.type]
	if c.state == "ready" or (c.state == "unlocking" and int(c.end) <= _now()):
		Data.save.chests[i] = null
		_give_chest(c.type)
		return
	var unlocking = false
	for o in Data.save.chests:
		if o and o.state == "unlocking" and int(o.end) > _now():
			unlocking = true
	if c.state == "locked" and not unlocking:
		c.state = "unlocking"
		c.end = _now() + t.time
		Data.persist()
		Sfx.play("unlock")
		_rebuild_tab()
		return
	var remaining = t.time if c.state == "locked" else int(c.end) - _now()
	var cost = maxi(1, int(ceil(remaining / 60.0)))
	var m = await _modal()
	var bg: Control = m[0]
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	m[1].add_child(v)
	var ic = _chest_icon(c.type, 200)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var tl = UI.label(t.name, 44)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tl)
	var il = UI.label("%d–%d or · jusqu'à %d gemmes\nTemps restant : %s" % [t.gold[0], t.gold[1], t.gems[1], _fmt_time(remaining)], 24)
	il.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(il)
	var ob = UI.button("Ouvrir maintenant · %d gemmes" % cost, UI.GREEN, 28)
	ob.disabled = Data.save.gems < cost
	ob.pressed.connect(func():
		Data.save.gems -= cost
		Data.save.chests[i] = null
		_close_modal(bg)
		_refresh_resources()
		_give_chest(c.type))
	v.add_child(ob)
	var cl = UI.button("Fermer", UI.RED, 24)
	cl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cl.pressed.connect(_close_modal.bind(bg))
	v.add_child(cl)

func _give_chest(type: String) -> void:
	var t: Dictionary = Data.CHEST_TYPES[type]
	var gold = randi_range(t.gold[0], t.gold[1])
	var gems = randi_range(t.gems[0], t.gems[1])
	Data.save.gold += gold
	Data.save.gems += gems
	Data.persist()
	_open_chest(type, gold, gems, _bonus_card(type))

func _quests_popup() -> void:
	Sfx.play("open")
	var m = await _modal()
	var bg: Control = m[0]
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	m[1].add_child(v)
	var t = UI.label("Quêtes du jour", 46, UI.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var k = 0
	for q in Data.save.quests:
		var d: Dictionary = Data.quest_def(q.id)
		var p = PanelContainer.new()
		p.add_theme_stylebox_override("panel", UI.panel(Color(0, 0, 0, 0.3), 16))
		var h = HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		p.add_child(h)
		var qv = VBoxContainer.new()
		qv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		qv.add_child(UI.label(d.text % d.goal, 26))
		var pb = ProgressBar.new()
		pb.custom_minimum_size.y = 26
		pb.max_value = d.goal
		pb.value = int(q.progress)
		pb.show_percentage = false
		pb.add_theme_stylebox_override("background", UI.panel(UI.INK, 10))
		var pf = StyleBoxFlat.new()
		pf.bg_color = UI.GREEN
		pf.set_corner_radius_all(8)
		pb.add_theme_stylebox_override("fill", pf)
		var pl = UI.label("%d / %d" % [int(q.progress), d.goal], 18, Color.WHITE, 5)
		UI.full_rect(pl)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pb.add_child(pl)
		qv.add_child(pb)
		qv.add_child(UI.label("Récompense : %d or + %d gemmes" % [d.gold, d.gems], 18, Color("ffd84a"), 5))
		h.add_child(qv)
		var done = int(q.progress) >= d.goal
		var b = UI.button("Fait" if q.claimed else ("Récupérer" if done else "En cours"), UI.GREEN if done and not q.claimed else Color("6a7690"), 22)
		b.disabled = q.claimed or not done
		b.pressed.connect(func():
			q.claimed = true
			Data.save.gold += d.gold
			Data.save.gems += d.gems
			Data.add_xp(15)
			Data.persist()
			Sfx.play("reward")
			_reward_burst(b.global_position + b.size / 2, ["coin", "gem"])
			_refresh_resources()
			b.disabled = true
			b.text = "Fait")
		h.add_child(b)
		v.add_child(p)
		UI.pop_in(p, 0.1 + k * 0.08)
		k += 1
	var nl = UI.label("Nouvelles quêtes chaque jour !", 20, Color(1, 1, 1, 0.75), 5)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nl)
	var cl = UI.button("Fermer", UI.RED, 24)
	cl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cl.pressed.connect(func():
		_close_modal(bg)
		_show_menu())
	v.add_child(cl)

func _profile_popup() -> void:
	var m = await _modal()
	var bg: Control = m[0]
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	m[1].add_child(v)
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var lv = PanelContainer.new()
	lv.add_theme_stylebox_override("panel", UI.panel(Color("2f6fe0"), 20))
	lv.custom_minimum_size = Vector2(110, 110)
	var ll = UI.label(str(int(Data.save.level)), 56)
	ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ll.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lv.add_child(ll)
	h.add_child(lv)
	var nv = VBoxContainer.new()
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nv.add_child(UI.label(Data.save.name, 44))
	nv.add_child(UI.label("Niveau %d · %d / %d XP" % [int(Data.save.level), int(Data.save.xp), Data.xp_needed(int(Data.save.level))], 22, Color("9fd6ff"), 6))
	nv.add_child(UI.label("Clan : Les Gardiens d'Essence", 22, UI.GOLD, 6))
	h.add_child(nv)
	v.add_child(h)
	var cards_found = Data.playable().filter(func(id): return Data.unlocked(id)).size()
	var maxed = 0
	var best_card = Data.save.deck[0]
	for id in Data.save.levels:
		if int(Data.save.levels[id]) > int(Data.save.levels.get(best_card, 1)):
			best_card = id
		if int(Data.save.levels[id]) >= Data.MAX_LEVEL:
			maxed += 1
	var stats = [["Trophées", str(Data.save.trophies)], ["Record", str(maxi(int(Data.save.get("best_trophies", 0)), Data.save.trophies))],
		["Victoires", str(Data.save.wins)], ["Défaites", str(Data.save.losses)], ["Victoires 3 couronnes", str(int(Data.save.three_crowns))],
		["Tours détruites", str(int(Data.save.towers))], ["Unités déployées", str(int(Data.save.deployed))], ["Cartes trouvées", "%d / %d" % [cards_found, Data.playable().size()]], ["Coffres ouverts", str(int(Data.save.get("chests_opened", 0)))],
		["Cartes au niveau max", str(maxed)], ["Île actuelle", Data.island_for(Data.save.trophies).name]]
	var g = GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	var k = 0
	for st in stats:
		var p = PanelContainer.new()
		var ps = UI.panel(Color(0, 0, 0, 0.3), 14)
		ps.set_border_width_all(0)
		ps.set_content_margin_all(10)
		p.add_theme_stylebox_override("panel", ps)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sv = VBoxContainer.new()
		sv.add_theme_constant_override("separation", -4)
		sv.add_child(UI.label(st[0], 18, Color("bcd4ff"), 5))
		sv.add_child(UI.label(st[1], 28))
		p.add_child(sv)
		g.add_child(p)
		UI.pop_in(p, 0.05 + k * 0.03)
		k += 1
	v.add_child(g)
	var fav = HBoxContainer.new()
	fav.add_theme_constant_override("separation", 12)
	var ft = TextureRect.new()
	ft.texture = Data.card_textures[best_card]
	ft.custom_minimum_size = Vector2(90, 120)
	ft.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ft.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fav.add_child(ft)
	var fl = UI.label("Carte favorite :\n" + Data.CARDS[best_card].name, 26)
	fav.add_child(fl)
	v.add_child(fav)
	var ab = UI.button("Succès", UI.GOLD, 28)
	ab.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ab.pressed.connect(func():
		_close_modal(bg)
		_achievements_popup())
	v.add_child(ab)
	var cl = UI.button("Fermer", UI.RED, 24)
	cl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cl.pressed.connect(_close_modal.bind(bg))
	v.add_child(cl)

func _popup_page(page: Control) -> void:
	var m = await _modal()
	var bg: Control = m[0]
	var v = VBoxContainer.new()
	m[1].add_child(v)
	page.custom_minimum_size = Vector2(600, get_viewport().get_visible_rect().size.y * 0.7)
	v.add_child(page)
	var cl = UI.button("Fermer", UI.RED, 24)
	cl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cl.pressed.connect(func():
		_close_modal(bg)
		_show_menu())
	v.add_child(cl)

func _road_popup() -> void:
	_popup_page(_trophy_road())

func _settings_popup() -> void:
	_popup_page(_tab_settings())

# ---------- Clan ----------
func _clan_members() -> Array:
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	var out = []
	for n in CLAN_NAMES:
		out.append({"name": n, "trophies": maxi(0, Data.save.trophies + rng.randi_range(-250, 400)), "role": "Membre"})
	out.append({"name": Data.save.name + " (toi)", "trophies": Data.save.trophies, "role": "Membre", "me": true})
	out.sort_custom(func(a, b): return a.trophies > b.trophies)
	out[0].role = "Chef"
	out[1].role = "Adjoint"
	out[2].role = "Aîné"
	return out

func _tab_clan() -> Control:
	var v = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 14)
	var banner = PanelContainer.new()
	banner.add_theme_stylebox_override("panel", UI.panel(Color("6a2fc4"), 22))
	var bh = HBoxContainer.new()
	bh.add_theme_constant_override("separation", 14)
	var bi = UI.icon("shield", 100)
	bh.add_child(bi)
	var bv = VBoxContainer.new()
	bv.add_child(UI.label("Les Gardiens d'Essence", 38, UI.GOLD))
	bv.add_child(UI.label("13 membres · Clan francophone · Actif", 22))
	var total = 0
	for mbr in _clan_members():
		total += mbr.trophies
	bv.add_child(UI.label("Trophées du clan : %d" % total, 22, Color("ffd54a")))
	bh.add_child(bv)
	banner.add_child(bh)
	v.add_child(banner)
	UI.pop_in(banner, 0.05)
	var tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	for t in [["clan", "Discussion"], ["members", "Membres"], ["ranking", "Classement"]]:
		var b = UI.button(t[1], UI.GOLD if clan_sub == t[0] else Color("3f7cf0"), 24)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: String = t[0]
		b.pressed.connect(func():
			clan_sub = id
			_rebuild_tab())
		tabs.add_child(b)
	v.add_child(tabs)
	match clan_sub:
		"clan": v.add_child(_clan_chat())
		"members": v.add_child(_clan_list(_clan_members(), false))
		_: v.add_child(_ranking())
	return _scroll(v)

func _clan_list(list: Array, ranking: bool) -> Control:
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var k = 0
	for mbr in list:
		var p = PanelContainer.new()
		var col = Color("2f63cf") if not mbr.get("me", false) else Color("e09a1f")
		p.add_theme_stylebox_override("panel", UI.panel(col, 14))
		var h = HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		var rk = UI.label("#%d" % (k + 1), 28, UI.GOLD if k < 3 else Color.WHITE)
		rk.custom_minimum_size.x = 70
		h.add_child(rk)
		var nv = VBoxContainer.new()
		nv.add_theme_constant_override("separation", -4)
		nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nv.add_child(UI.label(mbr.name, 26))
		nv.add_child(UI.label(mbr.get("role", mbr.get("clan", "")), 18, Color("bcd4ff"), 5))
		h.add_child(nv)
		h.add_child(UI.icon("trophy", 34))
		h.add_child(UI.label(str(mbr.trophies), 26, Color("ffd54a")))
		p.add_child(h)
		box.add_child(p)
		UI.pop_in(p, 0.03 * mini(k, 15))
		k += 1
	return box

func _ranking() -> Control:
	var rng = RandomNumberGenerator.new()
	rng.seed = 7
	var clans = ["Les Rois du Pont", "Brume Éternelle", "Team Météore", "Les Gardiens d'Essence", "Squelettes & Co", "Île Céleste FR"]
	var list = []
	for i in 30:
		var n = ["Arka", "Vex", "Luna", "Brak", "Zed", "Mira", "Orion", "Kai", "Nova", "Taro"][rng.randi() % 10] + ["_", "", "X", "Pro", "77", "Fr"][rng.randi() % 6] + str(rng.randi_range(1, 99))
		list.append({"name": n, "trophies": 2400 - i * 60 + rng.randi_range(-20, 20), "clan": clans[rng.randi() % clans.size()]})
	list.append({"name": Data.save.name + " (toi)", "trophies": Data.save.trophies, "clan": "Les Gardiens d'Essence", "me": true})
	list.sort_custom(func(a, b): return a.trophies > b.trophies)
	return _clan_list(list, true)

func _clan_chat() -> Control:
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var chat: Array = Data.save.get("clan_chat", [])
	if chat.is_empty():
		for i in 6:
			chat.append({"who": CLAN_NAMES[randi() % CLAN_NAMES.size()], "text": CLAN_LINES[randi() % CLAN_LINES.size()]})
		Data.save.clan_chat = chat
	var list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	box.add_child(list)
	var add_msg = func(m: Dictionary, animate: bool):
		var me = m.who == Data.save.name
		var p = PanelContainer.new()
		p.add_theme_stylebox_override("panel", UI.panel(Color("e09a1f") if me else Color(1, 1, 1, 0.92), 16))
		p.size_flags_horizontal = Control.SIZE_SHRINK_END if me else Control.SIZE_SHRINK_BEGIN
		var mv = VBoxContainer.new()
		mv.add_theme_constant_override("separation", -2)
		mv.add_child(UI.label(m.who, 20, UI.GOLD if me else Color("2f63cf"), 0 if not me else 5))
		var tl = UI.label(m.text, 24, Color.WHITE if me else UI.INK, 5 if me else 0)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD
		tl.custom_minimum_size.x = 380
		mv.add_child(tl)
		p.add_child(mv)
		list.add_child(p)
		if animate:
			UI.pop_in(p, 0.0, 0.6)
	for m in chat.slice(maxi(0, chat.size() - 12)):
		add_msg.call(m, false)
	var input = HBoxContainer.new()
	var le = LineEdit.new()
	le.placeholder_text = "Écris un message…"
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.custom_minimum_size.y = 64
	le.add_theme_font_size_override("font_size", 26)
	input.add_child(le)
	var send = UI.button("Envoyer", UI.GREEN, 24)
	var do_send = func():
		var t = le.text.strip_edges()
		if t == "":
			return
		le.text = ""
		var msg = {"who": Data.save.name, "text": t}
		chat.append(msg)
		add_msg.call(msg, true)
		Sfx.play("swipe")
		get_tree().create_timer(randf_range(1.2, 2.6)).timeout.connect(func():
			if not is_instance_valid(list):
				return
			var reply = {"who": CLAN_NAMES[randi() % CLAN_NAMES.size()], "text": ["Haha trop vrai !", "Bien vu " + Data.save.name + " !", "On fait un combat ?", "👍", "Je suis d'accord", "Bonne chance pour ton prochain match !"][randi() % 6]}
			chat.append(reply)
			add_msg.call(reply, true)
			Sfx.play("notify")
			Data.save.clan_chat = chat.slice(maxi(0, chat.size() - 30))
			Data.persist())
	send.pressed.connect(do_send)
	le.text_submitted.connect(func(_t): do_send.call())
	input.add_child(send)
	box.add_child(input)
	return box

# ---------- Événements / modes de jeu ----------
func _tab_events() -> Control:
	var v = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 16)
	v.add_child(_ribbon("Modes de jeu"))
	var k = 0
	for md in Data.MODES:
		var on = md.id == Data.save.get("mode", "classic")
		var p = PanelContainer.new()
		var st = UI.panel(md.color.darkened(0.15), 24)
		if on:
			st.border_color = UI.GOLD
			st.set_border_width_all(7)
		p.add_theme_stylebox_override("panel", st)
		var h = HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		var ic = UI.icon("swords" if md.id == "classic" else ("drop" if md.id in ["double", "triple"] else ("crown" if md.id == "sudden" else "cards")), 96)
		h.add_child(ic)
		var tv = VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UI.label(md.name, 36))
		var dl = UI.label(md.desc, 20)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD
		dl.custom_minimum_size.x = 300
		tv.add_child(dl)
		tv.add_child(UI.label("Trophées en jeu" if md.trophies else "Sans perte de trophées", 18, Color("ffd54a") if md.trophies else Color("c8ffc8"), 5))
		h.add_child(tv)
		var b = UI.button("Jouer", UI.GOLD, 28)
		var id: String = md.id
		b.pressed.connect(func():
			Data.save.mode = id
			Data.persist()
			_matchmaking())
		h.add_child(b)
		p.add_child(h)
		v.add_child(p)
		UI.pop_in(p, 0.05 + k * 0.07)
		k += 1
	return _scroll(v)


# ================= Contenu : route des trophées, pass, succès, cadeaux, offres =================
func _reward_text(r: Dictionary) -> String:
	if r.has("gold"):
		return "%d or" % r.gold
	if r.has("gems"):
		return "%d gemmes" % r.gems
	return Data.CHEST_TYPES[r.chest].name

func _reward_icon(r: Dictionary, sz: float) -> Control:
	if r.has("chest"):
		return _chest_icon(r.chest, sz)
	var ic = UI.icon("coin" if r.has("gold") else "gem", sz)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return ic

## Donne une récompense (or, gemmes ou coffre à ouvrir tout de suite).
func _grant(r: Dictionary, from: Vector2) -> void:
	if r.has("chest"):
		_give_chest(r.chest)
		return
	if r.has("gold"):
		Data.save.gold += r.gold
	if r.has("gems"):
		Data.save.gems += r.gems
	Data.persist()
	Sfx.play("reward")
	_reward_burst(from, ["coin"] if r.has("gold") else ["gem"])
	_refresh_resources()

func _road_claimable() -> int:
	var n = 0
	for i in Data.ROAD.size():
		if Data.save.trophies >= Data.ROAD[i].t and not i in Data.save.road_claimed:
			n += 1
	return n

func _trophy_road() -> Control:
	var v = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	v.add_child(_ribbon("Route des trophées"))
	var rows = []
	for isl in Data.ISLANDS:
		rows.append({"kind": "island", "t": isl.trophies, "isl": isl})
	for i in Data.ROAD.size():
		rows.append({"kind": "reward", "t": Data.ROAD[i].t, "i": i})
	rows.sort_custom(func(a, b): return a.t > b.t if a.t != b.t else a.kind == "reward")
	var cur = Data.island_for(Data.save.trophies)
	for row in rows:
		var reached = Data.save.trophies >= row.t
		var p = PanelContainer.new()
		var h = HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		p.add_child(h)
		if row.kind == "island":
			var isl: Dictionary = row.isl
			var st = UI.panel(isl.sky.darkened(0.3) if reached else Color("3a4458"), 22)
			if isl.id == cur.id:
				st.border_color = UI.GOLD
				st.set_border_width_all(6)
			p.add_theme_stylebox_override("panel", st)
			h.add_child(UI.icon("island", 90))
			var tv = VBoxContainer.new()
			tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tv.add_child(UI.label(isl.name, 34))
			var th = HBoxContainer.new()
			th.add_child(UI.icon("trophy", 28))
			th.add_child(UI.label("%d" % isl.trophies, 22, Color("ffd54a"), 6))
			tv.add_child(th)
			h.add_child(tv)
			var cards = HBoxContainer.new()
			cards.add_theme_constant_override("separation", 2)
			for id in Data.playable():
				if Data.UNLOCK.get(id, 0) == isl.id and isl.id > 0:
					var tr = TextureRect.new()
					tr.texture = Data.card_textures[id]
					tr.custom_minimum_size = Vector2(46, 60)
					tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					if not reached:
						tr.modulate = Color(0.35, 0.35, 0.45)
					cards.add_child(tr)
			h.add_child(cards)
			if not reached:
				p.modulate = Color(0.8, 0.8, 0.85)
		else:
			var r: Dictionary = Data.ROAD[row.i]
			var claimed = row.i in Data.save.road_claimed
			p.add_theme_stylebox_override("panel", UI.panel(Color("1f3f8a") if reached else Color(0.05, 0.08, 0.2, 0.8), 16))
			var tl = HBoxContainer.new()
			tl.custom_minimum_size.x = 120
			tl.add_child(UI.icon("trophy", 30))
			tl.add_child(UI.label(str(r.t), 26, Color("ffd54a")))
			h.add_child(tl)
			h.add_child(_reward_icon(r, 64))
			var nl = UI.label(_reward_text(r), 26)
			nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(nl)
			var b = UI.button("Reçu" if claimed else ("Récupérer" if reached else "Verrouillé"), UI.GREEN if reached and not claimed else Color("5a6680"), 22)
			b.disabled = claimed or not reached
			var idx: int = row.i
			b.pressed.connect(func():
				Data.save.road_claimed.append(idx)
				Data.persist()
				b.disabled = true
				b.text = "Reçu"
				_grant(r, b.global_position + b.size / 2))
			h.add_child(b)
		v.add_child(p)
	return _scroll(v)

func _pass_tier() -> int:
	return mini(Data.PASS.size(), int(Data.save.pass_points) / Data.PASS_STEP)

func _pass_claimable() -> int:
	var n = 0
	for i in _pass_tier():
		if not i in Data.save.pass_claimed:
			n += 1
	return n

func _pass_popup() -> void:
	Sfx.play("open")
	var page = VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 12)
	page.add_child(_ribbon("Pass Essence"))
	var tier = _pass_tier()
	var info = UI.label("Palier %d / %d  ·  1 couronne gagnée = 1 point, %d points par palier" % [tier, Data.PASS.size(), Data.PASS_STEP], 20, Color("e7c6ff"), 5)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	page.add_child(info)
	var pb = ProgressBar.new()
	pb.custom_minimum_size.y = 30
	pb.show_percentage = false
	pb.max_value = Data.PASS_STEP
	pb.value = int(Data.save.pass_points) % Data.PASS_STEP if tier < Data.PASS.size() else Data.PASS_STEP
	pb.add_theme_stylebox_override("background", UI.panel(UI.INK, 12))
	var pf = StyleBoxFlat.new()
	pf.bg_color = UI.PURPLE
	pf.set_corner_radius_all(10)
	pb.add_theme_stylebox_override("fill", pf)
	page.add_child(pb)
	for i in Data.PASS.size():
		var r: Dictionary = Data.PASS[i]
		var reached = i < tier
		var claimed = i in Data.save.pass_claimed
		var p = PanelContainer.new()
		p.add_theme_stylebox_override("panel", UI.panel(Color("6a2fc4") if reached else Color(0.12, 0.08, 0.25, 0.85), 16))
		var h = HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		p.add_child(h)
		var num = UI.label(str(i + 1), 34, UI.GOLD if reached else Color(0.7, 0.7, 0.8))
		num.custom_minimum_size.x = 56
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(num)
		h.add_child(_reward_icon(r, 64))
		var nl = UI.label(_reward_text(r), 26)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nl)
		var b = UI.button("Reçu" if claimed else ("Récupérer" if reached else "%d pts" % ((i + 1) * Data.PASS_STEP)), UI.GREEN if reached and not claimed else Color("5a6680"), 22)
		b.disabled = claimed or not reached
		var idx = i
		b.pressed.connect(func():
			Data.save.pass_claimed.append(idx)
			Data.persist()
			b.disabled = true
			b.text = "Reçu"
			_grant(r, b.global_position + b.size / 2))
		h.add_child(b)
		page.add_child(p)
	_popup_page(_scroll(page))

func _ach_value(stat: String) -> int:
	if stat == "best_trophies":
		return maxi(int(Data.save.get("best_trophies", 0)), Data.save.trophies)
	return int(Data.save.get(stat, 0))

func _achievements_popup() -> void:
	var page = VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 10)
	page.add_child(_ribbon("Succès"))
	for a in Data.ACHIEVEMENTS:
		var val = _ach_value(a[2])
		var goal: int = a[3]
		var done = val >= goal
		var claimed = a[0] in Data.save.ach_claimed
		var p = PanelContainer.new()
		p.add_theme_stylebox_override("panel", UI.panel(Color("1f6f3a") if claimed else (Color("2f63cf") if done else Color(0.05, 0.08, 0.2, 0.85)), 16))
		var h = HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		p.add_child(h)
		h.add_child(UI.icon("trophy" if done else "lock", 56))
		var tv = VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UI.label(a[1], 26))
		var bar = ProgressBar.new()
		bar.custom_minimum_size.y = 20
		bar.max_value = goal
		bar.value = mini(val, goal)
		bar.show_percentage = false
		bar.add_theme_stylebox_override("background", UI.panel(UI.INK, 8))
		var bf = StyleBoxFlat.new()
		bf.bg_color = UI.GOLD
		bf.set_corner_radius_all(6)
		bar.add_theme_stylebox_override("fill", bf)
		tv.add_child(bar)
		tv.add_child(UI.label("%d / %d  ·  %d gemmes" % [mini(val, goal), goal, a[4]], 18, Color("c8ffc8"), 5))
		h.add_child(tv)
		var b = UI.button("Reçu" if claimed else "Récupérer", UI.GREEN if done and not claimed else Color("5a6680"), 22)
		b.disabled = claimed or not done
		var id: String = a[0]
		var gems: int = a[4]
		b.pressed.connect(func():
			Data.save.ach_claimed.append(id)
			b.disabled = true
			b.text = "Reçu"
			Sfx.play("achievement")
			_grant({"gems": gems}, b.global_position + b.size / 2))
		h.add_child(b)
		page.add_child(p)
	_popup_page(_scroll(page))

## Cadeau de connexion quotidien (calendrier de 7 jours).
func _login_popup() -> void:
	var day = int(Time.get_unix_time_from_system() / 86400)
	if int(Data.save.get("login_day", -1)) == day:
		return
	var idx = int(Data.save.get("login_index", 0)) % Data.LOGIN.size()
	var m = await _modal()
	var bg: Control = m[0]
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	m[1].add_child(v)
	var t = UI.label("Cadeau du jour !", 50, UI.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var g = GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	for i in Data.LOGIN.size():
		var r: Dictionary = Data.LOGIN[i]
		var p = PanelContainer.new()
		var col = Color("1f6f3a") if i < idx else (UI.GOLD.darkened(0.2) if i == idx else Color(0.05, 0.08, 0.2, 0.85))
		p.add_theme_stylebox_override("panel", UI.panel(col, 16))
		var pv = VBoxContainer.new()
		pv.alignment = BoxContainer.ALIGNMENT_CENTER
		var dl = UI.label("Jour %d" % (i + 1), 20)
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pv.add_child(dl)
		pv.add_child(_reward_icon(r, 70))
		var rl = UI.label(_reward_text(r), 16, Color.WHITE, 5)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD
		rl.custom_minimum_size.x = 120
		pv.add_child(rl)
		p.add_child(pv)
		g.add_child(p)
		UI.pop_in(p, 0.05 * i)
		if i == idx:
			p.ready.connect(func(): UI.pulse(p, 1.06, 0.8))
	v.add_child(g)
	var b = UI.button("Récupérer", UI.GREEN, 32)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func():
		Data.save.login_day = day
		Data.save.login_index = idx + 1
		Data.persist()
		_close_modal(bg)
		_grant(Data.LOGIN[idx], get_viewport().get_visible_rect().size / 2))
	v.add_child(b)

## Offres du jour : 3 améliorations de cartes à prix réduit + gemmes gratuites.
func _daily_deals() -> Control:
	var day = int(Time.get_unix_time_from_system() / 86400)
	if int(Data.save.get("deal_day", -1)) != day:
		var pool = Data.playable().filter(func(id): return Data.unlocked(id) and int(Data.save.levels[id]) < Data.MAX_LEVEL)
		pool.shuffle()
		Data.save.deal_day = day
		Data.save.deals = pool.slice(0, 3)
		Data.save.deals_bought = []
		Data.persist()
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.add_child(UI.label("Offres du jour", 34))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	# gemmes gratuites
	var fp = PanelContainer.new()
	fp.add_theme_stylebox_override("panel", UI.panel(Color("1f8a4a"), 18))
	fp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fv = VBoxContainer.new()
	fv.alignment = BoxContainer.ALIGNMENT_CENTER
	var gi = UI.icon("gem", 90)
	gi.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	fv.add_child(gi)
	var fl = UI.label("10 gemmes", 22)
	fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fv.add_child(fl)
	var got = "free" in Data.save.deals_bought
	var fb = UI.button("Pris" if got else "Gratuit", UI.GREEN, 22)
	fb.disabled = got
	fb.pressed.connect(func():
		Data.save.deals_bought.append("free")
		fb.disabled = true
		fb.text = "Pris"
		_grant({"gems": 10}, fb.global_position + fb.size / 2))
	fv.add_child(fb)
	fp.add_child(fv)
	row.add_child(fp)
	for id in Data.save.deals:
		if not Data.CARDS.has(id):
			continue
		var lvl = int(Data.save.levels[id])
		var price = int(Data.upgrade_cost(lvl) * 0.6)
		var p = PanelContainer.new()
		p.add_theme_stylebox_override("panel", UI.panel(Color("2f63cf"), 18))
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pv = VBoxContainer.new()
		pv.alignment = BoxContainer.ALIGNMENT_CENTER
		var tr = TextureRect.new()
		tr.texture = Data.card_textures[id]
		tr.custom_minimum_size = Vector2(80, 100)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pv.add_child(tr)
		var ll = UI.label("Niv. %d → %d" % [lvl, lvl + 1], 18, Color("7cf27a"), 5)
		ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pv.add_child(ll)
		var bought = id in Data.save.deals_bought
		var b = UI.button("Acheté" if bought else "%d or" % price, UI.GOLD, 20)
		b.disabled = bought or Data.save.gold < price or lvl >= Data.MAX_LEVEL
		b.pressed.connect(func():
			Data.save.gold -= price
			Data.save.levels[id] = int(Data.save.levels[id]) + 1
			Data.save.deals_bought.append(id)
			Data.persist()
			Sfx.play("levelup")
			_refresh_resources()
			b.disabled = true
			b.text = "Acheté")
		pv.add_child(b)
		p.add_child(pv)
		row.add_child(p)
	box.add_child(row)
	return box
