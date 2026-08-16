extends CharacterBody3D

const Kaykit := preload("res://scripts/kaykit.gd")
const Island := preload("res://scripts/island.gd")

var max_hp := 55.0
var hp := 55.0
var speed := 3.15
var dead := false
var hurt := 0.0
var contact_cd := 0.0
var _mat: StandardMaterial3D
var _flash_mats: Array = []
var _base_albedos: Array = []
var _knock := Vector3.ZERO
var altar: Node3D
var player: Node3D
var role := "night"
var home := Vector3.ZERO
var leash := 7.2
var _base_color := Color(0.42, 0.16, 0.55)
var _model: Node3D
var _ap: AnimationPlayer
var _walk_clip := ""
var _idle_clip := ""
var spawn_tag := ""
var skel_kind := "warrior"
var _attack_clip := ""
var _attack_t := 0.0
var attack_cd := 0.0
var _kit := {}
var _slash: MeshInstance3D
var _slash_t := 0.0


func setup(pos: Vector3, p_altar: Node3D, p_player: Node3D, p_role: String = "night", p_kind: String = "") -> void:
	position = pos
	altar = p_altar
	player = p_player
	role = p_role
	home = pos
	if p_kind != "":
		skel_kind = p_kind
	collision_layer = 4
	collision_mask = 1
	add_to_group("enemies")
	if role == "guard":
		add_to_group("guards")
		max_hp = 34.0
		speed = 2.85
		_base_color = Color(0.52, 0.32, 0.20)
		spawn_tag = "guard"
	elif role == "dummy":
		add_to_group("dummies")
		max_hp = 80.0
		speed = 0.0
		_base_color = Color(0.55, 0.18, 0.62)
		spawn_tag = "dummy"
	elif role == "wild":
		add_to_group("wilds")
		max_hp = 42.0
		speed = 2.55
		leash = 9.5
		_base_color = Color(0.62, 0.58, 0.52)
		spawn_tag = "wild"
		if p_kind == "":
			skel_kind = "minion"
	else:
		if pos.x > 8.0:
			spawn_tag = "woods"
		elif pos.x < -8.0:
			spawn_tag = "shore"
		else:
			spawn_tag = "field"
		if p_kind == "":
			if spawn_tag == "woods":
				skel_kind = "rogue" if pos.z > 8.0 else "warrior"
			elif spawn_tag == "shore":
				skel_kind = "mage" if pos.z >= 0.0 else "minion"
			else:
				skel_kind = "warrior"
	hp = max_hp

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.35
	col.shape = cap
	col.position = Vector3(0, 0.7, 0)
	add_child(col)

	if not _attach_kaykit():
		_fallback_capsule()

	# glowing eyes + a small aura so night fog-shadows read in the dark
	var eye := SphereMesh.new()
	eye.radius = 0.055
	eye.height = 0.10
	var eye_col := Color(0.95, 0.72, 0.25) if role == "guard" else Color(1.0, 0.32, 0.48)
	var eye_mat := Mats.solid(eye_col, true, eye_col, 3.2)
	Mats.mesh(self, eye, eye_mat, Vector3(-0.10, 1.54, 0.20))
	Mats.mesh(self, eye, eye_mat, Vector3(0.10, 1.54, 0.20))
	if role != "guard" and role != "wild" and role != "dummy":
		var aura := SphereMesh.new()
		aura.radius = 0.20
		aura.height = 0.42
		var am := Mats.solid(Color(0.55, 0.18, 0.70, 0.32), true, Color(0.55, 0.12, 0.75), 1.4)
		am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		Mats.mesh(self, aura, am, Vector3(0.0, 0.95, 0.0))
		var ol := OmniLight3D.new()
		ol.position = Vector3(0.0, 1.2, 0.0)
		ol.light_color = Color(0.72, 0.28, 0.95)
		ol.light_energy = 1.15
		ol.omni_range = 3.6
		ol.shadow_enabled = false
		add_child(ol)

	print("enemy spawn role=", role, " tag=", spawn_tag, " pos=", Vector3(snappedf(pos.x, 0.1), snappedf(pos.y, 0.1), snappedf(pos.z, 0.1)))


func _attach_kaykit() -> bool:
	var inst: Node3D
	if role == "guard":
		inst = Kaykit.instantiate_id("knight")
	else:
		inst = Kaykit.instantiate_skel(skel_kind)
	if inst == null or inst.get_child_count() == 0:
		return false
	_model = inst
	add_child(_model)
	_model.rotation = Vector3.ZERO
	_model.position = Vector3.ZERO
	var h := 1.46 if skel_kind == "minion" else 1.68
	Kaykit.fit_height(_model, h)
	if role == "guard":
		_tint_model(_model, Color(0.70, 0.55, 0.40))
	else:
		# Cool bone, not the old purple-rogue wash.
		_tint_model(_model, Color(0.92, 0.88, 0.96))
	_ap = Kaykit.find_ap(_model)
	if _ap:
		_ap.active = true
		_idle_clip = Kaykit.first_clip(_ap, Kaykit.IDLE_CLIPS)
		var walks: Array = Kaykit.SKEL_WALK if role != "guard" else Kaykit.WALK_CLIPS
		_walk_clip = Kaykit.first_clip(_ap, walks)
		if role == "dummy" and _idle_clip != "":
			_ap.play(_idle_clip)
		elif _walk_clip != "":
			_ap.play(_walk_clip)
		elif _idle_clip != "":
			_ap.play(_idle_clip)
	if role != "guard":
		_kit = Kaykit.skel_kit(skel_kind)
		if _ap:
			_attack_clip = Kaykit.first_clip(_ap, _kit.get("atk", []))
		_make_slash()
	print("enemy model kind=", skel_kind if role != "guard" else "knight", " role=", role, " atk=", _attack_clip)
	return true


func _tint_model(root: Node, mul: Color) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var msh := mi.mesh
			if msh:
				for i in msh.get_surface_count():
					var mat := mi.get_active_material(i)
					if mat is StandardMaterial3D:
						var d: StandardMaterial3D = mat.duplicate()
						d.albedo_color = Color(d.albedo_color.r * mul.r, d.albedo_color.g * mul.g, d.albedo_color.b * mul.b, d.albedo_color.a)
						mi.set_surface_override_material(i, d)
						_flash_mats.append(d)
						_base_albedos.append(d.albedo_color)
		for c in n.get_children():
			stack.append(c)


func _fallback_capsule() -> void:
	_mat = Mats.solid(_base_color)
	var body := CapsuleMesh.new()
	body.radius = 0.4
	body.height = 1.2
	Mats.mesh(self, body, _mat, Vector3(0, 0.7, 0))
	var head := SphereMesh.new()
	head.radius = 0.32
	head.height = 0.5
	var head_col := Color(0.38, 0.22, 0.14) if role == "guard" else Color(0.28, 0.08, 0.38)
	Mats.mesh(self, head, Mats.solid(head_col), Vector3(0, 1.42, 0))
	_flash_mats.append(_mat)
	_base_albedos.append(_base_color)


func take_hit(amount: float, knock: Vector3) -> bool:
	if dead:
		return false
	hp -= amount
	hurt = 0.18
	_knock = knock
	_set_flash(Color(0.95, 0.55, 0.85) if role != "guard" else Color(0.95, 0.72, 0.45))
	if hp <= 0.0:
		_die()
		return true
	return false


func _set_flash(c: Color) -> void:
	for m in _flash_mats:
		if m is StandardMaterial3D:
			m.albedo_color = c


func _clear_flash() -> void:
	for i in _flash_mats.size():
		if _flash_mats[i] is StandardMaterial3D:
			_flash_mats[i].albedo_color = _base_albedos[i]


func _make_slash() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.92
	var mat := Mats.solid(Color(1.0, 0.45, 0.55, 0.0), true, Color(1.0, 0.35, 0.45), 2.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_slash = MeshInstance3D.new()
	_slash.mesh = torus
	_slash.material_override = mat
	_slash.rotation_degrees = Vector3(90, 0, 0)
	_slash.visible = false
	add_child(_slash)


func _flash_slash(radius: float) -> void:
	if _slash == null:
		return
	_slash.visible = true
	_slash_t = 0.22
	_slash.position = Vector3(0.0, 0.95, maxf(0.65, radius * 0.46))
	var sm := _slash.material_override as StandardMaterial3D
	if sm:
		sm.albedo_color = Color(1.0, 0.42, 0.52, 0.85)
	var s := clampf(radius / 1.7, 0.70, 1.7)
	_slash.scale = Vector3(s, 1.0, s)


func _die() -> void:
	dead = true
	collision_layer = 0
	collision_mask = 0
	if role == "wild":
		_drop_bone()
	var clip := ""
	if _ap:
		clip = Kaykit.first_clip(_ap, ["Death_C_Skeletons", "Death_A", "Death_B"])
	if clip != "":
		_ap.play(clip, 0.05)
		var leng := _ap.current_animation_length
		get_tree().create_timer(maxf(0.7, leng)).timeout.connect(queue_free)
	else:
		queue_free()


func _drop_bone() -> void:
	var ps := load("res://scripts/pickup.gd")
	if ps == null:
		return
	var drop: Node = ps.new()
	var host: Node = get_parent()
	if host == null:
		return
	host.add_child(drop)
	drop.setup(global_position + Vector3(0.15, 0.12, 0.1), "bone")


func _physics_process(delta: float) -> void:
	if dead:
		return
	if not GameState.is_live():
		Island.snap_feet(self)
		return
	contact_cd = maxf(0.0, contact_cd - delta)
	attack_cd = maxf(0.0, attack_cd - delta)
	_attack_t = maxf(0.0, _attack_t - delta)
	if hurt > 0.0:
		hurt -= delta
		if hurt <= 0.0:
			_clear_flash()
	if _slash_t > 0.0 and _slash:
		_slash_t = maxf(0.0, _slash_t - delta)
		var a := clampf(_slash_t / 0.20, 0.0, 1.0)
		var mat := _slash.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color.a = a * 0.70
		if _slash_t <= 0.0:
			_slash.visible = false

	var target := Vector3.ZERO
	if role == "dummy":
		target = global_position
	elif role == "guard" or role == "wild":
		target = home
		if player and is_instance_valid(player):
			var to_p := Vector3(player.global_position.x - global_position.x, 0, player.global_position.z - global_position.z)
			var from_home := Vector3(player.global_position.x - home.x, 0, player.global_position.z - home.z)
			var aggro := 8.2 if role == "guard" else 9.5
			if to_p.length() < aggro and from_home.length() < leash + 2.5:
				target = player.global_position
		var away := Vector3(global_position.x - home.x, 0, global_position.z - home.z)
		if away.length() > leash:
			target = home
	else:
		target = altar.global_position if altar else Vector3.ZERO
		var shrine := _nearest_shrine()
		if shrine:
			var ds := Vector3(shrine.global_position.x - global_position.x, 0, shrine.global_position.z - global_position.z).length()
			var da := Vector3(target.x - global_position.x, 0, target.z - global_position.z).length()
			if ds <= 7.5 or ds < da:
				target = shrine.global_position
		if player and is_instance_valid(player):
			var to_p := Vector3(player.global_position.x - global_position.x, 0, player.global_position.z - global_position.z)
			var to_t := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
			if to_p.length() < 9.0 and to_p.length() < to_t.length():
				target = player.global_position

	var to := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
	var dist := to.length()
	var hold := _want_attack(dist)
	# do not stall on a shrine / altar — walk in and smash
	if role != "guard" and role != "wild" and role != "dummy":
		if player == null or not is_instance_valid(player) or Vector3(target.x - player.global_position.x, 0, target.z - player.global_position.z).length() > 1.2:
			hold = false
	var dir := Vector3.ZERO if hold or dist <= 0.15 else to.normalized()
	if to.length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), delta * 6.0)

	_knock = _knock.move_toward(Vector3.ZERO, delta * 18.0)
	velocity.x = dir.x * speed + _knock.x
	velocity.z = dir.z * speed + _knock.z
	if not is_on_floor():
		velocity.y -= 28.0 * delta
	else:
		velocity.y = 0.0
	var pre := global_position
	move_and_slide()
	if dir != Vector3.ZERO:
		var moved := Vector3(global_position.x - pre.x, 0, global_position.z - pre.z).length()
		if moved < speed * delta * 0.22:
			var side := Vector3(-dir.z, 0, dir.x)
			if int(Time.get_ticks_msec() / 400) % 2 == 1:
				side = -side
			velocity.x = side.x * speed
			velocity.z = side.z * speed
			move_and_slide()
	Island.snap_feet(self)

	if role != "guard" and role != "wild" and role != "dummy":
		var hit_shrine := _nearest_shrine()
		if hit_shrine:
			var sd := Vector3(hit_shrine.global_position.x - global_position.x, 0, hit_shrine.global_position.z - global_position.z).length()
			if sd < 1.7:
				if hit_shrine.has_method("smash"):
					hit_shrine.smash()
				_die()
				return
		if altar and is_instance_valid(altar):
			var ad := Vector3(altar.global_position.x - global_position.x, 0, altar.global_position.z - global_position.z).length()
			if ad < 1.7:
				if altar.has_method("smash"):
					altar.smash()
				_die()
				return

	if _ap and _attack_t <= 0.0:
		if dir != Vector3.ZERO and _walk_clip != "":
			if _ap.current_animation != _walk_clip:
				_ap.play(_walk_clip, 0.12)
		elif _idle_clip != "" and _ap.current_animation != _idle_clip:
			_ap.play(_idle_clip, 0.16)

	if hold:
		_try_attack()

	if role == "guard" and player and is_instance_valid(player) and contact_cd <= 0.0:
		var d := Vector3(player.global_position.x - global_position.x, 0, player.global_position.z - global_position.z).length()
		if d < 1.15:
			player.take_hit(10.0)
			contact_cd = 0.85


func _want_attack(dist: float) -> bool:
	if role == "dummy" or role == "guard" or player == null or not is_instance_valid(player):
		return false
	if _kit.is_empty():
		return dist < 1.2
	var reach := float(_kit.get("range", 1.6))
	if str(_kit.get("kind", "melee")) == "proj":
		return dist < reach and dist > 1.35
	return dist < reach * 0.92


func _try_attack() -> void:
	if attack_cd > 0.0 or _kit.is_empty() or player == null:
		return
	attack_cd = float(_kit.get("cd", 1.0))
	if _ap and _attack_clip != "":
		_ap.play(_attack_clip, 0.06)
		_attack_t = _ap.current_animation_length if _ap.current_animation_length > 0.05 else 0.45
	var kind := str(_kit.get("kind", "melee"))
	if kind == "proj":
		_spawn_shot(str(_kit.get("proj", "orb")), float(_kit.get("dmg", 9.0)), float(_kit.get("knock", 1.6)))
		print("enemy_atk kind=", skel_kind, " proj=", _kit.get("proj"))
		return
	var radius := float(_kit.get("range", 1.7))
	_flash_slash(radius)
	_melee_hit(float(_kit.get("dmg", 10.0)), float(_kit.get("knock", 2.5)), radius, float(_kit.get("angle", 100.0)))
	print("enemy_atk kind=", skel_kind, " melee r=", snappedf(radius, 0.01))


func _melee_hit(dmg: float, knock: float, radius: float, angle_deg: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var to := Vector3(player.global_position.x - global_position.x, 0, player.global_position.z - global_position.z)
	var d := to.length()
	if d > radius:
		return
	var face := Vector3(sin(rotation.y), 0, cos(rotation.y))
	if d > 0.35:
		var ang := rad_to_deg(acos(clampf(to.normalized().dot(face), -1.0, 1.0)))
		if ang > angle_deg * 0.5:
			return
	player.take_hit(dmg)
	_knock = -face * 0.6


func _spawn_shot(kind: String, dmg: float, knock: float) -> void:
	var face := Vector3(sin(rotation.y), 0, cos(rotation.y))
	if player and is_instance_valid(player):
		var to := Vector3(player.global_position.x - global_position.x, 0, player.global_position.z - global_position.z)
		if to.length() > 0.05:
			face = to.normalized()
	var origin := global_position + Vector3(0, 1.28, 0) + face * 0.55
	var ps := load("res://scripts/projectile.gd")
	var p: Node3D = ps.new()
	var host: Node = get_parent()
	if host == null:
		host = self
	host.add_child(p)
	p.setup(kind, origin, face, dmg, knock, self, "player")

func _nearest_shrine() -> Node3D:
	var tree := get_tree()
	if tree == null:
		return null
	var best: Node3D = null
	var best_d := 999.0
	for s in tree.get_nodes_in_group("shrines"):
		if not is_instance_valid(s):
			continue
		if "broken" in s and s.broken:
			continue
		var d: float = Vector3(s.global_position.x - global_position.x, 0, s.global_position.z - global_position.z).length()
		if d < best_d:
			best_d = d
			best = s
	return best

