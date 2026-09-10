extends SceneTree

## Headless smoke test. Run:
##   godot --headless --path . --script res://_selftest.gd
##
## Parse-checks the scripts (a parse error makes load() / class refs fail) and
## checks the formation geometry + entry choreography that the fly-in relies on.

const SCRIPTS := [
	"res://ship.gd",
	"res://laser.gd",
	"res://enemy.gd",
	"res://enemy_kinds.gd",
	"res://formation.gd",
	"res://entry_paths.gd",
	"res://stage_director.gd",
	"res://game.gd",
	"res://item.gd",
	"res://random_item_placer.gd",
]

func _init() -> void:
	var fails := 0

	for path in SCRIPTS:
		fails += _expect(load(path) != null, "parses: %s" % path)

	# --- project config -----------------------------------------------------
	var canvas := Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	fails += _expect(canvas.y > canvas.x, "design canvas is portrait (%dx%d)" % [canvas.x, canvas.y])
	fails += _expect(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items",
		"stretch mode = canvas_items")
	for action in ["move_left", "move_right", "shoot", "pause"]:
		fails += _expect(InputMap.has_action(action), "input action present: %s" % action)

	# --- formation --------------------------------------------------------
	var f := Formation.new()
	f._build_slots()
	fails += _expect(f.slot_count() == 40, "formation has 40 slots, got %d" % f.slot_count())
	fails += _expect(f.slot_kind(0) == EnemyKinds.BOSS, "top row is bosses")
	fails += _expect(f.slot_kind(39) == EnemyKinds.ZAKO, "bottom row is zako")
	var inside := true
	for i in f.slot_count():
		var s := f.slot_local(i)
		if absf(s.x) > canvas.x * 0.5 or s.y < 0.0 or s.y > canvas.y * 0.5:
			inside = false
	fails += _expect(inside, "every slot sits inside the upper half of the canvas")
	f.free()

	# --- entry paths -----------------------------------------------------
	for pat in [EntryPaths.BOTTOM_UP, EntryPaths.TOP_LEFT, EntryPaths.TOP_RIGHT]:
		var c := EntryPaths.make(pat, canvas)
		fails += _expect(c.get_baked_length() > 400.0,
			"entry path %d bakes a real curve (len %.0f)" % [pat, c.get_baked_length()])

	print("SELFTEST: %s (%d failure(s))" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)


func _expect(cond: bool, msg: String) -> int:
	if cond:
		print("  ok   ", msg)
		return 0
	print("  FAIL ", msg)
	return 1
