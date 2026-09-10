extends Area2D

## Enemy shot, dropped by diving enemies. Falls, slightly homing toward the
## player's x at spawn. Placeholder art (procedural) like the rest for now.

var _vel := Vector2(0, 430)

func _ready() -> void:
	add_to_group("enemy_shots")
	area_entered.connect(_on_area_entered)
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var dx: float = clampf(player.global_position.x - global_position.x, -140.0, 140.0)
		_vel.x = dx * 0.9
	queue_redraw()

func _process(delta: float) -> void:
	position += _vel * delta
	if position.y > get_viewport_rect().size.y + 40.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_lasers"):
		# player can shoot bombs out of the air
		area.queue_free()
		queue_free()

func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -7), Vector2(4, 0), Vector2(0, 7), Vector2(-4, 0),
	]), Color("ffd23f"))
	draw_circle(Vector2(0, 0), 2.0, Color("fff6cf"))
