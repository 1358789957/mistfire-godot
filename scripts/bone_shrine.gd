extends StaticBody3D
## 骨祠 — night taunt shrine. Night enemies walk here and smash it instead of the altar.

const TAUNT_R := 7.5
const HIT_R := 1.7
const MAX_HP := 4
const SCL := 1.05
const BODY_H := 1.0
const COLORMAP := "res://assets/kenney_graveyard/Textures/colormap.png"

var ghost := false
var place_ok := true
var yaw := 0.0
var hp := MAX_HP
var broken := false
var _pulse := 0.0
var _shake := 0.0
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _body_mats: Array = []
var _base_albedos: Array = []
var _flame: Node3D
var _light: OmniLight3D
var _visual: Node3D
var last_place_flash: bool = false
var place_flash_t: float = 0.0


func setup(pos: Vector3, p_yaw: float = 0.0, as_ghost: bool = false) -> void:
	position = pos
	yaw = p_yaw
	rotation.y = yaw
	ghost = as_ghost
	hp = GameState.shrine_hp()
	broken = false
	collision_layer = 0 if as_ghost else 1
	collision_mask = 0
	if not as_ghost:
		add_to_group("shrines")

	if not as_ghost:
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.45, 1.70, 1.50)
		col.shape = box
		col.position = Vector3(0, 0.85, 0)
		add_child(col)

	_visual = Node3D.new()
	_visual.name = "Visual"
	_visual.scale = Vector3(SCL, SCL, SCL)
	add_child(_visual)
	if not _attach_crypt():
		_fallback_box()

	_add_accent()

	_flame = Node3D.new()
	_visual.add_child(_flame)
	var core := SphereMesh.new()
	core.radius = 0.11
	core.height = 0.20
	Mats.mesh(_flame, core, Mats.solid(Color(1.0, 0.84, 0.42), true, Color(1.0, 0.65, 0.2), 2.2), Vector3(0.0, 0.42, 0.92))
	var outer := SphereMesh.new()
	outer.radius = 0.18
	outer.height = 0.32
	Mats.mesh(_flame, outer, Mats.solid(Color(1.0, 0.40, 0.12, 0.88), true, Color(1.0, 0.32, 0.06), 1.6), Vector3(0.0, 0.56, 0.92))

	_ring_mat = Mats.solid(Color(0.86, 0.74, 0.42, 0.22), true, Color(0.95, 0.72, 0.28), 0.85)
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ring := CylinderMesh.new()
	ring.top_radius = TAUNT_R
	ring.bottom_radius = TAUNT_R
	ring.height = 0.05
	ring.radial_segments = 22
	_ring = Mats.mesh(self, ring, _ring_mat, Vector3(0, 0.07, 0))

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.62, 0.28)
	_light.light_energy = 0.0 if as_ghost else 1.85
	_light.omni_range = 6.4
	_light.position = Vector3(0.0, 1.15, 0.85)
	_light.shadow_enabled = false
	add_child(_light)

	_paint_colormap(_visual)
	_collect_mats(_visual)
	if as_ghost:
		_set_ghost_tint(true)
	print("shrine model roof=yes basket=yes h~", snappedf(1.74 * SCL, 0.01))


func _attach_crypt() -> bool:
	var body_path := "res://assets/kenney_graveyard/crypt-small.glb"
	if not ResourceLoader.exists(body_path):
		return false
	var body: Node3D = (load(body_path) as PackedScene).instantiate()
	_visual.add_child(body)
	var roof_path := "res://assets/kenney_graveyard/crypt-small-roof.glb"
	if ResourceLoader.exists(roof_path):
		var roof: Node3D = (load(roof_path) as PackedScene).instantiate()
		# roof mesh origin is at its own soles (y=0..0.74); sit it on the 1 m body
		roof.position = Vector3(0.0, BODY_H, 0.0)
		_visual.add_child(roof)
	return true


func _add_accent() -> void:
	var basket_path := "res://assets/kenney_graveyard/fire-basket.glb"
	if ResourceLoader.exists(basket_path):
		var basket: Node3D = (load(basket_path) as PackedScene).instantiate()
		basket.position = Vector3(0.0, 0.0, 0.92)
		basket.scale = Vector3(2.15, 2.15, 2.15)
		_visual.add_child(basket)
	var wood_path := "res://assets/kenney_graveyard/altar-wood.glb"
	if ResourceLoader.exists(wood_path):
		var aw: Node3D = (load(wood_path) as PackedScene).instantiate()
		aw.position = Vector3(-0.82, 0.0, 0.12)
		aw.rotation.y = 0.4
		aw.scale = Vector3(0.72, 0.72, 0.72)
		_visual.add_child(aw)
	var lan_path := "res://assets/kenney_graveyard/lantern-candle.glb"
	if ResourceLoader.exists(lan_path):
		var lan: Node3D = (load(lan_path) as PackedScene).instantiate()
		lan.position = Vector3(0.62, 0.0, 0.55)
		lan.scale = Vector3(1.15, 1.15, 1.15)
		_visual.add_child(lan)


func _paint_colormap(root: Node) -> void:
	var tex: Texture2D = null
	if ResourceLoader.exists(COLORMAP):
		tex = load(COLORMAP) as Texture2D
	if tex == null:
		return
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var msh := mi.mesh
			if msh:
				for i in msh.get_surface_count():
					var src := mi.get_active_material(i)
					var d: StandardMaterial3D
					if src is StandardMaterial3D:
						d = src.duplicate()
					else:
						d = StandardMaterial3D.new()
					d.albedo_texture = tex
					d.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
					d.metallic = 0.0
					d.roughness = 0.86
					d.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
					mi.set_surface_override_material(i, d)
		for c in n.get_children():
			stack.append(c)


func _fallback_box() -> void:
	var stone := Mats.solid(Color(0.72, 0.68, 0.60))
	var base := BoxMesh.new()
	base.size = Vector3(1.20, 1.00, 1.25)
	Mats.mesh(_visual, base, stone, Vector3(0, 0.50, 0))
	var roof := BoxMesh.new()
	roof.size = Vector3(1.38, 0.22, 1.42)
	Mats.mesh(_visual, roof, Mats.solid(Color(0.38, 0.24, 0.14)), Vector3(0, 1.12, 0))
	var peak := BoxMesh.new()
	peak.size = Vector3(0.30, 0.28, 0.30)
	Mats.mesh(_visual, peak, Mats.solid(Color(0.80, 0.74, 0.58)), Vector3(0, 1.32, 0))


func _collect_mats(root: Node) -> void:
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
						_body_mats.append(mat)
						_base_albedos.append(mat.albedo_color)
		for c in n.get_children():
			stack.append(c)


func set_place_ok(ok: bool) -> void:
	place_ok = ok
	if ghost:
		_set_ghost_tint(ok)


func _set_ghost_tint(ok: bool) -> void:
	var c := Color(0.25, 0.85, 0.4, 0.38) if ok else Color(0.9, 0.2, 0.18, 0.4)
	if _ring_mat:
		_ring_mat.albedo_color = c
		_ring_mat.emission = c
	for m in _body_mats:
		if m is StandardMaterial3D:
			m.albedo_color = c
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func flash_place() -> void:
	last_place_flash = true
	place_flash_t = 0.42
	if _light:
		_light.light_energy = 5.4
	if _ring_mat:
		var c := Color(0.32, 0.95, 0.86, 0.58) if GameState.rune_id == "precise" else Color(1.0, 0.82, 0.42, 0.52)
		_ring_mat.albedo_color = c
		_ring_mat.emission = c
	print("place_flash shrine")


func smash() -> bool:
	if ghost or broken:
		return true
	hp -= 1
	_shake = 0.28
	print("shrine_hp ", hp)
	Sfx.play("smash")
	if hp <= 0:
		_break()
		return true
	return false


func _break() -> void:
	broken = true
	print("shrine_broke")
	visible = false
	collision_layer = 0
	queue_free()


func _process(delta: float) -> void:
	if ghost or broken:
		return
	_pulse += delta * 5.2
	if place_flash_t > 0.0:
		place_flash_t = maxf(0.0, place_flash_t - delta)
		var u: float = place_flash_t / 0.42
		if _light:
			_light.light_energy = 1.55 + 3.8 * u
		if _ring_mat:
			_ring_mat.albedo_color.a = 0.14 + 0.44 * u
	else:
		if _flame:
			var s := 1.0 + sin(_pulse) * 0.12
			_flame.scale = Vector3(s, 1.0 + sin(_pulse * 1.35) * 0.16, s)
		if _light:
			_light.light_energy = 1.55 + sin(_pulse * 1.5) * 0.35
		if _ring_mat:
			_ring_mat.albedo_color.a = 0.14 + sin(_pulse) * 0.05
	if _shake > 0.0 and _visual:
		_shake = maxf(0.0, _shake - delta * 2.2)
		_visual.rotation_degrees.z = sin(Time.get_ticks_msec() * 0.05) * _shake * 14.0
	elif _visual:
		_visual.rotation_degrees.z = move_toward(_visual.rotation_degrees.z, 0.0, delta * 50.0)
