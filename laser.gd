extends Area2D

# Der Laser ist meistens deutlich schneller als das Schiff
var speed := 850.0

func _ready() -> void:
	# Wir verbinden das Signal des Notifiers, um mitzubekommen, 
	# wann der Laser den sichtbaren Bereich verlässt.
	# print("!!!Der Laser ist aktiv!!!")
	var notifier = $VisibleOnScreenNotifier2D
	if notifier:
		notifier.screen_exited.connect(_on_screen_exited)
		
	# Wenn wir später Gegner haben, brauchen wir auch dieses Signal:
	# area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	# In Godot ist "oben" auf der Y-Achse negativ.
	# Der Laser bewegt sich also jeden Frame weiter nach oben.
	position.y -= speed * delta
	# NEU: Schießen abfragen
	
func _on_screen_exited() -> void:
	# queue_free() löscht den Node und alle seine Kinder sicher aus dem Speicher
	queue_free()

# (Vorbereitung für später)
# func _on_area_entered(area: Area2D) -> void:
# 	if area.is_in_group("enemy"):
# 		queue_free() # Laser zerstört sich selbst beim Treffer
