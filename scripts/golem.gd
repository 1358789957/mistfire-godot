extends CharacterBody3D

const FOLLOW := 4.6
const CHOP_RATE := 0.26

var master: Node3D
var _chopping: Node3D
var _bob := 0.0


func setup(p_master: Node3D) -> void:
	master = p_master
	collision_layer = 0
	collision_mask = 1
	add_to_group("golem")
	if master:
		position = master.global_position + Vector3(-1.2, 0.0, 0.8)
		position.y = 0.7

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.55, 0.85, 0.5)
	col.shape = box
	col.position = Vector3(0, 0.45, 0)
	add_child(col)

	var brass := Mats.solid(Color(0.78, 0.52, 0.18))
	var dark := Mats.solid(Color(0.42, 0.28, 0.10))
	var body := BoxMesh.new()
	body.size = Vector3(0.52, 0.62, 0.44)
	Mats.mesh(self, body, brass, Vector3(0, 0.48, 0))
	var head := BoxMesh.new()
	head.size = Vector3(0.36, 0.28, 0.32)
	Mats.mesh(self, head, brass.duplicate() if false else Mats.solid(Color(0.86, 0.60, 0.22)), Vector3(0, 0.92, 0))
	var eye := BoxMesh.new()
	eye.size = Vector3(0.16, 0.08, 0.06)
	Mats.mesh(self, eye, Mats.solid(Color(1.0, 0.85, 0.35), true, Color(1.0, 0.7, 0.2), 1.6), Vector3(0, 0.94, -0.16))
	var arm := BoxMesh.new()
	arm.size = Vector3(0.14, 0.42, 0.14)
	Mats.mesh(self, arm, dark, Vector3(0.36, 0.5, 0))
	Mats.mesh(self, arm, dark, Vector3(-0.36, 0.5, 0))


func _physics_process(delta: float) -> void:
	if not GameState.is_live() or master == null or not is_instance_valid(master):
		velocity = Vector3.ZERO
		return
	_bob += delta * 5.0

	var target_tree: Node3D = null
	if GameState.phase == GameState.Phase.DAY:
		var best := 10.0
		for t in get_tree().get_nodes_in_group("trees"):
			if t.is_down:
				continue
			var d: float = Vector3(t.global_position.x - global_position.x, 0, t.global_position.z - global_position.z).length()
			if d < best:
				best = d
				target_tree = t

	var dest := master.global_position + Vector3(-1.15, 0, 0.85)
	if target_tree and Vector3(target_tree.global_position.x - global_position.x, 0, target_tree.global_position.z - global_position.z).length() < 9.0:
		dest = target_tree.global_position

	var to := Vector3(dest.x - global_position.x, 0, dest.z - global_position.z)
	var dist := to.length()
	var dir := to.normalized() if dist > 0.12 else Vector3.ZERO
	if dir != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), delta * 7.0)

	var spd := FOLLOW
	if target_tree and dist < 1.85:
		spd = 0.15
		if target_tree.chop(CHOP_RATE * delta):
			if master.has_method("grant_wood"):
				master.grant_wood(1)
		# tiny chop bob
		position.y = 0.7 + abs(sin(_bob * 2.2)) * 0.05
	else:
		position.y = 0.7 + sin(_bob) * 0.03

	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	if not is_on_floor():
		velocity.y -= 28.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
