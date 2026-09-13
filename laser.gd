class_name Laser
extends Area2D

# Der Laser ist meistens deutlich schneller als das Schiff
var speed := 850.0

## Flash color while in flight — a static beam read as too flat/lifeless.
## Ship.gd picks which one to hand a given shot: normal fire flickers
## white/turquoise; Hyper-Ammo (see ship.gd::activate_hyper_ammo) flickers
## white/red instead, so the two power levels are unmistakable at a glance.
const ACCENT_NORMAL := Color("40e0d0")
const ACCENT_HYPER := Color("ff4d4d")
const FLASH_TIME := 0.12

var accent_color := ACCENT_NORMAL

func _ready() -> void:
	# Game.process_mode=ALWAYS (fürs Pausenmenü) würde sich sonst vererben —
	# explizit PAUSABLE, damit Laser bei Pause einfrieren statt weiterzufliegen.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# Signal des Notifiers verbinden: wann verlässt der Laser den Schirm?
	var notifier = $VisibleOnScreenNotifier2D
	if notifier:
		notifier.screen_exited.connect(_on_screen_exited)
	queue_redraw()
	# modulate multiplies the _draw() colors below at render time, so this
	# flash needs no redraw of its own — just the tween.
	var t := create_tween()
	t.set_loops()
	t.tween_property(self, "modulate", accent_color, FLASH_TIME)
	t.tween_property(self, "modulate", Color.WHITE, FLASH_TIME)

func _process(delta: float) -> void:
	# In Godot ist "oben" auf der Y-Achse negativ.
	position.y -= speed * delta

func _on_screen_exited() -> void:
	queue_free()

# Temporärer Platzhalter statt des zu großen laser.png — kurzer heller Strich.
func _draw() -> void:
	draw_rect(Rect2(-1.5, -8.0, 3.0, 16.0), Color("cfefff"))
	draw_rect(Rect2(-1.5, -8.0, 3.0, 5.0), Color.WHITE)
