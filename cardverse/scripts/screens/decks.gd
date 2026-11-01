extends Control
## Decks : liste, deck actif, éditeur (leader, cartes, remplissage automatique, validation 20 cartes).

var main: Control
var editing := -1
var root: VBoxContainer
var _filter_el := ""

func setup(p: Dictionary) -> void:
	main = get_meta("main")
	editing = int(p.get("edit", -1))
	root = UI.vbox(12)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 18
	root.offset_right = -18
	root.offset_top = 12
	add_child(root)
	_build()

func refresh() -> void:
	_build()

func _clear() -> void:
	for c in root.get_children():
		c.queue_free()

func _build() -> void:
	_clear()
	if editing >= 0 and editing < Profile.d.decks.size():
		_editor()
	else:
		_list()

func _list() -> void:
	var t := UI.label("Decks", 40, UI.GOLD, "serif", 800)
	UI.outline(t, 6)
	root.add_child(t)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	var v := UI.vbox(14)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	for i in Profile.d.decks.size():
		var deck: Dictionary = Profile.d.decks[i]
		var active: bool = i == int(Profile.d.active_deck)
		var ld := DB.leader(deck.leader)
		var p := UI.panel(Color(0.1, 0.06, 0.2, 0.9), 22, UI.GOLD if active else UI.LINE, 3 if active else 2)
		var h := UI.hbox(12)
		h.add_child(UI.icon_rect("el_" + ld.element, 64))
		var dv := UI.vbox(2)
		dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dv.add_child(UI.label(deck.name, 26, Color.WHITE, "body", 800))
		var ok := Profile.deck_valid(deck)
		dv.add_child(UI.label("%s · %d/%d%s" % [ld.name.split(",")[0], deck.cards.size(), Profile.DECK_SIZE, "" if ok else " · incomplet"], 18, UI.MUTED if ok else UI.BAD, "body", 600))
		if active:
			dv.add_child(UI.label("DECK ACTIF", 16, UI.GOLD, "body", 800))
		h.add_child(dv)
		if not active:
			var ab := UI.button("Activer", UI.GOOD.darkened(0.25), 20, Vector2(0, 62))
			var idx: int = i
			ab.pressed.connect(func():
				Profile.d.active_deck = idx
				Profile.save_game()
				_build())
			h.add_child(ab)
		var eb := UI.button("Modifier", UI.ACCENT, 20, Vector2(0, 62), "ui_deck")
		var idx2: int = i
		eb.pressed.connect(func():
			editing = idx2
			_build())
		h.add_child(eb)
		p.add_child(h)
		v.add_child(p)
	if Profile.d.decks.size() < 6:
		var nb := UI.button("Nouveau deck", Color("1e9e8a"), 26, Vector2(0, 86), "ui_deck")
		nb.pressed.connect(func():
			Profile.d.decks.append({"name": "Deck %d" % (Profile.d.decks.size() + 1), "leader": "pyra", "cards": []})
			Profile.save_game()
			editing = Profile.d.decks.size() - 1
			_build())
		v.add_child(nb)
	var rules := UI.label("Règles : %d cartes exactement · 2 exemplaires maximum (1 pour les Légendaires et au-delà). Le leader apporte 25 PV et un pouvoir utilisable une fois par tour." % Profile.DECK_SIZE, 18, UI.MUTED, "body", 600)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(rules)

func _editor() -> void:
	var deck: Dictionary = Profile.d.decks[editing]
	var top := UI.hbox(10)
	var back := UI.icon_button("ui_back", 64)
	back.pressed.connect(func():
		Profile.save_game()
		editing = -1
		_build())
	top.add_child(back)
	var name_e := LineEdit.new()
	name_e.text = deck.name
	name_e.max_length = 24
	name_e.custom_minimum_size = Vector2(0, 64)
	name_e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_e.add_theme_font_override("font", UI.font("body", 800))
	name_e.add_theme_font_size_override("font_size", 26)
	name_e.add_theme_stylebox_override("normal", UI.box(Color(0, 0, 0, 0.4), 14, UI.LINE, 2))
	name_e.text_changed.connect(func(s): deck.name = s if s.strip_edges() != "" else "Deck")
	top.add_child(name_e)
	var count := UI.label("%d/%d" % [deck.cards.size(), Profile.DECK_SIZE], 30, UI.GOOD if deck.cards.size() == Profile.DECK_SIZE else UI.GOLD, "num", 400)
	top.add_child(count)
	root.add_child(top)
	# leader
	var lh := UI.hbox(8)
	for ld in DB.leaders:
		var on: bool = deck.leader == ld.id
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 92)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("normal", UI.box(Color(DB.element_color(ld.element), 0.35 if on else 0.1), 16, DB.element_color(ld.element) if on else UI.LINE, 3 if on else 1))
		b.add_theme_stylebox_override("hover", UI.box(Color(DB.element_color(ld.element), 0.3), 16, DB.element_color(ld.element), 2))
		b.add_theme_stylebox_override("pressed", UI.box(Color(DB.element_color(ld.element), 0.4), 16, DB.element_color(ld.element), 2))
		var bv := UI.vbox(0)
		bv.set_anchors_preset(Control.PRESET_FULL_RECT)
		bv.alignment = BoxContainer.ALIGNMENT_CENTER
		bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := UI.icon_rect("el_" + ld.element, 40)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bv.add_child(ic)
		bv.add_child(UI.label(ld.name.split(",")[0], 17, Color.WHITE, "body", 800, HORIZONTAL_ALIGNMENT_CENTER))
		b.add_child(bv)
		var lid: String = ld.id
		b.pressed.connect(func():
			Sfx.play("click")
			deck.leader = lid
			_build())
		lh.add_child(b)
	root.add_child(lh)
	var ldd := DB.leader(deck.leader)
	var pw := UI.label("Pouvoir — %s (%d) : %s" % [ldd.power.name, int(ldd.power.cost), ldd.power.desc], 18, UI.ACCENT2, "body", 700)
	pw.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(pw)
	# actions
	var ah := UI.hbox(8)
	var auto := UI.button("Remplir auto", Color("1e9e8a"), 20, Vector2(0, 60), "ui_star")
	auto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto.pressed.connect(func(): _autofill(deck); _build())
	ah.add_child(auto)
	var clr := UI.button("Vider", Color("6a2a3a"), 20, Vector2(0, 60), "ui_close")
	clr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clr.pressed.connect(func(): deck.cards.clear(); Profile.save_game(); _build())
	ah.add_child(clr)
	root.add_child(ah)
	# contenu du deck (barres compactes)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	var v := UI.vbox(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	v.add_child(UI.label("Dans le deck (touche pour retirer)", 20, UI.MUTED, "body", 700))
	var ids: Array = []
	for id in deck.cards:
		if not id in ids:
			ids.append(id)
	ids.sort_custom(func(a, b): return int(DB.card(a).cost) < int(DB.card(b).cost) or (int(DB.card(a).cost) == int(DB.card(b).cost) and a < b))
	var curve := {}
	for id in deck.cards:
		var cst := mini(7, int(DB.card(id).cost))
		curve[cst] = int(curve.get(cst, 0)) + 1
	v.add_child(_curve(curve))
	for id in ids:
		v.add_child(_deck_row(deck, id))
	v.add_child(UI.spacer(10))
	v.add_child(UI.label("Ta collection (touche pour ajouter)", 20, UI.MUTED, "body", 700))
	var er := UI.hbox(2)
	for el in [""] + DB.element_order:
		var b := TextureButton.new()
		b.texture_normal = DB.icon("el_" + el) if el != "" else DB.icon("ui_album")
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(56, 56)
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.modulate = Color.WHITE if _filter_el == el else Color(0.45, 0.45, 0.5)
		var ee: String = el
		b.pressed.connect(func(): _filter_el = ee; _build())
		er.add_child(b)
	v.add_child(er)
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	for id in DB.card_order:
		if Profile.owned(id) == 0:
			continue
		if _filter_el != "" and DB.card(id).element != _filter_el:
			continue
		var cell := UI.vbox(2)
		var hld := CardView.holder(id, 0.33)
		var cv: CardView = hld.get_meta("card")
		cv.fx_enabled = false
		var in_deck := Profile.deck_count(deck, id)
		var left := mini(Profile.owned(id), Profile.deck_max(id)) - in_deck
		if left <= 0:
			cv.set_dim(true)
		var cid: String = id
		cv.tapped.connect(func(_c):
			var why := Profile.can_add_to_deck(deck, cid)
			if why != "":
				main.show_toast(why, "error")
				return
			deck.cards.append(cid)
			Sfx.play("pop")
			Profile.save_game()
			_build())
		cell.add_child(hld)
		cell.add_child(UI.label("%d / %d" % [in_deck, mini(Profile.owned(id), Profile.deck_max(id))], 18, UI.TEXT, "num", 400, HORIZONTAL_ALIGNMENT_CENTER))
		g.add_child(cell)
	v.add_child(g)

func _deck_row(deck: Dictionary, id: String) -> Control:
	var c := DB.card(id)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 58)
	var col := DB.rarity_color(c.rarity)
	b.add_theme_stylebox_override("normal", UI.box(Color(col, 0.16), 14, col, 2))
	b.add_theme_stylebox_override("hover", UI.box(Color(col, 0.26), 14, col, 2))
	b.add_theme_stylebox_override("pressed", UI.box(Color(col, 0.35), 14, col, 2))
	var h := UI.hbox(10)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 10
	h.offset_right = -14
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cost := UI.badge(str(c.cost), Color("2f5fd0"), 22)
	cost.custom_minimum_size = Vector2(44, 0)
	cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(cost)
	h.add_child(UI.icon_rect("el_" + c.element, 34))
	var nl := UI.label(c.name, 21, Color.WHITE, "body", 700)
	nl.clip_text = true
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(nl)
	if c.type == "creature":
		h.add_child(UI.label("%d/%d" % [int(c.atk), int(c.hp)], 20, UI.MUTED, "num", 400))
	h.add_child(UI.label("x%d" % Profile.deck_count(deck, id), 24, UI.GOLD, "num", 400))
	b.add_child(h)
	b.pressed.connect(func():
		deck.cards.erase(id)
		Sfx.play("back")
		Profile.save_game()
		_build())
	return b

func _curve(curve: Dictionary) -> Control:
	var h := UI.hbox(6)
	h.custom_minimum_size = Vector2(0, 90)
	var mx := 1
	for k in curve:
		mx = maxi(mx, int(curve[k]))
	for cst in range(0, 8):
		var v := UI.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.alignment = BoxContainer.ALIGNMENT_END
		var n := int(curve.get(cst, 0))
		var bar := ColorRect.new()
		bar.color = UI.ACCENT2 if n > 0 else Color(1, 1, 1, 0.08)
		bar.custom_minimum_size = Vector2(0, 6 + 54.0 * n / mx)
		v.add_child(bar)
		v.add_child(UI.label(("%d+" % cst) if cst == 7 else str(cst), 16, UI.MUTED, "num", 400, HORIZONTAL_ALIGNMENT_CENTER))
		h.add_child(v)
	return h

## Complète le deck avec les meilleures cartes possédées, en privilégiant l'élément du leader.
func _autofill(deck: Dictionary) -> void:
	var el: String = DB.leader(deck.leader).element
	var pool := []
	for id in Profile.d.collection:
		if DB.card(id).is_empty():
			continue
		pool.append(id)
	pool.sort_custom(func(a, b):
		var sa := DB.power_of(a) + (8 if DB.card(a).element == el else 0) - absi(int(DB.card(a).cost) - 3)
		var sb := DB.power_of(b) + (8 if DB.card(b).element == el else 0) - absi(int(DB.card(b).cost) - 3)
		return sa > sb)
	var guard := 0
	while deck.cards.size() < Profile.DECK_SIZE and guard < 5:
		guard += 1
		for id in pool:
			if deck.cards.size() >= Profile.DECK_SIZE:
				break
			if Profile.can_add_to_deck(deck, id) == "":
				deck.cards.append(id)
	Profile.save_game()
	if deck.cards.size() < Profile.DECK_SIZE:
		main.show_toast("Pas assez de cartes : ouvre des boosters !", "error")
