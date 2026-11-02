extends Control
## Display en 3D : une caisse modélisée qu'on fait pivoter au doigt. Le scellé se déchire et le couvercle s'ouvre,
## puis on choisit un booster dans la caisse : il s'en extrait et s'ouvre. La caisse se vide au fur et à mesure,
## et la rareté garantie tombe au plus tard au dernier booster.

const BW := 2.0     # largeur de la caisse
const BD := 1.2     # profondeur
const BH := 0.62    # hauteur des parois (les boosters dépassent)
const WT := 0.04    # épaisseur des parois

var idx := 0
var dsp: Dictionary
var dd: Dictionary
var booster: Dictionary
var busy := false
var info: Label
var hint: Label
var _t := 0.0

var vpc: SubViewportContainer
var vp: SubViewport
var cam: Camera3D
var rig: Node3D
var lid_pivot: Node3D
var inner_light: OmniLight3D
var packs: Array = []
var _yaw := 0.0
var _yaw_target := -0.25
var _press := Vector2(-1, -1)
var _dragging := false

func setup(i: int) -> void:
	idx = i
	dsp = Profile.d.displays[i]
	dd = DB.product("displays", dsp.id)
	booster = DB.booster(dd.booster)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var col := Color(dd.color)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/menu_bg.gdshader")
	m.set_shader_parameter("c1", Color(0.03, 0.02, 0.06))
	m.set_shader_parameter("c2", col.darkened(0.6))
	m.set_shader_parameter("c3", col.darkened(0.4))
	m.set_shader_parameter("res", size)
	bg.material = m
	add_child(bg)
	var glow := UI.glow_rect(Color(col, 0.35), Vector2(1000, 1000), 1.6, 10.0)
	glow.position = size / 2 - Vector2(500, 520)
	add_child(glow)
	# scène 3D
	vpc = SubViewportContainer.new()
	vpc.stretch = true
	vpc.position = Vector2(0, 150)
	vpc.size = Vector2(size.x, 820)
	vpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vpc)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vpc.add_child(vp)
	_build_scene()
	# interface
	var title := UI.label(dd.name, 42, Color.WHITE, "serif", 800, HORIZONTAL_ALIGNMENT_CENTER)
	UI.outline(title, 10)
	title.position = Vector2(20, 46)
	title.size = Vector2(size.x - 130, 60)
	UI.fit(title, size.x - 140, 42, 22)
	add_child(title)
	info = UI.label("", 22, UI.GOLD, "body", 800, HORIZONTAL_ALIGNMENT_CENTER)
	UI.outline(info, 6)
	info.position = Vector2(0, 106)
	info.size = Vector2(size.x, 34)
	add_child(info)
	hint = UI.label("", 21, UI.TEXT, "body", 700, HORIZONTAL_ALIGNMENT_CENTER)
	UI.outline(hint, 5)
	hint.position = Vector2(20, size.y - 230)
	hint.size = Vector2(size.x - 40, 30)
	add_child(hint)
	var next := UI.button("Ouvrir le suivant", col.darkened(0.15), 26, Vector2(380, 92), "ui_gift")
	next.position = Vector2(size.x / 2 - 190, size.y - 170)
	next.name = "next"
	next.pressed.connect(func():
		if not dsp.get("lid", false):
			_open_lid()
		elif not packs.is_empty():
			_pull(packs[packs.size() - 1]))
	add_child(next)
	var close := UI.icon_button("ui_close", 70)
	close.position = Vector2(size.x - 92, 20)
	close.pressed.connect(_close)
	add_child(close)
	_refresh()
	Sfx.play("whoosh")
	# entrée : la caisse tombe du ciel
	rig.position.y = 3.0
	var t := create_tween()
	t.tween_property(rig, "position:y", 0.0, 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

# ---------------------------------------------------------------- construction 3D
func _mat(tex: Texture2D = null, col := Color.WHITE, alpha := false) -> StandardMaterial3D:
	var mt := StandardMaterial3D.new()
	mt.albedo_color = col
	if tex:
		mt.albedo_texture = tex
		mt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if alpha:
		mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mt.alpha_scissor_threshold = 0.5
		mt.cull_mode = BaseMaterial3D.CULL_DISABLED
	mt.roughness = 0.55
	return mt

func _box(sz: Vector3, pos: Vector3, mt: Material, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mt
	parent.add_child(mi)
	return mi

func _quad(sz: Vector2, pos: Vector3, rot: Vector3, mt: Material, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = sz
	mi.mesh = qm
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mt
	parent.add_child(mi)
	return mi

func _build_scene() -> void:
	var col := Color(dd.color)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.72, 0.9)
	e.ambient_light_energy = 0.55
	env.environment = e
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(25), 0)
	sun.light_energy = 1.2
	vp.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(deg_to_rad(-20), deg_to_rad(200), 0)
	rim.light_energy = 0.6
	rim.light_color = col.lightened(0.4)
	vp.add_child(rim)
	cam = Camera3D.new()
	cam.position = Vector3(0, 2.55, 3.45)
	cam.fov = 46
	vp.add_child(cam)
	cam.look_at(Vector3(0, 0.3, 0))
	rig = Node3D.new()
	vp.add_child(rig)
	var tex_front := DB.tex("res://assets/ui/display3d/%s_front.png" % dd.id)
	var tex_side := DB.tex("res://assets/ui/display3d/%s_side.png" % dd.id)
	var tex_lid := DB.tex("res://assets/ui/display3d/%s_lid.png" % dd.id)
	var wall := _mat(null, col.darkened(0.35))
	var inside := _mat(null, col.darkened(0.7))
	# fond et parois
	_box(Vector3(BW, WT, BD), Vector3(0, WT / 2, 0), inside, rig)
	_box(Vector3(BW, BH, WT), Vector3(0, BH / 2, BD / 2), wall, rig)
	_box(Vector3(BW, BH, WT), Vector3(0, BH / 2, -BD / 2), wall, rig)
	_box(Vector3(WT, BH, BD), Vector3(-BW / 2, BH / 2, 0), wall, rig)
	_box(Vector3(WT, BH, BD), Vector3(BW / 2, BH / 2, 0), wall, rig)
	# faces décorées
	_quad(Vector2(BW, BH), Vector3(0, BH / 2, BD / 2 + WT / 2 + 0.003), Vector3.ZERO, _mat(tex_front), rig)
	_quad(Vector2(BD, BH), Vector3(BW / 2 + WT / 2 + 0.003, BH / 2, 0), Vector3(0, PI / 2, 0), _mat(tex_side), rig)
	_quad(Vector2(BD, BH), Vector3(-BW / 2 - WT / 2 - 0.003, BH / 2, 0), Vector3(0, -PI / 2, 0), _mat(tex_side), rig)
	_quad(Vector2(BW, BH), Vector3(0, BH / 2, -BD / 2 - WT / 2 - 0.003), Vector3(0, PI, 0), _mat(tex_side), rig)
	# couvercle articulé sur l'arête arrière
	lid_pivot = Node3D.new()
	lid_pivot.position = Vector3(0, BH, -BD / 2)
	rig.add_child(lid_pivot)
	_box(Vector3(BW + 0.06, WT, BD + 0.06), Vector3(0, WT / 2, BD / 2), wall, lid_pivot)
	_quad(Vector2(BW + 0.06, BD + 0.06), Vector3(0, WT + 0.003, BD / 2), Vector3(-PI / 2, 0, 0), _mat(tex_lid), lid_pivot)
	_box(Vector3(BW + 0.06, 0.12, WT), Vector3(0, -0.05, BD + 0.03), wall, lid_pivot)
	if dsp.get("lid", false):
		lid_pivot.rotation.x = deg_to_rad(-112)
	# lumière intérieure (s'allume à l'ouverture)
	inner_light = OmniLight3D.new()
	inner_light.position = Vector3(0, 0.9, 0.2)
	inner_light.omni_range = 2.5
	inner_light.light_color = col.lightened(0.5)
	inner_light.light_energy = 1.5 if dsp.get("lid", false) else 0.0
	rig.add_child(inner_light)
	_build_packs()

func _build_packs() -> void:
	for p in packs:
		if is_instance_valid(p):
			p.queue_free()
	packs.clear()
	var n := int(dsp.left)
	var total := int(dd.count)
	var cols := 6
	var rows := int(ceil(total / float(cols)))
	var tex := DB.tex("res://assets/ui/packs/%s.png" % booster.id)
	var pmat := _mat(tex, Color.WHITE, true)
	var sx := (BW - 0.25) / cols
	var sz := (BD - 0.2) / rows
	for k in n:
		var r := k / cols
		var c := k % cols
		var holder := Node3D.new()
		holder.position = Vector3(-BW / 2 + 0.125 + sx * (c + 0.5), 0.4 + r * 0.03, -BD / 2 + 0.1 + sz * (r + 0.5))
		holder.rotation.x = deg_to_rad(-14)
		rig.add_child(holder)
		_quad(Vector2(0.3, 0.46), Vector3.ZERO, Vector3.ZERO, pmat, holder)
		holder.set_meta("phase", randf() * TAU)
		packs.append(holder)

# ---------------------------------------------------------------- interaction
func _refresh() -> void:
	info.text = "%d / %d boosters restants%s" % [int(dsp.left), int(dd.count), " · garantie obtenue !" if dsp.hit else ""]
	if not dsp.get("lid", false):
		hint.text = "Touche le display pour déchirer le scellé et l'ouvrir"
		get_node("next").text = "Ouvrir le display"
	else:
		hint.text = "Fais pivoter la caisse au doigt · touche un booster pour le sortir"
		get_node("next").text = "Ouvrir le suivant"

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_press = e.position
			_dragging = false
		else:
			if not _dragging and _press.x >= 0:
				_tap(e.position)
			_press = Vector2(-1, -1)
	elif e is InputEventMouseMotion and _press.x >= 0 and (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
		if (e.position - _press).length() > 12:
			_dragging = true
		if _dragging:
			_yaw_target = clampf(_yaw_target + e.relative.x / 240.0, -0.9, 0.9)

func _tap(pos: Vector2) -> void:
	if busy:
		return
	if not dsp.get("lid", false):
		_open_lid()
		return
	var local := pos - vpc.position
	var best: Node3D = null
	var best_d := 80.0
	for p in packs:
		var sp := cam.unproject_position(p.global_position + Vector3(0, 0.1, 0))
		var d := sp.distance_to(local)
		if d < best_d:
			best_d = d
			best = p
	if best:
		_pull(best)

func _open_lid() -> void:
	if busy or dsp.get("lid", false):
		return
	busy = true
	Sfx.play("tear")
	for i in 3:
		var t0 := create_tween()
		t0.tween_property(rig, "rotation:z", 0.04, 0.05)
		t0.tween_property(rig, "rotation:z", -0.04, 0.08)
		t0.tween_property(rig, "rotation:z", 0.0, 0.05)
		await t0.finished
	var t := create_tween().set_parallel(true)
	t.tween_property(lid_pivot, "rotation:x", deg_to_rad(-112), 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(inner_light, "light_energy", 1.5, 0.9)
	Sfx.play("flash")
	var sp := vpc.position + cam.unproject_position(rig.global_position + Vector3(0, BH, 0))
	UI.burst(self, sp, Color(dd.color).lightened(0.5), 80, 700, 0.8, 1.2, 150)
	_flash(Color(1, 1, 1, 0.7), 0.5)
	await t.finished
	dsp.lid = true
	Profile.save_game()
	busy = false
	_refresh()

func _pull(p: Node3D) -> void:
	if busy or int(dsp.left) <= 0:
		return
	busy = true
	packs.erase(p)
	Sfx.play("whoosh", 1.2)
	var start := p.global_position
	var t := create_tween().set_parallel(true)
	t.tween_property(p, "global_position", start + Vector3(0, 0.55, 0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(p, "global_position", cam.global_position + (Vector3(0, 0.4, 0) - cam.global_position).normalized() * 1.3, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(p, "rotation:y", p.rotation.y + TAU, 0.7)
	t.parallel().tween_property(p, "rotation:x", 0.0, 0.4)
	await t.finished
	_flash(Color(1, 1, 1, 0.8), 0.4)
	p.queue_free()
	dsp.left = int(dsp.left) - 1
	var opts := {}
	if int(dsp.left) == 0 and not dsp.hit:
		opts.force_min = dd.guarantee
	var main = get_tree().root.get_node("Main")
	var o: Control = load("res://scripts/screens/shop.gd").open_pack(main, booster, opts)
	o.set_meta("no_again", true)
	for r in o.get_meta("results"):
		if DB.rarity_index(DB.card(r.id).rarity) >= DB.rarity_index(dd.guarantee):
			dsp.hit = true
	if int(dsp.left) <= 0:
		Profile.d.displays.erase(dsp)
	Profile.save_game()
	_refresh()
	await o.tree_exited
	busy = false
	if int(dsp.left) <= 0:
		_finished()

func _process(delta: float) -> void:
	_t += delta
	if not _dragging:
		_yaw_target = lerpf(_yaw_target, sin(_t * 0.4) * 0.25, delta * 0.6)
	_yaw = lerpf(_yaw, _yaw_target, minf(1.0, delta * 6.0))
	if rig:
		rig.rotation.y = _yaw
	for p in packs:
		if is_instance_valid(p):
			p.rotation.z = sin(_t * 1.8 + float(p.get_meta("phase", 0.0))) * 0.03
	if inner_light and dsp.get("lid", false):
		inner_light.light_energy = 1.4 + sin(_t * 3.0) * 0.15

func _flash(c: Color, dur: float) -> void:
	var f := ColorRect.new()
	f.color = c
	f.size = size
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(f)
	var t := f.create_tween()
	t.tween_property(f, "color:a", 0.0, dur)
	t.tween_callback(f.queue_free)

func _finished() -> void:
	info.text = "Display terminé !"
	Sfx.play("victory")
	for i in 3:
		UI.burst(self, Vector2(randf_range(150, size.x - 150), randf_range(300, 700)), Color(dd.color).lightened(0.3), 60, 600, 0.7, 1.2, 300)
	var main = get_tree().root.get_node("Main")
	var l := UI.label("Tu as ouvert les %d boosters de ce display. Retrouve tes nouvelles cartes dans l'Album !" % int(dd.count), 22, UI.TEXT, "body", 600)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main.modal("Display terminé", l, [["Fermer", UI.ACCENT, func(): queue_free()]])

func _close() -> void:
	if busy:
		return
	Sfx.play("back")
	queue_free()
