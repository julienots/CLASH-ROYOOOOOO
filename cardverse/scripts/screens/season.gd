extends Control
## Passe de saison : 30 paliers, voie gratuite et voie Élite (débloquée avec des Cristaux gagnés en jeu).

var main: Control
var body: VBoxContainer

func setup(_p: Dictionary) -> void:
	main = get_meta("main")
	var root := UI.vbox(12)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 18
	root.offset_right = -18
	root.offset_top = 12
	add_child(root)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	body = UI.vbox(10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(body)
	_build()

func refresh() -> void:
	_build()

func _build() -> void:
	for c in body.get_children():
		c.queue_free()
	var S: Dictionary = DB.season
	var pd := Profile.pass_data()
	var tier := Profile.pass_tier()
	# en-tête
	var hp := PanelContainer.new()
	var st := UI.box(Color("2a1450"), 24, UI.GOLD, 3, 8)
	st.content_margin_left = 18
	st.content_margin_right = 18
	st.content_margin_top = 16
	st.content_margin_bottom = 16
	hp.add_theme_stylebox_override("panel", st)
	var hv := UI.vbox(8)
	var t := UI.label(S.name, 32, UI.GOLD, "serif", 800)
	UI.outline(t, 6)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(t)
	hv.add_child(UI.label("Se termine le %s · palier %d / %d" % [UI.date_fr(S.end), tier, S.tiers.size()], 19, UI.TEXT, "body", 700))
	var xp_in := int(pd.xp) % int(S.xp_per_tier) if tier < S.tiers.size() else int(S.xp_per_tier)
	hv.add_child(UI.progress(float(xp_in) / int(S.xp_per_tier), UI.GOLD, 16))
	hv.add_child(UI.label("%d / %d XP pour le prochain palier (l'XP des combats, boosters et missions compte)" % [xp_in, int(S.xp_per_tier)], 16, UI.MUTED, "body", 600))
	if not pd.elite:
		var eb := UI.price_button(S.elite_price, Color("b8842a"), 24)
		eb.text = "Débloquer le Passe Élite · %d" % int(S.elite_price.crystals)
		eb.pressed.connect(func():
			if Profile.buy_elite():
				Sfx.play("reveal_3")
				main.show_toast("Passe Élite débloqué !", "reward")
				_build()
			else:
				main.show_toast("Pas assez de Cristaux.", "error"))
		hv.add_child(eb)
		var nt := UI.label("Le Passe Élite s'achète avec des Cristaux gagnés en jeu (pas d'argent réel).", 16, UI.ACCENT2, "body", 600)
		nt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hv.add_child(nt)
	else:
		hv.add_child(UI.label("PASSE ÉLITE ACTIF", 22, UI.GOLD, "body", 800))
	var all_b := UI.button("Tout récupérer", UI.GOOD.darkened(0.2), 22, Vector2(0, 64), "ui_gift")
	all_b.disabled = Profile.pass_pending() == 0
	all_b.pressed.connect(func():
		for k in range(1, tier + 1):
			Profile.claim_pass(k, false)
			if pd.elite:
				Profile.claim_pass(k, true)
		Profile.save_game()
		Sfx.play("buy")
		_build())
	hv.add_child(all_b)
	hp.add_child(hv)
	body.add_child(hp)
	var head := UI.hbox(10)
	head.add_child(UI.spacer(0, 70))
	head.add_child(UI.expand(UI.label("Gratuit", 20, UI.TEXT, "body", 800, HORIZONTAL_ALIGNMENT_CENTER)))
	head.add_child(UI.expand(UI.label("Élite", 20, UI.GOLD, "body", 800, HORIZONTAL_ALIGNMENT_CENTER)))
	body.add_child(head)
	for td in S.tiers:
		body.add_child(_row(td, tier, pd))

func _row(td: Dictionary, tier: int, pd: Dictionary) -> Control:
	var n := int(td.tier)
	var reached := n <= tier
	var h := UI.hbox(10)
	var num := UI.badge(str(n), UI.GOLD.darkened(0.3) if reached else Color("3a3350"), 24)
	num.custom_minimum_size = Vector2(70, 0)
	num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(num)
	for elite in [false, true]:
		var rew: Dictionary = td.elite if elite else td.free
		var claimed: bool = n in (pd.elite_claimed if elite else pd.free)
		var locked: bool = elite and not pd.elite
		var p := UI.panel(Color(0.12, 0.08, 0.04, 0.9) if elite else Color(0.08, 0.06, 0.16, 0.9), 16, UI.GOLD if (reached and not claimed and not locked) else UI.LINE, 2)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := UI.hbox(6)
		var ic := "coin"
		var txt := ""
		for k in rew:
			match k:
				"booster":
					ic = "ui_gift"
					txt = DB.booster(rew.booster).get("name", "Booster")
				"cosmetic":
					ic = "ui_star"
					txt = "Dos Éclipse (exclusif)"
				_:
					if txt == "":
						ic = {"coins": "coin", "crystals": "crystal", "tokens": "token", "dust": "dust", "event": "event"}.get(k, "coin")
						txt = "%d %s" % [int(rew[k]), Profile.cur_name(k, int(rew[k]))]
					else:
						txt += " + %d %s" % [int(rew[k]), Profile.cur_name(k, int(rew[k]))]
		v.add_child(UI.icon_rect(ic, 40))
		var l := UI.label(txt, 16, UI.TEXT if not locked else UI.MUTED, "body", 700)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(l)
		if claimed:
			v.add_child(UI.icon_rect("ui_check", 30, UI.GOOD))
		elif locked:
			v.add_child(UI.icon_rect("ui_lock", 28, UI.MUTED))
		elif reached:
			var b := UI.button("OK", UI.GOOD.darkened(0.2), 18, Vector2(64, 52))
			var el: bool = elite
			b.pressed.connect(func():
				if Profile.claim_pass(n, el):
					Profile.save_game()
					Sfx.play("buy")
					_build())
			v.add_child(b)
		p.add_child(v)
		h.add_child(p)
	return h
