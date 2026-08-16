extends Node
## Tiny one-shot mixer. Dummy audio driver is fine — we still play() and print.

const PATHS := {
	"chop": "res://assets/kenney_rpg_audio/chop.ogg",
	"hit": "res://assets/kenney_rpg_audio/knifeSlice.ogg",
	"chest": "res://assets/kenney_rpg_audio/doorOpen_1.ogg",
	"pickup": "res://assets/kenney_rpg_audio/handleCoins.ogg",
	"ember": "res://assets/kenney_rpg_audio/metalClick.ogg",
	"smash": "res://assets/kenney_impact/impactWood_medium_000.ogg",
	"confirm": "res://assets/kenney_ui/confirmation_001.ogg",
	"error": "res://assets/kenney_ui/error_001.ogg",
	"night": "res://assets/kenney_jingles/jingles_HIT03.ogg",
	"win": "res://assets/kenney_jingles/jingles_PIZZI01.ogg",
	"lose": "res://assets/kenney_jingles/jingles_HIT00.ogg",
}

const FALLBACKS := {
	"chop": ["res://assets/kenney_rpg_audio/knifeSlice.ogg"],
	"hit": ["res://assets/kenney_impact/impactGeneric_light_000.ogg", "res://assets/kenney_rpg_audio/knifeSlice2.ogg"],
	"chest": ["res://assets/kenney_rpg_audio/creak1.ogg", "res://assets/kenney_rpg_audio/doorOpen_2.ogg"],
	"pickup": ["res://assets/kenney_rpg_audio/handleCoins2.ogg", "res://assets/kenney_ui/drop_001.ogg"],
	"ember": ["res://assets/kenney_impact/impactGeneric_light_000.ogg", "res://assets/kenney_rpg_audio/metalLatch.ogg"],
	"smash": ["res://assets/kenney_impact/impactWood_medium_001.ogg", "res://assets/kenney_impact/impactGeneric_light_000.ogg"],
	"confirm": ["res://assets/kenney_ui/confirmation_002.ogg", "res://assets/kenney_ui/click_001.ogg"],
	"error": ["res://assets/kenney_ui/error_002.ogg", "res://assets/kenney_ui/click_002.ogg"],
	"night": ["res://assets/kenney_jingles/jingles_HIT04.ogg", "res://assets/kenney_jingles/jingles_HIT02.ogg"],
	"win": ["res://assets/kenney_jingles/jingles_HIT10.ogg", "res://assets/kenney_jingles/jingles_PIZZI00.ogg"],
	"lose": ["res://assets/kenney_jingles/jingles_HIT07.ogg", "res://assets/kenney_jingles/jingles_HIT01.ogg"],
}

var _voices: Array = []
var _cache: Dictionary = {}
var _i := 0


func _ready() -> void:
	for _n in 6:
		var p := AudioStreamPlayer.new()
		p.volume_db = -10.0
		p.bus = "Master"
		add_child(p)
		_voices.append(p)


func play(kind: String) -> void:
	var key := kind.to_lower()
	var stream := _stream_for(key)
	if stream == null:
		print("sfx ", key, " missing")
		return
	var p: AudioStreamPlayer = _voices[_i % _voices.size()]
	_i += 1
	p.stream = stream
	p.volume_db = -10.0
	p.play()
	print("sfx ", key)


func _stream_for(key: String) -> AudioStream:
	if _cache.has(key):
		return _cache[key]
	var paths: Array = []
	if PATHS.has(key):
		paths.append(PATHS[key])
	if FALLBACKS.has(key):
		for f in FALLBACKS[key]:
			paths.append(f)
	for path in paths:
		if ResourceLoader.exists(String(path)):
			var r: Resource = load(String(path))
			if r is AudioStream:
				_cache[key] = r
				return r
	_cache[key] = null
	return null
