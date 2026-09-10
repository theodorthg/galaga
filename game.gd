class_name Game
extends Node2D

## Top-level level controller. State machine for now:
##   READY     — "STAGE n" banner, ~1.8 s
##   ENTERING  — StageDirector runs the fly-in
##   FORMATION — enemies sway and dive; clear them all -> next stage
## Lives, HUD and game-over land in phase 2.

enum { READY, ENTERING, FORMATION }

@onready var _formation: Formation = $Formation
@onready var _director: StageDirector = $StageDirector
@onready var _ship: Area2D = $Ship
@onready var _score_label: Label = $HUD/Score
@onready var _stage_label: Label = $HUD/StageFlash

var _state := READY
var _stage := 1
var _score := 0

func _ready() -> void:
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_director.setup(_formation, self)
	_director.stage_populated.connect(_on_stage_populated)
	_director.enemy_killed.connect(_on_enemy_killed)
	_ship.died.connect(_on_ship_died)
	_start_ready()

func _start_ready() -> void:
	_state = READY
	_director.stop_attacks()
	_stage_label.text = "STAGE %d" % _stage
	_stage_label.visible = true
	await get_tree().create_timer(1.8).timeout
	if not is_instance_valid(self):
		return
	_stage_label.visible = false
	_state = ENTERING
	_director.start_stage(_stage)

func _on_stage_populated() -> void:
	if _state == ENTERING:
		_state = FORMATION
		_director.begin_attacks()

func _on_enemy_killed(points: int) -> void:
	_score += points

func _on_ship_died() -> void:
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(_ship):
		_ship.respawn()

func _process(_delta: float) -> void:
	_score_label.text = "%06d" % _score
	if _state == FORMATION and _formation.live_count() == 0:
		_stage += 1
		_start_ready()
