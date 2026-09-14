class_name GameSettings

## Gameplay settings — persisted in user://settings.cfg section [s], shared by
## the start-screen and pause Settings menu. (Sound volumes are a separate
## section owned by sound_manager.gd.)

const CFG_PATH := "user://settings.cfg"

const DEF := {
	"lives": 3,          # LIVES_MIN..LIVES_MAX
	"extra_life": 5000,  # 0 = off, sonst EXTRA_STEP..EXTRA_MAX in EXTRA_STEP-Schritten
	                     # (user request 2026-09-13; bewusst NICHT mehr an boss_interval
	                     # gekoppelt, seit der auf 10000 hochging — 2026-09-14)
	"difficulty": 1,     # 0 easy, 1 normal, 2 hard
	"max_shots": 2,      # MAX_SHOTS_MIN..MAX_SHOTS_MAX, gleichzeitig fliegende Laser
	"boss_interval": 10000, # 0 = off, sonst BOSS_INTERVAL_STEP..BOSS_INTERVAL_MAX in
	                        # BOSS_INTERVAL_STEP-Schritten — garantierter Boss-Capture-
	                        # Versuch alle N Punkte, zusätzlich zur Zufallschance; beide
	                        # Wege zusammen max. EIN Fang pro Stage (stage_director.gd)
	                        # — 5000 → 10000 am 2026-09-14 (fühlte sich zu häufig an)
	"win_score": 100000,    # 0 = aus (endlos wie bisher), sonst WIN_SCORE_STEP..
	                        # WIN_SCORE_MAX — Zielscore für ein "gewonnenes" Spiel
	                        # (eigener Eintrag in derselben Hall of Fame)
}

const LIVES_MIN := 2
const LIVES_MAX := 9
const EXTRA_MAX := 30000
const EXTRA_STEP := 1000
const MAX_SHOTS_MIN := 1
const MAX_SHOTS_MAX := 5
const BOSS_INTERVAL_MAX := 20000
const BOSS_INTERVAL_STEP := 1000
const WIN_SCORE_MAX := 500000
const WIN_SCORE_STEP := 10000
const DIFF_NAMES := ["Leicht", "Normal", "Schwer"]

static func load_all() -> Dictionary:
	var out := DEF.duplicate()
	var c := ConfigFile.new()
	if c.load(CFG_PATH) == OK:
		for k in DEF:
			out[k] = c.get_value("s", k, DEF[k])
	return out

static func save(data: Dictionary) -> void:
	var c := ConfigFile.new()
	c.load(CFG_PATH)
	for k in data:
		c.set_value("s", k, data[k])
	c.save(CFG_PATH)

# difficulty -> StageDirector attack tuning
static func dive_params(difficulty: int) -> Dictionary:
	match difficulty:
		0:
			return {"first": 3.0, "min": 2.2, "max": 4.6, "max_divers": 2}
		2:
			return {"first": 1.0, "min": 0.8, "max": 1.9, "max_divers": 4}
		_:
			return {"first": 1.8, "min": 1.3, "max": 3.2, "max_divers": 3}
