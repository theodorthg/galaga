class_name HallOfFame

## Top-10 score board, persisted in user://hall_of_fame.cfg.

const PATH := "user://hall_of_fame.cfg"
const MAX := 10

static func load_list() -> Array:
	var c := ConfigFile.new()
	if c.load(PATH) != OK:
		return []
	var raw = c.get_value("hof", "entries", [])
	return raw if raw is Array else []

static func _save_list(list: Array) -> void:
	var c := ConfigFile.new()
	c.set_value("hof", "entries", list)
	c.save(PATH)

static func qualifies(score: int) -> bool:
	if score <= 0:
		return false
	var list := load_list()
	if list.size() < MAX:
		return true
	return score > int(list[list.size() - 1].get("score", 0))

## The rank (1-based) `score` would land at if entered right now, or -1 if it
## doesn't qualify (see qualifies() above) — used by the run-summary screen
## (menus.gd::show_run_summary()) to tell the player where they'd land BEFORE
## they actually type a name in.
static func rank_for(score: int) -> int:
	if not qualifies(score):
		return -1
	var list := load_list()
	var rank := 1
	for e in list:
		if score <= int(e.get("score", 0)):
			rank += 1
	return rank

static func insert(who: String, score: int, stage: int) -> Array:
	var list := load_list()
	list.append({"name": who, "score": score, "stage": stage})
	list.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))
	if list.size() > MAX:
		list = list.slice(0, MAX)
	_save_list(list)
	return list
