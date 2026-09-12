class_name EnemyKinds

## Static data for the three classic Galaga enemy tiers.
## Sprites: enemy2_trim/enemy3_trim/enemy4_trim.png, verified against real
## Galaga reference art (enemy4 = exact match for "Boss Galaga", enemy2 =
## close match for the "Zako" bee). enemy1.png didn't match any canonical
## tier (wrong palette) and enemy3.png doesn't match Goei's silhouette either,
## though its red/yellow/blue palette fits Goei's colour tier — used as the
## best available stand-in. Drawn nose-up (-y) at rotation 0, matching the
## old procedural placeholders' convention (enemy.gd rotates to face travel
## direction during flight/dive/return, resets to 0 in formation).

enum { ZAKO, GOEI, BOSS }

const DATA := {
	ZAKO: {"half": 13.0, "points": 50,
		"texture": "res://assets/graphics/enemy2_trim.png", "scale": 0.075},
	GOEI: {"half": 15.0, "points": 80,
		"texture": "res://assets/graphics/enemy3_trim.png", "scale": 0.078},
	BOSS: {"half": 18.0, "points": 150,
		"texture": "res://assets/graphics/enemy4_trim.png", "scale": 0.115},
}

## Stage 2+ visual variety: real 2-frame flap art from the "Gyaraga" fan-art
## series (ss77relaunched on DeviantArt — see galaga's CLAUDE.md). Unlike
## DATA's classic single-frame sprites (flap faked via skew/squash wobble,
## see enemy.gd), these actually swap texture between two drawn frames.
## Cycles by (stage - 2) so stage 2 always starts at variant 0.
const GOEI_VARIANTS := [
	{"frames": ["res://assets/graphics/goei_f0.png", "res://assets/graphics/goei_f1.png"], "scale": 0.24},
	{"frames": ["res://assets/graphics/neo_goei_f0.png", "res://assets/graphics/neo_goei_f1.png"], "scale": 0.24},
]
const ZAKO_VARIANTS := [
	{"frames": ["res://assets/graphics/sasori_f0.png", "res://assets/graphics/sasori_f1.png"], "scale": 0.27},
	{"frames": ["res://assets/graphics/neo_tonbo_f0.png", "res://assets/graphics/neo_tonbo_f1.png"], "scale": 0.20},
]
## "gorg-bos--damaged" (Gyaraga fan-art) — the only one of the two remaining
## unused Gyaraga gifs that turned out to actually be a coherent creature
## sprite; "hyper-smmo.gif" is a scattered decorative icon strip (two
## unrelated flapping gem glyphs over a static, non-animating ship outline),
## not an enemy pose, so it stays unused like enemy1.png (wrong palette).
const BOSS_VARIANTS := [
	{"frames": ["res://assets/graphics/gorg_bos_f0.png", "res://assets/graphics/gorg_bos_f1.png"], "scale": 0.27},
]

## Which texture(s) a formation slot should use, given its kind and the
## current stage. Stage 1 always gets the classic DATA look; stage 2+ cycles
## GOEI/ZAKO/BOSS through the Gyaraga variants above for stage-to-stage variety.
static func pick_visual(kind: int, stage: int) -> Dictionary:
	var variants: Array = []
	match kind:
		GOEI:
			variants = GOEI_VARIANTS
		ZAKO:
			variants = ZAKO_VARIANTS
		BOSS:
			variants = BOSS_VARIANTS
	if stage >= 2 and not variants.is_empty():
		return variants[(stage - 2) % variants.size()]
	return {"frames": [], "texture": DATA[kind]["texture"], "scale": DATA[kind]["scale"]}
