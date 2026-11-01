extends Control
## Profil : nom, niveau, titre, statistiques, répartition des raretés et complétion par élément.

var main: Control

func setup(_p: Dictionary) -> void:
	main = get_meta("main")
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 20)
	sc.add_child(m)
	var v := UI.vbox(16)
	m.add_child(v)
	var d: Dictionary = Profile.d
	var head := UI.panel(Color(0.12, 0.07, 0.24, 0.92), 26, UI.GOLD, 3)
	var hv := UI.vbox(10)
	var nh := UI.hbox(10)
	var ne := LineEdit.new()
	ne.text = d.name
	ne.max_length = 18
	ne.custom_minimum_size = Vector2(0, 66)
	ne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ne.add_theme_font_override("font", UI.font("serif", 800))
	ne.add_theme_font_size_override("font_size", 32)
	ne.add_theme_stylebox_override("normal", UI.box(Color(0, 0, 0, 0.3), 14, UI.LINE, 2))
	ne.text_submitted.connect(func(s): _rename(s))
	ne.focus_exited.connect(func(): _rename(ne.text))
	nh.add_child(ne)
	nh.add_child(UI.label("Niv. %d" % int(d.level), 34, UI.GOLD, "num", 400))
	hv.add_child(nh)
	hv.add_child(UI.label(d.get("title", "Novice"), 22, UI.ACCENT2, "body", 800))
	var lo := Profile.xp_needed(int(d.level) - 1) if int(d.level) > 1 else 0
	var hi := Profile.xp_needed(int(d.level))
	hv.add_child(UI.progress(float(int(d.xp) - lo) / max(1, hi - lo), UI.GOLD, 16))
	hv.add_child(UI.label("%d / %d XP" % [int(d.xp) - lo, hi - lo], 18, UI.MUTED, "body", 600))
	head.add_child(hv)
	v.add_child(head)
	# statistiques
	var st: Dictionary = d.stats
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	var played := int(st.get("battles_played", 0))
	var won := int(st.get("battles_won", 0))
	for s in [["Combats gagnés", str(won)], ["Taux de victoire", ("%d %%" % int(100.0 * won / played)) if played > 0 else "—"],
			["Boosters ouverts", str(st.get("boosters_opened", 0))], ["Cartes uniques", "%d / %d" % [Profile.unique_count(), DB.card_order.size()]],
			["Variantes trouvées", str(st.get("variants_found", 0))], ["Évolutions", str(st.get("evolutions", 0))],
			["Points de classement", str(d.rank.get("points", 0))], ["Poussière d'étoile", str(d.get("dust", 0))]]:
		var p := UI.panel(Color(0.08, 0.05, 0.16, 0.9), 18)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pv := UI.vbox(2)
		pv.add_child(UI.label(s[0], 18, UI.MUTED, "body", 700))
		pv.add_child(UI.label(s[1], 32, Color.WHITE, "num", 400))
		p.add_child(pv)
		g.add_child(p)
	v.add_child(g)
	# raretés possédées
	v.add_child(UI.label("Raretés possédées", 26, UI.TEXT, "serif", 800))
	var rg := GridContainer.new()
	rg.columns = 3
	rg.add_theme_constant_override("h_separation", 10)
	rg.add_theme_constant_override("v_separation", 8)
	for r in DB.rarity_order:
		var have := 0
		var tot := 0
		for id in DB.card_order:
			if DB.card(id).rarity == r:
				tot += 1
				if Profile.owned(id) > 0:
					have += 1
		var l := UI.label("%s  %d/%d" % [DB.rarity(r).name, have, tot], 18, DB.rarity_color(r), "body", 800)
		UI.outline(l, 3)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rg.add_child(l)
	v.add_child(rg)
	v.add_child(UI.label("Classement", 26, UI.TEXT, "serif", 800))
	var note := UI.label("Les classements mondiaux et les ligues arriveront avec le serveur de jeu. Tes points de classement sont déjà comptabilisés localement.", 18, UI.MUTED, "body", 600)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)

func _rename(s: String) -> void:
	s = s.strip_edges()
	if s != "" and s != Profile.d.name:
		Profile.d.name = s
		Profile.save_game()
