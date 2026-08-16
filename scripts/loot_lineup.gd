extends Node3D
## One-off look-at of newly scraped free props.

const ITEMS := [
	{"path": "res://assets/kaykit_dungeon/chest.glb", "label": "箱", "s": 1.8},
	{"path": "res://assets/kaykit_dungeon/chest_gold.glb", "label": "金箱", "s": 1.8},
	{"path": "res://assets/kaykit_dungeon/barrel_large.gltf.glb", "label": "桶", "s": 1.6},
	{"path": "res://assets/kaykit_dungeon/torch_lit.gltf.glb", "label": "火把", "s": 1.8},
	{"path": "res://assets/kenney_graveyard/altar-wood.glb", "label": "木祭坛", "s": 1.4},
	{"path": "res://assets/kenney_graveyard/crypt-small.glb", "label": "小墓室", "s": 1.0},
	{"path": "res://assets/kenney_graveyard/fire-basket.glb", "label": "火篓", "s": 1.6},
	{"path": "res://assets/kenney_pirate/cannon.glb", "label": "炮", "s": 1.2},
	{"path": "res://assets/kenney_pirate/boat-row-small.glb", "label": "小船", "s": 0.7},
]


func _ready() -> void:
	var win := get_window()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = Vector2i(1600, 900)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	get_viewport().size = Vector2i(1600, 900)
	_build_world()
	_spawn()
	await get_tree().create_timer(1.4).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "/workspace/mistfire-godot/shot-loot.png"
	var err := img.save_png(path)
	print("saved shot ", path, " err=", err)
	get_tree().quit()


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.20, 0.24, 0.30)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.64, 0.68, 0.76)
	env.ambient_light_energy = 0.95
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.95, 0.90, 0.80)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50.0, 32.0, 0.0)
	add_child(sun)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.42, 0.48, 0.36)
	var grass := load("res://assets/ground/grass.png") as Texture2D
	if grass:
		gmat.albedo_texture = grass
		gmat.uv1_scale = Vector3(16, 16, 16)
	gmat.roughness = 0.95
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(28, 12)
	ground.mesh = plane
	ground.material_override = gmat
	add_child(ground)
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 3.6, 8.4)
	cam.fov = 42.0
	cam.current = true
	add_child(cam)
	cam.look_at(Vector3(0.0, 0.7, 0.0))
	var title := Label3D.new()
	title.text = "新刮到的免费件 · 箱/桶/祭坛/墓室/炮/船"
	title.font_size = 64
	title.pixel_size = 0.012
	title.position = Vector3(0.0, 3.15, -1.2)
	title.modulate = Color(1.0, 0.92, 0.72)
	add_child(title)


func _spawn() -> void:
	var n := ITEMS.size()
	var span := 16.0
	for i in n:
		var it: Dictionary = ITEMS[i]
		var x := -span * 0.5 + span * (float(i) + 0.5) / float(n)
		if not ResourceLoader.exists(it["path"]):
			print("MISSING ", it["path"])
			continue
		var node: Node3D = (load(it["path"]) as PackedScene).instantiate()
		node.position = Vector3(x, 0.0, 0.0)
		var s: float = it["s"]
		node.scale = Vector3(s, s, s)
		node.rotation.y = 0.55
		add_child(node)
		var lab := Label3D.new()
		lab.text = str(it["label"])
		lab.font_size = 48
		lab.pixel_size = 0.010
		lab.position = Vector3(x, 2.05, 0.35)
		lab.modulate = Color(0.95, 0.95, 0.90)
		add_child(lab)
		print("loot ", it["label"], " at ", x)
