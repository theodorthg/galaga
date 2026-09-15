extends Node

## Autoload "Snd". One AudioStreamPlayer per sound key. Per-sound volume 0–100
## lives in user://settings.cfg [sound]. Clips are expected at
## res://assets/sounds/<key>.ogg — a missing file just makes that key silent,
## which is fine until the user supplies audio (see global CLAUDE.md #12).
##
## Access from class_name scripts via get_node_or_null("/root/Snd") — the bare
## "Snd" identifier does not resolve under `godot --script` (breaks _selftest).

const CFG_PATH := "user://settings.cfg"
const CALIB_VERSION := 5  # bumped 2026-09-15: real per-sound calibration
                          # (base_db) replaces the neutral 0.0 placeholders —
                          # see SOUNDS' own comment below. Old saved %
                          # values were tuned against the old (flat) curve
                          # and would land at the wrong loudness under the
                          # new one.

# clips: res://assets/sounds/<key>.wav (or .ogg). All-.ogg as of 2026-09-13.
const EXTS := [".wav", ".ogg"]

# key -> [display name, default %, base_db calibration]. Default % is 50 for
# every key (2026-09-15) — a deliberate, uniform "middle" so raising/lowering
# a slider always means "louder/quieter than the reference", never "louder/
# quieter than some other key's arbitrary starting point". base_db per key is
# derived from the user's own in-game listening (not a measured clip level):
# they reported, per sound, the % they found comfortable under the OLD
# calibration (base_db=0.0 for all). volume_db = base_db + linear_to_db(pct/100)
# (see _apply() below), so reproducing "sounds like pct_old% did at base_db=0"
# at the new default of 50% requires base_db = 20*log10(pct_old/50) — solved
# from base_db + linear_to_db(0.5) = linear_to_db(pct_old/100).
const SOUNDS := {
	"menu-music":              ["Menu music", 50, -1.94],   # was comfortable at 40%
	"scoring-board-music":     ["Results music", 50, -6.02],  # was comfortable at 25%
	"start-first-level-music": ["Intro music (level 1)", 50, -4.44],  # was comfortable at 30%
	"shoot":                   ["Shot", 50, -10.46],  # was comfortable at 15%
	"enemy-death1":            ["Enemy kill", 50, -10.46],  # was comfortable at 15%
	"enemy-death2":            ["Enemy kill (diving)", 50, -10.46],  # was comfortable at 15%
	"dive":                    ["Dive", 50, -13.98],  # was comfortable at 10%
	"enemy-wave1":             ["Wave announcement", 50, -13.98],  # was comfortable at 10%
	"beam-sound":              ["Tractor beam capture", 50, -10.46],  # was comfortable at 15%
	"boss-killed":             ["Boss killed", 50, -6.02],  # was comfortable at 25%
	"ship-destroyed":          ["Ship destroyed", 50, -4.44],  # was comfortable at 30%
	"extra":                   ["Extra life", 50, -4.44],  # was comfortable at 30%
	"bonus-stage-cleared":     ["Achievement row full", 50, -7.96],  # was comfortable at 20%
	"level-cleared":           ["Stage cleared", 50, -7.96],  # was comfortable at 20%
	"stage":                   ["Next stage", 50, -7.96],  # was comfortable at 20%
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

## Global mute (HUD button top-right, "mute" input action — M / D-pad Select)
## — muting the Master bus rather than each AudioStreamPlayer individually
## means every per-sound volume in _vol stays exactly as the user set it;
## unmuting just un-silences the whole mix again, no bookkeeping needed here.
var _muted := false
var _players := {}
var _vol := {}
## Currently-auditioned key in the Sound settings screen (menus.gd's
## _sound_row()), or "" — see preview_exclusive()/stop_preview() below.
var _previewing := ""

func _ready() -> void:
	_load()
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), _muted)
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

func is_muted() -> bool:
	return _muted

## Returns the new state, for callers (hud.gd via game.gd) that need to sync
## a button icon right away without a separate is_muted() round trip.
func toggle_mute() -> bool:
	set_muted(not _muted)
	return _muted

func set_muted(m: bool) -> void:
	_muted = m
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), m)
	_save()

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

## Used ONLY by the Sound settings screen's sliders (menus.gd::_sound_row()) —
## deliberately separate from play()/stop()/LOOPING_KEYS's looping bookkeeping:
## auditioning a sound has nothing to do with whether it's normally a looping
## background track (menu-music, scoring-board-music) — that distinction must
## not matter while auditioning (user request 2026-09-15: previously, toggling
## a LOOPING_KEYS preview on/off while it was ALSO the screen's own ambient
## music produced confusing starts/stops, and unrelated one-shot previews
## could overlap each other with nothing to cut them off). Only ever one
## preview plays at a time — starting a new one always cuts off whatever
## was previewing before, looping or not, and it never auto-repeats (bypasses
## _wanted entirely, unlike play()).
func preview_exclusive(key: String) -> void:
	stop_preview()
	var p = _players.get(key)
	if p and p.stream:
		p.play()
		_previewing = key

## Called whenever the Sound screen closes (menus.gd::hide_all()) so a still-
## playing preview never bleeds into whatever comes next (resumed menu music,
## or actual gameplay).
func stop_preview() -> void:
	if _previewing == "":
		return
	var p = _players.get(_previewing)
	if p:
		p.stop()
	_previewing = ""

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
	# muted isn't gated on CALIB_VERSION — it's an independent on/off switch,
	# not a per-sound loudness value the calibration rework could invalidate.
	_muted = c.get_value("sound", "muted", false)
	if c.get_value("sound", "calib_version", 0) != CALIB_VERSION:
		return
	for key in SOUNDS:
		_vol[key] = c.get_value("sound", key, SOUNDS[key][1])

func _save() -> void:
	var c := ConfigFile.new()
	c.load(CFG_PATH)
	c.set_value("sound", "calib_version", CALIB_VERSION)
	c.set_value("sound", "muted", _muted)
	for key in _vol:
		c.set_value("sound", key, _vol[key])
	c.save(CFG_PATH)
