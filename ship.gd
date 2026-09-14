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
## whole second ship rather than a tighter spread from the same gun. 14 px
## between the beam centres + the 9 px hitbox each = ~23 px of coverage per
## salvo vs. 9 px for a single beam (was 10 px / ~19 px — user asked for a
## clearly better hit chance than the plain laser, not just a visual double).
const HYPER_OFFSET := 14.0
## The main thruster's flame can reach up to its own max_length below the ship
## at full power (plus the GPU particle trail) — far enough to dip into the
## HUD's bottom-center bonus-icon row (hud.gd) on a tall/thin canvas. Shifting
## the resting position up by that length + a small safety margin keeps the
## flame clear of it regardless of how main_thruster.tscn's max_length is tuned.
const THRUSTER_CLEARANCE_MARGIN := 5.0
## Resting y is measured from the REAL viewport bottom, not a canvas-fixed
## value — on a touch device (CONTENT_SCALE_ASPECT_KEEP_WIDTH) get_viewport_
## rect().size.y reports MORE than the 960 design height (the extra room is
## deliberately free space for fingers below the fixed-canvas HUD/gameplay —
## see the global CLAUDE.md's touch note), so a ship pinned to a canvas-fixed
## y sat far above where bonus_item.gd/bomb.gd (which fall against this same
## real height) actually reach: achievements fell "past" the ship, uncatchable
## (user report), and the ship read as oddly high up with a lot of dead space
## below it. On desktop (CONTENT_SCALE_ASPECT_KEEP) get_viewport_rect().size.y
## is always exactly the design 960, so this reproduces the old fixed position
## (960 - 76 = 884, game.tscn's original override) there unchanged.
const HUD_BOTTOM_CLEARANCE := 76.0
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
## Set by enemy.gd for the whole span of a Boss capture attempt (capture_dive()
## through _begin_capture_beam()'s timer) — see set_capture_invulnerable()
## below for why this exists as its own flag instead of just reusing _invuln.
var _capture_invuln := false
var _capture_blink_t := 0.0
var _mouse_aim := false
var _mouse_down := false
## Actual finger-on-screen state — distinct from "this device supports touch
## at all". Auto-fire must track only this, not device capability (see
## _process()'s fire condition and _unhandled_input() below): a touch-capable
## device that's currently being driven by mouse/keyboard (Linux/Windows
## touchscreen laptops, the user's own example) must not keep firing just
## because a finger isn't actually down.
var _touch_down := false
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

## show_explosion is false only for a Boss tractor-beam capture (see
## _on_area_entered() below) — game.gd's handler plays ship_explosion.tscn
## at the ship's position and waits for it before reconstructing, but only
## when this is true (a capture isn't a destruction, no boom for it).
signal died(show_explosion: bool)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE  # freeze on pause, not inherit Game's ALWAYS
	add_to_group("player")
	add_to_group("touch_layout_listeners")
	_snd = get_node_or_null("/root/Snd")
	area_entered.connect(_on_area_entered)
	viewport_width = get_viewport_rect().size.x
	_update_home_y()

## See HUD_BOTTOM_CLEARANCE above for why this reads the real viewport height
## instead of using a value baked into the scene.
func _update_home_y() -> void:
	var vp_h := get_viewport_rect().size.y
	position.y = vp_h - HUD_BOTTOM_CLEARANCE - _thruster.max_length - THRUSTER_CLEARANCE_MARGIN

# group "touch_layout_listeners": first real touch event flips content_scale_
# aspect to KEEP_WIDTH (game.gd) — re-home once that's taken effect. Deferred
# since this call and game.gd's own group-call sibling can fire in either
# order within the same call_group(); by the next frame the aspect switch (and
# therefore get_viewport_rect()) is definitely settled. Only y moves here —
# x stays wherever the player currently is, so this doesn't yank the ship back
# to center mid-fight on the rare "browser reported touch late" case.
func apply_touch_layout() -> void:
	_update_home_y.call_deferred()

func _process(delta: float) -> void:
	if _capture_invuln:
		# Same blink as the post-respawn window below, just driven by a
		# steadily-increasing clock instead of a countdown — this window has
		# no fixed length (it lasts exactly as long as the Boss's current
		# capture attempt takes, see set_capture_invulnerable()).
		_capture_blink_t += delta
		modulate.a = 0.35 + 0.4 * (0.5 + 0.5 * sin(_capture_blink_t * 32.0))
	elif _invuln > 0.0:
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

	if _touch_down or _mouse_down or Input.is_action_pressed("shoot"):
		shoot()

func _unhandled_input(event: InputEvent) -> void:
	# Press/release state is tracked regardless of _alive: gating this behind
	# the alive check let a finger/mouse-button already held at the moment of
	# death leave _touch_down/_mouse_down stuck true (the release event during
	# the reconstruct animation was swallowed), which would auto-fire the
	# instant the new ship became alive again with no fresh press at all.
	if event is InputEventScreenTouch:
		_touch_down = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_down = event.pressed
	if not _alive:
		return
	if event is InputEventMouseMotion:
		_mouse_aim = true
	elif event is InputEventScreenDrag:
		position.x = clampf(position.x + event.relative.x,
			ship_half_width, viewport_width - ship_half_width)

func shoot() -> void:
	if _fire_cooldown_t > 0.0:
		return
	# The cap counts SALVOS, not beams: a Hyper-Ammo shot puts two lasers in
	# flight at once, so counting beams against max_shots meant one salvo
	# filled a 2-shot cap and the "bonus" fired at HALF the normal rate — a
	# downgrade (user report). Twin ships already double _max_lasers itself.
	var cap := _max_lasers * (2 if _hyper_ammo else 1)
	if get_tree().get_nodes_in_group("player_lasers").size() >= cap:
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
	var is_capture := area.is_in_group("capture_beam")
	# _capture_invuln blocks everything EXCEPT the capture beam's own contact —
	# that contact is the capture itself (still needs to reach _destroy() below
	# to hide the ship / trigger the respawn flow, just without an explosion).
	# Only bombs, rams, or (in principle) some other Boss's beam get ignored
	# during this window — see set_capture_invulnerable().
	if _capture_invuln and not is_capture:
		return
	if area.is_in_group("enemy_shots"):
		area.queue_free()
		_destroy(not is_capture)
	elif area.is_in_group("enemy") and area.is_active_diver():
		_destroy(true)

func _destroy(show_explosion := true) -> void:
	_alive = false
	visible = false
	set_deferred("monitoring", false)
	_revert_twin()  # twin bonus doesn't survive a hit, matches the arcade original
	if _snd:
		_snd.play("ship-destroyed")
	died.emit(show_explosion)

## Called by enemy.gd for the whole duration of a Boss capture attempt (from
## capture_dive() to just before _begin_return()) — user report/request
## 2026-09-14: the ship dying to something ELSE (a bomb, a ram, another Boss's
## own capture beam extending at the same time) mid-attempt made the capture
## itself abort with no reward, since ship.gd's own collision handling and
## capture_beam.gd's "caught" detection both fire off the very same beam-vs-
## ship overlap — trying to tell "died to something else" apart from "this is
## the catch itself" after the fact (e.g. checking _alive from the beam's side)
## is a losing race: both handlers respond to the identical physics event, so
## which one runs first isn't something to depend on (an earlier attempt at
## exactly that check made the capture fail almost every time — see CLAUDE.md).
## The user's own proposed fix, implemented here instead: while a capture is
## in progress, the ship simply CANNOT be destroyed by anything else at all —
## same blinking look as the post-respawn window (_invuln above), just for as
## long as the capture attempt takes rather than a fixed duration.
func set_capture_invulnerable(on: bool) -> void:
	_capture_invuln = on
	if not on and _invuln <= 0.0:
		modulate.a = 1.0

func respawn() -> void:
	position.x = viewport_width * 0.5
	_alive = true
	visible = true
	_invuln = RESPAWN_INVULN
	# Safety net for the vanishingly rare case where the Boss carrying the
	# capture attempt got freed (e.g. a quit-to-title mid-beam) before it could
	# call set_capture_invulnerable(false) itself — a fresh ship should never
	# start out permanently unkillable.
	_capture_invuln = false
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
