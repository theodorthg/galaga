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

const GAME_OVER_DELAY := 1.0
const RECONSTRUCT_SCENE := preload("res://ship_reconstruct.tscn")
const BONUS_ITEM_SCENE := preload("res://bonus_item.tscn")
const BONUS_INTERVAL_MIN := 14.0
const BONUS_INTERVAL_MAX := 24.0

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
var _bonus_t := 0.0
var _boss_interval := 0
var _next_boss_score := 0
var _win_score := 0

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
	_menus.splash_done.connect(_enter_title, CONNECT_ONE_SHOT)
	get_tree().paused = true
	_menus.show_splash()

# --- device layout: fixed design canvas, aspect handled at runtime ------
func _apply_display_mode() -> void:
	get_window().content_scale_aspect = (
		Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH if _touch
		else Window.CONTENT_SCALE_ASPECT_KEEP)

func apply_touch_layout() -> void:
	if _touch:
		return
	_touch = true
	_apply_display_mode()

# --- run lifecycle ----------------------------------------------------
func _reload_settings() -> void:
	_cfg = GameSettings.load_all()
	if is_instance_valid(_ship):
		_ship.configure(int(_cfg.get("max_shots", 2)))

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
	# _lives is the RESERVE count — ships still in the wings, not counting the
	# one that's about to fly. Standard arcade convention (Galaga, Tetris' next
	# piece, ...): the ship on screen never counts towards its own indicator.
	_lives = int(_cfg.get("lives", 3)) - 1
	_extra_step = int(_cfg.get("extra_life", 0))
	_next_extra = _extra_step
	_boss_interval = int(_cfg.get("boss_interval", 0))
	_next_boss_score = _boss_interval
	_win_score = int(_cfg.get("win_score", 0))
	_pending_twin = false
	_ship.deactivate_hyper_ammo()  # a fresh game never starts with a leftover buff
	_director.configure(GameSettings.dive_params(int(_cfg.get("difficulty", 1))))

	_clear_board()
	_hud.set_score(0)
	_hud.set_lives(_lives)
	_hud.clear_bonus_icons()
	_hud.set_playing(true)
	_menus.hide_all()

	_paused = false
	get_tree().paused = false
	if _snd:
		_snd.play("music")
	_ship.visible = false
	_ship.set_deferred("monitoring", false)
	_hud.flash_banner("BEREIT")
	await _play_reconstruct(_ship_spawn_pos())
	_hud.hide_banner()
	_ship.respawn()
	_start_ready()

## Plays the ship-(re)construction.gif materialize animation at `at` and waits
## for it to finish — used at the start of every run (stage 1) and on every
## respawn, in place of a flat timer wait that showed nothing happening.
func _play_reconstruct(at: Vector2) -> void:
	var r := RECONSTRUCT_SCENE.instantiate()
	add_child(r)
	r.global_position = at
	await r.build_done

## Where the ship reappears — always horizontally centered (respawn() does
## the same), at whatever y the ship scene was authored with.
func _ship_spawn_pos() -> Vector2:
	return Vector2(_ship.viewport_width * 0.5, _ship.position.y)

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
		_bonus_t = randf_range(BONUS_INTERVAL_MIN, BONUS_INTERVAL_MAX)

## Arcade-standard cap regardless of genre (Tetris, Galaga, ...) — see the
## global CLAUDE.md's life-count rule.
const MAX_LIVES_RUNTIME := 99

func _on_enemy_killed(points: int) -> void:
	_score += points
	_hud.set_score(_score)
	while _extra_step > 0 and _score >= _next_extra and _lives < MAX_LIVES_RUNTIME:
		_next_extra += _extra_step
		_lives = mini(_lives + 1, MAX_LIVES_RUNTIME)
		_hud.set_lives(_lives)
		if _snd:
			_snd.play("extra")
	_check_boss_threshold()
	_check_win()

## "Boss alle X Punkte" (GameSettings.boss_interval) — a guaranteed capture
## attempt on top of StageDirector's own random per-interval chance, so the
## mechanic isn't left purely to luck. `while` (not `if`) covers a big single
## score jump (e.g. the bonus-lap bonus) crossing more than one threshold at once.
## force_boss_capture() itself keeps retrying every couple of seconds until a
## Boss is actually available — see stage_director.gd — so this "fire and
## forget" call survives a stage change or the player losing a ship in between.
func _check_boss_threshold() -> void:
	if _boss_interval <= 0:
		return
	while _score >= _next_boss_score:
		_next_boss_score += _boss_interval
		_director.force_boss_capture()

## "Sieg bei X Punkten" (GameSettings.win_score) — an optional target score;
## 0 = off (endless, as before). Checked alongside the boss threshold so any
## scoring event (kill or bonus pickup) can trigger it.
func _check_win() -> void:
	if _win_score <= 0 or _state != FORMATION or _score < _win_score:
		return
	_state = GAME_OVER
	_director.stop_attacks()
	if _snd:
		_snd.stop("music")
	_hud.set_playing(false)
	_menus.show_game_over(_score, _stage, true)
	get_tree().paused = true

var _pending_twin := false

func _on_ship_rescued() -> void:
	# The Boss that had been carrying a captured ship just got destroyed — the
	# prisoner comes home. Common edge case: a laser fired just before you got
	# captured lands on that same boss a moment later, so the ship rescue
	# happens while your new ship hasn't respawned yet (mid-reconstruct animation).
	# Don't just drop the reward on that timing coincidence — queue it for the
	# respawn that's already on its way.
	if _state == GAME_OVER:
		return
	if is_instance_valid(_ship) and _ship._alive:
		_ship.become_twin()
	else:
		_pending_twin = true
	if _snd:
		_snd.play("extra")

func _on_ship_died() -> void:
	# _lives already excludes the ship that just died (it was never counted in
	# the reserve), so game-over is "no reserve left to draw from", checked
	# BEFORE decrementing — decrementing an already-zero reserve would send it
	# negative and misreport as "one ship left" on the next run's display.
	if _lives <= 0:
		_state = GAME_OVER
		_director.stop_attacks()
		if _snd:
			_snd.stop("music")
		await get_tree().create_timer(GAME_OVER_DELAY).timeout
		if not is_instance_valid(self) or _state != GAME_OVER:
			return
		_hud.set_playing(false)
		_menus.show_game_over(_score, _stage, false)
		get_tree().paused = true
		return
	_lives -= 1
	_hud.set_lives(_lives)
	await _play_reconstruct(_ship_spawn_pos())
	if is_instance_valid(_ship) and _state != GAME_OVER and _state != TITLE:
		_ship.respawn()
		if _pending_twin:
			_pending_twin = false
			_ship.become_twin()

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

func _process(delta: float) -> void:
	# Not Formation.live_count() — that only counts enemies currently occupying
	# a slot. A diving enemy releases its slot the instant it peels off (still
	# alive, still on screen, still able to return), so if it's the last one
	# left, live_count() hits 0 while it's still mid-dive and the next stage
	# would start under it. The "enemy" group covers every state (formation,
	# diving, returning) and only loses a member once it's actually destroyed.
	if _state != FORMATION or _paused:
		return
	if get_tree().get_nodes_in_group("enemy").is_empty():
		_stage += 1
		_ship.deactivate_hyper_ammo()  # Hyper-Ammo only lasts "for the rest of this stage"
		_start_ready()
		return
	_bonus_t -= delta
	if _bonus_t <= 0.0:
		_bonus_t = randf_range(BONUS_INTERVAL_MIN, BONUS_INTERVAL_MAX)
		_spawn_bonus_item()

## Occasional bonus pickup — one of the achivements.jpg ship-gallery icons,
## worth a flat bonus whether flown through or shot; it works out its own
## full-width sway pattern (see bonus_item.gd), we just drop it in from the top.
func _spawn_bonus_item() -> void:
	var b := BONUS_ITEM_SCENE.instantiate()
	b.position.y = -30.0
	add_child(b)
	b.collected.connect(_on_bonus_collected)

## Extra bonus for clearing a full row of collected icons (see hud.gd's
## BONUS_MAX_SHOWN / add_bonus_icon) — on top of the per-item POINTS.
const BONUS_LAP_POINTS := 2500

func _on_bonus_collected(points: int, icon: Texture2D, icon_index: int) -> void:
	_score += points
	if _hud.add_bonus_icon(icon):
		_score += BONUS_LAP_POINTS
	_hud.set_score(_score)
	_check_boss_threshold()
	_check_win()
	# achievement_00 specifically ("the flagship one") grants Hyper-Ammo — two
	# closely-spaced beams per shot — for the rest of the current stage.
	if icon_index == 0:
		_ship.activate_hyper_ammo()
	if _snd:
		_snd.play("extra")

# --- helpers -----------------------------------------------------
func _clear_board() -> void:
	for group in ["enemy", "player_lasers", "enemy_shots", "bonus_item"]:
		for n in get_tree().get_nodes_in_group(group):
			n.queue_free()
	_formation.reset()
