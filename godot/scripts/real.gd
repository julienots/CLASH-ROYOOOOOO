class_name RealModels
## Vrais modèles 3D animés (KayKit, CC0) : personnages, armes et décors.

const DIR := "res://assets/models/"

## Configuration de chaque carte : fichier, échelle, équipement visible et animations.
const UNITS := {
	"blade": {"file": "Rogue_Hooded", "scale": 0.6, "show": ["Knife", "Knife_Offhand"],
		"move": "Running_A", "attack": "Dualwield_Melee_Attack_Slice", "pose": ["Dualwield_Melee_Attack_Slice", 0.35]},
	"archers": {"file": "Rogue", "scale": 0.58, "show": ["1H_Crossbow"],
		"move": "Walking_A", "attack": "1H_Ranged_Shoot", "pose": ["1H_Ranged_Aiming", 0.3]},
	"pyro": {"file": "Mage", "scale": 0.6, "show": ["2H_Staff"],
		"move": "Walking_A", "attack": "Spellcast_Shoot", "pose": ["Spellcast_Shoot", 0.3]},
	"shield": {"file": "Knight", "scale": 0.62, "show": ["1H_Sword", "Badge_Shield"],
		"move": "Walking_A", "attack": "1H_Melee_Attack_Chop", "pose": ["Blocking", 0.2]},
	"golem": {"file": "Barbarian", "scale": 1.05, "show": ["2H_Axe"],
		"move": "Walking_A", "attack": "2H_Melee_Attack_Chop", "pose": ["2H_Melee_Idle", 0.3]},
	"shard": {"file": "Barbarian", "scale": 0.5, "show": ["1H_Axe", "Barbarian_Round_Shield"], "hide": ["Barbarian_Hat"],
		"move": "Running_A", "attack": "1H_Melee_Attack_Chop", "pose": ["Idle", 0.2]},
	"swarm": {"file": "Skeleton_Minion", "scale": 0.4, "attach_r": "Skeleton_Blade", "spawn": "Spawn_Ground_Skeletons",
		"move": "Running_C", "attack": "1H_Melee_Attack_Stab", "pose": ["Idle_Combat", 0.3]},
	"storm": {"file": "Skeleton_Mage", "scale": 1.0, "attach_r": "Skeleton_Staff", "spawn": "Spawn_Ground_Skeletons",
		"move": "Walking_D_Skeletons", "attack": "Spellcast_Shoot", "pose": ["Spellcast_Raise", 0.5]},
	"sapper": {"file": "Skeleton_Rogue", "scale": 0.55, "back": "keg_decorated", "spawn": "Spawn_Ground_Skeletons",
		"move": "Running_B", "attack": "Throw", "pose": ["Running_B", 0.3]},
}

static var _scenes := {}
static var _tints := {}

static func has(id: String) -> bool:
	return UNITS.has(id)

static func scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]

static func prop(name: String) -> Node3D:
	var n: Node3D = scene(DIR + "props/" + name + ".glb").instantiate()
	_shadows(n)
	return n

static func _shadows(n: Node) -> void:
	for c in n.get_children():
		if c is GeometryInstance3D:
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_shadows(c)

## Construit l'unité : un conteneur (rotation/échelle gérées par le jeu) + le personnage animé.
static func build(id: String, team: int) -> Node3D:
	var cfg: Dictionary = UNITS[id]
	var holder := Node3D.new()
	var ch: Node3D = scene(DIR + "characters/" + cfg.file + ".glb").instantiate()
	ch.scale = Vector3.ONE * cfg.scale
	holder.add_child(ch)
	var skel: Skeleton3D = ch.find_child("Skeleton3D", true, false)
	var show: Array = cfg.get("show", [])
	var hide: Array = cfg.get("hide", [])
	for c in skel.get_children():
		if c is BoneAttachment3D:
			var n := String(c.name)
			var wearable := n.contains("Cape") or n.contains("Hat") or n.contains("Helmet") or n.contains("Cloak")
			c.visible = (wearable and not n in hide) or n in show
	if cfg.has("attach_r"):
		var ba := BoneAttachment3D.new()
		ba.bone_name = "handslot.r"
		skel.add_child(ba)
		ba.add_child(scene(DIR + "weapons/" + cfg.attach_r + ".gltf").instantiate())
	if cfg.has("back"):
		var ba := BoneAttachment3D.new()
		ba.bone_name = "chest"
		skel.add_child(ba)
		var keg := prop(cfg.back)
		keg.scale = Vector3.ONE * 0.9
		keg.position = Vector3(0, 0.2, -0.55)
		keg.rotation.x = 0.3
		ba.add_child(keg)
		var spark := Models.mi(Models.sphere(0.12, 8), Models.glow(Color("ffd23f"), 5.0), Vector3(0, 0.95, -0.6), ba)
		spark.name = "Spark"
	_tint(ch, team)
	_shadows(ch)
	var ap: AnimationPlayer = ch.find_child("AnimationPlayer", true, false)
	for a in ["Idle", cfg.move, "Walking_A", "Running_A", "Idle_Combat", "Cheer", "2H_Melee_Idle", "Spellcasting", "Blocking"]:
		if ap.has_animation(a):
			ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	ap.play("Idle")
	ap.seek(randf() * 1.0, true)
	holder.set_meta("ap", ap)
	holder.set_meta("cfg", cfg)
	holder.set_meta("real", true)
	return holder

## Couleur d'équipe : capes/chapeaux teintés, léger reflet sur le reste.
static func _tint(n: Node, team: int) -> void:
	for c in n.get_children():
		if c is MeshInstance3D and c.mesh:
			var team_part := false
			var p := c.get_parent()
			for s in [String(c.name), String(p.name)]:
				if s.contains("Cape") or s.contains("Hat") or s.contains("Cloak") or s.contains("Badge") or s.contains("Helmet"):
					team_part = true
			for si in c.mesh.get_surface_count():
				var base: Material = c.mesh.surface_get_material(si)
				if not base is BaseMaterial3D:
					continue
				var key := "%d|%d|%d" % [base.get_instance_id(), team, int(team_part)]
				if not _tints.has(key):
					var m: BaseMaterial3D = base.duplicate()
					var col: Color = Data.TEAM_COLORS[team]
					if team_part:
						m.albedo_color = Color(1, 1, 1).lerp(col, 0.75) * 1.2
					else:
						m.albedo_color = Color(0.92, 0.96, 1.0) if team == 0 else Color(1.0, 0.86, 0.84)
					_tints[key] = m
				c.set_surface_override_material(si, _tints[key])
		_tint(c, team)

## Garde de tour : arbalétrier (tours latérales) ou chevalier (Tour Cœur).
static func guard(team: int, core: bool) -> Node3D:
	var holder := Node3D.new()
	var file := "Knight" if core else "Rogue"
	var ch: Node3D = scene(DIR + "characters/" + file + ".glb").instantiate()
	ch.scale = Vector3.ONE * (0.5 if core else 0.42)
	holder.add_child(ch)
	var skel: Skeleton3D = ch.find_child("Skeleton3D", true, false)
	var show := ["2H_Sword", "Knight_Helmet", "Knight_Cape"] if core else ["2H_Crossbow", "Rogue_Cape"]
	for c in skel.get_children():
		if c is BoneAttachment3D:
			c.visible = String(c.name) in show
	_tint(ch, team)
	var ap: AnimationPlayer = ch.find_child("AnimationPlayer", true, false)
	var idle := "2H_Melee_Idle" if core else "2H_Ranged_Aiming"
	ap.get_animation(idle).loop_mode = Animation.LOOP_LINEAR
	ap.play(idle)
	holder.set_meta("ap", ap)
	holder.set_meta("cfg", {"idle": idle, "attack": "2H_Melee_Attack_Chop" if core else "2H_Ranged_Shoot"})
	holder.set_meta("real", true)
	return holder

## Pose figée pour l'illustration des cartes.
static func pose(model: Node3D) -> void:
	var ap: AnimationPlayer = model.get_meta("ap")
	var p: Array = model.get_meta("cfg").pose
	ap.play(p[0])
	ap.seek(ap.current_animation_length * p[1], true)
	ap.pause()

## Machine d'états d'animation, appelée à chaque image.
static func update(model: Node3D, moving: bool, frozen: bool, attack_started: bool, hit_speed: float, deploying: bool, speed: float) -> void:
	var ap: AnimationPlayer = model.get_meta("ap")
	var cfg: Dictionary = model.get_meta("cfg")
	if frozen:
		ap.speed_scale = 0.0
		return
	if deploying:
		var sp: String = cfg.get("spawn", "")
		if sp != "" and ap.current_animation != sp:
			ap.play(sp, 0.0, 1.6)
		return
	if attack_started:
		var len := ap.get_animation(cfg.attack).length
		ap.speed_scale = maxf(1.2, len / maxf(0.3, hit_speed * 0.9))
		ap.play(cfg.attack, 0.08)
		ap.seek(0.0, true)
		return
	if ap.current_animation == cfg.attack and ap.is_playing():
		return
	if moving:
		ap.speed_scale = clampf(speed / 1.2, 0.8, 1.8)
		if ap.current_animation != cfg.move:
			ap.play(cfg.move, 0.15)
	else:
		ap.speed_scale = 1.0
		var idle: String = "Idle_Combat" if ap.has_animation("Idle_Combat") else "Idle"
		if ap.current_animation != idle:
			ap.play(idle, 0.2)

static func death(model: Node3D) -> float:
	var ap: AnimationPlayer = model.get_meta("ap")
	ap.speed_scale = 1.3
	ap.play("Death_A", 0.05)
	return ap.get_animation("Death_A").length / 1.3
