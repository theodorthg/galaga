class_name Menus
extends CanvasLayer

## All menu screens, built in code (like tetris' ui.gd): title, pause, settings,
## sound sub-page, how-to-play, game-over + hall of fame. Game drives which one
## is visible and listens to the signals below.

signal start_game       # title Play, game-over Play again
signal resume_game      # pause Resume
signal to_title         # pause Quit-to-title, game-over Title
signal settings_changed # a gameplay setting was saved
signal splash_done      # minimum time elapsed (or the player skipped it)

## See space_background.gd::set_cabinet_lane() for the full story.
const DESIGN_WIDTH := 540.0
const DESIGN_HEIGHT := 960.0

const ACCENT := Color("4db2ff")
var IS_WEB := OS.has_feature("web")  # not const: OS.has_feature isn't a constant expr

## Godot's native boot_splash is just a static image for minimum_display_time
## seconds — on Linux/Android that gap is so short (this project is tiny) it
## barely registers, and it never had a progress bar to begin with. This is a
## real in-game screen instead, held open for a fixed SPLASH_TIME regardless
## of how fast everything actually loaded, with a fake progress bar so it
## reads as "loading" rather than "frozen".
const SPLASH_TIME := 3.0

var _root: Control
var _glass: ColorRect
var _screens := {}
var _return_to := "title"     # where "Fertig" in settings/sound/help goes back to
var _cfg := {}
var _splash_active := false
var _splash_tween: Tween

# How-to-play pages — image-based (like tetris' ui.gd), not plain text: each
# page is one full illustration rendered from assets/help_src/<file>.svg (see
# that folder's render.sh) to assets/graphics/help/<file>.png, in Galaga's own
# colour scheme (UiStyle.ACCENT cyan on dark navy) rather than tetris' own
# palette. Two sets, matched to how the player is actually driving the ship
# right now (see set_touch_context()) — desktop gets separate keyboard/mouse
# pages, touch gets one combined swipe/tap page instead; both sets share the
# goal/boss-capture/bonus-item pages, since those don't depend on input method.
const HELP_DIR := "res://assets/graphics/help/"
# Fully spelled out (not built via array concatenation) — GDScript const
# initializers need to be compile-time constant expressions, and it's not
# worth relying on Array "+" folding there for two short lists.
const HELP_PAGES_DESKTOP := [
	{"file": "keyboard", "h": "Controls — Keyboard/Gamepad"},
	{"file": "mouse", "h": "Controls — Mouse"},
	{"file": "goal", "h": "Goal & Points"},
	{"file": "difficulty", "h": "Difficulty Levels"},
	{"file": "capture", "h": "Boss Capture"},
	{"file": "bonus", "h": "Achievements & Bonuses"},
]
const HELP_PAGES_TOUCH := [
	{"file": "touch", "h": "Controls — Touch"},
	{"file": "goal", "h": "Goal & Points"},
	{"file": "difficulty", "h": "Difficulty Levels"},
	{"file": "capture", "h": "Boss Capture"},
	{"file": "bonus", "h": "Achievements & Bonuses"},
]
var _help_page := 0
var _help_done_btn: Button
## Which page set _help_pages() returns — set from game.gd (see
## set_touch_context()), mirroring the same touch detection/retroactive flip
## game.gd itself uses for content_scale_aspect, so the help matches whatever
## input method the player is actually using right now.
var _touch_context := false

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cfg = GameSettings.load_all()

	# frosted-glass backdrop, shared by every screen (pacman's trick)
	var g := UiStyle.make_glass_backdrop()
	add_child(g.backbuffer)
	add_child(g.glass)
	_glass = g.glass

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_screens["splash"] = _build_splash()
	_screens["title"] = _build_title()
	_screens["pause"] = _build_pause()
	_screens["confirm_title"] = _build_confirm_title()
	_screens["settings"] = _build_settings()
	_screens["confirm_reset"] = _build_confirm_reset()
	_screens["sound"] = _build_sound()
	_screens["help"] = _build_help()
	_screens["gameover"] = _build_gameover()
	_screens["summary"] = _build_summary()
	_screens["highscores"] = _build_highscores()
	for s in _screens.values():
		_root.add_child(s)
	hide_all()

# ---------------------------------------------------------------- public
func hide_all() -> void:
	for s in _screens.values():
		s.hide()
	_glass.visible = false
	# Whatever the Sound screen was auditioning (SoundManager.preview_exclusive())
	# must not keep playing once it's no longer visible — covers the "Done"
	# button (via _swap()'s own hide_all() call) AND game.gd's direct callers
	# (_resume(), _new_run(), _revive_after_win_edit()) that could otherwise
	# leave a preview running right into actual gameplay (user request 2026-09-15).
	var snd := get_node_or_null("/root/Snd")
	if snd:
		snd.stop_preview()

## See space_background.gd::set_cabinet_lane() for the full story — both
## _root (every screen's container) and _glass (the frosted backdrop) default
## to full-rect, which is exactly wrong once the landscape-cabinet-overlay
## case widens the viewport: menus would center themselves on the WIDE
## window instead of the narrower lane the game world (via its own fixed
## Camera2D) actually shows. Restoring the original full-rect behavior when
## cabinet mode ends is a no-op for KEEP/KEEP_WIDTH, which never widen the
## viewport past 540 in the first place.
func set_cabinet_lane(active: bool, offset_x: float) -> void:
	for c: Control in [_root, _glass]:
		if active:
			c.set_anchors_preset(Control.PRESET_TOP_LEFT)
			c.size = Vector2(DESIGN_WIDTH, DESIGN_HEIGHT)
			c.position = Vector2(offset_x, 0.0)
		else:
			c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			c.position = Vector2.ZERO

## Screen -> which looping music track (see sound_manager.gd's LOOPING_KEYS)
## should be playing while it's shown. "menu-music" is genuinely the SAME
## background music across pause/settings/sound/confirm_reset/highscores/
## help — the user's point that it shouldn't restart just because the player
## moved to a different one of those screens — so this tracks what's ALREADY
## playing (_active_menu_music) and only stops/starts anything when the
## wanted track actually changes, never on a same-track no-op swap.
## "title"/"splash" fall through to the empty-string case (silence). "sound"
## is deliberately NOT in this list (user request 2026-09-15) — the whole
## point of that screen is auditioning individual sounds via
## SoundManager.preview_exclusive(), which ambient menu-music playing
## underneath would interfere with. Leaving "sound" for any other menu screen
## resumes menu-music normally (all of those ARE in this list).
const MENU_MUSIC_SCREENS := ["title", "pause", "settings", "confirm_reset", "confirm_title", "highscores", "help"]
const SCORE_MUSIC_SCREENS := ["summary", "gameover"]
var _active_menu_music := ""  # "" | "menu-music" | "scoring-board-music"

func _apply_screen_music(screen_name: String) -> void:
	var snd := get_node_or_null("/root/Snd")
	if not snd:
		return
	var wanted := ""
	if screen_name in MENU_MUSIC_SCREENS:
		wanted = "menu-music"
	elif screen_name in SCORE_MUSIC_SCREENS:
		wanted = "scoring-board-music"
	if wanted == _active_menu_music:
		return  # same track (or same silence) as before — leave it alone
	if _active_menu_music != "":
		snd.stop(_active_menu_music)
	_active_menu_music = wanted
	if wanted != "":
		snd.play(wanted)

## For game.gd's direct hide_all() callers (_resume(), _new_run(),
## _revive_after_win_edit()) that bypass _swap() — the only other place
## _apply_screen_music() runs — to correctly silence menu music when leaving
## the whole menu system for actual gameplay.
func stop_menu_music() -> void:
	_apply_screen_music("")

func is_open() -> bool:
	for s in _screens.values():
		if s.visible:
			return true
	return false

## Shown once at startup, before the title — see SPLASH_TIME above.
func show_splash() -> void:
	hide_all()
	_screens["splash"].show()
	_splash_active = true
	var bar := _screens["splash"].find_child("Bar", true, false) as ProgressBar
	bar.value = 0.0
	_splash_tween = create_tween()
	_splash_tween.tween_property(bar, "value", 100.0, SPLASH_TIME)
	_splash_tween.tween_callback(_finish_splash)

func _finish_splash() -> void:
	if not _splash_active:
		return
	_splash_active = false
	if _splash_tween and _splash_tween.is_valid():
		_splash_tween.kill()
	splash_done.emit()

## Tap/click/key skips the wait early — nobody wants to sit through a fixed
## delay twice in a row after backing out to the title and pressing Play again
## (show_splash() only ever runs once at startup, but better safe than annoying).
func _unhandled_input(event: InputEvent) -> void:
	if _splash_active:
		var skip: bool = (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed)
		if skip:
			get_viewport().set_input_as_handled()
			_finish_splash()
		return

	# Hall of Fame name entry: a LineEdit only submits on Enter/Kp Enter (its
	# own internal key check), never on the generic ui_accept action, so a
	# gamepad's A would otherwise do nothing while that field has focus.
	if _name_edit and is_instance_valid(_name_edit) and _name_edit.has_focus() \
			and event.is_action_pressed("ui_accept"):
		_commit_score()
		get_viewport().set_input_as_handled()
		return

	# B (ui_cancel) always backs out via whichever button on the CURRENTLY
	# visible screen is tagged "is_cancel" (see _button()'s is_cancel param),
	# independent of what currently has focus — standard gamepad convention:
	# A confirms the focused/default action, B always backs out too, both are
	# expected to work at once, not a contradiction.
	if event.is_action_pressed("ui_cancel"):
		for s in _screens.values():
			if not s.visible:
				continue
			for b in s.find_children("*", "Button", true, false):
				if b.visible and b.get_meta("is_cancel", false):
					b.pressed.emit()
					get_viewport().set_input_as_handled()
					return
			break  # found the (one) visible screen, nothing to cancel on it

	# Help page D-pad paging — ui_left/ui_right rather than move_left/right,
	# since those fire during actual gameplay steering too, not just here.
	if _screens["help"].visible:
		if event.is_action_pressed("ui_left"):
			_help_go(-1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right"):
			_help_go(1)
			get_viewport().set_input_as_handled()

func show_title() -> void:
	_swap("title")

func show_pause() -> void:
	_swap("pause")

## `won` distinguishes a "Sieg bei X Punkten" ending (GameSettings.win_score,
## game.gd::_check_win()) from a regular game over — same screen, same Hall
## of Fame, just a different heading.
func show_game_over(score: int, stage: int, won := false) -> void:
	_fill_gameover(score, stage, won)
	_swap("gameover")

## Shown first, before "gameover" (see show_game_over above) — a recap of the
## run (rescued ships + the points earned specifically from those, achievements
## collected + lap bonuses, total score) plus the player's prospective Hall of
## Fame rank if they'd qualify. Only after "Weiter" does the player reach the
## actual name-entry screen. `won` distinguishes the "Sieg bei X Punkten"
## ending from a regular game over, same as show_game_over().
func show_run_summary(score: int, stage: int, won: bool, rescues: int, rescue_points: int, achievements: int, laps: int, kill_stats: Array) -> void:
	_pending = {"score": score, "stage": stage, "won": won}
	_fill_summary(score, won, rescues, rescue_points, achievements, laps, kill_stats)
	_swap("summary")

## Reachable from the title screen AND, since the twelfth playtest round, the
## in-game pause menu (user request) — a read-only look at the board, no name
## entry involved (that only ever happens right after a run, via
## show_game_over()'s "gameover" screen). `from` reuses the same _return_to
## mechanism as settings/help so "Fertig" goes back to wherever this was
## opened from — opening it from Pause and always landing on the title screen
## afterwards would silently strand the paused run.
func show_highscores(from := "title") -> void:
	_return_to = from
	_render_hof_into(_highscores_box, HallOfFame.load_list(), -1)
	_swap("highscores")

# ---------------------------------------------------------------- helpers
func _swap(name: String) -> void:
	hide_all()
	_screens[name].show()
	_glass.visible = true
	_apply_screen_music(name)
	_grab_default_focus(_screens[name])

## First enabled, focusable Control in the screen (tree order — i.e. the
## first Button/LineEdit a builder added), for gamepad/keyboard users: without
## SOME control holding focus when a screen appears, ui_accept has nothing to
## trigger and D-pad up/down/left/right has nothing to move away from.
## call_deferred() — grab_focus() the same frame a node turns visible is
## unreliable (same reason _name_edit's own grab_focus already used it below).
func _grab_default_focus(screen: Control) -> void:
	for n in screen.find_children("*", "", true, false):
		if n is Control and n.visible and n.focus_mode != Control.FOCUS_NONE \
				and not (n is BaseButton and n.disabled):
			n.grab_focus.call_deferred()
			return

## Full-rect click-blocker (mouse_filter=STOP keeps clicks from reaching the
## game underneath) containing a centered, bordered panel — the frosted glass
## backdrop behind it is shared (see _glass), not per-screen.
func _screen() -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.name = "Box"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(340, 0)
	panel.add_child(box)
	return c

func _box(screen: Control) -> VBoxContainer:
	return screen.find_child("Box", true, false)

## Headings (size >= 24) get a dark outline — flat colored text on the panel
## read muddy; body/label text stays outline-free so it doesn't get heavy.
func _title_label(text: String, size := 30, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	if size >= 24:
		# Every screen heading (GALAGA, PAUSE, Einstellungen, Sound, Hilfe,
		# GAME OVER) gets the same "Stage 1"-banner look — one consistent
		# marquee style instead of each screen picking its own flat color.
		UiStyle.impact_label(l)
	else:
		l.add_theme_color_override("font_color", col)
	return l

## Minimum comfortable touch target (Android/iOS guidelines land around 44-48dp;
## the design canvas maps ~1:1 to device px via KEEP_WIDTH, so we size to that).
const TOUCH_H := 56.0

## `is_cancel`: tags this button as the screen's "back"/"cancel" target for the
## gamepad's B button (ui_cancel) — see _unhandled_input()'s cancel handling
## below. Focusable (Control.FOCUS_ALL, Godot's own Button default — this used
## to be FOCUS_NONE, which is exactly why keyboard/gamepad menu navigation
## never worked here at all: ui_accept only ever fires a Button that actually
## HAS focus, and a non-focusable Button can never receive it) so D-pad
## up/down/left/right can move between buttons and ui_accept can confirm
## whichever one currently has focus, same as every other Godot menu.
func _button(text: String, cb: Callable, is_cancel := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(270, TOUCH_H)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	UiStyle.style_button(b)
	if is_cancel:
		b.set_meta("is_cancel", true)
	return b

## `set_from_text`, if given, makes the value a tappable/clickable field the
## user can type an exact number into (Enter or tapping away commits it) —
## on top of the </> steppers, not instead of them. Omit it (e.g. for
## Schwierigkeit, a named choice rather than a number) to keep a plain label.
## Appends 4 flat children (name, <, value, >) to `grid` — see _build_settings()
## for why a shared GridContainer replaced one HBoxContainer per row. Returns
## the {"left", "val", "right"} controls so a caller (see _lives_stepper /
## _update_lives_lock() below) can lock a specific row after the fact.
func _add_stepper(grid: GridContainer, label_text: String, get_text: Callable, step: Callable, set_from_text := Callable()) -> Dictionary:
	var name_l := _title_label(label_text, 20)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(name_l)

	var left := _button("<", func(): step.call(-1); _refresh_settings())
	left.custom_minimum_size = Vector2(56, TOUCH_H)
	grid.add_child(left)

	var val: Control
	if set_from_text.is_valid():
		var edit := LineEdit.new()
		edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		edit.add_theme_font_size_override("font_size", 20)
		edit.add_theme_color_override("font_color", ACCENT)
		edit.add_theme_color_override("font_uneditable_color", ACCENT)
		edit.select_all_on_focus = true
		var commit := func():
			set_from_text.call(edit.text)
			_refresh_settings()
		edit.text_submitted.connect(func(_t): commit.call())
		edit.focus_entered.connect(func():
			if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
				DisplayServer.virtual_keyboard_show(edit.text, Rect2(), DisplayServer.KEYBOARD_TYPE_NUMBER))
		edit.focus_exited.connect(func():
			if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
				DisplayServer.virtual_keyboard_hide()
			commit.call())
		val = edit
	else:
		val = _title_label("", 20, ACCENT)
	val.custom_minimum_size = Vector2(110, TOUCH_H if set_from_text.is_valid() else 0.0)
	val.set_meta("get_text", get_text)
	grid.add_child(val)

	var right := _button(">", func(): step.call(1); _refresh_settings())
	right.custom_minimum_size = Vector2(56, TOUCH_H)
	grid.add_child(right)
	return {"left": left, "val": val, "right": right}

# ---------------------------------------------------------------- splash
## Deliberately NOT built via _screen() — this should read as a full-bleed
## title card, not a bordered menu panel floating on the frosted glass.
func _build_splash() -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP  # eats input so a stray tap can't leak to the game

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.035, 0.06, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(bg)

	var img := TextureRect.new()
	img.texture = load("res://splash-screen.png")
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(img)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_END
	stack.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	stack.offset_left = 50
	stack.offset_right = -50
	stack.offset_top = -90
	stack.offset_bottom = -50
	stack.add_theme_constant_override("separation", 8)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(stack)

	var lbl := _title_label("Loading …", 16, ACCENT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(lbl)

	var bar := ProgressBar.new()
	bar.name = "Bar"
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 0.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(bar)

	return c

# ---------------------------------------------------------------- title
func _build_title() -> Control:
	var s := _screen()
	var box := _box(s)
	box.add_child(_title_label("GALAGA", 52, ACCENT))
	box.add_child(_spacer(18))
	box.add_child(_button("Play", func(): start_game.emit()))
	box.add_child(_button("Settings", func(): _open_settings("title")))
	box.add_child(_button("High Scores", func(): show_highscores("title")))
	box.add_child(_button("How to Play", func(): _open_help("title")))
	if not IS_WEB:
		box.add_child(_button("Exit", func(): get_tree().quit()))
	return s

# ---------------------------------------------------------------- pause
func _build_pause() -> Control:
	var s := _screen()
	var box := _box(s)
	box.add_child(_title_label("PAUSE", 40))
	box.add_child(_spacer(14))
	box.add_child(_button("Resume", func(): resume_game.emit()))
	box.add_child(_button("Settings", func(): _open_settings("pause")))
	box.add_child(_button("High Scores", func(): show_highscores("pause")))
	box.add_child(_button("How to Play", func(): _open_help("pause")))
	box.add_child(_button("Main Menu", func(): _swap("confirm_title")))
	if not IS_WEB:
		box.add_child(_button("Exit", func(): get_tree().quit()))
	return s

## Confirmation gate for "Start-Menü" from the pause screen (user request: a
## misclick shouldn't silently abandon the run mid-game — realized only after
## shipping the button that "Start-Menü" from inside an active run is really
## "restart", not a harmless navigation). Same Ja/Nein pattern as
## _build_confirm_reset() below. Only ever reachable from "pause", so "Nein"
## can go straight back there rather than tracking a _return_to.
func _build_confirm_title() -> Control:
	var s := _screen()
	var box := _box(s)
	box.add_child(_title_label("Restart?", 26))
	box.add_child(_spacer(6))
	var msg := _title_label("Back to the main menu?\nThe current run will be lost.", 18)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(msg)
	box.add_child(_spacer(10))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var no_btn := _button("No", func(): _swap("pause"), true)
	no_btn.custom_minimum_size = Vector2(130, TOUCH_H)
	var yes_btn := _button("Yes", func(): to_title.emit())
	yes_btn.custom_minimum_size = Vector2(130, TOUCH_H)
	row.add_child(no_btn)
	row.add_child(yes_btn)
	box.add_child(row)
	return s

# ---------------------------------------------------------------- settings
func _build_settings() -> Control:
	var s := _screen()
	var box := _box(s)
	box.add_child(_title_label("Settings", 30))
	box.add_child(_spacer(10))
	# GridContainer, not one HBoxContainer per row: a GridContainer sizes each
	# COLUMN to its widest cell across every row, so </> always line up in the
	# same x position no matter how long an individual row's label is ("Boss
	# alle X Punkte" / "Sieg bei X Punkten" overflowed the old fixed-width
	# label column and threw off just those two rows' buttons).
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	_lives_stepper = _add_stepper(grid, "Lives", _fmt_lives, _step_lives, _set_lives_text)
	_add_stepper(grid, "Extra life", _fmt_extra, _step_extra, _set_extra_text)
	_add_stepper(grid, "Boss every X points", _fmt_boss_interval, _step_boss_interval, _set_boss_interval_text)
	_add_stepper(grid, "Win at X points", _fmt_win_score, _step_win_score, _set_win_score_text)
	_add_stepper(grid, "Max. shots", _fmt_max_shots, _step_max_shots, _set_max_shots_text)
	_add_stepper(grid, "Difficulty", _fmt_diff, _step_diff)
	_add_stepper(grid, "Bonus level every X stages", _fmt_bonus_interval, _step_bonus_interval, _set_bonus_interval_text)
	box.add_child(_spacer(8))
	box.add_child(_button("Defaults", func(): _swap("confirm_reset")))
	box.add_child(_button("Sound", func(): _open_sound()))
	box.add_child(_button("Done", func(): _close_sub(), true))
	return s

## Resets the gameplay steppers above to fixed factory defaults (user request)
## — NOT Sound, which lives in its own settings.cfg section and has its own
## per-key defaults already. Only mutates `_cfg` in memory, same as every
## other stepper here: still needs "Fertig" to actually persist + apply, so
## it's easy to back out of by just not confirming. Respects the same
## Leben-lock as the stepper itself (see _update_lives_lock()) — resetting it
## mid-run would be just as inert as manually stepping it, for the same reason.
## Only ever called after the "confirm_reset" screen's "Ja" (see below) — the
## "Standardwerte" button itself only opens that confirmation, so a stray tap
## can't silently wipe every setting.
func _reset_defaults() -> void:
	if _return_to != "pause" and _return_to != "summary":
		_cfg.lives = 3
	_cfg.extra_life = 5000
	_cfg.boss_interval = 10000
	_cfg.win_score = 0
	_cfg.max_shots = 2
	_cfg.difficulty = 1
	_cfg.bonus_level_interval = 3
	_refresh_settings()

## Confirmation gate for "Standardwerte" (user request: a misclick shouldn't
## silently wipe every setting) — "Nein" just goes back to "settings" with
## nothing changed, "Ja" actually calls _reset_defaults() first.
func _build_confirm_reset() -> Control:
	var s := _screen()
	var box := _box(s)
	box.add_child(_title_label("Reset?", 26))
	box.add_child(_spacer(6))
	var msg := _title_label("Really reset all settings\nto their defaults?", 18)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(msg)
	box.add_child(_spacer(10))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var no_btn := _button("No", func(): _swap("settings"), true)
	no_btn.custom_minimum_size = Vector2(130, TOUCH_H)
	var yes_btn := _button("Yes", func(): _reset_defaults(); _swap("settings"))
	yes_btn.custom_minimum_size = Vector2(130, TOUCH_H)
	row.add_child(no_btn)
	row.add_child(yes_btn)
	box.add_child(row)
	return s

func _open_settings(from: String) -> void:
	_return_to = from
	_refresh_settings()
	_swap("settings")

var _lives_stepper := {}

func _refresh_settings() -> void:
	var grid := _box(_screens["settings"]).get_node("Grid")
	for val in grid.get_children():
		if not val.has_meta("get_text"):
			continue
		if val is LineEdit and val.has_focus():
			continue  # don't clobber text the user is mid-typing
		val.text = str(val.get_meta("get_text").call())
	_update_lives_lock()

## "Leben" (initial life count) must not be changeable mid-run (user request) —
## unlike every other setting here, it's only ever read once, in game.gd's
## _new_run(), so editing it mid-game would silently do nothing anyway; better
## to make that visible than to let the player think they changed something.
## _return_to is "pause" (in-game pause menu) or "summary" (the win screen's
## own "Einstellungen" button, see _build_summary()) whenever a run is still
## in progress (or, for "summary", could resume — see game.gd's
## _revive_after_win_edit()); "title" means no run is active yet.
func _update_lives_lock() -> void:
	if _lives_stepper.is_empty():
		return
	var locked := _return_to == "pause" or _return_to == "summary"
	_lives_stepper.left.disabled = locked
	_lives_stepper.right.disabled = locked
	var val = _lives_stepper.val
	if val is LineEdit:
		val.editable = not locked
		val.focus_mode = Control.FOCUS_NONE if locked else Control.FOCUS_ALL
	val.modulate = Color(1, 1, 1, 0.4) if locked else Color(1, 1, 1, 1)

func _close_sub() -> void:
	GameSettings.save(_cfg)
	settings_changed.emit()
	# Two ways that signal can change what should happen next, both handled
	# inside game.gd's _reload_settings() synchronously before emit() returns:
	#  - it just ENDED a run early (_check_win() — lowering "Sieg bei X
	#    Punkten" below the current score) and swapped straight to the summary
	#    screen: don't stomp that by swapping back to the pause menu we came
	#    from.
	#  - it just REVIVED a run (_revive_after_win_edit() — raising/disabling
	#    "Sieg bei X Punkten" from the win screen's own settings button) and
	#    unpaused the tree to resume gameplay: don't show any menu at all, not
	#    even the summary screen we came from — that run isn't "won" anymore.
	if not get_tree().paused:
		hide_all()
		return
	if _screens["summary"].visible or _screens["gameover"].visible:
		return
	_swap(_return_to)

func _fmt_lives() -> String: return str(_cfg.lives)
func _step_lives(d: int) -> void:
	_cfg.lives = clampi(_cfg.lives + d, GameSettings.LIVES_MIN, GameSettings.LIVES_MAX)
func _set_lives_text(t: String) -> void:
	_cfg.lives = clampi(t.to_int(), GameSettings.LIVES_MIN, GameSettings.LIVES_MAX)

func _fmt_extra() -> String:
	return "off" if _cfg.extra_life == 0 else str(_cfg.extra_life)
func _step_extra(d: int) -> void:
	_cfg.extra_life = clampi(_cfg.extra_life + d * GameSettings.EXTRA_STEP, 0, GameSettings.EXTRA_MAX)
func _set_extra_text(t: String) -> void:
	var s := t.strip_edges().to_lower()
	if s == "" or s == "off" or s == "aus":
		_cfg.extra_life = 0
		return
	var n := clampi(t.to_int(), 0, GameSettings.EXTRA_MAX)
	_cfg.extra_life = int(roundf(float(n) / GameSettings.EXTRA_STEP)) * GameSettings.EXTRA_STEP

func _fmt_boss_interval() -> String:
	return "off" if _cfg.boss_interval == 0 else str(_cfg.boss_interval)
func _step_boss_interval(d: int) -> void:
	_cfg.boss_interval = clampi(_cfg.boss_interval + d * GameSettings.BOSS_INTERVAL_STEP, 0, GameSettings.BOSS_INTERVAL_MAX)
func _set_boss_interval_text(t: String) -> void:
	var s := t.strip_edges().to_lower()
	if s == "" or s == "off" or s == "aus":
		_cfg.boss_interval = 0
		return
	var n := clampi(t.to_int(), 0, GameSettings.BOSS_INTERVAL_MAX)
	_cfg.boss_interval = int(roundf(float(n) / GameSettings.BOSS_INTERVAL_STEP)) * GameSettings.BOSS_INTERVAL_STEP

func _fmt_win_score() -> String:
	return "off" if _cfg.win_score == 0 else str(_cfg.win_score)
func _step_win_score(d: int) -> void:
	_cfg.win_score = clampi(_cfg.win_score + d * GameSettings.WIN_SCORE_STEP, 0, GameSettings.WIN_SCORE_MAX)
func _set_win_score_text(t: String) -> void:
	var s := t.strip_edges().to_lower()
	if s == "" or s == "off" or s == "aus":
		_cfg.win_score = 0
		return
	var n := clampi(t.to_int(), 0, GameSettings.WIN_SCORE_MAX)
	_cfg.win_score = int(roundf(float(n) / GameSettings.WIN_SCORE_STEP)) * GameSettings.WIN_SCORE_STEP

func _fmt_max_shots() -> String: return str(_cfg.max_shots)
func _step_max_shots(d: int) -> void:
	_cfg.max_shots = clampi(_cfg.max_shots + d, GameSettings.MAX_SHOTS_MIN, GameSettings.MAX_SHOTS_MAX)
func _set_max_shots_text(t: String) -> void:
	_cfg.max_shots = clampi(t.to_int(), GameSettings.MAX_SHOTS_MIN, GameSettings.MAX_SHOTS_MAX)

func _fmt_diff() -> String: return GameSettings.DIFF_NAMES[_cfg.difficulty]
func _step_diff(d: int) -> void:
	_cfg.difficulty = clampi(_cfg.difficulty + d, 0, 2)

func _fmt_bonus_interval() -> String:
	return "off" if _cfg.bonus_level_interval == 0 else str(_cfg.bonus_level_interval)
func _step_bonus_interval(d: int) -> void:
	_cfg.bonus_level_interval = clampi(_cfg.bonus_level_interval + d, 0, GameSettings.BONUS_LEVEL_INTERVAL_MAX)
func _set_bonus_interval_text(t: String) -> void:
	var s := t.strip_edges().to_lower()
	if s == "" or s == "off" or s == "aus":
		_cfg.bonus_level_interval = 0
		return
	_cfg.bonus_level_interval = clampi(t.to_int(), 0, GameSettings.BONUS_LEVEL_INTERVAL_MAX)

# ---------------------------------------------------------------- sound
func _build_sound() -> Control:
	var s := _screen()
	var box := _box(s)
	# Widened past the standard 340px (like _build_help()) — several of the
	# 2026-09-13 sound batch's German names ("Pause-/Einstellungsmusik" etc.)
	# are longer than the old 7 keys' names and need room to wrap onto two
	# lines (see _sound_row()'s autowrap) instead of overflowing the panel.
	box.custom_minimum_size = Vector2(460, 0)
	box.add_child(_title_label("Sound", 30))
	box.add_child(_spacer(6))
	# Scrollable — 16 rows (was 7) no longer fit the 960 design canvas at once
	# alongside the title/Fertig button.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	box.add_child(scroll)
	var snd := get_node_or_null("/root/Snd")
	for key in (snd.ORDER if snd else []):
		list.add_child(_sound_row(key, snd))
	box.add_child(_spacer(8))
	box.add_child(_button("Done", func(): _swap("settings"), true))
	return s

func _sound_row(key: String, snd) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var name_l := _title_label(snd.SOUNDS[key][0], 18)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sl := HSlider.new()
	sl.min_value = 0
	sl.max_value = 100
	sl.step = 5
	sl.value = snd.get_volume(key)
	sl.custom_minimum_size = Vector2(160, TOUCH_H)
	var val := _title_label("%d%%" % int(sl.value), 17, ACCENT)
	val.custom_minimum_size = Vector2(48, 0)
	sl.value_changed.connect(func(v):
		val.text = "%d%%" % int(v)
		snd.set_volume(key, int(v)))
	sl.drag_ended.connect(func(changed):
		if changed: snd.preview_exclusive(key))
	row.add_child(name_l)
	row.add_child(sl)
	row.add_child(val)
	return row

func _open_sound() -> void:
	_swap("sound")

# ---------------------------------------------------------------- help
## Image-based (see HELP_PAGES_DESKTOP/_TOUCH above) — the panel is widened
## well past the standard 340px other screens use so the illustration has
## real room, matching how _build_splash() also breaks from the shared
## narrow-box convention for its own full-bleed art.
func _build_help() -> Control:
	var s := _screen()
	var box := _box(s)
	box.name = "Box"
	box.custom_minimum_size = Vector2(460, 0)
	var head := _title_label("", 26, ACCENT)
	head.name = "Head"
	box.add_child(head)
	box.add_child(_spacer(6))
	var img := TextureRect.new()
	img.name = "Image"
	img.custom_minimum_size = Vector2(430, 468)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(img)
	box.add_child(_spacer(8))
	var nav := HBoxContainer.new()
	nav.name = "Nav"
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 10)
	var prev := _button("‹", func(): _help_go(-1))
	prev.custom_minimum_size = Vector2(56, TOUCH_H)
	nav.add_child(prev)
	var dots := HBoxContainer.new()
	dots.name = "Dots"
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	dots.add_theme_constant_override("separation", 8)
	dots.custom_minimum_size = Vector2(80, 0)
	nav.add_child(dots)
	var next := _button("›", func(): _help_go(1))
	next.custom_minimum_size = Vector2(56, TOUCH_H)
	nav.add_child(next)
	box.add_child(nav)
	box.add_child(_spacer(4))
	# Tiny, easy-to-miss-on-purpose hint (user request 2026-09-15) — shown on
	# every page rather than added to one specific SVG, so it doesn't need
	# new artwork and stays visible regardless of which page a player happens
	# to land on. Mentions both input paths since the mute button itself is
	# always on screen (mouse/touch) but M/Select only apply off-touch.
	var mute_hint := Label.new()
	mute_hint.name = "MuteHint"
	mute_hint.text = "Tip: mute/unmute with the speaker button next to Pause, or press M / D-pad Select"
	mute_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mute_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	mute_hint.add_theme_font_size_override("font_size", 14)
	mute_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	box.add_child(mute_hint)
	box.add_child(_spacer(4))
	_help_done_btn = _button("Done", func(): _swap(_return_to), true)
	box.add_child(_help_done_btn)
	return s

## Called from game.gd whenever it (re)determines whether the player is on a
## touch device — initial detection AND the retroactive flip
## (apply_touch_layout()) both call this, so Help always matches the input
## method actually in use. Only affects which page SET _help_pages() returns;
## an already-open Help screen doesn't need to react live, this just needs to
## be current by the time _open_help() is next called.
func set_touch_context(v: bool) -> void:
	_touch_context = v

func _help_pages() -> Array:
	return HELP_PAGES_TOUCH if _touch_context else HELP_PAGES_DESKTOP

func _open_help(from: String) -> void:
	_return_to = from
	_help_page = 0
	_help_render()
	_swap("help")
	# Override _swap()'s generic "first focusable control" default (which
	# would land on the "‹" prev button here): a focused Button/Control
	# consumes ui_left/ui_right FIRST for Godot's own built-in focus-neighbor
	# navigation, before _unhandled_input()'s _help_go() ever sees the event —
	# landing default focus on "‹"/"›" meant the first D-pad-right press only
	# moved focus over to Done, and only the SECOND press actually paged (user
	# report, confirmed live on the RG552). Defaulting to Done instead — the
	# rightmost control, with no further focusable neighbor to its right —
	# means that built-in focus-move has nowhere to go, so ui_right falls
	# through to _help_go() immediately on the very first press.
	_help_done_btn.grab_focus.call_deferred()

func _help_go(d: int) -> void:
	_help_page = wrapi(_help_page + d, 0, _help_pages().size())
	_help_render()

func _help_render() -> void:
	var pages := _help_pages()
	var p: Dictionary = pages[_help_page]
	var box := _box(_screens["help"])
	(box.get_node("Head") as Label).text = p.h
	(box.get_node("Image") as TextureRect).texture = load(HELP_DIR + p.file + ".png")

	var dots := box.get_node("Nav/Dots") as HBoxContainer
	for c in dots.get_children():
		c.queue_free()
	for i in pages.size():
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(10, 10)
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		d.color = ACCENT if i == _help_page else Color(1, 1, 1, 0.22)
		dots.add_child(d)

# ---------------------------------------------------------------- game over
var _name_edit: LineEdit
var _hof_box: GridContainer
var _play_again_btn: Button

func _build_gameover() -> Control:
	var s := _screen()
	var box := _box(s)
	var title := _title_label("GAME OVER", 36)
	title.name = "Title"
	box.add_child(title)
	var sub := _title_label("", 20)
	sub.name = "Sub"
	box.add_child(sub)
	box.add_child(_spacer(6))

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Name"
	_name_edit.max_length = 8
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.custom_minimum_size = Vector2(180, TOUCH_H)
	_name_edit.add_theme_font_size_override("font_size", 20)
	_name_edit.name = "NameEdit"
	# Android/iOS only raise the on-screen keyboard on a focus change that
	# clearly comes from a tap; grab_focus() alone is not always enough on
	# every OEM skin, so nudge the virtual keyboard explicitly too.
	_name_edit.focus_entered.connect(func():
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
			DisplayServer.virtual_keyboard_show(_name_edit.text, Rect2(), DisplayServer.KEYBOARD_TYPE_DEFAULT, _name_edit.max_length))
	_name_edit.focus_exited.connect(func():
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
			DisplayServer.virtual_keyboard_hide())
	_name_edit.text_submitted.connect(func(_t: String): _commit_score())  # Enter/Return
	var save_btn := _button("Enter", func(): _commit_score())
	save_btn.name = "SaveBtn"
	var entry := HBoxContainer.new()
	entry.name = "Entry"
	entry.alignment = BoxContainer.ALIGNMENT_CENTER
	entry.add_theme_constant_override("separation", 8)
	entry.add_child(_name_edit)
	entry.add_child(save_btn)
	box.add_child(entry)

	# GridContainer (rank / name / score columns), not one padded/centered string
	# per row — a monospace-style padded string doesn't actually line up in a
	## proportional font (user report). Same fix as the settings-stepper grid
	# above: each column sizes to its own widest cell.
	_hof_box = GridContainer.new()
	_hof_box.name = "Hof"
	_hof_box.columns = 3
	_hof_box.add_theme_constant_override("h_separation", 10)
	_hof_box.add_theme_constant_override("v_separation", 2)
	box.add_child(_hof_box)

	box.add_child(_spacer(8))
	_play_again_btn = _button("Play Again", func(): _maybe_auto_commit(); start_game.emit())
	box.add_child(_play_again_btn)
	box.add_child(_button("Main Menu", func(): _maybe_auto_commit(); to_title.emit()))
	if not IS_WEB:
		box.add_child(_button("Exit", func(): _maybe_auto_commit(); get_tree().quit()))
	return s

## A qualifying score that's never actually entered (player leaves the screen
## without typing a name or clicking "Eintragen") would otherwise just be
## lost — user request: commit it as "YOU" automatically, exactly as if
## "Eintragen" had been pressed with an empty name. `Entry.visible` is exactly
## "still needs to enter" (see _fill_gameover()/​_commit_score() below), so it
## doubles as the "did they forget" check.
func _maybe_auto_commit() -> void:
	if _box(_screens["gameover"]).get_node("Entry").visible:
		_commit_score()

var _pending := {}

# ---------------------------------------------------------------- run summary
func _build_summary() -> Control:
	var s := _screen()
	var box := _box(s)
	var title := _title_label("", 36)
	title.name = "Title"
	box.add_child(title)
	box.add_child(_spacer(8))
	# Kill breakdown, one cell per SPRITE actually seen this run (not a fixed
	# 3-column row any more — there are 8 visually distinct enemies across the
	# 3 scoring tiers once stage variants are counted, plus a 9th "Boss
	# (Rettung)" bucket, see _fill_summary()/game.gd's _kill_stats). A
	# GridContainer wraps as needed instead of assuming a fixed count.
	var kills := GridContainer.new()
	kills.name = "Kills"
	kills.columns = 4
	kills.add_theme_constant_override("h_separation", 14)
	kills.add_theme_constant_override("v_separation", 6)
	box.add_child(kills)
	box.add_child(_spacer(10))
	var rescues_l := _title_label("", 18)
	rescues_l.name = "Rescues"
	box.add_child(rescues_l)
	var achv_l := _title_label("", 18)
	achv_l.name = "Achv"
	box.add_child(achv_l)
	box.add_child(_spacer(8))
	var score_l := _title_label("", 26, ACCENT)
	score_l.name = "Score"
	box.add_child(score_l)
	var rank_l := _title_label("", 18, ACCENT)
	rank_l.name = "Rank"
	box.add_child(rank_l)
	box.add_child(_spacer(12))
	# User request: let the player check/adjust settings right from the win
	# screen — most useful for "Sieg bei X Punkten": raising it (or turning it
	# off) here un-ends the run and drops straight back into gameplay instead
	# of forcing a restart just to keep playing past the old target. See
	# game.gd's _revive_after_win_edit() / _close_sub() below for the other
	# half of this.
	box.add_child(_button("Settings", func(): _open_settings("summary")))
	box.add_child(_button("Continue", func(): show_game_over(_pending.score, _pending.stage, _pending.won)))
	return s

## One cell of the Kills grid (see _build_summary above): a representative
## still-frame sprite (game.gd already resolved which one, including the
## dedicated rescue-kill icon) over an "N× / P Pkt." label.
func _kill_stat_col(icon: Texture2D, count: int, points: int) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	var icon_rect := TextureRect.new()
	icon_rect.texture = icon
	icon_rect.custom_minimum_size = Vector2(36, 36)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	col.add_child(icon_rect)
	col.add_child(_title_label("%d×\n%d pts" % [count, points], 14))
	return col

func _fill_summary(score: int, won: bool, rescues: int, rescue_points: int, achievements: int, laps: int, kill_stats: Array) -> void:
	var box := _box(_screens["summary"])
	(box.get_node("Title") as Label).text = "YOU WIN!" if won else "GAME OVER"
	var kills_grid := box.get_node("Kills") as GridContainer
	for c in kills_grid.get_children():
		c.queue_free()
	if kill_stats.is_empty():
		kills_grid.add_child(_title_label("— no enemies shot down —", 15))
	else:
		# Stable, readable order: by scoring tier, then stage-variant, with any
		# rescue-kill bucket last (it's a Boss kill too, but a distinct enough
		# event to read best at the end rather than interleaved by variant).
		var sorted: Array = kill_stats.duplicate()
		sorted.sort_custom(func(a, b):
			if a.is_rescue != b.is_rescue:
				return b.is_rescue
			if a.kind != b.kind:
				return a.kind < b.kind
			return a.variant_idx < b.variant_idx)
		for e in sorted:
			kills_grid.add_child(_kill_stat_col(e.icon, int(e.count), int(e.points)))
	(box.get_node("Rescues") as Label).text = "Rescued ships: %d  (%d points)" % [rescues, rescue_points]
	(box.get_node("Achv") as Label).text = "Achievements: %d  (laps: %d)" % [achievements, laps]
	(box.get_node("Score") as Label).text = "Total score: %06d" % score
	var rank_l := box.get_node("Rank") as Label
	var rank := HallOfFame.rank_for(score)
	rank_l.visible = rank > 0
	if rank > 0:
		rank_l.text = "New high score — rank %d!" % rank

func _fill_gameover(score: int, stage: int, won := false) -> void:
	_pending = {"score": score, "stage": stage}
	var box := _box(_screens["gameover"])
	(box.get_node("Title") as Label).text = "YOU WIN!" if won else "GAME OVER"
	(box.get_node("Sub") as Label).text = "SCORE  %06d      STAGE  %d" % [score, stage]
	var qualifies := HallOfFame.qualifies(score)
	box.get_node("Entry").visible = qualifies
	if qualifies:
		_name_edit.text = ""
		# deferred: grab_focus() the same frame a node turns visible is unreliable
		_name_edit.grab_focus.call_deferred()
	_render_hof(HallOfFame.load_list(), -1)

func _commit_score() -> void:
	var who := _name_edit.text.strip_edges()
	if who == "":
		who = "YOU"
	# Stored upper-case (user request: names always display upper-case) —
	# does nothing for names already typed in caps, and _render_hof_into()
	# below upper-cases at render time too, so pre-existing lower-case entries
	# from before this change still display correctly without a migration.
	who = who.to_upper()
	var list := HallOfFame.insert(who, int(_pending.score), int(_pending.stage))
	_box(_screens["gameover"]).get_node("Entry").visible = false
	# The name field just disappeared out from under whatever had focus (often
	# itself) — hand focus to Play Again so a gamepad/keyboard user can carry
	# straight on instead of focus hanging on a now-invisible control.
	_play_again_btn.grab_focus()
	var mine := -1
	for i in list.size():
		if list[i].name == who and int(list[i].score) == int(_pending.score):
			mine = i
			break
	_render_hof(list, mine)

func _render_hof(list: Array, highlight: int) -> void:
	_render_hof_into(_hof_box, list, highlight)

## Shared by the game-over screen's board (_hof_box, with a highlighted own
## entry) and the title screen's read-only "Highscores" screen
## (_highscores_box, no highlight) — see show_highscores() above.
func _render_hof_into(box: GridContainer, list: Array, highlight: int) -> void:
	for c in box.get_children():
		c.queue_free()
	if list.is_empty():
		box.add_child(_title_label("— no entries yet —", 17))
		return
	for i in list.size():
		var e = list[i]
		var col := ACCENT if i == highlight else Color.WHITE
		var rank_l := _title_label("%d." % (i + 1), 17, col)
		rank_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var name_l := _title_label(str(e.name).to_upper(), 17, col)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var score_l := _title_label("%06d" % int(e.score), 17, col)
		score_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		box.add_child(rank_l)
		box.add_child(name_l)
		box.add_child(score_l)

# ---------------------------------------------------------------- highscores
var _highscores_box: GridContainer

func _build_highscores() -> Control:
	var s := _screen()
	var box := _box(s)
	box.add_child(_title_label("High Scores", 30))
	box.add_child(_spacer(10))
	_highscores_box = GridContainer.new()
	_highscores_box.name = "Hof"
	_highscores_box.columns = 3
	_highscores_box.add_theme_constant_override("h_separation", 10)
	_highscores_box.add_theme_constant_override("v_separation", 2)
	box.add_child(_highscores_box)
	box.add_child(_spacer(10))
	box.add_child(_button("Done", func(): _swap(_return_to), true))
	return s

# ---------------------------------------------------------------- misc
func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func current_config() -> Dictionary:
	return _cfg.duplicate()
