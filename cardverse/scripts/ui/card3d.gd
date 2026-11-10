class_name Card3D extends SubViewportContainer
## Carte en vraie 3D : plaque à coins arrondis avec épaisseur (tranche blanche comme un vrai carton),
## recto = rendu 2D animé de la carte (texture de viewport), verso = dos de carte, vernis brillant
## et reflet de lumière qui suit la rotation. Sert à la fiche détaillée.

const CW := 1.0
const CH := 1.4
const RAD := 0.055
const THICK := 0.014

var front_tex: Texture2D
var uv_rect := Rect2(0, 0, 1, 1)   # zone de la carte dans la texture du recto
var back_tex: Texture2D
var rot := Vector2.ZERO            # x = rotation Y (tourner), y = rotation X (pencher)
var margin := 1.3
var vp: SubViewport
var card: Node3D
var _glare: DirectionalLight3D
var _shadow: MeshInstance3D
var _t := 0.0

static func make(front: Texture2D, uvr: Rect2, px: Vector2, margin_v := 1.3) -> Card3D:
	var c := Card3D.new()
	c.front_tex = front
	c.uv_rect = uvr
	c.margin = margin_v
	c.custom_minimum_size = px * margin_v
	c.size = px * margin_v
	c.stretch = true
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _ready() -> void:
	vp = SubViewport.new()
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 24.0
	cam.position = Vector3(0, 0, margin * CH / (2.0 * tan(deg_to_rad(cam.fov) / 2.0)))
	vp.add_child(cam)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 0.92
	env.environment = e
	vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-20), deg_to_rad(-25), 0)
	key.light_energy = 0.18
	key.light_specular = 0.35
	vp.add_child(key)
	_glare = DirectionalLight3D.new()
	_glare.light_energy = 0.08
	_glare.light_specular = 0.9
	vp.add_child(_glare)
	# ombre douce projetée derrière la carte
	_shadow = MeshInstance3D.new()
	var sq := QuadMesh.new()
	sq.size = Vector2(CW * 1.25, CH * 1.2)
	_shadow.mesh = sq
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_texture = _shadow_tex()
	sm.albedo_color = Color(0, 0, 0, 0.55)
	_shadow.material_override = sm
	_shadow.position = Vector3(0.06, -0.08, -0.35)
	vp.add_child(_shadow)
	card = _build_card()
	vp.add_child(card)

func _process(delta: float) -> void:
	_t += delta
	card.rotation = Vector3(rot.y, rot.x, 0)
	# l'ombre glisse à l'opposé de l'inclinaison, comme sous une lampe
	_shadow.position = Vector3(0.06 - sin(rot.x) * 0.12, -0.08 + sin(rot.y) * 0.12, -0.35)
	_shadow.scale = Vector3(maxf(0.15, absf(cos(rot.x))), maxf(0.3, absf(cos(rot.y))), 1)
	# le reflet tourne lentement : la lumière glisse sur le vernis
	_glare.rotation = Vector3(deg_to_rad(-8) + sin(_t * 0.5) * 0.15, sin(_t * 0.7) * 0.6, 0)

## Côté visible : true si le recto fait face à la caméra.
func front_visible() -> bool:
	return cos(rot.x) * cos(rot.y) >= 0.0

func _build_card() -> Node3D:
	var root := Node3D.new()
	var front := MeshInstance3D.new()
	front.mesh = _face(true)
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = front_tex
	fm.roughness = 0.3
	fm.metallic_specular = 0.5
	fm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	front.material_override = fm
	root.add_child(front)
	var back := MeshInstance3D.new()
	back.mesh = _face(false)
	var bm := StandardMaterial3D.new()
	bm.albedo_texture = back_tex if back_tex else DB.tex("res://assets/ui/card_back.png")
	bm.roughness = 0.3
	bm.metallic_specular = 0.6
	back.material_override = bm
	root.add_child(back)
	var edge := MeshInstance3D.new()
	edge.mesh = _edge()
	var em := StandardMaterial3D.new()
	em.albedo_color = Color(0.92, 0.9, 0.86)   # âme du carton, légèrement crème
	em.roughness = 0.8
	em.cull_mode = BaseMaterial3D.CULL_DISABLED
	edge.material_override = em
	root.add_child(edge)
	return root

# ---------------------------------------------------------------- géométrie
static func _outline() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var hw := CW / 2.0 - RAD
	var hh := CH / 2.0 - RAD
	var centers := [Vector2(hw, hh), Vector2(-hw, hh), Vector2(-hw, -hh), Vector2(hw, -hh)]
	for k in 4:
		for s in 7:
			var a := PI / 2.0 * k + PI / 2.0 * s / 6.0
			pts.append(centers[k] + Vector2(cos(a), sin(a)) * RAD)
	return pts

func _uv_of(p: Vector2, flip: bool) -> Vector2:
	var u := (p.x + CW / 2.0) / CW
	var v := 1.0 - (p.y + CH / 2.0) / CH
	if flip:
		u = 1.0 - u
		return Vector2(u, v)
	return uv_rect.position + Vector2(u, v) * uv_rect.size

func _face(is_front: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := _outline()
	var z := THICK / 2.0 if is_front else -THICK / 2.0
	var n := pts.size()
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var tri := [Vector2.ZERO, b, a] if is_front else [Vector2.ZERO, a, b]
		for p in tri:
			st.set_normal(Vector3(0, 0, 1 if is_front else -1))
			st.set_uv(_uv_of(p, not is_front))
			st.add_vertex(Vector3(p.x, p.y, z))
	return st.commit()

func _edge() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := _outline()
	var n := pts.size()
	var z0 := -THICK / 2.0
	var z1 := THICK / 2.0
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var quad := [Vector3(a.x, a.y, z1), Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0), Vector3(a.x, a.y, z1), Vector3(b.x, b.y, z0), Vector3(b.x, b.y, z1)]
		for q in quad:
			st.add_vertex(q)
	st.generate_normals()
	return st.commit()

static func _shadow_tex() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	return gt
