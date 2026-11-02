extends Control
## Boutique : boosters, offres du jour/semaine (rotation), cartes à l'unité, cosmétiques, cristaux premium.

var main: Control
var tab := "boosters"
var body: VBoxContainer
var _tabs := {}

const TABS := [["boosters", "Boosters"], ["products", "Displays"], ["offers", "Offres"], ["singles", "Cartes"], ["cosmetics", "Style"], ["premium", "Cristaux"]]
const BACK_HUES := {"back_ember": 0.62, "back_jade": 0.35, "back_gold": 0.83, "back_eclipse": 0.12}
const SINGLE_PRICE := {"C": 40, "U": 80, "R": 180, "SR": 350, "E": 700, "L": 1800}
const COSMETICS := [
	{"id": "back_default", "type": "back", "name": "Dos Nébuleuse", "price": {}},
	{"id": "back_ember", "type": "back", "name": "Dos Braise", "price": {"crystals": 60}},
	{"id": "back_jade", "type": "back", "name": "Dos Jade", "price": {"crystals": 60}},
	{"id": "back_gold", "type": "back", "name": "Dos Aurore", "price": {"crystals": 120}},
	{"id": "back_eclipse", "type": "back", "name": "Dos Éclipse", "price": {}, "exclusive": "Passe Élite, palier 30"},
	{"id": "board_default", "type": "board", "name": "Arène Astrale", "price": {}, "colors": ["0b0716", "3a1466", "0d4070"]},
	{"id": "board_volcano", "type": "board", "name": "Arène Volcanique", "price": {"crystals": 80}, "colors": ["160505", "6a1a08", "8a3a10"]},
	{"id": "board_abyss", "type": "board", "name": "Arène Abyssale", "price": {"crystals": 80}, "colors": ["02101a", "06404a", "0a2a60"]},
	{"id": "board_sanctum", "type": "board", "name": "Sanctuaire Doré", "price": {"crystals": 150}, "colors": ["160e04", "6a4a10", "4a2a60"]},
]

func setup(p: Dictionary) -> void:
	main = get_meta("main")
	tab = p.get("tab", "boosters")
	var root := UI.vbox(12)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 18
	root.offset_right = -18
	root.offset_top = 12
	add_child(root)
	var t := UI.label("Boutique", 40, UI.GOLD, "serif", 800)
	UI.outline(t, 6)
	root.add_child(t)
	var th := UI.hbox(6)
	for td in TABS:
		var b := Button.new()
		b.text = td[1]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 58)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_override("font", UI.font("body", 800))
		b.add_theme_font_size_override("font_size", 17)
		var k: String = td[0]
		b.pressed.connect(func(): Sfx.play("click"); tab = k; _build())
		_tabs[k] = b
		th.add_child(b)
	root.add_child(th)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	body = UI.vbox(16)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(body)
	_build()

func refresh() -> void:
	_build()

func _build() -> void:
	for k in _tabs:
		var on: bool = k == tab
		_tabs[k].add_theme_stylebox_override("normal", UI.box(Color(UI.ACCENT, 0.55) if on else Color(0, 0, 0, 0.4), 16, UI.ACCENT if on else UI.LINE, 2))
		_tabs[k].add_theme_stylebox_override("hover", UI.box(Color(UI.ACCENT, 0.4), 16, UI.ACCENT, 2))
		_tabs[k].add_theme_stylebox_override("pressed", UI.box(Color(UI.ACCENT, 0.6), 16, UI.ACCENT, 2))
	for c in body.get_children():
		c.queue_free()
	match tab:
		"boosters": _boosters()
		"products": _products()
		"offers": _offers()
		"singles": _singles()
		"cosmetics": _cosmetics()
		"premium": _premium()

# ---------------------------------------------------------------- boosters
func _boosters() -> void:
	var pity: Dictionary = Profile.d.pity
	var info := UI.label("Protection anti-malchance : Légendaire ou mieux garanti dans %d booster(s) · Mythique ou mieux dans %d." % [
		int(DB.pity.legendary_plus.hard) - int(pity.get("legendary_plus", 0)), int(DB.pity.mythic_plus.hard) - int(pity.get("mythic_plus", 0))], 19, UI.ACCENT2, "body", 700)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(info)
	for grp in [["gen", "Par génération", "Gén. 1 Genèse · Gén. 2 Éclipse · Gén. 3 Âge Primitif · Multivers"], ["type", "Par type", "Uniquement les cartes d'un élément, toutes générations"], ["special", "Boosters spéciaux", "Thèmes, chances accrues, événement"]]:
		body.add_child(_section(grp[1], grp[2]))
		for b in DB.boosters:
			if b.get("group", "special") != grp[0]:
				continue
			if b.has("event") and DB.active_event().get("id", "") != b.event:
				continue
			body.add_child(_booster_row(b))

func _booster_row(b: Dictionary) -> Control:
	var col := Color(b.color)
	var p := PanelContainer.new()
	var st := UI.box(col.darkened(0.72), 24, col, 3, 8)
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 14
	st.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", st)
	var h := UI.hbox(16)
	var pack := TextureRect.new()
	pack.texture = DB.tex("res://assets/ui/packs/%s.png" % b.id)
	pack.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pack.custom_minimum_size = Vector2(150, 232)
	pack.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	h.add_child(pack)
	var v := UI.vbox(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n := UI.label(b.name, 30, Color.WHITE, "serif", 800)
	UI.outline(n, 6)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(n)
	var d := UI.label(b.desc, 20, UI.TEXT, "body", 600)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	v.add_child(UI.label("%d cartes · la 5e est Rare ou mieux" % int(b.cards), 18, UI.MUTED, "body", 600))
	var bh := UI.hbox(10)
	var locked: bool = int(b.get("min_level", 0)) > int(Profile.d.level)
	var free: bool = Profile.free_count(b.id) > 0
	var buy: Button
	if locked:
		buy = UI.button("Niveau %d requis" % int(b.min_level), Color("4a3a6a"), 22, Vector2(0, 70), "ui_lock")
		buy.disabled = true
	elif free:
		buy = UI.button("GRATUIT (%d)" % Profile.free_count(b.id), UI.GOOD.darkened(0.2), 24, Vector2(0, 70), "ui_gift")
	else:
		buy = UI.price_button(b.price, col.darkened(0.15), 26)
	buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy.pressed.connect(func(): open_booster(b))
	bh.add_child(buy)
	var odds := UI.icon_button("ui_info", 70)
	odds.pressed.connect(func(): _show_odds(b))
	bh.add_child(odds)
	v.add_child(bh)
	h.add_child(v)
	p.add_child(h)
	return p

func open_booster(b: Dictionary, test := false) -> void:
	if not test:
		if int(b.get("min_level", 0)) > int(Profile.d.level):
			return
		if Profile.use_free(b.id):
			pass
		elif not Profile.pay(b.price):
			main.show_toast("Pas assez de %s." % Profile.CURRENCY_NAMES.get(b.price.keys()[0], ""), "error")
			return
	open_pack(main, b, {"force_piece": test and get_meta("force_piece", false)})

## Tire et ouvre un booster déjà payé. opts : force_min (rareté garantie), force_piece. Renvoie l'écran d'ouverture.
static func open_pack(main_node: Control, b: Dictionary, opts := {}) -> Control:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var force: String = opts.get("force_min", "")
	if force != "":
		var key := "mythic_plus" if DB.rarity_index(force) >= DB.rarity_index("M") else "legendary_plus"
		Profile.d.pity[key] = maxi(int(Profile.d.pity.get(key, 0)), int(DB.pity[key].hard) - 1)
	var res := BoosterLogic.open(b, Profile.d.pity, rng)
	for r in res:
		r["new"] = Profile.add_card(r.id, r.variant)
		if DB.card(r.id).rarity in DB.numbered.rarities:
			r["serial"] = int(Profile.entry(r.id).get("serial", 0))
	# pièce de puzzle SWAP éventuelle
	var st := {"pity": int(Profile.d.puzzle_pity), "puzzles": Profile.d.puzzles}
	var piece := BoosterLogic.roll_piece(b, st, rng)
	if opts.get("force_piece", false) and piece.is_empty():
		piece = BoosterLogic.roll_piece(b, {"pity": 999, "puzzles": Profile.d.puzzles}, rng)
	Profile.d.puzzle_pity = int(st.pity)
	if not piece.is_empty():
		piece.merge(Profile.add_piece(piece.id, int(piece.piece)))
	Profile.stat("boosters_opened")
	Profile.add_xp(15)
	Profile.check_collection_rewards()
	Profile.save_game()
	var o = load("res://scripts/ui/booster_open.gd").new()
	o.setup(b, res, piece)
	o.set_meta("results", res)
	main_node.open_overlay(o, true)
	return o

func _show_odds(b: Dictionary) -> void:
	var v := UI.vbox(6)
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 24)
	g.add_theme_constant_override("v_separation", 4)
	for hd in ["Rareté", "Cartes 1 à 4", "Carte 5"]:
		g.add_child(UI.label(hd, 20, UI.MUTED, "body", 800))
	for line in BoosterLogic.odds_lines(b):
		var l := UI.label(DB.rarity(line.rarity).name, 21, DB.rarity_color(line.rarity), "body", 800)
		UI.outline(l, 3)
		g.add_child(l)
		g.add_child(UI.label(BoosterLogic.fmt_pct(line.slot), 21, UI.TEXT, "body", 600, HORIZONTAL_ALIGNMENT_RIGHT))
		g.add_child(UI.label(BoosterLogic.fmt_pct(line.last), 21, UI.TEXT, "body", 600, HORIZONTAL_ALIGNMENT_RIGHT))
	v.add_child(g)
	var var_txt := "Variantes par carte : "
	var parts := []
	for k in DB.variants:
		parts.append("%s %s" % [DB.variants[k].name, BoosterLogic.fmt_pct(float(DB.variants[k].chance) * sqrt(float(b.get("luck", 1.0))) * 100.0)])
	var vl := UI.label(var_txt + ", ".join(parts) + ".", 17, UI.MUTED, "body", 600)
	vl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(vl)
	var pz: Dictionary = DB.puzzle_cfg()
	var pzl := UI.label("Pièce de puzzle SWAP : %s par booster, garantie au moins tous les %d boosters. 9 pièces forment une carte SWAP." % [BoosterLogic.fmt_pct(float(pz.chance) * sqrt(float(b.get("luck", 1.0))) * 100.0), int(pz.pity)], 17, Color("4dffea"), "body", 700)
	pzl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(pzl)
	var pl := UI.label("Garanties : Légendaire+ au plus tard au %de booster sans Légendaire (chances accrues dès le %de), Mythique+ au %de." % [int(DB.pity.legendary_plus.hard), int(DB.pity.legendary_plus.soft), int(DB.pity.mythic_plus.hard)], 17, UI.ACCENT2, "body", 700)
	pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(pl)
	main.modal("Probabilités", v)

# ---------------------------------------------------------------- offres
# ---------------------------------------------------------------- displays et coffrets
func _products() -> void:
	var mine: Array = Profile.d.get("displays", [])
	if not mine.is_empty():
		body.add_child(_section("Tes displays en cours", "Reprends l'ouverture là où tu t'es arrêté"))
		for i in mine.size():
			var dsp: Dictionary = mine[i]
			var dd := DB.product("displays", dsp.id)
			var b := UI.button("%s · %d / %d boosters restants" % [dd.name, int(dsp.left), int(dd.count)], Color(dd.color).darkened(0.2), 22, Vector2(0, 80), "ui_gift")
			var idx: int = i
			b.pressed.connect(func(): open_display(idx))
			body.add_child(b)
	body.add_child(_section("Displays", "Une caisse de boosters à ouvrir un par un, avec une carte garantie"))
	for dd in DB.products.displays:
		body.add_child(_product_row(dd, true))
	body.add_child(_section("Coffrets", "Boosters, jetons et une carte promo précise garantie"))
	for bx in DB.products.boxes:
		body.add_child(_product_row(bx, false))

func _product_row(pd: Dictionary, is_display: bool) -> Control:
	var col := Color(pd.color)
	var p := PanelContainer.new()
	var st := UI.box(col.darkened(0.72), 24, col, 3, 8)
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 14
	st.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", st)
	var h := UI.hbox(14)
	var pv := Control.new()
	pv.custom_minimum_size = Vector2(170, 200)
	if is_display:
		var box := Panel.new()
		box.position = Vector2(0, 40)
		box.size = Vector2(170, 150)
		box.add_theme_stylebox_override("panel", UI.box(col.darkened(0.35), 10, col.lightened(0.3), 3))
		pv.add_child(box)
		for k in 6:
			var t := TextureRect.new()
			t.texture = DB.tex("res://assets/ui/packs/%s.png" % pd.booster)
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			t.size = Vector2(46, 72)
			t.position = Vector2(8 + k * 26, 6 + (k % 2) * 6)
			t.rotation = (k - 2.5) * 0.04
			pv.add_child(t)
		var lb := UI.label("x%d" % int(pd.count), 30, Color.WHITE, "num", 400, HORIZONTAL_ALIGNMENT_CENTER)
		UI.outline(lb, 6)
		lb.position = Vector2(0, 110)
		lb.size = Vector2(170, 50)
		pv.add_child(lb)
	else:
		var hld := CardView.holder(pd.promo.card, 0.3, pd.promo.variant)
		hld.position = Vector2(18, 4)
		pv.add_child(hld)
	h.add_child(pv)
	var v := UI.vbox(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n := UI.label(pd.name, 27, Color.WHITE, "serif", 800)
	UI.outline(n, 6)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(n)
	var dtxt: String = pd.get("desc", "")
	if is_display:
		dtxt = "%d × %s. %s ou mieux garanti dans le display." % [int(pd.count), DB.booster(pd.booster).name, DB.rarity(pd.guarantee).name]
	var d := UI.label(dtxt, 18, UI.TEXT, "body", 600)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	var buy := UI.price_button(pd.price, col.darkened(0.15), 24)
	buy.pressed.connect(func():
		if not Profile.pay(pd.price):
			main.show_toast("Pas assez de ressources.", "error")
			return
		Sfx.play("buy")
		if is_display:
			Profile.d.displays.append({"id": pd.id, "left": int(pd.count), "hit": false})
			Profile.save_game()
			open_display(Profile.d.displays.size() - 1)
		else:
			open_box(pd))
	v.add_child(buy)
	h.add_child(v)
	p.add_child(h)
	return p

func open_display(i: int) -> void:
	var o = load("res://scripts/ui/display_open.gd").new()
	o.setup(i)
	main.open_overlay(o, true)

func open_box(pd: Dictionary) -> void:
	var o = load("res://scripts/ui/box_open.gd").new()
	o.setup(pd)
	main.open_overlay(o, true)

func _today() -> String:
	return Time.get_date_string_from_system()

func _bought(key: String) -> bool:
	if Profile.d.shop.get("date", "") != _today():
		Profile.d.shop = {"date": _today(), "bought": Profile.d.shop.get("bought", []).filter(func(k): return k.begins_with("W"))}
	return key in Profile.d.shop.bought

func _offers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_today())
	var pool := [
		{"id": "o_classic", "title": "Booster Genèse -30 %", "desc": "Un booster Genèse à prix réduit.", "price": {"coins": 70}, "booster": "classic"},
		{"id": "o_crystals", "title": "Cadeau du jour", "desc": "5 Cristaux offerts, chaque jour.", "price": {}, "reward": {"crystals": 5}},
		{"id": "o_dragons", "title": "Booster Draconique -25 %", "desc": "Les dragons à prix doux.", "price": {"coins": 120}, "booster": "dragons"},
		{"id": "o_abyss", "title": "Booster Abyssal -25 %", "desc": "Plongée à prix réduit.", "price": {"coins": 120}, "booster": "abyss"},
		{"id": "o_coins", "title": "Bourse d'aventurier", "desc": "300 Pièces contre 20 Cristaux.", "price": {"crystals": 20}, "reward": {"coins": 300}},
		{"id": "o_dust", "title": "Poussière d'étoile", "desc": "150 Poussières pour 100 Pièces.", "price": {"coins": 100}, "reward": {"dust": 150}},
	]
	var picks := [pool[1]]
	pool.remove_at(1)
	while picks.size() < 3:
		picks.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	body.add_child(_section("Offres du jour", "Renouvelées chaque jour à minuit"))
	for o in picks:
		body.add_child(_offer_row(o, o.id))
	body.add_child(_section("Offre de la semaine", ""))
	var wk := "W" + Profile._period_key(true)
	var wo := {"id": "w_token", "title": "Jeton spécial", "desc": "Un Jeton pour le Booster Secret (niveau 5).", "price": {"crystals": 60}, "reward": {"tokens": 1}}
	body.add_child(_offer_row(wo, wk + "_token"))

func _section(t: String, sub: String) -> Control:
	var v := UI.vbox(2)
	var l := UI.label(t, 28, UI.TEXT, "serif", 800)
	v.add_child(l)
	if sub != "":
		v.add_child(UI.label(sub, 18, UI.MUTED, "body", 600))
	return v

func _offer_row(o: Dictionary, key: String) -> Control:
	var p := UI.panel(Color(0.1, 0.06, 0.2, 0.9))
	var h := UI.hbox(14)
	var ic := "ui_gift"
	if o.has("booster"):
		var tr := TextureRect.new()
		tr.texture = DB.tex("res://assets/ui/packs/%s.png" % o.booster)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.custom_minimum_size = Vector2(70, 108)
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		h.add_child(tr)
	else:
		h.add_child(UI.icon_rect(UI.price_icon(o.reward) if UI.price_icon(o.reward) != "" else ic, 70))
	var v := UI.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.label(o.title, 24, Color.WHITE, "body", 800))
	var d := UI.label(o.desc, 18, UI.MUTED, "body", 600)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	h.add_child(v)
	var done := _bought(key)
	var b: Button
	if done:
		b = UI.button("Acheté", Color("3a3350"), 22, Vector2(150, 70), "ui_check")
		b.disabled = true
	elif o.price.is_empty():
		b = UI.button("Gratuit", UI.GOOD.darkened(0.2), 22, Vector2(150, 70))
	else:
		b = UI.price_button(o.price, UI.ACCENT, 24)
		b.custom_minimum_size.x = 150
	b.pressed.connect(func():
		if not o.price.is_empty() and not Profile.pay(o.price):
			main.show_toast("Pas assez de ressources.", "error")
			return
		Profile.d.shop.bought.append(key)
		Sfx.play("buy")
		if o.has("booster"):
			Profile.save_game()
			var bd := DB.booster(o.booster)
			open_booster(bd, true)
		else:
			Profile.give(o.reward)
		_build())
	h.add_child(b)
	p.add_child(h)
	return p

# ---------------------------------------------------------------- cartes à l'unité
func _singles() -> void:
	body.add_child(_section("Cartes à l'unité", "4 cartes en vente, renouvelées chaque jour"))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_today() + "singles")
	var pool := []
	for id in DB.card_order:
		if SINGLE_PRICE.has(DB.card(id).rarity):
			pool.append(id)
	var picks := []
	while picks.size() < 4:
		var id: String = pool[rng.randi_range(0, pool.size() - 1)]
		if not id in picks:
			picks.append(id)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 20)
	g.add_theme_constant_override("v_separation", 20)
	for id in picks:
		var v := UI.vbox(8)
		var h := CardView.holder(id, 0.66)
		h.get_meta("card").tapped.connect(func(_c): main.show_card(id))
		v.add_child(h)
		var key: String = "single_" + id
		var price := {"coins": SINGLE_PRICE[DB.card(id).rarity]}
		var b: Button
		if _bought(key):
			b = UI.button("Achetée", Color("3a3350"), 22, Vector2(0, 66), "ui_check")
			b.disabled = true
		else:
			b = UI.price_button(price, UI.ACCENT, 24)
		b.pressed.connect(func():
			if not Profile.pay(price):
				main.show_toast("Pas assez de Pièces.", "error")
				return
			Profile.d.shop.bought.append(key)
			var is_new := Profile.add_card(id)
			Profile.check_collection_rewards()
			Profile.save_game()
			Sfx.play("buy")
			main.show_toast("%s ajoutée à ta collection%s" % [DB.card(id).name, " (nouvelle !)" if is_new else ""], "reward")
			_build())
		v.add_child(b)
		g.add_child(v)
	body.add_child(g)

# ---------------------------------------------------------------- cosmétiques
func _cosmetics() -> void:
	body.add_child(_section("Dos de cartes", "Visible en combat et à l'ouverture des boosters"))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 20)
	g.add_theme_constant_override("v_separation", 20)
	for c in COSMETICS:
		if c.type != "back":
			continue
		var v := UI.vbox(6)
		var prev := TextureRect.new()
		prev.texture = DB.tex("res://assets/ui/card_back.png")
		prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		prev.custom_minimum_size = Vector2(200, 280)
		prev.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		prev.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/art_fx.gdshader")
		m.set_shader_parameter("mode", 0 if c.id == "back_default" else 1)
		m.set_shader_parameter("hue_shift", BACK_HUES.get(c.id, 0.0))
		prev.material = m
		v.add_child(prev)
		v.add_child(UI.label(c.name, 22, UI.TEXT, "body", 800, HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(_cosmetic_button(c, "back"))
		g.add_child(v)
	body.add_child(g)
	body.add_child(_section("Plateaux de combat", "Change l'ambiance de l'arène"))
	for c in COSMETICS:
		if c.type != "board":
			continue
		var p := UI.panel(Color(c.colors[1]).darkened(0.3), 20, Color(c.colors[2]).lightened(0.3), 2)
		var h := UI.hbox(12)
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(140, 90)
		var m2 := ShaderMaterial.new()
		m2.shader = load("res://shaders/menu_bg.gdshader")
		m2.set_shader_parameter("c1", Color(c.colors[0]))
		m2.set_shader_parameter("c2", Color(c.colors[1]))
		m2.set_shader_parameter("c3", Color(c.colors[2]))
		m2.set_shader_parameter("res", Vector2(140, 90))
		sw.material = m2
		h.add_child(sw)
		h.add_child(UI.expand(UI.label(c.name, 24, Color.WHITE, "body", 800)))
		h.add_child(_cosmetic_button(c, "board"))
		p.add_child(h)
		body.add_child(p)

func _cosmetic_button(c: Dictionary, kind: String) -> Button:
	var cos: Dictionary = Profile.d.cosmetics
	var owned: bool = c.id in cos.owned
	var equipped: bool = cos.get(kind, "") == c.id
	var b: Button
	if equipped:
		b = UI.button("Équipé", Color("2f8a5a"), 22, Vector2(170, 64), "ui_check")
		b.disabled = true
	elif owned:
		b = UI.button("Équiper", UI.ACCENT, 22, Vector2(170, 64))
	elif c.has("exclusive"):
		b = UI.button(c.exclusive, Color("3a3350"), 16, Vector2(170, 64), "ui_lock")
		b.disabled = true
	else:
		b = UI.price_button(c.price, UI.ACCENT, 22)
		b.custom_minimum_size.x = 170
	b.pressed.connect(func():
		if not owned:
			if not Profile.pay(c.price):
				main.show_toast("Pas assez de Cristaux.", "error")
				return
			cos.owned.append(c.id)
			Sfx.play("buy")
		cos[kind] = c.id
		Profile.save_game()
		_build())
	return b

# ---------------------------------------------------------------- premium
func _premium() -> void:
	body.add_child(_section("Cristaux", "Monétisation facultative : tout le contenu s'obtient aussi en jouant."))
	var note := UI.label("Les achats réels ne sont pas activés dans ce prototype. L'intégration prévue passe par Google Play Billing avec validation des reçus côté serveur (voir ARCHITECTURE.md). Les cristaux se gagnent gratuitement : missions, succès, niveaux, connexion quotidienne et collections.", 19, UI.ACCENT2, "body", 600)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)
	for pk in [[80, "Poignée de cristaux", "0,99 €"], [500, "Coffret de cristaux", "4,99 €"], [1200, "Trésor de cristaux", "9,99 €"], [2800, "Météore de cristaux", "19,99 €"]]:
		var p := UI.panel(Color(0.08, 0.1, 0.22, 0.9), 20, Color("4a7dff"), 2)
		var h := UI.hbox(14)
		h.add_child(UI.icon_rect("crystal", 64))
		var v := UI.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UI.label("%d Cristaux" % pk[0], 26, Color.WHITE, "num", 400))
		v.add_child(UI.label(pk[1], 18, UI.MUTED, "body", 600))
		h.add_child(v)
		var b := UI.button(pk[2], Color("3a3350"), 22, Vector2(150, 64))
		b.disabled = true
		h.add_child(b)
		p.add_child(h)
		body.add_child(p)
