extends ColorRect

## The shader's two-layer star parallax was written for a scrolling/camera-
## following game (view_offset = camera position) — galaga has a fixed
## camera, so that offset never changed and the starfield just sat still.
## Feeding it a steadily increasing downward offset instead gives the classic
## "streaming past" shmup starfield without touching the shader's parallax
## math at all.
const SCROLL_SPEED := 22.0

var _elapsed := 0.0

func _process(delta: float) -> void:
	_elapsed += delta
	material.set_shader_parameter("view_offset", Vector2(0.0, _elapsed * SCROLL_SPEED))
