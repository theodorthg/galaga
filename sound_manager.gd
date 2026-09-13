extends Node

## Autoload "Snd". One AudioStreamPlayer per sound key. Per-sound volume 0–100
## lives in user://settings.cfg [sound]. Clips are expected at
## res://assets/sounds/<key>.ogg — a missing file just makes that key silent,
## which is fine until the user supplies audio (see global CLAUDE.md #12).
##
## Access from class_name scripts via get_node_or_null("/root/Snd") — the bare
## "Snd" identifier does not resolve under `godot --script` (breaks _selftest).

const CFG_PATH := "user://settings.cfg"
const CALIB_VERSION := 4  # bumped 2026-09-13 (second time same day): "music"
                          # (gameplay background loop) retired entirely — NES
                          # Galaga has no in-game music, user's call — and
                          # "pause-menu-music" replaced by "menu-music" (a
                          # single track the user liked better, reused from
                          # what was going to be the highscore screen's own
                          # music); dive/extra/stage got real clips for the
                          # first time. Old saved % values for any of that
                          # would be meaningless.

# clips: res://assets/sounds/<key>.wav (or .ogg). All-.ogg as of 2026-09-13.
const EXTS := [".wav", ".ogg"]

# key -> [display name, default %, base_db calibration]. base_db is 0.0 for
# every key with a clip as of 2026-09-13 — the user asked to defer real
# calibration to a later round once they've actually heard these in-game, so
# these are neutral placeholders, not measured levels.
const SOUNDS := {
	"menu-music":              ["Menü-Musik", 45, 0.0],
	"scoring-board-music":     ["Auswertungs-Musik", 45, 0.0],
	"start-first-level-music": ["Intro-Musik (Level 1)", 45, 0.0],
	"shoot":                   ["Schuss", 50, 0.0],
	"enemy-death1":            ["Gegner-Abschuss", 70, 0.0],
	"enemy-death2":            ["Gegner-Abschuss (Sturzflug)", 70, 0.0],
	"dive":                    ["Sturzflug", 60, 0.0],
	"enemy-wave1":             ["Wellen-Ankündigung", 70, 0.0],
	"beam-sound":              ["Traktorstrahl-Fang", 70, 0.0],
	"boss-killed":             ["Boss abgeschossen", 70, 0.0],
	"ship-destroyed":          ["Schiff zerstört", 85, 0.0],
	"extra":                   ["Extra-Leben", 75, 0.0],
	"bonus-stage-cleared":     ["Achievement-Reihe voll", 70, 0.0],
	"level-cleared":           ["Stage geschafft", 70, 0.0],
	"stage":                   ["Nächstes Level", 70, 0.0],
}
const ORDER := [
	"menu-music", "scoring-board-music", "start-first-level-music",
	"shoot", "enemy-death1", "enemy-death2", "dive", "enemy-wave1",
	"beam-sound", "boss-killed", "ship-destroyed", "extra",
	"bonus-stage-cleared", "level-cleared", "stage",
]

## Tracks played via play(key) auto-loop by re-triggering themselves on
## "finished" for as long as they're still "wanted" (stop(key) clears that) —
## manual, since a plain OGG/WAV import doesn't loop on its own.
const LOOPING_KEYS := ["menu-music", "scoring-board-music"]
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
		# Every LOOPING_KEYS track is meant to keep looping for as long as a
		# menu screen is shown — but EVERY menu screen (Pause, Settings,
		# Summary, Game Over, ...) runs with get_tree().paused = true, and a
		# node's default process_mode (PAUSABLE, inherited) means its own
		# "finished" signal simply stops firing once the tree is paused — the
		# audio itself keeps playing through to the end once, then just goes
		# silent instead of looping (user report: "pause music doesn't loop
		# while the menu is open"). ALWAYS keeps this one node's bookkeeping
		# running regardless of pause state, without affecting anything else.
		p.process_mode = Node.PROCESS_MODE_ALWAYS
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
