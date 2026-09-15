extends Node

## New res://project run/main_scene (2026-09-15), replacing game.tscn directly.
## Exists for ONE reason: a device that can't rotate to portrait at all (user's
## Anbernic RG552, running this project's Linux export) has no way to show a
## portrait 540x960 game without either (a) plain black bars left/right
## (today's game.gd::_apply_display_mode() KEEP behavior) or (b) badly
## squashing the game if treated as a "touch" device (KEEP_WIDTH assumes a
## device TALLER than 540:960, not wider). This shell instead fills those bars
## with the user's own arcade-cabinet artwork (arcade-screen1.png).
##
## Godot's own canvas_items + KEEP stretch mode CANNOT do this itself: the
## letterbox area it produces is genuinely outside the scene tree's reach —
## nothing can be drawn there, by design. Reproducing "KEEP, but with custom
## art in the bars" therefore needs disabling the engine's automatic window
## scaling and doing it by hand: a full-window background Control, with the
## actual game running inside a SubViewport sized/positioned to sit within the
## background image's own transparent cutout.
##
## Deliberately triggers on window SHAPE alone (landscape, i.e. wider than
## tall — see _wants_overlay()), not on touch/mobile detection: any window
## that's landscape-shaped has the same letterbox problem regardless of what
## device it's running on, so — per user request 2026-09-15 — this applies
## equally to a normal widescreen desktop window as it does to the RG552; no
## separate device-specific carve-out. A portrait-ish or taller-than-wide
## window (phones, tablets, a narrow desktop window) has no meaningful
## letterbox space to fill in the first place, so it instantiates game.tscn
## directly as this node's only child instead — ZERO structural difference
## from game.tscn being the main scene itself, project.godot's existing
## window/stretch/mode="canvas_items" keeps working exactly as before there,
## completely untouched.
##
## Verified live on the user's actual RG552 (2026-09-15, via adb screenshots)
## — looks correct: symmetric cabinet art both sides, game centered exactly on
## the transparent cutout. Two real bugs found and fixed in the process, both
## confirmed for good reason to trust actual device testing over guessing:
## (1) OS.has_feature("mobile") is true on this Android device, so an earlier
## version's touch/mobile gate on _wants_overlay() skipped the overlay branch
## entirely regardless of screen shape — removed, see _wants_overlay() below.
## (2) TextureRect's default expand_mode=EXPAND_KEEP_SIZE sized the background
## to the texture's native 2728x1536 pixels anchored at (0,0), ignoring the
## anchors entirely — only the image's top-left corner showed, cropped to the
## screen, nothing at all on the right. Fixed via expand_mode=EXPAND_IGNORE_SIZE
## (see _build_overlay() below).

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

var _container: SubViewportContainer

func _ready() -> void:
	if _wants_overlay():
		_build_overlay()
	else:
		add_child(GAME_SCENE.instantiate())

## Landscape-shaped (wider than tall) — a portrait-ish or square window has no
## meaningful letterbox space for the art to fill in the first place. NOT
## gated on touch/mobile any more (2026-09-15 fix, user report: RG552 is an
## Android device, so OS.has_feature("mobile") is almost certainly true there,
## which skipped this branch entirely regardless of the screen's actual
## shape) — a landscape-locked device needing this treatment has nothing to
## do with whether it happens to report "mobile" or has a touchscreen at all.
func _wants_overlay() -> bool:
	var win := DisplayServer.window_get_size()
	return win.x > win.y

func _build_overlay() -> void:
	# The engine's own automatic scaling is exactly what walls off the
	# letterbox area from the scene tree in the first place — turn it off for
	# this one code path so the Control/SubViewport structure below can
	# address the REAL window pixels directly instead.
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var bg := TextureRect.new()
	bg.texture = BG_TEXTURE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# TextureRect defaults to expand_mode=EXPAND_KEEP_SIZE, which sizes the
	# Control to the TEXTURE's own native pixel size (2728x1536 here) and
	# ignores anchors entirely — confirmed live on the RG552 (2026-09-15):
	# only the image's top-left corner showed, anchored at (0,0), cropped to
	# the screen, with nothing at all on the right (that part of the 2728px-
	# wide image fell outside the 1920px-wide screen). EXPAND_IGNORE_SIZE
	# lets the Control's rect follow the anchors below like any other Control,
	# which is what actually makes stretch_mode's scale-to-fit take effect.
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	_container = SubViewportContainer.new()
	_container.stretch = true
	root.add_child(_container)

	var vp := SubViewport.new()
	vp.size = Vector2i(DESIGN_SIZE)
	_container.add_child(vp)
	var game_instance := GAME_SCENE.instantiate()
	# This case is always controller/keyboard driven, and the SubViewport
	# above is a fixed 540x960 with no "extra height" to give a touch layout
	# anyway — see force_non_touch's own doc comment in game.gd.
	game_instance.force_non_touch = true
	vp.add_child(game_instance)

	_update_layout()
	get_window().size_changed.connect(_update_layout)

## Same fit-to-window math TextureRect's own STRETCH_KEEP_ASPECT_CENTERED uses
## for the background (scale to fit, centered) — applied here to place the
## SubViewportContainer at the corresponding spot within the DISPLAYED image,
## not the raw image's own pixel coordinates.
func _update_layout() -> void:
	if not is_instance_valid(_container):
		return
	var win := Vector2(DisplayServer.window_get_size())
	var scale := minf(win.x / IMG_SIZE.x, win.y / IMG_SIZE.y)
	var displayed := IMG_SIZE * scale
	var offset := (win - displayed) * 0.5
	var game_h := displayed.y
	var game_w := game_h * (DESIGN_SIZE.x / DESIGN_SIZE.y)
	var game_x := offset.x + CUTOUT_CENTER_X * scale - game_w * 0.5
	_container.position = Vector2(game_x, offset.y)
	_container.size = Vector2(game_w, game_h)
