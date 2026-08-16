extends CharacterBody3D

const Kaykit := preload("res://scripts/kaykit.gd")
const Island := preload("res://scripts/island.gd")

signal died
signal wood_gained
signal chopped_tree
signal attacked
signal core_saved
signal power_struck(killed: bool)

const SPEED := 7.2
const LIFE_MAX_HP := 120.0
const LIFE_INCOMING := 0.85
const LIFE_SLIVER := 12.0
const LIFE_OOC_REGEN := 3.6
const LIFE_NET_REGEN := 1.6
const LIFE_NET_R := 5.2
const POWER_DMG := 1.90
const POWER_CD := 0.76
const POWER_KNOCK := 1.35
const POWER_RANGE := 1.12
const POWER_NIGHT_SPD := 1.10
const POWER_HASTE_SPD := 1.16
const POWER_HASTE_T := 2.6
const POWER_KILL_HEAL := 8.0

var rune_id := "power"
var character_id := "knight"
var max_hp := 80.0
var hp := 80.0
var wood := 0
var attack_cd := 0.0
var chop_target: Node3D
var facing := Vector3(0, 0, -1)
var invuln := 0.0
var shield_charges := 0
var shield_cd := 0.0
var _orb: MeshInstance3D
var _slash: MeshInstance3D
var _slash_t := 0.0
var cam_yaw := 0.35
var kill_haste := false
var kill_haste_t := 0.0
var combat_t := 8.0
var core_save_ready := true
var last_core_save := false
var last_hurt_pulse := false
var last_kill_burst := false
var last_heavy := false
var last_kill_heal := 0.0
var heal_pulse_t := 0.0
var near_life_net := false
var _heal_ring: MeshInstance3D
var _heal_ring_mat: StandardMaterial3D
var _life_net_light: OmniLight3D
var _burst_t := 0.0
var _burst_ring: MeshInstance3D
var _burst_mat: StandardMaterial3D
var _burst_light: OmniLight3D

var _model: Node3D
var _ap: AnimationPlayer
var _idle_clip := ""
var _walk_clip := ""
var _run_clip := ""
var _attack_clip := ""
var _chop_clip := ""
var _anim := ""
var _attack_t := 0.0
var _visual_scale := 1.0
var _use_slash_fallback := true

var _stab2_t := -1.0
var _stab2_dmg := 0.0
var _stab2_knock := 0.0
var _stab2_range := 1.6
var _stab2_angle := 90.0

# last swing, for verify / HUD
var atk_kind := ""
var atk_range := 0.0
var atk_hits := 0


func setup(id: String) -> void:
	rune_id = id
	character_id = GameState.character_id
	if character_id.is_empty() or not GameState.CHARACTERS.has(character_id):
		character_id = "knight"
		GameState.character_id = "knight"
	collision_layer = 2
	collision_mask = 1
	add_to_group("player")
	position = Vector3(7.5, Island.foot_y(7.5, 8.2, 0.9), 8.2)
	floor_snap_length = 1.15
	floor_max_angle = deg_to_rad(52.0)
	safe_margin = 0.08
	kill_haste = false
	kill_haste_t = 0.0
	combat_t = 8.0
	core_save_ready = true
	last_core_save = false
	last_hurt_pulse = false
	last_kill_burst = false
	last_heavy = false
	last_kill_heal = 0.0
	heal_pulse_t = 0.0
	near_life_net = false
	_burst_t = 0.0

	match rune_id:
		"life":
			max_hp = LIFE_MAX_HP
		"puppet":
			max_hp = 80.0
			shield_charges = 1
		_:
			max_hp = 80.0
	hp = max_hp

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.55
	col.shape = cap
	col.position = Vector3(0, 0.78, 0)
	add_child(col)

	_attach_kaykit()

	if rune_id == "puppet":
		var orb_mesh := SphereMesh.new()
		orb_mesh.radius = 0.16
		orb_mesh.height = 0.32
		_orb = Mats.mesh(self, orb_mesh, Mats.solid(Color(0.95, 0.72, 0.28), true, Color(1.0, 0.7, 0.2), 1.4), Vector3(0.7, 1.3, 0.0))

	# small rune-tinted shoulder gem — does not recolor the whole adventurer
	var gem := SphereMesh.new()
	gem.radius = 0.07
	gem.height = 0.14
	var gc: Color = GameState.rune_color(rune_id)
	Mats.mesh(self, gem, Mats.solid(gc, true, gc, 1.1), Vector3(0.22, 1.28, 0.06))
	if rune_id == "life":
		_make_life_fx()
	if rune_id == "power":
		_make_power_fx()

	var slash_mesh := CylinderMesh.new()
	slash_mesh.top_radius = 1.0
	slash_mesh.bottom_radius = 1.0
	slash_mesh.height = 0.08
	slash_mesh.radial_segments = 16
	var slash_mat := Mats.solid(Color(1.0, 0.85, 0.4, 0.0), true, Color(1.0, 0.6, 0.2), 2.0)
	slash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_slash = Mats.mesh(self, slash_mesh, slash_mat, Vector3(0, 0.95, 0.9))
	_slash.visible = false


func _attach_kaykit() -> void:
	_model = Kaykit.instantiate_id(character_id)
	add_child(_model)
	# KayKit rest faces +Z; player yaw 0 also faces +Z. No extra yaw.
	_model.rotation = Vector3.ZERO
	_model.position = Vector3.ZERO
	_visual_scale = Kaykit.fit_height(_model, Kaykit.TARGET_H)
	# Scale is about the origin. If soles are not at local y=0, slide the visual so they are.
	var aabb := Kaykit.local_body_aabb(_model)
	if aabb.size.y > 0.08:
		_model.position.y = -aabb.position.y * _model.scale.y
		print("player feet plant aabb_min_y=", snappedf(aabb.position.y, 0.001), " model.y=", snappedf(_model.position.y, 0.001))
	_ap = Kaykit.find_ap(_model)
	if _ap:
		_ap.active = true
		_idle_clip = Kaykit.first_clip(_ap, Kaykit.IDLE_CLIPS)
		_walk_clip = Kaykit.first_clip(_ap, Kaykit.WALK_CLIPS)
		_run_clip = Kaykit.first_clip(_ap, Kaykit.RUN_CLIPS)
		_attack_clip = Kaykit.first_clip(_ap, Kaykit.attack_clips_for(character_id))
		_chop_clip = Kaykit.first_clip(_ap, ["1H_Melee_Attack_Chop", "2H_Melee_Attack_Chop", "1H_Melee_Attack_Slice_Horizontal", "1H_Melee_Attack_Stab"])
		if _chop_clip == "":
			_chop_clip = _attack_clip
		_use_slash_fallback = _attack_clip.is_empty()
		if _idle_clip != "":
			_ap.play(_idle_clip)
			_ap.advance(0.25)
			_anim = _idle_clip
		print("player kaykit id=", character_id,
			" scale=", snappedf(_visual_scale, 0.001),
			" idle=", _idle_clip,
			" walk=", _walk_clip,
			" run=", _run_clip,
			" attack=", _attack_clip,
			" chop=", _chop_clip)
	else:
		_use_slash_fallback = true
		print("player kaykit: no AnimationPlayer on ", character_id)


func kit() -> Dictionary:
	var k := {
		"id": character_id,
		"kind": "melee",
		"range": 2.2,
		"angle": 110.0,
		"dmg": 24.0,
		"knock": 3.2,
		"cd": 0.48,
		"ticks": 1,
		"tick_gap": 0.0,
		"proj": "",
	}
	match character_id:
		"barbarian":
			k["range"] = 2.8
			k["angle"] = 140.0
			k["dmg"] = 42.0
			k["knock"] = 9.0
			k["cd"] = 0.80
		"mage":
			k["kind"] = "proj"
			k["range"] = 14.0
			k["angle"] = 12.0
			k["dmg"] = 22.0
			k["knock"] = 1.6
			k["cd"] = 0.56
			k["proj"] = "orb"
		"rogue":
			k["range"] = 1.6
			k["angle"] = 90.0
			k["dmg"] = 13.0
			k["knock"] = 2.2
			k["cd"] = 0.28
			k["ticks"] = 2
			k["tick_gap"] = 0.14
		"rogue_hooded":
			k["kind"] = "proj"
			k["range"] = 16.0
			k["angle"] = 8.0
			k["dmg"] = 32.0
			k["knock"] = 2.6
			k["cd"] = 0.70
			k["proj"] = "bolt"
		_:
			pass
	if rune_id == "power":
		k["dmg"] = float(k["dmg"]) * POWER_DMG
		k["knock"] = float(k["knock"]) * POWER_KNOCK
		k["cd"] = float(k["cd"]) * POWER_CD
		if str(k["kind"]) == "melee":
			k["range"] = float(k["range"]) * POWER_RANGE
	if rune_id == "precise":
		k["cd"] = float(k["cd"]) * 0.70
	return k


func is_melee() -> bool:
	return str(kit()["kind"]) == "melee"


func move_speed() -> float:
	var spd := SPEED
	if rune_id == "power":
		if GameState.phase == GameState.Phase.NIGHT:
			spd *= POWER_NIGHT_SPD
		if kill_haste_t > 0.0:
			spd *= POWER_HASTE_SPD
	return spd


func grant_wood(n: int = 1) -> void:
	wood += n
	wood_gained.emit()


func _physics_process(delta: float) -> void:
	if not GameState.is_live():
		velocity = Vector3.ZERO
		Island.snap_feet(self)
		_play_locomotion()
		return

	attack_cd = maxf(0.0, attack_cd - delta)
	invuln = maxf(0.0, invuln - delta)
	_attack_t = maxf(0.0, _attack_t - delta)
	combat_t += delta
	if rune_id == "power":
		_tick_power(delta)
	if rune_id == "life":
		_tick_life(delta)
	if rune_id == "puppet":
		shield_cd = maxf(0.0, shield_cd - delta)
		if shield_charges <= 0 and shield_cd <= 0.0:
			shield_charges = 1
		if _orb:
			var t := Time.get_ticks_msec() * 0.004
			_orb.position = Vector3(cos(t) * 0.75, 1.25 + sin(t * 1.7) * 0.12, sin(t) * 0.75)
			_orb.visible = shield_charges > 0

	if _stab2_t >= 0.0:
		_stab2_t -= delta
		if _stab2_t <= 0.0:
			_stab2_t = -1.0
			_melee_pulse(_stab2_dmg, _stab2_knock, _stab2_range, _stab2_angle)

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward := Vector3(-sin(cam_yaw), 0.0, -cos(cam_yaw))
	var right := Vector3(cos(cam_yaw), 0.0, -sin(cam_yaw))
	var wish := (right * input.x + forward * -input.y)
	if wish.length() > 0.08:
		wish = wish.normalized()
		facing = wish
		# KayKit faces +Z at rest; this yaw faces +Z when wish is +Z.
		var target_yaw := atan2(wish.x, wish.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, delta * 10.0)

	var spd := move_speed()
	velocity.x = wish.x * spd
	velocity.z = wish.z * spd
	if not is_on_floor():
		velocity.y -= 28.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()

	var clamped := Island.clamp_xz(position.x, position.z, 1.25)
	position.x = clamped.x
	position.z = clamped.y
	Island.snap_feet(self)

	if _slash_t > 0.0:
		_slash_t = maxf(0.0, _slash_t - delta)
		var a := clampf(_slash_t / 0.20, 0.0, 1.0)
		var mat := _slash.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color.a = a * 0.70
		_slash.scale = Vector3.ONE * (1.0 + (1.0 - a) * 0.45)
		if _slash_t <= 0.0:
			_slash.visible = false

	_play_locomotion()


func _play_locomotion() -> void:
	if _ap == null:
		return
	if _attack_t > 0.0:
		return
	var spd := Vector2(velocity.x, velocity.z).length()
	var clip := _idle_clip
	if spd > 4.2 and _run_clip != "":
		clip = _run_clip
	elif spd > 0.22 and _walk_clip != "":
		clip = _walk_clip
	elif spd > 0.22 and _run_clip != "":
		clip = _run_clip
	if clip == "" or _anim == clip:
		return
	_ap.play(clip, 0.14)
	_anim = clip


func _start_clip(clip: String) -> bool:
	if _ap == null or clip == "":
		return false
	if _anim == clip and _attack_t > 0.08:
		return true
	_ap.play(clip, 0.06)
	_anim = clip
	var leng := _ap.current_animation_length
	_attack_t = leng if leng > 0.05 else 0.45
	return true


func _start_attack_anim() -> bool:
	return _start_clip(_attack_clip)


func _flash_slash(radius: float, col: Color) -> void:
	if _slash == null:
		return
	_slash.visible = true
	_slash_t = 0.24
	_slash.position = Vector3(0.0, 0.95, maxf(0.70, radius * 0.48))
	var sm := _slash.material_override as StandardMaterial3D
	if sm:
		sm.albedo_color = col
		sm.albedo_color.a = 0.88
		sm.emission = col
	var s := clampf(radius / 1.7, 0.70, 1.85)
	_slash.scale = Vector3(s, 1.0, s)


func try_chop(delta: float) -> void:
	if not Input.is_action_pressed("action"):
		chop_target = null
		return
	if GameState.phase == GameState.Phase.NIGHT:
		return
	var nearest: Node3D = null
	var best := 3.05
	for t in get_tree().get_nodes_in_group("trees"):
		if t.is_down:
			continue
		var d: float = Vector3(t.global_position.x - global_position.x, 0, t.global_position.z - global_position.z).length()
		if d < best:
			best = d
			nearest = t
	chop_target = nearest
	if nearest == null:
		return
	if not _start_clip(_chop_clip) and _use_slash_fallback:
		if _slash_t <= 0.0:
			_flash_slash(1.8, GameState.rune_color(rune_id))
	var rate := 1.35 if rune_id == "precise" else 1.05
	if nearest.chop(rate * delta):
		wood += 1
		wood_gained.emit()
		chopped_tree.emit()


func wants_attack() -> bool:
	if attack_cd > 0.0:
		return false
	# 力量 hold-to-repeat is melee-only; casters / crossbow stay tap-to-fire
	if rune_id == "power" and is_melee():
		return Input.is_action_pressed("action")
	return Input.is_action_just_pressed("action")


func do_attack() -> void:
	if attack_cd > 0.0:
		return
	var k := kit()
	atk_kind = str(k["kind"])
	atk_range = float(k["range"])
	atk_hits = 0
	attack_cd = float(k["cd"])

	if not _start_attack_anim():
		if atk_kind == "melee":
			_flash_slash(float(k["range"]), _slash_color())

	if atk_kind == "proj":
		_spawn_projectile(str(k["proj"]), float(k["dmg"]), float(k["knock"]))
		return

	_flash_slash(float(k["range"]), _slash_color())
	if rune_id == "power":
		_slash_t = 0.32
		if _slash:
			_slash.scale *= 1.18
	_melee_pulse(float(k["dmg"]), float(k["knock"]), float(k["range"]), float(k["angle"]))
	if int(k["ticks"]) >= 2:
		_stab2_t = float(k["tick_gap"])
		_stab2_dmg = float(k["dmg"])
		_stab2_knock = float(k["knock"])
		_stab2_range = float(k["range"])
		_stab2_angle = float(k["angle"])


func _slash_color() -> Color:
	if rune_id == "power":
		return Color(1.0, 0.36, 0.10)
	match character_id:
		"barbarian":
			return Color(1.0, 0.42, 0.18)
		"rogue":
			return Color(0.85, 0.90, 1.0)
		"knight":
			return Color(1.0, 0.88, 0.42)
		_:
			return GameState.rune_color(rune_id)


func _in_front_cone(pos: Vector3, radius: float, angle_deg: float) -> bool:
	var to := Vector3(pos.x - global_position.x, 0.0, pos.z - global_position.z)
	var d := to.length()
	if d > radius:
		return false
	if d < 0.42:
		return true
	var face := Vector3(facing.x, 0.0, facing.z)
	if face.length() < 0.01:
		face = Vector3(0, 0, 1)
	face = face.normalized()
	var ang := rad_to_deg(acos(clampf(to.normalized().dot(face), -1.0, 1.0)))
	return ang <= angle_deg * 0.5


func _melee_pulse(dmg: float, knock: float, radius: float, angle_deg: float) -> void:
	var hit_any := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead:
			continue
		if not _in_front_cone(e.global_position, radius, angle_deg):
			continue
		var dir: Vector3 = e.global_position - global_position
		dir.y = 0
		if dir.length() > 0.01:
			dir = dir.normalized()
		else:
			dir = facing
		var killed: bool = e.take_hit(dmg, dir * knock)
		hit_any = true
		atk_hits += 1
		if rune_id == "power":
			_on_power_connect(killed)
	if hit_any:
		Sfx.play("hit")
		attacked.emit()


func _spawn_projectile(kind: String, dmg: float, knock: float) -> void:
	var face := Vector3(facing.x, 0.0, facing.z)
	if face.length() < 0.01:
		face = Vector3(0, 0, 1)
	face = face.normalized()
	var origin := global_position + Vector3(0, 1.38, 0) + face * 0.55
	var ps := load("res://scripts/projectile.gd")
	var p: Node3D = ps.new()
	var host: Node = get_parent()
	if host == null:
		host = self
	host.add_child(p)
	p.setup(kind, origin, face, dmg, knock, self)


func notify_proj_hit(killed: bool) -> void:
	atk_hits += 1
	attacked.emit()
	if rune_id == "power":
		_on_power_connect(killed)


func take_hit(amount: float) -> void:
	if invuln > 0.0 or hp <= 0.0:
		return
	combat_t = 0.0
	if rune_id == "puppet" and shield_charges > 0:
		shield_charges = 0
		shield_cd = 9.0
		invuln = 0.45
		return
	# knight shield: facing an enemy shaves a bit of the incoming hit
	if character_id == "knight":
		var blocked := false
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e) or e.dead:
				continue
			var to := Vector3(e.global_position.x - global_position.x, 0, e.global_position.z - global_position.z)
			if to.length() < 2.5 and to.length() > 0.05 and to.normalized().dot(facing) > 0.32:
				blocked = true
				break
		if blocked:
			amount *= 0.72
	if rune_id == "life":
		amount *= LIFE_INCOMING
	if hp - amount <= 0.0 and _try_core_save():
		return
	hp = maxf(0.0, hp - amount)
	invuln = 0.55
	if rune_id == "life":
		_start_heal_pulse()
	if hp <= 0.0:
		died.emit()


func arm_core_save() -> void:
	if rune_id != "life":
		return
	core_save_ready = true
	last_core_save = false


func _try_core_save() -> bool:
	if rune_id != "life" or not core_save_ready:
		return false
	if GameState.phase != GameState.Phase.NIGHT:
		return false
	core_save_ready = false
	last_core_save = true
	hp = LIFE_SLIVER
	invuln = 1.15
	combat_t = 0.0
	_start_heal_pulse()
	core_saved.emit()
	print("life_core_save hp=", snappedf(hp, 0.1))
	return true


func _on_power_connect(killed: bool) -> void:
	last_heavy = true
	_start_power_burst(killed)
	if killed:
		last_kill_burst = true
		kill_haste = true
		kill_haste_t = POWER_HASTE_T
		var before := hp
		hp = minf(max_hp, hp + POWER_KILL_HEAL)
		last_kill_heal = hp - before
		print("power_kill dmg_mult=", POWER_DMG, " heal=", snappedf(last_kill_heal, 0.1), " hp=", snappedf(hp, 0.1))
	else:
		print("power_heavy dmg=", snappedf(float(kit()["dmg"]), 0.1))
	power_struck.emit(killed)


func _make_power_fx() -> void:
	var ring := CylinderMesh.new()
	ring.top_radius = 1.28
	ring.bottom_radius = 1.28
	ring.height = 0.10
	ring.radial_segments = 18
	_burst_mat = Mats.solid(Color(1.0, 0.42, 0.12, 0.0), true, Color(1.0, 0.38, 0.08), 2.2)
	_burst_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_burst_ring = Mats.mesh(self, ring, _burst_mat, Vector3(0.0, 0.18, 0.0))
	_burst_ring.visible = false
	_burst_light = OmniLight3D.new()
	_burst_light.light_color = Color(1.0, 0.40, 0.12)
	_burst_light.light_energy = 0.0
	_burst_light.omni_range = 4.2
	_burst_light.position = Vector3(0.0, 1.15, 0.0)
	_burst_light.shadow_enabled = false
	add_child(_burst_light)


func _start_power_burst(killed: bool) -> void:
	_burst_t = 0.38 if killed else 0.20
	if _burst_ring:
		_burst_ring.visible = true
	_paint_power_burst(1.0, killed)


func _paint_power_burst(strength: float, killed: bool) -> void:
	if _burst_mat == null:
		return
	var a := clampf(strength, 0.0, 1.0) * (0.88 if killed else 0.55)
	_burst_mat.albedo_color = Color(1.0, 0.40, 0.10, a)
	_burst_mat.emission_energy_multiplier = 1.1 + a * 2.4
	if _burst_ring:
		var s := 0.70 + (1.0 - clampf(strength, 0.0, 1.0)) * (1.15 if killed else 0.55)
		_burst_ring.scale = Vector3(s, 1.0, s)
		_burst_ring.visible = a > 0.02
	if _burst_light:
		_burst_light.light_energy = (2.4 if killed else 1.1) * a


func _tick_power(delta: float) -> void:
	if kill_haste_t > 0.0:
		kill_haste_t = maxf(0.0, kill_haste_t - delta)
		if kill_haste_t <= 0.0:
			kill_haste = false
	if _burst_t > 0.0:
		_burst_t = maxf(0.0, _burst_t - delta)
		var span := 0.38 if last_kill_burst and _burst_t > 0.12 else 0.20
		_paint_power_burst(_burst_t / maxf(0.08, span), last_kill_burst and _burst_t > 0.08)
		if _burst_t <= 0.0:
			_paint_power_burst(0.0, false)
			if _burst_ring:
				_burst_ring.visible = false
			if _burst_light:
				_burst_light.light_energy = 0.0


func _make_life_fx() -> void:
	var ring := CylinderMesh.new()
	ring.top_radius = 1.05
	ring.bottom_radius = 1.05
	ring.height = 0.07
	ring.radial_segments = 18
	_heal_ring_mat = Mats.solid(Color(0.38, 0.92, 0.48, 0.0), true, Color(0.32, 0.88, 0.40), 1.5)
	_heal_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_heal_ring = Mats.mesh(self, ring, _heal_ring_mat, Vector3(0.0, 0.10, 0.0))
	_heal_ring.visible = false
	_life_net_light = OmniLight3D.new()
	_life_net_light.light_color = Color(0.42, 0.92, 0.48)
	_life_net_light.light_energy = 0.0
	_life_net_light.omni_range = 3.2
	_life_net_light.position = Vector3(0.0, 1.15, 0.0)
	_life_net_light.shadow_enabled = false
	add_child(_life_net_light)


func _start_heal_pulse() -> void:
	last_hurt_pulse = true
	heal_pulse_t = 0.42
	if _heal_ring:
		_heal_ring.visible = true
	_paint_heal_pulse(1.0)
	print("life_hurt_pulse hp=", snappedf(hp, 0.1))


func _paint_heal_pulse(strength: float) -> void:
	if _heal_ring_mat == null:
		return
	var a := clampf(strength, 0.0, 1.0) * 0.72
	_heal_ring_mat.albedo_color = Color(0.38, 0.92, 0.48, a)
	_heal_ring_mat.emission_energy_multiplier = 0.6 + a * 1.4
	if _heal_ring:
		var s := 0.85 + (1.0 - clampf(strength, 0.0, 1.0)) * 0.55
		_heal_ring.scale = Vector3(s, 1.0, s)
		_heal_ring.visible = a > 0.02


func _tick_life(delta: float) -> void:
	if hp <= 0.0:
		return
	near_life_net = _life_network_near()
	if hp < max_hp:
		if combat_t >= 3.4:
			hp = minf(max_hp, hp + LIFE_OOC_REGEN * delta)
		if near_life_net:
			hp = minf(max_hp, hp + LIFE_NET_REGEN * delta)
	if heal_pulse_t > 0.0:
		heal_pulse_t = maxf(0.0, heal_pulse_t - delta)
		_paint_heal_pulse(heal_pulse_t / 0.42)
		if heal_pulse_t <= 0.0 and near_life_net:
			_paint_heal_pulse(0.22)
	elif near_life_net:
		var wobble := 0.16 + 0.06 * sin(Time.get_ticks_msec() * 0.006)
		_paint_heal_pulse(wobble)
	elif _heal_ring:
		_heal_ring.visible = false
	if _life_net_light:
		_life_net_light.light_energy = 0.42 if near_life_net else 0.0


func _life_network_near() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	for a in tree.get_nodes_in_group("altar"):
		if a == null or not is_instance_valid(a):
			continue
		if bool(a.get("lit")) and near_altar(a, LIFE_NET_R):
			return true
	for s in tree.get_nodes_in_group("shrines"):
		if s == null or not is_instance_valid(s):
			continue
		if bool(s.get("broken")):
			continue
		var d := Vector3(s.global_position.x - global_position.x, 0, s.global_position.z - global_position.z).length()
		if d <= LIFE_NET_R:
			return true
	return false


func near_altar(altar: Node3D, dist: float = 4.8) -> bool:
	if altar == null:
		return false
	var d := Vector3(altar.global_position.x - global_position.x, 0, altar.global_position.z - global_position.z).length()
	return d <= dist
