extends Node3D
## Walk-over drop: wood log or bone.

var kind := "wood"
var _spin := 0.0
var taken := false


func setup(pos: Vector3, p_kind: String = "wood") -> void:
	kind = p_kind
	global_position = pos
	add_to_group("pickups")
	if kind == "bone":
		var box := BoxMesh.new()
		box.size = Vector3(0.16, 0.12, 0.55)
		Mats.mesh(self, box, Mats.solid(Color(0.90, 0.86, 0.78)), Vector3(0, 0.12, 0))
		var knob := SphereMesh.new()
		knob.radius = 0.09
		knob.height = 0.16
		Mats.mesh(self, knob, Mats.solid(Color(0.86, 0.82, 0.74)), Vector3(0, 0.12, 0.24))
	else:
		var log := CylinderMesh.new()
		log.top_radius = 0.12
		log.bottom_radius = 0.14
		log.height = 0.72
		log.radial_segments = 7
		var mi := Mats.mesh(self, log, Mats.tree_bark(), Vector3(0, 0.14, 0))
		mi.rotation_degrees = Vector3(0, 0, 90)


func _process(delta: float) -> void:
	if taken:
		return
	_spin += delta
	rotation.y += delta * 1.6
	position.y += sin(_spin * 3.2) * 0.002
	var p := get_tree().get_first_node_in_group("player")
	if p == null or not is_instance_valid(p):
		return
	var d := Vector3(p.global_position.x - global_position.x, 0, p.global_position.z - global_position.z).length()
	if d < 1.25:
		_collect(p)


func _collect(p: Node) -> void:
	taken = true
	if kind == "wood" and p.has_method("grant_wood"):
		p.grant_wood(1)
	elif kind == "bone" and p.has_method("grant_wood"):
		p.grant_wood(1)
	Sfx.play("pickup")
	print("pickup ", kind, " at ", global_position)
	queue_free()
