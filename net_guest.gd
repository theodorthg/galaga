class_name NetGuest
extends Node2D

## Online / LAN co-op, GUEST side. Runs no game logic: it draws what the host
## sends (see net_host.gd) — sprites from a pool keyed by the host's sprite id,
## shots/beams straight from _draw() — drives the HUD and menus from the
## snapshot, replays the one-shot events (banners, explosions, sounds), and
## sends this device's steering ("in") back. Lives as a child of Game, drawn
## on top of the (parked, invisible) local ships.

const SEND_INTERVAL := 1.0 / 30.0
## Exponential smoothing of sprite positions between 25 Hz snapshots.
const SMOOTH := 28.0
const LASER_SPEED := 850.0
## The ship's engine flame (same scene ship.tscn uses; it lights up by itself when
## its parent moves sideways — see main_thruster.gd). Offset/rotation as in ship.tscn.
const THRUSTER_SCENE := preload("res://assets/ship_visual_effects/main_thruster/main_thruster.tscn")
const THRUSTER_POS := Vector2(0, 50)
const TWIN_OFFSET := 34.0   # Ship.TWIN_OFFSET

signal left(reason: String)
signal started
signal over(results: Array)

var game: Game
var link: NetLink
var _sprites := {}       # host sprite id -> {"n": Sprite2D, "seen": bool, "pos": Vector2, "rot": float}
var _lasers := PackedFloat32Array()
var _bombs := PackedFloat32Array()
var _beams := PackedFloat32Array()
var _snap_time := 0.0
var _have_snap := false
var _in_acc := 0.0
var _mouse_aim := false
var _touch_down := false
var _mouse_down := false
var _touch_x := 270.0
var _my_x := 270.0
var _was_paused := false
var _closed := false
var _hud_cache := {}
var _ship_fx := []         # per ship slot: {"n": Node2D, "a": Node2D, "b": Node2D, "pos": Vector2}
var _pz_ignore_until := 0.0

func setup(g: Game, l: NetLink) -> void:
	game = g
	link = l
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 5

func reset_view() -> void:
	for id in _sprites:
		(_sprites[id].n as Node).queue_free()
	_sprites.clear()
	_lasers = PackedFloat32Array()
	_bombs = PackedFloat32Array()
	_beams = PackedFloat32Array()
	_have_snap = false
	_hud_cache.clear()
	_was_paused = false
	for fx in _ship_fx:
		fx.n.visible = false
	queue_redraw()

func shutdown() -> void:
	if _closed:
		return
	_closed = true
	if link:
		link.send("bye", 0)
		link.close()

func _process(delta: float) -> void:
	if _closed:
		return
	for e in link.poll():
		match str(e[0]):
			"msg":
				_on_msg(str(e[1]), e[2])
			"disconnect":
				_lost("The host left the game.")
			"closed", "error":
				_lost(str(e[1]))
	if _closed:
		return
	# smooth the sprites toward their latest snapshot targets
	var k := 1.0 - exp(-SMOOTH * delta)
	for id in _sprites:
		var d: Dictionary = _sprites[id]
		var n: Sprite2D = d.n
		n.position = n.position.lerp(d.pos, k)
		n.rotation = lerp_angle(n.rotation, d.rot, k)
	for fx in _ship_fx:
		fx.n.position = fx.n.position.lerp(fx.pos, k)
	_in_acc += delta
	if _in_acc >= SEND_INTERVAL:
		_in_acc = 0.0
		_send_input()
	queue_redraw()

func _lost(why: String) -> void:
	if _closed:
		return
	_closed = true
	left.emit(why)

func _on_msg(type: String, p) -> void:
	match type:
		"start":
			if p is Dictionary and not _version_ok(str(p.get("v", ""))):
				shutdown()
				left.emit("The host runs a different version of the game.")
				return
			reset_view()
			started.emit()
		"snap":
			if p is Dictionary:
				_apply(p)
		"over":
			if p is Array:
				over.emit(p)
		"bye":
			_lost("The host left the game.")

## Same major.minor, like the relay checks for online games.
static func _version_ok(v: String) -> bool:
	var a := NetLink.version().split(".")
	var b := v.split(".")
	return v == "" or (a.size() >= 2 and b.size() >= 2 and a[0] == b[0] and a[1] == b[1])

# --- snapshot -> screen ------------------------------------------------
func _apply(s: Dictionary) -> void:
	_snap_time = Time.get_ticks_msec() / 1000.0
	_have_snap = true
	_lasers = s.get("ls", PackedFloat32Array())
	_bombs = s.get("bm", PackedFloat32Array())
	_beams = s.get("bc", PackedFloat32Array())
	_apply_hud(s.get("h", []), s.get("bi", []))
	_apply_ship_fx(s.get("sh", []))
	_apply_sprites(s.get("sp", PackedFloat32Array()))
	for e in s.get("ev", []):
		_event(e)

func _apply_hud(h: Array, bi: Array) -> void:
	if h.size() < 8:
		return
	var hud: Hud = game._hud
	if _hud_cache.get("score", -1) != h[0]:
		hud.set_score(int(h[0]))
	if _hud_cache.get("stage", -1) != h[1]:
		hud.set_stage(int(h[1]))
	if _hud_cache.get("l0", -1) != h[2] or _hud_cache.get("l1", -1) != h[3]:
		hud.set_coop_lives(int(h[2]), int(h[3]))
	var key := str(bi) + str(h[4]) + str(h[5])
	if _hud_cache.get("bonus", "") != key:
		var icons: Array = []
		var idx: Array = []
		for i in bi:
			icons.append(NetTex.get_tex(NetTex.index_of_achievement(int(i))))
			idx.append(int(i))
		hud.set_bonus_state({"icons": icons, "indices": idx, "laps": int(h[4]), "pending": int(h[5]) == 1})
	var paused := int(h[6]) == 1
	# the host's (or the partner's) pause: show/hide our pause screen. Right after
	# WE resumed, snapshots that still say "paused" are stale — ignored briefly.
	if Time.get_ticks_msec() / 1000.0 >= _pz_ignore_until:
		if paused and not _was_paused:
			game._net_guest_host_paused(true)
		elif _was_paused and not paused:
			game._net_guest_host_paused(false)
		_was_paused = paused
	_my_x = float(h[7]) if float(h[7]) >= 0.0 else _my_x
	_hud_cache = {"score": h[0], "stage": h[1], "l0": h[2], "l1": h[3], "bonus": key}

## Engine flames: one proxy node per ship that follows the (smoothed) ship, so the
## thruster's own "parent moved sideways" logic drives the flame.
func _apply_ship_fx(sh: Array) -> void:
	for i in sh.size():
		var d: Array = sh[i]
		while _ship_fx.size() <= i:
			var n := Node2D.new()
			add_child(n)
			var a := THRUSTER_SCENE.instantiate()
			a.position = THRUSTER_POS
			a.rotation = PI * 0.5
			n.add_child(a)
			var b := THRUSTER_SCENE.instantiate()
			b.position = THRUSTER_POS + Vector2(TWIN_OFFSET, 0)
			b.rotation = PI * 0.5
			n.add_child(b)
			n.visible = false
			_ship_fx.append({"n": n, "a": a, "b": b, "pos": Vector2.ZERO})
		var fx: Dictionary = _ship_fx[i]
		var pos := Vector2(d[0], d[1])
		var was_hidden: bool = not fx.n.visible
		fx.pos = pos
		fx.n.visible = int(d[2]) == 1
		if was_hidden:
			fx.n.position = pos
		var twin := int(d[3]) == 1
		fx.a.position.x = -TWIN_OFFSET if twin else 0.0
		fx.b.visible = twin

func _apply_sprites(a: PackedFloat32Array) -> void:
	for id in _sprites:
		_sprites[id].seen = false
	var i := 0
	while i + 12 <= a.size():
		var id := int(a[i])
		var tex := NetTex.get_tex(int(a[i + 1]))
		var pos := Vector2(a[i + 2], a[i + 3])
		var d: Dictionary
		if _sprites.has(id):
			d = _sprites[id]
		else:
			var n := Sprite2D.new()
			add_child(n)
			n.position = pos
			n.rotation = a[i + 4]
			d = {"n": n, "seen": true, "pos": pos, "rot": a[i + 4]}
			_sprites[id] = d
		var sp: Sprite2D = d.n
		if sp.texture != tex:
			sp.texture = tex
		d.pos = pos
		d.rot = a[i + 4]
		d.seen = true
		sp.scale = Vector2(a[i + 5], a[i + 6])
		sp.skew = a[i + 7]
		sp.modulate = Color(a[i + 8], a[i + 9], a[i + 10], a[i + 11])
		i += 12
	for id in _sprites.keys():
		if not _sprites[id].seen:
			(_sprites[id].n as Node).queue_free()
			_sprites.erase(id)

func _event(e) -> void:
	if not (e is Array) or e.is_empty():
		return
	match str(e[0]):
		"banner":
			game._hud.flash_banner(str(e[1]))
		"hbanner":
			game._hud.hide_banner()
		"boom":
			var x := Game.EXPLOSION_SCENE.instantiate()
			game.add_child(x)
			x.global_position = e[1]
		"recon":
			for at in e[1]:
				var r := Game.RECONSTRUCT_SCENE.instantiate()
				game.add_child(r)
				r.global_position = at
		"popup":
			game._spawn_score_popup(e[1], str(e[2]))
		"snd":
			var snd := game.get_node_or_null("/root/Snd")
			if snd:
				snd.play(str(e[1]))

# --- drawing: shots and beams -------------------------------------------
func _draw() -> void:
	if not _have_snap:
		return
	var age := minf(Time.get_ticks_msec() / 1000.0 - _snap_time, 0.15)
	var i := 0
	while i + 3 <= _lasers.size():
		var p := Vector2(_lasers[i], _lasers[i + 1] - LASER_SPEED * age)
		var hyper := _lasers[i + 2] > 0.5
		var col := Laser.ACCENT_HYPER if hyper else Color("cfefff")
		draw_rect(Rect2(p.x - 1.5, p.y - 8.0, 3.0, Laser.BEAM_LEN), col)
		draw_rect(Rect2(p.x - 1.5, p.y - 8.0, 3.0, Laser.BEAM_HEAD_LEN), Color.WHITE)
		i += 3
	i = 0
	while i + 4 <= _bombs.size():
		var c := Vector2(_bombs[i] + _bombs[i + 2] * age, _bombs[i + 1] + _bombs[i + 3] * age)
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -7), c + Vector2(4, 0), c + Vector2(0, 7), c + Vector2(-4, 0)]), Color("ffd23f"))
		draw_circle(c, 2.0, Color("fff6cf"))
		i += 4
	i = 0
	while i + 3 <= _beams.size():
		var w := 22.0
		var len_: float = _beams[i + 2]
		if len_ > 0.0:
			draw_rect(Rect2(_beams[i] - w * 0.5, _beams[i + 1], w, len_), Color(0.25, 0.95, 0.5, 0.5))
			draw_rect(Rect2(_beams[i] - w * 0.18, _beams[i + 1], w * 0.36, len_), Color(0.7, 1.0, 0.85, 0.75))
		i += 3

# --- input -> host --------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_touch_down = event.pressed
		if event.pressed:
			_touch_x = _my_x
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_down = event.pressed
	elif event is InputEventMouseMotion:
		_mouse_aim = true
	elif event is InputEventScreenDrag:
		_touch_x = clampf(_touch_x + event.relative.x, 0.0, Game.DESIGN_WIDTH)

## The guest's pause button: pauses the host's game for both (shared pause).
func send_pause(on: bool) -> void:
	if on:
		link.send("pause", 0)
	else:
		_pz_ignore_until = Time.get_ticks_msec() / 1000.0 + 0.6
		link.send("resume", 0)

func _send_input() -> void:
	var dir := Input.get_axis("move_left", "move_right")
	var x := -1.0
	if dir != 0.0:
		_mouse_aim = false
	elif _touch_down:
		x = _touch_x
	elif _mouse_aim:
		x = get_global_mouse_position().x
	var shoot := _touch_down or _mouse_down or Input.is_action_pressed("shoot")
	link.send("in", [dir, shoot, x])
