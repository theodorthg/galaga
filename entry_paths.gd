class_name EntryPaths

## Classic Galaga fly-in choreography as smooth Curve2D paths, sized to the
## current viewport. Every enemy in a group follows the same curve nose-to-tail;
## the short hop from the curve's end to each enemy's own formation slot is a
## tween (see enemy.gd), which fans the group out into its row.

enum { BOTTOM_UP, TOP_LEFT, TOP_RIGHT }

static func make(pattern: int, vp: Vector2) -> Curve2D:
	match pattern:
		TOP_LEFT:
			return _smooth(_top_side(vp, -1.0))
		TOP_RIGHT:
			return _smooth(_top_side(vp, 1.0))
		_:
			return _smooth(_bottom_up(vp))

# rises from below centre, loops once near the top, heads back down to formation
static func _bottom_up(vp: Vector2) -> PackedVector2Array:
	var w := vp.x
	var h := vp.y
	return PackedVector2Array([
		Vector2(w * 0.50, h + 70.0),
		Vector2(w * 0.50, h * 0.62),
		Vector2(w * 0.30, h * 0.40),
		Vector2(w * 0.30, h * 0.19),
		Vector2(w * 0.50, h * 0.11),
		Vector2(w * 0.70, h * 0.19),
		Vector2(w * 0.62, h * 0.35),
		Vector2(w * 0.50, h * 0.30),
	])

# sweeps in from off-screen left (dir -1) or right (dir +1), curls, settles
static func _top_side(vp: Vector2, dir: float) -> PackedVector2Array:
	var w := vp.x
	var h := vp.y
	var start_x := w * 0.5 + dir * (w * 0.5 + 70.0)
	return PackedVector2Array([
		Vector2(start_x, h * 0.09),
		Vector2(w * 0.5 + dir * w * 0.20, h * 0.11),
		Vector2(w * 0.5 - dir * w * 0.10, h * 0.30),
		Vector2(w * 0.5 - dir * w * 0.22, h * 0.42),
		Vector2(w * 0.5 - dir * w * 0.02, h * 0.35),
		Vector2(w * 0.5, h * 0.27),
	])

# Catmull-Rom-ish tangents so add_point() gives a fair curve without hand-tuned handles
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
