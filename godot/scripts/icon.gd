class_name Icon
extends Control
## Icônes vectorielles dessinées (couronne, trophée, pièce, gemme, essence, coffre…).

var kind = "crown"
var tint = Color.WHITE
var dim = false

func _draw() -> void:
	var s = minf(size.x, size.y)
	var o = (size - Vector2(s, s)) / 2
	var ink = UI.INK
	var k = Color(0.35, 0.35, 0.4) if dim else Color.WHITE
	match kind:
		"crown":
			var c = Color("ffd23f") * k
			if tint != Color.WHITE:
				c = tint * k
			var pts = PackedVector2Array([Vector2(0.08, 0.82), Vector2(0.08, 0.3), Vector2(0.3, 0.52), Vector2(0.5, 0.15), Vector2(0.7, 0.52), Vector2(0.92, 0.3), Vector2(0.92, 0.82)])
			_poly(pts, s, o, c, ink, 0.07)
			for p in [Vector2(0.08, 0.27), Vector2(0.5, 0.12), Vector2(0.92, 0.27)]:
				draw_circle(o + p * s, s * 0.07, ink)
				draw_circle(o + p * s, s * 0.045, Color("fff3a0") * k)
			draw_rect(Rect2(o + Vector2(0.14, 0.66) * s, Vector2(0.72, 0.08) * s), c.darkened(0.25))
		"trophy":
			var c = Color("ffc928")
			_poly(PackedVector2Array([Vector2(0.2, 0.1), Vector2(0.8, 0.1), Vector2(0.72, 0.5), Vector2(0.56, 0.6), Vector2(0.56, 0.75), Vector2(0.72, 0.8), Vector2(0.72, 0.92), Vector2(0.28, 0.92), Vector2(0.28, 0.8), Vector2(0.44, 0.75), Vector2(0.44, 0.6), Vector2(0.28, 0.5)]), s, o, c, ink, 0.06)
			draw_arc(o + Vector2(0.2, 0.3) * s, s * 0.14, PI / 2, PI * 1.5, 12, ink, s * 0.07)
			draw_arc(o + Vector2(0.8, 0.3) * s, s * 0.14, -PI / 2, PI / 2, 12, ink, s * 0.07)
			draw_rect(Rect2(o + Vector2(0.3, 0.16) * s, Vector2(0.1, 0.3) * s), Color(1, 1, 1, 0.45))
		"coin":
			draw_circle(o + Vector2(0.5, 0.5) * s, s * 0.46, ink)
			draw_circle(o + Vector2(0.5, 0.5) * s, s * 0.39, Color("f7b500"))
			draw_circle(o + Vector2(0.5, 0.46) * s, s * 0.3, Color("ffd84a"))
			draw_rect(Rect2(o + Vector2(0.44, 0.28) * s, Vector2(0.12, 0.36) * s), Color("e09a00"))
		"gem":
			_poly(PackedVector2Array([Vector2(0.5, 0.06), Vector2(0.9, 0.38), Vector2(0.5, 0.94), Vector2(0.1, 0.38)]), s, o, Color("4fe06a"), ink, 0.07)
			draw_colored_polygon(PackedVector2Array([o + Vector2(0.5, 0.12) * s, o + Vector2(0.8, 0.38) * s, o + Vector2(0.5, 0.38) * s]), Color("b8ffc0"))
		"drop":
			var c = Color("d052ff")
			_poly(PackedVector2Array([Vector2(0.5, 0.04), Vector2(0.2, 0.56), Vector2(0.8, 0.56)]), s, o, ink, ink, 0.12)
			draw_circle(o + Vector2(0.5, 0.62) * s, s * 0.34, ink)
			draw_colored_polygon(PackedVector2Array([o + Vector2(0.5, 0.12) * s, o + Vector2(0.26, 0.56) * s, o + Vector2(0.74, 0.56) * s]), c)
			draw_circle(o + Vector2(0.5, 0.62) * s, s * 0.28, c)
			draw_circle(o + Vector2(0.4, 0.58) * s, s * 0.08, Color(1, 1, 1, 0.6))
		"chest":
			_poly(PackedVector2Array([Vector2(0.08, 0.42), Vector2(0.92, 0.42), Vector2(0.92, 0.9), Vector2(0.08, 0.9)]), s, o, tint if tint != Color.WHITE else Color("a0642a"), ink, 0.06)
			_poly(PackedVector2Array([Vector2(0.08, 0.42), Vector2(0.15, 0.18), Vector2(0.85, 0.18), Vector2(0.92, 0.42)]), s, o, (tint if tint != Color.WHITE else Color("a0642a")).lightened(0.15), ink, 0.06)
			draw_rect(Rect2(o + Vector2(0.42, 0.36) * s, Vector2(0.16, 0.2) * s), Color("ffd23f"))
		"swords":
			for d in [-1, 1]:
				var a = Vector2(0.5 - 0.32 * d, 0.12)
				var b = Vector2(0.5 + 0.25 * d, 0.82)
				draw_line(o + a * s, o + b * s, ink, s * 0.16)
				draw_line(o + a * s, o + b * s, Color("e6eef8"), s * 0.09)
				draw_line(o + (b + Vector2(-0.12 * d, -0.08)) * s, o + (b + Vector2(0.1 * d, -0.16)) * s, Color("ffc928"), s * 0.08)
		"cards":
			for i in 2:
				var r = Rect2(o + Vector2(0.16 + i * 0.22, 0.1 + i * 0.08) * s, Vector2(0.48, 0.66) * s)
				draw_rect(r.grow(s * 0.04), ink)
				draw_rect(r, Color("4f8fff") if i == 0 else Color("ffb02e"))
		"shop":
			_poly(PackedVector2Array([Vector2(0.1, 0.3), Vector2(0.9, 0.3), Vector2(0.82, 0.88), Vector2(0.18, 0.88)]), s, o, Color("ff6a6a"), ink, 0.06)
			draw_arc(o + Vector2(0.5, 0.32) * s, s * 0.2, PI, TAU, 12, ink, s * 0.08)
		"island":
			_poly(PackedVector2Array([Vector2(0.1, 0.45), Vector2(0.9, 0.45), Vector2(0.5, 0.95)]), s, o, Color("8a6b4a"), ink, 0.06)
			_poly(PackedVector2Array([Vector2(0.05, 0.4), Vector2(0.95, 0.4), Vector2(0.95, 0.5), Vector2(0.05, 0.5)]), s, o, Color("58b847"), ink, 0.05)
			draw_rect(Rect2(o + Vector2(0.45, 0.15) * s, Vector2(0.08, 0.26) * s), Color("6b4423"))
			draw_circle(o + Vector2(0.5, 0.17) * s, s * 0.16, Color("3f9e3a"))
		"gear":
			for i in 8:
				var a = i / 8.0 * TAU
				draw_line(o + (Vector2(0.5, 0.5) + Vector2(cos(a), sin(a)) * 0.2) * s, o + (Vector2(0.5, 0.5) + Vector2(cos(a), sin(a)) * 0.42) * s, ink, s * 0.18)
			draw_circle(o + Vector2(0.5, 0.5) * s, s * 0.32, ink)
			for i in 8:
				var a = i / 8.0 * TAU
				draw_line(o + (Vector2(0.5, 0.5) + Vector2(cos(a), sin(a)) * 0.2) * s, o + (Vector2(0.5, 0.5) + Vector2(cos(a), sin(a)) * 0.38) * s, Color("b8c4d8"), s * 0.11)
			draw_circle(o + Vector2(0.5, 0.5) * s, s * 0.26, Color("b8c4d8"))
			draw_circle(o + Vector2(0.5, 0.5) * s, s * 0.1, ink)
		"shield":
			var col = tint if tint != Color.WHITE else Color("6a2fc4")
			_poly(PackedVector2Array([Vector2(0.15, 0.12), Vector2(0.85, 0.12), Vector2(0.85, 0.5), Vector2(0.5, 0.92), Vector2(0.15, 0.5)]), s, o, col, ink, 0.07)
			_poly(PackedVector2Array([Vector2(0.5, 0.2), Vector2(0.75, 0.2), Vector2(0.75, 0.5), Vector2(0.5, 0.8)]), s, o, col.lightened(0.25), ink, 0.0)
			_poly(PackedVector2Array([Vector2(0.38, 0.32), Vector2(0.62, 0.32), Vector2(0.62, 0.48), Vector2(0.5, 0.62), Vector2(0.38, 0.48)]), s, o, Color("ffc928"), ink, 0.04)
		"scroll":
			_poly(PackedVector2Array([Vector2(0.22, 0.15), Vector2(0.78, 0.15), Vector2(0.78, 0.85), Vector2(0.22, 0.85)]), s, o, Color("f4e3b8"), ink, 0.06)
			for j in 4:
				draw_line(o + Vector2(0.32, 0.3 + j * 0.13) * s, o + Vector2(0.68, 0.3 + j * 0.13) * s, Color("8a6a3a"), s * 0.04)
			draw_circle(o + Vector2(0.22, 0.15) * s, s * 0.09, Color("c9a96a"))
			draw_circle(o + Vector2(0.78, 0.85) * s, s * 0.09, Color("c9a96a"))
			draw_circle(o + Vector2(0.68, 0.78) * s, s * 0.1, Color("e23a3a"))
		"star":
			var pts = PackedVector2Array()
			for j in 10:
				var a = -PI / 2 + j * PI / 5
				var rr = 0.44 if j % 2 == 0 else 0.19
				pts.append(Vector2(0.5 + cos(a) * rr, 0.52 + sin(a) * rr))
			_poly(pts, s, o, Color("ffd23f"), ink, 0.06)
		"gift":
			_poly(PackedVector2Array([Vector2(0.15, 0.42), Vector2(0.85, 0.42), Vector2(0.85, 0.9), Vector2(0.15, 0.9)]), s, o, Color("ff6a8a"), ink, 0.06)
			_poly(PackedVector2Array([Vector2(0.1, 0.3), Vector2(0.9, 0.3), Vector2(0.9, 0.45), Vector2(0.1, 0.45)]), s, o, Color("ff8aa6"), ink, 0.05)
			draw_rect(Rect2(o + Vector2(0.44, 0.3) * s, Vector2(0.12, 0.6) * s), Color("ffd23f"))
			draw_circle(o + Vector2(0.38, 0.22) * s, s * 0.1, Color("ffd23f"))
			draw_circle(o + Vector2(0.62, 0.22) * s, s * 0.1, Color("ffd23f"))
		"lock":
			draw_arc(o + Vector2(0.5, 0.42) * s, s * 0.2, PI, TAU, 12, ink, s * 0.1)
			_poly(PackedVector2Array([Vector2(0.2, 0.42), Vector2(0.8, 0.42), Vector2(0.8, 0.9), Vector2(0.2, 0.9)]), s, o, Color("ffc928"), ink, 0.06)

func _poly(pts: PackedVector2Array, s: float, o: Vector2, fill: Color, ink: Color, w: float) -> void:
	var p = PackedVector2Array()
	for v in pts:
		p.append(o + v * s)
	draw_colored_polygon(p, fill)
	p.append(p[0])
	draw_polyline(p, ink, s * w, true)
