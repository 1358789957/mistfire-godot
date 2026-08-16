extends CharacterBody3D

const FOLLOW := 4.6
const CHOP_RATE := 0.26
const TREE_LEASH := 14.0
const FOE_RANGE := 8.0
const HIT_REACH := 1.75
const HIT_DMG := 12.0
const HIT_KNOCK := 2.8
const HIT_CD := 0.72


var master: Node3D
var _bob := 0.0
var _atk_cd := 0.0
var _swing := 0.0
var last_hit_at := 0.0
var _arm: MeshInstance3D
var _eye_mat: StandardMaterial3D
var _glow: OmniLight3D


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

	var brass: StandardMaterial3D = Mats.solid(Color(0.78, 0.52, 0.18))
	brass.metallic = 0.52
	brass.roughness = 0.40
	var dark: StandardMaterial3D = Mats.solid(Color(0.42, 0.28, 0.10))
	dark.metallic = 0.35
	var head_mat: StandardMaterial3D = Mats.solid(Color(0.86, 0.60, 0.22))
	head_mat.metallic = 0.48
	head_mat.roughness = 0.38
	_eye_mat = Mats.solid(Color(1.0, 0.85, 0.35), true, Color(1.0, 0.7, 0.2), 1.6)

	var body := BoxMesh.new()
	body.size = Vector3(0.52, 0.62, 0.44)
	Mats.mesh(self, body, brass, Vector3(0, 0.48, 0))
	var head := BoxMesh.new()
	head.size = Vector3(0.36, 0.28, 0.32)
	Mats.mesh(self, head, head_mat, Vector3(0, 0.92, 0))
	var visor := BoxMesh.new()
	visor.size = Vector3(0.30, 0.07, 0.08)
	Mats.mesh(self, visor, dark, Vector3(0, 0.96, -0.14))
	var eye := BoxMesh.new()
	eye.size = Vector3(0.16, 0.08, 0.06)
	Mats.mesh(self, eye, _eye_mat, Vector3(0, 0.94, -0.16))
	var arm_l := BoxMesh.new()
	arm_l.size = Vector3(0.14, 0.42, 0.14)
	Mats.mesh(self, arm_l, dark, Vector3(-0.36, 0.5, 0))
	var arm_r := BoxMesh.new()
	arm_r.size = Vector3(0.16, 0.52, 0.16)
	_arm = Mats.mesh(self, arm_r, dark, Vector3(0.36, 0.5, 0))

	_glow = OmniLight3D.new()
	_glow.position = Vector3(0.0, 1.05, -0.12)
	_glow.light_color = Color(1.0, 0.72, 0.28)
	_glow.light_energy = 0.0
	_glow.omni_range = 2.4
	_glow.shadow_enabled = false
	add_child(_glow)


func _physics_process(delta: float) -> void:
	if master == null or not is_instance_valid(master):
		velocity = Vector3.ZERO
		return
	_bob += delta * 5.0
	_atk_cd = maxf(0.0, _atk_cd - delta)
	_swing = maxf(0.0, _swing - delta)
	_pose_arm()
	_sync_night_look()

	# Dawn overlay: stay in the world (do not queue_free). Idle bob only.
	if not GameState.is_live():
		velocity = Vector3.ZERO
		position.y = 0.7 + sin(_bob) * 0.03
		return

	var dest: Vector3 = master.global_position + Vector3(-1.15, 0, 0.85)
	var chopping := false
	var fighting := false
	if GameState.phase == GameState.Phase.DAY:
		var target_tree: Node3D = _nearest_day_tree()
		if target_tree:
			dest = target_tree.global_position
			var td: float = _xz(target_tree)
			if td < 1.85:
				chopping = true
				dest = global_position
				if target_tree.has_method("chop") and target_tree.chop(CHOP_RATE * delta):
					if master.has_method("grant_wood"):
						master.grant_wood(1)
				_pulse_swing()
	elif GameState.phase == GameState.Phase.NIGHT:
		var foe: Node3D = _nearest_night_foe()
		if foe:
			dest = foe.global_position
			var fd: float = _xz(foe)
			if fd < HIT_REACH:
				fighting = true
				dest = global_position
				_try_hit(foe)

	var to: Vector3 = Vector3(dest.x - global_position.x, 0, dest.z - global_position.z)
	var dist: float = to.length()
	var dir: Vector3 = to.normalized() if dist > 0.12 else Vector3.ZERO
	if dir != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), delta * 7.0)

	var spd: float = FOLLOW
	if chopping or fighting:
		spd = 0.15
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


func _xz(n: Node3D) -> float:
	return Vector3(n.global_position.x - global_position.x, 0, n.global_position.z - global_position.z).length()


func _nearest_day_tree() -> Node3D:
	if master == null or not is_instance_valid(master):
		return null
	var scene := get_tree()
	if scene == null:
		return null
	var best: Node3D = null
	var best_d := 999.0
	var nodes: Array = scene.get_nodes_in_group("trees")
	for n in nodes:
		var t: Node3D = n as Node3D
		if t == null or not is_instance_valid(t):
			continue
		if t.is_down:
			continue
		var from_player: float = Vector3(t.global_position.x - master.global_position.x, 0, t.global_position.z - master.global_position.z).length()
		if from_player > TREE_LEASH:
			continue
		var from_me: float = _xz(t)
		if from_me < best_d:
			best_d = from_me
			best = t
	return best


func _nearest_night_foe() -> Node3D:
	var scene := get_tree()
	if scene == null:
		return null
	var best: Node3D = null
	var best_d := FOE_RANGE
	var nodes: Array = scene.get_nodes_in_group("enemies")
	for n in nodes:
		var e: Node3D = n as Node3D
		if e == null or not is_instance_valid(e):
			continue
		if e.is_in_group("guards") or e.is_in_group("wilds") or e.is_in_group("dummies"):
			continue
		if e.dead:
			continue
		var d: float = _xz(e)
		if d < best_d:
			best_d = d
			best = e
	return best


func _try_hit(foe: Node3D) -> void:
	if _atk_cd > 0.0 or foe == null or not is_instance_valid(foe):
		return
	if not foe.has_method("take_hit"):
		return
	_atk_cd = HIT_CD
	_swing = 0.28
	last_hit_at = Time.get_ticks_msec() * 0.001
	var knock: Vector3 = Vector3(foe.global_position.x - global_position.x, 0, foe.global_position.z - global_position.z)
	if knock.length() < 0.05:
		knock = Vector3(sin(rotation.y), 0, cos(rotation.y))
	else:
		knock = knock.normalized()
	foe.take_hit(HIT_DMG, knock * HIT_KNOCK)
	Sfx.play("hit")
	print("golem_hit dmg=", HIT_DMG)


func _pulse_swing() -> void:
	if _swing <= 0.08:
		_swing = 0.20


func _pose_arm() -> void:
	if _arm == null:
		return
	var k: float = clampf(_swing / 0.22, 0.0, 1.0)
	_arm.rotation.x = -sin(k * PI) * 1.45
	_arm.position = Vector3(0.36, 0.50 + k * 0.10, -k * 0.22)


func _sync_night_look() -> void:
	var night: bool = GameState.phase == GameState.Phase.NIGHT
	if _eye_mat:
		_eye_mat.emission_energy_multiplier = 3.6 if night else 1.6
	if _glow:
		_glow.light_energy = 1.15 if night else 0.0
