class_name Hud
extends Control

## In-play HUD only: score (top-left), stage (bottom-right), remaining lives as
## little ship marks (bottom-left, drawn), the centre "STAGE n" banner, and a
## top-right pause button (frosted glass, always visible — clickable with the
## mouse on desktop, not just a touch-only affordance).
## Title / pause / settings / game-over screens live in menus.gd.

@onready var _score: Label = $Score
@onready var _stage: Label = $Stage
@onready var _banner: Label = $Banner
@onready var _pause_btn: Button = $PauseButton
var _pause_glass: ColorRect

## Small ship icons, bottom-left — the real ship art rather than a generic
## placeholder, per the user's request. Below MANY_THRESHOLD each spare ship
## gets its own icon (classic arcade style); at/above it, tetris-style, one
## icon plus "× N" instead of a row that would otherwise run off-screen.
const SHIP_ICON := preload("res://assets/graphics/player_trim.png")
const ICON_H := 24.0
const ICON_GAP := 8.0
const MANY_THRESHOLD := 3

## Bottom-centre row of collected bonus_item icons (see bonus_item.gd). A full
## row of BONUS_MAX_SHOWN is the most that fits without crowding — reaching it
## grants a lap bonus (game.gd's BONUS_LAP_POINTS) right away, then after a
## short hold (LAP_HOLD_TIME, so the completed row is actually seen) bumps the
## turquoise lap counter and clears the row so collecting can start again.
const BONUS_ICON_H := 22.0
const BONUS_ICON_GAP := 6.0
const BONUS_MAX_SHOWN := 7
# Same colour as the Stage label right next to it (UiStyle.ACCENT — a
# blue-leaning turquoise, per the user: "also a kind of turquoise", just not
# the more saturated Laser.ACCENT_NORMAL this used at first) rather than the
# gold it used to be, so the two neighbouring HUD elements read as one family.
const BONUS_LAP_COLOR := UiStyle.ACCENT
## How long a just-completed 7-icon row stays fully visible before it clears
## and the lap counter ticks up (user report: the 7th, previously-unseen icon
## used to get wiped in the very same frame it was added — add_bonus_icon()
## below returned "lap done" and the row was cleared synchronously, so the
## HUD never actually drew that 7th icon even once).
const LAP_HOLD_TIME := 0.7
## Lap marker now sits at a FIXED spot near the right edge (user request: was
## drawn immediately after the icon row, which made it drift left/right with
## the row's own width) — anchored off the Stage label's own left edge
## (game.tscn: anchor_right=1, offset_left=-170) so it keeps a real gap to
## Stage on its right and stays clear of the bonus-icon row (centered, max
## 6 icons shown before a lap clears it) on its left.
const STAGE_LABEL_LEFT := 170.0
# Trimmed from 14 (user report: too much air to Stage, too little to the
# achievement row) — moving the marker right shrinks the Stage gap by exactly
# this much AND grows the achievement-row gap by about half as much again
# (the row's own centering formula also shifts right as the usable zone
# shrinks), so this one number improves both complaints at once.
const LAP_MARKER_GAP_RIGHT := 6.0
const LAP_MARKER_W := 54.0
const ICON_ROW_GAP_FROM_MARKER := 10.0
## Shifts the whole achievement-icon row right, off dead-center (user report:
## at 3+ remaining ships the lives readout becomes "icon × N" text — see
## MANY_THRESHOLD below — and with a wide N (two digits) plus a wide icon row,
## the row's own left edge could reach far enough left to sit under that text).
## This is only the PREFERRED offset; _draw_bonus_icons() below still clamps
## the result to never actually cross ROW_LEFT_MIN_X or the lap-marker zone.
const BONUS_ROW_SHIFT_RIGHT := 28.0
## Hard left boundary for the icon row — clears the lives readout even at its
## widest ("× 99", the runtime cap — see game.gd's MAX_LIVES_RUNTIME) plus a
## real gap, verified against the font's actual string width live.
const ROW_LEFT_MIN_X := 90.0

# Stage banner: full-opacity hold, then a fade tail (tetris' main.gd _flash()
# does the same "hold then fade" instead of a hard on/off — a banner that
# just vanishes reads as way too brief even at a longer raw duration).
const BANNER_HOLD := 1.8
const BANNER_FADE := 0.9
const BANNER_TOTAL := BANNER_HOLD + BANNER_FADE

var _lives := 0
var _banner_tween: Tween
var _bonus_icons: Array[Texture2D] = []
var _bonus_icon_indices: Array[int] = []
var _bonus_laps := 0
var _lap_pending := false

signal pause_pressed

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	_pause_btn.pressed.connect(func(): pause_pressed.emit())
	_pause_btn.visible = true
	UiStyle.style_button(_pause_btn)
	_add_pause_glass()
	UiStyle.impact_label(_banner)
	_stage.add_theme_color_override("font_color", UiStyle.ACCENT)
	_stage.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_stage.add_theme_constant_override("outline_size", 4)

func set_score(n: int) -> void:
	_score.text = "%06d" % n

func set_stage(n: int) -> void:
	_stage.text = "STAGE %d" % n

func set_lives(n: int) -> void:
	_lives = maxi(n, 0)
	queue_redraw()

## Returns true if this icon completed a full row (lap) — the caller (game.gd)
## awards BONUS_LAP_POINTS and flashes the "LAP!" banner right away when that
## happens. The row itself, though, stays fully visible (all 7 icons drawn)
## for LAP_HOLD_TIME before it actually clears and the lap counter ticks up —
## see _finish_lap() below.
func add_bonus_icon(tex: Texture2D, idx: int) -> bool:
	if _lap_pending:
		# The row is already full and holding for display (see _finish_lap()) —
		# a pickup landing during that ~0.7s window still scores in game.gd (it
		# adds its own points before calling this), it just doesn't get a slot
		# in the row: appending here would let the row grow past BONUS_MAX_SHOWN
		# until the hold ends (caught live: 6 extra test pickups during one
		# hold window pushed the drawn row to 8 icons, spilling into the lap
		# marker's reserved space).
		return false
	_bonus_icons.append(tex)
	_bonus_icon_indices.append(idx)
	queue_redraw()
	var lap_done := _bonus_icons.size() >= BONUS_MAX_SHOWN
	if lap_done:
		_lap_pending = true
		get_tree().create_timer(LAP_HOLD_TIME, false).timeout.connect(_finish_lap)
	return lap_done

func _finish_lap() -> void:
	if not _lap_pending:
		return  # a run reset (clear_bonus_icons()) already cancelled this
	_lap_pending = false
	_bonus_laps += 1
	_bonus_icons.clear()
	_bonus_icon_indices.clear()
	queue_redraw()

## Which icon indices are already shown in the CURRENT (unfinished) row — a
## new bonus_item (see bonus_item.gd) excludes these so the same achievement
## never appears twice before the row resets.
func current_lap_indices() -> Array[int]:
	return _bonus_icon_indices.duplicate()

func clear_bonus_icons() -> void:
	_bonus_icons.clear()
	_bonus_icon_indices.clear()
	_bonus_laps = 0
	_lap_pending = false  # cancels any in-flight _finish_lap() from the last run
	queue_redraw()

## Frosted-glass chip sized to the pause button's own rect — same trick as
## menus.gd's full-screen backdrop (UiStyle.make_glass_backdrop()), just
## scaled to one small control instead of the whole panel, and always on
## (not toggled) since the pause button itself is always visible now.
func _add_pause_glass() -> void:
	var g := UiStyle.make_glass_backdrop()
	# Draw order matters twice over here: the BackBufferCopy must capture the
	# frame BEFORE the button draws (else it'd blur-capture its own button),
	# and the glass ColorRect must draw AFTER the backbuffer but BEFORE the
	# button (else the blur would paint over the button's label/style).
	var btn_idx := _pause_btn.get_index()
	add_child(g.backbuffer)
	move_child(g.backbuffer, btn_idx)
	add_child(g.glass)
	move_child(g.glass, btn_idx + 1)
	_pause_glass = g.glass
	_pause_glass.visible = true
	_pause_glass.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_pause_glass.offset_left = _pause_btn.offset_left
	_pause_glass.offset_top = _pause_btn.offset_top
	_pause_glass.offset_right = _pause_btn.offset_right
	_pause_glass.offset_bottom = _pause_btn.offset_bottom

# hide the whole HUD while a full-screen menu is up
func set_playing(on: bool) -> void:
	visible = on

func flash_banner(text: String) -> void:
	if _banner_tween:
		_banner_tween.kill()
	_banner.text = text
	_banner.modulate.a = 1.0
	_banner.visible = true
	_banner_tween = create_tween()
	_banner_tween.tween_interval(BANNER_HOLD)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, BANNER_FADE)
	_banner_tween.tween_callback(func(): _banner.visible = false)

func hide_banner() -> void:
	if _banner_tween:
		_banner_tween.kill()
	_banner.visible = false

func _draw() -> void:
	_draw_lives()
	_draw_bonus_icons()

func _draw_lives() -> void:
	if _lives <= 0:
		return
	var y := size.y - ICON_H - 6.0
	var icon_w := ICON_H * (SHIP_ICON.get_width() / float(SHIP_ICON.get_height()))
	if _lives < MANY_THRESHOLD:
		for i in _lives:
			var x := 12.0 + i * (icon_w + ICON_GAP)
			draw_texture_rect(SHIP_ICON, Rect2(x, y, icon_w, ICON_H), false)
		return
	draw_texture_rect(SHIP_ICON, Rect2(12.0, y, icon_w, ICON_H), false)
	var font := get_theme_default_font()
	var fsize := 20
	var label_pos := Vector2(12.0 + icon_w + 6.0, y + ICON_H - 4.0)
	draw_string_outline(font, label_pos, "× %d" % _lives, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, 4, Color(0, 0, 0, 0.85))
	draw_string(font, label_pos, "× %d" % _lives, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, UiStyle.ACCENT)

## Bottom-centre — plenty of free space there per the user's own suggestion.
## Centered within the space LEFT of the fixed lap-marker zone (not the full
## screen width), nudged right by BONUS_ROW_SHIFT_RIGHT and then hard-clamped
## to [ROW_LEFT_MIN_X, usable_w - total_w] — i.e. it can never cross into
## either the lives readout on its left or the lap marker on its right,
## regardless of icon count/width or how many digits the lives count has.
## A row that still wouldn't fit that gap at full size (verified live: 7
## icons of the widest achievement art, all at once, overflowed both bounds
## at once) is scaled down uniformly instead of being allowed to overlap
## either neighbour — a smaller row reads far better than a collision.
## The lap marker itself is always drawn (even at 0 icons / 0 laps) — user
## request: it should read as a permanent counter, not something that only
## appears once you've earned your first lap.
func _draw_bonus_icons() -> void:
	var y := size.y - BONUS_ICON_H - 6.0
	_draw_lap_marker(y)
	if _bonus_icons.is_empty():
		return
	var raw_widths: Array[float] = []
	var raw_total := -BONUS_ICON_GAP
	for tex in _bonus_icons:
		var w := BONUS_ICON_H * (tex.get_width() / float(tex.get_height()))
		raw_widths.append(w)
		raw_total += w + BONUS_ICON_GAP
	var marker_left := size.x - STAGE_LABEL_LEFT - LAP_MARKER_GAP_RIGHT - LAP_MARKER_W
	var usable_w := marker_left - ICON_ROW_GAP_FROM_MARKER
	var available_w := usable_w - ROW_LEFT_MIN_X
	# "row_scale", not "scale" — Control already has a built-in `scale` property
	# (its own transform), and shadowing it triggered a real warning live.
	var row_scale := 1.0 if raw_total <= available_w else available_w / raw_total
	var icon_h := BONUS_ICON_H * row_scale
	var gap := BONUS_ICON_GAP * row_scale
	var widths: Array[float] = []
	var total_w := -gap
	for w in raw_widths:
		var sw := w * row_scale
		widths.append(sw)
		total_w += sw + gap
	var icon_y := size.y - icon_h - 6.0
	var x := clampf(usable_w * 0.5 - total_w * 0.5 + BONUS_ROW_SHIFT_RIGHT,
		ROW_LEFT_MIN_X, usable_w - total_w)
	for i in _bonus_icons.size():
		draw_texture_rect(_bonus_icons[i], Rect2(x, icon_y, widths[i], icon_h), false)
		x += widths[i] + gap

## Small turquoise "lap" badge — how many times a full row has been cleared —
## at its fixed position near the right edge, see STAGE_LABEL_LEFT above.
## Always drawn, starting at "× 0" (see _draw_bonus_icons()).
func _draw_lap_marker(y: float) -> void:
	var x := size.x - STAGE_LABEL_LEFT - LAP_MARKER_GAP_RIGHT - LAP_MARKER_W
	var r := BONUS_ICON_H * 0.5
	var center := Vector2(x + r, y + r)
	draw_circle(center, r, BONUS_LAP_COLOR)
	draw_arc(center, r, 0.0, TAU, 24, Color(0, 0, 0, 0.85), 2.0)
	var font := get_theme_default_font()
	var fsize := 16
	var label_pos := Vector2(x + BONUS_ICON_H + 4.0, y + BONUS_ICON_H - 5.0)
	draw_string_outline(font, label_pos, "× %d" % _bonus_laps, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, 3, Color(0, 0, 0, 0.85))
	draw_string(font, label_pos, "× %d" % _bonus_laps, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, BONUS_LAP_COLOR)
