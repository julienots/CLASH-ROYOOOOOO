class_name Battle
extends Node3D
## Combat : simulation, IA, caméra, HUD et toutes les animations de match.

signal finished(result: Dictionary)

const RIVER := 1.3
const BRIDGE_X := 5.5
const BATTLE_TIME := 180.0
const OVERTIME := 60.0
const ESSENCE_RATE := 1.0 / 2.8
const SIGHT := 5.5
const STEP := 1.0 / 60.0

var deck: Array
var enemy_deck: Array
var island: Dictionary
var enemy_name = ""
var levels = [{}, {}]

var cam: Camera3D
var cam_base = Vector3.ZERO
var cam_look = Vector3.ZERO
var fx: FX
var entities: Array = []
var projectiles: Array = []
var pending: Array = []
var time_left = BATTLE_TIME
var overtime = false
var double_shown = false
var started = false
var over = false
var crowns = [0, 0]
var shown_crowns = [0, 0]
var essence = [5.0, 5.0]
var players = []
var selected = -1
var ai_think = 2.0
var shake = 0.0
var hitstop = 0.0
var acc = 0.0
var now = 0.0
var next_id = 1
var last_ess = 5
var last_sec = -1

# HUD
var hud: CanvasLayer
var overlay: Control
var top_bar: Control
var hand_panel: Control
var slots: Array = []
var next_tex: TextureRect
var ess_bar: Control
var ess_label: Label
var ess_drop: Control
var timer_label: Label
var timer_caption: Label
var timer_box: PanelContainer
var crown_labels: Array = []
var banner: Label
var ghost: TextureRect
var forbid: MeshInstance3D
var forbid2: MeshInstance3D
var cursor: Node3D
var cursor_disc: MeshInstance3D
var cursor_model: Node3D
var drag = {}
var mode: Dictionary = {}
var arena_node: Node3D
var emote_bubbles = [null, null]
var ai_emote_cd = 0.0
var tower_hit_cd = 0.0
var zones = []
var stats = {"deployed": 0, "spells": 0, "towers": 0}

func setup(p: Dictionary) -> void:
	deck = p.deck
	enemy_deck = p.enemy_deck
	island = p.island
	enemy_name = p.enemy_name
	levels = p.levels
	mode = p.get("mode", Data.MODES[0])
	time_left = mode.time
	essence = [mode.start, mode.start]

func _ready() -> void:
	_build_world()
	players = [_make_hand(deck), _make_hand(enemy_deck)]
	for team in [0, 1]:
		var s = 1.0 if team == 0 else -1.0
		_add_tower(team, -BRIDGE_X, 10.5 * s, false)
		_add_tower(team, BRIDGE_X, 10.5 * s, false)
		_add_tower(team, 0.0, 13.6 * s, true)
	_build_hud()
	_build_placement()
	get_viewport().size_changed.connect(_fit_camera)
	await get_tree().process_frame
	_fit_camera()
	_intro()

# ================= Monde =================
func _build_world() -> void:
	var env = WorldEnvironment.new()
	env.environment = Models.sky_environment(island)
	add_child(env)
	var sun = DirectionalLight3D.new()
	sun.light_color = Color("fff1d6")
	sun.light_energy = 1.1
	sun.rotation = Vector3(deg_to_rad(-58), deg_to_rad(-35), 0)
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)
	var fill = DirectionalLight3D.new()
	fill.light_color = Color("9fd0ff")
	fill.light_energy = 0.35
	fill.rotation = Vector3(deg_to_rad(-30), deg_to_rad(150), 0)
	add_child(fill)
	arena_node = Models.arena(island)
	add_child(arena_node)
	fx = FX.new()
	add_child(fx)
	cam = Camera3D.new()
	cam.fov = 40
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	add_child(cam)
	cam.current = true

func _fit_camera() -> void:
	var vp = get_viewport().get_visible_rect().size
	var top_h = top_bar.size.y + 6.0
	var bot = vp.y - hand_panel.size.y + 30.0
	var pitch = deg_to_rad(60.0)
	var look = Vector3(0, 0, 0.6)
	var corners = [Vector3(-9.6, 0, -16.6), Vector3(9.6, 0, -16.6), Vector3(-9.6, 0, 16.6), Vector3(9.6, 0, 16.6)]
	var d = 8.0
	for it in 200:
		cam.position = look + Vector3(0, sin(pitch), cos(pitch)) * d
		cam.look_at(look)
		var ok = true
		var ymin = INF
		var ymax = -INF
		for c in corners:
			var p = cam.unproject_position(c)
			ymin = min(ymin, p.y)
			ymax = max(ymax, p.y)
			if p.x < 0 or p.x > vp.x:
				ok = false
		if ok and ymax - ymin <= bot - top_h:
			break
		d += 0.25
	# recentrer l'arène entre la barre du haut et la main
	for it in 30:
		var py_top = cam.unproject_position(Vector3(0, 0, -16.6)).y
		var py_bot = cam.unproject_position(Vector3(0, 0, 16.6)).y
		var err = ((top_h + bot) / 2.0) - (py_top + py_bot) / 2.0
		if abs(err) < 1.0:
			break
		look.z -= err * 0.01
		cam.position = look + Vector3(0, sin(pitch), cos(pitch)) * d
		cam.look_at(look)
	cam_base = cam.position
	cam_look = look
	var eb = hud.get_node_or_null("EmoteButton")
	if eb:
		eb.position = Vector2(14, vp.y - hand_panel.size.y - 92)

func _intro() -> void:
	# la caméra plonge du ciel vers l'arène
	var target = cam_base
	cam.position = cam_base + Vector3(0, 18, 10)
	cam.look_at(cam_look)
	var tw = create_tween()
	tw.tween_method(func(k: float):
		cam.position = (cam_base + Vector3(0, 18, 10)).lerp(target, k)
		cam.look_at(cam_look), 0.0, 1.0, 1.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	hand_panel.position.y += 400
	top_bar.position.y -= 200
	var tw2 = create_tween().set_parallel()
	tw2.tween_property(hand_panel, "position:y", hand_panel.position.y - 400, 0.6).set_delay(0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw2.tween_property(top_bar, "position:y", top_bar.position.y + 200, 0.5).set_delay(0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.music("")
	await get_tree().create_timer(1.3).timeout
	for t in ["3", "2", "1"]:
		_show_banner(t, 150, Color.WHITE, 0.6)
		Sfx.play("tick")
		await get_tree().create_timer(0.65).timeout
	_show_banner("COMBAT !", 110, UI.GOLD, 1.2)
	Sfx.play("go")
	Sfx.music("battle")
	Sfx.set_ambience(true)
	_shake(0.3)
	started = true

func _make_hand(d: Array) -> Dictionary:
	var q = d.duplicate()
	q.shuffle()
	return {"hand": q.slice(0, 4), "queue": q.slice(4)}

func _cycle(team: int, slot: int) -> void:
	var p: Dictionary = players[team]
	var used = p.hand[slot]
	p.hand[slot] = p.queue.pop_front()
	p.queue.append(used)

# ================= Entités =================
func _mult(team: int, card_id: String) -> float:
	var base = "golem" if card_id == "shard" else card_id
	return Data.level_mult(int(levels[team].get(base, 1)))

func _add_tower(team: int, px: float, pz: float, is_core: bool) -> Entity:
	var d: Dictionary = Data.TOWER.core if is_core else Data.TOWER.side
	var e = Entity.new()
	e.id = next_id
	next_id += 1
	e.team = team
	e.kind = "tower"
	e.core = is_core
	e.x = px
	e.z = pz
	e.hp = d.hp
	e.max_hp = d.hp
	e.radius = d.radius
	e.dmg = d.dmg
	e.hit_speed = d.hit_speed
	e.attack_range = d.range
	e.attack = "arrow"
	e.targets = "both"
	e.is_building = true
	e.lane = 0 if px < 0 else (1 if px > 0 else -1)
	e.active = not is_core
	e.position = Vector3(px, 0, pz)
	var m = Models.tower(team, is_core)
	if team == 1:
		m.rotation.y = PI
	e.setup_model(m)
	e.ring = MeshInstance3D.new()
	e.add_child(e.ring)
	add_child(e)
	entities.append(e)
	return e

func _spawn(card_id: String, team: int, px: float, pz: float, delay := 1.0) -> Entity:
	var c: Dictionary = Data.CARDS[card_id]
	var mult = _mult(team, card_id)
	var e = Entity.new()
	e.id = next_id
	next_id += 1
	e.team = team
	e.card_id = card_id
	e.kind = "building" if c.type == "building" else "unit"
	e.x = px
	e.z = pz
	e.flying = c.get("flying", false)
	e.y = 2.6 if e.flying else 0.0
	e.hp = c.hp * mult
	e.max_hp = e.hp
	e.shield = c.get("shield", 0) * mult
	e.max_shield = e.shield
	e.radius = c.radius
	e.speed = c.get("speed", 0.0)
	e.dmg = c.dmg * mult
	e.hit_speed = c.hit_speed
	e.attack_range = c.range
	e.targets = c.targets
	e.attack = c.attack
	e.splash = c.get("splash", 0.0)
	e.deploy = delay
	e.deploy_total = max(delay, 0.01)
	e.first_strike = c.get("first_strike", 0.0)
	e.is_building = c.type == "building"
	e.lifetime = c.get("lifetime", 0.0)
	e.heavy = c.get("heavy", false)
	e.seed = randf() * 10.0
	e.facing = PI if team == 0 else 0.0
	e.base_scale = 1.2 if RealModels.has(card_id) else (1.15 if e.heavy else 1.3)
	var m = Models.build(card_id, team)
	m.rotation.y = e.facing
	e.setup_model(m)
	e.position = Vector3(px, e.y + 6.0, pz)
	# anneau d'équipe + ombre portée douce
	var ring = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = c.radius * 0.85
	tm.outer_radius = c.radius * 1.05
	tm.rings = 28
	tm.ring_segments = 3
	ring.mesh = tm
	ring.scale = Vector3(1, 0.05, 1)
	var rm = StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(Data.TEAM_COLORS[team], 0.6)
	ring.material_override = rm
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = Vector3(px, 0.04, pz)
	add_child(ring)
	e.ring = ring
	if e.flying:
		var blob = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = c.radius
		cm.bottom_radius = c.radius
		cm.height = 0.01
		blob.mesh = cm
		blob.material_override = Models.mat(Color(0, 0, 0), 0.0, 1.0, 0.0, 0.3)
		blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(blob)
		e.shadow_blob = blob
	add_child(e)
	entities.append(e)
	e.min_range = c.get("min_range", 0.0)
	e.invisible = c.get("invisible", false)
	if e.invisible:
		_set_ghost(e, true)
	e.summon_t = c.get("summon_every", 0.0) * 0.6
	if RealModels.has(card_id) and RealModels.UNITS[card_id].has("spawn") and delay > 0.3:
		Sfx.play("rattle")
	if delay > 0.3:
		var land = delay * 0.45
		get_tree().create_timer(land).timeout.connect(func():
			if is_instance_valid(e) and e.alive:
				fx.dust(Vector3(e.x, 0, e.z), 8 if not e.heavy else 18, 0.8 if not e.heavy else 1.6)
				if e.heavy:
					_shake(0.35)
					fx.ring(Vector3(e.x, 0, e.z), 3.0, Color(1, 0.9, 0.7), 0.4)
					Sfx.play("boom", 0.7)
				else:
					Sfx.play("pop", 1.4 if e.card_id == "swarm" else 1.0))
	return e

func deploy(team: int, card_id: String, px: float, pz: float) -> void:
	var c: Dictionary = Data.CARDS[card_id]
	essence[team] -= c.cost
	fx.float_text(Vector3(px, 2.6, pz), c.name, Color("ff9a9a") if team == 1 else Color.WHITE, 46, 1.0, 1.4)
	if team == 0:
		if c.type == "spell":
			stats.spells += 1
		else:
			stats.deployed += c.get("count", 1)
	if c.type == "spell":
		_cast_spell(team, card_id, px, pz)
		return
	Sfx.play("deploy")
	var n: int = c.get("count", 1)
	for i in n:
		var a = float(i) / n * TAU
		var r = 0.0 if n == 1 else (0.8 if n > 3 else 0.55)
		_spawn(card_id, team, px + cos(a) * r, pz + sin(a) * r, 1.0 + i * 0.06)
	fx.ring(Vector3(px, 0, pz), 1.8, Data.TEAM_GLOW[team], 0.6)

func _cast_spell(team: int, card_id: String, px: float, pz: float) -> void:
	var c: Dictionary = Data.CARDS[card_id]
	var dmg: float = c.dmg * _mult(team, card_id)
	if card_id == "meteor":
		var rock = Models.build("meteor", team)
		add_child(rock)
		var from = Vector3(px - 7, 24, pz - 5)
		rock.position = from
		var warn = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = c.radius
		cm.bottom_radius = c.radius
		cm.height = 0.02
		warn.mesh = cm
		var wm = StandardMaterial3D.new()
		wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wm.albedo_color = Color(1, 0.35, 0, 0.3)
		warn.material_override = wm
		warn.position = Vector3(px, 0.07, pz)
		add_child(warn)
		var pt = create_tween().set_loops(4)
		pt.tween_property(wm, "albedo_color:a", 0.55, 0.12)
		pt.tween_property(wm, "albedo_color:a", 0.2, 0.12)
		Sfx.play("meteor")
		pending.append({"t": c.delay, "total": c.delay, "node": rock, "warn": warn, "from": from, "to": Vector3(px, 0.6, pz),
			"done": _meteor_impact.bind(team, px, pz, c, dmg)})
	elif card_id == "arrows":
		Sfx.play("arrow", 0.8)
		var vol = Node3D.new()
		add_child(vol)
		for i in 26:
			var holder = Models.build("arrows", team)
			var a = holder.get_child(0)
			holder.remove_child(a)
			holder.queue_free()
			vol.add_child(a)
			var start = Vector3(px + randf_range(-c.radius, c.radius) - 3.0, 12.0 + randf() * 4.0, pz + randf_range(-c.radius, c.radius) * 0.8 - 2.0)
			var end = Vector3(start.x + 3.0, 0.3, start.z + 2.0)
			a.position = start
			a.rotation = Vector3(0.25, 0, -0.35)
			var tw = create_tween()
			tw.tween_interval(randf() * 0.25)
			tw.tween_property(a, "position", end, c.delay).set_ease(Tween.EASE_IN)
		pending.append({"t": c.delay + 0.2, "total": c.delay + 0.2, "node": vol, "warn": _warn_circle(px, pz, c.radius, Color(1, 0.9, 0.3, 0.3)), "from": Vector3.ZERO, "to": Vector3.ZERO, "static": true,
			"done": _arrows_impact.bind(team, px, pz, c, dmg)})
	elif card_id == "rage":
		Sfx.play("levelup", 0.8)
		fx.ring(Vector3(px, 0, pz), c.radius, Color("d24bff"), 0.6, 0.35)
		fx.burst(Vector3(px, 0.5, pz), Color("e07bff"), 40, 5.0, 0.7, 0.9, -1.0)
		var pot = Models.build("rage", team)
		pot.position = Vector3(px, 4.0, pz)
		add_child(pot)
		var tw = create_tween()
		tw.tween_property(pot, "position:y", 0.3, 0.3).set_ease(Tween.EASE_IN)
		tw.tween_property(pot, "scale", Vector3(2.5, 0.1, 2.5), 0.12)
		tw.tween_callback(pot.queue_free)
		for e in entities:
			if e.alive and e.team == team and e.kind == "unit" and Vector2(e.x - px, e.z - pz).length() <= c.radius:
				e.rage_t = c.rage
				fx.float_text(e.position_vec(2.2), "RAGE !", Color("e07bff"), 40)
	elif card_id == "comets":
		for i in c.count:
			var a = randf() * TAU
			var rr = sqrt(randf()) * c.radius
			var cx = px + cos(a) * rr
			var cz = pz + sin(a) * rr * 0.85
			var rock = Models.build("meteor", team)
			rock.scale = Vector3.ONE * 0.55
			add_child(rock)
			var from = Vector3(cx - 5, 18, cz - 3)
			rock.position = from
			var delay = 0.5 + i * 0.22
			pending.append({"t": delay, "total": delay, "node": rock, "warn": _warn_circle(cx, cz, 1.6, Color(1, 0.4, 0.1, 0.3)), "from": from, "to": Vector3(cx, 0.4, cz),
				"done": _comet_impact.bind(team, cx, cz, dmg, c.tower_mult)})
		Sfx.play("meteor", 1.2)
	elif card_id == "clone":
		Sfx.play("unlock", 1.3)
		fx.ring(Vector3(px, 0, pz), c.radius, Color("6fe7ff"), 0.5, 0.3)
		var src = entities.filter(func(o): return o.alive and o.team == team and o.kind == "unit" and not o.is_clone and Vector2(o.x - px, o.z - pz).length() <= c.radius + o.radius)
		for o in src:
			var cl = _spawn(o.card_id, team, o.x + 0.7, o.z + (0.5 if team == 0 else -0.5), 0.2)
			cl.hp = 1.0
			cl.max_hp = 1.0
			cl.shield = 0.0
			cl.max_shield = 0.0
			cl.is_clone = true
			for m in cl.meshes:
				if is_instance_valid(m):
					m.transparency = 0.35
			cl.set_overlay(Entity.ice_mat)
			fx.burst(cl.position_vec(1.0), Color("6fe7ff"), 10, 2.5, 0.5, 0.5)
	elif card_id == "aegis":
		Sfx.play("levelup", 0.9)
		fx.ring(Vector3(px, 0, pz), c.radius, Color("ffd24a"), 0.5, 0.3)
		for o in entities:
			if o.alive and o.team == team and o.kind == "unit" and Vector2(o.x - px, o.z - pz).length() <= c.radius + o.radius:
				var amount = c.shield * _mult(team, card_id)
				o.shield += amount
				o.max_shield = maxf(o.max_shield, o.shield)
				fx.burst(o.position_vec(1.0), Color("ffe27a"), 10, 2.0, 0.45, 0.6, -1.0)
				fx.float_text(o.position_vec(2.3), "+%d bouclier" % int(amount), Color("ffe27a"), 34)
	elif card_id == "lightning":
		var cands = entities.filter(func(o): return o.alive and o.team != team and Vector2(o.x - px, o.z - pz).length() <= c.radius + o.radius)
		cands.sort_custom(func(a, b): return a.hp > b.hp)
		var k = 0
		for o in cands.slice(0, c.strikes):
			var target: Entity = o
			get_tree().create_timer(k * 0.22).timeout.connect(func():
				if not is_instance_valid(target) or not target.alive:
					return
				var top = target.position_vec(14.0)
				fx.bolt([top, top.lerp(target.position_vec(1.0), 0.5) + Vector3(randf_range(-1, 1), 0, 0), target.position_vec(1.0)], Color("fff27a"))
				fx.flash(target.position_vec(1.0), Color("fff7b0"), 4.0, 0.25)
				_damage(target, dmg * (c.tower_mult if target.kind == "tower" else 1.0), true)
				if target.alive:
					target.freeze(0.5)
				_shake(0.35)
				Sfx.play("zap", 0.8))
			k += 1
		_warn_flash(px, pz, c.radius, Color(1, 0.95, 0.4, 0.25))
	elif card_id == "tornado":
		zones.append({"kind": "tornado", "team": team, "x": px, "z": pz, "r": c.radius, "t": c.pull, "dmg": dmg / c.pull, "node": _tornado_node(px, pz, c.radius)})
		Sfx.play("whoosh", 0.6)
	elif card_id == "heal":
		Sfx.play("levelup", 1.2)
		fx.ring(Vector3(px, 0, pz), c.radius, Color("ffe27a"), 0.6, 0.35)
		fx.burst(Vector3(px, 0.3, pz), Color("fff3b0"), 40, 3.0, 0.6, 1.0, -3.0)
		for o in entities:
			if o.alive and o.team == team and o.kind == "unit" and Vector2(o.x - px, o.z - pz).length() <= c.radius + o.radius:
				var amount = minf(c.heal * _mult(team, card_id), o.max_hp - o.hp)
				o.hp += amount
				if amount > 0:
					fx.float_text(o.position_vec(2.0), "+%d" % int(amount), Color("7cf27a"), 40)
	elif card_id == "poison":
		zones.append({"kind": "poison", "team": team, "x": px, "z": pz, "r": c.radius, "t": c.duration, "tick": 0.0,
			"dmg": dmg / (c.duration * 2.0), "tower_mult": c.tower_mult, "node": _warn_circle(px, pz, c.radius, Color(0.4, 0.9, 0.2, 0.32))})
		Sfx.play("beam", 0.5)
	elif card_id == "frost":
		Sfx.play("freeze")
		_area_damage(team, px, pz, c.radius, dmg, c.tower_mult, true, c.freeze)
		fx.burst(Vector3(px, 0.5, pz), Color("bff4ff"), 40, 7.0, 0.7, 0.9, -2.0)
		fx.flash(Vector3(px, 1, pz), Color("8fe6ff"), c.radius * 3.0, 0.35)
		fx.ring(Vector3(px, 0, pz), c.radius, Color("8fe6ff"), 0.6, 0.3)
		var crystal = Models.build("frost", team)
		crystal.position = Vector3(px, 0, pz)
		crystal.scale = Vector3(0.1, 0.1, 0.1)
		add_child(crystal)
		var tw = create_tween()
		tw.tween_property(crystal, "scale", Vector3.ONE * 1.8, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.4)
		tw.tween_property(crystal, "scale", Vector3(0.01, 0.01, 0.01), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(crystal.queue_free)
		_shake(0.25)

func _meteor_impact(team: int, px: float, pz: float, c: Dictionary, dmg: float) -> void:
	_area_damage(team, px, pz, c.radius, dmg, c.tower_mult, true)
	fx.explosion(Vector3(px, 0, pz), c.radius, Color("ff6a00"))
	fx.debris(Vector3(px, 0.3, pz), Color("3a2a22"), 16, 9.0)
	_crater(px, pz, c.radius)
	_shake(0.8)
	hitstop = 0.06
	Sfx.play("big_boom")

func _comet_impact(team: int, x: float, z: float, dmg: float, tower_mult: float) -> void:
	_area_damage(team, x, z, 1.6, dmg, tower_mult, true)
	fx.explosion(Vector3(x, 0, z), 1.4, Color("ff6a00"))
	fx.debris(Vector3(x, 0.3, z), Color("3a2a22"), 8, 7.0)
	_crater(x, z, 1.4)
	_shake(0.35)
	Sfx.play("boom")

func _warn_flash(px: float, pz: float, r: float, col: Color) -> void:
	var w = _warn_circle(px, pz, r, col)
	var tw = create_tween()
	tw.tween_property(w.material_override, "albedo_color:a", 0.0, 0.8)
	tw.tween_callback(w.queue_free)

func _tornado_node(px: float, pz: float, r: float) -> Node3D:
	var n = Models.build("tornado", 0)
	n.position = Vector3(px, 0, pz)
	n.scale = Vector3(r * 0.6, 1.4, r * 0.6)
	add_child(n)
	return n

## Effets de zone persistants (tornade, poison).
func _update_zones(dt: float) -> void:
	for i in range(zones.size() - 1, -1, -1):
		var z: Dictionary = zones[i]
		z.t -= dt
		var node: Node3D = z.node
		if z.kind == "tornado":
			node.rotation.y += dt * 9.0
			if randf() < 0.6:
				var a = randf() * TAU
				fx.burst(Vector3(z.x + cos(a) * z.r * 0.8, 0.3, z.z + sin(a) * z.r * 0.8), Color(0.9, 0.9, 0.95, 0.7), 1, 1.0, 0.6, 0.5, 0.0, false)
			for o in entities:
				if o.alive and o.team != z.team and o.kind == "unit":
					var d = Vector2(z.x - o.x, z.z - o.z)
					var l = d.length()
					if l <= z.r + 0.5 and l > 0.15:
						o.x += d.x / l * minf(l, 3.2 * dt)
						o.z += d.y / l * minf(l, 3.2 * dt)
						_damage(o, z.dmg * dt)
		elif z.kind == "poison":
			z.tick -= dt
			if randf() < 0.5:
				fx.burst(Vector3(z.x + randf_range(-z.r, z.r) * 0.7, 0.2, z.z + randf_range(-z.r, z.r) * 0.7), Color("7be04a"), 1, 0.6, 0.45, 0.8, -1.5)
			if z.tick <= 0.0:
				z.tick = 0.5
				for o in entities:
					if o.alive and o.team != z.team and Vector2(o.x - z.x, o.z - z.z).length() <= z.r + o.radius * 0.5:
						_damage(o, z.dmg * (z.tower_mult if o.kind == "tower" else 1.0))
						o.poison_t = 0.6
		if z.t <= 0.0:
			var tw = create_tween()
			tw.tween_property(node, "scale", Vector3.ZERO, 0.25)
			tw.tween_callback(node.queue_free)
			zones.remove_at(i)

func _warn_circle(px: float, pz: float, r: float, col: Color) -> MeshInstance3D:
	var warn = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.02
	warn.mesh = cm
	var wm = StandardMaterial3D.new()
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.albedo_color = col
	warn.material_override = wm
	warn.position = Vector3(px, 0.07, pz)
	add_child(warn)
	return warn

func _arrows_impact(team: int, px: float, pz: float, c: Dictionary, dmg: float) -> void:
	_area_damage(team, px, pz, c.radius, dmg, c.tower_mult, true)
	fx.dust(Vector3(px, 0, pz), 24, 2.2)
	for i in 12:
		fx.burst(Vector3(px + randf_range(-c.radius, c.radius), 0.3, pz + randf_range(-c.radius, c.radius) * 0.8), Color("fff3c4"), 3, 2.0, 0.3, 0.3)
	Sfx.play("arrow_hit", 0.8)
	Sfx.play("stab", 0.7)
	_shake(0.2)

func _crater(px: float, pz: float, r: float) -> void:
	var o = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = r * 0.7
	cm.bottom_radius = r * 0.7
	cm.height = 0.01
	o.mesh = cm
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(0.15, 0.1, 0.08, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	o.material_override = m
	o.position = Vector3(px, 0.03, pz)
	add_child(o)
	var tw = create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(m, "albedo_color:a", 0.0, 1.5)
	tw.tween_callback(o.queue_free)

func _area_damage(team: int, px: float, pz: float, r: float, amount: float, tower_mult := 1.0, hits_air := true, freeze := 0.0) -> void:
	for e in entities.duplicate():
		if not e.alive or e.team == team:
			continue
		if e.flying and not hits_air:
			continue
		if Vector2(e.x - px, e.z - pz).length() > r + e.radius * 0.5:
			continue
		if freeze > 0.0:
			e.freeze(freeze)
		_damage(e, amount * tower_mult if e.kind == "tower" else amount, true)

func _damage(e: Entity, amount: float, big := false) -> void:
	if not e.alive:
		return
	if e.shield > 0.0:
		e.shield -= amount
		if e.shield <= 0.0:
			amount = -e.shield
			e.shield = 0.0
			var rig: Dictionary = e.model.get_meta("rig", {})
			if rig.has("shield_mesh"):
				var sm: Node3D = rig.shield_mesh
				var tw = create_tween()
				tw.tween_property(sm, "scale", Vector3.ONE * 1.5, 0.08)
				tw.tween_property(sm, "scale", Vector3.ZERO, 0.15)
				tw.tween_callback(func(): sm.visible = false)
			fx.burst(e.position_vec(1.0), Color("d4a52a"), 14, 4.0, 0.4, 0.5)
			fx.float_text(e.position_vec(2.4), "Bouclier brisé !", Color("ffd23f"), 40)
		else:
			amount = 0.0
	e.hp -= amount
	e.on_hit(big or amount > 200.0)
	if e.kind == "tower" and amount > 0.0 and tower_hit_cd <= 0.0:
		tower_hit_cd = 0.18
		Sfx.play("tower_hit")
	if amount >= 1.0 and (e.kind == "tower" or amount >= 100.0):
		var h = 4.2 if e.kind == "tower" else 2.0
		fx.float_text(Vector3(e.x + randf_range(-0.4, 0.4), h, e.z), str(int(amount)), Color("fff3c4") if e.team == 1 else Color("ffb3b3"), 52 if amount >= 300 else 40, 1.0, 0.7)
	if e.kind == "tower" and e.core and not e.active:
		_wake_core(e)
	if e.hp <= 0.0:
		_kill(e)

func _wake_core(e: Entity) -> void:
	e.active = true
	fx.float_text(Vector3(e.x, 5.5, e.z), "Réveillé !", Color("ffd23f"), 48)
	fx.ring(Vector3(e.x, 0, e.z), 4.0, Data.TEAM_GLOW[e.team], 0.5)
	if e.model.has_meta("guard"):
		var g: Node3D = e.model.get_meta("guard")
		var tw = create_tween()
		tw.tween_property(g, "position:y", g.position.y + 0.8, 0.15).set_ease(Tween.EASE_OUT)
		tw.tween_property(g, "position:y", g.position.y, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _kill(e: Entity) -> void:
	e.alive = false
	e.hp = 0.0
	if e.kind == "tower":
		_destroy_tower(e)
		return
	e.ring.visible = false
	Sfx.play("death")
	if e.shadow_blob:
		e.shadow_blob.queue_free()
	fx.soul(e.position_vec(), e.team)
	fx.burst(e.position_vec(0.6), Data.TEAM_GLOW[e.team], 10, 3.0, 0.45, 0.5)
	fx.burst(e.position_vec(0.5), Color(1, 1, 1, 0.8), 8, 2.0, 0.8, 0.6, 1.0, false, 1.0, true)
	var tw = create_tween()
	if e.model.has_meta("real") and e.attack != "kamikaze":
		# vraie animation de mort, puis l'unité s'enfonce dans le sol
		e.set_overlay(null)
		var t = RealModels.death(e.model)
		tw.tween_interval(t + 0.3)
		tw.tween_property(e, "position:y", -1.5, 0.5).set_ease(Tween.EASE_IN)
	else:
		tw.tween_property(e, "scale", e.scale * Vector3(1.3, 0.4, 1.3), 0.08)
		tw.tween_property(e, "scale", Vector3.ZERO, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): e.ring.queue_free(); e.queue_free())
	var c: Dictionary = Data.CARDS[e.card_id]
	if c.has("death_bomb"):
		var dx = e.x
		var dz = e.z
		var dteam = e.team
		var did = e.card_id
		get_tree().create_timer(0.6).timeout.connect(func():
			if not is_instance_valid(self):
				return
			_area_damage(dteam, dx, dz, c.death_radius, c.death_bomb * _mult(dteam, did), 1.0, false)
			fx.explosion(Vector3(dx, 0, dz), c.death_radius, Color("ff8a1f"))
			fx.debris(Vector3(dx, 0.5, dz), Color("e8e2d0"), 14, 8.0)
			_shake(0.7)
			Sfx.play("big_boom"))
		fx.float_text(e.position_vec(2.5), "BOUM !", Color("ffb02e"), 50)
	if c.has("death_freeze"):
		fx.burst(e.position_vec(1.0), Color("bff4ff"), 30, 5.0, 0.6, 0.8)
		fx.ring(e.position_vec(), 3.0, Color("8fe6ff"), 0.5, 0.3)
		Sfx.play("freeze")
		for o in entities:
			if o.alive and o.team != e.team and _dist(e, o) <= 3.0:
				o.freeze(c.death_freeze)
	if c.has("death_rage"):
		fx.ring(e.position_vec(), 3.0, Color("d24bff"), 0.6, 0.35)
		fx.burst(e.position_vec(0.5), Color("e07bff"), 30, 4.0, 0.6, 0.8, -1.0)
		Sfx.play("levelup", 0.8)
		for o in entities:
			if o.alive and o.team == e.team and o.kind == "unit" and _dist(e, o) <= 3.0:
				o.rage_t = c.death_rage
	if c.has("on_death"):
		for i in c.death_count:
			_spawn(c.on_death, e.team, e.x + (0.6 if i else -0.6), e.z, 0.35)
		fx.debris(e.position_vec(1.0), Color("4a4a52"), 12, 7.0)
		fx.dust(e.position_vec(), 18, 2.0)
		_shake(0.4)
		Sfx.play("boom", 0.8)

func _destroy_tower(e: Entity) -> void:
	var other = 1 - e.team
	if arena_node and arena_node.has_meta("crowd"):
		var cm: ShaderMaterial = arena_node.get_meta("crowd")
		cm.set_shader_parameter("excite", 1.0)
		create_tween().tween_method(func(v: float): cm.set_shader_parameter("excite", v), 1.0, 0.0, 3.5).set_delay(1.0)
	if other == 0:
		stats.towers += 1
	else:
		_ai_emote(["Ha ha !", "Trop facile !", "Pas mal !"][randi() % 3])
	hitstop = 0.12
	_shake(1.2)
	Sfx.play("tower_down")
	fx.explosion(Vector3(e.x, 1.5, e.z), 3.0, Color("ffc36b"))
	fx.debris(Vector3(e.x, 2.0, e.z), Color("b9b2a5"), 22, 11.0)
	fx.debris(Vector3(e.x, 2.0, e.z), Data.TEAM_COLORS[e.team], 8, 9.0)
	fx.dust(Vector3(e.x, 0, e.z), 30, 3.0)
	# la tour tremble, s'incline et s'effondre
	var m = e.model
	var tw = create_tween()
	for i in 4:
		tw.tween_property(m, "position:x", 0.15 * (1 if i % 2 else -1), 0.04)
	tw.tween_property(m, "position:x", 0.0, 0.04)
	tw.tween_property(m, "rotation:x", 0.35 * (1 if e.team == 0 else -1), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(m, "position:y", -4.5, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		m.visible = false
		var rb = Models.rubble()
		e.add_child(rb)
		rb.scale = Vector3(1.4, 0.1, 1.4)
		var t2 = create_tween()
		t2.tween_property(rb, "scale", Vector3.ONE * 1.4, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT))
	if e.core:
		crowns[other] = 3
		for t in entities:
			if t.kind == "tower" and t.team == e.team and t.alive and t != e:
				t.alive = false
				get_tree().create_timer(0.4).timeout.connect(_destroy_tower.bind(t))
		_finish(other)
	elif crowns[other] < 3:
		crowns[other] += 1
		for t in entities:
			if t.kind == "tower" and t.core and t.team == e.team and t.alive and not t.active:
				_wake_core(t)
		_show_banner("Tour détruite !" if other == 0 else "Tour perdue !", 70, UI.GOLD if other == 0 else Color("ff8a8a"), 1.6)
		if mode.get("sudden", false):
			_finish(other)
	_fly_crown(e, other)

func _fly_crown(e: Entity, to_team: int) -> void:
	var start = cam.unproject_position(Vector3(e.x, 4.0, e.z))
	var ic = UI.icon("crown", 90)
	ic.tint = Color("6fc4ff") if to_team == 0 else Color("ff8a8a")
	hud.add_child(ic)
	ic.position = start - Vector2(45, 45)
	ic.pivot_offset = Vector2(45, 45)
	ic.scale = Vector2(0.2, 0.2)
	var dest: Control = crown_labels[to_team]
	var end = dest.global_position + dest.size / 2 - Vector2(45, 45)
	var tw = create_tween()
	tw.tween_property(ic, "scale", Vector2(1.6, 1.6), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ic, "position:y", ic.position.y - 80, 0.35).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ic, "rotation", TAU, 0.35)
	tw.tween_interval(0.25)
	tw.tween_property(ic, "position", end, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(ic, "scale", Vector2(0.45, 0.45), 0.5)
	tw.tween_callback(func():
		ic.queue_free()
		shown_crowns[to_team] = min(3, crowns[to_team])
		Sfx.play("crown")
		_update_crowns()
		UI.squash(dest, 1.0))

# ================= Ciblage, déplacement =================
func _can_target(a: Entity, b: Entity) -> bool:
	if not b.alive or b.team == a.team or b.deploy > 0.5 or b.hidden():
		return false
	if a.targets == "buildings":
		return b.is_building
	if a.targets == "ground" and b.flying:
		return false
	return true

func _dist(a: Entity, b: Entity) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _find_target(e: Entity) -> Entity:
	var best: Entity = null
	var bd = INF
	var sight = SIGHT + (e.attack_range * 0.3 if e.attack_range > 2 else 0.0) if e.kind == "unit" else e.attack_range
	for o in entities:
		if not _can_target(e, o):
			continue
		var d = _dist(e, o) - o.radius
		if e.min_range > 0.0 and d < e.min_range:
			continue
		if e.targets != "buildings" and not o.is_building and d > sight:
			continue
		if e.kind != "unit" and d > e.attack_range + e.radius:
			continue
		var score = d + 50.0 if (o.is_building and e.targets != "buildings") else d
		if score < bd:
			bd = score
			best = o
	if best and best.is_building and e.kind == "unit":
		var bb: Entity = null
		var bdd = INF
		for o in entities:
			if not o.is_building or not _can_target(e, o):
				continue
			var d = _dist(e, o)
			if d < bdd:
				bdd = d
				bb = o
		best = bb
	return best

func _move_target(e: Entity, tx: float, tz: float) -> Vector2:
	if e.flying:
		return Vector2(tx, tz)
	var side = 1.0 if e.z > 0 else -1.0
	var tside = 1.0 if tz > 0 else -1.0
	if side != tside:
		var bx = -BRIDGE_X if abs(e.x + BRIDGE_X) < abs(e.x - BRIDGE_X) else BRIDGE_X
		if abs(e.z) > RIVER - 0.2 and abs(e.x - bx) > 0.7:
			return Vector2(bx, side * (RIVER + 0.6))
		return Vector2(bx, -side * (RIVER + 1.0))
	return Vector2(tx, tz)

func _update_entity(e: Entity, dt: float) -> void:
	if e.deploy > 0.0:
		e.deploy -= dt
		return
	if e.frozen > 0.0:
		e.frozen -= dt
		return
	if e.lifetime > 0.0:
		var cl: Dictionary = Data.CARDS[e.card_id]
		if cl.has("hatch"):
			e.lifetime -= dt
			if randf() < 0.3:
				fx.burst(e.position_vec(0.8), Color("ffb02e"), 1, 1.0, 0.4, 0.5, -2.0)
			if e.lifetime <= 0.0:
				var bx = e.x
				var bz = e.z
				var bt = e.team
				e.alive = false
				e.ring.queue_free()
				e.queue_free()
				fx.explosion(Vector3(bx, 0, bz), 1.5, Color("ff8a1f"))
				fx.float_text(Vector3(bx, 2.5, bz), "RENAISSANCE !", Color("ffb02e"), 46)
				Sfx.play("levelup", 1.1)
				_spawn(cl.hatch, bt, bx, bz, 0.3)
				return
		else:
			e.hp -= e.max_hp / e.lifetime * dt
			if e.hp <= 0.0:
				_kill(e)
				return
	if e.kind == "tower" and not e.active:
		return
	e.blink_t -= dt
	e.dash_t -= dt
	if not e.dash.is_empty():
		_update_dash(e, dt)
		return
	if e.chill_t > 0.0:
		e.chill_t -= dt
		if randf() < 0.15:
			fx.burst(e.position_vec(0.6), Color("bff4ff"), 1, 0.8, 0.35, 0.5, 1.0)
	if e.poison_t > 0.0:
		e.poison_t -= dt
	if e.invisible:
		var was = e.revealed_t > 0.0
		e.revealed_t -= dt
		if was and e.revealed_t <= 0.0:
			_set_ghost(e, true)
	if e.rage_t > 0.0:
		e.rage_t -= dt
		if randf() < 0.25:
			fx.burst(e.position_vec(0.3), Color("d24bff"), 1, 1.0, 0.5, 0.5, 2.0)
	if e.kind == "building":
		var cb: Dictionary = Data.CARDS[e.card_id]
		if cb.has("summon"):
			e.summon_t -= dt
			if e.summon_t <= 0.0:
				e.summon_t = cb.summon_every
				_summon(e, cb)
		if cb.attack == "none":
			return
	if e.kind == "unit":
		var c: Dictionary = Data.CARDS[e.card_id]
		if c.get("enrage", false) and not e.enraged and e.hp < e.max_hp * 0.5:
			e.enraged = true
			e.speed *= 1.3
			fx.float_text(e.position_vec(2.4), "FURIE !", Color("ff4a3a"), 48)
			fx.burst(e.position_vec(1.0), Color("ff3a2a"), 20, 4.0, 0.6, 0.5)
			Sfx.play("streak")
		if e.enraged and randf() < 0.2:
			fx.burst(e.position_vec(1.2), Color("ff5a3a"), 1, 1.0, 0.4, 0.4, 2.0)
		if c.has("heal"):
			e.heal_t -= dt
			if e.heal_t <= 0.0:
				e.heal_t = 2.0
				_heal_pulse(e, c)
		if c.has("summon"):
			e.summon_t -= dt
			if e.summon_t <= 0.0:
				e.summon_t = c.summon_every
				_summon(e, c)
	e.cooldown -= dt * e.atk_mult()
	e.retarget -= dt
	var t = e.target
	var lost = t == null or not is_instance_valid(t) or not t.alive
	if lost or e.retarget <= 0.0 or (e.kind != "unit" and _dist(e, t) - t.radius > e.attack_range + e.radius):
		if lost or e.windup <= 0.0:
			e.target = _find_target(e)
		e.retarget = 0.4
	t = e.target
	if e.windup > 0.0:
		e.windup -= dt
		if e.windup <= 0.0 and t and is_instance_valid(t) and t.alive:
			_strike(e, t)
		return
	if t == null:
		e.moving = false
		return
	var d = _dist(e, t) - t.radius - e.radius
	if d <= e.attack_range:
		e.moving = false
		e.facing = atan2(t.x - e.x, t.z - e.z)
		if e.cooldown <= 0.0:
			e.cooldown = e.hit_speed
			if e.kind == "building" and e.model.has_meta("building"):
				var bm: Node3D = e.model.get_meta("building")
				var rt = create_tween()
				rt.tween_property(bm, "scale", Vector3(1.4, 1.1, 1.4), 0.08)
				rt.tween_property(bm, "scale", Vector3.ONE * 1.25, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			e.windup = 0.05 if e.attack == "kamikaze" else (0.45 if e.heavy else (0.34 if e.model.has_meta("real") else 0.28))
			e.play_attack()
	elif e.kind == "unit" and _special_move(e, t, d, dt):
		pass
	elif e.kind == "unit":
		var m = _move_target(e, t.x, t.z)
		var dir = Vector2(m.x - e.x, m.y - e.z)
		var l = maxf(dir.length(), 0.001)
		e.x += dir.x / l * e.speed * e.spd_mult() * dt
		e.z += dir.y / l * e.speed * e.spd_mult() * dt
		e.facing = atan2(dir.x, dir.y)
		e.moving = true

## Téléportation (Sorcière des Ombres) et bond (Chevalier Céleste).
func _special_move(e: Entity, t: Entity, d: float, dt: float) -> bool:
	var c: Dictionary = Data.CARDS[e.card_id]
	if c.has("blink") and e.blink_t <= 0.0 and d > e.attack_range + 1.0:
		e.blink_t = c.blink
		var dir = Vector2(t.x - e.x, t.z - e.z).normalized()
		var step = minf(4.0, d - e.attack_range + 0.3)
		fx.burst(e.position_vec(1.0), Color("7a3fd0"), 16, 3.0, 0.6, 0.5)
		fx.ring(e.position_vec(), 1.4, Color("9b5cff"), 0.35)
		var m = _move_target(e, e.x + dir.x * step, e.z + dir.y * step)
		var md = Vector2(m.x - e.x, m.y - e.z)
		if md.length() > step:
			md = md.normalized() * step
		e.x += md.x
		e.z += md.y
		fx.burst(e.position_vec(1.0), Color("b98bff"), 16, 3.0, 0.6, 0.5)
		fx.float_text(e.position_vec(2.3), "Blink !", Color("c9a6ff"), 34)
		Sfx.play("zap", 1.8)
		return true
	if c.has("dash") and e.dash_t <= 0.0 and d >= 2.5 and d <= 6.0 and abs(e.z - t.z) < 6.0 and (sign(e.z) == sign(t.z) or abs(abs(e.x) - BRIDGE_X) < 1.2):
		e.dash_t = c.dash
		e.dash = {"from": Vector2(e.x, e.z), "target": t, "k": 0.0}
		RealModels.play_once(e.model, "Jump_Full_Short")
		Sfx.play("whoosh", 1.2)
		return true
	return false

func _update_dash(e: Entity, dt: float) -> void:
	var t: Entity = e.dash.target
	e.dash.k += dt / 0.45
	var k: float = minf(1.0, e.dash.k)
	var dest = Vector2(t.x, t.z) if is_instance_valid(t) and t.alive else e.dash.from
	var dir = (dest - e.dash.from)
	var stop = dest - dir.normalized() * (t.radius + e.radius if is_instance_valid(t) else 0.0)
	var p = e.dash.from.lerp(stop, k)
	e.x = p.x
	e.z = p.y
	e.y = sin(k * PI) * 1.8
	e.facing = atan2(dir.x, dir.y)
	e.moving = false
	if k >= 1.0:
		e.y = 0.0
		e.dash = {}
		fx.dust(e.position_vec(), 14, 1.4)
		fx.ring(e.position_vec(), 2.0, Color("9fe0ff"), 0.35)
		_shake(0.3)
		Sfx.play("hit", 0.9)
		if is_instance_valid(t) and t.alive:
			_damage(t, e.dmg * 2.0, true)
			fx.float_text(t.position_vec(2.6), "BOND !", Color("9fe0ff"), 44)
		e.cooldown = e.hit_speed * 0.5

func _heal_pulse(e: Entity, c: Dictionary) -> void:
	var healed = false
	for o in entities:
		if o.alive and o.team == e.team and o.kind == "unit" and o != e and o.hp < o.max_hp and _dist(e, o) <= c.heal_radius:
			var amount = minf(c.heal * _mult(e.team, e.card_id), o.max_hp - o.hp)
			o.hp += amount
			healed = true
			fx.float_text(o.position_vec(2.0), "+%d" % int(amount), Color("7cf27a"), 38)
			fx.burst(o.position_vec(0.8), Color("7cf27a"), 6, 2.0, 0.4, 0.5, -2.0)
	if healed:
		fx.ring(e.position_vec(), c.heal_radius, Color("7cf27a"), 0.5, 0.2)
		RealModels.play_once(e.model, "Spellcast_Raise")
		Sfx.play("beam", 1.6)

func _summon(e: Entity, c: Dictionary) -> void:
	if e.model.has_meta("real"):
		RealModels.play_once(e.model, "Spellcast_Summon")
	elif e.model.has_meta("building"):
		var bm: Node3D = e.model.get_meta("building")
		var rt = create_tween()
		rt.tween_property(bm, "scale", bm.scale * Vector3(1.1, 0.9, 1.1), 0.1)
		rt.tween_property(bm, "scale", bm.scale, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	fx.ring(e.position_vec(), 2.0, Color("9b5cff"), 0.5, 0.3)
	Sfx.play("rattle")
	for i in c.summon_count:
		var a = randf() * TAU
		var off = e.radius + 0.6
		var m = _spawn(c.summon, e.team, e.x + cos(a) * off, e.z + sin(a) * off + (off if e.team == 1 else -off) * 0.5, 0.6)
		fx.burst(m.position_vec(0.2), Color("9b5cff"), 10, 2.5, 0.5, 0.5)

func _set_ghost(e: Entity, hide: bool) -> void:
	for m in e.meshes:
		if is_instance_valid(m):
			m.transparency = 0.72 if hide else 0.0
	if not hide:
		fx.burst(e.position_vec(1.0), Color("b9a6ff"), 10, 2.5, 0.4, 0.4)

func _strike(e: Entity, t: Entity) -> void:
	if e.invisible:
		if e.revealed_t <= 0.0:
			_set_ghost(e, false)
		e.revealed_t = 1.3
	var dmg = e.dmg
	var team_glow: Color = Data.TEAM_GLOW[e.team]
	if e.first_strike > 0.0:
		dmg *= e.first_strike
		e.first_strike = 0.0
		fx.burst(t.position_vec(1.0), Color("63f5ff"), 18, 5.0, 0.5, 0.4)
		fx.float_text(t.position_vec(2.6), "CRITIQUE !", Color("63f5ff"), 44)
	match e.attack:
		"melee":
			if e.splash > 0.0:
				_area_damage(e.team, e.x, e.z, e.splash + e.radius, dmg, 1.0, false)
				fx.ring(e.position_vec(), e.splash + e.radius, Color(1, 0.95, 0.75), 0.3, 0.2)
				fx.burst(e.position_vec(0.8), Color("fff3c4"), 14, 5.0, 0.4, 0.3, 0.0)
				Sfx.play("hit", 1.3)
				Sfx.play("sword", 0.9)
				return
			_damage(t, dmg)
			fx.burst(t.position_vec(0.8), Color("fff3c4"), 8, 3.0, 0.35, 0.3)
			fx.flash(t.position_vec(0.9), Color(1, 1, 0.8), 1.2, 0.12)
			if e.card_id == "golem":
				fx.dust(t.position_vec(), 10, 1.4)
				fx.ring(t.position_vec(), 2.0, Color(1, 0.8, 0.5), 0.35)
				_shake(0.25)
				Sfx.play("hit", 0.6)
			elif e.card_id in ["shard", "berserker"]:
				Sfx.play("hit", 1.2)
			elif e.card_id in ["swarm", "minion"]:
				Sfx.play("stab")
			else:
				Sfx.play("sword")
		"arrow":
			var h = (e.model.get_meta("top", 3.4) - 0.6) if e.kind == "tower" and not e.core else (2.6 if e.core else 1.1)
			_projectile("arrow", e, t, Vector3(e.x, h, e.z), 18.0, dmg, 0.0)
			Sfx.play("arrow")
		"fireball":
			_projectile("fire", e, t, e.position_vec(1.9), 10.0, dmg, e.splash)
			Sfx.play("fire")
		"breath":
			var start = e.position_vec(0.5) + Vector3(sin(e.facing), 0, cos(e.facing)) * 1.2
			_projectile("breath", e, t, start, 12.0, dmg, e.splash)
			Sfx.play("fire", 1.3)
		"knife":
			for k in 3:
				_projectile("knife", e, t, e.position_vec(1.2) + Vector3(randf_range(-0.2, 0.2), k * 0.1, 0), 20.0 + k, dmg / 3.0, 0.0)
			Sfx.play("swipe", 1.5)
		"inferno":
			if e.ramp_target != t:
				e.ramp_target = t
				e.ramp_t = 0.0
			e.ramp_t += e.hit_speed
			var mult = 1.0 + minf(3.0, e.ramp_t * 0.75)
			_damage(t, dmg * mult)
			var col = Color("ff9a2e").lerp(Color("ff2a10"), clampf(e.ramp_t / 4.0, 0, 1))
			fx.beam(e.position_vec(0.2) + Vector3(sin(e.facing), 0, cos(e.facing)) * 1.4, t.position_vec(0.8 if t.kind != "tower" else 2.5), col)
			fx.burst(t.position_vec(0.8), col, 3, 2.0, 0.35 + mult * 0.08, 0.3, 0.0)
			if randf() < 0.3:
				Sfx.play("fire", 1.4)
		"cannonball":
			_projectile("cannonball", e, t, e.position_vec(1.1), 15.0, dmg, 0.0)
			fx.burst(e.position_vec(1.2) + Vector3(sin(e.facing), 0, cos(e.facing)) * 1.0, Color(0.8, 0.8, 0.8, 0.8), 8, 2.0, 0.6, 0.5, 0.0, false, 0.3, true)
			Sfx.play("boom", 1.6)
			if e.model.has_meta("building_ap"):
				var bap: AnimationPlayer = e.model.get_meta("building_ap")
				bap.stop()
				bap.play("Attack")
		"bomb":
			_projectile("bomb", e, t, e.position_vec(1.4), 9.0, dmg, e.splash)
			Sfx.play("swipe", 0.8)
		"ice":
			_projectile("ice", e, t, e.position_vec(1.6), 12.0, dmg, e.splash)
			Sfx.play("freeze", 1.8)
		"arcane":
			_projectile("arcane", e, t, e.position_vec(1.5), 13.0, dmg, 0.0)
			Sfx.play("beam", 1.3)
		"shadow":
			_projectile("shadow", e, t, e.position_vec(1.8), 11.0, dmg, 0.0)
			Sfx.play("zap", 1.6)
		"boulder":
			_projectile("boulder", e, t, e.position_vec(3.0), 9.0, dmg, e.splash)
			Sfx.play("hit", 0.6)
		"beam":
			_damage(t, dmg)
			fx.beam(e.position_vec(2.4), t.position_vec(0.8 if t.kind != "tower" else 2.5), team_glow)
			fx.burst(t.position_vec(0.8), team_glow, 6, 2.0, 0.4, 0.3)
			Sfx.play("beam")
		"chain":
			var hit = [t]
			var cur = t
			for i in 2:
				var nb: Entity = null
				var nd = 3.5
				for o in entities:
					if not o.alive or o.team == e.team or hit.has(o) or o.deploy > 0.5:
						continue
					var d = _dist(cur, o)
					if d < nd:
						nd = d
						nb = o
				if nb == null:
					break
				hit.append(nb)
				cur = nb
			var pts = [e.position_vec(3.0)]
			for h in hit:
				pts.append(h.position_vec(2.5 if h.kind == "tower" else 0.9))
			fx.bolt(pts)
			for h in hit:
				_damage(h, dmg, true)
			_shake(0.15)
			Sfx.play("zap")
		"kamikaze":
			fx.explosion(e.position_vec(), e.splash, Color("ffa21f"))
			fx.debris(e.position_vec(0.5), Color("8b5a2b"), 10, 7.0)
			_shake(0.5)
			hitstop = 0.05
			Sfx.play("boom")
			_area_damage(e.team, e.x, e.z, e.splash, e.dmg, 1.0, false)
			_kill(e)

func _projectile(type: String, from_e: Entity, t: Entity, pos: Vector3, spd: float, dmg: float, splash: float) -> void:
	var n = Node3D.new()
	if type == "arrow":
		var shaft = Models.mi(Models.cyl(0.03, 0.03, 0.8, 5), Models.mat(Color("5a3a1a")), Vector3.ZERO, n)
		shaft.rotation.x = PI / 2
		var tip = Models.mi(Models.cone(0.07, 0.18, 5), Models.mat(Color("dddddd"), 0.6), Vector3(0, 0, 0.45), n)
		tip.rotation.x = PI / 2
		Models.mi(Models.box(0.12, 0.02, 0.15), Models.mat(Data.TEAM_COLORS[from_e.team]), Vector3(0, 0, -0.35), n)
	elif type == "knife":
		var k = Models.mi(Models.box(0.05, 0.02, 0.4), Models.mat(Color("dfe6ee"), 0.8, 0.2), Vector3.ZERO, n)
		k.rotation.y = randf()
	elif type in ["arcane", "shadow"]:
		var col = Color("b56bff") if type == "arcane" else Color("5a1f8a")
		Models.mi(Models.sphere(0.2, 10), Models.glow(col.lightened(0.4), 4.0), Vector3.ZERO, n)
		Models.mi(Models.sphere(0.32, 10), Models.mat(col, 0.0, 0.5, 2.5, 0.45), Vector3.ZERO, n)
	elif type == "cannonball":
		Models.mi(Models.sphere(0.2, 10), Models.mat(Color("2a2a30"), 0.5, 0.4), Vector3.ZERO, n)
	elif type == "bomb":
		Models.mi(Models.sphere(0.22, 10), Models.mat(Color("2a2a30"), 0.4, 0.4), Vector3.ZERO, n)
		Models.mi(Models.sphere(0.06, 6), Models.glow(Color("ffb02e"), 5.0), Vector3(0, 0.25, 0), n)
	elif type == "ice":
		var shard = Models.mi(Models.gem(0.22), Models.mat(Color("bff4ff"), 0.2, 0.1, 1.5, 0.9), Vector3.ZERO, n)
		shard.scale = Vector3(0.6, 0.6, 1.6)
	elif type == "boulder":
		Models.mi(Models.rock(0.45), Models.mat(Color("7a7368"), 0.0, 0.9), Vector3.ZERO, n)
	else:
		var r = 0.32 if type == "fire" else 0.24
		Models.mi(Models.sphere(r, 10), Models.glow(Color("ffd24a"), 4.0), Vector3.ZERO, n)
		Models.mi(Models.sphere(r * 1.5, 10), Models.mat(Color("ff6a00"), 0.0, 0.5, 2.5, 0.5), Vector3.ZERO, n)
	n.position = pos
	add_child(n)
	projectiles.append({"type": type, "team": from_e.team, "target": t, "pos": pos, "start": pos, "speed": spd, "dmg": dmg, "splash": splash, "node": n, "dest": t.position_vec(2.0 if t.kind == "tower" else 0.8)})

func _update_projectiles(dt: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var p: Dictionary = projectiles[i]
		var t: Entity = p.target
		if is_instance_valid(t) and t.alive:
			p.dest = t.position_vec(2.0 if t.kind == "tower" else 0.8)
		var d: Vector3 = p.dest - p.pos
		var l = d.length()
		var step: float = p.speed * dt
		var node: Node3D = p.node
		if l <= step:
			node.queue_free()
			projectiles.remove_at(i)
			if p.splash > 0.0:
				_area_damage(p.team, p.dest.x, p.dest.z, p.splash, p.dmg, 1.0, true)
				fx.burst(p.dest, Color("ff8a1f"), 18, 4.0, 0.6, 0.5)
				fx.flash(p.dest, Color(1, 0.8, 0.4), p.splash * 2.0, 0.2)
				fx.ring(p.dest, p.splash, Color("ff8a1f"), 0.35)
				if p.type == "fire":
					Sfx.play("boom", 1.4)
				elif p.type == "bomb":
					Sfx.play("boom", 1.2)
					fx.explosion(p.dest, p.splash * 0.8, Color("ff9a2e"))
				elif p.type == "ice":
					for o in entities:
						if o.alive and o.team != p.team and o.kind == "unit" and Vector2(o.x - p.dest.x, o.z - p.dest.z).length() <= p.splash + o.radius:
							o.chill_t = 2.0
					fx.burst(p.dest, Color("bff4ff"), 14, 3.0, 0.5, 0.5)
					fx.ring(p.dest, p.splash, Color("8fe6ff"), 0.3)
				elif p.type == "boulder":
					Sfx.play("boom", 0.9)
					fx.debris(p.dest, Color("7a7368"), 10, 6.0)
					fx.dust(p.dest, 12, 1.4)
					_shake(0.2)
			elif is_instance_valid(t) and t.alive:
				_damage(t, p.dmg)
				fx.burst(p.dest, Color.WHITE if p.type in ["arrow", "knife"] else Color("c58bff"), 4, 2.0, 0.3, 0.25)
				if p.type == "arrow":
					Sfx.play("arrow_hit")
			continue
		p.pos += d / l * step
		var total: float = max(0.01, (p.dest - p.start).length())
		var k: float = clamp(1.0 - l / total, 0.0, 1.0)
		var arc = sin(k * PI) * (min(2.0, total * 0.15) if p.type == "arrow" else (total * 0.35 if p.type in ["boulder", "bomb"] else 0.0))
		var prev = node.position
		node.position = p.pos + Vector3(0, arc, 0)
		if node.position.distance_to(prev) > 0.001:
			node.look_at(node.position + (node.position - prev), Vector3.UP)
			node.rotate_object_local(Vector3.UP, PI)
		if p.type in ["fire", "breath"] and randf() < 0.9:
			fx.burst(node.position, Color("ff6a00"), 2, 0.5, 0.7, 0.3, 0.0)
		elif p.type in ["arcane", "shadow"] and randf() < 0.7:
			fx.burst(node.position, Color("b56bff") if p.type == "arcane" else Color("6a2fa0"), 1, 0.3, 0.5, 0.3, 0.0)
		elif p.type == "boulder":
			node.rotation.x += dt * 8.0

func _separate() -> void:
	var list = entities.filter(func(e): return e.alive)
	for i in list.size():
		var a: Entity = list[i]
		for j in range(i + 1, list.size()):
			var b: Entity = list[j]
			if a.flying != b.flying:
				continue
			var dx = b.x - a.x
			var dz = b.z - a.z
			var d = sqrt(dx * dx + dz * dz)
			var mn = (a.radius + b.radius) * 0.9
			if d >= mn:
				continue
			if d < 0.001:
				a.x += 0.01
				continue
			var fa = a.kind != "unit"
			var fb = b.kind != "unit"
			if fa and fb:
				continue
			var push = (mn - d) / d
			var wa = 0.0 if fa else (1.0 if fb else (0.85 if b.heavy and not a.heavy else (0.15 if a.heavy and not b.heavy else 0.5)))
			var wb = 1.0 - wa
			a.x -= dx * push * wa
			a.z -= dz * push * wa
			b.x += dx * push * wb
			b.z += dz * push * wb
	for e in list:
		if e.kind != "unit":
			continue
		e.x = clampf(e.x, -8.6, 8.6)
		e.z = clampf(e.z, -15.6, 15.6)
		if not e.flying and abs(e.z) < RIVER and abs(abs(e.x) - BRIDGE_X) >= 1.1:
			e.z = signf(e.z if e.z != 0 else 1.0) * RIVER

# ================= IA =================
func valid_zone(team: int, px: float, pz: float, card_id: String) -> bool:
	var c: Dictionary = Data.CARDS[card_id]
	if abs(px) > 8.7 or abs(pz) > 15.8:
		return false
	if c.type == "spell":
		return true
	var zz = pz * (1.0 if team == 0 else -1.0)
	if zz >= RIVER + 0.3:
		return true
	var lane = 0 if px < 0 else 1
	for t in entities:
		if t.kind == "tower" and not t.core and t.team != team and t.lane == lane and not t.alive:
			return zz >= -6.0
	return false

func _ai_update(dt: float) -> void:
	ai_think -= dt
	if ai_think > 0.0:
		return
	ai_think = randf_range(1.6, 2.8) if mode.get("easy", false) else randf_range(0.6, 1.4)
	var P: Dictionary = players[1]
	var ess: float = essence[1]
	var threats = entities.filter(func(e): return e.alive and e.team == 0 and e.kind == "unit" and e.z < 3.0)
	var affordable = []
	for i in 4:
		var id: String = P.hand[i]
		if Data.CARDS[id].cost <= ess:
			affordable.append({"id": id, "i": i, "c": Data.CARDS[id]})
	if affordable.is_empty():
		return
	var pick = func(f: Callable):
		var best = null
		for o in affordable:
			if f.call(o) and (best == null or o.c.cost > best.c.cost):
				best = o
		return best
	if not threats.is_empty():
		var center = Vector2.ZERO
		for t in threats:
			center += Vector2(t.x, t.z) / threats.size()
		var near = threats.filter(func(t): return Vector2(t.x - center.x, t.z - center.y).length() < 2.5)
		var value = 0.0
		for t in near:
			var tc: Dictionary = Data.CARDS[t.card_id]
			value += float(tc.cost) / tc.get("count", 1)
		var spell = pick.call(func(o): return o.c.type == "spell")
		if spell and value >= spell.c.cost - 0.5 and near.size() >= 2:
			_ai_play(spell, center.x, center.y + 0.5)
			return
		threats.sort_custom(func(a, b): return a.z < b.z)
		var lead: Entity = threats[0]
		var def = pick.call(func(o): return o.c.type != "spell" and o.c.get("targets", "") != "buildings")
		if def:
			_ai_play(def, clampf(lead.x * 0.7, -8, 8), clampf(lead.z - 3.0, -14.0, -RIVER - 0.8))
			return
	if ess >= 8.5 or (ess >= 6.0 and randf() < 0.25):
		var card = pick.call(func(o): return o.c.type != "spell")
		if card == null:
			return
		var lx = -BRIDGE_X if _ai_lane() == 0 else BRIDGE_X
		if card.c.get("targets", "") == "buildings" and card.c.cost >= 5:
			_ai_play(card, lx * 0.6, -13.5)
		elif card.c.type == "building":
			_ai_play(card, lx * 0.4, -6.0)
		else:
			_ai_play(card, lx, -RIVER - 0.8 if card.c.get("speed", 0) > 2 else -10.0)

func _ai_lane() -> int:
	var alive = entities.filter(func(t): return t.kind == "tower" and not t.core and t.team == 0 and t.alive)
	if alive.size() == 1:
		return alive[0].lane
	if alive.size() == 2:
		return alive[0].lane if alive[0].hp < alive[1].hp else alive[1].lane
	return randi() % 2

func _ai_play(o: Dictionary, px: float, pz: float) -> void:
	if not valid_zone(1, px, pz, o.id):
		pz = -RIVER - 1.0
	deploy(1, o.id, px, pz)
	_cycle(1, o.i)

# ================= Boucle =================
func _process(dt: float) -> void:
	now += dt
	if hitstop > 0.0:
		hitstop -= dt
	elif started and not over:
		acc += dt
		while acc >= STEP:
			_sim(STEP)
			acc -= STEP
	for e in entities:
		if is_instance_valid(e):
			e.visual_update(dt, now)
	# tremblement de caméra
	if started or over:
		var off = Vector3.ZERO
		if shake > 0.0:
			off = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.6
			shake = max(0.0, shake - dt * 2.5)
		cam.position = cam_base + off
	Models.animate_clouds(arena_node, dt)
	_update_hud(dt)
	overlay.queue_redraw()

func _sim(dt: float) -> void:
	time_left -= dt
	var rate = ESSENCE_RATE * mode.essence * (2.0 if overtime or time_left <= 60.0 else 1.0)
	tower_hit_cd -= dt
	ai_emote_cd -= dt
	for t in [0, 1]:
		essence[t] = minf(10.0, essence[t] + rate * dt)
	if time_left <= 60.0 and not double_shown and not overtime:
		double_shown = true
		_show_banner("Essence x2 !", 80, Color("f2a5ff"), 1.6)
		Sfx.play("unlock")
		Sfx.music("final")
	if time_left <= 0.0:
		if not overtime and crowns[0] == crowns[1]:
			overtime = true
			time_left = OVERTIME
			_show_banner("Prolongation !", 80, UI.GOLD, 1.6)
		else:
			var w = 0 if crowns[0] > crowns[1] else (1 if crowns[1] > crowns[0] else _tie_break())
			_finish(w)
			return
	_ai_update(dt)
	for e in entities.duplicate():
		if e.alive:
			_update_entity(e, dt)
	_update_projectiles(dt)
	_update_zones(dt)
	_separate()
	for i in range(pending.size() - 1, -1, -1):
		var p: Dictionary = pending[i]
		p.t -= dt
		var k: float = 1.0 - maxf(0.0, p.t) / p.total
		var node: Node3D = p.node
		if not p.get("static", false):
			node.position = p.from.lerp(p.to, k * k)
			node.rotation.x += dt * 5.0
			node.rotation.z += dt * 3.0
			fx.burst(node.position, Color("ff6a00"), 2, 1.0, 1.4, 0.4, 0.0)
		if p.t <= 0.0:
			node.queue_free()
			p.warn.queue_free()
			p.done.call()
			pending.remove_at(i)
	entities = entities.filter(func(e): return is_instance_valid(e) and (e.alive or e.kind == "tower"))

func _tie_break() -> int:
	var lo = [1.0, 1.0]
	for t in entities:
		if t.kind == "tower" and t.alive:
			lo[t.team] = min(lo[t.team], t.hp / t.max_hp)
	if abs(lo[0] - lo[1]) < 0.001:
		return -1
	return 0 if lo[0] > lo[1] else 1

func _finish(winner: int) -> void:
	if over:
		return
	over = true
	_hide_placement()
	Sfx.music("")
	Sfx.set_ambience(false)
	if winner == 1:
		_ai_emote("GG !")
	var tw = create_tween()
	tw.tween_property(hand_panel, "position:y", hand_panel.position.y + 500, 0.5).set_delay(0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if winner >= 0:
		Engine.time_scale = 0.35
		get_tree().create_timer(0.5, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)
	await get_tree().create_timer(2.4, true, false, true).timeout
	finished.emit({"winner": winner, "crowns": crowns.duplicate()})

func _shake(a: float) -> void:
	shake = max(shake, a)

# ================= HUD =================
func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	overlay = Control.new()
	UI.full_rect(overlay)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	hud.add_child(overlay)

	# barre du haut : adversaire, couronnes, chrono
	top_bar = MarginContainer.new()
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.add_theme_constant_override("margin_left", 14)
	top_bar.add_theme_constant_override("margin_right", 14)
	top_bar.add_theme_constant_override("margin_top", 14)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(top_bar)
	var row = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(row)
	var who = VBoxContainer.new()
	who.add_theme_constant_override("separation", -6)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_child(UI.label(enemy_name, 30, Color("ff8a8a")))
	who.add_child(UI.label(island.name, 20, Color("dbe7ff"), 6))
	row.add_child(who)
	var cbox = PanelContainer.new()
	cbox.add_theme_stylebox_override("panel", UI.panel(Color(0, 0, 0, 0.55), 18))
	var ch = HBoxContainer.new()
	ch.add_theme_constant_override("separation", 6)
	cbox.add_child(ch)
	for team in [0, 1]:
		var l = UI.label("0", 36, Color("6fc4ff") if team == 0 else Color("ff8a8a"))
		crown_labels.append(l)
	ch.add_child(crown_labels[0])
	var cic = UI.icon("crown", 40)
	ch.add_child(cic)
	ch.add_child(crown_labels[1])
	row.add_child(cbox)
	var sp = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	timer_box = PanelContainer.new()
	timer_box.add_theme_stylebox_override("panel", UI.panel(Color(0, 0, 0, 0.6), 16))
	var tv = VBoxContainer.new()
	tv.add_theme_constant_override("separation", -8)
	timer_caption = UI.label("Fin dans", 18, Color.WHITE, 5)
	timer_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_label = UI.label("3:00", 40)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tv.add_child(timer_caption)
	tv.add_child(timer_label)
	timer_box.add_child(tv)
	row.add_child(timer_box)

	# main de cartes + barre d'essence
	hand_panel = PanelContainer.new()
	var hs = StyleBoxFlat.new()
	hs.bg_color = Color("1e4aa8")
	hs.border_width_top = 6
	hs.border_color = UI.INK
	hs.content_margin_left = 12
	hs.content_margin_right = 12
	hs.content_margin_top = 14
	hs.content_margin_bottom = 22
	hs.shadow_color = Color(0, 0, 0, 0.4)
	hs.shadow_size = 12
	hand_panel.add_theme_stylebox_override("panel", hs)
	hand_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hand_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud.add_child(hand_panel)
	var hv = VBoxContainer.new()
	hv.add_theme_constant_override("separation", 16)
	hand_panel.add_child(hv)
	var cards_row = HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 10)
	hv.add_child(cards_row)
	var nv = VBoxContainer.new()
	nv.add_theme_constant_override("separation", 0)
	nv.custom_minimum_size.x = 96
	var nl = UI.label("Suivante", 18, Color.WHITE, 5)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nv.add_child(nl)
	next_tex = TextureRect.new()
	next_tex.custom_minimum_size = Vector2(90, 115)
	next_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	next_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	next_tex.modulate = Color(0.85, 0.85, 0.85)
	nv.add_child(next_tex)
	nv.size_flags_vertical = Control.SIZE_SHRINK_END
	cards_row.add_child(nv)
	for i in 4:
		var slot = _make_slot(i)
		cards_row.add_child(slot)
		slots.append(slot)
	var er = HBoxContainer.new()
	er.add_theme_constant_override("separation", 8)
	hv.add_child(er)
	ess_drop = UI.icon("drop", 62)
	ess_label = UI.label("5", 34)
	ess_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ess_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.full_rect(ess_label)
	ess_label.position.y += 6
	ess_drop.add_child(ess_label)
	er.add_child(ess_drop)
	ess_bar = Control.new()
	ess_bar.custom_minimum_size.y = 40
	ess_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ess_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ess_bar.draw.connect(_draw_essence)
	er.add_child(ess_bar)

	banner = UI.label("", 90, Color.WHITE, 16)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	banner.position.y -= 120
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(banner)

	ghost = TextureRect.new()
	ghost.custom_minimum_size = Vector2(110, 140)
	ghost.size = Vector2(110, 140)
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.visible = false
	hud.add_child(ghost)
	_refresh_hand(true)
	_build_emotes()

func _make_slot(i: int) -> Control:
	var slot = Control.new()
	slot.custom_minimum_size = Vector2(0, 165)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tex = TextureRect.new()
	tex.name = "Card"
	UI.full_rect(tex)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(tex)
	var cost = UI.icon("drop", 46)
	cost.name = "Cost"
	cost.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	cost.position.y += 14
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cl = UI.label("3", 26)
	cl.name = "N"
	UI.full_rect(cl)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cl.position.y += 4
	cost.add_child(cl)
	slot.add_child(cost)
	slot.gui_input.connect(_on_slot_input.bind(i))
	return slot

func _refresh_hand(force := false) -> void:
	var P: Dictionary = players[0]
	for i in 4:
		var slot: Control = slots[i]
		var id: String = P.hand[i]
		if force or slot.get_meta("id", "") != id:
			var old: String = slot.get_meta("id", "")
			slot.set_meta("id", id)
			(slot.get_node("Card") as TextureRect).texture = Data.card_textures[id]
			(slot.get_node("Cost/N") as Label).text = str(Data.CARDS[id].cost)
			if old != "":
				_animate_draw(slot)
	next_tex.texture = Data.card_textures[P.queue[0]]

## Nouvelle carte : elle glisse depuis « Suivante » en tournant.
func _animate_draw(slot: Control) -> void:
	var card: Control = slot.get_node("Card")
	card.pivot_offset = card.size / 2
	var from = next_tex.global_position - slot.global_position
	card.position = from
	card.scale = Vector2(0.6, 0.6)
	card.rotation = -0.4
	var tw = card.create_tween().set_parallel()
	tw.tween_property(card, "position", Vector2.ZERO, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "rotation", 0.0, 0.35)
	var nt = next_tex.create_tween()
	next_tex.pivot_offset = next_tex.size / 2
	next_tex.scale = Vector2(0.2, 1)
	nt.tween_property(next_tex, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _select(i: int) -> void:
	selected = i
	for k in 4:
		var card: Control = slots[k].get_node("Card")
		card.pivot_offset = card.size / 2
		var tw = card.create_tween().set_parallel()
		tw.tween_property(card, "position:y", -22.0 if k == i else 0.0, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale", Vector2(1.08, 1.08) if k == i else Vector2.ONE, 0.15)
	_hide_placement()
	if i >= 0:
		_show_placement(players[0].hand[i])

func _on_slot_input(ev: InputEvent, i: int) -> void:
	if over or not started:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			drag = {"slot": i, "start": ev.global_position, "moved": false, "pos": null}
			_select(i)
			Sfx.play("click", 1.3)
			ghost.texture = Data.card_textures[players[0].hand[i]]
		elif not drag.is_empty():
			var d = drag
			drag = {}
			ghost.visible = false
			if d.moved and d.pos != null:
				_try_deploy(d.slot, d.pos.x, d.pos.z)
			elif d.moved:
				_select(-1)
	elif ev is InputEventMouseMotion and not drag.is_empty():
		var gp: Vector2 = ev.global_position
		if gp.distance_to(drag.start) > 12:
			drag.moved = true
		if drag.moved:
			_update_drag(gp)

func _update_drag(gp: Vector2) -> void:
	var over_hand = gp.y > hand_panel.global_position.y
	var id: String = players[0].hand[drag.slot]
	var c: Dictionary = Data.CARDS[id]
	ghost.visible = over_hand
	ghost.position = gp - ghost.size * Vector2(0.5, 0.7)
	if over_hand:
		cursor.visible = false
		drag.pos = null
		return
	var p = _ground_at(gp)
	if p == null:
		cursor.visible = false
		drag.pos = null
		return
	p.x = clampf(p.x, -8.6, 8.6)
	p.z = clampf(p.z, -15.6, 15.6)
	if c.type != "spell" and not valid_zone(0, p.x, p.z, id):
		p.z = max(p.z, RIVER + 0.4)
	drag.pos = p
	cursor.visible = true
	cursor.position = Vector3(p.x, 0, p.z)
	var r: float = c.radius if c.type == "spell" else (c.range if c.type == "building" else (1.2 if c.get("count", 1) > 1 else max(0.7, c.radius * 1.4)))
	cursor_disc.scale = Vector3(r, 1, r)
	if cursor_model == null and c.type != "spell":
		cursor_model = Models.build(id, 0)
		cursor_model.rotation.y = PI
		cursor_model.scale = Vector3.ONE * (1.0 if RealModels.has(id) else 1.3)
		if c.get("flying", false):
			cursor_model.position.y = 2.6
		_ghostify(cursor_model)
		cursor.add_child(cursor_model)

func _ghostify(n: Node) -> void:
	for c in n.get_children():
		if c is GeometryInstance3D:
			c.transparency = 0.45
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ghostify(c)

func _unhandled_input(ev: InputEvent) -> void:
	if selected < 0 or over or not started or not drag.is_empty():
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var p = _ground_at(ev.global_position)
		if p != null:
			_try_deploy(selected, clampf(p.x, -8.6, 8.6), clampf(p.z, -15.6, 15.6))

func _ground_at(sp: Vector2):
	var o = cam.project_ray_origin(sp)
	var d = cam.project_ray_normal(sp)
	if abs(d.y) < 0.0001:
		return null
	var t = -o.y / d.y
	if t < 0:
		return null
	return o + d * t

func _try_deploy(slot: int, px: float, pz: float) -> void:
	var id: String = players[0].hand[slot]
	var c: Dictionary = Data.CARDS[id]
	if not valid_zone(0, px, pz, id):
		if c.type != "spell":
			pz = max(pz, RIVER + 0.4)
		if not valid_zone(0, px, pz, id):
			Sfx.play("no")
			return
	if essence[0] < c.cost:
		Sfx.play("no")
		fx.float_text(Vector3(px, 1.5, pz), "Pas assez d'essence !", Color("e59cff"), 40)
		var card: Control = slots[slot].get_node("Card")
		var tw = card.create_tween()
		for k in 3:
			tw.tween_property(card, "position:x", 8.0, 0.04)
			tw.tween_property(card, "position:x", -8.0, 0.04)
		tw.tween_property(card, "position:x", 0.0, 0.04)
		return
	deploy(0, id, px, pz)
	_cycle(0, slot)
	_select(-1)
	_refresh_hand()

func _build_placement() -> void:
	var fm = StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.albedo_color = Color(1, 0.15, 0.15, 0.3)
	for k in 2:
		var f = MeshInstance3D.new()
		var pm = PlaneMesh.new()
		pm.size = Vector2(1, 1)
		f.mesh = pm
		f.material_override = fm
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.visible = false
		add_child(f)
		if k == 0:
			forbid = f
		else:
			forbid2 = f
	cursor = Node3D.new()
	cursor_disc = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 1
	cm.bottom_radius = 1
	cm.height = 0.01
	cm.radial_segments = 40
	cursor_disc.mesh = cm
	cursor_disc.material_override = Models.mat(Color.WHITE, 0.0, 1.0, 0.0, 0.3)
	cursor_disc.position.y = 0.08
	cursor.add_child(cursor_disc)
	cursor.visible = false
	add_child(cursor)

func _set_zone(m: MeshInstance3D, x0: float, x1: float, z0: float, z1: float) -> void:
	m.visible = true
	m.scale = Vector3(x1 - x0, 1, z1 - z0)
	m.position = Vector3((x0 + x1) / 2, 0.07, (z0 + z1) / 2)

func _show_placement(id: String) -> void:
	var c: Dictionary = Data.CARDS[id]
	if c.type == "spell":
		return
	var open_l = valid_zone(0, -5, -3, id)
	var open_r = valid_zone(0, 5, -3, id)
	if not open_l and not open_r:
		_set_zone(forbid, -9, 9, -16, RIVER + 0.3)
	elif open_l and open_r:
		_set_zone(forbid, -9, 9, -16, -6)
	elif open_l:
		_set_zone(forbid, 0, 9, -16, RIVER + 0.3)
		_set_zone(forbid2, -9, 0, -16, -6)
	else:
		_set_zone(forbid, -9, 0, -16, RIVER + 0.3)
		_set_zone(forbid2, 0, 9, -16, -6)
	for f in [forbid, forbid2]:
		if f.visible:
			var m: StandardMaterial3D = f.material_override
			m.albedo_color.a = 0.0
			create_tween().tween_property(m, "albedo_color:a", 0.3, 0.15)

func _hide_placement() -> void:
	forbid.visible = false
	forbid2.visible = false
	cursor.visible = false
	if cursor_model:
		cursor_model.queue_free()
		cursor_model = null

func _show_banner(text: String, size := 90, color := Color.WHITE, dur := 1.4) -> void:
	banner.text = text
	banner.add_theme_font_size_override("font_size", size)
	banner.add_theme_color_override("font_color", color)
	banner.reset_size()
	banner.position = (get_viewport().get_visible_rect().size - banner.size) / 2 - Vector2(0, 140)
	banner.pivot_offset = banner.size / 2
	banner.scale = Vector2(2.6, 2.6)
	banner.modulate.a = 0.0
	banner.rotation = -0.08
	var tw = banner.create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(banner, "rotation", 0.0, 0.35)
	tw.tween_interval(max(0.1, dur - 0.65))
	tw.tween_property(banner, "modulate:a", 0.0, 0.25)
	tw.parallel().tween_property(banner, "scale", Vector2(0.6, 0.6), 0.25).set_ease(Tween.EASE_IN)

func _update_crowns() -> void:
	for t in [0, 1]:
		crown_labels[t].text = str(shown_crowns[t])

func _update_hud(_dt: float) -> void:
	var e: float = essence[0]
	var n = int(floor(e))
	if n != last_ess:
		ess_label.text = str(maxi(0, n))
		if n > last_ess:
			Sfx.play("essence")
			ess_drop.pivot_offset = ess_drop.size / 2
			ess_drop.scale = Vector2(1.3, 1.3)
			ess_drop.create_tween().tween_property(ess_drop, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		last_ess = n
	ess_bar.queue_redraw()
	var secs = int(ceil(max(0.0, time_left)))
	if secs != last_sec:
		last_sec = secs
		timer_label.text = "%d:%02d" % [secs / 60, secs % 60]
		timer_caption.text = "Prolongation" if overtime else ("Essence x2" if time_left <= 60.0 else "Fin dans")
		var x2 = overtime or time_left <= 60.0
		timer_box.add_theme_stylebox_override("panel", UI.panel(Color("8a1cc9") if x2 else Color(0, 0, 0, 0.6), 16))
		if secs <= 10 and started and not over:
			timer_label.add_theme_color_override("font_color", Color("ff6a6a"))
			UI.squash(timer_box, 1.0)
			Sfx.play("tick", 1.5)
	var P: Dictionary = players[0]
	for i in 4:
		var poor: bool = Data.CARDS[P.hand[i]].cost > e
		var card: Control = slots[i].get_node("Card")
		card.modulate = Color(0.45, 0.45, 0.5) if poor else Color.WHITE

func _draw_essence() -> void:
	var s = ess_bar.size
	var r = Rect2(Vector2.ZERO, s)
	ess_bar.draw_style_box(UI.panel(Color("2a0a44"), 12), r)
	var k: float = essence[0] / 10.0
	if k > 0.0:
		var fr = Rect2(Vector2(5, 5), Vector2((s.x - 10) * k, s.y - 10))
		var st = StyleBoxFlat.new()
		st.bg_color = Color("c23cf0")
		st.set_corner_radius_all(8)
		ess_bar.draw_style_box(st, fr)
		ess_bar.draw_rect(Rect2(fr.position + Vector2(4, 3), Vector2(max(0, fr.size.x - 8), 6)), Color(1, 1, 1, 0.35))
		if essence[0] >= 10.0:
			var a = 0.25 + sin(now * 6.0) * 0.2
			ess_bar.draw_rect(fr, Color(1, 1, 1, a))
	for i in range(1, 10):
		var x = 5 + (s.x - 10) * i / 10.0
		ess_bar.draw_line(Vector2(x, 6), Vector2(x, s.y - 6), Color(0, 0, 0, 0.45), 3)

func _draw_overlay() -> void:
	var f: Font = UI.font
	for e in entities:
		if not is_instance_valid(e) or not e.alive:
			continue
		if e.kind == "tower":
			var p = cam.unproject_position(Vector3(e.x, e.model.get_meta("top", 4.6) + (2.6 if e.core else 0.4), e.z))
			var w = 120.0 if e.core else 96.0
			_bar(Vector2(p.x - w / 2, p.y), w, 16, e.hp / e.max_hp, e.team, true)
			var txt = str(int(ceil(e.hp)))
			overlay.draw_string_outline(f, Vector2(p.x - w / 2, p.y - 4), txt, HORIZONTAL_ALIGNMENT_CENTER, w, 24, 8, UI.INK)
			overlay.draw_string(f, Vector2(p.x - w / 2, p.y - 4), txt, HORIZONTAL_ALIGNMENT_CENTER, w, 24, Color.WHITE)
			continue
		if e.hp >= e.max_hp and e.max_shield <= 0.0 and e.lifetime <= 0.0:
			continue
		var c: Dictionary = Data.CARDS[e.card_id]
		var h = e.y + 1.3 if e.flying else (3.4 if c.get("heavy", false) else (0.9 if e.card_id == "swarm" else (3.2 if e.card_id == "totem" else 2.2)))
		var p = cam.unproject_position(Vector3(e.x, h, e.z))
		var w = 34.0 if e.card_id == "swarm" else (78.0 if c.get("heavy", false) else 58.0)
		_bar(Vector2(p.x - w / 2, p.y), w, 10, e.hp / e.max_hp, e.team, false)
		if e.max_shield > 0.0 and e.shield > 0.0:
			_bar(Vector2(p.x - w / 2, p.y - 11), w, 7, e.shield / e.max_shield, 2, false)

func _bar(pos: Vector2, w: float, h: float, k: float, team: int, big: bool) -> void:
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.7)
	bg.set_corner_radius_all(5)
	overlay.draw_style_box(bg, Rect2(pos - Vector2(3, 3), Vector2(w + 6, h + 6)))
	var fg = StyleBoxFlat.new()
	fg.bg_color = Color("3aa0ff") if team == 0 else (Color("ff4458") if team == 1 else Color("f4c542"))
	fg.set_corner_radius_all(4)
	if k > 0.0:
		overlay.draw_style_box(fg, Rect2(pos, Vector2(w * clampf(k, 0, 1), h)))
		if big:
			overlay.draw_rect(Rect2(pos + Vector2(2, 2), Vector2(max(0, w * k - 4), h * 0.3)), Color(1, 1, 1, 0.3))


# ================= Émotes =================
const EMOTES = ["Bien joué !", "Merci !", "Oups !", "Grrr !", "Ha ha !", "Wouah !"]

func _build_emotes() -> void:
	var btn = Button.new()
	btn.text = "..."
	btn.add_theme_font_size_override("font_size", 34)
	var st = UI.panel(Color(1, 1, 1, 0.92), 40)
	st.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", st)
	btn.add_theme_stylebox_override("pressed", st)
	btn.add_theme_color_override("font_color", UI.INK)
	btn.add_theme_constant_override("outline_size", 0)
	btn.custom_minimum_size = Vector2(76, 76)
	btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hud.add_child(btn)
	btn.name = "EmoteButton"
	btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var menu = VBoxContainer.new()
	menu.visible = false
	menu.add_theme_constant_override("separation", 8)
	hud.add_child(menu)
	for t in EMOTES:
		var b = UI.button(t, Color.WHITE, 24)
		b.add_theme_color_override("font_color", UI.INK)
		b.add_theme_constant_override("outline_size", 0)
		b.pressed.connect(func():
			menu.visible = false
			_emote(0, t))
		menu.add_child(b)
	btn.pressed.connect(func():
		Sfx.play("open")
		menu.visible = not menu.visible
		menu.reset_size()
		menu.position = btn.position + Vector2(0, -menu.size.y - 10)
		if menu.visible:
			UI.pop_in(menu, 0.0, 0.6))

func _ai_emote(text: String) -> void:
	if ai_emote_cd > 0.0 or over and text != "GG !":
		return
	ai_emote_cd = 6.0
	get_tree().create_timer(randf_range(0.4, 1.0)).timeout.connect(func(): if is_instance_valid(self): _emote(1, text))

## Bulle d'émote au-dessus de la Tour Cœur, avec rebond.
func _emote(team: int, text: String) -> void:
	if emote_bubbles[team] and is_instance_valid(emote_bubbles[team]):
		emote_bubbles[team].queue_free()
	var p = PanelContainer.new()
	var st = UI.panel(Color.WHITE, 24)
	st.border_color = Data.TEAM_COLORS[team]
	st.set_border_width_all(5)
	p.add_theme_stylebox_override("panel", st)
	var l = UI.label(text, 34, UI.INK, 0)
	p.add_child(l)
	hud.add_child(p)
	emote_bubbles[team] = p
	Sfx.play("notify")
	var tz = 13.6 if team == 0 else -13.6
	await get_tree().process_frame
	if not is_instance_valid(p):
		return
	var sp = cam.unproject_position(Vector3(0, 6.5, tz))
	p.position = sp - Vector2(p.size.x / 2, p.size.y)
	p.pivot_offset = Vector2(p.size.x / 2, p.size.y)
	p.scale = Vector2(0.2, 0.2)
	var tw = p.create_tween()
	tw.tween_property(p, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "rotation", 0.06, 0.15)
	tw.tween_property(p, "rotation", -0.06, 0.15)
	tw.tween_property(p, "rotation", 0.0, 0.1)
	tw.tween_interval(1.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)
	if team == 0 and randf() < 0.5:
		_ai_emote(["Grrr !", "Ha ha !", "Merci !"][randi() % 3])
