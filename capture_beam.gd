extends Area2D

## Boss Galaga's tractor beam. Grows down from the boss, holds, retracts.
## Same "enemy_shots" group/layer as bomb.gd, so the ship's own collision
## handling destroys it exactly like a bomb hit (lose a life, respawn) —
## this script only needs to separately notice the catch itself, so the
## owning boss (enemy.gd) knows to carry a captured-ship sprite home instead
## of returning empty. Also tagged "capture_beam" (on top of "enemy_shots")
## so ship.gd can tell a capture apart from an actual hit — the user wants
## the new destruction explosion skipped for a capture (it's not really
## "destroyed", just carried off), see ship.gd::_destroy().

const GROW_TIME := 0.28
const HOLD_TIME := 0.45
const SHRINK_TIME := 0.22
const MAX_LEN := 520.0
const WIDTH := 22.0

var _t := 0.0
var _phase := 0  # 0 grow, 1 hold, 2 shrink
var _len := 0.0
var _caught := false

signal caught

@onready var _col: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE  # freeze on pause, not inherit Game's ALWAYS
	add_to_group("enemy_shots")
	add_to_group("capture_beam")
	area_entered.connect(_on_area_entered)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(WIDTH, 1.0)
	_col.shape = shape
	_update_shape()
	queue_redraw()

func _on_area_entered(area: Area2D) -> void:
	if not _caught and area.is_in_group("player"):
		_caught = true
		caught.emit()

func _process(delta: float) -> void:
	_t += delta
	match _phase:
		0:
			_len = MAX_LEN * minf(_t / GROW_TIME, 1.0)
			if _t >= GROW_TIME:
				_phase = 1
				_t = 0.0
		1:
			if _t >= HOLD_TIME:
				_phase = 2
				_t = 0.0
		2:
			_len = MAX_LEN * (1.0 - minf(_t / SHRINK_TIME, 1.0))
			if _t >= SHRINK_TIME:
				queue_free()
				return
	_update_shape()
	queue_redraw()

func _update_shape() -> void:
	var shape: RectangleShape2D = _col.shape
	shape.size = Vector2(WIDTH, maxf(_len, 1.0))
	_col.position = Vector2(0, _len * 0.5)

func _draw() -> void:
	if _len <= 0.0:
		return
	draw_rect(Rect2(-WIDTH * 0.5, 0, WIDTH, _len), Color(0.25, 0.95, 0.5, 0.5))
	draw_rect(Rect2(-WIDTH * 0.18, 0, WIDTH * 0.36, _len), Color(0.7, 1.0, 0.85, 0.75))
