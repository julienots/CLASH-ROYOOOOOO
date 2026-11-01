class_name UI
## Boîte à outils d'interface : polices, couleurs, styles, boutons animés, particules et effets.

const BG := Color("0b0716")
const PANEL := Color("171029")
const PANEL2 := Color("221640")
const LINE := Color("3d2a6b")
const GOLD := Color("ffcf5a")
const TEXT := Color("efe9ff")
const MUTED := Color("a99fc8")
const ACCENT := Color("8a5bff")
const ACCENT2 := Color("39d0ff")
const GOOD := Color("5ee08a")
const BAD := Color("ff5a6e")

static var _fonts := {}

static func font(kind := "body", weight := 500) -> Font:
	var key := "%s_%d" % [kind, weight]
	if _fonts.has(key):
		return _fonts[key]
	var path := "res://assets/fonts/Exo2.ttf"
	match kind:
		"title": path = "res://assets/fonts/CinzelDecorative-Bold.ttf"
		"serif": path = "res://assets/fonts/Cinzel.ttf"
		"num": path = "res://assets/fonts/lilita_one.woff2"
	var base: FontFile = load(path)
	var f: Font = base
	if kind in ["body", "serif"]:
		var v := FontVariation.new()
		v.base_font = base
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		f = v
	_fonts[key] = f
	return f

# ---------------------------------------------------------------- styles
static func box(bg: Color, radius := 18, border := Color(0, 0, 0, 0), bw := 0, shadow := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	if shadow > 0:
		s.shadow_color = Color(0, 0, 0, 0.45)
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0, shadow * 0.4)
	s.anti_aliasing = true
	return s

static func grad_box(top: Color, bottom: Color, radius := 18, border := Color(0, 0, 0, 0), bw := 0) -> StyleBoxTexture:
	var g := Gradient.new()
	g.set_color(0, top)
	g.set_color(1, bottom)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	var s := StyleBoxTexture.new()
	s.texture = gt
	return s

static func label(text: String, size := 26, color := TEXT, kind := "body", weight := 600, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind, weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func outline(l: Control, size := 6, c := Color(0.04, 0.02, 0.08)) -> Control:
	l.add_theme_constant_override("outline_size", size)
	l.add_theme_color_override("font_outline_color", c)
	return l

static func rich(text: String, size := 22, color := TEXT) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = text
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_override("normal_font", font("body", 500))
	r.add_theme_font_override("bold_font", font("body", 800))
	r.add_theme_font_override("italics_font", font("serif", 500))
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_size_override("italics_font_size", size - 2)
	r.add_theme_color_override("default_color", color)
	return r

## Bouton premium : dégradé, contour lumineux, rebond au toucher, son.
static func button(text: String, color := ACCENT, size := 28, min_size := Vector2(0, 84), icon_name := "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font("body", 800))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 0.85))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.4))
	b.add_theme_constant_override("outline_size", 5)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.45))
	var n := box(color.darkened(0.05), 22, color.lightened(0.45), 3, 6)
	n.bg_color = color
	var h := box(color.lightened(0.12), 22, color.lightened(0.6), 3, 8)
	var p := box(color.darkened(0.25), 22, color.lightened(0.3), 3, 2)
	var dis := box(Color(0.25, 0.22, 0.32), 22, Color(0.4, 0.37, 0.5), 3, 2)
	for st in [n, h, p, dis]:
		st.content_margin_left = 22
		st.content_margin_right = 22
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", dis)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if icon_name != "":
		b.icon = DB.icon(icon_name)
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", int(size * 1.3))
	juice(b)
	return b

## Rebond élastique + son sur un bouton.
static func juice(b: BaseButton, snd := "click") -> void:
	b.pivot_offset = b.size / 2
	b.resized.connect(func(): b.pivot_offset = b.size / 2)
	b.button_down.connect(func():
		var t := b.create_tween()
		t.tween_property(b, "scale", Vector2(0.93, 0.93), 0.06))
	b.button_up.connect(func():
		var t := b.create_tween()
		t.tween_property(b, "scale", Vector2(1.06, 1.06), 0.08)
		t.tween_property(b, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT))
	if snd != "":
		b.pressed.connect(func(): Sfx.play(snd))

static func icon_rect(name: String, size := 40, tint := Color.WHITE) -> TextureRect:
	var t := TextureRect.new()
	t.texture = DB.icon(name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.modulate = tint
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

static func icon_button(name: String, size := 72, tint := Color.WHITE, bg := PANEL2) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_NONE
	b.icon = DB.icon(name)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for k in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(k, tint)
	var m := int(size * 0.22)
	for st_name in ["normal", "hover", "pressed"]:
		var col := bg if st_name == "normal" else (bg.lightened(0.1) if st_name == "hover" else bg.darkened(0.2))
		var st := box(col, size / 2, LINE if st_name == "normal" else ACCENT, 2)
		st.content_margin_left = m
		st.content_margin_right = m
		st.content_margin_top = m
		st.content_margin_bottom = m
		b.add_theme_stylebox_override(st_name, st)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	juice(b)
	return b

## Réduit la taille de police d'un label jusqu'à ce que le texte tienne dans la largeur.
static func fit(l: Label, width: float, max_size: int, min_size := 14) -> void:
	var f: Font = l.get_theme_font("font")
	var s := max_size
	while s > min_size and f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > width:
		s -= 1
	l.add_theme_font_size_override("font_size", s)

static func date_fr(iso: String) -> String:
	var p := iso.split("-")
	return "%s/%s/%s" % [p[2], p[1], p[0]] if p.size() == 3 else iso

static func panel(bg := PANEL, radius := 24, border := LINE, bw := 2) -> PanelContainer:
	var p := PanelContainer.new()
	var s := box(bg, radius, border, bw, 8)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 18
	s.content_margin_bottom = 18
	p.add_theme_stylebox_override("panel", s)
	return p

static func vbox(sep := 14) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep := 14) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func spacer(h := 0, w := 0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func expand(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

static func price_text(price: Dictionary) -> String:
	for k in price:
		return "%d" % int(price[k])
	return "Gratuit"

static func price_icon(price: Dictionary) -> String:
	for k in price:
		match k:
			"coins": return "coin"
			"crystals": return "crystal"
			"tokens": return "token"
			"event": return "event"
			"dust": return "dust"
	return ""

static func price_button(price: Dictionary, color := ACCENT, size := 26) -> Button:
	var b := button(price_text(price), color, size, Vector2(0, 70))
	var ic := price_icon(price)
	if ic != "":
		b.icon = DB.icon(ic)
		b.add_theme_constant_override("icon_max_width", 40)
	if not Profile.can_pay(price):
		b.modulate = Color(1, 0.75, 0.75)
	return b

static func progress(value: float, color := ACCENT2, h := 16, bg := Color(0, 0, 0, 0.4)) -> ProgressBar:
	var p := ProgressBar.new()
	p.min_value = 0
	p.max_value = 1
	p.value = clampf(value, 0, 1)
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, h)
	p.add_theme_stylebox_override("background", box(bg, h / 2))
	p.add_theme_stylebox_override("fill", box(color, h / 2))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

static func badge(text: String, color := BAD, size := 20) -> Label:
	var l := label(text, size, Color.WHITE, "body", 800, HORIZONTAL_ALIGNMENT_CENTER)
	var s := box(color, 14, Color.WHITE, 2)
	s.content_margin_left = 8
	s.content_margin_right = 8
	l.add_theme_stylebox_override("normal", s)
	return l

# ---------------------------------------------------------------- particules et effets
static var _dot: Texture2D

static func dot_tex() -> Texture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(0.5, 0.0)
		gt.width = 32
		gt.height = 32
		_dot = gt
	return _dot

## Gerbe de particules ponctuelle.
static func burst(parent: Node, pos: Vector2, color: Color, amount := 40, speed := 420.0, scale_v := 0.6, life := 0.9, gravity := 300.0) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = dot_tex()
	p.position = pos
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = life
	p.direction = Vector2(0, -1)
	p.spread = 180
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.damping_min = 40
	p.damping_max = 120
	p.scale_amount_min = scale_v * 0.4
	p.scale_amount_max = scale_v
	var g := Gradient.new()
	g.set_color(0, color.lightened(0.5))
	g.set_color(1, Color(color.r, color.g, color.b, 0))
	p.color_ramp = g
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	parent.add_child(p)
	p.emitting = true
	parent.get_tree().create_timer(life + 0.5).timeout.connect(p.queue_free)
	return p

## Particules continues (aura autour d'une carte rare).
static func aura_particles(parent: Node, rect: Rect2, color: Color, amount := 24) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = dot_tex()
	p.position = rect.get_center()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = rect.size / 2
	p.amount = amount
	p.lifetime = 2.2
	p.direction = Vector2(0, -1)
	p.spread = 25
	p.initial_velocity_min = 20
	p.initial_velocity_max = 70
	p.gravity = Vector2(0, -20)
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.45
	var g := Gradient.new()
	g.set_color(0, Color(color.r, color.g, color.b, 0))
	g.add_point(0.3, color.lightened(0.4))
	g.set_color(g.get_point_count() - 1, Color(color.r, color.g, color.b, 0))
	p.color_ramp = g
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	parent.add_child(p)
	return p

static func glow_rect(color: Color, size: Vector2, power := 2.0, rays := 0.0) -> ColorRect:
	var r := ColorRect.new()
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/flash.gdshader")
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("power", power)
	m.set_shader_parameter("rays", rays)
	r.material = m
	return r

static func shake(node: CanvasItem, strength := 12.0, dur := 0.35) -> void:
	var base: Vector2 = node.position
	var t := node.create_tween()
	var n := int(dur / 0.04)
	for i in n:
		var k := 1.0 - float(i) / n
		t.tween_property(node, "position", base + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * k, 0.04)
	t.tween_property(node, "position", base, 0.04)

static func pop_in(node: Control, delay := 0.0, from := 0.6) -> void:
	node.pivot_offset = node.size / 2
	node.scale = Vector2(from, from)
	node.modulate.a = 0
	var t := node.create_tween()
	t.tween_interval(delay)
	t.set_parallel(true)
	t.tween_property(node, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "modulate:a", 1.0, 0.25)

static func float_text(parent: Node, pos: Vector2, text: String, color: Color, size := 46) -> void:
	var l := label(text, size, color, "num", 400, HORIZONTAL_ALIGNMENT_CENTER)
	outline(l, 10)
	l.position = pos - Vector2(100, 30)
	l.size = Vector2(200, 60)
	l.pivot_offset = l.size / 2
	l.scale = Vector2(0.4, 0.4)
	l.z_index = 50
	parent.add_child(l)
	var t := l.create_tween()
	t.tween_property(l, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK)
	t.tween_property(l, "scale", Vector2.ONE, 0.1)
	t.set_parallel(true)
	t.tween_property(l, "position:y", l.position.y - 90, 0.9).set_delay(0.25)
	t.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.6)
	t.chain().tween_callback(l.queue_free)
