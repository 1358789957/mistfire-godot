extends Node3D

const Kaykit := preload("res://scripts/kaykit.gd")
## One-off look-at of the four free KayKit skeletons.

const SKEL_DIR := "res://assets/kaykit_skeletons/Characters/gltf/"

const LINEUP := [
	{"file": "Skeleton_Warrior.glb", "label": "Warrior", "kind": "warrior"},
	{"file": "Skeleton_Rogue.glb", "label": "Rogue", "kind": "rogue"},
	{"file": "Skeleton_Mage.glb", "label": "Mage", "kind": "mage"},
	{"file": "Skeleton_Minion.glb", "label": "Minion", "kind": "minion"},
]


func _ready() -> void:
	var win := get_window()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = Vector2i(1600, 900)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	get_viewport().size = Vector2i(1600, 900)
	_build_world()
	_spawn_lineup()
	await get_tree().process_frame
	for child in get_children():
		var ap := child.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap:
			ap.advance(0.4)
	await get_tree().create_timer(1.6).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "/workspace/mistfire-godot/shot-monsters.png"
	var err := img.save_png(path)
	print("saved shot ", path, " err=", err, " size=", img.get_width(), "x", img.get_height())
	get_tree().quit()


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.22, 0.26, 0.32)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.74)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.92, 0.88, 0.80)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-48.0, 36.0, 0.0)
	add_child(sun)

	var fill := OmniLight3D.new()
	fill.light_color = Color(0.78, 0.55, 1.0)
	fill.light_energy = 0.85
	fill.omni_range = 18.0
	fill.position = Vector3(1.8, 2.8, 4.6)
	add_child(fill)

	var grass_tex := load("res://assets/ground/grass.png") as Texture2D
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.55, 0.62, 0.42)
	if grass_tex:
		gmat.albedo_texture = grass_tex
		gmat.uv1_scale = Vector3(18, 18, 18)
	gmat.roughness = 0.95
	gmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(24, 14)
	ground.mesh = plane
	ground.material_override = gmat
	add_child(ground)

	var cam := Camera3D.new()
	cam.fov = 34.0
	cam.position = Vector3(2.15, 1.85, 5.85)
	add_child(cam)
	cam.look_at(Vector3(0.05, 0.82, 0.10))
	cam.current = true

	var hud := CanvasLayer.new()
	add_child(hud)
	var title := Label.new()
	title.text = "野怪  ·  KayKit Skeletons  ·  FREE  ·  Warrior · Rogue · Mage · Minion"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(20, 16)
	title.size = Vector2(1560, 40)
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Noto Sans CJK SC", "Noto Sans", "DejaVu Sans"])
	f.font_weight = 700
	title.add_theme_font_override("font", f)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.90, 0.78))
	title.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.10, 0.92))
	title.add_theme_constant_override("outline_size", 8)
	hud.add_child(title)


func _spawn_lineup() -> void:
	var n := LINEUP.size()
	var spacing := 1.85
	var start_x := -spacing * 0.5 * float(n - 1)
	for i in n:
		var spec: Dictionary = LINEUP[i]
		var kind := String(spec.get("kind", "warrior"))
		var inst := Kaykit.instantiate_skel(kind)
		inst.name = String(spec["label"])
		inst.position = Vector3(start_x + spacing * float(i), 0.0, 0.0)
		inst.rotation_degrees = Vector3(0, 0, 0)
		add_child(inst)
		Kaykit.fit_height(inst, 1.46 if kind == "minion" else 1.68)
		_play_idle(inst)
		var tag := Label3D.new()
		tag.text = String(spec["label"])
		tag.font_size = 48
		tag.pixel_size = 0.0034
		tag.modulate = Color(0.95, 0.90, 0.78)
		tag.outline_modulate = Color(0.08, 0.08, 0.10, 0.95)
		tag.outline_size = 12
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = Vector3(inst.position.x, 0.10, 0.68)
		add_child(tag)
		print("spawned ", spec["label"], " at ", inst.position)


func _play_idle(root: Node) -> void:
	var ap := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		print("no AnimationPlayer on ", root.name)
		return
	ap.active = true
	if ap.has_animation("Idle"):
		ap.play("Idle")
		print(root.name, " playing Idle")
	elif ap.has_animation("Unarmed_Idle"):
		ap.play("Unarmed_Idle")
	else:
		print(root.name, " no Idle, list=", ap.get_animation_list())
