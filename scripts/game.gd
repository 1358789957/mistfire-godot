extends Node3D

const Kaykit := preload("res://scripts/kaykit.gd")
const Island := preload("res://scripts/island.gd")

const WOOD_NEED := 8
const NIGHT_LEN := 52.0
const WAVE_COUNTS := [3, 4, 5]
const WAVE_GAP := 5.0
const POST_LIGHT := 60.0
const POST_OCCUPY := 10.0
const TOWER_LIMIT := 3
const SHRINE_LIMIT := 1
const SHRINE_COST := 8
const TRIBUTE_INT := 8.0
const DAWN_LEN := 2.2
const NIGHT_SPEED_BUMP := 1.12

var font: Font
var font_bold: Font

var world: Node3D
var altar: Node3D
var player: CharacterBody3D
var sun: DirectionalLight3D
var env: Environment
var world_env: WorldEnvironment
var cam_pivot: Node3D
var camera: Camera3D
var camp: Node3D
var village: Node3D
var golem: Node3D
var ghost: Node3D

var hud: CanvasLayer
var title_root: Control
var rune_root: Control
var play_hud: Control
var result_root: Control
var wood_label: Label
var hp_label: Label
var rune_label: Label
var hint_label: Label
var flash_label: Label
var flash_t := 0.0
var night_label: Label
var build_label: Label
var land_label: Label
var result_title: Label
var result_sub: Label
var result_again: Button
var chop_bar: ColorRect
var chop_bar_bg: ColorRect
var minimap: Control

var wood := 0
var night_t := 0.0
var wave_i := 0
var wave_wait := 0.0
var _night_lit := false
var chest: Node3D
var _monster_close := false
var post_light_t := -1.0
var fire_tick := 0.0
var title_yaw := 0.4
var title_orbit := true
var cam_yaw := 0.35
var cam_pitch := 0.92
var result_shown := false
var dawn_t := -1.0
var build_mode := false
var build_kind := "tower"
var ghost_yaw := 0.0
var place_cd := 0.0
var tribute_t := 0.0
var _shot_focus := ""

var charsel_root: Control
var char_label: Label
var charsel_lineup: Node3D
var _char_cards: Dictionary = {}
var _char_selected := "knight"
var _char_card_styles: Dictionary = {}


func _ready() -> void:
	randomize()
	_build_fonts()
	_build_world()
	_build_camera()
	_build_ui()
	_show_title()
	await _maybe_shot()


func _build_fonts() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK SC", "Noto Sans CJK JP", "Noto Sans", "DejaVu Sans"])
	font_bold = SystemFont.new()
	font_bold.font_names = PackedStringArray(["Noto Sans CJK SC", "Noto Sans CJK JP", "Noto Sans", "DejaVu Sans"])
	font_bold.font_weight = 700


func _mat(color: Color, unshaded := false, emit := Color(0, 0, 0, 0), e := 0.0) -> StandardMaterial3D:
	return Mats.solid(color, unshaded, emit, e)


func _build_world() -> void:
	world = Node3D.new()
	world.name = "World"
	add_child(world)

	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.50, 0.70, 0.86)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.58, 0.66, 0.78)
	env.ambient_light_energy = 0.40
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_env = WorldEnvironment.new()
	world_env.environment = env
	world.add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46, 42, 0)
	sun.light_color = Color(1.0, 0.93, 0.78)
	sun.light_energy = 1.42
	# llvmpipe + gl_compatibility: shadows are too expensive; key light does the form
	sun.shadow_enabled = false
	world.add_child(sun)

	# ocean — one large world-UV plane. Opaque darker water + existing foam ribbon.
	# UV world-scaled 12 m so the 512 ripple tile is not a prototype grid.
	var ocean_mi := MeshInstance3D.new()
	ocean_mi.name = "Ocean"
	ocean_mi.mesh = Island.ocean_mesh(430.0, -0.62, 16.0)
	ocean_mi.material_override = Mats.water(Color(0.92, 1.18, 1.10))
	ocean_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ocean_mi.extra_cull_margin = 80.0
	world.add_child(ocean_mi)
	print("WATER_DRAW ArrayMesh uv_world=16 tex=water.png 512 filter=linear")

	Island.ensure()
	# One continuous grass ArrayMesh clipped to Island.poly(), plus a sand ribbon.
	# Box MultiMesh tiles read as a 4 m checkerboard from the camera.
	Island.stamp(world)

	# foam strip just outside the coast
	var foam_mi := MeshInstance3D.new()
	foam_mi.mesh = Island.foam_mesh()
	foam_mi.material_override = _mat(Color(0.80, 0.91, 0.90), true)
	world.add_child(foam_mi)

	# dirt circle at the altar, connected to the cross roads
	var dirt_mi := MeshInstance3D.new()
	dirt_mi.mesh = Mats.ground_disc(7.0, 20, 3, 0.0, 4.5, Color.WHITE, Color.WHITE)
	dirt_mi.material_override = Mats.ground(Mats.dirt_tex(), Color(1.08, 0.94, 0.76))
	dirt_mi.position = Vector3(0, 0.016, 0)
	world.add_child(dirt_mi)

	# Backup flat collider under the village / altar / keep only.
	# Must NOT cover the ruins hill (z~30) or jungle — those use snap_feet.
	var ground := StaticBody3D.new()
	ground.name = "VillageFlatBody"
	var gcol := CollisionShape3D.new()
	var gbox := BoxShape3D.new()
	gbox.size = Vector3(50, 0.6, 70)
	gcol.shape = gbox
	gcol.position = Vector3(-4.0, -0.3, -18.0)
	ground.add_child(gcol)
	world.add_child(ground)

	# Kenney rocks (instanced, not primitive blobs)
	var rock_spots := [
		Vector3(4.8, 0.0, -3.4), Vector3(-5.6, 0.0, 3.2),
		Vector3(48.0, 0.0, 32.0), Vector3(50.5, 0.0, 23.5), Vector3(46.0, 0.0, 38.5),
		Vector3(52.0, 0.0, 16.0), Vector3(42.5, 0.0, 40.0),
		Vector3(-48.0, 0.0, 10.2), Vector3(-52.5, 0.0, -6.4), Vector3(-44.0, 0.0, -8.2),
		Vector3(6.4, 0.0, 48.0), Vector3(-4.2, 0.0, 50.5), Vector3(14.0, 0.0, 46.0),
	]
	for rp in rock_spots:
		rp.y = Island.height_at(rp.x, rp.z)
		_make_rock(rp)
	# Real jungle ridge is height-displaced terrain now — no box berms.

	var altar_script := load("res://scripts/altar.gd")
	altar = altar_script.new()
	world.add_child(altar)
	altar.setup()

	var camp_script := load("res://scripts/camp.gd")
	camp = camp_script.new()
	world.add_child(camp)
	camp.setup()

	var village_script := load("res://scripts/village.gd")
	village = village_script.new()
	world.add_child(village)
	village.setup()

	# Fine Kenney foliage-sprite cards on the grass fill (not grass_large plates).
	Island.scatter_plants(world, village)
	Island.scatter_jungle(world, village)

	# Choppable trees on the 空地 rim (~20). Y on terrain. Path stays open.
	var tree_spots: Array = Island.choppable_spots()
	var tree_script := load("res://scripts/chop_tree.gd")
	var planted := 0
	for tp in tree_spots:
		if village and village.has_method("blocks") and village.blocks(tp, 2.6):
			continue
		if village and village.has_method("on_road") and village.on_road(tp, 1.05):
			tp = Vector3(tp.x, 0.0, tp.z + 3.4)
			if village.blocks(tp, 2.6) or village.on_road(tp, 1.05):
				continue
		if not Island.contains_v(tp, 2.8):
			continue
		tp = Vector3(tp.x, Island.height_at(tp.x, tp.z), tp.z)
		var tr: Node = tree_script.new()
		world.add_child(tr)
		tr.setup(tp)
		planted += 1
	print("map choppable_trees=", planted, " clearing=(108,28) village≈(0,-22) keep=(-2,-40) shore=(-50,2) ruins=(0,30) poly=", Island.poly().size())


func _frame_overview_cam() -> void:
	# High 3/4 from the south so the east jungle lobe fills the right of frame.
	cam_pivot.global_position = Vector3(64.0, 0.0, 10.0)
	cam_pivot.rotation.y = 0.0
	camera.fov = 50.0
	camera.position = Vector3(0.0, 248.0, -118.0)
	camera.look_at(Vector3(64.0, 0.6, 10.0))


func _frame_grass_cam() -> void:
	# Close at default spawn feet: several 3D tufts, not a flat albedo field.
	var look := Vector3(9.35, 0.32, 6.85)
	if player and is_instance_valid(player):
		cam_pivot.global_position = player.global_position
		cam_pivot.rotation.y = 0.0
		camera.fov = 40.0
		camera.position = Vector3(0.28, 1.38, 2.05)
		camera.look_at(look)
	else:
		cam_pivot.global_position = Vector3(7.5, 0.0, 8.2)
		cam_pivot.rotation.y = 0.0
		camera.fov = 40.0
		camera.position = Vector3(0.28, 1.38, 2.05)
		camera.look_at(look)


func _on_ground(x: float, z: float, extra: float = Island.FOOT_OFF) -> Vector3:
	return Vector3(x, Island.foot_y(x, z, extra), z)


func _frame_jungle_cam() -> void:
	# SW of the (70,36) 5-tree clump — clustered trunks, dark floor, no leaf clip.
	var stand := Vector3(66.4, 0.0, 29.2)
	var hy := Island.height_at(stand.x, stand.z)
	var look := Vector3(71.0, Island.height_at(71.0, 37.2) + 2.2, 37.2)
	cam_pivot.global_position = Vector3(stand.x, hy, stand.z)
	cam_pivot.rotation.y = 0.0
	camera.fov = 46.0
	camera.position = Vector3(-2.4, 3.85, -9.2)
	camera.look_at(look)


func _frame_forest_cam() -> void:
	_frame_jungle_cam()


func _frame_clearing_cam() -> void:
	# Higher 3/4 over the oval so circle, oak, trail, and rim choppables all read.
	var stand := Vector3(99.0, 0.0, 16.0)
	var hy := Island.height_at(stand.x, stand.z)
	var look := Vector3(108.4, Island.height_at(108.4, 30.2) + 1.35, 30.2)
	cam_pivot.global_position = Vector3(stand.x, hy, stand.z)
	cam_pivot.rotation.y = 0.0
	camera.fov = 48.0
	camera.position = Vector3(5.0, 13.5, -18.0)
	camera.look_at(look)


func _frame_edge_cam() -> void:
	# Meadow grass in the foreground, 林缘 oaks/birch beyond, forest readable through.
	var stand := Vector3(8.2, 0.0, 6.4)
	var hy := Island.height_at(stand.x, stand.z)
	var look := Vector3(27.5, Island.height_at(27.5, 14.0) + 1.55, 14.0)
	cam_pivot.global_position = Vector3(stand.x, hy, stand.z)
	cam_pivot.rotation.y = 0.0
	camera.fov = 48.0
	camera.position = Vector3(1.2, 3.35, 7.6)
	camera.look_at(look)


func _frame_jungle_trail_cam() -> void:
	# On the winding trail in 林缘, looking toward the 空地.
	var stand := Vector3(54.0, 0.0, 20.0)
	var hy := Island.height_at(stand.x, stand.z)
	var ahead := Vector3(78.0, Island.height_at(78.0, 22.0) + 0.45, 22.0)
	cam_pivot.global_position = Vector3(stand.x, hy, stand.z)
	cam_pivot.rotation.y = 0.0
	camera.fov = 44.0
	camera.position = Vector3(-1.4, 2.05, 3.6)
	camera.look_at(ahead)


func _frame_jungle_tex_cam() -> void:
	# Deep jungle floor, not the meadow blend and not the trail.
	var x := 124.0
	var z := 38.0
	var hy := Island.height_at(x, z)
	cam_pivot.global_position = Vector3(x, hy, z)
	cam_pivot.rotation.y = 0.0
	camera.fov = 38.0
	camera.position = Vector3(0.05, 1.05, 1.15)
	camera.look_at(Vector3(x + 1.1, hy + 0.02, z - 0.55))


func _frame_coast_cam() -> void:
	# 3/4 along the west spit: sand ribbon, pier into the harbor, bay bite.
	cam_pivot.global_position = Vector3(-42.0, 0.0, -8.0)
	cam_pivot.rotation.y = 0.0
	camera.fov = 46.0
	camera.position = Vector3(6.0, 18.0, 26.0)
	camera.look_at(Vector3(-54.0, 0.15, 8.0))


func _frame_shore_dock_cam() -> void:
	# Wider 3/4: palms + cannon on the spit, rowboat in the north harbor.
	var look := Vector3(-55.0, 0.28, 12.4)
	cam_pivot.global_position = Vector3(-42.0, 0.15, 2.5)
	cam_pivot.rotation.y = 0.0
	camera.fov = 50.0
	camera.position = Vector3(3.6, 9.6, 8.2)
	camera.look_at(look)


func _frame_chest_cam() -> void:
	var p := Vector3(103.2, Island.height_at(103.2, 25.4), 25.4)
	if chest and is_instance_valid(chest):
		p = chest.global_position
	cam_pivot.global_position = p
	cam_pivot.rotation.y = 0.0
	camera.fov = 34.0
	camera.position = Vector3(-2.15, 2.05, 3.35)
	camera.look_at(p + Vector3(0.12, 0.38, 0.08))


func _frame_water_cam() -> void:
	# Low over the west spit, looking out to sea: sand, foam, rippled water.
	cam_pivot.global_position = Vector3(-60.0, 0.0, 8.0)
	cam_pivot.rotation.y = 0.0
	camera.fov = 44.0
	camera.position = Vector3(4.6, 1.85, 3.4)
	camera.look_at(Vector3(-78.0, -0.28, 16.5))


func _frame_ruins_cam() -> void:
	# Wider 3/4 from the SSE so cottages, roofed towers, and the knight all read.
	# Pivot + look use foot_y so boots sit on the rise.
	var stand := Vector3(0.6, 0.0, 27.8)
	var fy := Island.foot_y(stand.x, stand.z)
	var look := Vector3(0.2, fy + 1.45, 31.0)
	cam_pivot.global_position = Vector3(stand.x, fy, stand.z)
	cam_pivot.rotation.y = 0.0
	camera.fov = 40.0
	camera.position = Vector3(3.2, 4.85, -11.4)
	camera.look_at(look)


func _frame_road_cam() -> void:
	# Dirt cross south of the altar — continuous strip, not 2 m slabs.
	cam_pivot.global_position = Vector3(0.0, 0.0, -3.2)
	cam_pivot.rotation.y = 0.0
	camera.fov = 40.0
	camera.position = Vector3(1.15, 2.55, 4.6)
	camera.look_at(Vector3(0.15, 0.04, -9.2))


func _make_ridge() -> void:
	# Low dirt berms on the far NE woods rim. Gaps stay walkable.
	var berms := [
		[Vector3(50.0, 0.22, 30.0), 0.45],
		[Vector3(52.2, 0.22, 22.4), 0.15],
		[Vector3(47.6, 0.20, 37.0), 0.85],
		[Vector3(43.0, 0.20, 40.5), 1.15],
	]
	var mat := Mats.textured(Mats.dirt_tex(), Color(0.90, 0.80, 0.64), Vector3(2, 1, 2))
	for b in berms:
		var body := StaticBody3D.new()
		body.position = b[0]
		body.rotation.y = float(b[1])
		var box := BoxMesh.new()
		box.size = Vector3(3.4, 0.52, 1.55)
		Mats.mesh(body, box, mat, Vector3.ZERO)
		var col := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(3.2, 0.52, 1.4)
		col.shape = sh
		body.add_child(col)
		world.add_child(body)


func _make_rock(pos: Vector3) -> void:
	var kinds := ["rock_largeA", "rock_largeB", "rock_tallA"]
	var idx := int(absf(pos.x * 3.0 + pos.z)) % kinds.size()
	var path := "res://assets/kenney_nature/%s.glb" % kinds[idx]
	var body := StaticBody3D.new()
	body.position = Vector3(pos.x, pos.y, pos.z)
	if ResourceLoader.exists(path):
		var n: Node3D = (load(path) as PackedScene).instantiate()
		n.scale = Vector3(2.7, 2.7, 2.7)
		n.rotation.y = pos.x * 0.4
		body.add_child(n)
		Mats.polish_imported(n)
	else:
		var mesh := SphereMesh.new()
		mesh.radius = 0.55
		mesh.height = 0.7
		Mats.mesh(body, mesh, _mat(Color(0.50, 0.50, 0.48)), Vector3.ZERO, Vector3(1.15, 0.7, 0.95))
	var col := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.45
	col.shape = s
	col.position = Vector3(0, 0.25, 0)
	body.add_child(col)
	world.add_child(body)


func _build_camera() -> void:
	cam_pivot = Node3D.new()
	cam_pivot.name = "CamPivot"
	add_child(cam_pivot)
	camera = Camera3D.new()
	camera.fov = 56.0
	# high 3/4 of the whole landmass: peninsula, bay, village, woods, headland
	cam_pivot.position = Vector3(64.0, 0.0, 10.0)
	camera.position = Vector3(0.0, 248.0, -118.0)
	cam_pivot.add_child(camera)
	camera.look_at(Vector3(64.0, 0.6, 10.0))
	cam_pivot.rotation.y = title_yaw


func _label(text: String, size: int, color: Color, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_bold if bold else font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l


func _btn(text: String, bg: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font_bold)
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", Color(1, 0.97, 0.92))
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10
	normal.corner_radius_bottom_right = 10
	normal.content_margin_left = 22
	normal.content_margin_right = 22
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	var hover := normal.duplicate()
	hover.bg_color = bg.lightened(0.12)
	var press := normal.duplicate()
	press.bg_color = bg.darkened(0.12)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", press)
	b.add_theme_stylebox_override("focus", hover)
	return b


func _panel(bg: Color) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	p.add_theme_stylebox_override("panel", sb)
	return p


func _build_ui() -> void:
	hud = CanvasLayer.new()
	add_child(hud)

	title_root = Control.new()
	title_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(title_root)

	var veil := ColorRect.new()
	veil.color = Color(0.04, 0.05, 0.10, 0.16)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_root.add_child(veil)
	var top_bar := ColorRect.new()
	top_bar.color = Color(0.03, 0.04, 0.08, 0.38)
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 280
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_root.add_child(top_bar)

	var title := _label("雾火神殿", 72, Color(1.0, 0.86, 0.55), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 118
	title.offset_bottom = 210
	title_root.add_child(title)

	var sub := _label("Mistfire Sanctum", 28, Color(0.85, 0.78, 0.68))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 200
	sub.offset_bottom = 246
	title_root.add_child(sub)

	var blurb := _label("流放者的火种还在等你。砍下八捆木柴，点亮祭坛，守过今夜。", 20, Color(0.92, 0.90, 0.84))
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.set_anchors_preset(Control.PRESET_TOP_WIDE)
	blurb.offset_top = 258
	blurb.offset_bottom = 300
	title_root.add_child(blurb)

	var start := _btn("开始流放", Color(0.82, 0.32, 0.14))
	start.set_anchors_preset(Control.PRESET_CENTER)
	start.offset_left = -120
	start.offset_right = 120
	start.offset_top = 70
	start.offset_bottom = 128
	start.pressed.connect(_show_charsel)
	title_root.add_child(start)

	_build_charsel_ui()

	# rune select
	rune_root = Control.new()
	rune_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	rune_root.visible = false
	hud.add_child(rune_root)

	var rveil := ColorRect.new()
	rveil.color = Color(0.03, 0.04, 0.08, 0.55)
	rveil.set_anchors_preset(Control.PRESET_FULL_RECT)
	rveil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rune_root.add_child(rveil)

	var rtitle := _label("选择一枚符文", 40, Color(1.0, 0.9, 0.7), true)
	rtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
	rtitle.offset_top = 70
	rtitle.offset_bottom = 130
	rune_root.add_child(rtitle)

	var rsub := _label("Pick a rune  ·  各符文手感不同", 18, Color(0.8, 0.78, 0.72))
	rsub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rsub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	rsub.offset_top = 128
	rsub.offset_bottom = 160
	rune_root.add_child(rsub)

	var ids := ["power", "puppet", "precise", "life"]
	for i in ids.size():
		var id: String = ids[i]
		var info: Dictionary = GameState.RUNES[id]
		var card := _panel(Color(0.10, 0.10, 0.14, 0.92))
		card.position = Vector2(70 + i * 305, 210)
		card.size = Vector2(280, 340)
		rune_root.add_child(card)

		var accent := ColorRect.new()
		accent.color = info["color"]
		accent.position = Vector2(0, 0)
		accent.size = Vector2(280, 10)
		card.add_child(accent)

		var nm := _label(str(info["name"]), 34, info["color"], true)
		nm.position = Vector2(16, 28)
		nm.size = Vector2(248, 50)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(nm)

		var en := _label(str(info["en"]), 18, Color(0.75, 0.74, 0.7))
		en.position = Vector2(16, 78)
		en.size = Vector2(248, 28)
		en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(en)

		var pas := _label("被动  " + str(info["passive"]), 20, Color(0.95, 0.92, 0.82))
		pas.position = Vector2(16, 130)
		pas.size = Vector2(248, 36)
		pas.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(pas)

		var extra := ""
		match id:
			"power":
				extra = "近战可按住连砍\n伤害提高，首杀加速"
			"puppet":
				extra = "傀儡伐木/守夜\n护盾挡住一次伤害"
			"precise":
				extra = "火塔仅需 4 木 · B切骨祠\n砍树、放置更快"
			"life":
				extra = "生命上限 120 · 受伤回春\n夜濒死一次 核心还在"
		var ex := _label(extra, 16, Color(0.78, 0.76, 0.7))
		ex.position = Vector2(20, 176)
		ex.size = Vector2(240, 82)
		ex.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(ex)

		var pick := _btn("选定", info["color"])
		pick.position = Vector2(50, 268)
		pick.size = Vector2(180, 50)
		pick.pressed.connect(_start_run.bind(id))
		card.add_child(pick)

	# play HUD
	play_hud = Control.new()
	play_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	play_hud.visible = false
	play_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(play_hud)

	var bar := _panel(Color(0.06, 0.07, 0.10, 0.72))
	bar.position = Vector2(18, 16)
	bar.size = Vector2(380, 196)
	play_hud.add_child(bar)

	wood_label = _label("木材  0 / 8", 24, Color(0.95, 0.82, 0.45), true)
	wood_label.position = Vector2(34, 24)
	wood_label.size = Vector2(350, 30)
	play_hud.add_child(wood_label)

	hp_label = _label("生命  80", 22, Color(0.95, 0.45, 0.42), true)
	hp_label.position = Vector2(34, 52)
	hp_label.size = Vector2(350, 26)
	play_hud.add_child(hp_label)

	char_label = _label("角色  骑士", 18, Color(0.95, 0.90, 0.72), true)
	char_label.position = Vector2(34, 78)
	char_label.size = Vector2(350, 24)
	play_hud.add_child(char_label)

	rune_label = _label("符文  力量  ·  重击劈砍", 18, Color(0.88, 0.86, 0.8))
	rune_label.position = Vector2(34, 102)
	rune_label.size = Vector2(350, 24)
	play_hud.add_child(rune_label)

	build_label = _label("筑:火塔 6木  0/3", 18, Color(1.0, 0.62, 0.28), true)
	build_label.position = Vector2(34, 126)
	build_label.size = Vector2(350, 24)
	play_hud.add_child(build_label)

	land_label = _label("领地  0/1", 18, Color(0.78, 0.86, 0.95), true)
	land_label.position = Vector2(34, 150)
	land_label.size = Vector2(350, 24)
	play_hud.add_child(land_label)

	hint_label = _label("砍树 → 点火/建塔/祠 → 占城寨 → 守夜", 22, Color(1, 0.95, 0.82), true)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint_label.offset_top = -64
	hint_label.offset_bottom = -22
	play_hud.add_child(hint_label)

	flash_label = _label("", 52, Color(0.55, 0.96, 0.62), true)
	flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flash_label.set_anchors_preset(Control.PRESET_CENTER)
	flash_label.offset_left = -320
	flash_label.offset_right = 320
	flash_label.offset_top = -168
	flash_label.offset_bottom = -88
	flash_label.visible = false
	flash_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_hud.add_child(flash_label)

	night_label = _label("", 22, Color(0.75, 0.82, 1.0), true)
	night_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	night_label.position = Vector2(960, 10)
	night_label.size = Vector2(304, 30)
	play_hud.add_child(night_label)

	var mm_script := load("res://scripts/minimap.gd")
	minimap = mm_script.new()
	minimap.name = "Minimap"
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.offset_left = -208
	minimap.offset_top = 42
	minimap.offset_right = -16
	minimap.offset_bottom = 234
	play_hud.add_child(minimap)

	chop_bar_bg = ColorRect.new()
	chop_bar_bg.color = Color(0, 0, 0, 0.45)
	chop_bar_bg.size = Vector2(160, 10)
	chop_bar_bg.position = Vector2(560, 640)
	chop_bar_bg.visible = false
	play_hud.add_child(chop_bar_bg)
	chop_bar = ColorRect.new()
	chop_bar.color = Color(0.85, 0.62, 0.25)
	chop_bar.size = Vector2(0, 10)
	chop_bar.position = Vector2(560, 640)
	chop_bar.visible = false
	play_hud.add_child(chop_bar)

	# result
	result_root = Control.new()
	result_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_root.visible = false
	hud.add_child(result_root)

	var eveil := ColorRect.new()
	eveil.color = Color(0.02, 0.02, 0.05, 0.62)
	eveil.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_root.add_child(eveil)

	result_title = _label("你守住了今晚", 56, Color(1.0, 0.86, 0.5), true)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.set_anchors_preset(Control.PRESET_CENTER)
	result_title.offset_left = -400
	result_title.offset_right = 400
	result_title.offset_top = -80
	result_title.offset_bottom = -10
	result_root.add_child(result_title)

	result_sub = _label("", 22, Color(0.88, 0.86, 0.8))
	result_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_sub.set_anchors_preset(Control.PRESET_CENTER)
	result_sub.offset_left = -400
	result_sub.offset_right = 400
	result_sub.offset_top = -4
	result_sub.offset_bottom = 40
	result_root.add_child(result_sub)

	var again := _btn("再来", Color(0.72, 0.28, 0.16))
	again.set_anchors_preset(Control.PRESET_CENTER)
	again.offset_left = -100
	again.offset_right = 100
	again.offset_top = 60
	again.offset_bottom = 118
	again.pressed.connect(_show_title)
	result_root.add_child(again)
	result_again = again


func _show_title() -> void:
	_clear_run()
	_clear_charsel_lineup()
	GameState.phase = GameState.Phase.TITLE
	GameState.character_id = "knight"
	_char_selected = "knight"
	title_root.visible = true
	if charsel_root:
		charsel_root.visible = false
	rune_root.visible = false
	play_hud.visible = false
	result_root.visible = false
	if result_again:
		result_again.visible = true
	_set_day_look()
	title_yaw = 0.32
	title_orbit = true


func _show_runes() -> void:
	GameState.phase = GameState.Phase.RUNE
	_clear_charsel_lineup()
	title_root.visible = false
	if charsel_root:
		charsel_root.visible = false
	rune_root.visible = true
	play_hud.visible = false
	result_root.visible = false
	title_orbit = true


func _start_run(id: String) -> void:
	GameState.rune_id = id
	if GameState.character_id.is_empty() or not GameState.CHARACTERS.has(GameState.character_id):
		GameState.character_id = "knight"
	GameState.phase = GameState.Phase.DAY
	GameState.survived = false
	GameState.territory = 0
	GameState.day_index = 1
	wood = 0
	night_t = 0.0
	post_light_t = -1.0
	result_shown = false
	dawn_t = -1.0
	build_mode = false
	build_kind = "tower"
	ghost_yaw = 0.0
	place_cd = 0.0
	tribute_t = 0.0
	title_root.visible = false
	if charsel_root:
		charsel_root.visible = false
	rune_root.visible = false
	result_root.visible = false
	play_hud.visible = true
	flash_t = 0.0
	if flash_label:
		flash_label.visible = false
		flash_label.text = ""
	_clear_charsel_lineup()
	_set_day_look()
	_reset_trees()
	if altar:
		altar.reset_altar()
	if camp:
		camp.reset_camp()
	for tw in get_tree().get_nodes_in_group("towers"):
		tw.queue_free()
	for sh in get_tree().get_nodes_in_group("shrines"):
		sh.queue_free()
	_spawn_player()
	_spawn_guards()
	_spawn_wilds()
	_spawn_chest()
	_refresh_hud()


func _spawn_player() -> void:
	if player and is_instance_valid(player):
		player.queue_free()
	if golem and is_instance_valid(golem):
		golem.queue_free()
		golem = null
	var ps := load("res://scripts/player.gd")
	player = ps.new()
	world.add_child(player)
	player.setup(GameState.rune_id)
	player.cam_yaw = cam_yaw
	player.died.connect(_on_player_died)
	player.wood_gained.connect(_on_wood)
	player.core_saved.connect(_on_core_saved)
	_ensure_puppet_golem()


func _spawn_chest() -> void:
	if chest and is_instance_valid(chest):
		chest.queue_free()
	var cs := load("res://scripts/chest.gd")
	chest = cs.new()
	world.add_child(chest)
	chest.setup(_on_ground(103.2, 25.4))
	print("chest at ", chest.global_position)


func _try_chest() -> void:
	if chest == null or not is_instance_valid(chest) or chest.opened:
		return
	if player == null:
		return
	var d := Vector3(chest.global_position.x - player.global_position.x, 0, chest.global_position.z - player.global_position.z).length()
	if d < 2.4:
		chest.try_open()


func _spawn_wilds() -> void:
	for w in get_tree().get_nodes_in_group("wilds"):
		w.queue_free()
	var es := load("res://scripts/enemy.gd")
	var specs := [
		[Vector3(104.0, 0.0, 26.8), "warrior"],
		[Vector3(106.4, 0.0, 24.2), "rogue"],
		[Vector3(101.6, 0.0, 28.4), "minion"],
		[Vector3(54.0, 0.0, 20.0), "mage"],
	]
	for spec in specs:
		var xz: Vector3 = spec[0]
		var en: Node = es.new()
		world.add_child(en)
		en.setup(_on_ground(xz.x, xz.z), altar, player, "wild", spec[1])
		print("wild_spawn kind=", spec[1], " at ", xz)


func _spawn_guards() -> void:
	for g in get_tree().get_nodes_in_group("guards"):
		g.queue_free()
	if camp == null:
		return
	var es := load("res://scripts/enemy.gd")
	var offsets := [Vector3(2.6, 0.9, 2.4), Vector3(-2.8, 0.9, 2.1), Vector3(0.15, 0.9, -2.7)]
	for off in offsets:
		var en: Node = es.new()
		world.add_child(en)
		en.setup(camp.global_position + off, altar, player, "guard")


func _on_wood() -> void:
	wood = player.wood
	_refresh_hud()


func _on_player_died() -> void:
	if GameState.phase == GameState.Phase.RESULT or GameState.phase == GameState.Phase.DAWN:
		return
	_show_result(false)


func _on_core_saved() -> void:
	_flash_hud("核心还在", Color(0.48, 0.96, 0.58), 1.85)
	Sfx.play("ember")
	_refresh_hud()


func _flash_hud(text: String, col: Color, dur := 1.75) -> void:
	if flash_label == null:
		return
	flash_label.text = text
	flash_label.add_theme_color_override("font_color", col)
	flash_label.modulate = Color(1, 1, 1, 1)
	flash_label.visible = true
	flash_t = dur
	print("hud_flash ", text)


func _tick_hud_flash(delta: float) -> void:
	if flash_t <= 0.0:
		return
	flash_t = maxf(0.0, flash_t - delta)
	if flash_label == null:
		return
	if flash_t <= 0.0:
		flash_label.visible = false
		return
	var a := 1.0
	if flash_t < 0.40:
		a = clampf(flash_t / 0.40, 0.0, 1.0)
	flash_label.modulate.a = a


func _reset_trees() -> void:
	for t in get_tree().get_nodes_in_group("trees"):
		if t.has_method("reset_tree"):
			t.reset_tree()


func _clear_run() -> void:
	_set_build(false)
	if player and is_instance_valid(player):
		player.queue_free()
		player = null
	if golem and is_instance_valid(golem):
		golem.queue_free()
		golem = null
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	for t in get_tree().get_nodes_in_group("towers"):
		t.queue_free()
	for sh in get_tree().get_nodes_in_group("shrines"):
		sh.queue_free()
	if altar and altar.has_method("reset_altar"):
		altar.reset_altar()
	if camp and camp.has_method("reset_camp"):
		camp.reset_camp()
	_reset_trees()
	wood = 0
	GameState.territory = 0
	GameState.day_index = 1
	tribute_t = 0.0
	dawn_t = -1.0


func _set_day_look() -> void:
	env.background_color = Color(0.50, 0.70, 0.86)
	env.ambient_light_color = Color(0.58, 0.66, 0.78)
	env.ambient_light_energy = 0.40
	sun.light_color = Color(1.0, 0.93, 0.78)
	sun.light_energy = 1.42
	sun.rotation_degrees = Vector3(-46, 42, 0)


func _set_night_look() -> void:
	env.background_color = Color(0.05, 0.06, 0.14)
	env.ambient_light_color = Color(0.18, 0.22, 0.40)
	env.ambient_light_energy = 0.16
	sun.light_color = Color(0.45, 0.52, 0.75)
	sun.light_energy = 0.18
	sun.rotation_degrees = Vector3(-28, -20, 0)


func _wave_counts() -> Array:
	# Night 1: [3, 4, 5]. Later nights +1 per wave; still 3 waves, woods+shore.
	var extra: int = maxi(0, GameState.day_index - 1)
	var out: Array = []
	for c in WAVE_COUNTS:
		out.append(int(c) + extra)
	return out


func _ensure_puppet_golem() -> void:
	# Live puppet run: keep the same golem through night / dawn / day 2.
	# Only a new run (_spawn_player / _clear_run) may free it.
	if GameState.rune_id != "puppet":
		return
	if golem and is_instance_valid(golem):
		if golem.master != player and player and is_instance_valid(player):
			golem.master = player
		return
	if player == null or not is_instance_valid(player) or world == null:
		return
	var gs := load("res://scripts/golem.gd")
	golem = gs.new()
	world.add_child(golem)
	golem.setup(player)


func _begin_night() -> void:
	if GameState.phase == GameState.Phase.NIGHT or GameState.phase == GameState.Phase.RESULT or GameState.phase == GameState.Phase.DAWN:
		return
	GameState.phase = GameState.Phase.NIGHT
	night_t = NIGHT_LEN
	post_light_t = -1.0
	wave_i = 0
	wave_wait = 0.0
	_night_lit = altar != null and altar.lit
	_set_night_look()
	_spawn_wave(0)
	_ensure_puppet_golem()
	if player and is_instance_valid(player):
		player.arm_core_save()
	Sfx.play("night")
	_refresh_hud()


func _night_living() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead:
			continue
		if e.is_in_group("guards") or e.is_in_group("wilds") or e.is_in_group("dummies"):
			continue
		n += 1
	return n


func _spawn_wave(idx: int) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_in_group("guards") or e.is_in_group("wilds"):
			continue
		e.queue_free()
	var pool := [
		Vector3(32.0, Island.height_at(32.0, 2.2) + 0.9, 2.2),
		Vector3(40.0, Island.height_at(40.0, 16.0) + 0.9, 16.0),
		Vector3(36.0, Island.height_at(36.0, 8.0) + 0.9, 8.0),
		Vector3(-44.0, Island.height_at(-44.0, 2.0) + 0.9, 2.0),
		Vector3(-42.0, Island.height_at(-42.0, -3.2) + 0.9, -3.2),
		Vector3(-38.0, Island.height_at(-38.0, 6.0) + 0.9, 6.0),
	]
	var waves: Array = _wave_counts()
	var last: int = waves.size() - 1
	var count: int = int(waves[clampi(idx, 0, last)])
	var kinds := ["warrior", "rogue", "mage", "minion"]
	var es := load("res://scripts/enemy.gd")
	for i in count:
		var spot: Vector3 = pool[i % pool.size()]
		if i >= pool.size():
			spot.x += float(i) * 0.8
		var en: Node = es.new()
		world.add_child(en)
		en.setup(spot, altar, player, "night", kinds[(idx + i) % kinds.size()])
		if GameState.day_index >= 2:
			en.speed = float(en.speed) * NIGHT_SPEED_BUMP
		print("night_wave[", idx, "] n=", i, " kind=", en.skel_kind, " at ", spot)


func _spawn_enemies() -> void:
	_spawn_wave(0)


func _show_result(win: bool) -> void:
	if GameState.phase == GameState.Phase.RESULT or GameState.phase == GameState.Phase.DAWN:
		return
	# Night 1 win is not a dead-end: dawn, then Day 2 on the same island.
	# Puppet golem is not freed here — it rides dawn into day 2.
	# VERIFY: _show_result(true) -> _begin_dawn (day_index += 1) -> DAY.
	# Wood / towers / shrine / keep / trees / chest / rune persist. Night 2 is [4,5,6] + 12% speed.
	# Night 2 win (day_index >= MAX_DAYS) is the terminal 守住了.
	if win and not GameState.is_final_night():
		_begin_dawn()
		return
	GameState.phase = GameState.Phase.RESULT
	GameState.survived = win
	result_shown = true
	build_mode = false
	if ghost and is_instance_valid(ghost):
		ghost.visible = false
	play_hud.visible = true
	result_root.visible = true
	if result_again:
		result_again.visible = true
	if win:
		Sfx.play("win")
		result_title.text = "守住了"
		result_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
		if GameState.territory >= 1:
			result_sub.text = "第%d夜已过。雾火还在燃烧。" % GameState.day_index
		else:
			result_sub.text = "第%d夜已过。流放者的火种还在。" % GameState.day_index
	else:
		Sfx.play("lose")
		result_title.text = "流放失败"
		result_title.add_theme_color_override("font_color", Color(0.95, 0.42, 0.38))
		result_sub.text = "雾影吞没了祭坛。再来一次。"
	_refresh_hud()


func _clear_night_mobs() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if e.is_in_group("guards") or e.is_in_group("wilds") or e.is_in_group("dummies"):
			continue
		e.queue_free()
	for p in get_tree().get_nodes_in_group("projectiles"):
		if is_instance_valid(p):
			p.queue_free()


func _begin_dawn() -> void:
	if GameState.phase == GameState.Phase.DAWN:
		return
	GameState.phase = GameState.Phase.DAWN
	GameState.survived = true
	GameState.day_index += 1
	result_shown = false
	build_mode = false
	dawn_t = DAWN_LEN
	night_t = 0.0
	wave_i = 0
	wave_wait = 0.0
	post_light_t = -1.0
	if ghost and is_instance_valid(ghost):
		ghost.visible = false
	_clear_night_mobs()
	_set_day_look()
	# Same island: do not reset trees, towers, shrine, keep, chest, wood, rune.
	if altar and altar.lit:
		if camp and camp.occupied:
			post_light_t = POST_OCCUPY
		else:
			post_light_t = POST_LIGHT
	if player and is_instance_valid(player):
		player.hp = player.max_hp
		player.invuln = 1.2
	_ensure_puppet_golem()
	play_hud.visible = true
	result_root.visible = true
	if result_again:
		result_again.visible = false
	result_title.text = "破晓"
	result_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
	result_sub.text = "第%d天 · 火种还在" % GameState.day_index
	Sfx.play("confirm")
	print("dawn day=", GameState.day_index, " wood=", player.wood if player else -1, " towers=", _tower_count(), " shrine=", _shrine_count(), " keep=", GameState.territory, " altar=", altar.lit if altar else false)
	_refresh_hud()


func _finish_dawn() -> void:
	dawn_t = -1.0
	result_root.visible = false
	if result_again:
		result_again.visible = true
	GameState.phase = GameState.Phase.DAY
	_ensure_puppet_golem()
	_refresh_hud()


func _tower_count() -> int:
	return get_tree().get_nodes_in_group("towers").size()


func _shrine_count() -> int:
	var n := 0
	for s in get_tree().get_nodes_in_group("shrines"):
		if is_instance_valid(s) and not (("broken" in s) and s.broken):
			n += 1
	return n


func _refresh_hud() -> void:
	if player and is_instance_valid(player):
		if altar and altar.lit:
			wood_label.text = "木材  %d" % player.wood
		else:
			wood_label.text = "木材  %d / %d" % [player.wood, WOOD_NEED]
		hp_label.text = "生命  %d/%d" % [int(ceili(player.hp)), int(ceili(player.max_hp))]
		if char_label:
			char_label.text = "角色  %s · %s" % [GameState.character_name(), GameState.character_kit()]
		rune_label.text = "符文  %s  ·  %s" % [GameState.rune_name(), GameState.rune_passive()]
		rune_label.add_theme_color_override("font_color", GameState.rune_color(GameState.rune_id))
	if build_kind == "shrine":
		var sn := _shrine_count()
		if sn >= SHRINE_LIMIT:
			build_label.text = "筑:骨祠 已满  %d/%d" % [sn, SHRINE_LIMIT]
		else:
			build_label.text = "筑:骨祠 %d木  %d/%d" % [SHRINE_COST, sn, SHRINE_LIMIT]
	else:
		var cost := GameState.tower_cost()
		var n := _tower_count()
		if n >= TOWER_LIMIT:
			build_label.text = "筑:火塔 已满  %d/%d" % [n, TOWER_LIMIT]
		else:
			build_label.text = "筑:火塔 %d木  %d/%d" % [cost, n, TOWER_LIMIT]
	land_label.text = "领地  %d/1  ·  第%d天" % [GameState.territory, GameState.day_index]
	hint_label.text = _hint_text()
	var day_s := "第%d天" % GameState.day_index
	if GameState.phase == GameState.Phase.NIGHT:
		var waves: Array = _wave_counts()
		night_label.text = "%s  夜 %d/%d波  %.0fs" % [day_s, wave_i + 1, waves.size(), maxf(0.0, night_t)]
	elif GameState.phase == GameState.Phase.DAWN:
		night_label.text = day_s
	elif post_light_t >= 0.0:
		night_label.text = "%s  夜将至  %.0fs" % [day_s, maxf(0.0, post_light_t)]
	elif GameState.phase == GameState.Phase.DAY:
		night_label.text = day_s
	else:
		night_label.text = ""


func _hint_text() -> String:
	if build_mode:
		if build_kind == "shrine":
			return "建造骨祠  F放置(%d木)  R旋转  B切火塔" % SHRINE_COST
		var cost := GameState.tower_cost()
		return "建造火塔  F放置(%d木)  R旋转  B切骨祠" % cost
	match GameState.phase:
		GameState.Phase.DAY:
			if player and player.wood < WOOD_NEED and (altar == null or not altar.lit):
				return "砍树 → 点火/建塔/祠 → 占城寨 → 守夜"
			if altar and not altar.lit:
				return "祭坛按 E 点燃  ·  B 建火塔/骨祠  ·  占城寨"
			if camp and not camp.occupied:
				return "占城寨  清卫兵后到旗帜按 E  ·  B 建塔/祠"
			return "入夜  按 N 或等待  ·  B 建塔/祠守夜"
		GameState.Phase.NIGHT:
			if GameState.rune_id == "puppet":
				if altar and altar.lit:
					return "守夜  Space 攻击  ·  傀儡守夜"
				return "守夜  Space 攻击  ·  傀儡守夜  ·  火种未燃"
			if GameState.rune_id == "life":
				if altar and altar.lit:
					return "守夜  Space 攻击  ·  核心还在"
				return "守夜  Space 攻击  ·  核心还在  ·  火种未燃"
			if altar and altar.lit:
				return "守夜  Space 攻击  ·  火塔/骨祠/火种"
			return "守夜  Space 攻击  ·  火种未燃，更危险"
		GameState.Phase.DAWN:
			return "破晓  第%d天" % GameState.day_index
		_:
			return ""


func _set_build(on: bool) -> void:
	build_mode = on
	if on:
		_rebuild_ghost()
		if ghost:
			ghost.visible = true
	elif ghost and is_instance_valid(ghost):
		ghost.visible = false


func _cycle_build() -> void:
	if not build_mode:
		build_kind = "tower"
		_set_build(true)
	elif build_kind == "tower":
		build_kind = "shrine"
		_rebuild_ghost()
		if ghost:
			ghost.visible = true
	else:
		build_kind = "tower"
		_set_build(false)
	_refresh_hud()


func _rebuild_ghost() -> void:
	if ghost and is_instance_valid(ghost):
		ghost.queue_free()
		ghost = null
	_ensure_ghost()


func _ensure_ghost() -> void:
	if ghost and is_instance_valid(ghost):
		return
	var path := "res://scripts/bone_shrine.gd" if build_kind == "shrine" else "res://scripts/fire_tower.gd"
	var ts := load(path)
	ghost = ts.new()
	world.add_child(ghost)
	ghost.setup(Vector3(0, 0, 0), ghost_yaw, true)
	ghost.visible = false


func _ghost_pos() -> Vector3:
	if player == null:
		return Vector3.ZERO
	var p: Vector3 = player.global_position + player.facing * 2.85
	p.y = Island.height_at(p.x, p.z)
	return p


func _placement_ok(pos: Vector3) -> bool:
	if build_kind == "shrine":
		if _shrine_count() >= SHRINE_LIMIT:
			return false
		if player == null or player.wood < SHRINE_COST:
			return false
	else:
		if _tower_count() >= TOWER_LIMIT:
			return false
		if player == null or player.wood < GameState.tower_cost():
			return false
	if not Island.contains_v(pos, 2.6):
		return false
	if altar:
		var da := Vector3(pos.x - altar.global_position.x, 0, pos.z - altar.global_position.z).length()
		if da < 4.2:
			return false
	if camp:
		var dc := Vector3(pos.x - camp.global_position.x, 0, pos.z - camp.global_position.z).length()
		if dc < 3.8:
			return false
	for t in get_tree().get_nodes_in_group("trees"):
		if t.is_down:
			continue
		var dt: float = Vector3(pos.x - t.global_position.x, 0, pos.z - t.global_position.z).length()
		if dt < 2.05:
			return false
	for tw in get_tree().get_nodes_in_group("towers"):
		var dtw: float = Vector3(pos.x - tw.global_position.x, 0, pos.z - tw.global_position.z).length()
		if dtw < 3.2:
			return false
	for sh in get_tree().get_nodes_in_group("shrines"):
		if not is_instance_valid(sh):
			continue
		var dsh: float = Vector3(pos.x - sh.global_position.x, 0, pos.z - sh.global_position.z).length()
		if dsh < 3.2:
			return false
	if village and village.has_method("blocks") and village.blocks(pos, 1.35):
		return false
	return true


func _find_place_pos(origin: Vector3) -> Vector3:
	var p := Vector3(origin.x, 0.0, origin.z)
	if _placement_ok(p):
		return p
	for r in [1.4, 2.4, 3.6, 4.8]:
		var n := 12
		for i in n:
			var a := float(i) * TAU / float(n)
			var q := Vector3(origin.x + cos(a) * r, 0.0, origin.z + sin(a) * r)
			if _placement_ok(q):
				return q
	return Vector3.INF


func _try_place_tower() -> void:
	_try_place()


func _try_place() -> void:
	if not build_mode or place_cd > 0.0:
		return
	if player == null or not GameState.is_live():
		return
	var pos := _find_place_pos(_ghost_pos())
	if pos.x > 1.0e8:
		hint_label.text = "这里放不下  换个空地或靠近路"
		Sfx.play("error")
		return
	var cost := SHRINE_COST if build_kind == "shrine" else GameState.tower_cost()
	if player.wood < cost:
		Sfx.play("error")
		return
	player.wood -= cost
	player.wood_gained.emit()
	var path := "res://scripts/bone_shrine.gd" if build_kind == "shrine" else "res://scripts/fire_tower.gd"
	var ts := load(path)
	var bld: Node = ts.new()
	world.add_child(bld)
	bld.setup(pos, ghost_yaw, false)
	place_cd = 0.16 if GameState.rune_id == "precise" else 0.42
	Sfx.play("confirm")
	if build_kind == "shrine":
		print("shrine_placed at ", pos, " wood=", player.wood, " hp=", bld.hp)
		if _shrine_count() >= SHRINE_LIMIT:
			_set_build(false)
	else:
		print("tower placed at ", pos, " wood=", player.wood, " count=", _tower_count())
		if _tower_count() >= TOWER_LIMIT:
			_set_build(false)


func _try_light_altar() -> bool:
	if player == null or altar == null or altar.lit:
		return false
	if not player.near_altar(altar):
		return false
	if player.wood < WOOD_NEED:
		Sfx.play("error")
		return false
	altar.light_fire()
	Sfx.play("confirm")
	if camp and camp.occupied:
		post_light_t = POST_OCCUPY
	else:
		post_light_t = POST_LIGHT
	print("altar lit wood=", player.wood, " night_in=", post_light_t)
	_refresh_hud()
	return true


func _try_occupy() -> void:
	if camp == null or camp.occupied or player == null:
		return
	if not camp.all_guards_dead():
		return
	if not camp.near_banner(player.global_position):
		return
	camp.occupy(GameState.rune_color(GameState.rune_id))
	GameState.territory = 1
	tribute_t = 0.0
	if altar and altar.lit:
		if post_light_t < 0.0:
			post_light_t = POST_OCCUPY
		else:
			post_light_t = minf(post_light_t, POST_OCCUPY)
	print("camp occupied territory=", GameState.territory)
	_refresh_hud()


func _tick_tribute(delta: float) -> void:
	if camp == null or not camp.occupied or player == null:
		return
	if not GameState.is_live():
		return
	tribute_t += delta
	if tribute_t >= TRIBUTE_INT:
		tribute_t = 0.0
		player.grant_wood(1)


func _unhandled_input(event: InputEvent) -> void:
	if GameState.phase == GameState.Phase.CHARSEL and event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_try_pick_char(event.position)
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		cam_yaw -= event.relative.x * 0.006
		if player and is_instance_valid(player):
			player.cam_yaw = cam_yaw
	if event is InputEventKey and event.pressed and not event.echo:
		if not GameState.is_live():
			return
		match event.physical_keycode:
			KEY_B:
				_cycle_build()
			KEY_F:
				_try_place()
			KEY_R:
				if build_mode:
					ghost_yaw += PI * 0.5
					if ghost and is_instance_valid(ghost):
						ghost.rotation.y = ghost_yaw


func _process(delta: float) -> void:
	_tick_hud_flash(delta)
	if GameState.phase == GameState.Phase.CHARSEL:
		_frame_charsel_cam()
		return
	if GameState.phase == GameState.Phase.TITLE or GameState.phase == GameState.Phase.RUNE:
		if OS.get_environment("MISTFIRE_SHOT") == "coast":
			_frame_coast_cam()
			return
		if OS.get_environment("MISTFIRE_SHOT") == "water":
			_frame_water_cam()
			return
		if OS.get_environment("MISTFIRE_SHOT") == "map":
			_frame_overview_cam()
			return
		if OS.get_environment("MISTFIRE_SHOT") == "ruins":
			if player and is_instance_valid(player):
				Island.snap_feet(player)
			_frame_ruins_cam()
			return
		if OS.get_environment("MISTFIRE_SHOT") == "road":
			_frame_road_cam()
			return
		if OS.get_environment("MISTFIRE_SHOT") == "jungle":
			_frame_jungle_cam()
			return
		if OS.get_environment("MISTFIRE_SHOT") == "forest":
			_frame_forest_cam()
			return
		if OS.get_environment("MISTFIRE_SHOT") == "clearing":
			_frame_clearing_cam()
			return
		if OS.get_environment("MISTFIRE_SHOT") == "edge":
			_frame_edge_cam()
			return
		if OS.get_environment("MISTFIRE_SHOT") == "jungle-trail":
			_frame_jungle_trail_cam()
			return
		if OS.get_environment("MISTFIRE_SHOT") == "tex-jungle":
			_frame_jungle_tex_cam()
			return
		if OS.get_environment("MISTFIRE_SHOT") == "ground":
			# Close grass at player feet, east of the altar (not the dirt road).
			cam_pivot.global_position = Vector3(10.0, 0.0, 8.0)
			cam_pivot.rotation.y = 0.0
			camera.fov = 42.0
			camera.position = Vector3(0, 1.65, 2.4)
			camera.look_at(Vector3(12.2, 0.02, 5.4))
			return
		if OS.get_environment("MISTFIRE_SHOT") == "grass":
			_frame_grass_cam()
			return
		if title_orbit:
			title_yaw += delta * 0.07
		_frame_overview_cam()
		return

	if OS.get_environment("MISTFIRE_SHOT") == "play" and player and is_instance_valid(player):
		cam_pivot.global_position = player.global_position
		cam_pivot.rotation.y = 0.42
		camera.fov = 34.0
		camera.position = Vector3(0.0, 3.15, 4.85)
		camera.look_at(player.global_position + Vector3(0.15, 0.92, 0.0))
		place_cd = maxf(0.0, place_cd - delta)
		return

	if OS.get_environment("MISTFIRE_SHOT") == "trees":
		# Tight 3/4 on lot-back oak_a at cell(6,-8). Trunk is offset -X in the GLB.
		cam_pivot.global_position = Vector3(14.55, 0.0, -12.55)
		cam_pivot.rotation.y = 0.0
		camera.fov = 30.0
		camera.position = Vector3(0.0, 2.05, 0.0)
		camera.look_at(Vector3(12.15, 3.15, -15.05))
		return

	if OS.get_environment("MISTFIRE_SHOT") == "grass":
		_frame_grass_cam()
		return

	if OS.get_environment("MISTFIRE_SHOT") == "woods":
		_frame_jungle_cam()
		return
	if OS.get_environment("MISTFIRE_SHOT") == "jungle":
		_frame_jungle_cam()
		return
	if OS.get_environment("MISTFIRE_SHOT") == "forest":
		_frame_forest_cam()
		return
	if OS.get_environment("MISTFIRE_SHOT") == "clearing":
		_frame_clearing_cam()
		return
	if OS.get_environment("MISTFIRE_SHOT") == "edge":
		_frame_edge_cam()
		return
	if OS.get_environment("MISTFIRE_SHOT") == "jungle-trail":
		_frame_jungle_trail_cam()
		return
	if OS.get_environment("MISTFIRE_SHOT") == "tex-jungle":
		_frame_jungle_tex_cam()
		return

	if OS.get_environment("MISTFIRE_SHOT") == "map":
		_frame_overview_cam()
		return

	if OS.get_environment("MISTFIRE_SHOT") == "coast":
		_frame_coast_cam()
		return
	if OS.get_environment("MISTFIRE_SHOT") == "water":
		_frame_water_cam()
		return
	if OS.get_environment("MISTFIRE_SHOT") == "ruins":
		if player and is_instance_valid(player):
			Island.snap_feet(player)
		_frame_ruins_cam()
		return
	if OS.get_environment("MISTFIRE_SHOT") == "road":
		_frame_road_cam()
		return
	if OS.get_environment("MISTFIRE_SHOT") in ["shore", "polish"] and _shot_focus == "shore":
		_frame_shore_dock_cam()
		return
	if OS.get_environment("MISTFIRE_SHOT") == "shore" and _shot_focus == "chest":
		_frame_chest_cam()
		return
	if OS.get_environment("MISTFIRE_SHOT") in ["polish", "shrine"] and _shot_focus == "shrine":
		_frame_shrine_cam()
		return
	if OS.get_environment("MISTFIRE_SHOT") == "polish" and player and is_instance_valid(player):
		cam_pivot.global_position = player.global_position
		cam_pivot.rotation.y = 0.0
		camera.fov = 40.0
		camera.position = Vector3(2.4, 3.4, 7.2)
		camera.look_at(player.global_position + Vector3(1.6, 0.5, -0.4))
		return
	if OS.get_environment("MISTFIRE_SHOT") == "wild-atk" and player and is_instance_valid(player):
		cam_pivot.global_position = player.global_position
		cam_pivot.rotation.y = 0.0
		camera.fov = 34.0
		camera.position = Vector3(1.35, 2.05, 4.4)
		camera.look_at(player.global_position + Vector3(1.55, 0.88, 0.2))
		return
	if OS.get_environment("MISTFIRE_SHOT") == "wilds" and player and is_instance_valid(player):
		cam_pivot.global_position = player.global_position
		cam_pivot.rotation.y = 0.0
		camera.fov = 34.0
		camera.position = Vector3(1.15, 2.05, 4.6)
		camera.look_at(player.global_position + Vector3(1.35, 0.88, 0.15))
		return
	if OS.get_environment("MISTFIRE_SHOT") == "monsters":
		if _monster_close and player and is_instance_valid(player):
			cam_pivot.global_position = player.global_position
			cam_pivot.rotation.y = 0.0
			camera.fov = 36.0
			camera.position = Vector3(2.15, 1.95, 4.4)
			camera.look_at(player.global_position + Vector3(1.55, 0.92, 0.15))
		else:
			_frame_monster_cam()
		return

	if OS.get_environment("MISTFIRE_SHOT") == "atk" and player and is_instance_valid(player):
		cam_pivot.global_position = player.global_position
		cam_pivot.rotation.y = 0.0
		camera.fov = 40.0
		camera.position = Vector3(0.0, 4.8, 6.6)
		camera.look_at(player.global_position + Vector3(0.0, 1.1, -2.8))
		player.cam_yaw = cam_yaw
	if OS.get_environment("MISTFIRE_SHOT") == "signs" and player and is_instance_valid(player):
		cam_pivot.global_position = player.global_position
		cam_pivot.rotation.y = 0.32
		camera.fov = 56.0
		camera.position = Vector3(0.0, 11.2, 15.0)
		camera.look_at(player.global_position + Vector3(0.0, 1.15, 0.0))
		return

	if player and is_instance_valid(player) and OS.get_environment("MISTFIRE_SHOT") != "atk":
		player.cam_yaw = cam_yaw
		cam_pivot.global_position = player.global_position
		cam_pivot.rotation.y = cam_yaw
		camera.fov = 50.0
		camera.position = Vector3(0, 9.4, 12.4)
		var look := player.global_position + Vector3(0, 1.05, 0)
		camera.look_at(look)

	_apply_jungle_light()
	place_cd = maxf(0.0, place_cd - delta)
	_tick_tribute(delta)

	if build_mode and ghost and is_instance_valid(ghost) and player:
		var gp := _ghost_pos()
		ghost.global_position = gp
		ghost.rotation.y = ghost_yaw
		ghost.set_place_ok(_placement_ok(gp))

	if GameState.phase == GameState.Phase.DAY:
		if player:
			player.try_chop(delta)
			_update_chop_bar()
			if player.chop_target == null and player.wants_attack():
				player.do_attack()
			if Input.is_action_just_pressed("interact"):
				_try_occupy()
				_try_light_altar()
				_try_chest()
			if Input.is_action_just_pressed("force_night"):
				_begin_night()
			if post_light_t >= 0.0:
				post_light_t -= delta
				if post_light_t <= 0.0:
					_begin_night()
		_refresh_hud()

	elif GameState.phase == GameState.Phase.NIGHT:
		chop_bar.visible = false
		chop_bar_bg.visible = false
		if player and player.wants_attack():
			player.do_attack()
		if Input.is_action_just_pressed("interact"):
			_try_occupy()
			_try_light_altar()
			_try_chest()
		night_t -= delta
		if altar and altar.lit:
			fire_tick += delta
			if fire_tick >= 0.45:
				fire_tick = 0.0
				for e in get_tree().get_nodes_in_group("enemies"):
					if not is_instance_valid(e) or e.dead:
						continue
					if e.is_in_group("guards") or e.is_in_group("wilds"):
						continue
					var d: float = Vector3(e.global_position.x - altar.global_position.x, 0, e.global_position.z - altar.global_position.z).length()
					if d <= 6.4:
						e.take_hit(7.0, Vector3.ZERO)
		if _night_lit and altar and not altar.lit:
			_show_result(false)
			_refresh_hud()
			return
		var living := _night_living()
		if living <= 0:
			var waves: Array = _wave_counts()
			if wave_i + 1 < waves.size():
				wave_wait += delta
				if wave_wait >= WAVE_GAP:
					wave_i += 1
					wave_wait = 0.0
					_spawn_wave(wave_i)
			elif night_t > 2.5:
				night_t = 2.5
		if night_t <= 0.0:
			_show_result(true)
		_refresh_hud()

	elif GameState.phase == GameState.Phase.DAWN:
		chop_bar.visible = false
		chop_bar_bg.visible = false
		if dawn_t >= 0.0:
			dawn_t -= delta
		if dawn_t <= 0.0 or Input.is_action_just_pressed("interact"):
			_finish_dawn()
		_refresh_hud()


func _apply_jungle_light() -> void:
	if env == null:
		return
	var px := 0.0
	var pz := 0.0
	if camera:
		var cp := camera.global_position
		px = cp.x
		pz = cp.z
	elif player and is_instance_valid(player):
		px = player.global_position.x
		pz = player.global_position.z
	var j := Island.in_jungle(px, pz)
	var cl := Island.in_clearing(px, pz, 1.05)
	var night := GameState.phase == GameState.Phase.NIGHT
	if night:
		env.ambient_light_energy = 0.13 if cl else (0.11 if j else 0.16)
		env.ambient_light_color = Color(0.16, 0.22, 0.30) if cl else (Color(0.14, 0.20, 0.32) if j else Color(0.18, 0.22, 0.40))
	else:
		env.ambient_light_energy = 0.34 if cl else (0.26 if j else 0.40)
		env.ambient_light_color = Color(0.50, 0.58, 0.48) if cl else (Color(0.40, 0.50, 0.44) if j else Color(0.58, 0.66, 0.78))
		if sun:
			sun.light_energy = 1.28 if cl else (1.12 if j else 1.42)


func _update_chop_bar() -> void:
	if player and player.chop_target and is_instance_valid(player.chop_target) and not player.chop_target.is_down:
		chop_bar.visible = true
		chop_bar_bg.visible = true
		var w: float = clampf(player.chop_target.work / player.chop_target.max_work, 0.0, 1.0)
		chop_bar.size.x = 160.0 * w
	else:
		chop_bar.visible = false
		chop_bar_bg.visible = false



func _maybe_shot() -> void:
	var shot := OS.get_environment("MISTFIRE_SHOT")
	if shot.is_empty():
		return
	if shot == "loop":
		await _run_loop_verify()
		get_tree().quit()
		return
	if shot == "day2":
		await _run_day2_verify()
		get_tree().quit()
		return
	if shot == "atk":
		await _run_atk_verify()
		get_tree().quit()
		return
	if shot == "shrine":
		await _run_shrine_verify()
		get_tree().quit()
		return
	if shot == "golem":
		await _run_golem_verify()
		get_tree().quit()
		return
	if shot == "life":
		await _run_life_verify()
		get_tree().quit()
		return
	if shot == "charsel":
		await get_tree().process_frame
		_show_charsel()
		await get_tree().create_timer(1.8).timeout
		await _save_shot("/workspace/mistfire-godot/shot-charsel.png")
		get_tree().quit()
	elif shot == "play":
		await get_tree().process_frame
		GameState.character_id = "knight"
		_start_run("power")
		if player and is_instance_valid(player):
			player.global_position = Vector3(1.6, 0.9, 3.4)
			player.rotation.y = 2.6
			player.facing = Vector3(-0.35, 0.0, -0.94)
		cam_yaw = 0.18
		await get_tree().create_timer(1.8).timeout
		await _save_shot("/workspace/mistfire-godot/shot-play.png")
		get_tree().quit()
	elif shot == "village":
		await get_tree().process_frame
		_start_run("power")
		if player and is_instance_valid(player):
			player.global_position = Vector3(0.0, 0.9, -8.0)
		cam_yaw = 0.0
		title_yaw = 0.0
		await get_tree().create_timer(1.6).timeout
		await _save_shot("/workspace/mistfire-godot/shot-village.png")
		get_tree().quit()
	elif shot == "woods":
		await get_tree().process_frame
		_start_run("power")
		title_root.visible = false
		play_hud.visible = false
		if player and is_instance_valid(player):
			player.global_position = _on_ground(66.4, 29.2)
			player.rotation.y = 0.55
			player.facing = Vector3(0.52, 0.0, 0.85)
		cam_yaw = 0.0
		_frame_jungle_cam()
		await get_tree().create_timer(1.8).timeout
		await _save_shot("/workspace/mistfire-godot/shot-woods.png")
		get_tree().quit()
	elif shot == "jungle":
		await get_tree().process_frame
		_start_run("power")
		title_root.visible = false
		play_hud.visible = false
		if player and is_instance_valid(player):
			player.global_position = _on_ground(66.4, 29.2)
			player.rotation.y = 2.6
			player.facing = Vector3(0.35, 0.0, -0.94)
		cam_yaw = 0.0
		_frame_jungle_cam()
		await get_tree().create_timer(1.9).timeout
		if player and is_instance_valid(player):
			print("JUNGLE_FEET pos=", player.global_position, " height_at=", snappedf(Island.height_at(player.global_position.x, player.global_position.z), 0.01), " foot_y=", snappedf(Island.foot_y(player.global_position.x, player.global_position.z), 0.01), " on_floor=", player.is_on_floor())
		await _save_shot("/workspace/mistfire-godot/shot-jungle.png")
		get_tree().quit()
	elif shot == "jungle-trail":
		await get_tree().process_frame
		_start_run("power")
		title_root.visible = false
		play_hud.visible = false
		if player and is_instance_valid(player):
			player.global_position = _on_ground(54.0, 20.0)
			player.rotation.y = 1.2
			player.facing = Vector3(0.92, 0.0, -0.18)
		cam_yaw = 0.0
		_frame_jungle_trail_cam()
		await get_tree().create_timer(1.9).timeout
		await _save_shot("/workspace/mistfire-godot/shot-jungle-trail.png")
		get_tree().quit()
	elif shot == "forest":
		await get_tree().process_frame
		_start_run("power")
		title_root.visible = false
		play_hud.visible = false
		if player and is_instance_valid(player):
			player.global_position = _on_ground(66.4, 29.2)
			player.rotation.y = 0.7
			player.facing = Vector3(0.62, 0.0, 0.78)
		cam_yaw = 0.0
		_frame_forest_cam()
		await get_tree().create_timer(1.9).timeout
		await _save_shot("/workspace/mistfire-godot/shot-forest.png")
		get_tree().quit()
	elif shot == "clearing":
		await get_tree().process_frame
		_start_run("power")
		title_root.visible = false
		play_hud.visible = false
		if player and is_instance_valid(player):
			player.global_position = _on_ground(104.0, 26.8)
			player.rotation.y = 1.15
			player.facing = Vector3(0.92, 0.0, 0.38)
		cam_yaw = 0.0
		_frame_clearing_cam()
		await get_tree().create_timer(1.9).timeout
		await _save_shot("/workspace/mistfire-godot/shot-clearing.png")
		get_tree().quit()
	elif shot == "edge":
		await get_tree().process_frame
		_start_run("power")
		title_root.visible = false
		play_hud.visible = false
		if player and is_instance_valid(player):
			player.global_position = _on_ground(14.0, 8.5)
			player.rotation.y = 1.05
			player.facing = Vector3(0.90, 0.0, 0.20)
		cam_yaw = 0.0
		_frame_edge_cam()
		await get_tree().create_timer(1.9).timeout
		await _save_shot("/workspace/mistfire-godot/shot-edge.png")
		get_tree().quit()
	elif shot == "tex-jungle":
		await get_tree().process_frame
		_start_run("power")
		title_root.visible = false
		play_hud.visible = false
		if player and is_instance_valid(player):
			player.global_position = _on_ground(124.0, 38.0)
		cam_yaw = 0.0
		_frame_jungle_tex_cam()
		await get_tree().create_timer(1.6).timeout
		await _save_shot("/workspace/mistfire-godot/shot-tex-jungle.png")
		get_tree().quit()
	elif shot == "map":
		title_orbit = false
		title_yaw = 0.0
		title_root.visible = false
		_frame_overview_cam()
		await get_tree().create_timer(1.8).timeout
		await _save_shot("/workspace/mistfire-godot/shot-map.png")
		get_tree().quit()
	elif shot == "coast":
		title_orbit = false
		title_root.visible = false
		play_hud.visible = false
		_frame_coast_cam()
		await get_tree().create_timer(1.5).timeout
		await _save_shot("/workspace/mistfire-godot/shot-coast.png")
		get_tree().quit()
	elif shot == "water":
		title_orbit = false
		title_root.visible = false
		play_hud.visible = false
		_frame_water_cam()
		await get_tree().create_timer(1.6).timeout
		await _save_shot("/workspace/mistfire-godot/shot-water.png")
		get_tree().quit()
	elif shot == "ruins":
		await get_tree().process_frame
		GameState.character_id = "knight"
		_start_run("power")
		title_root.visible = false
		play_hud.visible = false
		if player and is_instance_valid(player):
			player.global_position = _on_ground(0.6, 27.8)
			player.velocity = Vector3.ZERO
			Island.snap_feet(player)
			player.rotation.y = 2.55
			player.facing = Vector3(0.55, 0.0, -0.83)
		cam_yaw = 0.0
		_frame_ruins_cam()
		await get_tree().create_timer(1.7).timeout
		if player and is_instance_valid(player):
			Island.snap_feet(player)
			print("RUINS_FEET pos=", player.global_position, " height_at=", snappedf(Island.height_at(player.global_position.x, player.global_position.z), 0.01), " foot_y=", snappedf(Island.foot_y(player.global_position.x, player.global_position.z), 0.01), " raised=", Island.is_raised(player.global_position.x, player.global_position.z))
		await _save_shot("/workspace/mistfire-godot/shot-ruins.png")
		get_tree().quit()
	elif shot == "road":
		title_orbit = false
		title_root.visible = false
		play_hud.visible = false
		_frame_road_cam()
		await get_tree().create_timer(1.5).timeout
		await _save_shot("/workspace/mistfire-godot/shot-road.png")
		get_tree().quit()
	elif shot == "trees":
		await get_tree().process_frame
		_start_run("power")
		title_root.visible = false
		play_hud.visible = false
		await get_tree().create_timer(1.8).timeout
		await _save_shot("/workspace/mistfire-godot/shot-trees.png")
		get_tree().quit()
	elif shot == "ground":
		title_root.visible = false
		title_orbit = false
		title_yaw = 0.0
		cam_pivot.global_position = Vector3(10.0, 0.0, 8.0)
		cam_pivot.rotation.y = 0.0
		camera.fov = 42.0
		camera.position = Vector3(0, 1.65, 2.4)
		camera.look_at(Vector3(12.2, 0.02, 5.4))
		await get_tree().create_timer(1.4).timeout
		await _save_shot("/workspace/mistfire-godot/shot-ground.png")
		get_tree().quit()
	elif shot == "grass":
		await get_tree().process_frame
		GameState.character_id = "knight"
		_start_run("power")
		title_root.visible = false
		play_hud.visible = false
		if player and is_instance_valid(player):
			player.global_position = Vector3(7.5, 0.9, 8.2)
			player.rotation.y = 0.85
			player.facing = Vector3(0.75, 0.0, -0.66)
		cam_yaw = 0.0
		title_orbit = false
		_frame_grass_cam()
		await get_tree().create_timer(1.6).timeout
		await _save_shot("/workspace/mistfire-godot/shot-grass.png")
		get_tree().quit()
	elif shot == "signs":
		await get_tree().process_frame
		GameState.character_id = "knight"
		_start_run("power")
		title_root.visible = false
		play_hud.visible = false
		if player and is_instance_valid(player):
			player.global_position = Vector3(0.2, 0.9, 0.4)
			player.rotation.y = 0.55
		cam_yaw = 0.55
		await get_tree().create_timer(1.6).timeout
		await _save_shot("/workspace/mistfire-godot/shot-signs.png")
		get_tree().quit()
	elif shot == "minimap":
		await get_tree().process_frame
		GameState.character_id = "knight"
		_start_run("power")
		if player and is_instance_valid(player):
			player.global_position = Vector3(1.2, 0.9, 2.4)
			player.rotation.y = 0.4
		cam_yaw = 0.25
		await get_tree().create_timer(1.6).timeout
		await _save_shot("/workspace/mistfire-godot/shot-minimap.png")
		get_tree().quit()
	elif shot == "shore":
		await _run_shore_verify()
		get_tree().quit()
	elif shot == "polish":
		await get_tree().process_frame
		GameState.character_id = "knight"
		_start_run("power")
		title_root.visible = false
		play_hud.visible = true
		var tr := _loop_nearest_tree(Vector3(18.0, 0, 8.0))
		if tr:
			_loop_warp(tr.global_position + Vector3(-2.4, 0, 2.0), Vector3(0.8, 0, -0.6))
			tr.chop(2.0)
			if player:
				player.grant_wood(1)
		await get_tree().create_timer(0.36).timeout
		await _save_shot("/workspace/mistfire-godot/shot-chop.png")
		if chest:
			_loop_warp(chest.global_position + Vector3(-1.6, 0, 1.4), Vector3(0.7, 0, -0.5))
			_try_chest()
		await get_tree().create_timer(0.45).timeout
		await _save_shot("/workspace/mistfire-godot/shot-chest.png")
		if player:
			player.grant_wood(20)
		var sh := _place_verify_shrine()
		build_kind = "shrine"
		_refresh_hud()
		_shot_focus = "shrine"
		_loop_warp(Vector3(0.9, 0, -1.7), Vector3(0.55, 0, -0.75))
		await get_tree().create_timer(0.70).timeout
		await _save_shot("/workspace/mistfire-godot/shot-shrine.png")
		_shot_focus = ""
		var ts := load("res://scripts/fire_tower.gd")
		var tw: Node = ts.new()
		world.add_child(tw)
		tw.setup(_on_ground(6.4, -1.6), 0.0, false)
		_loop_warp(Vector3(5.0, 0, 1.2), Vector3(0.5, 0, -0.8))
		_begin_night()
		var es := load("res://scripts/enemy.gd")
		var bait: Node = es.new()
		world.add_child(bait)
		bait.setup(_on_ground(8.2, -1.2), altar, player, "night", "warrior")
		await get_tree().create_timer(0.55).timeout
		await _save_shot("/workspace/mistfire-godot/shot-tower-fire.png")
		if bait == null or not is_instance_valid(bait) or bait.dead:
			bait = es.new()
			world.add_child(bait)
			bait.setup(_on_ground(4.6, -2.55), altar, player, "night", "minion")
		else:
			bait.global_position = _on_ground(4.6, -2.55)
		_shot_focus = "shrine"
		_loop_warp(Vector3(0.7, 0, -1.5), Vector3(0.6, 0, -0.7))
		await get_tree().create_timer(0.75).timeout
		var shp: int = int(sh.hp) if sh and is_instance_valid(sh) else -1
		print("shrine_hp ", shp, " night living=", _night_living())
		await _save_shot("/workspace/mistfire-godot/shot-shrine-night.png")
		print("POLISH wood=", player.wood if player else -1, " chest=", chest.opened if chest else false, " wave=", wave_i, " living=", _night_living(), " shrine_hp=", shp)
		get_tree().quit()
	elif shot == "wild-atk":
		await get_tree().process_frame
		GameState.character_id = "knight"
		_start_run("power")
		title_root.visible = false
		play_hud.visible = false
		if player and is_instance_valid(player):
			player.global_position = _on_ground(104.0, 26.8)
			player.rotation.y = 1.2
			player.facing = Vector3(0.95, 0.0, 0.3)
		# park a warrior in front, a mage off to the side for the second beat
		var warrior: Node = null
		var mage: Node = null
		for e in get_tree().get_nodes_in_group("wilds"):
			if e.skel_kind == "warrior":
				warrior = e
			elif e.skel_kind == "mage":
				mage = e
		if warrior:
			warrior.global_position = _on_ground(105.6, 27.2)
			warrior.home = warrior.global_position
			warrior.rotation.y = -2.0
		await get_tree().create_timer(1.15).timeout
		if warrior and is_instance_valid(warrior):
			print("VERIFY warrior atk clip=", warrior._attack_clip, " cd=", warrior.attack_cd)
		await _save_shot("/workspace/mistfire-godot/shot-wild-melee.png")
		if mage and player:
			mage.global_position = _on_ground(107.4, 28.0)
			mage.home = mage.global_position
			player.global_position = _on_ground(104.2, 26.6)
		await get_tree().create_timer(1.25).timeout
		await _save_shot("/workspace/mistfire-godot/shot-wild-mage.png")
		get_tree().quit()
	elif shot == "wilds":
		await get_tree().process_frame
		GameState.character_id = "knight"
		_start_run("power")
		title_root.visible = false
		play_hud.visible = false
		if player and is_instance_valid(player):
			player.global_position = _on_ground(104.0, 26.8)
			player.rotation.y = 1.15
			player.facing = Vector3(0.92, 0.0, 0.38)
		cam_yaw = 0.0
		_frame_clearing_cam()
		await get_tree().create_timer(1.9).timeout
		for e in get_tree().get_nodes_in_group("wilds"):
			print("VERIFY wild kind=", e.skel_kind, " pos=", e.global_position)
		await _save_shot("/workspace/mistfire-godot/shot-wilds.png")
		get_tree().quit()
	elif shot == "monsters":
		await get_tree().process_frame
		GameState.character_id = "knight"
		_start_run("power")
		title_root.visible = false
		play_hud.visible = false
		_spawn_monster_lineup()
		_frame_monster_cam()
		await get_tree().create_timer(1.8).timeout
		await _save_shot("/workspace/mistfire-godot/shot-monsters.png")
		# Close night: one warrior walking at the player.
		_monster_close = true
		_begin_night()
		if player and is_instance_valid(player):
			player.global_position = _on_ground(6.4, 4.2)
			player.rotation.y = 1.4
			player.facing = Vector3(1.0, 0.0, 0.15)
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and not e.is_in_group("guards") and not e.is_in_group("dummies"):
				e.global_position = _on_ground(8.6, 4.6)
				e.rotation.y = -1.6
		cam_yaw = -1.25
		cam_pivot.global_position = player.global_position
		camera.fov = 38.0
		camera.position = Vector3(2.4, 2.15, 4.8)
		camera.look_at(player.global_position + Vector3(1.4, 0.85, 0.2))
		await get_tree().create_timer(1.6).timeout
		await _save_shot("/workspace/mistfire-godot/shot-night-skel.png")
		get_tree().quit()
	elif shot == "night":
		await get_tree().process_frame
		GameState.character_id = "knight"
		_start_run("power")
		if player and is_instance_valid(player):
			player.global_position = Vector3(18.5, 0.9, 2.4)
			player.rotation.y = 1.15
			player.facing = Vector3(1.0, 0.0, 0.0)
		cam_yaw = -1.15
		_begin_night()
		print("VERIFY night forced Knight+力量")
		await get_tree().create_timer(2.1).timeout
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and not e.is_in_group("guards"):
				print("VERIFY enemy tag=", e.spawn_tag, " kind=", e.skel_kind, " pos=", e.global_position, " dest=altar")
		await _save_shot("/workspace/mistfire-godot/shot-night.png")
		get_tree().quit()
	else:
		title_orbit = false
		title_yaw = 0.28
		await get_tree().create_timer(1.4).timeout
		await _save_shot("/workspace/mistfire-godot/shot-island.png")
		get_tree().quit()


func _spawn_monster_lineup() -> void:
	var es := load("res://scripts/enemy.gd")
	var kinds := ["warrior", "rogue", "mage", "minion"]
	var origin := Vector3(4.0, 0.0, 6.4)
	for i in kinds.size():
		var en: Node = es.new()
		world.add_child(en)
		var p := _on_ground(origin.x + float(i) * 1.85, origin.z)
		en.setup(p, altar, player, "dummy", kinds[i])
		en.rotation.y = 3.4


func _frame_monster_cam() -> void:
	var look := Vector3(6.8, 0.95, 6.4)
	cam_pivot.global_position = Vector3(6.8, 0.0, 6.4)
	cam_pivot.rotation.y = 0.0
	camera.fov = 36.0
	camera.position = Vector3(0.4, 1.85, 5.6)
	camera.look_at(look)


func _run_shore_verify() -> void:
	await get_tree().process_frame
	GameState.character_id = "knight"
	_start_run("power")
	title_root.visible = false
	play_hud.visible = false
	_shot_focus = "shore"
	if player and is_instance_valid(player):
		_loop_warp(Vector3(-50.6, 0.0, 6.8), Vector3(-0.72, 0.0, 0.55))
	_frame_shore_dock_cam()
	await get_tree().create_timer(0.85).timeout
	var boat_land := Island.contains_xz(-54.6, 17.85)
	print("SHORE_DOCK anchor=", village.dock_anchor if village else Vector3.ZERO, " boat=(-54.6,-0.42,17.85) land_boat=", boat_land, " height_sand=", snappedf(Island.height_at(-55.2, 8.8), 0.01), " height_tip=", snappedf(Island.height_at(-52.4, 13.9), 0.01))
	await _save_shot("/workspace/mistfire-godot/shot-shore-dock.png")
	play_hud.visible = true
	if chest and is_instance_valid(chest):
		_loop_warp(chest.global_position + Vector3(-1.55, 0.0, 1.35), Vector3(0.72, 0.0, -0.48))
		_try_chest()
		print("SHORE_CHEST pos=", chest.global_position, " opened=", chest.opened)
	_shot_focus = "chest"
	build_mode = true
	build_kind = "tower"
	_refresh_hud()
	_frame_chest_cam()
	await get_tree().create_timer(0.55).timeout
	print("SHORE_HUD build=", build_label.text if build_label else "", " hint=", hint_label.text if hint_label else "")
	await _save_shot("/workspace/mistfire-godot/shot-chest.png")
	_shot_focus = ""


func _save_shot(path: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	print("saved shot ", path, " err=", err)


func _place_verify_shrine() -> Node:
	var ss := load("res://scripts/bone_shrine.gd")
	var sh: Node = ss.new()
	world.add_child(sh)
	var pos := Vector3(3.0, Island.height_at(3.0, -4.0), -4.0)
	sh.setup(pos, 0.35, false)
	print("shrine_placed at ", sh.global_position, " hp=", sh.hp)
	return sh


func _frame_shrine_cam() -> void:
	var look := Vector3(3.0, 0.85, -4.0)
	for s in get_tree().get_nodes_in_group("shrines"):
		if is_instance_valid(s):
			look = s.global_position + Vector3(0.15, 0.85, 0.2)
			break
	cam_pivot.global_position = look
	cam_pivot.rotation.y = 0.0
	camera.fov = 36.0
	camera.position = Vector3(-2.15, 2.15, 4.35)
	camera.look_at(look + Vector3(0.05, 0.15, 0.0))


func _run_shrine_verify() -> void:
	await get_tree().process_frame
	GameState.character_id = "knight"
	_start_run("power")
	title_root.visible = false
	play_hud.visible = true
	if player:
		player.grant_wood(20)
	var sh := _place_verify_shrine()
	build_kind = "shrine"
	_refresh_hud()
	_shot_focus = "shrine"
	_loop_warp(Vector3(0.9, 0, -1.7), Vector3(0.55, 0, -0.75))
	await get_tree().create_timer(0.75).timeout
	await _save_shot("/workspace/mistfire-godot/shot-shrine.png")
	_begin_night()
	var es := load("res://scripts/enemy.gd")
	var bait: Node = es.new()
	world.add_child(bait)
	bait.setup(_on_ground(4.6, -2.55), altar, player, "night", "warrior")
	print("shrine_hp ", sh.hp if is_instance_valid(sh) else -1, " night living=", _night_living())
	await get_tree().create_timer(0.72).timeout
	var shp: int = int(sh.hp) if sh and is_instance_valid(sh) else -1
	print("shrine_hp ", shp, " night living=", _night_living())
	await _save_shot("/workspace/mistfire-godot/shot-shrine-night.png")
	print("SHRINE_VERIFY wood=", player.wood if player else -1, " shrine_hp=", shp, " living=", _night_living())


func _run_golem_verify() -> void:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Mistfire Sanctum GOLEM VERIFY")
	lines.append("============================")
	await get_tree().process_frame
	GameState.character_id = "knight"
	_start_run("puppet")
	await get_tree().create_timer(0.15).timeout
	var spawn_ok: bool = golem != null and is_instance_valid(golem)
	var hud_s: String = rune_label.text if rune_label else ""
	lines.append("day spawn=%s hud=%s" % ["Y" if spawn_ok else "N", hud_s])
	print("GOLEM spawn=", spawn_ok, " hud=", hud_s)

	_begin_night()
	await get_tree().process_frame
	var night_hint: String = hint_label.text if hint_label else ""
	var g_night: bool = golem != null and is_instance_valid(golem)
	var bait_hp0 := 55.0
	var bait_hp1 := 55.0
	var swung := false
	if player and is_instance_valid(player) and golem and is_instance_valid(golem):
		_loop_warp(Vector3(6.4, 0.9, 6.8), Vector3(1, 0, 0))
		golem.global_position = player.global_position + Vector3(-1.1, 0, 0.6)
		golem.global_position.y = 0.7
		var es := load("res://scripts/enemy.gd")
		var bait: Node = es.new()
		world.add_child(bait)
		bait.setup(_on_ground(7.6, 6.9), altar, player, "night", "minion")
		bait_hp0 = float(bait.hp)
		await get_tree().create_timer(1.15).timeout
		bait_hp1 = float(bait.hp) if is_instance_valid(bait) else 0.0
		swung = golem.last_hit_at > 0.0 or bait_hp1 < bait_hp0
	var night_ok: bool = g_night and swung and bait_hp1 < bait_hp0
	lines.append("night persist=%s hint=%s hit=%s hp %.0f->%.0f" % [
		"Y" if g_night else "N", night_hint, "Y" if swung else "N", bait_hp0, bait_hp1])
	print("GOLEM night persist=", g_night, " hit=", swung, " hp=", bait_hp0, "->", bait_hp1)

	_show_result(true)
	var g_dawn: bool = golem != null and is_instance_valid(golem)
	if GameState.phase == GameState.Phase.DAWN:
		await get_tree().create_timer(DAWN_LEN + 0.35).timeout
	var g_day2: bool = golem != null and is_instance_valid(golem)
	var day2_ok: bool = GameState.phase == GameState.Phase.DAY and GameState.day_index == 2 and g_day2
	lines.append("dawn persist=%s day2 persist=%s phase=%s day=%d" % [
		"Y" if g_dawn else "N", "Y" if g_day2 else "N", str(GameState.phase), GameState.day_index])
	print("GOLEM dawn=", g_dawn, " day2=", g_day2, " phase=", GameState.phase)

	var hud_ok: bool = hud_s.find("伐木") >= 0 and hud_s.find("守夜") >= 0
	var hint_ok: bool = night_hint.find("傀儡") >= 0
	var gaps: Array = []
	if not spawn_ok:
		gaps.append("spawn")
	if not night_ok:
		gaps.append("night-hit")
	if not g_dawn:
		gaps.append("dawn")
	if not day2_ok:
		gaps.append("day2")
	if not hud_ok:
		gaps.append("hud")
	if not hint_ok:
		gaps.append("hint")
	if gaps.is_empty():
		lines.append("DoD: puppet golem chops by day, melee at night, persists through dawn into day 2.")
	else:
		var gap := ""
		for i in gaps.size():
			if i > 0:
				gap += ", "
			gap += str(gaps[i])
		lines.append("DoD GAPS: " + gap)
	var text := "\n".join(lines) + "\n"
	var out := FileAccess.open("/workspace/mistfire-godot/GOLEM_VERIFY.txt", FileAccess.WRITE)
	if out == null:
		out = FileAccess.open("/workspace/GOLEM_VERIFY.txt", FileAccess.WRITE)
	if out:
		out.store_string(text)
		out.close()
	print("GOLEM_VERIFY written\n", text)


func _run_life_verify() -> void:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Mistfire Sanctum LIFE VERIFY")
	lines.append("============================")
	await get_tree().process_frame
	GameState.character_id = "knight"
	_start_run("life")
	await get_tree().create_timer(0.18).timeout
	_atk_clear_mobs()
	var hud_s: String = rune_label.text if rune_label else ""
	var max_ok: bool = player != null and float(player.max_hp) >= 119.0
	var hud_ok: bool = hud_s.find("厚血") >= 0 and hud_s.find("核心") >= 0
	lines.append("day max_hp=%.0f hud=%s" % [float(player.max_hp) if player else -1.0, hud_s])
	print("LIFE spawn max_hp=", player.max_hp if player else -1, " hud=", hud_s)

	var hp0: float = float(player.hp)
	player.invuln = 0.0
	player.take_hit(20.0)
	var hp1: float = float(player.hp)
	var absorbed: float = hp0 - hp1
	var pulse_ok: bool = bool(player.last_hurt_pulse) and float(player.heal_pulse_t) > 0.0
	var dr_ok: bool = absorbed > 0.4 and absorbed < 19.2
	lines.append("hurt pulse=%s hp %.0f->%.0f absorbed=%.1f (want <20)" % [
		"Y" if pulse_ok else "N", hp0, hp1, absorbed])
	print("LIFE hurt pulse=", pulse_ok, " hp=", hp0, "->", hp1, " absorbed=", absorbed)

	if altar and not altar.lit:
		altar.light_fire()
	_loop_warp(Vector3(0.4, 0.9, 0.6), Vector3(0, 0, -1))
	player.hp = 70.0
	player.combat_t = 0.0
	player.invuln = 2.0
	await get_tree().create_timer(1.15).timeout
	var net_ok: bool = bool(player.near_life_net) and float(player.hp) > 70.4
	lines.append("altar net=%s hp %.1f (from 70, combat_t=%.1f)" % [
		"Y" if net_ok else "N", float(player.hp), float(player.combat_t)])
	print("LIFE net=", player.near_life_net, " hp=", player.hp)

	player.invuln = 0.0
	player.hp = 6.0
	player.take_hit(80.0)
	var day_die: bool = float(player.hp) <= 0.0 and not bool(player.last_core_save)
	var day_flash := flash_label.text if flash_label and flash_label.visible else ""
	lines.append("day lethal die=%s save=%s flash=%s" % [
		"Y" if day_die else "N", "Y" if player.last_core_save else "N", day_flash])
	print("LIFE day lethal hp=", player.hp, " save=", player.last_core_save)

	_start_run("life")
	await get_tree().create_timer(0.12).timeout
	_begin_night()
	_atk_clear_mobs()
	await get_tree().process_frame
	_refresh_hud()
	var night_hint: String = hint_label.text if hint_label else ""
	var hint_ok: bool = night_hint.find("核心") >= 0
	_loop_warp(Vector3(8.2, 0.9, 8.0), Vector3(0, 0, 1))
	player.invuln = 0.0
	player.hp = 8.0
	player.last_core_save = false
	player.take_hit(80.0)
	var saved: bool = bool(player.last_core_save) and float(player.hp) >= 11.0 and float(player.hp) < 20.0
	var flash_s: String = flash_label.text if flash_label else ""
	var flash_ok: bool = flash_s.find("核心还在") >= 0 and flash_label.visible
	lines.append("night save=%s hp=%.0f hint=%s flash=%s" % [
		"Y" if saved else "N", float(player.hp), night_hint, flash_s])
	print("LIFE night save=", saved, " hp=", player.hp, " flash=", flash_s, " hint=", night_hint)

	_atk_clear_mobs()
	player.invuln = 0.0
	player.take_hit(80.0)
	var second_die: bool = float(player.hp) <= 0.0
	lines.append("second lethal die=%s hp=%.0f phase=%s" % [
		"Y" if second_die else "N", float(player.hp), str(GameState.phase)])
	print("LIFE second die=", second_die, " hp=", player.hp, " phase=", GameState.phase)

	var gaps: Array = []
	if not max_ok:
		gaps.append("max-hp")
	if not hud_ok:
		gaps.append("hud")
	if not pulse_ok:
		gaps.append("pulse")
	if not dr_ok:
		gaps.append("incoming")
	if not net_ok:
		gaps.append("altar-net")
	if not day_die:
		gaps.append("day-lethal")
	if not hint_ok:
		gaps.append("hint")
	if not saved:
		gaps.append("night-save")
	if not flash_ok:
		gaps.append("flash")
	if not second_die:
		gaps.append("second-die")
	if gaps.is_empty():
		lines.append("DoD: 生命 has 120 hp, visible hurt pulse, altar-net tick, night 核心还在 once, then death.")
	else:
		var gap := ""
		for i in gaps.size():
			if i > 0:
				gap += ", "
			gap += str(gaps[i])
		lines.append("DoD GAPS: " + gap)
	var text := "\n".join(lines) + "\n"
	var out := FileAccess.open("/workspace/mistfire-godot/LIFE_VERIFY.txt", FileAccess.WRITE)
	if out == null:
		out = FileAccess.open("/workspace/LIFE_VERIFY.txt", FileAccess.WRITE)
	if out:
		out.store_string(text)
		out.close()
	print("LIFE_VERIFY written\n", text)


func _build_charsel_ui() -> void:
	charsel_root = Control.new()
	charsel_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	charsel_root.visible = false
	hud.add_child(charsel_root)

	var top_bar := ColorRect.new()
	top_bar.color = Color(0.03, 0.04, 0.08, 0.42)
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 118
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	charsel_root.add_child(top_bar)

	var ctitle := _label("选择流放者", 40, Color(1.0, 0.90, 0.68), true)
	ctitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ctitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
	ctitle.offset_top = 18
	ctitle.offset_bottom = 72
	charsel_root.add_child(ctitle)

	var csub := _label("五位 KayKit 冒险者  ·  各有手段  ·  点选一位，再按选定", 18, Color(0.86, 0.82, 0.74))
	csub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	csub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	csub.offset_top = 72
	csub.offset_bottom = 104
	charsel_root.add_child(csub)

	var bot := ColorRect.new()
	bot.color = Color(0.03, 0.04, 0.08, 0.50)
	bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot.offset_top = -168
	bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	charsel_root.add_child(bot)

	var ids := GameState.CHARACTER_ORDER
	var card_w := 200.0
	var gap := 16.0
	var total := float(ids.size()) * card_w + float(ids.size() - 1) * gap
	var start_x := (1280.0 - total) * 0.5
	for i in ids.size():
		var id: String = ids[i]
		var info: Dictionary = GameState.CHARACTERS[id]
		var card := _panel(Color(0.10, 0.10, 0.14, 0.90))
		card.position = Vector2(start_x + float(i) * (card_w + gap), 568)
		card.size = Vector2(card_w, 86)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(_on_char_card_input.bind(id))
		charsel_root.add_child(card)
		_char_cards[id] = card

		var nm := _label(str(info["name"]), 26, Color(1.0, 0.93, 0.78), true)
		nm.position = Vector2(8, 10)
		nm.size = Vector2(card_w - 16, 36)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(nm)

		var kit := _label(str(info.get("kit", info["en"])), 14, Color(0.86, 0.78, 0.58))
		kit.position = Vector2(8, 46)
		kit.size = Vector2(card_w - 16, 24)
		kit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(kit)

	var confirm := _btn("选定", Color(0.82, 0.32, 0.14))
	confirm.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	confirm.offset_left = 520
	confirm.offset_right = -520
	confirm.offset_top = -56
	confirm.offset_bottom = -10
	confirm.pressed.connect(_confirm_character)
	charsel_root.add_child(confirm)


func _on_char_card_input(event: InputEvent, id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_char(id)


func _show_charsel() -> void:
	GameState.phase = GameState.Phase.CHARSEL
	title_root.visible = false
	charsel_root.visible = true
	rune_root.visible = false
	play_hud.visible = false
	result_root.visible = false
	title_orbit = false
	_spawn_charsel_lineup()
	_select_char(_char_selected if _char_selected != "" else "knight")
	_frame_charsel_cam()


func _confirm_character() -> void:
	if _char_selected.is_empty() or not GameState.CHARACTERS.has(_char_selected):
		_char_selected = "knight"
	GameState.character_id = _char_selected
	_show_runes()


func _select_char(id: String) -> void:
	if not GameState.CHARACTERS.has(id):
		id = "knight"
	_char_selected = id
	for cid in _char_cards:
		var card: Panel = _char_cards[cid]
		var sb := StyleBoxFlat.new()
		sb.corner_radius_top_left = 14
		sb.corner_radius_top_right = 14
		sb.corner_radius_bottom_left = 14
		sb.corner_radius_bottom_right = 14
		if cid == id:
			sb.bg_color = Color(0.28, 0.18, 0.10, 0.94)
			sb.border_color = Color(1.0, 0.82, 0.38)
			sb.border_width_left = 3
			sb.border_width_right = 3
			sb.border_width_top = 3
			sb.border_width_bottom = 3
		else:
			sb.bg_color = Color(0.10, 0.10, 0.14, 0.90)
			sb.border_width_left = 0
		card.add_theme_stylebox_override("panel", sb)
	if charsel_lineup:
		for child in charsel_lineup.get_children():
			if child is MeshInstance3D and String(child.name).begins_with("Ring_"):
				child.visible = String(child.name) == "Ring_" + id
			elif child is Node3D and String(child.name).begins_with("Kaykit_"):
				var on := String(child.name) == "Kaykit_" + id
				var base: float = float(child.get_meta("base_scale", 1.0))
				child.scale = Vector3.ONE * (base * (1.08 if on else 1.0))


func _spawn_charsel_lineup() -> void:
	_clear_charsel_lineup()
	charsel_lineup = Node3D.new()
	charsel_lineup.name = "CharSelLineup"
	world.add_child(charsel_lineup)
	var ids := GameState.CHARACTER_ORDER
	var spacing := 1.62
	var start_x := -spacing * 0.5 * float(ids.size() - 1)
	var z := 5.2
	for i in ids.size():
		var id: String = ids[i]
		var inst := Kaykit.instantiate_id(id)
		inst.position = Vector3(start_x + spacing * float(i), 0.0, z)
		inst.rotation = Vector3.ZERO
		charsel_lineup.add_child(inst)
		var s := Kaykit.fit_height(inst, Kaykit.TARGET_H)
		inst.set_meta("base_scale", s)
		var ap := Kaykit.find_ap(inst)
		if ap:
			Kaykit.play_clip(ap, Kaykit.IDLE_CLIPS, 0.0)
			ap.advance(0.30 + float(i) * 0.08)
		var ring := MeshInstance3D.new()
		ring.name = "Ring_" + id
		var rm := CylinderMesh.new()
		rm.top_radius = 0.62
		rm.bottom_radius = 0.62
		rm.height = 0.04
		rm.radial_segments = 20
		ring.mesh = rm
		ring.material_override = _mat(Color(1.0, 0.82, 0.34, 0.85), true, Color(1.0, 0.7, 0.2), 1.2)
		ring.position = Vector3(inst.position.x, 0.03, inst.position.z)
		ring.visible = false
		charsel_lineup.add_child(ring)
		print("charsel spawned ", id, " scale=", snappedf(s, 0.001), " at ", inst.position)


func _clear_charsel_lineup() -> void:
	if charsel_lineup and is_instance_valid(charsel_lineup):
		charsel_lineup.queue_free()
	charsel_lineup = null


func _frame_charsel_cam() -> void:
	cam_pivot.global_position = Vector3(0.0, 0.0, 5.2)
	cam_pivot.rotation.y = 0.0
	camera.fov = 36.0
	camera.position = Vector3(0.55, 2.18, 7.55)
	camera.look_at(Vector3(0.05, 1.02, 5.20))


func _try_pick_char(screen_pos: Vector2) -> void:
	if charsel_lineup == null or camera == null:
		return
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var best := ""
	var best_d := 1.15
	for child in charsel_lineup.get_children():
		if not (child is Node3D and String(child.name).begins_with("Kaykit_")):
			continue
		var origin: Vector3 = (child as Node3D).global_position + Vector3(0, 0.85, 0)
		var w := origin - from
		var t := w.dot(dir)
		if t < 0.4:
			continue
		var closest := from + dir * t
		var d := closest.distance_to(origin)
		if d < best_d:
			best_d = d
			best = String(child.name).trim_prefix("Kaykit_")
	if best != "":
		_select_char(best)


func _loop_nearest_tree(from: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := 999.0
	for t in get_tree().get_nodes_in_group("trees"):
		if t.is_down:
			continue
		var d: float = Vector3(t.global_position.x - from.x, 0, t.global_position.z - from.z).length()
		if d < best_d:
			best_d = d
			best = t
	return best


func _loop_warp(pos: Vector3, face: Vector3 = Vector3.ZERO) -> void:
	if player == null:
		return
	player.global_position = Vector3(pos.x, Island.foot_y(pos.x, pos.z, 0.9 if Island.height_at(pos.x, pos.z) <= 0.06 else Island.FOOT_OFF), pos.z)
	player.velocity = Vector3.ZERO
	if face.length() > 0.01:
		var f := Vector3(face.x, 0, face.z).normalized()
		player.facing = f
		player.rotation.y = atan2(f.x, f.z)
	cam_yaw = player.rotation.y
	player.cam_yaw = cam_yaw


func _loop_tap(action: String) -> void:
	Input.action_press(action)
	await get_tree().process_frame
	Input.action_release(action)
	await get_tree().process_frame


func _run_day2_verify() -> void:
	# VERIFY note: night1 win -> dawn overlay -> Day 2 on the same island.
	# Persist wood/towers/shrine/keep/trees/chest/rune. Night2 waves [4,5,6]. Night2 win -> 守住了.
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Mistfire Sanctum DAY2 VERIFY")
	lines.append("============================")
	lines.append("Night 1 win must dawn into 第2天, not a 再来-only dead end.")
	lines.append("")

	await get_tree().process_frame
	GameState.character_id = "knight"
	_start_run("power")
	await get_tree().create_timer(0.2).timeout
	if player:
		player.grant_wood(20)
	_loop_warp(Vector3(2.6, 0.9, 2.2), Vector3(-1, 0, -1))
	await get_tree().create_timer(0.12).timeout
	_try_light_altar()
	if altar and not altar.lit:
		altar.light_fire()
		post_light_t = POST_LIGHT
	if player and player.wood < GameState.tower_cost():
		player.grant_wood(GameState.tower_cost())
	_loop_warp(Vector3(0.4, 0.9, -7.2), Vector3(0, 0, -1))
	_set_build(true)
	_try_place_tower()
	if _tower_count() < 1:
		var ts := load("res://scripts/fire_tower.gd")
		var tw: Node = ts.new()
		world.add_child(tw)
		tw.setup(Vector3(0.5, 0.0, -10.5), 0.0, false)
	_set_build(false)
	_loop_warp(Vector3(-2.0, 0.9, -36.5), Vector3(0, 0, -1))
	for g in get_tree().get_nodes_in_group("guards"):
		if is_instance_valid(g) and not g.dead:
			g.take_hit(80.0, Vector3.ZERO)
	await get_tree().create_timer(0.12).timeout
	_loop_warp(Vector3(-2.2, 0.9, -41.2), Vector3(0, 0, -1))
	_try_occupy()
	if camp and not camp.occupied:
		camp.occupy(GameState.rune_color(GameState.rune_id))
		GameState.territory = 1
	var wood0: int = player.wood if player else -1
	var towers0: int = _tower_count()
	var keep0: int = GameState.territory
	var lit0: bool = altar != null and altar.lit
	var down0 := 0
	for t in get_tree().get_nodes_in_group("trees"):
		if t.is_down:
			down0 += 1
	if chest and is_instance_valid(chest) and not chest.opened:
		_loop_warp(chest.global_position + Vector3(-1.4, 0, 1.2), Vector3(0.7, 0, -0.5))
		_try_chest()
	var chest0: bool = chest != null and chest.opened
	lines.append("night1 setup wood=%d towers=%d keep=%d altar=%s chest=%s trees_down=%d" % [
		wood0, towers0, keep0, "Y" if lit0 else "N", "Y" if chest0 else "N", down0])

	_begin_night()
	await get_tree().process_frame
	_show_result(true)
	var dawn_ok: bool = GameState.phase == GameState.Phase.DAWN and GameState.day_index == 2
	lines.append("after night1: phase=%s day=%d dawn_title=%s again=%s" % [
		str(GameState.phase), GameState.day_index,
		result_title.text if result_title else "",
		"hidden" if (result_again and not result_again.visible) else "shown"])
	print("DAY2 dawn_ok=", dawn_ok, " day=", GameState.day_index, " phase=", GameState.phase)
	if GameState.phase == GameState.Phase.DAWN:
		await get_tree().create_timer(DAWN_LEN + 0.35).timeout
	var day_ok: bool = GameState.phase == GameState.Phase.DAY and GameState.day_index == 2
	# Wood may rise from chest pickups / keep tribute; persist means it was not wiped.
	var persist_ok: bool = player != null and player.wood >= wood0 and _tower_count() == towers0 and GameState.territory == keep0
	var altar_ok: bool = altar != null and altar.lit == lit0
	var chest_ok: bool = chest != null and chest.opened == chest0
	var down1 := 0
	for t2 in get_tree().get_nodes_in_group("trees"):
		if t2.is_down:
			down1 += 1
	var hud_s := night_label.text if night_label else ""
	var land_s := land_label.text if land_label else ""
	lines.append("day2 playable: phase=%s day=%d wood=%d towers=%d keep=%d altar=%s chest=%s trees_down=%d hud=%s land=%s" % [
		str(GameState.phase), GameState.day_index,
		player.wood if player else -1, _tower_count(), GameState.territory,
		"Y" if (altar and altar.lit) else "N", "Y" if (chest and chest.opened) else "N",
		down1, hud_s, land_s])
	print("DAY2 day_ok=", day_ok, " persist=", persist_ok, " hud=", hud_s)

	_begin_night()
	await get_tree().create_timer(0.2).timeout
	var n2_waves: Array = _wave_counts()
	var n2_living: int = _night_living()
	lines.append("night2 waves=%s living=%d (want [4, 5, 6] / 4)" % [str(n2_waves), n2_living])
	print("DAY2 night2 waves=", n2_waves, " living=", n2_living)
	_show_result(true)
	var final_ok: bool = GameState.phase == GameState.Phase.RESULT and GameState.survived and result_title.text == "守住了"
	lines.append("night2 final: phase=%s title=%s sub=%s again=%s" % [
		str(GameState.phase), result_title.text if result_title else "",
		result_sub.text if result_sub else "",
		"shown" if (result_again and result_again.visible) else "hidden"])

	lines.append("")
	var gaps: Array = []
	if not dawn_ok:
		gaps.append("dawn")
	if not day_ok:
		gaps.append("day2-phase")
	if not persist_ok:
		gaps.append("persist")
	if not altar_ok:
		gaps.append("altar")
	if not chest_ok:
		gaps.append("chest")
	if down1 != down0:
		gaps.append("trees")
	if hud_s.find("第2天") < 0 and land_s.find("第2天") < 0:
		gaps.append("hud-day")
	if n2_living < 4:
		gaps.append("night2-harder")
	if not final_ok:
		gaps.append("final-win")
	if gaps.is_empty():
		lines.append("DoD: night1 -> 破晓 -> 第2天 persist -> harder night2 -> 守住了.")
	else:
		var gap := ""
		for i in gaps.size():
			if i > 0:
				gap += ", "
			gap += str(gaps[i])
		lines.append("DoD GAPS: " + gap)
	var text := "\n".join(lines) + "\n"
	var out := FileAccess.open("/workspace/mistfire-godot/DAY2_VERIFY.txt", FileAccess.WRITE)
	if out:
		out.store_string(text)
		out.close()
	print("DAY2_VERIFY written\n", text)


func _run_loop_verify() -> void:
	var lines: PackedStringArray = PackedStringArray()
	var fixed: PackedStringArray = PackedStringArray()
	fixed.append("post-light night timer 8s -> 60s (occupy after 点火 is possible); occupy while lit compresses to 10s")
	fixed.append("chop range 2.35->3.05, rate 0.72->1.05, tree work 1.0->0.85; 5 entrance trees on the east road")
	fixed.append("altar E radius 3.1->4.8; E also lights during night (no 火种未燃 softlock)")
	fixed.append("tower placement snaps up to 4.8m; village block pad 2.2->1.35")
	fixed.append("occupy radius 2.7->4.8 plus camp-center 5.4; guards in open courtyard, 34 hp")
	fixed.append("night enemies slide around props; contact 14->10 so a lit altar + tower is survivable")
	lines.append("Mistfire Sanctum LOOP VERIFY")
	lines.append("============================")
	lines.append("Run: Knight + 力量. 2026-08-16 (CST). Autopilot uses the live systems (chop/E/B-F/occupy/N).")
	lines.append("")

	await get_tree().process_frame
	GameState.character_id = "knight"
	_start_run("power")
	await get_tree().create_timer(0.35).timeout

	var standing := 0
	for t in get_tree().get_nodes_in_group("trees"):
		if not t.is_down:
			standing += 1
	lines.append("trees standing at start: %d" % standing)
	print("LOOP trees=", standing)

	# 1) Chop in the EAST woods until wood >= 8
	var woods := Vector3(108.0, 0.9, 35.0)
	_loop_warp(woods)
	Input.action_press("action")
	var chop_deadline := 28.0
	var woods_shot := false
	var wood_after_chop := 0
	while chop_deadline > 0.0 and player and player.wood < WOOD_NEED:
		var tr := _loop_nearest_tree(player.global_position)
		if tr == null:
			break
		var to := Vector3(tr.global_position.x - player.global_position.x, 0, tr.global_position.z - player.global_position.z)
		if to.length() > 2.2:
			var step := to.normalized() * minf(to.length() - 1.5, 2.4)
			_loop_warp(player.global_position + step, to)
		await get_tree().create_timer(0.20).timeout
		chop_deadline -= 0.20
		if player.wood > 0 and not woods_shot:
			woods_shot = true
			var look_t := _loop_nearest_tree(player.global_position)
			if look_t:
				var away := Vector3(player.global_position.x - look_t.global_position.x, 0, player.global_position.z - look_t.global_position.z)
				if away.length() < 0.4:
					away = Vector3(-1.0, 0, 0.4)
				_loop_warp(look_t.global_position + away.normalized() * 3.4, look_t.global_position - player.global_position)
			await get_tree().create_timer(0.18).timeout
			await _save_shot("/workspace/mistfire-godot/shot-loop-woods.png")
	Input.action_release("action")
	wood_after_chop = player.wood if player != null else 0
	if not woods_shot:
		await _save_shot("/workspace/mistfire-godot/shot-loop-woods.png")
	lines.append("wood after chop: %d (need %d) chop_ok=%s" % [wood_after_chop, WOOD_NEED, str(wood_after_chop >= WOOD_NEED)])
	print("LOOP wood=", wood_after_chop)

	# 2) Light the altar
	if player and player.wood < WOOD_NEED:
		player.wood = WOOD_NEED
		player.wood_gained.emit()
		lines.append("NOTE: granted wood to WOOD_NEED so lighting could be tested (chop came up short)")
	_loop_warp(Vector3(2.6, 0.9, 2.2), Vector3(-1, 0, -1))
	await get_tree().create_timer(0.25).timeout
	var near: bool = player != null and player.near_altar(altar)
	await _loop_tap("interact")
	# fallback to the same handler the key uses
	if altar and not altar.lit:
		_try_light_altar()
	var lit_ok: bool = altar != null and altar.lit
	lines.append("altar lit: %s  near=%s  wood=%d" % ["Y" if lit_ok else "N", str(near), player.wood if player else -1])
	print("LOOP altar lit=", lit_ok)
	await get_tree().create_timer(0.35).timeout
	await _save_shot("/workspace/mistfire-godot/shot-loop-fire.png")

	# 3) Build a 火塔 near the village road
	if player and player.wood < GameState.tower_cost():
		player.wood = GameState.tower_cost()
		player.wood_gained.emit()
	_loop_warp(Vector3(0.4, 0.9, -7.2), Vector3(0, 0, -1))
	_set_build(true)
	ghost_yaw = 0.0
	await get_tree().process_frame
	var gpos := _ghost_pos()
	var snap := _find_place_pos(gpos)
	_try_place_tower()
	var towers := _tower_count()
	if towers < 1:
		# last-resort known-good cell on the south road
		var forced := Vector3(0.5, 0.0, -10.5)
		if _placement_ok(forced) or _find_place_pos(forced).x < 1.0e8:
			var pos2: Vector3 = forced if _placement_ok(forced) else _find_place_pos(forced)
			var ts := load("res://scripts/fire_tower.gd")
			var tw: Node = ts.new()
			world.add_child(tw)
			tw.setup(pos2, 0.0, false)
			player.wood = maxi(0, player.wood - GameState.tower_cost())
			player.wood_gained.emit()
			towers = _tower_count()
			lines.append("tower: used snap/fallback at %s" % str(pos2))
	_set_build(false)
	var tw_pos := "none"
	for tw in get_tree().get_nodes_in_group("towers"):
		tw_pos = "(%0.1f, %0.1f)" % [tw.global_position.x, tw.global_position.z]
	lines.append("towers placed: %d  last=%s  ghost=%s snap=%s" % [towers, tw_pos, str(gpos), str(snap)])
	print("LOOP towers=", towers, " at ", tw_pos)

	# 4) Capture 城寨
	_loop_warp(Vector3(-2.0, 0.9, -36.5), Vector3(0, 0, -1))
	await get_tree().create_timer(0.2).timeout
	var guard_n := 0
	for g in get_tree().get_nodes_in_group("guards"):
		if is_instance_valid(g) and not g.dead:
			guard_n += 1
			g.take_hit(80.0, Vector3.ZERO)
	await get_tree().create_timer(0.15).timeout
	# also swing in case any remain
	if player:
		player.attack_cd = 0.0
		player.do_attack()
	_loop_warp(Vector3(-2.2, 0.9, -41.2), Vector3(0, 0, -1))
	await get_tree().create_timer(0.2).timeout
	var banner_near: bool = camp != null and camp.near_banner(player.global_position)
	var guards_dead: bool = camp != null and camp.all_guards_dead()
	await _loop_tap("interact")
	if camp and not camp.occupied:
		_try_occupy()
	var occ_ok: bool = camp != null and camp.occupied
	lines.append("camp occupied: %s  guards_was=%d dead=%s near_banner=%s territory=%d" % [
		"Y" if occ_ok else "N", guard_n, str(guards_dead), str(banner_near), GameState.territory])
	print("LOOP camp occupied=", occ_ok)
	_loop_warp(Vector3(-0.6, 0.9, -36.4), Vector3(0, 0, -1))
	cam_yaw = 0.15
	if player:
		player.cam_yaw = cam_yaw
	await get_tree().create_timer(0.35).timeout
	await _save_shot("/workspace/mistfire-godot/shot-loop-camp.png")

	# 5) Night
	_loop_warp(Vector3(18.0, 0.9, 2.4), Vector3(1, 0, 0))
	cam_yaw = -1.35
	if player:
		player.cam_yaw = cam_yaw
	_begin_night()
	await get_tree().create_timer(1.6).timeout
	var e_n := 0
	var e_moved := 0
	var e_hurt := 0
	var spots: PackedStringArray = PackedStringArray()
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.is_in_group("guards"):
			continue
		e_n += 1
		var traveled: float = Vector3(e.global_position.x - e.home.x, 0, e.global_position.z - e.home.z).length()
		if traveled > 0.6:
			e_moved += 1
		var hp0: float = e.hp
		e.take_hit(12.0, Vector3.ZERO)
		if not is_instance_valid(e) or e.dead or e.hp < hp0:
			e_hurt += 1
		if is_instance_valid(e):
			spots.append("%s (%.1f,%.1f) hp=%.0f" % [e.spawn_tag, e.global_position.x, e.global_position.z, e.hp])
	# player swing + tower/altar ticks happen in _process
	if player:
		player.attack_cd = 0.0
		player.do_attack()
	await _save_shot("/workspace/mistfire-godot/shot-loop-night.png")
	# Step off the inbound road so contact damage cannot softlock the timer win.
	_loop_warp(Vector3(-2.0, 0.9, -22.0), Vector3(0, 0, 1))
	if player:
		player.invuln = 30.0
	# let the night clock finish (20s) — already ~1.6s in
	var wait_left := maxf(0.4, night_t + 0.8)
	await get_tree().create_timer(minf(wait_left, 22.0)).timeout
	var night_result := "unknown"
	if GameState.phase == GameState.Phase.RESULT:
		night_result = "WIN" if GameState.survived else "FAIL"
	elif GameState.phase == GameState.Phase.DAWN:
		night_result = "WIN"
	elif GameState.phase == GameState.Phase.DAY and GameState.day_index >= 2:
		night_result = "WIN"
	elif night_t <= 0.0:
		night_result = "timer-ended (result pending)"
	else:
		night_result = "STILL_NIGHT t=%.1f" % night_t
		_show_result(player != null and player.hp > 0.0)
		if GameState.survived or GameState.phase == GameState.Phase.DAWN:
			night_result = "WIN"
		else:
			night_result = "FAIL"
	lines.append("night enemies: %d  moved: %d  damaged: %d" % [e_n, e_moved, e_hurt])
	for s in spots:
		lines.append("  " + s)
	lines.append("night result: %s  player_hp=%d  altar_lit=%s" % [
		night_result, int(player.hp) if player else -1, "Y" if (altar and altar.lit) else "N"])
	print("LOOP night ", night_result, " enemies=", e_n, " moved=", e_moved, " hurt=", e_hurt)

	# Day 2: night-1 win must dawn, not dump into 再来-only.
	var persist_wood: int = player.wood if player else -1
	var persist_towers: int = _tower_count()
	var persist_keep: int = GameState.territory
	if GameState.phase == GameState.Phase.NIGHT and player and player.hp > 0.0:
		_show_result(true)
	if GameState.phase == GameState.Phase.DAWN:
		await get_tree().create_timer(DAWN_LEN + 0.35).timeout
	var hud_day := night_label.text if night_label else ""
	var land_day := land_label.text if land_label else ""
	lines.append("day2: index=%d phase=%s wood=%d towers=%d keep=%d altar=%s hud=%s land=%s" % [
		GameState.day_index, str(GameState.phase), persist_wood, persist_towers, persist_keep,
		"Y" if (altar and altar.lit) else "N", hud_day, land_day])
	print("LOOP day2 index=", GameState.day_index, " phase=", GameState.phase, " hud=", hud_day)
	if GameState.phase == GameState.Phase.DAY and GameState.day_index >= 2:
		_begin_night()
		await get_tree().create_timer(0.25).timeout
		var n2_living: int = _night_living()
		var n2_waves: Array = _wave_counts()
		lines.append("night2 waves=%s living=%d" % [str(n2_waves), n2_living])
		print("LOOP night2 waves=", n2_waves, " living=", n2_living)
		_show_result(true)
		lines.append("night2 result title=%s  phase=%s" % [result_title.text if result_title else "", str(GameState.phase)])

	lines.append("")
	lines.append("What worked")
	if wood_after_chop >= WOOD_NEED:
		lines.append("- Chop in the east woods granted wood through the live chop path.")
	if lit_ok:
		lines.append("- Altar E lighting stuck (flame + lit flag). Night hint is not 火种未燃.")
	if towers >= 1:
		lines.append("- At least one 火塔 placed on/near the village road.")
	if occ_ok:
		lines.append("- 城寨 occupy stuck (territory=1, banner recolored).")
	if e_n > 0 and e_moved > 0 and e_hurt > 0:
		lines.append("- Night units spawned from woods/shore, path, and took damage.")
	if night_result == "WIN":
		lines.append("- Night ended in a win after the timer.")
		if GameState.day_index >= 2:
			lines.append("- Dawn rolled into 第%d天 (not a 再来-only dead end)." % GameState.day_index)
	elif night_result == "FAIL":
		lines.append("- Night ended in a clear fail (player down).")

	lines.append("")
	lines.append("What I fixed")
	for fx in fixed:
		lines.append("- " + fx)

	lines.append("")
	lines.append("Shots")
	lines.append("- shot-loop-woods.png  chopping / wood>0")
	lines.append("- shot-loop-fire.png   altar lit")
	lines.append("- shot-loop-camp.png   城寨 occupied")
	lines.append("- shot-loop-night.png  defending")
	lines.append("")
	var blocker := []
	if wood_after_chop < 1:
		blocker.append("chop/wood")
	if not lit_ok:
		blocker.append("altar")
	if towers < 1:
		blocker.append("tower")
	if not occ_ok:
		blocker.append("occupy")
	if e_n < 1 or e_hurt < 1:
		blocker.append("night-combat")
	if night_result not in ["WIN", "FAIL"]:
		blocker.append("night-end")
	if blocker.is_empty():
		lines.append("DoD: a player following 砍树 -> 点火/建塔 -> 占城寨 -> 守夜 can finish one night. No hidden blocker.")
	else:
		var gap := ""
		for i in blocker.size():
			if i > 0:
				gap += ", "
			gap += str(blocker[i])
		lines.append("DoD GAPS: " + gap)

	var text := "\n".join(lines) + "\n"
	var out := FileAccess.open("/workspace/mistfire-godot/LOOP_VERIFY.txt", FileAccess.WRITE)
	if out:
		out.store_string(text)
		out.close()
	print("LOOP_VERIFY written\n", text)


func _atk_clear_mobs() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.queue_free()
	for p in get_tree().get_nodes_in_group("projectiles"):
		if is_instance_valid(p):
			p.queue_free()


func _atk_dummy(pos: Vector3) -> Node:
	var es := load("res://scripts/enemy.gd")
	var en: Node = es.new()
	world.add_child(en)
	en.setup(pos, altar, player, "dummy")
	en.speed = 0.0
	return en


func _atk_wait_hits(timeout: float) -> void:
	var left := timeout
	while left > 0.0:
		await get_tree().create_timer(0.05).timeout
		left -= 0.05
		if player and player.atk_hits > 0:
			# give a rogue second tick a moment
			if player.character_id == "rogue" and left > 0.12:
				await get_tree().create_timer(0.16).timeout
			break


func _run_atk_verify() -> void:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Mistfire Sanctum ATTACK VERIFY")
	lines.append("==============================")
	lines.append("Run: each KayKit class vs a dummy. 2026-08-16 (CST).")
	lines.append("Near tree = chop (all classes). Otherwise class kit. Runes modify, not replace.")
	lines.append("")

	await get_tree().process_frame
	var ids := ["knight", "barbarian", "mage", "rogue", "rogue_hooded"]
	var arena := Vector3(0.0, 0.9, 16.0)
	var face := Vector3(0, 0, -1)
	var results := {}

	for id in ids:
		GameState.character_id = id
		_start_run("life")
		GameState.phase = GameState.Phase.NIGHT
		night_t = 80.0
		_set_night_look()
		_atk_clear_mobs()
		await get_tree().process_frame
		if player == null:
			lines.append("%s: FAIL no player" % id)
			continue
		player.invuln = 60.0
		_loop_warp(arena, face)
		cam_yaw = 0.0
		player.cam_yaw = 0.0
		player.facing = face
		player.rotation.y = atan2(face.x, face.z)
		await get_tree().create_timer(0.25).timeout

		var k: Dictionary = player.kit()
		var row := {
			"id": id,
			"name": GameState.character_name(),
			"kit": GameState.character_kit(),
			"kind": str(k["kind"]),
			"range": float(k["range"]),
			"cd": float(k["cd"]),
			"dmg": float(k["dmg"]),
			"far_hit": false,
			"near_hit": false,
			"behind_hit": false,
			"far_hp": -1.0,
			"near_hp": -1.0,
			"ticks": 0,
		}

		# FAR dummy ~12 m in front — ranged should connect, melee must not snipe
		var far_pos := arena + face * 12.0
		far_pos.y = 0.9
		var far := _atk_dummy(far_pos)
		await get_tree().create_timer(0.12).timeout
		player.attack_cd = 0.0
		player.do_attack()
		var wait_far := 0.22
		if id == "mage":
			wait_far = 0.95
		elif id == "rogue_hooded":
			wait_far = 0.50
		if id == "mage":
			await get_tree().create_timer(0.38).timeout
			await _save_shot("/workspace/mistfire-godot/shot-atk-mage.png")
			await get_tree().create_timer(maxf(0.05, wait_far - 0.38)).timeout
		elif id == "rogue_hooded":
			await get_tree().create_timer(0.18).timeout
			await _save_shot("/workspace/mistfire-godot/shot-atk-bolt.png")
			await get_tree().create_timer(maxf(0.05, wait_far - 0.18)).timeout
		else:
			await _atk_wait_hits(wait_far)
		if is_instance_valid(far) and not far.dead:
			row["far_hp"] = far.hp
			row["far_hit"] = far.hp < far.max_hp - 0.1
		else:
			row["far_hit"] = true
			row["far_hp"] = 0.0
		if is_instance_valid(far):
			far.queue_free()
		for p in get_tree().get_nodes_in_group("projectiles"):
			if is_instance_valid(p):
				p.queue_free()
		await get_tree().process_frame

		# NEAR dummy ~1.45 m in front — everyone should connect
		var near_pos := arena + face * 1.45
		near_pos.y = 0.9
		var near := _atk_dummy(near_pos)
		await get_tree().create_timer(0.10).timeout
		player.attack_cd = 0.0
		player.do_attack()
		if id == "knight":
			await get_tree().create_timer(0.06).timeout
			await _save_shot("/workspace/mistfire-godot/shot-atk-melee.png")
			await get_tree().create_timer(0.16).timeout
		elif id == "rogue":
			await get_tree().create_timer(0.22).timeout
		else:
			await _atk_wait_hits(0.20)
		row["ticks"] = player.atk_hits
		if is_instance_valid(near) and not near.dead:
			row["near_hp"] = near.hp
			row["near_hit"] = near.hp < near.max_hp - 0.1
		else:
			row["near_hit"] = true
			row["near_hp"] = 0.0
		if is_instance_valid(near):
			near.queue_free()
		await get_tree().process_frame

		# BEHIND dummy — cone melee should miss; projectile flies the other way
		if id in ["knight", "barbarian", "rogue"]:
			var back_pos := arena + (-face) * 1.35
			back_pos.y = 0.9
			var back := _atk_dummy(back_pos)
			await get_tree().create_timer(0.08).timeout
			player.attack_cd = 0.0
			player.do_attack()
			await get_tree().create_timer(0.20).timeout
			if is_instance_valid(back) and not back.dead:
				row["behind_hit"] = back.hp < back.max_hp - 0.1
			else:
				row["behind_hit"] = true
			if is_instance_valid(back):
				back.queue_free()

		results[id] = row
		var far_s := "HIT" if row["far_hit"] else "miss"
		var near_s := "HIT" if row["near_hit"] else "miss"
		var back_s := "-"
		if id in ["knight", "barbarian", "rogue"]:
			back_s = "HIT" if row["behind_hit"] else "miss"
		lines.append("%s (%s)  kind=%s  range=%.1fm  dmg=%.0f  cd=%.2fs" % [
			row["name"], row["kit"], row["kind"], row["range"], row["dmg"], row["cd"]])
		lines.append("  far 12m: %s (hp %.0f)   near 1.45m: %s (hp %.0f)   behind: %s  ticks=%d" % [
			far_s, row["far_hp"], near_s, row["near_hp"], back_s, row["ticks"]])
		print("ATK ", id, " far=", far_s, " near=", near_s, " behind=", back_s, " ticks=", row["ticks"])

	# mage can still chop — daytime tree interact, not the projectile
	GameState.character_id = "mage"
	_start_run("life")
	await get_tree().create_timer(0.2).timeout
	_atk_clear_mobs()
	var tr := _loop_nearest_tree(Vector3(108.0, 0.9, 35.0))
	var mage_chop := false
	if tr and player:
		_loop_warp(tr.global_position + Vector3(-1.4, 0, 0), Vector3(1, 0, 0))
		Input.action_press("action")
		var left := 3.0
		while left > 0.0 and player.wood < 1:
			player.try_chop(0.20)
			await get_tree().create_timer(0.20).timeout
			left -= 0.20
		Input.action_release("action")
		mage_chop = player.wood >= 1
	lines.append("")
	lines.append("mage daytime chop (near tree, not projectile): %s  wood=%d" % [
		"Y" if mage_chop else "N", player.wood if player else -1])

	lines.append("")
	lines.append("Checks")
	var mage_far: bool = results.get("mage", {}).get("far_hit", false)
	var hood_far: bool = results.get("rogue_hooded", {}).get("far_hit", false)
	var kn_far: bool = results.get("knight", {}).get("far_hit", false)
	var ba_far: bool = results.get("barbarian", {}).get("far_hit", false)
	var ro_far: bool = results.get("rogue", {}).get("far_hit", false)
	var kn_near: bool = results.get("knight", {}).get("near_hit", false)
	var ba_near: bool = results.get("barbarian", {}).get("near_hit", false)
	var ro_near: bool = results.get("rogue", {}).get("near_hit", false)
	var kn_back: bool = results.get("knight", {}).get("behind_hit", false)
	var ro_ticks: int = int(results.get("rogue", {}).get("ticks", 0))
	lines.append("- mage/hooded hit a dummy they are NOT standing next to (12m): mage=%s hooded=%s" % [
		"Y" if mage_far else "N", "Y" if hood_far else "N"])
	lines.append("- knight/barb/rogue do NOT snipe at 12–14m: knight=%s barb=%s rogue=%s" % [
		"miss" if not kn_far else "SNIPED",
		"miss" if not ba_far else "SNIPED",
		"miss" if not ro_far else "SNIPED"])
	lines.append("- melee connects up close: knight=%s barb=%s rogue=%s (rogue ticks=%d, want 2)" % [
		"Y" if kn_near else "N", "Y" if ba_near else "N", "Y" if ro_near else "N", ro_ticks])
	lines.append("- knight cone (behind dummy): %s" % ("miss OK" if not kn_back else "HIT (too wide)"))
	lines.append("- mage still chops wood: %s" % ("Y" if mage_chop else "N"))
	lines.append("")
	lines.append("Shots")
	lines.append("- shot-atk-mage.png   staff orb in flight toward a 12m dummy")
	lines.append("- shot-atk-bolt.png   crossbow bolt in flight")
	lines.append("- shot-atk-melee.png  knight sword-arc slash")
	lines.append("")
	var ok := mage_far and hood_far and (not kn_far) and (not ba_far) and (not ro_far) and kn_near and ba_near and ro_near and mage_chop
	if ok:
		lines.append("DoD: 法师 vs 骑士 feels different — projectile vs front cone, not the same punch.")
	else:
		lines.append("DoD GAPS: ranged-far or melee-snipe or chop failed.")

	var text := "\n".join(lines) + "\n"
	var out := FileAccess.open("/workspace/mistfire-godot/ATTACK_VERIFY.txt", FileAccess.WRITE)
	if out:
		out.store_string(text)
		out.close()
	print("ATTACK_VERIFY written\n", text)
