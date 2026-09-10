extends SceneTree

## Headless smoke test. Run:
##   godot --headless --path . --script res://_selftest.gd
##
## For now this only parse-checks the gameplay scripts (a parse error in any
## of them makes load() return null) and sanity-checks the project config.
## Grows real rule tests as the Galaga mechanics land (formation, dives,
## scoring, waves).

const SCRIPTS := [
	"res://ship.gd",
	"res://enemy.gd",
	"res://laser.gd",
	"res://item.gd",
	"res://random_item_placer.gd",
]

func _init() -> void:
	var fails := 0

	for path in SCRIPTS:
		fails += _expect(load(path) != null, "parses: %s" % path)

	var canvas := Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	fails += _expect(canvas.y > canvas.x, "design canvas is portrait (%dx%d)" % [canvas.x, canvas.y])
	fails += _expect(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items",
		"stretch mode = canvas_items")

	for action in ["move_left", "move_right", "shoot", "pause"]:
		fails += _expect(InputMap.has_action(action), "input action present: %s" % action)

	print("SELFTEST: %s (%d failure(s))" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)


func _expect(cond: bool, msg: String) -> int:
	if cond:
		print("  ok   ", msg)
		return 0
	print("  FAIL ", msg)
	return 1
