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

const LIFE_ICON := Color("ffd23f")

var _lives := 0

signal pause_pressed

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	_pause_btn.pressed.connect(func(): pause_pressed.emit())
	_pause_btn.visible = false

func set_score(n: int) -> void:
	_score.text = "%06d" % n

func set_stage(n: int) -> void:
	_stage.text = "STAGE %d" % n

func set_lives(n: int) -> void:
	_lives = maxi(n, 0)
	queue_redraw()

func set_touch(on: bool) -> void:
	_pause_btn.visible = on

# hide the whole HUD while a full-screen menu is up
func set_playing(on: bool) -> void:
	visible = on

func flash_banner(text: String) -> void:
	_banner.text = text
	_banner.visible = true

func hide_banner() -> void:
	_banner.visible = false

func _draw() -> void:
	var y := size.y - 20.0
	for i in _lives:
		var x := 16.0 + i * 26.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, y - 10.0), Vector2(x + 9.0, y + 8.0),
			Vector2(x, y + 3.0), Vector2(x - 9.0, y + 8.0),
		]), LIFE_ICON)
