class_name Game
extends Node2D

## Top-level level controller.
##   READY     — "STAGE n" banner, ~1.8 s
##   ENTERING  — StageDirector runs the fly-in
##   FORMATION — enemies sway and dive; clear them all -> next stage
##   GAME_OVER — lives spent; SHOOT restarts

enum { READY, ENTERING, FORMATION, GAME_OVER }

const START_LIVES := 3
const EXTRA_LIFE_EVERY := 20000
const RESPAWN_DELAY := 1.2

@onready var _formation: Formation = $Formation
@onready var _director: StageDirector = $StageDirector
@onready var _ship: Area2D = $Ship
@onready var _hud: Hud = $HUD/Root

var _state := READY
var _stage := 1
var _score := 0
var _lives := START_LIVES
var _next_extra := EXTRA_LIFE_EVERY
var _touch := false
var _paused := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("touch_layout_listeners")
	_touch = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	_apply_display_mode()

	_director.setup(_formation, self)
	_director.stage_populated.connect(_on_stage_populated)
	_director.enemy_killed.connect(_on_enemy_killed)
	_ship.died.connect(_on_ship_died)
	_hud.pause_pressed.connect(_toggle_pause)
	_hud.set_score(0)
	_hud.set_lives(_lives)
	_start_ready()

# --- device layout: fixed design canvas, aspect handled at runtime ------
func _apply_display_mode() -> void:
	get_window().content_scale_aspect = (
		Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH if _touch
		else Window.CONTENT_SCALE_ASPECT_KEEP)
	_hud.set_touch(_touch)

# group "touch_layout_listeners": first real touch event flips us to touch mode
func apply_touch_layout() -> void:
	if _touch:
		return
	_touch = true
	_apply_display_mode()

func _toggle_pause() -> void:
	if _state == GAME_OVER:
		return
	_paused = not _paused
	get_tree().paused = _paused
	_hud.set_paused(_paused)

func _start_ready() -> void:
	_state = READY
	_director.stop_attacks()
	_hud.set_stage(_stage)
	_hud.flash_banner("STAGE %d" % _stage)
	await get_tree().create_timer(1.8).timeout
	if not is_instance_valid(self) or _state != READY:
		return
	_hud.hide_banner()
	_state = ENTERING
	_director.start_stage(_stage)

func _on_stage_populated() -> void:
	if _state == ENTERING:
		_state = FORMATION
		_director.begin_attacks()

func _on_enemy_killed(points: int) -> void:
	_score += points
	_hud.set_score(_score)
	while _score >= _next_extra:
		_next_extra += EXTRA_LIFE_EVERY
		_lives += 1
		_hud.set_lives(_lives)

func _on_ship_died() -> void:
	_lives -= 1
	_hud.set_lives(_lives)
	if _lives <= 0:
		_state = GAME_OVER
		_director.stop_attacks()
		_hud.show_game_over(_score)
		return
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	if is_instance_valid(_ship) and _state != GAME_OVER:
		_ship.respawn()

func _input(event: InputEvent) -> void:
	# retroactive flip: some mobile browsers report touch late
	if not _touch and (event is InputEventScreenTouch or event is InputEventScreenDrag):
		get_tree().call_group("touch_layout_listeners", "apply_touch_layout")

func _unhandled_input(event: InputEvent) -> void:
	if _state == GAME_OVER:
		if event.is_action_pressed("shoot") or (event is InputEventMouseButton and event.pressed) \
				or (event is InputEventScreenTouch and event.pressed):
			get_tree().reload_current_scene()
		return
	if event.is_action_pressed("pause"):
		_toggle_pause()
	elif _paused and (event is InputEventScreenTouch and event.pressed):
		_toggle_pause()

func _process(_delta: float) -> void:
	if _state == FORMATION and _formation.live_count() == 0:
		_stage += 1
		_start_ready()
