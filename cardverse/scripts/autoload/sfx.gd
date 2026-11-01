extends Node
## Lecture des effets sonores (pool de lecteurs) et de la musique en boucle.

var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _cache := {}
var _current_music := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -8
	add_child(_music)

func _stream(name: String) -> AudioStream:
	if not _cache.has(name):
		var path := "res://assets/audio/%s.wav" % name
		_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return _cache[name]

func play(name: String, pitch := 1.0, vol := 0.0) -> void:
	if not Profile.d.get("settings", {}).get("sfx", true):
		return
	var s := _stream(name)
	if s == null:
		return
	for p in _players:
		if not p.playing:
			p.stream = s
			p.pitch_scale = pitch
			p.volume_db = vol
			p.play()
			return
	_players[0].stream = s
	_players[0].play()

func music(name: String) -> void:
	if name == _current_music and _music.playing:
		return
	_current_music = name
	if not Profile.d.get("settings", {}).get("music", true):
		_music.stop()
		return
	var s := _stream(name)
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = int(s.get_length() * s.mix_rate)
	_music.stream = s
	_music.volume_db = -30
	_music.play()
	create_tween().tween_property(_music, "volume_db", -9.0, 1.2)

func refresh_music() -> void:
	var n := _current_music
	_current_music = ""
	if Profile.d.settings.get("music", true):
		music(n)
	else:
		_music.stop()
