class_name Game
extends Node2D

## Top-level level controller.
##   TITLE     — title screen (tree paused)
##   READY     — "STAGE n" banner, ~1.8 s
##   ENTERING  — StageDirector runs the fly-in
##   FORMATION — enemies sway and dive; clear them all -> next stage
##   GAME_OVER — lives spent; menus.gd shows the board
## Pause (in-game) freezes the tree and shows the pause menu.

enum { TITLE, READY, ENTERING, FORMATION, GAME_OVER, BONUS }

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

const BONUS_ENEMY_SCENE := preload("res://bonus_enemy.tscn")
## Bonus Level (GameSettings.bonus_level_interval — user proposal 2026-09-14,
## corrected 2026-09-14/2026-09-15 after real playtests): instead of the
## normal 40-slot formation, WAVE_COUNT flights of ENEMIES_PER_WAVE enemies
## each fly in from above and queue up nose-to-tail on ONE dead-straight
## vertical track — not a formation sliding sideways across the screen — so
## the player can plant the ship under that column and shoot the whole flight
## from one spot, without having to track a moving line. No dive/bomb/capture
## (bonus_enemy.gd isn't in the "enemy" group, so none of the main formation's
## attack machinery applies) — BUT ramming one still costs a life exactly like
## ramming a diving formation enemy does (ship.gd checks the "bonus_wave_active"
## group directly for that) — flying straight through untouched felt wrong
## (user report). No Boss ever appears here (user spec: a capture attempt
## would defeat the point of a Bonus Level) — EnemyKinds only has two other
## kinds, so the 3 flights alternate ZAKO/GOEI/ZAKO, each at a different
## column x ("von unterschiedlichen Stellen aus").
const BONUS_WAVE_COUNT := 3
const BONUS_ENEMIES_PER_WAVE := 6
## Time between launching each chain member onto the shared track — creates
## the queued "chain" by staggering LAUNCH TIME, not by offsetting each
## member's own geometry (the previous, sideways-crossing design's approach).
## ~70px of visual gap at bonus_enemy.gd's own default 260px/s travel speed.
const BONUS_LAUNCH_GAP := 0.27
const BONUS_WAVE_PAUSE := 1.2
## Escalating base speed per wave + a per-member random jitter on top (user
## request 2026-09-14: the first playtest felt too uniform/predictable for a
## "Challenge") — each wave is a bit faster than the last, and no two members
## of the same wave travel at quite the same speed, so the queue doesn't read
## as a perfectly even, fully predictable conveyor belt.
const BONUS_WAVE_SPEEDS := [230.0, 290.0, 350.0]
const BONUS_SPEED_JITTER := 0.18  # ± fraction of the wave's base speed
## With the Twin-ship bonus active (ship.gd::_twin, two guns firing at once),
## each wave spawns TWO parallel columns instead of one, offset this far apart
## — user request 2026-09-15: two guns with only one column to shoot at felt
## wasted. Roughly matches ship.gd's own TWIN_OFFSET*2 (34*2=68), so each
## column lands close to directly under one of the twin ship's two guns.
## Checked fresh at the START of every wave (not once for the whole level) —
## ramming a bonus_enemy now costs a life same as any other hit, which can
## revert the Twin bonus mid-level, so a later wave should stop doubling if
## that happens.
const BONUS_TWIN_ROW_GAP := 70.0
## See ship.gd::DESIGN_WIDTH — bonus-level column x positions are fractions of
## the fixed playable-lane width, not the actual (possibly wider, landscape-
## cabinet-overlay) viewport, or they'd drift into the cabinet-art margins.
const DESIGN_WIDTH := 540.0

## Manual override to force non-touch regardless of what OS.has_feature
## ("mobile")/touchscreen autodetection or the connected-joypad check (see
## _ready()) would otherwise conclude. Not currently set by anything —
## superseded by the joypad check for the one case it was originally written
## for (the Anbernic RG552's landscape-cabinet-overlay mode, which turned out
## to need this to be based on "is a real controller actually connected",
## not "is this device in some particular shape/mode"). Left in place as an
## explicit escape hatch for a future device that needs it.
var force_non_touch := false

@onready var _hud_layer: CanvasLayer = $HUD
@onready var _formation: Formation = $Formation
@onready var _director: StageDirector = $StageDirector
@onready var _ship: Area2D = $Ship
@onready var _hud: Hud = $HUD/Root
@onready var _menus: Menus = $Menus
@onready var _space_bg := $SpaceBackground/ColorRect

## Cabinet-overlay side-margin decoration, shown only when
## _wants_cabinet_overlay() is true (see below). arcade-screen1a.png is the
## user-edited variant of the original research image (arcade-screen1.png,
## kept in the repo for reference): same 2728x1536 art, but with the top/
## bottom decorative border strips hollowed out (outline kept, solid fill
## made transparent) at the spots that would otherwise sit right behind the
## HUD once those strips bleed into the lane itself — see
## _set_cabinet_strips_visible() below. The image's cutout spans the full
## height and is horizontally centered on the image's own midpoint, which is
## also where STRETCH_KEEP_ASPECT_CENTERED naturally centers the whole image
## within any window, so it lines up with the game lane's own center for
## free, no extra positioning math.
const CABINET_ART := preload("res://arcade-screen1a.png")
## Native pixel size of CABINET_ART — needed to replicate Godot's own
## STRETCH_KEEP_ASPECT_CENTERED math by hand in _set_cabinet_strips_visible()
## (see its doc comment for why: the image's actual fitted top/bottom edges
## move depending on the window's aspect ratio, they're not always at y=0/
## win.y — confirmed live on the RG552, whose 1920x1152 shape is narrower
## than this image's own ~1.776:1, so the image is fit by WIDTH there and
## letterboxed top/bottom by about 30 logical units, unlike a 960x540 desktop
## window which happens to fit by HEIGHT with near-zero letterbox).
const CABINET_ART_SIZE := Vector2(2728.0, 1536.0)
var _cabinet_art_rect: TextureRect

## The cabinet art's top/bottom decorative border strips bleed INTO the lane
## itself, replacing the starfield right at its very top/bottom edge (not
## changing the lane's own 540x960 gameplay dimensions, just what's drawn
## behind those few pixels). Implemented as two small "clip windows": each is
## a Control with clip_contents=true sized to one strip's on-screen band,
## with a child TextureRect INSIDE it that duplicates the exact same
## full-window, STRETCH_KEEP_ASPECT_CENTERED rendering as the main
## _cabinet_art_rect above but shifted by -position so the same big image
## lines up pixel-identically — the clip then reveals only the slice of it
## that falls within that band. Simpler than computing a source-texture
## region_rect by hand, and guaranteed to match the margins' own art exactly
## since it's the same texture+stretch settings, just windowed differently.
## Sits on its own CanvasLayer at layer -1: above SpaceBackground's starfield
## (-2), so it paints over the star lane's own top/bottom edges, but below
## HUD/Menus (layer 0), so score/buttons/etc. still draw on top as always.
const CABINET_STRIP_H := 70.0
var _cabinet_strip_top: Control
var _cabinet_strip_top_tex: TextureRect
var _cabinet_strip_bottom: Control
var _cabinet_strip_bottom_tex: TextureRect

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
var _bonus_hits := 0
var _bonus_total := 0
var _bonus_points := 0
## Set by _on_ship_died() when a ship is lost DURING a Bonus Level (user
## request 2026-09-15: only the Bonus Level should end early like this, no
## other stage ever has) — checked by _start_bonus_level()/_run_bonus_wave()
## instead of relying on _state alone, since flipping _state away from BONUS
## immediately would make _process()'s normal FORMATION stage-clear check
## misfire while the ship is still mid-explosion/reconstruct (a Bonus Level's
## "enemy"/"bonus_item" groups are already trivially empty). Reset per level.
var _bonus_abort := false
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
	# NOT tied to _wants_cabinet_overlay() — tried that first, but it forces
	# every landscape-shaped window non-touch, which is right for the
	# Anbernic RG552 (has a touchscreen but is actually played with its
	# D-pad/buttons there) and WRONG for a plain phone that rotates to
	# landscape — a phone has no alternative controller, so forcing
	# non-touch would leave the ship completely uncontrollable, not just
	# cosmetically off (also why phones stay portrait-locked again after a
	# 2026-09-15 test — see the project's own CLAUDE.md for the outcome). A
	# connected joypad is a much more direct signal of "this device has a
	# real controller" than window shape ever was — confirmed live on the
	# RG552 (its own D-pad/buttons enumerate as Input's joypad device 1 from
	# boot, per the DBGINPUT logcat capture from the gamepad-menu-support
	# round).
	_touch = false if (force_non_touch or Input.get_connected_joypads().size() > 0) \
		else (OS.has_feature("mobile") or DisplayServer.is_touchscreen_available())
	_apply_display_mode()
	_menus.set_touch_context(_touch)
	# Live window resizing (desktop) can cross into/out of cabinet-overlay
	# shape, or just change how much excess width there is while already in
	# it — _center_canvas_layers() needs the current width each time, unlike
	# the fixed Camera2D which needs no re-positioning at all (see
	# _set_cabinet_camera_active()'s doc comment). Kept as a best-effort extra
	# signal alongside the _process() poll below, not the only source of
	# truth — live-tested on Linux/X11 (user report 2026-09-15): dragging
	# ONLY the width edge didn't reliably fire size_changed at all, while
	# dragging height did, leaving the display mode stuck stale until some
	# later resize that happened to touch height. The RG552 was never
	# affected (fixed window size for its whole session, no live resize ever
	# happens there) — this is specifically a desktop live-resize gap.
	get_window().size_changed.connect(_apply_display_mode)
	_last_window_size = DisplayServer.window_get_size()
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
	if _snd:
		_hud.set_muted(_snd.is_muted())

	_director.setup(_formation, self)
	_director.stage_populated.connect(_on_stage_populated)
	_director.enemy_killed.connect(_on_enemy_killed)
	_director.ship_rescued.connect(_on_ship_rescued)
	_ship.died.connect(_on_ship_died)
	_hud.pause_pressed.connect(_request_pause)
	_hud.mute_pressed.connect(_toggle_mute)
	_menus.start_game.connect(_new_run)
	_menus.resume_game.connect(_resume)
	_menus.to_title.connect(_enter_title)
	_menus.settings_changed.connect(_reload_settings)

	_reload_settings()
	_menus.splash_done.connect(_enter_title, CONNECT_ONE_SHOT)
	get_tree().paused = true
	_menus.show_splash()

# --- device layout: fixed design canvas, aspect handled at runtime ------
## Matches display/window/size/viewport_height in project.godot — see
## ship.gd::DESIGN_WIDTH for the width counterpart and why a fixed constant
## is needed here instead of reading the live viewport rect.
const DESIGN_HEIGHT := 960.0

var _cabinet_cam: Camera2D
## See the _process() poll below and _ready()'s size_changed connection —
## belt-and-suspenders against size_changed not firing for every kind of
## desktop window resize.
var _last_window_size := Vector2i.ZERO

## Landscape-shaped window (wider than tall) — a portrait-ish or square window
## has no meaningful side margin for cabinet art to fill in the first place.
## Deliberately NOT gated on touch/mobile: a landscape-locked device needing
## this (the Anbernic RG552) reports OS.has_feature("mobile")=true regardless
## of screen shape, and an earlier attempt (see the retired arcade_shell.gd's
## own history, CLAUDE.md "Achtundzwanzigste Playtest-Runde") excluded touch
## for exactly that reason and never triggered at all. Also true for a plain
## desktop window someone's dragged wide — same treatment applies there too.
func _wants_cabinet_overlay() -> bool:
	var win := DisplayServer.window_get_size()
	return win.x > win.y

func _apply_display_mode() -> void:
	var cabinet := _wants_cabinet_overlay()
	get_window().content_scale_aspect = (
		Window.CONTENT_SCALE_ASPECT_EXPAND if cabinet
		else Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH if _touch
		else Window.CONTENT_SCALE_ASPECT_KEEP)
	_set_cabinet_camera_active(cabinet)
	_center_canvas_layers(cabinet)
	_set_cabinet_art_visible(cabinet)
	_set_cabinet_strips_visible(cabinet)

## See CABINET_ART's doc comment above. Built once, lazily
## (only if cabinet mode is ever actually engaged), as a CanvasLayer BELOW
## SpaceBackground (layer -3 vs its -2) so the lane's own opaque star
## background — now correctly confined to the 540 lane, see
## set_cabinet_lane() — draws on top of it inside the lane, leaving the art
## visible only in the margins either side. Full-window-sized on purpose
## (STRETCH_KEEP_ASPECT_CENTERED needs the real window rect to center the
## artwork within, unlike the lane content which is deliberately confined).
func _set_cabinet_art_visible(visible_now: bool) -> void:
	if visible_now and not is_instance_valid(_cabinet_art_rect):
		var layer := CanvasLayer.new()
		layer.layer = -3
		add_child(layer)
		var rect := TextureRect.new()
		rect.texture = CABINET_ART
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.add_child(rect)
		_cabinet_art_rect = rect
	if is_instance_valid(_cabinet_art_rect):
		_cabinet_art_rect.get_parent().visible = visible_now

## See CABINET_STRIP_H's doc comment above.
func _set_cabinet_strips_visible(cabinet: bool) -> void:
	if cabinet and not is_instance_valid(_cabinet_strip_top):
		var layer := CanvasLayer.new()
		layer.layer = -1
		add_child(layer)
		_cabinet_strip_top = _build_cabinet_strip_clip()
		_cabinet_strip_bottom = _build_cabinet_strip_clip()
		layer.add_child(_cabinet_strip_top)
		layer.add_child(_cabinet_strip_bottom)
		_cabinet_strip_top_tex = _cabinet_strip_top.get_child(0)
		_cabinet_strip_bottom_tex = _cabinet_strip_bottom.get_child(0)
	if not is_instance_valid(_cabinet_strip_top):
		return
	_cabinet_strip_top.get_parent().visible = cabinet
	if not cabinet:
		return
	var win := get_viewport_rect().size
	var offset_x := maxf(win.x - DESIGN_WIDTH, 0.0) * 0.5
	# Replicates STRETCH_KEEP_ASPECT_CENTERED's own fit math (the smaller of
	# the two axis scales wins, image is centered in whichever axis has
	# leftover space) so the strip bands track the image's REAL fitted edges
	# instead of assuming they always sit flush with the window edges.
	var img_scale := minf(win.x / CABINET_ART_SIZE.x, win.y / CABINET_ART_SIZE.y)
	var img_top := (win.y - CABINET_ART_SIZE.y * img_scale) * 0.5
	_position_cabinet_strip(_cabinet_strip_top, _cabinet_strip_top_tex, win, offset_x, img_top)
	_position_cabinet_strip(_cabinet_strip_bottom, _cabinet_strip_bottom_tex, win, offset_x,
		win.y - img_top - CABINET_STRIP_H)

func _build_cabinet_strip_clip() -> Control:
	var clip := Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := TextureRect.new()
	tex.texture = CABINET_ART
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(tex)
	return clip

## band_y is in lane-local (0..DESIGN_HEIGHT) coordinates, like set_cabinet_
## lane()'s own offset_x parameter — clip.position converts that to window
## space by adding offset_x, same as every other cabinet-mode element.
func _position_cabinet_strip(clip: Control, tex: TextureRect, win: Vector2, offset_x: float,
		band_y: float) -> void:
	clip.position = Vector2(offset_x, band_y)
	clip.size = Vector2(DESIGN_WIDTH, CABINET_STRIP_H)
	tex.size = win
	tex.position = Vector2(-offset_x, -band_y)

## EXPAND keeps DESIGN_HEIGHT fixed and grows get_viewport_rect().size.x to
## fill a wider window (measured directly, see the CLAUDE.md entry for this
## round) — pinned at the LEFT edge, not centered, same as KEEP_WIDTH pins its
## own extra height at the top. A Camera2D fixed at the design canvas's own
## center re-centers it for free: Camera2D always shows a viewport-sized
## window centered ON the camera's position, so a camera sitting exactly on
## the lane's own center (270, 480) makes the visible margin equal on both
## sides for ANY viewport width, with no per-resize recalculation needed —
## the same "fixed camera, never move it" principle the global CLAUDE.md
## documents for vertical centering, applied to the horizontal case here.
## Left disabled outside cabinet mode: KEEP already shows exactly this same
## view with no camera at all (a fixed camera here would be a no-op for it),
## but KEEP_WIDTH's whole point is pinning content to the TOP, not centering
## it — an active camera would fight that.
func _set_cabinet_camera_active(cabinet: bool) -> void:
	if cabinet and not is_instance_valid(_cabinet_cam):
		_cabinet_cam = Camera2D.new()
		_cabinet_cam.position = Vector2(DESIGN_WIDTH * 0.5, DESIGN_HEIGHT * 0.5)
		add_child(_cabinet_cam)
	if is_instance_valid(_cabinet_cam):
		_cabinet_cam.enabled = cabinet
		if cabinet:
			_cabinet_cam.make_current()

## HUD/Menus are CanvasLayers, which deliberately don't inherit ancestor
## Node2D transforms (that's the whole point of CanvasLayer) - so the
## Camera2D above re-centers the game WORLD but not these, and they need the
## same centering applied by hand. NOT via CanvasLayer.offset, despite that
## looking like the obvious tool — tried first, and found (live, on Linux)
## to be wrong: HUD/Menus's own root Controls default to PRESET_FULL_RECT,
## sized to match the CanvasLayer's own (now widened) viewport rect, so an
## .offset just translates that same oversized rect sideways rather than
## narrowing it — CenterContainer content ends up centered on the WRONG,
## still-1706-wide rect, and edge-anchored elements (Stage, PauseButton)
## pin to ITS corners instead of the lane's. See set_cabinet_lane() on Hud/
## Menus/space_background.gd instead: constrains each to a genuine, fixed
## 540-wide rect positioned at the current offset. Re-run on every resize
## (see the size_changed connection in _ready()) since, unlike the camera,
## this genuinely depends on the current excess width.
func _center_canvas_layers(cabinet: bool) -> void:
	var offset_x := 0.0
	if cabinet:
		offset_x = maxf(get_viewport_rect().size.x - DESIGN_WIDTH, 0.0) * 0.5
	_hud.set_cabinet_lane(cabinet, offset_x)
	_menus.set_cabinet_lane(cabinet, offset_x)
	_space_bg.set_cabinet_lane(cabinet, offset_x)

func apply_touch_layout() -> void:
	# Not gated on _wants_cabinet_overlay() any more — see _ready()'s _touch
	# computation for why window shape alone no longer decides this.
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

## Works regardless of pause state (same "always processes" reasoning as the
## pause action itself, see _unhandled_input()) — muting while paused should
## take effect immediately, not wait for the game to resume.
func _toggle_mute() -> void:
	if not _snd:
		return
	_hud.set_muted(_snd.toggle_mute())

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
	# Bonus Level: replaces the whole normal formation/fly-in for this stage
	# number, every bonus_level_interval stages (0 = off). Checked here, not
	# in _process()'s stage-clear block, so it also fires correctly right
	# after a fresh _new_run() lands on stage 1 in the (silly but possible)
	# case of interval == 1.
	var interval := int(_cfg.get("bonus_level_interval", 0))
	if interval > 0 and _stage % interval == 0:
		_hud.flash_banner("BONUS LEVEL")
		if _snd:
			_snd.play("stage")
		await get_tree().create_timer(Hud.BANNER_TOTAL, false).timeout
		if not is_instance_valid(self) or _state != READY:
			return
		if not await _wait_sound_then_gap("stage"):
			return
		_hud.hide_banner()
		_state = BONUS
		_start_bonus_level()
		return
	_hud.flash_banner("STAGE %d" % _stage)
	# Stage 1 of a fresh run has its own, much longer intro (6.9 s,
	# start-first-level-music) — that IS the fanfare there, so the 2.6 s
	# stage jingle stays silent instead of playing on top of it.
	if _snd and not _intro_gate_active:
		_snd.play("stage")
	await get_tree().create_timer(Hud.BANNER_TOTAL, false).timeout
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

# --- Bonus Level -----------------------------------------------------
## Fires each wave in turn (enemy-wave1.ogg re-announces every single one,
## per the user's plan for this sound key — see CLAUDE.md item 11), waits for
## all of a wave's enemies to resolve before starting the next, then moves on
## to the next normal stage. Aborts cleanly if the run leaves BONUS meanwhile
## (pause doesn't count — the tree itself freezes then; this only guards
## against title/game-over).
func _start_bonus_level() -> void:
	_bonus_hits = 0
	# Not a fixed BONUS_WAVE_COUNT * BONUS_ENEMIES_PER_WAVE any more — a Twin
	# ship doubles a wave's actual enemy count (see _run_bonus_wave()), and
	# since ramming a bonus_enemy can now cost a life (and with it the Twin
	# bonus) mid-level, the total isn't knowable up front. _run_bonus_wave()
	# adds to this as each wave actually spawns.
	_bonus_total = 0
	_bonus_points = 0
	_bonus_abort = false
	var vp := Vector2(DESIGN_WIDTH, get_viewport_rect().size.y)
	# Three separate flights, one after another, each its own vertical column
	# at a different x ("von unterschiedlichen Stellen aus") — never a Boss
	# (see the class doc above). Only two non-Boss kinds exist, so consecutive
	# flights alternate ZAKO/GOEI/ZAKO — a deliberate, documented choice (see
	# CLAUDE.md), not an oversight. Speed escalates wave to wave (see
	# BONUS_WAVE_SPEEDS) for a bit of ramping challenge.
	var wave_defs := [
		{"kind": EnemyKinds.ZAKO, "x": vp.x * 0.25, "speed": BONUS_WAVE_SPEEDS[0]},
		{"kind": EnemyKinds.GOEI, "x": vp.x * 0.75, "speed": BONUS_WAVE_SPEEDS[1]},
		{"kind": EnemyKinds.ZAKO, "x": vp.x * 0.50, "speed": BONUS_WAVE_SPEEDS[2]},
	]
	for wd in wave_defs:
		if _state != BONUS or _bonus_abort:
			return
		await _run_bonus_wave(wd["kind"], wd["x"], wd["speed"])
	if _state != BONUS or _bonus_abort:
		return
	_finish_bonus_level()

func _run_bonus_wave(kind: int, column_x: float, base_speed: float) -> void:
	if _snd:
		_snd.play("enemy-wave1")
	var vis := EnemyKinds.pick_visual(kind, _stage)
	var tex: String = vis["frames"][0] if vis.get("frames", []).size() == 2 else vis["texture"]
	var vp := get_viewport_rect().size
	# Dead straight, top to bottom — "eine quasi senkrechte Linie, die man von
	# einem Punkt aus abschießen kann" (user spec). No horizontal drift at all:
	# the player parks under column_x once and never has to re-track a moving
	# line. Twin ship (two guns) gets a second parallel column instead of one
	# (user request) — checked fresh per wave since a ram can revert the Twin
	# bonus mid-level.
	var twin: bool = is_instance_valid(_ship) and _ship._twin
	var columns: Array[float] = [column_x]
	if twin:
		columns = [column_x - BONUS_TWIN_ROW_GAP * 0.5, column_x + BONUS_TWIN_ROW_GAP * 0.5]
	var curves: Array[Curve2D] = []
	for col_x in columns:
		var curve := Curve2D.new()
		curve.add_point(Vector2(col_x, -60.0))
		curve.add_point(Vector2(col_x, vp.y + 60.0))
		curves.append(curve)
	_bonus_total += BONUS_ENEMIES_PER_WAVE * columns.size()
	for i in BONUS_ENEMIES_PER_WAVE:
		if _state != BONUS or _bonus_abort:
			return
		for curve in curves:
			var e := BONUS_ENEMY_SCENE.instantiate()
			add_child(e)
			e.killed.connect(_on_bonus_enemy_killed)
			# Per-member jitter on top of the wave's base speed (user request: a
			# perfectly even, single-speed queue felt too predictable) — no two
			# members of the same wave move at quite the same pace.
			var spd := base_speed * randf_range(1.0 - BONUS_SPEED_JITTER, 1.0 + BONUS_SPEED_JITTER)
			e.setup(kind, curve, tex, float(vis["scale"]), spd)
		await get_tree().create_timer(BONUS_LAUNCH_GAP, false).timeout
	# Every chain member frees itself on death or on reaching the bottom of the
	# track (bonus_enemy.gd) and, doing so, automatically drops out of this
	# group — waiting for the group to empty out is therefore the whole "wave
	# cleared" check.
	#
	# The PREVIOUS version instead counted a plain `var pending := 6` down
	# inside a per-enemy signal-connected lambda (`e.resolved.connect(func():
	# pending -= 1)`). That never worked: GDScript lambdas capture value-type
	# locals like int BY VALUE — `pending -= 1` only ever mutated the lambda's
	# own private copy, never the outer `pending` this loop actually checked.
	# `pending` therefore never reached 0, the wave (and the whole Bonus Level)
	# hung forever after the last enemy died — exactly the "game logic never
	# notices a wave got cleared" bug the user reported.
	while not get_tree().get_nodes_in_group("bonus_wave_active").is_empty():
		await get_tree().process_frame
		if _state != BONUS or _bonus_abort:
			return
	await get_tree().create_timer(BONUS_WAVE_PAUSE, false).timeout

func _on_bonus_enemy_killed(points: int) -> void:
	_bonus_hits += 1
	if _ship._hyper_ammo:
		points *= 2
	_bonus_points += points
	_score += points
	_hud.set_score(_score)

## No ship-warp transition here any more (2026-09-14 user report: the warp
## animation "looks bad" both for a twin ship and for a single ship) — the
## ship never actually left the screen during a Bonus Level, so there's
## nothing to materialize; just show the banner and go straight to the next
## stage's "STAGE n" sequence.
func _finish_bonus_level() -> void:
	var perfect := _bonus_hits == _bonus_total
	# A raw "N/18" hit count could read wrong even when every enemy WAS shot
	# down (a since-fixed bug briefly double-counted some kills, e.g. "23/18"
	# — user report) — showing the points actually earned instead sidesteps
	# that confusion entirely and is more meaningful anyway (user request).
	_hud.flash_banner(("PERFECT! +%d" % _bonus_points) if perfect else ("BONUS: +%d" % _bonus_points))
	if _snd:
		_snd.play("bonus-stage-cleared" if perfect else "level-cleared")
	await get_tree().create_timer(Hud.BANNER_TOTAL, false).timeout
	if not is_instance_valid(self) or _state != BONUS:
		return
	_hud.hide_banner()
	_stage += 1
	_start_ready()

## Called from _on_ship_died() once a ship lost mid-Bonus-Level has actually
## respawned — the same banner+wait+next-stage tail as _finish_bonus_level()
## above, except it never shows "PERFECT!" (the level was cut short, not
## completed on its own terms) and doesn't wait on the by-then-already-stopped
## wave coroutine (_bonus_abort took care of that in _on_ship_died()).
func _finish_bonus_level_early() -> void:
	_hud.flash_banner("BONUS: +%d" % _bonus_points)
	if _snd:
		_snd.play("level-cleared")
	await get_tree().create_timer(Hud.BANNER_TOTAL, false).timeout
	if not is_instance_valid(self) or _state != BONUS:
		return
	_hud.hide_banner()
	_stage += 1
	_start_ready()

## Waits until `key` has stopped playing (skips the wait if it isn't), then
## STAGE_JINGLE_GAP more. False if the run left READY meanwhile (menu, title).
func _wait_sound_then_gap(key: String) -> bool:
	while _snd and _snd.is_playing(key):
		await get_tree().process_frame
		if not is_instance_valid(self) or _state != READY:
			return false
	await get_tree().create_timer(STAGE_JINGLE_GAP, false).timeout
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
	# Stop the dive/capture lottery for the whole death sequence (explosion +
	# reconstruct/respawn) — enemies previously kept diving, throwing bombs,
	# and making noise the entire time despite the player having no ship to
	# react with or shoot back with, which read as confusing (user report).
	# Resumed via _director.resume_attacks() once the new ship is actually up
	# (see below) — not called at all if the run ends in game-over instead.
	_director.stop_attacks()
	# Losing a ship DURING a Bonus Level ends just that level, not the whole
	# stage cycle (user request 2026-09-15) — no other stage has ever cut
	# short like this on a lost ship. Flagged here (not via _state directly,
	# see _bonus_abort's own doc comment for why) and acted on further down,
	# once the ship has actually respawned.
	var was_bonus := _state == BONUS
	if was_bonus:
		_bonus_abort = true
		for n in get_tree().get_nodes_in_group("bonus_wave_active"):
			n.queue_free()
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
		await get_tree().create_timer(GAME_OVER_DELAY, false).timeout
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
		_director.resume_attacks()
		if was_bonus:
			await _finish_bonus_level_early()

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
	if event.is_action_pressed("mute"):
		_toggle_mute()

func _process(delta: float) -> void:
	# Belt-and-suspenders against get_window().size_changed not firing for
	# every kind of desktop resize (see _ready()'s connection to
	# _apply_display_mode() for the live-tested specifics) — a plain
	# Vector2i comparison every frame is cheap enough to just always run,
	# unconditionally, ahead of every early-return below (a resize must be
	# picked up regardless of game state — title screen, paused, mid-run).
	var win_now := DisplayServer.window_get_size()
	if win_now != _last_window_size:
		_last_window_size = win_now
		_apply_display_mode()

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
	for group in ["enemy", "player_lasers", "enemy_shots", "bonus_item", "bonus_transient"]:
		for n in get_tree().get_nodes_in_group(group):
			n.queue_free()
	_formation.reset()
