extends Area2D

# Der Laser ist meistens deutlich schneller als das Schiff
var speed := 850.0

func _ready() -> void:
	# Game.process_mode=ALWAYS (fürs Pausenmenü) würde sich sonst vererben —
	# explizit PAUSABLE, damit Laser bei Pause einfrieren statt weiterzufliegen.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# Signal des Notifiers verbinden: wann verlässt der Laser den Schirm?
	var notifier = $VisibleOnScreenNotifier2D
	if notifier:
		notifier.screen_exited.connect(_on_screen_exited)
	queue_redraw()

func _process(delta: float) -> void:
	# In Godot ist "oben" auf der Y-Achse negativ.
	position.y -= speed * delta

func _on_screen_exited() -> void:
	queue_free()

# Temporärer Platzhalter statt des zu großen laser.png — kurzer heller Strich.
func _draw() -> void:
	draw_rect(Rect2(-1.5, -8.0, 3.0, 16.0), Color("cfefff"))
	draw_rect(Rect2(-1.5, -8.0, 3.0, 5.0), Color.WHITE)
