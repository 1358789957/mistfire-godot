extends RefCounted
class_name Kaykit
## Shared KayKit Adventurer load / dress / measure / anim helpers.

const CHAR_DIR := "res://assets/kaykit_adventurers/Characters/gltf/"
const SKEL_DIR := "res://assets/kaykit_skeletons/Characters/gltf/"
const TARGET_H := 1.75

const SKEL_FILES := {
	"warrior": "Skeleton_Warrior.glb",
	"rogue": "Skeleton_Rogue.glb",
	"mage": "Skeleton_Mage.glb",
	"minion": "Skeleton_Minion.glb",
}
const SKEL_WALK := ["Walking_D_Skeletons", "Walking_A", "Walking_B", "Walking_C"]
const WEAP_DIR := "res://assets/kaykit_skeletons/Assets/gltf/"
const SKEL_KITS := {
	"warrior": {
		"r": "Skeleton_Blade.gltf", "l": "Skeleton_Shield_Small_A.gltf",
		"atk": ["1H_Melee_Attack_Chop", "1H_Melee_Attack_Slice_Diagonal"],
		"kind": "melee", "range": 1.85, "angle": 110.0, "dmg": 12.0, "knock": 3.4, "cd": 1.05,
	},
	"rogue": {
		"r": "Skeleton_Crossbow.gltf",
		"atk": ["1H_Ranged_Shoot", "1H_Ranged_Shooting"],
		"kind": "proj", "proj": "bolt", "range": 11.0, "dmg": 9.0, "knock": 1.6, "cd": 1.35,
	},
	"mage": {
		"r": "Skeleton_Staff.gltf",
		"atk": ["Spellcast_Shoot", "Spellcast_Long"],
		"kind": "proj", "proj": "orb", "range": 13.0, "dmg": 11.0, "knock": 1.8, "cd": 1.55,
	},
	"minion": {
		"r": "Skeleton_Axe.gltf",
		"atk": ["1H_Melee_Attack_Slice_Horizontal", "1H_Melee_Attack_Chop"],
		"kind": "melee", "range": 1.55, "angle": 100.0, "dmg": 8.0, "knock": 2.4, "cd": 0.78,
	},
}

const HELD := [
	"1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield", "Round_Shield", "Spike_Shield",
	"1H_Sword", "2H_Sword",
	"1H_Axe_Offhand", "Barbarian_Round_Shield", "1H_Axe", "2H_Axe", "Mug",
	"Spellbook", "Spellbook_open", "1H_Wand", "2H_Staff",
	"Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Knife", "Throwable",
]

const IDLE_CLIPS := ["Idle", "Unarmed_Idle", "2H_Melee_Idle"]
const WALK_CLIPS := ["Walking_A", "Walking_B", "Walking_C"]
const RUN_CLIPS := ["Running_A", "Running_B"]


static func spec(id: String) -> Dictionary:
	if GameState.CHARACTERS.has(id):
		return GameState.CHARACTERS[id]
	return GameState.CHARACTERS["knight"]


static func instantiate_id(id: String) -> Node3D:
	var s := spec(id)
	var path: String = CHAR_DIR + String(s["file"])
	if not ResourceLoader.exists(path):
		push_error("Kaykit missing " + path)
		return Node3D.new()
	var packed := load(path) as PackedScene
	var inst := packed.instantiate() as Node3D
	inst.name = "Kaykit_" + id
	hide_extra_held(inst, s["keep"])
	Mats.polish_imported(inst)
	return inst


static func instantiate_skel(kind: String) -> Node3D:
	var k := kind if SKEL_FILES.has(kind) else "warrior"
	var path: String = SKEL_DIR + String(SKEL_FILES[k])
	if not ResourceLoader.exists(path):
		push_error("Kaykit skeleton missing " + path)
		return Node3D.new()
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Kaykit skeleton load fail " + path)
		return Node3D.new()
	var inst := packed.instantiate() as Node3D
	inst.name = "KaykitSkel_" + k
	Mats.polish_imported(inst)
	attach_skel_gear(inst, k)
	return inst


static func hide_extra_held(root: Node, keep: Array) -> void:
	var keep_set := {}
	for k in keep:
		keep_set[String(k)] = true
	for n in root.find_children("*", "", true, false):
		if String(n.name) in HELD and not keep_set.has(String(n.name)):
			n.visible = false


static func skel_kit(kind: String) -> Dictionary:
	if SKEL_KITS.has(kind):
		return SKEL_KITS[kind].duplicate()
	return SKEL_KITS["warrior"].duplicate()


static func _find_named(root: Node, name: String) -> Node3D:
	var n := root.find_child(name, true, false)
	if n:
		return n as Node3D
	var alt := name.replace(".", "_")
	n = root.find_child(alt, true, false)
	if n:
		return n as Node3D
	return null


static func _find_slot(root: Node, side: String) -> Node3D:
	var hits := [
		"handslot." + side, "handslot_" + side, "handslot-" + side,
		"hand." + side, "hand_" + side,
	]
	for h in hits:
		var n := _find_named(root, h)
		if n:
			return n
	for n in root.find_children("*", "", true, false):
		if not (n is Node3D):
			continue
		var nm := String(n.name).to_lower()
		if "handslot" in nm and (nm.ends_with(side) or ("_" + side) in nm or ("." + side) in nm):
			return n as Node3D
	return null


static func _instance_weap(file: String) -> Node3D:
	var path := WEAP_DIR + file
	if not ResourceLoader.exists(path):
		push_error("Kaykit weapon missing " + path)
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var inst := packed.instantiate() as Node3D
	Mats.polish_imported(inst)
	return inst


static func _skeletons(root: Node) -> Array:
	var out: Array = []
	if root is Skeleton3D:
		out.append(root)
	for n in root.find_children("*", "Skeleton3D", true, false):
		out.append(n)
	return out


static func _bone_attach(root: Node3D, hints: Array, file: String, tag: String) -> bool:
	var w := _instance_weap(file)
	if w == null:
		print("weap miss file ", file)
		return false
	for skel in _skeletons(root):
		var s := skel as Skeleton3D
		for h in hints:
			var idx := s.find_bone(String(h))
			if idx < 0:
				continue
			var att := BoneAttachment3D.new()
			att.name = "Weap_" + tag
			att.bone_idx = idx
			att.bone_name = s.get_bone_name(idx)
			s.add_child(att)
			att.add_child(w)
			w.position = Vector3.ZERO
			w.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
			w.visible = true
			print("weap bone ", tag, " -> ", s.name, ".", s.get_bone_name(idx), " idx=", idx)
			return true
	# last resort: park on the model at a hand-ish local offset so it still reads
	w.name = "Weap_" + tag
	root.add_child(w)
	w.position = Vector3(0.28 if tag.ends_with("r") else -0.28, 0.95, 0.18)
	w.rotation_degrees = Vector3(0, 0, -25 if tag.ends_with("r") else 25)
	print("weap fallback ", tag, " on ", root.name)
	return true


static func attach_skel_gear(root: Node3D, kind: String) -> void:
	var kit := skel_kit(kind)
	var skels := _skeletons(root)
	if not skels.is_empty():
		var s: Skeleton3D = skels[0]
		var names: PackedStringArray = PackedStringArray()
		for i in s.get_bone_count():
			names.append(s.get_bone_name(i))
		print("weap bones kind=", kind, " skel=", s.name, " n=", s.get_bone_count(), " sample=", ", ".join(names.slice(0, 12)))
	if kit.has("r"):
		_bone_attach(root, ["handslot.r", "handslot_r", "hand.r", "hand_r"], str(kit["r"]), kind + ".r")
	if kit.has("l"):
		_bone_attach(root, ["handslot.l", "handslot_l", "hand.l", "hand_l"], str(kit["l"]), kind + ".l")


static func find_ap(root: Node) -> AnimationPlayer:
	return root.find_child("AnimationPlayer", true, false) as AnimationPlayer


static func first_clip(ap: AnimationPlayer, names: Array) -> String:
	if ap == null:
		return ""
	for n in names:
		if ap.has_animation(String(n)):
			return String(n)
	return ""


static func play_clip(ap: AnimationPlayer, names: Array, blend := 0.12) -> String:
	var clip := first_clip(ap, names)
	if clip == "":
		return ""
	ap.active = true
	ap.play(clip, blend)
	return clip


static func attack_clips_for(id: String) -> Array:
	return spec(id).get("attack", ["1H_Melee_Attack_Chop"])


static func local_body_aabb(root: Node3D) -> AABB:
	var acc := AABB()
	var started := false
	var inv := root.global_transform.affine_inverse()
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.visible and not (String(mi.name) in HELD):
				var local: AABB = mi.get_aabb()
				for i in 8:
					var w: Vector3 = inv * (mi.global_transform * local.get_endpoint(i))
					if not started:
						acc = AABB(w, Vector3.ZERO)
						started = true
					else:
						acc = acc.expand(w)
		for c in n.get_children():
			stack.append(c)
	return acc


static func fit_height(inst: Node3D, target_h: float = TARGET_H) -> float:
	## Scale so the dressed body (weapons excluded) is ~target_h metres.
	## Must be inside the tree. Feet stay at local y=0 (KayKit authored that way).
	inst.scale = Vector3.ONE
	var aabb := local_body_aabb(inst)
	var h := aabb.size.y
	if h < 0.08:
		h = 1.05
	var s := clampf(target_h / h, 0.45, 3.2)
	inst.scale = Vector3(s, s, s)
	print("kaykit fit ", inst.name, " aabb_h=", snappedf(h, 0.001), " scale=", snappedf(s, 0.001), " -> ", snappedf(h * s, 0.001), "m")
	return s
