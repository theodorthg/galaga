extends Area2D

func _ready() -> void:
	# Wir verbinden das Kollisions-Signal, um Treffer zu bemerken
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	# Hat uns ein Laser des Spielers getroffen?
	if area.is_in_group("player_lasers"):
		# 1. Den Laser zerstören, der uns getroffen hat
		area.queue_free()
		
		# 2. Uns selbst (den Gegner) zerstören
		queue_free()
