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
const EXPLOSION_SCENE := preload("res://ship_explosion.tscn")
const BONUS_ITEM_SCENE := preload("res://bonus_item.tscn")
const SCORE_POPUP_SCRIPT := preload("res://score_popup.gd")
# Tightened from 14-24s (2026-09-13 report: "one achievement in a 60000-point
# run") — most of that scarcity was actually _on_stage_populated() resetting
# this timer on every single stage clear (see below), throwing away whatever
# had already counted down; a good player who clears stages in well under
# 14s could go an entire run without the timer ever reaching zero. Shortening
# the range on top of the reset-bug fix gives a bit more headroom either way.
const BONUS_INTERVAL_MIN := 9.0
const BONUS_INTERVAL_MAX := 16.0
## Icon for the run-summary's "Boss (Rettung)" kill-breakdown row (see
## _kill_stat_entry()) — a rescue-kill is tracked separately from a plain Boss
## kill, so it gets its own icon rather than reusing the Boss sprite: the
## freed captive itself, not the Boss that was carrying it.
const RESCUE_ICON := preload("res://assets/graphics/ship_captured.png")

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
## Gates the stage-1 fly-in on start-first-level-music actually finishing (or
## being skipped by a click/tap) — see _new_run(), _unhandled_input(), and
## _start_ready(). Never set for stage 2+ (only _new_run() sets it).
var _intro_gate_active := false
# Run-summary tracking (menus.gd::show_run_summary(), see _on_ship_died() /
# _check_win()) — reset once per run in _new_run().
var _rescues := 0
var _rescue_points := 0
var _last_kill_points := 0
var _achievements_collected := 0
# Per-SPRITE kill breakdown for the run-summary screen (menus.gd::
# show_run_summary()/_fill_summary()) — reset once per run in _new_run().
# There are 8 visually distinct enemies across the 3 scoring tiers (classic +
# 2 stage-variants each for Zako/Goei, classic + 1 stage-variant for Boss),
# not just 3 — plus a 9th "Boss (Rettung)" bucket for a Boss shot down WHILE
# carrying a captured ship, tracked separately from a plain Boss kill (user
# request). Each entry: {kind, variant_idx, is_rescue, icon, count, points} —
# see _kill_stat_entry().
var _kill_stats: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("touch_layout_listeners")
	_touch = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	_apply_display_mode()
	_menus.set_touch_context(_touch)
	# Ship is a CHILD node, so its own _ready() (and _update_home_y() inside
	# it) already ran BEFORE this parent _ready() — against whatever aspect
	# was in effect at scene load, not the one _apply_display_mode() just set
	# above. On a device where touch is known upfront (OS.has_feature
	# ("mobile")), that stale KEEP-based position never gets corrected
	# afterwards: the retroactive-flip group call below only fires on an
	# actual touch/drag INPUT EVENT, which never happens on a device that was
	# already touch-known from the start. Re-running the whole
	# touch_layout_listeners group here (harmless no-op for game.gd's own
	# listener, since _touch is already set) re-homes the ship against the
	# now-correct KEEP_WIDTH viewport height — fixes the ship sitting far too
	# high on tall touch devices (e.g. OnePlus 12), user-reported 2026-09-13.
	get_tree().call_group("touch_layout_listeners", "apply_touch_layout")
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
	_menus.set_touch_context(_touch)

# --- run lifecycle ----------------------------------------------------
func _reload_settings() -> void:
	_cfg = GameSettings.load_all()
	if is_instance_valid(_ship):
		_ship.configure(int(_cfg.get("max_shots", 2)))
	# Difficulty only ever fed StageDirector's dive timing (see game_settings.gd's
	# dive_params: first-dive delay, min/max seconds between dives, max
	# concurrent divers) — nothing else keys off it. configure() just merges
	# these into _atk without touching in-flight timers, so re-applying it here
	# is safe mid-stage and takes effect on the very next dive roll.
	_director.configure(GameSettings.dive_params(int(_cfg.get("difficulty", 1))))
	_apply_extra_life_setting(int(_cfg.get("extra_life", 0)))
	_apply_boss_interval_setting(int(_cfg.get("boss_interval", 0)))
	_win_score = int(_cfg.get("win_score", 0))
	# The reverse direction: raising the win score (or turning it off) from the
	# win screen's own "Einstellungen" button (see menus.gd's "summary" screen)
	# past the current score un-ends a run that was stopped by _check_win() —
	# see _revive_after_win_edit(). Never applies to a real game-over (ship
	# count exhausted): _ended_by_win is only ever set by _check_win() itself.
	if _state == GAME_OVER and _ended_by_win and (_win_score <= 0 or _score < _win_score):
		_revive_after_win_edit()
	# Makes "Sieg bei X Punkten" reactive: lowering it below (or to) the score
	# already reached while a run is in progress ends the run right away,
	# instead of only taking effect on the next game. Guarded by _state ==
	# FORMATION inside _check_win() itself, so this is a no-op both before the
	# very first run (_state == TITLE) and while _new_run() is still assembling
	# a fresh run (called again below, _score not yet reset to 0 at that point).
	if _state == FORMATION:
		_check_win()

## Recomputes the next extra-life threshold from the CURRENT score whenever the
## step size itself changes (settings can be edited mid-run via pause, see
## _reload_settings() above) — keeps the fixed original step's absolute
## thresholds (which no longer mean anything once the step changes) from either
## firing immediately in a burst or never firing again.
func _apply_extra_life_setting(new_step: int) -> void:
	if new_step == _extra_step:
		return
	_extra_step = new_step
	_next_extra = (new_step * (floori(float(_score) / new_step) + 1)) if new_step > 0 else 0

## Same idea as _apply_extra_life_setting() above, for "Boss alle X Punkte".
func _apply_boss_interval_setting(new_interval: int) -> void:
	if new_interval == _boss_interval:
		return
	_boss_interval = new_interval
	_next_boss_score = (new_interval * (floori(float(_score) / new_interval) + 1)) if new_interval > 0 else 0

func _enter_title() -> void:
	_state = TITLE
	_paused = false
	_director.abort()
	_clear_board()
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
	_ended_by_win = false
	# Set ONCE per run, not re-rolled on every stage clear (see
	# _on_stage_populated() for why that used to throw away a mostly-elapsed
	# countdown every time a stage ended quickly).
	_bonus_t = randf_range(BONUS_INTERVAL_MIN, BONUS_INTERVAL_MAX)
	_pending_twin = false
	_rescues = 0
	_rescue_points = 0
	_last_kill_points = 0
	_achievements_collected = 0
	_kill_stats = []
	_ship.deactivate_hyper_ammo()  # a fresh game never starts with a leftover buff
	_director.configure(GameSettings.dive_params(int(_cfg.get("difficulty", 1))))

	_clear_board()
	_hud.set_score(0)
	_hud.set_lives(_lives)
	_hud.clear_bonus_icons()
	_hud.set_playing(true)
	_menus.hide_all()
	_menus.stop_menu_music()  # in case this run started from "Nochmal" on the game-over screen, scoring-board-music was still playing

	_paused = false
	get_tree().paused = false
	if _snd:
		# One-shot intro, stage 1 of a fresh game only (user request) — gates
		# the fly-in in _start_ready() below until it finishes or the player
		# clicks/taps to skip (see _unhandled_input()).
		if _snd.has_clip("start-first-level-music"):
			_snd.play("start-first-level-music")
			_intro_gate_active = true
	_ship.visible = false
	_ship._alive = false  # blocks shoot() during the materialize animation below
	_ship.set_deferred("monitoring", false)
	_hud.flash_banner("READY")
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

## Plays the ship_explosion.tscn boom at `at` and waits for it — a real hit
## (not a Boss capture, see ship.gd::_destroy()'s show_explosion) always gets
## this BEFORE any reconstruct/game-over handling runs, so the ship visibly
## blows up before it's allowed to start materializing again (user request).
func _play_explosion(at: Vector2) -> void:
	var e := EXPLOSION_SCENE.instantiate()
	add_child(e)
	e.global_position = at
	await e.explosion_done
	# The "ship-destroyed" SFX (started by ship.gd::_destroy() right before
	# this got called) runs longer than the ~0.4s boom animation — waiting on
	# the animation alone let the reconstruct start while the ship's own
	# death sound was still playing underneath it (user report).
	while _snd and _snd.is_playing("ship-destroyed"):
		await get_tree().process_frame

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
	_menus.stop_menu_music()
	_hud.set_playing(true)
	get_tree().paused = false

# --- stage flow -----------------------------------------------------
## Breathing room between the jingles of a stage change: level-cleared ->
## (gap) -> "STAGE n" banner + stage jingle -> (gap) -> fly-in. Before this,
## level-cleared and the stage jingle started in the same frame and talked
## over each other, and the fly-in began while the jingle was still playing
## (user report: "Abstand viel zu klein").
const STAGE_JINGLE_GAP := 0.5

func _start_ready() -> void:
	_state = READY
	_director.stop_attacks()
	_hud.set_stage(_stage)
	if not await _wait_sound_then_gap("level-cleared"):
		return
	_hud.flash_banner("STAGE %d" % _stage)
	# Stage 1 of a fresh run has its own, much longer intro (6.9 s,
	# start-first-level-music) — that IS the fanfare there, so the 2.6 s
	# stage jingle stays silent instead of playing on top of it.
	if _snd and not _intro_gate_active:
		_snd.play("stage")
	await get_tree().create_timer(Hud.BANNER_TOTAL).timeout
	if not is_instance_valid(self) or _state != READY:
		return
	# Stage-1-of-a-fresh-run intro gate (user request): don't start the fly-in
	# until start-first-level-music has actually finished, or the player
	# skipped it early via _unhandled_input(). A no-op whenever the intro
	# either already finished during the banner's own BANNER_TOTAL wait above,
	# was skipped, or never started (stage 2+, or no clip supplied).
	if not await _wait_sound_then_gap("start-first-level-music" if _intro_gate_active else "stage"):
		return
	_intro_gate_active = false
	_hud.hide_banner()
	_state = ENTERING
	_director.start_stage(_stage)

## Waits until `key` has stopped playing (skips the wait if it isn't), then
## STAGE_JINGLE_GAP more. False if the run left READY meanwhile (menu, title).
func _wait_sound_then_gap(key: String) -> bool:
	while _snd and _snd.is_playing(key):
		await get_tree().process_frame
		if not is_instance_valid(self) or _state != READY:
			return false
	await get_tree().create_timer(STAGE_JINGLE_GAP).timeout
	return is_instance_valid(self) and _state == READY

func _on_stage_populated() -> void:
	if _state == ENTERING:
		_state = FORMATION
		_director.begin_attacks()
		# _bonus_t deliberately NOT reset here — it counts down continuously
		# across the whole run (see _new_run()), so a stage cleared in a few
		# seconds doesn't erase progress a skilled player already built up
		# toward the next bonus spawn.

## Arcade-standard cap regardless of genre (Tetris, Galaga, ...) — see the
## global CLAUDE.md's life-count rule.
const MAX_LIVES_RUNTIME := 99

func _on_enemy_killed(points: int, kind: int, variant_idx: int, was_carrying_captive: bool) -> void:
	# Hyper-Ammo (see ship.gd::activate_hyper_ammo) doubles points per kill too,
	# not just the shot count — user request, on top of the existing beam buff.
	if _ship._hyper_ammo:
		points *= 2
	_last_kill_points = points
	var stat := _kill_stat_entry(kind, variant_idx, was_carrying_captive)
	stat.count += 1
	stat.points += points
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

## Finds (or creates) the _kill_stats entry for this exact combination —
## same kind+variant_idx from different stages of the same run still share
## one bucket, but a rescue-kill (was_carrying_captive) always gets its own
## bucket regardless of variant, per the user's explicit request to track it
## separately from a plain Boss kill. Linear search is fine here: at most 9
## possible categories total ever exist (8 sprites + 1 rescue bucket).
func _kill_stat_entry(kind: int, variant_idx: int, is_rescue: bool) -> Dictionary:
	for e in _kill_stats:
		if e.kind == kind and e.variant_idx == variant_idx and e.is_rescue == is_rescue:
			return e
	var icon: Texture2D = RESCUE_ICON if is_rescue else load(EnemyKinds.icon_texture(kind, variant_idx))
	var e := {"kind": kind, "variant_idx": variant_idx, "is_rescue": is_rescue, "icon": icon, "count": 0, "points": 0}
	_kill_stats.append(e)
	return e

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
var _ended_by_win := false

func _check_win() -> void:
	if _win_score <= 0 or _state != FORMATION or _score < _win_score:
		return
	_ended_by_win = true
	_state = GAME_OVER
	_director.stop_attacks()
	_hud.set_playing(false)
	_menus.show_run_summary(_score, _stage, true, _rescues, _rescue_points, _achievements_collected, _hud._bonus_laps, _kill_stats)
	get_tree().paused = true

## Undoes _check_win() above if the win screen's own "Einstellungen" button
## (user request) is used to raise (or turn off) the win score enough that the
## current score no longer qualifies as a win — lets the player keep playing
## the SAME run instead of being forced to restart just because they wanted a
## higher target. Only ever applies to a WIN ending, never a real game-over
## (no ship left) — `_ended_by_win` distinguishes the two, since both share
## GAME_OVER. Nothing else about the run's state needs restoring: _check_win()
## never cleared the board or touched the ship, only paused/stopped things.
func _revive_after_win_edit() -> void:
	_ended_by_win = false
	_state = FORMATION
	_director.begin_attacks()
	_hud.set_playing(true)
	_menus.hide_all()
	_menus.stop_menu_music()  # was on menu-music (from the summary screen's own "Einstellungen" button)
	get_tree().paused = false

var _pending_twin := false

func _on_ship_rescued(at_position: Vector2) -> void:
	# The Boss that had been carrying a captured ship just got destroyed — the
	# prisoner comes home. Common edge case: a laser fired just before you got
	# captured lands on that same boss a moment later, so the ship rescue
	# happens while your new ship hasn't respawned yet (mid-reconstruct animation).
	# Don't just drop the reward on that timing coincidence — queue it for the
	# respawn that's already on its way.
	_rescues += 1
	_rescue_points += _last_kill_points
	_spawn_score_popup(at_position, "+%d" % _last_kill_points)
	if _state == GAME_OVER:
		return
	if is_instance_valid(_ship) and _ship._alive:
		_ship.become_twin()
	else:
		_pending_twin = true
	if _snd:
		_snd.play("extra")

func _on_ship_died(show_explosion: bool) -> void:
	# Captured BEFORE anything below runs — _ship.position doesn't change
	# again until respawn()/_ship_spawn_pos() later, so this is still exactly
	# where it was hit. A capture (show_explosion == false) skips this: not a
	# destruction, no boom (user request).
	if show_explosion:
		await _play_explosion(_ship.global_position)
	# _lives already excludes the ship that just died (it was never counted in
	# the reserve), so game-over is "no reserve left to draw from", checked
	# BEFORE decrementing — decrementing an already-zero reserve would send it
	# negative and misreport as "one ship left" on the next run's display.
	if _lives <= 0:
		_state = GAME_OVER
		_director.stop_attacks()
		await get_tree().create_timer(GAME_OVER_DELAY).timeout
		if not is_instance_valid(self) or _state != GAME_OVER:
			return
		_hud.set_playing(false)
		_menus.show_run_summary(_score, _stage, false, _rescues, _rescue_points, _achievements_collected, _hud._bonus_laps, _kill_stats)
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
	# Skip the stage-1 intro music early (user request: mouse click or tap,
	# not e.g. any keypress) — _start_ready() below is polling is_playing()
	# for this same clip, so stopping it here is all skipping needs to do.
	if _intro_gate_active and ((event is InputEventMouseButton and event.pressed)
			or (event is InputEventScreenTouch and event.pressed)):
		_intro_gate_active = false
		if _snd:
			_snd.stop("start-first-level-music")
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
	# Stage clear also waits for any bonus_item still on screen (user request:
	# an achievement shouldn't be able to linger into — or get orphaned by —
	# the next stage's fly-in) — it either gets collected or falls off-screen
	# and frees itself (bonus_item.gd), either way leaving the group.
	if get_tree().get_nodes_in_group("enemy").is_empty() \
		and get_tree().get_nodes_in_group("bonus_item").is_empty():
		# Bombs already in flight from this stage are independent of the enemy
		# that threw them (see bomb.gd) and would otherwise keep falling —
		# and keep being able to hit the ship — into the next stage's "STAGE n"
		# banner, which reads as unfair once the stage is actually cleared.
		for n in get_tree().get_nodes_in_group("enemy_shots"):
			n.queue_free()
		if _snd:
			_snd.play("level-cleared")
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
	# Must be set before add_child() — bonus_item.gd's _ready() (which picks
	# the icon) fires synchronously during add_child(), same ordering gotcha
	# as the x-position bug from the "Dritte Playtest-Runde".
	b.exclude_indices = _hud.current_lap_indices()
	add_child(b)
	b.collected.connect(_on_bonus_collected)

## Extra bonus for clearing a full row of collected icons (see hud.gd's
## BONUS_MAX_SHOWN / add_bonus_icon) — on top of the per-item POINTS.
const BONUS_LAP_POINTS := 2500

func _on_bonus_collected(points: int, icon: Texture2D, icon_index: int, at_position: Vector2) -> void:
	_achievements_collected += 1
	var total := points
	_score += points
	var lap_done := _hud.add_bonus_icon(icon, icon_index)
	if lap_done:
		total += BONUS_LAP_POINTS
		_score += BONUS_LAP_POINTS
		_hud.flash_banner("LAP!")
	_hud.set_score(_score)
	_spawn_score_popup(at_position, "+%d" % total)
	_check_boss_threshold()
	_check_win()
	# achievement_00 specifically ("the flagship one") grants Hyper-Ammo — two
	# closely-spaced beams per shot — for the rest of the current stage.
	if icon_index == 0:
		_ship.activate_hyper_ammo()
	if _snd:
		_snd.play("bonus-stage-cleared" if lap_done else "extra")

## Small "+points" floating text at the exact catch point — bonus_item pickups
## only, deliberately not used for enemy kills.
func _spawn_score_popup(at: Vector2, text: String) -> void:
	var p := SCORE_POPUP_SCRIPT.new()
	p.text = text
	add_child(p)
	p.global_position = at

# --- helpers -----------------------------------------------------
func _clear_board() -> void:
	for group in ["enemy", "player_lasers", "enemy_shots", "bonus_item"]:
		for n in get_tree().get_nodes_in_group(group):
			n.queue_free()
	_formation.reset()
