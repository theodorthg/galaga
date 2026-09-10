extends Area2D

# Hier lädt das Schiff die Laser-Vorlage (Klasse) in den Speicher
var laser_scene = preload("res://laser.tscn")

# Konstante Geschwindigkeit für ein typisches Arcade-Gefühl
var speed := 550.0 
var ship_count := 100 # In Galaga eher "Leben", z.B. 3
var gem_count := 0

# Definiert den halben Durchmesser des Sprites, damit das Schiff 
# nicht zur Hälfte aus dem Bildschirm ragt, bevor es stoppt.
var ship_half_width := 50.0 
var viewport_width := 0.0

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	set_ship_count(ship_count)
	# get_node("Sprite2D").rotation = -1.58
	# Bildschirmbreite einmalig speichern
	viewport_width = get_viewport_rect().size.x
# NEU: Das Schiff automatisch im unteren Bereich platzieren
	# get_viewport_rect().size.y ist die maximale Bildschirmhöhe. 
	# Wir ziehen z.B. 80 Pixel ab, damit es etwas über dem unteren Rand schwebt.
	# position.y = get_viewport_rect().size.y + 130.0
func set_gem_count(new_gem_count: int) -> void:
	gem_count = new_gem_count
	get_node("UI/GemCount").text = "x" + str(gem_count)

func set_ship_count(new_ship_count: int) -> void:
	ship_count = new_ship_count
	# Optional: Verhindern, dass Health über 100 steigt
	ship_count = clampi(ship_count, 0, 100) 
	get_node("UI/HealthBar").value = ship_count
	
	if ship_count <= 0:
		get_tree().change_scene_to_file("res://game_over.tscn")

# Maus als zusätzliche Steuerung: sobald die Maus bewegt wird, folgt das Schiff
# ihrer X-Position; die nächste Tastatur-/Pad-Eingabe übernimmt wieder.
var _mouse_aim := false

func _process(delta: float) -> void:
	var direction_x := Input.get_axis("move_left", "move_right")

	if direction_x != 0.0:
		_mouse_aim = false
		position.x += direction_x * speed * delta
	elif _mouse_aim:
		position.x = move_toward(position.x, get_global_mouse_position().x, speed * delta)

	# Bewegung an den Rändern blockieren
	position.x = clamp(position.x, ship_half_width, viewport_width - ship_half_width)

	if Input.is_action_just_pressed("shoot"):
		shoot()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_aim = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		shoot()

# (Optional kannst Du das auch ganz oben bei Deinen Variablen definieren)
var max_lasers := 3 

func shoot() -> void:
	# 1. Wir zählen, wie viele Objekte aktuell in der Gruppe "player_lasers" sind
	var current_lasers = get_tree().get_nodes_in_group("player_lasers").size()
	
	# 2. Wenn das Limit erreicht ist, brechen wir die Funktion hier ab (return)
	if current_lasers >= max_lasers:
		return 
		
	# 3. Das Limit ist nicht erreicht: Wir erzeugen den Laser
	var laser = laser_scene.instantiate()
	
	# NEU: 4. Wir kleben dem neuen Laser das "Namensschild" an
	laser.add_to_group("player_lasers")
	
	# 5. Dem Level hinzufügen und positionieren
	get_parent().add_child(laser)
	laser.position = position
	laser.position.y -= 20.0

func _on_area_entered(area_that_entered: Area2D) -> void:
	if area_that_entered.is_in_group("healing_item"):
		set_ship_count(ship_count + 1)
	elif area_that_entered.is_in_group("gem"):
		set_gem_count(gem_count + 1)
	elif area_that_entered.is_in_group("enemy"):
		# Späterer Galaga-Code: Kollision mit einem Gegner
		set_ship_count(ship_count - 1) # Oder: Leben - 1
		# area_that_entered.queue_free() # Zerstört den Gegner bei Ramm-Kollision
