class_name Hud
extends Control

## Score (top-left), stage (bottom-right), remaining lives as little ship marks
## (bottom-left, drawn), centre banner ("STAGE n"), game-over panel, and — on
## touch devices — a pause button in the top band plus a PAUSED overlay.

@onready var _score: Label = $Score
@onready var _stage: Label = $Stage
@onready var _banner: Label = $Banner
@onready var _scrim: ColorRect = $Scrim
@onready var _over: Label = $GameOver
@onready var _pause_btn: Button = $PauseButton
@onready var _paused_label: Label = $Paused

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

func set_paused(on: bool) -> void:
	_scrim.visible = on
	_paused_label.visible = on

func flash_banner(text: String) -> void:
	_banner.text = text
	_banner.visible = true

func hide_banner() -> void:
	_banner.visible = false

func show_game_over(score: int) -> void:
	_over.text = "GAME OVER\n\nSCORE  %06d\n\nSHOOT TO RESTART" % score
	_scrim.visible = true
	_over.visible = true

func _draw() -> void:
	var y := size.y - 20.0
	for i in _lives:
		var x := 16.0 + i * 26.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, y - 10.0), Vector2(x + 9.0, y + 8.0),
			Vector2(x, y + 3.0), Vector2(x - 9.0, y + 8.0),
		]), LIFE_ICON)
