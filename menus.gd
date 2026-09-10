class_name Menus
extends CanvasLayer

## All menu screens, built in code (like tetris' ui.gd): title, pause, settings,
## sound sub-page, how-to-play, game-over + hall of fame. Game drives which one
## is visible and listens to the signals below.

signal start_game       # title Play, game-over Play again
signal resume_game      # pause Resume
signal to_title         # pause Quit-to-title, game-over Title
signal settings_changed # a gameplay setting was saved

const ACCENT := Color("4db2ff")
const DIM := Color(0.02, 0.03, 0.06, 0.86)
var IS_WEB := OS.has_feature("web")  # not const: OS.has_feature isn't a constant expr

var _root: Control
var _screens := {}
var _return_to := "title"     # where "Fertig" in settings/sound/help goes back to
var _cfg := {}

# how-to-play pages
const HELP_PAGES := [
	{
		"h": "Steuerung — Tastatur / Maus",
		"l": [
			"← →  oder  A / D   bewegen",
			"Leertaste  oder  ↑    schießen",
			"Maus: Schiff folgt dem Zeiger, Linksklick schießt",
			"Esc / P    Pause",
		],
	},
	{
		"h": "Steuerung — Touch",
		"l": [
			"Irgendwo ziehen  →  Schiff lenken",
			"Es wird automatisch geschossen",
			"Pause-Knopf oben rechts",
		],
	},
	{
		"h": "Ziel",
		"l": [
			"Räume die Formation ab, bevor sie dich erwischt.",
			"Gegner tauchen einzeln herab und werfen Bomben —",
			"ausweichen und zurückschießen.",
			"Alle weg  →  nächste Stage.",
			"",
			"Bienen 50  ·  Schmetterlinge 80  ·  Flaggschiffe 150",
		],
	},
]
var _help_page := 0

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cfg = GameSettings.load_all()

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

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

func is_open() -> bool:
	for s in _screens.values():
		if s.visible:
			return true
	return false

func show_title() -> void:
	_swap("title")

func show_pause() -> void:
	_swap("pause")

func show_game_over(score: int, stage: int) -> void:
	_fill_gameover(score, stage)
	_swap("gameover")

# ---------------------------------------------------------------- helpers
func _swap(name: String) -> void:
	hide_all()
	_screens[name].show()

func _screen(dim := true) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	if dim:
		var bg := ColorRect.new()
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.color = DIM
		c.add_child(bg)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	c.add_child(box)
	return c

func _box(screen: Control) -> VBoxContainer:
	return screen.get_node("Box")

func _title_label(text: String, size := 30, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(260, 44)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	return b

func _stepper(label_text: String, get_text: Callable, step: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(320, 40)

	var name_l := _title_label(label_text, 18)
	name_l.custom_minimum_size = Vector2(150, 0)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	var left := _button("<", func(): step.call(-1); _refresh_settings())
	left.custom_minimum_size = Vector2(40, 36)
	var val := _title_label("", 18, ACCENT)
	val.custom_minimum_size = Vector2(110, 0)
	val.name = "Val"
	var right := _button(">", func(): step.call(1); _refresh_settings())
	right.custom_minimum_size = Vector2(40, 36)

	row.add_child(name_l)
	row.add_child(left)
	row.add_child(val)
	row.add_child(right)
	row.set_meta("get_text", get_text)
	return row

# ---------------------------------------------------------------- title
func _build_title() -> Control:
	var s := _screen()
	var box := _box(s)
	box.add_child(_title_label("GALAGA", 52, ACCENT))
	box.add_child(_spacer(18))
	box.add_child(_button("Spielen", func(): start_game.emit()))
	box.add_child(_button("Einstellungen", func(): _open_settings("title")))
	box.add_child(_button("Steuerung", func(): _open_help("title")))
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
	box.add_child(_button("Steuerung", func(): _open_help("pause")))
	box.add_child(_button("Zum Titel", func(): to_title.emit()))
	if not IS_WEB:
		box.add_child(_button("Beenden", func(): get_tree().quit()))
	return s

# ---------------------------------------------------------------- settings
func _build_settings() -> Control:
	var s := _screen()
	var box := _box(s)
	box.add_child(_title_label("Einstellungen", 30))
	box.add_child(_spacer(10))
	box.add_child(_stepper("Leben", _fmt_lives, _step_lives))
	box.add_child(_stepper("Extra-Leben", _fmt_extra, _step_extra))
	box.add_child(_stepper("Schwierigkeit", _fmt_diff, _step_diff))
	box.add_child(_spacer(8))
	box.add_child(_button("Sound", func(): _open_sound()))
	box.add_child(_button("Fertig", func(): _close_sub()))
	return s

func _open_settings(from: String) -> void:
	_return_to = from
	_refresh_settings()
	_swap("settings")

func _refresh_settings() -> void:
	for row in _box(_screens["settings"]).get_children():
		if row.has_meta("get_text"):
			(row.get_node("Val") as Label).text = str(row.get_meta("get_text").call())

func _close_sub() -> void:
	GameSettings.save(_cfg)
	settings_changed.emit()
	_swap(_return_to)

func _fmt_lives() -> String: return str(_cfg.lives)
func _step_lives(d: int) -> void:
	_cfg.lives = _cycle(GameSettings.LIVES_CHOICES, _cfg.lives, d)

func _fmt_extra() -> String:
	return "aus" if _cfg.extra_life == 0 else str(_cfg.extra_life)
func _step_extra(d: int) -> void:
	_cfg.extra_life = _cycle(GameSettings.EXTRA_CHOICES, _cfg.extra_life, d)

func _fmt_diff() -> String: return GameSettings.DIFF_NAMES[_cfg.difficulty]
func _step_diff(d: int) -> void:
	_cfg.difficulty = clampi(_cfg.difficulty + d, 0, 2)

func _cycle(choices: Array, cur, d: int):
	var i := choices.find(cur)
	if i == -1:
		i = 0
	return choices[wrapi(i + d, 0, choices.size())]

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
	var name_l := _title_label(snd.SOUNDS[key][0], 16)
	name_l.custom_minimum_size = Vector2(140, 0)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var sl := HSlider.new()
	sl.min_value = 0
	sl.max_value = 100
	sl.step = 5
	sl.value = snd.get_volume(key)
	sl.custom_minimum_size = Vector2(180, 20)
	var val := _title_label("%d%%" % int(sl.value), 15, ACCENT)
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
	var head := _title_label("", 26, ACCENT)
	head.name = "Head"
	box.add_child(head)
	box.add_child(_spacer(6))
	var body := _title_label("", 17)
	body.name = "Body"
	body.custom_minimum_size = Vector2(380, 180)
	box.add_child(body)
	box.add_child(_spacer(8))
	var nav := HBoxContainer.new()
	nav.name = "Nav"
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 10)
	var prev := _button("‹", func(): _help_go(-1))
	prev.custom_minimum_size = Vector2(48, 40)
	nav.add_child(prev)
	var dots := _title_label("", 16)
	dots.name = "Dots"
	dots.custom_minimum_size = Vector2(80, 0)
	nav.add_child(dots)
	var next := _button("›", func(): _help_go(1))
	next.custom_minimum_size = Vector2(48, 40)
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
	(box.get_node("Nav/Dots") as Label).text = "  ".join(
		range(HELP_PAGES.size()).map(func(i): return "●" if i == _help_page else "○"))

# ---------------------------------------------------------------- game over
var _name_edit: LineEdit
var _hof_box: VBoxContainer

func _build_gameover() -> Control:
	var s := _screen()
	var box := _box(s)
	box.add_child(_title_label("GAME OVER", 34, Color("ff6464")))
	var sub := _title_label("", 18)
	sub.name = "Sub"
	box.add_child(sub)
	box.add_child(_spacer(6))

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Name"
	_name_edit.max_length = 8
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.custom_minimum_size = Vector2(160, 34)
	_name_edit.name = "NameEdit"
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
	box.add_child(_button("Titel", func(): to_title.emit()))
	return s

var _pending := {}

func _fill_gameover(score: int, stage: int) -> void:
	_pending = {"score": score, "stage": stage}
	var box := _box(_screens["gameover"])
	(box.get_node("Sub") as Label).text = "SCORE  %06d      STAGE  %d" % [score, stage]
	var qualifies := HallOfFame.qualifies(score)
	box.get_node("Entry").visible = qualifies
	if qualifies:
		_name_edit.text = ""
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
		_hof_box.add_child(_title_label("— noch keine Einträge —", 15))
		return
	for i in list.size():
		var e = list[i]
		var line := _title_label("%2d.  %-8s  %06d" % [i + 1, str(e.name), int(e.score)], 15,
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
