class_name CoopInput

## Local co-op controls: who flies with what. The join screen (menus.gd) lets
## each player press fire on THEIR device; that decides p2_pad:
##   - p2_pad >= 0: player 2 flies with that gamepad (device id), player 1 gets
##     every OTHER pad — matters on devices that report the D-pad and the face
##     buttons as separate device ids (Anbernic RG552, see global CLAUDE.md #17);
##   - p2_pad == -1: player 2 is on the keyboard half below.
## The keyboard is always split: player 1 A/D + Space/W, player 2 arrows +
## Up/K/Num0 — so two people can share one keyboard, or either one can use a pad
## while the other types.
## build() writes p1_*/p2_* actions; ship.gd points `act` at them in co-op. The
## plain move_left/move_right/shoot actions stay untouched (menus, solo play).

const P1_KEYS := {"left": [KEY_A], "right": [KEY_D], "shoot": [KEY_SPACE, KEY_W]}
const P2_KEYS := {"left": [KEY_LEFT], "right": [KEY_RIGHT], "shoot": [KEY_UP, KEY_K, KEY_KP_0]}
## What makes a player join on the join screen (no Enter: it would press the
## focused "Back" button).
const JOIN_P1_KEYS := [KEY_SPACE, KEY_W, KEY_Z]
const JOIN_P2_KEYS := [KEY_UP, KEY_K, KEY_KP_0]
const BASE := {"left": "move_left", "right": "move_right", "shoot": "shoot"}

static var p2_pad := -1

static func action_names(player: int) -> Dictionary:
	var d := {}
	for k in BASE:
		d[k] = "p%d_%s" % [player + 1, k]
	return d

static func _add_key(action: String, code: int) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	InputMap.action_add_event(action, e)

## (Re)builds p1_* / p2_* from the keyboard split and the connected pads.
static func build() -> void:
	for player in 2:
		var names := action_names(player)
		var keys: Dictionary = P2_KEYS if player == 1 else P1_KEYS
		for k in BASE:
			var n: String = names[k]
			if InputMap.has_action(n):
				InputMap.erase_action(n)
			InputMap.add_action(n, InputMap.action_get_deadzone(BASE[k]) if InputMap.has_action(BASE[k]) else 0.5)
			for code in keys[k]:
				_add_key(n, code)
	for k in BASE:
		if not InputMap.has_action(BASE[k]):
			continue
		for e in InputMap.action_get_events(BASE[k]):
			if not (e is InputEventJoypadButton or e is InputEventJoypadMotion):
				continue
			for dev in Input.get_connected_joypads():
				var c: InputEvent = e.duplicate()
				c.device = dev
				InputMap.action_add_event(action_names(1 if dev == p2_pad else 0)[k], c)

## Short "who plays with what" line for the join screen.
static func describe() -> String:
	var p1 := "keyboard (A D, Space / W) or gamepad"
	var p2 := ("gamepad %d" % p2_pad) if p2_pad >= 0 else "keyboard (arrows, Up / K)"
	return "Player 1: %s\nPlayer 2: %s" % [p1, p2]
