extends Control
## Accueil : logo, carte vedette, ouverture de booster, combat, missions, événement, récompense quotidienne.

var main: Control
var showcase: Control
var _show_card: CardView
var _t := 0.0

func setup(_p: Dictionary) -> void:
	main = get_meta("main")
	Profile.refresh_quests()
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var v := UI.vbox(18)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 26)
	pad.add_theme_constant_override("margin_top", 14)
	pad.add_theme_constant_override("margin_bottom", 30)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(pad)
	var col := UI.vbox(18)
	pad.add_child(col)

	# logo
	var logo := UI.label("CARDVERSE", 74, Color("fff2d0"), "title", 700, HORIZONTAL_ALIGNMENT_CENTER)
	UI.outline(logo, 14, Color("2a0d4a"))
	logo.add_theme_constant_override("shadow_offset_y", 6)
	logo.add_theme_color_override("font_shadow_color", Color(0.6, 0.2, 1.0, 0.6))
	col.add_child(logo)
	var sub := UI.label("ULTIMATE  TCG  COLLECTION", 22, Color("c9b3ff"), "serif", 700, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(sub)

	# vitrine : la carte la plus rare possédée flotte au centre
	showcase = Control.new()
	showcase.custom_minimum_size = Vector2(0, 430)
	col.add_child(showcase)
	var best := _best_card()
	if best != "":
		var c := DB.card(best)
		var glow := UI.glow_rect(DB.rarity_color(c.rarity) * Color(1, 1, 1, 0.55), Vector2(560, 560), 1.6, 10.0)
		glow.position = Vector2(334 - 280, 215 - 280)
		showcase.add_child(glow)
		_show_card = CardView.make(best, 0.62, _best_variant(best))
		_show_card.position = Vector2(334 - CardView.W * 0.31, 8)
		showcase.add_child(_show_card)
		_show_card.tapped.connect(func(_v): main.show_card(best, _best_variant(best)))
		var cap := UI.label("Ta carte la plus précieuse", 20, UI.MUTED, "body", 600, HORIZONTAL_ALIGNMENT_CENTER)
		col.add_child(cap)
	# bouton principal : booster
	var free := Profile.total_free()
	var open_b := UI.button("OUVRIR UN BOOSTER", Color("7b3dff"), 34, Vector2(0, 112), "ui_gift")
	col.add_child(open_b)
	open_b.pressed.connect(func(): main.goto("shop", {"tab": "boosters"}))
	if free > 0:
		var bd := UI.badge("%d GRATUIT%s" % [free, "S" if free > 1 else ""], UI.GOOD, 20)
		bd.position = Vector2(470, -14)
		open_b.add_child(bd)
	var row := UI.hbox(16)
	var fight := UI.button("COMBAT", Color("d8452f"), 30, Vector2(0, 100), "ui_battle")
	fight.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fight.pressed.connect(func(): main.goto("battle_select"))
	row.add_child(fight)
	var miss := UI.button("MISSIONS", Color("1e9e8a"), 30, Vector2(0, 100), "ui_missions")
	miss.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	miss.pressed.connect(func(): main.goto("missions"))
	row.add_child(miss)
	var n := Profile.pending_rewards()
	if n > 0:
		var bd2 := UI.badge(str(n), UI.BAD, 22)
		bd2.position = Vector2(270, -12)
		miss.add_child(bd2)
	col.add_child(row)
	col.add_child(_new_cards_banner())
	var row2 := UI.hbox(16)
	var forge_b := UI.button("ATELIER", Color("8a3ad1"), 28, Vector2(0, 92), "ui_star")
	forge_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	forge_b.pressed.connect(func(): main.goto("forge"))
	row2.add_child(forge_b)
	var pass_b := UI.button("PASSE", Color("b8842a"), 28, Vector2(0, 92), "ui_trophy")
	pass_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pass_b.pressed.connect(func(): main.goto("season"))
	row2.add_child(pass_b)
	var pp := Profile.pass_pending()
	if pp > 0:
		var bd3 := UI.badge(str(pp), UI.BAD, 22)
		bd3.position = Vector2(270, -12)
		pass_b.add_child(bd3)
	col.add_child(row2)
	# événement
	var ev := DB.active_event()
	if not ev.is_empty():
		col.add_child(_event_banner(ev))
	# progression de collection
	var cp := UI.panel(Color(0.08, 0.05, 0.16, 0.85))
	var cv := UI.vbox(8)
	var ch := UI.hbox()
	ch.add_child(UI.icon_rect("ui_album", 40, UI.ACCENT2))
	ch.add_child(UI.expand(UI.label("Collection Genèse", 26, UI.TEXT, "body", 800)))
	ch.add_child(UI.label("%d / %d" % [Profile.unique_count(), DB.card_order.size()], 26, UI.GOLD, "num", 400))
	cv.add_child(ch)
	cv.add_child(UI.progress(Profile.completion(), UI.ACCENT2, 18))
	cp.add_child(cv)
	var cb := Button.new()
	cb.flat = true
	cb.set_anchors_preset(Control.PRESET_FULL_RECT)
	cb.pressed.connect(func(): main.goto("collection"))
	cp.add_child(cb)
	col.add_child(cp)
	# connexion quotidienne, tutoriel, nouveautés
	if Profile.d.get("pending_gift8", false):
		_gift8_popup.call_deferred()
	elif Profile.d.get("pending_gift", false):
		_gift_popup.call_deferred()
	elif Profile.d.get("pending_gift7", false):
		_gift7_popup.call_deferred()
	elif Profile.d.get("pending_gift6", false):
		_gift6_popup.call_deferred()
	elif not Profile.d.get("tutorial_done", true):
		_tutorial.call_deferred(0)
	elif Profile.login_available():
		_login_popup.call_deferred()
	elif Profile.d.get("seen_version", "0.5") < "0.4":
		_news.call_deferred()

func _event_banner(ev: Dictionary) -> Control:
	var p := PanelContainer.new()
	var st := UI.box(Color(ev.color).darkened(0.55), 24, Color(ev.color), 3, 8)
	st.content_margin_left = 20
	st.content_margin_right = 20
	st.content_margin_top = 16
	st.content_margin_bottom = 16
	p.add_theme_stylebox_override("panel", st)
	var h := UI.hbox(16)
	var art := TextureRect.new()
	var at := AtlasTexture.new()
	at.atlas = DB.card_art("f006")
	at.region = Rect2(60, 60, 330, 300)
	art.texture = at
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.custom_minimum_size = Vector2(130, 118)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	h.add_child(art)
	var v := UI.vbox(4)
	v.add_child(UI.label("ÉVÉNEMENT", 18, Color(ev.color).lightened(0.4), "body", 800))
	var t := UI.label(ev.name, 30, Color.WHITE, "serif", 800)
	UI.outline(t, 5)
	v.add_child(t)
	var d := UI.label("Jusqu'au %s" % UI.date_fr(ev.end), 18, UI.MUTED, "body", 600)
	v.add_child(d)
	h.add_child(UI.expand(v))
	h.add_child(UI.icon_rect("ui_flame", 50, Color(ev.color)))
	p.add_child(h)
	var b := Button.new()
	b.flat = true
	b.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.pressed.connect(func(): main.goto("events"))
	UI.juice(b)
	p.add_child(b)
	return p

func _best_card() -> String:
	var best := ""
	var bi := -1
	for id in Profile.d.collection:
		var i := DB.rarity_index(DB.card(id).rarity) * 100 + DB.power_of(id)
		if i > bi:
			bi = i
			best = id
	return best

func _best_variant(id: String) -> String:
	var vs: Dictionary = Profile.entry(id).get("variants", {})
	for v in ["secret", "prisma", "animated", "chroma", "alt", "fullart", "holo"]:
		if vs.has(v):
			return v
	return ""

func _process(delta: float) -> void:
	_t += delta
	if _show_card:
		_show_card.position.y = 8 + sin(_t * 1.6) * 8
		_show_card.rotation = sin(_t * 0.9) * 0.025
		_show_card.set_tilt(Vector2(sin(_t * 0.7), cos(_t * 0.5)) * 0.6)

func _login_popup() -> void:
	var cal: Array = DB.progression.login_calendar
	var day := int(Profile.d.login.get("day", 0)) % cal.size()
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	for i in cal.size():
		var p := UI.panel(UI.PANEL2 if i != day else Color("4a2a8a"), 16, UI.GOLD if i == day else UI.LINE, 3 if i == day else 1)
		p.custom_minimum_size = Vector2(140, 120)
		var v := UI.vbox(2)
		v.add_child(UI.label("Jour %d" % (i + 1), 18, UI.MUTED if i != day else Color.WHITE, "body", 800, HORIZONTAL_ALIGNMENT_CENTER))
		var r: Dictionary = cal[i]
		for k in r:
			var txt := "Booster" if k == "booster" else "%d %s" % [int(r[k]), Profile.cur_name(k, int(r[k]))]
			v.add_child(UI.label(txt, 18, UI.GOLD if i == day else UI.TEXT, "body", 700, HORIZONTAL_ALIGNMENT_CENTER))
		if i < day:
			v.add_child(UI.icon_rect("ui_check", 28, UI.GOOD))
		p.add_child(v)
		g.add_child(p)
	main.modal("Récompense quotidienne", g, [["Récupérer", UI.GOOD, func():
		Profile.claim_login()
		if is_instance_valid(self):
			main.goto("home", {"r": 1})]])

const TUTO := [
	["Bienvenue dans le Cardverse !", "Collectionne des centaines de créatures, ouvre des boosters et affronte d'autres invocateurs en duel stratégique.\n\nTu commences avec un deck de départ et 3 boosters gratuits."],
	["Les boosters", "Boutique > Boosters : fais tourner le paquet, glisse le doigt le long du haut pour le déchirer, puis touche chaque carte pour la retourner. Plus la rareté est haute, plus la révélation est spectaculaire."],
	["Les raretés", "15 raretés, de Commune à ??? ! Chaque niveau possède son cadre, ses effets et ses sons. Le bouton i de chaque booster affiche les probabilités exactes, et une garantie te protège de la malchance."],
	["Le combat", "Chaque tour, ton énergie augmente (max 10). Touche une carte puis JOUER. Touche une créature prête (contour vert) puis une cible pour attaquer. Les créatures avec Garde protègent leur leader, et un élément favorable inflige des dégâts x1,5. Réduis le leader adverse à 0 PV !"],
	["Collection et progression", "L'Album montre tes cartes et les silhouettes de celles qui te manquent. L'Atelier fait évoluer tes créatures avec la Poussière d'étoile. Missions, succès et Passe de saison récompensent chaque partie. Bonne chance !"],
]

func _tutorial(step: int) -> void:
	if step >= TUTO.size():
		Profile.d.tutorial_done = true
		Profile.d.seen_version = "0.4"
		Profile.save_game()
		if Profile.login_available():
			_login_popup()
		return
	var l := UI.label(TUTO[step][1], 24, UI.TEXT, "body", 600)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(560, 0)
	var v := UI.vbox(10)
	v.add_child(l)
	v.add_child(UI.label("%d / %d" % [step + 1, TUTO.size()], 18, UI.MUTED, "body", 700, HORIZONTAL_ALIGNMENT_CENTER))
	var btns := [["Suivant" if step < TUTO.size() - 1 else "C'est parti !", UI.ACCENT, func(): _tutorial(step + 1)]]
	if step == 0:
		btns.push_front(["Passer", Color("4a3a6a"), func(): _tutorial(TUTO.size())])
	main.modal(TUTO[step][0], v, btns)

func _news() -> void:
	var l := UI.label("• DISPLAYS (Boutique > Displays) : une caisse de 12 à 18 boosters à ouvrir un par un, avec un Légendaire garanti (Mythique pour le Multivers). Tu peux t'arrêter et reprendre plus tard.\n• COFFRETS : une carte promo précise garantie (Vorrak Secret Art, Séléné Full Art, Gaïarch Full Art, Licorne Prismatique), des boosters et des jetons spéciaux, avec une ouverture animée.\n• BOOSTERS PAR GÉNÉRATION : Gén. 1 Genèse, Gén. 2 Éclipse, Gén. 3 Âge Primitif et Multivers (toutes générations).\n• BOOSTERS PAR TYPE : un booster pour chacun des 10 éléments.", 20, UI.TEXT, "body", 600)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(560, 0)
	main.modal("Nouveautés 0.4", l, [["Génial !", UI.ACCENT, func():
		Profile.d.seen_version = "0.4"
		Profile.save_game()]])

## Bannière « Nouvelles cartes » : aperçu de la dernière génération, ouvre ses boosters.
func _new_cards_banner() -> Control:
	var last: Dictionary = DB.sets[-1]
	var p := PanelContainer.new()
	var st := UI.box(Color("12384a"), 24, Color("4aa3c8"), 3, 8)
	st.content_margin_left = 16
	st.content_margin_right = 16
	st.content_margin_top = 12
	st.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", st)
	var v := UI.vbox(8)
	var h := UI.hbox(8)
	var t := UI.label("NOUVEAU · GÉN. %d %s" % [int(last.gen), last.name.to_upper()], 24, Color("bfefff"), "serif", 800)
	UI.outline(t, 5)
	h.add_child(UI.expand(t))
	h.add_child(UI.badge("NEW", UI.BAD, 18))
	v.add_child(h)
	var row := UI.hbox(6)
	var picks := []
	for id in last.cards:
		if DB.rarity_index(DB.card(id).rarity) >= DB.rarity_index("SR"):
			picks.append(id)
	picks.sort_custom(func(a, b): return DB.rarity_index(DB.card(a).rarity) > DB.rarity_index(DB.card(b).rarity))
	for id in picks.slice(0, 5):
		var hld := CardView.holder(id, 0.25, "", "preview")
		hld.get_meta("card").tapped.connect(func(_c): main.show_card(id, "", []))
		row.add_child(hld)
	v.add_child(row)
	v.add_child(UI.label("%d cartes à découvrir · touche pour voir les boosters" % last.cards.size(), 17, UI.MUTED, "body", 600))
	p.add_child(v)
	var b := Button.new()
	b.flat = true
	b.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.pressed.connect(func(): main.goto("shop", {"tab": "boosters"}))
	p.add_child(b)
	return p

func _gift_popup() -> void:
	var l := UI.label("Merci de jouer à CARDVERSE !\n\nPour découvrir les nouvelles générations, tu reçois :\n• 1 Booster Éclipse (Gén. 2)\n• 2 Boosters Âge Primitif (Gén. 3)\n• 3 Boosters Mécanica (Gén. 4)\n\nIls t'attendent dans la Boutique (bouton GRATUIT).\n\nAstuce : le Booster Genèse ne contient que la Gén. 1. Pour les nouvelles cartes, ouvre les boosters de leur génération, Multivers ou par type. Le bouton « Aperçu » de l'Album montre toutes les cartes.", 20, UI.TEXT, "body", 600)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(560, 0)
	main.modal("Cadeau : nouvelles cartes !", l, [["Plus tard", Color("4a3a6a"), func():
		Profile.d.pending_gift = false
		Profile.d.seen_version = "0.5"
		Profile.save_game()], ["Ouvrir mes boosters", UI.GOOD.darkened(0.2), func():
		Profile.d.pending_gift = false
		Profile.d.seen_version = "0.5"
		Profile.save_game()
		main.goto("shop", {"tab": "boosters"})]])

func _gift6_popup() -> void:
	var l := UI.label("Nouveautés 0.6 :\n• GÉNÉRATION 5 « ROYAUME DES SONGES » : 47 cartes de fées, rêves et cauchemars, avec la mécanique SOMMEIL (la cible ne peut plus attaquer pendant 2 tours).\n• DISPLAYS EN 3D : fais pivoter la caisse au doigt, déchire le scellé, puis sors les boosters un par un. La caisse se vide au fur et à mesure.\n\nCadeau : 3 Boosters Songes t'attendent dans la Boutique (bouton GRATUIT).", 20, UI.TEXT, "body", 600)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(560, 0)
	main.modal("Royaume des Songes", l, [["Plus tard", Color("4a3a6a"), func():
		Profile.d.pending_gift6 = false
		Profile.save_game()], ["Ouvrir mes boosters", UI.GOOD.darkened(0.2), func():
		Profile.d.pending_gift6 = false
		Profile.save_game()
		main.goto("shop", {"tab": "boosters"})]])

func _gift7_popup() -> void:
	var l := UI.label("Nouveautés 0.7 :\n• NOUVELLE RARETÉ « GOD », la plus haute de toutes : cadre en or massif, contour d'or liquide animé, éclats, rayons divins et révélation spéciale.\n• GÉNÉRATION 6 « PANTHÉON CÉLESTE » : 47 cartes de dieux, titans et bêtes sacrées, dont 3 cartes GOD (Zeus, Solaris, Æther), et la mécanique RÉSURRECTION.\n• LA TOUR DES DIEUX (onglet Combat) : 20 étages de défis avec des règles spéciales et des boss. Une carte GOD est garantie au sommet !\n\nCadeau : 3 Boosters Panthéon t'attendent dans la Boutique.", 20, UI.TEXT, "body", 600)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(560, 0)
	main.modal("L'ère des Dieux", l, [["La Tour", Color("c89a20"), func():
		Profile.d.pending_gift7 = false
		Profile.d.pending_gift6 = false
		Profile.save_game()
		main.goto("tower")], ["Mes boosters", UI.GOOD.darkened(0.2), func():
		Profile.d.pending_gift7 = false
		Profile.d.pending_gift6 = false
		Profile.save_game()
		main.goto("shop", {"tab": "boosters"})]])

func _gift8_popup() -> void:
	var l := UI.label("Nouveautés 0.8 :\n• 91 NOUVELLES CARTES : Gén. 7 « Corsaires Astraux » et Gén. 8 « Jungle Sauvage », avec une nouvelle carte GOD (Gaïarugh).\n• 3 NOUVELLES RARETÉS : Néon (tubes lumineux), Infernale (flammes) et Mirage (reflets ondulants).\n• NOUVEAUX EFFETS : Brûlure, Métamorphose et Copie.\n• NOUVELLE ÉDITION : Booster Prestige (8 cartes, variante garantie) et Mini-Booster.\n• BOUTIQUE : Roue de la Fortune (1 tour gratuit par jour), Marché Noir et Packs groupés.\n• SAISON 2 : Corsaires des Étoiles, avec un dos et un plateau exclusifs.\n\nCadeau : 2 Boosters Corsaires, 2 Boosters Jungle et 1 Booster Prestige t'attendent dans la Boutique.", 19, UI.TEXT, "body", 600)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(560, 0)
	var close := func():
		Profile.d.pending_gift8 = false
		for k in ["pending_gift", "pending_gift6", "pending_gift7"]:
			Profile.d[k] = false
		Profile.d.seen_version = "0.8"
		Profile.save_game()
	main.modal("Corsaires & Jungle", l, [["La Roue", Color("c89a20"), func():
		close.call()
		main.goto("shop", {"tab": "wheel"})], ["Mes boosters", UI.GOOD.darkened(0.2), func():
		close.call()
		main.goto("shop", {"tab": "boosters"})]])
