extends Area2D

## One enemy in a Bonus Level chain (see game.gd::_start_bonus_level()) — flies
## straight down a single shared vertical track from just above the screen to
## just below it, then frees itself. A wave's members are launched one after
## another with a short delay (game.gd's BONUS_LAUNCH_GAP), not spawned all at
## once, so they queue up nose-to-tail on the SAME line instead of moving as a
## rigid offset block — game.gd waits for the "bonus_wave_active" group below
## to empty as its "wave cleared" signal, rather than tracking a per-wave
## counter (see the comment in game.gd::_run_bonus_wave() for why a counter
## driven by a signal-connected lambda was the actual bug behind "the game
## never notices a cleared wave").
## Deliberately NOT in the "enemy" group: ship.gd's own collision handler only
## reacts to that group, so a Bonus Level is pure shooting-gallery scoring —
## no dive, no bomb, no way to lose a life, matching the classic arcade
## "challenging stage" this is modeled on.

signal killed(points: int)

const DEFAULT_SPEED := 260.0

var kind := EnemyKinds.ZAKO
var speed := DEFAULT_SPEED
var _path: Curve2D
var _path_dist := 0.0
var _dead := false  # guards against a double kill (see _explode() below)

@onready var _col: CollisionShape2D = $CollisionShape2D
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _snd: Node = get_node_or_null("/root/Snd")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# Shared with bonus_item.gd/etc. purely so game.gd::_clear_board() can sweep
	# this away too if the player quits to the title screen mid-wave.
	add_to_group("bonus_transient")
	# game.gd polls this group emptying out as its "wave cleared" signal —
	# queue_free() (below, on kill or reaching the bottom of the path) drops
	# group membership automatically, so no explicit "I'm done" signal/counter
	# is needed at all.
	add_to_group("bonus_wave_active")
	area_entered.connect(_on_area_entered)

## p_speed lets game.gd vary pace per wave/member (2026-09-14 user request:
## "etwas Challenge" — a Bonus Level felt too uniform/predictable at one flat
## speed) — defaults to DEFAULT_SPEED so nothing else calling setup() breaks.
func setup(p_kind: int, curve: Curve2D, texture_path: String, tex_scale: float, p_speed := DEFAULT_SPEED) -> void:
	kind = p_kind
	_path = curve
	speed = p_speed
	var circ := CircleShape2D.new()
	circ.radius = float(EnemyKinds.DATA[kind]["half"])
	_col.shape = circ
	_sprite.texture = load(texture_path)
	_sprite.scale = Vector2.ONE * tex_scale
	global_position = curve.sample_baked(0.0)

func _physics_process(delta: float) -> void:
	var length := _path.get_baked_length()
	_path_dist += speed * delta
	var d: float = min(_path_dist, length)
	var pos := _path.sample_baked(d)
	var ahead := _path.sample_baked(min(d + 8.0, length))
	global_position = pos
	if ahead != pos:
		rotation = (ahead - pos).angle() - PI / 2.0
	if _path_dist >= length:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_lasers"):
		area.queue_free()
		_explode()

func _explode() -> void:
	# Two lasers (e.g. Hyper-Ammo's twin beams, 14px apart — easily both inside
	# this enemy's hitbox at once) can each trigger _on_area_entered() in the
	# same physics frame, before set_physics_process(false) below has any
	# chance to matter — without this guard that meant a DOUBLE (sometimes
	# triple) killed.emit() per enemy, which is exactly how the end-of-level
	# tally could read "23/18" despite shooting down all 18 and nothing more
	# (user report). enemy.gd has the same class of guard (`if _state ==
	# LOCKING: return`) for the same reason.
	if _dead:
		return
	_dead = true
	set_physics_process(false)
	killed.emit(int(EnemyKinds.DATA[kind]["points"]))
	if _snd:
		_snd.play("enemy-death1")
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "scale", scale * 1.9, 0.16)
	t.tween_property(self, "modulate:a", 0.0, 0.16)
	await t.finished
	queue_free()
