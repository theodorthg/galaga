# CLAUDE.md — Galaga

Ergänzt die übergeordnete `CLAUDE.md` unter
`~/GodotDev/learn_2d_gamedev_godot_4_0.57.0_linux/`.

**Stand: v0.1.0 (2026-09-12).** Scaffolding + Phasen 1–5 durch. Fertig:
**Formation + Einflug**, **Sturzflüge + Gegnerfeuer** (P1), **Leben / HUD /
Game-Over** (P2), **Touch + Aspect-Umschaltung + Pause** (P3), **Menüs /
Settings / Sound / Hall of Fame** (P4), **echte Assets + Boss-Capture** (P5).
40er-Formation, gruppenweiser Einflug entlang Kurven, echte Sprites mit
Skew/Squash-Flügelschlag (siehe „Erste echte Assets" unten). Divers peelen
einzeln raus, sweepen am Spieler vorbei (Bomben werfend), fliegen unten raus
und kehren von oben in ihren Slot zurück. Bosse können stattdessen einen
Capture-Anflug fliegen (Traktorstrahl, Zwillingsjäger-Belohnung — siehe
„Boss-Capture" unten).
Start-Screen (Play / Einstellungen / Steuerung / Beenden), Pausenmenü,
Einstellungen (Leben / Extra-Leben / Schwierigkeit → live in die nächste Runde),
Sound-Unterseite (Regler pro Sound), bildlose Hilfe (3 Seiten), Game-Over mit
Hall of Fame + Namenseingabe + „Beenden". **Sounds sind echte SFX-Rips**
(siehe „Erste echte Assets" unten), nicht mehr die `gen_sounds.py`-Platzhalter.
**Nicht mehr pausiert** — die Assets sind da, Gameplay-Weiterbau läuft normal
weiter. Offen bleibt vor allem: zusätzliche Gegnertypen für spätere
Stages/Bonuslevel (siehe „Offen" unten — Umfang/Look mit dem Nutzer noch
nicht final besprochen, bewusst zurückgestellt statt ungefragt reingebaut).

**Nach Nutzer-Test gefundene + gefixte Bugs (2026-09-11):**
- **Linksklick schoss nicht** — `space_background.tscn`s vollflächiges
  `ColorRect` hatte kein `mouse_filter` gesetzt → Godot-Default `STOP` fraß
  jeden Mausklick, bevor `ship.gd::_unhandled_input` ihn sah. Fix:
  `mouse_filter = 2` (IGNORE) auf dem ColorRect.
- **Pause pausierte das Gameplay nicht wirklich** (nebenbei entdeckt, per
  Diagnose-Capture verifiziert: 40/41 Objekte bewegten sich trotz Pause) —
  `Game.process_mode = ALWAYS` (nötig fürs Pausenmenü) vererbt sich an alle
  Kinder ohne eigene Einstellung. Fix: `process_mode = PROCESS_MODE_PAUSABLE`
  explizit in `_ready()` von `ship.gd`, `formation.gd`, `stage_director.gd`,
  `enemy.gd`, `laser.gd`, `bomb.gd` — bricht die Vererbung, alles friert bei
  `get_tree().paused` jetzt korrekt ein. Bekannte Lücke: `get_tree().create_timer()`
  läuft standardmäßig mit `process_always=true` weiter, d. h. pausiert man exakt
  während des ~8-s-Einflugs (READY/ENTERING-State), zählt der Gruppen-Timer im
  StageDirector im Hintergrund weiter. Seltener Randfall, nicht gefixt.
- „Zum Titel"/„Titel"-Buttons in Pause/Game-Over → **„Start-Menü"** umbenannt.
- **Enter im Namensfeld trug den Highscore-Eintrag nicht ein** — nur der
  „Eintragen"-Button löste `_commit_score()` aus. `LineEdit.text_submitted`
  (Enter/Return) jetzt zusätzlich verbunden.
- **Namensfeld nahm auf Android keine Eingabe an** — Fokus-per-Tap allein öffnet
  auf manchen Android-Skins nicht zuverlässig die virtuelle Tastatur. Fix:
  `grab_focus.call_deferred()` beim Erscheinen + explizites
  `DisplayServer.virtual_keyboard_show()/hide()` an `focus_entered`/`focus_exited`.
- **Touch-Ziele zu klein** — einheitliche Mindesthöhe `TOUCH_H=56` für Buttons,
  Stepper-Pfeile, Help-Nav, Sound-Slider, Namensfeld, Pause-Button (vorher 34–44,
  Pause-Button 42×36 → 62×56).
- **Hilfetext zu winzig** (auch am Desktop) — Schriftgrößen in Menüs/Hilfe
  angehoben (Body 17→22 usw.).
- **Menüs wirkten „flach"** — `ui_style.gd` (neu, `class_name UiStyle`) liefert
  gemeinsames Chrome für `menus.gd` + `hud.gd`: bordered/shadowed
  `PanelContainer` um jeden Screen (`panel_style()`, tetris-Vorbild), Buttons
  mit Per-State-`StyleBoxFlat` statt Default-Theme (`style_button()`),
  Überschriften mit Outline (`_title_label`, Größe ≥24 automatisch), **Milchglas-
  Hintergrund** (`assets/ui/frosted_glass.gdshader`, 1:1 von pacman übernommen —
  `BackBufferCopy` + `ColorRect`-Shader, in GL Compatibility zwingend über
  `BackBufferCopy`, sonst kein `SCREEN_TEXTURE`). Ein einziger geteilter
  Glas-Hintergrund pro `Menus`-CanvasLayer statt einer separaten Instanz pro
  Screen. Dabei entdeckt + gefixt: `_build_help`s Body-Label ohne `autowrap_mode`
  ließ eine lange Zeile bei größerer Schrift den ganzen Panel-Rahmen sprengen
  (randlos über den ganzen Bildschirm) → `autowrap_mode = AUTOWRAP_WORD`.
- **Kaputte Zeichen im Hilfetext** — die Pfeil-Glyphen `← → ↑` (U+2190/2192/2191)
  fehlen offenbar im tatsächlich verwendeten Font-Subset; durch Worte ersetzt
  ("Pfeiltasten links/rechts", "Pfeiltaste hoch") bzw. durch `=`. Em-Dash `—`
  und Mittelpunkt `·` sind unauffällig geblieben, nicht angefasst.
- Button „Steuerung" (Start/Pause) → **„Hilfe"** umbenannt (führte zur Hilfe,
  nicht zu Steuerungs-Einstellungen — die Seitentitel *innerhalb* der Hilfe
  heißen weiter „Steuerung — …").
- **Kein Dauerfeuer auf Tastatur/Maus** (Touch hatte es schon) — `ship.gd`
  feuerte pro Tastendruck/Klick nur einmal (`is_action_just_pressed`, Klick nur
  auf die `pressed`-Flanke). Jetzt `Input.is_action_pressed("shoot")` (gehalten)
  bzw. ein `_mouse_down`-Flag (an/aus bei Maus-Press/Release) — Halten feuert
  jetzt auf allen drei Eingabewegen kontinuierlich nach, sobald ein Laser-Slot
  frei wird (weiter gedeckelt durch `MAX_LASERS`). Verifiziert per Diagnose-
  Capture: 2 Laser bleiben über 4 s gehaltener Taste/Maustaste konstant in der
  Luft (einzelner Laser lebt nur ~1,1 s, muss also laufend nachgefeuert werden).

**Erste echte Assets eingebaut (2026-09-12):** Nutzer hat echte Grafiken/Sounds
geliefert, Platzhalter ersetzt:
- **Schiff**: `player.png` (getrimmt → `player_trim.png`) statt Platzhalter,
  `Sprite2D.rotation=0` (Kunst zeigt schon nach oben, kein Twist mehr nötig).
  Recherche ergab: `enemy2.png`/`enemy4.png` sind echte 1981er-Arcade-Sprites
  (Zako/Boss, exakter Farb-/Formabgleich gegen Referenzblatt), `enemy1.png`/
  `enemy3.png` passen zu keinem der drei kanonischen Gegner (falsche Palette/
  Form) — vermutlich Reste des schon vorher notierten „Galaxian-Asset-Pack".
  `enemy3.png` trotzdem für GOEI verwendet (Farbfamilie passt, Form nicht) —
  bewusster Kompromiss, kein 1:1-Fund. Die diversen `.gif`s (goei, neo-goei,
  sasori, neo-tonbo, hyper-smmo, gorg-bos, gyaraga-ship*) sind **Fan-Art**
  einer DeviantArt-Serie „Gyaraga" von ss77relaunched, kein offizieller Namco-
  Nachfolger — für spätere Level/Bonusstufen vorgemerkt, nicht integriert.
  Capture-Beam/Ammo-Gifs bewusst nicht übernommen (Nutzer will die später
  selbst nachbauen lassen).
- **Captured-Schiff-Variante**: erstes Frame aus `gyaraga-ship-captured.gif`
  extrahiert → `ship_captured.png` (die klassische rot getönte Optik) — Asset
  liegt bereit, Capture-Mechanik selbst kommt erst mit einer späteren Phase.
- **Blaue Antriebsflamme**: das schon vorhandene Partikel/Shader-System aus
  `ship_visual_effects/` (Rest des Twin-Stick-Moduls) zeigt/versteckt sich
  bereits richtig nach Bewegung — nur die Farbe (Gradient in
  `thruster_material.tres` + `main_thruster.tscn`) war orange, jetzt blau.
  **Echter Bug dabei gefunden** (erst durchs `godot-mcp-pro`-Live-Testen
  aufgefallen, im Screenshot schlicht unsichtbar): `MainThruster` hing als
  Kind am `Sprite2D`, das inzwischen `scale=0.11` hat (fürs viel größere neue
  Schiffs-Sprite) — die ganze Flamme (Line2D-Breite, Partikelgrößen, alles für
  `scale=1` gebaut) schrumpfte dadurch auf ~11 %, praktisch unsichtbar. Fix:
  `MainThruster` jetzt eigenständiges Kind von `Ship` statt von `Sprite2D`,
  Position neu für die Root-Ebene berechnet. Beide SideThruster-Instanzen
  entfernt (Nutzer wollte nur eine Flamme unten, keine seitlichen Jets).
- **Gegner-Sprites**: `enemy2_trim`/`enemy3_trim`/`enemy4_trim.png` ersetzen
  `enemy.gd`s `_draw_zako/_draw_goei/_draw_boss`. Da es nur je ein Standbild
  gibt, wird der Flügelschlag jetzt per Transform-Wobble simuliert
  (`Node2D.skew` + `scale:y`-Pulsieren, per Tween, synchron zum
  bestehenden `Formation.flap_toggled`-Takt von 0,28 s) statt durch ein
  zweites gezeichnetes Frame.
- **Sounds**: echte SFX-Rips (`m01se_*.wav`, japanische Funktionsnamen wie
  „suikomi"/„hakidasi" für die Tractor-Beam-Mechanik, passend zu
  `Galaga_88`-Referenzmaterial des Nutzers) ersetzen die synthetischen
  Platzhalter aus `gen_sounds.py`. Pegel gemessen (nahe 0 dBFS, viel heißer
  als die Platzhalter) → `_BASE_DB` je Sound neu kalibriert,
  `CALIB_VERSION` 1→2 (verwirft alte gespeicherte %-Werte automatisch).
  Zuordnung nach Dateiname+Pegel/Länge, ungehört — bei Bedarf einzeln
  nachjustieren.
- **Splash-Screen**: `splash-screen.webp` (offizielles „Arcade Game Series"-
  Logo, aus Nutzer-Recherche) → `splash-screen.png` im Root, in
  `project.godot` (`boot_splash/image`) verdrahtet.
- **Laser-Trefferbox**: 5×16 → 9×18 (sichtbarer Strahl bleibt 3 px schmal) —
  Nutzer fand Treffen zu schwer, das ist ein erster vorsichtiger Schritt,
  kein großer Balance-Eingriff.
- **Maussteuerung**: `move_toward()` (Tastatur-Speed-Limit 480 px/s) durch
  direktes 1:1-Snapping (`position.x = get_global_mouse_position().x`)
  ersetzt — die Maus kann beliebig schnell springen, das alte Verfolgen
  wirkte dadurch wie Verzögerung/„Nachziehen", war aber kein Performance-Bug.
- **Fenstergröße**: `window_width_override=1152`/`window_height_override=648`
  (Altlast aus dem Twin-Stick-Querformat, nur für den Editor-Debug-Lauf
  relevant) entfernt — Editor-Debug-Fenster nutzt jetzt die echten 540×960.
  `window/size/resizable` **nicht** gesetzt (wie bei pacman/tetris) — frei
  skalierbar, nur die Startgröße ist fix.

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
  Ist der Gegner ein Boss und noch kein Schiff gefangen
  (`is_carrying_captive()` über alle `"enemy"` prüfen), 22 % Chance auf
  `capture_dive()` statt `dive()` (siehe Boss-Capture unten). `stop_attacks()`
  beim Stage-Wechsel. Reicht `enemy_killed(points)` und `ship_rescued` durch.
- `enemy.gd` (Area2D, kein `class_name`) — States FLYING_IN / LOCKING /
  IN_FORMATION / DIVING / RETURNING / **CAPTURE_APPROACH / CAPTURE_BEAM**
  (Boss-Capture, siehe unten). Generischer Path-Follower
  (`_start_path(curve, speed, done_callable)`): FLY 480 / DIVE 300 / RETURN
  360 px/s, Ausrichtung nach Fahrtrichtung, dann 0,4-s-Tween in den Slot.
  Beim `dive()` gibt der Gegner seinen Slot frei (`_formation.release`), wirft
  bis zu 2 Bomben (`bomb.tscn`), kehrt nach dem Kurvenende via `return_to`
  zurück und belegt den Slot neu. Sprite + Skew/Squash-Flap
  (`EnemyKinds.DATA[kind]["texture"/"scale"]`, siehe „Erste echte Assets").
  Kollision Layer 4 / Maske 8.
- **Boss-Capture** (`enemy.gd` + `capture_beam.gd`/`.tscn` + `attack_paths.gd`s
  `capture_approach()`): Boss hovert statt durchzufliegen (CAPTURE_APPROACH),
  lässt `capture_beam.tscn` herab (grüner Strahl, wächst/hält/zieht sich
  zurück, Gruppe `"enemy_shots"` — zerstört das Schiff über den schon
  bestehenden Kollisions-Code in `ship.gd`, kein Sonderfall nötig). Trifft der
  Strahl (`caught`-Signal), trägt der Boss eine `ship_captured.png`-Sprite als
  Kind-Node zurück in die Formation (folgt Position/Rotation automatisch).
  Wird genau dieser Boss später zerstört (`_explode()`), feuert er
  `ship_rescued` — `game.gd::_on_ship_rescued()` macht daraus
  `ship.become_twin()`: zweites Schiff+Triebwerk (Duplikat, `TWIN_OFFSET=34`),
  doppelte Laser-Kapazität, ein Treffer beendet den Bonus wieder
  (`_destroy() -> _revert_twin()`). Max. ein gefangenes Schiff gleichzeitig.
- `bomb.gd` / `bomb.tscn` — Gegner-Schuss, fällt (leicht Richtung Spieler-x zum
  Abwurfzeitpunkt), Platzhalter-Raute. Layer 16 (enemy_shots) / Maske 9
  (player + player_shots — Laser können Bomben abschießen).
- `laser.gd` — Platzhalter-Strich im `_draw()` (laser.png raus), Layer 8,
  Hitbox 9×18 (sichtbarer Strahl bleibt 3 px schmal — großzügiger als er
  aussieht, Nutzer fand Treffen zu schwer).
- `enemy_kinds.gd` (`class_name EnemyKinds`) — ZAKO/GOEI/BOSS: Radius, Punkte,
  Sprite-Textur + Skalierung (siehe „Erste echte Assets").

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

**Erledigt:** Phasen 1–5 (Formation+Einflug, Sturzflüge+Gegnerfeuer, Leben/HUD/
Game-Over, Touch+Aspect+Pause, Menüs/Settings/Sound/HoF, echte Assets +
Boss-Capture). Echte Sounds, echte Gegner-/Schiff-Sprites, Splash-Screen,
Maus-1:1-Steuerung, frei skalierbares Fenster — siehe „Erste echte Assets"
und „Boss-Capture" weiter oben für Details.

1. **Zusätzliche Gegnertypen für spätere Stages/Bonuslevel** — mit dem Nutzer
   besprochen als nächstes Thema, Umfang/Look noch offen. Kandidaten: das
   bislang ungenutzte `enemy1.png` (noch nicht getrimmt, falsche Palette für
   einen der drei kanonischen Typen, aber vorhanden) und/oder die
   Fan-Art-Serie „Gyaraga"
   (`assets/graphics/*.gif` — sasori, neo-tonbo, hyper-smmo, gorg-bos, …).
2. **Auf echten Geräten testen** (OPPO Find X2 Pro, OnePlus 12 ≈ 2,2:1;
   Galaxy S4 = 16:9): Aspect-Umschaltung, Touch-Drag, Pause-Button-Position,
   Formation-Größe. In beiden Ratios im echten Browser screenshotten.
   Canvas-Wechsel bliebe ein Einzeiler in `project.godot`.
3. **Hilfe bildbasiert** (optional) — derzeit 3 Textseiten in `menus.gd`
   (`HELP_PAGES`). tetris macht's mit SVG→PNG (`assets/help_src/` + `render.sh`).
   Reicht vorerst als Text.
4. `assets/` aufräumen (lose Test-PNGs, Loot-System `item.gd`/`gem.tscn`/… —
   Galaga hat keins), HUD-Feinschliff, „1UP"-Flash beim Extra-Leben.
5. Später evtl.: Challenging/Bonus-Stage, Combo-Scoring, Auto-Fire als
   abschaltbares Setting, Diver/Bomben gegen die 960er-Canvas festnageln statt
   `get_viewport_rect()`. Fällt uns sicher noch mehr ein.

## Aseprite MCP Pro

Bei Nutzung der Aseprite-MCP-Pro-Tools (`mcp__aseprite-mcp-pro__*`) dem
Pixel-Art-Skill-Guide folgen:
@/home/bernd/GodotDev/learn_2d_gamedev_godot_4_0.57.0_linux/aseprite-mcp-pro-server/skills.md
