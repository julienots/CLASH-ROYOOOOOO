extends Control
## Ouverture de booster : rotation du paquet au doigt, déchirure en glissant, flash, révélation carte par carte
## avec effets selon la rareté (faille cosmique pour les Mythiques et au-delà), puis récapitulatif.

var booster := {}
var results: Array = []

var phase := "pack"  # pack -> tearing -> reveal -> summary
var stage: Control
var dim: ColorRect
var pack_root: Control
var pack_top: TextureRect
var pack_body: TextureRect
var tear_line: Line2D
var hint: Label
var _tear_from := -1.0
var _tear_max := 0.0
var _tear_min := 99999.0
var _spin := 0.0
var _spin_target := 0.0
var _drag_x := -1.0
var _t := 0.0
var idx := 0
var current: CardView
var _busy := false
var _rift: ColorRect
var _glow: ColorRect
var _title: Label
var _done_cards: Array = []
var _tick_cd := 0.0

const PACK_SIZE := Vector2(330, 510)

func setup(b: Dictionary, res: Array) -> void:
	booster = b
	results = res

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/menu_bg.gdshader")
	var c := Color(booster.color)
	m.set_shader_parameter("c1", Color(0.02, 0.01, 0.05))
	m.set_shader_parameter("c2", c.darkened(0.6))
	m.set_shader_parameter("c3", c.darkened(0.35))
	m.set_shader_parameter("res", size)
	bg.material = m
	add_child(bg)
	_glow = UI.glow_rect(Color(c, 0.5), Vector2(900, 900), 1.5, 14.0)
	_glow.position = size / 2 - Vector2(450, 470)
	add_child(_glow)
	stage = Control.new()
	stage.size = size
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0)
	dim.size = size
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_rift = ColorRect.new()
	_rift.size = size
	_rift.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rm := ShaderMaterial.new()
	rm.shader = load("res://shaders/rift.gdshader")
	rm.set_shader_parameter("res", size)
	_rift.material = rm
	_rift.visible = false
	add_child(_rift)
	_build_pack()
	var title := UI.label(booster.name, 40, Color.WHITE, "serif", 800, HORIZONTAL_ALIGNMENT_CENTER)
	UI.outline(title, 8)
	title.position = Vector2(0, 80)
	title.size = Vector2(size.x, 60)
	title.name = "pack_title"
	add_child(title)
	hint = UI.label("Fais tourner le booster, puis glisse le long du haut pour le déchirer", 24, UI.TEXT, "body", 700, HORIZONTAL_ALIGNMENT_CENTER)
	UI.outline(hint, 6)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.position = Vector2(40, size.y - 260)
	hint.size = Vector2(size.x - 80, 80)
	add_child(hint)
	var quick := UI.button("Ouvrir", Color(booster.color).darkened(0.2), 26, Vector2(240, 80), "ui_gift")
	quick.position = Vector2(size.x / 2 - 120, size.y - 160)
	quick.name = "quick"
	quick.pressed.connect(auto_tear)
	add_child(quick)
	Sfx.play("whoosh")

func _build_pack() -> void:
	pack_root = Control.new()
	pack_root.size = PACK_SIZE
	pack_root.position = size / 2 - PACK_SIZE / 2 - Vector2(0, 40)
	pack_root.pivot_offset = PACK_SIZE / 2
	pack_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(pack_root)
	var tex := DB.tex("res://assets/ui/packs/%s.png" % booster.id)
	var top_h := tex.get_height() * 0.16
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(0, 0, tex.get_width(), top_h)
	var ab := AtlasTexture.new()
	ab.atlas = tex
	ab.region = Rect2(0, top_h, tex.get_width(), tex.get_height() - top_h)
	var k := PACK_SIZE.x / tex.get_width()
	pack_top = TextureRect.new()
	pack_top.texture = at
	pack_top.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pack_top.size = Vector2(PACK_SIZE.x, top_h * k)
	pack_top.pivot_offset = pack_top.size / 2
	pack_top.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pack_body = TextureRect.new()
	pack_body.texture = ab
	pack_body.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pack_body.position = Vector2(0, top_h * k)
	pack_body.size = Vector2(PACK_SIZE.x, PACK_SIZE.y - top_h * k)
	pack_body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pack_root.add_child(pack_body)
	pack_root.add_child(pack_top)
	var shine := ColorRect.new()
	shine.size = PACK_SIZE
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/card_fx.gdshader")
	sm.set_shader_parameter("mode", 2)
	sm.set_shader_parameter("card_size", PACK_SIZE)
	sm.set_shader_parameter("intensity", 0.7)
	shine.material = sm
	shine.name = "shine"
	pack_root.add_child(shine)
	var name_l := UI.label(booster.name.to_upper(), 26, Color.WHITE, "serif", 800, HORIZONTAL_ALIGNMENT_CENTER)
	UI.outline(name_l, 7)
	name_l.position = Vector2(10, PACK_SIZE.y - 120)
	name_l.size = Vector2(PACK_SIZE.x - 20, 40)
	UI.fit(name_l, PACK_SIZE.x - 30, 26, 16)
	pack_root.add_child(name_l)
	var logo := UI.label("CARDVERSE", 30, Color("fff2d0"), "title", 700, HORIZONTAL_ALIGNMENT_CENTER)
	UI.outline(logo, 8, Color("2a0d4a"))
	logo.position = Vector2(0, PACK_SIZE.y * 0.16 + 6)
	logo.size = Vector2(PACK_SIZE.x, 40)
	pack_root.add_child(logo)
	tear_line = Line2D.new()
	tear_line.width = 6
	tear_line.default_color = Color(1, 0.95, 0.8)
	tear_line.position = Vector2(0, top_h * k)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	tear_line.material = mat
	pack_root.add_child(tear_line)
	UI.pop_in(pack_root, 0.05, 0.3)

func _pack_rect() -> Rect2:
	return Rect2(pack_root.position, PACK_SIZE)

func _gui_input(e: InputEvent) -> void:
	if phase == "pack" or phase == "tearing":
		var r := _pack_rect()
		var tear_zone := Rect2(r.position + Vector2(-60, -40), Vector2(r.size.x + 120, r.size.y * 0.3 + 40))
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				if tear_zone.has_point(e.position):
					phase = "tearing"
					_tear_from = e.position.x
					_tear_min = e.position.x
					_tear_max = e.position.x
				else:
					_drag_x = e.position.x
			else:
				_drag_x = -1
				if phase == "tearing" and _tear_progress() < 0.75:
					phase = "pack"
					tear_line.clear_points()
		elif e is InputEventMouseMotion:
			if phase == "tearing":
				_tear_min = min(_tear_min, e.position.x)
				_tear_max = max(_tear_max, e.position.x)
				_update_tear(e.position.x)
			elif _drag_x >= 0:
				_spin_target = clampf(_spin_target + (e.position.x - _drag_x) / 200.0, -1.2, 1.2)
				_drag_x = e.position.x
	elif phase == "reveal" and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_advance()

func _tear_progress() -> float:
	return (_tear_max - _tear_min) / PACK_SIZE.x

func _update_tear(x: float) -> void:
	var r := _pack_rect()
	var p := _tear_progress()
	tear_line.clear_points()
	var x0: float = clampf(_tear_min - r.position.x, 0, PACK_SIZE.x)
	var x1: float = clampf(_tear_max - r.position.x, 0, PACK_SIZE.x)
	var n := 12
	for i in n + 1:
		var xx: float = lerpf(x0, x1, float(i) / n)
		tear_line.add_point(Vector2(xx, sin(xx * 0.3) * 4))
	pack_top.rotation = -p * 0.08
	if _tick_cd <= 0:
		Sfx.play("tear_tick", randf_range(0.9, 1.2))
		_tick_cd = 0.05
	if p >= 0.75:
		_finish_tear()

func auto_tear() -> void:
	if phase != "pack" and phase != "tearing":
		return
	phase = "tearing"
	var r := _pack_rect()
	_tear_min = r.position.x
	var t := create_tween()
	t.tween_method(func(x):
		_tear_max = x
		_update_tear(x), r.position.x, r.position.x + PACK_SIZE.x * 0.8, 0.45)

func _finish_tear() -> void:
	if phase != "tearing":
		return
	phase = "opening"
	_busy = true
	get_node("quick").queue_free()
	hint.text = ""
	Sfx.play("tear")
	tear_line.clear_points()
	var t := create_tween().set_parallel(true)
	t.tween_property(pack_top, "position", pack_top.position + Vector2(260, -420), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(pack_top, "rotation", 1.6, 0.6)
	t.tween_property(pack_top, "modulate:a", 0.0, 0.6)
	await get_tree().create_timer(0.18).timeout
	_flash(Color(1, 1, 1), 0.5)
	Sfx.play("flash")
	UI.burst(self, pack_root.position + Vector2(PACK_SIZE.x / 2, 60), Color(booster.color).lightened(0.3), 70, 700, 0.8, 1.1)
	UI.shake(stage, 10, 0.3)
	# les cartes sortent du paquet
	var hi := 0
	for r in results:
		hi = max(hi, int(DB.rarity(DB.card(r.id).rarity).fx))
	var t2 := create_tween()
	t2.tween_property(pack_root, "position:y", size.y + 100, 0.7).set_delay(0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t2.parallel().tween_property(get_node("pack_title"), "modulate:a", 0.0, 0.4)
	await get_tree().create_timer(0.4).timeout
	_spawn_stack()
	await get_tree().create_timer(0.9).timeout
	phase = "reveal"
	_busy = false
	hint.text = "Touche pour retourner la carte"
	_show_next()

func _flash(c: Color, dur: float) -> void:
	var f := ColorRect.new()
	f.color = c
	f.size = size
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(f)
	var t := f.create_tween()
	t.tween_property(f, "color:a", 0.0, dur)
	t.tween_callback(f.queue_free)

var _stack: Array = []

func _spawn_stack() -> void:
	for i in results.size():
		var r: Dictionary = results[i]
		var cv := CardView.make(r.id, 0.86, r.variant, "back")
		cv.serial = int(r.get("serial", 0))
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var target := size / 2 - Vector2(CardView.W, CardView.H) * 0.43 + Vector2(0, -60) + Vector2(i * 4, -i * 6)
		cv.position = Vector2(target.x, size.y * 0.6)
		cv.modulate.a = 0
		stage.add_child(cv)
		stage.move_child(cv, 0)
		var t := cv.create_tween().set_parallel(true)
		t.tween_property(cv, "position", target, 0.55).set_delay(i * 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(cv, "modulate:a", 1.0, 0.3).set_delay(i * 0.08)
		_stack.append(cv)
	# la carte la plus faible (results[0]) au-dessus de la pile
	for i in range(_stack.size() - 1, -1, -1):
		stage.move_child(_stack[i], stage.get_child_count() - 1)

## Prépare la carte suivante : anticipation lumineuse selon la rareté.
func _show_next() -> void:
	if idx >= results.size():
		_summary()
		return
	current = _stack[idx]
	var r: Dictionary = results[idx]
	var c := DB.card(r.id)
	var fx := int(DB.rarity(c.rarity).fx)
	var col := DB.rarity_color(c.rarity)
	_glow.material.set_shader_parameter("color", Color(col, 0.25 + fx * 0.12) if fx > 0 else Color(1, 1, 1, 0.12))
	if fx >= 1:
		var t := current.create_tween().set_loops(3)
		t.tween_property(current, "modulate", Color(1.0 + fx * 0.15, 1.0 + fx * 0.1, 1.0 + fx * 0.15), 0.25)
		t.tween_property(current, "modulate", Color.WHITE, 0.25)
	if fx >= 2:
		UI.shake(current, 3.0 + fx * 2, 0.5)

func _advance() -> void:
	if _busy or phase != "reveal":
		return
	if current and current.state == "back":
		_busy = true
		await _reveal(current, results[idx])
		_busy = false
	elif current:
		_busy = true
		_stash(current)
		idx += 1
		await get_tree().create_timer(0.15).timeout
		_busy = false
		_show_next()

func _reveal(cv: CardView, r: Dictionary) -> void:
	var c := DB.card(r.id)
	var fx := int(DB.rarity(c.rarity).fx)
	var col := DB.rarity_color(c.rarity)
	var ri := DB.rarity_index(c.rarity)
	if ri >= DB.rarity_index("M"):
		await _cosmic_sequence(cv, c, col)
	cv.set_pivot(Vector2(CardView.W, CardView.H) / 2)
	Sfx.play("flip")
	var t := cv.create_tween()
	t.tween_property(cv, "scale:x", 0.0, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished
	cv.show_face(true)
	var t2 := cv.create_tween()
	t2.tween_property(cv, "scale:x", 0.94, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t2.parallel().tween_property(cv, "scale:y", 0.94, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t2.tween_property(cv, "scale", Vector2(0.86, 0.86), 0.25)
	var center := cv.position + Vector2(CardView.W, CardView.H) * 0.5
	var snd := "reveal_1"
	if fx >= 1:
		snd = "reveal_2"
	if ri >= DB.rarity_index("L"):
		snd = "reveal_3"
	if ri >= DB.rarity_index("M"):
		snd = "reveal_4"
	Sfx.play(snd)
	UI.burst(self, center, col, 30 + fx * 30, 400 + fx * 150, 0.5 + fx * 0.12, 0.9 + fx * 0.2, 200)
	if fx >= 2:
		_flash(Color(col, 0.6), 0.45)
		UI.shake(stage, 6 + fx * 3, 0.35)
	if fx >= 3:
		UI.aura_particles(cv, Rect2(Vector2.ZERO, Vector2(CardView.W, CardView.H)), col, 30)
	_label_for(c, r, col, fx)

func _label_for(c: Dictionary, r: Dictionary, col: Color, fx: int) -> void:
	if _title:
		_title.queue_free()
	_title = UI.label(DB.rarity(c.rarity).name.to_upper() + ("  !" if fx >= 2 else ""), 34 + fx * 6, col.lightened(0.2), "serif", 800, HORIZONTAL_ALIGNMENT_CENTER)
	UI.outline(_title, 10)
	_title.position = Vector2(0, 110)
	_title.size = Vector2(size.x, 70)
	add_child(_title)
	UI.pop_in(_title, 0.0, 0.3)
	var extra := []
	if r.get("new", false):
		extra.append("NOUVELLE CARTE")
	if r.variant != "":
		extra.append(DB.variants[r.variant].name.to_upper())
	if r.get("pity", false):
		extra.append("GARANTIE")
	hint.text = "  ·  ".join(extra) if not extra.is_empty() else "Touche pour continuer"
	hint.add_theme_color_override("font_color", UI.GOLD if not extra.is_empty() else UI.TEXT)

## Mise en scène des hautes raretés : l'écran s'assombrit, une faille cosmique s'ouvre et libère la carte.
func _cosmic_sequence(cv: CardView, c: Dictionary, col: Color) -> void:
	hint.text = ""
	var t := create_tween()
	t.tween_property(dim, "color:a", 0.85, 0.5)
	Sfx.play("rift")
	_rift.visible = true
	_rift.material.set_shader_parameter("color", col)
	_rift.material.set_shader_parameter("open", 0.0)
	var cv_pos := cv.position
	var t2 := create_tween()
	t2.tween_property(cv, "modulate:a", 0.0, 0.3)
	t2.tween_method(func(v): _rift.material.set_shader_parameter("open", v), 0.0, 1.0, 1.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	UI.shake(self, 8, 1.6)
	await t2.finished
	move_child(cv.get_parent(), get_child_count() - 1)
	cv.set_pivot(Vector2(CardView.W, CardView.H) / 2)
	cv.scale = Vector2(0.2, 0.2)
	cv.modulate.a = 1.0
	cv.position = cv_pos
	_flash(Color(1, 1, 1), 0.8)
	var rays := UI.glow_rect(Color(col, 0.9), Vector2(1400, 1400), 1.2, 18.0)
	rays.position = size / 2 - Vector2(700, 760)
	add_child(rays)
	move_child(rays, get_child_count() - 2)
	var t3 := create_tween().set_parallel(true)
	t3.tween_property(cv, "scale", Vector2(0.86, 0.86), 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t3.tween_property(dim, "color:a", 0.4, 0.9)
	t3.tween_method(func(v): _rift.material.set_shader_parameter("open", v), 1.0, 0.0, 1.2)
	t3.tween_property(rays, "modulate:a", 0.0, 2.5).set_delay(0.8)
	await get_tree().create_timer(0.75).timeout
	get_tree().create_timer(3.0).timeout.connect(rays.queue_free)

## Remet le pivot en haut à gauche sans déplacer visuellement la carte.
func _unpivot(cv: CardView) -> void:
	cv.set_pivot(Vector2.ZERO)

func _stash(cv: CardView) -> void:
	_unpivot(cv)
	_done_cards.append(cv)
	var n := _done_cards.size() - 1
	var target := Vector2(20 + n * 138, size.y - 330)
	Sfx.play("whoosh", 1.3)
	var t := cv.create_tween().set_parallel(true)
	t.tween_property(cv, "position", target, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(cv, "scale", Vector2(0.29, 0.29), 0.35)
	t.tween_property(cv, "rotation", (n - 2) * 0.04, 0.35)
	if _title:
		_title.queue_free()
		_title = null

func _summary() -> void:
	if phase == "summary":
		return
	phase = "summary"
	hint.text = ""
	_glow.material.set_shader_parameter("color", Color(booster.color, 0.3))
	for i in _done_cards.size():
		var cv: CardView = _done_cards[i]
		var col := i % 3
		var row := i / 3
		var target := Vector2(30 + col * 228 + (114 if row == 1 else 0), 160 + row * 330)
		var t := cv.create_tween().set_parallel(true)
		t.tween_property(cv, "position", target, 0.45).set_delay(i * 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(cv, "scale", Vector2(0.46, 0.46), 0.45).set_delay(i * 0.05)
		t.tween_property(cv, "rotation", 0.0, 0.3)
		cv.mouse_filter = Control.MOUSE_FILTER_STOP
		var id: String = results[i].id
		var vr: String = results[i].variant
		cv.tapped.connect(func(_c): Main_show(id, vr))
		if results[i].get("new", false):
			var nb := UI.badge("NOUVELLE", UI.GOOD.darkened(0.1), 34)
			nb.position = Vector2(110, -26)
			cv.add_child(nb)
	var tl := UI.label("Récapitulatif", 40, UI.GOLD, "serif", 800, HORIZONTAL_ALIGNMENT_CENTER)
	UI.outline(tl, 8)
	tl.position = Vector2(0, 70)
	tl.size = Vector2(size.x, 60)
	add_child(tl)
	var h := UI.hbox(16)
	h.position = Vector2(40, size.y - 170)
	h.size = Vector2(size.x - 80, 100)
	var again_b := UI.button("Encore un", Color(booster.color).darkened(0.2), 26, Vector2(0, 92), "ui_gift")
	again_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var can: bool = Profile.can_pay(booster.price) or (booster.id == "classic" and int(Profile.d.free_boosters) > 0)
	again_b.disabled = not can
	again_b.pressed.connect(func():
		var main = get_tree().root.get_node("Main")
		queue_free()
		if main.current and main.current.has_method("open_booster"):
			main.current.open_booster(booster))
	h.add_child(again_b)
	var cont := UI.button("Continuer", UI.ACCENT, 26, Vector2(0, 92), "ui_check")
	cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cont.pressed.connect(func():
		Sfx.play("back")
		queue_free())
	h.add_child(cont)
	add_child(h)
	UI.pop_in(h, 0.3)

func Main_show(id: String, vr: String) -> void:
	get_tree().root.get_node("Main").show_card(id, vr)

func _process(delta: float) -> void:
	_t += delta
	_tick_cd -= delta
	if phase == "pack" or phase == "tearing":
		_spin = lerpf(_spin, _spin_target, delta * 6)
		if _drag_x < 0:
			_spin_target = lerpf(_spin_target, 0.0, delta * 1.5)
		pack_root.scale.x = cos(_spin) * (1.0 + sin(_t * 2) * 0.01)
		pack_root.scale.y = 1.0 + sin(_t * 2) * 0.01
		pack_root.position.y = size.y / 2 - PACK_SIZE.y / 2 - 40 + sin(_t * 1.5) * 8
		var sh := pack_root.get_node_or_null("shine")
		if sh:
			sh.material.set_shader_parameter("tilt", Vector2(_spin * 2.0 + sin(_t * 0.5), 0))
	if current and phase == "reveal" and current.state == "face":
		current.set_tilt(Vector2(sin(_t), cos(_t * 0.7)) * 0.6)
