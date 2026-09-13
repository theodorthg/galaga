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

# how-to-play pages
const HELP_PAGES := [
	{
		"h": "Steuerung — Tastatur / Maus",
		"l": [
			"Pfeiltasten links/rechts  oder  A / D   bewegen",
			"Leertaste  oder  Pfeiltaste hoch   schießen",
			"Maus: Schiff folgt dem Zeiger, Linksklick schießt",
			"Esc / P    Pause",
		],
	},
	{
		"h": "Steuerung — Touch",
		"l": [
			"Irgendwo ziehen, um das Schiff zu lenken",
			"Es wird automatisch geschossen",
			"Pause-Knopf oben rechts",
		],
	},
	{
		"h": "Ziel & Punkte",
		"l": [
			"Räume die Formation ab, bevor sie dich erwischt.",
			"Gegner tauchen einzeln herab und werfen Bomben —",
			"ausweichen und zurückschießen. Alle weg = nächste Stage.",
			"",
			"Ein Boss kann dein Schiff mit einem Traktorstrahl fangen.",
			"Schießt du genau diesen Boss danach ab, bekommst du es",
			"zurück — als Doppeljäger mit doppelter Feuerkraft.",
		],
		"icons": [
			{"kind": EnemyKinds.ZAKO, "name": "Biene"},
			{"kind": EnemyKinds.GOEI, "name": "Schmetterling"},
			{"kind": EnemyKinds.BOSS, "name": "Flaggschiff"},
		],
	},
]
var _help_page := 0

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
	_screens["settings"] = _build_settings()
	_screens["sound"] = _build_sound()
	_screens["help"] = _build_help()
	_screens["gameover"] = _build_gameover()
	for s in _screens.values():
		_root.add_child(s)
	hide_all()

# ---------------------------------------------------------------- public
func hide_all() -> void:
	for s in _screens.values():
		s.hide()
	_glass.visible = false

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
	if not _splash_active:
		return
	var skip: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if skip:
		get_viewport().set_input_as_handled()
		_finish_splash()

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

# ---------------------------------------------------------------- helpers
func _swap(name: String) -> void:
	hide_all()
	_screens[name].show()
	_glass.visible = true

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

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(270, TOUCH_H)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	UiStyle.style_button(b)
	return b

## `set_from_text`, if given, makes the value a tappable/clickable field the
## user can type an exact number into (Enter or tapping away commits it) —
## on top of the </> steppers, not instead of them. Omit it (e.g. for
## Schwierigkeit, a named choice rather than a number) to keep a plain label.
## Appends 4 flat children (name, <, value, >) to `grid` — see _build_settings()
## for why a shared GridContainer replaced one HBoxContainer per row.
func _add_stepper(grid: GridContainer, label_text: String, get_text: Callable, step: Callable, set_from_text := Callable()) -> void:
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

	var lbl := _title_label("Lädt …", 16, ACCENT)
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
	box.add_child(_button("Spielen", func(): start_game.emit()))
	box.add_child(_button("Einstellungen", func(): _open_settings("title")))
	box.add_child(_button("Hilfe", func(): _open_help("title")))
	if not IS_WEB:
		box.add_child(_button("Beenden", func(): get_tree().quit()))
	return s

# ---------------------------------------------------------------- pause
func _build_pause() -> Control:
	var s := _screen()
	var box := _box(s)
	box.add_child(_title_label("PAUSE", 40))
	box.add_child(_spacer(14))
	box.add_child(_button("Weiter", func(): resume_game.emit()))
	box.add_child(_button("Einstellungen", func(): _open_settings("pause")))
	box.add_child(_button("Hilfe", func(): _open_help("pause")))
	box.add_child(_button("Start-Menü", func(): to_title.emit()))
	if not IS_WEB:
		box.add_child(_button("Beenden", func(): get_tree().quit()))
	return s

# ---------------------------------------------------------------- settings
func _build_settings() -> Control:
	var s := _screen()
	var box := _box(s)
	box.add_child(_title_label("Einstellungen", 30))
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
	_add_stepper(grid, "Leben", _fmt_lives, _step_lives, _set_lives_text)
	_add_stepper(grid, "Extra-Leben", _fmt_extra, _step_extra, _set_extra_text)
	_add_stepper(grid, "Boss alle X Punkte", _fmt_boss_interval, _step_boss_interval, _set_boss_interval_text)
	_add_stepper(grid, "Sieg bei X Punkten", _fmt_win_score, _step_win_score, _set_win_score_text)
	_add_stepper(grid, "Max. Schüsse", _fmt_max_shots, _step_max_shots, _set_max_shots_text)
	_add_stepper(grid, "Schwierigkeit", _fmt_diff, _step_diff)
	box.add_child(_spacer(8))
	box.add_child(_button("Sound", func(): _open_sound()))
	box.add_child(_button("Fertig", func(): _close_sub()))
	return s

func _open_settings(from: String) -> void:
	_return_to = from
	_refresh_settings()
	_swap("settings")

func _refresh_settings() -> void:
	var grid := _box(_screens["settings"]).get_node("Grid")
	for val in grid.get_children():
		if not val.has_meta("get_text"):
			continue
		if val is LineEdit and val.has_focus():
			continue  # don't clobber text the user is mid-typing
		val.text = str(val.get_meta("get_text").call())

func _close_sub() -> void:
	GameSettings.save(_cfg)
	settings_changed.emit()
	_swap(_return_to)

func _fmt_lives() -> String: return str(_cfg.lives)
func _step_lives(d: int) -> void:
	_cfg.lives = clampi(_cfg.lives + d, GameSettings.LIVES_MIN, GameSettings.LIVES_MAX)
func _set_lives_text(t: String) -> void:
	_cfg.lives = clampi(t.to_int(), GameSettings.LIVES_MIN, GameSettings.LIVES_MAX)

func _fmt_extra() -> String:
	return "aus" if _cfg.extra_life == 0 else str(_cfg.extra_life)
func _step_extra(d: int) -> void:
	_cfg.extra_life = clampi(_cfg.extra_life + d * GameSettings.EXTRA_STEP, 0, GameSettings.EXTRA_MAX)
func _set_extra_text(t: String) -> void:
	var s := t.strip_edges().to_lower()
	if s == "" or s == "aus":
		_cfg.extra_life = 0
		return
	var n := clampi(t.to_int(), 0, GameSettings.EXTRA_MAX)
	_cfg.extra_life = int(roundf(float(n) / GameSettings.EXTRA_STEP)) * GameSettings.EXTRA_STEP

func _fmt_boss_interval() -> String:
	return "aus" if _cfg.boss_interval == 0 else str(_cfg.boss_interval)
func _step_boss_interval(d: int) -> void:
	_cfg.boss_interval = clampi(_cfg.boss_interval + d * GameSettings.BOSS_INTERVAL_STEP, 0, GameSettings.BOSS_INTERVAL_MAX)
func _set_boss_interval_text(t: String) -> void:
	var s := t.strip_edges().to_lower()
	if s == "" or s == "aus":
		_cfg.boss_interval = 0
		return
	var n := clampi(t.to_int(), 0, GameSettings.BOSS_INTERVAL_MAX)
	_cfg.boss_interval = int(roundf(float(n) / GameSettings.BOSS_INTERVAL_STEP)) * GameSettings.BOSS_INTERVAL_STEP

func _fmt_win_score() -> String:
	return "aus" if _cfg.win_score == 0 else str(_cfg.win_score)
func _step_win_score(d: int) -> void:
	_cfg.win_score = clampi(_cfg.win_score + d * GameSettings.WIN_SCORE_STEP, 0, GameSettings.WIN_SCORE_MAX)
func _set_win_score_text(t: String) -> void:
	var s := t.strip_edges().to_lower()
	if s == "" or s == "aus":
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

# ---------------------------------------------------------------- sound
func _build_sound() -> Control:
	var s := _screen()
	var box := _box(s)
	box.add_child(_title_label("Sound", 30))
	box.add_child(_spacer(6))
	var snd := get_node_or_null("/root/Snd")
	for key in (snd.ORDER if snd else []):
		box.add_child(_sound_row(key, snd))
	box.add_child(_spacer(8))
	box.add_child(_button("Fertig", func(): _swap("settings")))
	return s

func _sound_row(key: String, snd) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var name_l := _title_label(snd.SOUNDS[key][0], 18)
	name_l.custom_minimum_size = Vector2(140, 0)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var sl := HSlider.new()
	sl.min_value = 0
	sl.max_value = 100
	sl.step = 5
	sl.value = snd.get_volume(key)
	sl.custom_minimum_size = Vector2(180, TOUCH_H)
	var val := _title_label("%d%%" % int(sl.value), 17, ACCENT)
	val.custom_minimum_size = Vector2(48, 0)
	sl.value_changed.connect(func(v):
		val.text = "%d%%" % int(v)
		snd.set_volume(key, int(v)))
	sl.drag_ended.connect(func(changed):
		if changed: snd.preview(key))
	row.add_child(name_l)
	row.add_child(sl)
	row.add_child(val)
	return row

func _open_sound() -> void:
	_swap("sound")

# ---------------------------------------------------------------- help
func _build_help() -> Control:
	var s := _screen()
	var box := _box(s)
	box.name = "Box"
	var head := _title_label("", 30, ACCENT)
	head.name = "Head"
	box.add_child(head)
	box.add_child(_spacer(8))
	var body := _title_label("", 22)
	body.name = "Body"
	body.custom_minimum_size = Vector2(400, 210)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD  # long lines wrap instead of stretching the panel
	box.add_child(body)
	var icons := HBoxContainer.new()
	icons.name = "Icons"
	icons.alignment = BoxContainer.ALIGNMENT_CENTER
	icons.add_theme_constant_override("separation", 22)
	box.add_child(icons)
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
	box.add_child(_button("Fertig", func(): _swap(_return_to)))
	return s

func _open_help(from: String) -> void:
	_return_to = from
	_help_page = 0
	_help_render()
	_swap("help")

func _help_go(d: int) -> void:
	_help_page = wrapi(_help_page + d, 0, HELP_PAGES.size())
	_help_render()

func _help_render() -> void:
	var p: Dictionary = HELP_PAGES[_help_page]
	var box := _box(_screens["help"])
	(box.get_node("Head") as Label).text = p.h
	(box.get_node("Body") as Label).text = "\n".join(p.l)

	var icons := box.get_node("Icons") as HBoxContainer
	for c in icons.get_children():
		c.queue_free()
	var icon_entries: Array = p.get("icons", [])
	icons.visible = not icon_entries.is_empty()
	for entry in icon_entries:
		icons.add_child(_icon_col(entry.kind, entry.name))

	var dots := box.get_node("Nav/Dots") as HBoxContainer
	for c in dots.get_children():
		c.queue_free()
	for i in HELP_PAGES.size():
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(10, 10)
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		d.color = ACCENT if i == _help_page else Color(1, 1, 1, 0.22)
		dots.add_child(d)

## Small "legend" column for the Ziel-page icon row: the enemy's classic
## sprite (stage-variant-independent, so it stays recognizable no matter
## which stage's reskin is currently in play) over its name + point value.
func _icon_col(kind: int, label_text: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	var icon := TextureRect.new()
	icon.texture = load(EnemyKinds.DATA[kind]["texture"])
	icon.custom_minimum_size = Vector2(44, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	col.add_child(icon)
	var lbl := _title_label("%s\n%d Pkt." % [label_text, int(EnemyKinds.DATA[kind]["points"])], 15)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(lbl)
	return col

# ---------------------------------------------------------------- game over
var _name_edit: LineEdit
var _hof_box: VBoxContainer

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
	var save_btn := _button("Eintragen", func(): _commit_score())
	save_btn.name = "SaveBtn"
	var entry := HBoxContainer.new()
	entry.name = "Entry"
	entry.alignment = BoxContainer.ALIGNMENT_CENTER
	entry.add_theme_constant_override("separation", 8)
	entry.add_child(_name_edit)
	entry.add_child(save_btn)
	box.add_child(entry)

	_hof_box = VBoxContainer.new()
	_hof_box.name = "Hof"
	_hof_box.add_theme_constant_override("separation", 2)
	box.add_child(_hof_box)

	box.add_child(_spacer(8))
	box.add_child(_button("Nochmal", func(): start_game.emit()))
	box.add_child(_button("Start-Menü", func(): to_title.emit()))
	if not IS_WEB:
		box.add_child(_button("Beenden", func(): get_tree().quit()))
	return s

var _pending := {}

func _fill_gameover(score: int, stage: int, won := false) -> void:
	_pending = {"score": score, "stage": stage}
	var box := _box(_screens["gameover"])
	(box.get_node("Title") as Label).text = "SIEG!" if won else "GAME OVER"
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
	var list := HallOfFame.insert(who, int(_pending.score), int(_pending.stage))
	_box(_screens["gameover"]).get_node("Entry").visible = false
	var mine := -1
	for i in list.size():
		if list[i].name == who and int(list[i].score) == int(_pending.score):
			mine = i
			break
	_render_hof(list, mine)

func _render_hof(list: Array, highlight: int) -> void:
	for c in _hof_box.get_children():
		c.queue_free()
	if list.is_empty():
		_hof_box.add_child(_title_label("— noch keine Einträge —", 17))
		return
	for i in list.size():
		var e = list[i]
		var line := _title_label("%2d.  %-8s  %06d" % [i + 1, str(e.name), int(e.score)], 17,
			ACCENT if i == highlight else Color.WHITE)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hof_box.add_child(line)

# ---------------------------------------------------------------- misc
func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func current_config() -> Dictionary:
	return _cfg.duplicate()
