extends Area2D

## Occasional bonus pickup — one of a curated set of "gallery" ship icons cut
## out of achivements.jpg (see galaga's CLAUDE.md, "Bonus-Sammelobjekte", for
## how the cutout was done and why a few indices are excluded). Fly through it
## or shoot it to collect: same fixed bonus either way, no precision test.
## Drifts down slowly, sweeping side to side across the FULL screen width (not
## just a small wobble around the spawn point) so it isn't easy to just ignore
## in one corner; despawns unclaimed if it reaches the bottom, no penalty.

const POINTS := 500
const FALL_SPEED := 110.0
const SWAY_SPEED_MIN := 0.5
const SWAY_SPEED_MAX := 1.1
const DISPLAY_H := 34.0
# Margin keeps the icon's own half-width off the sway extremes so it never
# clips off-screen at the turnaround points.
const SIDE_MARGIN := 40.0

# 1, 5, 6, 7 dropped: 1 reads too easily as the player's own ship sprite
# (risk of confusion mid-fight); 5/6/7 still carry heavy nebula-background
# residue from the automated cutout (dense haze patch in that part of the
# source grid).
const ICON_INDICES := [0, 2, 3, 4, 8, 9, 10, 11, 12, 13, 14, 15]

## icon_index is passed along so game.gd can special-case achievement_00 (see
## ship.gd::activate_hyper_ammo) — every other index is just points. Position
## is passed too so game.gd can show a small "+points" popup at the exact
## spot the item was caught.
signal collected(points, icon, icon_index, at_position)

## Icon indices already showing in the HUD's current (unfinished) row — set by
## game.gd BEFORE add_child() (see the ordering note in _spawn_bonus_item()),
## so the same achievement never appears twice in one row. Always leaves
## plenty of choices: the row caps at hud.gd's BONUS_MAX_SHOWN (7), well under
## ICON_INDICES' 12 entries.
var exclude_indices: Array[int] = []

var _t := 0.0
var _base_x := 0.0
var _amplitude := 0.0
var _phase := 0.0
var _sway_speed := 1.0
var _icon_tex: Texture2D
var _icon_idx := -1

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _col: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("bonus_item")
	area_entered.connect(_on_area_entered)
	# Sweep the whole design width, not just wobble around wherever the
	# caller happened to place it — centered sine covering edge-to-edge.
	var vp_w := get_viewport_rect().size.x
	_base_x = vp_w * 0.5
	_amplitude = maxf(vp_w * 0.5 - SIDE_MARGIN, 0.0)
	_phase = randf_range(0.0, TAU)
	_sway_speed = randf_range(SWAY_SPEED_MIN, SWAY_SPEED_MAX)
	position.x = _base_x + sin(_phase) * _amplitude
	var available := ICON_INDICES.filter(func(i): return i not in exclude_indices)
	if available.is_empty():
		available = ICON_INDICES  # shouldn't happen (7-slot row vs 12-icon pool), but never crash
	_icon_idx = available.pick_random()
	_icon_tex = load("res://assets/graphics/achievement_%02d.png" % _icon_idx)
	_sprite.texture = _icon_tex
	_sprite.scale = Vector2.ONE * (DISPLAY_H / float(_icon_tex.get_height()))
	var circ := CircleShape2D.new()
	circ.radius = DISPLAY_H * 0.5
	_col.shape = circ

func _process(delta: float) -> void:
	_t += delta
	position.y += FALL_SPEED * delta
	position.x = _base_x + sin(_t * _sway_speed + _phase) * _amplitude
	if position.y > get_viewport_rect().size.y + 40.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_lasers"):
		area.queue_free()
		_collect()
	elif area.is_in_group("player"):
		_collect()

func _collect() -> void:
	collected.emit(POINTS, _icon_tex, _icon_idx, global_position)
	queue_free()
