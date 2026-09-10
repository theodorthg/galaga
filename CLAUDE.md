# CLAUDE.md — Galaga

Ergänzt die übergeordnete `CLAUDE.md` unter
`~/GodotDev/learn_2d_gamedev_godot_4_0.57.0_linux/`.

**Stand: v0.1.0.** Scaffolding steht. **Formation + Einflug fertig** (erster
Galaga-Baustein): 40er-Formation in 5 Reihen, gruppenweiser Einflug entlang
Kurven, prozedurale Platzhalter-Gegner mit 2-Frame-Flügelschlag. Als Nächstes:
Sturzflüge + Gegnerfeuer.

## Gameplay-Architektur (alles im Code, wie tetris)

Main-Scene `game.tscn` (Node2D `Game` + `game.gd`): SpaceBackground, Formation,
StageDirector, Ship, HUD-CanvasLayer.

- `game.gd` (`class_name Game`) — State-Machine READY → ENTERING → FORMATION,
  Stage-Zähler, Score, `content_scale_aspect = KEEP` (Desktop; Touch-Umschaltung
  noch offen). Formation leergeräumt → nächste Stage.
- `formation.gd` (`class_name Formation`) — 40 Slots (`ROWS`: 4 Boss / 8+8 Goei /
  10+10 Zako), Slot-Geometrie, „Breathing"-Sway des ganzen Blocks, Flap-Timer
  (`flap_toggled`), Belegungs-Tracking (`assign`/`release`/`live_count`).
- `entry_paths.gd` (`class_name EntryPaths`) — 3 klassische Einflug-Muster
  (`BOTTOM_UP`, `TOP_LEFT`, `TOP_RIGHT`) als `Curve2D`, viewport-skaliert,
  Catmull-Rom-Tangenten.
- `stage_director.gd` (`class_name StageDirector`) — teilt die 40 Slots in
  5er-Gruppen à 8, schickt jede Gruppe entlang einer Kurve (Launch-Versatz
  0,16 s; Gruppen-Abstand 0,9 s), meldet `stage_populated`, reicht
  `enemy_killed(points)` durch.
- `enemy.gd` (Area2D, kein `class_name`) — States FLYING_IN → LOCKING →
  IN_FORMATION. Kurvenfahrt mit konstant 480 px/s + Ausrichtung nach
  Fahrtrichtung, dann 0,45-s-Tween in den Slot. `_draw()` zeichnet den
  Platzhalter je Kind (nach unten gerichtet), Flügelschlag aus `Formation.flap`.
  Kollision: Layer 4 (enemies) / Maske 8 (player_shots); Laser jetzt Layer 8.
- `enemy_kinds.gd` (`class_name EnemyKinds`) — ZAKO/GOEI/BOSS: Radius + Punkte.

`_capture.tscn`/`_capture.gd` (gitignored): lädt `game.tscn`, schießt Frames des
Einflugs als PNG. `godot --path . res://_capture.tscn -- <out_dir>` (braucht
DISPLAY, kein `--headless`).

Bestand aus dem Twin-Stick-Modul (noch da, teils ungenutzt): `ship.gd`
(Bewegung + Schuss, jetzt **+ Maus**: Schiff folgt Cursor-X, Linksklick
schießt), `laser.gd`, `item.gd`/`gem.tscn`/`health_pack.tscn`/
`random_item_placer.*` (Loot-System — Galaga hat keins; aufräumen oder für
Powerups behalten). `game_over.tscn` mit kaputten Querformat-Offsets.
`ship.tscn` HealthBar-`UI` ist ausgeblendet.

## Herkunft / Bestand

- `ship.gd` — horizontale Bewegung + `clamp`, Schuss mit 3-Laser-Limit
  (Gruppe `player_lasers`). „Leben" heißt noch `ship_count`, HealthBar 0–100.
- `enemy.gd` — stirbt bei Laser-Treffer, sonst nichts. Keine Formation,
  Bewegung, Sturzflug, kein Gegnerfeuer.
- `laser.gd` — fliegt hoch, `queue_free` bei `screen_exited`.
- `item.gd` / `random_item_placer.gd` — Gem/Health-Spawner aus dem twin-stick-
  Modul, in `galaga_level.tscn` auf `visible=false`.
- `game_over.tscn` — nur ein Label, Offsets noch aus altem 1152×648-Querformat
  (muss mit den Menüs neu gebaut werden).
- `assets/background/` — funktionierender Shader-Sternenhimmel (`star_field.gdshader`).
- `assets/ship_visual_effects/` — Thruster-Effekte (Shader + Partikel).
- `assets/Images/` + `assets/PSD/` — Galaga-Asset-Pack (player, enemy1–4).
- Viele lose Test-Sprites in `assets/` (canvas*.png, enemy1.jpeg, Gemini_*…) —
  vor dem ersten „echten" Commit-Meilenstein aufräumen.

## Design-Entscheidungen (bestätigt)

- **Voller Galaga-Umfang** als Ziel: Formation oben, Einflug-Choreo, Sturzflüge
  (`Path2D`/Tween), Gegnerfeuer, „Boss-Galaga fängt dein Schiff"-Mechanik,
  Wellen/Stages, Score + Extra-Leben.
- **Hochkant.** Design-Canvas aktuell **540×960** (9:16) — siehe „Offen".
- **Steuerung Desktop/Browser:**
  - Tastatur: ← → / A D bewegen, **Leertaste / ↑** schießen, Esc/P Pause.
  - Gamepad: D-Pad/Stick links-rechts, A schießen, Start Pause.
  - **Maus (zusätzlich):** Schiff folgt der Cursor-X-Position, Linksklick
    schießt.
- **Touch:** Swipe/Drag links-rechts zum Steuern, Tap schießt (Auto-Fire
  optional), Pause-Button im oberen Band. Auto-Erkennung + retroaktiver Flip
  wie pacman/tetris.
- Menüs: Start-Screen (Play / Settings / How to Play), Pause-Overlay,
  Game-Over/Win — Exit als letzter Button, ausgeblendet unter `OS.has_feature("web")`.
- Settings (Start **und** Pause): Schwierigkeits-/Punkte-Gruppe +
  Sound-Unterseite mit Pro-Sound-Lautstärke. Persistenz `user://settings.cfg`.

## Bauen & Testen (Editor bleibt zu)

Editor läuft aktuell auf **tetris**, nicht galaga — headless-Bauen für galaga ist
also unbedenklich. Vor jedem Lauf `ps aux | grep '[g]odot.*--editor'` prüfen.

```
bash projects/galaga/build.sh            # Linux + Web + Android (+ adb install)
bash projects/galaga/build.sh web        # einzeln: linux | web | android
```

- **Selbsttest:** `godot --headless --path . --script res://_selftest.gd`
  (bislang nur Parse-Check + Config-Sanity; wächst mit den Mechaniken).
- **Linux:** `projects/galaga-linux.x86_64`
- **Web:** `cd projects/web-release-galaga && python3 -m http.server 8099`
  (In-App-Browser hat kein WebGL → echtes Chrome). `chrome-devtools`-MCP ist
  `-s local` für dieses Projekt registriert (`mcp__chrome-devtools__*`).
- **Windows:** CI, Release-Tag `vX.Y.Z` pushen (`config/version` vorher setzen).

## Offen / als Nächstes

1. **Design-Canvas ausprobieren:** 540×960 gewählt, weil das exakt der 16:9-Ratio
   des Galaxy S4 entspricht (dort perfekter Vollbild-Fit, kein verschenkter
   Rand) und die 2,2:1-Geräte (OPPO Find X2 Pro, OnePlus 12) mit
   `CONTENT_SCALE_ASPECT_KEEP_WIDTH` ein komfortables Touch-Band unter dem
   Spielfeld bekommen. Sobald Start-Screen + Spielfeld + HUD stehen: in allen
   drei Geräte-Ratios (2,2:1 und 16:9) im Browser screenshotten und ggf.
   nachziehen. Canvas-Wechsel ist ein Einzeiler in `project.godot` + Layout-Code,
   der ohnehin aus `get_viewport_rect()` rechnet.
2. **Sturzflüge + Gegnerfeuer** (nächster Schritt): Angriffs-Scheduler im
   StageDirector, DIVING/RETURNING-States im `enemy.gd`, Angriffskurven,
   Boss-Capture-Mechanik. Danach: mehrere Waves/Stages, Challenging Stage.
3. Ship-Treffer (Layer/Maske Ship↔Enemy + Enemy-Shots), echte 3 Leben statt
   `ship_count=100`, HUD (Leben, Stage), Game-Over/Win-Screen neu bauen.
4. Laufzeit-`content_scale_aspect`-Umschaltung (Desktop KEEP / Touch KEEP_WIDTH)
   + Touch-Swipe-Steuerung + Touch-HUD oben.
5. Menüs + Settings + `sound_manager.gd` nach pacman-Muster.
6. **Sprites vom Nutzer** — kommen nach, je Einheit **mind. 2 Frames als
   Animation**, evtl. als `.gif`. Pipeline: `.gif` → Aseprite-MCP
   (`open_sprite`/Frames extrahieren) → `export_sprite_sheet` bzw.
   `generate_spriteframes_tres` → `SpriteFrames`. Ersetzt das `_draw()` in
   `enemy.gd`. Bis dahin bleiben die prozeduralen Platzhalter.
7. **`splash-screen.png`** (Bindestrich, Wurzelverzeichnis) fehlt noch —
   vom Nutzer liefern lassen oder generieren, dann als Boot-Splash + Ladescreen.
8. **Design-Canvas ausprobieren:** 540×960 gewählt = exakt 16:9 des Galaxy S4
   (perfekter Vollbild-Fit); 2,2:1-Geräte (OPPO Find X2 Pro, OnePlus 12) kriegen
   mit `KEEP_WIDTH` ein Touch-Band unter dem Spielfeld. Sobald Start-Screen +
   HUD stehen: in beiden Ratios im Browser screenshotten, ggf. nachziehen
   (Einzeiler in `project.godot`, Layout rechnet aus `get_viewport_rect()`).
9. `assets/` aufräumen (lose Test-PNGs, Loot-System entscheiden), HUD responsiv,
   Formation-Feinschliff (Reihenabstand etwas eng).

## Aseprite MCP Pro

Bei Nutzung der Aseprite-MCP-Pro-Tools (`mcp__aseprite-mcp-pro__*`) dem
Pixel-Art-Skill-Guide folgen:
@/home/bernd/GodotDev/learn_2d_gamedev_godot_4_0.57.0_linux/aseprite-mcp-pro-server/skills.md
