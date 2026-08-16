extends Node

enum Phase { TITLE, CHARSEL, RUNE, DAY, NIGHT, RESULT }

var phase: Phase = Phase.TITLE
var rune_id := "power"
var character_id := "knight"
var survived := false
var territory := 0

# Bounding half-extent only (minimap scale / legacy). Walk/build use Island PIP.
const ISLAND_R := 76.0
const ISLAND_VISUAL_R := 76.0
const TOWER_MAX_R := 74.0

const RUNES := {
	"power": {"name": "力量", "en": "Might", "passive": "重击劈砍", "color": Color(0.86, 0.24, 0.18)},
	"puppet": {"name": "机械傀儡", "en": "Puppet", "passive": "傀儡伐木", "color": Color(0.86, 0.58, 0.18)},
	"precise": {"name": "精密", "en": "Precision", "passive": "巧筑迅伐", "color": Color(0.16, 0.68, 0.64)},
	"life": {"name": "生命", "en": "Life", "passive": "生机回春", "color": Color(0.30, 0.72, 0.32)},
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
	return 8
