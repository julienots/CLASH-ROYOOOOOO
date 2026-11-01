extends Control
## Paramètres : sons, musique, animations rapides, réinitialisation, crédits.

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
	var t := UI.label("Paramètres", 40, UI.GOLD, "serif", 800)
	UI.outline(t, 6)
	v.add_child(t)
	var st: Dictionary = Profile.d.settings
	for opt in [["sfx", "Effets sonores"], ["music", "Musique"], ["fast", "Animations de combat rapides"]]:
		var p := UI.panel(Color(0.1, 0.06, 0.2, 0.9))
		var h := UI.hbox(10)
		h.add_child(UI.expand(UI.label(opt[1], 26, Color.WHITE, "body", 700)))
		var cb := CheckButton.new()
		cb.button_pressed = st.get(opt[0], opt[0] != "fast")
		cb.focus_mode = Control.FOCUS_NONE
		cb.scale = Vector2(1.6, 1.6)
		var key: String = opt[0]
		cb.toggled.connect(func(on):
			st[key] = on
			Profile.save_game()
			if key == "music":
				Sfx.refresh_music()
			Sfx.play("click"))
		h.add_child(cb)
		h.add_child(UI.spacer(0, 40))
		p.add_child(h)
		v.add_child(p)
	var reset := UI.button("Réinitialiser la progression", Color("8a2a3a"), 24, Vector2(0, 84), "ui_recycle")
	reset.pressed.connect(func():
		var l := UI.label("Toute ta collection et ta progression seront effacées. Cette action est irréversible.", 22, UI.TEXT, "body", 600)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		main.modal("Réinitialiser ?", l, [["Annuler", UI.ACCENT, null], ["Effacer", Color("b8283c"), func():
			Profile.reset()
			main.goto("home", {"reset": 1})]]))
	v.add_child(reset)
	var cr := UI.panel(Color(0.08, 0.05, 0.16, 0.9))
	var cv := UI.vbox(6)
	cv.add_child(UI.label("CARDVERSE · version 0.2", 24, UI.GOLD, "serif", 800))
	var txt := UI.label("Jeu développé avec Godot 4.3. Illustrations pixel art, cadres, icônes, sons et musiques générés par les outils du projet (dossier tools/). Polices Cinzel, Exo 2 et Lilita One sous licence SIL OFL.\n\nSauvegarde locale : %s" % ProjectSettings.globalize_path(Profile.SAVE_PATH), 18, UI.MUTED, "body", 600)
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(txt)
	cr.add_child(cv)
	v.add_child(cr)
