extends AnimatedSprite2D

## One-shot "ship materializing" animation (ship-(re)construction.gif, 28
## frames) — played at the start of every run (stage 1) and on every respawn,
## replacing a flat timer wait with something that actually shows what's
## happening. Frees itself when the animation finishes.

signal build_done

const FRAME_COUNT := 28
const FPS := 16.0
const DISPLAY_SCALE := 0.85  # roughly matches the real ship's on-screen size

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	scale = Vector2.ONE * DISPLAY_SCALE
	var frames := SpriteFrames.new()
	frames.add_animation("build")
	frames.set_animation_speed("build", FPS)
	frames.set_animation_loop("build", false)
	for i in FRAME_COUNT:
		frames.add_frame("build", load("res://assets/graphics/reconstruct_f%02d.png" % i))
	sprite_frames = frames
	animation_finished.connect(_on_finished)
	play("build")

func _on_finished() -> void:
	build_done.emit()
	queue_free()
