extends Node3D
## Cheap class-kit projectile: mage orb or hooded crossbow bolt.
## Swept XZ test so a long frame cannot skip through a target.

var vel := Vector3.ZERO
var dmg := 22.0
var knock_s := 2.0
var life := 1.0
var hit_r := 0.5
var max_dist := 14.0
var traveled := 0.0
var owner_p: Node
var kind := "orb"
var side := "enemy"


func setup(p_kind: String, origin: Vector3, dir: Vector3, p_dmg: float, p_knock: float, p_owner: Node, p_side: String = "enemy") -> void:
	kind = p_kind
	owner_p = p_owner
	side = p_side
	dmg = p_dmg
	knock_s = p_knock
	add_to_group("projectiles")
	global_position = origin
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length() < 0.01:
		d = Vector3(0, 0, 1)
	d = d.normalized()
	if kind == "orb":
		vel = d * 16.0
		hit_r = 0.70
		max_dist = 14.0
		life = 1.05
		_make_orb()
	elif kind == "ember":
		vel = d * 22.0
		hit_r = 0.55
		max_dist = 8.5
		life = 0.55
		_make_ember()
	else:
		vel = d * 28.0
		hit_r = 0.48
		max_dist = 16.0
		life = 0.70
		_make_bolt()
	if d.length() > 0.01:
		look_at(global_position + d, Vector3.UP)
	# catch a dummy already overlapping the muzzle
	if _try_hit_segment(global_position, global_position):
		return


func _make_orb() -> void:
	var sm := SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.56
	var mat := Mats.solid(Color(0.55, 0.85, 1.0, 1.0), true, Color(0.35, 0.75, 1.0), 4.2)
	Mats.mesh(self, sm, mat)
	var core := SphereMesh.new()
	core.radius = 0.13
	core.height = 0.26
	Mats.mesh(self, core, Mats.solid(Color(1.0, 1.0, 1.0), true, Color(0.9, 0.97, 1.0), 5.0))
	var ol := OmniLight3D.new()
	ol.light_color = Color(0.45, 0.80, 1.0)
	ol.light_energy = 3.4
	ol.omni_range = 6.5
	ol.shadow_enabled = false
	add_child(ol)


func _make_ember() -> void:
	var sm := SphereMesh.new()
	sm.radius = 0.18
	sm.height = 0.36
	Mats.mesh(self, sm, Mats.solid(Color(1.0, 0.62, 0.18), true, Color(1.0, 0.45, 0.08), 4.4))
	var tail := SphereMesh.new()
	tail.radius = 0.28
	tail.height = 0.48
	var tm := Mats.solid(Color(1.0, 0.35, 0.08, 0.55), true, Color(1.0, 0.28, 0.05), 2.6)
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	Mats.mesh(self, tail, tm, Vector3(0, 0, 0.22))
	var ol := OmniLight3D.new()
	ol.light_color = Color(1.0, 0.48, 0.12)
	ol.light_energy = 3.2
	ol.omni_range = 4.5
	ol.shadow_enabled = false
	add_child(ol)


func _make_bolt() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(0.16, 0.16, 1.05)
	var mat := Mats.solid(Color(0.95, 0.62, 0.22), true, Color(1.0, 0.55, 0.12), 2.8)
	Mats.mesh(self, box, mat)
	var tip := SphereMesh.new()
	tip.radius = 0.14
	tip.height = 0.28
	Mats.mesh(self, tip, Mats.solid(Color(1.0, 0.82, 0.35), true, Color(1.0, 0.7, 0.2), 3.4), Vector3(0, 0, -0.44))
	var trail := SphereMesh.new()
	trail.radius = 0.22
	trail.height = 0.44
	var tm := Mats.solid(Color(1.0, 0.55, 0.15, 0.7), true, Color(1.0, 0.45, 0.08), 2.2)
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	Mats.mesh(self, trail, tm, Vector3(0, 0, 0.18))
	var ol := OmniLight3D.new()
	ol.light_color = Color(1.0, 0.58, 0.18)
	ol.light_energy = 2.6
	ol.omni_range = 5.0
	ol.shadow_enabled = false
	add_child(ol)


func _seg_dist(ax: float, az: float, bx: float, bz: float, px: float, pz: float) -> float:
	var abx := bx - ax
	var abz := bz - az
	var apx := px - ax
	var apz := pz - az
	var ab2 := abx * abx + abz * abz
	if ab2 < 0.0001:
		return sqrt(apx * apx + apz * apz)
	var t := clampf((apx * abx + apz * abz) / ab2, 0.0, 1.0)
	var cx := ax + abx * t
	var cz := az + abz * t
	return sqrt((px - cx) * (px - cx) + (pz - cz) * (pz - cz))


func _try_hit_segment(from: Vector3, to: Vector3) -> bool:
	if side == "player":
		var pl := get_tree().get_first_node_in_group("player")
		if pl and is_instance_valid(pl) and pl != owner_p:
			var d := _seg_dist(from.x, from.z, to.x, to.z, pl.global_position.x, pl.global_position.z)
			if d <= hit_r + 0.15:
				if pl.has_method("take_hit"):
					pl.take_hit(dmg)
				queue_free()
				return true
		return false
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead:
			continue
		if e == owner_p:
			continue
		var d := _seg_dist(from.x, from.z, to.x, to.z, e.global_position.x, e.global_position.z)
		if d <= hit_r:
			var k := vel
			k.y = 0.0
			if k.length() > 0.01:
				k = k.normalized() * knock_s
			else:
				k = Vector3.ZERO
			var killed: bool = e.take_hit(dmg, k)
			if owner_p and is_instance_valid(owner_p) and owner_p.has_method("notify_proj_hit"):
				owner_p.notify_proj_hit(killed)
			queue_free()
			return true
	return false


func _process(delta: float) -> void:
	var step := vel * delta
	var n := maxi(1, int(ceil(step.length() / 0.32)))
	var sub := step / float(n)
	for i in n:
		var nxt := global_position + sub
		if _try_hit_segment(global_position, nxt):
			return
		global_position = nxt
		traveled += sub.length()
		if traveled >= max_dist:
			queue_free()
			return
	life -= delta
	if life <= 0.0:
		queue_free()
