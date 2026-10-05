class_name NetHost
extends Node

## Online / LAN co-op, HOST side. The host runs the whole co-op game exactly like
## local co-op (game.gd with _coop = true) — the guest's ship is just a second
## Ship whose steering comes from the guest's messages ("in") instead of local
## keys (ship.gd `remote`). Several times a second the host sends a snapshot of
## everything the guest has to draw (sprites, shots, HUD numbers, one-shot
## events such as banners, explosions and sounds); the guest (net_guest.gd) runs
## no game logic at all.
##
## Messages (NetLink: var_to_bytes([type, payload])):
##   host -> guest   "start" {v}   a run begins (also after "Play Again")
##                   "snap"  {...} see _snapshot()
##                   "over"  [...] results, same dicts as game.gd::_show_results()
##                   "bye"
##   guest -> host   "in"    [dir, shoot, x]   steering state, see ship.gd
##                   "pause" / "resume"   the guest's pause button (shared pause)
##                   "bye"

const SEND_INTERVAL := 1.0 / 25.0
## Sounds the guest should NOT get: looping menu music has no place in a game.
const SKIP_SOUNDS := ["menu-music", "scoring-board-music"]

signal partner_left
signal pause_requested
signal resume_requested

var game: Game
var link: NetLink
var _acc := 0.0
var _events: Array = []
var _ids := {}          # sprite instance id -> small int (exact in a float32)
var _next_id := 1
var _sent := 0
var _in := [0.0, false, -1.0]
var _closed := false

func setup(g: Game, l: NetLink) -> void:
	game = g
	link = l
	process_mode = Node.PROCESS_MODE_ALWAYS
	var snd := g.get_node_or_null("/root/Snd")
	if snd:
		snd.played.connect(_on_sound)

func _on_sound(key: String) -> void:
	if key in SKIP_SOUNDS:
		return
	ev(["snd", key])

## One-shot happenings for the guest: ["banner", text], ["hbanner"],
## ["boom", pos], ["recon", pos], ["popup", pos, text], ["snd", key].
func ev(e: Array) -> void:
	_events.append(e)

func send_start() -> void:
	_events.clear()
	link.send("start", {"v": NetLink.version()})

func send_over(results: Array) -> void:
	_flush_events()
	var clean: Array = []
	for r in results:
		var d: Dictionary = r.duplicate()
		var ks: Array = []
		for k in d.kill_stats:
			ks.append({"kind": k.kind, "variant_idx": k.variant_idx, "is_rescue": k.is_rescue,
				"count": k.count, "points": k.points})
		d["kill_stats"] = ks
		clean.append(d)
	link.send("over", clean)

func shutdown() -> void:
	if _closed:
		return
	_closed = true
	if link:
		link.send("bye", 0)
		link.close()
	var snd := game.get_node_or_null("/root/Snd") if game else null
	if snd and snd.played.is_connected(_on_sound):
		snd.played.disconnect(_on_sound)

func _process(delta: float) -> void:
	if _closed or link == null:
		return
	for e in link.poll():
		match str(e[0]):
			"msg":
				match str(e[1]):
					"in":
						if e[2] is Array and e[2].size() >= 3:
							_in = e[2]
					"pause":
						pause_requested.emit()
					"resume":
						resume_requested.emit()
					"bye":
						_partner_gone()
			"disconnect", "closed":
				_partner_gone()
	_apply_input()
	_acc += delta
	if _acc >= SEND_INTERVAL:
		_acc = 0.0
		_flush_events()

func _partner_gone() -> void:
	if _closed:
		return
	_in = [0.0, false, -1.0]
	_apply_input()
	partner_left.emit()

func _apply_input() -> void:
	var s: Ship = game._ship2
	if not is_instance_valid(s):
		return
	s.remote = true
	s.remote_dir = clampf(float(_in[0]), -1.0, 1.0)
	s.remote_shoot = bool(_in[1])
	s.remote_x = float(_in[2])

func _flush_events() -> void:
	link.send("snap", _snapshot())
	_events.clear()
	_sent += 1
	if _sent % 250 == 0:
		_prune_ids()

func _prune_ids() -> void:
	for k in _ids.keys():
		if not is_instance_id_valid(k):
			_ids.erase(k)

# --- snapshot ----------------------------------------------------------
func _snapshot() -> Dictionary:
	var tree := game.get_tree()
	var spr := PackedFloat32Array()
	for n in tree.get_nodes_in_group("enemy"):
		_add_sprite(spr, n.get("_sprite"))
		_add_sprite(spr, n.get("_captive_visual"))
	for n in tree.get_nodes_in_group("bonus_item"):
		_add_sprite(spr, n.get("_sprite"))
	for n in tree.get_nodes_in_group("bonus_transient"):
		_add_sprite(spr, n.get("_sprite"))
	for s in game._ships:
		_add_sprite(spr, s._sprite)
		_add_sprite(spr, s._sprite2)
	var lasers := PackedFloat32Array()
	for n in tree.get_nodes_in_group("player_lasers"):
		lasers.append_array([n.global_position.x, n.global_position.y,
			1.0 if n.accent_color == Laser.ACCENT_HYPER else 0.0])
	var bombs := PackedFloat32Array()
	var beams := PackedFloat32Array()
	for n in tree.get_nodes_in_group("enemy_shots"):
		if n.is_in_group("capture_beam"):
			beams.append_array([n.global_position.x, n.global_position.y, n._len])
		else:
			bombs.append_array([n.global_position.x, n.global_position.y, n._vel.x, n._vel.y])
	var ships := []
	for sh in game._ships:
		ships.append([sh.global_position.x, sh.global_position.y,
			1 if (sh.visible and sh._alive) else 0, 1 if sh._twin else 0])
	var hud: Hud = game._hud
	var p2x := -1.0
	if is_instance_valid(game._ship2):
		p2x = game._ship2.position.x
	return {
		"h": [game._score, game._stage, game._coop_lives[0], game._coop_lives[1],
			hud._bonus_laps, 1 if hud._lap_pending else 0, 1 if tree.paused else 0, p2x],
		"bi": hud._bonus_icon_indices,
		"sh": ships,
		"sp": spr, "ls": lasers, "bm": bombs, "bc": beams,
		"ev": _events,
	}

## Stride 12: id, texture, x, y, rotation, scale x/y, skew, r, g, b, a.
func _add_sprite(out: PackedFloat32Array, spr) -> void:
	if spr == null or not is_instance_valid(spr) or not (spr as Sprite2D).is_visible_in_tree():
		return
	var sp: Sprite2D = spr
	var ti := NetTex.index_of(sp.texture)
	if ti < 0:
		return
	var key := sp.get_instance_id()
	var id: int = _ids.get(key, 0)
	if id == 0:
		id = _next_id
		_next_id += 1
		_ids[key] = id
	var col: Color = sp.self_modulate
	var n: Node = sp
	while n is CanvasItem:
		col *= (n as CanvasItem).modulate
		n = n.get_parent()
	var gs := sp.global_scale
	out.append_array([id, ti, sp.global_position.x, sp.global_position.y, sp.global_rotation,
		gs.x, gs.y, sp.global_skew, col.r, col.g, col.b, col.a])
