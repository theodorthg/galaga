extends SceneTree

## Two processes, one host and one guest, over LAN (loopback) or the relay:
##   godot --headless --audio-driver Dummy --path . --script res://tools/nettest.gd -- host lan
##   godot --headless --audio-driver Dummy --path . --script res://tools/nettest.gd -- guest lan
## online: "host online" first (it writes the room code to /tmp/galaga_code),
## then "guest online"; GALAGA_RELAY=ws://127.0.0.1:8765 for a local relay.

var game: Game
var fails := 0

func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var role: String = args[0]
	var transport: String = args[1]
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._menus.splash_done.disconnect(game._enter_title)
	game._menus._finish_splash()
	await process_frame
	var link := NetLink.new()
	if role == "host":
		if transport == "lan":
			check(link.host_lan() == OK, "host: LAN socket open")
		else:
			check(link.host_online(NetLink.relay_url()) == OK, "host: relay connect started")
		await _host(link, transport)
	else:
		if transport == "lan":
			check(link.join_lan("127.0.0.1") == OK, "guest: LAN connect started")
		else:
			var code := ""
			for i in 200:
				if FileAccess.file_exists("/tmp/galaga_code"):
					code = FileAccess.get_file_as_string("/tmp/galaga_code").strip_edges()
					break
				await create_timer(0.1).timeout
			check(link.join_online(NetLink.relay_url(), code) == OK, "guest: join %s" % code)
		await _guest(link)
	print("fails: %d" % fails)
	print("done")
	quit(1 if fails > 0 else 0)

func _wait_connect(link: NetLink, seconds: float) -> bool:
	var t := 0.0
	while t < seconds:
		for e in link.poll():
			if e[0] == "room":
				var f := FileAccess.open("/tmp/galaga_code", FileAccess.WRITE)
				f.store_string(str(e[1]))
				f.close()
				print("room ", e[1])
			elif e[0] == "connect":
				return true
			elif e[0] == "error" or e[0] == "closed":
				print("link: ", e)
				return false
		await create_timer(0.05).timeout
		t += 0.05
	return false

func _host(link: NetLink, _transport: String) -> void:
	DirAccess.remove_absolute("/tmp/galaga_code") if FileAccess.file_exists("/tmp/galaga_code") and _transport == "online" else null
	check(await _wait_connect(link, 40.0), "host: guest connected")
	game.net_start_host(link)
	var pause_log := [0, 0]
	game._net_host.pause_requested.connect(func(): pause_log[0] += 1)
	game._net_host.resume_requested.connect(func(): pause_log[1] += 1)
	await create_timer(1.0).timeout
	check(game._coop and game._net_host != null, "host: co-op run with a NetHost")
	check(is_instance_valid(game._ship2) and game._ship2.remote, "host: ship 2 is remote-controlled")
	# wait for the fly-in, then watch the guest's ship move and shoot
	var t := 0.0
	while game._state != Game.FORMATION and t < 40.0:
		await create_timer(0.25).timeout
		t += 0.25
	check(game._state == Game.FORMATION, "host: stage 1 formation reached (%.1fs)" % t)
	var x0: float = game._ship2.position.x
	await create_timer(3.0).timeout
	var x1: float = game._ship2.position.x
	check(x1 > 400.0, "host: guest's input moves ship 2 right of its home 356 (%.0f -> %.0f)" % [x0, x1])
	var shots := 0
	for l in get_nodes_in_group("player_lasers"):
		if l.owner_idx == 1:
			shots += 1
	check(shots > 0 or game._score > 0, "host: guest's ship fires (%d lasers, score %d)" % [shots, game._score])
	await create_timer(2.0).timeout
	check(pause_log[0] >= 1 and pause_log[1] >= 1, "host: the guest's pause/resume arrived (%s)" % str(pause_log))
	check(not game._paused and not paused, "host: running again after the guest resumed")
	# both ships lost, no reserve -> game over -> the guest gets the results
	game._coop_lives = [0, 0]
	for sh in game._ships:
		sh._destroy(true)
	t = 0.0
	while game._state != Game.GAME_OVER and t < 20.0:
		await create_timer(0.25).timeout
		t += 0.25
	check(game._state == Game.GAME_OVER, "host: game over (%.1fs)" % t)
	await create_timer(2.0).timeout
	check(game._menus._screens["summary"].visible, "host: TEAM summary shown")
	await create_timer(2.0).timeout
	game._new_run()                       # "Play Again": the guest follows
	await create_timer(2.5).timeout
	check(game._state != Game.GAME_OVER and game._net_host != null, "host: second run started with the same guest")
	t = 0.0
	while game._net_host != null and t < 15.0:      # the guest leaves now
		await create_timer(0.25).timeout
		t += 0.25
	check(game._net_host == null and game._out[1], "host: guest left -> ship 2 out, game goes on")

func _guest(link: NetLink) -> void:
	check(await _wait_connect(link, 40.0), "guest: connected")
	game.net_start_guest(link)
	check(game._net_guest != null, "guest: NetGuest running")
	Input.action_press("move_right")
	Input.action_press("shoot")
	var t := 0.0
	var sprites := 0
	while t < 30.0:
		await create_timer(0.25).timeout
		t += 0.25
		sprites = game._net_guest._sprites.size()
		if sprites > 30:
			break
	check(sprites > 30, "guest: sprites from the host (%d)" % sprites)
	await create_timer(3.0).timeout
	var hud: Hud = game._hud
	check(hud._lives2 >= 0, "guest: co-op life rows on the HUD (%d/%d)" % [hud._lives, hud._lives2])
	check(game._net_guest._lasers.size() > 0 or hud._score_value > 0, "guest: lasers or score arrive")
	check(game._net_guest._snap_time > 0.0, "guest: snapshots arrive")
	check(game._net_guest._ship_fx.size() == 2 and game._net_guest._ship_fx[1].n.visible, "guest: engine flames for both ships")
	var fx0: Dictionary = game._net_guest._ship_fx[0]
	for i in 12:
		fx0.pos.x += 6.0          # the ship "moves": the flame must light up
		await process_frame
	check(fx0.a.power > 0.3, "guest: engine flame lights up while the ship moves (power %.2f)" % fx0.a.power)
	game._request_pause()
	await create_timer(1.0).timeout
	check(game._paused and game._menus._screens["net_pause"].visible, "guest: own pause screen")
	check(game._net_guest._was_paused, "guest: the host confirms the pause (pz)")
	game._resume()
	await create_timer(1.0).timeout
	check(not game._paused and not game._menus._screens["net_pause"].visible, "guest: resumed")
	t = 0.0
	while game._state != Game.GAME_OVER and t < 40.0:
		await create_timer(0.25).timeout
		t += 0.25
	check(game._state == Game.GAME_OVER and game._menus._screens["summary"].visible, "guest: results screen from the host (%.1fs)" % t)
	game._menus._fill_gameover(0, 1)
	check(not game._menus._play_again_btn.visible, "guest: no \"Play Again\" of his own")
	t = 0.0
	while game._menus._screens["summary"].visible and t < 20.0:
		await create_timer(0.25).timeout
		t += 0.25
	check(not game._menus._screens["summary"].visible, "guest: follows the host into the next run (%.1fs)" % t)
	game._request_pause()
	check(game._menus._screens["net_pause"].visible, "guest: pause opens the pause screen")
	Input.action_release("move_right")
	Input.action_release("shoot")
	await create_timer(5.0).timeout
	game._enter_title()
	check(game._net_guest == null, "guest: left cleanly")
