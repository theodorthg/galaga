extends Area2D

## A formation enemy.
##   FLYING_IN  — rides the shared group entry curve, then tweens into its slot
##   IN_FORMATION — tracks slot_global(idx) every frame, wings flapping
##   DIVING     — peeled off, sweeping down at the player, dropping bombs
##   RETURNING  — off the bottom, curving back in from the top to its slot
##   LOCKING    — transient tween into the slot (from FLYING_IN or RETURNING)

enum { FLYING_IN, LOCKING, IN_FORMATION, DIVING, RETURNING }

const FLY_SPEED := 480.0
const DIVE_SPEED := 300.0
const RETURN_SPEED := 360.0
const LOCK_TIME := 0.4
const BOMB_SCENE := preload("res://bomb.tscn")

var kind := EnemyKinds.ZAKO
var _state := FLYING_IN
var _formation: Formation
var _slot := -1

var _path: Curve2D
var _path_dist := 0.0
var _path_speed := FLY_SPEED
var _after_path := Callable()

var _bombs_left := 0
var _bomb_t := 0.0

var _resolved := false

@onready var _col: CollisionShape2D = $CollisionShape2D

signal locked_in(enemy)
signal killed(points)
signal resolved

func setup(p_kind: int, p_formation: Formation, p_slot: int, p_curve: Curve2D, start_delay: float) -> void:
	kind = p_kind
	_formation = p_formation
	_slot = p_slot

	var circ := CircleShape2D.new()
	circ.radius = float(EnemyKinds.DATA[kind]["half"])
	_col.shape = circ

	_formation.flap_toggled.connect(_on_flap)
	_start_path(p_curve, FLY_SPEED, _begin_lock)
	global_position = p_curve.sample_baked(0.0)
	visible = false
	set_physics_process(false)

	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	if not is_instance_valid(self):
		return
	visible = true
	set_physics_process(true)

@onready var _snd: Node = get_node_or_null("/root/Snd")

func _ready() -> void:
	add_to_group("enemy")
	area_entered.connect(_on_area_entered)
	tree_exiting.connect(_finish)

# --- dive lifecycle, driven by StageDirector ------------------------------
func is_available_to_dive() -> bool:
	return _state == IN_FORMATION

func is_active_diver() -> bool:
	return _state == DIVING or _state == RETURNING

func dive() -> void:
	if _state != IN_FORMATION:
		return
	_formation.release(self)
	_state = DIVING
	_bombs_left = 2
	_bomb_t = 0.55
	if _snd:
		_snd.play("dive")
	var vp := get_viewport_rect().size
	var player := get_tree().get_first_node_in_group("player")
	var ppos: Vector2 = player.global_position if player else Vector2(vp.x * 0.5, vp.y * 0.82)
	_start_path(AttackPaths.dive(global_position, ppos, vp), DIVE_SPEED, _begin_return)

func _begin_return() -> void:
	_state = RETURNING
	var vp := get_viewport_rect().size
	_start_path(AttackPaths.return_to(_formation.slot_global(_slot), vp), RETURN_SPEED, _begin_lock)

# --- generic path follower ----------------------------------------------
func _start_path(curve: Curve2D, speed: float, done: Callable) -> void:
	_path = curve
	_path_dist = 0.0
	_path_speed = speed
	_after_path = done

func _physics_process(delta: float) -> void:
	match _state:
		FLYING_IN, DIVING, RETURNING:
			_follow_path(delta)
		IN_FORMATION:
			global_position = _formation.slot_global(_slot)
	if _state == DIVING:
		_maybe_bomb(delta)

func _follow_path(delta: float) -> void:
	var length := _path.get_baked_length()
	_path_dist += _path_speed * delta
	var d: float = min(_path_dist, length)
	var pos := _path.sample_baked(d)
	var ahead := _path.sample_baked(min(d + 8.0, length))
	global_position = pos
	if ahead != pos:
		rotation = (ahead - pos).angle() - PI / 2.0
	queue_redraw()
	if _path_dist >= length:
		_after_path.call()

func _maybe_bomb(delta: float) -> void:
	if _bombs_left <= 0:
		return
	_bomb_t -= delta
	if _bomb_t <= 0.0:
		_bomb_t = randf_range(0.35, 0.7)
		_bombs_left -= 1
		var b := BOMB_SCENE.instantiate()
		get_parent().add_child(b)
		b.global_position = global_position + Vector2(0, 12)

func _begin_lock() -> void:
	_state = LOCKING
	var target := _formation.slot_global(_slot)
	var t := create_tween()
	t.set_parallel(true)
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "global_position", target, LOCK_TIME)
	t.tween_property(self, "rotation", 0.0, LOCK_TIME)
	await t.finished
	if not is_instance_valid(self):
		return
	_state = IN_FORMATION
	_formation.assign(_slot, self)
	locked_in.emit(self)
	_finish()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_lasers"):
		area.queue_free()
		_explode()

func _explode() -> void:
	if _state == LOCKING:
		return
	set_physics_process(false)
	_state = LOCKING  # inert
	if _formation:
		_formation.release(self)
	killed.emit(int(EnemyKinds.DATA[kind]["points"]))
	if _snd:
		_snd.play("hit")
	_finish()
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2(1.9, 1.9), 0.16)
	t.tween_property(self, "modulate:a", 0.0, 0.16)
	await t.finished
	queue_free()

func _finish() -> void:
	if _resolved:
		return
	_resolved = true
	resolved.emit()

func _on_flap(_state_in: bool) -> void:
	if _state == IN_FORMATION:
		queue_redraw()

# ---------------------------------------------------------------------------
#  Placeholder art — procedural, 2-frame wing flap driven by Formation.flap.
#  Drawn nose-down (+y), matching a formation enemy facing the player.
# ---------------------------------------------------------------------------
func _draw() -> void:
	var up: bool = _formation != null and _formation.flap
	match kind:
		EnemyKinds.ZAKO:
			_draw_zako(up)
		EnemyKinds.GOEI:
			_draw_goei(up)
		EnemyKinds.BOSS:
			_draw_boss(up)

func _poly(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)

func _draw_zako(up: bool) -> void:
	var body := Color("4db2ff")
	var wing := Color("ffe14d")
	var wy := -6.0 if up else 4.0
	_poly([Vector2(-4, -2), Vector2(-15, wy), Vector2(-13, wy + 8), Vector2(-3, 4)], wing)
	_poly([Vector2(4, -2), Vector2(15, wy), Vector2(13, wy + 8), Vector2(3, 4)], wing)
	_poly([Vector2(0, -13), Vector2(6, 0), Vector2(0, 11), Vector2(-6, 0)], body)
	draw_circle(Vector2(0, -2), 2.2, Color.WHITE)

func _draw_goei(up: bool) -> void:
	var body := Color("ff5a5a")
	var wing := Color("ffd7d7")
	var wy := -8.0 if up else 2.0
	_poly([Vector2(-3, -4), Vector2(-16, wy), Vector2(-15, wy + 12), Vector2(-2, 6)], wing)
	_poly([Vector2(3, -4), Vector2(16, wy), Vector2(15, wy + 12), Vector2(2, 6)], wing)
	_poly([Vector2(0, -15), Vector2(5, -3), Vector2(0, 2), Vector2(-5, -3)], body)
	_poly([Vector2(0, 13), Vector2(6, 1), Vector2(0, -2), Vector2(-6, 1)], body)

func _draw_boss(up: bool) -> void:
	var top := Color("46c46e")
	var bot := Color("3aa0ff")
	var wy := -7.0 if up else 3.0
	_poly([Vector2(-5, -2), Vector2(-18, wy), Vector2(-16, wy + 11), Vector2(-4, 7)], bot)
	_poly([Vector2(5, -2), Vector2(18, wy), Vector2(16, wy + 11), Vector2(4, 7)], bot)
	draw_line(Vector2(-5, -10), Vector2(-9, -20), top, 3.0)
	draw_line(Vector2(5, -10), Vector2(9, -20), top, 3.0)
	_poly([Vector2(0, -14), Vector2(11, -2), Vector2(9, 6), Vector2(-9, 6), Vector2(-11, -2)], top)
	_poly([Vector2(-9, 6), Vector2(9, 6), Vector2(5, 14), Vector2(-5, 14)], bot)
	draw_circle(Vector2(-3.5, 0), 1.8, Color.WHITE)
	draw_circle(Vector2(3.5, 0), 1.8, Color.WHITE)
