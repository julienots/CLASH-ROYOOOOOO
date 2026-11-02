extends Control
## Écran de combat : affiche l'état du BattleEngine, gère le toucher (jouer, cibler, attaquer)
## et anime chaque événement du moteur (invocations, attaques, sorts, morts, évolutions…).

var cfg := {}            # {difficulty, opponent, leader, deck, enemy_deck, enemy_leader, enemy_hp, mode, rewards_mult}
var g: BattleEngine
var ai: BattleAI
var units := {}          # uid -> UnitView
var hand_views := {}     # hid -> CardView
var busy := false
var sel_hid := -1        # carte de la main sélectionnée
var sel_uid := -1        # créature sélectionnée pour attaquer
var targeting := ""      # "" | "play" | "attack"
var valid_targets: Array = []

var board_layer: Control
var fx_layer: Control
var hand_layer: Control
var leader_views := [null, null]
var energy_labels := [null, null]
var enemy_hand_label: Label
var end_btn: Button
var power_btn: Button
var banner: Label
var arrow: Line2D
var preview: Control
var _t := 0.0
var _finished := false

const BOARD_Y := [218.0, 500.0]
const SLOT_W := 138.0
const HAND_S := 0.4

func setup(c: Dictionary) -> void:
	cfg = c

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bgc: Array = cfg.get("board_colors", ["0b0716", "3a1466", "0d4070"])
	var bg := ColorRect.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/menu_bg.gdshader")
	m.set_shader_parameter("c1", Color(bgc[0]))
	m.set_shader_parameter("c2", Color(bgc[1]))
	m.set_shader_parameter("c3", Color(bgc[2]))
	m.set_shader_parameter("res", size)
	bg.material = m
	add_child(bg)
	# terrain
	for i in 2:
		var lane := Panel.new()
		lane.position = Vector2(14, BOARD_Y[i] - 16)
		lane.size = Vector2(size.x - 28, UnitView.SZ.y + 32)
		lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lane.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.04), 26, Color(1, 1, 1, 0.12), 2))
		add_child(lane)
	var mid := ColorRect.new()
	mid.color = Color(1, 1, 1, 0.12)
	mid.position = Vector2(30, 445)
	mid.size = Vector2(size.x - 220, 2)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mid)
	board_layer = Control.new()
	board_layer.size = size
	board_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board_layer)
	_build_leaders()
	hand_layer = Control.new()
	hand_layer.size = size
	hand_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hand_layer)
	end_btn = UI.button("FIN DU TOUR", Color("c98a1e"), 22, Vector2(176, 74))
	end_btn.position = Vector2(size.x - 192, 409)
	end_btn.pressed.connect(_on_end_turn)
	add_child(end_btn)
	arrow = Line2D.new()
	arrow.width = 10
	arrow.default_color = Color(1, 0.4, 0.3, 0.85)
	arrow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	arrow.end_cap_mode = Line2D.LINE_CAP_ROUND
	arrow.z_index = 30
	add_child(arrow)
	fx_layer = Control.new()
	fx_layer.size = size
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx_layer)
	banner = UI.label("", 52, Color.WHITE, "serif", 800, HORIZONTAL_ALIGNMENT_CENTER)
	UI.outline(banner, 12)
	banner.position = Vector2(0, 420)
	banner.size = Vector2(size.x, 80)
	banner.modulate.a = 0
	add_child(banner)
	var quit := UI.icon_button("ui_close", 58, Color.WHITE, Color(0, 0, 0, 0.5))
	quit.position = Vector2(14, 14)
	quit.pressed.connect(_confirm_quit)
	add_child(quit)
	Sfx.music("music_battle")
	_start()

func _build_leaders() -> void:
	for i in 2:
		var ld: Dictionary = DB.leader(cfg.leader if i == 0 else cfg.enemy_leader)
		var root := Control.new()
		root.size = Vector2(140, 140)
		root.position = Vector2(size.x / 2 - 70, 20) if i == 1 else Vector2(size.x / 2 - 70, 690)
		root.mouse_filter = Control.MOUSE_FILTER_STOP
		var ring := Panel.new()
		ring.size = root.size
		ring.add_theme_stylebox_override("panel", UI.box(UI.PANEL2, 70, DB.element_color(ld.element), 5, 10))
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(ring)
		var clip := Panel.new()
		clip.position = Vector2(8, 8)
		clip.size = root.size - Vector2(16, 16)
		clip.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		clip.add_theme_stylebox_override("panel", UI.box(Color.WHITE, 62))
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(clip)
		var art := TextureRect.new()
		var at := AtlasTexture.new()
		at.atlas = DB.card_art(ld.art)
		at.region = Rect2(90, 60, 270, 270)
		art.texture = at
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.size = clip.size
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.add_child(art)
		var hpbg := Panel.new()
		hpbg.size = Vector2(76, 52)
		hpbg.position = Vector2(root.size.x - 50, root.size.y - 50)
		hpbg.add_theme_stylebox_override("panel", UI.box(Color("b8283c"), 22, Color.WHITE, 3))
		hpbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(hpbg)
		var hp := UI.label("25", 32, Color.WHITE, "num", 400, HORIZONTAL_ALIGNMENT_CENTER)
		UI.outline(hp, 6)
		hp.size = hpbg.size
		hp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hp.name = "hp"
		hpbg.add_child(hp)
		var tg := Panel.new()
		tg.name = "target"
		tg.position = Vector2(-8, -8)
		tg.size = root.size + Vector2(16, 16)
		tg.add_theme_stylebox_override("panel", UI.box(Color(1, 0.3, 0.3, 0.2), 78, Color(1, 0.35, 0.3), 6))
		tg.visible = false
		tg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(tg)
		var nm := UI.label(ld.name.split(",")[0], 20, UI.TEXT, "body", 800, HORIZONTAL_ALIGNMENT_CENTER)
		UI.outline(nm, 5)
		nm.position = Vector2(-60, root.size.y - 6) if i == 0 else Vector2(-60, root.size.y - 2)
		nm.size = Vector2(root.size.x + 120, 28)
		root.add_child(nm)
		var idx := i
		root.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
				_on_leader_tap(idx))
		add_child(root)
		leader_views[i] = root
		# énergie
		var en := UI.label("", 34, Color("8fd8ff"), "num", 400)
		UI.outline(en, 6)
		en.position = Vector2(130, 30) if i == 1 else Vector2(80, 742)
		en.size = Vector2(150, 44)
		en.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(en)
		var eic := UI.icon_rect("ui_energy", 44, Color("8fd8ff"))
		eic.position = en.position - Vector2(48, 0)
		add_child(eic)
		var el := UI.label("ÉNERGIE", 15, Color("8fd8ff"), "body", 800)
		el.position = en.position + Vector2(-46, 42)
		add_child(el)
		energy_labels[i] = en
	enemy_hand_label = UI.label("", 22, UI.MUTED, "body", 700, HORIZONTAL_ALIGNMENT_RIGHT)
	enemy_hand_label.position = Vector2(size.x - 250, 40)
	enemy_hand_label.size = Vector2(230, 30)
	add_child(enemy_hand_label)
	var me: Dictionary = DB.leader(cfg.leader)
	power_btn = UI.button("%s (%d)" % [me.power.name, int(me.power.cost)], Color("6a3db8"), 19, Vector2(190, 66), "ui_star")
	power_btn.position = Vector2(size.x - 210, 730)
	power_btn.pressed.connect(_on_power)
	add_child(power_btn)
	var pd := UI.label(me.power.desc, 15, UI.MUTED, "body", 600, HORIZONTAL_ALIGNMENT_CENTER)
	pd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pd.position = Vector2(size.x - 220, 800)
	pd.size = Vector2(210, 40)
	add_child(pd)

# ======================================================================= déroulement
func _start() -> void:
	g = BattleEngine.new()
	ai = BattleAI.new(int(cfg.get("difficulty", 1)))
	g.setup(cfg.deck, cfg.leader, cfg.enemy_deck, cfg.enemy_leader, 0, int(cfg.get("enemy_hp", 0)))
	busy = true
	_sync(true)
	await _wait(0.3)
	await _show_banner("COMBAT !", UI.GOLD)
	await _play(g.take_events())
	busy = false
	_after_action()

func _after_action() -> void:
	_sync()
	if g.winner >= 0:
		_end_battle()
		return
	if g.current == 1:
		_ai_turn()

func _ai_turn() -> void:
	busy = true
	await _wait(0.6)
	var guard := 0
	while g.winner < 0 and g.current == 1 and guard < 60:
		guard += 1
		var a := ai.next_action(g)
		match a.type:
			"play":
				var h := g.find_hand(1, a.hid)
				g.play(1, a.hid, a.target)
				if not h.is_empty():
					await _show_enemy_card(h.id)
			"attack":
				g.attack(a.uid, a.target)
			"power":
				g.use_power(1)
			"end":
				g.end_turn()
		await _play(g.take_events())
		_sync()
		await _wait(0.35 if not _fast() else 0.12)
	if guard >= 60 and g.winner < 0 and g.current == 1:
		g.end_turn()
		await _play(g.take_events())
	busy = false
	_after_action()

func _fast() -> bool:
	return Profile.d.settings.get("fast", false)

func _wait(t: float) -> void:
	await get_tree().create_timer(t * (0.5 if _fast() else 1.0)).timeout

# ======================================================================= synchronisation de l'affichage
func _slot_pos(p: int, i: int, n: int) -> Vector2:
	var total := n * SLOT_W
	var x0 := (size.x - total) / 2 + (SLOT_W - UnitView.SZ.x) / 2
	return Vector2(x0 + i * SLOT_W, BOARD_Y[0] if p == 1 else BOARD_Y[1])

func _sync(instant := false) -> void:
	# créatures
	var alive := {}
	for p in 2:
		var board: Array = g.pl[p].board
		for i in board.size():
			var u: Dictionary = board[i]
			alive[int(u.uid)] = true
			var v: UnitView = units.get(int(u.uid))
			if v == null:
				v = _make_unit(u)
				v.position = _slot_pos(p, i, board.size())
			v.refresh(u)
			var target := _slot_pos(p, i, board.size())
			if instant:
				v.position = target
			elif v.position.distance_to(target) > 1:
				v.create_tween().tween_property(v, "position", target, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			v.set_ready(p == 0 and g.current == 0 and g.can_attack(int(u.uid)) and not busy)
	for uid in units.keys():
		if not alive.has(uid):
			var v: UnitView = units[uid]
			units.erase(uid)
			if is_instance_valid(v):
				v.queue_free()
	# leaders et énergie
	for p in 2:
		var L: Dictionary = g.pl[p].leader
		(leader_views[p].find_child("hp", true, false) as Label).text = str(maxi(0, int(L.hp)))
		energy_labels[p].text = "%d / %d" % [g.pl[p].energy, g.pl[p].max_energy]
	enemy_hand_label.text = "Main : %d · Deck : %d" % [g.pl[1].hand.size(), g.pl[1].deck.size()]
	power_btn.disabled = not g.can_use_power(0) or busy
	end_btn.disabled = g.current != 0 or busy or g.winner >= 0
	_sync_hand(instant)
	_update_end_glow()

func _make_unit(u: Dictionary) -> UnitView:
	var old: UnitView = units.get(int(u.uid))
	if old and is_instance_valid(old):
		old.queue_free()
	var v := UnitView.new()
	v.setup(u)
	v.tapped.connect(_on_unit_tap)
	board_layer.add_child(v)
	units[int(u.uid)] = v
	return v

func _hand_pos(i: int, n: int) -> Vector2:
	var cw := CardView.W * HAND_S
	var span := minf(size.x - 60 - cw, (n - 1) * (cw + 8))
	var step := span / maxi(1, n - 1)
	var x0 := (size.x - (span + cw)) / 2
	var mid := (n - 1) / 2.0
	return Vector2(x0 + i * step, size.y - CardView.H * HAND_S - 18 + absf(i - mid) * absf(i - mid) * 4)

func _sync_hand(instant := false) -> void:
	var hand: Array = g.pl[0].hand
	var present := {}
	for i in hand.size():
		var h: Dictionary = hand[i]
		present[int(h.hid)] = true
		var cv: CardView = hand_views.get(int(h.hid))
		if cv == null:
			cv = CardView.make(h.id, HAND_S)
			cv.compact = true
			cv.fx_enabled = false
			var hid := int(h.hid)
			cv.tapped.connect(func(_c): _on_hand_tap(hid))
			hand_layer.add_child(cv)
			hand_views[hid] = cv
			cv.position = Vector2(size.x + 40, 1100)
		var n := hand.size()
		var target := _hand_pos(i, n)
		var rot := (i - (n - 1) / 2.0) * 0.05
		if int(h.hid) == sel_hid:
			target.y -= 60
		cv.z_index = i
		var playable := g.current == 0 and g.can_play(0, int(h.hid)) == "" and not busy
		cv.modulate = Color.WHITE if playable or g.current != 0 else Color(0.62, 0.6, 0.68)
		if instant:
			cv.position = target
			cv.rotation = rot
		else:
			var t := cv.create_tween().set_parallel(true)
			t.tween_property(cv, "position", target, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			t.tween_property(cv, "rotation", rot, 0.3)
	for hid in hand_views.keys():
		if not present.has(hid):
			var cv: CardView = hand_views[hid]
			hand_views.erase(hid)
			if is_instance_valid(cv) and not cv.has_meta("flying"):
				cv.queue_free()

func _update_end_glow() -> void:
	if g.current != 0 or busy:
		end_btn.modulate = Color.WHITE
		return
	var moves := false
	for h in g.pl[0].hand:
		if g.can_play(0, int(h.hid)) == "":
			moves = true
	for u in g.pl[0].board:
		if g.can_attack(int(u.uid)):
			moves = true
	end_btn.modulate = Color(1.25, 1.25, 1.0) if not moves else Color.WHITE

# ======================================================================= entrées joueur
func _on_hand_tap(hid: int) -> void:
	if busy or g.current != 0 or _finished:
		return
	if targeting != "":
		_cancel_target()
	if sel_hid == hid:
		_try_play(hid)
		return
	sel_hid = hid
	sel_uid = -1
	Sfx.play("flip", 1.2)
	_show_preview(g.find_hand(0, hid).id)
	_sync_hand()

func _show_preview(id: String) -> void:
	_clear_preview()
	preview = Control.new()
	preview.size = size
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(preview)
	var cv := CardView.make(id, 0.62)
	cv.position = Vector2(size.x / 2 - CardView.W * 0.31, 250)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(cv)
	cv.modulate.a = 0
	cv.position.y += 40
	var pt := cv.create_tween().set_parallel(true)
	pt.tween_property(cv, "modulate:a", 1.0, 0.15)
	pt.tween_property(cv, "position:y", cv.position.y - 40, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var why := g.can_play(0, sel_hid)
	var b := UI.button("JOUER" if why == "" else why, UI.GOOD.darkened(0.15) if why == "" else Color("4a3a6a"), 26, Vector2(300, 80))
	b.position = Vector2(size.x / 2 - 150, 250 + CardView.H * 0.62 + 14)
	b.disabled = why != ""
	b.pressed.connect(func(): _try_play(sel_hid))
	preview.add_child(b)

func _clear_preview() -> void:
	if preview:
		preview.queue_free()
		preview = null

func _try_play(hid: int) -> void:
	var h := g.find_hand(0, hid)
	if h.is_empty():
		return
	var why := g.can_play(0, hid)
	if why != "":
		get_tree().root.get_node("Main").show_toast(why, "error")
		return
	var tt := g.needs_target(h.id)
	if tt != "":
		var opts := g.targets_for(0, tt)
		if not opts.is_empty():
			_clear_preview()
			targeting = "play"
			_set_targets(opts)
			_show_banner_small("Choisis une cible")
			return
		elif DB.card(h.id).type == "spell":
			return
	_do_play(hid, null)

func _do_play(hid: int, target) -> void:
	_clear_preview()
	_clear_targets()
	busy = true
	sel_hid = -1
	var h := g.find_hand(0, hid)
	var cv: CardView = hand_views.get(hid)
	g.play(0, hid, target)
	if cv:
		cv.set_meta("flying", true)
		hand_views.erase(hid)
		if DB.rarity_index(DB.card(h.id).rarity) >= DB.rarity_index("SR"):
			cv.visible = false
			await _splash(h.id)
		await _fly_card(cv, DB.card(h.id))
	await _play(g.take_events())
	busy = false
	_after_action()

func _fly_card(cv: CardView, c: Dictionary) -> void:
	cv.z_index = 40
	var dest := Vector2(size.x / 2 - CardView.W * 0.2, BOARD_Y[1] - 20)
	if c.type == "spell":
		dest = Vector2(size.x / 2 - CardView.W * 0.25, 320)
	var t := cv.create_tween().set_parallel(true)
	t.tween_property(cv, "position", dest, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(cv, "rotation", 0.0, 0.2)
	t.tween_property(cv, "scale", Vector2(0.5, 0.5) if c.type == "spell" else Vector2(0.4, 0.4), 0.28)
	await t.finished
	if c.type == "spell":
		Sfx.play("spell")
		UI.burst(fx_layer, cv.position + Vector2(CardView.W, CardView.H) * 0.25, DB.element_color(c.element), 40, 500)
		await _wait(0.25)
	var t2 := cv.create_tween().set_parallel(true)
	t2.tween_property(cv, "modulate:a", 0.0, 0.2)
	t2.tween_property(cv, "scale", cv.scale * 1.2, 0.2)
	await t2.finished
	cv.queue_free()

## Entrée spectaculaire des cartes Super Rares et plus : rayons, éclats, titre, tremblement.
func _splash(id: String) -> void:
	var c := DB.card(id)
	var ri := DB.rarity_index(c.rarity)
	var col := DB.rarity_color(c.rarity)
	var ecol := DB.element_color(c.element)
	var big := ri >= DB.rarity_index("L")
	var root := Control.new()
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(root)
	var dimr := ColorRect.new()
	dimr.color = Color(0, 0, 0, 0)
	dimr.size = size
	dimr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dimr)
	var rays := UI.glow_rect(Color(col, 0.85), Vector2(1100, 1100), 1.3, 18.0 if big else 12.0)
	rays.position = size / 2 - Vector2(550, 600)
	rays.pivot_offset = Vector2(550, 550)
	root.add_child(rays)
	var cv := CardView.make(id, 0.66)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.position = size / 2 - Vector2(CardView.W, CardView.H) * 0.33 - Vector2(0, 50)
	cv.set_pivot(Vector2(CardView.W, CardView.H) / 2)
	cv.scale = Vector2(0.15, 0.15)
	cv.rotation = -0.5
	root.add_child(cv)
	var title := UI.label("SWAP !" if c.rarity == "SW" else (DB.rarity(c.rarity).name.to_upper() + " !"), 52 if big else 40, col.lightened(0.25), "serif", 800, HORIZONTAL_ALIGNMENT_CENTER)
	UI.outline(title, 12)
	title.position = Vector2(0, 150)
	title.size = Vector2(size.x, 70)
	title.modulate.a = 0
	root.add_child(title)
	Sfx.play("reveal_4" if big else "reveal_3")
	var t := root.create_tween().set_parallel(true)
	t.tween_property(dimr, "color:a", 0.6 if big else 0.4, 0.2)
	t.tween_property(cv, "scale", Vector2(0.66, 0.66), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(cv, "rotation", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(title, "modulate:a", 1.0, 0.25).set_delay(0.2)
	t.tween_property(rays, "rotation", 0.6, 1.6)
	await get_tree().create_timer(0.35).timeout
	UI.burst(root, size / 2 - Vector2(0, 50), ecol, 60 if big else 40, 650, 0.7, 1.0, 0)
	UI.burst(root, size / 2 - Vector2(0, 50), col, 40, 500, 0.5, 1.2, -100)
	if big:
		_flash(Color(col, 0.5), 0.5)
		UI.shake(self, 14, 0.5)
	var hold := 0.0
	while hold < (1.2 if big else 0.8) * (0.5 if _fast() else 1.0):
		cv.set_tilt(Vector2(sin(hold * 4.0), cos(hold * 3.0)) * 0.8)
		await get_tree().process_frame
		hold += get_process_delta_time()
	var t2 := root.create_tween().set_parallel(true)
	t2.tween_property(root, "modulate:a", 0.0, 0.25)
	t2.tween_property(cv, "scale", Vector2(0.3, 0.3), 0.25)
	await t2.finished
	root.queue_free()

func _show_enemy_card(id: String) -> void:
	if DB.rarity_index(DB.card(id).rarity) >= DB.rarity_index("SR"):
		await _splash(id)
		return
	var cv := CardView.make(id, 0.5)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.position = Vector2(size.x / 2 - CardView.W * 0.25, -200)
	fx_layer.add_child(cv)
	var t := cv.create_tween()
	t.tween_property(cv, "position:y", 300.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.7 if not _fast() else 0.3)
	t.tween_property(cv, "modulate:a", 0.0, 0.2)
	t.tween_callback(cv.queue_free)
	Sfx.play("flip")
	await _wait(0.9)

func _on_unit_tap(v: UnitView) -> void:
	if _finished:
		return
	if targeting != "":
		var ref := {"k": "unit", "uid": v.uid}
		if _is_valid(ref):
			_confirm_target(ref)
		else:
			_cancel_target()
		return
	if busy:
		return
	var u := g.find_unit(v.uid)
	if u.is_empty():
		return
	if int(u.owner) == 0 and g.current == 0 and g.can_attack(v.uid):
		_clear_preview()
		sel_hid = -1
		_sync_hand()
		sel_uid = v.uid
		targeting = "attack"
		_set_targets(g.attack_targets(v.uid))
		Sfx.play("click")
		v.create_tween().tween_property(v, "scale", Vector2(1.1, 1.1), 0.1)
	else:
		get_tree().root.get_node("Main").show_card(u.id)

func _on_leader_tap(p: int) -> void:
	if targeting != "":
		var ref := {"k": "leader", "p": p}
		if _is_valid(ref):
			_confirm_target(ref)
		else:
			_cancel_target()

func _is_valid(ref: Dictionary) -> bool:
	for t in valid_targets:
		if t.k == ref.k and t.get("uid", -1) == ref.get("uid", -1) and t.get("p", -1) == ref.get("p", -1):
			return true
	return false

func _set_targets(opts: Array) -> void:
	valid_targets = opts
	for t in opts:
		if t.k == "unit" and units.has(int(t.uid)):
			units[int(t.uid)].set_target(true)
		elif t.k == "leader":
			leader_views[t.p].get_node("target").visible = true

func _clear_targets() -> void:
	for v in units.values():
		v.set_target(false)
	for lv in leader_views:
		lv.get_node("target").visible = false
	valid_targets = []
	arrow.clear_points()

func _cancel_target() -> void:
	_clear_targets()
	if sel_uid >= 0 and units.has(sel_uid):
		units[sel_uid].create_tween().tween_property(units[sel_uid], "scale", Vector2.ONE, 0.1)
	targeting = ""
	sel_uid = -1
	sel_hid = -1
	_sync_hand()

func _confirm_target(ref: Dictionary) -> void:
	var mode := targeting
	targeting = ""
	_clear_targets()
	if mode == "play":
		_do_play(sel_hid, ref)
	elif mode == "attack":
		var uid := sel_uid
		sel_uid = -1
		if units.has(uid):
			units[uid].scale = Vector2.ONE
		busy = true
		g.attack(uid, ref)
		await _play(g.take_events())
		busy = false
		_after_action()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		if targeting != "":
			_cancel_target()
		elif sel_hid >= 0:
			sel_hid = -1
			_clear_preview()
			_sync_hand()
	elif e is InputEventMouseMotion and targeting == "attack" and units.has(sel_uid):
		arrow.clear_points()
		arrow.add_point(units[sel_uid].center())
		arrow.add_point(e.position)

func _on_end_turn() -> void:
	if busy or g.current != 0:
		return
	_cancel_target()
	_clear_preview()
	busy = true
	g.end_turn()
	await _play(g.take_events())
	busy = false
	_after_action()

func _on_power() -> void:
	if busy or not g.can_use_power(0):
		return
	busy = true
	g.use_power(0)
	await _play(g.take_events())
	busy = false
	_after_action()

# ======================================================================= animations d'événements
func _ref_pos(r: Dictionary) -> Vector2:
	if r.k == "leader":
		return leader_views[r.p].position + leader_views[r.p].size / 2
	var v: UnitView = units.get(int(r.uid))
	return v.position + UnitView.SZ / 2 if v else size / 2

func _play(evs: Array) -> void:
	for e in evs:
		if not is_inside_tree():
			return
		await _anim(e)

var anim_seen := {}

func _anim(e: Dictionary) -> void:
	anim_seen[e.t] = int(anim_seen.get(e.t, 0)) + 1
	match e.t:
		"turn":
			_sync()
			if e.turn > 1 or e.p == 0:
				Sfx.play("turn")
				await _show_banner("À TOI DE JOUER" if e.p == 0 else "TOUR ADVERSE", UI.GOLD if e.p == 0 else Color("ff8a7a"))
		"draw":
			if e.p == 0:
				Sfx.play("flip", 1.1)
				_sync_hand()
				await _wait(0.12)
		"burn":
			if e.p == 0:
				get_tree().root.get_node("Main").show_toast("Main pleine : %s est détruite." % DB.card(e.id).name, "error")
		"fatigue":
			UI.float_text(fx_layer, _ref_pos({"k": "leader", "p": e.p}) - Vector2(0, 60), "Deck vide !", UI.BAD, 30)
		"summon":
			var u: Dictionary = e.unit
			var v: UnitView = units.get(int(u.uid))
			if v == null:
				v = _make_unit(u)
			var n: int = g.pl[e.p].board.size()
			var slot := int(e.slot)
			v.position = _slot_pos(e.p, min(slot, max(0, n - 1)), max(n, slot + 1))
			v.scale = Vector2(1.6, 1.6)
			v.modulate.a = 0
			var t := v.create_tween().set_parallel(true)
			t.tween_property(v, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_property(v, "modulate:a", 1.0, 0.15)
			Sfx.play("summon")
			var c := DB.card(u.id)
			UI.burst(fx_layer, v.position + UnitView.SZ / 2, DB.element_color(c.element), 30 + DB.rarity_index(c.rarity) * 4, 350, 0.5, 0.7, 100)
			if DB.rarity_index(c.rarity) >= DB.rarity_index("L"):
				UI.shake(self, 8, 0.3)
			await _wait(0.32)
			_sync()
		"attack":
			var v2: UnitView = units.get(int(e.uid))
			if v2:
				var from := v2.position
				var to := _ref_pos(e.target) - UnitView.SZ / 2
				var mid := from.lerp(to, 0.78)
				v2.z_index = 20
				var t2 := v2.create_tween()
				t2.tween_property(v2, "position", from + (from - to).normalized() * 16, 0.1)
				t2.tween_property(v2, "position", mid, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				await t2.finished
				Sfx.play("hit_big" if int(g.find_unit(e.uid).get("atk", 0)) >= 5 else "hit")
				UI.burst(fx_layer, mid + UnitView.SZ / 2, Color(1, 0.8, 0.5), 20, 300, 0.4, 0.5, 0)
				var t3 := v2.create_tween()
				t3.tween_property(v2, "position", from, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				t3.tween_callback(func(): v2.z_index = 0)
		"damage":
			var pos := _ref_pos(e.target)
			UI.float_text(fx_layer, pos, "-%d" % int(e.amount), Color("ff5a5a") if not e.get("adv", false) else Color("ffb340"), 50 if not e.get("adv", false) else 60)
			if e.get("adv", false):
				UI.float_text(fx_layer, pos - Vector2(0, 50), "SUPER EFFICACE", Color("ffcf5a"), 22)
			if e.target.k == "leader":
				UI.shake(leader_views[e.target.p], 10, 0.3)
				(leader_views[e.target.p].find_child("hp", true, false) as Label).text = str(maxi(0, int(e.hp)))
				if int(e.amount) >= 5:
					UI.shake(self, 8, 0.25)
			else:
				var v3: UnitView = units.get(int(e.target.uid))
				if v3:
					v3.modulate = Color(2, 0.6, 0.6)
					v3.create_tween().tween_property(v3, "modulate", Color.WHITE, 0.25)
					UI.shake(v3, 6, 0.2)
					var d := v3.data.duplicate(true)
					d.hp = e.hp
					v3.refresh(d)
			await _wait(0.18)
		"heal":
			UI.float_text(fx_layer, _ref_pos(e.target), "+%d" % int(e.amount), UI.GOOD, 46)
			if e.target.k == "leader":
				(leader_views[e.target.p].find_child("hp", true, false) as Label).text = str(e.hp)
			await _wait(0.12)
		"shield":
			Sfx.play("shield")
			if units.has(int(e.uid)):
				var vv: UnitView = units[int(e.uid)]
				var d2 := vv.data.duplicate(true)
				if e.on:
					d2.kw["bouclier"] = true
				else:
					d2.kw.erase("bouclier")
					UI.float_text(fx_layer, vv.position + UnitView.SZ / 2, "Bloqué !", UI.GOLD, 30)
				vv.refresh(d2)
			await _wait(0.12)
		"freeze":
			Sfx.play("freeze")
			if units.has(int(e.uid)):
				UI.burst(fx_layer, units[int(e.uid)].position + UnitView.SZ / 2, Color(0.6, 0.9, 1.0), 24, 250, 0.4, 0.6, 0)
				var d3: Dictionary = units[int(e.uid)].data.duplicate(true)
				d3.frozen = 1
				units[int(e.uid)].refresh(d3)
			await _wait(0.12)
		"buff":
			if units.has(int(e.uid)):
				var vb: UnitView = units[int(e.uid)]
				UI.float_text(fx_layer, vb.position + UnitView.SZ / 2 - Vector2(0, 40), "Rage !" if e.get("rage", false) else "Renforcé", UI.GOLD, 26)
				var d4 := vb.data.duplicate(true)
				d4.atk = e.atk
				d4.hp = e.hp
				d4.max_hp = e.max_hp
				vb.refresh(d4)
			await _wait(0.1)
		"poison":
			if units.has(int(e.uid)):
				UI.float_text(fx_layer, units[int(e.uid)].position + UnitView.SZ / 2, "Poison", Color("8dff6a"), 30)
		"sleep":
			Sfx.play("heal", 0.7)
			if units.has(int(e.uid)):
				var vz: UnitView = units[int(e.uid)]
				UI.float_text(fx_layer, vz.position + UnitView.SZ / 2, "Endormie", Color("c9b3ff"), 30)
				UI.burst(fx_layer, vz.position + UnitView.SZ / 2, Color("c9b3ff"), 24, 200, 0.4, 0.8, -120)
				var dz := vz.data.duplicate(true)
				dz.frozen = 2
				vz.refresh(dz)
			await _wait(0.15)
		"silence":
			Sfx.play("shield", 0.6)
			if units.has(int(e.uid)):
				var vs: UnitView = units[int(e.uid)]
				UI.float_text(fx_layer, vs.position + UnitView.SZ / 2, "Silence", Color("d0c8e8"), 30)
				vs.refresh(e.unit)
			await _wait(0.2)
		"bounce":
			var vbn: UnitView = units.get(int(e.uid))
			if vbn:
				units.erase(int(e.uid))
				Sfx.play("whoosh")
				var tb := vbn.create_tween().set_parallel(true)
				tb.tween_property(vbn, "position:y", -200.0 if e.p == 1 else size.y, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
				tb.tween_property(vbn, "modulate:a", 0.0, 0.35)
				tb.chain().tween_callback(vbn.queue_free)
				UI.float_text(fx_layer, vbn.position + UnitView.SZ / 2, "Renvoyée !", Color("9fd8ff"), 30)
				await _wait(0.35)
			_sync()
		"steal":
			var vst: UnitView = units.get(int(e.uid))
			if vst:
				UI.float_text(fx_layer, vst.position + UnitView.SZ / 2, "Contrôle volé !", Color("4dffea"), 30)
				UI.burst(fx_layer, vst.position + UnitView.SZ / 2, Color("4dffea"), 40, 400)
			Sfx.play("evolve")
			await _wait(0.4)
			_sync()
		"swap":
			if units.has(int(e.uid)):
				var vw: UnitView = units[int(e.uid)]
				UI.float_text(fx_layer, vw.position + UnitView.SZ / 2, "SWAP", Color("4dffea"), 30)
				vw.refresh(e.unit)
			Sfx.play("shield", 1.4)
			await _wait(0.15)
		"swap_leaders":
			Sfx.play("rift")
			_flash(Color(0.3, 1.0, 0.9, 0.5), 0.7)
			UI.shake(self, 12, 0.6)
			for p2 in 2:
				UI.float_text(fx_layer, _ref_pos({"k": "leader", "p": p2}) - Vector2(0, 70), "PV ÉCHANGÉS", Color("4dffea"), 30)
			await _wait(0.6)
			_sync()
		"energy":
			Sfx.play("coin")
			UI.float_text(fx_layer, _ref_pos({"k": "leader", "p": e.p}) - Vector2(0, 80), "+%d énergie" % int(e.amount), Color("8fd8ff"), 30)
			_sync()
		"destroy":
			if units.has(int(e.uid)):
				UI.burst(fx_layer, units[int(e.uid)].position + UnitView.SZ / 2, Color(0.7, 0.3, 1.0), 40, 400)
		"death":
			var vd: UnitView = units.get(int(e.uid))
			if vd:
				units.erase(int(e.uid))
				Sfx.play("death")
				UI.burst(fx_layer, vd.position + UnitView.SZ / 2, DB.element_color(DB.card(e.id).element), 36, 380, 0.55, 0.8, -100)
				var t4 := vd.create_tween().set_parallel(true)
				t4.tween_property(vd, "scale", Vector2(0.2, 0.2), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
				t4.tween_property(vd, "modulate:a", 0.0, 0.3)
				t4.chain().tween_callback(vd.queue_free)
				await _wait(0.25)
		"evolve":
			var ve: UnitView = units.get(int(e.uid))
			if ve:
				Sfx.play("evolve")
				var t5 := ve.create_tween()
				t5.tween_property(ve, "modulate", Color(3, 3, 3), 0.35)
				t5.tween_callback(func(): ve.refresh(e.unit))
				t5.tween_property(ve, "scale", Vector2(1.35, 1.35), 0.15)
				t5.tween_property(ve, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				t5.parallel().tween_property(ve, "modulate", Color.WHITE, 0.4)
				UI.burst(fx_layer, ve.position + UnitView.SZ / 2, Color(1, 1, 0.8), 60, 500, 0.7, 1.0, -50)
				UI.float_text(fx_layer, ve.position + UnitView.SZ / 2 - Vector2(0, 70), "ÉVOLUTION !", UI.GOLD, 32)
				await _wait(0.9)
		"fx":
			await _effect_fx(e)
		"spell":
			pass
		"power":
			Sfx.play("spell")
			UI.burst(fx_layer, _ref_pos({"k": "leader", "p": e.p}), Color(0.8, 0.6, 1.0), 40, 400)
			await _wait(0.2)
		"win":
			pass

func _effect_fx(e: Dictionary) -> void:
	var col := DB.element_color(e.get("element", "lumiere"))
	var src := _ref_pos(e.src)
	match e.kind:
		"damage":
			Sfx.play("fire" if e.get("element", "") == "feu" else "spell")
			for t in e.targets:
				_projectile(src, _ref_pos(t), col)
			await _wait(0.3)
		"heal":
			Sfx.play("heal")
			for t in e.targets:
				UI.burst(fx_layer, _ref_pos(t), UI.GOOD, 24, 200, 0.45, 0.8, -150)
			await _wait(0.15)
		"trample":
			Sfx.play("hit_big")
			UI.shake(self, 8, 0.25)
			for t in e.targets:
				UI.float_text(fx_layer, _ref_pos(t) - Vector2(0, 60), "Piétinement !", Color("ffb340"), 28)
			await _wait(0.15)
		"freeze", "sleep", "shield", "buff", "silence", "bounce", "steal", "swap_stats":
			for t in e.targets:
				UI.burst(fx_layer, _ref_pos(t), col, 18, 200, 0.4, 0.6, -80)
			await _wait(0.1)
		"destroy":
			Sfx.play("rift")
			_flash(Color(0.5, 0.2, 0.9, 0.5), 0.6)
			UI.shake(self, 12, 0.5)
			await _wait(0.4)

func _projectile(from: Vector2, to: Vector2, col: Color) -> void:
	var p := CPUParticles2D.new()
	p.texture = UI.dot_tex()
	p.amount = 30
	p.lifetime = 0.35
	p.local_coords = false
	p.spread = 30
	p.initial_velocity_min = 10
	p.initial_velocity_max = 60
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.8
	var gr := Gradient.new()
	gr.set_color(0, col.lightened(0.6))
	gr.set_color(1, Color(col, 0))
	p.color_ramp = gr
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	p.position = from
	fx_layer.add_child(p)
	var t := p.create_tween()
	t.tween_property(p, "position", to, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		UI.burst(fx_layer, to, col, 26, 320, 0.55, 0.5, 0)
		p.emitting = false)
	t.tween_interval(0.4)
	t.tween_callback(p.queue_free)

func _flash(c: Color, dur: float) -> void:
	var f := ColorRect.new()
	f.color = c
	f.size = size
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(f)
	var t := f.create_tween()
	t.tween_property(f, "color:a", 0.0, dur)
	t.tween_callback(f.queue_free)

func _show_banner(text: String, col: Color) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", col)
	banner.pivot_offset = banner.size / 2
	banner.scale = Vector2(0.6, 0.6)
	var t := banner.create_tween()
	t.set_parallel(true)
	t.tween_property(banner, "modulate:a", 1.0, 0.15)
	t.tween_property(banner, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_interval(0.55 if not _fast() else 0.25)
	t.chain().tween_property(banner, "modulate:a", 0.0, 0.2)
	await t.finished

func _show_banner_small(text: String) -> void:
	UI.float_text(fx_layer, Vector2(size.x / 2, 470), text, Color.WHITE, 30)

func _process(delta: float) -> void:
	_t += delta
	for v in units.values():
		if v._ready_glow.visible:
			v._ready_glow.modulate.a = 0.55 + sin(_t * 5) * 0.45
		if v._target_glow.visible:
			v._target_glow.modulate.a = 0.55 + sin(_t * 7) * 0.45
	for lv in leader_views:
		if lv:
			var tg: Control = lv.get_node("target")
			if tg.visible:
				tg.modulate.a = 0.55 + sin(_t * 7) * 0.45

# ======================================================================= fin de partie
func _end_battle() -> void:
	if _finished:
		return
	_finished = true
	busy = true
	var won := g.winner == 0
	var rew: Dictionary = (DB.progression.battle_rewards.win if won else DB.progression.battle_rewards.loss).duplicate()
	var mult := float(cfg.get("rewards_mult", 1.0))
	for k in rew:
		rew[k] = int(round(int(rew[k]) * mult))
	if not cfg.get("event", false):
		rew.erase("event")
	# statistiques et missions
	Profile.stat("battles_played")
	if won:
		Profile.stat("battles_won")
		Profile.d.rank.points = int(Profile.d.rank.get("points", 0)) + 12
	for k in g.stats:
		if int(g.stats[k]) > 0:
			Profile.stat(k, int(g.stats[k]))
	Profile.give(rew, true)
	Profile.save_game()
	Sfx.play("victory" if won else "defeat")
	await _wait(0.6)
	var root := Control.new()
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dimr := ColorRect.new()
	dimr.color = Color(0, 0, 0, 0.75)
	dimr.size = size
	root.add_child(dimr)
	var col := UI.GOLD if won else Color("ff6a7a")
	var glow := UI.glow_rect(Color(col, 0.6), Vector2(900, 900), 1.4, 16.0 if won else 0.0)
	glow.position = size / 2 - Vector2(450, 600)
	root.add_child(glow)
	var t := UI.label("VICTOIRE !" if won else "DÉFAITE", 84, col, "title", 700, HORIZONTAL_ALIGNMENT_CENTER)
	UI.outline(t, 16)
	t.position = Vector2(0, 260)
	t.size = Vector2(size.x, 120)
	root.add_child(t)
	var v := UI.vbox(14)
	v.position = Vector2(80, 440)
	v.size = Vector2(size.x - 160, 0)
	v.add_child(UI.label("Tours joués : %d" % g.turn, 26, UI.TEXT, "body", 700, HORIZONTAL_ALIGNMENT_CENTER))
	for k in rew:
		var h := UI.hbox(10)
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		var icn := {"coins": "coin", "xp": "ui_star", "event": "event", "dust": "dust"}.get(k, "coin")
		h.add_child(UI.icon_rect(icn, 54, UI.GOLD if k == "xp" else Color.WHITE))
		var amount := UI.label("+%d %s" % [int(rew[k]), "XP" if k == "xp" else Profile.cur_name(k, int(rew[k]))], 36, Color.WHITE, "num", 400)
		UI.outline(amount, 6)
		h.add_child(amount)
		v.add_child(h)
	root.add_child(v)
	var b := UI.button("Continuer", UI.ACCENT, 30, Vector2(360, 96), "ui_check")
	b.position = Vector2(size.x / 2 - 180, 900)
	b.pressed.connect(func():
		Sfx.music("music_menu")
		queue_free())
	root.add_child(b)
	add_child(root)
	UI.pop_in(t, 0.0, 0.3)
	UI.pop_in(v, 0.3)
	UI.pop_in(b, 0.6)
	if won:
		for i in 4:
			UI.burst(root, Vector2(randf_range(100, size.x - 100), randf_range(200, 500)), Color.from_hsv(randf(), 0.6, 1), 50, 600, 0.7, 1.4, 400)
			await _wait(0.25)

## Mode test : l'IA joue aussi pour le joueur, via les mêmes fonctions que les entrées tactiles.
func autoplay_step() -> void:
	if busy or _finished or g.current != 0:
		return
	var a := BattleAI.new(2).next_action(g)
	match a.type:
		"play":
			sel_hid = int(a.hid)
			var tt := g.needs_target(g.find_hand(0, a.hid).id)
			if tt != "" and a.target != null:
				targeting = "play"
				_set_targets(g.targets_for(0, tt))
				_confirm_target(a.target)
			else:
				_do_play(int(a.hid), a.target)
		"attack":
			sel_uid = int(a.uid)
			targeting = "attack"
			_set_targets(g.attack_targets(a.uid))
			_confirm_target(a.target)
		"power":
			_on_power()
		"end":
			_on_end_turn()

func _confirm_quit() -> void:
	if _finished:
		queue_free()
		return
	var main = get_tree().root.get_node("Main")
	var l := UI.label("Abandonner compte comme une défaite.", 24, UI.TEXT, "body", 600, HORIZONTAL_ALIGNMENT_CENTER)
	main.modal("Abandonner ?", l, [["Rester", UI.ACCENT, null], ["Abandonner", Color("b8283c"), func():
		g.pl[0].leader.hp = 0
		g._check_winner()
		_end_battle()]])
