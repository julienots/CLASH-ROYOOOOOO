extends Control
## La Tour des Dieux : 20 étages de combats de difficulté croissante, avec règles spéciales,
## boss aux étages 5/10/15/20 et une carte GOD garantie au sommet.

var main: Control
var sc: ScrollContainer

func setup(_p: Dictionary) -> void:
	main = get_meta("main")
	var root := UI.vbox(10)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 18
	root.offset_right = -18
	root.offset_top = 12
	add_child(root)
	var head := UI.hbox(10)
	var back := UI.icon_button("ui_back", 60)
	back.pressed.connect(func(): main.goto("battle_select"))
	head.add_child(back)
	var t := UI.label("La Tour des Dieux", 38, UI.GOLD, "serif", 800)
	UI.outline(t, 6)
	head.add_child(UI.expand(t))
	root.add_child(head)
	var T: Dictionary = Profile.d.tower
	var best := int(T.get("best", 0))
	var total: int = DB.tower.floors.size()
	var pl := UI.label("Étages franchis : %d / %d · carte GOD garantie au sommet" % [best, total], 20, UI.TEXT, "body", 700)
	root.add_child(pl)
	root.add_child(UI.progress(float(best) / total, UI.GOLD, 14))
	sc = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	var v := UI.vbox(10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	# du sommet (20) vers la base (1)
	var cur_node: Control = null
	for i in range(total - 1, -1, -1):
		var fl: Dictionary = DB.tower.floors[i]
		var row := _floor_row(fl, best)
		v.add_child(row)
		if int(fl.floor) == mini(best + 1, total):
			cur_node = row
	if cur_node:
		_scroll_to.call_deferred(cur_node)

func _scroll_to(n: Control) -> void:
	await get_tree().process_frame
	sc.scroll_vertical = int(maxf(0, n.position.y - 200))

func _floor_row(fl: Dictionary, best: int) -> Control:
	var n := int(fl.floor)
	var done := n <= best
	var current := n == best + 1
	var locked := n > best + 1
	var boss: bool = fl.boss
	var col := Color("e8b830") if boss else (UI.GOOD if done else (UI.ACCENT if current else Color("3a3350")))
	var p := PanelContainer.new()
	var st := UI.box(col.darkened(0.72 if not current else 0.55), 22, col, 4 if current or boss else 2, 8 if current else 4)
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 12
	st.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", st)
	if locked:
		p.modulate = Color(0.7, 0.7, 0.75)
	var h := UI.hbox(12)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(84, 84)
	badge.add_theme_stylebox_override("panel", UI.box(col.darkened(0.2), 42, Color.WHITE if current else col.lightened(0.3), 3))
	var nl := UI.label(str(n), 38, Color.WHITE, "num", 400, HORIZONTAL_ALIGNMENT_CENTER)
	UI.outline(nl, 6)
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(nl)
	h.add_child(badge)
	var v := UI.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_l := UI.label(("BOSS · " if boss else "") + fl.name, 24 if boss else 22, Color.WHITE if not boss else UI.GOLD, "body", 800)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(name_l)
	var els := UI.hbox(4)
	for e in fl.elements:
		els.add_child(UI.icon_rect("el_" + e, 26))
	els.add_child(UI.label("  %d PV · IA %s" % [int(fl.hp), ["facile", "normale", "difficile"][int(fl.difficulty)]], 16, UI.MUTED, "body", 700))
	v.add_child(els)
	for mt in fl.mods_text:
		v.add_child(UI.label("Règle : " + mt, 16, Color("ffb3a0"), "body", 700))
	var rp := []
	for k in fl.reward:
		match k:
			"booster": rp.append(DB.booster(fl.reward.booster).get("name", "Booster"))
			"god_card": rp.append("CARTE GOD")
			"xp": rp.append("%d XP" % int(fl.reward.xp))
			_: rp.append("%d %s" % [int(fl.reward[k]), Profile.cur_name(k, int(fl.reward[k]))])
	var rl := UI.label(" · ".join(rp), 16, UI.GOLD, "body", 700)
	rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(rl)
	h.add_child(v)
	if done:
		var again := UI.button("Rejouer", Color("2f8a5a"), 18, Vector2(110, 64))
		again.pressed.connect(func(): _fight(fl))
		h.add_child(again)
	elif current:
		var go := UI.button("COMBATTRE", col.darkened(0.1), 20, Vector2(150, 76), "ui_battle")
		go.pressed.connect(func(): _fight(fl))
		h.add_child(go)
	else:
		h.add_child(UI.icon_rect("ui_lock", 40, UI.MUTED))
	p.add_child(h)
	return p

func _fight(fl: Dictionary) -> void:
	var deck := Profile.active_deck()
	if not Profile.deck_valid(deck):
		main.show_toast("Ton deck doit contenir %d cartes que tu possèdes." % Profile.DECK_SIZE, "error")
		main.goto("decks")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("tour" + str(fl.floor))
	var cfg := {
		"deck": deck.cards.duplicate(), "leader": deck.leader,
		"enemy_deck": BattleAI.build_deck(fl.elements, rng, fl.max_rarity), "enemy_leader": fl.leader,
		"enemy_hp": int(fl.hp), "difficulty": int(fl.difficulty), "rewards_mult": 1.0 + int(fl.floor) * 0.05,
		"event": false, "board_colors": ["140c04", "5a3a10", "3a2060"] if fl.boss else ["0b0716", "3a2a10", "1a2a50"],
		"tower_floor": int(fl.floor), "mods": fl.mods,
	}
	var bv = load("res://scripts/ui/battle_view.gd").new()
	bv.setup(cfg)
	Sfx.play("whoosh")
	main.open_overlay(bv, true)

func refresh() -> void:
	for c in get_children():
		c.queue_free()
	setup({})
