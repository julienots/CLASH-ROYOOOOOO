class_name CardView extends Control
## Affichage d'une carte (450x630 unités, mis à l'échelle via `scale`).
## Gère : cadre de rareté, illustration, textes, variantes, effets animés, dos, silhouette (manquante).

const W := 450.0
const H := 630.0

signal tapped(view: CardView)

var card_id := ""
var variant := ""
var state := "face"     # face | back | missing
var compact := false    # masque les textes longs (petites tailles)
var serial := 0
var fx_enabled := true
var tilt := Vector2.ZERO
var pieces: Array = []   # état "puzzle" : pièces SWAP possédées (0..8)
var covers := {}         # index -> Panel masquant une pièce manquante

var _fx: ColorRect
var _art: TextureRect
var _back: TextureRect
var _root: Control

static func make(id: String, s := 0.5, var_name := "", st := "face") -> CardView:
	var v := CardView.new()
	if st == "auto":
		st = "face"
		if DB.card(id).rarity == "SW" and Profile.owned(id) == 0:
			st = "puzzle"
			v.pieces = Profile.pieces(id).duplicate()
	v.mouse_filter = Control.MOUSE_FILTER_STOP  # modifiable avant l'ajout à l'arbre (ex. IGNORE)
	v.card_id = id
	v.variant = var_name
	v.state = st
	v.compact = s < 0.42
	v.scale = Vector2(s, s)
	v.size = Vector2(W, H)
	return v

## Conteneur à taille fixe pour placer une carte mise à l'échelle dans une grille.
static func holder(id: String, s := 0.4, var_name := "", st := "face") -> Control:
	var h := Control.new()
	h.custom_minimum_size = Vector2(W, H) * s
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	var v := make(id, s, var_name, st)
	h.add_child(v)
	h.set_meta("card", v)
	return h

func _ready() -> void:
	size = Vector2(W, H)
	build()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		if Rect2(Vector2.ZERO, size).has_point(e.position):
			tapped.emit(self)

func build() -> void:
	for c in get_children():
		c.queue_free()
	_root = Control.new()
	_root.size = size
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var c := DB.card(card_id)
	if c.is_empty():
		return
	var lay: Dictionary = DB.layout
	var sc := float(lay.scale)
	var full := variant in ["fullart", "secret"]
	var rar: String = c.rarity
	var rcol := DB.rarity_color(rar)
	var filt := CanvasItem.TEXTURE_FILTER_NEAREST if scale.x >= 0.7 else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	# illustration
	_art = TextureRect.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.texture_filter = filt
	var tex := DB.card_art(card_id)
	if full:
		_art.texture = tex
		_art.size = size
	else:
		var win: Array = lay.win
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(win[0] * sc, win[1] * sc, (win[2] - win[0]) * sc, (win[3] - win[1]) * sc)
		_art.texture = at
		_art.position = Vector2(win[0], win[1]) * sc
		_art.size = at.region.size
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	var am := ShaderMaterial.new()
	am.shader = load("res://shaders/art_fx.gdshader")
	var amode := 0
	match variant:
		"alt": amode = 1
		"chroma": amode = 2
		"animated": amode = 4
	if rar == "X":
		amode = 5
	if state == "missing":
		amode = 3
	if state == "preview":
		amode = 6
	am.set_shader_parameter("mode", amode)
	am.set_shader_parameter("hue_shift", 0.5 if variant == "alt" else 0.18)
	_art.material = am
	_root.add_child(_art)

	if full:
		# cadre fin pour les Full Art / Secret Art
		var border := Panel.new()
		border.size = size
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		border.add_theme_stylebox_override("panel", UI.box(Color(0, 0, 0, 0), 22, rcol, 9))
		_root.add_child(border)
		var txtbg := Panel.new()
		var tx: Array = lay.text
		txtbg.position = Vector2(tx[0], tx[1] - 34) * sc
		txtbg.size = Vector2(tx[2] - tx[0], tx[3] - tx[1] + 34) * sc
		txtbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		txtbg.add_theme_stylebox_override("panel", UI.box(Color(0.03, 0.02, 0.07, 0.72), 14))
		_root.add_child(txtbg)
		var nbg := Panel.new()
		var nm: Array = lay.name
		nbg.position = Vector2(nm[0] - 6, nm[1]) * sc
		nbg.size = Vector2(nm[2] - nm[0] + 3, nm[3] - nm[1]) * sc
		nbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nbg.add_theme_stylebox_override("panel", UI.box(Color(0.03, 0.02, 0.07, 0.65), 12))
		_root.add_child(nbg)
		for gem in [lay.cost, lay.atk, lay.hp]:
			if gem == lay.cost or c.type == "creature":
				var g := Panel.new()
				var r: float = (gem[2] + 1) * sc
				g.position = Vector2(gem[0] * sc - r, gem[1] * sc - r)
				g.size = Vector2(r, r) * 2
				g.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var col := Color("3a7bff") if gem == lay.cost else (Color("e05a3c") if gem == lay.atk else Color("4cc06e"))
				g.add_theme_stylebox_override("panel", UI.box(col, int(r), Color(1, 1, 1, 0.8), 3))
				_root.add_child(g)
	else:
		var fr := TextureRect.new()
		fr.texture = DB.frame_tex(rar)
		fr.size = size
		fr.texture_filter = filt
		fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(fr)

	var missing := state == "missing"
	if state == "puzzle":
		_build_covers()
	# coût
	var cost := UI.label(str(c.cost) if not missing else "?", 44, Color.WHITE, "num", 400, HORIZONTAL_ALIGNMENT_CENTER)
	UI.outline(cost, 8)
	cost.size = Vector2(70, 60)
	cost.position = Vector2(lay.cost[0] * sc - 35, lay.cost[1] * sc - 31)
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_root.add_child(cost)
	# nom
	var nm2: Array = lay.name
	var name_txt: String = c.name if not missing else "? ? ?"
	var fs := 30
	var nl := UI.label(name_txt, fs, Color("fff7e6"), "serif", 800)
	UI.outline(nl, 5)
	nl.position = Vector2(nm2[0] * sc + 4, nm2[1] * sc)
	nl.size = Vector2((nm2[2] - nm2[0]) * sc - 8, (nm2[3] - nm2[1]) * sc)
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nl.clip_text = true
	UI.fit(nl, nl.size.x - 4, fs, 16)
	_root.add_child(nl)
	# ligne de type
	var tp: Array = lay.type
	var type_txt := "%s · %s" % ["Sort" if c.type == "spell" else DB.family_name(c.family), DB.rarity(rar).name]
	var tl := UI.label(type_txt if not missing else DB.rarity(rar).name, 19, rcol.lightened(0.35), "body", 700)
	UI.outline(tl, 4)
	tl.position = Vector2(tp[0] * sc + 8, tp[1] * sc)
	tl.size = Vector2((tp[2] - tp[0]) * sc - 50, (tp[3] - tp[1]) * sc)
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tl.clip_text = true
	_root.add_child(tl)
	var eli := TextureRect.new()
	eli.texture = DB.icon("el_" + c.element)
	eli.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	eli.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	eli.size = Vector2(40, 40)
	eli.position = Vector2(tp[2] * sc - 44, (tp[1] + tp[3]) * 0.5 * sc - 20)
	eli.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(eli)
	# texte de capacité
	var tx2: Array = lay.text
	if not compact and not missing:
		var rt := UI.rich("", 21, Color("ece6ff"))
		var body := DB.ability_text(c)
		if body != "":
			body += "\n"
		body += "[color=#b3a8d6][i]%s[/i][/color]" % c.get("lore", "")
		rt.text = body
		rt.add_theme_font_size_override("italics_font_size", 18 if body.length() > 170 else 19)
		if body.length() > 230:
			rt.add_theme_font_size_override("normal_font_size", 18)
			rt.add_theme_font_size_override("bold_font_size", 18)
		rt.position = Vector2(tx2[0] * sc + 12, tx2[1] * sc + 8)
		rt.size = Vector2((tx2[2] - tx2[0]) * sc - 24, (tx2[3] - tx2[1]) * sc - 30)
		rt.fit_content = false
		rt.clip_contents = true
		_root.add_child(rt)
	elif missing:
		var q := UI.label("Carte non découverte", 22, UI.MUTED, "body", 600, HORIZONTAL_ALIGNMENT_CENTER)
		q.position = Vector2(tx2[0] * sc, (tx2[1] + tx2[3]) * 0.5 * sc - 20)
		q.size = Vector2((tx2[2] - tx2[0]) * sc, 40)
		_root.add_child(q)
	# statistiques
	if c.type == "creature":
		for pair in [[lay.atk, str(c.atk)], [lay.hp, str(c.hp)]]:
			var l := UI.label(pair[1] if not missing else "?", 46, Color.WHITE, "num", 400, HORIZONTAL_ALIGNMENT_CENTER)
			UI.outline(l, 9)
			l.size = Vector2(80, 64)
			l.position = Vector2(pair[0][0] * sc - 40, pair[0][1] * sc - 33)
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_root.add_child(l)
	else:
		for gem in [lay.atk, lay.hp]:
			var cover := Panel.new()
			var r2: float = (gem[2] + 1) * sc
			cover.position = Vector2(gem[0] * sc - r2, gem[1] * sc - r2)
			cover.size = Vector2(r2, r2) * 2
			cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cover.add_theme_stylebox_override("panel", UI.box(Color("2a1d4f"), int(r2), Color("b48cff"), 3))
			_root.add_child(cover)
			var st := UI.icon_rect("ui_star", 34, Color("d9c2ff"))
			st.position = cover.position + cover.size / 2 - Vector2(17, 17)
			_root.add_child(st)
	# badge de variante / numéro
	if variant != "" and not missing:
		var vb := UI.badge(DB.variants.get(variant, {}).get("name", variant).to_upper(), Color(0.08, 0.05, 0.15, 0.85), 18)
		vb.position = Vector2(W - 210, 82)
		vb.size = Vector2(190, 30)
		vb.add_theme_color_override("font_color", rcol.lightened(0.3))
		_root.add_child(vb)
	if serial > 0 and not missing:
		var sl := UI.label("N° %03d / %d" % [serial, DB.numbered.print_run], 18, Color("fff3c4"), "body", 800, HORIZONTAL_ALIGNMENT_CENTER)
		UI.outline(sl, 5)
		sl.position = Vector2(W / 2 - 100, H - 34)
		sl.size = Vector2(200, 24)
		_root.add_child(sl)
	# effets animés
	_fx = ColorRect.new()
	_fx.size = size
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fm := ShaderMaterial.new()
	fm.shader = load("res://shaders/card_fx.gdshader")
	var fxl := int(DB.rarity(rar).fx)
	var mode: int = [0, 1, 2, 3, 4][fxl]
	match variant:
		"holo": mode = max(mode, 2)
		"prisma": mode = 5
		"secret": mode = 6
		"chroma": mode = max(mode, 3)
	if missing or not fx_enabled or state == "preview":
		mode = 0
	fm.set_shader_parameter("mode", mode)
	fm.set_shader_parameter("tint", rcol)
	fm.set_shader_parameter("intensity", 0.9)
	# particules élémentaires (Rare et plus), cadre animé (Épique et plus)
	var fx_on := fxl >= 1 and not missing and fx_enabled and state != "preview"
	fm.set_shader_parameter("element", DB.element_order.find(c.element) if fx_on else -1)
	fm.set_shader_parameter("elem_color", DB.element_color(c.element))
	fm.set_shader_parameter("fx_level", float(fxl))
	var bord := 0
	if fx_on and fxl >= 2:
		bord = 1
	if fx_on and rar == "P":
		bord = 2
	if fx_on and rar == "SW":
		bord = 3
	fm.set_shader_parameter("border", bord)
	if full:
		fm.set_shader_parameter("win", Vector4(0.03, 0.03, 0.97, 0.6))
	else:
		var wn: Array = lay.win
		fm.set_shader_parameter("win", Vector4(wn[0] * sc / W, wn[1] * sc / H, wn[2] * sc / W, wn[3] * sc / H))
	_fx.material = fm
	_fx.visible = mode > 0 or fx_on
	_root.add_child(_fx)
	# dos de carte
	_back = TextureRect.new()
	_back.texture = DB.tex("res://assets/ui/card_back.png")
	_back.size = size
	_back.texture_filter = filt
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.visible = state == "back"
	var bm := ShaderMaterial.new()
	bm.shader = load("res://shaders/art_fx.gdshader")
	var back_id: String = Profile.d.get("cosmetics", {}).get("back", "back_default")
	bm.set_shader_parameter("mode", 0 if back_id == "back_default" else 1)
	bm.set_shader_parameter("hue_shift", {"back_ember": 0.62, "back_jade": 0.35, "back_gold": 0.83, "back_eclipse": 0.12}.get(back_id, 0.0))
	_back.material = bm
	add_child(_back)

## Masque les pièces manquantes d'une carte SWAP (grille 3x3).
func _build_covers() -> void:
	covers.clear()
	var pw := W / 3.0
	var ph := H / 3.0
	for k in 9:
		if k in pieces:
			continue
		var c := Panel.new()
		c.position = Vector2((k % 3) * pw, (k / 3) * ph)
		c.size = Vector2(pw, ph)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var st := UI.box(Color(0.03, 0.06, 0.09, 0.97), 6, Color(0.3, 1.0, 0.92, 0.55), 2)
		c.add_theme_stylebox_override("panel", st)
		var ic := UI.icon_rect("ui_puzzle", 56, Color(0.3, 1.0, 0.92, 0.35))
		ic.position = c.size / 2 - Vector2(28, 28)
		c.add_child(ic)
		covers[k] = c
	# les caches passent au-dessus de tout le contenu de la carte
	for k in covers:
		_root.add_child.call_deferred(covers[k])
	var pl := UI.label("PIÈCES %d / 9" % pieces.size(), 26, Color("4dffea"), "body", 800, HORIZONTAL_ALIGNMENT_CENTER)
	UI.outline(pl, 6)
	pl.position = Vector2(0, H / 2 - 20)
	pl.size = Vector2(W, 40)
	pl.name = "pieces_label"
	_root.add_child.call_deferred(pl)

## Révèle une pièce (animation d'assemblage).
func reveal_piece(k: int) -> void:
	if not covers.has(k):
		return
	var c: Panel = covers[k]
	covers.erase(k)
	var t := c.create_tween()
	t.tween_property(c, "modulate", Color(3, 3, 3, 1), 0.15)
	t.tween_property(c, "modulate:a", 0.0, 0.35)
	t.tween_callback(c.queue_free)
	var pl := _root.get_node_or_null("pieces_label")
	if pl:
		pl.text = "PIÈCES %d / 9" % (9 - covers.size())
		if covers.is_empty():
			pl.queue_free()

func set_tilt(t: Vector2) -> void:
	tilt = t
	# relief : l'illustration se décale légèrement avec l'inclinaison (Rare et plus)
	if _art and _art.material and int(DB.rarity(DB.card(card_id).get("rarity", "C")).get("fx", 0)) >= 1:
		_art.material.set_shader_parameter("parallax", -t * 0.012)
	if _fx and _fx.material:
		_fx.material.set_shader_parameter("tilt", t)

func show_face(v := true) -> void:
	state = "face" if v else "back"
	if _back:
		_back.visible = not v

## Change le pivot sans déplacer visuellement la carte.
func set_pivot(p: Vector2) -> void:
	position += (pivot_offset - p) * (Vector2.ONE - scale)
	pivot_offset = p

func set_dim(v: bool) -> void:
	modulate = Color(0.45, 0.45, 0.5) if v else Color.WHITE
