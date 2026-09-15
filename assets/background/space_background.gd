extends ColorRect

## The shader's two-layer star parallax was written for a scrolling/camera-
## following game (view_offset = camera position) — galaga has a fixed
## camera, so that offset never changed and the starfield just sat still.
## Feeding it a steadily increasing downward offset instead gives the classic
## "streaming past" shmup starfield without touching the shader's parallax
## math at all.
const SCROLL_SPEED := 22.0

## See ship.gd::DESIGN_WIDTH/game.gd::DESIGN_HEIGHT.
const DESIGN_WIDTH := 540.0
const DESIGN_HEIGHT := 960.0

var _elapsed := 0.0

func _process(delta: float) -> void:
	_elapsed += delta
	material.set_shader_parameter("view_offset", Vector2(0.0, _elapsed * SCROLL_SPEED))

## Called by game.gd::_center_canvas_layers() — this ColorRect defaults to
## PRESET_FULL_RECT (anchors tied to the CanvasLayer's own viewport-sized
## rect), which is exactly right normally (viewport IS the 540-wide lane) but
## WRONG once CONTENT_SCALE_ASPECT_EXPAND widens that viewport for the
## landscape-cabinet-overlay case: a full-rect background would then stretch
## across the WHOLE wide window instead of just the centered lane, leaving a
## visible seam where it doesn't match up with the world content the fixed
## Camera2D shows (confirmed live on Linux — this function exists precisely
## because that bug was caught, not preemptively). Swaps to a fixed
## 540x960 rect positioned at the current centering offset instead; restores
## the original full-rect behavior (unneeded elsewhere, since KEEP/KEEP_WIDTH
## never make the viewport wider than 540) when cabinet mode ends.
func set_cabinet_lane(active: bool, offset_x: float) -> void:
	if active:
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		size = Vector2(DESIGN_WIDTH, DESIGN_HEIGHT)
		position = Vector2(offset_x, 0.0)
	else:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		position = Vector2.ZERO
