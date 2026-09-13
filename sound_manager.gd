extends Node

## Autoload "Snd". One AudioStreamPlayer per sound key. Per-sound volume 0–100
## lives in user://settings.cfg [sound]. Clips are expected at
## res://assets/sounds/<key>.ogg — a missing file just makes that key silent,
## which is fine until the user supplies audio (see global CLAUDE.md #12).
##
## Access from class_name scripts via get_node_or_null("/root/Snd") — the bare
## "Snd" identifier does not resolve under `godot --script` (breaks _selftest).

const CFG_PATH := "user://settings.cfg"
const CALIB_VERSION := 3  # bumped 2026-09-13: whole assets/sounds/ folder swapped
                          # for a larger, better-matched clip set (old one kept
                          # as assets/sounds_old/) — several keys renamed or
                          # retired (see SOUNDS below), so old saved % values
                          # would be meaningless even where a key survived.

# clips: res://assets/sounds/<key>.wav (or .ogg). All-.ogg as of 2026-09-13.
const EXTS := [".wav", ".ogg"]

# key -> [display name, default %, base_db calibration]. base_db is 0.0 for
# every key that got a brand-new clip in the 2026-09-13 batch — the user
# asked to defer calibration to a later round once they've actually heard
# these in-game, so these are neutral placeholders, not measured levels
# (contrast "dive"/"extra"/"stage" below, which kept their old 2026-09-11
# calibration numbers because they did NOT get a new clip this round and are
# simply silent until one shows up).
const SOUNDS := {
	"music":                   ["Musik", 45, -17.0],
	"pause-menu-music":        ["Pause-/Einstellungsmusik", 45, 0.0],
	"scoring-board-music":     ["Auswertungs-Musik", 45, 0.0],
	"start-first-level-music": ["Intro-Musik (Level 1)", 45, 0.0],
	"shoot":                   ["Schuss", 50, 0.0],
	"enemy-death1":            ["Gegner-Abschuss", 70, 0.0],
	"enemy-death2":            ["Gegner-Abschuss (Sturzflug)", 70, 0.0],
	"dive":                    ["Sturzflug", 60, -10.0],
	"enemy-wave1":             ["Wellen-Ankündigung", 70, 0.0],
	"beam-sound":              ["Traktorstrahl-Fang", 70, 0.0],
	"boss-killed":             ["Boss (mit Schiff) abgeschossen", 70, 0.0],
	"ship-destroyed":          ["Schiff zerstört", 85, 0.0],
	"extra":                   ["Extra-Leben", 75, -7.0],
	"bonus-stage-cleared":     ["Achievement-Reihe voll", 70, 0.0],
	"level-cleared":           ["Stage geschafft", 70, 0.0],
	"stage":                   ["Stage-Start", 70, -4.0],
}
const ORDER := [
	"music", "pause-menu-music", "scoring-board-music", "start-first-level-music",
	"shoot", "enemy-death1", "enemy-death2", "dive", "enemy-wave1",
	"beam-sound", "boss-killed", "ship-destroyed", "extra",
	"bonus-stage-cleared", "level-cleared", "stage",
]

## Tracks played via play(key) auto-loop by re-triggering themselves on
## "finished" for as long as they're still "wanted" (stop(key) clears that) —
## manual, since a plain OGG/WAV import doesn't loop on its own. Generalized
## 2026-09-13 from a single hardcoded "music" special case to any number of
## looping tracks (pause/settings and the run-summary screen each got their
## own loop) — see menus.gd's _apply_screen_music().
const LOOPING_KEYS := ["music", "pause-menu-music", "scoring-board-music"]
var _wanted := {}  # key (from LOOPING_KEYS) -> bool, "should keep looping"

var _players := {}
var _vol := {}

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
	for key in LOOPING_KEYS:
		_wanted[key] = false
		var p: AudioStreamPlayer = _players[key]
		p.finished.connect(func() -> void:
			if _wanted.get(key, false):
				p.play())

func _find_stream(key: String) -> AudioStream:
	for ext in EXTS:
		var path := "res://assets/sounds/%s%s" % [key, ext]
		if ResourceLoader.exists(path):
			return load(path)
	return null

func play(key: String) -> void:
	if key in LOOPING_KEYS:
		_wanted[key] = true
	var p = _players.get(key)
	if p and p.stream:
		p.play()

func stop(key: String) -> void:
	if key in LOOPING_KEYS:
		_wanted[key] = false
	var p = _players.get(key)
	if p:
		p.stop()

func has_clip(key: String) -> bool:
	var p = _players.get(key)
	return p != null and p.stream != null

## Used by game.gd to gate the stage-1 fly-in on start-first-level-music
## actually finishing (or being skipped) — see _start_ready().
func is_playing(key: String) -> bool:
	var p = _players.get(key)
	return p != null and p.playing

func get_volume(key: String) -> int:
	return int(_vol.get(key, SOUNDS[key][1]))

func set_volume(key: String, pct: int) -> void:
	_vol[key] = clampi(pct, 0, 100)
	_apply(key)
	_save()

func preview(key: String) -> void:
	if key in LOOPING_KEYS:
		if is_playing(key):
			stop(key)
		else:
			play(key)
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
