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
## IMPORTANT — this only ever affects the ONE new code path below
## (_wants_overlay() == true, i.e. non-touch AND landscape-shaped window).
## Every other case (phones, tablets, normal desktop/web windows) instantiates
## game.tscn directly as this node's only child, with ZERO structural
## difference from it being the main scene itself — project.godot's existing
## window/stretch/mode="canvas_items" keeps working exactly as before there,
## completely untouched. That also means: for now, a normal landscape-shaped
## DESKTOP window (not just the RG552) will ALSO get the cabinet-art overlay,
## since there's currently no way to tell those apart from window shape alone
## — flag if that turns out to be unwanted for regular desktop play, it's an
## easy follow-up to scope down further (e.g. an explicit settings toggle).
##
## Not yet visually verified — no display/device available to check pixel
## alignment against. Built from directly measuring arcade-screen1.png's own
## transparent cutout (see IMG_SIZE/CUTOUT_CENTER_X below); needs the user's
## own eyes on the actual RG552 to confirm it looks right, then iterate on the
## numbers below if not.

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

## Non-touch (a touch device already gets its own correct, non-letterboxed
## KEEP_WIDTH handling from game.gd) AND landscape-shaped (wider than tall) —
## a portrait-ish or square window has no meaningful letterbox space for the
## art to fill in the first place.
func _wants_overlay() -> bool:
	if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
		return false
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
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	_container = SubViewportContainer.new()
	_container.stretch = true
	root.add_child(_container)

	var vp := SubViewport.new()
	vp.size = Vector2i(DESIGN_SIZE)
	_container.add_child(vp)
	vp.add_child(GAME_SCENE.instantiate())

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
