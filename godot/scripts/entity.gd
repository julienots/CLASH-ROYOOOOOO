class_name Entity
extends Node3D
## Une unité, un bâtiment ou une tour sur le terrain (état de simulation + animations).

var id = 0
var team = 0
var card_id = ""
var kind = "unit"  # unit | building | tower
var core = false
var lane = -1
var active = true
var x = 0.0
var z = 0.0
var y = 0.0
var hp = 0.0
var max_hp = 0.0
var shield = 0.0
var max_shield = 0.0
var radius = 0.5
var speed = 0.0
var dmg = 0.0
var hit_speed = 1.0
var attack_range = 1.0
var cooldown = 0.3
var windup = 0.0
var targets = "both"
var attack = "melee"
var flying = false
var splash = 0.0
var frozen = 0.0
var alive = true
var deploy = 0.0
var deploy_total = 1.0
var target: Entity = null
var retarget = 0.0
var first_strike = 0.0
var is_building = false
var lifetime = 0.0
var heavy = false
var seed = 0.0
var moving = false
var facing = 0.0
var attack_anim = 0.0
var hit_pulse = 0.0
var base_scale = 1.0

var model: Node3D
var ring: MeshInstance3D
var shadow_blob: MeshInstance3D
var meshes: Array = []

static var flash_mat: StandardMaterial3D
static var ice_mat: StandardMaterial3D

static func _init_mats() -> void:
	if flash_mat:
		return
	flash_mat = StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flash_mat.albedo_color = Color(1, 1, 1, 0.75)
	ice_mat = StandardMaterial3D.new()
	ice_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ice_mat.albedo_color = Color(0.35, 0.75, 1.0, 0.55)

func setup_model(m: Node3D) -> void:
	_init_mats()
	model = m
	add_child(m)
	_collect(m)

func _collect(n: Node) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			meshes.append(c)
		_collect(c)

func set_overlay(m: Material) -> void:
	for mi in meshes:
		if is_instance_valid(mi):
			mi.material_overlay = m

func position_vec(h := 0.0) -> Vector3:
	return Vector3(x, y + h, z)

## Animation de chargement d'attaque (anticipation) puis frappe.
func play_attack() -> void:
	attack_anim = 1.0

## Réaction visuelle à un coup : flash blanc + écrasement élastique.
func on_hit(big: bool) -> void:
	hit_pulse = 0.18 if big else 0.1
	set_overlay(flash_mat)
	get_tree().create_timer(0.07).timeout.connect(func():
		if is_instance_valid(self) and alive:
			set_overlay(ice_mat if frozen > 0.0 else null))
	if kind == "tower" and model:
		var tw = create_tween()
		var amp = 0.06 if big else 0.03
		tw.tween_property(model, "rotation:z", amp, 0.04)
		tw.tween_property(model, "rotation:z", -amp, 0.06)
		tw.tween_property(model, "rotation:z", 0.0, 0.08)

func freeze(t: float) -> void:
	frozen = max(frozen, t)
	set_overlay(ice_mat)

func visual_update(dt: float, now: float) -> void:
	if not alive:
		return
	if kind == "tower":
		if model.has_meta("crystal"):
			var c: Node3D = model.get_meta("crystal")
			c.rotation.y += dt * 1.5
		if model.has_meta("flag"):
			model.get_meta("flag").rotation.y = sin(now * 3.0 + x) * 0.3
		if model.has_meta("guard") and target and is_instance_valid(target) and target.alive:
			var g: Node3D = model.get_meta("guard")
			var a = atan2(target.x - x, target.z - z) - model.rotation.y
			g.rotation.y = lerp_angle(g.rotation.y, a, min(1.0, dt * 8.0))
			if attack_anim > 0.0:
				Models.animate(g, now, false, sin((1.0 - attack_anim) * PI), 0.0)
		attack_anim = max(0.0, attack_anim - dt * 4.0)
		hit_pulse = max(0.0, hit_pulse - dt)
		var s = 1.0 + hit_pulse * 0.4
		model.scale = Vector3(s, 1.0 - hit_pulse * 0.5, s)
		_check_thaw()
		return
	# chute depuis le ciel pendant le déploiement + écrasement à l'atterrissage
	var drop = 0.0
	var squash = Vector3.ONE
	if deploy > 0.0:
		var k: float = clamp(1.0 - deploy / deploy_total, 0.0, 1.0)
		if k < 0.45:
			var f = k / 0.45
			drop = (1.0 - f * f) * 6.0
			squash = Vector3(0.8, 1.35, 0.8)
		else:
			var f = (k - 0.45) / 0.55
			var b = sin(f * PI * 2.5) * exp(-f * 4.0)
			squash = Vector3(1.0 + b * 0.35, 1.0 - b * 0.45, 1.0 + b * 0.35)
	position = Vector3(x, y + drop, z)
	ring.position = Vector3(x, 0.04, z)
	if shadow_blob:
		shadow_blob.position = Vector3(x, 0.05, z)
		var ss = clampf(1.0 - drop / 8.0, 0.3, 1.0)
		shadow_blob.scale = Vector3(ss, 1, ss)
	model.rotation.y = lerp_angle(model.rotation.y, facing, min(1.0, dt * 12.0))
	attack_anim = max(0.0, attack_anim - dt * 3.0)
	# courbe d'attaque : anticipation (recul) puis frappe rapide
	var atk = 0.0
	if attack_anim > 0.0:
		var p = 1.0 - attack_anim
		atk = -0.35 * sin(p / 0.35 * PI) if p < 0.35 else sin((p - 0.35) / 0.65 * PI) * 1.2
	var mv = moving and frozen <= 0.0 and deploy <= 0.0
	Models.animate(model, now if frozen <= 0.0 else 0.0, mv, atk, seed)
	hit_pulse = max(0.0, hit_pulse - dt)
	var hp_s = 1.0 + hit_pulse * 1.2
	var sc = base_scale * hp_s
	scale = Vector3(squash.x * sc, squash.y * (base_scale * (1.0 - hit_pulse * 0.8)), squash.z * sc)
	_check_thaw()

var _was_frozen = false
func _check_thaw() -> void:
	if frozen > 0.0:
		_was_frozen = true
	elif _was_frozen:
		_was_frozen = false
		set_overlay(null)
