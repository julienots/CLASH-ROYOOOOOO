extends Node
## Audio : effets sonores (variantes + couches), musiques avec fondu enchaîné, ambiance. (Autoload « Sfx »)

const DIR := "res://assets/sounds/"

## Identifiant logique -> liste de couches [fichier (sans _N.ogg), nombre de variantes, volume dB]
const BANK := {
	"click": [["ui_press", 1, -4.0]],
	"back": [["ui_back", 1, -4.0]],
	"swipe": [["ui_swipe", 1, -6.0]],
	"open": [["ui_open", 1, -4.0]],
	"close": [["ui_close", 1, -4.0]],
	"no": [["ui_error", 1, -3.0]],
	"reward": [["ui_reward", 1, -2.0]],
	"levelup": [["ui_levelup", 1, -1.0]],
	"unlock": [["ui_unlock", 1, -2.0]],
	"purchase": [["ui_purchase", 1, -3.0]],
	"achievement": [["ui_achievement", 1, -2.0]],
	"select": [["ui_select", 1, -6.0]],
	"bonus": [["ui_bonus", 1, -4.0]],
	"notify": [["ui_notify", 1, -4.0]],
	"streak": [["ui_streak", 1, -2.0]],
	"toggle": [["ui_toggle", 1, -5.0]],
	"step": [["ui_step", 1, -8.0]],
	"coin": [["k_coin", 1, -8.0]],
	"pop": [["k_place", 2, -6.0]],
	"deploy": [["deploy", 1, -3.0], ["k_place", 2, -4.0]],
	"sword": [["sword", 3, -6.0]],
	"hit": [["heavy", 3, -3.0], ["k_impact", 1, -10.0]],
	"stab": [["stab", 3, -9.0]],
	"arrow": [["bow", 3, -9.0]],
	"arrow_hit": [["arrow_hit", 3, -12.0]],
	"fire": [["fire_cast", 1, -6.0]],
	"boom": [["explode", 1, -3.0], ["k_break", 1, -10.0]],
	"big_boom": [["big_boom", 1, 0.0], ["k_break", 1, -6.0]],
	"meteor": [["meteor_fall", 1, -4.0]],
	"zap": [["zap", 1, -3.0]],
	"freeze": [["freeze", 1, -2.0]],
	"beam": [["beam", 1, -10.0]],
	"rattle": [["rattle", 1, -6.0]],
	"death": [["death", 3, -9.0], ["k_destroy", 1, -16.0]],
	"tower_hit": [["tower_hit", 3, -12.0]],
	"tower_down": [["collapse", 1, 0.0]],
	"fuse": [["fuse", 1, -10.0]],
	"crown": [["crown", 1, -2.0]],
	"go": [["go", 1, -1.0]],
	"tick": [["tick", 1, -3.0]],
	"win": [["victory", 1, -1.0]],
	"lose": [["defeat", 1, -2.0]],
	"vs": [["vs", 1, -1.0]],
	"chest": [["chest", 1, -1.0]],
	"essence": [["ui_step", 1, -18.0]],
	"whoosh": [["ui_swipe", 1, -2.0]],
}

var _cache := {}
var players: Array[AudioStreamPlayer] = []
var music_a: AudioStreamPlayer
var music_b: AudioStreamPlayer
var ambience: AudioStreamPlayer
var current_music := ""
var muted := false
var music_on := true
var _last_play := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i in 24:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		players.append(p)
	music_a = _music_player()
	music_b = _music_player()
	ambience = _music_player()
	muted = Data.save.get("muted", false)
	music_on = Data.save.get("music", true)
	_apply_mute()

func _setup_buses() -> void:
	var lim := AudioEffectLimiter.new()
	lim.ceiling_db = -0.5
	lim.threshold_db = -3.0
	AudioServer.add_bus_effect(0, lim)
	for b in ["Music", "SFX"]:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, b)
		AudioServer.set_bus_send(idx, "Master")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), -7.0)
	var comp := AudioEffectCompressor.new()
	comp.threshold = -14.0
	comp.ratio = 3.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"), comp)

func _music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = -80.0
	add_child(p)
	return p

func _stream(file: String) -> AudioStream:
	if not _cache.has(file):
		var path := DIR + file + ".ogg"
		_cache[file] = load(path) if ResourceLoader.exists(path) else null
	return _cache[file]

func play(id: String, pitch := 1.0, vol := 0.0) -> void:
	if muted or not BANK.has(id):
		return
	# évite d'empiler 10 fois le même son dans la même image
	var now := Time.get_ticks_msec()
	if _last_play.get(id, -1000) > now - 40:
		return
	_last_play[id] = now
	for layer in BANK[id]:
		var n: int = layer[1]
		var s := _stream("%s_%d" % [layer[0], randi() % n])
		if s == null:
			continue
		for p in players:
			if not p.playing:
				p.stream = s
				p.volume_db = float(layer[2]) + vol
				p.pitch_scale = pitch * randf_range(0.94, 1.06)
				p.play()
				break

## Musique avec fondu enchaîné : "menu", "battle", "final" ou "" pour couper.
func music(name: String) -> void:
	if name == current_music:
		return
	current_music = name
	var old := music_a if music_a.playing and music_a.volume_db > -60 else music_b
	var new := music_b if old == music_a else music_a
	var tw := create_tween().set_parallel()
	if old.playing:
		tw.tween_property(old, "volume_db", -80.0, 1.0)
		tw.chain().tween_callback(old.stop)
	if name != "" and music_on and not muted:
		var s: AudioStreamOggVorbis = _stream("music_" + name)
		if s:
			s.loop = true
			new.stream = s
			new.volume_db = -40.0
			new.play()
			create_tween().tween_property(new, "volume_db", 0.0, 0.8)

func set_ambience(on: bool) -> void:
	if on and not muted:
		if not ambience.playing:
			var s: AudioStreamOggVorbis = _stream("ambience")
			if s:
				s.loop = true
				ambience.stream = s
				ambience.play()
				create_tween().tween_property(ambience, "volume_db", -12.0, 1.5)
	elif ambience.playing:
		var tw := create_tween()
		tw.tween_property(ambience, "volume_db", -80.0, 1.0)
		tw.tween_callback(ambience.stop)

func _apply_mute() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), muted)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), muted or not music_on)

func set_muted(v: bool) -> void:
	muted = v
	Data.save.muted = v
	Data.persist()
	_apply_mute()

func set_music(v: bool) -> void:
	music_on = v
	Data.save.music = v
	Data.persist()
	_apply_mute()
	if v and current_music != "":
		var m := current_music
		current_music = ""
		music(m)
