extends Node3D
## Walk-over drop: wood log or bone.

var kind: String = "wood"
var _spin: float = 0.0
var _base_y: float = 0.0
var taken: bool = false


func setup(pos: Vector3, p_kind: String = "wood") -> void:
	kind = p_kind
	global_position = pos
	_base_y = pos.y
	add_to_group("pickups")
	if kind == "bone":
		_build_bone()
	else:
		var log := CylinderMesh.new()
		log.top_radius = 0.12
		log.bottom_radius = 0.14
		log.height = 0.72
		log.radial_segments = 7
		var mi := Mats.mesh(self, log, Mats.tree_bark(), Vector3(0, 0.14, 0))
		mi.rotation_degrees = Vector3(0, 0, 90)


func _build_bone() -> void:
	# Bright, oversized shard so a forest drop is readable at a glance.
	var shaft := BoxMesh.new()
	shaft.size = Vector3(0.28, 0.22, 1.05)
	var bone_mat := Mats.solid(Color(0.98, 0.92, 0.70), true, Color(1.0, 0.86, 0.48), 2.6)
	Mats.mesh(self, shaft, bone_mat, Vector3(0.0, 0.28, 0.0))
	var knob := SphereMesh.new()
	knob.radius = 0.18
	knob.height = 0.34
	var knob_mat := Mats.solid(Color(1.0, 0.94, 0.76), true, Color(1.0, 0.88, 0.52), 2.2)
	Mats.mesh(self, knob, knob_mat, Vector3(0.0, 0.28, 0.46))
	Mats.mesh(self, knob, knob_mat, Vector3(0.0, 0.28, -0.46))
	var ol := OmniLight3D.new()
	ol.position = Vector3(0.0, 0.55, 0.0)
	ol.light_color = Color(1.0, 0.88, 0.55)
	ol.light_energy = 1.85
	ol.omni_range = 3.4
	ol.shadow_enabled = false
	add_child(ol)
	var tag := Label3D.new()
	tag.text = "骨"
	tag.font = _cjk_font()
	tag.font_size = 72
	tag.pixel_size = 0.010
	tag.position = Vector3(0.0, 0.92, 0.0)
	tag.modulate = Color(1.0, 0.92, 0.58)
	tag.outline_size = 14
	tag.outline_modulate = Color(0.18, 0.10, 0.04)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.shaded = false
	add_child(tag)


func _cjk_font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
		"Noto Sans CJK SC", "WenQuanYi Micro Hei", "Droid Sans Fallback",
		"Noto Sans CJK JP", "Noto Sans", "DejaVu Sans"
	])
	f.font_weight = 700
	return f


func _process(delta: float) -> void:
	if taken:
		return
	_spin += delta
	rotation.y += delta * 2.1
	position.y = _base_y + 0.10 + sin(_spin * 3.6) * 0.08
	var p := get_tree().get_first_node_in_group("player")
	if p == null or not is_instance_valid(p):
		return
	var d := Vector3(p.global_position.x - global_position.x, 0, p.global_position.z - global_position.z).length()
	if d < 1.45:
		_collect(p)


func _collect(p: Node) -> void:
	taken = true
	var amount: int = 1
	if kind == "bone" and not GameState.wild_bone_today:
		GameState.wild_bone_today = true
		amount = 2
	if p.has_method("grant_wood"):
		p.grant_wood(amount)
	var note: String = ("骨 +%d" % amount) if kind == "bone" else ("木 +%d" % amount)
	if kind == "bone":
		_spawn_float(note)
		if p.has_method("note_loot"):
			p.note_loot(note)
	Sfx.play("pickup")
	print("pickup ", kind, " +", amount, " at ", global_position)
	queue_free()


func _spawn_float(text: String) -> void:
	var host: Node = get_parent()
	if host == null:
		return
	var lab := Label3D.new()
	lab.text = text
	lab.font = _cjk_font()
	lab.font_size = 78
	lab.pixel_size = 0.012
	lab.position = global_position + Vector3(0.0, 1.15, 0.0)
	lab.modulate = Color(1.0, 0.90, 0.52)
	lab.outline_size = 16
	lab.outline_modulate = Color(0.16, 0.08, 0.03)
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.no_depth_test = true
	lab.shaded = false
	host.add_child(lab)
	var tw := host.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lab, "position:y", lab.position.y + 1.15, 0.82)
	tw.tween_property(lab, "modulate:a", 0.0, 0.82)
	tw.chain().tween_callback(lab.queue_free)
