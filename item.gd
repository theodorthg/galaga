extends Area2D

func play_floating_animation() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	var sprite_2d := get_node("Sprite2D")
	var target_position := Vector2(0.0, 4.0)
	var duration = randf_range(0.8, 1.2)
	tween.tween_property(sprite_2d, "position", target_position, duration)
	tween.tween_property(sprite_2d, "position",  -1.0 * target_position, duration)
	tween.set_loops()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	area_entered.connect(_on_area_entered)
	play_floating_animation()
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_area_entered(area_that_entered: Area2D) -> void:
	queue_free()
	
