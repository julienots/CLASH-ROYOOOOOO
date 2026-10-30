extends Node
## Effets sonores synthétisés au démarrage (aucun fichier audio). (Autoload « Sfx »)

const RATE := 22050
var streams = {}
var players: Array[AudioStreamPlayer] = []
var muted = false

func _ready() -> void:
	for i in 12:
		var p = AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	# [fréquence, durée, forme, glissement, bruit, volume, (notes)]
	_make("click", [[660.0, 0.08, "tri", 200.0, 0.0, 0.5]])
	_make("deploy", [[220.0, 0.22, "tri", -100.0, 0.5, 0.6]])
	_make("sword", [[2400.0, 0.12, "noise", 0.0, 1.0, 0.4]])
	_make("hit", [[150.0, 0.12, "square", -70.0, 0.2, 0.35]])
	_make("arrow", [[1300.0, 0.12, "sine", -900.0, 0.1, 0.2]])
	_make("fire", [[320.0, 0.3, "saw", -180.0, 0.7, 0.4]])
	_make("boom", [[90.0, 0.6, "sine", -50.0, 0.9, 0.9]])
	_make("zap", [[1800.0, 0.18, "saw", -1500.0, 0.5, 0.35]])
	_make("freeze", [[1500.0, 0.5, "sine", 900.0, 0.1, 0.35], [2200.0, 0.4, "tri", 600.0, 0.0, 0.2, 0.05]])
	_make("beam", [[880.0, 0.15, "sine", 300.0, 0.0, 0.2]])
	_make("tower_down", [[70.0, 1.0, "sine", -30.0, 1.0, 1.0]])
	_make("crown", [[523.0, 0.2, "tri", 0.0, 0.0, 0.45, 0.0], [659.0, 0.2, "tri", 0.0, 0.0, 0.45, 0.1], [784.0, 0.3, "tri", 0.0, 0.0, 0.45, 0.2]])
	_make("win", [[523.0, 0.25, "tri", 0, 0, 0.5, 0.0], [659.0, 0.25, "tri", 0, 0, 0.5, 0.14], [784.0, 0.25, "tri", 0, 0, 0.5, 0.28], [1046.0, 0.5, "tri", 0, 0, 0.5, 0.42]])
	_make("lose", [[392.0, 0.35, "saw", 0, 0, 0.25, 0.0], [349.0, 0.35, "saw", 0, 0, 0.25, 0.2], [311.0, 0.35, "saw", 0, 0, 0.25, 0.4], [262.0, 0.6, "saw", 0, 0, 0.25, 0.6]])
	_make("essence", [[1046.0, 0.06, "sine", 0.0, 0.0, 0.12]])
	_make("no", [[140.0, 0.15, "square", 0.0, 0.0, 0.35]])
	_make("whoosh", [[400.0, 0.3, "noise", 0.0, 1.0, 0.3]])
	_make("tick", [[880.0, 0.1, "square", 0.0, 0.0, 0.3]])
	_make("go", [[523.0, 0.15, "square", 0, 0, 0.3, 0.0], [1046.0, 0.35, "square", 0, 0, 0.3, 0.1]])
	_make("coin", [[1318.0, 0.08, "square", 0, 0, 0.25, 0.0], [1760.0, 0.15, "square", 0, 0, 0.25, 0.06]])
	_make("pop", [[300.0, 0.1, "sine", 600.0, 0.0, 0.4]])
	muted = Data.save.get("muted", false)

func _make(id: String, parts: Array) -> void:
	var total = 0.0
	for p in parts:
		total = max(total, float(p[1]) + (float(p[6]) if p.size() > 6 else 0.0))
	var n = int(total * RATE)
	var buf = PackedFloat32Array()
	buf.resize(n)
	buf.fill(0.0)
	for p in parts:
		var freq = float(p[0])
		var dur = float(p[1])
		var shape: String = p[2]
		var slide = float(p[3])
		var noise = float(p[4])
		var vol = float(p[5])
		var start = int((float(p[6]) if p.size() > 6 else 0.0) * RATE)
		var len = int(dur * RATE)
		var phase = 0.0
		var lp = 0.0
		for i in len:
			var t = float(i) / len
			var f: float = max(20.0, freq + slide * t)
			phase += f / RATE
			var ph = fmod(phase, 1.0)
			var v = 0.0
			match shape:
				"sine": v = sin(ph * TAU)
				"tri": v = 4.0 * abs(ph - 0.5) - 1.0
				"square": v = 1.0 if ph < 0.5 else -1.0
				"saw": v = ph * 2.0 - 1.0
				"noise": v = 0.0
			var nz = randf() * 2.0 - 1.0
			lp += (nz - lp) * clamp(freq / RATE * 2.0, 0.02, 1.0)
			v = v * (1.0 - noise) + (lp if shape != "noise" else nz * 0.5 + lp * 0.5) * noise * (1.6 if shape != "noise" else 1.0)
			var env = min(1.0, t * 40.0) * pow(1.0 - t, 2.0)
			if start + i < n:
				buf[start + i] += v * env * vol
	var data = PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clamp(buf[i], -1.0, 1.0) * 32000.0))
	var s = AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = data
	streams[id] = s

func play(id: String, pitch := 1.0) -> void:
	if muted or not streams.has(id):
		return
	for p in players:
		if not p.playing:
			p.stream = streams[id]
			p.pitch_scale = pitch * randf_range(0.95, 1.05)
			p.play()
			return

func set_muted(v: bool) -> void:
	muted = v
	Data.save.muted = v
	Data.persist()
