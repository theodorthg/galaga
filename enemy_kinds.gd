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
