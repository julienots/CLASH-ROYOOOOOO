extends Control
## Coquille de l'application : fond animé, barre supérieure, navigation, écrans, superpositions et notifications.

static var inst: Control

const TOP_H := 118.0
const NAV_H := 140.0
const TABS := [
	["home", "Accueil", "ui_home"], ["collection", "Album", "ui_album"], ["shop", "Boutique", "ui_shop"],
	["battle_select", "Combat", "ui_battle"], ["decks", "Decks", "ui_deck"]]

var bg: ColorRect
var top: Control
var content: Control
var nav: Control
var overlay: Control
var toasts: VBoxContainer
var current_name := ""
var current: Control
var _nav_buttons := {}
var _cur_labels := {}
var _lvl_label: Label
var _xp_bar: ProgressBar
var _name_label: Label
var _badge_missions: Label

func _ready() -> void:
	inst = self
	var args := OS.get_cmdline_user_args()
	if "--logic-test" in args:
		var s = load("res://scripts/tests/logic_test.gd")
		var t = s.new()
		add_child(t)
		var f: int = t.run()
		get_tree().quit(1 if f > 0 else 0)
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	Profile.changed.connect(_refresh_top)
	Profile.toast.connect(show_toast)
	get_viewport().size_changed.connect(_layout)
	_layout()
	goto("home")
	Sfx.music("music_menu")
	for a in args:
		if a.begins_with("--shots="):
			var sh = load("res://scripts/tests/shots.gd").new()
			add_child(sh)
			sh.run(self, a.substr(8))

func _build() -> void:
	bg = ColorRect.new()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/menu_bg.gdshader")
	bg.material = m
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	content = Control.new()
	content.clip_contents = true
	add_child(content)
	_build_top()
	_build_nav()
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	toasts = UI.vbox(10)
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toasts)

func _layout() -> void:
	var s := get_viewport_rect().size
	size = s
	bg.size = s
	bg.material.set_shader_parameter("res", s)
	top.size = Vector2(s.x, TOP_H)
	content.position = Vector2(0, TOP_H)
	content.size = Vector2(s.x, s.y - TOP_H - NAV_H)
	nav.position = Vector2(0, s.y - NAV_H)
	nav.size = Vector2(s.x, NAV_H)
	overlay.size = s
	toasts.position = Vector2(30, TOP_H + 10)
	toasts.size = Vector2(s.x - 60, 0)
	if current:
		current.size = content.size

# ---------------------------------------------------------------- barre supérieure
func _build_top() -> void:
	top = Control.new()
	add_child(top)
	var bar := Panel.new()
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	var st := UI.box(Color(0.05, 0.03, 0.1, 0.88), 0, UI.LINE, 0)
	st.border_width_bottom = 2
	st.border_color = UI.LINE
	bar.add_theme_stylebox_override("panel", st)
	top.add_child(bar)
	var h := UI.hbox(10)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 16
	h.offset_right = -16
	h.offset_top = 14
	h.offset_bottom = -14
	top.add_child(h)
	# avatar + niveau
	var av := Button.new()
	av.custom_minimum_size = Vector2(86, 86)
	av.focus_mode = Control.FOCUS_NONE
	av.add_theme_stylebox_override("normal", UI.box(UI.PANEL2, 43, UI.GOLD, 4))
	av.add_theme_stylebox_override("hover", UI.box(UI.PANEL2.lightened(0.1), 43, UI.GOLD, 4))
	av.add_theme_stylebox_override("pressed", UI.box(UI.PANEL2, 43, UI.GOLD, 4))
	av.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_lvl_label = UI.label("1", 38, UI.GOLD, "num", 400, HORIZONTAL_ALIGNMENT_CENTER)
	UI.outline(_lvl_label, 6)
	_lvl_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lvl_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	av.add_child(_lvl_label)
	UI.juice(av)
	av.pressed.connect(func(): goto("profile"))
	h.add_child(av)
	var nv := UI.vbox(4)
	nv.custom_minimum_size = Vector2(150, 0)
	nv.alignment = BoxContainer.ALIGNMENT_CENTER
	_name_label = UI.label("Invocateur", 22, UI.TEXT, "body", 800)
	_name_label.clip_text = true
	nv.add_child(_name_label)
	_xp_bar = UI.progress(0.3, UI.GOLD, 12)
	nv.add_child(_xp_bar)
	h.add_child(nv)
	h.add_child(UI.expand(UI.spacer()))
	for cur in ["coins", "crystals", "tokens"]:
		var chip := PanelContainer.new()
		var cs := UI.box(Color(0, 0, 0, 0.45), 20, UI.LINE, 2)
		cs.content_margin_left = 6
		cs.content_margin_right = 12
		chip.add_theme_stylebox_override("panel", cs)
		var ch := UI.hbox(4)
		ch.add_child(UI.icon_rect(cur.trim_suffix("s") if cur != "crystals" else "crystal", 38))
		var l := UI.label("0", 24, Color.WHITE, "num", 400)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ch.add_child(l)
		chip.add_child(ch)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_cur_labels[cur] = l
		h.add_child(chip)
	var gear := UI.icon_button("ui_gear", 62)
	gear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gear.pressed.connect(func(): goto("settings"))
	h.add_child(gear)
	_refresh_top()

func _refresh_top() -> void:
	if _lvl_label == null:
		return
	var d: Dictionary = Profile.d
	_lvl_label.text = str(d.level)
	_name_label.text = d.name
	var lo := Profile.xp_needed(int(d.level) - 1) if int(d.level) > 1 else 0
	var hi := Profile.xp_needed(int(d.level))
	_xp_bar.value = float(int(d.xp) - lo) / max(1, hi - lo)
	for cur in _cur_labels:
		var l: Label = _cur_labels[cur]
		var v := int(d.get(cur, 0))
		l.text = _short(v)
	if _badge_missions:
		var n := Profile.pending_rewards()
		_badge_missions.text = str(n)
		_badge_missions.visible = n > 0

static func _short(v: int) -> String:
	if v >= 100000:
		return "%dk" % (v / 1000)
	if v >= 10000:
		return "%.1fk" % (v / 1000.0)
	return str(v)

# ---------------------------------------------------------------- navigation
func _build_nav() -> void:
	nav = Control.new()
	add_child(nav)
	var bar := Panel.new()
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	var st := UI.box(Color(0.05, 0.03, 0.1, 0.94), 0)
	st.border_width_top = 2
	st.border_color = UI.LINE
	bar.add_theme_stylebox_override("panel", st)
	nav.add_child(bar)
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_bottom = -18
	h.add_theme_constant_override("separation", 0)
	nav.add_child(h)
	for t in TABS:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var v := UI.vbox(2)
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hl := Panel.new()
		hl.name = "hl"
		hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hl.add_theme_stylebox_override("panel", UI.box(Color(UI.ACCENT, 0.28), 26, UI.ACCENT, 2))
		hl.set_anchors_preset(Control.PRESET_FULL_RECT)
		hl.offset_left = 8
		hl.offset_right = -8
		hl.offset_top = 10
		hl.offset_bottom = 0
		b.add_child(hl)
		var ic := UI.icon_rect(t[2], 56)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		var l := UI.label(t[1], 20, UI.MUTED, "body", 700, HORIZONTAL_ALIGNMENT_CENTER)
		l.name = "lbl"
		v.add_child(l)
		b.add_child(v)
		UI.juice(b)
		var target: String = t[0]
		b.pressed.connect(func(): goto(target))
		h.add_child(b)
		_nav_buttons[target] = b

func _update_nav(name: String) -> void:
	for k in _nav_buttons:
		var b: Button = _nav_buttons[k]
		var on: bool = k == name
		b.get_node("hl").visible = on
		var l: Label = b.find_child("lbl", true, false)
		l.add_theme_color_override("font_color", Color.WHITE if on else UI.MUTED)

func goto(name: String, params := {}) -> void:
	if name == current_name and params.is_empty() and current != null:
		if current.has_method("refresh"):
			current.refresh()
		return
	var path := "res://scripts/screens/%s.gd" % name
	if not ResourceLoader.exists(path):
		show_toast("Écran indisponible : " + name, "error")
		return
	var old := current
	var scr: Control = load(path).new()
	scr.size = content.size
	scr.set_meta("main", self)
	current = scr
	current_name = name
	content.add_child(scr)
	if scr.has_method("setup"):
		scr.setup(params)
	_update_nav(name)
	_refresh_top()
	scr.modulate.a = 0
	scr.position = Vector2(0, 30)
	var t := scr.create_tween().set_parallel(true)
	t.tween_property(scr, "modulate:a", 1.0, 0.22)
	t.tween_property(scr, "position", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if old:
		var t2 := old.create_tween()
		t2.tween_property(old, "modulate:a", 0.0, 0.15)
		t2.tween_callback(old.queue_free)

## Superposition plein écran (détail de carte, ouverture de booster, combat…).
func open_overlay(node: Control, hide_chrome := false) -> void:
	node.size = size
	overlay.add_child(node)
	if hide_chrome:
		node.set_meta("fullscreen", true)
		top.visible = false
		nav.visible = false
		content.visible = false
	node.tree_exited.connect(func():
		if is_instance_valid(top) and _no_fullscreen():
			top.visible = true
			nav.visible = true
			content.visible = true
			_refresh_top()
			if current and current.has_method("refresh"):
				current.refresh())

func _no_fullscreen() -> bool:
	for c in overlay.get_children():
		if c.get_meta("fullscreen", false) and not c.is_queued_for_deletion():
			return false
	return true

func show_toast(text: String, kind := "info") -> void:
	var col: Color = {"reward": UI.GOLD, "level": UI.ACCENT2, "error": UI.BAD}.get(kind, UI.ACCENT)
	var p := UI.panel(Color(0.07, 0.04, 0.14, 0.95), 20, col, 3)
	var l := UI.label(text, 24, Color.WHITE, "body", 700, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.add_child(p)
	if kind == "error":
		Sfx.play("error")
	elif kind in ["reward", "level"]:
		Sfx.play("coin")
	p.modulate.a = 0
	var t := p.create_tween()
	t.tween_property(p, "modulate:a", 1.0, 0.2)
	t.tween_interval(2.4)
	t.tween_property(p, "modulate:a", 0.0, 0.4)
	t.tween_callback(p.queue_free)

## Fenêtre modale générique.
func modal(title: String, body: Control, buttons: Array = []) -> Control:
	var root := Control.new()
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.size = size
	root.add_child(dim)
	var p := UI.panel(UI.PANEL, 30, UI.ACCENT, 3)
	p.custom_minimum_size = Vector2(size.x - 60, 0)
	var v := UI.vbox(18)
	var tl := UI.label(title, 36, UI.GOLD, "serif", 800, HORIZONTAL_ALIGNMENT_CENTER)
	UI.outline(tl, 6)
	v.add_child(tl)
	v.add_child(body)
	var bh := UI.hbox(16)
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	if buttons.is_empty():
		buttons = [["Fermer", UI.ACCENT, null]]
	for bd in buttons:
		var b := UI.button(bd[0], bd[1], 26, Vector2(220, 76))
		var cb = bd[2]
		b.pressed.connect(func():
			root.queue_free()
			if cb != null:
				cb.call())
		bh.add_child(b)
	v.add_child(bh)
	p.add_child(v)
	root.add_child(p)
	open_overlay(root)
	await get_tree().process_frame
	p.position = (size - p.size) / 2
	UI.pop_in(p)
	return root

# ---------------------------------------------------------------- Android : retour et mise en pause
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		Profile.save_game()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()

func _on_back() -> void:
	if overlay and overlay.get_child_count() > 0:
		var top_node: Node = overlay.get_child(overlay.get_child_count() - 1)
		if top_node.has_method("_confirm_quit"):
			top_node._confirm_quit()
		elif top_node.has_method("_close"):
			top_node._close()
		elif top_node.get_meta("fullscreen", false) and top_node.get("phase") != "summary":
			pass  # ouverture de booster en cours : on laisse finir
		else:
			top_node.queue_free()
		return
	if current_name != "home":
		goto("home")
	else:
		Profile.save_game()
		get_tree().quit()

func show_card(id: String, variant := "", list: Array = []) -> void:
	var d = load("res://scripts/ui/card_detail.gd").new()
	d.setup(id, variant, list)
	open_overlay(d)
