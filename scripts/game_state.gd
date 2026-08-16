extends Node

enum Phase { TITLE, CHARSEL, RUNE, DAY, NIGHT, DAWN, RESULT }

const MAX_DAYS := 2

var phase: Phase = Phase.TITLE
var rune_id := "power"
var character_id := "knight"
var survived := false
var territory := 0
var day_index := 1
var wild_bone_today: bool = false

# Bounding half-extent only (minimap scale / legacy). Walk/build use Island PIP.
const ISLAND_R := 76.0
const ISLAND_VISUAL_R := 76.0
const TOWER_MAX_R := 74.0

const RUNES := {
	"power": {"name": "力量", "en": "Might", "passive": "重击/掠杀", "color": Color(0.86, 0.24, 0.18)},
	"puppet": {"name": "机械傀儡", "en": "Puppet", "passive": "傀儡伐木/守夜", "color": Color(0.86, 0.58, 0.18)},
	"precise": {"name": "精密", "en": "Precision", "passive": "测算/速筑", "color": Color(0.16, 0.68, 0.64)},
	"life": {"name": "生命", "en": "Life", "passive": "厚血/核心还在", "color": Color(0.30, 0.72, 0.32)},
}

const CHARACTER_ORDER := ["knight", "barbarian", "mage", "rogue", "rogue_hooded"]

const CHARACTERS := {
	"knight": {
		"name": "骑士", "en": "Knight", "file": "Knight.glb",
		"kit": "剑弧近战",
		"keep": ["1H_Sword", "Rectangle_Shield"],
		"attack": ["1H_Melee_Attack_Chop", "1H_Melee_Attack_Slice_Horizontal"],
	},
	"barbarian": {
		"name": "野蛮人", "en": "Barbarian", "file": "Barbarian.glb",
		"kit": "阔斧重击",
		"keep": ["1H_Axe", "Barbarian_Round_Shield"],
		"attack": ["1H_Melee_Attack_Chop", "1H_Melee_Attack_Slice_Diagonal"],
	},
	"mage": {
		"name": "法师", "en": "Mage", "file": "Mage.glb",
		"kit": "法杖飞弹",
		"keep": ["2H_Staff"],
		"attack": ["Spellcast_Shoot", "Spellcast_Long", "2H_Melee_Attack_Chop"],
	},
	"rogue": {
		"name": "盗贼", "en": "Rogue", "file": "Rogue.glb",
		"kit": "双刺连击",
		"keep": ["Knife"],
		"attack": ["Dualwield_Melee_Attack_Chop", "1H_Melee_Attack_Stab", "1H_Melee_Attack_Chop"],
	},
	"rogue_hooded": {
		"name": "蒙面盗贼", "en": "Rogue Hooded", "file": "Rogue_Hooded.glb",
		"kit": "弩矢点射",
		"keep": ["1H_Crossbow"],
		"attack": ["1H_Ranged_Shoot", "1H_Ranged_Shooting", "1H_Melee_Attack_Chop"],
	},
}


func is_live() -> bool:
	return phase == Phase.DAY or phase == Phase.NIGHT


func is_final_night() -> bool:
	return day_index >= MAX_DAYS


func rune_name() -> String:
	return str(RUNES[rune_id]["name"])


func rune_passive() -> String:
	return str(RUNES[rune_id]["passive"])


static func rune_color(id: String) -> Color:
	if RUNES.has(id):
		return RUNES[id]["color"]
	return Color.WHITE


func character_name() -> String:
	if CHARACTERS.has(character_id):
		return str(CHARACTERS[character_id]["name"])
	return str(CHARACTERS["knight"]["name"])


func character_kit() -> String:
	if CHARACTERS.has(character_id):
		return str(CHARACTERS[character_id].get("kit", ""))
	return str(CHARACTERS["knight"].get("kit", ""))


func tower_cost() -> int:
	return 4 if rune_id == "precise" else 6


func shrine_cost() -> int:
	return 6 if rune_id == "precise" else 8


func shrine_hp() -> int:
	return 5 if rune_id == "precise" else 4


func tower_embers() -> int:
	return 2 if rune_id == "precise" else 1


func tower_interval() -> float:
	return 0.26 if rune_id == "precise" else 0.34
