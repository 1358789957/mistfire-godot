extends StaticBody3D

const RADIUS := 5.05
const DOT := 12.0
const DOT_INT := 0.34

var ghost := false
var place_ok := true
var yaw := 0.0
var _dot_t := 0.0
var _pulse := 0.0
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _body_mats: Array = []
var _flame: Node3D
var _light: OmniLight3D
var last_embers: int = 0
var shot_n: int = 0
var last_place_flash: bool = false
var place_flash_t: float = 0.0


func setup(pos: Vector3, p_yaw: float = 0.0, as_ghost: bool = false) -> void:
	position = pos
	yaw = p_yaw
	rotation.y = yaw
	ghost = as_ghost
	collision_layer = 0 if as_ghost else 1
	collision_mask = 0
	if not as_ghost:
		add_to_group("towers")

	if not as_ghost:
		var col := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.55
		cyl.height = 1.6
		col.shape = cyl
		col.position = Vector3(0, 0.8, 0)
		add_child(col)

	var stone := Mats.solid(Color(0.46, 0.32, 0.22) if as_ghost else Color(0.50, 0.34, 0.22))
	_body_mats.append(stone)
	var base := CylinderMesh.new()
	base.top_radius = 0.72
	base.bottom_radius = 0.82
	base.height = 0.28
	base.radial_segments = 10
	Mats.mesh(self, base, stone, Vector3(0, 0.14, 0))

	var brick := Mats.solid(Color(0.62, 0.28, 0.16) if as_ghost else Color(0.70, 0.30, 0.16))
	_body_mats.append(brick)
	var mid := CylinderMesh.new()
	mid.top_radius = 0.42
	mid.bottom_radius = 0.58
	mid.height = 1.05
	mid.radial_segments = 8
	Mats.mesh(self, mid, brick, Vector3(0, 0.78, 0))

	# a small "door" so rotate is readable
	var door := BoxMesh.new()
	door.size = Vector3(0.28, 0.42, 0.08)
	Mats.mesh(self, door, Mats.solid(Color(0.22, 0.12, 0.08)), Vector3(0, 0.55, -0.52))

	var rim := CylinderMesh.new()
	rim.top_radius = 0.52
	rim.bottom_radius = 0.46
	rim.height = 0.16
	rim.radial_segments = 8
	Mats.mesh(self, rim, stone, Vector3(0, 1.32, 0))

	_flame = Node3D.new()
	add_child(_flame)
	var core := SphereMesh.new()
	core.radius = 0.22
	core.height = 0.4
	Mats.mesh(_flame, core, Mats.solid(Color(1.0, 0.88, 0.4), true, Color(1.0, 0.7, 0.2), 2.2), Vector3(0, 1.62, 0))
	var outer := SphereMesh.new()
	outer.radius = 0.34
	outer.height = 0.62
	Mats.mesh(_flame, outer, Mats.solid(Color(1.0, 0.42, 0.1, 0.92), true, Color(1.0, 0.3, 0.05), 1.8), Vector3(0, 1.78, 0))

	_ring_mat = Mats.solid(Color(1.0, 0.45, 0.12, 0.22), true, Color(1.0, 0.35, 0.08), 0.8)
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ring := CylinderMesh.new()
	ring.top_radius = RADIUS
	ring.bottom_radius = RADIUS
	ring.height = 0.06
	ring.radial_segments = 20
	_ring = Mats.mesh(self, ring, _ring_mat, Vector3(0, 0.08, 0))

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.5, 0.18)
	_light.light_energy = 0.0 if as_ghost else 2.4
	_light.omni_range = 8.5
	_light.position = Vector3(0, 2.0, 0)
	add_child(_light)

	if as_ghost:
		_set_ghost_tint(true)
	elif GameState.rune_id == "precise":
		# teal rim so 精密 towers read as the measured pair, not a silent buff
		if _ring_mat:
			_ring_mat.albedo_color = Color(0.22, 0.82, 0.72, 0.24)
			_ring_mat.emission = Color(0.18, 0.72, 0.64)


func set_place_ok(ok: bool) -> void:
	place_ok = ok
	if ghost:
		_set_ghost_tint(ok)


func _set_ghost_tint(ok: bool) -> void:
	var c := Color(0.25, 0.85, 0.4, 0.38) if ok else Color(0.9, 0.2, 0.18, 0.4)
	if _ring_mat:
		_ring_mat.albedo_color = c
		_ring_mat.emission = c
	for m in _body_mats:
		if m:
			m.albedo_color = c
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func flash_place() -> void:
	last_place_flash = true
	place_flash_t = 0.42
	if _light:
		_light.light_energy = 6.4
	if _ring_mat:
		var c := Color(0.32, 0.95, 0.86, 0.62) if GameState.rune_id == "precise" else Color(1.0, 0.72, 0.28, 0.55)
		_ring_mat.albedo_color = c
		_ring_mat.emission = c
	if _flame:
		_flame.scale = Vector3(1.55, 1.65, 1.55)
	print("place_flash tower")


func _process(delta: float) -> void:
	if ghost:
		return
	_pulse += delta * 5.5
	if place_flash_t > 0.0:
		place_flash_t = maxf(0.0, place_flash_t - delta)
		var u: float = place_flash_t / 0.42
		if _light:
			_light.light_energy = 2.2 + 4.2 * u
		if _ring_mat:
			_ring_mat.albedo_color.a = 0.16 + 0.46 * u
	else:
		if _flame:
			var s := 1.0 + sin(_pulse) * 0.1
			_flame.scale = Vector3(s, 1.0 + sin(_pulse * 1.4) * 0.14, s)
		if _light:
			_light.light_energy = 2.2 + sin(_pulse * 1.6) * 0.45
		if _ring_mat:
			_ring_mat.albedo_color.a = 0.16 + sin(_pulse) * 0.05

	if GameState.phase != GameState.Phase.NIGHT:
		return
	_dot_t += delta
	var gap: float = GameState.tower_interval()
	if _dot_t < gap:
		return
	_dot_t = 0.0
	var tree := get_tree()
	if tree == null:
		return
	var best: Node = null
	var best_d := RADIUS
	for e in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead:
			continue
		if e.is_in_group("guards"):
			continue
		var d: float = Vector3(e.global_position.x - global_position.x, 0, e.global_position.z - global_position.z).length()
		if d <= best_d:
			best_d = d
			best = e
	if best:
		_shoot(best)


func _spawn_ember(origin: Vector3, dir: Vector3) -> void:
	var ps := load("res://scripts/projectile.gd")
	var bolt: Node3D = ps.new()
	var host: Node = get_parent()
	if host == null:
		host = self
	host.add_child(bolt)
	bolt.setup("ember", origin, dir, DOT, 1.1, self, "enemy")


func _shoot(e: Node) -> void:
	var origin := global_position + Vector3(0.0, 1.72, 0.0)
	var dest: Vector3 = e.global_position + Vector3(0.0, 0.9, 0.0)
	var dir: Vector3 = dest - origin
	dir.y = 0.0
	if dir.length() < 0.05:
		dir = Vector3(0, 0, 1)
	dir = dir.normalized()
	var n: int = GameState.tower_embers()
	last_embers = n
	shot_n += 1
	_spawn_ember(origin, dir)
	if n >= 2:
		var side: Vector3 = dir.cross(Vector3.UP)
		if side.length() < 0.01:
			side = Vector3(1.0, 0.0, 0.0)
		side = side.normalized()
		var dir2: Vector3 = (dir + side * 0.28).normalized()
		_spawn_ember(origin + side * 0.32, dir2)
	Sfx.play("ember")
	if _flame:
		_flame.scale = Vector3(1.45, 1.55, 1.45)
	if _light:
		_light.light_energy = 4.2
	print("tower_shot embers=", n, " at ", e.global_position)
