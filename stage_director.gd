class_name StageDirector
extends Node2D

## Orchestrates a stage's fly-in: splits the 40 formation slots into groups of
## 8, sends each group in along one entry curve with a per-enemy launch delay,
## and reports `stage_populated` once every spawned enemy has either locked into
## formation or been destroyed.

const ENEMY_SCENE := preload("res://enemy.tscn")
const GROUP_SIZE := 8
const GROUP_GAP := 0.9      # s between successive groups launching
const LAUNCH_GAP := 0.16    # s between enemies within a group

var _formation: Formation
var _spawn_parent: Node
var _pending := 0
var _spawning := false

signal stage_populated
signal enemy_killed(points)

func setup(formation: Formation, spawn_parent: Node) -> void:
	_formation = formation
	_spawn_parent = spawn_parent

func start_stage(stage: int) -> void:
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
