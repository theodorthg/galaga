class_name EnemyKinds

## Static data for the three classic Galaga enemy tiers.
## Placeholder visuals are drawn procedurally in enemy.gd (_draw); the real
## sprites the user supplies will replace that later.

enum { ZAKO, GOEI, BOSS }

const DATA := {
	ZAKO: {"half": 13.0, "points": 50},   # blue "bee"    — bottom rows
	GOEI: {"half": 15.0, "points": 80},   # red "butterfly" — middle rows
	BOSS: {"half": 18.0, "points": 150},  # green flagship  — top row
}
