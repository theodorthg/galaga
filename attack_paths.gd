class_name AttackPaths

## Curves for a formation enemy peeling off to dive at the player and, after it
## leaves the bottom of the screen, curving back in from the top to its slot.
## Same Catmull-Rom smoothing as EntryPaths.

## Three distinct shapes, picked at random per dive (not tied to stage) so
## bombing runs don't all look the same within a stage OR read as "stage 4
## repeats stage 1" — see the user report that motion patterns felt too
## similar across stages.
static func dive(slot_pos: Vector2, player_pos: Vector2, vp: Vector2) -> Curve2D:
	var side := -1.0 if slot_pos.x < vp.x * 0.5 else 1.0
	var px: float = clampf(player_pos.x, vp.x * 0.12, vp.x * 0.88)
	match randi() % 3:
		1:
			# wide loop-back: brief hook the "wrong" way, then a big swing out
			# and around before diving through the player
			return _smooth(PackedVector2Array([
				slot_pos,
				slot_pos + Vector2(-side * 40.0, 30.0),
				slot_pos + Vector2(side * 130.0, 10.0),
				Vector2(vp.x * 0.5 + side * vp.x * 0.46, vp.y * 0.42),
				Vector2(px + side * 70.0, vp.y * 0.62),
				Vector2(px - side * 30.0, vp.y * 0.85),
				Vector2(vp.x * 0.5 + side * vp.x * 0.12, vp.y + 90.0),
			]))
		2:
			# steep center plunge with a wag: tighter, more direct, less side travel
			return _smooth(PackedVector2Array([
				slot_pos,
				slot_pos + Vector2(side * 40.0, 20.0),
				Vector2(px - side * 60.0, vp.y * 0.38),
				Vector2(px + side * 70.0, vp.y * 0.58),
				Vector2(px - side * 40.0, vp.y * 0.80),
				Vector2(px, vp.y + 90.0),
			]))
		_:
			# original: peel toward the nearer side wall, sweep down across the player
			return _smooth(PackedVector2Array([
				slot_pos,
				slot_pos + Vector2(side * 70.0, -14.0),
				Vector2(vp.x * 0.5 + side * vp.x * 0.44, vp.y * 0.34),
				Vector2(px - side * 90.0, vp.y * 0.56),
				Vector2(px + side * 50.0, vp.y * 0.78),
				Vector2(vp.x * 0.5 - side * vp.x * 0.18, vp.y + 90.0),
			]))

## Boss-only capture approach: peels out like a normal dive, but stops hovering
## above the player instead of sweeping through — the pause is where the
## tractor beam extends (see enemy.gd's CAPTURE_BEAM state).
static func capture_approach(slot_pos: Vector2, player_pos: Vector2, vp: Vector2) -> Curve2D:
	var side := -1.0 if slot_pos.x < vp.x * 0.5 else 1.0
	var px: float = clampf(player_pos.x, vp.x * 0.15, vp.x * 0.85)
	var hover_y := vp.y * 0.6
	return _smooth(PackedVector2Array([
		slot_pos,
		slot_pos + Vector2(side * 60.0, -10.0),
		Vector2(vp.x * 0.5 + side * vp.x * 0.35, vp.y * 0.3),
		Vector2(px + side * 40.0, hover_y - 70.0),
		Vector2(px, hover_y),
	]))

static func return_to(slot_pos: Vector2, vp: Vector2) -> Curve2D:
	var drift := randf_range(-70.0, 70.0)
	return _smooth(PackedVector2Array([
		Vector2(slot_pos.x + drift, -60.0),
		Vector2(slot_pos.x + drift * 0.4, vp.y * 0.16),
		slot_pos + Vector2(0.0, -34.0),
		slot_pos,
	]))

static func _smooth(pts: PackedVector2Array, tension := 0.35) -> Curve2D:
	var c := Curve2D.new()
	c.bake_interval = 6.0
	var n := pts.size()
	for i in n:
		var prev: Vector2 = pts[maxi(i - 1, 0)]
		var nxt: Vector2 = pts[mini(i + 1, n - 1)]
		var tan := (nxt - prev) * tension
		c.add_point(pts[i], -tan, tan)
	return c
