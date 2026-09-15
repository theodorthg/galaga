extends Node

## PARKED, NOT CURRENTLY WIRED UP (2026-09-15) — project.godot's
## run/main_scene points at res://game.tscn directly again, NOT this file.
## Kept around (code + comments) as a starting point for whoever picks this
## back up, since real work and two real findings went into it — see below —
## but it must NOT be re-enabled as-is: the current code in this file has a
## known, unresolved bug (explained below) that would break core gameplay
## math on every screen it activates for.
##
## GOAL: a device that can't rotate to portrait at all (user's Anbernic
## RG552) shows the portrait 540x960 game letterboxed with plain black bars
## left/right (game.gd::_apply_display_mode()'s normal KEEP behavior on a
## non-touch device). The idea was to fill those bars with the user's own
## arcade-cabinet artwork (arcade-screen1.png) instead of plain black.
##
## Godot's own canvas_items + KEEP stretch mode can't do this itself: the
## letterbox area it produces is genuinely outside the scene tree's reach —
## nothing can be drawn there, by design. Reproducing "KEEP, but with custom
## art in the bars" needs disabling the engine's automatic window scaling and
## doing it by hand — and BOTH ways tried so far to then still show the game
## itself turned out to break something else:
##
## ATTEMPT 1 — wrap game.tscn in its own SubViewport, sized/scaled via a
## SubViewportContainer to sit in the background image's transparent cutout.
## Looked correct in screenshots (confirmed live on the RG552 via adb: art
## symmetric both sides, game centered right on the cutout). But live-testing
## actual interaction (`adb shell input tap` at the Exit button's on-screen
## position, since the RG552 was on USB in developer mode) found it silently
## broke ALL touch input: nothing happened, and not even this shell's own
## top-level _input() saw the event any more, though the EXACT same tap
## worked and correctly exited the app with the SubViewport removed.
## SubViewportContainer evidently does not reliably forward
## InputEventScreenTouch/Drag to a child SubViewport on this Android/Godot
## 4.7.1 combination — confirmed by direct A/B testing on the device, not a
## guess (mouse/keyboard/gamepad were never isolated, only touch).
##
## ATTEMPT 2 (this file's current code) — avoid a second viewport entirely:
## keep game.tscn a plain, direct child of the SAME viewport as this shell,
## manually scaled/positioned via game.gd::apply_manual_scale() instead of a
## SubViewport. This DOES fix the touch problem (single viewport, nothing to
## forward) — but introduces a different, more fundamental one, caught before
## ever reaching the device: with content_scale_mode disabled for the whole
## window, get_viewport_rect() now returns the RAW WINDOW size (e.g.
## 1920x1152 on the RG552) instead of the ~540x960 design size EVERY piece of
## gameplay code assumes (ship.gd's movement clamp, entry_paths.gd/
## attack_paths.gd curves, bonus level column placement, HUD layout, bomb
## despawn bounds, ...). Left as-is, the ship could wander most of the way
## across a 1920px-wide screen instead of the intended ~540 design units —
## not a cosmetic bug, the game becomes unplayable. Fixing that would mean
## either restoring a real design-sized viewport (bringing back Attempt 1's
## touch problem) or auditing and adapting every one of those call sites,
## neither of which happened here.
##
## NEXT STEPS for whoever resumes this: either find the actual reason
## SubViewportContainer drops touch here (an engine version quirk? a missing
## property?) and fix Attempt 1 properly, or find a way to give the game a
## fixed logical viewport size without a second Viewport object at all. A
## native-Android approach (transparent Godot surface over a custom launcher
## background image) was considered but needs a custom Gradle/Android export
## build, well beyond this project's current build setup — noted here rather
## than attempted.

const GAME_SCENE := preload("res://game.tscn")
const BG_TEXTURE := preload("res://arcade-screen1.png")
## Measured directly from arcade-screen1.png (2728x1536 total): its one big
## transparent cutout spans the FULL image height and is horizontally
## centered, itself much wider (~1787px) than a 540:960 slice needs — rather
## than stretching the game to fill that whole (non-portrait-shaped) cutout,
## the game keeps its own correct aspect and is centered within it, sized to
## the cutout's full height. Leaves a bit of the cutout's own transparent
## margin visible either side of the actual game rect, which is fine — it's
## still well inside the intended "screen" cutout, not spilling onto the
## surrounding cabinet artwork.
const IMG_SIZE := Vector2(2728.0, 1536.0)
const CUTOUT_CENTER_X := IMG_SIZE.x * 0.5  # the cutout is horizontally centered on the image
const DESIGN_SIZE := Vector2(540.0, 960.0)

var _game_instance: Node2D

func _ready() -> void:
	if _wants_overlay():
		_build_overlay()
	else:
		add_child(GAME_SCENE.instantiate())

## Landscape-shaped (wider than tall) — a portrait-ish or square window has no
## meaningful letterbox space for the art to fill in the first place. NOT
## gated on touch/mobile: a landscape-locked device needing this treatment has
## nothing to do with whether it happens to report "mobile" or has a
## touchscreen at all (2026-09-15 fix — RG552 is Android, so OS.has_feature
## ("mobile") is true there; an earlier version excluded it for exactly that
## reason and never built the overlay at all regardless of screen shape).
func _wants_overlay() -> bool:
	var win := DisplayServer.window_get_size()
	return win.x > win.y

func _build_overlay() -> void:
	# The engine's own automatic scaling is exactly what walls off the
	# letterbox area from the scene tree in the first place — turn it off for
	# this one code path so the background Control below can address the REAL
	# window pixels directly instead.
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED

	var bg_root := Control.new()
	bg_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_root)

	var bg := TextureRect.new()
	bg.texture = BG_TEXTURE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# TextureRect defaults to expand_mode=EXPAND_KEEP_SIZE, which sizes the
	# Control to the TEXTURE's own native pixel size (2728x1536 here) and
	# ignores anchors entirely — confirmed live on the RG552 (2026-09-15):
	# only the image's top-left corner showed, anchored at (0,0), cropped to
	# the screen, with nothing at all on the right (that part of the 2728px-
	# wide image fell outside the 1920px-wide screen). EXPAND_IGNORE_SIZE lets
	# the Control's rect follow the anchors below like any other Control,
	# which is what actually makes stretch_mode's scale-to-fit take effect.
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_root.add_child(bg)

	_game_instance = GAME_SCENE.instantiate()
	# This case is always controller/keyboard driven — see force_non_touch's
	# own doc comment in game.gd.
	_game_instance.force_non_touch = true
	add_child(_game_instance)

	_update_layout()
	get_window().size_changed.connect(_update_layout)

## Same fit-to-window math TextureRect's own STRETCH_KEEP_ASPECT_CENTERED uses
## for the background (scale to fit, centered) — applied here to work out
## where the game itself should sit within the DISPLAYED image, not the raw
## image's own pixel coordinates, then handed to game.gd::apply_manual_scale()
## to actually place it (see that function for why it needs the game itself to
## do this rather than a wrapping Control/SubViewport).
func _update_layout() -> void:
	if not is_instance_valid(_game_instance):
		return
	var win := Vector2(DisplayServer.window_get_size())
	var img_scale := minf(win.x / IMG_SIZE.x, win.y / IMG_SIZE.y)
	var displayed := IMG_SIZE * img_scale
	var offset := (win - displayed) * 0.5
	var game_h := displayed.y
	var game_w := game_h * (DESIGN_SIZE.x / DESIGN_SIZE.y)
	var game_scale := game_h / DESIGN_SIZE.y
	var game_x := offset.x + CUTOUT_CENTER_X * img_scale - game_w * 0.5
	_game_instance.apply_manual_scale(game_scale, Vector2(game_x, offset.y))
