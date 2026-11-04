class_name WheelView extends Control
## Roue de la Fortune dessinée et animée : spin(index) la fait tourner jusqu'au segment voulu.

signal finished(index: int)

const R := 240.0
var disc: Control
var spinning := false
var _last_tick := -1

func _ready() -> void:
	custom_minimum_size = Vector2(R * 2 + 20, R * 2 + 60)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc = Control.new()
	disc.size = Vector2(R * 2, R * 2)
	disc.position = Vector2(10, 40)
	disc.pivot_offset = Vector2(R, R)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.draw.connect(_draw_disc)
	add_child(disc)
	# icônes et libellés posés sur le disque (ils tournent avec lui)
	var n := ShopLogic.WHEEL.size()
	var a := TAU / n
	for i in n:
		var s: Dictionary = ShopLogic.WHEEL[i]
		var ang := -PI / 2 + (i + 0.5) * a
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.position = Vector2(R, R) + Vector2.from_angle(ang) * R * 0.66
		holder.rotation = ang + PI / 2
		disc.add_child(holder)
		var ic := UI.icon_rect(s.icon, 46, Color("ffe9a8") if s.icon.begins_with("ui_") else Color.WHITE)
		ic.size = Vector2(46, 46)
		ic.position = Vector2(-23, -40)
		holder.add_child(ic)
		var l := UI.label(s.label, 20 if s.label.length() > 4 else 24, Color.WHITE, "num", 400, HORIZONTAL_ALIGNMENT_CENTER)
		UI.outline(l, 5)
		l.size = Vector2(110, 30)
		l.position = Vector2(-55, 6)
		holder.add_child(l)
	var hub := Panel.new()
	hub.size = Vector2(84, 84)
	hub.position = disc.position + Vector2(R - 42, R - 42)
	hub.add_theme_stylebox_override("panel", UI.box(Color("2a1a4a"), 42, UI.GOLD, 5))
	hub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hub)
	var star := UI.icon_rect("ui_star", 50, UI.GOLD)
	star.size = Vector2(50, 50)
	star.position = Vector2(17, 17)
	hub.add_child(star)

func _draw() -> void:
	# pointeur doré en haut
	var c := Vector2(10 + R, 40)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-26, -36), c + Vector2(26, -36), c + Vector2(0, 18)]), UI.GOLD)
	draw_polyline(PackedVector2Array([c + Vector2(-26, -36), c + Vector2(26, -36), c + Vector2(0, 18), c + Vector2(-26, -36)]), Color(0.2, 0.1, 0), 4)

func _draw_disc() -> void:
	var n := ShopLogic.WHEEL.size()
	var a := TAU / n
	var ctr := Vector2(R, R)
	disc.draw_circle(ctr, R + 10, Color("ffd36e"))
	disc.draw_circle(ctr, R + 4, Color("3a2208"))
	for i in n:
		var col := Color(ShopLogic.WHEEL[i].color)
		var pts := PackedVector2Array([ctr])
		var a0 := -PI / 2 + i * a
		for k in 25:
			pts.append(ctr + Vector2.from_angle(a0 + a * k / 24.0) * R)
		disc.draw_colored_polygon(pts, col)
		# reflet intérieur
		var pts2 := PackedVector2Array([ctr])
		for k in 25:
			pts2.append(ctr + Vector2.from_angle(a0 + a * k / 24.0) * R * 0.45)
		disc.draw_colored_polygon(pts2, col.lightened(0.15))
		disc.draw_line(ctr, ctr + Vector2.from_angle(a0) * R, Color("ffd36e"), 4)
	# ampoules du pourtour
	for k in n * 2:
		var p := ctr + Vector2.from_angle(-PI / 2 + k * a / 2) * (R + 7)
		disc.draw_circle(p, 5, Color("fff6d0") if k % 2 == 0 else Color("ff9a3a"))

## Fait tourner la roue pour qu'elle s'arrête sur le segment i.
func spin(i: int, fast := false) -> void:
	if spinning:
		return
	spinning = true
	var n := ShopLogic.WHEEL.size()
	var a := TAU / n
	var jitter := randf_range(-0.35, 0.35) * a
	var base := disc.rotation - fposmod(disc.rotation, TAU)
	var target := base + TAU * 6 + fposmod(-(i + 0.5) * a + jitter, TAU)
	var tw := create_tween()
	tw.tween_property(disc, "rotation", target, 0.4 if fast else 4.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		spinning = false
		finished.emit(i))

func _process(_dt: float) -> void:
	if not spinning:
		return
	var a := TAU / ShopLogic.WHEEL.size()
	var tick := int(floor(disc.rotation / a))
	if tick != _last_tick:
		_last_tick = tick
		Sfx.play("tear_tick", 1.3, -6.0)
