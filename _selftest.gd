extends SceneTree

## Headless smoke test. Run:
##   godot --headless --path . --script res://_selftest.gd
##
## Checks that every script compiles (see _all_scripts()) and
## checks the formation geometry + entry choreography that the fly-in relies on.

## Every game script, found automatically — a hand-kept list silently goes
## stale. Walks res:// recursively, skipping addons/, tools/, android/ (Godot's
## build template), hidden and .gdignore'd folders and _-prefixed dev scripts
## (_selftest.gd itself, local helpers like _capture.gd).
## A script only counts if it also COMPILES: in Godot 4 load() returns the
## resource even when compilation failed (incl. a broken dependency), so check
## can_instantiate() (found in mario-clone v1.1, where `load() != null` let a
## type-inference error through with "all checks passed" and exit 0).
const SKIP_DIRS := ["addons", "tools", "android"]

func _all_scripts(dir := "res://") -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") and not f.begins_with("_"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		var sub := dir.path_join(d)
		if d.begins_with(".") or d in SKIP_DIRS or FileAccess.file_exists(sub.path_join(".gdignore")):
			continue
		out.append_array(_all_scripts(sub))
	return out

func _init() -> void:
	var fails := 0

	var scripts := _all_scripts()
	fails += _expect(scripts.size() >= 20, "found %d scripts (expect >= 20)" % scripts.size())
	for path in scripts:
		var s: Script = load(path)
		fails += _expect(s != null and s.can_instantiate(), "compiles: %s" % path)

	# --- project config -----------------------------------------------------
	var canvas := Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	fails += _expect(canvas.y > canvas.x, "design canvas is portrait (%dx%d)" % [canvas.x, canvas.y])
	fails += _expect(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items",
		"stretch mode = canvas_items")
	for action in ["move_left", "move_right", "shoot", "pause", "mute"]:
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
		# Lower bound is BOSS_ROW_Y_NUDGE, not 0 — the Boss row is deliberately
		# nudged a few px above row 0's nominal y (see formation.gd) to keep a
		# captured-ship passenger sprite clear of the row underneath it.
		if absf(s.x) > canvas.x * 0.5 or s.y < Formation.BOSS_ROW_Y_NUDGE or s.y > canvas.y * 0.5:
			inside = false
	fails += _expect(inside, "every slot sits inside the upper half of the canvas")
	f.free()

	# --- entry paths -----------------------------------------------------
	for pat in [EntryPaths.BOTTOM_UP, EntryPaths.TOP_LEFT, EntryPaths.TOP_RIGHT]:
		var c := EntryPaths.make(pat, canvas)
		fails += _expect(c.get_baked_length() > 400.0,
			"entry path %d bakes a real curve (len %.0f)" % [pat, c.get_baked_length()])

	# --- attack paths ---------------------------------------------------
	var slot := Vector2(canvas.x * 0.3, canvas.y * 0.2)
	var ppos := Vector2(canvas.x * 0.5, canvas.y * 0.8)
	var dv := AttackPaths.dive(slot, ppos, canvas)
	fails += _expect(dv.get_baked_length() > 600.0, "dive curve bakes (len %.0f)" % dv.get_baked_length())
	fails += _expect(dv.sample_baked(dv.get_baked_length()).y > canvas.y,
		"dive curve exits below the screen")
	var rt := AttackPaths.return_to(slot, canvas)
	fails += _expect(rt.sample_baked(0.0).y < 0.0, "return curve starts above the screen")
	fails += _expect(rt.sample_baked(rt.get_baked_length()).distance_to(slot) < 4.0,
		"return curve ends on the slot")

	# --- settings + hall of fame -------------------------------------
	var cfg := GameSettings.load_all()
	fails += _expect(cfg.has("lives") and cfg.has("difficulty"), "settings defaults present")
	fails += _expect(int(GameSettings.dive_params(2)["max_divers"]) >= int(GameSettings.dive_params(0)["max_divers"]),
		"hard difficulty allows >= easy divers")
	fails += _expect(not HallOfFame.qualifies(0), "score 0 never qualifies for the board")
	fails += _expect(HallOfFame.MAX == 10, "hall of fame keeps 10")

	# --- sound_manager: keys/order consistent -----------------------
	var sm: GDScript = load("res://sound_manager.gd")
	var consts := sm.get_script_constant_map()
	fails += _expect(consts.has("SOUNDS") and consts.has("ORDER"), "sound_manager exposes SOUNDS + ORDER")
	if consts.has("SOUNDS") and consts.has("ORDER"):
		var missing := false
		for k in consts["ORDER"]:
			if not consts["SOUNDS"].has(k):
				missing = true
		fails += _expect(not missing, "every ORDER key exists in SOUNDS")

	print("SELFTEST: %s (%d failure(s))" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)


func _expect(cond: bool, msg: String) -> int:
	if cond:
		print("  ok   ", msg)
		return 0
	print("  FAIL ", msg)
	return 1
