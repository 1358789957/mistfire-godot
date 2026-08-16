extends RefCounted
class_name Island
## Irregular mistfire coastline. Not a disc. Point-in-polygon clamp.

const BEACH_IN := 2.55
const CLIFF_H := 0.70
const GRID := 5.5
const EDGE_STEP := 4.6

static var _poly: PackedVector2Array = PackedVector2Array()
static var _centroid := Vector2.ZERO
static var _ready := false


static func ensure() -> void:
	if _ready and _poly.size() > 8:
		return
	_ready = true
	# Clockwise from the northern rocky tip. Bays bite IN.
	# S lobe = village/城寨, E bulge = 伐木林, W spit = 码头, N headland = 废墟.
	var raw: Array[Vector2] = [
		Vector2(4, 58), Vector2(16, 52), Vector2(24, 44), Vector2(28, 36),
		Vector2(40, 50), Vector2(56, 62), Vector2(74, 74), Vector2(86, 64),
		Vector2(94, 80), Vector2(112, 76), Vector2(122, 62), Vector2(136, 70),
		Vector2(154, 64), Vector2(170, 54), Vector2(184, 42), Vector2(196, 30),
		Vector2(202, 16), Vector2(198, 4), Vector2(186, -6), Vector2(172, 8),
		Vector2(158, -14), Vector2(144, -8), Vector2(130, -18), Vector2(116, -10),
		Vector2(102, 2), Vector2(88, -8), Vector2(74, 0), Vector2(60, -8),
		Vector2(50, -12), Vector2(44, -14), Vector2(40, -12), Vector2(36, -16),
		Vector2(30, -22), Vector2(26, -32), Vector2(20, -44), Vector2(12, -54),
		Vector2(2, -60), Vector2(-10, -58), Vector2(-18, -50), Vector2(-22, -42),
		Vector2(-20, -36), Vector2(-26, -34), Vector2(-16, -28), Vector2(-18, -22),
		Vector2(-28, -20), Vector2(-38, -14), Vector2(-50, -10), Vector2(-60, -6),
		Vector2(-70, -1), Vector2(-74, 4), Vector2(-70, 10), Vector2(-60, 14),
		Vector2(-50, 14), Vector2(-42, 16), Vector2(-34, 20), Vector2(-26, 10),
		Vector2(-22, 8), Vector2(-18, 16), Vector2(-16, 26), Vector2(-12, 38),
		Vector2(-6, 50),
	]
	_poly = PackedVector2Array(raw)
	_centroid = Vector2.ZERO
	for p in _poly:
		_centroid += p
	_centroid /= float(_poly.size())
	_trail = PackedVector2Array([
		Vector2(32, 16), Vector2(42, 18), Vector2(54, 20), Vector2(66, 24),
		Vector2(78, 22), Vector2(90, 26), Vector2(100, 28), Vector2(108, 28),
		Vector2(116, 28), Vector2(128, 32), Vector2(140, 36), Vector2(154, 40),
	])
	_ridge = PackedVector2Array([
		Vector2(48, 42), Vector2(82, 52), Vector2(120, 56), Vector2(158, 46),
	])
	_creek = PackedVector2Array([
		Vector2(94, 12), Vector2(102, 6), Vector2(110, 0),
		Vector2(118, -6), Vector2(126, -12), Vector2(134, -16),
	])


static func poly() -> PackedVector2Array:
	ensure()
	return _poly


static func centroid() -> Vector2:
	ensure()
	return _centroid


static func contains_xz(x: float, z: float) -> bool:
	ensure()
	var n := _poly.size()
	var inside := false
	var j := n - 1
	for i in n:
		var zi := _poly[i].y
		var zj := _poly[j].y
		if (zi > z) != (zj > z):
			var xi := _poly[i].x
			var xj := _poly[j].x
			var xint := (xj - xi) * (z - zi) / (zj - zi + 0.0000001) + xi
			if x < xint:
				inside = not inside
		j = i
	return inside


static func contains_v(pos: Vector3, margin: float = 0.0) -> bool:
	if not contains_xz(pos.x, pos.z):
		return false
	if margin <= 0.0:
		return true
	return dist_to_coast(pos.x, pos.z) >= margin


static func dist_to_coast(x: float, z: float) -> float:
	ensure()
	var p := Vector2(x, z)
	var best := 1.0e9
	var n := _poly.size()
	for i in n:
		var a := _poly[i]
		var b := _poly[(i + 1) % n]
		var d := _dist_seg(p, a, b)
		if d < best:
			best = d
	return best


static func _dist_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := 0.0
	var den := ab.length_squared()
	if den > 0.0001:
		t = clampf((p - a).dot(ab) / den, 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func nearest_on_coast(x: float, z: float) -> Vector2:
	ensure()
	var p := Vector2(x, z)
	var best := p
	var best_d := 1.0e9
	var n := _poly.size()
	for i in n:
		var a := _poly[i]
		var b := _poly[(i + 1) % n]
		var ab := b - a
		var t := 0.0
		var den := ab.length_squared()
		if den > 0.0001:
			t = clampf((p - a).dot(ab) / den, 0.0, 1.0)
		var q := a + ab * t
		var d := p.distance_squared_to(q)
		if d < best_d:
			best_d = d
			best = q
	return best


static func _inward_at(p: Vector2) -> Vector2:
	ensure()
	var n := _poly.size()
	var best_i := 0
	var best_d := 1.0e9
	for i in n:
		var a := _poly[i]
		var b := _poly[(i + 1) % n]
		var ab := b - a
		var t := 0.0
		var den := ab.length_squared()
		if den > 0.0001:
			t = clampf((p - a).dot(ab) / den, 0.0, 1.0)
		var q := a + ab * t
		var d := p.distance_squared_to(q)
		if d < best_d:
			best_d = d
			best_i = i
	var a2 := _poly[best_i]
	var b2 := _poly[(best_i + 1) % n]
	var dir := (b2 - a2)
	if dir.length() < 0.0001:
		return (_centroid - p).normalized()
	# Clockwise poly: inward is right of the edge = (dz, -dx) wait
	# Edge (dx, dy) with dy=z. Rotate 90° clockwise: (dy, -dx).
	var inward := Vector2(dir.y, -dir.x).normalized()
	# Confirm it points toward centroid-ish / inside
	var test := p + inward * 0.8
	if not contains_xz(test.x, test.y):
		inward = -inward
	return inward


static func clamp_xz(x: float, z: float, margin: float = 1.25) -> Vector2:
	ensure()
	var p := Vector2(x, z)
	if contains_xz(x, z) and dist_to_coast(x, z) >= margin:
		return p
	var on := nearest_on_coast(x, z)
	var inward := _inward_at(on)
	var q := on + inward * margin
	if contains_xz(q.x, q.y) and dist_to_coast(q.x, q.y) >= margin * 0.55:
		return q
	# Walk toward a known interior (altar) until we are safely inside.
	var dest := Vector2.ZERO
	if not contains_xz(0.0, 0.0):
		dest = _centroid
	var lo := 0.0
	var hi := 1.0
	var origin := p
	for _k in 10:
		var mid := (lo + hi) * 0.5
		var t: Vector2 = origin.lerp(dest, mid)
		if contains_xz(t.x, t.y) and dist_to_coast(t.x, t.y) >= margin:
			hi = mid
		else:
			lo = mid
	return origin.lerp(dest, hi)


static var _trail: PackedVector2Array = PackedVector2Array()
static var _ridge: PackedVector2Array = PackedVector2Array()
static var _creek: PackedVector2Array = PackedVector2Array()


static func _poly_dist(p: Vector2, line: PackedVector2Array) -> float:
	var best := 1.0e9
	var n := line.size()
	if n == 0:
		return best
	if n == 1:
		return p.distance_to(line[0])
	for i in range(n - 1):
		var d := _dist_seg(p, line[i], line[i + 1])
		if d < best:
			best = d
	return best


static func trail_points() -> PackedVector2Array:
	ensure()
	return _trail


static func trail_dist(x: float, z: float) -> float:
	ensure()
	return _poly_dist(Vector2(x, z), _trail)


static func on_trail(x: float, z: float, pad: float = 2.25) -> bool:
	return trail_dist(x, z) < pad


# Forest plan — composed zones, not a Poisson dump.
const CLEAR_C := Vector2(108.0, 28.0)
const CLEAR_RX := 11.0
const CLEAR_RZ := 8.0
const SHRINE_C := Vector2(154.0, 40.0)
const HOLLOW_C := Vector2(96.0, 10.0)


static func clearing_norm(x: float, z: float) -> float:
	var dx := (x - CLEAR_C.x) / CLEAR_RX
	var dz := (z - CLEAR_C.y) / CLEAR_RZ
	return sqrt(dx * dx + dz * dz)


static func in_clearing(x: float, z: float, rim: float = 1.0) -> bool:
	return clearing_norm(x, z) < rim


static func forest_zone(x: float, z: float) -> String:
	ensure()
	if not contains_xz(x, z):
		return "sea"
	if jungle_weight(x, z) < 0.16:
		return "meadow"
	if clearing_norm(x, z) < 1.0:
		return "clearing"
	if on_trail(x, z, 2.15):
		return "trail"
	var rd := _poly_dist(Vector2(x, z), _ridge)
	if rd < 7.5:
		return "ridge"
	if Vector2(x - HOLLOW_C.x, z - HOLLOW_C.y).length() < 14.0 or creek_dist(x, z) < 5.5:
		return "hollow"
	# 林缘: meadow-facing west belt toward the altar.
	if x < 54.0 and z > -2.0 and z < 42.0:
		return "edge"
	if jungle_weight(x, z) < 0.52:
		return "edge"
	return "dense"


static func choppable_spots() -> Array:
	# ~20 on the 空地 rim. Skip / nudge off the E–W trail through the glade.
	ensure()
	var pts: Array = []
	var angs := [
		0.40, 0.70, 1.05, 1.40, 1.75, 2.10, 2.45, 2.80,
		3.55, 3.90, 4.25, 4.60, 4.95, 5.30, 5.65, 6.00,
		0.95, 2.25, 4.15, 5.45,
	]
	var rads := [
		1.02, 1.06, 1.00, 1.08, 1.04, 1.02, 1.10, 1.05,
		1.02, 1.08, 1.00, 1.06, 1.04, 1.02, 1.10, 1.05,
		1.18, 1.16, 1.18, 1.16,
	]
	for i in angs.size():
		var a: float = angs[i]
		var u: float = rads[i]
		var x := CLEAR_C.x + cos(a) * CLEAR_RX * u
		var z := CLEAR_C.y + sin(a) * CLEAR_RZ * u
		if on_trail(x, z, 3.15):
			z += 2.6 if z >= CLEAR_C.y else -2.6
		if on_trail(x, z, 2.75):
			continue
		if not contains_v(Vector3(x, 0.0, z), 2.8):
			continue
		pts.append(Vector3(x, height_at(x, z), z))
	return pts


static func creek_dist(x: float, z: float) -> float:
	ensure()
	return _poly_dist(Vector2(x, z), _creek)


static func ruins_weight(x: float, z: float) -> float:
	# North headland hill. Village mask already kills z<10.
	if z < 12.0 or absf(x) > 20.0:
		return 0.0
	var w := clampf(1.0 - absf(z - 32.0) / 20.0, 0.0, 1.0)
	w *= clampf(1.0 - absf(x) / 18.0, 0.0, 1.0)
	return w


static func jungle_weight(x: float, z: float) -> float:
	# Village / altar / keep stay meadow. Jungle ramps in east of the east road.
	if x < 16.0:
		return 0.0
	if z < -20.0 and x < 48.0:
		return 0.0
	var w := clampf((x - 18.0) / 16.0, 0.0, 1.0)
	if z < -6.0 and x < 40.0:
		w *= clampf((z + 20.0) / 14.0, 0.0, 1.0)
	return w


static func in_jungle(x: float, z: float) -> bool:
	return jungle_weight(x, z) > 0.55 and contains_xz(x, z)


static func _flat_mask(x: float, z: float) -> float:
	# 1 = force y~0 (buildings). Village lobe, altar disc, keep, near-town roads.
	var m := 0.0
	if Vector2(x, z).length() < 8.6:
		return 1.0
	if z < 10.0 and z > -52.0 and x > -24.0 and x < 17.0:
		m = 1.0
	if z < -32.0 and z > -48.0 and absf(x) < 12.0:
		m = 1.0
	# pier boards stay at water; dunes may rise around them
	if x > -55.0 and x < -46.0 and z > 1.0 and z < 16.8:
		m = maxf(m, 0.95)
	return m


static func _roll(x: float, z: float) -> float:
	return (
		sin(x * 0.105) * cos(z * 0.088) * 0.50
		+ sin(x * 0.221 + z * 0.164) * 0.32
		+ sin(x * 0.067 - z * 0.129 + 1.3) * 0.28
		+ sin((x + z) * 0.041) * 0.18
	)


static func height_at(x: float, z: float) -> float:
	ensure()
	var flat := _flat_mask(x, z)
	var jw := jungle_weight(x, z)
	var h := 0.02
	# 北 废墟 — rocky rise ~2–3.5 m. Ramp from the north road stays walkable.
	var rw := ruins_weight(x, z)
	if rw > 0.001:
		var rise := rw * rw * (3.0 - 2.0 * rw)
		var k1 := clampf(1.0 - Vector2(x - 6.4, z - 38.0).length() / 6.8, 0.0, 1.0)
		var k2 := clampf(1.0 - Vector2(x + 7.6, z - 31.5).length() / 5.8, 0.0, 1.0)
		h += 3.20 * rise + 0.55 * k1 * k1 + 0.48 * k2 * k2
	# 西 码头 — gentle spit / dunes. Beach still drops via coast term.
	if x < -26.0 and x > -74.0 and z > -18.0 and z < 24.0:
		var inland := clampf((-x - 26.0) / 16.0, 0.0, 1.0)
		inland *= clampf(1.0 - maxf(0.0, -x - 54.0) / 14.0, 0.0, 1.0)
		var band := clampf(1.0 - absf(z - 2.0) / 16.0, 0.0, 1.0)
		var d1 := clampf(1.0 - Vector2(x + 36.0, z - 9.0).length() / 7.4, 0.0, 1.0)
		var d2 := clampf(1.0 - Vector2(x + 40.0, z + 7.2).length() / 6.4, 0.0, 1.0)
		h += 0.32 * inland * band + 1.05 * d1 * d1 + 0.88 * d2 * d2
	if jw > 0.001:
		var td := trail_dist(x, z)
		var rd := _poly_dist(Vector2(x, z), _ridge)
		var valley := clampf(1.0 - td / 7.2, 0.0, 1.0)
		valley *= valley
		var ridge := clampf(1.0 - rd / 13.5, 0.0, 1.0)
		ridge *= ridge
		# one readable hollow south of the mid-trail
		var hd := Vector2(x - 96.0, z - 10.0).length()
		var hollow := clampf(1.0 - hd / 15.5, 0.0, 1.0)
		hollow *= hollow
		var roll := 0.50 + 0.50 * clampf(_roll(x, z), -1.2, 1.2) / 1.2
		var jh := 1.20 + roll * 1.45
		jh += ridge * 2.05
		jh -= hollow * 1.55
		# trail follows the valley floor
		jh = lerpf(jh, 0.38 + roll * 0.22, valley * 0.92)
		jh = clampf(jh, 0.10, 4.05)
		h = lerpf(h, jh, jw)
	# shallow creek channel (visual + slight dip)
	var cd := creek_dist(x, z)
	if cd < 2.4:
		var dip := (1.0 - cd / 2.4)
		h -= 0.38 * dip * dip
	h *= (1.0 - flat)
	var dc := dist_to_coast(x, z)
	if dc < 4.4:
		var drop := 1.0 - dc / 4.4
		h -= (h + 0.14) * drop * 0.88
		if dc < 1.7:
			h = minf(h, 0.035)
	return h


const FOOT_OFF := 0.05


static func foot_y(x: float, z: float, extra: float = FOOT_OFF) -> float:
	# KayKit origin is the soles. Use the highest sample under the stance so
	# the uphill boot is not buried; extra keeps leather off the triangles.
	var h := height_at(x, z)
	h = maxf(h, height_at(x + 0.26, z))
	h = maxf(h, height_at(x - 0.26, z))
	h = maxf(h, height_at(x, z + 0.26))
	h = maxf(h, height_at(x, z - 0.26))
	return h + extra


static func is_raised(x: float, z: float) -> bool:
	# Village / altar / keep stay y=0. Ruins hill, shore dunes, jungle do not.
	return height_at(x, z) > 0.06


static func snap_feet(body: Node3D, extra: float = FOOT_OFF) -> void:
	# Pin KayKit soles to the height field on ANY raised terrain (ruins,
	# shore dunes, jungle). ConcavePolygonShape3D + the village y=0 box
	# let CharacterBody3D fall through and clip waist-deep.
	if body == null:
		return
	var x := body.global_position.x
	var z := body.global_position.z
	if not is_raised(x, z):
		return
	var fy := foot_y(x, z, extra)
	body.global_position = Vector3(x, fy, z)
	if body is CharacterBody3D:
		var cb := body as CharacterBody3D
		if cb.velocity.y < 0.0:
			cb.velocity.y = 0.0


static func beach_width(p: Vector2) -> float:
	if p.x < -40.0:
		return 3.6
	if p.y > 40.0:
		return 1.45
	if p.y < -48.0:
		return 2.1
	return 2.55


static func _densify() -> PackedVector2Array:
	ensure()
	var out := PackedVector2Array()
	var n := _poly.size()
	for i in n:
		var a := _poly[i]
		var b := _poly[(i + 1) % n]
		out.append(a)
		var d := a.distance_to(b)
		var steps := maxi(1, int(ceil(d / EDGE_STEP)))
		for s in range(1, steps):
			out.append(a.lerp(b, float(s) / float(steps)))
	return out


static func _edge_inward(a: Vector2, b: Vector2) -> Vector2:
	var dir := b - a
	if dir.length() < 0.0001:
		return Vector2.ZERO
	var inward := Vector2(dir.y, -dir.x).normalized()
	var mid := (a + b) * 0.5
	if not contains_xz(mid.x + inward.x * 0.8, mid.y + inward.y * 0.8):
		inward = -inward
	return inward


static func _emit_tri_raw(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uv_s: float, nrm: Vector3) -> void:
	for v in [a, b, c]:
		st.set_normal(nrm)
		st.set_color(Color.WHITE)
		st.set_uv(Vector2(v.x / uv_s, v.z / uv_s))
		st.add_vertex(v)


static func _emit_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uv_s: float, nrm: Vector3 = Vector3.UP) -> void:
	# Match Mats.ground_disc: color + UV + explicit normal. No generate_normals
	# (that call was wiping the ArrayMesh on gl_compatibility).
	var cr := (b - a).cross(c - a)
	if cr.length_squared() < 0.0000001:
		return
	if nrm.y > 0.5 and cr.y < 0.0:
		var tmp := b
		b = c
		c = tmp
	_emit_tri_raw(st, a, b, c, uv_s, nrm)


static func _emit_tri_both(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uv_s: float, nrm: Vector3 = Vector3.UP) -> void:
	var cr := (b - a).cross(c - a)
	if cr.length_squared() < 0.0000001:
		return
	_emit_tri_raw(st, a, b, c, uv_s, nrm)
	_emit_tri_raw(st, a, c, b, uv_s, nrm)


static func _finish_mesh(st: SurfaceTool) -> ArrayMesh:
	var mesh := st.commit()
	# llvmpipe + gl_compatibility has culled runtime ArrayMeshes with a bad AABB.
	mesh.custom_aabb = AABB(Vector3(-100.0, -6.0, -90.0), Vector3(330.0, 16.0, 200.0))
	return mesh


static func grass_mesh() -> ArrayMesh:
	# Kept for callers; real land is the height grid in stamp().
	return _terrain_surface("meadow")


static func _terrain_surface(kind: String) -> ArrayMesh:
	var pack := _sample_height_grid()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var used := _emit_grid_kind(st, pack, kind)
	var mesh := _finish_mesh(st)
	print("island terrain ", kind, " tris=", used, " aabb=", mesh.get_aabb())
	return mesh


static func _sample_height_grid() -> Dictionary:
	ensure()
	var xmin := -80.0
	var xmax := 208.0
	var zmin := -68.0
	var zmax := 86.0
	var step := 2.0
	var nx := int(round((xmax - xmin) / step)) + 1
	var nz := int(round((zmax - zmin) / step)) + 1
	var H: Array = []
	var IN: Array = []
	var hmin := 99.0
	var hmax := -99.0
	for iz in nz:
		var row_h: Array = []
		var row_in: Array = []
		var z := zmin + float(iz) * step
		for ix in nx:
			var x := xmin + float(ix) * step
			var hv := height_at(x, z)
			row_h.append(hv)
			row_in.append(contains_xz(x, z))
			if row_in[row_in.size() - 1]:
				if hv < hmin:
					hmin = hv
				if hv > hmax:
					hmax = hv
		H.append(row_h)
		IN.append(row_in)
	return {
		"H": H, "IN": IN, "nx": nx, "nz": nz,
		"xmin": xmin, "zmin": zmin, "step": step,
		"hmin": hmin, "hmax": hmax,
	}


static func _emit_grid_kind(st: SurfaceTool, pack: Dictionary, kind: String) -> int:
	var H: Array = pack["H"]
	var IN: Array = pack["IN"]
	var nx: int = pack["nx"]
	var nz: int = pack["nz"]
	var xmin: float = pack["xmin"]
	var zmin: float = pack["zmin"]
	var step: float = pack["step"]
	var used := 0
	for iz in range(nz - 1):
		for ix in range(nx - 1):
			var n_in := 0
			if IN[iz][ix]:
				n_in += 1
			if IN[iz][ix + 1]:
				n_in += 1
			if IN[iz + 1][ix]:
				n_in += 1
			if IN[iz + 1][ix + 1]:
				n_in += 1
			if n_in < 3:
				continue
			var x0 := xmin + float(ix) * step
			var x1 := x0 + step
			var z0 := zmin + float(iz) * step
			var z1 := z0 + step
			var cx := (x0 + x1) * 0.5
			var cz := (z0 + z1) * 0.5
			var td := trail_dist(cx, cz)
			var jw := jungle_weight(cx, cz)
			var rw := ruins_weight(cx, cz)
			var cd := creek_dist(cx, cz)
			var zone := forest_zone(cx, cz)
			var cell := "meadow"
			if cd < 1.45 and jw > 0.18:
				cell = "creek"
			elif td < 2.35 and jw > 0.22:
				cell = "trail"
			elif rw > 0.38:
				cell = "ruins"
			elif zone == "clearing" or zone == "edge" or (jw > 0.20 and jw < 0.50):
				cell = "litter"
			elif jw > 0.42:
				cell = "jungle"
			var hollowish := Vector2(cx - HOLLOW_C.x, cz - HOLLOW_C.y).length() < 16.0 or cd < 6.5
			if kind != "all" and kind != cell:
				var moss_ok := kind == "moss" and td > 2.5 and (
					cell == "jungle" or (hollowish and cell != "trail" and cell != "creek")
				)
				if not moss_ok:
					continue
			var v00 := Vector3(x0, H[iz][ix], z0)
			var v10 := Vector3(x1, H[iz][ix + 1], z0)
			var v01 := Vector3(x0, H[iz + 1][ix], z1)
			var v11 := Vector3(x1, H[iz + 1][ix + 1], z1)
			var cr := (v10 - v00).cross(v11 - v00)
			if cr.length_squared() < 0.0000001:
				continue
			var nrm := cr.normalized()
			if nrm.y < 0.0:
				nrm = -nrm
			var uv_s := 2.0
			if cell == "jungle":
				uv_s = 3.5
			elif cell == "litter":
				uv_s = 3.2
			elif cell == "trail" or cell == "creek":
				uv_s = 3.0
			elif cell == "ruins":
				uv_s = 3.2
			if kind == "moss":
				if not hollowish and nrm.y > 0.90 and nrm.z < 0.16:
					continue
				var lift := nrm * 0.02
				uv_s = 3.0
				_emit_tri(st, v00 + lift, v10 + lift, v11 + lift, uv_s, nrm)
				_emit_tri(st, v00 + lift, v11 + lift, v01 + lift, uv_s, nrm)
			else:
				_emit_tri(st, v00, v10, v11, uv_s, nrm)
				_emit_tri(st, v00, v11, v01, uv_s, nrm)
			used += 2
	return used


static func _collision_faces(pack: Dictionary) -> PackedVector3Array:
	var faces := PackedVector3Array()
	var H: Array = pack["H"]
	var IN: Array = pack["IN"]
	var nx: int = pack["nx"]
	var nz: int = pack["nz"]
	var xmin: float = pack["xmin"]
	var zmin: float = pack["zmin"]
	var step: float = pack["step"]
	for iz in range(nz - 1):
		for ix in range(nx - 1):
			var n_in := 0
			if IN[iz][ix]:
				n_in += 1
			if IN[iz][ix + 1]:
				n_in += 1
			if IN[iz + 1][ix]:
				n_in += 1
			if IN[iz + 1][ix + 1]:
				n_in += 1
			if n_in < 3:
				continue
			var x0 := xmin + float(ix) * step
			var x1 := x0 + step
			var z0 := zmin + float(iz) * step
			var z1 := z0 + step
			var v00 := Vector3(x0, H[iz][ix], z0)
			var v10 := Vector3(x1, H[iz][ix + 1], z0)
			var v01 := Vector3(x0, H[iz + 1][ix], z1)
			var v11 := Vector3(x1, H[iz + 1][ix + 1], z1)
			var cr := (v10 - v00).cross(v11 - v00)
			if cr.y < 0.0:
				faces.append(v00)
				faces.append(v11)
				faces.append(v10)
				faces.append(v00)
				faces.append(v01)
				faces.append(v11)
			else:
				faces.append(v00)
				faces.append(v10)
				faces.append(v11)
				faces.append(v00)
				faces.append(v11)
				faces.append(v01)
	return faces


static func trail_ribbon_mesh() -> ArrayMesh:
	ensure()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := _trail.size()
	if n < 2:
		return _finish_mesh(st)
	var half := 1.65
	for i in range(n - 1):
		var a: Vector2 = _trail[i]
		var b: Vector2 = _trail[i + 1]
		var dir := b - a
		if dir.length() < 0.05:
			continue
		var side := Vector2(-dir.y, dir.x).normalized() * half
		var p00 := a - side
		var p10 := a + side
		var p01 := b - side
		var p11 := b + side
		var v00 := Vector3(p00.x, height_at(p00.x, p00.y) + 0.03, p00.y)
		var v10 := Vector3(p10.x, height_at(p10.x, p10.y) + 0.03, p10.y)
		var v01 := Vector3(p01.x, height_at(p01.x, p01.y) + 0.03, p01.y)
		var v11 := Vector3(p11.x, height_at(p11.x, p11.y) + 0.03, p11.y)
		_emit_tri(st, v00, v10, v11, 3.0, Vector3.UP)
		_emit_tri(st, v00, v11, v01, 3.0, Vector3.UP)
	return _finish_mesh(st)


static func creek_ribbon_mesh() -> ArrayMesh:
	ensure()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := _creek.size()
	if n < 2:
		return _finish_mesh(st)
	var half := 1.05
	for i in range(n - 1):
		var a: Vector2 = _creek[i]
		var b: Vector2 = _creek[i + 1]
		var dir := b - a
		if dir.length() < 0.05:
			continue
		var side := Vector2(-dir.y, dir.x).normalized() * half
		var p00 := a - side
		var p10 := a + side
		var p01 := b - side
		var p11 := b + side
		var v00 := Vector3(p00.x, height_at(p00.x, p00.y) + 0.02, p00.y)
		var v10 := Vector3(p10.x, height_at(p10.x, p10.y) + 0.02, p10.y)
		var v01 := Vector3(p01.x, height_at(p01.x, p01.y) + 0.02, p01.y)
		var v11 := Vector3(p11.x, height_at(p11.x, p11.y) + 0.02, p11.y)
		_emit_tri(st, v00, v10, v11, 4.0, Vector3.UP)
		_emit_tri(st, v00, v11, v01, 4.0, Vector3.UP)
	return _finish_mesh(st)


static func ocean_mesh(half: float = 430.0, y: float = -0.62, uv_world: float = 12.0) -> ArrayMesh:
	# One large quad, world-projected UVs. No prototype tile scale.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [
		Vector3(-half, y, -half), Vector3(half, y, -half),
		Vector3(half, y, half), Vector3(-half, y, half),
	]
	for tri in [[0, 1, 2], [0, 2, 3]]:
		for i in tri:
			var v: Vector3 = pts[i]
			st.set_normal(Vector3.UP)
			st.set_color(Color.WHITE)
			st.set_uv(Vector2(v.x / uv_world, v.z / uv_world))
			st.add_vertex(v)
	var mesh := st.commit()
	mesh.custom_aabb = AABB(Vector3(-half, y - 2.0, -half), Vector3(half * 2.0, 6.0, half * 2.0))
	return mesh


static func cliff_mesh() -> ArrayMesh:
	var ring := _densify()
	var n := ring.size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var a := ring[i]
		var b := ring[(i + 1) % n]
		var outn := -_edge_inward(a, b)
		var ha := height_at(a.x, a.y)
		var hb := height_at(b.x, b.y)
		var a0 := Vector3(a.x, ha + 0.04, a.y)
		var b0 := Vector3(b.x, hb + 0.04, b.y)
		var a1 := Vector3(a.x + outn.x * 0.55, -CLIFF_H, a.y + outn.y * 0.55)
		var b1 := Vector3(b.x + outn.x * 0.55, -CLIFF_H, b.y + outn.y * 0.55)
		var nrm := Vector3(outn.x, 0.15, outn.y).normalized()
		_emit_tri(st, a0, b0, b1, 4.0, nrm)
		_emit_tri(st, a0, b1, a1, 4.0, nrm)
	return _finish_mesh(st)


static func sand_mesh() -> ArrayMesh:
	var ring := _densify()
	var n := ring.size()
	var inner := PackedVector2Array()
	var outer := PackedVector2Array()
	for i in n:
		var prev := ring[(i - 1 + n) % n]
		var cur := ring[i]
		var nxt := ring[(i + 1) % n]
		var inn := (_edge_inward(prev, cur) + _edge_inward(cur, nxt))
		if inn.length() < 0.001:
			inn = _centroid - cur
		inn = inn.normalized()
		var in_w := 1.0
		var out_w := 3.0
		if cur.x < -40.0:
			in_w = 1.25
			out_w = 3.6
		var ip := cur + inn * in_w
		if not contains_xz(ip.x, ip.y):
			ip = cur + inn * 0.45
		inner.append(ip)
		outer.append(cur - inn * out_w)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var used := 0
	for i in n:
		var i2 := (i + 1) % n
		var yi := height_at(inner[i].x, inner[i].y) + 0.012
		var yi2 := height_at(inner[i2].x, inner[i2].y) + 0.012
		var a := Vector3(outer[i].x, -0.02, outer[i].y)
		var b := Vector3(outer[i2].x, -0.02, outer[i2].y)
		var c := Vector3(inner[i2].x, yi2, inner[i2].y)
		var d := Vector3(inner[i].x, yi, inner[i].y)
		_emit_tri(st, a, b, c, 2.0, Vector3.UP)
		_emit_tri(st, a, c, d, 2.0, Vector3.UP)
		used += 2
	var mesh := _finish_mesh(st)
	print("island sand quads=", used, " ring=", n, " aabb=", mesh.get_aabb())
	return mesh


static func foam_mesh() -> ArrayMesh:
	var ring := _densify()
	var n := ring.size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var a := ring[i]
		var b := ring[(i + 1) % n]
		var outn := -_edge_inward(a, b)
		var a0 := Vector3(a.x, -0.13, a.y)
		var b0 := Vector3(b.x, -0.13, b.y)
		var a1 := Vector3(a.x + outn.x * 0.95, -0.13, a.y + outn.y * 0.95)
		var b1 := Vector3(b.x + outn.x * 0.95, -0.13, b.y + outn.y * 0.95)
		_emit_tri(st, a0, b0, b1, 3.0, Vector3.UP)
		_emit_tri(st, a0, b1, a1, 3.0, Vector3.UP)
	return _finish_mesh(st)


static func _add_surf(parent: Node3D, mesh: ArrayMesh, mat: Material, name: String) -> bool:
	if mesh == null or mesh.get_surface_count() < 1:
		return false
	var aabb := mesh.get_aabb()
	if aabb.size.x < 1.0 and aabb.size.z < 1.0:
		return false
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 40.0
	parent.add_child(mi)
	print("island draw ", name, " ArrayMesh surfs=", mesh.get_surface_count(), " aabb=", aabb)
	return true


static func _csg_fill(parent: Node3D, p: PackedVector2Array, mat: Material, depth: float, y: float, name: String) -> void:
	var csg := CSGPolygon3D.new()
	csg.name = name
	csg.polygon = p
	csg.mode = CSGPolygon3D.MODE_DEPTH
	csg.depth = depth
	csg.material = mat
	csg.rotation_degrees = Vector3(90, 0, 0)
	csg.position = Vector3(0.0, y, 0.0)
	csg.use_collision = false
	csg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(csg)
	print("island draw ", name, " CSGPolygon3D verts=", p.size(), " depth=", depth)


static func stamp(parent: Node3D) -> void:
	ensure()
	var pack := _sample_height_grid()
	var gmat := Mats.ground(Mats.grass_tex())
	var jmat := Mats.ground(Mats.jungle_floor_tex(), Color(1.32, 1.22, 1.02))
	var tmat := Mats.ground(Mats.jungle_dirt_tex(), Color(1.18, 1.05, 0.88))
	var mmat := Mats.ground(Mats.jungle_moss_tex(), Color(1.10, 1.28, 0.92))
	var smat := Mats.ground(Mats.sand_tex())
	var dmat := Mats.ground(Mats.dirt_tex(), Color(0.95, 0.86, 0.68))

	var st_m := SurfaceTool.new()
	st_m.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_m := _emit_grid_kind(st_m, pack, "meadow")
	var st_j := SurfaceTool.new()
	st_j.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_j := _emit_grid_kind(st_j, pack, "jungle")
	var st_t := SurfaceTool.new()
	st_t.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_t := _emit_grid_kind(st_t, pack, "trail")
	var st_s := SurfaceTool.new()
	st_s.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_s := _emit_grid_kind(st_s, pack, "moss")
	var st_r := SurfaceTool.new()
	st_r.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_r := _emit_grid_kind(st_r, pack, "ruins")
	var st_c := SurfaceTool.new()
	st_c.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_c := _emit_grid_kind(st_c, pack, "creek")
	var st_l := SurfaceTool.new()
	st_l.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_l := _emit_grid_kind(st_l, pack, "litter")

	var grass_kind := "HeightGrid"
	if not _add_surf(parent, _finish_mesh(st_m), gmat, "IslandMeadow"):
		_csg_fill(parent, poly(), gmat, 0.08, 0.0, "IslandGrassCSG")
		grass_kind = "CSGPolygon3D"
	_add_surf(parent, _finish_mesh(st_j), jmat, "IslandJungle")
	var lmat := Mats.ground(Mats.jungle_litter_tex(), Color(1.48, 1.46, 1.12))
	_add_surf(parent, _finish_mesh(st_l), lmat, "IslandLitter")
	_add_surf(parent, _finish_mesh(st_t), tmat, "IslandTrail")
	_add_surf(parent, trail_ribbon_mesh(), tmat, "IslandTrailRibbon")
	_add_surf(parent, _finish_mesh(st_s), mmat, "IslandMoss")
	var rmat := Mats.ground(Mats.dirt_tex(), Color(0.92, 0.82, 0.70))
	_add_surf(parent, _finish_mesh(st_r), rmat, "IslandRuinsHill")
	var cmat := Mats.ground(Mats.jungle_dirt_tex(), Color(0.70, 0.78, 0.82))
	_add_surf(parent, _finish_mesh(st_c), cmat, "IslandCreek")
	_add_surf(parent, creek_ribbon_mesh(), Mats.water(Color(0.55, 0.78, 0.74)), "IslandCreekRibbon")

	var faces := _collision_faces(pack)
	var body := StaticBody3D.new()
	body.name = "IslandTerrainBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var sh := ConcavePolygonShape3D.new()
	sh.backface_collision = true
	sh.set_faces(faces)
	col.shape = sh
	body.add_child(col)
	parent.add_child(body)
	print("island terrain collision faces=", faces.size() / 3, " h=[", snappedf(float(pack["hmin"]), 0.01), ",", snappedf(float(pack["hmax"]), 0.01), "] backface=1")

	var sand_kind := "ArrayMesh"
	if not _add_surf(parent, sand_mesh(), smat, "IslandSand"):
		sand_kind = "missing"
	var cliff_kind := "ArrayMesh"
	if not _add_surf(parent, cliff_mesh(), dmat, "IslandCliff"):
		cliff_kind = "missing"

	print("GROUND_DRAW meadow_tris=", n_m, " jungle_tris=", n_j, " litter_tris=", n_l, " trail_tris=", n_t, " moss_tris=", n_s, " ruins_tris=", n_r, " creek_tris=", n_c, " sand=", sand_kind, " cliff=", cliff_kind, " kind=", grass_kind, " uv_jungle=xz/3.5 tex=jungle_floor")


# Fine grass: Kenney Foliage Sprites on a 4-quad star (not grass_large.glb).
# Native card 0.34 m tall × 0.28 m wide. Scale jitter → ankle / mid-shin.
const GRASS_H := 0.34
const GRASS_W := 0.28
const GRASS_CARDS := 4
const BUSH_SCL := 2.85
const BUSH_L_SCL := 3.20
const FLOWER_SCL := 2.55
const ALTAR_DIRT_R := 7.35


static func grass_card_mesh(width: float = GRASS_W, height: float = GRASS_H, cards: int = GRASS_CARDS) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := width * 0.5
	for i in cards:
		var yaw := float(i) * PI / float(cards)
		var c := cos(yaw)
		var s := sin(yaw)
		var bl := Vector3(-hw * c, 0.0, -hw * s)
		var br := Vector3(hw * c, 0.0, hw * s)
		var tl := Vector3(-hw * c, height, -hw * s)
		var tr := Vector3(hw * c, height, hw * s)
		var nrm := Vector3(-s, 0.0, c)
		var verts: Array = [
			[bl, Vector2(0.0, 1.0)], [br, Vector2(1.0, 1.0)], [tr, Vector2(1.0, 0.0)],
			[bl, Vector2(0.0, 1.0)], [tr, Vector2(1.0, 0.0)], [tl, Vector2(0.0, 0.0)],
		]
		for v_uv in verts:
			st.set_normal(nrm)
			st.set_uv(v_uv[1])
			st.set_color(Color.WHITE)
			st.add_vertex(v_uv[0])
	var mesh := st.commit()
	mesh.custom_aabb = AABB(Vector3(-0.45, -0.04, -0.45), Vector3(0.90, 0.55, 0.90))
	return mesh


static func scatter_plants(parent: Node3D, village: Node) -> void:
	ensure()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260816

	var grass_a: Array = []
	var grass_b: Array = []
	var grass_c: Array = []
	var bush: Array = []
	var bush_l: Array = []
	var fl_y: Array = []
	var fl_r: Array = []
	var fl_p: Array = []

	# Dense meadow at default spawn (7.5, 8.2) so the feet-cam is lush, not 3 plates.
	var feet := [
		Vector3(8.55, 0.0, 7.35), Vector3(9.25, 0.0, 8.15), Vector3(8.10, 0.0, 6.70),
		Vector3(9.85, 0.0, 7.55), Vector3(7.15, 0.0, 6.55), Vector3(10.15, 0.0, 8.70),
		Vector3(6.55, 0.0, 7.20), Vector3(8.90, 0.0, 9.40), Vector3(9.60, 0.0, 6.40),
		Vector3(7.80, 0.0, 9.55), Vector3(9.40, 0.0, 7.10), Vector3(8.20, 0.0, 7.80),
		Vector3(10.40, 0.0, 6.90), Vector3(8.70, 0.0, 6.20), Vector3(9.10, 0.0, 8.80),
		Vector3(7.40, 0.0, 7.60), Vector3(10.60, 0.0, 7.80), Vector3(8.00, 0.0, 5.90),
	]
	for fp in feet:
		if _plant_ok(fp, village, 0.85):
			_push_grass(grass_a, grass_b, grass_c, fp, rng, rng.randf_range(0.86, 1.14))
	for _si in 42:
		var ang := rng.randf() * TAU
		var rad := rng.randf_range(0.7, 5.4)
		var sp := Vector3(7.5 + cos(ang) * rad, 0.0, 8.2 + sin(ang) * rad)
		if _plant_ok(sp, village, 0.90):
			_push_grass(grass_a, grass_b, grass_c, sp, rng, rng.randf_range(0.80, 1.16))
	# Tight cluster in the grass-cam look-at (9.35, 6.85) so the close shot is lush.
	for _ci in 28:
		var cang := rng.randf() * TAU
		var crad := rng.randf_range(0.25, 2.15)
		var cp := Vector3(9.20 + cos(cang) * crad, 0.0, 7.00 + sin(cang) * crad)
		if _plant_ok(cp, village, 0.75):
			_push_grass(grass_a, grass_b, grass_c, cp, rng, rng.randf_range(0.82, 1.12))

	# Jittered island grid — readable clumps, not a carpet.
	for ix in range(-74, 200, 7):
		for iz in range(-60, 80, 7):
			var gp := Vector3(float(ix) + rng.randf_range(-2.4, 2.4), 0.0, float(iz) + rng.randf_range(-2.4, 2.4))
			if _plant_ok(gp, village, 1.10):
				_push_grass(grass_a, grass_b, grass_c, gp, rng, rng.randf_range(0.78, 1.16))
	# Forest undergrowth by zone — dense only is thick; edge stays readable.
	for _ji in 260:
		var jx := rng.randf_range(20.0, 190.0)
		var jz := rng.randf_range(-14.0, 74.0)
		var zn := forest_zone(jx, jz)
		if zn in ["trail", "meadow", "sea"]:
			continue
		if zn == "clearing" and clearing_norm(jx, jz) < 0.72:
			continue
		if zn == "ridge" and rng.randf() > 0.28:
			continue
		if zn == "edge" and rng.randf() > 0.50:
			continue
		var jp := Vector3(jx, 0.0, jz)
		if _plant_ok(jp, village, 1.05):
			var gsc := rng.randf_range(0.74, 1.10)
			if zn == "edge":
				gsc = rng.randf_range(0.88, 1.18)
			_push_grass(grass_a, grass_b, grass_c, jp, rng, gsc)
	# Extra tufts only in 密林.
	for _di in 90:
		var dx := rng.randf_range(58.0, 175.0)
		var dz := rng.randf_range(6.0, 58.0)
		if forest_zone(dx, dz) != "dense":
			continue
		var dp := Vector3(dx, 0.0, dz)
		if _plant_ok(dp, village, 1.05):
			_push_grass(grass_a, grass_b, grass_c, dp, rng, rng.randf_range(0.70, 1.06))

	# Path shoulders — extra density both sides of dirt roads.
	if village and village.has_method("road_points"):
		var roads: Array = village.road_points()
		var ri := 0
		for rc in roads:
			ri += 1
			var rcx: float = rc.x
			var rcz: float = rc.z
			for side_i in 2:
				var side := -1.0 if side_i == 0 else 1.0
				var off := 2.35 + rng.randf_range(0.0, 1.55)
				var dx := off * side
				var dz := rng.randf_range(-0.55, 0.55)
				if absf(rcx) < 3.5:
					dx = rng.randf_range(-0.55, 0.55)
					dz = off * side
				var rp := Vector3(rcx + dx, 0.0, rcz + dz)
				if _plant_ok(rp, village, 0.80):
					_push_grass(grass_a, grass_b, grass_c, rp, rng, rng.randf_range(0.82, 1.12))
				# second tuft a bit further out on every other cell
				if ri % 2 == 0:
					var rp2 := Vector3(rp.x + rng.randf_range(-0.9, 0.9), 0.0, rp.z + rng.randf_range(-0.9, 0.9))
					if _plant_ok(rp2, village, 0.80):
						_push_grass(grass_a, grass_b, grass_c, rp2, rng, rng.randf_range(0.78, 1.10))

	# 林缘 brighter grass — meadow side of the forest, you can see in.
	for wi in 40:
		var wa := float(wi) * TAU / 40.0 + rng.randf_range(-0.08, 0.08)
		var radw := rng.randf_range(8.0, 22.0)
		var wp := Vector3(36.0 + cos(wa) * radw, 0.0, 18.0 + sin(wa) * radw)
		if forest_zone(wp.x, wp.z) not in ["edge", "meadow"]:
			continue
		if _plant_ok(wp, village, 1.05):
			_push_grass(grass_a, grass_b, grass_c, wp, rng, rng.randf_range(0.90, 1.20))

	# Village lot backs / hedges (not the street).
	var lots := [
		Vector3(11.4, 0.0, -15.2), Vector3(11.6, 0.0, -8.4), Vector3(11.2, 0.0, -25.0),
		Vector3(11.5, 0.0, -31.6), Vector3(-13.4, 0.0, -15.0), Vector3(-13.6, 0.0, -8.2),
		Vector3(-13.2, 0.0, -25.2), Vector3(-13.5, 0.0, -31.4),
		Vector3(8.6, 0.0, -6.2), Vector3(-10.4, 0.0, -6.0),
		Vector3(4.8, 0.0, -28.6), Vector3(-6.6, 0.0, -28.4),
	]
	for lp in lots:
		for _k in 2:
			var lq := Vector3(lp.x + rng.randf_range(-0.9, 0.9), 0.0, lp.z + rng.randf_range(-0.9, 0.9))
			if _plant_ok(lq, village, 1.00):
				_push_grass(grass_a, grass_b, grass_c, lq, rng, rng.randf_range(0.84, 1.10))

	# Coast grass — inward of the sand ribbon.
	var ring := _densify()
	var nring := ring.size()
	for ci in nring:
		if ci % 2 == 1:
			continue
		var ca: Vector2 = ring[ci]
		var cb: Vector2 = ring[(ci + 1) % nring]
		var inn := _edge_inward(ca, cb)
		var mid := (ca + cb) * 0.5
		var cp := Vector3(mid.x + inn.x * rng.randf_range(2.6, 4.4), 0.0, mid.y + inn.y * rng.randf_range(2.6, 4.4))
		if _plant_ok(cp, village, 1.05):
			_push_grass(grass_a, grass_b, grass_c, cp, rng, rng.randf_range(0.78, 1.08))

	# Fill / trim to a slightly higher band now that the jungle is large.
	var guard := 0
	while (grass_a.size() + grass_b.size() + grass_c.size()) < 640 and guard < 2200:
		guard += 1
		var xp := Vector3(rng.randf_range(-70.0, 190.0), 0.0, rng.randf_range(-56.0, 72.0))
		if on_trail(xp.x, xp.z, 2.5):
			continue
		if _plant_ok(xp, village, 1.10):
			_push_grass(grass_a, grass_b, grass_c, xp, rng, rng.randf_range(0.78, 1.16))
	# Soft cap — keep spawn/path extras, trim random fill first.
	if (grass_a.size() + grass_b.size() + grass_c.size()) > 820:
		var over := grass_a.size() + grass_b.size() + grass_c.size() - 820
		while over > 0 and grass_c.size() > 8:
			grass_c.pop_back()
			over -= 1
		while over > 0 and grass_b.size() > 40:
			grass_b.pop_back()
			over -= 1
		while over > 0 and grass_a.size() > 80:
			grass_a.pop_back()
			over -= 1

	# Bushes — woods rim, lot backs, a few coast.
	var bush_spots := [
		Vector3(28.4, 0.0, 12.2), Vector3(38.6, 0.0, 14.8), Vector3(42.2, 0.0, 24.4),
		Vector3(36.0, 0.0, 32.6), Vector3(24.8, 0.0, 26.0), Vector3(30.2, 0.0, 8.6),
		Vector3(46.4, 0.0, 20.2), Vector3(22.6, 0.0, 18.4), Vector3(40.8, 0.0, 8.8),
		Vector3(12.4, 0.0, -12.6), Vector3(12.8, 0.0, -22.4), Vector3(-14.6, 0.0, -12.2),
		Vector3(-14.8, 0.0, -22.8), Vector3(12.2, 0.0, -32.0), Vector3(-14.4, 0.0, -32.2),
		Vector3(16.6, 0.0, 4.4), Vector3(-16.2, 0.0, 6.8), Vector3(8.2, 0.0, 18.6),
		Vector3(-10.4, 0.0, 16.2), Vector3(-38.4, 0.0, 8.6), Vector3(-36.2, 0.0, -8.4),
		Vector3(4.6, 0.0, 42.2), Vector3(-8.8, 0.0, 40.6), Vector3(18.4, 0.0, -36.2),
		Vector3(-20.6, 0.0, -18.4), Vector3(48.2, 0.0, 28.6), Vector3(26.8, 0.0, 38.4),
		Vector3(20.4, 0.0, 4.8), Vector3(-22.8, 0.0, 4.2), Vector3(14.6, 0.0, 22.4),
		Vector3(-6.2, 0.0, 22.8), Vector3(32.4, 0.0, 36.8), Vector3(50.2, 0.0, 14.6),
		Vector3(64.0, 0.0, 14.0), Vector3(72.0, 0.0, 38.0), Vector3(86.0, 0.0, 42.0),
		Vector3(92.0, 0.0, 14.0), Vector3(118.0, 0.0, 16.0), Vector3(126.0, 0.0, 48.0),
		Vector3(134.0, 0.0, 20.0), Vector3(148.0, 0.0, 22.0), Vector3(162.0, 0.0, 32.0),
		Vector3(100.0, 0.0, 48.0), Vector3(80.0, 0.0, 10.0), Vector3(142.0, 0.0, 52.0),
		Vector3(70.0, 0.0, 34.0), Vector3(124.0, 0.0, 44.0), Vector3(168.0, 0.0, 42.0),
		Vector3(88.0, 0.0, 8.0), Vector3(112.0, 0.0, 10.0), Vector3(156.0, 0.0, 24.0),
	]
	for bi in bush_spots.size():
		var bp: Vector3 = bush_spots[bi]
		bp.x += rng.randf_range(-0.8, 0.8)
		bp.z += rng.randf_range(-0.8, 0.8)
		if not _plant_ok(bp, village, 1.20):
			continue
		if bi % 3 == 0:
			bush_l.append(_xf(bp, rng.randf() * TAU, BUSH_L_SCL * rng.randf_range(0.92, 1.10)))
		else:
			bush.append(_xf(bp, rng.randf() * TAU, BUSH_SCL * rng.randf_range(0.90, 1.12)))

	# A few flowers on lot edges + near the spawn meadow.
	var flower_spots := [
		Vector3(8.2, 0.0, 6.2), Vector3(10.4, 0.0, 9.1), Vector3(6.4, 0.0, 9.8),
		Vector3(10.8, 0.0, -10.6), Vector3(-12.2, 0.0, -10.4), Vector3(10.6, 0.0, -18.8),
		Vector3(-12.4, 0.0, -18.6), Vector3(5.6, 0.0, 14.2), Vector3(-8.6, 0.0, 12.4),
		Vector3(16.2, 0.0, 6.6),
	]
	for fi in flower_spots.size():
		var fpos: Vector3 = flower_spots[fi]
		if not _plant_ok(fpos, village, 1.00):
			continue
		var fxf := _xf(fpos, rng.randf() * TAU, FLOWER_SCL * rng.randf_range(0.92, 1.12))
		match fi % 3:
			0:
				fl_y.append(fxf)
			1:
				fl_r.append(fxf)
			_:
				fl_p.append(fxf)

	var card := grass_card_mesh()
	var ga_n := _stamp_card_mm(parent, card, Mats.grass_card("a"), grass_a, "IslandGrassTufts")
	var gb_n := _stamp_card_mm(parent, card, Mats.grass_card("b", Color(0.98, 1.04, 0.88)), grass_b, "IslandGrassTuftsB")
	var gc_n := _stamp_card_mm(parent, card, Mats.grass_card("c", Color(0.92, 1.00, 0.84)), grass_c, "IslandGrassTuftsC")
	var b_n := _stamp_mm(parent, "res://assets/kenney_nature/plant_bush.glb", bush, "IslandBushes", true)
	var bl_n := _stamp_mm(parent, "res://assets/kenney_nature/plant_bushLarge.glb", bush_l, "IslandBushesLarge", true)
	var fy_n := _stamp_mm(parent, "res://assets/kenney_nature/flower_yellowA.glb", fl_y, "IslandFlowersY", false)
	var fr_n := _stamp_mm(parent, "res://assets/kenney_nature/flower_redA.glb", fl_r, "IslandFlowersR", false)
	var fp_n := _stamp_mm(parent, "res://assets/kenney_nature/flower_purpleA.glb", fl_p, "IslandFlowersP", false)
	var g_tot := ga_n + gb_n + gc_n
	print("GRASS_FINE cards=4 blades~12/18/7 instances=", g_tot, " (a=", ga_n, " b=", gb_n, " c=", gc_n, ") h=", GRASS_H, " bush=", b_n, " bushLarge=", bl_n, " flowers=", fy_n + fr_n + fp_n)

static func _push_grass(a: Array, b: Array, c: Array, pos: Vector3, rng: RandomNumberGenerator, scl: float) -> void:
	var xf := _xf(pos, rng.randf() * TAU, scl)
	var k := rng.randi() % 100
	if k < 52:
		a.append(xf)
	elif k < 86:
		b.append(xf)
	else:
		c.append(xf)


static func _xf(pos: Vector3, yaw: float, scl: float) -> Transform3D:
	var y := height_at(pos.x, pos.z)
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3(scl, scl, scl))
	return Transform3D(basis, Vector3(pos.x, y, pos.z))


static func _plant_ok(pos: Vector3, village: Node, road_pad: float) -> bool:
	# Land only, stay off the sand ribbon / water / jungle trail.
	if not contains_v(pos, 2.15):
		return false
	if on_trail(pos.x, pos.z, 2.35):
		return false
	if in_clearing(pos.x, pos.z, 0.70):
		return false
	# Altar dirt disc (r~7).
	if Vector2(pos.x, pos.z).length() < ALTAR_DIRT_R:
		return false
	# Keep courtyard (Kenney cells x -3..1, z -22..-18).
	if pos.x > -6.8 and pos.x < 4.8 and pos.z > -45.0 and pos.z < -33.5:
		return false
	# Pier boards on the west spit.
	if pos.x > -54.5 and pos.x < -46.5 and pos.z > 1.0 and pos.z < 16.5:
		return false
	if village:
		if village.has_method("blocks") and village.blocks(pos, 1.15):
			return false
		if village.has_method("on_road") and village.on_road(pos, road_pad):
			return false
	return true


static func _first_mi(root: Node) -> MeshInstance3D:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			return n as MeshInstance3D
		for c in n.get_children():
			stack.append(c)
	return null


static func _stamp_card_mm(parent: Node3D, mesh: ArrayMesh, mat: Material, xfs: Array, name: String) -> int:
	if xfs.is_empty() or mesh == null:
		return 0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = name
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 24.0
	mmi.custom_aabb = AABB(Vector3(-100.0, -2.0, -90.0), Vector3(330.0, 16.0, 200.0))
	parent.add_child(mmi)
	print("island draw ", name, " MultiMesh n=", xfs.size(), " mesh=grass_card_star4")
	return xfs.size()


static func _stamp_mm(parent: Node3D, path: String, xfs: Array, name: String, override_mat: bool) -> int:
	if xfs.is_empty():
		return 0
	if not ResourceLoader.exists(path):
		print("scatter missing ", path)
		return 0
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	if "quaternius_trees" in path:
		Mats.dress_tree(inst)
	else:
		Mats.polish_imported(inst)
	var mi := _first_mi(inst)
	if mi == null or mi.mesh == null:
		inst.free()
		return 0
	var mesh: Mesh = mi.mesh
	var mat: Material = mi.get_active_material(0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = name
	mmi.multimesh = mm
	if override_mat:
		mmi.material_override = Mats.nature_leaf()
	elif mat:
		mmi.material_override = null
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 24.0
	mmi.custom_aabb = AABB(Vector3(-100.0, -2.0, -90.0), Vector3(330.0, 16.0, 200.0))
	parent.add_child(mmi)
	inst.free()
	print("island draw ", name, " MultiMesh n=", xfs.size(), " mesh=", path.get_file())
	return xfs.size()



static func scatter_jungle(parent: Node3D, village: Node) -> void:
	# Authored forest PLAN. No uniform Poisson / random fill-to-N.
	ensure()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260816
	var oak: Array = []
	var pine: Array = []
	var birch: Array = []
	var logs: Array = []
	var stumps: Array = []
	var rocks: Array = []
	var occupied: Array = []
	var n_edge := 0
	var n_dense := 0
	var n_ridge := 0
	var n_hollow := 0
	var n_shoulder := 0

	# 1) 林缘 — spaced oak + birch toward the altar/meadow. You can see in.
	var edge_trees := [
		[28.0, 22.0, "oak", 1.46], [34.0, 10.0, "oak", 1.52], [38.0, 28.0, "birch", 1.06],
		[42.0, 8.0, "oak", 1.40], [46.0, 32.0, "oak", 1.48], [48.0, 12.0, "birch", 1.00],
		[52.0, 26.0, "oak", 1.42], [30.0, 32.0, "birch", 0.98], [36.0, 16.0, "oak", 1.38],
		[50.0, 6.0, "oak", 1.50], [26.0, 14.0, "birch", 1.02], [44.0, 36.0, "oak", 1.44],
		[54.0, 14.0, "birch", 1.08], [40.0, 4.0, "oak", 1.36], [22.0, 26.0, "oak", 1.40],
		[56.0, 34.0, "oak", 1.46], [24.0, 20.0, "oak", 1.42], [32.0, 6.0, "birch", 1.04],
		[20.0, 18.0, "oak", 1.44], [25.0, 8.0, "birch", 1.02], [47.0, 38.0, "oak", 1.48],
		[18.0, 12.0, "oak", 1.38], [41.0, 24.0, "birch", 1.00],
	]
	for e in edge_trees:
		var kind: String = e[2]
		var dest: Array = oak if kind == "oak" else birch
		if _plant_decor(dest, occupied, float(e[0]), float(e[1]), float(e[0]) * 0.31, float(e[3]), village, 5.4):
			n_edge += 1

	# 2) 密林 — clumps of 3–5, not a grid. Walk corridors between clumps.
	var clumps := [
		[64.0, 12.0, 4, 0.50], [70.0, 36.0, 5, 0.60], [80.0, 8.0, 3, 0.40],
		[86.0, 40.0, 4, 0.70], [92.0, 12.0, 4, 0.40], [118.0, 14.0, 4, 0.50],
		[124.0, 46.0, 5, 0.60], [134.0, 18.0, 4, 0.50], [142.0, 50.0, 3, 0.70],
		[148.0, 20.0, 4, 0.40], [162.0, 30.0, 4, 0.50], [168.0, 44.0, 3, 0.60],
		[74.0, 48.0, 3, 0.80], [100.0, 46.0, 4, 0.60], [112.0, 8.0, 3, 0.30],
		[128.0, 8.0, 3, 0.40], [176.0, 22.0, 3, 0.50], [60.0, 8.0, 3, 0.30],
	]
	var offs3 := [Vector2(-2.2, -1.4), Vector2(2.4, 0.6), Vector2(0.2, 2.6)]
	var offs4 := [Vector2(-2.6, -1.8), Vector2(2.2, -1.2), Vector2(1.8, 2.4), Vector2(-1.6, 2.2)]
	var offs5 := [Vector2(-2.8, -1.6), Vector2(2.6, -1.4), Vector2(2.2, 2.6), Vector2(-2.2, 2.4), Vector2(0.4, 0.15)]
	for cl in clumps:
		var n: int = int(cl[2])
		var pine_frac: float = float(cl[3])
		var offs: Array = offs5 if n >= 5 else (offs4 if n == 4 else offs3)
		for i in offs.size():
			var o: Vector2 = offs[i]
			var x: float = float(cl[0]) + o.x
			var z: float = float(cl[1]) + o.y
			var yaw := (x + z) * 0.17
			var use_pine := float(i) < float(n) * pine_frac
			if use_pine:
				if _plant_decor(pine, occupied, x, z, yaw, 1.08 + fmod(absf(x), 0.18), village, 2.35):
					n_dense += 1
			else:
				if _plant_decor(oak, occupied, x, z, yaw, 1.38 + fmod(absf(z), 0.20), village, 2.35):
					n_dense += 1

	# 3) 山脊 — pines + rock line, little undergrowth.
	var ridge_pines := [
		[50.0, 40.0], [58.0, 46.0], [68.0, 50.0], [78.0, 52.0], [92.0, 54.0],
		[106.0, 56.0], [118.0, 54.0], [132.0, 50.0], [146.0, 46.0], [160.0, 44.0],
		[54.0, 48.0], [84.0, 48.0], [124.0, 58.0], [152.0, 50.0],
	]
	for rp in ridge_pines:
		if _plant_decor(pine, occupied, float(rp[0]), float(rp[1]), float(rp[0]) * 0.21, 1.16, village, 5.2):
			n_ridge += 1

	# 4) 谷地/溪 — birch, mossier floor already.
	var hollow_birch := [
		[88.0, 8.0], [96.0, 4.0], [104.0, 2.0], [112.0, -2.0], [120.0, -8.0],
		[90.0, 16.0], [100.0, 12.0], [108.0, 6.0], [84.0, 4.0], [126.0, -4.0],
		[94.0, 0.0], [116.0, 8.0],
	]
	for hb in hollow_birch:
		if _plant_decor(birch, occupied, float(hb[0]), float(hb[1]), float(hb[0]) * 0.27, 1.02, village, 4.2):
			n_hollow += 1

	# Trail shoulders — a few readable trunks, never on the path.
	var shoulders := [
		[60.0, 28.0, "oak", 1.44], [84.0, 30.0, "oak", 1.40],
		[96.0, 22.0, "pine", 1.10], [122.0, 36.0, "oak", 1.46], [136.0, 30.0, "pine", 1.14],
	]
	for sh in shoulders:
		var dest2: Array = oak if sh[2] == "oak" else pine
		if _plant_decor(dest2, occupied, float(sh[0]), float(sh[1]), float(sh[0]) * 0.19, float(sh[3]), village, 4.0):
			n_shoulder += 1

	# 空地 middle — stumps / logs (chopping happens on the rim).
	var glade_litter := [
		Vector3(106.2, 0, 23.4), Vector3(110.8, 0, 22.8), Vector3(104.4, 0, 22.2),
		Vector3(108.6, 0, 21.6), Vector3(111.4, 0, 24.0),
	]
	for i in glade_litter.size():
		var lp: Vector3 = glade_litter[i]
		if not contains_v(lp, 2.4) or on_trail(lp.x, lp.z, 2.6):
			continue
		if i < 3:
			stumps.append(_xf(lp, lp.x * 0.4, 2.45))
		else:
			logs.append(_xf(lp, lp.x * 0.5, 2.25))

	# Dense-floor logs (not a scatter carpet).
	for lp2 in [Vector3(68.4, 0, 34.2), Vector3(88.6, 0, 10.4), Vector3(126.2, 0, 44.8), Vector3(160.4, 0, 28.6)]:
		if contains_v(lp2, 2.6) and not on_trail(lp2.x, lp2.z, 2.8) and not in_clearing(lp2.x, lp2.z, 0.95):
			logs.append(_xf(lp2, lp2.z * 0.3, 2.20))

	# Ridge rock line.
	var ridge_rocks := [
		Vector3(52.0, 0, 42.0), Vector3(66.0, 0, 50.0), Vector3(80.0, 0, 53.0),
		Vector3(96.0, 0, 55.0), Vector3(114.0, 0, 55.0), Vector3(130.0, 0, 51.0),
		Vector3(148.0, 0, 47.0), Vector3(164.0, 0, 43.0), Vector3(72.0, 0, 46.0),
		Vector3(122.0, 0, 58.0),
	]
	for rk in ridge_rocks:
		if contains_v(rk, 2.6) and not on_trail(rk.x, rk.z, 2.6):
			rocks.append(_xf(rk, rk.x * 0.22, 2.45))

	var oak_n := _stamp_mm(parent, "res://assets/quaternius_trees/tree_oak_a.glb", oak, "JungleOak", false)
	var pine_n := _stamp_mm(parent, "res://assets/quaternius_trees/tree_pine_a.glb", pine, "JunglePine", false)
	var birch_n := _stamp_mm(parent, "res://assets/quaternius_trees/tree_birch_a.glb", birch, "JungleBirch", false)
	var log_n := _stamp_mm(parent, "res://assets/kenney_nature/log.glb", logs, "JungleLogs", true)
	var st_n := _stamp_mm(parent, "res://assets/kenney_nature/stump_round.glb", stumps, "JungleStumps", true)
	var rk_n := _stamp_mm(parent, "res://assets/kenney_nature/rock_largeA.glb", rocks, "JungleRocks", true)
	_stamp_forest_places(parent)
	var chop_n := choppable_spots().size()
	var total := oak_n + pine_n + birch_n
	print("FOREST_PLAN edge=", n_edge, " dense=", n_dense, " ridge=", n_ridge, " hollow=", n_hollow, " shoulder=", n_shoulder, " decor=", total, " oak=", oak_n, " pine=", pine_n, " birch=", birch_n, " logs=", log_n, " stumps=", st_n, " rocks=", rk_n, " chop_rim=", chop_n, " trail=landing→缘→空地→shrine")
	print("JUNGLE_DECOR oak=", oak_n, " pine=", pine_n, " birch=", birch_n, " total=", total, " logs=", log_n, " stumps=", st_n, " rocks=", rk_n)


static func _plant_decor(dest: Array, occupied: Array, x: float, z: float, yaw: float, scl: float, village: Node, min_sep: float) -> bool:
	if not contains_v(Vector3(x, 0.0, z), 3.0):
		return false
	if on_trail(x, z, 3.2):
		return false
	if in_clearing(x, z, 0.92):
		return false
	if village and village.has_method("blocks") and village.blocks(Vector3(x, 0.0, z), 2.4):
		return false
	if village and village.has_method("on_road") and village.on_road(Vector3(x, 0.0, z), 1.4):
		return false
	for o in occupied:
		var p: Vector2 = o
		if Vector2(x - p.x, z - p.y).length() < min_sep:
			return false
	dest.append(_xf(Vector3(x, 0.0, z), yaw, scl))
	occupied.append(Vector2(x, z))
	return true


static func _stamp_unique(parent: Node3D, path: String, pos: Vector3, yaw: float, scl: float, name: String) -> Node3D:
	if not ResourceLoader.exists(path):
		print("forest missing ", path)
		return null
	var n: Node3D = (load(path) as PackedScene).instantiate()
	n.name = name
	n.position = Vector3(pos.x, height_at(pos.x, pos.z) + 0.02, pos.z)
	n.rotation.y = yaw
	n.scale = Vector3(scl, scl, scl)
	if "quaternius_trees" in path:
		Mats.dress_tree(n)
	else:
		Mats.polish_imported(n)
	parent.add_child(n)
	return n


static func _stamp_forest_places(parent: Node3D) -> void:
	# Landmark in the 空地: stone circle + one unique oak. The forest has a "place".
	_stamp_unique(parent, "res://assets/kenney_nature/path_stoneCircle.glb", Vector3(108.0, 0, 31.2), 0.18, 3.35, "ForestGladeCircle")
	_stamp_unique(parent, "res://assets/kenney_fantasy_town/pillar-stone.glb", Vector3(108.0, 0, 31.2), 0.0, 1.18, "ForestGladePillar")
	for i in 6:
		var a := float(i) * TAU / 6.0 + 0.18
		var sx := 108.0 + cos(a) * 3.40
		var sz := 31.2 + sin(a) * 3.10
		if on_trail(sx, sz, 2.35):
			continue
		var pk := "rock_tallA" if i % 2 == 0 else "rock_largeA"
		_stamp_unique(parent, "res://assets/kenney_nature/%s.glb" % pk, Vector3(sx, 0, sz), a, 2.10, "ForestGladeStone%d" % i)
	_stamp_unique(parent, "res://assets/quaternius_trees/tree_oak_d.glb", Vector3(112.6, 0, 33.8), 0.72, 2.48, "ForestGladeOak")

	# Dead-end shrine at the trail tip.
	_stamp_unique(parent, "res://assets/kenney_nature/path_stoneCircle.glb", Vector3(SHRINE_C.x, 0, SHRINE_C.y), 0.4, 2.15, "ForestShrineCircle")
	_stamp_unique(parent, "res://assets/kenney_fantasy_town/pillar-stone.glb", Vector3(154.0, 0, 43.2), 0.1, 1.25, "ForestShrinePillarN")
	_stamp_unique(parent, "res://assets/kenney_fantasy_town/pillar-stone.glb", Vector3(151.2, 0, 38.4), 1.1, 1.20, "ForestShrinePillarSW")
	_stamp_unique(parent, "res://assets/kenney_fantasy_town/pillar-stone.glb", Vector3(156.8, 0, 38.6), -0.8, 1.20, "ForestShrinePillarSE")
	_stamp_unique(parent, "res://assets/kenney_nature/rock_tallA.glb", Vector3(152.0, 0, 42.4), 0.5, 2.20, "ForestShrineRockA")
	_stamp_unique(parent, "res://assets/kenney_nature/rock_largeA.glb", Vector3(156.2, 0, 42.0), 1.2, 2.25, "ForestShrineRockB")
	_stamp_unique(parent, "res://assets/kenney_fantasy_town/lantern.glb", Vector3(153.2, 0, 41.6), 0.0, 1.0, "ForestShrineLantern")
	print("FOREST_PLACES glade=(108,31) oak=(112.6,33.8) shrine=(154,40)")
