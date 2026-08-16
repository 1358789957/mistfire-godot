extends StaticBody3D

const CHEST_PATH := "res://assets/kaykit_dungeon/chest.glb"
const CHEST_GOLD := "res://assets/kaykit_dungeon/chest_gold.glb"

var opened: bool = false
var _lid: Node3D
var _visual: Node3D


func setup(pos: Vector3) -> void:
	global_position = pos
	collision_layer = 1
	collision_mask = 0
	add_to_group("chests")
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 0.7, 0.62)
	col.shape = box
	col.position = Vector3(0, 0.35, 0)
	add_child(col)

	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var kay := _attach_kaykit()
	if not kay:
		_fallback_box()
	_lid = _find_lid(_visual)
	if _lid == null:
		_lid = _visual
	print("chest kaykit=", "yes" if kay else "no", " lid=", "node" if _lid != _visual else "fallback-visual", " at ", global_position)


func _attach_kaykit() -> bool:
	var path := CHEST_PATH if ResourceLoader.exists(CHEST_PATH) else CHEST_GOLD
	if not ResourceLoader.exists(path):
		return false
	var model: Node3D = (load(path) as PackedScene).instantiate()
	model.scale = Vector3(1.15, 1.15, 1.15)
	_visual.add_child(model)
	Mats.polish_imported(model)
	return true


func _fallback_box() -> void:
	var body := BoxMesh.new()
	body.size = Vector3(0.86, 0.42, 0.56)
	Mats.mesh(_visual, body, Mats.solid(Color(0.62, 0.22, 0.16)), Vector3(0, 0.24, 0))
	var band := BoxMesh.new()
	band.size = Vector3(0.90, 0.08, 0.58)
	Mats.mesh(_visual, band, Mats.solid(Color(0.78, 0.62, 0.22)), Vector3(0, 0.42, 0))
	var lid := BoxMesh.new()
	lid.size = Vector3(0.86, 0.12, 0.56)
	Mats.mesh(_visual, lid, Mats.solid(Color(0.70, 0.26, 0.16)), Vector3(0, 0.52, 0))


func try_open() -> bool:
	if opened:
		return false
	opened = true
	if _lid:
		_lid.position.y += 0.16
		_lid.scale = Vector3(1.04, 1.12, 1.04)
		_lid.rotation_degrees.x = -28.0
	var ps := load("res://scripts/pickup.gd")
	for i in 3:
		var drop: Node = ps.new()
		get_parent().add_child(drop)
		var a := (float(i) - 1.0) * 0.45
		drop.setup(global_position + Vector3(a, 0.2, 0.55), "wood")
	Sfx.play("chest")
	print("chest_open at ", global_position)
	return true


func _find_lid(root: Node) -> Node3D:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var nm := String(n.name).to_lower()
		if "lid" in nm and n is Node3D:
			return n
		for c in n.get_children():
			stack.append(c)
	return null
