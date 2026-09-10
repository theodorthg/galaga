class_name StageDirector
extends Node2D

## Runs a stage:
##  1. fly-in — 40 slots split into groups of 8, each group in on one entry
##     curve; emits `stage_populated` once every spawned enemy has locked in
##     or been destroyed.
##  2. attacks — once `begin_attacks()` is called, periodically sends a random
##     formation enemy diving (capped at MAX_DIVERS at once).

const ENEMY_SCENE := preload("res://enemy.tscn")
const GROUP_SIZE := 8
const GROUP_GAP := 0.9
const LAUNCH_GAP := 0.16

const ATTACK_FIRST := 1.8
const ATTACK_MIN := 1.3
const ATTACK_MAX := 3.2
const MAX_DIVERS := 3

var _formation: Formation
var _spawn_parent: Node
var _pending := 0
var _spawning := false
var _attacks_on := false
var _attack_t := 0.0

signal stage_populated
signal enemy_killed(points)

func setup(formation: Formation, spawn_parent: Node) -> void:
	_formation = formation
	_spawn_parent = spawn_parent

# --- fly-in ------------------------------------------------------------
func start_stage(stage: int) -> void:
	_attacks_on = false
	_run_stage(stage)

func _run_stage(stage: int) -> void:
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
			_spawn(idx, curve, k * LAUNCH_GAP)
		await get_tree().create_timer(GROUP_GAP).timeout
		if not is_instance_valid(self):
			return

	_spawning = false
	_check_done()

func _spawn(idx: int, curve: Curve2D, delay: float) -> void:
	var e := ENEMY_SCENE.instantiate()
	_spawn_parent.add_child(e)
	e.resolved.connect(_on_resolved)
	e.killed.connect(func(pts: int): enemy_killed.emit(pts))
	_pending += 1
	e.setup(_formation.slot_kind(idx), _formation, idx, curve, delay)

func _on_resolved() -> void:
	_pending -= 1
	_check_done()

func _check_done() -> void:
	if not _spawning and _pending <= 0:
		stage_populated.emit()

# --- attacks ---------------------------------------------------------
func begin_attacks() -> void:
	_attacks_on = true
	_attack_t = ATTACK_FIRST

func stop_attacks() -> void:
	_attacks_on = false

func _process(delta: float) -> void:
	if not _attacks_on:
		return
	_attack_t -= delta
	if _attack_t > 0.0:
		return
	_attack_t = randf_range(ATTACK_MIN, ATTACK_MAX)
	_launch_dive()

func _launch_dive() -> void:
	var ready_to_dive: Array = []
	var divers := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.is_active_diver():
			divers += 1
		elif e.is_available_to_dive():
			ready_to_dive.append(e)
	if divers >= MAX_DIVERS or ready_to_dive.is_empty():
		return
	ready_to_dive.pick_random().dive()
