extends StaticBody3D

var lit := false
var hp := 3
var _flame: Node3D
var _light: OmniLight3D
var _glow_mat: StandardMaterial3D
var _pulse := 0.0


func setup() -> void:
	position = Vector3(0, 0, 0)
	collision_layer = 1
	collision_mask = 0
	add_to_group("altar")

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.2, 1.4, 3.2)
	col.shape = box
	col.position = Vector3(0, 0.7, 0)
	add_child(col)

	# stone plinth
	var base := CylinderMesh.new()
	base.top_radius = 1.7
	base.bottom_radius = 1.9
	base.height = 0.45
	base.radial_segments = 12
	Mats.mesh(self, base, Mats.solid(Color(0.48, 0.47, 0.44)), Vector3(0, 0.22, 0))

	var mid := CylinderMesh.new()
	mid.top_radius = 1.15
	mid.bottom_radius = 1.35
	mid.height = 0.7
	mid.radial_segments = 10
	Mats.mesh(self, mid, Mats.solid(Color(0.58, 0.56, 0.52)), Vector3(0, 0.72, 0))

	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.72
	bowl.bottom_radius = 0.55
	bowl.height = 0.28
	bowl.radial_segments = 10
	_glow_mat = Mats.solid(Color(0.35, 0.32, 0.30))
	Mats.mesh(self, bowl, _glow_mat, Vector3(0, 1.12, 0))

	# four standing stones
	for i in 4:
		var ang := i * TAU / 4.0 + 0.4
		var pillar := BoxMesh.new()
		pillar.size = Vector3(0.35, 1.1, 0.28)
		var p := Vector3(cos(ang) * 1.55, 0.7, sin(ang) * 1.55)
		Mats.mesh(self, pillar, Mats.solid(Color(0.52, 0.50, 0.46)), p)

	_flame = Node3D.new()
	_flame.name = "Flame"
	_flame.visible = false
	add_child(_flame)

	var core := SphereMesh.new()
	core.radius = 0.28
	core.height = 0.5
	Mats.mesh(_flame, core, Mats.solid(Color(1.0, 0.92, 0.55), true, Color(1.0, 0.8, 0.3), 2.4), Vector3(0, 1.45, 0))

	var outer := SphereMesh.new()
	outer.radius = 0.42
	outer.height = 0.85
	Mats.mesh(_flame, outer, Mats.solid(Color(1.0, 0.45, 0.12, 0.95), true, Color(1.0, 0.35, 0.05), 1.8), Vector3(0, 1.62, 0))

	var tip := SphereMesh.new()
	tip.radius = 0.18
	tip.height = 0.42
	Mats.mesh(_flame, tip, Mats.solid(Color(1.0, 0.75, 0.25), true, Color(1.0, 0.6, 0.1), 2.0), Vector3(0, 1.95, 0))

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.22)
	_light.light_energy = 0.0
	_light.omni_range = 14.0
	_light.position = Vector3(0, 2.2, 0)
	add_child(_light)


func light_fire() -> void:
	if lit:
		return
	lit = true
	hp = 3
	_flame.visible = true
	_light.light_energy = 3.6
	_glow_mat.albedo_color = Color(0.85, 0.42, 0.16)
	_glow_mat.emission_enabled = true
	_glow_mat.emission = Color(1.0, 0.4, 0.1)
	_glow_mat.emission_energy_multiplier = 1.6


func smash() -> bool:
	if not lit:
		return true
	hp -= 1
	Sfx.play("smash")
	print("altar_smash hp=", hp)
	if hp <= 0:
		reset_altar()
		return true
	return false


func reset_altar() -> void:
	lit = false
	hp = 3
	_flame.visible = false
	_light.light_energy = 0.0
	_glow_mat.albedo_color = Color(0.35, 0.32, 0.30)
	_glow_mat.emission_enabled = false


func _process(delta: float) -> void:
	if not lit:
		return
	_pulse += delta * 6.0
	var s := 1.0 + sin(_pulse) * 0.08
	_flame.scale = Vector3(s, 1.0 + sin(_pulse * 1.3) * 0.12, s)
	_light.light_energy = 3.2 + sin(_pulse * 1.7) * 0.5
