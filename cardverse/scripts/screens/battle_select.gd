extends Control
## Choix du mode de combat : IA (3 niveaux), boss d'événement ; modes en ligne affichés comme à venir.

var main: Control

const OPPONENTS := [
	{"name": "Apprenti Lumen", "desc": "Entraînement · IA facile", "leader": "sylva", "elements": ["nature", "lumiere"], "difficulty": 0, "max_rarity": "R", "hp": 22, "mult": 0.7, "color": "2f9e6a"},
	{"name": "Kaël le Vagabond", "desc": "Duel · IA normale", "leader": "thalassa", "elements": ["eau", "glace"], "difficulty": 1, "max_rarity": "E", "hp": 25, "mult": 1.0, "color": "2f7bd1"},
	{"name": "Archiviste Noctis", "desc": "Défi · IA difficile · 30 PV", "leader": "umbra", "elements": ["ombre", "neant"], "difficulty": 2, "max_rarity": "L", "hp": 30, "mult": 1.6, "color": "8a3ad1"},
]

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
	var t := UI.label("Combat", 40, UI.GOLD, "serif", 800)
	UI.outline(t, 6)
	v.add_child(t)
	# deck actif
	var deck := Profile.active_deck()
	var dp := UI.panel(Color(0.08, 0.05, 0.16, 0.9))
	var dh := UI.hbox(14)
	var ld := DB.leader(deck.leader)
	dh.add_child(UI.icon_rect("el_" + ld.element, 64))
	var dv := UI.vbox(2)
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dv.add_child(UI.label(deck.name, 26, Color.WHITE, "body", 800))
	var ok := Profile.deck_valid(deck)
	dv.add_child(UI.label("%s · %d/%d cartes%s" % [ld.name.split(",")[0], deck.cards.size(), Profile.DECK_SIZE, "" if ok else " · incomplet"], 19, UI.MUTED if ok else UI.BAD, "body", 600))
	dh.add_child(dv)
	var eb := UI.button("Modifier", Color("4a3a6a"), 22, Vector2(0, 64), "ui_deck")
	eb.pressed.connect(func(): main.goto("decks"))
	dh.add_child(eb)
	dp.add_child(dh)
	v.add_child(dp)
	v.add_child(UI.label("Contre l'IA", 26, UI.TEXT, "serif", 800))
	for i in OPPONENTS.size():
		v.add_child(_opp_row(OPPONENTS[i], i))
	var ev := DB.active_event()
	if not ev.is_empty():
		v.add_child(UI.label("Événement", 26, UI.TEXT, "serif", 800))
		var boss := {"name": ev.boss.name, "desc": "Boss de %s · gagne des %s" % [ev.name, ev.currency], "leader": ev.boss.leader, "elements": ev.boss.deck_elements, "difficulty": int(ev.boss.difficulty), "max_rarity": "M", "hp": int(ev.boss.hp), "mult": 1.5, "color": ev.color.trim_prefix("#"), "event": true}
		v.add_child(_opp_row(boss, 99))
	v.add_child(UI.label("En ligne", 26, UI.TEXT, "serif", 800))
	for o in [["Classé", "Affronte des joueurs et grimpe dans les ligues"], ["Amical", "Défie un ami avec un code"], ["Tournois", "Brackets hebdomadaires à 8 joueurs"]]:
		var p := UI.panel(Color(0.08, 0.06, 0.12, 0.85), 20, Color(1, 1, 1, 0.1), 2)
		var h := UI.hbox(12)
		h.add_child(UI.icon_rect("ui_globe", 52, UI.MUTED))
		var ov := UI.vbox(2)
		ov.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ov.add_child(UI.label(o[0], 24, UI.MUTED, "body", 800))
		var dl := UI.label(o[1], 17, UI.MUTED, "body", 600)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ov.add_child(dl)
		h.add_child(ov)
		h.add_child(UI.badge("BIENTÔT", Color("4a3a6a"), 18))
		p.add_child(h)
		v.add_child(p)
	var note := UI.label("Les modes en ligne nécessitent le serveur de jeu (étape 5 de la feuille de route) : ils ne sont pas simulés.", 17, UI.MUTED, "body", 600)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)

func _opp_row(o: Dictionary, idx: int) -> Control:
	var col := Color(o.color)
	var p := PanelContainer.new()
	var st := UI.box(col.darkened(0.7), 22, col, 3, 6)
	st.content_margin_left = 16
	st.content_margin_right = 16
	st.content_margin_top = 14
	st.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", st)
	var h := UI.hbox(14)
	var ld := DB.leader(o.leader)
	var art := TextureRect.new()
	var at := AtlasTexture.new()
	at.atlas = DB.card_art(ld.art)
	at.region = Rect2(90, 60, 270, 270)
	art.texture = at
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.custom_minimum_size = Vector2(96, 96)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	h.add_child(art)
	var v := UI.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.label(o.name, 26, Color.WHITE, "body", 800))
	var d := UI.label(o.desc, 18, UI.TEXT, "body", 600)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	var els := UI.hbox(4)
	for e in o.elements:
		els.add_child(UI.icon_rect("el_" + e, 30))
	v.add_child(els)
	h.add_child(v)
	var b := UI.button("JOUER", col.darkened(0.1), 24, Vector2(140, 76), "ui_play")
	b.pressed.connect(func(): start_with(o))
	h.add_child(b)
	p.add_child(h)
	return p

func start_battle(i: int) -> void:
	start_with(OPPONENTS[clampi(i, 0, OPPONENTS.size() - 1)])

func start_with(o: Dictionary) -> void:
	var deck := Profile.active_deck()
	if not Profile.deck_valid(deck):
		main.show_toast("Ton deck doit contenir %d cartes que tu possèdes." % Profile.DECK_SIZE, "error")
		main.goto("decks")
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var board_id: String = Profile.d.cosmetics.get("board", "board_default")
	var colors: Array = ["0b0716", "3a1466", "0d4070"]
	for c in load("res://scripts/screens/shop.gd").COSMETICS:
		if c.id == board_id and c.has("colors"):
			colors = c.colors
	var cfg := {
		"deck": deck.cards.duplicate(), "leader": deck.leader,
		"enemy_deck": BattleAI.build_deck(o.elements, rng, o.max_rarity), "enemy_leader": o.leader,
		"enemy_hp": int(o.hp), "difficulty": int(o.difficulty), "rewards_mult": float(o.mult),
		"event": o.get("event", false), "board_colors": colors,
	}
	var bv = load("res://scripts/ui/battle_view.gd").new()
	bv.setup(cfg)
	Sfx.play("whoosh")
	main.open_overlay(bv, true)
