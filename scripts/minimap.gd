extends Control
const Island := preload("res://scripts/island.gd")
## Top-right map. Draws the real irregular silhouette, not a green disc.

const MAP_R := 168.0
const MAP_ORIGIN := Vector2(58.0, 8.0)
const LANDMARKS := [
	{"pos": Vector2(0.0, 0.0), "color": Color(1.00, 0.62, 0.22), "r": 4.2, "name": "祭"},
	{"pos": Vector2(0.0, -22.0), "color": Color(0.82, 0.32, 0.22), "r": 3.4, "name": "村"},
	{"pos": Vector2(-2.0, -40.0), "color": Color(0.62, 0.58, 0.52), "r": 3.6, "name": "寨"},
	{"pos": Vector2(108.0, 28.0), "color": Color(0.18, 0.42, 0.18), "r": 4.0, "name": "林"},
	{"pos": Vector2(-50.0, 2.0), "color": Color(0.86, 0.74, 0.42), "r": 3.4, "name": "码"},
	{"pos": Vector2(0.0, 30.0), "color": Color(0.48, 0.40, 0.46), "r": 3.4, "name": "哨"},
]

var player: Node3D
var _font: Font
var _land_tris: Array = []
var _coast: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Noto Sans CJK SC", "Noto Sans CJK JP", "Noto Sans"])
	Island.ensure()
	_coast = Island.poly()
	var idx := Geometry2D.triangulate_polygon(_coast)
	_land_tris.clear()
	for i in range(0, idx.size() - 2, 3):
		_land_tris.append([_coast[idx[i]], _coast[idx[i + 1]], _coast[idx[i + 2]]])


func _process(_delta: float) -> void:
	if not visible:
		return
	if player == null or not is_instance_valid(player):
		var tree := get_tree()
		if tree:
			var ps := tree.get_nodes_in_group("player")
			if ps.size() > 0:
				player = ps[0]
	queue_redraw()


func _wz(p: Vector2) -> Vector2:
	var c := size * 0.5
	var sc := (minf(size.x, size.y) * 0.5 - 10.0) / MAP_R
	var q := p - MAP_ORIGIN
	return Vector2(c.x + q.x * sc, c.y - q.y * sc)


func _draw() -> void:
	var c := size * 0.5
	var outer := minf(size.x, size.y) * 0.5 - 2.0
	draw_circle(c, outer, Color(0.06, 0.08, 0.10, 0.78))
	draw_arc(c, outer - 1.0, 0.0, TAU, 48, Color(0.72, 0.58, 0.32, 0.85), 2.0, true)
	# ocean fill inside the chrome disc
	draw_circle(c, outer - 4.0, Color(0.16, 0.32, 0.42, 0.62))

	# real land silhouette — darker green on the eastern jungle lobe
	for tri in _land_tris:
		var mid: Vector2 = (tri[0] + tri[1] + tri[2]) / 3.0
		var col := Color(0.18, 0.36, 0.16, 0.94) if mid.x > 28.0 else Color(0.30, 0.50, 0.26, 0.94)
		draw_colored_polygon(PackedVector2Array([_wz(tri[0]), _wz(tri[1]), _wz(tri[2])]), col)

	# sand edge
	if _coast.size() >= 3:
		var sand := PackedVector2Array()
		for p in _coast:
			sand.append(_wz(p))
		sand.append(_wz(_coast[0]))
		draw_polyline(sand, Color(0.78, 0.68, 0.42, 0.88), 2.4, true)

	var brown := Color(0.50, 0.34, 0.16, 0.95)
	var w := 3.2
	_line(Vector2(0, 34), Vector2(0, -44), brown, w)
	_line(Vector2(-50, 0), Vector2(34, 0), brown, w)
	_line(Vector2(-16, -21), Vector2(22, -21), brown, w * 0.75)
	_line(Vector2(31, 0), Vector2(31, 17), brown, w * 0.75)
	_line(Vector2(0, -36), Vector2(0, -42), brown, w * 0.8)
	# jungle valley trail
	var trail := Island.trail_points()
	if trail.size() >= 2:
		var tp := PackedVector2Array()
		for q in trail:
			tp.append(_wz(q))
		draw_polyline(tp, Color(0.42, 0.28, 0.14, 0.92), 2.6, true)

	for lm in LANDMARKS:
		var p: Vector2 = _wz(lm["pos"])
		draw_circle(p, float(lm["r"]), lm["color"])
		draw_circle(p, float(lm["r"]) - 1.2, lm["color"].lightened(0.25))
		if _font:
			var lab: String = lm["name"]
			draw_string(_font, p + Vector2(-6, -7), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.96, 0.88, 0.95))

	var tree := get_tree()
	if tree:
		for s in tree.get_nodes_in_group("shrines"):
			if not is_instance_valid(s):
				continue
			if ("broken" in s) and s.broken:
				continue
			var sp := _wz(Vector2(s.global_position.x, s.global_position.z))
			draw_circle(sp, 3.2, Color(0.90, 0.76, 0.36))
			draw_circle(sp, 2.0, Color(0.98, 0.88, 0.52))
			if _font:
				draw_string(_font, sp + Vector2(-6, -7), "祠", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.96, 0.88, 0.95))

	if player and is_instance_valid(player):
		var pp := _wz(Vector2(player.global_position.x, player.global_position.z))
		var yaw := player.rotation.y
		var tip := pp + Vector2(sin(yaw), -cos(yaw)) * 8.0
		var left := pp + Vector2(sin(yaw + 2.4), -cos(yaw + 2.4)) * 5.0
		var right := pp + Vector2(sin(yaw - 2.4), -cos(yaw - 2.4)) * 5.0
		draw_colored_polygon(PackedVector2Array([tip, left, right]), Color(1.0, 0.95, 0.55))
		draw_circle(pp, 2.4, Color(0.12, 0.08, 0.04))

	if _font:
		draw_string(_font, Vector2(8, 16), "雾火岛", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.88, 0.70, 0.9))


func _line(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	draw_line(_wz(a), _wz(b), color, width, true)
