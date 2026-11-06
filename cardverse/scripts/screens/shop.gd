extends Control
## Boutique : boosters, offres du jour/semaine (rotation), cartes à l'unité, cosmétiques, cristaux premium.

var main: Control
var tab := "boosters"
var body: VBoxContainer
var _tabs := {}

const TABS := [["boosters", "Boosters"], ["products", "Displays"], ["bundles", "Packs"], ["wheel", "Roue"], ["market", "Marché"], ["offers", "Offres"], ["singles", "Cartes"], ["cosmetics", "Style"], ["premium", "Cristaux"]]
const BACK_HUES := {"back_ember": 0.62, "back_jade": 0.35, "back_gold": 0.83, "back_eclipse": 0.12, "back_corsair": 0.5, "back_nebula": 0.92, "back_neon": 0.42}
const SINGLE_PRICE := {"C": 40, "U": 80, "R": 180, "SR": 350, "E": 700, "L": 1800}
const COSMETICS := [
	{"id": "back_default", "type": "back", "name": "Dos Nébuleuse", "price": {}},
	{"id": "back_ember", "type": "back", "name": "Dos Braise", "price": {"crystals": 60}},
	{"id": "back_jade", "type": "back", "name": "Dos Jade", "price": {"crystals": 60}},
	{"id": "back_gold", "type": "back", "name": "Dos Aurore", "price": {"crystals": 120}},
	{"id": "back_eclipse", "type": "back", "name": "Dos Éclipse", "price": {}, "exclusive": "Saison 1"},
	{"id": "back_neon", "type": "back", "name": "Dos Néon", "price": {"crystals": 90}},
	{"id": "back_corsair", "type": "back", "name": "Dos Corsaire", "price": {}, "exclusive": "Passe S2 · 30"},
	{"id": "back_nebula", "type": "back", "name": "Dos Nébuleuse Pourpre", "price": {}, "exclusive": "Malle (Packs)"},
	{"id": "board_default", "type": "board", "name": "Arène Astrale", "price": {}, "colors": ["0b0716", "3a1466", "0d4070"]},
	{"id": "board_volcano", "type": "board", "name": "Arène Volcanique", "price": {"crystals": 80}, "colors": ["160505", "6a1a08", "8a3a10"]},
	{"id": "board_abyss", "type": "board", "name": "Arène Abyssale", "price": {"crystals": 80}, "colors": ["02101a", "06404a", "0a2a60"]},
	{"id": "board_sanctum", "type": "board", "name": "Sanctuaire Doré", "price": {"crystals": 150}, "colors": ["160e04", "6a4a10", "4a2a60"]},
	{"id": "board_jungle", "type": "board", "name": "Arène de la Jungle", "price": {"crystals": 100}, "colors": ["03140a", "0e4a22", "3a6a10"]},
	{"id": "board_nebula", "type": "board", "name": "Pont du Vaisseau Astral", "price": {}, "colors": ["05051a", "1a1060", "0a6a8a"], "exclusive": "Passe S2 · 15"},
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
	# onglets sur deux rangées (9 onglets)
	var rows := UI.vbox(6)
	var th := UI.hbox(6)
	for td in TABS:
		if th.get_child_count() == 5:
			rows.add_child(th)
			th = UI.hbox(6)
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
		if k in ["wheel", "market"]:
			b.add_theme_color_override("font_color", UI.GOLD)
		th.add_child(b)
	rows.add_child(th)
	root.add_child(rows)
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
		"bundles": _bundles()
		"wheel": _wheel()
		"market": _market()
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
	for grp in [["edition", "Nouvelle édition", "Booster Prestige (8 cartes, variante garantie) et Mini-Booster (3 cartes)"], ["gen", "Par génération", "Gén. 1 à Gén. 8, et Multivers (toutes générations)"], ["type", "Par type", "Uniquement les cartes d'un élément, toutes générations"], ["special", "Boosters spéciaux", "Thèmes, chances accrues, événement"]]:
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
	# booster en vraie 3D (balancement doux, reflets foil)
	var pack := Pack3D.make(b.id, Vector2(150, 232), 1.12)
	pack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	var rs := int(b.get("rare_slots", 1))
	var info_txt := "%d cartes · %s Rare ou mieux" % [int(b.cards), "la dernière est" if rs == 1 else "les %d dernières sont" % rs]
	if b.get("guaranteed_variant", false):
		info_txt += " · variante garantie"
	var il := UI.label(info_txt, 18, UI.ACCENT2 if b.get("group", "") == "edition" else UI.MUTED, "body", 700)
	il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(il)
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
	# garantie au-delà de Mythique (display APEX : Chaos ou Symbiot)
	if force != "" and DB.rarity_index(force) > DB.rarity_index("M"):
		BoosterLogic.force_top(b, res, force, rng)
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
	var nc := int(b.get("cards", 5))
	var rs := int(b.get("rare_slots", 1))
	var heads := ["Rareté", "Cartes 1 à %d" % (nc - rs), ("Carte %d" % nc) if rs == 1 else ("Cartes %d à %d" % [nc - rs + 1, nc])]
	for hd in heads:
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
		var sl := UI.label(sub, 18, UI.MUTED, "body", 600)
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(sl)
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
		var bl := UI.label(c.name, 24, Color.WHITE, "body", 800)
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.add_child(UI.expand(bl))
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

# ---------------------------------------------------------------- packs groupés
func _bundles() -> void:
	body.add_child(_section("Packs groupés", "Plusieurs boosters et ressources à prix réduit · renouvelés chaque semaine"))
	var wk := Profile._period_key(true)
	for bd in DB.products.get("bundles", []):
		var key: String = ("BD_" + bd.id) if bd.get("limit", "week") == "once" else (wk + "_" + bd.id)
		body.add_child(_bundle_row(bd, key))

func _bundle_row(bd: Dictionary, key: String) -> Control:
	var col := Color(bd.color)
	var p := PanelContainer.new()
	var st := UI.box(col.darkened(0.75), 24, col, 3, 8)
	for side in ["left", "right", "top", "bottom"]:
		st.set("content_margin_" + side, 14)
	p.add_theme_stylebox_override("panel", st)
	var v := UI.vbox(10)
	var n := UI.label(bd.name, 28, Color.WHITE, "serif", 800)
	UI.outline(n, 6)
	v.add_child(n)
	# éventail des boosters inclus
	var fan := UI.hbox(-30)
	var rew: Dictionary = bd.reward
	for bid in rew.get("boosters", {}):
		for k in mini(int(rew.boosters[bid]), 3):
			var t := TextureRect.new()
			t.texture = DB.tex("res://assets/ui/packs/%s.png" % bid)
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			t.custom_minimum_size = Vector2(76, 118)
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fan.add_child(t)
	for cur in ["coins", "crystals", "dust", "tokens"]:
		if rew.has(cur):
			var cv := UI.vbox(0)
			cv.add_child(UI.spacer(36))
			cv.add_child(UI.icon_rect(cur if cur != "tokens" else "token", 56))
			cv.add_child(UI.label("+%d" % int(rew[cur]), 20, Color.WHITE, "num", 400, HORIZONTAL_ALIGNMENT_CENTER))
			fan.add_child(UI.spacer(0, 40))
			fan.add_child(cv)
	if rew.has("random_card"):
		fan.add_child(UI.spacer(0, 40))
		var q := UI.label("?", 70, DB.rarity_color(rew.random_card.rarity), "serif", 900, HORIZONTAL_ALIGNMENT_CENTER)
		UI.outline(q, 8)
		q.custom_minimum_size = Vector2(80, 118)
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fan.add_child(q)
	v.add_child(fan)
	var d := UI.label(bd.desc, 19, UI.TEXT, "body", 600)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	var lim := UI.label("Achat unique" if bd.get("limit", "week") == "once" else "1 par semaine", 16, UI.MUTED, "body", 700)
	v.add_child(lim)
	var b: Button
	if _bought_key(key):
		b = UI.button("Acheté", Color("3a3350"), 22, Vector2(0, 70), "ui_check")
		b.disabled = true
	else:
		b = UI.price_button(bd.price, col.darkened(0.25), 26)
	b.pressed.connect(func():
		if not Profile.pay(bd.price):
			main.show_toast("Pas assez de ressources.", "error")
			return
		Profile.d.shop_once.append(key)
		Sfx.play("buy")
		Profile.give(rew)
		Profile.save_game()
		_build())
	v.add_child(b)
	p.add_child(v)
	return p

func _bought_key(key: String) -> bool:
	if not Profile.d.has("shop_once"):
		Profile.d["shop_once"] = []
	return key in Profile.d.shop_once

# ---------------------------------------------------------------- roue de la fortune
var _wheel_view: WheelView
var wheel_last := -1

func _wheel() -> void:
	body.add_child(_section("Roue de la Fortune", "Un tour gratuit chaque jour · %d tours bonus maximum" % ShopLogic.EXTRA_SPINS_PER_DAY))
	var ws := ShopLogic.wheel_state(Profile.d, _today())
	var c := CenterContainer.new()
	_wheel_view = WheelView.new()
	c.add_child(_wheel_view)
	body.add_child(c)
	var b: Button
	if not ws.free_used:
		b = UI.button("TOURNER GRATUITEMENT", UI.GOOD.darkened(0.2), 28, Vector2(0, 90), "ui_gift")
	elif int(ws.extra) < ShopLogic.EXTRA_SPINS_PER_DAY:
		b = UI.price_button(ShopLogic.EXTRA_SPIN_PRICE, Color("b8283c"), 28)
		b.text = "Tour bonus (%d/%d)  " % [int(ws.extra) + 1, ShopLogic.EXTRA_SPINS_PER_DAY] + b.text
	else:
		b = UI.button("Reviens demain !", Color("3a3350"), 26, Vector2(0, 90), "ui_calendar")
		b.disabled = true
	b.pressed.connect(func(): spin_wheel(b))
	body.add_child(b)
	var odds := UI.vbox(2)
	odds.add_child(UI.label("Chances de chaque case", 20, UI.MUTED, "body", 800))
	for i in ShopLogic.WHEEL.size():
		var s: Dictionary = ShopLogic.WHEEL[i]
		var txt := _wheel_text(s.reward)
		odds.add_child(UI.label("%s : %s" % [txt, BoosterLogic.fmt_pct(ShopLogic.wheel_chance(i))], 17, UI.TEXT, "body", 600))
	body.add_child(odds)

func _wheel_text(rew: Dictionary) -> String:
	for k in rew:
		match k:
			"booster":
				return "1 " + DB.booster(rew.booster).name
			"random_card":
				return "1 carte %s au hasard" % DB.rarity(rew.random_card.rarity).name
			_:
				return "%d %s" % [int(rew[k]), Profile.cur_name(k, int(rew[k]))]
	return ""

## Lance la roue (payée si besoin) ; la récompense est donnée à l'arrêt.
func spin_wheel(btn: Button = null, fast := false) -> int:
	var ws := ShopLogic.wheel_state(Profile.d, _today())
	if _wheel_view == null or _wheel_view.spinning:
		return -1
	if ws.free_used:
		if int(ws.extra) >= ShopLogic.EXTRA_SPINS_PER_DAY:
			return -1
		if not Profile.pay(ShopLogic.EXTRA_SPIN_PRICE):
			main.show_toast("Pas assez de Cristaux.", "error")
			return -1
		ws.extra = int(ws.extra) + 1
	else:
		ws.free_used = true
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var i := ShopLogic.wheel_roll(rng)
	wheel_last = i
	Profile.save_game()
	if btn:
		btn.disabled = true
	Sfx.play("whoosh")
	_wheel_view.finished.connect(func(idx):
		var rew: Dictionary = ShopLogic.WHEEL[idx].reward
		Sfx.play("reveal_3" if ShopLogic.WHEEL[idx].w <= 6.0 else "coin")
		UI.burst(self, _wheel_view.global_position + Vector2(250, 60), Color(ShopLogic.WHEEL[idx].color).lightened(0.4), 60)
		Profile.give(rew, true)
		Profile.stat("wheel_spins")
		Profile.save_game()
		if fast:
			_build.call_deferred()
			return
		var rv := UI.vbox(10)
		var ic := UI.icon_rect(ShopLogic.WHEEL[idx].icon, 110, UI.GOLD if ShopLogic.WHEEL[idx].icon.begins_with("ui_") else Color.WHITE)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		rv.add_child(ic)
		var rl := UI.label(_wheel_text(rew), 30, Color.WHITE, "serif", 800, HORIZONTAL_ALIGNMENT_CENTER)
		UI.outline(rl, 6)
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rl.custom_minimum_size = Vector2(480, 0)
		rv.add_child(rl)
		if rew.has("random_card") and Profile.last_given_card != "":
			var ch := CardView.holder(Profile.last_given_card, 0.5)
			ch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			rv.add_child(ch)
		var hint := "Le booster t'attend dans l'onglet Boosters (GRATUIT)." if rew.has("booster") else ("Ajoutée à ta collection." if rew.has("random_card") else "")
		if hint != "":
			rv.add_child(UI.label(hint, 18, UI.MUTED, "body", 600, HORIZONTAL_ALIGNMENT_CENTER))
		main.modal("Gagné !", rv, [["Super !", UI.GOOD.darkened(0.2), func(): _build()]]), CONNECT_ONE_SHOT)
	_wheel_view.spin(i, fast)
	return i

# ---------------------------------------------------------------- marché noir
func _market() -> void:
	var now := Time.get_unix_time_from_system()
	var period := ShopLogic.market_period(now)
	var left := ShopLogic.market_seconds_left(now)
	body.add_child(_section("Marché Noir", "Cartes rares (Épique à Mythique) contre Poussière ou Cristaux · nouveau stock dans %dh%02d" % [left / 3600, (left % 3600) / 60]))
	var info := UI.label("Le marchand masqué ne vend chaque carte qu'une fois par rotation. Poussière : %d" % int(Profile.d.dust), 18, UI.ACCENT2, "body", 700)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(info)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 20)
	g.add_theme_constant_override("v_separation", 22)
	for o in ShopLogic.market_offers(period):
		var id: String = o.id
		var key := "M%d_%s" % [period, id]
		var v := UI.vbox(6)
		var h := CardView.holder(id, 0.66)
		h.get_meta("card").tapped.connect(func(_c): main.show_card(id))
		v.add_child(h)
		var owned: bool = Profile.owned(id) > 0
		v.add_child(UI.label(("Possédée" if owned else "NOUVELLE") + " · " + DB.rarity(DB.card(id).rarity).name, 16, UI.MUTED if owned else UI.GOOD, "body", 800, HORIZONTAL_ALIGNMENT_CENTER))
		if _bought_key(key):
			var bb := UI.button("Vendue", Color("3a3350"), 22, Vector2(0, 62), "ui_check")
			bb.disabled = true
			v.add_child(bb)
		else:
			for cur in ["dust", "crystals"]:
				var price := {cur: int(o[cur])}
				var b := UI.price_button(price, Color("4a2a6a") if cur == "dust" else Color("2a4a8a"), 22)
				b.custom_minimum_size.y = 60
				b.pressed.connect(func():
					if not Profile.pay(price):
						main.show_toast("Pas assez de %s." % Profile.cur_name(cur, 2), "error")
						return
					Profile.d.shop_once.append(key)
					var is_new := Profile.add_card(id)
					Profile.check_collection_rewards()
					Profile.save_game()
					Sfx.play("buy")
					main.show_toast("%s achetée au Marché Noir%s" % [DB.card(id).name, " (nouvelle !)" if is_new else ""], "reward")
					_build())
				v.add_child(b)
		g.add_child(v)
	body.add_child(g)
