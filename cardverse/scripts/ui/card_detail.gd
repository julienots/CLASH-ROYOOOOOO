extends Control
## Fiche détaillée d'une carte : grande carte inclinable au doigt (perspective 3D + reflets),
## aura et particules selon la rareté, infos de collection, favoris, navigation et comparaison.

var card_id := ""
var variant := ""
var list: Array = []
var _vp: SubViewport
var _card: CardView
var _disp: TextureRect
var _mat: ShaderMaterial
var _drag := false
var _tilt := Vector2.ZERO
var _target := Vector2.ZERO
var _t := 0.0
var _info: VBoxContainer
var _particles: CPUParticles2D
var _glow: ColorRect

const DISP := Vector2(540, 756)

func setup(id: String, var_name := "", ids: Array = []) -> void:
	card_id = id
	variant = var_name
	list = ids

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.color = Color(0.02, 0.01, 0.05, 0.93)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_vp = SubViewport.new()
	_vp.size = Vector2i(CardView.W + 120, CardView.H + 120)
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_glow = UI.glow_rect(Color.WHITE, Vector2(820, 820), 1.8, 12.0)
	add_child(_glow)
	_disp = TextureRect.new()
	_disp.texture = _vp.get_texture()
	_disp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_disp.size = DISP * (CardView.W + 120) / CardView.W
	_disp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/tilt.gdshader")
	_mat.set_shader_parameter("inset", 0.0)
	_disp.material = _mat
	add_child(_disp)
	_info = UI.vbox(10)
	add_child(_info)
	var close := UI.icon_button("ui_close", 74)
	close.position = Vector2(size.x - 100, 30)
	close.pressed.connect(_close)
	add_child(close)
	_load_card()

func _load_card() -> void:
	for c in _vp.get_children():
		c.queue_free()
	var owned := Profile.owned(card_id) > 0
	var c := DB.card(card_id)
	var st := "face" if owned or c.get("token", false) or list.is_empty() else "preview"
	if c.rarity == "SW" and not owned:
		st = "auto"
	_card = CardView.make(card_id, 1.0, variant, st)
	_card.position = Vector2(60, 60)
	_card.serial = int(Profile.entry(card_id).get("serial", 0))
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp.add_child(_card)
	var col := DB.rarity_color(c.rarity)
	var fx := int(DB.rarity(c.rarity).fx)
	_glow.material.set_shader_parameter("color", Color(col, 0.18 + fx * 0.1))
	_glow.visible = fx >= 1 and _card.state != "missing"
	if _particles:
		_particles.queue_free()
		_particles = null
	if fx >= 2 and _card.state != "missing":
		_particles = UI.aura_particles(self, Rect2(Vector2((size.x - DISP.x) / 2, 120), DISP), col, 14 + fx * 10)
	_build_info()
	_layout()

func _layout() -> void:
	var cx := size.x / 2
	_disp.position = Vector2(cx - _disp.size.x / 2, 90 - (_disp.size.y - DISP.y) / 2)
	_glow.position = Vector2(cx - 410, 90 + DISP.y / 2 - 410)
	_info.position = Vector2(40, 90 + DISP.y + 24)
	_info.size = Vector2(size.x - 80, 0)

func _build_info() -> void:
	for ch in _info.get_children():
		ch.queue_free()
	var c := DB.card(card_id)
	var e := Profile.entry(card_id)
	var owned := int(e.get("count", 0))
	var h := UI.hbox(12)
	var rl := UI.label(DB.rarity(c.rarity).name.to_upper(), 26, DB.rarity_color(c.rarity), "serif", 800)
	UI.outline(rl, 5)
	h.add_child(rl)
	h.add_child(UI.label("· %s · %s" % [DB.element_name(c.element), DB.family_name(c.family)], 22, UI.MUTED, "body", 600))
	_info.add_child(h)
	var h2 := UI.hbox(14)
	var txt := "Possédée : %d" % owned if owned > 0 else ("Jeton (créé en combat)" if c.get("token", false) else "Non découverte")
	if c.rarity == "SW" and owned == 0:
		txt = "Carte SWAP : %d / 9 pièces de puzzle (trouvables dans les boosters)" % Profile.pieces(card_id).size()
	h2.add_child(UI.expand(UI.label(txt, 22, UI.TEXT, "body", 700)))
	if owned > 0:
		var vs: Dictionary = e.get("variants", {})
		if not vs.is_empty():
			h2.add_child(UI.label("Variantes : " + ", ".join(vs.keys().map(func(k): return DB.variants[k].name)), 18, UI.GOLD, "body", 700))
	_info.add_child(h2)
	var bh := UI.hbox(12)
	if owned > 0:
		var fav := UI.button("Favori" if not e.get("fav", false) else "Retirer", Color("c43d7a") if not e.get("fav", false) else Color("4a3a6a"), 22, Vector2(0, 64), "ui_heart")
		fav.pressed.connect(func():
			Profile.toggle_fav(card_id)
			_build_info())
		bh.add_child(fav)
		var vs2: Array = ["" ] + e.get("variants", {}).keys()
		if vs2.size() > 1:
			var vb := UI.button("Variante", Color("2f7bd1"), 22, Vector2(0, 64), "ui_star")
			vb.pressed.connect(func():
				var i := vs2.find(variant)
				variant = vs2[(i + 1) % vs2.size()]
				_load_card())
			bh.add_child(vb)
	if list.size() > 1:
		bh.add_child(UI.expand(UI.spacer()))
		var prev := UI.icon_button("ui_back", 64)
		prev.pressed.connect(func(): _step(-1))
		bh.add_child(prev)
		var nxt := UI.icon_button("ui_play", 64)
		nxt.pressed.connect(func(): _step(1))
		bh.add_child(nxt)
	_info.add_child(bh)
	if c.has("evolve") or _evolves_from() != "":
		var line := ""
		if _evolves_from() != "":
			line = "Évolue depuis : %s" % DB.card(_evolves_from()).name
		if c.has("evolve"):
			line += ("   " if line != "" else "") + "Évolue en : %s (après %d tours en jeu)" % [DB.card(c.evolve.into).name, int(c.evolve.turns)]
		var el := UI.label(line, 20, UI.ACCENT2, "body", 700)
		el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_info.add_child(el)
	var hint := UI.label("Fais glisser la carte pour l'incliner", 18, UI.MUTED, "body", 500, HORIZONTAL_ALIGNMENT_CENTER)
	_info.add_child(hint)

func _evolves_from() -> String:
	for id in DB.cards:
		var c := DB.card(id)
		if c.has("evolve") and c.evolve.into == card_id:
			return id
	return ""

func _step(d: int) -> void:
	var i := list.find(card_id)
	card_id = list[(i + d + list.size()) % list.size()]
	variant = ""
	Sfx.play("flip")
	_load_card()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		var r := Rect2(_disp.position + (_disp.size - DISP) / 2, DISP)
		_drag = e.pressed and r.has_point(e.position)
		if not e.pressed:
			_target = Vector2.ZERO
	elif e is InputEventMouseMotion and _drag:
		var r2 := Rect2(_disp.position + (_disp.size - DISP) / 2, DISP)
		var rel: Vector2 = (e.position - r2.get_center()) / (DISP / 2)
		_target = Vector2(clampf(rel.x, -1, 1), clampf(rel.y, -1, 1))

func _process(delta: float) -> void:
	_t += delta
	var idle := Vector2(sin(_t * 0.8), cos(_t * 0.6)) * 0.18 if not _drag else Vector2.ZERO
	_tilt = _tilt.lerp(_target + idle, min(1.0, delta * 8.0))
	_mat.set_shader_parameter("y_rot", _tilt.x * 22.0)
	_mat.set_shader_parameter("x_rot", -_tilt.y * 22.0)
	if _card:
		_card.set_tilt(_tilt)

func _close() -> void:
	Sfx.play("back")
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.15)
	t.tween_callback(queue_free)
