class_name AttackPaths

## Curves for a formation enemy peeling off to dive at the player and, after it
## leaves the bottom of the screen, curving back in from the top to its slot.
## Same Catmull-Rom smoothing as EntryPaths.

static func dive(slot_pos: Vector2, player_pos: Vector2, vp: Vector2) -> Curve2D:
	# peel toward the nearer side wall, then sweep down across the player
	var side := -1.0 if slot_pos.x < vp.x * 0.5 else 1.0
	var px: float = clampf(player_pos.x, vp.x * 0.12, vp.x * 0.88)
	return _smooth(PackedVector2Array([
		slot_pos,
		slot_pos + Vector2(side * 70.0, -14.0),
		Vector2(vp.x * 0.5 + side * vp.x * 0.44, vp.y * 0.34),
		Vector2(px - side * 90.0, vp.y * 0.56),
		Vector2(px + side * 50.0, vp.y * 0.78),
		Vector2(vp.x * 0.5 - side * vp.x * 0.18, vp.y + 90.0),
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
