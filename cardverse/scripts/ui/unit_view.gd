class_name UnitView extends Control
## Créature sur le terrain : illustration, cadre de rareté, ATQ/PV, mots-clés et états (gel, bouclier, furtif…).

const SZ := Vector2(126, 162)

signal tapped(v: UnitView)

var uid := 0
var data := {}
var _art: TextureRect
var _border: Panel
var _atk: Label
var _hp: Label
var _icons: HBoxContainer
var _ice: ColorRect
var _shield: Panel
var _ready_glow: Panel
var _target_glow: Panel
var _sleep: Label

func setup(u: Dictionary) -> void:
	uid = int(u.uid)
	data = u.duplicate(true)

func _ready() -> void:
	size = SZ
	pivot_offset = SZ / 2
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ready_glow = Panel.new()
	_ready_glow.position = Vector2(-7, -7)
	_ready_glow.size = SZ + Vector2(14, 14)
	_ready_glow.add_theme_stylebox_override("panel", UI.box(Color(0.3, 1, 0.5, 0.15), 18, Color(0.4, 1, 0.55), 4))
	_ready_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ready_glow.visible = false
	add_child(_ready_glow)
	_target_glow = Panel.new()
	_target_glow.position = Vector2(-8, -8)
	_target_glow.size = SZ + Vector2(16, 16)
	_target_glow.add_theme_stylebox_override("panel", UI.box(Color(1, 0.3, 0.3, 0.2), 18, Color(1, 0.35, 0.3), 5))
	_target_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_glow.visible = false
	add_child(_target_glow)
	var clip := Panel.new()
	clip.size = SZ
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_theme_stylebox_override("panel", UI.box(Color(0.05, 0.03, 0.1), 14))
	add_child(clip)
	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.size = SZ
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(_art)
	_ice = ColorRect.new()
	_ice.size = SZ
	_ice.color = Color(0.5, 0.85, 1.0, 0.45)
	_ice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ice.visible = false
	clip.add_child(_ice)
	_border = Panel.new()
	_border.size = SZ
	_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_border)
	_shield = Panel.new()
	_shield.position = Vector2(-4, -4)
	_shield.size = SZ + Vector2(8, 8)
	_shield.add_theme_stylebox_override("panel", UI.box(Color(1, 0.85, 0.3, 0.12), 18, Color(1, 0.85, 0.35), 5))
	_shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shield)
	_icons = UI.hbox(2)
	_icons.position = Vector2(4, 4)
	add_child(_icons)
	for i in 2:
		var bg := Panel.new()
		bg.size = Vector2(48, 48)
		bg.position = Vector2(-8 if i == 0 else SZ.x - 40, SZ.y - 40)
		bg.add_theme_stylebox_override("panel", UI.box(Color("c4402c") if i == 0 else Color("3f9e5a"), 24, Color(1, 1, 1, 0.85), 3))
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		var l := UI.label("0", 30, Color.WHITE, "num", 400, HORIZONTAL_ALIGNMENT_CENTER)
		UI.outline(l, 6)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size = bg.size
		bg.add_child(l)
		if i == 0:
			_atk = l
		else:
			_hp = l
	_sleep = UI.label("z z", 26, Color(0.8, 0.85, 1), "num", 400, HORIZONTAL_ALIGNMENT_RIGHT)
	UI.outline(_sleep, 5)
	_sleep.position = Vector2(SZ.x - 70, 2)
	_sleep.size = Vector2(64, 30)
	add_child(_sleep)
	refresh(data)

func refresh(u: Dictionary) -> void:
	data = u.duplicate(true)
	var c := DB.card(u.id)
	var at := AtlasTexture.new()
	at.atlas = DB.card_art(u.id)
	at.region = Rect2(75, 80, 300, 270)
	_art.texture = at
	_border.add_theme_stylebox_override("panel", UI.box(Color(0, 0, 0, 0), 14, DB.rarity_color(c.rarity), 4))
	_atk.text = str(u.atk)
	_hp.text = str(u.hp)
	_hp.add_theme_color_override("font_color", Color("ffb3b3") if int(u.hp) < int(u.max_hp) else Color.WHITE)
	_atk.add_theme_color_override("font_color", Color("ffe08a") if int(u.atk) > int(c.get("atk", 0)) else Color.WHITE)
	_ice.visible = int(u.get("frozen", 0)) > 0
	_shield.visible = u.kw.get("bouclier", false)
	modulate.a = 0.55 if u.kw.get("furtif", false) else 1.0
	for ch in _icons.get_children():
		ch.queue_free()
	if u.kw.get("garde", false):
		_icons.add_child(UI.icon_rect("ui_shield", 30, Color("ffd36e")))
	if u.kw.get("poison", false):
		_icons.add_child(UI.icon_rect("ui_flame", 26, Color("8dff6a")))
	if u.kw.get("vol_de_vie", false):
		_icons.add_child(UI.icon_rect("ui_heart", 26, Color("ff6f8f")))
	if u.kw.get("rage", false):
		_icons.add_child(UI.icon_rect("ui_star", 26, Color("ff8a4a")))
	if u.kw.get("celerite", false):
		_icons.add_child(UI.icon_rect("ui_energy", 26, Color("ffe14a")))
	if u.kw.get("pietinement", false):
		_icons.add_child(UI.icon_rect("ui_trample", 28, Color("ffb340")))
	if u.kw.get("envol", false):
		_icons.add_child(UI.icon_rect("ui_wing", 28, Color("bfe6ff")))
	if u.get("silenced", false):
		_icons.add_child(UI.icon_rect("ui_mute", 28, Color("c9c2d8")))
	_art.modulate = Color(0.7, 0.7, 0.75) if u.get("silenced", false) else Color.WHITE
	_sleep.visible = u.get("sleep", false) and not u.kw.get("celerite", false)

func set_ready(v: bool) -> void:
	_ready_glow.visible = v

func set_target(v: bool) -> void:
	_target_glow.visible = v

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		tapped.emit(self)

func center() -> Vector2:
	return global_position + SZ / 2
