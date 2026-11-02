extends Control
## Album de collection : filtres, tris, recherche, silhouettes des cartes manquantes, comparaison, recyclage.

var main: Control
var grid: GridContainer
var filt := {"preview": false, "set": "", "element": "", "rarity": "", "family": "", "search": "", "missing": false, "fav": false, "sort": 0}
var compare_mode := false
var compare_pick: Array = []
var _count_label: Label
var _el_buttons := {}
var _cmp_btn: Button
var _shown: Array = []

const SORTS := ["Album", "Rareté", "Puissance", "Coût", "Date d'obtention", "Nom"]

func setup(_p: Dictionary) -> void:
	main = get_meta("main")
	Profile.check_collection_rewards()
	var root := UI.vbox(10)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 18
	root.offset_right = -18
	root.offset_top = 12
	add_child(root)
	# en-tête : progression
	var head := UI.hbox(12)
	var t := UI.label("Album", 40, UI.GOLD, "serif", 800)
	UI.outline(t, 6)
	head.add_child(t)
	var pct := Profile.completion()
	var pl := UI.label("%d / %d cartes · %d %%" % [Profile.unique_count(), DB.card_order.size(), int(round(pct * 100))], 22, UI.TEXT, "body", 700, HORIZONTAL_ALIGNMENT_RIGHT)
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(pl)
	root.add_child(head)
	root.add_child(UI.progress(pct, UI.ACCENT2, 12))
	# éléments
	var er := UI.hbox(4)
	for el in DB.element_order:
		var b := TextureButton.new()
		b.texture_normal = DB.icon("el_" + el)
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(60, 60)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.pressed.connect(func():
			filt.element = "" if filt.element == el else el
			Sfx.play("click")
			_refresh_el()
			rebuild())
		_el_buttons[el] = b
		er.add_child(b)
	root.add_child(er)
	# rareté / famille / tri
	var r2 := UI.hbox(6)
	var ro := _option(["Toutes raretés"] + DB.rarity_order.map(func(r): return DB.rarity(r).name))
	ro.item_selected.connect(func(i): filt.rarity = "" if i == 0 else DB.rarity_order[i - 1]; rebuild())
	r2.add_child(ro)
	var fams: Array = DB.families.keys()
	var fo := _option(["Toutes familles"] + fams.map(func(f): return DB.families[f]))
	fo.item_selected.connect(func(i): filt.family = "" if i == 0 else fams[i - 1]; rebuild())
	r2.add_child(fo)
	var sets: Array = DB.sets.map(func(x): return x.id)
	var seto := _option(["Tous les sets"] + DB.sets.map(func(x): return x.name))
	seto.item_selected.connect(func(i): filt.set = "" if i == 0 else sets[i - 1]; rebuild())
	r2.add_child(seto)
	var so := _option(SORTS.map(func(s): return "Tri : " + s))
	so.item_selected.connect(func(i): filt.sort = i; rebuild())
	r2.add_child(so)
	root.add_child(r2)
	# recherche + bascules
	var r3 := UI.hbox(8)
	var se := LineEdit.new()
	se.placeholder_text = "Rechercher une carte…"
	se.custom_minimum_size = Vector2(0, 60)
	se.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	se.add_theme_font_override("font", UI.font("body", 600))
	se.add_theme_font_size_override("font_size", 22)
	se.add_theme_stylebox_override("normal", _field_style())
	se.add_theme_stylebox_override("focus", _field_style(UI.ACCENT))
	se.text_changed.connect(func(s): filt.search = s.to_lower(); rebuild())
	r3.add_child(se)
	var mb := _toggle("Manquantes", func(on): filt.missing = on; rebuild())
	r3.add_child(mb)
	var fb := _toggle("Favoris", func(on): filt.fav = on; rebuild())
	r3.add_child(fb)
	var pb := _toggle("Aperçu", func(on): filt.preview = on; rebuild())
	r3.add_child(pb)
	root.add_child(r3)
	var r4 := UI.hbox(8)
	_cmp_btn = UI.button("Comparer", Color("2f7bd1"), 20, Vector2(0, 54), "ui_compare")
	_cmp_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cmp_btn.pressed.connect(_toggle_compare)
	r4.add_child(_cmp_btn)
	var rec := UI.button("Doublons", Color("6a3db8"), 20, Vector2(0, 54), "ui_recycle")
	rec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rec.pressed.connect(_recycle)
	r4.add_child(rec)
	var rw := UI.button("Récompenses", Color("b8842a"), 20, Vector2(0, 54), "ui_trophy")
	rw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rw.pressed.connect(_rewards)
	r4.add_child(rw)
	root.add_child(r4)
	_count_label = UI.label("", 18, UI.MUTED, "body", 600)
	root.add_child(_count_label)
	# grille
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 16)
	sc.add_child(grid)
	_refresh_el()
	rebuild()

func _option(items: Array) -> OptionButton:
	var o := OptionButton.new()
	for it in items:
		o.add_item(it)
	o.custom_minimum_size = Vector2(0, 56)
	o.fit_to_longest_item = false
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.focus_mode = Control.FOCUS_NONE
	o.add_theme_font_override("font", UI.font("body", 700))
	o.add_theme_font_size_override("font_size", 18)
	o.add_theme_stylebox_override("normal", _field_style())
	o.add_theme_stylebox_override("hover", _field_style(UI.ACCENT))
	o.add_theme_stylebox_override("pressed", _field_style(UI.ACCENT))
	o.get_popup().add_theme_font_size_override("font_size", 26)
	o.get_popup().add_theme_font_override("font", UI.font("body", 600))
	o.clip_text = true
	return o

func _field_style(border := UI.LINE) -> StyleBoxFlat:
	var s := UI.box(Color(0, 0, 0, 0.45), 14, border, 2)
	s.content_margin_left = 14
	s.content_margin_right = 10
	return s

func _toggle(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.custom_minimum_size.x = 0
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 60)
	b.add_theme_font_override("font", UI.font("body", 700))
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_stylebox_override("normal", _field_style())
	b.add_theme_stylebox_override("hover", _field_style(UI.ACCENT))
	b.add_theme_stylebox_override("pressed", UI.box(Color(UI.ACCENT, 0.45), 14, UI.ACCENT, 2))
	b.add_theme_stylebox_override("hover_pressed", UI.box(Color(UI.ACCENT, 0.45), 14, UI.ACCENT, 2))
	b.toggled.connect(func(on): Sfx.play("click"); cb.call(on))
	return b

func _refresh_el() -> void:
	for el in _el_buttons:
		var b: TextureButton = _el_buttons[el]
		b.modulate = Color.WHITE if filt.element in ["", el] else Color(0.4, 0.4, 0.45)
		b.scale = Vector2.ONE

func _visible_ids() -> Array:
	var out := []
	for id in DB.card_order:
		var c := DB.card(id)
		var owned := Profile.owned(id) > 0
		if filt.set != "" and c.set != filt.set:
			continue
		if filt.element != "" and c.element != filt.element:
			continue
		if filt.rarity != "" and c.rarity != filt.rarity:
			continue
		if filt.family != "" and c.family != filt.family:
			continue
		if filt.missing and owned:
			continue
		if filt.fav and not Profile.entry(id).get("fav", false):
			continue
		if filt.search != "" and ((not owned and not filt.preview) or not (filt.search in c.name.to_lower() or filt.search in DB.ability_text(c).to_lower())):
			continue
		out.append(id)
	match int(filt.sort):
		1: out.sort_custom(func(a, b): return DB.rarity_index(DB.card(a).rarity) > DB.rarity_index(DB.card(b).rarity))
		2: out.sort_custom(func(a, b): return DB.power_of(a) > DB.power_of(b))
		3: out.sort_custom(func(a, b): return int(DB.card(a).cost) < int(DB.card(b).cost))
		4: out.sort_custom(func(a, b): return float(Profile.entry(a).get("first", 0)) > float(Profile.entry(b).get("first", 0)))
		5: out.sort_custom(func(a, b): return DB.card(a).name < DB.card(b).name)
	return out

func rebuild() -> void:
	for c in grid.get_children():
		c.queue_free()
	_shown = _visible_ids()
	var owned_shown := 0
	for id in _shown:
		var owned := Profile.owned(id) > 0
		if owned:
			owned_shown += 1
		var e := Profile.entry(id)
		var cell := UI.vbox(2)
		var is_swap: bool = DB.card(id).rarity == "SW"
		var h := CardView.holder(id, 0.44, _best_variant(e), "face" if owned else ("auto" if is_swap else ("preview" if filt.preview else "missing")))
		var cv: CardView = h.get_meta("card")
		cv.fx_enabled = owned
		cv.tapped.connect(func(_v): _on_tap(id))
		cell.add_child(h)
		var info := UI.hbox(4)
		if owned:
			info.add_child(UI.label("x%d" % int(e.count), 20, UI.TEXT, "num", 400))
			if e.get("fav", false):
				info.add_child(UI.icon_rect("ui_heart", 22, Color("ff6fa8")))
			if not e.get("variants", {}).is_empty():
				info.add_child(UI.icon_rect("ui_star", 22, UI.GOLD))
		elif is_swap:
			info.add_child(UI.icon_rect("ui_puzzle", 22, Color("4dffea")))
			info.add_child(UI.label("%d/9" % Profile.pieces(id).size(), 18, Color("4dffea"), "num", 400))
		else:
			info.add_child(UI.label("Manquante", 18, UI.MUTED, "body", 600))
		info.add_child(UI.expand(UI.spacer()))
		info.add_child(UI.label("#%03d" % (DB.card_order.find(id) + 1), 16, UI.MUTED, "body", 600))
		cell.add_child(info)
		grid.add_child(cell)
	_count_label.text = "%d cartes affichées · %d possédées" % [_shown.size(), owned_shown]

func _best_variant(e: Dictionary) -> String:
	var vs: Dictionary = e.get("variants", {})
	for v in ["secret", "prisma", "animated", "chroma", "alt", "fullart", "holo"]:
		if vs.has(v):
			return v
	return ""

func _on_tap(id: String) -> void:
	Sfx.play("flip")
	if DB.card(id).rarity == "SW" and Profile.owned(id) == 0:
		main.show_card(id, "", [])
		return
	if compare_mode:
		if Profile.owned(id) == 0:
			main.show_toast("Choisis deux cartes que tu possèdes.", "error")
			return
		compare_pick.append(id)
		if compare_pick.size() == 2:
			_show_compare(compare_pick[0], compare_pick[1])
			_toggle_compare()
		else:
			main.show_toast("Choisis la deuxième carte.")
		return
	main.show_card(id, _best_variant(Profile.entry(id)), _shown)

func _toggle_compare() -> void:
	compare_mode = not compare_mode
	compare_pick = []
	_cmp_btn.text = "Annuler" if compare_mode else "Comparer"
	if compare_mode:
		main.show_toast("Mode comparaison : touche deux cartes.")

func _show_compare(a: String, b: String) -> void:
	var v := UI.vbox(12)
	var cards := UI.hbox(16)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	for id in [a, b]:
		cards.add_child(CardView.holder(id, 0.6))
	v.add_child(cards)
	var ca := DB.card(a)
	var cb := DB.card(b)
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 20)
	var rows := [
		["Coût", str(ca.cost), str(cb.cost)],
		["Attaque", str(ca.get("atk", "-")), str(cb.get("atk", "-"))],
		["Points de vie", str(ca.get("hp", "-")), str(cb.get("hp", "-"))],
		["Puissance", str(DB.power_of(a)), str(DB.power_of(b))],
		["Rareté", DB.rarity(ca.rarity).name, DB.rarity(cb.rarity).name],
		["Élément", DB.element_name(ca.element), DB.element_name(cb.element)],
		["Avantage", "x1,5" if DB.is_strong(ca.element, cb.element) else "—", "x1,5" if DB.is_strong(cb.element, ca.element) else "—"],
	]
	for r in rows:
		g.add_child(UI.label(r[0], 22, UI.MUTED, "body", 700))
		for k in [1, 2]:
			g.add_child(UI.label(r[k], 24, UI.TEXT, "num", 400, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(g)
	main.modal("Comparaison", v)

func _recycle() -> void:
	var extra := 0
	var dust := 0
	for id in Profile.d.collection:
		var n := int(Profile.d.collection[id].count) - 3
		if n > 0:
			extra += n
			dust += n * int(DB.rarity(DB.card(id).rarity).dust)
	var body := UI.label("Les exemplaires au-delà de 3 sont transformés en Poussière d'étoile (utile pour les futures évolutions).\n\nDoublons recyclables : %d\nPoussière obtenue : %d" % [extra, dust], 24, UI.TEXT, "body", 600)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if extra == 0:
		main.modal("Doublons", body)
		return
	main.modal("Doublons", body, [["Annuler", Color("4a3a6a"), null], ["Recycler", UI.ACCENT, func():
		var got := Profile.recycle_duplicates()
		main.show_toast("+%d Poussière d'étoile" % got, "reward")
		rebuild()]])

func _rewards() -> void:
	var v := UI.vbox(10)
	var cr: Dictionary = DB.progression.collection_rewards
	for el in DB.element_order:
		var have := 0
		var tot := 0
		for id in DB.card_order:
			if DB.card(id).element == el:
				tot += 1
				if Profile.owned(id) > 0:
					have += 1
		var h := UI.hbox(10)
		h.add_child(UI.icon_rect("el_" + el, 40))
		var nv := UI.vbox(2)
		nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nv.add_child(UI.label("%s  %d/%d" % [DB.element_name(el), have, tot], 20, UI.TEXT, "body", 700))
		nv.add_child(UI.progress(float(have) / max(1, tot), DB.element_color(el), 10))
		h.add_child(nv)
		var done: bool = ("el_" + el) in Profile.d.collection_rewards
		h.add_child(UI.label("Obtenue" if done else "+%d" % int(cr.element.crystals), 20, UI.GOOD if done else UI.GOLD, "body", 800))
		v.add_child(h)
	var s := UI.label("Set Genèse complet : +%d Cristaux et %d Jetons" % [int(cr.set.crystals), int(cr.set.tokens)], 22, UI.GOLD, "body", 800)
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(s)
	main.modal("Récompenses de collection", v)

func refresh() -> void:
	rebuild()
