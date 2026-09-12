extends Node

## Autoload "Snd". One AudioStreamPlayer per sound key. Per-sound volume 0–100
## lives in user://settings.cfg [sound]. Clips are expected at
## res://assets/sounds/<key>.ogg — a missing file just makes that key silent,
## which is fine until the user supplies audio (see global CLAUDE.md #12).
##
## Access from class_name scripts via get_node_or_null("/root/Snd") — the bare
## "Snd" identifier does not resolve under `godot --script` (breaks _selftest).

const CFG_PATH := "user://settings.cfg"
const CALIB_VERSION := 2  # bumped: real SFX (2026-09-11) master much hotter than
                          # the old synthetic placeholders — old saved % would
                          # now be far too loud, so discard and recalibrate.

# clips: res://assets/sounds/<key>.wav (or .ogg). Real ripped SFX as of 2026-09-11.
const EXTS := [".wav", ".ogg"]

# key -> [display name, default %, base_db calibration]
const SOUNDS := {
	"shoot":       ["Schuss", 50, -7.0],
	"hit":         ["Treffer", 70, -9.0],
	"dive":        ["Sturzflug", 60, -10.0],
	"player_boom": ["Schiff zerstört", 85, -3.0],
	"extra":       ["Extra-Leben", 75, -7.0],
	"stage":       ["Stage-Start", 70, -4.0],
	"music":       ["Musik", 45, -17.0],
}
const ORDER := ["music", "shoot", "hit", "dive", "player_boom", "extra", "stage"]

var _players := {}
var _vol := {}
var _music_wanted := false

func _ready() -> void:
	_load()
	for key in SOUNDS:
		var p := AudioStreamPlayer.new()
		p.name = key
		var stream := _find_stream(key)
		if stream:
			p.stream = stream
		add_child(p)
		_players[key] = p
		_apply(key)
	# manual music loop — format-agnostic (WAV import doesn't loop by default)
	var music_p: AudioStreamPlayer = _players["music"]
	music_p.finished.connect(func() -> void:
		if _music_wanted:
			music_p.play())

func _find_stream(key: String) -> AudioStream:
	for ext in EXTS:
		var path := "res://assets/sounds/%s%s" % [key, ext]
		if ResourceLoader.exists(path):
			return load(path)
	return null

func play(key: String) -> void:
	if key == "music":
		_music_wanted = true
	var p = _players.get(key)
	if p and p.stream:
		p.play()

func stop(key: String) -> void:
	if key == "music":
		_music_wanted = false
	var p = _players.get(key)
	if p:
		p.stop()

func has_clip(key: String) -> bool:
	var p = _players.get(key)
	return p != null and p.stream != null

func get_volume(key: String) -> int:
	return int(_vol.get(key, SOUNDS[key][1]))

func set_volume(key: String, pct: int) -> void:
	_vol[key] = clampi(pct, 0, 100)
	_apply(key)
	_save()

func preview(key: String) -> void:
	if key == "music":
		if _players["music"].playing:
			stop("music")
		else:
			play("music")
	else:
		play(key)

func _apply(key: String) -> void:
	var p = _players.get(key)
	if not p:
		return
	var pct := get_volume(key)
	if pct <= 0:
		p.volume_db = -80.0
	else:
		p.volume_db = float(SOUNDS[key][2]) + linear_to_db(pct / 100.0)

func _load() -> void:
	var c := ConfigFile.new()
	if c.load(CFG_PATH) != OK:
		return
	if c.get_value("sound", "calib_version", 0) != CALIB_VERSION:
		return
	for key in SOUNDS:
		_vol[key] = c.get_value("sound", key, SOUNDS[key][1])

func _save() -> void:
	var c := ConfigFile.new()
	c.load(CFG_PATH)
	c.set_value("sound", "calib_version", CALIB_VERSION)
	for key in _vol:
		c.set_value("sound", key, _vol[key])
	c.save(CFG_PATH)
