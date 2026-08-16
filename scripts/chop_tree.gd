extends StaticBody3D

signal felled

# Quaternius Ultimate Nature Pack — already metric (oaks ~5–6.4 m, pines ~7.5–10 m).
# Scale to ~8–10 m next to 2 m-grid Kenney cottages (NOT 2.5–4×; that would be 15–40 m giants).
const TREE_PATHS := [
	"res://assets/quaternius_trees/tree_oak_a.glb",
	"res://assets/quaternius_trees/tree_oak_b.glb",
	"res://assets/quaternius_trees/tree_oak_c.glb",
	"res://assets/quaternius_trees/tree_oak_d.glb",
	"res://assets/quaternius_trees/tree_pine_a.glb",
	"res://assets/quaternius_trees/tree_pine_b.glb",
	"res://assets/quaternius_trees/tree_pine_c.glb",
	"res://assets/quaternius_trees/tree_birch_a.glb",
	"res://assets/quaternius_trees/tree_birch_b.glb",
]
const TREE_SCALE := [1.55, 1.60, 1.50, 1.40, 1.20, 1.15, 0.95, 1.05, 0.95]

var max_work := 0.85
var work := 0.0
var is_down := false
var shake := 0.0
var _visual: Node3D
var _stump: Node3D
var _falling := false
var _fall_t := 0.0
var _fall_dir := 1.0


func setup(pos: Vector3) -> void:
	position = pos
	collision_layer = 1
	collision_mask = 0
	add_to_group("trees")

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.48
	cyl.height = 2.8
	col.shape = cyl
	col.position = Vector3(0, 1.4, 0)
	add_child(col)

	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var idx := int(absf(pos.x * 13.0 + pos.z * 7.0)) % TREE_PATHS.size()
	var path: String = TREE_PATHS[idx]
	var scl: float = float(TREE_SCALE[idx])
	if ResourceLoader.exists(path):
		var model: Node3D = (load(path) as PackedScene).instantiate()
		model.scale = Vector3(scl, scl, scl)
		model.rotation.y = fmod(pos.x * 1.7 + pos.z, TAU)
		_visual.add_child(model)
		Mats.dress_tree(model)
	else:
		_fallback_lollipop()

	_stump = Node3D.new()
	_stump.name = "Stump"
	_stump.visible = false
	add_child(_stump)
	var stump_path := "res://assets/kenney_nature/stump_round.glb"
	if ResourceLoader.exists(stump_path):
		var sm: Node3D = (load(stump_path) as PackedScene).instantiate()
		sm.scale = Vector3(2.6, 2.6, 2.6)
		_stump.add_child(sm)
		_paint_bark(sm)
	else:
		var stump := CylinderMesh.new()
		stump.top_radius = 0.3
		stump.bottom_radius = 0.34
		stump.height = 0.28
		stump.radial_segments = 8
		Mats.mesh(_stump, stump, Mats.tree_bark(), Vector3(0, 0.14, 0))


func _paint_bark(root: Node) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			(n as MeshInstance3D).material_override = Mats.tree_bark()
		for c in n.get_children():
			stack.append(c)


func _fallback_lollipop() -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.22
	trunk.bottom_radius = 0.32
	trunk.height = 2.1
	trunk.radial_segments = 8
	Mats.mesh(_visual, trunk, Mats.solid(Color(0.42, 0.26, 0.14)), Vector3(0, 1.05, 0))
	var canopy := SphereMesh.new()
	canopy.radius = 0.95
	canopy.height = 1.55
	Mats.mesh(_visual, canopy, Mats.solid(Color(0.22, 0.55, 0.24)), Vector3(0, 2.35, 0))


func chop(amount: float) -> bool:
	if is_down:
		return false
	var first := work <= 0.0
	work += amount
	shake = 0.18
	if first:
		Sfx.play("chop")
	if work >= max_work:
		_fell()
		return true
	return false


func _fell() -> void:
	is_down = true
	_falling = true
	_fall_t = 0.0
	_fall_dir = 1.0 if fmod(absf(position.x) * 10.0, 2.0) < 1.0 else -1.0
	if _stump:
		_stump.visible = true
	var col := get_node_or_null("CollisionShape3D")
	if col:
		col.disabled = true
	_drop_log()
	felled.emit()
	Sfx.play("chop")
	print("tree_fell at ", Vector3(snappedf(position.x, 0.1), 0, snappedf(position.z, 0.1)))


func _drop_log() -> void:
	var ps := load("res://scripts/pickup.gd")
	if ps == null:
		return
	var drop: Node = ps.new()
	var host := get_parent()
	if host == null:
		host = self
	host.add_child(drop)
	var off := Vector3(_fall_dir * 0.85, 0.15, 0.25)
	drop.setup(global_position + off, "wood")


func reset_tree() -> void:
	is_down = false
	_falling = false
	_fall_t = 0.0
	work = 0.0
	shake = 0.0
	_visual.visible = true
	_visual.rotation = Vector3.ZERO
	if _stump:
		_stump.visible = false
	var col := get_child(0) as CollisionShape3D
	if col:
		col.disabled = false


func _process(delta: float) -> void:
	if _falling and _visual:
		_fall_t += delta
		var k := clampf(_fall_t / 0.58, 0.0, 1.0)
		var ease := k * k
		_visual.rotation_degrees.z = _fall_dir * 86.0 * ease
		if k >= 1.0:
			_falling = false
			_visual.rotation_degrees.z = _fall_dir * 86.0
		return
	if shake > 0.0 and _visual and not is_down:
		shake = maxf(0.0, shake - delta * 1.6)
		_visual.rotation_degrees.z = sin(Time.get_ticks_msec() * 0.04) * shake * 18.0
	elif _visual and not is_down:
		_visual.rotation_degrees.z = move_toward(_visual.rotation_degrees.z, 0.0, delta * 40.0)
