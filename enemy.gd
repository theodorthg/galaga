extends Area2D

## A formation enemy.
##   FLYING_IN        — rides the shared group entry curve, then tweens into its slot
##   IN_FORMATION     — tracks slot_global(idx) every frame, wings flapping
##   DIVING           — peeled off, sweeping down at the player, dropping bombs
##   RETURNING        — off the bottom, curving back in from the top to its slot
##   LOCKING          — transient tween into the slot (from FLYING_IN or RETURNING)
##   CAPTURE_APPROACH — Boss only: peels out and hovers above the player instead
##                      of sweeping through (see capture_dive())
##   CAPTURE_BEAM     — Boss only: holds position while the tractor beam extends;
##                      catches the ship -> carries a captive sprite home, which
##                      a later kill of THIS boss releases (ship_rescued)

enum { FLYING_IN, LOCKING, IN_FORMATION, DIVING, RETURNING, CAPTURE_APPROACH, CAPTURE_BEAM }

const FLY_SPEED := 480.0
const DIVE_SPEED := 300.0
const RETURN_SPEED := 360.0
const LOCK_TIME := 0.4
const BOMB_SCENE := preload("res://bomb.tscn")
const CAPTURE_BEAM_SCENE := preload("res://capture_beam.tscn")
const CAPTIVE_TEXTURE := preload("res://assets/graphics/ship_captured.png")
const CAPTURE_BEAM_TOTAL := 0.95  # keep in sync with capture_beam.gd (grow+hold+shrink)

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

var _carrying_captive := false
var _captive_visual: Sprite2D = null
var _captured_ship_this_beam := false

var _resolved := false

@onready var _col: CollisionShape2D = $CollisionShape2D
@onready var _sprite: Sprite2D = $Sprite2D
var _flap_tween: Tween
var _flap_frames: Array = []  # 2 texture paths for a real flap (EnemyKinds variants); empty -> wobble

signal locked_in(enemy)
signal killed(points)
signal resolved
signal ship_rescued

func setup(p_kind: int, p_formation: Formation, p_slot: int, p_curve: Curve2D, start_delay: float, p_stage: int = 1) -> void:
	kind = p_kind
	_formation = p_formation
	_slot = p_slot

	var circ := CircleShape2D.new()
	circ.radius = float(EnemyKinds.DATA[kind]["half"])
	_col.shape = circ

	var vis := EnemyKinds.pick_visual(kind, p_stage)
	_flap_frames = vis.get("frames", [])
	_sprite.texture = load(_flap_frames[0] if _flap_frames.size() == 2 else vis["texture"])
	_sprite.scale = Vector2.ONE * float(vis["scale"])

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
	process_mode = Node.PROCESS_MODE_PAUSABLE  # freeze on pause, not inherit Game's ALWAYS
	add_to_group("enemy")
	area_entered.connect(_on_area_entered)
	tree_exiting.connect(_finish)

# --- dive lifecycle, driven by StageDirector ------------------------------
func is_available_to_dive() -> bool:
	return _state == IN_FORMATION

func is_active_diver() -> bool:
	return _state == DIVING or _state == RETURNING or _state == CAPTURE_APPROACH or _state == CAPTURE_BEAM

func is_carrying_captive() -> bool:
	return _carrying_captive

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

# Boss-only tractor-beam attempt — see the CAPTURE_* states above.
func capture_dive() -> void:
	if _state != IN_FORMATION or kind != EnemyKinds.BOSS:
		return
	_formation.release(self)
	_state = CAPTURE_APPROACH
	if _snd:
		_snd.play("dive")
	var vp := get_viewport_rect().size
	var player := get_tree().get_first_node_in_group("player")
	var ppos: Vector2 = player.global_position if player else Vector2(vp.x * 0.5, vp.y * 0.82)
	_start_path(AttackPaths.capture_approach(global_position, ppos, vp), DIVE_SPEED, _begin_capture_beam)

func _begin_capture_beam() -> void:
	_state = CAPTURE_BEAM
	rotation = 0.0
	_captured_ship_this_beam = false
	var beam := CAPTURE_BEAM_SCENE.instantiate()
	get_parent().add_child(beam)
	beam.global_position = global_position
	beam.caught.connect(func(): _captured_ship_this_beam = true)
	await get_tree().create_timer(CAPTURE_BEAM_TOTAL).timeout
	if not is_instance_valid(self):
		return
	if _captured_ship_this_beam:
		_carrying_captive = true
		_spawn_captive_visual()
	_begin_return()

func _spawn_captive_visual() -> void:
	_captive_visual = Sprite2D.new()
	_captive_visual.texture = CAPTIVE_TEXTURE
	_captive_visual.scale = Vector2.ONE * 0.11  # matches player Sprite2D in ship.tscn
	_captive_visual.position = Vector2(0, 30)
	add_child(_captive_visual)

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
		FLYING_IN, DIVING, RETURNING, CAPTURE_APPROACH:
			_follow_path(delta)
		IN_FORMATION:
			global_position = _formation.slot_global(_slot)
		# CAPTURE_BEAM: holds still where the approach path left it.
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
	if _carrying_captive:
		_carrying_captive = false
		if is_instance_valid(_captive_visual):
			_captive_visual.queue_free()
		ship_rescued.emit()
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

func _on_flap(state_in: bool) -> void:
	if _state != IN_FORMATION and not is_active_diver():
		return
	_animate_flap(state_in)

# ---------------------------------------------------------------------------
#  Two flap looks, picked in setup() via EnemyKinds.pick_visual():
#  - Gyaraga variants (stage 2+ GOEI/ZAKO) ship a real 2nd drawn frame —
#    just swap the texture, no transform trickery needed.
#  - The classic single-frame sprites fake it with a transform wobble: a
#    quick skew + vertical squash pulse in sync with Formation's shared
#    0.28s flap cadence — every enemy flutters on the same beat, same as the
#    old 2-frame placeholder did before real art existed.
# ---------------------------------------------------------------------------
func _animate_flap(up: bool) -> void:
	if _flap_frames.size() == 2:
		_sprite.texture = load(_flap_frames[1] if up else _flap_frames[0])
		return
	if _flap_tween:
		_flap_tween.kill()
	var base_scale: float = _sprite.scale.x
	var skew_to := (0.16 if up else -0.16)
	var squash_to := base_scale * (0.88 if up else 1.0)
	_flap_tween = create_tween()
	_flap_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_flap_tween.set_parallel(true)
	_flap_tween.tween_property(_sprite, "skew", skew_to, 0.12)
	_flap_tween.tween_property(_sprite, "scale:y", squash_to, 0.12)
