class_name Formation
extends Node2D

## The Galaga formation grid: 40 slots in 5 rows. Owns slot geometry, the
## whole-block "breathing" sway, and which slot holds which live enemy.
## Enemies are NOT children of this node — they follow world-space entry
## curves first and then lock onto slot_global(idx) every frame.

const COL_SPACING := 44.0
const ROW_SPACING := 52.0
const SWAY_AMP := 24.0
const SWAY_SPEED := 0.7          # rad/s
const FLAP_INTERVAL := 0.28      # 2-frame wing-flap cadence for every enemy

# row layout, top -> bottom: [kind, count]  (4 + 8 + 8 + 10 + 10 = 40)
const ROWS := [
	[EnemyKinds.BOSS, 4],
	[EnemyKinds.GOEI, 8],
	[EnemyKinds.GOEI, 8],
	[EnemyKinds.ZAKO, 10],
	[EnemyKinds.ZAKO, 10],
]

var home := Vector2(270, 214)

var _slots_local: Array[Vector2] = []
var _slot_kind: Array[int] = []
var _occupant: Array = []        # Node or null, len == slot count
var _time := 0.0
var flap := false
var _flap_t := 0.0

signal flap_toggled(state: bool)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE  # freeze on pause, not inherit Game's ALWAYS
	_build_slots()
	_occupant.resize(_slots_local.size())
	position = home

func _build_slots() -> void:
	if not _slots_local.is_empty():
		return
	var r := 0
	for row in ROWS:
		var count: int = row[1]
		for i in count:
			var x := (i - (count - 1) / 2.0) * COL_SPACING
			_slots_local.append(Vector2(x, r * ROW_SPACING))
			_slot_kind.append(row[0])
		r += 1

func slot_count() -> int:
	return _slots_local.size()

func slot_kind(idx: int) -> int:
	return _slot_kind[idx]

func slot_local(idx: int) -> Vector2:
	return _slots_local[idx]

func slot_global(idx: int) -> Vector2:
	return to_global(_slots_local[idx])

func assign(idx: int, enemy: Node) -> void:
	_occupant[idx] = enemy

func release(enemy: Node) -> void:
	var i := _occupant.find(enemy)
	if i != -1:
		_occupant[i] = null

func reset() -> void:
	for i in _occupant.size():
		_occupant[i] = null

func live_count() -> int:
	var n := 0
	for o in _occupant:
		if o != null and is_instance_valid(o):
			n += 1
	return n

func _process(delta: float) -> void:
	_time += delta
	position.x = home.x + sin(_time * SWAY_SPEED) * SWAY_AMP

	_flap_t += delta
	if _flap_t >= FLAP_INTERVAL:
		_flap_t -= FLAP_INTERVAL
		flap = not flap
		flap_toggled.emit(flap)
