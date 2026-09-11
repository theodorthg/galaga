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
const MAX_LASERS := 2
const RESPAWN_INVULN := 1.6

var speed := 480.0
var ship_half_width := 34.0
var viewport_width := 0.0

var _alive := true
var _invuln := 0.0
var _mouse_aim := false
var _mouse_down := false
var _touch := false
var _snd: Node

signal died

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE  # freeze on pause, not inherit Game's ALWAYS
	add_to_group("player")
	add_to_group("touch_layout_listeners")
	_touch = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	_snd = get_node_or_null("/root/Snd")
	area_entered.connect(_on_area_entered)
	viewport_width = get_viewport_rect().size.x

# group "touch_layout_listeners": first real touch event flips us to touch mode
func apply_touch_layout() -> void:
	_touch = true

func _process(delta: float) -> void:
	if _invuln > 0.0:
		_invuln -= delta
		modulate.a = 0.35 + 0.4 * (0.5 + 0.5 * sin(_invuln * 32.0))
		if _invuln <= 0.0:
			modulate.a = 1.0

	if not _alive:
		return

	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		_mouse_aim = false
		position.x += dir * speed * delta
	elif _mouse_aim:
		position.x = move_toward(position.x, get_global_mouse_position().x, speed * delta)
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
	if get_tree().get_nodes_in_group("player_lasers").size() >= MAX_LASERS:
		return
	var laser := LASER_SCENE.instantiate()
	laser.add_to_group("player_lasers")
	get_parent().add_child(laser)
	laser.global_position = global_position + Vector2(0, -22)
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
	if _snd:
		_snd.play("player_boom")
	died.emit()

func respawn() -> void:
	position.x = viewport_width * 0.5
	_alive = true
	visible = true
	_invuln = RESPAWN_INVULN
	set_deferred("monitoring", true)
