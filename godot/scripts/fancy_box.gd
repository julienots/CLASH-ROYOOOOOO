class_name FancyBox
extends StyleBoxTexture
## Style de panneau/bouton « jeu mobile » : dégradé vertical, reflet brillant, ombre basse, bord sombre, coins arrondis.
## Texture générée puis étirée en 9 tranches. Compatible avec les propriétés de StyleBoxFlat qu'utilise le jeu.

static var _cache = {}

var bg_color: Color = Color.WHITE:
	set(v):
		bg_color = v
		_regen()
var border_color: Color = Color("0b1430"):
	set(v):
		border_color = v
		_regen()
var radius = 18
var border = 4
var shadow = 6
var gloss = 0.28
var border_width_left = 4:
	set(v):
		border_width_left = v
		border = v
		_regen()
var border_width_right = 4:
	set(v):
		border_width_right = v
var border_width_top = 4:
	set(v):
		border_width_top = v
var border_width_bottom = 4:
	set(v):
		border_width_bottom = v
var _ready_to_regen = false

static func make(color: Color, r := 18, b := 4, sh := 6, gl := 0.28) -> FancyBox:
	var f = FancyBox.new()
	f.radius = r
	f.border = b
	f.shadow = sh
	f.gloss = gl
	f._ready_to_regen = true
	f.bg_color = color
	f.content_margin_left = 18
	f.content_margin_right = 18
	f.content_margin_top = 10
	f.content_margin_bottom = 10 + sh
	return f

func set_border_width_all(w: int) -> void:
	border = w
	_regen()

func set_corner_radius_all(r: int) -> void:
	radius = r
	_regen()

func _regen() -> void:
	if not _ready_to_regen:
		return
	var key = "%s|%s|%d|%d|%d|%.2f" % [bg_color.to_html(), border_color.to_html(), radius, border, shadow, gloss]
	if not _cache.has(key):
		_cache[key] = _build()
	texture = _cache[key]
	var m = radius + border + 2
	texture_margin_left = m
	texture_margin_right = m
	texture_margin_top = m
	texture_margin_bottom = m + shadow

func _build() -> ImageTexture:
	var r = float(radius)
	var W = int(r * 2 + border * 2 + 24)
	var H = int(r * 2 + border * 2 + 24 + shadow)
	var img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	var top = bg_color.lightened(0.16)
	var bot = bg_color.darkened(0.14)
	var shade = bg_color.darkened(0.45)
	shade.a = bg_color.a
	var ink = border_color
	for y in H:
		for x in W:
			# distance au bord du rectangle arrondi (positif = dedans)
			var cx = clampf(x + 0.5, r, W - r)
			var cy = clampf(y + 0.5, r, H - r)
			var d = r - Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
			if d <= 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var aa = clampf(d, 0.0, 1.0)
			var col: Color
			if d < border:
				col = ink
			elif y >= H - shadow - border - 1 and d >= border:
				# tranche basse foncée : effet 3D
				col = shade
			else:
				var t = float(y) / float(H - shadow)
				col = top.lerp(bot, t)
				# reflet brillant dans le haut
				if y < H * 0.42 and d > border + 2:
					var k = 1.0 - float(y) / (H * 0.42)
					col = col.lerp(Color(1, 1, 1, col.a), gloss * (0.35 + 0.65 * k))
			col.a *= aa
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
