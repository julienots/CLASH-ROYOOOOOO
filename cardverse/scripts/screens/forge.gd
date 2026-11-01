extends Control
## Atelier : évolutions de collection, transformations secrètes, fabrication de cartes et variantes (Poussière d'étoile).

var main: Control
var tab := "evolve"
var body: VBoxContainer
var _tabs := {}
var _dust: Label

func setup(p: Dictionary) -> void:
	main = get_meta("main")
	tab = p.get("tab", "evolve")
	var root := UI.vbox(12)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 18
	root.offset_right = -18
	root.offset_top = 12
	add_child(root)
	var head := UI.hbox(10)
	var t := UI.label("Atelier", 40, UI.GOLD, "serif", 800)
	UI.outline(t, 6)
	head.add_child(UI.expand(t))
	head.add_child(UI.icon_rect("dust", 46))
	_dust = UI.label("", 30, Color.WHITE, "num", 400)
	_dust.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_dust)
	root.add_child(head)
	var th := UI.hbox(6)
	for td in [["evolve", "Évolutions"], ["secret", "Secrets"], ["craft", "Créer"], ["variant", "Variantes"]]:
		var b := Button.new()
		b.text = td[1]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 58)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_override("font", UI.font("body", 800))
		b.add_theme_font_size_override("font_size", 20)
		var k: String = td[0]
		b.pressed.connect(func(): Sfx.play("click"); tab = k; _build())
		_tabs[k] = b
		th.add_child(b)
	root.add_child(th)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	body = UI.vbox(14)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(body)
	_build()

func refresh() -> void:
	_build()

func _build() -> void:
	_dust.text = str(Profile.get_cur("dust"))
	for k in _tabs:
		var on: bool = k == tab
		_tabs[k].add_theme_stylebox_override("normal", UI.box(Color(UI.ACCENT, 0.55) if on else Color(0, 0, 0, 0.4), 16, UI.ACCENT if on else UI.LINE, 2))
		_tabs[k].add_theme_stylebox_override("hover", UI.box(Color(UI.ACCENT, 0.4), 16, UI.ACCENT, 2))
		_tabs[k].add_theme_stylebox_override("pressed", UI.box(Color(UI.ACCENT, 0.6), 16, UI.ACCENT, 2))
	for c in body.get_children():
		c.queue_free()
	match tab:
		"evolve": _evolutions()
		"secret": _secrets()
		"craft": _craft()
		"variant": _variants()

func _note(t: String) -> void:
	var l := UI.label(t, 18, UI.MUTED, "body", 600)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(l)

func _mini(id: String, st := "face") -> Control:
	var h := CardView.holder(id, 0.3, "", st)
	var cv: CardView = h.get_meta("card")
	cv.fx_enabled = st == "face"
	cv.tapped.connect(func(_c): main.show_card(id))
	return h

func _arrow() -> Control:
	var l := UI.label(">", 46, UI.GOLD, "num", 400, HORIZONTAL_ALIGNMENT_CENTER)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l

# ---------------------------------------------------------------- évolutions
func _evolutions() -> void:
	_note("Fusionne 3 exemplaires d'une créature avec de la Poussière d'étoile pour obtenir sa forme évoluée, avec une nouvelle illustration et de nouvelles capacités.")
	for r in DB.forge.evolutions:
		var have := Profile.owned(r.from)
		var ok: bool = have >= int(r.count) and Profile.get_cur("dust") >= int(r.dust)
		var p := UI.panel(Color(0.1, 0.06, 0.2, 0.9), 22, UI.GOLD if ok else UI.LINE, 3 if ok else 2)
		var v := UI.vbox(10)
		var h := UI.hbox(10)
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(_mini(r.from, "face" if Profile.discovered(r.from) else "missing"))
		h.add_child(_arrow())
		h.add_child(_mini(r.to, "face" if Profile.discovered(r.to) else "missing"))
		v.add_child(h)
		var info := UI.label("%s x%d (tu en as %d) + %d Poussière" % [DB.card(r.from).name, int(r.count), have, int(r.dust)], 20, UI.TEXT, "body", 700, HORIZONTAL_ALIGNMENT_CENTER)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(info)
		var b := UI.button("Faire évoluer", UI.GOOD.darkened(0.2) if ok else Color("3a3350"), 24, Vector2(0, 72), "ui_star")
		b.disabled = not ok
		b.pressed.connect(func(): _do_evolve(r.from, int(r.count), int(r.dust), r.to))
		v.add_child(b)
		p.add_child(v)
		body.add_child(p)

func _do_evolve(from: String, count: int, dust: int, to: String) -> void:
	if Profile.owned(from) < count or not Profile.pay({"dust": dust}):
		return
	Profile.remove_card(from, count)
	var is_new := Profile.add_card(to)
	Profile.stat("forge_evolutions")
	Profile.check_collection_rewards()
	Profile.save_game()
	_celebrate(to, "ÉVOLUTION !", is_new)

## Animation de création : flash, carte qui apparaît en grand, particules.
func _celebrate(id: String, title: String, is_new: bool) -> void:
	Sfx.play("evolve")
	var root := Control.new()
	root.size = main.size
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.size = root.size
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var col := DB.rarity_color(DB.card(id).rarity)
	var glow := UI.glow_rect(Color(col, 0.7), Vector2(900, 900), 1.4, 14.0)
	glow.position = root.size / 2 - Vector2(450, 500)
	root.add_child(glow)
	var cv := CardView.make(id, 0.8)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.position = root.size / 2 - Vector2(CardView.W, CardView.H) * 0.4 - Vector2(0, 60)
	cv.set_pivot(Vector2(CardView.W, CardView.H) / 2)
	cv.scale = Vector2(0.1, 0.1)
	root.add_child(cv)
	var tl := UI.label(title, 48, col.lightened(0.3), "serif", 800, HORIZONTAL_ALIGNMENT_CENTER)
	UI.outline(tl, 10)
	tl.position = Vector2(0, 90)
	tl.size = Vector2(root.size.x, 70)
	root.add_child(tl)
	if is_new:
		var nl := UI.label("NOUVELLE CARTE", 26, UI.GOOD, "body", 800, HORIZONTAL_ALIGNMENT_CENTER)
		UI.outline(nl, 6)
		nl.position = Vector2(0, 160)
		nl.size = Vector2(root.size.x, 40)
		root.add_child(nl)
	var b := UI.button("Continuer", UI.ACCENT, 28, Vector2(320, 90), "ui_check")
	b.position = Vector2(root.size.x / 2 - 160, root.size.y - 200)
	b.pressed.connect(func():
		root.queue_free()
		_build())
	root.add_child(b)
	main.open_overlay(root)
	var t := cv.create_tween()
	t.tween_property(cv, "scale", Vector2(0.8, 0.8), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	UI.burst(root, root.size / 2 - Vector2(0, 60), col, 90, 700, 0.8, 1.3, 100)
	Sfx.play("reveal_3")

# ---------------------------------------------------------------- transformations secrètes
func _secrets() -> void:
	_note("Des fusions oubliées relient certaines cartes. Les indices se dévoilent ; les ingrédients n'apparaissent que lorsque tu les possèdes tous.")
	for r in DB.forge.secrets:
		var have_all := true
		for id in r.inputs:
			if Profile.owned(id) == 0:
				have_all = false
		var known: bool = r.id in Profile.d.forge_known
		if have_all and not known:
			Profile.d.forge_known.append(r.id)
			known = true
		var ok: bool = have_all and Profile.get_cur("dust") >= int(r.dust)
		var p := UI.panel(Color(0.12, 0.05, 0.18, 0.92), 22, Color("b46cff") if known else UI.LINE, 2)
		var v := UI.vbox(10)
		var tl := UI.label("Transformation secrète", 22, Color("d9b3ff"), "serif", 800)
		v.add_child(tl)
		var hint := UI.label("« %s »" % r.hint, 19, UI.TEXT, "serif", 600)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(hint)
		var h := UI.hbox(8)
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		for i in r.inputs.size():
			var id: String = r.inputs[i]
			h.add_child(_mini(id, "face" if known or Profile.owned(id) > 0 else "missing"))
			if i < r.inputs.size() - 1:
				h.add_child(UI.label("+", 40, UI.GOLD, "num", 400))
		h.add_child(_arrow())
		h.add_child(_mini(r.to, "face" if Profile.discovered(r.to) else "missing"))
		v.add_child(h)
		var b := UI.button("Transformer (%d Poussière)" % int(r.dust) if known else "Ingrédients inconnus", Color("8a3ad1") if ok else Color("3a3350"), 22, Vector2(0, 70), "ui_star")
		b.disabled = not ok
		b.pressed.connect(func():
			if not Profile.pay({"dust": int(r.dust)}):
				return
			for id in r.inputs:
				Profile.remove_card(id)
			var is_new := Profile.add_card(r.to)
			Profile.stat("secret_forges")
			Profile.check_collection_rewards()
			Profile.save_game()
			_celebrate(r.to, "TRANSFORMATION SECRÈTE !", is_new))
		v.add_child(b)
		p.add_child(v)
		body.add_child(p)
	Profile.save_game()

# ---------------------------------------------------------------- fabrication
func _craft() -> void:
	_note("Crée un exemplaire de n'importe quelle carte déjà découverte (jusqu'à la rareté Mythique). La Poussière s'obtient en recyclant les doublons (Album), en combat et via le passe.")
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	var costs: Dictionary = DB.forge.craft
	var n := 0
	for id in DB.card_order:
		var c := DB.card(id)
		if not Profile.discovered(id) or not costs.has(c.rarity):
			continue
		n += 1
		var cell := UI.vbox(4)
		var hld := CardView.holder(id, 0.4)
		var cv: CardView = hld.get_meta("card")
		cv.fx_enabled = false
		cv.tapped.connect(func(_c): main.show_card(id))
		cell.add_child(hld)
		var price := {"dust": int(costs[c.rarity])}
		var b := UI.price_button(price, UI.ACCENT, 20)
		b.custom_minimum_size = Vector2(0, 56)
		b.pressed.connect(func():
			if not Profile.pay(price):
				main.show_toast("Pas assez de Poussière d'étoile.", "error")
				return
			Profile.add_card(id)
			Profile.stat("cards_crafted")
			Profile.save_game()
			Sfx.play("buy")
			main.show_toast("%s créée (x%d)" % [c.name, Profile.owned(id)], "reward")
			_build())
		cell.add_child(b)
		g.add_child(cell)
	body.add_child(g)
	if n == 0:
		_note("Aucune carte découverte pour l'instant.")

# ---------------------------------------------------------------- variantes
func _variants() -> void:
	var vc: Dictionary = DB.forge.variants
	_note("Applique une variante à une carte possédée : Holographique, Full Art ou Alternate Art. Le coût augmente avec la rareté.")
	for id in DB.card_order:
		if Profile.owned(id) == 0:
			continue
		var c := DB.card(id)
		var e := Profile.entry(id)
		var p := UI.panel(Color(0.1, 0.06, 0.2, 0.9), 20)
		var h := UI.hbox(10)
		var hld := CardView.holder(id, 0.24)
		hld.get_meta("card").fx_enabled = false
		h.add_child(hld)
		var v := UI.vbox(6)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nl := UI.label(c.name, 21, Color.WHITE, "body", 800)
		nl.clip_text = true
		v.add_child(nl)
		var bh := UI.hbox(6)
		for k in vc:
			var cost := int(round(int(vc[k]) * (1.0 + DB.rarity_index(c.rarity) * 0.25)))
			var has: bool = e.get("variants", {}).has(k)
			var b := UI.button(("%s ✓" if false else "%s") % DB.variants[k].name.split(" ")[0], Color("2f8a5a") if has else Color("6a3db8"), 15, Vector2(0, 56))
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.tooltip_text = "%d Poussière" % cost
			if has:
				b.disabled = true
				b.text = DB.variants[k].name.split(" ")[0] + " ok"
			else:
				b.text = "%s\n%d" % [DB.variants[k].name.split(" ")[0], cost]
			var kk: String = k
			b.pressed.connect(func():
				if not Profile.pay({"dust": cost}):
					main.show_toast("Pas assez de Poussière d'étoile.", "error")
					return
				e.variants[kk] = int(e.variants.get(kk, 0)) + 1
				Profile.stat("variants_found")
				Profile.save_game()
				Sfx.play("reveal_2")
				main.show_card(id, kk)
				_build())
			bh.add_child(b)
		v.add_child(bh)
		h.add_child(v)
		p.add_child(h)
		body.add_child(p)
