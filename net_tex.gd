class_name NetTex

## Texture table shared by host and guest: a snapshot names a sprite's texture
## by its index here instead of sending a path. Built from the same constants on
## both sides, so the indices always agree (same game version — NetLink checks
## major.minor).

static var _paths: Array = []
static var _index := {}
static var _cache := {}

static func _build() -> void:
	if not _paths.is_empty():
		return
	var list: Array = ["res://assets/graphics/player_trim.png", "res://assets/graphics/ship_captured.png"]
	for k in EnemyKinds.DATA:
		list.append(EnemyKinds.DATA[k]["texture"])
	for variants in [EnemyKinds.GOEI_VARIANTS, EnemyKinds.ZAKO_VARIANTS, EnemyKinds.BOSS_VARIANTS]:
		for v in variants:
			for f in v["frames"]:
				list.append(f)
	for i in 16:
		list.append("res://assets/graphics/achievement_%02d.png" % i)
	_paths = list
	for i in list.size():
		_index[list[i]] = i

## -1 when the texture is not in the table (then the sprite is simply not sent).
static func index_of(tex: Texture2D) -> int:
	_build()
	if tex == null:
		return -1
	return int(_index.get(tex.resource_path, -1))

static func get_tex(i: int) -> Texture2D:
	_build()
	if i < 0 or i >= _paths.size():
		return null
	if not _cache.has(i):
		_cache[i] = load(_paths[i])
	return _cache[i]

## Table index of achievement_NN.png (the HUD row is sent as plain NN values).
static func index_of_achievement(n: int) -> int:
	_build()
	return int(_index.get("res://assets/graphics/achievement_%02d.png" % n, -1))
