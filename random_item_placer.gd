extends Node2D

var item_scenes := [
	preload("gem.tscn"),
	preload("health_pack.tscn")
]

var item_counter := 0
 
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_node("Timer").timeout.connect(_on_timer_timeout)

func _on_area_entered(area_entered) -> void:
	item_counter -= 1
	 
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func _on_timer_timeout() -> void:
	if item_counter < 6:
		var random_item_scene: PackedScene = item_scenes.pick_random()
		var item_instance := random_item_scene.instantiate()
		var viewport_size := get_viewport_rect().size
		var random_position := Vector2(0.0, 0.0)
		random_position.x = randf_range(0.0, viewport_size.x)
		random_position.y = randf_range(0.0, viewport_size.y)
		item_instance.position = random_position
		item_instance.area_entered.connect(_on_area_entered)
		add_child(item_instance)
		item_counter += 1
	
	
