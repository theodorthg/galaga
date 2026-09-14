extends AnimatedSprite2D

## One-shot "warp" transition (ship-warp-drive.gif, 19 frames) — played once,
## right after a Bonus Level is cleared, on the way to the next normal stage
## (see game.gd::_finish_bonus_level()). Same self-contained pattern as
## ship_reconstruct.gd/ship_explosion.gd: SpriteFrames built at runtime, a
## "done" signal, frees itself when finished.

signal warp_done

const FRAME_COUNT := 19
const FPS := 20.0
## Not verified against the real ship's on-screen size live (no MCP access
## this round, see CLAUDE.md) — 100x100 source, this is a best guess to land
## roughly ship-sized; revisit after the next playtest if it looks off.
const DISPLAY_SCALE := 1.2

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# Shared with bonus_enemy.gd purely so game.gd::_clear_board() can sweep
	# this away too if the player quits to the title screen mid-transition.
	add_to_group("bonus_transient")
	scale = Vector2.ONE * DISPLAY_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var frames := SpriteFrames.new()
	frames.add_animation("warp")
	frames.set_animation_speed("warp", FPS)
	frames.set_animation_loop("warp", false)
	for i in FRAME_COUNT:
		frames.add_frame("warp", load("res://assets/graphics/warp_f%02d.png" % i))
	sprite_frames = frames
	animation_finished.connect(_on_finished)
	play("warp")

func _on_finished() -> void:
	warp_done.emit()
	queue_free()
