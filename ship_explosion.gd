extends AnimatedSprite2D

## One-shot "ship destroyed" explosion (assets/explosion and laser.png, 4
## hand-picked frames: spark -> burst -> bright peak -> smoky fade) — played
## whenever the ship is actually HIT (laser/bomb/diving enemy), same pattern
## as ship_reconstruct.gd. Deliberately NOT played when the ship is caught by
## a Boss's tractor beam instead (see ship.gd::_destroy()'s show_explosion
## parameter) — a capture isn't a destruction, no boom for it.

signal explosion_done

const FRAME_COUNT := 4
const FPS := 10.0
const DISPLAY_SCALE := 0.5  # peak frame's bloom lands close to the ship's own on-screen size

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	scale = Vector2.ONE * DISPLAY_SCALE
	var frames := SpriteFrames.new()
	frames.add_animation("boom")
	frames.set_animation_speed("boom", FPS)
	frames.set_animation_loop("boom", false)
	for i in FRAME_COUNT:
		frames.add_frame("boom", load("res://assets/graphics/ship_explosion_f%d.png" % i))
	sprite_frames = frames
	animation_finished.connect(_on_finished)
	play("boom")

func _on_finished() -> void:
	explosion_done.emit()
	queue_free()
