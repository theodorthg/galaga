class_name StageDirector
extends Node2D

## Runs a stage:
##  1. fly-in — 40 slots split into groups of 8, each group in on one entry
##     curve; emits `stage_populated` once every spawned enemy has locked in
##     or been destroyed.
##  2. attacks — once `begin_attacks()` is called, periodically sends a random
##     formation enemy diving (capped at `_atk.max_divers` at once).
##
## `configure()` overrides the attack tuning from the difficulty setting.
## `abort()` cancels an in-flight fly-in (used on quit-to-title).

const ENEMY_SCENE := preload("res://enemy.tscn")
const GROUP_SIZE := 8
const GROUP_GAP := 0.9
const LAUNCH_GAP := 0.16

const ATTACK_DEFAULT := {"first": 1.8, "min": 1.3, "max": 3.2, "max_divers": 3}
# Capture attempts run on their own clock instead of piggy-backing on the
# regular dive lottery (4 Bosses out of 40 enemies made that a rare fluke that
# read as "at most once a stage" rather than a real, repeatable threat).
const CAPTURE_CHANCE := 0.33      # rolled each time the interval below elapses
const CAPTURE_INTERVAL_MIN := 5.0
const CAPTURE_INTERVAL_MAX := 9.0
# How often a still-unfulfilled force_boss_capture() request (see below) gets
# retried while it waits for a Boss to actually become available.
const FORCED_RETRY_INTERVAL := 2.0

var _formation: Formation
var _spawn_parent: Node
var _pending := 0
var _spawning := false
var _attacks_on := false
var _attack_t := 0.0
var _capture_t := 0.0
var _atk := ATTACK_DEFAULT.duplicate()
var _run_id := 0
var _forced_pending := false
var _forced_retry_t := 0.0
# Hard cap: at most ONE capture attempt per stage, whichever trigger asks for
# it (random roll or a "boss every N points" threshold). Without this, the
# only brake was "no new capture while a Boss is still CARRYING a ship" —
# the moment that Boss got shot (rescue), the next attempt could start in the
# very same stage, and every capture costs a life (user report: two Bosses
# with stolen ships on screen at once, reserve drained). A threshold request
# (_forced_pending) that hits this cap simply stays pending for the next stage.
var _capture_done_this_stage := false

signal stage_populated
signal enemy_killed(points, kind, variant_idx, was_carrying_captive)
signal ship_rescued(at_position)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE  # freeze on pause, not inherit Game's ALWAYS

func setup(formation: Formation, spawn_parent: Node) -> void:
	_formation = formation
	_spawn_parent = spawn_parent

func configure(params: Dictionary) -> void:
	for k in params:
		_atk[k] = params[k]
	# Called once per fresh run (game.gd::_new_run()) — any force_boss_capture()
	# request left unfulfilled from a previous game no longer means anything
	# once the score resets.
	_forced_pending = false

# --- fly-in ------------------------------------------------------------
func start_stage(stage: int) -> void:
	_attacks_on = false
	_capture_done_this_stage = false
	_run_id += 1
	_run_stage(stage, _run_id)

func abort() -> void:
	_run_id += 1
	_attacks_on = false
	_spawning = false
	_pending = 0
	_forced_pending = false

func _run_stage(stage: int, run_id: int) -> void:
	_spawning = true
	_pending = 0
	var vp := get_viewport_rect().size
	var total := _formation.slot_count()
	var patterns := [EntryPaths.BOTTOM_UP, EntryPaths.TOP_LEFT, EntryPaths.TOP_RIGHT]
	var group_count := int(ceil(float(total) / GROUP_SIZE))

	for g in group_count:
		var pattern: int = patterns[(g + stage - 1) % patterns.size()]
		var curve := EntryPaths.make(pattern, vp)
		for k in GROUP_SIZE:
			var idx := g * GROUP_SIZE + k
			if idx >= total:
				break
			_spawn(idx, curve, k * LAUNCH_GAP, stage)
		await get_tree().create_timer(GROUP_GAP, false).timeout
		if not is_instance_valid(self) or run_id != _run_id:
			return

	_spawning = false
	_check_done()

func _spawn(idx: int, curve: Curve2D, delay: float, stage: int) -> void:
	var e := ENEMY_SCENE.instantiate()
	_spawn_parent.add_child(e)
	e.resolved.connect(_on_resolved)
	e.killed.connect(func(pts: int, k: int, vi: int, carrying: bool): enemy_killed.emit(pts, k, vi, carrying))
	e.ship_rescued.connect(func(pos): ship_rescued.emit(pos))
	_pending += 1
	e.setup(_formation.slot_kind(idx), _formation, idx, curve, delay, stage)

func _on_resolved() -> void:
	_pending -= 1
	_check_done()

func _check_done() -> void:
	if not _spawning and _pending <= 0:
		stage_populated.emit()

# --- attacks ---------------------------------------------------------
func begin_attacks() -> void:
	_attacks_on = true
	_attack_t = _atk["first"]
	_capture_t = randf_range(CAPTURE_INTERVAL_MIN, CAPTURE_INTERVAL_MAX)

func stop_attacks() -> void:
	_attacks_on = false

## Re-enables the dive/capture timers after a temporary freeze (ship.gd death
## sequence, see game.gd::_on_ship_died()) WITHOUT resetting their countdowns
## to a fresh "first dive" wait like begin_attacks() does — the player just
## lost a ship, that's penalty enough; the attack cadence picks up exactly
## where stop_attacks() left it instead of restarting the whole rhythm.
func resume_attacks() -> void:
	_attacks_on = true

func _process(delta: float) -> void:
	if not _attacks_on:
		return
	_attack_t -= delta
	if _attack_t <= 0.0:
		_attack_t = randf_range(_atk["min"], _atk["max"])
		_launch_dive()
	_capture_t -= delta
	if _capture_t <= 0.0:
		_capture_t = randf_range(CAPTURE_INTERVAL_MIN, CAPTURE_INTERVAL_MAX)
		_try_capture_dive()
	if _forced_pending:
		_forced_retry_t -= delta
		if _forced_retry_t <= 0.0:
			_forced_retry_t = FORCED_RETRY_INTERVAL
			if _attempt_capture_dive():
				_forced_pending = false

## Bosses are excluded here — they're dedicated to capture attempts
## (_try_capture_dive() below). Previously they competed for the same random
## pick as everyone else, so a Boss "used up" on a plain dive was then
## unavailable when the capture timer fired, making genuine capture attempts
## rarer than CAPTURE_CHANCE alone would suggest.
func _launch_dive() -> void:
	var ready_to_dive: Array = []
	var divers := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.is_active_diver():
			divers += 1
		elif e.kind != EnemyKinds.BOSS and e.is_available_to_dive():
			ready_to_dive.append(e)
	if divers >= int(_atk["max_divers"]) or ready_to_dive.is_empty():
		return
	(ready_to_dive.pick_random() as Node).dive()

## Called from game.gd whenever the score crosses a "boss every N points"
## threshold (GameSettings.boss_interval) — a guaranteed attempt on top of the
## per-interval random chance above, so a Boss capture isn't left purely to
## luck. Doesn't try to force a capture through immediately: the exact moment
## a threshold is crossed there may be no Boss free (mid fly-in, all Bosses
## already diving/capturing/carrying a captive, a stage transition in
## progress...). Instead it just raises a flag that _process() above keeps
## retrying every FORCED_RETRY_INTERVAL seconds — including across a stage
## change or the player losing a ship in between — until a Boss is actually
## available. This is what fixed "no forced Boss until 15000 points despite a
## 5000 setting": the old one-shot version silently gave up the instant a
## single attempt failed, wasting that threshold for the rest of the run.
func force_boss_capture() -> void:
	_forced_pending = true
	_forced_retry_t = 0.0  # try on the very next _process() tick

## Independent of _launch_dive() above: every CAPTURE_INTERVAL_MIN..MAX seconds,
## roll CAPTURE_CHANCE for a formation Boss to peel off on a capture attempt
## instead of waiting to maybe get picked by the regular dive lottery.
func _try_capture_dive() -> void:
	if randf() >= CAPTURE_CHANCE:
		return
	_attempt_capture_dive()

## Returns true if a Boss actually started a capture attempt just now.
func _attempt_capture_dive() -> bool:
	if _capture_done_this_stage:
		return false
	# Never send a Boss after a ship that isn't actually there — mid-explosion
	# or mid-reconstruct (ship.gd's _alive == false), there's nothing to catch,
	# and a capture attempt right then reads as a Boss "capturing" a ship the
	# player only just lost (user report: this condition wasn't checked at all).
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player._alive:
		return false
	var divers := 0
	var bosses: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.is_carrying_captive():
			return false  # only one captive ship in play at a time (arcade original)
		if e.is_active_diver():
			divers += 1
		elif e.kind == EnemyKinds.BOSS and e.is_available_to_dive():
			bosses.append(e)
	if divers >= int(_atk["max_divers"]) or bosses.is_empty():
		return false
	(bosses.pick_random() as Node).capture_dive()
	_capture_done_this_stage = true
	return true
