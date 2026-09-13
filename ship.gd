extends Area2D

## Player fighter.
##   Keyboard / pad : move_left/move_right axis, hold shoot action to fire
##   Mouse          : ship follows cursor x, hold left-click to fire
##   Touch          : drag anywhere to steer (relative), auto-fire while alive
## All three fire continuously (capped at MAX_LASERS in flight) rather than one
## shot per press — holding the button keeps the queue topped up exactly like
## touch's auto-fire, so a held position mows down a column the same way on
## every input method.
## Destroyed by a diving enemy or a bomb; Game handles lives / respawn.

const LASER_SCENE := preload("res://laser.tscn")
const RESPAWN_INVULN := 1.6
const TWIN_OFFSET := 34.0
const SINGLE_HALF_WIDTH := 34.0
## Two beams close together instead of one, while Hyper-Ammo is active (see
## activate_hyper_ammo()) — much narrower than TWIN_OFFSET, which represents a
## whole second ship rather than a tighter spread from the same gun.
const HYPER_OFFSET := 10.0
## The main thruster's flame can reach up to its own max_length below the ship
## at full power (plus the GPU particle trail) — far enough to dip into the
## HUD's bottom-center bonus-icon row (hud.gd) on a tall/thin canvas. Shifting
## the resting position up by that length + a small safety margin keeps the
## flame clear of it regardless of how main_thruster.tscn's max_length is tuned.
const THRUSTER_CLEARANCE_MARGIN := 5.0
## Vertical offset from the ship's own origin to its actual laser muzzle (see
## _fire_laser() below). enemy.gd reads this too, so its "invulnerable until
## above the gun" check (BOTTOM_UP fly-in) measures from the real muzzle
## point instead of the ship's body origin, which sits 22px lower.
const GUN_MUZZLE_OFFSET_Y := -22.0
## Minimum time between shots, regardless of slot capacity — without this, a
## twin-ship + high-max_shots combo could re-fill its laser slots as fast as
## they left the muzzle (limited only by travel time to a hit), clearing a
## whole stage in a few seconds. Independent of _max_lasers/_twin so it caps
## every fire-rate combo the same way.
const FIRE_COOLDOWN := 0.15

var speed := 480.0
var ship_half_width := 34.0
var viewport_width := 0.0

var _alive := true
var _invuln := 0.0
var _mouse_aim := false
var _mouse_down := false
var _touch := false
var _snd: Node
var _max_lasers_base := 2  # set from GameSettings.max_shots via configure()
var _max_lasers := _max_lasers_base
var _hyper_ammo := false
var _fire_cooldown_t := 0.0

var _twin := false
var _sprite2: Sprite2D
var _thruster2: Line2D

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _thruster: Line2D = $MainThruster

signal died

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE  # freeze on pause, not inherit Game's ALWAYS
	add_to_group("player")
	add_to_group("touch_layout_listeners")
	_touch = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	_snd = get_node_or_null("/root/Snd")
	area_entered.connect(_on_area_entered)
	viewport_width = get_viewport_rect().size.x
	position.y -= _thruster.max_length + THRUSTER_CLEARANCE_MARGIN

# group "touch_layout_listeners": first real touch event flips us to touch mode
func apply_touch_layout() -> void:
	_touch = true

func _process(delta: float) -> void:
	if _invuln > 0.0:
		_invuln -= delta
		modulate.a = 0.35 + 0.4 * (0.5 + 0.5 * sin(_invuln * 32.0))
		if _invuln <= 0.0:
			modulate.a = 1.0

	if _fire_cooldown_t > 0.0:
		_fire_cooldown_t -= delta

	if not _alive:
		return

	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		_mouse_aim = false
		position.x += dir * speed * delta
	elif _mouse_aim:
		# Direct 1:1 tracking, not move_toward — the mouse can jump arbitrarily
		# fast, so chasing it at the keyboard's speed cap made the ship visibly
		# lag behind on a quick swipe; snapping feels immediate like the
		# original arcade's paddle-style control.
		position.x = get_global_mouse_position().x
	position.x = clampf(position.x, ship_half_width, viewport_width - ship_half_width)

	if _touch or _mouse_down or Input.is_action_pressed("shoot"):
		shoot()

func _unhandled_input(event: InputEvent) -> void:
	if not _alive:
		return
	if event is InputEventMouseMotion:
		_mouse_aim = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_down = event.pressed
	elif event is InputEventScreenDrag:
		position.x = clampf(position.x + event.relative.x,
			ship_half_width, viewport_width - ship_half_width)

func shoot() -> void:
	if _fire_cooldown_t > 0.0:
		return
	if get_tree().get_nodes_in_group("player_lasers").size() >= _max_lasers:
		return
	_fire_cooldown_t = FIRE_COOLDOWN
	for gun_x in ([-TWIN_OFFSET, TWIN_OFFSET] if _twin else [0.0]):
		if _hyper_ammo:
			_fire_laser(gun_x - HYPER_OFFSET * 0.5)
			_fire_laser(gun_x + HYPER_OFFSET * 0.5)
		else:
			_fire_laser(gun_x)

func _fire_laser(x_offset: float) -> void:
	var laser := LASER_SCENE.instantiate()
	laser.add_to_group("player_lasers")
	laser.accent_color = Laser.ACCENT_HYPER if _hyper_ammo else Laser.ACCENT_NORMAL
	get_parent().add_child(laser)
	laser.global_position = global_position + Vector2(x_offset, GUN_MUZZLE_OFFSET_Y)
	if _snd:
		_snd.play("shoot")

func _on_area_entered(area: Area2D) -> void:
	if not _alive or _invuln > 0.0:
		return
	if area.is_in_group("enemy_shots"):
		area.queue_free()
		_destroy()
	elif area.is_in_group("enemy") and area.is_active_diver():
		_destroy()

func _destroy() -> void:
	_alive = false
	visible = false
	set_deferred("monitoring", false)
	_revert_twin()  # twin bonus doesn't survive a hit, matches the arcade original
	if _snd:
		_snd.play("player_boom")
	died.emit()

func respawn() -> void:
	position.x = viewport_width * 0.5
	_alive = true
	visible = true
	_invuln = RESPAWN_INVULN
	set_deferred("monitoring", true)

## Applies GameSettings.max_shots — called on every new run and again whenever
## settings change mid-game (game.gd's _reload_settings()), so raising/lowering
## it in the pause menu takes effect immediately instead of waiting for a
## fresh run.
func configure(max_shots: int) -> void:
	_max_lasers_base = max_shots
	_max_lasers = _max_lasers_base * 2 if _twin else _max_lasers_base

## Rewarded when the Boss carrying a previously-captured ship is destroyed —
## a second fighter joins in, doubling fire, until the next hit.
func become_twin() -> void:
	if _twin or not _alive:
		return
	_twin = true
	ship_half_width = SINGLE_HALF_WIDTH + TWIN_OFFSET
	_max_lasers = _max_lasers_base * 2
	_sprite.position.x = -TWIN_OFFSET
	_thruster.position.x = -TWIN_OFFSET
	_sprite2 = _sprite.duplicate()
	_sprite2.position.x = TWIN_OFFSET
	add_child(_sprite2)
	_thruster2 = _thruster.duplicate()
	_thruster2.position.x = TWIN_OFFSET
	add_child(_thruster2)

## Rewarded for collecting the achievement_00 bonus item specifically (see
## game.gd's _on_bonus_collected) — two closely-spaced beams per shot instead
## of one, in a distinct white-red flash so it reads as a different power-up
## from the normal white-turquoise laser. Lasts for the rest of the current
## stage (game.gd clears it on every stage change), independent of the
## twin-ship reward — stacks with it if both are active.
func activate_hyper_ammo() -> void:
	_hyper_ammo = true

func deactivate_hyper_ammo() -> void:
	_hyper_ammo = false

func _revert_twin() -> void:
	if not _twin:
		return
	_twin = false
	ship_half_width = SINGLE_HALF_WIDTH
	_max_lasers = _max_lasers_base
	_sprite.position.x = 0.0
	_thruster.position.x = 0.0
	if is_instance_valid(_sprite2):
		_sprite2.queue_free()
	if is_instance_valid(_thruster2):
		_thruster2.queue_free()
