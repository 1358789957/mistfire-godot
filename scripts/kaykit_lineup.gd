extends Node3D
## One-off look-at lineup. Does not replace the capsule player.

const CHAR_DIR := "res://assets/kaykit_adventurers/Characters/gltf/"

const LINEUP := [
	{"file": "Knight.glb", "label": "Knight", "keep": ["1H_Sword", "Rectangle_Shield"]},
	{"file": "Barbarian.glb", "label": "Barbarian", "keep": ["1H_Axe", "Barbarian_Round_Shield"]},
	{"file": "Mage.glb", "label": "Mage", "keep": ["2H_Staff"]},
	{"file": "Rogue.glb", "label": "Rogue", "keep": ["Knife"]},
	{"file": "Rogue_Hooded.glb", "label": "Rogue Hooded", "keep": ["1H_Crossbow"]},
]

const HELD := [
	"1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield", "Round_Shield", "Spike_Shield",
	"1H_Sword", "2H_Sword",
	"1H_Axe_Offhand", "Barbarian_Round_Shield", "1H_Axe", "2H_Axe", "Mug",
	"Spellbook", "Spellbook_open", "1H_Wand", "2H_Staff",
	"Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Knife", "Throwable",
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
	# Advance idles so the rest T-pose is replaced.
	for child in get_children():
		var ap := child.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap:
			ap.advance(0.35)
	await get_tree().create_timer(1.6).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "/workspace/mistfire-godot/shot-kaykit.png"
	var err := img.save_png(path)
	print("saved shot ", path, " err=", err, " size=", img.get_width(), "x", img.get_height())
	get_tree().quit()


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.58, 0.76, 0.91)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.80, 0.86)
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.97, 0.90)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50.0, 40.0, 0.0)
	add_child(sun)

	var fill := OmniLight3D.new()
	fill.light_color = Color(0.80, 0.88, 1.0)
	fill.light_energy = 0.7
	fill.omni_range = 20.0
	fill.position = Vector3(2.5, 3.2, 5.0)
	add_child(fill)

	var grass_tex := load("res://assets/ground/grass.png") as Texture2D
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.80, 0.90, 0.58)
	if grass_tex:
		gmat.albedo_texture = grass_tex
		gmat.uv1_scale = Vector3(22, 22, 22)
	gmat.roughness = 0.95
	gmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 18)
	ground.mesh = plane
	ground.material_override = gmat
	add_child(ground)

	# 3/4 front: models face +Z, camera sits in front-right.
	var cam := Camera3D.new()
	cam.fov = 36.0
	cam.position = Vector3(2.85, 2.05, 6.55)
	add_child(cam)
	cam.look_at(Vector3(0.05, 0.88, 0.15))
	cam.current = true

	var hud := CanvasLayer.new()
	add_child(hud)
	var title := Label.new()
	title.text = "KayKit Adventurers  ·  FREE  ·  Knight · Barbarian · Mage · Rogue · Rogue Hooded"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(20, 16)
	title.size = Vector2(1560, 40)
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Noto Sans CJK SC", "Noto Sans", "DejaVu Sans"])
	f.font_weight = 700
	title.add_theme_font_override("font", f)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.10, 0.12, 0.16))
	title.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.92))
	title.add_theme_constant_override("outline_size", 8)
	hud.add_child(title)


func _spawn_lineup() -> void:
	var n := LINEUP.size()
	var spacing := 1.72
	var start_x := -spacing * 0.5 * float(n - 1)
	for i in n:
		var spec: Dictionary = LINEUP[i]
		var path: String = CHAR_DIR + String(spec["file"])
		var packed := load(path) as PackedScene
		if packed == null:
			push_error("missing " + path)
			continue
		var inst := packed.instantiate() as Node3D
		inst.name = String(spec["label"]).replace(" ", "_")
		inst.position = Vector3(start_x + spacing * float(i), 0.0, 0.0)
		# Official KayKit rest faces +Z in Godot — keep rotation 0 so they face the camera.
		inst.rotation_degrees = Vector3(0, 0, 0)
		add_child(inst)
		_hide_extra_held(inst, spec["keep"])
		_play_idle(inst)
		if i == 0:
			_dump_tree(inst, 0)
		var tag := Label3D.new()
		tag.text = String(spec["label"])
		tag.font_size = 48
		tag.pixel_size = 0.0034
		tag.modulate = Color(0.08, 0.10, 0.14)
		tag.outline_modulate = Color(1, 1, 1, 0.95)
		tag.outline_size = 12
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = Vector3(inst.position.x, 0.12, 0.72)
		add_child(tag)
		print("spawned ", spec["label"], " at ", inst.position)


func _hide_extra_held(root: Node, keep: Array) -> void:
	var keep_set := {}
	for k in keep:
		keep_set[String(k)] = true
	for n in root.find_children("*", "", true, false):
		if String(n.name) in HELD and not keep_set.has(String(n.name)):
			n.visible = false


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


func _dump_tree(n: Node, depth: int) -> void:
	var vis := ""
	if n is Node3D:
		vis = " vis=" + str((n as Node3D).visible)
	print("  ".repeat(depth) + n.name + " [" + n.get_class() + "]" + vis)
	for c in n.get_children():
		_dump_tree(c, depth + 1)
