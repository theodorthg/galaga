extends Area2D

## Occasional bonus pickup — one of a curated set of "gallery" ship icons cut
## out of achivements.jpg (see galaga's CLAUDE.md, "Bonus-Sammelobjekte", for
## how the cutout was done and why a few indices are excluded). Fly through it
## or shoot it to collect: same fixed bonus either way, no precision test.
## Drifts down slowly with a gentle side-to-side sway; despawns unclaimed if
## it reaches the bottom, no penalty.

const POINTS := 500
const FALL_SPEED := 110.0
const SWAY_AMPLITUDE := 26.0
const SWAY_SPEED := 1.6
const DISPLAY_H := 34.0

# 5, 6, 7 dropped: heavy nebula-background residue survived the automated
# cutout (dense haze patch in that part of the source grid).
const ICON_INDICES := [0, 1, 2, 3, 4, 8, 9, 10, 11, 12, 13, 14, 15]

signal collected(points, icon)

var _t := 0.0
var _base_x := 0.0
var _icon_tex: Texture2D

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _col: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("bonus_item")
	area_entered.connect(_on_area_entered)
	_base_x = position.x
	var idx: int = ICON_INDICES.pick_random()
	_icon_tex = load("res://assets/graphics/achievement_%02d.png" % idx)
	_sprite.texture = _icon_tex
	_sprite.scale = Vector2.ONE * (DISPLAY_H / float(_icon_tex.get_height()))
	var circ := CircleShape2D.new()
	circ.radius = DISPLAY_H * 0.5
	_col.shape = circ

func _process(delta: float) -> void:
	_t += delta
	position.y += FALL_SPEED * delta
	position.x = _base_x + sin(_t * SWAY_SPEED) * SWAY_AMPLITUDE
	if position.y > get_viewport_rect().size.y + 40.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_lasers"):
		area.queue_free()
		_collect()
	elif area.is_in_group("player"):
		_collect()

func _collect() -> void:
	collected.emit(POINTS, _icon_tex)
	queue_free()
