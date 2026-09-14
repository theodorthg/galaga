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

const SPEED := 260.0

var kind := EnemyKinds.ZAKO
var _path: Curve2D
var _path_dist := 0.0

@onready var _col: CollisionShape2D = $CollisionShape2D
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _snd: Node = get_node_or_null("/root/Snd")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# Shared with ship_warp.gd purely so game.gd::_clear_board() can sweep this
	# away too if the player quits to the title screen mid-transition.
	add_to_group("bonus_transient")
	# game.gd polls this group emptying out as its "wave cleared" signal —
	# queue_free() (below, on kill or reaching the bottom of the path) drops
	# group membership automatically, so no explicit "I'm done" signal/counter
	# is needed at all.
	add_to_group("bonus_wave_active")
	area_entered.connect(_on_area_entered)

func setup(p_kind: int, curve: Curve2D, texture_path: String, tex_scale: float) -> void:
	kind = p_kind
	_path = curve
	var circ := CircleShape2D.new()
	circ.radius = float(EnemyKinds.DATA[kind]["half"])
	_col.shape = circ
	_sprite.texture = load(texture_path)
	_sprite.scale = Vector2.ONE * tex_scale
	global_position = curve.sample_baked(0.0)

func _physics_process(delta: float) -> void:
	var length := _path.get_baked_length()
	_path_dist += SPEED * delta
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
