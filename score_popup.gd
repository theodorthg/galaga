extends Node2D

## Small floating "+points" text shown briefly at the exact spot a bonus_item
## was caught, then fades upward and frees itself. Deliberately NOT used for
## enemy kills (per user request) — only bonus_item pickups get this.

const RISE := 26.0
const DURATION := 0.7
const FONT_SIZE := 18

var text := ""
var color := Color.WHITE

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var t := create_tween()
	t.tween_property(self, "position:y", position.y - RISE, DURATION)
	t.parallel().tween_property(self, "modulate:a", 0.0, DURATION)
	t.tween_callback(queue_free)

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var pos := Vector2(-w * 0.5, 0.0)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 3, Color(0, 0, 0, 0.85))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
