extends Node3D

const CAMP_POS := Vector3(-2.0, 0.0, -40.0)

var occupied := false
var _flag_mat: StandardMaterial3D
var _cloth_mat: StandardMaterial3D
var _accent_mats: Array = []
var _banner: Node3D


func setup() -> void:
	position = CAMP_POS
	add_to_group("camp")
	_build_keep()
	_add_collision()


func _build_keep() -> void:
	var stone := Mats.solid(Color(0.48, 0.40, 0.32))
	var dark := Mats.solid(Color(0.32, 0.26, 0.20))
	var wood := Mats.solid(Color(0.40, 0.26, 0.14))

	var pad := CylinderMesh.new()
	pad.top_radius = 3.15
	pad.bottom_radius = 3.3
	pad.height = 0.16
	pad.radial_segments = 14
	Mats.mesh(self, pad, Mats.solid(Color(0.42, 0.36, 0.28)), Vector3(0, 0.18, 0))

	# Kenney walls in village.gd are the ring. Interior keep only.

	# keep block
	var keep := BoxMesh.new()
	keep.size = Vector3(2.1, 1.55, 1.7)
	Mats.mesh(self, keep, stone, Vector3(0.15, 0.95, 0.35))
	var roof := BoxMesh.new()
	roof.size = Vector3(2.35, 0.22, 1.95)
	var roof_m := Mats.solid(Color(0.42, 0.22, 0.14))
	_accent_mats.append(roof_m)
	Mats.mesh(self, roof, roof_m, Vector3(0.15, 1.82, 0.35))

	# side hut
	var hut := BoxMesh.new()
	hut.size = Vector3(1.15, 0.95, 1.05)
	Mats.mesh(self, hut, dark, Vector3(-1.35, 0.62, -0.4))

	# banner pole
	_banner = Node3D.new()
	_banner.name = "Banner"
	add_child(_banner)
	_banner.position = Vector3(-0.15, 0, -1.15)

	var pole := CylinderMesh.new()
	pole.top_radius = 0.05
	pole.bottom_radius = 0.07
	pole.height = 2.55
	Mats.mesh(_banner, pole, wood, Vector3(0, 1.35, 0))

	_flag_mat = Mats.solid(Color(0.55, 0.18, 0.16), true)
	var flag := BoxMesh.new()
	flag.size = Vector3(0.95, 0.62, 0.05)
	Mats.mesh(_banner, flag, _flag_mat, Vector3(0.52, 2.15, 0))

	_cloth_mat = Mats.solid(Color(0.62, 0.22, 0.18), true)
	var tail := BoxMesh.new()
	tail.size = Vector3(0.28, 0.55, 0.04)
	Mats.mesh(_banner, tail, _cloth_mat, Vector3(0.95, 1.85, 0))

	# enemy faction mark on keep
	var mark := BoxMesh.new()
	mark.size = Vector3(0.55, 0.4, 0.06)
	Mats.mesh(self, mark, _flag_mat, Vector3(0.15, 1.25, -0.52))



func _add_collision() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var keep := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 1.7, 1.85)
	keep.shape = box
	keep.position = Vector3(0.15, 0.95, 0.35)
	body.add_child(keep)
	var hut := CollisionShape3D.new()
	var hbox := BoxShape3D.new()
	hbox.size = Vector3(1.2, 1.05, 1.1)
	hut.shape = hbox
	hut.position = Vector3(-1.35, 0.62, -0.4)
	body.add_child(hut)


func occupy(color: Color) -> void:
	if occupied:
		return
	occupied = true
	_flag_mat.albedo_color = color
	_flag_mat.emission_enabled = true
	_flag_mat.emission = color
	_flag_mat.emission_energy_multiplier = 1.3
	_cloth_mat.albedo_color = color.lightened(0.12)
	for m in _accent_mats:
		m.albedo_color = m.albedo_color.lerp(color, 0.35)


func reset_camp() -> void:
	occupied = false
	_flag_mat.albedo_color = Color(0.55, 0.18, 0.16)
	_flag_mat.emission_enabled = false
	_cloth_mat.albedo_color = Color(0.62, 0.22, 0.18)
	# accent mats were lerped; rebuild is heavy — retint toward brown
	for m in _accent_mats:
		m.albedo_color = Color(0.40, 0.24, 0.13)


func banner_pos() -> Vector3:
	if _banner:
		return _banner.global_position
	return global_position


func near_banner(pos: Vector3, dist: float = 4.8) -> bool:
	var d := Vector3(banner_pos().x - pos.x, 0, banner_pos().z - pos.z).length()
	if d <= dist:
		return true
	var c := Vector3(global_position.x - pos.x, 0, global_position.z - pos.z).length()
	return c <= 5.4


func all_guards_dead() -> bool:
	var tree := get_tree()
	if tree == null:
		return true
	for g in tree.get_nodes_in_group("guards"):
		if is_instance_valid(g) and not g.dead:
			return false
	return true
