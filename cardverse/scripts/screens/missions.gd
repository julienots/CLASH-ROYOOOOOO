extends Control
## Missions quotidiennes, hebdomadaires et succès.

var main: Control
var tab := "daily"
var body: VBoxContainer
var _tabs := {}

func setup(_p: Dictionary) -> void:
	main = get_meta("main")
	Profile.refresh_quests()
	var root := UI.vbox(12)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 18
	root.offset_right = -18
	root.offset_top = 12
	add_child(root)
	var t := UI.label("Missions", 40, UI.GOLD, "serif", 800)
	UI.outline(t, 6)
	root.add_child(t)
	var th := UI.hbox(8)
	for td in [["daily", "Quotidiennes"], ["weekly", "Hebdo"], ["ach", "Succès"]]:
		var b := Button.new()
		b.text = td[1]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 60)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_override("font", UI.font("body", 800))
		b.add_theme_font_size_override("font_size", 22)
		var k: String = td[0]
		b.pressed.connect(func(): Sfx.play("click"); tab = k; _build())
		_tabs[k] = b
		th.add_child(b)
	root.add_child(th)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	body = UI.vbox(12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(body)
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
		"daily":
			body.add_child(_note("Renouvelées chaque jour à minuit."))
			for q in Profile.daily_quests():
				body.add_child(_row(q.text, "", Profile.quest_progress(q, false), int(q.goal), q.reward, Profile.quest_claimed(q, false), func(): return Profile.claim_quest(q, false)))
		"weekly":
			body.add_child(_note("Renouvelées chaque lundi."))
			for q in DB.progression.weekly:
				body.add_child(_row(q.text, "", Profile.quest_progress(q, true), int(q.goal), q.reward, Profile.quest_claimed(q, true), func(): return Profile.claim_quest(q, true)))
		"ach":
			var done: int = Profile.d.achievements.size()
			body.add_child(_note("%d / %d succès débloqués" % [done, DB.progression.achievements.size()]))
			for a in DB.progression.achievements:
				body.add_child(_row(a.text, a.desc, Profile.achievement_progress(a), int(a.goal), a.reward, Profile.d.achievements.has(a.id), func(): return Profile.claim_achievement(a)))

func _note(t: String) -> Label:
	return UI.label(t, 19, UI.MUTED, "body", 600)

func _row(title: String, desc: String, prog: int, goal: int, rew: Dictionary, claimed: bool, claim: Callable) -> Control:
	var done := prog >= goal
	var p := UI.panel(Color(0.1, 0.06, 0.2, 0.9), 20, UI.GOLD if done and not claimed else UI.LINE, 3 if done and not claimed else 2)
	var h := UI.hbox(12)
	h.add_child(UI.icon_rect("ui_trophy" if desc != "" else "ui_missions", 54, UI.GOLD if done else UI.MUTED))
	var v := UI.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.label(title, 23, Color.WHITE, "body", 800))
	if desc != "":
		var d := UI.label(desc, 17, UI.MUTED, "body", 600)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(d)
	var ph := UI.hbox(8)
	var bar := UI.progress(float(prog) / goal, UI.GOOD if done else UI.ACCENT2, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.add_child(bar)
	ph.add_child(UI.label("%d/%d" % [mini(prog, goal), goal], 18, UI.TEXT, "num", 400))
	v.add_child(ph)
	var parts := []
	for k in rew:
		parts.append("+%d %s" % [int(rew[k]), "XP" if k == "xp" else Profile.cur_name(k, int(rew[k]))])
	v.add_child(UI.label(" · ".join(parts), 17, UI.GOLD, "body", 700))
	h.add_child(v)
	var b: Button
	if claimed:
		b = UI.button("Reçu", Color("3a3350"), 20, Vector2(124, 64), "ui_check")
		b.disabled = true
	else:
		b = UI.button("Récupérer", UI.GOOD.darkened(0.2) if done else Color("3a3350"), 18, Vector2(124, 64))
		b.disabled = not done
		b.pressed.connect(func():
			if claim.call():
				Sfx.play("buy")
				_build())
	h.add_child(b)
	p.add_child(h)
	return p

func refresh() -> void:
	_build()
