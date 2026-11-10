class_name MenuBg3D extends SubViewportContainer
## Fond des menus : de vraies cartes 3D (cadre, illustration, dos) qui dérivent lentement dans l'espace,
## tournent sur elles-mêmes et se perdent dans la brume au loin. Rendu à mi-résolution (flou de profondeur).

const N_CARDS := 9
var vp: SubViewport
var cards: Array = []
var _pool: Array = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	stretch_shrink = 2
	vp = SubViewport.new()
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.position = Vector3(0, 0, 7)
	vp.add_child(cam)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.75, 1.0)
	e.ambient_light_energy = 0.95
	e.fog_enabled = true
	e.fog_light_color = Color(0.08, 0.04, 0.16)
	e.fog_density = 0.045
	env.environment = e
	vp.add_child(env)
	var l := DirectionalLight3D.new()
	l.rotation = Vector3(deg_to_rad(-30), deg_to_rad(35), 0)
	l.light_energy = 0.7
	vp.add_child(l)
	for id in DB.card_order:
		var c := DB.card(id)
		if not c.get("token", false) and DB.rarity_index(c.rarity) >= DB.rarity_index("SR") and c.rarity != "SW":
			_pool.append(id)
	for i in N_CARDS:
		var n := _make_card(_pool[_rng.randi_range(0, _pool.size() - 1)])
		vp.add_child(n)
		_respawn(n, true)
		cards.append(n)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	for n in cards:
		var v: Vector3 = n.get_meta("vel")
		n.position += v * delta
		n.rotation += n.get_meta("spin") * delta
		if n.position.y > 7.5:
			_swap_art(n)
			_respawn(n, false)

func _respawn(n: Node3D, initial: bool) -> void:
	var z := _rng.randf_range(-9.0, 1.5)
	n.position = Vector3(_rng.randf_range(-4.0, 4.0), _rng.randf_range(-7.0, 7.0) if initial else -7.5, z)
	n.rotation = Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(0, TAU), _rng.randf_range(-0.4, 0.4))
	n.set_meta("vel", Vector3(_rng.randf_range(-0.08, 0.08), _rng.randf_range(0.18, 0.45), 0))
	n.set_meta("spin", Vector3(_rng.randf_range(-0.08, 0.08), _rng.randf_range(0.15, 0.45) * (1 if _rng.randf() < 0.5 else -1), _rng.randf_range(-0.05, 0.05)))

func _swap_art(n: Node3D) -> void:
	var id: String = _pool[_rng.randi_range(0, _pool.size() - 1)]
	var c := DB.card(id)
	(n.get_node("art") as MeshInstance3D).material_override.albedo_texture = DB.card_art(id)
	(n.get_node("frame") as MeshInstance3D).material_override.albedo_texture = DB.frame_tex(c.rarity)

func _quad(sz: Vector2, tex: Texture2D, alpha: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = sz
	mi.mesh = qm
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 0.35
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
	mi.material_override = m
	return mi

func _make_card(id: String) -> Node3D:
	var c := DB.card(id)
	var root := Node3D.new()
	# illustration derrière la fenêtre du cadre (positions tirées du gabarit 150 x 210)
	var art := _quad(Vector2(0.907, 0.62), DB.card_art(id), false)
	var am: StandardMaterial3D = art.material_override
	am.uv1_scale = Vector3(136.0 / 150.0, 93.0 / 210.0, 1)
	am.uv1_offset = Vector3(7.0 / 150.0, 25.0 / 210.0, 0)
	art.position = Vector3(0, 0.223, -0.002)
	art.name = "art"
	root.add_child(art)
	var fr := _quad(Vector2(1.0, 1.4), DB.frame_tex(c.rarity), true)
	fr.name = "frame"
	root.add_child(fr)
	var back := _quad(Vector2(1.0, 1.4), DB.tex("res://assets/ui/card_back.png"), true)
	back.rotation.y = PI
	back.position.z = -0.006
	root.add_child(back)
	return root
