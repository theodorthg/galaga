class_name Hud
extends Control

## In-play HUD only: score (top-left), stage (bottom-right), remaining lives as
## little ship marks (bottom-left, drawn), the centre "STAGE n" banner, and — on
## touch devices — a pause button in the top band.
## Title / pause / settings / game-over screens live in menus.gd.

@onready var _score: Label = $Score
@onready var _stage: Label = $Stage
@onready var _banner: Label = $Banner
@onready var _pause_btn: Button = $PauseButton

## Small ship icons, bottom-left — the real ship art rather than a generic
## placeholder, per the user's request. Below MANY_THRESHOLD each spare ship
## gets its own icon (classic arcade style); at/above it, tetris-style, one
## icon plus "× N" instead of a row that would otherwise run off-screen.
const SHIP_ICON := preload("res://assets/graphics/player_trim.png")
const ICON_H := 24.0
const ICON_GAP := 8.0
const MANY_THRESHOLD := 5

## Bottom-centre row of collected bonus_item icons (see bonus_item.gd). A full
## row of BONUS_MAX_SHOWN is the most that fits without crowding — reaching it
## grants a lap bonus (game.gd's BONUS_LAP_POINTS), bumps the lap counter
## (small gold marker, drawn to the right of the row) and clears the row so
## collecting can start again from empty.
const BONUS_ICON_H := 22.0
const BONUS_ICON_GAP := 6.0
const BONUS_MAX_SHOWN := 7
const BONUS_LAP_COLOR := Color(0.95, 0.75, 0.15)

# Stage banner: full-opacity hold, then a fade tail (tetris' main.gd _flash()
# does the same "hold then fade" instead of a hard on/off — a banner that
# just vanishes reads as way too brief even at a longer raw duration).
const BANNER_HOLD := 1.8
const BANNER_FADE := 0.9
const BANNER_TOTAL := BANNER_HOLD + BANNER_FADE

var _lives := 0
var _banner_tween: Tween
var _bonus_icons: Array[Texture2D] = []
var _bonus_laps := 0

signal pause_pressed

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	_pause_btn.pressed.connect(func(): pause_pressed.emit())
	_pause_btn.visible = false
	UiStyle.style_button(_pause_btn)
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

## Returns true if this icon completed a full row (lap) — the caller
## (game.gd) awards BONUS_LAP_POINTS when that happens.
func add_bonus_icon(tex: Texture2D) -> bool:
	_bonus_icons.append(tex)
	var lap_done := _bonus_icons.size() >= BONUS_MAX_SHOWN
	if lap_done:
		_bonus_laps += 1
		_bonus_icons.clear()
	queue_redraw()
	return lap_done

func clear_bonus_icons() -> void:
	_bonus_icons.clear()
	_bonus_laps = 0
	queue_redraw()

func set_touch(on: bool) -> void:
	_pause_btn.visible = on

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
func _draw_bonus_icons() -> void:
	if _bonus_icons.is_empty() and _bonus_laps <= 0:
		return
	var widths: Array[float] = []
	var total_w := -BONUS_ICON_GAP if not _bonus_icons.is_empty() else 0.0
	for tex in _bonus_icons:
		var w := BONUS_ICON_H * (tex.get_width() / float(tex.get_height()))
		widths.append(w)
		total_w += w + BONUS_ICON_GAP
	var y := size.y - BONUS_ICON_H - 6.0
	var x := size.x * 0.5 - total_w * 0.5
	for i in _bonus_icons.size():
		draw_texture_rect(_bonus_icons[i], Rect2(x, y, widths[i], BONUS_ICON_H), false)
		x += widths[i] + BONUS_ICON_GAP
	if _bonus_laps > 0:
		_draw_lap_marker(x + (BONUS_ICON_GAP if not _bonus_icons.is_empty() else 0.0), y)

## Small gold "lap" badge — how many times a full row has been cleared —
## drawn right after the current (possibly empty) icon row.
func _draw_lap_marker(x: float, y: float) -> void:
	var r := BONUS_ICON_H * 0.5
	var center := Vector2(x + r, y + r)
	draw_circle(center, r, BONUS_LAP_COLOR)
	draw_arc(center, r, 0.0, TAU, 24, Color(0, 0, 0, 0.85), 2.0)
	var font := get_theme_default_font()
	var fsize := 16
	var label_pos := Vector2(x + BONUS_ICON_H + 4.0, y + BONUS_ICON_H - 5.0)
	draw_string_outline(font, label_pos, "× %d" % _bonus_laps, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, 3, Color(0, 0, 0, 0.85))
	draw_string(font, label_pos, "× %d" % _bonus_laps, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, BONUS_LAP_COLOR)
