extends Control
## Coffret : couvercle qui saute, carte promo garantie qui se révèle, jetons et boosters qui jaillissent.
## Le contenu est crédité dès l'ouverture de l'écran (rien n'est perdu si l'application se ferme).

var pd := {}
var phase := "closed"
var box: Control
var lid: Panel
var hint: Label
var _t := 0.0
var _promo_new := false
var _busy := false

func setup(p: Dictionary) -> void:
	pd = p

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_grant()
	var col := Color(pd.color)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/menu_bg.gdshader")
	m.set_shader_parameter("c1", Color(0.03, 0.02, 0.06))
	m.set_shader_parameter("c2", col.darkened(0.6))
	m.set_shader_parameter("c3", col.darkened(0.45))
	m.set_shader_parameter("res", size)
	bg.material = m
	add_child(bg)
	var title := UI.label(pd.name, 40, Color.WHITE, "serif", 800, HORIZONTAL_ALIGNMENT_CENTER)
	UI.outline(title, 10)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.position = Vector2(20, 60)
	title.size = Vector2(size.x - 40, 100)
	title.name = "title"
	add_child(title)
	# le coffret
	box = Control.new()
	box.size = Vector2(520, 420)
	box.position = Vector2(size.x / 2 - 260, 520)
	box.pivot_offset = box.size / 2
	add_child(box)
	var base := Panel.new()
	base.position = Vector2(0, 90)
	base.size = Vector2(520, 330)
	base.add_theme_stylebox_override("panel", UI.box(col.darkened(0.25), 22, col.lightened(0.4), 5, 16))
	box.add_child(base)
	var art := TextureRect.new()
	var at := AtlasTexture.new()
	at.atlas = DB.card_art(pd.promo.card)
	at.region = Rect2(60, 70, 330, 280)
	art.texture = at
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.position = Vector2(150, 120)
	art.size = Vector2(220, 186)
	box.add_child(art)
	var frame := Panel.new()
	frame.position = art.position - Vector2(6, 6)
	frame.size = art.size + Vector2(12, 12)
	frame.add_theme_stylebox_override("panel", UI.box(Color(0, 0, 0, 0), 10, UI.GOLD, 5))
	box.add_child(frame)
	var ribbon2 := ColorRect.new()
	ribbon2.color = UI.GOLD
	ribbon2.position = Vector2(280, 90)
	ribbon2.size = Vector2(40, 330)
	ribbon2.name = "ribbon2"
	box.add_child(ribbon2)
	var name_l := UI.label("CARDVERSE", 30, Color("fff2d0"), "title", 700, HORIZONTAL_ALIGNMENT_CENTER)
	UI.outline(name_l, 8, Color("2a0d4a"))
	name_l.position = Vector2(0, 330)
	name_l.size = Vector2(520, 50)
	box.add_child(name_l)
	lid = Panel.new()
	lid.size = Vector2(560, 110)
	lid.position = Vector2(-20, 0)
	lid.pivot_offset = Vector2(280, 55)
	lid.add_theme_stylebox_override("panel", UI.box(col.lightened(0.05), 22, col.lightened(0.55), 5, 10))
	box.add_child(lid)
	var ribbon := ColorRect.new()
	ribbon.color = UI.GOLD
	ribbon.position = Vector2(260, 0)
	ribbon.size = Vector2(40, 110)
	lid.add_child(ribbon)
	var bow := UI.icon_rect("ui_gift", 90, UI.GOLD)
	bow.position = Vector2(235, -60)
	lid.add_child(bow)
	_ignore_input(box)
	hint = UI.label("Touche le coffret pour l'ouvrir", 26, UI.TEXT, "body", 800, HORIZONTAL_ALIGNMENT_CENTER)
	UI.outline(hint, 6)
	hint.position = Vector2(0, size.y - 260)
	hint.size = Vector2(size.x, 40)
	add_child(hint)
	var content := UI.label(_content_text(), 19, UI.MUTED, "body", 600, HORIZONTAL_ALIGNMENT_CENTER)
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.position = Vector2(40, 180)
	content.size = Vector2(size.x - 80, 60)
	content.name = "content"
	add_child(content)
	Sfx.play("whoosh")
	box.position.y = -500
	create_tween().tween_property(box, "position:y", 520.0, 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _content_text() -> String:
	var n := 0
	for k in pd.boosters:
		n += int(pd.boosters[k])
	return "Contenu : carte promo %s (%s) · %d boosters · %d jetons spéciaux" % [DB.card(pd.promo.card).name, DB.variants[pd.promo.variant].name, n, int(pd.tokens)]

func _grant() -> void:
	_promo_new = Profile.add_card(pd.promo.card, pd.promo.variant)
	for k in pd.boosters:
		Profile.add_free(k, int(pd.boosters[k]))
	Profile.d.tokens = Profile.get_cur("tokens") + int(pd.tokens)
	Profile.stat("boxes_opened")
	Profile.check_collection_rewards()
	Profile.save_game()

func _process(delta: float) -> void:
	_t += delta
	if phase == "closed" and box:
		box.rotation = sin(_t * 2.2) * 0.02
		box.scale = Vector2.ONE * (1.0 + sin(_t * 3.0) * 0.01)

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and phase == "closed" and not _busy:
		_open()

func _open() -> void:
	_busy = true
	phase = "opening"
	hint.text = ""
	get_node("content").visible = false
	# anticipation : le coffret tremble trois fois
	for i in 3:
		Sfx.play("tear_tick", 0.8 + i * 0.2)
		var t := box.create_tween()
		t.tween_property(box, "rotation", 0.08, 0.05)
		t.tween_property(box, "rotation", -0.08, 0.08)
		t.tween_property(box, "rotation", 0.0, 0.05)
		await t.finished
		await get_tree().create_timer(0.15).timeout
	# le couvercle saute
	Sfx.play("tear")
	box.get_node("ribbon2").visible = false
	var tl := lid.create_tween().set_parallel(true)
	tl.tween_property(lid, "position", lid.position + Vector2(260, -1300), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tl.tween_property(lid, "rotation", 1.8, 0.8)
	tl.tween_property(lid, "modulate:a", 0.0, 0.8)
	tl.tween_property(get_node("title"), "modulate:a", 0.0, 0.4)
	var col := Color(pd.color)
	var rays := UI.glow_rect(Color(col.lightened(0.3), 0.9), Vector2(1200, 1200), 1.2, 16.0)
	rays.position = box.position + Vector2(260, 100) - Vector2(600, 600)
	rays.pivot_offset = Vector2(600, 600)
	add_child(rays)
	move_child(rays, box.get_index())
	rays.create_tween().tween_property(rays, "rotation", 3.0, 8.0)
	_flash(Color.WHITE, 0.6)
	Sfx.play("flash")
	UI.burst(self, box.position + Vector2(260, 90), col.lightened(0.4), 90, 800, 0.8, 1.3, 200)
	UI.shake(self, 10, 0.4)
	await get_tree().create_timer(0.6).timeout
	# la carte promo jaillit et se retourne
	var c := DB.card(pd.promo.card)
	var rc := DB.rarity_color(c.rarity)
	var cv := CardView.make(pd.promo.card, 0.62, pd.promo.variant, "back")
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.position = Vector2(size.x / 2 - CardView.W * 0.31, box.position.y + 60)
	cv.set_pivot(Vector2(CardView.W, CardView.H) / 2)
	add_child(cv)
	var tc := cv.create_tween()
	tc.tween_property(cv, "position:y", 150.0, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("whoosh")
	await tc.finished
	await get_tree().create_timer(0.3).timeout
	var tf := cv.create_tween()
	tf.tween_property(cv, "scale:x", 0.0, 0.14)
	await tf.finished
	cv.show_face(true)
	var tf2 := cv.create_tween()
	tf2.tween_property(cv, "scale:x", 0.62, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("reveal_4" if DB.rarity_index(c.rarity) >= DB.rarity_index("L") else "reveal_3")
	UI.burst(self, cv.position + Vector2(CardView.W, CardView.H) * 0.5, rc, 70, 650, 0.7, 1.2, 0)
	UI.aura_particles(cv, Rect2(Vector2.ZERO, Vector2(CardView.W, CardView.H)), rc, 30)
	var pl := UI.label("CARTE PROMO EXCLUSIVE · %s%s" % [DB.variants[pd.promo.variant].name.to_upper(), " · NOUVELLE" if _promo_new else ""], 22, UI.GOLD, "body", 800, HORIZONTAL_ALIGNMENT_CENTER)
	UI.outline(pl, 6)
	pl.position = Vector2(0, 100)
	pl.size = Vector2(size.x, 40)
	add_child(pl)
	var hold := 0.0
	while hold < 1.2:
		cv.set_tilt(Vector2(sin(hold * 3.0), cos(hold * 2.0)) * 0.7)
		await get_tree().process_frame
		hold += get_process_delta_time()
	# jetons
	var y0 := box.position.y + 40
	var row := UI.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.position = Vector2(0, 960)
	row.size = Vector2(size.x, 70)
	add_child(row)
	for i in int(pd.tokens):
		var ic := UI.icon_rect("token", 60)
		row.add_child(ic)
		ic.modulate.a = 0
		ic.create_tween().tween_property(ic, "modulate:a", 1.0, 0.2)
		Sfx.play("coin", 1.0 + i * 0.1)
		await get_tree().create_timer(0.18).timeout
	var tlbl := UI.label("+%d jetons spéciaux" % int(pd.tokens), 26, Color("e6b3ff"), "num", 400)
	UI.outline(tlbl, 6)
	row.add_child(tlbl)
	# boosters
	var packs := []
	for k in pd.boosters:
		for i in int(pd.boosters[k]):
			packs.append(k)
	var n := packs.size()
	var w := minf(96.0, (size.x - 60) / n)
	for i in n:
		var t := TextureRect.new()
		t.texture = DB.tex("res://assets/ui/packs/%s.png" % packs[i])
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.size = Vector2(80, 124)
		t.position = Vector2(size.x / 2 - 40, y0 + 100)
		add_child(t)
		var dest := Vector2(30 + i * w + (w - 80) / 2.0 + (size.x - 60 - n * w) / 2.0, 820)
		var tp := t.create_tween().set_parallel(true)
		tp.tween_property(t, "position", dest, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tp.tween_property(t, "rotation", (i - n / 2.0) * 0.03, 0.45)
		Sfx.play("pop", 0.9 + i * 0.05)
		await get_tree().create_timer(0.12).timeout
	var create := UI.label("%d boosters ajoutés à ta réserve (Boutique > Boosters, bouton GRATUIT)" % n, 19, UI.TEXT, "body", 700, HORIZONTAL_ALIGNMENT_CENTER)
	create.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	create.position = Vector2(30, 1040)
	create.size = Vector2(size.x - 60, 50)
	add_child(create)
	var bh := UI.hbox(14)
	bh.position = Vector2(30, size.y - 130)
	bh.size = Vector2(size.x - 60, 92)
	var see := UI.button("Voir la carte", Color("2f7bd1"), 22, Vector2(0, 88), "ui_eye")
	see.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	see.pressed.connect(func(): get_tree().root.get_node("Main").show_card(pd.promo.card, pd.promo.variant))
	bh.add_child(see)
	var go := UI.button("Ouvrir les boosters", UI.GOOD.darkened(0.2), 22, Vector2(0, 88), "ui_gift")
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.pressed.connect(func():
		var main = get_tree().root.get_node("Main")
		queue_free()
		main.goto("shop", {"tab": "boosters"}))
	bh.add_child(go)
	add_child(bh)
	var close := UI.icon_button("ui_close", 70)
	close.position = Vector2(size.x - 92, 20)
	close.pressed.connect(func():
		Sfx.play("back")
		queue_free())
	add_child(close)
	phase = "done"
	_busy = false

func _flash(c: Color, dur: float) -> void:
	var f := ColorRect.new()
	f.color = c
	f.size = size
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(f)
	var t := f.create_tween()
	t.tween_property(f, "color:a", 0.0, dur)
	t.tween_callback(f.queue_free)

func _close() -> void:
	Sfx.play("back")
	queue_free()

## Les éléments décoratifs ne doivent pas intercepter le toucher (sinon le coffret ne s'ouvre pas).
func _ignore_input(n: Node) -> void:
	if n is Control:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_input(c)
