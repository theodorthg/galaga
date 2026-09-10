# CLAUDE.md — Galaga

Ergänzt die übergeordnete `CLAUDE.md` unter
`~/GodotDev/learn_2d_gamedev_godot_4_0.57.0_linux/`.

**Stand: v0.1.0.** Scaffolding + Phasen 1–4 durch. Fertig: **Formation +
Einflug**, **Sturzflüge + Gegnerfeuer** (P1), **Leben / HUD / Game-Over** (P2),
**Touch + Aspect-Umschaltung + Pause** (P3), **Menüs / Settings / Sound /
Hall of Fame** (P4).
40er-Formation, gruppenweiser Einflug entlang Kurven, prozedurale Platzhalter
mit 2-Frame-Flap. Divers peelen einzeln raus, sweepen am Spieler vorbei (Bomben
werfend), fliegen unten raus und kehren von oben in ihren Slot zurück.
Start-Screen (Play / Einstellungen / Steuerung / Beenden), Pausenmenü,
Einstellungen (Leben / Extra-Leben / Schwierigkeit → live in die nächste Runde),
Sound-Unterseite (Regler pro Sound), bildlose Hilfe (3 Seiten), Game-Over mit
Hall of Fame + Namenseingabe. **Sounds sind Platzhalter-WAVs** (synthetisch via
`gen_sounds.py`) — echte Audios kommen später.
Als Nächstes: Polish + auf echten Geräten testen, Sprites/Splash vom Nutzer.

## Gameplay-Architektur (alles im Code, wie tetris)

Main-Scene `game.tscn` (Node2D `Game` + `game.gd`): SpaceBackground, Formation,
StageDirector, Ship, HUD-CanvasLayer.

- `game.gd` (`class_name Game`) — State-Machine TITLE → READY → ENTERING →
  FORMATION → GAME_OVER + `_paused`. `_new_run()` (aus Titel/„Nochmal"): liest
  `GameSettings`, setzt Leben/Extra-Leben-Schwelle, `_director.configure(...)`
  aus der Schwierigkeit, räumt das Feld (`_clear_board`), entpausiert, Musik an.
  Ship `died` → Leben−1 → respawn nach 1,2 s bzw. bei 0 → GAME_OVER (1 s Delay,
  dann `menus.show_game_over`, Tree pausiert). Pause (`pause`-Action / HUD-Button)
  → Tree pausiert + `menus.show_pause()`. `_enter_title()` bei „Zum Titel".
  `_snd` = `get_node_or_null("/root/Snd")` (bare `Snd` bricht `_selftest`).
  `content_scale_aspect` KEEP/KEEP_WIDTH je Touch. `process_mode = ALWAYS`.
- `hud.gd` (`class_name Hud`) — **nur noch das In-Game-HUD**: Score (oben links),
  Stage (unten rechts), Leben als gezeichnete Marken (unten links, `_draw`),
  Center-Banner, Touch-Pause-Button (`set_touch`), Signal `pause_pressed`,
  `set_playing(on)` blendet das ganze HUD bei offenem Menü aus. Titel / Pause /
  Settings / Game-Over macht jetzt `menus.gd`.
- `menus.gd` (`class_name Menus`, eigener `CanvasLayer` in `game.tscn`,
  `process_mode = ALWAYS`) — alle Menü-Screens im Code wie tetris' `ui.gd`:
  Titel, Pause, Einstellungen (Stepper Leben / Extra-Leben / Schwierigkeit),
  Sound-Unterseite (HSlider pro Sound, Loslassen = Vorhören), Hilfe (3 Textseiten
  mit ‹/›), Game-Over + Hall-of-Fame-Liste + Namenseingabe bei Qualifikation.
  Signale `start_game` / `resume_game` / `to_title` / `settings_changed`.
  „Beenden" nur wenn nicht `OS.has_feature("web")`.
- `game_settings.gd` (`class_name GameSettings`) — `user://settings.cfg` `[s]`:
  `lives` (2–5), `extra_life` (0/10k/20k/30k), `difficulty` (0–2).
  `dive_params(difficulty)` → `{first, min, max, max_divers}` für den Director.
- `hall_of_fame.gd` (`class_name HallOfFame`) — `user://hall_of_fame.cfg`, Top 10
  nach Score (`qualifies` / `insert`).
- `sound_manager.gd` (Autoload `Snd`, `project.godot [autoload]`) — ein
  `AudioStreamPlayer` je Key, Clip `res://assets/sounds/<key>.wav` (fällt auf
  `.ogg` zurück; fehlt die Datei → still). Pro-Sound-Lautstärke 0–100 in
  `user://settings.cfg [sound]` + `calib_version`, `_BASE_DB`-Kalibrierung je
  Sound. Musik-Loop manuell über `finished` (WAV-Import loopt nicht von selbst).
  Keys: `music shoot hit dive player_boom extra stage`. **Aktuell
  Platzhalter-WAVs** aus `gen_sounds.py` (synthetische
  Blips) — bei echten Audios einfach die Dateien in `assets/sounds/` ersetzen.

### Geräte-Layout (Phase 3)

Feste Design-Canvas 540×960 + `stretch/mode=canvas_items`. `game.gd` erkennt
Touch (`OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()`,
gecacht) und schaltet zur Laufzeit `content_scale_aspect`:
Desktop → `KEEP` (Letterbox), Touch → `KEEP_WIDTH` (Feld oben angepinnt,
Überhöhe fällt unter das Feld — Fingerbereich). **Retroaktiver Flip**: `game.gd`
und `ship.gd` sind in Gruppe `touch_layout_listeners` mit `apply_touch_layout()`;
`game._input` löst beim ersten echten `InputEventScreenTouch/Drag` einen
`call_group(...)` aus (manche Mobil-Browser melden Touch verspätet).

Gameplay-Positionen (Formation `home.y`, Schiff-y, HUD) sind **fix gegen die
960er-Canvas**, nicht gegen `get_viewport_rect()` — die Überhöhe bleibt so
freier Raum unten. (Ausnahme: `attack_paths`/`bomb` nehmen noch die echte
Viewport-Höhe; Divers/Bomben laufen auf hohen Phones etwas weiter runter, bevor
sie despawnen — unkritisch, ggf. später gegen 960 festnageln.)

Steuerung Touch: **Drag irgendwo** = relatives Lenken (`ship._unhandled_input`,
`event.relative.x`), **Auto-Fire** solange lebendig. Pause: Button oder
`pause`-Action; bei Pause zusätzlich Tap = Resume.
- `formation.gd` (`class_name Formation`) — 40 Slots (`ROWS`: 4 Boss / 8+8 Goei /
  10+10 Zako), Slot-Geometrie, „Breathing"-Sway des ganzen Blocks, Flap-Timer
  (`flap_toggled`), Belegungs-Tracking (`assign`/`release`/`live_count`).
- `entry_paths.gd` (`class_name EntryPaths`) — 3 Einflug-Muster (`BOTTOM_UP`,
  `TOP_LEFT`, `TOP_RIGHT`) als viewport-skalierte `Curve2D`, Catmull-Rom-Tangenten.
- `attack_paths.gd` (`class_name AttackPaths`) — `dive(slot, player, vp)` (peelt
  zur Wand, sweept am Spieler vorbei, unten raus) und `return_to(slot, vp)`
  (von oben zurück in den Slot). Gleiches Catmull-Rom-Smoothing wie EntryPaths.
- `stage_director.gd` (`class_name StageDirector`) — **Fly-in**: 40 Slots in
  5er-Gruppen à 8 entlang einer Kurve (Launch-Versatz 0,16 s; Gruppen 0,9 s),
  meldet `stage_populated`. **Attacks**: nach `begin_attacks()` schickt alle
  1,3–3,2 s einen zufälligen Formations-Gegner ins `dive()`, max. 3 gleichzeitig
  (`_launch_dive` zählt über `is_active_diver()`/`is_available_to_dive()`).
  `stop_attacks()` beim Stage-Wechsel. Reicht `enemy_killed(points)` durch.
- `enemy.gd` (Area2D, kein `class_name`) — States FLYING_IN / LOCKING /
  IN_FORMATION / **DIVING / RETURNING**. Generischer Path-Follower
  (`_start_path(curve, speed, done_callable)`): FLY 480 / DIVE 300 / RETURN
  360 px/s, Ausrichtung nach Fahrtrichtung, dann 0,4-s-Tween in den Slot.
  Beim `dive()` gibt der Gegner seinen Slot frei (`_formation.release`), wirft
  bis zu 2 Bomben (`bomb.tscn`), kehrt nach dem Kurvenende via `return_to`
  zurück und belegt den Slot neu. `_draw()` je Kind (nach unten gerichtet),
  Flap aus `Formation.flap`. Kollision Layer 4 / Maske 8.
- `bomb.gd` / `bomb.tscn` — Gegner-Schuss, fällt (leicht Richtung Spieler-x zum
  Abwurfzeitpunkt), Platzhalter-Raute. Layer 16 (enemy_shots) / Maske 9
  (player + player_shots — Laser können Bomben abschießen).
- `laser.gd` — Platzhalter-Strich im `_draw()` (laser.png raus), Layer 8,
  Hitbox 5×16.
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

**Erledigt:** Phasen 1–4 (Formation+Einflug, Sturzflüge+Gegnerfeuer, Leben/HUD/
Game-Over, Touch+Aspect+Pause, Menüs/Settings/Sound/HoF).

1. **Echte Sounds** — aktuell synthetische Platzhalter-WAVs (`gen_sounds.py` in der Projektwurzel). Der Nutzer liefert richtige; dann die 7 Dateien in
   `assets/sounds/` ersetzen (`music shoot hit dive player_boom extra stage`).
   `_BASE_DB` je Sound ggf. neu kalibrieren, `calib_version` hochzählen.
2. **Sprites vom Nutzer** — je Einheit **mind. 2 Frames**, evtl. `.gif`.
   Pipeline: `.gif` → Aseprite-MCP → `SpriteFrames`. Ersetzt das `_draw()` in
   `enemy.gd` (und Schiff/Laser/Bombe). Bis dahin prozedurale Platzhalter.
3. **`splash-screen.png`** (Bindestrich, Wurzel) fehlt — liefern/generieren,
   dann Boot-Splash + Ladescreen.
4. **Auf echten Geräten testen** (OPPO Find X2 Pro, OnePlus 12 ≈ 2,2:1;
   Galaxy S4 = 16:9): Aspect-Umschaltung, Touch-Drag, Pause-Button-Position,
   Formation-Größe. In beiden Ratios im echten Browser screenshotten.
   Canvas-Wechsel bliebe ein Einzeiler in `project.godot`.
5. **Hilfe bildbasiert** (optional) — derzeit 3 Textseiten in `menus.gd`
   (`HELP_PAGES`). tetris macht's mit SVG→PNG (`assets/help_src/` + `render.sh`).
   Reicht vorerst als Text.
6. `assets/` aufräumen (lose Test-PNGs, Loot-System `item.gd`/`gem.tscn`/… —
   Galaga hat keins), HUD-Feinschliff, „1UP"-Flash beim Extra-Leben.
7. Später evtl.: Boss-Capture (Traktorstrahl fängt Schiff → nach Boss-Abschuss
   Doppel-Jäger), Challenging/Bonus-Stage, Combo-Scoring, Auto-Fire als
   abschaltbares Setting, Diver/Bomben gegen die 960er-Canvas festnageln statt
   `get_viewport_rect()`. Fällt uns sicher noch mehr ein.

## Aseprite MCP Pro

Bei Nutzung der Aseprite-MCP-Pro-Tools (`mcp__aseprite-mcp-pro__*`) dem
Pixel-Art-Skill-Guide folgen:
@/home/bernd/GodotDev/learn_2d_gamedev_godot_4_0.57.0_linux/aseprite-mcp-pro-server/skills.md
