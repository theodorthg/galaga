extends Area2D

## A formation enemy.
##   FLYING_IN        — rides the shared group entry curve, then tweens into its slot
##   IN_FORMATION     — tracks slot_global(idx) every frame, wings flapping
##   DIVING           — peeled off, sweeping down at the player, dropping bombs
##   RETURNING        — off the bottom, curving back in from the top to its slot
##   LOCKING          — transient tween into the slot (from FLYING_IN or RETURNING)
##   CAPTURE_APPROACH — Boss only: actively homes toward the player's CURRENT
##                      x position while descending to a fixed hover height —
##                      not a pre-baked curve to a one-time snapshot position
##                      (see capture_dive()). The player doesn't have to fly
##                      into the beam and can't simply out-position it: the
##                      Boss keeps re-aiming every frame until it's overhead.
##   CAPTURE_BEAM     — Boss only: still homes on the player's x (see
##                      _track_player_x()) while the tractor beam — now a
##                      CHILD of the Boss, so it moves with it for free —
##                      extends; catches the ship -> carries a captive sprite
##                      home, which a later kill of THIS boss releases
##                      (ship_rescued)

enum { FLYING_IN, LOCKING, IN_FORMATION, DIVING, RETURNING, CAPTURE_APPROACH, CAPTURE_BEAM }

const FLY_SPEED := 480.0
const DIVE_SPEED := 300.0
const RETURN_SPEED := 360.0
const LOCK_TIME := 0.4
const BOMB_SCENE := preload("res://bomb.tscn")
const CAPTURE_BEAM_SCENE := preload("res://capture_beam.tscn")
const CAPTIVE_TEXTURE := preload("res://assets/graphics/ship_captured.png")
const CAPTURE_BEAM_TOTAL := 0.95  # keep in sync with capture_beam.gd (grow+hold+shrink)
## See ship.gd::DESIGN_WIDTH — dive()/return_to() curves are generated in
## terms of a Vector2(width, height) "canvas"; width must stay the fixed
## playable-lane width, not the actual (possibly wider, landscape-cabinet-
## overlay) viewport, or dives would sweep out into the cabinet-art margins.
const DESIGN_WIDTH := 540.0

var kind := EnemyKinds.ZAKO
## Which of EnemyKinds' several stage-variant sprites this particular enemy is
## wearing (-1 = the classic stage-1 look, see EnemyKinds.pick_visual()) — set
## in setup(), read by _explode() for the run-summary's per-sprite kill
## breakdown (game.gd).
var _variant_idx := -1
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
var _captive_glow_tween: Tween

var _resolved := false

@onready var _col: CollisionShape2D = $CollisionShape2D
@onready var _sprite: Sprite2D = $Sprite2D
var _flap_tween: Tween
var _flap_frames: Array = []  # 2 texture paths for a real flap (EnemyKinds variants); empty -> wobble

signal locked_in(enemy)
signal killed(points, kind, variant_idx, was_carrying_captive)
signal resolved
signal ship_rescued(at_position: Vector2)

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
	_variant_idx = int(vis.get("variant_idx", -1))

	_formation.flap_toggled.connect(_on_flap)
	_start_path(p_curve, FLY_SPEED, _begin_lock)
	global_position = p_curve.sample_baked(0.0)
	visible = false
	set_physics_process(false)

	if start_delay > 0.0:
		await get_tree().create_timer(start_delay, false).timeout
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
	var vp := Vector2(DESIGN_WIDTH, get_viewport_rect().size.y)
	var player := get_tree().get_first_node_in_group("player")
	var ppos: Vector2 = player.global_position if player else Vector2(vp.x * 0.5, vp.y * 0.82)
	_start_path(AttackPaths.dive(global_position, ppos, vp), DIVE_SPEED, _begin_return)

# Boss-only tractor-beam attempt — see the CAPTURE_* states above. Homing
# instead of a pre-baked curve (see _home_toward_player()), so the outcome
# doesn't depend on a stale snapshot of where the player happened to be the
# instant this started.
const CAPTURE_HOVER_Y_FRAC := 0.58
const CAPTURE_HOMING_SPEED := 640.0  # faster than the ship's own 480 px/s move
									  # speed, so it always eventually closes
									  # the horizontal gap — "kann nicht
									  # entkommen" per the user's request.

func capture_dive() -> void:
	if _state != IN_FORMATION or kind != EnemyKinds.BOSS:
		return
	_formation.release(self)
	_state = CAPTURE_APPROACH
	_set_player_capture_invuln(true)
	# No "dive" sound here (user report 2026-09-15: heard it play right before
	# a Boss capture) — this is a capture approach, not a plain dive, and it
	# already has its own dedicated cue ("beam-sound", played once the beam
	# actually catches the ship — see _begin_capture_beam() below). Playing
	# "dive" on top of that read as two overlapping, conflicting sounds for
	# one event.

## See ship.gd::set_capture_invulnerable() for why the whole attempt (not just
## the beam itself) needs to make the ship immune to any OTHER source of death.
func _set_player_capture_invuln(on: bool) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.set_capture_invulnerable(on)

func _home_toward_player(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	var vp := get_viewport_rect().size
	var target_x: float = player.global_position.x if player else global_position.x
	var target_y: float = vp.y * CAPTURE_HOVER_Y_FRAC
	global_position.x = move_toward(global_position.x, target_x, CAPTURE_HOMING_SPEED * delta)
	global_position.y = move_toward(global_position.y, target_y, DIVE_SPEED * delta)
	if is_equal_approx(global_position.y, target_y):
		_begin_capture_beam()

## Keeps the Boss (and with it the beam, its child — see _begin_capture_beam())
## tracking the player horizontally for as long as the beam is live, so a
## sideways dodge during the grow/hold window doesn't let the player slip out
## from under it.
func _track_player_x(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		global_position.x = move_toward(global_position.x, player.global_position.x, CAPTURE_HOMING_SPEED * delta)

func _begin_capture_beam() -> void:
	_state = CAPTURE_BEAM
	rotation = 0.0
	var beam := CAPTURE_BEAM_SCENE.instantiate()
	add_child(beam)  # child of the Boss, not a scene-tree sibling — it now
					  # tracks the Boss's own position for free as _track_player_x()
					  # keeps adjusting it, no manual position sync needed.
	beam.position = Vector2.ZERO
	# Flag the catch (and attach the visual) the instant it happens, not after
	# the beam's hold/shrink finishes — a bullet already in flight can still
	# blow up this boss during that tail end, and _explode() only grants the
	# twin-ship reward if _carrying_captive is already true by then.
	beam.caught.connect(func():
		_carrying_captive = true
		_spawn_captive_visual()
		if _snd:
			_snd.play("beam-sound"))
	await get_tree().create_timer(CAPTURE_BEAM_TOTAL, false).timeout
	if not is_instance_valid(self):
		return
	_set_player_capture_invuln(false)
	_begin_return()

## Smaller than the player's own Sprite2D scale (0.11) and closer to the Boss
## than a straight 1:1 match would put it — at full ship size + the original
## 30px offset, it hung low enough to visually overlap the formation row
## right below the Boss row (see formation.gd's BOSS_ROW_Y_NUDGE for the other
## half of that fix). Reads fine as "small captured passenger", not "same
## size as its carrier".
const CAPTIVE_SCALE := 0.085
const CAPTIVE_OFFSET_Y := 22.0

func _spawn_captive_visual() -> void:
	_captive_visual = Sprite2D.new()
	_captive_visual.texture = CAPTIVE_TEXTURE
	_captive_visual.scale = Vector2.ONE * CAPTIVE_SCALE
	_captive_visual.position = Vector2(0, CAPTIVE_OFFSET_Y)
	add_child(_captive_visual)
	# Every Boss at a given stage looks identical (from stage 2+ they all share
	# the same reskin) — without an obvious marker, "shoot the one that's
	# carrying your ship" is nearly impossible to act on in the middle of a
	# fight. A looping colour pulse makes this specific Boss unmistakable.
	_captive_glow_tween = create_tween()
	_captive_glow_tween.set_loops()
	_captive_glow_tween.tween_property(_sprite, "modulate", Color(1.0, 1.0, 0.35), 0.35)
	_captive_glow_tween.tween_property(_sprite, "modulate", Color.WHITE, 0.35)

func _begin_return() -> void:
	_state = RETURNING
	var vp := Vector2(DESIGN_WIDTH, get_viewport_rect().size.y)
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
		CAPTURE_APPROACH:
			_home_toward_player(delta)
		CAPTURE_BEAM:
			_track_player_x(delta)
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

## Two unrelated reasons an enemy can't be hit right now:
##  - Boss mid-capture (see the CAPTURE_* states above) — a hit is absorbed
##    with no effect so the Boss can't die mid-capture off a shot already in
##    flight, which would hide that the tractor beam had caught the player.
##    Vulnerable again once it settles back into formation (IN_FORMATION).
##  - The BOTTOM_UP fly-in entry (entry_paths.gd) spawns enemies from BELOW
##    the screen and flies them up past the player before they loop into
##    formation — while still level with or below the ship's own gun,
##    "shooting" them makes no physical sense (the beam fires upward from the
##    ship). The margin is a full enemy height (diameter) above the actual
##    MUZZLE point (ship.gd::GUN_MUZZLE_OFFSET_Y, 22px above the ship's own
##    body origin — comparing against the body origin instead measured the
##    margin from the wrong point and still let enemies get shot right next
##    to the muzzle), so the enemy has visibly cleared the barrel before it
##    counts as "above" it. Only applies during FLYING_IN; TOP_LEFT/TOP_RIGHT
##    entries never start below the ship, so this is a no-op for them.
func _is_invulnerable() -> bool:
	if _state == CAPTURE_APPROACH or _state == CAPTURE_BEAM \
		or (_state == RETURNING and _carrying_captive):
		return true
	if _state == FLYING_IN:
		var player := get_tree().get_first_node_in_group("player")
		if player:
			var enemy_height: float = float(EnemyKinds.DATA[kind]["half"]) * 2.0
			var gun_y: float = player.global_position.y + player.GUN_MUZZLE_OFFSET_Y
			if global_position.y > gun_y - enemy_height:
				return true
	return false

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_lasers"):
		area.queue_free()
		if _is_invulnerable():
			return
		_explode()

func _explode() -> void:
	if _state == LOCKING:
		return
	# Captured BEFORE _state flips to LOCKING below — the sound-selection
	# check further down needs to know whether this kill happened mid-attack,
	# and "was this enemy DIVING/RETURNING the instant it died" is exactly
	# what _state stops telling you one line later (real bug caught live
	# during testing: reading _state after the LOCKING assignment always fell
	# through to the "else" branch, since LOCKING is neither DIVING nor
	# RETURNING).
	var was_diving := _state == DIVING or _state == RETURNING
	set_physics_process(false)
	_state = LOCKING  # inert
	if _formation:
		_formation.release(self)
	# _carrying_captive is read here BEFORE the block below clears it, so a
	# rescue-kill still reports was_carrying_captive=true to the summary
	# breakdown (game.gd) — it's a separate bucket there, not lumped in with
	# plain Boss kills.
	killed.emit(int(EnemyKinds.DATA[kind]["points"]), kind, _variant_idx, _carrying_captive)
	if _snd:
		# Three distinct kill sounds (2026-09-13, replacing the one generic
		# "hit"): ANY Boss kill gets its own fanfare — originally only the
		# carrying-a-captive case, widened same-day per user request to every
		# Boss kill regardless of whether it was carrying anyone — otherwise a
		# plain in-formation kill vs. one caught mid-attack (DIVING/RETURNING)
		# get different sounds, the user specifically wanted a diving kill to
		# sound distinct.
		if kind == EnemyKinds.BOSS:
			_snd.play("boss-killed")
		elif was_diving:
			_snd.play("enemy-death2")
		else:
			_snd.play("enemy-death1")
	if _carrying_captive:
		_carrying_captive = false
		if _captive_glow_tween:
			_captive_glow_tween.kill()
		if is_instance_valid(_captive_visual):
			_captive_visual.queue_free()
		ship_rescued.emit(global_position)
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
