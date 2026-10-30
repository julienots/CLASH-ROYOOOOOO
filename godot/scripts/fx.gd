class_name FX
extends Node3D
## Effets visuels : particules, ondes de choc, éclairs, chiffres de dégâts.

var _quad_add: QuadMesh
var _quad_norm: QuadMesh
var _chunk: BoxMesh
var _font: Font

func _ready() -> void:
	_quad_add = _make_quad(true)
	_quad_norm = _make_quad(false)
	_chunk = BoxMesh.new()
	_chunk.size = Vector3(0.25, 0.2, 0.25)
	_font = load("res://assets/lilita_one.woff2")

func _make_quad(additive: bool) -> QuadMesh:
	var q = QuadMesh.new()
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _radial_tex()
	m.no_depth_test = false
	q.material = m
	return q

static var _tex: ImageTexture
static func _radial_tex() -> ImageTexture:
	if _tex:
		return _tex
	var s = 64
	var img = Image.create(s, s, false, Image.FORMAT_RGBA8)
	for x in s:
		for y in s:
			var d = Vector2(x - s / 2.0, y - s / 2.0).length() / (s / 2.0)
			var a = clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a * (3.0 - 2.0 * a)))
	_tex = ImageTexture.create_from_image(img)
	return _tex

func burst(pos: Vector3, color: Color, amount := 12, speed := 3.0, size := 0.4, life := 0.6, gravity := -6.0, additive := true, up := 1.0, grow := false) -> void:
	var p = CPUParticles3D.new()
	p.mesh = _quad_add if additive else _quad_norm
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = life
	p.direction = Vector3(0, up, 0)
	p.spread = 180.0 if up < 0.5 else 75.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity, 0)
	p.damping_min = 1.0
	p.damping_max = 3.0
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size * 1.4
	var curve = Curve.new()
	if grow:
		curve.add_point(Vector2(0, 0.5))
		curve.add_point(Vector2(1, 1.6))
	else:
		curve.add_point(Vector2(0, 1))
		curve.add_point(Vector2(1, 0.1))
	p.scale_amount_curve = curve
	var grad = Gradient.new()
	grad.set_color(0, color)
	grad.set_color(1, Color(color, 0.0))
	p.color_ramp = grad
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.2).timeout.connect(p.queue_free)

func debris(pos: Vector3, color: Color, amount := 14, speed := 8.0) -> void:
	var p = CPUParticles3D.new()
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	var mesh = _chunk.duplicate()
	mesh.material = m
	p.mesh = mesh
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 1.4
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -22, 0)
	p.angular_velocity_min = -400
	p.angular_velocity_max = 400
	p.particle_flag_rotate_y = true
	p.scale_amount_min = 0.6
	p.scale_amount_max = 2.2
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.6).timeout.connect(p.queue_free)

func dust(pos: Vector3, amount := 10, r := 1.0) -> void:
	burst(Vector3(pos.x, 0.25, pos.z), Color(0.9, 0.85, 0.72, 0.85), amount, 3.0 * r, 0.9 * r, 0.7, 0.0, false, 0.15, true)

func ring(pos: Vector3, radius: float, color: Color, dur := 0.45, width := 0.15) -> void:
	var t = TorusMesh.new()
	t.inner_radius = 1.0 - width
	t.outer_radius = 1.0
	t.rings = 32
	t.ring_segments = 4
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = color
	var o = MeshInstance3D.new()
	o.mesh = t
	o.material_override = m
	o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	o.position = Vector3(pos.x, 0.12, pos.z)
	o.scale = Vector3(radius * 0.2, 0.05, radius * 0.2)
	add_child(o)
	var tw = create_tween().set_parallel()
	tw.tween_property(o, "scale", Vector3(radius, 0.05, radius), dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, dur).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(o.queue_free)

func flash(pos: Vector3, color: Color, size := 3.0, dur := 0.25) -> void:
	var o = MeshInstance3D.new()
	var q = QuadMesh.new()
	q.size = Vector2(1, 1)
	var m: StandardMaterial3D = _quad_add.material.duplicate()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = false
	m.albedo_color = color
	o.mesh = q
	o.material_override = m
	o.position = pos
	o.scale = Vector3.ONE * size * 0.3
	add_child(o)
	var tw = create_tween().set_parallel()
	tw.tween_property(o, "scale", Vector3.ONE * size, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, dur)
	tw.chain().tween_callback(o.queue_free)

func explosion(pos: Vector3, r: float, color: Color) -> void:
	flash(pos + Vector3(0, 0.8, 0), Color(1, 0.95, 0.7), r * 3.0, 0.3)
	burst(pos + Vector3(0, 0.5, 0), color, 30, r * 4.0, 1.0, 0.7, -4.0)
	burst(pos + Vector3(0, 0.5, 0), Color(1, 0.95, 0.6), 12, r * 2.0, 1.4, 0.35, 0.0)
	burst(pos + Vector3(0, 0.4, 0), Color(0.3, 0.3, 0.3, 0.8), 14, r * 2.0, 1.4, 1.1, 2.0, false, 1.0, true)
	ring(pos, r * 1.2, color, 0.5, 0.25)
	ring(pos, r * 0.8, Color.WHITE, 0.3, 0.1)

func bolt(points: Array, color := Color("9fe8ff")) -> void:
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = color
	var holder = Node3D.new()
	add_child(holder)
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var prev = a
		for k in range(1, 7):
			var p = a.lerp(b, k / 6.0)
			if k < 6:
				p += Vector3(randf_range(-0.4, 0.4), randf_range(-0.3, 0.3), randf_range(-0.4, 0.4))
			_segment(holder, prev, p, 0.07, m)
			_segment(holder, prev, p, 0.025, Models.glow(Color.WHITE, 4.0))
			prev = p
		burst(b, color, 8, 3.0, 0.5, 0.3, 0.0)
		flash(b, color, 1.6, 0.2)
	var tw = create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.25)
	tw.tween_callback(holder.queue_free)

func beam(a: Vector3, b: Vector3, color: Color) -> void:
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = color
	var holder = Node3D.new()
	add_child(holder)
	_segment(holder, a, b, 0.12, m)
	_segment(holder, a, b, 0.04, Models.glow(Color.WHITE, 3.0))
	flash(b, color, 1.4, 0.2)
	var tw = create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.2)
	tw.tween_callback(holder.queue_free)

func _segment(parent: Node3D, a: Vector3, b: Vector3, r: float, m: Material) -> void:
	var len = a.distance_to(b)
	if len < 0.01:
		return
	var o = MeshInstance3D.new()
	var c = CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = len
	c.radial_segments = 5
	c.rings = 1
	o.mesh = c
	o.material_override = m
	o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(o)
	var mid = (a + b) * 0.5
	var dir = (b - a).normalized()
	var axis = Vector3.UP.cross(dir)
	var basis = Basis()
	if axis.length() > 0.0001:
		basis = Basis(axis.normalized(), acos(clampf(Vector3.UP.dot(dir), -1, 1)))
	o.global_transform = Transform3D(basis, mid)

## Chiffre ou texte flottant qui « pop » puis s'envole.
func float_text(pos: Vector3, text: String, color: Color, size := 64, rise := 1.2, dur := 0.9) -> void:
	var l = Label3D.new()
	l.text = text
	l.font = _font
	l.font_size = size
	l.outline_size = int(size * 0.22)
	l.outline_modulate = Color(0.05, 0.08, 0.2)
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 10
	l.outline_render_priority = 9
	l.pixel_size = 0.006
	l.position = pos
	l.scale = Vector3.ONE * 0.2
	add_child(l)
	var tw = create_tween()
	tw.tween_property(l, "scale", Vector3.ONE * 1.25, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector3.ONE, 0.1)
	tw.parallel().tween_property(l, "position:y", pos.y + rise, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(l, "modulate:a", 0.0, dur * 0.4).set_delay(dur * 0.6)
	tw.parallel().tween_property(l, "outline_modulate:a", 0.0, dur * 0.4).set_delay(dur * 0.6)
	tw.tween_callback(l.queue_free)

## Âme qui s'envole à la mort d'une unité.
func soul(pos: Vector3, team: int) -> void:
	var o = MeshInstance3D.new()
	o.mesh = Models.sphere(0.3, 10)
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(Data.TEAM_GLOW[team], 0.7)
	o.material_override = m
	o.position = pos + Vector3(0, 0.8, 0)
	o.scale = Vector3(1, 1.4, 1)
	add_child(o)
	var tw = create_tween().set_parallel()
	tw.tween_property(o, "position:y", pos.y + 3.5, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(o, "position:x", pos.x + 0.4, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.9).set_ease(Tween.EASE_IN)
	tw.tween_property(o, "scale", Vector3(0.4, 0.9, 0.4), 0.9)
	tw.chain().tween_callback(o.queue_free)
