class_name Models
## Modèles 3D procéduraux (style cartoon) : unités, tours, arène.

static var _mats := {}

static func mat(color: Color, metal := 0.0, rough := 0.55, emis := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var key = "%s|%s|%s|%s|%s" % [color.to_html(), metal, rough, emis, alpha]
	if _mats.has(key):
		return _mats[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(color, alpha)
	m.metallic = metal
	m.roughness = rough
	if emis > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emis
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m

static func glow(c: Color, e := 2.0) -> StandardMaterial3D:
	return mat(c, 0.0, 0.3, e)

static func team_mat(team: int) -> StandardMaterial3D:
	return mat(Data.TEAM_COLORS[team])

static func mi(mesh: Mesh, m: Material, pos := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var o = MeshInstance3D.new()
	o.mesh = mesh
	o.material_override = m
	o.position = pos
	if parent:
		parent.add_child(o)
	return o

static func sphere(r: float, seg := 16) -> SphereMesh:
	var s = SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = seg / 2
	return s

static func cyl(top: float, bottom: float, h: float, seg := 14) -> CylinderMesh:
	var c = CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c

static func cone(r: float, h: float, seg := 14) -> CylinderMesh:
	return cyl(0.0, r, h, seg)

static func box(x: float, y: float, z: float) -> BoxMesh:
	var b = BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b

static func gem(r: float) -> SphereMesh:
	# octaèdre approximé : sphère à 4 segments
	var s = SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 4
	s.rings = 2
	return s

static func rock(r: float) -> SphereMesh:
	var s = SphereMesh.new()
	s.radius = r
	s.height = r * 1.8
	s.radial_segments = 6
	s.rings = 4
	return s

static func pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n = Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n

# ---------- Humanoïde générique ----------
static func humanoid(o: Dictionary) -> Node3D:
	var root = Node3D.new()
	var body = Node3D.new()
	root.add_child(body)
	body.scale = Vector3.ONE * o.get("scale", 1.0)
	var skin = mat(o.get("skin", Color("f2c19b")))
	var cloth = mat(o.get("cloth", Color("555555")), o.get("metal", 0.0), 0.3 if o.get("metal", 0.0) > 0 else 0.55)
	var pants = mat(o.get("pants", Color("3b3b48")))
	var legL = pivot(body, Vector3(-0.17, 0.5, 0))
	var legR = pivot(body, Vector3(0.17, 0.5, 0))
	for leg in [legL, legR]:
		mi(cyl(0.11, 0.1, 0.42), pants, Vector3(0, -0.22, 0), leg)
		mi(box(0.2, 0.12, 0.3), mat(o.get("boots", Color("4a2f1f"))), Vector3(0, -0.44, 0.05), leg)
	var torso = mi(cyl(0.3, 0.34, 0.55, 16), cloth, Vector3(0, 0.78, 0), body)
	mi(cyl(0.36, 0.36, 0.08, 16), mat(o.get("belt", Color("6b4423"))), Vector3(0, 0.55, 0), body)
	var head = pivot(body, Vector3(0, 1.2, 0))
	var h = mi(sphere(0.33), skin, Vector3(0, 0.12, 0), head)
	h.scale = Vector3(1, 1.02, 0.95)
	var eye: Material = glow(o.eye_glow, 3.0) if o.has("eye_glow") else mat(Color("1b1b22"), 0.0, 0.2)
	mi(sphere(0.055, 8), eye, Vector3(-0.12, 0.16, 0.29), head)
	mi(sphere(0.055, 8), eye, Vector3(0.12, 0.16, 0.29), head)
	var armL = pivot(body, Vector3(-0.4, 0.98, 0))
	var armR = pivot(body, Vector3(0.4, 0.98, 0))
	for arm in [armL, armR]:
		mi(cyl(0.09, 0.08, 0.42), cloth, Vector3(0, -0.2, 0), arm)
		mi(sphere(0.1, 10), skin, Vector3(0, -0.44, 0), arm)
	root.set_meta("rig", {"body": body, "legL": legL, "legR": legR, "armL": armL, "armR": armR, "head": head, "torso": torso, "face": h})
	return root

static func build(id: String, team: int) -> Node3D:
	if RealModels.has(id):
		return RealModels.build(id, team)
	var r: Node3D
	match id:
		"drake": r = _drake(team)
		"totem": r = _totem(team)
		"catapult": r = _catapult(team)
		"babydrake": r = _babydrake(team)
		"xbow": r = _xbow(team)
		"tomb": r = _tomb(team)
		"barracks": r = _barracks(team)
		"lightning": r = _bolt_icon()
		"tornado": r = _tornado()
		"heal": r = _flask(Color("ffd84a"), Color("fff3b0"))
		"poison": r = _flask(Color("6ad13a"), Color("b8ff8a"))
		"arrows": r = _arrows()
		"rage": r = _rage()
		"meteor": r = _meteor()
		"frost": r = _frost()
		_: r = Node3D.new()
	_set_shadows(r)
	return r

static func _set_shadows(n: Node) -> void:
	for c in n.get_children():
		if c is GeometryInstance3D:
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_set_shadows(c)

## Modèle créé dans Blender (tools/blender/make_models.py), matériaux « Team » recolorés.
static func blend(name: String, team := 0) -> Node3D:
	var n: Node3D = RealModels.scene("res://assets/models/blender/" + name + ".glb").instantiate()
	recolor(n, {"Team": Color(1, 1, 1).lerp(Data.TEAM_COLORS[team], 0.85), "TeamGlow": Data.TEAM_GLOW[team]})
	_set_shadows(n)
	return n

static var _recolor_cache = {}
static func recolor(n: Node, colors: Dictionary) -> void:
	for c in n.get_children():
		if c is MeshInstance3D and c.mesh:
			for si in c.mesh.get_surface_count():
				var m = c.mesh.surface_get_material(si)
				if m is BaseMaterial3D and colors.has(m.resource_name):
					var key = "%d|%s" % [m.get_instance_id(), colors[m.resource_name].to_html()]
					if not _recolor_cache.has(key):
						var d = m.duplicate()
						d.albedo_color = colors[m.resource_name]
						if d.emission_enabled:
							d.emission = colors[m.resource_name]
						_recolor_cache[key] = d
					c.set_surface_override_material(si, _recolor_cache[key])
		recolor(c, colors)

static func _drake(team: int) -> Node3D:
	var holder = Node3D.new()
	var dragon = blend("dragon", team)
	dragon.scale = Vector3.ONE * 0.75
	holder.add_child(dragon)
	var ap: AnimationPlayer = dragon.find_child("AnimationPlayer", false, false)
	# cavalier KayKit assis sur la selle
	var seat: Node3D = dragon.find_child("Seat", true, false)
	var rider: Node3D = RealModels.scene(RealModels.DIR + "characters/Knight.glb").instantiate()
	rider.scale = Vector3.ONE * 0.42
	rider.position = Vector3(0, -0.35, 0)
	var skel: Skeleton3D = rider.find_child("Skeleton3D", true, false)
	for c in skel.get_children():
		if c is BoneAttachment3D:
			c.visible = String(c.name) in ["1H_Sword", "Knight_Helmet", "Knight_Cape"]
	RealModels._tint(rider, team)
	(seat if seat else dragon).add_child(rider)
	var rap: AnimationPlayer = rider.find_child("AnimationPlayer", true, false)
	rap.get_animation("Sit_Chair_Idle").loop_mode = Animation.LOOP_LINEAR
	rap.play("Sit_Chair_Idle")
	for a in ["Idle", "Fly"]:
		ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	ap.play("Fly")
	holder.set_meta("ap", ap)
	holder.set_meta("cfg", {"move": "Fly", "attack": "Attack", "pose": ["Attack", 0.45]})
	holder.set_meta("real", true)
	return holder

static func _totem(team: int) -> Node3D:
	var r = blend("totem", team)
	r.scale = Vector3.ONE * 0.85
	var ap: AnimationPlayer = r.find_child("AnimationPlayer", true, false)
	if ap:
		ap.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
		ap.play("Idle")
	return r

static func _catapult(team: int) -> Node3D:
	var r = Node3D.new()
	var b = RealModels.hex("building_tower_catapult_" + ("blue" if team == 0 else "red"))
	b.scale = Vector3.ONE * 1.25
	b.rotation.y = PI if team == 0 else 0.0
	r.add_child(b)
	r.set_meta("building", b)
	return r

static func _babydrake(team: int) -> Node3D:
	var holder = Node3D.new()
	var dragon = blend("dragon", team)
	dragon.scale = Vector3.ONE * 0.5
	holder.add_child(dragon)
	var ap: AnimationPlayer = dragon.find_child("AnimationPlayer", false, false)
	var saddle = dragon.find_child("Saddle", true, false)
	if saddle:
		saddle.visible = false
	for a in ["Idle", "Fly"]:
		ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	ap.play("Fly")
	holder.set_meta("ap", ap)
	holder.set_meta("cfg", {"move": "Fly", "attack": "Attack", "pose": ["Attack", 0.45]})
	holder.set_meta("real", true)
	return holder

static func _xbow(team: int) -> Node3D:
	var r = Node3D.new()
	var b = RealModels.hex("building_tower_A_" + ("blue" if team == 0 else "red"))
	b.scale = Vector3.ONE * 1.5
	r.add_child(b)
	r.set_meta("building", b)
	var guard = RealModels.guard(team, false)
	guard.position = Vector3(0, aabb_of(b).end.y - 0.9, 0.35 if team == 0 else -0.35)
	r.add_child(guard)
	r.set_meta("guard", guard)
	return r

static func _tomb(team: int) -> Node3D:
	var r = Node3D.new()
	mi(cyl(1.0, 1.15, 0.3, 10), mat(Color("4a4652"), 0.0, 0.95), Vector3(0, 0.15, 0), r)
	var p = RealModels.prop("pillar_decorated")
	p.scale = Vector3.ONE * 0.75
	r.add_child(p)
	var rb = RealModels.prop("rubble_half")
	rb.scale = Vector3.ONE * 0.6
	rb.position = Vector3(0.5, 0, 0.4)
	r.add_child(rb)
	var glow_m = glow(Color("8be04a"), 2.5)
	for i in 4:
		var a = i * TAU / 4.0 + 0.4
		mi(sphere(0.12, 8), glow_m, Vector3(cos(a) * 0.85, 0.45, sin(a) * 0.85), r)
	mi(gem(0.3), glow(Data.TEAM_GLOW[team], 2.0), Vector3(0, 2.8, 0), r).scale = Vector3(1, 1.5, 1)
	return r

static func _barracks(team: int) -> Node3D:
	var r = Node3D.new()
	var b = RealModels.hex("building_barracks_" + ("blue" if team == 0 else "red"))
	b.scale = Vector3.ONE * 1.6
	b.rotation.y = PI if team == 0 else 0.0
	r.add_child(b)
	r.set_meta("building", b)
	return r

static func _bolt_icon() -> Node3D:
	var r = Node3D.new()
	var g = glow(Color("ffe95a"), 4.0)
	var pts = [Vector3(0.2, 2.0, 0), Vector3(-0.25, 1.2, 0), Vector3(0.25, 1.1, 0), Vector3(-0.2, 0.2, 0)]
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var seg = mi(box(0.16, a.distance_to(b), 0.16), g, (a + b) / 2, r)
		seg.rotation.z = atan2(-(b.x - a.x), b.y - a.y) + PI
	mi(sphere(0.35), mat(Color("6f8bff"), 0.0, 0.5, 1.5, 0.6), Vector3(0, 2.1, 0), r)
	mi(cyl(0.6, 0.7, 0.25, 12), mat(Color("4a4f66"), 0.0, 0.9), Vector3(0, 0.1, 0), r)
	return r

static func _tornado() -> Node3D:
	var r = Node3D.new()
	for i in 7:
		var t = TorusMesh.new()
		t.inner_radius = 0.15 + i * 0.12
		t.outer_radius = 0.25 + i * 0.13
		var o = mi(t, mat(Color(0.85, 0.9, 1.0), 0.0, 0.6, 0.4, 0.75), Vector3(sin(i) * 0.08, 0.2 + i * 0.28, 0), r)
		o.rotation.z = sin(i * 1.3) * 0.15
	return r

static func _flask(liquid: Color, glass: Color) -> Node3D:
	var f = blend("potion")
	recolor(f, {"Liquid": liquid, "Glass": glass})
	return f

static func _arrows() -> Node3D:
	var r = Node3D.new()
	for i in 9:
		var a = blend("arrow")
		a.position = Vector3(randf_range(-0.6, 0.6), randf_range(0.0, 0.9), randf_range(-0.4, 0.4))
		a.rotation = Vector3(randf_range(-0.25, 0.25), randf() * TAU, randf_range(-0.25, 0.25))
		r.add_child(a)
	return r

static func _rage() -> Node3D:
	return blend("potion")

static func _meteor() -> Node3D:
	return blend("meteor")

static func _frost() -> Node3D:
	return blend("frost")

# ---------- Animation procédurale ----------
static func animate(model: Node3D, t: float, moving: bool, attack: float, seed: float) -> void:
	if not model.has_meta("rig"):
		return
	var rig: Dictionary = model.get_meta("rig")
	var heavy: bool = rig.get("heavy", false)
	var w = sin(t * (5.0 if heavy else 10.0) + seed) if moving else 0.0
	if rig.get("flying", false):
		var f = sin(t * 8.0 + seed)
		rig.wingL.rotation.z = f * 0.7
		rig.wingR.rotation.z = -f * 0.7
		rig.body.position.y = sin(t * 2.0 + seed) * 0.2 - f * 0.05
		rig.body.rotation.x = -0.1 + attack * 0.2
		rig.head.rotation.x = attack * 0.6
		return
	if rig.has("legs"):
		for i in rig.legs.size():
			rig.legs[i].rotation.x = sin(t * 24.0 + i * 1.7 + seed) * (0.7 if moving else 0.05)
		rig.body.position.y = abs(sin(t * 24.0 + seed)) * 0.05 if moving else 0.0
		rig.body.rotation.x = -attack * 0.5
		return
	if rig.has("crystal"):
		rig.crystal.rotation.y = t * 2.0
		rig.crystal.position.y = 2.4 + sin(t * 3.0) * 0.12
		return
	if rig.has("legL"):
		rig.legL.rotation.x = w * 0.8
		rig.legR.rotation.x = -w * 0.8
		# rebond de marche + léger penché vers l'avant
		rig.body.position.y = abs(w) * (0.12 if heavy else 0.07) if moving else sin(t * 2.5 + seed) * 0.015
		rig.body.rotation.x = (0.12 if moving else 0.0) - attack * 0.25
		rig.body.rotation.z = w * 0.05
	if rig.has("armL"):
		rig.armL.rotation.x = -w * 0.6
		rig.armR.rotation.x = w * 0.6 - attack * 2.4
		if heavy:
			rig.armL.rotation.x = -attack * 2.2 - w * 0.4
	if rig.has("head"):
		rig.head.rotation.y = sin(t * 0.7 + seed) * 0.15 if not moving else 0.0
	if rig.has("cape"):
		rig.cape.rotation.x = 0.15 + (0.5 if moving else 0.0) + sin(t * 9.0) * 0.08
	if rig.has("orb"):
		rig.orb.scale = Vector3.ONE * (1.0 + sin(t * 8.0) * 0.15 + attack * 0.8)
	if rig.has("spark"):
		rig.spark.scale = Vector3.ONE * randf_range(0.6, 1.5)

# ---------- Tours ----------
static func aabb_of(n: Node, t := Transform3D()) -> AABB:
	var r = AABB()
	var tt = t * (n.transform if n is Node3D else Transform3D())
	if n is MeshInstance3D:
		r = tt * n.get_aabb()
	for c in n.get_children():
		var a = aabb_of(c, tt)
		if a.size != Vector3.ZERO:
			r = a if r.size == Vector3.ZERO else r.merge(a)
	return r

static func tower(team: int, core: bool) -> Node3D:
	var g = Node3D.new()
	var color = "blue" if team == 0 else "red"
	var front = 1.0 if team == 0 else -1.0
	if not core:
		var b = RealModels.hex("building_tower_base_" + color)
		b.scale = Vector3.ONE * 2.3
		b.rotation.y = 0.0 if team == 0 else PI
		g.add_child(b)
		var top = aabb_of(b).end.y
		var guard = RealModels.guard(team, false)
		guard.position = Vector3(0, top - 0.25, 0)
		g.add_child(guard)
		g.set_meta("guard", guard)
		var flag = RealModels.hex("flag_" + color)
		flag.scale = Vector3.ONE * 4.0
		flag.position = Vector3(0.75, top - 0.3, -0.55 * front)
		g.add_child(flag)
		g.set_meta("flag", flag)
		for sx in [-1.0, 1.0]:
			var tc = RealModels.prop("torch_lit")
			tc.position = Vector3(sx * 1.25, 0.0, 0.9 * front)
			tc.scale = Vector3.ONE * 0.75
			g.add_child(tc)
		var ban = RealModels.prop("banner_patternA_blue" if team == 0 else "banner_patternA_red")
		ban.position = Vector3(0, 1.3, 1.05 * front)
		ban.rotation.y = 0.0 if team == 0 else PI
		ban.scale = Vector3.ONE * 0.6
		g.add_child(ban)
		g.set_meta("top", top + 1.4)
	else:
		var c = RealModels.hex("building_castle_" + color)
		c.scale = Vector3.ONE * 1.55
		c.rotation.y = 0.0 if team == 0 else PI
		g.add_child(c)
		mi(cyl(0.75, 0.9, 1.6, 12), mat(Color("9e978b"), 0.0, 0.85), Vector3(0, 0.8, 2.05 * front), g)
		mi(cyl(0.85, 0.85, 0.18, 12), team_mat(team), Vector3(0, 1.62, 2.05 * front), g)
		var guard = RealModels.guard(team, true)
		guard.position = Vector3(0, 1.7, 2.05 * front)
		g.add_child(guard)
		g.set_meta("guard", guard)
		for sx in [-1.0, 1.0]:
			var ban = RealModels.prop("banner_shield_blue" if team == 0 else "banner_shield_red")
			ban.position = Vector3(sx * 1.25, 0.9, 1.75 * front)
			ban.rotation.y = 0.0 if team == 0 else PI
			ban.scale = Vector3.ONE * 0.6
			g.add_child(ban)
			var br = RealModels.prop("barrel_large")
			br.position = Vector3(sx * 2.2, 0, 1.3 * front)
			br.scale = Vector3.ONE * 0.6
			g.add_child(br)
		var crystal = mi(gem(0.45), glow(Data.TEAM_GLOW[team], 2.0), Vector3(0, aabb_of(c).end.y + 0.9, 0), g)
		crystal.scale = Vector3(1, 1.6, 1)
		g.set_meta("crystal", crystal)
		g.set_meta("top", 3.4)
	_set_shadows(g)
	return g

static func rubble() -> Node3D:
	var g = Node3D.new()
	var real = RealModels.prop("rubble_large")
	real.scale = Vector3.ONE * 0.6
	g.add_child(real)
	return g

# ---------- Arène sur île flottante ----------
static func arena(isl: Dictionary) -> Node3D:
	var g = Node3D.new()
	var ground = MeshInstance3D.new()
	var pm = PlaneMesh.new()
	pm.size = Vector2(18, 32)
	ground.mesh = pm
	var gm = ShaderMaterial.new()
	gm.shader = load("res://scripts/ground.gdshader")
	gm.set_shader_parameter("grass_a", isl.grass)
	gm.set_shader_parameter("grass_b", isl.grass2)
	gm.set_shader_parameter("tile", isl.tile)
	ground.material_override = gm
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(ground)
	# socle de l'île flottante (modèle Blender) recoloré selon l'île
	var island_model = blend("island")
	recolor(island_model, {"Rock": isl.cliff, "RockDark": Color(isl.cliff).darkened(0.3), "Grass": isl.grass2})
	for m in island_model.find_children("*", "GeometryInstance3D", true, false):
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(island_model)
	var rng = RandomNumberGenerator.new()
	rng.seed = 3
	# rivière animée
	var water = MeshInstance3D.new()
	var wp = PlaneMesh.new()
	wp.size = Vector2(24, 2.4)
	water.mesh = wp
	var wm = ShaderMaterial.new()
	wm.shader = load("res://scripts/water.gdshader")
	wm.set_shader_parameter("base_color", isl.water)
	water.material_override = wm
	water.position.y = -0.08
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(water)
	for wx in [-8.0, -3.0, 2.5, 8.0]:
		var lily = RealModels.hex("waterlily_A")
		lily.position = Vector3(wx + rng.randf_range(-0.6, 0.6), -0.05, rng.randf_range(-0.6, 0.6))
		lily.scale = Vector3.ONE * 1.4
		g.add_child(lily)
	var bank = mat(Color("a8865a"), 0.0, 0.9)
	mi(box(18, 0.25, 0.25), bank, Vector3(0, -0.02, 1.25), g)
	mi(box(18, 0.25, 0.25), bank, Vector3(0, -0.02, -1.25), g)
	for bx in [-5.5, 5.5]:
		for i in 7:
			mi(box(2.4, 0.18, 0.42), mat(Color("9a6233") if i % 2 else Color("8a5629")), Vector3(bx, 0.08, -1.35 + i * 0.45), g)
		for sx in [-1.25, 1.25]:
			mi(box(0.12, 0.5, 3.1), mat(Color("6b3f1f")), Vector3(bx + sx, 0.4, 0), g)
			for sz in [-1.45, 0.0, 1.45]:
				mi(cyl(0.11, 0.11, 0.8, 8), mat(Color("5a341a")), Vector3(bx + sx, 0.3, sz), g)
	# murets en pierre
	var wall = mat(Color("cfc6b5"), 0.0, 0.85)
	var cap = mat(Color("b3aa98"), 0.0, 0.85)
	for sx in [-9.3, 9.3]:
		mi(box(0.6, 0.7, 32.6), wall, Vector3(sx, 0.35, 0), g)
		mi(box(0.75, 0.12, 32.8), cap, Vector3(sx, 0.74, 0), g)
		for z in range(-15, 16, 3):
			mi(box(0.85, 1.0, 0.85), wall, Vector3(sx, 0.5, z), g)
			mi(box(0.95, 0.12, 0.95), cap, Vector3(sx, 1.03, z), g)
	for sz in [-16.3, 16.3]:
		mi(box(19.2, 0.7, 0.6), wall, Vector3(0, 0.35, sz), g)
		mi(box(19.3, 0.12, 0.75), cap, Vector3(0, 0.74, sz), g)
	# forêts, rochers et montagnes autour de l'arène
	var trees = ["trees_A_large", "trees_B_large", "trees_A_medium", "trees_B_medium", "tree_single_A", "tree_single_B"]
	for i in 26:
		var side = 1 if i % 2 else -1
		var t = RealModels.hex(trees[rng.randi() % trees.size()])
		t.position = Vector3(side * rng.randf_range(10.6, 13.5), 0, -17 + i / 26.0 * 34 + rng.randf())
		t.scale = Vector3.ONE * rng.randf_range(1.6, 2.2)
		t.rotation.y = rng.randf() * TAU
		g.add_child(t)
	for sz in [-1, 1]:
		for i in 7:
			var t = RealModels.hex(trees[rng.randi() % trees.size()])
			t.position = Vector3(-10.5 + i * 3.5 + rng.randf(), 0, sz * rng.randf_range(17.4, 19.2))
			t.scale = Vector3.ONE * rng.randf_range(1.6, 2.0)
			t.rotation.y = rng.randf() * TAU
			g.add_child(t)
	var mounts = ["mountain_A_grass_trees", "mountain_B_grass_trees", "mountain_C_grass", "hills_A_trees", "hills_B_trees"]
	for p in [Vector3(-13.5, 0, -14), Vector3(13.5, 0, -12), Vector3(-14, 0, 9), Vector3(14, 0, 13), Vector3(-12.5, 0, 20), Vector3(12.5, 0, -21)]:
		var m = RealModels.hex(mounts[rng.randi() % mounts.size()])
		m.position = p
		m.scale = Vector3.ONE * rng.randf_range(2.6, 3.4)
		m.rotation.y = rng.randf() * TAU
		g.add_child(m)
	for i in 10:
		var r = RealModels.hex("rock_single_" + ["A", "B", "C", "D"][rng.randi() % 4])
		r.position = Vector3((1 if i % 2 else -1) * rng.randf_range(9.8, 10.4), 0, rng.randf_range(-15, 15))
		r.scale = Vector3.ONE * rng.randf_range(2.5, 4.0)
		g.add_child(r)
	# torches et accessoires de camp
	for sx in [-8.6, 8.6]:
		for sz in [-1.8, 1.8]:
			var tc = RealModels.prop("torch_lit")
			tc.position = Vector3(sx, 0.7, sz)
			tc.scale = Vector3.ONE * 0.9
			g.add_child(tc)
	var deco = [["tent", -11.2, -4.0, 3.5], ["weaponrack", 10.6, 4.0, 3.0], ["target", -10.6, 4.5, 3.0], ["wheelbarrow", 10.8, -3.5, 3.0],
		["barrel_small_stack", -10.4, -8.0, 0.8], ["crates_stacked", 10.4, -7.0, 0.8], ["keg_decorated", -10.3, 7.5, 0.8], ["sack", 10.5, 9.0, 3.5],
		["bucket_arrows", -10.5, 12.5, 3.5], ["tent", 11.2, 12.0, 3.5]]
	for d in deco:
		var pr = RealModels.hex(d[0]) if ResourceLoader.exists(RealModels.DIR + "hex/" + d[0] + ".gltf") else RealModels.prop(d[0])
		pr.position = Vector3(d[1], 0, d[2])
		pr.rotation.y = rng.randf() * TAU
		pr.scale = Vector3.ONE * d[3]
		g.add_child(pr)
	# nuages qui flottent autour et sous l'île
	var clouds = Node3D.new()
	clouds.name = "Clouds"
	for i in 14:
		var c = RealModels.hex("cloud_big" if i % 2 else "cloud_small")
		var ang = i / 14.0 * TAU
		c.position = Vector3(cos(ang) * rng.randf_range(20, 28), rng.randf_range(-9, -2), sin(ang) * rng.randf_range(26, 34))
		c.scale = Vector3.ONE * rng.randf_range(2.5, 4.5)
		c.set_meta("speed", rng.randf_range(0.2, 0.5))
		for m in c.find_children("*", "GeometryInstance3D", true, false):
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		clouds.add_child(c)
	g.add_child(clouds)
	g.set_meta("clouds", clouds)
	return g

static func animate_clouds(arena_node: Node3D, dt: float) -> void:
	if not arena_node or not arena_node.has_meta("clouds"):
		return
	for c in arena_node.get_meta("clouds").get_children():
		c.position.x += c.get_meta("speed") * dt
		if c.position.x > 32:
			c.position.x = -32

static func sky_environment(isl: Dictionary) -> Environment:
	var e = Environment.new()
	var sky = Sky.new()
	var sm = ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(isl.sky).darkened(0.25)
	sm.sky_horizon_color = Color(isl.sky).lightened(0.35)
	sm.ground_horizon_color = Color(isl.sky).lightened(0.3)
	sm.ground_bottom_color = Color(isl.sky).darkened(0.1)
	sm.sun_angle_max = 20.0
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.9, 1.0)
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.0
	e.fog_enabled = false
	e.fog_light_color = Color(isl.sky).lightened(0.4)
	e.fog_density = 0.004
	e.fog_sky_affect = 0.0
	return e
