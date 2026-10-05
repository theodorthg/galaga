class_name NetLobby
extends Node

## Menu side of online / LAN co-op: the screens (mode choice, waiting for the
## partner, LAN host list, code entry) and the connection set-up. As soon as two
## devices are connected the link is handed to the game (host_connected /
## guest_connected -> game.gd::net_start_host/net_start_guest) and this node is
## idle again. Builds its screens with the Menus helpers, so they look and
## behave like every other menu (focus, B = cancel, music).
##   LAN:    ENet on the series' shared ports; the host answers a broadcast/sweep
##           (NetLink.Discovery), so the guest just picks the host from a list.
##   Online: a 4-letter room code over the shared relay (works in the browser).

signal host_connected(link: NetLink)
signal guest_connected(link: NetLink)

var m: Menus
var link: NetLink
var _disc: NetLink.Discovery
var _mode := ""          # "host_lan" | "host_online" | "join_lan" | "join_online"
var _wait_title: Label
var _wait_text: Label
var _code_big: Label
var _find_list: VBoxContainer
var _find_hint: Label
var _ip_edit: LineEdit
var _code_edit: LineEdit
var _found_key := ""
var _origin := "net_online"   # the screen "Cancel" returns to

func setup(menus: Menus) -> void:
	m = menus
	process_mode = Node.PROCESS_MODE_ALWAYS
	m._screens["net_online"] = _build_online()
	m._screens["net_lan"] = _build_lan()
	m._screens["net_wait"] = _build_wait()
	m._screens["net_find"] = _build_find()
	m._screens["net_code"] = _build_code()
	for k in ["net_online", "net_lan", "net_wait", "net_find", "net_code"]:
		m._root.add_child(m._screens[k])

# ---------------------------------------------------------------- screens
func _build_online() -> Control:
	var s := m._screen()
	var box := m._box(s)
	box.add_child(m._title_label("ONLINE", 34))
	var t := m._title_label("Two players, each on their own device, anywhere (also in the browser). A 4-letter code connects you.", 15)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD
	t.custom_minimum_size = Vector2(320, 0)
	box.add_child(t)
	box.add_child(m._spacer(8))
	box.add_child(m._button("Host a game (get a code)", func(): _start_host_online()))
	box.add_child(m._button("Join with a code", func(): _open_code()))
	box.add_child(m._spacer(4))
	box.add_child(m._button("Back", func(): m.show_mode(), true))
	return s

func _build_lan() -> Control:
	var s := m._screen()
	var box := m._box(s)
	box.add_child(m._title_label("WI-FI / LAN", 34))
	var t := m._title_label("Two players on the same network, no server needed.", 15)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD
	t.custom_minimum_size = Vector2(320, 0)
	box.add_child(t)
	box.add_child(m._spacer(8))
	box.add_child(m._button("Host a game", func(): _start_host_lan()))
	box.add_child(m._button("Join a game", func(): _start_join_lan()))
	box.add_child(m._spacer(4))
	box.add_child(m._button("Back", func(): m.show_mode(), true))
	return s

func _build_wait() -> Control:
	var s := m._screen()
	var box := m._box(s)
	_wait_title = m._title_label("", 30)
	box.add_child(_wait_title)
	_code_big = m._title_label("", 60, Menus.ACCENT)
	box.add_child(_code_big)
	_wait_text = m._title_label("", 17)
	_wait_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_wait_text.custom_minimum_size = Vector2(320, 0)
	box.add_child(_wait_text)
	box.add_child(m._spacer(8))
	box.add_child(m._button("Cancel", func(): cancel(), true))
	return s

func _build_find() -> Control:
	var s := m._screen()
	var box := m._box(s)
	box.add_child(m._title_label("JOIN (LAN)", 30))
	_find_hint = m._title_label("Looking for games…", 17)
	box.add_child(_find_hint)
	_find_list = VBoxContainer.new()
	_find_list.add_theme_constant_override("separation", 8)
	box.add_child(_find_list)
	box.add_child(m._spacer(6))
	box.add_child(m._title_label("or type the host's address:", 15))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	_ip_edit = _line_edit("192.168.…", 15)
	_ip_edit.text_submitted.connect(func(_t: String): _join_lan(_ip_edit.text))
	row.add_child(_ip_edit)
	var go := m._button("Join", func(): _join_lan(_ip_edit.text))
	go.custom_minimum_size = Vector2(90, Menus.TOUCH_H)
	row.add_child(go)
	box.add_child(row)
	box.add_child(m._spacer(4))
	box.add_child(m._button("Back", func(): cancel(), true))
	return s

func _build_code() -> Control:
	var s := m._screen()
	var box := m._box(s)
	box.add_child(m._title_label("JOIN ONLINE", 30))
	box.add_child(m._title_label("Enter the 4-letter code\nthe host sees on screen", 17))
	_code_edit = _line_edit("CODE", 8)
	_code_edit.custom_minimum_size = Vector2(200, Menus.TOUCH_H)
	_code_edit.add_theme_font_size_override("font_size", 30)
	_code_edit.text_changed.connect(func(t: String):
		var up := t.to_upper()
		if up != t:
			var c := _code_edit.caret_column
			_code_edit.text = up
			_code_edit.caret_column = c)
	_code_edit.text_submitted.connect(func(_t: String): _join_online(_code_edit.text))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_code_edit)
	box.add_child(row)
	box.add_child(m._spacer(6))
	box.add_child(m._button("Join", func(): _join_online(_code_edit.text)))
	box.add_child(m._button("Back", func(): m._swap("net_online"), true))
	return s

func _line_edit(placeholder: String, max_len: int) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.max_length = max_len
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.custom_minimum_size = Vector2(170, Menus.TOUCH_H)
	e.add_theme_font_size_override("font_size", 20)
	# same on-screen-keyboard nudge as the high-score name field
	e.focus_entered.connect(func():
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
			DisplayServer.virtual_keyboard_show(e.text, Rect2(), DisplayServer.KEYBOARD_TYPE_DEFAULT, e.max_length))
	e.focus_exited.connect(func():
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
			DisplayServer.virtual_keyboard_hide())
	return e

# ---------------------------------------------------------------- flow
## kind: "online" or "lan" — the screen Play > Online / Wi-Fi LAN leads to.
func open(kind: String) -> void:
	cancel(false)
	_origin = "net_lan" if kind == "lan" else "net_online"
	m._swap(_origin)

## Closes whatever is being set up (not the link of a running game).
func cancel(back_to_menu := true) -> void:
	if link:
		link.close()
		link = null
	if _disc:
		_disc.stop()
		_disc = null
	_mode = ""
	_found_key = ""
	if back_to_menu:
		m._swap(_origin)

func _wait(title: String, text: String, code := "") -> void:
	_wait_title.text = title
	_wait_text.text = text
	_code_big.text = code
	_code_big.visible = code != ""
	m._swap("net_wait")

func _fail(text: String) -> void:
	cancel(false)
	m.show_notice(text, _origin)

func _start_host_lan() -> void:
	cancel(false)
	link = NetLink.new()
	var err := link.host_lan()
	if err != OK:
		_fail("The LAN game could not be opened (port %d in use?)." % NetLink.PORT)
		return
	_disc = NetLink.Discovery.new()
	_disc.start_host(NetLink.device_name())
	_mode = "host_lan"
	var ips := NetLink.local_ips()
	_wait("HOSTING (LAN)", "Waiting for your partner…\nHe/she picks \"%s\" under \"Join a game\" on the same Wi-Fi.\nYour address: %s\n\nIf nobody finds you, allow UDP ports %d–%d in the firewall." % [
		NetLink.device_name(), ", ".join(ips) if not ips.is_empty() else "?", NetLink.DISCOVERY_PORT, NetLink.PORT])

func _start_join_lan() -> void:
	cancel(false)
	_disc = NetLink.Discovery.new()
	_disc.start_search()
	_mode = "join_lan"
	_found_key = "-"
	_find_hint.text = "Looking for games…"
	m._swap("net_find")

func _join_lan(ip: String) -> void:
	ip = ip.strip_edges()
	if ip == "":
		return
	if _disc:
		_disc.stop()
		_disc = null
	link = NetLink.new()
	if link.join_lan(ip) != OK:
		_fail("Could not connect to %s." % ip)
		return
	_mode = "join_lan_connecting"
	_wait("CONNECTING…", "Connecting to %s" % ip)

func _start_host_online() -> void:
	cancel(false)
	link = NetLink.new()
	if link.host_online(NetLink.relay_url()) != OK:
		_fail("No online server configured.")
		return
	_mode = "host_online"
	_wait("HOSTING (ONLINE)", "Connecting to the server…")

func _open_code() -> void:
	cancel(false)
	_code_edit.text = ""
	m._swap("net_code")
	_code_edit.grab_focus.call_deferred()

func _join_online(code: String) -> void:
	code = NetLink.clean_code(code)
	if code.length() < 4:
		return
	cancel(false)
	link = NetLink.new()
	if link.join_online(NetLink.relay_url(), code) != OK:
		_fail("No online server configured.")
		return
	_mode = "join_online"
	_wait("JOINING…", "Connecting to the server…")

# ---------------------------------------------------------------- per frame
func _process(delta: float) -> void:
	if _disc:
		_disc.poll(delta)
		if _mode == "join_lan":
			_refresh_found()
	if link == null:
		return
	for e in link.poll():
		match str(e[0]):
			"room":
				_wait("HOSTING (ONLINE)", "Tell your partner this code\n(\"Join with a code\"):", str(e[1]))
			"connect":
				_handover()
				return
			"error":
				_fail(str(e[1]))
				return
			"closed":
				_fail(str(e[1]))
				return
			"disconnect":
				if _mode == "join_lan_connecting":
					_fail("Could not connect to the host.")
					return

func _handover() -> void:
	var l := link
	var host := l.is_host
	link = null
	if _disc:
		_disc.stop()
		_disc = null
	_mode = ""
	if host:
		host_connected.emit(l)
	else:
		guest_connected.emit(l)

func _refresh_found() -> void:
	var found: Dictionary = _disc.found
	var key := ",".join(found.keys())
	if key == _found_key:
		return
	_found_key = key
	for c in _find_list.get_children():
		_find_list.remove_child(c)
		c.queue_free()
	_find_hint.text = "Pick a game:" if not found.is_empty() else "Looking for games…"
	for ip in found:
		var b := m._button("%s  (%s)" % [found[ip].name, ip], func(): _join_lan(ip))
		_find_list.add_child(b)
	if not found.is_empty() and m._screens["net_find"].visible:
		m._grab_default_focus.call_deferred(m._screens["net_find"])
