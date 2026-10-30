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
	var r: Node3D
	match id:
		"blade": r = _blade(team)
		"archers": r = _archer(team)
		"pyro": r = _pyro(team)
		"swarm": r = _beetle(team)
		"golem": r = _golem(team, false)
		"shard": r = _golem(team, true)
		"storm": r = _storm(team)
		"shield": r = _knight(team)
		"sapper": r = _sapper(team)
		"drake": r = _drake(team)
		"totem": r = _totem(team)
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

static func _blade(team: int) -> Node3D:
	var r = humanoid({"skin": Color("9fd8ff"), "cloth": Color("2b2440"), "pants": Color("1d1830"), "boots": Color("15121f"), "eye_glow": Color("7ff6ff")})
	var rig: Dictionary = r.get_meta("rig")
	rig.face.material_override = mat(Color("0c0f1c"))
	var hood = mi(sphere(0.38), mat(Color("2b2440")), Vector3(0, 0.16, -0.05), rig.head)
	hood.scale = Vector3(1.05, 1.08, 1.0)
	var tip = mi(cone(0.3, 0.35), mat(Color("2b2440")), Vector3(0, 0.5, -0.15), rig.head)
	tip.rotation.x = -0.6
	mi(cyl(0.33, 0.36, 0.12, 16), team_mat(team), Vector3(0, 1.05, 0), rig.body)
	var cape = mi(box(0.55, 0.7, 0.05), team_mat(team), Vector3(0, 0.75, -0.32), rig.body)
	cape.rotation.x = 0.15
	var sword = pivot(rig.armR, Vector3(0, -0.45, 0.05))
	mi(box(0.07, 0.95, 0.16), glow(Color("63f5ff"), 2.5), Vector3(0, 0.5, 0), sword)
	mi(box(0.3, 0.06, 0.08), mat(Color("8a8fa8"), 0.8, 0.3), Vector3(0, 0.02, 0), sword)
	sword.rotation.x = PI / 2.3
	rig["weapon"] = sword
	rig["cape"] = cape
	return r

static func _archer(team: int) -> Node3D:
	var r = humanoid({"skin": Color("f6cfae"), "cloth": Color("2f7d3a"), "pants": Color("4a3524"), "boots": Color("3a2516")})
	var rig: Dictionary = r.get_meta("rig")
	var hair = mi(sphere(0.36), mat(Color("f1d36b")), Vector3(0, 0.2, -0.05), rig.head)
	hair.scale = Vector3(1.02, 0.9, 1.05)
	var e1 = mi(cone(0.07, 0.3, 6), mat(Color("f6cfae")), Vector3(-0.34, 0.12, 0), rig.head)
	e1.rotation.z = 1.2
	var e2 = mi(cone(0.07, 0.3, 6), mat(Color("f6cfae")), Vector3(0.34, 0.12, 0), rig.head)
	e2.rotation.z = -1.2
	var tail = mi(cone(0.2, 0.55), mat(Color("f1d36b")), Vector3(0, -0.05, -0.32), rig.head)
	tail.rotation.x = 2.7
	mi(box(0.62, 0.12, 0.6), team_mat(team), Vector3(0, 1.07, 0), rig.body)
	var bow = pivot(rig.armL, Vector3(0, -0.45, 0.1))
	var arc = TorusMesh.new()
	arc.inner_radius = 0.42
	arc.outer_radius = 0.48
	var bm = mi(arc, mat(Color("8b5a2b")), Vector3.ZERO, bow)
	bm.scale = Vector3(1, 1, 0.4)
	bm.rotation.x = PI / 2
	bow.rotation.x = PI / 2
	var q = mi(cyl(0.1, 0.09, 0.5, 10), mat(Color("6b3f1f")), Vector3(0.15, 0.85, -0.33), rig.body)
	q.rotation.z = 0.3
	rig["weapon"] = bow
	return r

static func _pyro(team: int) -> Node3D:
	var r = humanoid({"skin": Color("e9b48f"), "cloth": Color("b32d1a"), "pants": Color("b32d1a"), "boots": Color("2a1a12")})
	var rig: Dictionary = r.get_meta("rig")
	mi(cone(0.48, 0.8, 18), mat(Color("9c2414")), Vector3(0, 0.42, 0), rig.body)
	rig.legL.visible = false
	rig.legR.visible = false
	var hat = mi(cone(0.42, 0.75, 18), mat(Color("5a1810")), Vector3(0, 0.68, 0), rig.head)
	hat.rotation.z = 0.15
	mi(cyl(0.55, 0.55, 0.05, 20), mat(Color("5a1810")), Vector3(0, 0.36, 0), rig.head)
	mi(cyl(0.43, 0.43, 0.08, 20), team_mat(team), Vector3(0, 0.42, 0), rig.head)
	var beard = mi(cone(0.2, 0.45, 10), mat(Color("dddddd")), Vector3(0, -0.15, 0.22), rig.head)
	beard.rotation.x = PI
	var staff = pivot(rig.armR, Vector3(0, -0.45, 0))
	mi(cyl(0.04, 0.04, 1.6, 8), mat(Color("5b3a1e")), Vector3(0, 0.3, 0), staff)
	rig["orb"] = mi(sphere(0.16), glow(Color("ff8a1f"), 3.0), Vector3(0, 1.15, 0), staff)
	rig["weapon"] = staff
	return r

static func _beetle(team: int) -> Node3D:
	var r = Node3D.new()
	var body = Node3D.new()
	r.add_child(body)
	var shell = mi(sphere(0.28), mat(Data.TEAM_COLORS[team], 0.6, 0.25), Vector3(0, 0.25, 0), body)
	shell.scale = Vector3(1, 0.7, 1.3)
	mi(sphere(0.16, 12), mat(Color("1a1a1a"), 0.4, 0.3), Vector3(0, 0.22, 0.32), body)
	var horn = mi(cone(0.05, 0.25, 6), mat(Color("ffd34d"), 0.7, 0.3), Vector3(0, 0.32, 0.48), body)
	horn.rotation.x = 1.1
	mi(sphere(0.04, 6), glow(Color("fff176")), Vector3(-0.07, 0.27, 0.45), body)
	mi(sphere(0.04, 6), glow(Color("fff176")), Vector3(0.07, 0.27, 0.45), body)
	var legs = []
	for i in 3:
		for sx in [-1, 1]:
			var l = mi(cyl(0.02, 0.02, 0.28, 4), mat(Color("111111")), Vector3(sx * 0.24, 0.12, -0.15 + i * 0.15), body)
			l.rotation.z = sx * 0.9
			legs.append(l)
	r.set_meta("rig", {"body": body, "legs": legs})
	return r

static func _golem(team: int, small: bool) -> Node3D:
	var r = Node3D.new()
	var body = Node3D.new()
	r.add_child(body)
	var stone = mat(Color("4a4a52"), 0.0, 0.9)
	var lava = glow(Color("ff6a00"), 3.0)
	var core = mi(rock(0.85), stone, Vector3(0, 1.55, 0), body)
	core.scale = Vector3(1.15, 1.1, 0.9)
	mi(gem(0.28), lava, Vector3(0, 1.6, 0.7), body)
	var head = pivot(body, Vector3(0, 2.35, 0.15))
	mi(rock(0.42), stone, Vector3.ZERO, head)
	mi(box(0.5, 0.07, 0.1), lava, Vector3(0, 0.05, 0.36), head)
	mi(box(0.9, 0.18, 0.18), team_mat(team), Vector3(0, 2.05, 0.35), body)
	var armL = pivot(body, Vector3(-1.05, 2.0, 0))
	var armR = pivot(body, Vector3(1.05, 2.0, 0))
	for a in [armL, armR]:
		mi(rock(0.4), stone, Vector3(0, -0.35, 0), a)
		mi(rock(0.5), stone, Vector3(0, -1.0, 0.05), a)
		mi(box(0.12, 0.3, 0.12), lava, Vector3(0, -0.7, 0.3), a)
	var legL = pivot(body, Vector3(-0.45, 0.85, 0))
	var legR = pivot(body, Vector3(0.45, 0.85, 0))
	for l in [legL, legR]:
		mi(rock(0.42), stone, Vector3(0, -0.45, 0), l)
	if small:
		body.scale = Vector3.ONE * 0.45
	r.set_meta("rig", {"body": body, "legL": legL, "legR": legR, "armL": armL, "armR": armR, "head": head, "heavy": true})
	return r

static func _storm(team: int) -> Node3D:
	var r = humanoid({"skin": Color("7c8aa8"), "cloth": Color("5d6a85"), "metal": 0.75, "pants": Color("3c4458"), "boots": Color("2a3040"), "eye_glow": Color("8fe9ff"), "scale": 1.75})
	var rig: Dictionary = r.get_meta("rig")
	rig.torso.scale = Vector3(1.35, 1, 1.2)
	mi(sphere(0.17), glow(Color("59d8ff"), 3.5), Vector3(0, 0.85, 0.33), rig.body)
	var steel = mat(Color("8c9ab8"), 0.8, 0.25)
	for sx in [-0.5, 0.5]:
		var p = mi(sphere(0.2), steel, Vector3(sx, 1.08, 0), rig.body)
		p.scale = Vector3(1.3, 0.8, 1.2)
	var helm = mi(sphere(0.37), steel, Vector3(0, 0.17, 0), rig.head)
	helm.scale = Vector3(1, 0.85, 1)
	for sx in [-1, 1]:
		var h = mi(cone(0.07, 0.4, 8), team_mat(team), Vector3(sx * 0.3, 0.45, 0), rig.head)
		h.rotation.z = -sx * 0.5
	var ham = pivot(rig.armR, Vector3(0, -0.45, 0))
	mi(cyl(0.04, 0.04, 1.0, 8), mat(Color("3a2a1a")), Vector3(0, 0.3, 0), ham)
	mi(box(0.45, 0.28, 0.28), mat(Color("9aa7c2"), 0.9, 0.2), Vector3(0, 0.8, 0), ham)
	mi(box(0.47, 0.06, 0.3), glow(Color("59d8ff"), 3.0), Vector3(0, 0.8, 0), ham)
	ham.rotation.x = 0.4
	rig["weapon"] = ham
	return r

static func _knight(team: int) -> Node3D:
	var steel = mat(Color("c3c9d6"), 0.85, 0.25)
	var gold = mat(Color("d4a52a"), 0.8, 0.3)
	var r = humanoid({"skin": Color("f0c4a0"), "cloth": Color("c3c9d6"), "metal": 0.85, "pants": Color("6d7385"), "boots": Color("6d7385")})
	var rig: Dictionary = r.get_meta("rig")
	var helm = mi(sphere(0.37), steel, Vector3(0, 0.14, -0.02), rig.head)
	helm.scale = Vector3(1, 1.05, 1)
	mi(box(0.5, 0.06, 0.06), mat(Color("222222")), Vector3(0, 0.15, 0.34), rig.head)
	mi(box(0.08, 0.35, 0.45), team_mat(team), Vector3(0, 0.55, -0.05), rig.head)
	var sw = pivot(rig.armR, Vector3(0, -0.45, 0.05))
	mi(box(0.07, 0.8, 0.12), steel, Vector3(0, 0.45, 0), sw)
	mi(box(0.28, 0.06, 0.1), gold, Vector3(0, 0.05, 0), sw)
	sw.rotation.x = PI / 2.4
	var sh = pivot(rig.armL, Vector3(-0.08, -0.35, 0.18))
	var disc = mi(cyl(0.38, 0.38, 0.07, 20), team_mat(team), Vector3.ZERO, sh)
	disc.rotation.x = PI / 2
	mi(sphere(0.1, 10), gold, Vector3(0, 0, 0.05), sh)
	rig["weapon"] = sw
	rig["shield_mesh"] = sh
	return r

static func _sapper(team: int) -> Node3D:
	var r = humanoid({"skin": Color("8fd16a"), "cloth": Color("6b4a2b"), "pants": Color("4a3420"), "boots": Color("2c1d10"), "scale": 0.85})
	var rig: Dictionary = r.get_meta("rig")
	for sx in [-1, 1]:
		var e = mi(cone(0.08, 0.35, 6), mat(Color("8fd16a")), Vector3(sx * 0.38, 0.18, 0), rig.head)
		e.rotation.z = -sx * 1.3
	mi(cyl(0.34, 0.34, 0.12, 16), team_mat(team), Vector3(0, 0.42, 0), rig.head)
	mi(box(0.45, 0.12, 0.08), mat(Color("332211")), Vector3(0, 0.22, 0.3), rig.head)
	var barrel = pivot(rig.body, Vector3(0, 1.0, -0.42))
	mi(cyl(0.3, 0.3, 0.6, 14), mat(Color("8b5a2b")), Vector3.ZERO, barrel)
	mi(cyl(0.31, 0.31, 0.06, 14), mat(Color("333333"), 0.7), Vector3(0, 0.2, 0), barrel)
	mi(cyl(0.31, 0.31, 0.06, 14), mat(Color("333333"), 0.7), Vector3(0, -0.2, 0), barrel)
	mi(cyl(0.02, 0.02, 0.25, 4), mat(Color("222222")), Vector3(0, 0.42, 0), barrel)
	rig["spark"] = mi(sphere(0.07, 8), glow(Color("ffd23f"), 5.0), Vector3(0, 0.56, 0), barrel)
	return r

static func _drake(team: int) -> Node3D:
	var r = Node3D.new()
	var body = Node3D.new()
	r.add_child(body)
	var scale_m = mat(Color("3e9b5a"), 0.0, 0.45)
	var t = mi(sphere(0.55), scale_m, Vector3.ZERO, body)
	t.scale = Vector3(0.9, 0.8, 1.5)
	var belly = mi(sphere(0.45), mat(Color("e6c27a")), Vector3(0, -0.18, 0.1), body)
	belly.scale = Vector3(0.8, 0.6, 1.3)
	var neck = mi(cyl(0.18, 0.26, 0.7, 10), scale_m, Vector3(0, 0.35, 0.75), body)
	neck.rotation.x = 0.8
	var head = pivot(body, Vector3(0, 0.62, 1.1))
	mi(box(0.38, 0.3, 0.6), scale_m, Vector3(0, 0, 0.1), head)
	for sx in [-1, 1]:
		var h = mi(cone(0.06, 0.3, 6), mat(Color("eeeeee")), Vector3(sx * 0.12, 0.25, -0.1), head)
		h.rotation.x = -0.6
		mi(sphere(0.05, 6), glow(Color("ffd23f"), 3.0), Vector3(sx * 0.15, 0.08, 0.3), head)
	var tail = mi(cone(0.2, 1.3, 10), scale_m, Vector3(0, -0.05, -1.25), body)
	tail.rotation.x = -PI / 2
	var wingL = pivot(body, Vector3(-0.35, 0.25, 0.1))
	var wingR = pivot(body, Vector3(0.35, 0.25, 0.1))
	var wm = mat(Data.TEAM_COLORS[team])
	var wl = mi(box(1.5, 0.04, 0.8), wm, Vector3(-0.75, 0, -0.1), wingL)
	wl.rotation.y = -0.2
	var wr = mi(box(1.5, 0.04, 0.8), wm, Vector3(0.75, 0, -0.1), wingR)
	wr.rotation.y = 0.2
	var rider = humanoid({"skin": Color("f0c4a0"), "cloth": Data.TEAM_COLORS[team], "scale": 0.5})
	rider.position = Vector3(0, 0.3, 0.1)
	body.add_child(rider)
	r.set_meta("rig", {"body": body, "wingL": wingL, "wingR": wingR, "head": head, "flying": true})
	return r

static func _totem(team: int) -> Node3D:
	var r = Node3D.new()
	var stone = mat(Color("8a8f9c"), 0.0, 0.85)
	mi(cyl(0.85, 1.0, 0.35, 8), stone, Vector3(0, 0.17, 0), r)
	mi(cyl(0.45, 0.6, 1.6, 6), stone, Vector3(0, 1.1, 0), r)
	mi(cyl(0.62, 0.62, 0.12, 6), team_mat(team), Vector3(0, 1.4, 0), r)
	for i in 3:
		var rune = mi(box(0.12, 0.3, 0.05), glow(Data.TEAM_GLOW[team]), Vector3(sin(i * 2.1) * 0.5, 0.95, cos(i * 2.1) * 0.5), r)
		rune.rotation.y = i * 2.1
	var crystal = mi(gem(0.38), glow(Data.TEAM_GLOW[team], 2.5), Vector3(0, 2.4, 0), r)
	crystal.scale = Vector3(1, 1.5, 1)
	r.set_meta("rig", {"body": r, "crystal": crystal})
	return r

static func _meteor() -> Node3D:
	var r = Node3D.new()
	var rk = mi(rock(0.8), mat(Color("3a2a22"), 0.0, 0.9), Vector3.ZERO, r)
	for i in 7:
		var a = i * 0.9
		var c = mi(box(0.3, 0.08, 0.08), glow(Color("ff5a00"), 4.0), Vector3(cos(a) * 0.72, sin(a * 1.7) * 0.4, sin(a) * 0.72), rk)
		c.rotation.y = -a
	mi(sphere(0.95), mat(Color("ff7a1a"), 0.0, 0.5, 2.0, 0.35), Vector3.ZERO, r).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return r

static func _frost() -> Node3D:
	var r = Node3D.new()
	var ice = mat(Color("aeeaff"), 0.2, 0.1, 0.8, 0.9)
	for i in 7:
		var c = mi(gem(0.3), ice, Vector3((i - 3) * 0.15, 0.3, cos(i) * 0.15), r)
		c.scale = Vector3(0.6, 2.0 + (i % 3) * 0.6, 0.6)
		c.rotation = Vector3(sin(i * 1.3) * 0.4, 0, (i - 3) * 0.35)
	mi(sphere(0.25), glow(Color.WHITE, 3.0), Vector3(0, 0.2, 0), r)
	return r

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
static func tower(team: int, core: bool) -> Node3D:
	var g = Node3D.new()
	var stone = mat(Color("b9b2a5"), 0.0, 0.8)
	var dark = mat(Color("8c8579"), 0.0, 0.85)
	var wood = mat(Color("7a4a26"))
	var trim = team_mat(team)
	var gold = mat(Color("f4c542"), 0.7, 0.3)
	var front = 1.0 if team == 0 else -1.0
	if not core:
		mi(cyl(1.35, 1.55, 0.45, 10), dark, Vector3(0, 0.22, 0), g)
		mi(cyl(1.15, 1.3, 2.2, 12), stone, Vector3(0, 1.55, 0), g)
		for i in 10:
			var a = i / 10.0 * TAU
			var b = mi(box(0.35, 0.22, 0.12), dark, Vector3(cos(a) * 1.25, 0.9 + (i % 2) * 0.7, sin(a) * 1.25), g)
			b.rotation.y = -a + PI / 2
		mi(cyl(1.4, 1.2, 0.3, 12), trim, Vector3(0, 2.75, 0), g)
		for i in 8:
			var a = i / 8.0 * TAU
			mi(box(0.35, 0.4, 0.35), stone, Vector3(cos(a) * 1.2, 3.1, sin(a) * 1.2), g)
		mi(box(0.6, 0.85, 0.1), wood, Vector3(0, 0.85, 1.25 * front), g)
		var guard = humanoid({"skin": Color("f0c4a0"), "cloth": Data.TEAM_COLORS[team], "scale": 0.7})
		guard.position = Vector3(0, 2.85, 0)
		g.add_child(guard)
		mi(box(0.9, 0.08, 0.1), wood, Vector3(0, 0.55, 0.45), guard.get_meta("rig").body)
		g.set_meta("guard", guard)
		mi(cyl(0.04, 0.04, 1.3, 6), wood, Vector3(0.9, 3.6, -0.6), g)
		g.set_meta("flag", mi(box(0.02, 0.45, 0.6), trim, Vector3(0.9, 3.95, -0.3), g))
		g.set_meta("crystal", mi(gem(0.25), glow(Data.TEAM_GLOW[team]), Vector3(-0.9, 3.7, -0.6), g))
	else:
		mi(box(3.6, 0.5, 3.6), dark, Vector3(0, 0.25, 0), g)
		mi(box(3.1, 2.4, 3.1), stone, Vector3(0, 1.7, 0), g)
		mi(box(3.4, 0.3, 3.4), trim, Vector3(0, 2.95, 0), g)
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				mi(cyl(0.5, 0.55, 3.6, 10), stone, Vector3(sx * 1.5, 1.8, sz * 1.5), g)
				mi(cone(0.65, 0.9, 10), trim, Vector3(sx * 1.5, 4.05, sz * 1.5), g)
				mi(sphere(0.12, 8), gold, Vector3(sx * 1.5, 4.55, sz * 1.5), g)
		mi(box(0.9, 1.3, 0.12), wood, Vector3(0, 1.0, 1.58 * front), g)
		mi(cyl(0.6, 0.9, 0.5, 8), gold, Vector3(0, 3.35, 0), g)
		var crystal = mi(gem(0.75), glow(Data.TEAM_GLOW[team], 2.0), Vector3(0, 4.6, 0), g)
		crystal.scale = Vector3(1, 1.6, 1)
		g.set_meta("crystal", crystal)
		var guard = humanoid({"skin": Color("f0c4a0"), "cloth": Data.TEAM_COLORS[team], "scale": 0.85})
		var crown = mi(cone(0.3, 0.45, 5), gold, Vector3(0, 0.6, 0), guard.get_meta("rig").head)
		crown.name = "Crown"
		guard.position = Vector3(0.9, 3.1, 0.9 * front)
		g.add_child(guard)
		g.set_meta("guard", guard)
	_set_shadows(g)
	return g

static func rubble() -> Node3D:
	var g = Node3D.new()
	var s = mat(Color("6d675d"), 0.0, 0.95)
	for i in 9:
		var r = randf_range(0.25, 0.7)
		var o = mi(rock(r), s, Vector3(randf_range(-1.1, 1.1), r * 0.5, randf_range(-1.1, 1.1)), g)
		o.rotation = Vector3(randf() * 3, randf() * 3, 0)
	return g

# ---------- Arène sur île flottante ----------
static func ground_texture(isl: Dictionary) -> ImageTexture:
	var W = 18
	var H = 32
	var px = 24
	var img = Image.create(W * px, H * px, false, Image.FORMAT_RGBA8)
	for i in W:
		for j in H:
			img.fill_rect(Rect2i(i * px, j * px, px, px), isl.grass if (i + j) % 2 else isl.grass2)
	var rng = RandomNumberGenerator.new()
	rng.seed = 7
	for k in 3000:
		var x = rng.randi_range(0, W * px - 2)
		var y = rng.randi_range(0, H * px - 2)
		var c: Color = img.get_pixel(x, y)
		img.fill_rect(Rect2i(x, y, 2, 2), c.darkened(0.06) if rng.randf() < 0.5 else c.lightened(0.06))
	var tile: Color = isl.tile
	var paths = [[-6.25, -12, -4.75, 12], [4.75, -12, 6.25, 12], [-5.5, 11.2, 5.5, 12.4], [-5.5, -12.4, 5.5, -11.2]]
	for p in paths:
		var x0 = int((p[0] + 9) * px)
		var z0 = int((p[1] + 16) * px)
		var x1 = int((p[2] + 9) * px)
		var z1 = int((p[3] + 16) * px)
		img.fill_rect(Rect2i(x0, z0, x1 - x0, z1 - z0), tile.darkened(0.15))
		var step = int(px * 0.75)
		var yy = z0
		while yy < z1:
			var xx = x0
			while xx < x1:
				img.fill_rect(Rect2i(xx + 1, yy + 1, min(step, x1 - xx) - 2, min(step, z1 - yy) - 2), tile)
				xx += step
			yy += step
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

static func arena(isl: Dictionary) -> Node3D:
	var g = Node3D.new()
	var ground = MeshInstance3D.new()
	var pm = PlaneMesh.new()
	pm.size = Vector2(18, 32)
	ground.mesh = pm
	var gm = StandardMaterial3D.new()
	gm.albedo_texture = ground_texture(isl)
	gm.roughness = 0.95
	gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	ground.material_override = gm
	g.add_child(ground)
	var cliff = mat(isl.cliff, 0.0, 0.95)
	var base = mi(cyl(15, 7, 10, 10), cliff, Vector3(0, -5.3, 0), g)
	base.scale = Vector3(1, 1, 1.75)
	mi(box(24, 0.6, 38), mat(isl.grass, 0.0, 1.0), Vector3(0, -0.32, 0), g)
	var rng = RandomNumberGenerator.new()
	rng.seed = 3
	for i in 14:
		var rk = mi(rock(rng.randf_range(1.0, 2.5)), cliff, Vector3(rng.randf_range(-11, 11), rng.randf_range(-10, -2), rng.randf_range(-20, 20)), g)
		rk.rotation = Vector3(rng.randf() * 3, rng.randf() * 3, 0)
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
	g.add_child(water)
	var bank = mat(Color("a8865a"), 0.0, 0.9)
	mi(box(18, 0.25, 0.25), bank, Vector3(0, -0.02, 1.25), g)
	mi(box(18, 0.25, 0.25), bank, Vector3(0, -0.02, -1.25), g)
	for bx in [-5.5, 5.5]:
		for i in 7:
			mi(box(2.4, 0.18, 0.42), mat(Color("9a6233")), Vector3(bx, 0.08, -1.35 + i * 0.45), g)
		for sx in [-1.25, 1.25]:
			mi(box(0.12, 0.5, 3.1), mat(Color("6b3f1f")), Vector3(bx + sx, 0.4, 0), g)
	var wall = mat(Color("c9bfae"), 0.0, 0.85)
	for sx in [-9.3, 9.3]:
		mi(box(0.6, 0.7, 32.6), wall, Vector3(sx, 0.35, 0), g)
		for z in range(-15, 16, 3):
			mi(box(0.8, 0.9, 0.8), wall, Vector3(sx, 0.45, z), g)
	for sz in [-16.3, 16.3]:
		mi(box(19.2, 0.7, 0.6), wall, Vector3(0, 0.35, sz), g)
	for i in 18:
		var side = 1 if i % 2 else -1
		_tree(g, Vector3(side * rng.randf_range(10.6, 12.4), 0, -16 + i / 18.0 * 32 + rng.randf()), rng.randf_range(0.8, 1.3), isl)
	for sz in [-1, 1]:
		for i in 6:
			_tree(g, Vector3(-9 + i * 3.6 + rng.randf(), 0, sz * rng.randf_range(17.4, 18.4)), 0.9, isl)
	for sx in [-8.6, 8.6]:
		for sz in [-1.8, 1.8]:
			mi(cyl(0.08, 0.1, 1.1, 6), mat(Color("4a2f1f")), Vector3(sx, 0.55, sz), g)
			mi(sphere(0.16, 8), glow(Color("ffa21f"), 4.0), Vector3(sx, 1.2, sz), g)
	_set_shadows(g)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return g

static func _tree(parent: Node3D, pos: Vector3, s: float, isl: Dictionary) -> void:
	var t = Node3D.new()
	t.position = pos
	t.scale = Vector3.ONE * s
	mi(cyl(0.18, 0.25, 1.2, 8), mat(Color("6b4423")), Vector3(0, 0.6, 0), t)
	mi(rock(0.9), mat(isl.leaf, 0.0, 0.8), Vector3(0, 1.7, 0), t)
	mi(rock(0.65), mat(isl.leaf.lightened(0.1), 0.0, 0.8), Vector3(0.3, 2.3, 0.1), t)
	parent.add_child(t)
