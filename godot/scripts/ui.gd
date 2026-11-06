class_name UI
## Petits utilitaires d'interface : thème, boutons « jeu mobile », icônes dessinées, animations.

const INK := Color("0b1430")
const GOLD := Color("ffc928")
const BLUE := Color("2f86ff")
const RED := Color("f2384a")
const GREEN := Color("4fc22a")
const PURPLE := Color("c23cf0")

static var font: Font

static func theme() -> Theme:
	font = load("res://assets/lilita_one.woff2")
	var t = Theme.new()
	t.default_font = font
	t.default_font_size = 26
	t.set_color("font_color", "Label", Color.WHITE)
	t.set_color("font_outline_color", "Label", INK)
	t.set_constant("outline_size", "Label", 8)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.5))
	t.set_constant("shadow_offset_y", "Label", 3)
	t.set_constant("shadow_offset_x", "Label", 0)
	t.set_color("font_outline_color", "Button", INK)
	t.set_constant("outline_size", "Button", 8)
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.85, 0.85, 0.85))
	t.set_font_size("font_size", "Button", 30)
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.04, 0.09, 0.25, 0.75)
	ps.set_corner_radius_all(20)
	ps.set_border_width_all(3)
	ps.border_color = Color(1, 1, 1, 0.12)
	t.set_stylebox("panel", "PanelContainer", ps)
	t.set_stylebox("panel", "Panel", ps)
	var le = StyleBoxFlat.new()
	le.bg_color = Color.WHITE
	le.set_corner_radius_all(12)
	le.set_border_width_all(3)
	le.border_color = INK
	le.content_margin_left = 14
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", le)
	t.set_color("font_color", "LineEdit", INK)
	return t

static func box(color: Color, radius := 18, border := 4, shadow := 6) -> StyleBox:
	return FancyBox.make(color, radius, border, shadow, 0.32)

static func panel(color: Color, radius := 20) -> StyleBox:
	var f = FancyBox.make(color, radius, 4, 0, 0.12 if color.a > 0.9 else 0.05)
	f.content_margin_left = 14
	f.content_margin_right = 14
	f.content_margin_top = 14
	f.content_margin_bottom = 14
	return f

## Bouton brillant avec effet d'enfoncement et rebond.
static func button(text: String, color := GOLD, size := 30) -> Button:
	var b = Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	var n = box(color)
	var h = box(color.lightened(0.12))
	var p = box(color.darkened(0.1), 18, 4, 2)
	p.content_margin_top = 14
	var d = box(color.darkened(0.45).lerp(Color.GRAY, 0.4))
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", d)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.button_down.connect(func(): Sfx.play("click"); squash(b, 0.92))
	b.button_up.connect(func(): squash(b, 1.0))
	b.resized.connect(func(): b.pivot_offset = b.size / 2)
	return b

## Bouton rond brillant avec icône, libellé dessous et pastille de notification.
static func round_button(icon_kind: String, text: String, color: Color, badge: int, cb: Callable) -> Control:
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", -6)
	var b = Button.new()
	b.custom_minimum_size = Vector2(92, 92)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var st = FancyBox.make(color, 44, 5, 6, 0.38)
	st.content_margin_left = 0
	st.content_margin_right = 0
	st.content_margin_top = 0
	st.content_margin_bottom = 0
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st)
	b.add_theme_stylebox_override("pressed", FancyBox.make(color.darkened(0.1), 44, 5, 2, 0.3))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ic = icon(icon_kind, 58)
	ic.size = Vector2(58, 58)
	ic.position = Vector2(17, 12)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	if badge > 0:
		var bd = Badge.new()
		bd.count = badge
		bd.position = Vector2(58, -8)
		bd.size = Vector2(40, 40)
		bd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(bd)
		b.ready.connect(func(): pulse(b, 1.07, 0.9))
	b.pressed.connect(cb)
	b.button_down.connect(func(): Sfx.play("open"); squash(b, 0.9))
	b.button_up.connect(func(): squash(b, 1.0))
	v.add_child(b)
	var l = label(text, 20, Color.WHITE, 7)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = 104
	v.add_child(l)
	return v

class Badge extends Control:
	var count = 1
	func _draw() -> void:
		var c = size / 2
		draw_circle(c, size.x / 2, Color("0b1430"))
		draw_circle(c, size.x / 2 - 4, Color("ff3b3b"))
		draw_circle(c + Vector2(-5, -6), size.x / 6, Color(1, 1, 1, 0.35))
		var f: Font = UI.font
		draw_string_outline(f, Vector2(0, c.y + 10), str(count), HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, 6, Color("0b1430"))
		draw_string(f, Vector2(0, c.y + 10), str(count), HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, Color.WHITE)

static func squash(c: Control, s: float) -> void:
	c.pivot_offset = c.size / 2
	var tw = c.create_tween()
	tw.tween_property(c, "scale", Vector2(s, s) if s < 1.0 else Vector2(1.06, 1.06), 0.06)
	if s >= 1.0:
		tw.tween_property(c, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

static func label(text: String, size := 26, color := Color.WHITE, outline := 8) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", outline)
	return l

## Fait apparaître un contrôle avec un rebond élastique.
static func pop_in(c: Control, delay := 0.0, from := 0.3) -> void:
	if not c.is_inside_tree():
		await c.tree_entered
		await c.get_tree().process_frame
		if not is_instance_valid(c):
			return
	c.pivot_offset = c.size / 2
	c.scale = Vector2(from, from)
	c.modulate.a = 0.0
	var tw = c.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func(): c.pivot_offset = c.size / 2)
	tw.tween_property(c, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(c, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

static func slide_in(c: Control, offset: Vector2, delay := 0.0, dur := 0.45) -> void:
	if not c.is_inside_tree():
		await c.tree_entered
		await c.get_tree().process_frame
		if not is_instance_valid(c):
			return
	var target = c.position
	c.position = target + offset
	var tw = c.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(c, "position", target, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

static func pulse(c: Control, amount := 1.06, period := 1.4) -> void:
	if not c.is_inside_tree():
		await c.tree_entered
		await c.get_tree().process_frame
		if not is_instance_valid(c):
			return
	c.pivot_offset = c.size / 2
	var tw = c.create_tween().set_loops()
	tw.tween_property(c, "scale", Vector2(amount, amount), period / 2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(c, "scale", Vector2.ONE, period / 2).set_trans(Tween.TRANS_SINE)

static func icon(kind: String, s := 40.0) -> Icon:
	var i = Icon.new()
	i.kind = kind
	i.custom_minimum_size = Vector2(s, s)
	return i

static func full_rect(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
