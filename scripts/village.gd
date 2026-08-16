extends Node3D
const Island := preload("res://scripts/island.gd")

## Planned hamlet on the Kenney 2 m grid (native 1 m tiles scaled x2).
## Town walls have their FACE on local +X at +0.5 m ( +1 m after scale ).
## Placing a piece at a cell center puts that face on the matching cell edge.

const G := 2.0
const S := 2.0

var blockers: Array = []
var _cache: Dictionary = {}
var _roads: Dictionary = {}
var road_count := 0
var house_count := 0
var dock_anchor := Vector3(-55.4, 0.35, 9.0)

const PIRATE_COLORMAP := "res://assets/kenney_pirate/Textures/colormap.png"


func setup() -> void:
	name = "Village"
	add_to_group("village")
	_pave_roads()
	_build_altar_ring()
	_build_signs()
	_build_plaza()
	_build_keep_ring()
	_build_cottages()
	_build_fences()
	_build_props()
	_build_shore()
	_build_woods_camp()
	_build_outpost()
	_build_decor()
	print("village grid=", G, " houses=", house_count, " road_tiles=", road_count, " outpost=(0,30)")


func blocks(pos: Vector3, pad: float = 2.4) -> bool:
	var p := Vector3(pos.x, 0.0, pos.z)
	for b in blockers:
		var q: Vector3 = b["pos"]
		if Vector3(p.x - q.x, 0.0, p.z - q.z).length() < float(b["r"]) + pad:
			return true
	return false


func on_road(pos: Vector3, pad: float = 1.35) -> bool:
	var ix := int(floor(pos.x / G))
	var iz := int(floor(pos.z / G))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var key := "%d,%d" % [ix + dx, iz + dz]
			if not _roads.has(key):
				continue
			var c := _cell(ix + dx, iz + dz)
			if Vector2(pos.x - c.x, pos.z - c.z).length() < G * 0.72 + pad:
				return true
	return false


func road_points() -> Array:
	var pts: Array = []
	for k in _roads.keys():
		var sp := String(k).split(",")
		if sp.size() < 2:
			continue
		pts.append(_cell(int(sp[0]), int(sp[1])))
	return pts


func _scene(path: String) -> PackedScene:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		_cache[path] = null
		return null
	var ps: Resource = load(path)
	if ps is PackedScene:
		_cache[path] = ps
		return ps
	_cache[path] = null
	return null


func _inst(path: String, pos: Vector3, yaw: float = 0.0, scl: float = 1.0, polish: bool = false, dress: bool = false) -> Node3D:
	var ps := _scene(path)
	if ps == null:
		return null
	var n: Node3D = ps.instantiate()
	n.position = pos
	n.rotation.y = yaw
	if scl != 1.0:
		n.scale = Vector3(scl, scl, scl)
	add_child(n)
	if dress:
		Mats.dress_tree(n)
	elif polish:
		Mats.polish_imported(n)
	return n


func _k(name: String) -> String:
	return "res://assets/kenney_fantasy_town/%s.glb" % name


func _p(name: String) -> String:
	return "res://assets/kenney_pirate/%s.glb" % name


func _c(name: String) -> String:
	return "res://assets/kenney_castle/%s.glb" % name


func _n(name: String) -> String:
	return "res://assets/kenney_nature/%s.glb" % name


func _qt(name: String) -> String:
	return "res://assets/quaternius_trees/%s.glb" % name


func _q(name: String) -> String:
	return "res://assets/quaternius_village/%s.gltf" % name


func _cell(ix: int, iz: int) -> Vector3:
	return Vector3((float(ix) + 0.5) * G, 0.0, (float(iz) + 0.5) * G)


func _block(pos: Vector3, r: float, h: float = 2.8) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3(pos.x, pos.y, pos.z)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(r * 1.7, h, r * 1.7)
	col.shape = box
	col.position = Vector3(0.0, h * 0.5, 0.0)
	body.add_child(col)
	add_child(body)
	blockers.append({"pos": Vector3(pos.x, 0.0, pos.z), "r": r})


func _town(name: String, pos: Vector3, yaw: float = 0.0) -> void:
	_inst(_k(name), pos, yaw, S)


func _castle(name: String, pos: Vector3, yaw: float = 0.0, y: float = 0.0) -> void:
	_inst(_c(name), Vector3(pos.x, y, pos.z), yaw, S)


func _road(ix: int, iz: int) -> void:
	var key := "%d,%d" % [ix, iz]
	if _roads.has(key):
		return
	_roads[key] = true
	road_count += 1


func _build_road_mesh() -> void:
	# One continuous dirt ArrayMesh. 2 m cell PLAN stays; UVs are world xz
	# so adjacent cells share the albedo — no chocolate-bar seams.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var uv_s := 4.5
	var lift := 0.028
	var used := 0
	for k in _roads.keys():
		var sp := String(k).split(",")
		if sp.size() < 2:
			continue
		var ix := int(sp[0])
		var iz := int(sp[1])
		var pad := 0.04
		var x0 := float(ix) * G - pad
		var x1 := x0 + G + pad * 2.0
		var z0 := float(iz) * G - pad
		var z1 := z0 + G + pad * 2.0
		var v00 := Vector3(x0, Island.height_at(x0, z0) + lift, z0)
		var v10 := Vector3(x1, Island.height_at(x1, z0) + lift, z0)
		var v01 := Vector3(x0, Island.height_at(x0, z1) + lift, z1)
		var v11 := Vector3(x1, Island.height_at(x1, z1) + lift, z1)
		for v in [v00, v10, v11, v00, v11, v01]:
			st.set_normal(Vector3.UP)
			st.set_color(Color.WHITE)
			st.set_uv(Vector2(v.x / uv_s, v.z / uv_s))
			st.add_vertex(v)
		used += 2
	var mesh := st.commit()
	mesh.custom_aabb = AABB(Vector3(-80.0, -2.0, -80.0), Vector3(160.0, 12.0, 160.0))
	var mi := MeshInstance3D.new()
	mi.name = "VillageRoads"
	mi.mesh = mesh
	mi.material_override = Mats.ground(Mats.dirt_tex(), Color(1.08, 0.94, 0.76))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 16.0
	add_child(mi)
	print("ROAD_DRAW ArrayMesh tris=", used, " cells=", road_count, " uv=xz/4.5 tex=dirt")


func _road_rect(x0: int, x1: int, z0: int, z1: int) -> void:
	var xa := mini(x0, x1)
	var xb := maxi(x0, x1)
	var za := mini(z0, z1)
	var zb := maxi(z0, z1)
	for ix in range(xa, xb + 1):
		for iz in range(za, zb + 1):
			_road(ix, iz)


func _pave_roads() -> void:
	# Main street: 4 m wide, altar -> plaza -> keep gate (south / -Z).
	_road_rect(-1, 0, -22, -1)
	# Plaza paving (also covers the main street through the square).
	_road_rect(-3, 1, -13, -9)
	# Cross street through the plaza, east spur to the mill.
	_road_rect(-8, 10, -11, -10)
	# Keep courtyard
	_road_rect(-2, 0, -21, -19)
	# East road: altar -> woods landing.
	_road_rect(1, 16, -1, 0)
	# Woods clearing (road ends among the trees).
	_road_rect(14, 16, 1, 8)
	# West road: altar -> shore / pier.
	_road_rect(-22, -2, -1, 0)
	# North road: altar -> 哨所 courtyard.
	_road_rect(-1, 0, 1, 14)
	_road_rect(-2, 1, 13, 16)
	# Ring: mill east, then north to meet the woods road.
	_road_rect(10, 16, -11, -10)
	_road_rect(15, 16, -9, 0)
	_build_road_mesh()


func _build_plaza() -> void:
	# Fountain on the plaza center (native 2 m piece, no extra scale).
	_inst(_k("fountain-round"), Vector3(-2.0, 0.0, -22.0), 0.0, 1.0)
	_block(Vector3(-2.0, 0.0, -22.0), 1.15, 1.4)
	# Four stalls on plaza tiles, axis-aligned, facing inward.
	_town("stall-red", _cell(-3, -11), 0.0)
	_town("stall-green", _cell(1, -11), PI)
	_town("stall", _cell(-1, -13), PI * 0.5)
	_town("stall-bench", _cell(-1, -9), -PI * 0.5)
	_block(_cell(-3, -11), 1.05, 1.7)
	_block(_cell(1, -11), 1.05, 1.7)
	_inst(_k("cart"), _cell(1, -9), PI * 0.5, 1.0)
	_inst(_q("Prop_Wagon"), _cell(-3, -9), 0.0, 1.0)
	_inst(_q("Prop_Crate"), Vector3(-5.0, 0.0, -17.0), 0.0, 1.0)
	_inst(_q("Prop_Crate"), Vector3(-4.2, 0.0, -16.2), PI * 0.5, 1.0)
	_block(_cell(-3, -9), 1.4, 1.6)
	_lantern(_cell(-3, -13))
	_lantern(_cell(1, -13))
	_lantern(_cell(-3, -9))
	_lantern(_cell(1, -9))
	_town("banner-red", _cell(-3, -12), 0.0)
	_town("banner-green", _cell(1, -12), PI)


func _lantern(pos: Vector3) -> void:
	_inst(_k("lantern"), pos, 0.0, 1.0)
	var ol := OmniLight3D.new()
	ol.position = pos + Vector3(0.0, 1.7, 0.0)
	ol.light_color = Color(1.0, 0.72, 0.38)
	ol.light_energy = 1.05
	ol.omni_range = 5.2
	ol.shadow_enabled = false
	add_child(ol)


func _build_keep_ring() -> void:
	# 5 x 5 cell rectangular keep, gate on the south wall facing the plaza/altar.
	var x0 := -3
	var x1 := 1
	var z0 := -22
	var z1 := -18
	var corners := [[x0, z0], [x1, z0], [x0, z1], [x1, z1]]
	for c in corners:
		_tower(_cell(c[0], c[1]))
	# North wall (between towers)
	for ix in range(x0 + 1, x1):
		_castle("wall", _cell(ix, z0), 0.0)
		_block(_cell(ix, z0), 1.15, 2.7)
	# East / west walls
	for iz in range(z0 + 1, z1):
		_castle("wall", _cell(x0, iz), PI * 0.5)
		_castle("wall", _cell(x1, iz), PI * 0.5)
		_block(_cell(x0, iz), 1.15, 2.7)
		_block(_cell(x1, iz), 1.15, 2.7)
	# South wall — leave x=-1 and x=0 open as the gate (on the main road).
	for ix in range(x0 + 1, x1):
		if ix == -1 or ix == 0:
			continue
		_castle("wall", _cell(ix, z1), 0.0)
		_block(_cell(ix, z1), 1.15, 2.7)
	# Gate furniture in the opening, no solid blocker so the player can walk in.
	_castle("wall-doorway", _cell(-1, z1), PI * 0.5)
	_castle("gate", Vector3(-1.0, 0.0, -35.2), 0.0)
	_inst(_k("stairs-stone"), Vector3(-1.0, 0.0, -34.6), PI * 0.5, S)
	_castle("flag-banner-long", _cell(-1, -20), 0.0)
	_castle("flag", _cell(x0, z0), 0.2)
	_lantern(_cell(-1, -17))
	_lantern(_cell(0, -17))


func _tower(p: Vector3) -> void:
	_castle("tower-square-base", p, 0.0, 0.0)
	_castle("tower-square-mid", p, 0.0, 2.02)
	_castle("tower-square-roof", p, 0.0, 4.04)
	_block(p, 1.35, 6.0)


func _lot_y(x0: int, z0: int, w: int, d: int) -> Vector2:
	# x = max height (house sits on this), y = min height (foundation drop).
	var hi := 0.0
	var lo := 1.0e9
	for ix in range(x0, x0 + w):
		for iz in range(z0, z0 + d):
			var c := _cell(ix, iz)
			var h := Island.height_at(c.x, c.z)
			hi = maxf(hi, h)
			lo = minf(lo, h)
	if hi < 0.08:
		return Vector2(0.0, 0.0)
	return Vector2(hi, lo)


func _cottage(x0: int, z0: int, w: int, d: int, door_dir: int, wood: bool) -> void:
	# door_dir: 0 east, 1 north, 2 west, 3 south. Walls sit on cell edges.
	# One lot height so a sloped hill lot does not stair-step. Village lots stay y=0.
	house_count += 1
	var lot := _lot_y(x0, z0, w, d)
	var hy := lot.x
	var hlo := lot.y
	var wall_a := "wall-wood" if wood else "wall"
	var wall_w := "wall-wood-window-shutters" if wood else "wall-window-shutters"
	var wall_d := "wall-wood-door" if wood else "wall-door"
	var roof := "roof-high" if wood else "roof"
	var gable := "roof-high-gable" if wood else "roof-gable"
	var door_slot := z0 + int(d / 2) if (door_dir == 0 or door_dir == 2) else x0 + int(w / 2)
	# East face
	for iz in range(z0, z0 + d):
		var piece := wall_d if door_dir == 0 and iz == door_slot else (wall_w if (iz - z0) % 2 == 0 else wall_a)
		var pe := _cell(x0 + w - 1, iz)
		pe.y = hy
		_town(piece, pe, 0.0)
	# West face
	for iz in range(z0, z0 + d):
		var piece := wall_d if door_dir == 2 and iz == door_slot else (wall_w if (iz - z0) % 2 == 1 else wall_a)
		var pw := _cell(x0, iz)
		pw.y = hy
		_town(piece, pw, PI)
	# South face
	for ix in range(x0, x0 + w):
		var piece := wall_d if door_dir == 3 and ix == door_slot else (wall_w if (ix - x0) % 2 == 1 else wall_a)
		var ps := _cell(ix, z0 + d - 1)
		ps.y = hy
		_town(piece, ps, -PI * 0.5)
	# North face
	for ix in range(x0, x0 + w):
		var piece := wall_d if door_dir == 1 and ix == door_slot else (wall_w if (ix - x0) % 2 == 0 else wall_a)
		var pn := _cell(ix, z0)
		pn.y = hy
		_town(piece, pn, PI * 0.5)
	# Roofs — one tile per cell, ridge along Z when the door faces the east/west street.
	var roof_yaw := 0.0 if (door_dir == 0 or door_dir == 2) else PI * 0.5
	for ix in range(x0, x0 + w):
		for iz in range(z0, z0 + d):
			var is_end := false
			if door_dir == 0 or door_dir == 2:
				is_end = iz == z0 or iz == z0 + d - 1
			else:
				is_end = ix == x0 or ix == x0 + w - 1
			var p := _cell(ix, iz)
			_town(gable if is_end else roof, Vector3(p.x, hy + 2.0, p.z), roof_yaw)
	var ch := _cell(x0 + w - 1, z0)
	_town("chimney", Vector3(ch.x, hy + 2.50, ch.z), roof_yaw)
	var drop := hy - hlo
	var pad := 0.08 if drop < 0.12 else drop + 0.18
	var origin := Vector3((float(x0) + float(w) * 0.5) * G, hy + 0.05, (float(z0) + float(d) * 0.5) * G)
	if drop >= 0.12:
		origin.y = hy - pad * 0.5 + 0.04
	var floor := BoxMesh.new()
	floor.size = Vector3(float(w) * G - 0.18, pad, float(d) * G - 0.18)
	Mats.mesh(self, floor, Mats.textured(Mats.dirt_tex(), Color(0.86, 0.76, 0.58)), origin)
	_block(Vector3(origin.x, hy, origin.z), maxf(float(w), float(d)) * G * 0.48, 3.6)


func _build_cottages() -> void:
	# Eight 2x2 cottages on lots facing the main street. Doors toward the road.
	# East bank, door west (2).
	_cottage(3, -8, 2, 2, 2, false)
	_cottage(3, -4, 2, 2, 2, true)
	_cottage(3, -13, 2, 2, 2, true)
	_cottage(3, -16, 2, 2, 2, false)
	# West bank, door east (0).
	_cottage(-6, -8, 2, 2, 0, true)
	_cottage(-6, -4, 2, 2, 0, false)
	_cottage(-6, -13, 2, 2, 0, false)
	_cottage(-6, -16, 2, 2, 0, true)


func _fence_edge(ix: int, iz: int, facing: int, gate: bool) -> void:
	var yaws: Array[float] = [0.0, PI * 0.5, PI, -PI * 0.5]
	_town("fence-gate" if gate else "fence", _cell(ix, iz), yaws[facing])


func _lot(x0: int, z0: int, w: int, d: int, gate_dir: int) -> void:
	var gx := x0 + int(w / 2)
	var gz := z0 + int(d / 2)
	for iz in range(z0, z0 + d):
		_fence_edge(x0 + w - 1, iz, 0, gate_dir == 0 and iz == gz)
		_fence_edge(x0, iz, 2, gate_dir == 2 and iz == gz)
	for ix in range(x0, x0 + w):
		_fence_edge(ix, z0 + d - 1, 3, gate_dir == 3 and ix == gx)
		_fence_edge(ix, z0, 1, gate_dir == 1 and ix == gx)


func _build_fences() -> void:
	# Lot is cottage + 1 cell toward the street and 1 cell back. Gate on the street line.
	_lot(2, -9, 4, 3, 2)
	_lot(2, -5, 4, 3, 2)
	_lot(2, -14, 4, 3, 2)
	_lot(2, -17, 4, 3, 2)
	_lot(-7, -9, 4, 3, 0)
	_lot(-7, -5, 4, 3, 0)
	_lot(-7, -14, 4, 3, 0)
	_lot(-7, -17, 4, 3, 0)
	# Hedges one cell behind the back fence (not on the same tile).
	for iz in [-8, -7, -4, -3, -13, -12, -16, -15]:
		_town("hedge", _cell(6, iz), 0.0)
		_town("hedge", _cell(-8, iz), PI)


func _build_props() -> void:
	# Windmill on the east spur, on-grid.
	_castle("tower-square", _cell(9, -10), 0.0)
	_inst(_k("windmill"), Vector3(19.0, 4.15, -19.0), 0.0, 1.0)
	_block(_cell(9, -10), 1.5, 4.6)
	_inst(_k("watermill"), Vector3(21.0, 0.95, -21.0), 0.0, 1.0)
	_block(Vector3(21.0, 0.0, -21.0), 1.3, 2.4)
	_lantern(_cell(-1, -3))
	_lantern(_cell(0, -8))
	_lantern(_cell(-1, -16))
	# KayKit barrels on the village road shoulder — no new forest.
	_inst("res://assets/kaykit_dungeon/barrel_small.gltf.glb", Vector3(2.55, 0.0, -10.35), 0.35, 1.05, true)
	_inst("res://assets/kaykit_dungeon/barrel_large.gltf.glb", Vector3(-4.35, 0.0, -14.15), -0.4, 1.0, true)
	_block(Vector3(2.55, 0.0, -10.35), 0.42, 0.9)
	_block(Vector3(-4.35, 0.0, -14.15), 0.48, 1.05)


func _build_decor() -> void:
	# Trees on lot backs and road ends — never in the street.
	var pines := [
		[6, -8], [6, -4], [6, -13], [6, -16],
		[-8, -8], [-8, -4], [-8, -13], [-8, -16],
		[6, -11], [-8, -11],
		[-4, -23], [2, -23],
	]
	# Mix oak / pine / birch. Native AABB is already 5–10 m; scale to ~8–10 m.
	var kinds := [
		"tree_oak_a", "tree_pine_a", "tree_birch_a", "tree_oak_c",
		"tree_pine_b", "tree_oak_b", "tree_birch_b", "tree_pine_c",
		"tree_oak_d", "tree_oak_a", "tree_pine_a", "tree_birch_a",
	]
	var scales := [1.55, 1.20, 1.05, 1.50, 1.15, 1.60, 0.95, 0.95, 1.40, 1.55, 1.20, 1.05]
	for i in pines.size():
		var c: Array = pines[i]
		var kind: String = kinds[i % kinds.size()]
		var scl: float = float(scales[i % scales.size()])
		_inst(_qt(kind), _cell(int(c[0]), int(c[1])), float(i) * 0.4, scl, false, true)
	var rocks := [[8, -3], [-9, -3], [8, 4], [-10, 6], [4, 10]]
	for i in rocks.size():
		var c: Array = rocks[i]
		var p := _cell(int(c[0]), int(c[1]))
		_inst(_n("rock_largeA" if i % 2 == 0 else "rock_tallA"), p, float(i) * 0.5, 2.4, true)
		_block(p, 0.9, 1.2)
	_inst(_n("plant_bushLarge"), _cell(5, -11), 0.0, 2.0, true)
	_inst(_n("plant_bush"), _cell(-7, -11), 0.2, 2.0, true)
	_inst(_n("flower_yellowA"), _cell(2, -9), 0.0, 2.2, true)
	_inst(_n("flower_redA"), _cell(-3, -9), 0.0, 2.2, true)
	_inst(_n("flower_purpleA"), _cell(2, -14), 0.0, 2.2, true)
	# Woods rim — decor only, outside the choppable grid.
	var rim := [[24, 18], [25, 12], [23, 20], [18, 20], [26, 8], [20, 19], [27, 15]]
	var rim_kinds := ["tree_pine_a", "tree_oak_d", "tree_pine_c", "tree_birch_a", "tree_pine_b", "tree_oak_c", "tree_pine_a"]
	var rim_scl := [1.25, 1.45, 1.00, 1.10, 1.18, 1.48, 1.22]
	for i in rim.size():
		var c: Array = rim[i]
		var rp := _cell(int(c[0]), int(c[1]))
		rp.y = Island.height_at(rp.x, rp.z)
		_inst(_qt(rim_kinds[i]), rp, float(i) * 0.55, float(rim_scl[i]), false, true)


func _build_altar_ring() -> void:
	# Stone path ring around the dirt circle. Gaps on the four roads.
	_inst(_n("path_stoneCircle"), Vector3(0.0, 0.02, 0.0), 0.0, 3.4, true)
	var angs := [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]
	for i in 4:
		var a: float = angs[i]
		var p := Vector3(cos(a) * 6.3, 0.0, sin(a) * 6.3)
		_inst(_k("pillar-stone"), p, a, 1.35)
		_block(p, 0.42, 1.7)
	for i in 12:
		var a := float(i) * TAU / 12.0 + 0.12
		if absf(cos(a)) > 0.82 or absf(sin(a)) > 0.82:
			continue
		_inst(_n("path_stone"), Vector3(cos(a) * 6.15, 0.02, sin(a) * 6.15), a, 2.0, true)
	_lantern(Vector3(5.2, 0.0, 5.2))
	_lantern(Vector3(-5.2, 0.0, 5.2))


func _gnd(x: float, z: float) -> Vector3:
	return Vector3(x, Island.height_at(x, z), z)


func _cell_h(ix: int, iz: int) -> Vector3:
	var p := _cell(ix, iz)
	p.y = Island.height_at(p.x, p.z)
	return p


func _build_woods_camp() -> void:
	# Small lumber landing where the east road enters the forest.
	_inst(_n("stump_round"), _gnd(31.2, 15.4), 0.35, 2.5, true)
	_inst(_n("log"), _gnd(33.6, 16.8), 0.9, 2.3, true)
	_inst(_n("log"), _gnd(29.4, 17.2), -0.4, 2.1, true)
	_inst(_q("Prop_Crate"), _gnd(30.4, 13.6), 0.5, 1.0)
	_inst(_q("Prop_Crate"), _gnd(31.1, 13.0), 1.2, 1.0)
	_lantern(_gnd(31.0, 13.0))
	_lantern(_gnd(33.0, 7.0))
	_block(Vector3(30.8, 0.0, 13.3), 0.9, 1.2)


func _build_shore() -> void:
	# West peninsula — pier into the north harbor bay (not a tangent on a disc).
	var plank := Mats.solid(Color(0.46, 0.32, 0.18))
	var origin := Vector3(-50.0, 0.0, 3.2)
	var step := Vector3(-0.28, 0.0, 2.12)
	var side := Vector3(1.12, 0.0, 0.15)
	for i in 6:
		var p: Vector3 = origin + step * float(i)
		var slab := BoxMesh.new()
		slab.size = Vector3(2.20, 0.10, 2.05)
		var mi := Mats.mesh(self, slab, plank, Vector3(p.x, 0.07, p.z))
		mi.rotation.y = 0.13
		_inst(_k("fence"), p + side, 0.13, 1.0)
		_inst(_k("fence"), p - side, 0.13 + PI, 1.0)
	_inst(_k("stairs-wood"), Vector3(-48.4, 0.0, 2.4), 0.13 + PI * 0.5, S)
	_inst(_k("watermill"), Vector3(-47.6, 0.95, -4.6), 0.15, 1.15)
	_block(Vector3(-47.6, 0.0, -4.6), 1.4, 2.6)
	_inst(_q("Prop_Crate"), Vector3(-51.4, 0.0, 1.05), 0.25, 1.0)
	_inst(_q("Prop_Crate"), Vector3(-52.2, 0.0, 1.7), 1.15, 1.0)
	_inst(_q("Prop_Crate"), Vector3(-51.6, 0.0, 2.85), 0.7, 1.0)
	_inst(_k("cart"), Vector3(-45.8, 0.0, 4.4), -0.45, 1.0)
	_inst(_k("stall"), Vector3(-44.6, 0.0, -0.9), PI * 0.5)
	_inst(_n("log"), Vector3(-54.2, 0.0, 4.4), 0.35, 2.2, true)
	_inst(_n("log"), Vector3(-56.4, 0.0, -0.5), -0.55, 2.2, true)
	_lantern(Vector3(-47.6, 0.0, 0.5))
	_lantern(Vector3(-47.6, 0.0, 3.5))
	_lantern(Vector3(-52.8, 0.0, 12.4))
	_dress_pirate_dock()
	_block(Vector3(-44.6, 0.0, -0.9), 1.15, 1.6)
	_block(Vector3(-45.8, 0.0, 4.4), 1.2, 1.4)


func _dress_pirate_dock() -> void:
	# Tight Kenney still-life on the existing west spit. No new land.
	var n := 0
	n += 1 if _pirate_inst("palm-straight", _gnd(-58.6, 3.8), 0.35, 1.08) else 0
	n += 1 if _pirate_inst("palm-bend", _gnd(-61.2, 8.4), -0.55, 1.05) else 0
	n += 1 if _pirate_inst("cannon", _gnd(-55.2, 8.8), 0.18, 1.0) else 0
	n += 1 if _pirate_inst("barrel", _gnd(-53.6, 6.4), 0.40, 1.0) else 0
	n += 1 if _pirate_inst("flag", _gnd(-56.8, 5.2), -0.25, 1.0) else 0
	n += 1 if _pirate_inst("rocks-sand-a", _gnd(-57.2, 12.4), 0.60, 1.0) else 0
	n += 1 if _pirate_inst("rocks-sand-a", _gnd(-62.0, -3.0), -0.35, 1.0) else 0
	var plank_x := -52.4
	var plank_z := 13.9
	var plank_y := maxf(Island.height_at(plank_x, plank_z), 0.05)
	n += 1 if _pirate_inst("platform-planks", Vector3(plank_x, plank_y, plank_z), 0.12, 1.15) else 0
	var bx := -54.6
	var bz := 17.85
	var by := -0.42
	if Island.contains_xz(bx, bz):
		by = Island.height_at(bx, bz) - 0.22
	n += 1 if _pirate_inst("boat-row-small", Vector3(bx, by, bz), 1.12, 1.0) else 0
	dock_anchor = Vector3(-55.4, Island.height_at(-55.4, 9.0) + 0.45, 9.0)
	_block(_gnd(-58.6, 3.8), 0.55, 2.6)
	_block(_gnd(-61.2, 8.4), 0.55, 2.4)
	_block(_gnd(-55.2, 8.8), 0.70, 1.15)
	_block(_gnd(-56.8, 5.2), 0.28, 2.2)
	_block(_gnd(-53.6, 6.4), 0.38, 0.85)
	print("pirate_dock n=", n, " anchor=", dock_anchor, " boat=(", snappedf(bx, 0.01), ",", snappedf(by, 0.01), ",", snappedf(bz, 0.01), ") land_boat=", Island.contains_xz(bx, bz))


func _pirate_inst(name: String, pos: Vector3, yaw: float = 0.0, scl: float = 1.0) -> Node3D:
	var node := _inst(_p(name), pos, yaw, scl)
	if node:
		_paint_pirate(node)
	return node


func _paint_pirate(root: Node) -> void:
	var tex: Texture2D = null
	if ResourceLoader.exists(PIRATE_COLORMAP):
		tex = load(PIRATE_COLORMAP) as Texture2D
	if tex == null:
		return
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		if nd is MeshInstance3D:
			var mi := nd as MeshInstance3D
			var msh := mi.mesh
			if msh:
				for i in msh.get_surface_count():
					var src := mi.get_active_material(i)
					var d: StandardMaterial3D
					if src is StandardMaterial3D:
						d = src.duplicate()
					else:
						d = StandardMaterial3D.new()
					d.albedo_texture = tex
					d.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
					d.metallic = 0.0
					d.roughness = 0.86
					d.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
					mi.set_surface_override_material(i, d)
		for c in nd.get_children():
			stack.append(c)


func _boat(pos: Vector3, yaw: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	add_child(n)
	var wood := Mats.solid(Color(0.40, 0.26, 0.14))
	var dark := Mats.solid(Color(0.28, 0.18, 0.10))
	var hull := BoxMesh.new()
	hull.size = Vector3(4.2, 0.42, 1.55)
	Mats.mesh(n, hull, wood, Vector3(0.0, -0.10, 0.0))
	var bow := BoxMesh.new()
	bow.size = Vector3(1.05, 0.34, 1.05)
	var bmi := Mats.mesh(n, bow, wood, Vector3(2.15, -0.08, 0.0))
	bmi.rotation.y = PI * 0.25
	var gunwale := BoxMesh.new()
	gunwale.size = Vector3(3.9, 0.12, 1.65)
	Mats.mesh(n, gunwale, dark, Vector3(-0.05, 0.08, 0.0))
	var mast := CylinderMesh.new()
	mast.top_radius = 0.035
	mast.bottom_radius = 0.05
	mast.height = 2.55
	mast.radial_segments = 6
	Mats.mesh(n, mast, dark, Vector3(0.10, 1.25, 0.0))
	var sail := BoxMesh.new()
	sail.size = Vector3(0.06, 1.65, 1.25)
	Mats.mesh(n, sail, Mats.solid(Color(0.84, 0.80, 0.70)), Vector3(0.20, 1.55, 0.16))

func _cjk_font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Noto Sans CJK SC", "Noto Sans CJK JP", "Noto Sans"])
	f.font_weight = 700
	return f


func _build_signs() -> void:
	# Four inward-facing posts just off the cross roads so a new player can read destinations from the altar.
	var font := _cjk_font()
	var specs := [
		{"pos": Vector3(3.55, 0.0, -7.15), "look": Vector3(0.0, 0.0, 0.0), "title": "南", "sub": "村子/城寨"},
		{"pos": Vector3(7.15, 0.0, 3.55), "look": Vector3(0.0, 0.0, 0.0), "title": "东", "sub": "伐木林"},
		{"pos": Vector3(-7.15, 0.0, 3.55), "look": Vector3(0.0, 0.0, 0.0), "title": "西", "sub": "码头"},
		{"pos": Vector3(3.55, 0.0, 7.15), "look": Vector3(0.0, 0.0, 0.0), "title": "北", "sub": "哨所"},
	]
	for s in specs:
		_signpost(s["pos"], s["look"], s["title"], s["sub"], font)
	# Kenney banners as extra wayfinding color at south / east
	_inst(_k("banner-red"), Vector3(4.6, 0.0, -7.6), 0.15, 1.15)
	_inst(_k("banner-green"), Vector3(7.6, 0.0, 4.6), PI * 0.5 + 0.1, 1.15)
	_inst(_c("flag-banner-long"), Vector3(4.4, 0.0, 7.5), 0.2, S)
	print("signs S=村子/城寨 E=伐木林 W=码头 N=哨所")


func _signpost(pos: Vector3, look: Vector3, title: String, sub: String, font: Font) -> void:
	var root := Node3D.new()
	root.name = "Sign_" + title
	root.position = pos
	var to := Vector3(look.x - pos.x, 0.0, look.z - pos.z)
	if to.length() > 0.05:
		root.rotation.y = atan2(to.x, to.z)
	add_child(root)
	var wood := Mats.solid(Color(0.42, 0.28, 0.14))
	var dark := Mats.solid(Color(0.28, 0.18, 0.08))
	var board_col := Mats.solid(Color(0.72, 0.58, 0.34))
	var post := CylinderMesh.new()
	post.top_radius = 0.055
	post.bottom_radius = 0.075
	post.height = 2.15
	post.radial_segments = 8
	Mats.mesh(root, post, dark, Vector3(0.0, 1.08, 0.0))
	var board := BoxMesh.new()
	board.size = Vector3(1.28, 0.92, 0.07)
	Mats.mesh(root, board, board_col, Vector3(0.0, 1.78, 0.06))
	var frame := BoxMesh.new()
	frame.size = Vector3(1.36, 0.08, 0.09)
	Mats.mesh(root, frame, wood, Vector3(0.0, 2.26, 0.06))
	Mats.mesh(root, frame, wood, Vector3(0.0, 1.30, 0.06))
	var cap := BoxMesh.new()
	cap.size = Vector3(0.22, 0.10, 0.22)
	Mats.mesh(root, cap, wood, Vector3(0.0, 2.20, 0.0))
	# arrow pointing away from the altar (down the road)
	var arrow := PrismMesh.new()
	arrow.size = Vector3(0.22, 0.14, 0.05)
	var ami := Mats.mesh(root, arrow, dark, Vector3(0.0, 2.08, 0.11))
	ami.rotation.z = PI
	_sign_label(root, title + "\n" + sub, font, Vector3(0.0, 1.74, 0.11), 0.0)
	_sign_label(root, title + "\n" + sub, font, Vector3(0.0, 1.74, 0.01), PI)
	_block(pos, 0.38, 2.1)


func _sign_label(parent: Node3D, text: String, font: Font, pos: Vector3, yaw: float) -> void:
	var lab := Label3D.new()
	lab.text = text
	lab.font = font
	lab.font_size = 76
	lab.pixel_size = 0.0085
	lab.position = pos
	lab.rotation.y = yaw
	lab.modulate = Color(0.16, 0.08, 0.04)
	lab.outline_size = 14
	lab.outline_modulate = Color(0.98, 0.92, 0.74)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.shaded = false
	lab.double_sided = false
	lab.render_priority = 2
	parent.add_child(lab)


func _outpost_tower(p: Vector3, windows: bool = false) -> void:
	_castle("tower-square-base", p, 0.0, p.y)
	_castle("tower-square-mid-windows" if windows else "tower-square-mid", p, 0.0, p.y + 2.02)
	_castle("tower-square-roof", p, 0.0, p.y + 4.04)
	_block(p, 1.35, 6.0)


func _wall_h(name: String, ix: int, iz: int, yaw: float, block: bool = true) -> void:
	var p := _cell_h(ix, iz)
	_castle(name, p, yaw, p.y)
	if block:
		_block(p, 1.15, 2.7)


func _build_outpost() -> void:
	# Intact watch post on the rocky rise. Landmark only — not a second 城寨.
	var hy0 := Island.height_at(0.0, 30.0)
	print("outpost hill height_at(0,30)=", snappedf(hy0, 0.01))

	# 4-cell-wide post. North lookout towers with roofs, south gate on the road.
	var tw := _cell_h(-2, 16)
	var te := _cell_h(1, 16)
	_outpost_tower(tw, false)
	_outpost_tower(te, true)
	_castle("flag", te, 0.2, te.y + 5.6)

	# North curtain between the towers (E–W, yaw 0).
	_wall_h("wall", -1, 16, 0.0)
	_wall_h("wall", 0, 16, 0.0)
	# Side returns
	_wall_h("wall", -2, 15, PI * 0.5)
	_wall_h("wall", 1, 15, PI * 0.5)
	# South gate on the road (ix=-1). Leave ix=0 open so the 4 m road walks in.
	_wall_h("wall-doorway", -1, 14, PI * 0.5, false)
	_wall_h("wall", 1, 14, 0.0)

	# Two complete cottages, doors toward the courtyard / road.
	_cottage(-5, 13, 2, 2, 0, true)
	_cottage(3, 13, 2, 2, 2, false)

	# Campfire + banner — the outpost has a pulse.
	_campfire(_gnd(0.15, 30.1))
	_inst(_c("flag-banner-long"), _cell_h(-2, 14), 0.25, S)
	_lantern(_cell_h(-1, 13))
	_inst(_q("Prop_Crate"), _gnd(-2.2, 28.6), 0.4, 1.0)
	_inst(_q("Prop_Crate"), _gnd(-1.5, 28.0), 1.1, 1.0)
	_inst(_n("stump_round"), _gnd(3.4, 26.8), 0.4, 2.3, true)
	_inst(_n("rock_largeA"), _gnd(-6.4, 34.8), 0.3, 2.2, true)
	_inst(_n("rock_tallA"), _gnd(6.8, 34.2), -0.4, 2.1, true)
	_block(_gnd(-6.4, 34.8), 0.85, 1.1)
	_block(_gnd(6.8, 34.2), 0.8, 1.1)
	print("outpost at (0,30) y=", snappedf(hy0, 0.01), " cottages=2 walls=standing towers=roofed campfire=yes capturable=no")


func _campfire(pos: Vector3) -> void:
	var ring := [
		Vector3(0.42, 0.08, 0.12), Vector3(-0.38, 0.08, 0.18),
		Vector3(0.08, 0.08, -0.40), Vector3(-0.12, 0.08, 0.42),
		Vector3(0.34, 0.08, -0.28), Vector3(-0.36, 0.08, -0.22),
	]
	var stone := Mats.solid(Color(0.38, 0.36, 0.34))
	for o in ring:
		var rk := SphereMesh.new()
		rk.radius = 0.11
		rk.height = 0.16
		Mats.mesh(self, rk, stone, pos + o, Vector3(1.15, 0.7, 0.95))
	var glow := SphereMesh.new()
	glow.radius = 0.22
	glow.height = 0.28
	Mats.mesh(self, glow, Mats.solid(Color(1.0, 0.45, 0.12), true, Color(1.0, 0.4, 0.08), 2.4), pos + Vector3(0.0, 0.22, 0.0))
	var flame := SphereMesh.new()
	flame.radius = 0.12
	flame.height = 0.28
	Mats.mesh(self, flame, Mats.solid(Color(1.0, 0.78, 0.28), true, Color(1.0, 0.55, 0.1), 2.8), pos + Vector3(0.02, 0.42, 0.0), Vector3(0.7, 1.35, 0.7))
	var ol := OmniLight3D.new()
	ol.position = pos + Vector3(0.0, 1.15, 0.0)
	ol.light_color = Color(1.0, 0.55, 0.22)
	ol.light_energy = 1.55
	ol.omni_range = 7.5
	ol.shadow_enabled = false
	add_child(ol)
	_inst(_n("log"), pos + Vector3(0.55, 0.0, 0.35), 0.4, 1.4, true)
	_inst(_n("log"), pos + Vector3(-0.50, 0.0, -0.15), -0.7, 1.35, true)
