extends RefCounted
class_name Mats

static var _grass_tex: Texture2D
static var _sand_tex: Texture2D
static var _water_tex: Texture2D
static var _dirt_tex: Texture2D
static var _jungle_floor_tex: Texture2D
static var _jungle_moss_tex: Texture2D
static var _jungle_litter_tex: Texture2D
static var _jungle_dirt_tex: Texture2D


static func solid(color: Color, unshaded: bool = false, emission: Color = Color(0, 0, 0, 0), emission_energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.86
	m.metallic = 0.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if emission.a > 0.0 or emission_energy > 0.0:
		m.emission_enabled = true
		m.emission = Color(emission.r, emission.g, emission.b)
		m.emission_energy_multiplier = maxf(emission_energy, 1.0)
	return m


static func nature_leaf(color: Color = Color(0.36, 0.60, 0.28)) -> StandardMaterial3D:
	var m := solid(color)
	m.roughness = 0.90
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static var _grass_card_a: Texture2D
static var _grass_card_b: Texture2D
static var _grass_card_c: Texture2D


static func grass_card_tex(which: String = "a") -> Texture2D:
	if which == "b":
		if _grass_card_b:
			return _grass_card_b
		_grass_card_b = _load_png("res://assets/kenney_foliage/grass_tuft_b.png")
		return _grass_card_b
	if which == "c":
		if _grass_card_c:
			return _grass_card_c
		_grass_card_c = _load_png("res://assets/kenney_foliage/grass_tuft_c.png")
		return _grass_card_c
	if _grass_card_a:
		return _grass_card_a
	_grass_card_a = _load_png("res://assets/kenney_foliage/grass_tuft_a.png")
	return _grass_card_a


static func grass_card(which: String = "a", color: Color = Color(1.04, 1.06, 0.92)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	var tex := grass_card_tex(which)
	if tex == null:
		tex = _make_grass_card_fallback(which)
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.40
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.metallic = 0.0
	m.roughness = 0.90
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	m.vertex_color_use_as_albedo = false
	return m


static func textured(tex: Texture2D, color: Color = Color.WHITE, uv_scale: Vector3 = Vector3.ONE, unshaded := false) -> StandardMaterial3D:
	var m := solid(color, unshaded)
	m.albedo_texture = tex
	m.uv1_scale = uv_scale
	m.vertex_color_use_as_albedo = false
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m


static func ground(tex: Texture2D, color: Color = Color.WHITE) -> StandardMaterial3D:
	# Continuous terrain. Nearest keeps 512 texels readable; cull_disabled covers winding.
	var m := StandardMaterial3D.new()
	if color == Color.WHITE:
		# Shade on llvmpipe eats ~half the albedo; lift so grass reads as a meadow.
		color = Color(1.22, 1.18, 1.08)
	m.albedo_color = color
	m.albedo_texture = tex
	m.roughness = 0.92
	m.metallic = 0.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Nearest: 512 texels stay readable at the player's feet; high-freq albedo hides the 2 m repeat.
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.vertex_color_use_as_albedo = false
	m.uv1_scale = Vector3.ONE
	return m


static func water(color: Color = Color(0.70, 0.92, 0.88)) -> StandardMaterial3D:
	# Soft sea. Linear filter so 512 ripples do not read as a texel grid.
	# Opaque — gl_compatibility + llvmpipe sorts alpha badly.
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = water_tex()
	m.roughness = 0.36
	m.metallic = 0.04
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	m.vertex_color_use_as_albedo = false
	m.uv1_scale = Vector3.ONE
	return m


static func mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scale
	parent.add_child(mi)
	return mi


static func polish_imported(root: Node) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.material_override is StandardMaterial3D:
				_polish_mat(mi.material_override)
			var msh := mi.mesh
			if msh:
				for i in msh.get_surface_count():
					var mat := mi.get_active_material(i)
					if mat is StandardMaterial3D:
						_polish_mat(mat)
					var sm := msh.surface_get_material(i)
					if sm is StandardMaterial3D:
						_polish_mat(sm)
		for c in n.get_children():
			stack.append(c)


static var _bark_mat: StandardMaterial3D
static var _leaf_mat: StandardMaterial3D
static var _pine_leaf_mat: StandardMaterial3D
static var _birch_bark_mat: StandardMaterial3D
static var _birch_leaf_mat: StandardMaterial3D
static var _wood_inner_mat: StandardMaterial3D


static func _load_mat(path: String) -> StandardMaterial3D:
	if ResourceLoader.exists(path):
		var r: Resource = load(path)
		if r is StandardMaterial3D:
			return r
	return null


static func tree_bark() -> StandardMaterial3D:
	if _bark_mat:
		return _bark_mat
	_bark_mat = _load_mat("res://assets/quaternius_trees/mat_bark.tres")
	if _bark_mat == null:
		_bark_mat = textured(_load_png("res://assets/quaternius_trees/Textures/Tree_Bark.jpg"), Color.WHITE)
		_bark_mat.roughness = 0.9
	return _bark_mat


static func tree_leaves() -> StandardMaterial3D:
	if _leaf_mat:
		return _leaf_mat
	_leaf_mat = _load_mat("res://assets/quaternius_trees/mat_leaves.tres")
	if _leaf_mat == null:
		_leaf_mat = textured(_load_png("res://assets/quaternius_trees/Textures/Tree_Leaves.png"), Color.WHITE)
		_leaf_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		_leaf_mat.alpha_scissor_threshold = 0.42
		_leaf_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_leaf_mat.roughness = 0.92
	return _leaf_mat


static func pine_leaves() -> StandardMaterial3D:
	if _pine_leaf_mat:
		return _pine_leaf_mat
	_pine_leaf_mat = _load_mat("res://assets/quaternius_trees/mat_pine_leaves.tres")
	if _pine_leaf_mat == null:
		_pine_leaf_mat = tree_leaves()
	return _pine_leaf_mat


static func birch_bark() -> StandardMaterial3D:
	if _birch_bark_mat:
		return _birch_bark_mat
	_birch_bark_mat = _load_mat("res://assets/quaternius_trees/mat_birch_bark.tres")
	if _birch_bark_mat == null:
		_birch_bark_mat = tree_bark()
	return _birch_bark_mat


static func birch_leaves() -> StandardMaterial3D:
	if _birch_leaf_mat:
		return _birch_leaf_mat
	_birch_leaf_mat = _load_mat("res://assets/quaternius_trees/mat_birch_leaves.tres")
	if _birch_leaf_mat == null:
		_birch_leaf_mat = tree_leaves()
	return _birch_leaf_mat


static func wood_inner() -> StandardMaterial3D:
	if _wood_inner_mat:
		return _wood_inner_mat
	_wood_inner_mat = _load_mat("res://assets/quaternius_trees/mat_wood_inner.tres")
	if _wood_inner_mat == null:
		_wood_inner_mat = tree_bark()
	return _wood_inner_mat


static func _mat_key(m: Material) -> String:
	if m == null:
		return ""
	var n := m.resource_name.to_lower()
	if n.is_empty() and m.resource_path:
		n = m.resource_path.get_file().to_lower()
	return n


static func pick_tree_mat(name: String) -> StandardMaterial3D:
	var n := name.to_lower()
	if n.is_empty():
		return null
	if "pine" in n and ("leaf" in n or "leaves" in n):
		return pine_leaves()
	if "birch" in n and ("leaf" in n or "leaves" in n):
		return birch_leaves()
	if "leaf" in n or "leaves" in n or n == "grass":
		return tree_leaves()
	if "birch" in n and "bark" in n:
		return birch_bark()
	if "inner" in n:
		return wood_inner()
	if "bark" in n or "wood" in n:
		return tree_bark()
	return null


static func _fallback_tree_mat(surf: int, hint: String) -> StandardMaterial3D:
	var n := hint.to_lower()
	if surf == 0:
		if "birch" in n:
			return birch_bark()
		return tree_bark()
	if "pine" in n:
		return pine_leaves()
	if "birch" in n:
		return birch_leaves()
	return tree_leaves()


static func dress_tree(root: Node) -> void:
	var hint := str(root.name).to_lower()
	var bound := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var nname := str(n.name).to_lower()
		if "oak" in nname or "pine" in nname or "birch" in nname:
			hint = nname
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var msh := mi.mesh
			if msh:
				var mhint := hint
				if msh.resource_name:
					mhint += " " + msh.resource_name.to_lower()
				mhint += " " + nname
				for i in msh.get_surface_count():
					var mat := mi.get_active_material(i)
					var key := _mat_key(mat)
					if key.is_empty() and msh.surface_get_material(i):
						key = _mat_key(msh.surface_get_material(i))
					var shared := pick_tree_mat(key)
					if shared == null:
						shared = pick_tree_mat(mhint + " " + key)
					if shared == null and msh.get_surface_count() >= 2:
						shared = _fallback_tree_mat(i, mhint + " " + key)
					if shared:
						mi.set_surface_override_material(i, shared)
						bound += 1
					elif mat is StandardMaterial3D:
						_polish_mat(mat)
		for c in n.get_children():
			stack.append(c)
	print("dress_tree bound=", bound, " hint=", hint, " root=", root)


static func _polish_mat(m: StandardMaterial3D) -> void:
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.metallic = 0.0
	if m.roughness < 0.55:
		m.roughness = 0.82
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	# Keep real albedo textures (Quaternius bark/leaves). Only recolor vertex-color Nature Kit.
	if m.albedo_texture != null:
		return
	var c := m.albedo_color
	# Nature Kit 2 ships mint/teal foliage (r~0.45 g~0.93 b~0.87) + orange bark, metallic=1.
	if c.g > 0.50 and c.b > 0.40 and c.r < c.g * 0.75:
		if c.g > 0.78:
			m.albedo_color = Color(0.36, 0.60, 0.28)  # grass tuft
		elif c.b > 0.62:
			m.albedo_color = Color(0.16, 0.42, 0.22)  # dark pine
		else:
			m.albedo_color = Color(0.22, 0.50, 0.24)  # oak leaf
	elif c.r > 0.68 and c.g > 0.38 and c.b < 0.48 and c.r > c.g:
		m.albedo_color = Color(0.46, 0.30, 0.16)


static func _load_png(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			return res
	# Stale .import / missing .ctex — read the PNG bytes directly.
	if FileAccess.file_exists(path):
		var img := Image.new()
		if img.load(path) == OK:
			return ImageTexture.create_from_image(img)
	return null


static func grass_tex() -> Texture2D:
	if _grass_tex:
		return _grass_tex
	_grass_tex = _load_png("res://assets/ground/grass.png")
	if _grass_tex == null:
		_grass_tex = _make_tile(32, [
			Color(0.18, 0.40, 0.14),
			Color(0.28, 0.52, 0.18),
			Color(0.12, 0.32, 0.10),
			Color(0.36, 0.58, 0.22),
			Color(0.22, 0.46, 0.16),
			Color(0.46, 0.66, 0.28),
		], 0)
	return _grass_tex


static func sand_tex() -> Texture2D:
	if _sand_tex:
		return _sand_tex
	_sand_tex = _load_png("res://assets/ground/sand.png")
	if _sand_tex:
		return _sand_tex
	_sand_tex = _make_tile(32, [
		Color(0.76, 0.68, 0.48),
		Color(0.82, 0.74, 0.52),
		Color(0.70, 0.60, 0.42),
		Color(0.86, 0.78, 0.56),
		Color(0.74, 0.64, 0.44),
		Color(0.68, 0.58, 0.40),
	], 1)
	return _sand_tex


static func dirt_tex() -> Texture2D:
	if _dirt_tex:
		return _dirt_tex
	_dirt_tex = _load_png("res://assets/ground/dirt.png")
	if _dirt_tex:
		return _dirt_tex
	_dirt_tex = _make_tile(32, [
		Color(0.48, 0.38, 0.24),
		Color(0.42, 0.34, 0.22),
		Color(0.54, 0.44, 0.28),
		Color(0.38, 0.30, 0.20),
		Color(0.50, 0.40, 0.26),
		Color(0.46, 0.36, 0.22),
	], 2)
	return _dirt_tex


static func jungle_floor_tex() -> Texture2D:
	if _jungle_floor_tex:
		return _jungle_floor_tex
	_jungle_floor_tex = _load_png("res://assets/ground/jungle_floor.png")
	if _jungle_floor_tex == null:
		_jungle_floor_tex = _make_tile(32, [
			Color(0.18, 0.14, 0.08),
			Color(0.22, 0.28, 0.12),
			Color(0.28, 0.18, 0.10),
			Color(0.14, 0.22, 0.10),
			Color(0.24, 0.16, 0.09),
			Color(0.16, 0.20, 0.08),
		], 11)
	return _jungle_floor_tex


static func jungle_moss_tex() -> Texture2D:
	if _jungle_moss_tex:
		return _jungle_moss_tex
	_jungle_moss_tex = _load_png("res://assets/ground/jungle_moss.png")
	if _jungle_moss_tex == null:
		_jungle_moss_tex = _make_tile(32, [
			Color(0.10, 0.28, 0.10),
			Color(0.16, 0.38, 0.14),
			Color(0.22, 0.46, 0.16),
			Color(0.08, 0.22, 0.08),
			Color(0.14, 0.34, 0.12),
			Color(0.20, 0.42, 0.15),
		], 12)
	return _jungle_moss_tex


static func jungle_litter_tex() -> Texture2D:
	if _jungle_litter_tex:
		return _jungle_litter_tex
	_jungle_litter_tex = _load_png("res://assets/ground/jungle_litter.png")
	if _jungle_litter_tex == null:
		_jungle_litter_tex = _make_tile(32, [
			Color(0.32, 0.20, 0.10),
			Color(0.40, 0.26, 0.12),
			Color(0.24, 0.16, 0.08),
			Color(0.36, 0.22, 0.11),
			Color(0.28, 0.18, 0.09),
			Color(0.44, 0.30, 0.14),
		], 13)
	return _jungle_litter_tex


static func jungle_dirt_tex() -> Texture2D:
	if _jungle_dirt_tex:
		return _jungle_dirt_tex
	_jungle_dirt_tex = _load_png("res://assets/ground/jungle_dirt.png")
	if _jungle_dirt_tex == null:
		_jungle_dirt_tex = _make_tile(32, [
			Color(0.22, 0.14, 0.08),
			Color(0.28, 0.18, 0.10),
			Color(0.18, 0.12, 0.07),
			Color(0.32, 0.22, 0.12),
			Color(0.24, 0.16, 0.09),
			Color(0.20, 0.13, 0.07),
		], 14)
	return _jungle_dirt_tex


static func water_tex() -> Texture2D:
	if _water_tex:
		return _water_tex
	_water_tex = _load_png("res://assets/ground/water.png")
	if _water_tex:
		return _water_tex
	_water_tex = _make_tile(32, [
		Color(0.10, 0.28, 0.38),
		Color(0.12, 0.34, 0.44),
		Color(0.08, 0.24, 0.34),
		Color(0.14, 0.38, 0.48),
		Color(0.09, 0.26, 0.36),
		Color(0.16, 0.40, 0.50),
	], 3)
	return _water_tex


static func _make_grass_card_fallback(which: String) -> Texture2D:
	# Thin tapered blades, transparent edges — never a solid rectangle.
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 68 if which == "a" else (69 if which == "b" else 66)
	var n := 16 if which == "b" else (8 if which == "c" else 12)
	for i in n:
		var cx := 28.0 + rng.randf() * 200.0
		var base_w := rng.randf_range(2.2, 4.6)
		var h := rng.randf_range(90.0, 240.0)
		var lean := rng.randf_range(-0.22, 0.22)
		var tip := Color(0.48, 0.74, 0.26, 1.0)
		var basec := Color(0.18, 0.40, 0.14, 1.0)
		for y in int(h):
			var t := float(y) / h
			var yy := 255 - y
			var w := base_w * (1.0 - t * 0.92)
			var xmid := cx + lean * float(y)
			var col := basec.lerp(tip, t)
			var x0 := int(xmid - w)
			var x1 := int(xmid + w)
			for x in range(maxi(0, x0), mini(256, x1 + 1)):
				if yy >= 0 and yy < 256:
					img.set_pixel(x, yy, col)
	return ImageTexture.create_from_image(img)


static func _make_tile(size: int, palette: Array, seed_n: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			# irregular value-noise clumps, not a regular cell grid
			var n1: int = ((x * 13 + y * 37 + seed_n * 19) ^ ((x / 3) * 91 + (y / 5) * 53)) & 0x7fffffff
			var n2: int = ((x * 7 + y * 11 + seed_n * 5) ^ ((x / 7) * 17 + (y / 4) * 29)) & 0x7fffffff
			var idx: int = (n1 + n2) % palette.size()
			var c: Color = palette[idx]
			var s: int = (x * 19 + y * 47 + seed_n * 9 + n1) & 7
			if s == 0:
				c = c.lightened(0.07)
			elif s == 1:
				c = c.darkened(0.09)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func _h(x: float, z: float, amp: float) -> float:
	return amp * sin(x * 0.31) * cos(z * 0.27) + amp * 0.45 * sin(x * 0.73 + z * 0.51)


static func ground_disc(radius: float, segs: int, rings: int, noise_amp: float, uv_world: float, c0: Color, c1: Color) -> ArrayMesh:
	var pts: Array[Vector3] = []
	var cols: Array[Color] = []
	var uvs: Array[Vector2] = []
	pts.append(Vector3(0.0, _h(0.0, 0.0, noise_amp), 0.0))
	cols.append(c0)
	uvs.append(Vector2.ZERO)
	for ring in range(1, rings + 1):
		var rr := radius * float(ring) / float(rings)
		for s in segs:
			var a := float(s) * TAU / float(segs)
			var x := cos(a) * rr
			var z := sin(a) * rr
			pts.append(Vector3(x, _h(x, z, noise_amp), z))
			var t := 0.5 + 0.5 * sin(x * 0.17) * cos(z * 0.15)
			cols.append(c0.lerp(c1, clampf(t, 0.0, 1.0)))
			uvs.append(Vector2(x / uv_world, z / uv_world))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in segs:
		_emit_tri(st, pts, cols, uvs, 0, 1 + s, 1 + ((s + 1) % segs))
	for ring in range(1, rings):
		var base := 1 + (ring - 1) * segs
		var nxt := 1 + ring * segs
		for s in segs:
			var s2 := (s + 1) % segs
			_emit_tri(st, pts, cols, uvs, base + s, nxt + s, nxt + s2)
			_emit_tri(st, pts, cols, uvs, base + s, nxt + s2, base + s2)
	st.generate_normals()
	return st.commit()


static func _emit_tri(st: SurfaceTool, pts: Array[Vector3], cols: Array[Color], uvs: Array[Vector2], a: int, b: int, c: int) -> void:
	for i in [a, b, c]:
		st.set_normal(Vector3.UP)
		st.set_color(cols[i])
		st.set_uv(uvs[i])
		st.add_vertex(pts[i])


static func ring_mesh(inner: float, outer: float, segs: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in segs:
		var a0 := float(s) * TAU / float(segs)
		var a1 := float(s + 1) * TAU / float(segs)
		var i0 := Vector3(cos(a0) * inner, 0.0, sin(a0) * inner)
		var i1 := Vector3(cos(a1) * inner, 0.0, sin(a1) * inner)
		var o0 := Vector3(cos(a0) * outer, 0.0, sin(a0) * outer)
		var o1 := Vector3(cos(a1) * outer, 0.0, sin(a1) * outer)
		for v in [i0, o0, o1, i0, o1, i1]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(v.x * 0.25, v.z * 0.25))
			st.add_vertex(v)
	return st.commit()
