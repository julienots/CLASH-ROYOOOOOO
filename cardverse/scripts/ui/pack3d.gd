class_name Pack3D extends SubViewportContainer
## Booster rendu en vraie 3D : maillage « coussin » bombé, bords sertis, recto illustré, verso teinté,
## matériau foil métallique, lumière principale + reflet qui balaie le paquet.
## Utilisé dans la boutique (rotation douce), à l'ouverture (rotation au doigt, déchirure du haut)
## et dans les displays 3D (pack_node()).

const PACK_W := 1.0
const PACK_H := 1.545          # proportions 330 x 510
const TOP_FRAC := 0.16         # bande du haut détachée à la déchirure

var booster_id := ""
var spin := 0.0                # rotation Y imposée (radians)
var tilt := 0.0                # rotation X imposée
var idle := true               # balancement automatique
var margin := 1.25             # zone visible autour du paquet (rotation sans coupure)
var _t := 0.0
var _phase := 0.0
var vp: SubViewport
var rig: Node3D
var top: Node3D
var _light2: DirectionalLight3D

static var _mesh_cache := {}

## Vue 3D d'un booster, à placer dans l'interface. `px` est la taille du paquet en pixels.
static func make(bid: String, px: Vector2, margin_v := 1.25) -> Pack3D:
	var p := Pack3D.new()
	p.booster_id = bid
	p.margin = margin_v
	p.custom_minimum_size = px * margin_v
	p.size = px * margin_v
	p.stretch = true
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func _ready() -> void:
	_phase = randf() * TAU
	vp = SubViewport.new()
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 26.0
	# à cette distance, la hauteur visible dans le plan du paquet vaut margin * PACK_H
	cam.position = Vector3(0, 0, margin * PACK_H / (2.0 * tan(deg_to_rad(cam.fov) / 2.0)))
	vp.add_child(cam)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.85, 0.95)
	e.ambient_light_energy = 0.55
	env.environment = e
	vp.add_child(env)
	var l1 := DirectionalLight3D.new()
	l1.rotation = Vector3(deg_to_rad(-25), deg_to_rad(-30), 0)
	l1.light_energy = 0.9
	vp.add_child(l1)
	_light2 = DirectionalLight3D.new()
	_light2.light_color = Color(1.0, 0.95, 0.85)
	_light2.light_energy = 0.45
	_light2.light_specular = 0.9
	vp.add_child(_light2)
	rig = pack_node(booster_id)
	vp.add_child(rig)
	top = rig.get_node("top")

func _process(delta: float) -> void:
	_t += delta
	# rendu seulement quand le paquet est à l'écran (listes de la boutique)
	var on_screen := get_global_rect().intersects(get_viewport_rect()) and is_visible_in_tree()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on_screen else SubViewport.UPDATE_DISABLED
	if not on_screen:
		return
	var ry := spin
	var rx := tilt
	if idle:
		ry += sin(_t * 0.9 + _phase) * 0.45
		rx += sin(_t * 0.6 + _phase) * 0.06
	rig.rotation = Vector3(rx, ry, sin(_t * 0.7 + _phase) * 0.02)
	# le reflet balaie le paquet en continu (effet foil)
	_light2.rotation = Vector3(deg_to_rad(-10), sin(_t * 0.8 + _phase) * 1.1, 0)

## Incline la bande du haut pendant la déchirure (p de 0 à 1).
func tear_progress(p: float) -> void:
	if top:
		top.rotation.z = -p * 0.08
		top.position.x = p * 0.02

## La bande du haut s'envole.
func fly_top() -> void:
	if not top:
		return
	var t := create_tween().set_parallel(true)
	t.tween_property(top, "position", top.position + Vector3(0.9, 1.4, 0.6), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(top, "rotation", Vector3(0.8, 1.2, -1.6), 0.6)

# ---------------------------------------------------------------- maillage
## Noeud 3D d'un booster (corps + bande du haut), centré, 1 unité de large.
static func pack_node(bid: String) -> Node3D:
	var root := Node3D.new()
	var tex: Texture2D = DB.tex("res://assets/ui/packs/%s.png" % bid)
	var back: Texture2D = DB.tex("res://assets/ui/packs/_back.png")
	var col := Color(DB.booster(bid).get("color", "#7a6cff"))
	var front_m := StandardMaterial3D.new()
	front_m.albedo_texture = tex
	front_m.metallic = 0.3
	front_m.metallic_specular = 0.55
	front_m.roughness = 0.38
	front_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	front_m.alpha_scissor_threshold = 0.5
	front_m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	front_m.cull_mode = BaseMaterial3D.CULL_BACK
	var back_m := front_m.duplicate() as StandardMaterial3D
	back_m.albedo_texture = back
	back_m.albedo_color = col.lerp(Color(0.25, 0.22, 0.3), 0.35)
	back_m.metallic = 0.3
	var body := MeshInstance3D.new()
	body.mesh = _pillow(TOP_FRAC, 1.0)
	body.set_surface_override_material(0, front_m)
	body.set_surface_override_material(1, back_m)
	body.name = "body"
	root.add_child(body)
	var top_n := Node3D.new()
	top_n.name = "top"
	root.add_child(top_n)
	var tm := MeshInstance3D.new()
	tm.mesh = _pillow(0.0, TOP_FRAC)
	tm.set_surface_override_material(0, front_m)
	tm.set_surface_override_material(1, back_m)
	top_n.add_child(tm)
	return root

## Surface bombée entre v0 et v1 (0 = haut du paquet), recto (surface 0) et verso (surface 1).
static func _pillow(v0: float, v1: float) -> ArrayMesh:
	var key := "%.3f_%.3f" % [v0, v1]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var am := ArrayMesh.new()
	var nx := 18
	var ny := maxi(4, int(round(28 * (v1 - v0))))
	for side in 2:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var sgn := 1.0 if side == 0 else -1.0
		for j in ny:
			for i in nx:
				var quad := [[i, j], [i + 1, j], [i + 1, j + 1], [i, j], [i + 1, j + 1], [i, j + 1]]
				if side == 1:
					quad = [[i, j], [i + 1, j + 1], [i + 1, j], [i, j], [i, j + 1], [i + 1, j + 1]]
				for q in quad:
					var u := float(q[0]) / nx
					var v := lerpf(v0, v1, float(q[1]) / ny)
					st.set_uv(Vector2(1.0 - u if side == 1 else u, v))
					st.add_vertex(_pt(u, v, sgn))
		st.generate_normals()
		st.commit(am)
	_mesh_cache[key] = am
	return am

## Point de la surface : bombé au centre, plat sur les bords et dans les zones serties.
static func _pt(u: float, v: float, sgn: float) -> Vector3:
	var x := (u - 0.5) * PACK_W
	var y := (0.5 - v) * PACK_H
	var crimp := 0.055
	var vv := clampf((v - crimp) / (1.0 - 2.0 * crimp), 0.0, 1.0)
	var bx := 1.0 - pow(absf(u * 2.0 - 1.0), 2.4)
	var by := 1.0 - pow(absf(vv * 2.0 - 1.0), 3.0)
	if v < crimp or v > 1.0 - crimp:
		by = 0.0
	var z := 0.085 * bx * by * sgn
	# légers plis horizontaux du film plastique
	z += 0.004 * sin(v * 40.0) * bx * by * sgn
	return Vector3(x, y, z)
