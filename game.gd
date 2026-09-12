class_name Game
extends Node2D

## Top-level level controller.
##   TITLE     — title screen (tree paused)
##   READY     — "STAGE n" banner, ~1.8 s
##   ENTERING  — StageDirector runs the fly-in
##   FORMATION — enemies sway and dive; clear them all -> next stage
##   GAME_OVER — lives spent; menus.gd shows the board
## Pause (in-game) freezes the tree and shows the pause menu.

enum { TITLE, READY, ENTERING, FORMATION, GAME_OVER }

const RESPAWN_DELAY := 1.2
const GAME_OVER_DELAY := 1.0

@onready var _formation: Formation = $Formation
@onready var _director: StageDirector = $StageDirector
@onready var _ship: Area2D = $Ship
@onready var _hud: Hud = $HUD/Root
@onready var _menus: Menus = $Menus

var _state := TITLE
var _stage := 1
var _score := 0
var _lives := 3
var _extra_step := 0
var _next_extra := 0
var _cfg := {}
var _touch := false
var _paused := false
var _snd: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("touch_layout_listeners")
	_touch = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	_apply_display_mode()
	_snd = get_node_or_null("/root/Snd")

	_director.setup(_formation, self)
	_director.stage_populated.connect(_on_stage_populated)
	_director.enemy_killed.connect(_on_enemy_killed)
	_director.ship_rescued.connect(_on_ship_rescued)
	_ship.died.connect(_on_ship_died)
	_hud.pause_pressed.connect(_request_pause)
	_menus.start_game.connect(_new_run)
	_menus.resume_game.connect(_resume)
	_menus.to_title.connect(_enter_title)
	_menus.settings_changed.connect(_reload_settings)

	_reload_settings()
	_enter_title()

# --- device layout: fixed design canvas, aspect handled at runtime ------
func _apply_display_mode() -> void:
	get_window().content_scale_aspect = (
		Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH if _touch
		else Window.CONTENT_SCALE_ASPECT_KEEP)
	_hud.set_touch(_touch)

func apply_touch_layout() -> void:
	if _touch:
		return
	_touch = true
	_apply_display_mode()

# --- run lifecycle ----------------------------------------------------
func _reload_settings() -> void:
	_cfg = GameSettings.load_all()

func _enter_title() -> void:
	_state = TITLE
	_paused = false
	_director.abort()
	_clear_board()
	if _snd:
		_snd.stop("music")
	_hud.set_playing(false)
	_menus.show_title()
	get_tree().paused = true

func _new_run() -> void:
	_reload_settings()
	_score = 0
	_stage = 1
	_lives = int(_cfg.get("lives", 3))
	_extra_step = int(_cfg.get("extra_life", 0))
	_next_extra = _extra_step
	_director.configure(GameSettings.dive_params(int(_cfg.get("difficulty", 1))))

	_clear_board()
	_hud.set_score(0)
	_hud.set_lives(_lives)
	_hud.set_playing(true)
	_menus.hide_all()

	_paused = false
	get_tree().paused = false
	_ship.respawn()
	if _snd:
		_snd.play("music")
	_start_ready()

func _request_pause() -> void:
	if _paused or _state == TITLE or _state == GAME_OVER:
		return
	_paused = true
	get_tree().paused = true
	_hud.set_playing(false)
	_menus.show_pause()

func _resume() -> void:
	_paused = false
	_menus.hide_all()
	_hud.set_playing(true)
	get_tree().paused = false

# --- stage flow -----------------------------------------------------
func _start_ready() -> void:
	_state = READY
	_director.stop_attacks()
	_hud.set_stage(_stage)
	_hud.flash_banner("STAGE %d" % _stage)
	if _snd:
		_snd.play("stage")
	await get_tree().create_timer(Hud.BANNER_TOTAL).timeout
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
	while _extra_step > 0 and _score >= _next_extra:
		_next_extra += _extra_step
		_lives += 1
		_hud.set_lives(_lives)
		if _snd:
			_snd.play("extra")

func _on_ship_rescued() -> void:
	# The Boss that had been carrying a captured ship just got destroyed — the
	# prisoner comes home. If the player's current ship is alive, it becomes a
	# twin fighter (double firepower, one hit ends the bonus for both).
	if is_instance_valid(_ship) and _state != GAME_OVER:
		_ship.become_twin()
		if _snd:
			_snd.play("extra")

func _on_ship_died() -> void:
	_lives -= 1
	_hud.set_lives(_lives)
	if _lives <= 0:
		_state = GAME_OVER
		_director.stop_attacks()
		if _snd:
			_snd.stop("music")
		await get_tree().create_timer(GAME_OVER_DELAY).timeout
		if not is_instance_valid(self) or _state != GAME_OVER:
			return
		_hud.set_playing(false)
		_menus.show_game_over(_score, _stage)
		get_tree().paused = true
		return
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	if is_instance_valid(_ship) and _state != GAME_OVER and _state != TITLE:
		_ship.respawn()

# --- input --------------------------------------------------------
func _input(event: InputEvent) -> void:
	# retroactive flip: some mobile browsers report touch late
	if not _touch and (event is InputEventScreenTouch or event is InputEventScreenDrag):
		get_tree().call_group("touch_layout_listeners", "apply_touch_layout")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _paused:
			_resume()
		else:
			_request_pause()

func _process(_delta: float) -> void:
	# Not Formation.live_count() — that only counts enemies currently occupying
	# a slot. A diving enemy releases its slot the instant it peels off (still
	# alive, still on screen, still able to return), so if it's the last one
	# left, live_count() hits 0 while it's still mid-dive and the next stage
	# would start under it. The "enemy" group covers every state (formation,
	# diving, returning) and only loses a member once it's actually destroyed.
	if _state == FORMATION and not _paused and get_tree().get_nodes_in_group("enemy").is_empty():
		_stage += 1
		_start_ready()

# --- helpers -----------------------------------------------------
func _clear_board() -> void:
	for group in ["enemy", "player_lasers", "enemy_shots"]:
		for n in get_tree().get_nodes_in_group(group):
			n.queue_free()
	_formation.reset()
