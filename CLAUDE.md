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
Sound-Unterseite (Regler pro Sound), Hilfe (3 Seiten, Ziel-Seite seit
2026-09-12 mit Icon-Legende statt reinem Text), Game-Over mit
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
  `ship_visual_effects/` (Rest des Twin-Stick-Moduls) — nur die Farbe (Gradient
  in `thruster_material.tres` + `main_thruster.tscn`) war orange, jetzt blau.
  **Echter Bug dabei gefunden** (erst durchs `godot-mcp-pro`-Live-Testen
  aufgefallen, im Screenshot schlicht unsichtbar): `MainThruster` hing als
  Kind am `Sprite2D`, das inzwischen `scale=0.11` hat (fürs viel größere neue
  Schiffs-Sprite) — die ganze Flamme (Line2D-Breite, Partikelgrößen, alles für
  `scale=1` gebaut) schrumpfte dadurch auf ~11 %, praktisch unsichtbar. Fix:
  `MainThruster` jetzt eigenständiges Kind von `Ship` statt von `Sprite2D`,
  Position neu für die Root-Ebene berechnet. Beide SideThruster-Instanzen
  entfernt (Nutzer wollte nur eine Flamme unten, keine seitlichen Jets).
  **Zweiter, unabhängiger Bug** (2026-09-12, nach Playtest gemeldet): die
  Sichtbarkeits-Logik selbst reagierte nur auf die `move_left`/`move_right`
  Input-Actions (Tastatur/Gamepad) — bei Maus- oder Touch-Steuerung (die das
  Schiff direkt per `position.x` bewegen, ohne diese Actions) blieb die Flamme
  fälschlich immer aus. Siehe „Boss-Capture-Race-Condition (Teil 2),
  Angriffsmuster-Vielfalt, Flammen-Fix" unten für den Fix.
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

**Zusätzliche Gegnertypen + Hilfe-Politur (2026-09-12):**
- **Boss-Variante für Stage 2+**: `gorg-bos--damaged.gif` (Gyaraga-Fan-Art,
  echtes 2-Frame-Flap-Paar) getrimmt/zugeschnitten → `gorg_bos_f0/f1.png`,
  als `EnemyKinds.BOSS_VARIANTS` eingehängt — schließt die bisherige Lücke
  „kein kuratiertes Reskin für den Boss". `hyper-smmo.gif` dagegen **nicht**
  verwendet: stellte sich beim Ansehen der Einzelframes als lose Deko-Grafik
  heraus (zwei unzusammenhängende Flapp-Edelstein-Icons über einem statischen,
  nicht animierten Schiffs-Umriss), keine zusammenhängende Gegner-Pose —
  bleibt wie `enemy1.png` (falsche Palette) ungenutzt.
- **Hilfe-Seite „Ziel & Punkte" aufgewertet**: zeigt jetzt die drei
  Gegner-Sprites als Icons neben Name + Punktwert (statt nur einer Textzeile
  „Bienen 50 · …") — erster Schritt Richtung „Hilfetexte bildlich statt nur
  Worte" (globale CLAUDE.md, Menü-Optik-Vorgabe). Ergänzt außerdem zwei Zeilen
  zur Boss-Capture-/Doppeljäger-Mechanik, die vorher nirgends erklärt war.
  Seiten-Indikator (`●`/`○`-Text) durch kleine farbige Quadrate ersetzt
  (`ColorRect`-Reihe, wie tetris' `_refresh_help_dots()`), sonst bleibt die
  Hilfe textbasiert (siehe „Offen" Punkt 3 für vollständig bildbasierte
  Seiten wie bei tetris).

**Boss-Capture-Race-Condition (Teil 2), Angriffsmuster-Vielfalt, Flammen-Fix
(2026-09-12):** Nutzer-Report nach echtem Playtest: Boss (mit gefangenem
Schiff) wurde erneut abgeschossen, ohne den Doppelschiff-Bonus auszulösen —
obwohl genau dieser Fall schon einmal gefixt worden war (`_pending_twin` in
`game.gd`).
- **Eigentliche Ursache gefunden**: `enemy.gd::_begin_capture_beam()` setzte
  `_carrying_captive = true` erst NACH dem vollen `CAPTURE_BEAM_TOTAL`-Timer
  (0,95 s) — fängt der Strahl das Schiff, aber ein bereits abgefeuerter Schuss
  trifft den Boss noch **innerhalb** dieses Zeitfensters (bevor der Timer
  abläuft), sieht `_explode()` `_carrying_captive` noch als `false` und lässt
  die Belohnung stillschweigend fallen. Fix: `_carrying_captive = true` +
  `_spawn_captive_visual()` laufen jetzt direkt im `beam.caught`-Signal-Handler,
  synchron im Moment des Fangs — nicht erst nach Ablauf des Timers. Verifiziert
  per gezieltem MCP-Script-Test (Strahl fängt, Boss wird sofort danach per
  `_explode()` zerstört, `ship_rescued` feuert korrekt).
- **Capture-Versuche jetzt zeitbasiert statt Zufalls-Beifang der Dive-Lotterie**:
  vorher wurde `CAPTURE_CHANCE` nur gewürfelt, wenn die normale Dive-Auswahl
  (zufällig aus allen 40 Formationsplätzen) zufällig einen Boss traf — bei nur
  4 Bossen wirkte das wie „höchstens einmal pro Stage". Jetzt läuft in
  `stage_director.gd` ein eigener Timer (`CAPTURE_INTERVAL_MIN/MAX`, seit der
  zweiten Playtest-Runde 5–9 s) parallel zur normalen Dive-Lotik; bei Ablauf
  wird `CAPTURE_CHANCE`
  gewürfelt und, falls ein Boss frei ist und kein Schiff schon gefangen ist,
  gezielt `capture_dive()` auf ihn ausgelöst (`_try_capture_dive()`).
- **Sturzflugmuster variieren jetzt**: `AttackPaths.dive()` wählte bisher immer
  dieselbe Kurvenform (Wand-Peel + Sweep am Spieler vorbei) — bei Dutzenden
  Dives pro Stage fiel die Wiederholung auf ("Bewegungsmuster ähneln sich zu
  sehr pro Stage"). Jetzt wird pro Dive zufällig eine von drei Formen gewählt
  (`randi() % 3`): das bisherige Wand-Peel, ein weiter Loop-Schlenker mit
  kurzem Gegenhaken, und ein steilerer Mittel-Plunge mit Wackler — nicht
  stage-gebunden, sondern jedes Mal neu gewürfelt, damit sich auch innerhalb
  einer Stage nicht alles gleich anfühlt.
- **Antriebsflamme unsichtbar unter Maus-/Touch-Steuerung**: `main_thruster.gd`
  las `Input.get_vector("move_left","move_right",…)` für „bewegt sich gerade"
  — reagiert nur auf Tastatur/Gamepad-Actions, nicht auf Maus (direktes
  `position.x`-Snapping) oder Touch-Drag, den beiden anderen Steuerwegen des
  Schiffs. Fix: verfolgt jetzt die tatsächliche x-Bewegung des Eltern-Knotens
  (`Ship`) frame-zu-frame statt der Input-Actions — funktioniert unabhängig
  von der Eingabemethode. Verifiziert per direktem `_process()`-Aufruf im
  MCP-Script (Power rampt 0,16→0,93 bei simulierter Bewegung, klingt bei
  Stillstand wieder ab).

**Zweite Playtest-Runde (2026-09-12): Max-Schüsse-Setting, Bomben-Hitbox,
Hintergrund-Bewegung, echter Splash-Screen, Boss-Capture-Häufigkeit +
Sichtbarkeit, Leben-Anzeige.**
- **Einstellbare Laser-Obergrenze**: `GameSettings.max_shots` (1–5, Default 2,
  `MAX_SHOTS_MIN/MAX`), neuer Stepper „Max. Schüsse" in `menus.gd`
  (Tastatur-Eingabe wie bei Leben/Extra-Leben). `ship.gd`s vormals konstantes
  `MAX_LASERS_BASE` ist jetzt `_max_lasers_base`, gesetzt über `configure()` —
  `game.gd::_reload_settings()` ruft das bei jedem Rundenstart UND bei
  `settings_changed` erneut auf, ändert sich also auch sofort, wenn man es
  mitten im Lauf über die Pause anpasst (nicht erst nächste Runde).
- **Bomben-Hitbox** 6.0 → 9.0 Radius (wie beim Laser: großzügiger als sie
  aussieht, leichter zu treffen).
- **Hintergrund-Bewegung + Blinken**: `space_background.gd` fütterte den
  Shader-Parameter `view_offset` bisher aus `Camera2D.global_position` — es
  gibt in Galaga aber gar keine Kamera, `get_viewport().get_camera_2d()` war
  immer `null`, `_process()` lief deshalb nie. Fix: `view_offset` bekommt
  stattdessen einen stetig wachsenden künstlichen Vertikal-Versatz
  (`SCROLL_SPEED`) — nutzt das bestehende Zweischicht-Stern-Parallax
  (`star_field.gdshader`) für einen klassischen "Sterne ziehen vorbei"-Effekt,
  ohne dessen Parallax-Mathe anzufassen. Zusätzlich bekommt jeder Stern ein
  eigenes, phasenverschobenes Helligkeits-Pulsieren (`twinkle`-Faktor im
  Shader) fürs "Blinken".
- **Echter Splash-Screen statt `boot_splash`**: Godots nativer Boot-Splash
  (nur ein Standbild für `minimum_display_time` Sekunden, kein Ladebalken) war
  auf Linux/Android faktisch nicht wahrnehmbar — das Projekt lädt so schnell,
  dass der native Splash quasi sofort wieder weg ist. Neuer Screen
  `menus.gd::show_splash()` (eigener, nicht über `_screen()` gebauter
  Vollbild-Screen ohne Panel-Chrome): zeigt `splash-screen.png` +
  Fake-Ladebalken (`Tween` über `SPLASH_TIME = 3.0` s), danach `splash_done`
  → `game.gd::_ready()` verbindet das mit `_enter_title()`
  (`CONNECT_ONE_SHOT`). Tap/Klick/Taste überspringt die Wartezeit. Der native
  `boot_splash` bleibt zusätzlich bestehen (deckt die eigentliche
  Engine-Ladelücke ab, überschneidet sich nicht mit dem neuen Screen).
  **Stolperfalle beim ersten Anlauf**: `var skip := (a or b or c)` mit
  `InputEvent`-Feldzugriffen (`event.pressed` o. Ä., die `Variant` liefern)
  scheiterte an Typ-Inferenz (`Cannot infer the type of "skip" variable`) —
  Godot lud danach das ganze Menü-Skript nicht mehr, Spiel blieb komplett
  hängen. Fix: `var skip: bool = (...)` explizit typisiert (wie tetris'
  `ui.gd::show_splash()` es schon richtig macht).
- **Boss-Capture: Häufigkeit + „funktioniert nicht"-Report untersucht** —
  Live-Test über die echten Methoden (`capture_dive()`, echte
  Strahl-Kollision, echtes `_explode()`) bestätigte: die Belohnungskette
  selbst (Fangen → `ship_rescued` → `become_twin()`) funktioniert korrekt und
  zuverlässig, auch unter Zeitdruck. Zwei echte Probleme dahinter gefunden:
  1. **Bosse konkurrierten mit der normalen Dive-Lotterie** um denselben Pool
     — ein Boss, der gerade einen stinknormalen Sturzflug macht, war nicht
     verfügbar, wenn der Capture-Timer feuerte. Fix: `_launch_dive()`
     schließt `EnemyKinds.BOSS` jetzt aus (Bosse fliegen nur noch
     Capture-Versuche, nie mehr stinknormale Dives). `CAPTURE_INTERVAL`
     zusätzlich von 6–11 s auf 5–9 s verkürzt.
  2. **Der eigentliche Grund, warum sich die Belohnung „kaputt" anfühlte**:
     alle Bosse einer Stage sehen identisch aus (ab Stage 2 sogar alle mit
     demselben Gyaraga-Reskin) — welcher Boss gerade das Schiff trägt, war
     rein optisch nicht zuverlässig erkennbar (nur ein kleines Passagier-
     Sprite auf dem Rücken). Man hat vermutlich oft den falschen Boss
     abgeschossen und dachte, die Mechanik sei kaputt. Fix:
     `enemy.gd::_spawn_captive_visual()` startet jetzt einen loopenden
     Farb-Puls (`_sprite.modulate` Weiß ↔ Gelb, 0,35 s) auf genau diesem
     Boss, solange er das Schiff trägt — unübersehbar. Beides per
     End-to-End-MCP-Test verifiziert (Fangen mit echter Strahl-Kollision,
     Rückkehr in Formation, Farb-Puls sichtbar im Screenshot, `_explode()`
     löst `become_twin()` real aus, Zwillingsjäger im Screenshot bestätigt).
- **Leben-Anzeige überarbeitet** (siehe auch die neue globale Regel dazu in
  der übergeordneten CLAUDE.md): `hud.gd` zeigt jetzt echte, kleine
  Schiffs-Sprites (`player_trim.png`) statt gelber Platzhalter-Dreiecke; ab
  `MANY_THRESHOLD = 5` ein Icon + „× N" statt einer wachsenden Reihe.
  `game.gd`: `_lives` ist jetzt die **Reserve** (zählt das gerade fliegende
  Schiff nicht mit) statt der Gesamtzahl — `_new_run()` setzt
  `_lives = cfg.lives - 1`, `_on_ship_died()` prüft `_lives <= 0` **vor** dem
  Dekrementieren (nicht danach). Extra-Leben-Bonus jetzt gedeckelt bei
  `MAX_LIVES_RUNTIME = 99`.
- **Nebenbei, beim Testen selbst passiert**: kurz versehentlich einen
  `--script`-Headless-Lauf (`_selftest.gd`) bei offenem Editor ausgeführt —
  genau der Zwei-Prozesse-Fehler aus dem `export_credentials.cfg`-Vorfall.
  Diesmal folgenlos geblieben (Datei danach geprüft, unversehrt, Android-Export
  hinterher erfolgreich) — Glück, kein Verdienst. `ps aux`-Check weiterhin vor
  **jedem** Headless-Lauf Pflicht.

**Ship-Reconstruct-Intro/Respawn, Bonus-Sammelobjekte aus achivements.jpg
(2026-09-12):**
- **`ship-(re)construction.gif` als Materialisierungs-Animation**: neue
  `ship_reconstruct.tscn`/`.gd` (`AnimatedSprite2D`, 28 Frames, 16 fps,
  einmalig, `build_done`-Signal, self-`queue_free()`). Läuft jetzt an zwei
  Stellen in `game.gd`: beim Rundenstart (`_new_run()`, mit „BEREIT"-Banner
  über `Hud.flash_banner()`, wie ein Tetris-„Get Ready") und bei jedem Respawn
  (`_on_ship_died()`, ersetzt den alten reinen Timer-Wait komplett — das Schiff
  war bisher bei Verlust einfach für `RESPAWN_DELAY` unsichtbar, jetzt sieht
  man, was passiert). `_play_reconstruct(at)`-Helfer + `_ship_spawn_pos()`
  (immer horizontal zentriert, wie `respawn()` selbst).
  **Extraktions-Stolperfalle**: `PIL.Image.seek(i)` auf diesem Gif lieferte für
  Frame 0 Modus `P` mit `info["transparency"]=255`, ab Frame 1 aber bereits
  fertig zu `RGBA` gewandelt **ohne** korrekten Alpha-Kanal (überall
  alpha=255, auch der Hintergrund) — ein bekanntes Pillow-Problem bei
  Disposal-Methode-2-Gifs. `.convert('RGBA')` naiv aufgerufen ergab dadurch
  einen **komplett opaken schwarzen Hintergrund** (in Godot als hässlicher
  schwarzer Kasten sichtbar, der die Formation dahinter verdeckte — per
  Live-Screenshot entdeckt). Fix: nachträglich per Farbschlüssel
  (`max(R,G,B) > 8 → alpha 255, sonst 0`) korrigiert, da der echte Hintergrund
  hier zuverlässig reines Schwarz ist. **Cache-Falle dabei**: der PNG-Fix allein
  reichte nicht — der bereits offene Editor hatte die alte (kaputte) Textur
  schon im Speicher; erst ein Editor-Neustart + Reimport zeigte die Korrektur.
- **Bonus-Sammelobjekte aus `achivements.jpg`**: der Nutzer hat ein
  4×4-Raster verschiedener Schiffs-Sprites (kein echtes „Achievements"-Asset,
  aber das Beste, was zur Hand war) mit störendem Sternenhimmel-Hintergrund
  bereitgestellt. Freigestellt per Python/numpy/scipy
  (`ndimage.label`-Connected-Components, alles vom Bildrand aus erreichbare
  Dunkel/Blau als Hintergrund geflutet, kleine Stern-Sprenkel < 6 px separat
  entfernt) zu 16 `achievement_00..15.png`. **3 Indizes (5, 6, 7) bewusst
  ausgeschlossen** — lagen mitten im dichtesten Dunst-Fleck der Vorlage, die
  automatische Freistellung ließ dort deutliche Reste stehen; kein
  Perfektionsanspruch verfolgt (Nutzer selbst: „vielleicht auch nicht ideal").
  Neue `bonus_item.tscn`/`.gd`: fällt langsam mit sanftem Schlingern vom
  oberen Rand, wahlweise per Berührung **oder** per Laser einsammelbar (kein
  Geschick-Test, beides gleich viel wert), 500 Punkte, Icon-Auswahl zufällig
  aus den 13 sauberen Indizes. `game.gd` spawnt alle
  `BONUS_INTERVAL_MIN/MAX` (14–24 s) während `FORMATION` einen Bonus
  (`_spawn_bonus_item()`), Timer wird bei jedem `_on_stage_populated()` neu
  gewürfelt. `hud.gd` zeigt die letzten `BONUS_MAX_SHOWN` (8) eingesammelten
  Icons als Reihe unten in der Bildschirmmitte (`add_bonus_icon()`,
  `_draw_bonus_icons()`) — genau der freie Platz, den der Nutzer vorschlug.
  Kollisionslayer: `collectibles` (Layer 2, bisher ungenutzt), Maske
  `player + player_shots` (9). Per End-to-End-MCP-Test verifiziert (echte
  Kollisions-Erkennung, nicht nur simuliert) — dabei erst einen
  Test-Methodik-Fehler bei mir selbst gefunden (Signal in einem früheren
  Testlauf nur an eine lokale Closure statt an `game._on_bonus_collected`
  verbunden, sah wie ein Kollisions-Bug aus, war aber keiner).
- **`ship-warp-drive.gif`, `hyper-ammo.gif`, `cyclone-ammo.gif`** — vom Nutzer
  bereitgestellt, noch **nicht** eingebaut, nur vorgemerkt:
  `ship-warp-drive.gif` (19 Frames, 100×100) ohne zugewiesenen Verwendungszweck.
  `hyper-ammo.gif` (2 Frames, 544×1024) ist vermutlich `hyper-smmo.gif`
  umbenannt (identische Maße/Dateigröße) — bereits früher als „lose
  Deko-Icons über statischem Schiffs-Umriss, keine Gegner-Pose" eingestuft
  (siehe „Zusätzliche Gegnertypen + Hilfe-Politur" weiter oben), also
  vermutlich weiterhin kein Enemy-Reskin-Kandidat, aber evtl. als
  Ammo-/Effekt-Grafik brauchbar. `cyclone-ammo.gif` (4 Frames, 544×3616,
  hochformatiges Spiralband) ungeprüft, Verwendung offen. Nutzer bewusst
  gebeten, sich Einsatzzweck später zu überlegen.
- **Menü-Farbkonzept + Laser-Farbe** (Nutzer-Feedback, noch nicht umgesetzt):
  Farbkonzept der Menüs braucht noch Arbeit (unspezifisch, kein Detail
  genannt); der Laser (aktuell reines Weiß, `laser.gd::_draw()`) soll
  „irgendwas Blaues" enthalten. Beides vorgemerkt für einen dedizierten
  Optik-Durchgang, siehe „Offen" Punkt 8. **Ein Teilaspekt ist seit 2026-09-13
  erledigt** — die grüne Überschriften-Outline, siehe unten.

**Dritte Playtest-Runde (2026-09-13): Bonus-Item-Sweep-Bug, Achievement-Liste
gekürzt + Runden-Zähler, garantierter Boss per Punkte-Schwelle, Boss während
Capture unverwundbar, Überschriften-Outline auf Cyan.**
- **Echter Bug gefunden: Bonus-Items klebten am linken Rand fest und liefen
  teils aus dem Bildschirm** — Ursache war `game.gd::_spawn_bonus_item()`:
  `add_child(b)` lief VOR `b.position = ...`, `_ready()` feuert aber
  synchron schon während `add_child()` — `bonus_item.gd` las `_base_x =
  position.x` also immer als `(0, 0)`, die anschließend gesetzte
  Zufalls-x-Position wurde von der nächsten `_process()`-Zeile sofort wieder
  überschrieben. Kein Zufalls-/Balance-Problem, ein reiner Reihenfolge-Bug.
  Fix + Redesign zugleich: `bonus_item.gd` berechnet seine x-Bewegung jetzt
  selbst aus der eigenen Viewport-Breite (`_base_x = vp.x/2`,
  `_amplitude = vp.x/2 - SIDE_MARGIN`, zufällige Phase + Sway-Geschwindigkeit
  pro Item) statt eines kleinen Wobbles um eine von außen übergebene
  Spawn-x — schwingt dadurch wirklich über die **gesamte** Bildschirmbreite
  (mit Rand-Marge, damit es nie clippt), `game.gd` setzt nur noch die
  Spawn-Höhe. Per direktem `_process()`-Loop im MCP-Script verifiziert:
  x-Bereich über 200 simulierte Frames lief von 40 bis 500 (Design-Canvas
  540 breit, Marge 40) — deckt praktisch die volle Breite ab, nie negativ.
- **Achievement-Icon-Liste weiter eingeschränkt**: Index 1 (`achievement_01.png`)
  raus — sieht im Spiel zu leicht mit dem eigentlichen Spieler-Schiff-Sprite
  verwechselbar aus (Verwirrungsgefahr mitten im Gefecht). Zusammen mit den
  schon vorher ausgeschlossenen 5/6/7 (Hintergrundreste) bleiben 12 von 16
  Indizes im Pool (`bonus_item.gd::ICON_INDICES`).
- **Bonus-Icon-Reihe: Maximalbreite + Runden-Zähler statt endlosem
  Nachschieben**: `hud.gd`s `BONUS_MAX_SHOWN` 8→7 (mehr passt nicht
  überschneidungsfrei nebeneinander). Erreicht die Reihe 7 Icons, gibt es
  jetzt statt reinem Herausschieben des ältesten Icons einen Bonus
  (`game.gd::BONUS_LAP_POINTS = 2500`), die Reihe wird geleert und ein
  kleiner goldener „Runden"-Marker mit `× N` erscheint rechts daneben
  (`hud.gd::_draw_lap_marker`, `_bonus_laps`) — zählt, wie oft eine volle
  7er-Reihe schon abgeräumt wurde, bleibt über den Marker sichtbar, auch
  wenn die aktuelle Reihe wieder leer ist. `add_bonus_icon()` gibt jetzt
  `true` zurück, wenn genau dieser Pickup die Reihe voll gemacht hat —
  `game.gd::_on_bonus_collected()` vergibt den Bonus dann. Per
  End-to-End-Script verifiziert (8 simulierte Pickups: Reihe füllt sich
  1→6, beim 7. Icon Reset auf 0 + Bonus + `_bonus_laps` 0→1).
- **Garantierter Boss-Capture-Versuch alle N Punkte** (zusätzlich zur
  bestehenden Zufallschance pro Intervall in `stage_director.gd`): neue
  Einstellung „Boss alle X Punkte" (`GameSettings.boss_interval`, Default
  5000, 0 = aus, Schritt `BOSS_INTERVAL_STEP` = 1000 bis
  `BOSS_INTERVAL_MAX` = 20000) — Stepper in `menus.gd` neben Extra-Leben
  (gleiches „aus"/Zahl-Textfeld-Muster). `game.gd` merkt sich
  `_next_boss_score` (gesetzt in `_new_run()`), `_check_boss_threshold()`
  läuft nach jeder Punktegutschrift (Gegner-Kill UND Bonus-Item-Pickup) und
  ruft bei Schwellenüberschreitung `StageDirector.force_boss_capture()` —
  dieselbe Auswahllogik wie die zufällige `_try_capture_dive()`, nur ohne
  den `CAPTURE_CHANCE`-Würfel (beide rufen jetzt den gemeinsamen
  `_attempt_capture_dive()`). Per Score-Manipulation im MCP-Script
  verifiziert: Schwelle bei 5000 überschritten → ein Boss wechselte
  augenblicklich in `CAPTURE_APPROACH`.
- **Boss während Capture + Rückflug unverwundbar**: bisher konnte ein
  bereits abgefeuerter Schuss den Boss noch während des Traktorstrahls oder
  kurz nach dem Fang treffen — man hat den Fang dann teils gar nicht
  mitbekommen. `enemy.gd::_is_invulnerable()` (neu) blockt Laser-Treffer
  während `CAPTURE_APPROACH`, `CAPTURE_BEAM`, sowie `RETURNING`
  **solange er das Schiff trägt** (`_carrying_captive`) — der Laser wird
  trotzdem konsumiert (kein Durchschuss), nur `_explode()` wird
  übersprungen. Verwundbar wieder, sobald er in Formation eingerastet ist
  (`IN_FORMATION`) — die Boss-Reihe ist laut `formation.gd::ROWS` ohnehin
  schon die oberste Reihe (Index 0), „nach oben zurückkehren" ist hier
  also identisch mit „zurück in den eigenen Slot". Per drei gezielten
  Zustands-/Treffer-Kombinationen im MCP-Script verifiziert (Treffer
  während `CAPTURE_APPROACH`, während `CAPTURE_BEAM`+tragend, während
  `RETURNING`+tragend → jeweils wirkungslos; Treffer in `IN_FORMATION` →
  `_explode()` greift normal).
- **Überschriften-Outline Grün → Cyan**: `ui_style.gd::impact_label()`s
  Outline-Default war `Color("0f9668")` (Grünton, passte zu keinem anderen
  UI-Element) — jetzt `ACCENT` (`4db2ff`), dasselbe Cyan wie Button-Ränder,
  Einstellungs-Zahlen und Hilfe-Seiten-Punkte. Betrifft automatisch jede
  Menü-Überschrift (`menus.gd::_title_label` ab Schriftgröße 24) UND das
  In-Game-„STAGE n"-Banner (`hud.gd`, nutzt dieselbe Funktion) — bewusst
  nicht getrennt, für ein einheitliches Bild. Per Screenshot verifiziert
  (Titel-Screen „GALAGA").

**Vierte Playtest-Runde (2026-09-13): Laser-Flash, Boss-Garantie „sticky"
gemacht, Schiffs-Freiraum, Einflug-von-unten-Unverwundbarkeit, Hyper-Ammo,
Sieg-Bedingung.**
- **Laser flasht Weiß/Türkis statt statischem Strich**: `laser.gd` bekam
  `class_name Laser` + einen loopenden `Tween` auf `modulate` zwischen Weiß
  und `ACCENT_NORMAL` (`40e0d0`, Türkis) — multipliziert die schon
  gezeichneten `_draw()`-Farben zur Laufzeit, kein Neuzeichnen nötig. Per
  Live-Test verifiziert (`modulate` wandert über mehrere Ticks Richtung Türkis).
- **„Boss alle X Punkte" war nicht wirklich garantiert**: Nutzer-Report — bei
  eingestellten 5000 kam der erste erzwungene Boss erst nach 15000 Punkten.
  Ursache: `force_boss_capture()` (2026-09-12 eingeführt) versuchte es genau
  einmal im Moment der Schwellenüberschreitung — war in diesem Moment kein
  Boss frei (mitten im Einflug, alle schon am Tauchen/Fangen, Stage-Wechsel im
  Gange …), verpuffte der Versuch ersatzlos und die nächste Chance kam erst
  bei der nächsten Schwelle. Fix: `stage_director.gd` merkt sich jetzt nur
  noch einen `_forced_pending`-Wunsch und probiert ihn alle
  `FORCED_RETRY_INTERVAL` (2 s) erneut — unabhängig von Schiffsverlust oder
  Stage-Wechsel (`_attacks_on` pausiert die Versuche nur zwischen den Stages,
  wirft den Wunsch aber nicht weg) —, bis tatsächlich ein Boss verfügbar ist.
  Wird bei jedem neuen Spiel (`configure()`) bzw. beim Verlassen zum Titel
  (`abort()`) zurückgesetzt, damit kein alter Wunsch ins nächste Spiel
  durchsickert. `_try_capture_dive()` und `force_boss_capture()` laufen jetzt
  beide über dieselbe `_attempt_capture_dive()`, die jetzt `bool` zurückgibt
  (Erfolg/Misserfolg). Per Live-Test verifiziert: alle Bosse künstlich
  „beschäftigt" (`LOCKING`) → Wunsch bleibt `_forced_pending=true` und nichts
  passiert; sobald einer wieder `IN_FORMATION` ist, greift der nächste Retry
  sofort (`CAPTURE_APPROACH`).
- **Schiff braucht mehr Freiraum zur Flamme**: die Haupttriebwerksflamme
  (`main_thruster.tscn`, `max_length = 100`) kann bei voller Leistung bis
  knapp unter den unteren Bildschirmrand reichen — auf der schmalen
  540×960-Canvas überlappt das mit `hud.gd`s Bonus-Icon-Reihe unten mittig.
  `ship.gd::_ready()` verschiebt die Ausgangsposition jetzt automatisch um
  `_thruster.max_length + THRUSTER_CLEARANCE_MARGIN (5)` nach oben (aus
  `main_thruster.tscn` gelesen, nicht hartkodiert, bleibt also synchron, falls
  die Flammenlänge je angepasst wird). `_thruster`/`_thruster2` sind jetzt als
  `Line2D` statt `Node2D` typisiert, damit `.max_length` direkt lesbar ist.
  Der tatsächlich verwendete Ship-Startwert kommt aus `game.tscn`s
  Instanz-Override (`position = Vector2(270, 884)`, NICHT `ship.tscn`s eigener
  Vorgabe 828!) — landet nach dem Shift bei y=779. Per Live-Test verifiziert.
- **Einflug von unten: erst über der eigenen Kanone abschießbar**: der
  `BOTTOM_UP`-Einflugpfad (`entry_paths.gd`) lässt Gegner unterhalb des
  Bildschirms starten und erst nach oben Richtung Formation fliegen — dabei
  passieren sie kurzzeitig eine Position UNTER dem Schiff, wo ein
  „Abschuss" physikalisch keinen Sinn ergibt (der Strahl fliegt nach oben).
  `enemy.gd::_is_invulnerable()` blockt jetzt zusätzlich Treffer während
  `FLYING_IN`, solange `global_position.y > player.global_position.y` — sobald
  der Gegner über die Kanonenhöhe steigt, ist er normal verwundbar. Betrifft
  `TOP_LEFT`/`TOP_RIGHT`-Einflüge nicht (starten schon oben). Per Live-Test
  mit zwei Positionen (unter/über der Kanone) verifiziert.
- **Hyper-Ammo**: Sammelt man `achievement_00` aus einem Bonus-Item ein (statt
  der anderen 11 Indizes, die nur Punkte geben), feuert das Schiff bis zum
  Stage-Ende zwei eng nebeneinanderliegende Strahlen pro Schuss
  (`ship.gd::HYPER_OFFSET = 10`, deutlich enger als `TWIN_OFFSET = 34` der
  Zwillingsjäger-Belohnung — beide Boni sind unabhängig und stapeln sich).
  Farblich klar unterscheidbar: Hyper-Ammo flasht Weiß/Rot
  (`Laser.ACCENT_HYPER = ff4d4d`) statt Weiß/Türkis. `bonus_item.gd`s
  `collected`-Signal gibt jetzt den Icon-Index mit durch, `game.gd::
  _on_bonus_collected()` ruft bei Index 0 `ship.activate_hyper_ammo()`;
  `deactivate_hyper_ammo()` läuft bei jedem Stage-Wechsel (`_process()`s
  Stage-Clear-Zweig) UND in `_new_run()` (damit ein neues Spiel nie mit einem
  Rest-Bonus aus der letzten Partie startet). Übersteht Schiffsverlust
  innerhalb derselben Stage (das Schiff-Node ist persistent, `_hyper_ammo`
  bleibt beim Respawn unangetastet). Per Live-Test verifiziert (2 Strahlen
  bei ±5 px, beide korrekt rot).
- **Sieg-Bedingung**: neue Einstellung „Sieg bei X Punkten"
  (`GameSettings.win_score`, Default 100000, „aus" möglich, 10000er-Schritte
  bis 500000) — auf Nachfrage des Nutzers, ob ein Endlos-Charakter ohne
  Ziel sinnvoll ist; mit dem Angebot, es umzusetzen "falls nichts dagegen
  spricht" (nichts sprach dagegen, umgesetzt). `game.gd::_check_win()` läuft
  neben `_check_boss_threshold()` bei jeder Punktegutschrift; bei Erreichen:
  gleicher Ablauf wie Game Over (Tree pausiert, Musik stoppt), aber
  `menus.gd::show_game_over(score, stage, won=true)` zeigt „SIEG!" statt
  „GAME OVER" (Titel-Label jetzt als `Title`-Node referenzierbar) — dieselbe
  Hall of Fame, kein separates Ranking. Per Live-Test verifiziert (Score über
  die Schwelle geschoben → Zustand wechselt zu GAME_OVER, Screenshot zeigt
  „SIEG!" korrekt mit Score/Stage und Namenseingabe).

**Fünfte Playtest-Runde (2026-09-13): Überschriften weiß statt gelb,
Pause-Button jetzt Milchglas + immer sichtbar/mausklickbar, Einflug-Marge um
eine Gegnerhöhe vergrößert, Achievement-Spawnrate überprüft (kein Bug).**
- **Überschriften Weiß statt Gelb**: `ui_style.gd::impact_label()`s
  Default-Füllfarbe war `Color("ffe066")` (Gelb) — jetzt `Color.WHITE`, Outline
  bleibt Cyan (`ACCENT`, seit „Dritte Playtest-Runde"). Betrifft wie beim
  Outline-Fix automatisch jede Menü-Überschrift UND das In-Game-„STAGE
  n"-Banner (gleiche Funktion, bewusst nicht getrennt).
- **Pause-Button: Milchglas + immer da, nicht nur Touch** — die globale
  CLAUDE.md fordert seit Punkt 15 („Menü-Optik") explizit Milchglas-Optik für
  den Pause-Button, das war für Galaga nie umgesetzt; zusätzlich war der
  Button überhaupt nur sichtbar, wenn `_touch` erkannt wurde
  (`hud.gd::set_touch()`) — auf Desktop/Maus unsichtbar und unklickbar, obwohl
  die Klick-Verdrahtung (`pressed`-Signal) längst da war. Fix: `set_touch()`
  entfernt (war die einzige Verwendung), `PauseButton.visible` ist jetzt
  immer `true` (`game.tscn`). Neue `hud.gd::_add_pause_glass()`: derselbe
  Trick wie `UiStyle.make_glass_backdrop()` in den Menüs (`BackBufferCopy` +
  geshaderte `ColorRect`), nur auf die Button-Fläche statt den ganzen Screen
  zugeschnitten (Rect exakt aus `_pause_btn`s eigenen Offsets übernommen,
  nicht separat hartkodiert) und dauerhaft sichtbar statt nur bei offenem
  Menü. Zeichenreihenfolge ist wichtig und per `move_child()` erzwungen:
  BackBufferCopy VOR dem Button (sonst würde es den Button mit ins
  Unschärfe-Sample einfangen), ColorRect NACH dem BackBufferCopy aber VOR dem
  Button (sonst würde die Unschärfe über Button-Text/-Stil zeichnen). Der
  bestehende `UiStyle.style_button()`-Akzent-Tint bleibt zusätzlich obendrauf
  (gleiches „Glas + Tönung"-Prinzip wie bei den Menü-Panels). Per Live-Test
  verifiziert: Button oben rechts sichtbar mit sichtbar geblurrtem Hintergrund,
  per `click_button_by_text` (simuliert echten Mausklick) öffnet er zuverlässig
  das Pausenmenü.
- **Einflug-von-unten-Marge um eine Gegnerhöhe vergrößert**: die am
  2026-09-13 (vierte Runde) eingeführte Regel „erst über der Kanonenhöhe
  abschießbar" verglich exakt gegen `player.global_position.y` — traf einen
  Gegner exakt auf Kanonenhöhe, sah das wie „aus dem Lauf geschossen" aus,
  nicht wie ein echter Treffer. `enemy.gd::_is_invulnerable()` vergleicht
  jetzt gegen `player.global_position.y - enemy_height` (`enemy_height` =
  `EnemyKinds.DATA[kind]["half"] * 2`, je nach Gegnertyp 26–36 px) — der
  Gegner muss also eine volle eigene Körperhöhe über der Kanonenspitze sein,
  bevor er verwundbar wird. Per Live-Test mit drei Positionen (auf Kanonenhöhe,
  knapp innerhalb der neuen Marge, knapp darüber) verifiziert.
- **„Viel weniger Achievements" — überprüft, kein Bug gefunden**:
  Nutzer-Sorge, die neue 7er-Reihen-Grenze/der Rundenzähler
  („Dritte Playtest-Runde") könnte versehentlich auch die Spawnrate der
  Bonus-Items selbst gedrückt haben. `game.gd`s Spawn-Timer
  (`BONUS_INTERVAL_MIN/MAX` = 14–24 s) wurde in keiner der letzten beiden
  Runden angefasst; per Live-Messung (`Time.get_ticks_msec()` vor/nach einem
  beobachteten Spawn) bestätigt: Intervall lief exakt im erwarteten Rahmen,
  ein Bonus-Item spawnte pünktlich. Die wahrscheinlichste Erklärung für den
  Eindruck „weniger": das ist das VOM NUTZER SELBST gewünschte Verhalten aus
  der dritten Runde — die Icon-Reihe zeigte vorher (Cap 8, `pop_front()`)
  nach den ersten 8 Pickups dauerhaft eine volle Reihe; jetzt leert sie sich
  bei jeder vollen 7er-Reihe komplett und baut sich von 0 neu auf, was sich
  optisch nach "plötzlich kommt nichts mehr" anfühlen kann, obwohl im
  Hintergrund exakt gleich oft gespawnt/gesammelt wird. Nicht ungefragt
  geändert (war explizite Vorgabe), aber hier vermerkt, falls das Design
  nochmal in Frage gestellt wird — z. B. mit einem kurzen "Lap!"-Aufblitzen
  beim Reset, damit es als Belohnung statt als Verschwinden liest. **Update
  2026-09-13 (Sechste Playtest-Runde): Die Analyse hier war unvollständig —
  es gab doch einen echten Bug, siehe unten.**

**Sechste Playtest-Runde (2026-09-13): echter Bonus-Timer-Bug gefunden,
eindeutige Achievement-Icons pro Reihe, "+Punkte"-Popup + "Lap!"-Banner,
Einflug-Marge korrigiert (Kanonenmündung statt Schiffsrumpf), Settings-Grid
für echte Spalten-Ausrichtung, Boss/Passagier-Überlappung behoben.**
- **Doch ein echter Bug bei „zu wenige Achievements"**: die Analyse aus der
  fünften Runde (reine Wahrnehmungsfrage durch den Reihen-Reset) war
  unvollständig. Der eigentliche Übeltäter: `game.gd::_on_stage_populated()`
  hat `_bonus_t` bei **jedem** Stage-Wechsel auf einen frischen Zufallswert
  gesetzt — unabhängig davon, wie viel von der vorherigen Runde schon
  abgelaufen war. Ein geübter Spieler, der eine Stage in deutlich unter
  14 Sekunden leerräumt, lässt den Timer dadurch NIE ablaufen: er wird vor
  Erreichen der Null immer wieder zurückgesetzt. Bei einem 60000-Punkte-Lauf
  über viele Stages hinweg erklärt das zwanglos „nur ein einziges Achievement
  gesehen". Fix: `_bonus_t` wird nur noch **einmal** pro Run gesetzt (in
  `_new_run()`), `_on_stage_populated()` fasst ihn nicht mehr an — er zählt
  jetzt durchgehend über Stage-Grenzen hinweg (pausiert nur während
  READY/ENTERING, wo `_process()` ohnehin früh zurückkehrt). Zusätzlich
  `BONUS_INTERVAL_MIN/MAX` von 14–24 s auf 9–16 s verkürzt, als zusätzlicher
  Puffer. Per Live-Test verifiziert: `_bonus_t` lief nach einem erzwungenen
  sofortigen Stage-Clear (statt zurückgesetzt) einfach weiter herunter und
  spawnte pünktlich, sobald er in der neuen Stage bei Null ankam.
- **Nur eindeutige Achievement-Icons pro Reihe**: `bonus_item.gd` bekommt jetzt
  vor dem Spawn (`game.gd::_spawn_bonus_item()`, gesetzt **vor** `add_child()`
  — gleiche Reihenfolge-Regel wie beim x-Positions-Bug der dritten Runde) die
  Liste der in der aktuellen (noch nicht vollen) HUD-Reihe bereits gezeigten
  Indizes (`hud.gd::current_lap_indices()`) und schließt sie beim
  Zufalls-Icon aus (`exclude_indices`). `hud.gd` führt dafür jetzt
  `_bonus_icon_indices` parallel zu `_bonus_icons`. Per Live-Test mit 7
  aufeinanderfolgenden Pickups verifiziert: alle 7 Icons unterschiedlich,
  danach korrekter Reihen-Reset.
- **"+Punkte"-Popup + "Lap!"-Banner**: neue `score_popup.gd` (schlichtes
  `Node2D` mit eigenem `_draw()`, kein `.tscn` nötig) zeigt kurz "+500" (oder
  "+3000" inkl. Rundenbonus) genau an der Stelle, wo ein Bonus-Item
  eingesammelt wurde, treibt dabei leicht nach oben und blendet aus
  (`game.gd::_spawn_score_popup()`). Gilt **nur** für Bonus-Items, nicht für
  Gegner-Kills (kein entsprechender Code in `enemy.gd`). Zusätzlich löst ein
  volles Lap (`hud.add_bonus_icon()` liefert `true`) jetzt `hud.flash_banner
  ("LAP!")` aus — denselben Center-Banner wie „BEREIT"/„STAGE n" — damit der
  Reihen-Reset als Belohnungsmoment statt als Verschwinden liest. Per
  Live-Test verifiziert: Popup-Text, Position und Banner-Text/-Sichtbarkeit
  exakt wie erwartet.
- **Einflug-Marge maß vom falschen Bezugspunkt**: die in der vierten Runde
  eingeführte "erst über der Kanone abschießbar"-Regel verglich gegen
  `player.global_position.y` — das ist der Schiffs-**Rumpf**, nicht die
  tatsächliche Laser-Mündung, die `ship.gd::_fire_laser()` schon immer 22 px
  höher ansetzt. Dadurch konnte ein Gegner, der sich exakt auf Mündungshöhe
  befand (statt Rumpfhöhe), fälschlich schon als „getroffen, nicht an der
  Mündung" gelten. Fix: neue benannte Konstante
  `ship.gd::GUN_MUZZLE_OFFSET_Y = -22.0` (ersetzt die vorher inline
  hartkodierte `-22` in `_fire_laser()`), `enemy.gd::_is_invulnerable()`
  rechnet jetzt `gun_y = player.global_position.y + GUN_MUZZLE_OFFSET_Y` und
  vergleicht die Gegnerhöhen-Marge dagegen statt gegen den rohen Rumpf-y-Wert.
  Per Live-Test mit dem alten UND dem neuen Schwellenwert verifiziert: die
  neue Zone ist um die vollen 22 px großzügiger als vorher.
- **Settings-Menü: Stepper-Buttons jetzt spaltenweise ausgerichtet**: die
  vorherige Ein-`HBoxContainer`-pro-Zeile-Bauweise (`_stepper()`) ließ jede
  Zeile ihre eigene Beschriftungsbreite bestimmen — „Boss alle X Punkte" /
  „Sieg bei X Punkten" überschritten die fest verdrahtete 150px-Minimalbreite
  der kürzeren Zeilen („Leben" etc.), wodurch deren `</>`-Buttons spürbar
  weiter rechts standen als bei den anderen Zeilen. Fix: `_stepper()` →
  `_add_stepper(grid, ...)`, alle Stepper-Zeilen sind jetzt flache Kinder
  **eines** gemeinsamen `GridContainer` (4 Spalten: Name/</Wert/>) in
  `_build_settings()` statt eigener Boxen — ein `GridContainer` sizt jede
  Spalte automatisch auf die breiteste Zelle über ALLE Zeilen hinweg, macht
  die Ausrichtung also automatisch und robust gegen künftig noch längere
  Label-Texte. `_refresh_settings()` iteriert jetzt direkt über die
  Grid-Kinder (Meta `get_text` sitzt auf dem Wert-Control selbst statt auf
  einem Zeilen-Wrapper). Per Screenshot verifiziert: alle `<`/`>` exakt
  spaltenweise übereinander, unabhängig von der Label-Länge.
- **Boss/gefangenes-Schiff-Überlappung behoben**: das Passagier-Sprite
  (`ship_captured.png`, `enemy.gd::_spawn_captive_visual()`) hing bei voller
  Größe (Skalierung 0.11, wie das Spieler-Schiff) und 30px Versatz so weit
  unter dem Boss, dass es in die Formationsreihe direkt darunter hineinragte,
  sobald diese noch besetzt war. Zwei kombinierte Fixes (beide vom Nutzer
  vorgeschlagen): (1) Passagier kleiner (`CAPTIVE_SCALE = 0.085`) und näher
  am Boss (`CAPTIVE_OFFSET_Y = 22.0`, vorher 30), (2) `formation.gd`s
  Boss-Zeile (Zeile 0) bekommt ein neues `BOSS_ROW_Y_NUDGE = -10.0`, das NUR
  auf Boss-Slots angewendet wird — `ROW_SPACING` selbst bleibt unverändert,
  alle anderen Zeilen sind also unberührt, nur der Abstand zwischen Boss- und
  der Zeile darunter wächst um 10px. `_selftest.gd`s
  "every slot sits inside the upper half"-Check musste entsprechend auf
  `s.y < Formation.BOSS_ROW_Y_NUDGE` (statt `< 0.0`) angepasst werden, da die
  Boss-Zeile jetzt absichtlich leicht negativ liegt. Per Live-Screenshot
  verifiziert: sichtbarer Abstand zwischen Passagier-Sprite und der
  Goei-Zeile darunter, keine Überlappung mehr.

**Siebte Playtest-Runde (2026-09-13): Capture-Beam-Homing statt Snapshot-Kurve,
Feuerrate-Cooldown, Schuss-vor-Rekonstruktion verhindert, Laser gekürzt,
Hyper-Ammo verdoppelt auch Punkte, Run-Summary-Screen + HoF-Rang-Vorschau,
HUD-Layout (Lap-Marker fest, weniger Lebens-Icons), Hall-of-Fame-Spalten,
Punkte-Popup bei Boss-Rettungskill.**
- **Nutzer-Frage geklärt: „Muss ich in den Strahl fliegen oder passiert das
  automatisch?"** — Ursache der wahrgenommenen Inkonsistenz: der alte
  Capture-Anflug (`AttackPaths.capture_approach()`) backte die Kurve aus einer
  EINMALIGEN Momentaufnahme der Spielerposition beim Start des Angriffs. Bewegt
  sich der Spieler währenddessen (~1–2 s Anflug), landet der Strahl am Ende oft
  gar nicht mehr über ihm — daher „Strahl gesehen, aber nicht gefangen". Der
  gegenteilige Fall („gefangen, ganz ohne Strahl gesehen") ist vermutlich reine
  Wahrnehmung: der Strahl ist nur ~0,73 s sichtbar (Wachsen+Halten) in einem
  vollen Formationsbild — kein separater Bug dahinter gefunden.
- **Fix: echtes Live-Homing statt Snapshot-Kurve.** `enemy.gd`s
  `capture_dive()` fliegt keine vorgebackene Kurve mehr — neue States laufen
  jetzt über `_home_toward_player(delta)` (Anflug: `move_toward()` Richtung
  der AKTUELLEN Spielerposition, jeden Frame neu berechnet, bis die Hover-Höhe
  `CAPTURE_HOVER_Y_FRAC = 0.58` erreicht ist) und `_track_player_x(delta)`
  (hält den Boss horizontal auf dem Spieler, solange der Strahl unten hängt).
  `CAPTURE_HOMING_SPEED = 640 px/s` liegt bewusst über der Schiffs-eigenen
  Geschwindigkeit (480 px/s) — der Abstand kann dadurch nur schrumpfen, ein
  Ausweichen verzögert den Fang, verhindert ihn aber nicht („kann nicht
  entkommen", wie vom Nutzer gewünscht). Der Strahl (`capture_beam.tscn`) ist
  jetzt außerdem Kind-Node des Bosses statt Geschwister im Baum — er folgt der
  live nachjustierten Boss-Position automatisch mit, ganz ohne eigenen
  Sync-Code. `AttackPaths.capture_approach()` (die alte Kurvenfunktion) war
  dadurch tot und wurde entfernt. `enemy.gd`s `ship_rescued`-Signal trägt jetzt
  `at_position: Vector2` mit (Boss-Position beim Zerstören) — durchgereicht via
  `stage_director.gd` bis zu `game.gd`, Basis für den Punkte-Popup weiter unten.
  **Verifiziert per direktem Methodenaufruf** (`_home_toward_player`/
  `_track_player_x` mit manuell kontrolliertem `delta` und einer zwischen den
  Aufrufen hin- und herspringenden Spielerposition, um Wall-Clock-Drift
  zwischen MCP-Tool-Aufrufen zu umgehen — bei echtem Live-Spiel lief der ganze
  Fang-Zyklus regelmäßig schon innerhalb eines einzigen Tool-Roundtrips durch):
  der Boss-x folgt in jedem simulierten Frame exakt der jeweils aktuellen
  Spieler-x-Position, unabhängig davon, wie oft sich diese zwischendurch ändert.
- **Feuerrate-Cooldown gegen 5-Sekunden-Stage-Clears**: Zwillingsjäger +
  hohe „Max. Schüsse"-Einstellung konnten die Laser-Slots so schnell
  nachfüllen, wie sie durch Treffer wieder frei wurden — begrenzt effektiv nur
  durch die Flugzeit zum nächsten Treffer, nicht durch eine echte Kadenz. Neue
  `ship.gd::FIRE_COOLDOWN = 0.15` s, `shoot()` blockt jetzt zusätzlich zur
  Slot-Kapazitätsprüfung auch bei laufendem Cooldown. Per Live-Test verifiziert:
  ein sofortiger zweiter `shoot()`-Aufruf direkt nach dem ersten wird geblockt,
  nach Ablauf von `FIRE_COOLDOWN` klappt der nächste Schuss wieder.
- **Schießen war während der Rekonstruktions-Animation möglich**: `ship.gd`s
  `_alive` startet beim Skript-Laden als `true` und wurde vor dem ALLERERSTEN
  Rekonstruktions-Lauf in `game.gd::_new_run()` nie explizit auf `false`
  gesetzt (nur `_destroy()` bei echten Treffern tat das) — `_process()`s
  `if not _alive: return`-Gate griff deshalb beim Rundenstart nicht, ein
  gehaltener Schuss-Input feuerte trotz unsichtbarem/nicht-monitorndem Schiff.
  Fix: `_new_run()` setzt jetzt `_ship._alive = false` direkt neben
  `_ship.visible = false`, noch vor dem `await _play_reconstruct(...)`. Der
  Respawn-Pfad (`_on_ship_died()`) war davon nicht betroffen — dort setzt
  `_destroy()` `_alive` schon vorher korrekt. Per Live-Test verifiziert:
  `_ship._alive` ist unmittelbar nach `_new_run()` (vor dem ersten `await`)
  `false`.
- **Laser auf 2/3 gekürzt**: `laser.gd::_draw()` nutzt jetzt
  `BEAM_LEN`/`BEAM_HEAD_LEN` (16px/5px × 2/3) statt der harten Werte — nur die
  sichtbaren `_draw()`-Rechtecke, die Trefferbox (9×18, bewusst großzügiger als
  der sichtbare Strahl) ist unangetastet.
- **Hyper-Ammo verdoppelt jetzt auch die Punktzahl pro Kill**, nicht nur die
  Schusszahl: `game.gd::_on_enemy_killed()` verdoppelt `points`, wenn
  `_ship._hyper_ammo` aktiv ist, bevor sie zum Score addiert werden. Per
  Live-Test verifiziert: derselbe 50-Punkte-Kill bringt mit aktivem Hyper-Ammo
  100, ohne 50.
- **Neuer Run-Summary-Screen vor dem Game-Over/Highscore-Bildschirm**:
  `menus.gd::show_run_summary(score, stage, won, rescues, rescue_points,
  achievements, laps)` (neuer Screen `"summary"`) zeigt Anzahl geretteter
  Schiffe + die dadurch erzielte Punktzahl, Anzahl gesammelter Achievements +
  Runden (Laps), die Gesamtpunktzahl, und — falls die Punktzahl für die
  Top 10 reicht — den voraussichtlichen Highscore-Platz (neue
  `HallOfFame.rank_for(score)`). Erst der „Weiter"-Button dort führt zum
  bestehenden `"gameover"`-Screen mit Namenseingabe. `game.gd` trackt dafür neu
  `_rescues`, `_rescue_points`, `_achievements_collected` (alle einmal pro Run
  in `_new_run()` zurückgesetzt) und ruft in `_on_ship_died()`s Game-Over-Zweig
  sowie in `_check_win()` jetzt `show_run_summary(...)` statt direkt
  `show_game_over(...)` auf. Per Live-Screenshot verifiziert (inkl. der
  Highscore-Rang-Zeile bei einer qualifizierenden Punktzahl).
- **Punkte-Popup jetzt auch bei Boss-Rettungskills**: `game.gd::
  _on_ship_rescued(at_position)` (neuer Parameter, siehe Homing-Fix oben) ruft
  jetzt `_spawn_score_popup(at_position, "+%d" % _last_kill_points)` auf —
  `_last_kill_points` wird in `_on_enemy_killed()` mitgeführt (die schon
  bestehende, bereits eventuell verdoppelte Kill-Punktzahl); da `killed` und
  `ship_rescued` synchron nacheinander aus `enemy.gd::_explode()` feuern, ist
  der Wert beim Rettungs-Handler garantiert schon aktuell. Gleiche
  Popup-Machinerie wie bei Bonus-Item-Pickups, nur an der Boss-Position statt
  am Item. Per Live-Test verifiziert (`_rescues`/`_rescue_points` erhöhen sich
  korrekt, Popup-Aufruf mit dem richtigen Betrag).
- **HUD-Layout**: `MANY_THRESHOLD` (Lebens-Icons) 5 → 3 — ab 3 verbleibenden
  Schiffen jetzt ein Icon + „× N" statt einzelner Symbole. Der Runden-Zähler
  (Lap-Marker, goldener Kreis) sitzt jetzt an einer FESTEN Position nahe dem
  rechten Rand (`hud.gd::STAGE_LABEL_LEFT/LAP_MARKER_GAP_RIGHT/LAP_MARKER_W`)
  statt direkt hinter der wechselnd breiten Achievement-Icon-Reihe herzuwandern.
  **Dabei einen echten Kollisions-Bug beim ersten Anlauf gefunden und behoben**:
  eine volle 6-Icon-Reihe (das Maximum vor dem automatischen Rundenschluss bei
  7) reichte bei echter Bildschirmzentrierung bis in den fest positionierten
  Marker-Bereich hinein (per Live-Screenshot entdeckt — Icons und Marker
  überlappten sichtbar). Fix: die Icon-Reihe zentriert sich jetzt nicht mehr
  über die volle Bildschirmbreite, sondern nur über den Platz LINKS vom
  Marker-Bereich (`ICON_ROW_GAP_FROM_MARKER`) — dadurch bleibt garantiert
  Abstand zum Marker, unabhängig von der aktuellen Icon-Zahl. Per
  Live-Screenshot mit 6 Icons erneut verifiziert: kein Überlapp mehr, sichtbare
  Lücken zu beiden Seiten des Markers. Die Stage-Anzeige war schon vorher
  Cyan (`UiStyle.ACCENT`, siehe `hud.gd::_ready()`) — dieser Teil des
  Nutzerwunsches war bereits erfüllt.
- **Hall-of-Fame-Liste spaltenweise ausgerichtet**: die alte Darstellung baute
  einen einzigen mit Leerzeichen aufgefüllten String pro Zeile
  (`"%2d.  %-8s  %06d"`) — mit einer proportionalen Schrift richten
  Leerzeichen nichts zuverlässig aus. Fix: `_hof_box` ist jetzt ein
  `GridContainer` (3 Spalten: Platz/Name/Score, gleiche Technik wie beim
  Settings-Stepper-Grid der sechsten Runde) statt einer `VBoxContainer` mit
  Text-Zeilen — Rang rechtsbündig, Name linksbündig (mit
  `SIZE_EXPAND_FILL`, damit die Score-Spalte immer am rechten Rand bleibt),
  Score rechtsbündig. Per Live-Screenshot verifiziert: alle Namen exakt
  linksbündig, alle Scores exakt rechtsbündig untereinander, unabhängig von
  Namenslänge.
- Erledigt bei der Gelegenheit: eine während dieser Testreihe versehentlich mit
  Test-Einträgen ("bb", "X", "MITTELLANG", …) verunreinigte
  `user://hall_of_fame.cfg` wurde zurückgesetzt.

**Achte Playtest-Runde (2026-09-13): Bomben verschwinden bei Stage-Clear,
Stage wartet zusätzlich auf Achievements, Kill-Aufschlüsselung in der
Run-Summary, Einstellungen wirklich live (inkl. Leben-Sperre + Sieg-Score-
Reaktivität), Schiffsposition gegen die echte Bildschirmhöhe statt fixe
Canvas-y, HUD-Achievement-Reihe kollisionssicher, Lap-Anzeige/-Zähler-Timing,
Touch-Feuern nur bei aufliegendem Finger.**
- **Bomben-Inkonsistenz nach Stage-Clear behoben**: Bomben sind eigenständige
  Objekte (`bomb.gd`), unabhängig vom werfenden Gegner — sie bleiben nach
  dessen Abschuss regulär gefährlich (kein Sonderfall nötig, das war schon so).
  Der eine echte Fall, in dem das falsch wirkte: nach dem letzten Gegner einer
  Stage blieben bereits geworfene Bomben einfach in der Luft und konnten noch
  während des „STAGE n"-Banners der nächsten Stage treffen — obwohl der Level
  bereits gecleared war. Fix: `game.gd::_process()` räumt beim Stage-Clear
  jetzt explizit die ganze `enemy_shots`-Gruppe leer, bevor `_stage` erhöht
  wird. Per direktem `_process()`-Aufruf verifiziert (Bombe vorhanden + letzter
  Gegner weg → Bombe verschwindet, Stage erhöht sich erst danach).
- **Stage-Clear wartet zusätzlich auf Achievements** (Nutzer-Zusatz mitten im
  Auftrag): ein noch auf dem Schirm befindliches `bonus_item` verzögert jetzt
  den Stage-Wechsel, bis es entweder eingesammelt wurde oder selbst unten
  herausgefallen ist (`bonus_item.gd` gibt sich dabei ohnehin frei) —
  `get_tree().get_nodes_in_group("bonus_item").is_empty()` als zusätzliche
  Bedingung neben der Gegner-Prüfung. Per direktem `_process()`-Aufruf mit
  einem künstlich plazierten `bonus_item` verifiziert: Stage bleibt bei
  vorhandenem Item stehen, wechselt sofort im Folgeaufruf nach dessen
  Entfernen.
- **Kill-Aufschlüsselung in der Run-Summary**: `enemy.gd`s `killed`-Signal
  trägt jetzt `(points, kind)` statt nur `points` (durchgereicht über
  `stage_director.gd`s `enemy_killed(points, kind)`), `game.gd` führt
  `_kill_counts`/`_kill_points` pro `EnemyKinds`-Wert (einmal pro Run
  zurückgesetzt) und übergibt beides an `menus.gd::show_run_summary(...)`.
  Der Summary-Screen zeigt jetzt eine Reihe mit den drei klassischen
  Gegner-Sprites (Biene/Schmetterling/Boss, stage-varianten-unabhängig wie
  schon die Hilfe-Seiten-Icons) + „N× / P Pkt." darunter — immer alle drei,
  auch bei 0, damit das Layout nicht je nach Run springt. Per Live-Test
  verifiziert (`_on_enemy_killed(50, ZAKO)` u. Ä. direkt aufgerufen, Summary
  zeigte korrekt „2× / 100 Pkt." usw.).
- **Einstellungen wirken jetzt wirklich sofort mid-Run** — vorher setzte nur
  „Max. Schüsse" (`ship.configure()`) live um, alles andere (Extra-Leben,
  Boss-Intervall, Sieg-Score, Schwierigkeit) wurde in `_reload_settings()`
  zwar neu geladen, aber erst in `_new_run()` tatsächlich in die laufenden
  `_next_extra`/`_next_boss_score`/`_win_score`/`_director`-Werte übernommen —
  eine Änderung mitten im Spiel griff also frühestens in der nächsten Runde.
  Fix: `_reload_settings()` (läuft bei jedem `settings_changed`, also auch aus
  dem Pausenmenü) ruft jetzt zusätzlich `_director.configure(GameSettings.
  dive_params(...))` (Schwierigkeit — steuert laut `game_settings.gd`
  ausschließlich das Sturzflug-Timing des `StageDirector`: Verzögerung bis zum
  ersten Dive, Sekunden zwischen Dives, max. gleichzeitige Diver — sonst
  nichts) sowie zwei neue Helfer `_apply_extra_life_setting()`/
  `_apply_boss_interval_setting()`, die bei einer Änderung des jeweiligen
  Schritts die nächste Schwelle relativ zum AKTUELLEN Punktestand neu
  berechnen (`floori(float(_score)/step)+1) * step` — verwirft die alte,
  jetzt bedeutungslose fixe Schwelle, statt sie entweder sofort im Block
  auszulösen oder nie wieder zu erreichen). „Sieg bei X Punkten" reagiert am
  sichtbarsten: `_win_score` wird sofort übernommen und `_check_win()` direkt
  danach erneut geprüft — senkt man es unter (oder auf) die aktuelle
  Punktzahl während einer laufenden Runde, endet das Spiel augenblicklich mit
  dem Sieg-Bildschirm, auch direkt aus dem Pausenmenü heraus. Dabei einen
  Race-Bug gefunden und gefixt: `menus.gd::_close_sub()` swappte nach dem
  `settings_changed`-Signal bedingungslos zurück auf `_return_to` (i. d. R.
  „pause") — lief der Sieg-Check im selben Aufruf synchron durch und zeigte
  bereits den Summary-Screen, wurde der sofort wieder vom Pausenmenü
  überschrieben. Fix: `_close_sub()` prüft danach, ob „summary"/„gameover"
  inzwischen sichtbar ist, und lässt den Swap in dem Fall aus. Alle Pfade per
  Live-Test verifiziert (`_reload_settings()` direkt mit geänderten
  `GameSettings`-Werten aufgerufen; `_close_sub()` mit `_cfg.win_score` unter
  dem laufenden Score aufgerufen → Summary-Screen erscheint, Pause-Screen
  bleibt versteckt).
- **„Leben" ist während einer laufenden Runde gesperrt** (Nutzer-Vorgabe: wird
  ohnehin nur einmalig in `_new_run()` gelesen, eine Änderung mitten im Spiel
  hätte also sowieso nichts bewirkt — das jetzt auch sichtbar machen statt
  einen wirkungslosen Regler anzubieten). `menus.gd::_add_stepper()` gibt jetzt
  seine `{left, val, right}`-Controls zurück; `_update_lives_lock()` (läuft in
  `_refresh_settings()`) deaktiviert `<`/`>` und macht das Eingabefeld
  nicht-editierbar + halbtransparent, sobald die Einstellungen aus dem
  Pausenmenü geöffnet wurden (`_return_to == "pause"`) — von Titel aus
  weiterhin normal bedienbar. Per Live-Test verifiziert (`left.disabled`/
  `right.disabled`/`val.editable` korrekt `true`/`true`/`false` mitten im Lauf,
  alle `false`/`false`/`true` vom Titel aus).
- **Schiffsposition folgt jetzt der echten Bildschirmhöhe statt einer
  Canvas-fixen y** — Ursache eines Nutzer-Reports „Achievements landen
  plötzlich unter dem Schiff, kaum einsammelbar, und das Schiff sitzt gefühlt
  zu weit oben": auf Touch-Geräten (`CONTENT_SCALE_ASPECT_KEEP_WIDTH`) meldet
  `get_viewport_rect().size.y` MEHR als die 960 Design-Höhe (der Rest ist laut
  globaler CLAUDE.md absichtlich freier Fingerraum unterhalb des fixen
  Spielfelds) — `bonus_item.gd`/`bomb.gd` fallen aber genau gegen diese
  ECHTE (größere) Höhe, während das Schiff bislang auf einer aus `game.tscn`
  fix übernommenen y-Position (960-76=884, minus Flammen-Clearance) verharrte.
  Auf einem deutlich höheren Gerät (z. B. 2,2:1 wie OPPO Find X2 Pro/OnePlus
  12) klafft dadurch eine Lücke von mehreren hundert Pixeln zwischen der
  fixen Schiffsposition und dem tatsächlichen unteren Rand, in die
  Achievements/Bomben ungehindert weiterfallen, ohne je das Schiff zu
  erreichen. Fix: `ship.gd::_update_home_y()` berechnet die Ruheposition jetzt
  als `get_viewport_rect().size.y - HUD_BOTTOM_CLEARANCE(76) - thruster.
  max_length - THRUSTER_CLEARANCE_MARGIN` — auf Desktop (`KEEP`, immer exakt
  960) reproduziert das die alte Position 1:1 (verifiziert: y=779 unverändert),
  auf einem simulierten großen Touch-Viewport (1188) rutscht das Schiff
  entsprechend weit nach unten (y=1007 statt der alten fixen 884). Läuft auch
  beim retroaktiven Touch-Flip (`apply_touch_layout()`, `call_deferred` damit
  die Aspect-Umschaltung sicher zuerst greift) — dabei bewusst nur y neu
  gesetzt, x bleibt an der aktuellen Spielerposition, damit ein spät
  erkannter Touch das Schiff nicht mitten im Gefecht auf die Mitte
  zurückspringen lässt.
- **HUD-Achievement-Reihe kollisionssicher gemacht statt nur nach rechts
  verschoben**: eine reine feste Verschiebung um 28px (wie ursprünglich
  angefragt) reichte nicht aus — bei 2-stelliger Lebensanzahl UND mehreren
  besonders breiten Achievement-Icons gleichzeitig (Live-Test mit
  `×99`-Anzeige + den 7 breitesten von 12 möglichen Icons) blieb die Reihe
  trotz Verschiebung mit der Lebensanzeige links UND geriet gleichzeitig zu
  nah an den Lap-Marker rechts — der verfügbare Platz zwischen beiden reicht
  in diesem Extremfall schlicht nicht für die volle Icon-Größe. Fix:
  `hud.gd::_draw_bonus_icons()` zentriert die Reihe weiterhin bevorzugt mit
  dem 28px-Rechts-Versatz, klemmt das Ergebnis aber hart auf
  `[ROW_LEFT_MIN_X(90), usable_w - Reihenbreite]` — und skaliert Icons + Lücken
  gleichmäßig herunter, falls selbst das nicht reicht, statt eine Kollision
  zuzulassen. Live gefunden UND live nachgewiesen behoben (erst mit
  sichtbarem Überlapp zwischen „× 12" und dem ersten Icon, nach dem Fix
  sauberer Abstand auf beiden Seiten, auch im 7-Icon-Extremfall mit leicht
  verkleinerten Icons statt Kollision).
- **Lap-Anzeige/-Zähler-Timing korrigiert**: das 7. (bis dahin einzigartige)
  Achievement-Icon wurde bislang im selben Frame wieder gelöscht, in dem es
  hinzugefügt wurde (`add_bonus_icon()` leerte die Reihe synchron beim
  Erreichen von `BONUS_MAX_SHOWN`) — man sah es also nie. Fix:
  `hud.gd::add_bonus_icon()` setzt bei voller Reihe nur noch `_lap_pending`
  und lässt die vollen 7 Icons `LAP_HOLD_TIME` (0,7 s) lang stehen, bevor
  `_finish_lap()` den Rundenzähler hochzählt und die Reihe leert (Pickups
  während dieses Hold-Fensters zählen in `game.gd` weiterhin Punkte, werden
  aber nicht mehr zusätzlich in die schon volle Reihe gehängt — ein echter,
  live gefundener Folgefehler des ersten Fixes: ohne diese Sperre wuchs die
  Reihe während des Hold-Fensters über 7 Icons hinaus und kollidierte selbst
  mit dem eigenen Lap-Marker). Der Marker selbst wird jetzt IMMER gezeichnet
  (auch bei 0 Runden, startet bei „× 0") statt erst ab der ersten
  abgeschlossenen Reihe zu erscheinen. Farbe von Gold auf Türkis geändert
  (`BONUS_LAP_COLOR`, passend zum normalen Laser-Akzent). Per
  `monitor_properties`-Zeitreihe verifiziert: sofort nach dem 7. Icon
  `_bonus_laps=0`/alle 7 sichtbar, nach Ablauf des Hold-Fensters (bei
  entpausiertem Baum — ein pausierter Baum hält den Timer korrekt an, statt
  ihn weiterlaufen zu lassen) `_bonus_laps=1`/Reihe leer.
- **Touch-Feuern nur bei tatsächlich aufliegendem Finger**: `ship.gd` feuerte
  bisher auf jedem als „Touch-fähig" erkannten Gerät DAUERHAFT
  (`if _touch or ...`, `_touch` war nur die einmalig erkannte Geräte-Fähigkeit,
  nicht der aktuelle Berührungszustand) — auf Geräten mit sowohl Touchscreen
  als auch Maus/Tastatur (Nutzer-Beispiel: Linux/Windows-Touch-Laptops) schoss
  das Schiff dadurch permanent, auch ohne aufliegenden Finger. Fix: neues
  `_touch_down`, gesetzt/gelöscht durch echte `InputEventScreenTouch`
  press/release-Events, ersetzt `_touch` in der Feuer-Bedingung (die
  Geräte-Fähigkeits-Var `_touch` selbst wurde dadurch überflüssig und
  entfernt). Dabei einen verwandten, latenten Bug in derselben Codezeile
  mitgefixt: Press/Release-Tracking lief bisher HINTER der `_alive`-Prüfung —
  starb das Schiff mit gehaltenem Finger/gehaltener Maustaste, ging das
  Release-Event während der Rekonstruktions-Animation verloren und
  `_touch_down`/`_mouse_down` blieben auf „gedrückt" hängen, was das neue
  Schiff sofort ohne frischen Tastendruck feuern ließ. Fix: Press/Release-
  Tracking läuft jetzt VOR dem `_alive`-Gate, nur die Steuerungs-Logik
  (Maus-Aim, Touch-Drag) bleibt dahinter. Per direktem
  `_unhandled_input()`-Aufruf mit synthetischen Touch-Events verifiziert
  (inkl. des Stirbt-mit-gehaltenem-Finger-Randfalls).

**Neunte Playtest-Runde (2026-09-13): Weiterspielen nach Sieg über
Einstellungen, Standardwerte-Button, Lap-Counter-Farbe/-Position feinjustiert,
Auto-Eintrag + Großschreibung in der Hall of Fame, Highscores vom Start-Menü,
Kill-Aufschlüsselung jetzt pro Sprite statt nur pro Gegnertyp.**
- **Korrektur zur achten Playtest-Runde**: dort stand „es gibt nur 3
  Gegnertypen" (ZAKO/GOEI/BOSS) — das stimmt nur für die drei PUNKTE-Stufen.
  Visuell gibt es 8 verschiedene Sprites (klassisch + 2 Stage-Varianten für
  Zako/Goei, klassisch + 1 Stage-Variante für Boss — siehe „Zusätzliche
  Gegnertypen" weiter oben), plus jetzt einen 9. Sonderfall für den
  Boss-Rettungskill (siehe unten). Die Kill-Aufschlüsselung im
  Run-Summary-Screen zeigt jetzt **pro tatsächlich gesehenem Sprite** eine
  eigene Kachel (Icon + „N× / P Pkt."), nicht mehr nur 3 fixe Spalten nach
  Punkte-Stufe. `enemy_kinds.gd::pick_visual()` liefert dafür jetzt zusätzlich
  `variant_idx` (-1 = klassischer Stage-1-Look, sonst Index in `*_VARIANTS`),
  `enemy.gd` merkt sich das in `_variant_idx` (gesetzt in `setup()`) und
  reicht es über sein `killed`-Signal (`points, kind, variant_idx,
  was_carrying_captive`) durch. **Ein Boss, der abgeschossen wird, während er
  gerade ein Schiff trägt** (`was_carrying_captive`), bekommt eine eigene,
  vom normalen Boss-Kill getrennte Kachel mit dem `ship_captured.png`-Icon —
  Nutzerwunsch, weil das ein qualitativ anderes Ereignis ist (bringt den
  Zwillingsjäger-Bonus). `game.gd::_kill_stats` ist jetzt ein Array von
  `{kind, variant_idx, is_rescue, icon, count, points}`-Einträgen
  (`_kill_stat_entry()` sucht/erstellt den passenden Eintrag), ersetzt die
  alten `_kill_counts`/`_kill_points`-Dictionaries. `menus.gd`s Kills-Reihe
  ist dafür jetzt ein `GridContainer` (4 Spalten, umbricht bei Bedarf) statt
  einer festen 3-Spalten-`HBoxContainer` — zeigt nur Kacheln für tatsächlich
  getroffene Sprites, sortiert nach Punkte-Stufe/Variante, Rettungskill immer
  zuletzt. Per Live-Test mit 6 verschiedenen simulierten Kills (3 Zako-Sprites,
  Goei, Boss normal, Boss-Rettung) verifiziert: 6 korrekt beschriftete Kacheln,
  sauber in 2 Zeilen umgebrochen.
- **Weiterspielen nach „Sieg" über die Einstellungen**: der Run-Summary-
  Screen (siebte Playtest-Runde) hat jetzt einen „Einstellungen"-Button
  (Nutzerwunsch) — nützlich vor allem für „Sieg bei X Punkten": hebt man den
  Wert dort an (oder schaltet ihn aus) über den aktuellen Punktestand hinaus,
  spielt die UNTERBROCHENE Runde direkt weiter, statt zwingend neu anfangen
  zu müssen. `game.gd::_ended_by_win` merkt sich, ob der aktuelle GAME_OVER
  ein „Sieg"-Ende war (nie bei einem echten Game Over durch Lebensverlust);
  `_reload_settings()` prüft danach `_state == GAME_OVER and _ended_by_win
  and (_win_score <= 0 or _score < _win_score)` und ruft in dem Fall
  `_revive_after_win_edit()` (Musik/Attacken/HUD/Pause rückgängig machen,
  `_state = FORMATION`) — nichts vom Spielfeld musste dafür extra
  aufgehoben werden, `_check_win()` hatte ohnehin nie `_clear_board()`
  aufgerufen. `menus.gd::_close_sub()` erkennt die Wiederbelebung am
  entpausierten Baum (`not get_tree().paused` direkt nach dem
  `settings_changed`-Signal) und blendet dann konsequent ALLE Menüs aus,
  statt zum Summary-Screen zurückzuspringen — sonst hätte der „Sieg"-Screen
  wieder aufgemacht, obwohl die Runde gerade erst weiterlief. Der
  Leben-Regler ist auch hier gesperrt (`_update_lives_lock()` behandelt
  `_return_to == "summary"` genauso wie `"pause"`), aus demselben Grund wie
  im Pausenmenü. Per Live-Test komplett durchgespielt: Sieg bei Score 530
  ausgelöst → Einstellungen geöffnet → Sieg-Score auf 100000 angehoben →
  Fertig → Spiel läuft mit demselben Score/Formation unmittelbar weiter,
  kein Menü sichtbar.
- **„Standardwerte"-Button in den Einstellungen** (Nutzerwunsch): setzt Leben
  3 / Extra-Leben 10000 / Boss alle 5000 Punkte / Sieg aus / Max. Schüsse 2 /
  Schwierigkeit Normal — bewusst NICHT Sound (eigene Sektion mit eigenen
  Defaults, siehe `sound_manager.gd`). Ändert wie jeder Stepper nur `_cfg` im
  Speicher, erst „Fertig" persistiert. Respektiert dieselbe Leben-Sperre wie
  der Leben-Stepper selbst — beim Zurücksetzen mitten in einer laufenden
  Runde (oder vom Sieg-Screen aus) bleibt Leben unangetastet, aus demselben
  Grund, aus dem der Regler dort gesperrt ist.
- **Lap-Counter-Farbe korrigiert**: der Nutzer hatte in der achten Runde
  „türkis" gesagt, gemeint war aber die konkrete Farbe des Stage-Labels
  direkt daneben (`UiStyle.ACCENT`, ein blaustichiges Türkis) — nicht das
  sattere `Laser.ACCENT_NORMAL`, das dort ursprünglich gelandet war.
  `hud.gd::BONUS_LAP_COLOR` zeigt jetzt exakt auf `UiStyle.ACCENT`. Zusätzlich
  `LAP_MARKER_GAP_RIGHT` 14→6 (Nutzerreport: zu viel Luft zu „Stage", zu
  wenig zur Achievement-Reihe) — verkleinert den Stage-Abstand um genau diesen
  Betrag UND vergrößert den Achievement-Abstand um etwa die Hälfte davon (die
  Icon-Reihe zentriert sich ja auch relativ zur Marker-Position, rutscht beim
  Verschieben des Markers also indirekt mit). Per Live-Screenshot verifiziert
  (Marker exakt stage-blau, sichtbarer Abstand auf beiden Seiten bei 6
  Achievement-Icons + „× 6" Lebensanzeige gleichzeitig).
- **Vergessene Highscore-Einträge werden automatisch nachgetragen**: verlässt
  man den Game-Over/Sieg-Bildschirm über „Nochmal", „Start-Menü" oder
  „Beenden", OHNE vorher „Eintragen" gedrückt zu haben, trägt
  `menus.gd::_maybe_auto_commit()` den Eintrag jetzt automatisch unter „YOU"
  ein — exakt das, was auch beim Drücken von „Eintragen" mit leerem Namen
  passiert wäre (`Entry.visible` dient dabei als „wurde noch nicht
  eingetragen"-Marker, wird durch `_commit_score()` auf `false` gesetzt).
  Nutzer nannte explizit „Nochmal"; auf „Start-Menü"/„Beenden" ausgeweitet,
  weil ein Verlassen ohne Eintrag dort denselben Datenverlust bedeuten würde.
- **Alle Highscore-Namen werden großgeschrieben angezeigt** — sowohl neu
  eingetragene (`_commit_score()` ruft jetzt `who.to_upper()` vor dem
  Speichern) als auch bereits vorhandene, noch klein geschriebene Alteinträge
  (`_render_hof_into()` ruft zusätzlich `.to_upper()` beim Anzeigen, deckt
  also auch Daten von vor dieser Änderung ab, ohne Migration).
- **Highscores vom Start-Menü aus aufrufbar** (Nutzerwunsch): neuer,
  rein lesender Screen `"highscores"` (`show_highscores()`,
  `_build_highscores()`) — derselbe `_render_hof_into()`-Renderer wie beim
  Game-Over-Screen, nur ohne Namenseingabe und ohne hervorgehobenen eigenen
  Eintrag (`highlight = -1`). Neuer Button „Highscores" im Titel-Bildschirm
  zwischen „Einstellungen" und „Hilfe".
- Erledigt bei der Gelegenheit: eine bei einer früheren Testreihe
  liegengebliebene, mit „bb"/1280 verunreinigte `user://hall_of_fame.cfg`
  wurde zurückgesetzt.

**Zehnte Playtest-Runde (2026-09-13): Standardwerte-Bestätigung, Laps-Anzeige
als Text + näher an Stage, komplett bildbasierte Hilfe.**
- **„Standardwerte" fragt jetzt nach** (Nutzer-Zusatz): der Button öffnet
  einen neuen Bestätigungs-Screen `"confirm_reset"` („Wirklich die
  Einstellungen auf Standardwerte zurücksetzen?" + „Ja"/„Nein") statt sofort
  zurückzusetzen — ein Verklicker kann die Einstellungen nicht mehr
  versehentlich wegwerfen. `_reset_defaults()` selbst läuft unverändert nur
  noch nach „Ja".
- **Lap-Anzeige ist jetzt Klartext**: `hud.gd::_draw_lap_marker()` zeichnet
  statt eines Kreis-Symbols + „× N" jetzt einfach „Laps N" (gleiche Farbe wie
  „Stage" daneben). `LAP_MARKER_GAP_RIGHT` weiter verkleinert (6→2 — dritte
  Anpassung in Folge, siehe „Neunte Playtest-Runde") und `LAP_MARKER_W` auf
  die neue Textbreite angepasst. Per Live-Screenshot mit `×12`-Lebensanzeige
  + 6 Achievement-Icons verifiziert: sauberer Abstand auf beiden Seiten.
- **Hilfe komplett neu, bildbasiert** (Nutzerwunsch, an tetris'
  `assets/help_src/`-Pipeline orientiert, aber Galagas eigenes Farbschema
  statt tetris' Gold/Lila): 6 neue Vektor-Illustrationen
  (`assets/help_src/*.svg`, gerendert per `render.sh`/Inkscape nach
  `assets/graphics/help/*.png`, 900px breit) — `keyboard`, `mouse`, `touch`,
  `goal`, `capture`, `bonus`. Jede bettet die ECHTEN Spiel-Sprites ein
  (`<image xlink:href="file:///…">` auf die tatsächlichen PNGs unter
  `assets/graphics/`, nicht nachgebaute Vektor-Icons) — Schiff, die drei
  Gegnertypen, das befreite Passagier-Sprite, zwei Achievement-Icons. Farben:
  dunkles Navy-Verlaufs-Panel + `UiStyle.ACCENT` (Cyan) für Akzente/Pfeile,
  passend zum Rest der Menüs.
  `menus.gd::HELP_PAGES_DESKTOP` (Tastatur, Maus, Ziel, Boss-Capture,
  Achievements — 5 Seiten) und `HELP_PAGES_TOUCH` (Touch statt Tastatur+Maus,
  sonst dieselben 3 gemeinsamen Seiten — 4 Seiten) ersetzen die alte
  text-only `HELP_PAGES`-Konstante; `_help_pages()` wählt anhand
  `_touch_context` (neu, gesetzt über `set_touch_context()` — `game.gd` ruft
  das sowohl bei der initialen Touch-Erkennung in `_ready()` als auch beim
  retroaktiven Touch-Flip in `apply_touch_layout()` auf, damit die Hilfe
  immer zur tatsächlich genutzten Eingabemethode passt). `_build_help()`
  bekommt dafür ein verbreitertes Panel (460px statt der sonst üblichen
  340px, wie schon `_build_splash()` vom schmalen Standard abweicht) mit
  einem `TextureRect` (430×468, `STRETCH_KEEP_ASPECT_CENTERED`) statt der
  alten Body-Label + Icons-Reihe; die Überschrift (`Head`-Label, z. B.
  „Steuerung — Tastatur") bleibt ein echtes Godot-Label darüber, nicht ins
  Bild gebacken — bleibt dadurch scharf und unabhängig von der
  Bild-Auflösung. `_icon_col()` (nur von der alten Ziel-Seite genutzt) war
  dadurch überflüssig und wurde entfernt. Per Live-Test alle 5 Desktop- und
  alle 4 Touch-Seiten durchgeklickt (inkl. Umschalten über
  `set_touch_context()`/`apply_touch_layout()`) — jede Seite sauber
  layoutet, keine Überlappungen (mehrere davon erst nach Layout-Korrekturen
  anhand der gerenderten PNGs, siehe die SVGs selbst für Details).

**Elfte Playtest-Runde (2026-09-13): eigene Hilfe-Karte „Schwierigkeitsstufen",
echte Achievement-Icons statt Platzhalter-Kacheln in der Bonus-Hilfe, echter
Bug bei der Schiffsposition auf hohen Touch-Geräten gefunden + behoben.**
- **Neue Hilfe-Seite „Schwierigkeitsstufen"** (Nutzerwunsch, nachdem er nach
  dem Unterschied zwischen Leicht/Normal/Schwer gefragt hatte — siehe
  `game_settings.gd::dive_params()`: die drei Stufen ändern NUR, wie oft und
  wie viele Gegner gleichzeitig aus der Formation stürzen, nicht Punkte,
  Leben oder die tatsächliche Flug-/Sturzgeschwindigkeit selbst). Neue
  `assets/help_src/difficulty.svg` → `difficulty.png`: ein „Angriffstempo"-
  Balken pro Stufe (grün/cyan/rot, Füllstand nur relativ — Leicht niedrig,
  Schwer fast voll, **bewusst ohne exakte Zahlen**, wie vom Nutzer verlangt)
  plus eine Reihe mit 1/2/3 Zako-Sprites für „gleichzeitige Angreifer", darunter
  zwei Klartext-Zeilen, dass sich sonst nichts ändert. Eingehängt in BEIDE
  `menus.gd::HELP_PAGES_DESKTOP`/`HELP_PAGES_TOUCH`, direkt nach „Ziel &
  Punkte" (6 Desktop- bzw. 5 Touch-Seiten jetzt, vorher 5/4). Per Live-Test in
  beiden Seiten-Sets verifiziert (Dot-Indikator korrekt bei 6 bzw. 5, Karte
  sauber im Panel, keine Überlappung).
- **Bonus-Hilfe: echte Icons statt der Platzhalter-Kacheln** — die
  „7 verschiedene Symbole in einer Reihe"-Mini-HUD-Mockup auf der
  Achievements-Hilfeseite zeigte bisher 7 einfarbige abgerundete Rechtecke
  (`fill-opacity 0.35`) statt echter Symbole — genau die vom Nutzer bemängelten
  „Karos". `assets/help_src/bonus.svg` bettet an deren Stelle jetzt 7
  tatsächlich unterschiedliche `achievement_XX.png` (Indizes 2/3/4/8/9/10/11,
  alle aus `bonus_item.gd::ICON_INDICES`, seitenverhältnis-korrekt skaliert auf
  eine gemeinsame Höhe von 52px) ein — zeigt die echte Symbolvielfalt statt
  einer abstrakten Platzhalter-Reihe. Zusätzlich (Nutzer-Zusatz) einen
  expliziten Hinweis ergänzt, dass das Flaggschiff-Symbol (`achievement_00`)
  den Laser **rot-weiß färbt** (vorher stand nur „Doppellaser", die Farbe war
  nirgends erwähnt) — dritte Textzeile „Doppellaser, färbt sich rot-weiß, bis
  zum Ende der Stage" im Hyper-Ammo-Abschnitt, restliche Sektion (Divider,
  „Laps 1"-Text, Bonuspunkte-Zeilen) entsprechend nach unten verschoben. Per
  Live-Screenshot verifiziert: alle 7 Icons sichtbar unterschiedlich, keine
  Überlappung, „rot-weiß" lesbar.
- **Echter Bug gefunden: Schiff auf hohen Touch-Geräten (z. B. OnePlus 12)
  saß noch immer zu weit oben** — die achte Playtest-Runde hatte
  `ship.gd::_update_home_y()` zwar schon korrekt auf die echte Viewport-Höhe
  umgestellt (statt einer canvas-fixen y), aber der Fix griff nur beim
  RETROAKTIVEN Touch-Flip (`apply_touch_layout()`, ausgelöst durch ein
  tatsächliches Touch-Input-Event) vollständig. Ursache: `Ship` ist ein
  KIND-Node von `Game` — Godot ruft `_ready()` von Kindern grundsätzlich VOR
  dem der Eltern auf. `ship._ready()` (und damit `_update_home_y()`) lief also
  schon, BEVOR `game._ready()` überhaupt `_apply_display_mode()` aufrief und
  `content_scale_aspect` von der Vorgabe auf `KEEP_WIDTH` umstellte. Auf einem
  Gerät, das Touch schon beim Start kennt (`OS.has_feature("mobile")` liefert
  sofort `true`, kein „später erkannt"-Fall), lief die
  `touch_layout_listeners`-Gruppe (die genau diese Neuberechnung nachholen
  würde) aber nie — sie wird ausschließlich von einem echten
  `InputEventScreenTouch`/`ScreenDrag` in `game.gd::_input()` ausgelöst, nicht
  vom synchronen Erkennungspfad in `_ready()`. Die einmalig in `ship._ready()`
  berechnete Position blieb also dauerhaft auf dem VORHERIGEN (kleineren)
  Viewport-Höhenwert stehen — exakt das vom Nutzer gemeldete Symptom. Fix:
  `game.gd::_ready()` ruft direkt nach `_apply_display_mode()` jetzt
  `get_tree().call_group("touch_layout_listeners", "apply_touch_layout")` auf
  (für `game.gd`s eigenen Listener ein harmloses No-op, da `_touch` da schon
  gesetzt ist; für `ship.gd` löst es `_update_home_y.call_deferred()` erneut
  aus — jetzt gegen den bereits korrekt umgeschalteten Aspect). Per
  Live-Test verifiziert (da die Embedded-Game-Ansicht im Editor sich nicht auf
  eine andere Fensterauflösung als die Design-Canvas bringen ließ, wurde die
  Korrektur-Mechanik direkt nachgewiesen: `ship.position.y` künstlich auf
  einen falschen Wert gesetzt, danach derselbe `call_group(...)`-Aufruf wie im
  Fix ausgeführt → Position sprang zuverlässig auf den aus der aktuellen
  Viewport-Höhe berechneten korrekten Wert zurück).

**Zwölfte Playtest-Runde (2026-09-13): Bonus-Icon-Reihe hält event-basiert
statt fester Zeit, Highscores auch aus dem Pausenmenü erreichbar.**
- **Bonus-Icon-Reihe: "Halten bis zum nächsten Pickup" statt fixer
  `LAP_HOLD_TIME`** (Nutzerwunsch — eine feste Sekundenzahl wirkte beliebig).
  `hud.gd::add_bonus_icon()` erhöht `_bonus_laps` jetzt SOFORT beim 7. Icon
  (der Lap-Zähler zeigt also augenblicklich „x+1", nicht erst nach einer
  Wartezeit) und setzt `_lap_pending = true`, räumt die Reihe aber NICHT
  selbst ab — sie bleibt mit allen 7 Icons stehen, solange nichts weiter
  passiert. Erst der NÄCHSTE Aufruf von `add_bonus_icon()` (irgendein
  künftiges Achievement) leert die alte Reihe und wird selbst zum einzigen
  Icon der neuen Reihe. Der bisherige `LAP_HOLD_TIME`-Timer (0,7 s) und
  `_finish_lap()` sind komplett entfallen — kein Timer mehr im Spiel,
  rein ereignisgesteuert. `current_lap_indices()` liefert während
  `_lap_pending` eine leere Liste (die alte, volle Reihe wird ohnehin gleich
  komplett ersetzt, „schon gesehene Icons ausschließen" ergibt für sie keinen
  Sinn mehr). Per Live-Test verifiziert: nach dem 7. Pickup `_bonus_laps=1`
  UND alle 7 Icons weiterhin sichtbar (`_lap_pending=true`); ein 8. simulierter
  Pickup danach leerte die Reihe auf genau 1 Icon, ohne `_bonus_laps` erneut
  zu erhöhen (`lap_done=false`).
- **Highscores jetzt auch aus dem Pausenmenü erreichbar** (Nutzerwunsch —
  bisher nur vom Titelbildschirm aus, siehe neunte Playtest-Runde). Neuer
  Button „Highscores" in `menus.gd::_build_pause()`, zwischen „Einstellungen"
  und „Hilfe". `show_highscores()` nimmt jetzt einen `from`-Parameter
  (Default `"title"`) und setzt `_return_to` genau wie `_open_settings()`/
  `_open_help()` — sonst hätte „Fertig" auf der Highscore-Seite eine aus der
  Pause heraus geöffnete Ansicht immer zum Titelbildschirm geschickt und die
  pausierte Runde dabei stillschweigend verloren. `_build_highscores()`s
  „Fertig" ruft entsprechend `_swap(_return_to)` statt fest `_swap("title")`.
  Per Live-Test verifiziert (direkter Aufruf von `_swap(_return_to)` nach
  `show_highscores("pause")`, da `click_button_by_text` bei zwei gleich
  benannten „Fertig"-Buttons im Baum — bekannte Einschränkung, siehe
  übergeordnete CLAUDE.md — den falschen traf): `_return_to` korrekt
  `"pause"`, Bildschirm nach dem Swap tatsächlich wieder „PAUSE".

**Dreizehnte Playtest-Runde (2026-09-13): kompletter Sound-Austausch —
zweite, größere Sammlung benannter Clips, neue Musik-Zustandsmaschine
(Pause/Einstellungen, Auswertung, Level-1-Intro mit Skip), drei neue
Abschuss-Sounds, Traktorstrahl-Fang-Sound, Stage-geschafft/Lap-voll-Sounds.**
- **Kompletter Ordnertausch**: `assets/sounds/` (die alten, synthetischen
  SFX-Rips aus der „Erste echte Assets"-Runde) → `assets/sounds_old/`
  (`git mv`, bleibt erhalten), eine zweite, deutlich größere vom Nutzer
  zusammengestellte Sammlung benannter `.ogg`-Clips
  (`~/Downloads/Galaga-Recherche/sounds/`, 12 Dateien) kopiert nach
  `assets/sounds/`. Einzige Korrektur dabei: `bonus-stage-clearedogg.ogg`
  (Tippfehler-Duplikat der Endung) → `bonus-stage-cleared.ogg` umbenannt.
  `sound_manager.gd`s Konvention „Key = Dateiname" (`res://assets/sounds/
  <key>.ogg`) wurde dabei konsequent durchgezogen: `player_boom` → Key +
  Dateiname `ship-destroyed` (ship.gd angepasst), das bisherige
  Sammel-`hit` komplett aufgeteilt in drei neue, gezieltere Keys (siehe
  unten) statt eines Alt-Keys mit neuer Datei. `CALIB_VERSION` 2→3 (verwirft
  alte gespeicherte %-Werte, da mehrere Keys umbenannt/neu sind). Vier
  bestehende Keys (`music`, `dive`, `extra`, `stage`) bekamen diesmal KEINE
  neue Datei — sie bleiben stumm, bis der Nutzer passende Clips nachliefert
  (exakt das in `sound_manager.gd`s eigenem Header dokumentierte
  Graceful-Degradation-Verhalten: „a missing file just makes that key
  silent"), ihre alte `base_db`-Kalibrierung blieb deshalb unangetastet. Alle
  neuen Keys bekamen `base_db=0.0` (neutral) — der Nutzer bat ausdrücklich
  darum, die Feinkalibrierung der Lautstärken auf eine spätere Runde zu
  verschieben, nachdem er die Clips im Spiel gehört hat; dafür bekam trotzdem
  **jeder** neue Sound sofort einen eigenen Lautstärke-Regler in der
  Sound-Unterseite (Nutzer-Zusatz), rein datengetrieben über
  `SoundManager.ORDER`/`SOUNDS` wie schon die alten 7 — keine Handarbeit in
  `menus.gd` pro Sound nötig.
- **Sound-Unterseite jetzt scrollbar + Zeilenumbruch-Labels**: von 7 auf 16
  Regler gewachsen, passte nicht mehr auf einmal in die 960er-Design-Canvas.
  `_build_sound()`: Box auf 460px verbreitert (wie `_build_help()`), die
  Regler-Liste steckt jetzt in einem `ScrollContainer` (560px hoch, „Fertig"
  bleibt außerhalb, immer sichtbar). `_sound_row()`s Namens-Label hat jetzt
  `autowrap_mode = AUTOWRAP_WORD` + `SIZE_EXPAND_FILL` statt einer festen
  140px-Mindestbreite — längere neue Namen wie „Boss (mit Schiff)
  abgeschossen" brechen sauber auf zwei Zeilen um, statt über den Panelrand
  hinauszulaufen (mehrere davon deutlich länger als die alten 7 kurzen
  Namen wie „Schuss"/„Treffer"). Per Live-Screenshot verifiziert (bis ganz
  unten gescrollt, alle 16 Zeilen sauber lesbar, kein Überlapp).
- **Neue Musik-Zustandsmaschine** (`sound_manager.gd` + `menus.gd`):
  `LOOPING_KEYS` (`music`, `pause-menu-music`, `scoring-board-music`)
  generalisiert den bisherigen, hart auf `"music"` verdrahteten
  Auto-Loop-Mechanismus (ein `_wanted`-Dictionary statt einer einzelnen
  `_music_wanted`-Bool-Variable) — `play()`/`stop()`/`preview()` behandeln
  jeden Key aus dieser Liste gleich (Sound-Unterseiten-Vorhören einer
  Loop-Spur toggled jetzt an/aus statt neu zu starten). Neue
  `is_playing(key)`. `menus.gd::_apply_screen_music(screen_name)` ist der
  EINZIGE Ort, der entscheidet, welche der beiden Menü-Musiken läuft —
  aufgerufen aus `_swap()` (jeder Screen-Wechsel) UND aus `hide_all()`
  (deckt auch die Direkt-Aufrufer in `game.gd` ab, die `hide_all()` ohne
  `_swap()` nutzen: `_resume()`, `_new_run()`, `_revive_after_win_edit()`).
  `MENU_MUSIC_SCREENS` (`pause`, `settings`, `confirm_reset`, `sound`,
  `highscores`) → `pause-menu-music` (Nutzerwunsch: „gehört zum
  Pause-Menü... auch für Einstellungs-Menü", Highscores als Fallback-Vorschlag
  des Nutzers selbst, „da habe ich keine Musik"). `SCORE_MUSIC_SCREENS`
  (`summary`, `gameover`) → `scoring-board-music` (Nutzerwunsch: „Musik für
  den Screen... mit der Übersicht der gemachten Punkte", ausdrücklich NICHT
  das separate Highscore-Board — `gameover` absichtlich mit reingenommen,
  da es direkt auf `summary` folgt und ein Musikbruch zwischen beiden
  Screens unnötig hart gewirkt hätte). Alles andere (`title`, `splash`,
  `help`) läuft still — für „Hilfe" nicht vom Nutzer erwähnt, deshalb bewusst
  auf „still" belassen statt geraten (Pause-Musik pausiert also kurz, wenn
  man aus der Pause die Hilfe öffnet — als möglicher Feinschliff vorgemerkt,
  falls das störend auffällt). Beide Musiken loopen (Nutzer-Zusatz: „Auch
  scoring-board-music muss loopen"). Per Live-Test jede Übergangskombination
  einzeln durchgeklickt (Titel→Einstellungen→Sound→Zurücksetzen→Titel,
  Pause→Highscores→zurück, Summary→Gameover→Titel) — jeweils genau die
  erwartete Musik an/aus.
- **Level-1-Intro-Musik mit Sperre + Skip** (`start-first-level-music`,
  einmalig, NICHT loopend): `game.gd::_new_run()` startet sie zusammen mit
  der (weiterhin stummen) `music`; `_intro_gate_active` merkt sich, dass
  gerade eine Sperre aktiv ist. `_start_ready()` lässt den Einflug (Wechsel
  zu ENTERING) nach dem üblichen Banner-Timer zusätzlich so lange stehen,
  bis der Clip fertig gespielt hat (`while _intro_gate_active and
  _snd.is_playing(...): await get_tree().process_frame` — reine Polling-
  Schleife, kein Timer/Signal-Racing nötig, da `is_playing()` ohnehin jeden
  Frame neu geprüft wird). `_unhandled_input()` beendet die Sperre sofort bei
  Linksklick ODER Touch-Tap (bewusst NICHT bei Tastendruck — exakte
  Nutzervorgabe „Maus/tappt"), stoppt den Clip dabei aktiv. Gilt nur für
  Stage 1 eines NEUEN Spiels (`_new_run()` läuft nur dort), nie bei Stage 2+
  oder einem Respawn. **Beim ersten Testlauf einen echten Timing-Bug bei mir
  selbst gefunden**: naive Verifikation über zwei getrennte MCP-Tool-Aufrufe
  mit dazwischenliegendem `sleep` täuschte ein sofortiges Durchrutschen vor —
  tatsächlich lag das an der immer wieder dokumentierten Zeit-Drift zwischen
  Tool-Aufrufen (die reale Rechenzeit zwischen zwei Anfragen reicht locker,
  um unbeaufsichtigt bis zum Game Over zu spielen). Sauber verifiziert über
  `Time.get_ticks_msec()`-Zeitstempel direkt im Spiel (Sperre hielt exakt bis
  zum natürlichen Ende der 6,9-Sekunden-Datei) sowie direkte
  `_unhandled_input()`-Aufrufe mit synthetischen Maus-/Touch-/Tastatur-Events
  (Maus und Touch brechen sofort ab, Taste tut nichts).
- **Drei Abschuss-Sounds statt einem** (`enemy.gd::_explode()`): ein Boss,
  der gerade ein Schiff trägt, bekommt `boss-killed`; ein Treffer während
  `DIVING`/`RETURNING` (nicht-Boss) bekommt `enemy-death2`; alles andere
  `enemy-death1` (ersetzt das alte Sammel-`hit`). **Echter Bug beim ersten
  Anlauf gefunden und sofort gefixt**: der Diving-Check las `_state`
  NACHDEM `_explode()` es schon auf `LOCKING` gesetzt hatte — fiel dadurch
  IMMER auf den „sonst"-Zweig zurück, ein Sturzflug-Kill klang nie anders
  als ein normaler. Fix: der Zustand wird jetzt in einer lokalen `was_diving`
  VOR der `LOCKING`-Zuweisung eingefroren. Per Live-Test mit allen drei
  Kombinationen verifiziert (IN_FORMATION → `enemy-death1`, künstlich auf
  `DIVING` gesetzt → `enemy-death2`, `_carrying_captive=true` → `boss-killed`,
  jeweils exakt einer der drei Sounds aktiv, nie mehr als einer).
- **Traktorstrahl-Fang-Sound** (`beam-sound`): schließt die in „Offen" Punkt 7
  vermerkte Lücke „kein eigener Schiff-gefangen-Alarm" — `enemy.gd`s
  `beam.caught`-Signal-Handler (derselbe, der `_carrying_captive` setzt und
  die Passagier-Grafik spawnt) spielt ihn jetzt mit. Per Live-Test mit
  direkt emittiertem `caught`-Signal verifiziert.
- **Zwei neue Event-Sounds ohne Vorgänger**: `level-cleared` (in
  `game.gd::_process()`, im selben Moment wie das bisher stille
  `_stage += 1` beim tatsächlichen Stage-Clear) und `bonus-stage-cleared`
  (in `_on_bonus_collected()`, genau wenn `_hud.add_bonus_icon(...)` `true`
  liefert — ersetzt dort das generische `extra` nur für DIESEN speziellen
  Pickup, ein normaler Zwischen-Pickup bleibt weiterhin am stillen `extra`
  hängen). `enemy-wave1` läuft, sobald der Einflug tatsächlich beginnt
  (`_state = ENTERING` in `_start_ready()`) — die Lesart „eine Welle von
  Gegnern kündigt sich an" als die ganze einfliegende Formation, nicht ein
  einzelner sturzfliegender Gegner (der weiterhin am stillen `dive` hängt).
  Alle drei per Live-Test verifiziert (`_process()` direkt mit geleerter
  `enemy`-Gruppe aufgerufen → `level-cleared` + `_stage` 1→2; sieben
  simulierte Bonus-Pickups → erst still, beim 7. `bonus-stage-cleared`).

**Vierzehnte Playtest-Runde (2026-09-13, direkt im Anschluss an die
dreizehnte): Menü-Musik konsolidiert + Neustart-Bug behoben, Boss-Sound
verallgemeinert, dive/stage/extra befüllt, kein Gameplay-Hintergrundmusik-Slot
mehr, Schiffs-Explosion als visuelle Komponente, Extra-Leben-Default auf 5000.**
- **Musik-Konsolidierung**: `pause-menu-music.ogg` doch nicht passend (Nutzer-
  Feedback) — komplett fallen gelassen (Datei sogar vom Nutzer selbst als
  `pause-menu-music_not used.ogg` markiert). Stattdessen EINE einzige
  `menu-music.ogg` (identisch mit der ursprünglich fürs Highscore-Board
  vorgesehenen Datei, `highscrores-music.ogg` — beide Dateien per `md5sum`
  bestätigt bytegleich) für ALLE Menü-Screens: Pause, Einstellungen, Sound,
  Standardwerte-Bestätigung, Highscores **und jetzt auch Hilfe** (Nutzerwunsch
  „darf in der Hilfe auch weiterlaufen" — vorher bewusst ausgenommen, siehe
  „Dreizehnte Playtest-Runde"). `sound_manager.gd`: Key `pause-menu-music` →
  `menu-music`, `LOOPING_KEYS` entsprechend angepasst.
- **Echter Bug behoben: Menü-Musik startete bei jedem Screen-Wechsel neu** —
  `menus.gd::hide_all()` rief bisher unbedingt `_apply_screen_music("")` auf
  (stoppte JEDE Musik), bevor `_swap()` sie für den neuen Screen wieder
  startete — auch wenn beide Screens dieselbe Musik wollten (z. B.
  Einstellungen → Sound-Unterseite, beide `menu-music`). Fix: neue
  `_active_menu_music`-Variable merkt sich, was gerade läuft;
  `_apply_screen_music(screen_name)` vergleicht nur noch den GEWÜNSCHTEN Track
  gegen den AKTUELLEN und tut bei Gleichheit gar nichts — stoppt/startet nur
  bei einem echten Wechsel (z. B. Pause → Auswertung). `hide_all()` fasst
  Musik jetzt gar nicht mehr an (reine Sichtbarkeit); die drei Stellen in
  `game.gd`, die `hide_all()` direkt aufrufen statt über `_swap()` zu gehen
  (`_resume()`, `_new_run()`, `_revive_after_win_edit()`), rufen jetzt
  zusätzlich explizit die neue `menus.stop_menu_music()` auf. Per Live-Test
  mit `AudioStreamPlayer.get_playback_position()` verifiziert: Position lief
  über Pause→Einstellungen→Sound→Standardwerte-Bestätigung→Hilfe→Highscores→
  zurück zu Pause monoton weiter (nie zurück auf ~0) — keine einzige
  Unterbrechung.
- **Echter Bug behoben: automatischer Musikwechsel am Spielende griff nicht
  zuverlässig** — der konkrete Fall: aus der Pause die Einstellungen öffnen
  (Musik: `menu-music`), „Sieg bei X Punkten" unter den aktuellen Punktestand
  senken, „Fertig" — das beendet den Lauf synchron noch INNERHALB von
  `_close_sub()` (über `settings_changed.emit() → game.gd::_reload_settings()
  → _check_win()`), der darauf folgende, bereits bestehende „nicht zurück zur
  Pause swappen"-Schutz in `_close_sub()` ließ dabei aber die Musik unangetastet
  auf `menu-music` stehen, statt auf `scoring-board-music` zu wechseln. Mit
  der neuen `_active_menu_music`-Logik löst sich das von selbst — `_swap
  ("summary")` (ausgelöst durch `show_run_summary()` mitten in diesem Ablauf)
  erkennt jetzt korrekt den Wechsel und tauscht die Musik aus. Per Live-Test
  mit exakt diesem Ablauf verifiziert (`_open_settings("pause")`, Score künstlich
  über den gesenkten `win_score` geschoben, `_close_sub()` aufgerufen →
  `scoring-board-music` läuft, `menu-music` steht, „summary" sichtbar). Die
  Rückrichtung (Sieg-Screen → eigene „Einstellungen" → Sieg-Score wieder
  anheben → „Fertig" → Lauf geht weiter) ebenfalls verifiziert: Musik danach
  komplett still (kein Gameplay-Musik-Slot mehr, siehe unten).
- **Boss-Sound gilt jetzt für JEDEN Boss-Kill**, nicht mehr nur für einen
  Rettungskill (Nutzerwunsch, war ursprünglich zu eng gefasst) —
  `enemy.gd::_explode()`s Sound-Auswahl prüft jetzt `kind == EnemyKinds.BOSS`
  statt `_carrying_captive`. Anzeigename in der Sound-Unterseite entsprechend
  von „Boss (mit Schiff) abgeschossen" zu „Boss abgeschossen" verkürzt.
- **Klarstellung zur Fanfaren-Zuordnung** (Nutzer-Rückfrage): `level-cleared`
  läuft genau in dem Moment, in dem eine Stage tatsächlich abgeräumt ist
  (`game.gd::_process()`, bevor `_stage` hochgezählt wird) — das IST die
  „Fanfare fürs Levelschaffen". `stage` (neu befüllt mit `stage.ogg`, siehe
  unten) läuft weiterhin beim Start des JEWEILS NÄCHSTEN Levels
  (`_start_ready()`s „STAGE n"-Banner) — Anzeigename entsprechend zu „Nächstes
  Level" umbenannt, um genau diese Abgrenzung sofort klar zu machen. Beide
  Zuordnungen waren schon in der dreizehnten Playtest-Runde korrekt verdrahtet,
  nur die Anzeigenamen waren missverständlich.
- **`dive.ogg`/`stage.ogg`/`extra.ogg` nachgereicht** — dieselben Keys wie
  zuvor (unverändert seit der ersten Sound-Runde), nur jetzt mit echtem Clip
  statt still. Kein Code geändert, nur die Dateien nach `assets/sounds/`
  kopiert.
- **Gameplay-Hintergrundmusik-Slot „music" komplett entfernt** (nicht nur
  stumm gelassen) — Nutzer-Feststellung: das originale NES-Galaga hat keine
  durchlaufende Musik während des Spiels, nur kurze Fanfaren/Jingles. Kurze
  Web-Recherche bestätigt das (Soundtrack-Komponist Nobuyuki Ohnogi portierte
  nur die Arcade-Jingles, keine Loop-Musik). `music`-Key aus `SOUNDS`/`ORDER`
  entfernt, alle `_snd.play("music")`/`_snd.stop("music")`-Aufrufe in
  `game.gd` (`_new_run()`, `_enter_title()`, `_check_win()`,
  `_revive_after_win_edit()`, `_on_ship_died()`) ersatzlos gestrichen — kein
  Slot mehr in der Sound-Unterseite dafür. Bleibt offen, falls der Nutzer
  online doch noch einen Hinweis auf eine tatsächliche NES-Loop-Musik findet.
- **Schiffs-Explosion als visuelle Komponente** (Nutzerwunsch: fehlte bisher
  komplett — das Schiff wurde bei einem Treffer einfach unsichtbar, ohne
  jeden visuellen Hinweis). Neue `ship_explosion.tscn`/`.gd` (gleiches Muster
  wie `ship_reconstruct.gd`: `AnimatedSprite2D`, `SpriteFrames` zur Laufzeit
  aus einzelnen PNGs gebaut, `explosion_done`-Signal, self-`queue_free()`) —
  4 Frames aus dem bereits im Projekt liegenden, bis dahin ungenutzten
  `assets/explosion and laser.png` (Bündel aus Laser- und Explosions-
  Sprites) extrahiert, per Alpha-Bounding-Box automatisiert ausgeschnitten
  und auf einen gemeinsamen 340×340-Canvas zentriert (`assets/graphics/
  ship_explosion_f0..3.png` — Funke → mittlerer Ausbruch → heller Höhepunkt →
  rauchiges Abklingen). `game.gd::_on_ship_died(show_explosion: bool)` spielt
  sie **vor** jeder Reconstruct-/Game-Over-Logik ab und wartet auf
  `explosion_done`, bevor irgendetwas anderes passiert — das Schiff kann also
  nicht reconstructen, solange die Explosion noch zu sehen ist (exakte
  Nutzervorgabe). `ship.gd::died`-Signal trägt dafür jetzt einen
  `show_explosion`-Parameter; `_destroy(show_explosion := true)` — `false`
  ausschließlich beim Boss-Traktorstrahl-Fang (neue Gruppe `"capture_beam"` auf
  `capture_beam.tscn`, zusätzlich zu dessen bestehender `"enemy_shots"`-
  Gruppe, lässt `ship.gd::_on_area_entered()` einen Fang von einem echten
  Treffer unterscheiden) — ein Fang ist keine Zerstörung, dafür gibt's schon
  den eigenen `beam-sound`. Per Live-Test verifiziert: echter Treffer (Bombe/
  Laser/Rammen) spawnt die Explosion (Screenshot mit `get_tree().paused=true`
  mitten in der Animation eingefangen), ein simulierter Boss-Fang (Area2D mit
  beiden Gruppen-Tags) spawnt sie nachweislich NICHT, obwohl das Schiff in
  beiden Fällen gleichermaßen `_alive=false` wird.
- **Extra-Leben-Standardwert 20000 → 5000** (`GameSettings.DEF.extra_life`,
  sowie `menus.gd::_reset_defaults()`s bisher abweichender Wert 10000 →
  ebenfalls 5000) — an `boss_interval`s eigenen Default (schon immer 5000)
  angeglichen, damit ein frisches Spiel für beide Mechaniken dieselbe
  Punkteschwelle verwendet, wie vom Nutzer gewünscht.

**Fünfzehnte Playtest-Runde (2026-09-14): Titel-Musik ergänzt, Pause-/
Auswertungs-Musik loopt jetzt wirklich trotz Pause, Neustart-Bestätigung vor
„Start-Menü", versehentliche Wellen-Ankündigung entfernt, Explosion mit
NEAREST-Filter, Rekonstruktion wartet auf den vollen Zerstörungs-Sound.**
- **Titel-Bildschirm bekommt jetzt auch `menu-music`**: in der Vierzehnten
  Playtest-Runde bewusst außen vor gelassen (nicht vom Nutzer verlangt) —
  jetzt explizit nachgefordert. `menus.gd::MENU_MUSIC_SCREENS` bekommt
  `"title"` dazu (`"splash"` bleibt weiterhin bewusst still). Per Live-Test
  verifiziert (`menus.show_title()` → `_active_menu_music == "menu-music"`,
  `Snd.is_playing("menu-music") == true`).
- **Echter Bug behoben: `menu-music`/`scoring-board-music` loopten nicht,
  solange ein Menü offen war** (Nutzer-Report — betraf dadurch indirekt auch
  Punkt 2, siehe unten). Ursache: `sound_manager.gd`s Loop-Mechanismus hängt
  komplett am `finished`-Signal des jeweiligen `AudioStreamPlayer` (manueller
  Re-`play()`, da ein reiner WAV/OGG-Import nicht selbst loopt) — dieses
  Signal ist an den `_process`-Zyklus des Nodes gekoppelt und feuert bei
  Godots Default-`process_mode` (`PAUSABLE`, vererbt) nicht mehr, sobald
  `get_tree().paused = true` ist. Genau das ist aber der Zustand während
  JEDES Menüs (Pause, Einstellungen, Auswertung, Game Over, …) — der Clip
  lief dadurch exakt einmal bis zum Ende durch und verstummte dann, statt zu
  loopen. Fix: `p.process_mode = Node.PROCESS_MODE_ALWAYS` für beide
  `LOOPING_KEYS`-Player in `sound_manager.gd::_ready()` — nur diese zwei
  Knoten laufen jetzt unabhängig vom Pause-Zustand weiter, sonst nichts am
  Pause-Verhalten geändert. Per Live-Test verifiziert: Wiedergabeposition
  über den Clip hinaus geseekt (`AudioStreamPlayer.seek()`), Baum bewusst
  pausiert gehalten — Position sprang zuverlässig zurück auf einen kleinen
  Wert (Loop hat gegriffen), `get_tree().paused` blieb dabei durchgehend
  `true`.
- **Game-Over-Bildschirm „ohne" `scoring-board-music`**: derselbe Bug wie
  oben, nicht ein fehlender Verdrahtungspunkt — `"gameover"` stand schon
  vorher korrekt in `SCORE_MUSIC_SCREENS`. Mit dem Loop-Fix oben automatisch
  miterledigt. Per Live-Test verifiziert (`menus.show_game_over(...)` →
  `_active_menu_music == "scoring-board-music"`,
  `Snd.is_playing("scoring-board-music") == true`).
- **„Start-Menü" aus der Pause fragt jetzt nach** (Nutzer-Selbstkorrektur:
  „Ich weiß nicht, was ich mir dabei gedacht habe. Aber ich meinte wohl eher
  sowas wie 'Neustart'.") — neuer Screen `"confirm_title"`
  (`_build_confirm_title()`, identisches Ja/Nein-Muster wie
  `_build_confirm_reset()`), Pause-Screen-Button ruft jetzt `_swap
  ("confirm_title")` statt direkt `to_title.emit()`. „Nein" geht zurück zu
  Pause (immer von dort erreichbar, kein `_return_to`-Tracking nötig), „Ja"
  verlässt wie bisher zum Titel. Per Live-Test verifiziert: Klick auf
  „Start-Menü" zeigt `confirm_title`, „Nein" zeigt wieder `pause`, ein
  zweiter Anlauf mit „Ja" bringt `game._state` tatsächlich auf `TITLE`.
- **Versehentliche `enemy-wave1`-Ankündigung beim normalen Stage-Start
  entfernt** (Selbstkorrektur des Nutzers: „Wohl mein Fehler beim
  Prompten.") — `game.gd::_start_ready()` rief bislang zusätzlich zum
  korrekten `level-cleared`/`stage`-Paar auch `_snd.play("enemy-wave1")` auf,
  und zwar bei JEDEM Levelwechsel, nicht nur bei einer echten
  Mehrfach-Wellen-Ankündigung. Der Aufruf war schlicht fehlplatziert — der
  Sound-Key selbst bleibt für sein eigentliches Vorhaben aufgehoben, siehe
  „Offen" Punkt 11 unten (Bonuslevel-Feature). Fix: Aufruf ersatzlos
  gestrichen. Statisch verifiziert (keine `enemy-wave1`-Fundstelle mehr in
  `game.gd`).
- **Explosion bekommt `TEXTURE_FILTER_NEAREST`** gegen den vom Nutzer
  gemeldeten „unschönen weißen Rand" — das Projekt hat keinen
  Default-Filter-Override, Godots Standard ist Linear, was den harten
  Alpha-Rand jedes Explosions-Frames gegen die volltransparente (schwarze,
  Alpha 0) Umgebung verwaschen kann und beim Herunterskalieren als heller
  Saum sichtbar wird — derselbe Mechanismus, der pixelgenaue Sprites
  grundsätzlich NEAREST statt Linear wollen. `ship_explosion.gd::_ready()`
  setzt jetzt explizit `texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST`,
  wie es jeder andere Sprite hier bei nativer Auflösung ohnehin implizit
  bekommt. Hinweis zur Verifikation: ausführliche Untersuchung (PIL-
  Alpha-Compositing, Rohpixel-Prüfung der transparenten Bereiche,
  In-Game-Screenshot-Zoom) konnte den exakten gemeldeten Saum auf dem
  Test-Desktop nicht reproduzieren — die Frames selbst rendern dort schon
  vorher sauber. Der Fix ist trotzdem der richtige, standardmäßige und
  risikoarme Schritt gegen genau dieses bekannte Artefakt und bleibt daher
  drin, auch ohne 1:1-Reproduktion.
- **Rekonstruktion wartet jetzt zusätzlich auf den vollen
  `ship-destroyed`-Sound**, nicht nur auf die Explosions-Animation — die
  Boom-Animation ist mit 4 Frames bei 10 fps nur ~0,4 s lang, `ship-
  destroyed.ogg` (per `ffprobe` gemessen) dagegen 2,93 s: das Schiff begann
  bislang schon nach 0,4 s mit der Rekonstruktion, während der eigentliche
  Zerstörungssound im Hintergrund noch weiterlief — hörbar unpassend, wenn
  das „neue" Schiff schon wieder da ist. `game.gd::_play_explosion(at)`
  wartet nach dem `explosion_done`-Signal jetzt zusätzlich in einer
  `while _snd.is_playing("ship-destroyed"): await get_tree().process_frame`-
  Schleife. Per Live-Test verifiziert (Zerstörung ausgelöst, Schiff
  unmittelbar danach unsichtbar/`_alive=false`; kompletter Zyklus lief ohne
  Hänger durch und das Schiff war am Ende wieder sichtbar/`_alive=true` —
  exakte Sekundenbruchteil-Messung der Wartezeit selbst war über die
  MCP-Tool-Rundreisen hinweg wegen des bekannten Hintergrund-Zeitdrifts
  zwischen getrennten Aufrufen nicht zuverlässig möglich, der Code-Pfad
  selbst ist aber eindeutig: der Loop kann nicht vor Sound-Ende verlassen
  werden).

**Sechzehnte Playtest-Runde (2026-09-14): max. ein Boss-Fang pro Stage,
Boss-Default 10000.**
- **Nutzer-Report: Boss-Fänge kamen zu oft, teils zwei Bosse mit geklauten
  Schiffen in derselben Stage → Reserve leer.** Ursache: die beiden
  Auslöser in `stage_director.gd` (Zufall 33 % alle 5–9 s + „sticky"
  Punkteschwelle, vierte Runde) hatten als einzige Bremse „kein neuer Fang,
  solange ein Boss gerade ein Schiff TRÄGT" — nach der Rettung (Boss
  abgeschossen) war der Weg in derselben Stage sofort wieder frei, und jeder
  Fang kostet ein Leben. Fix: `_capture_done_this_stage`-Flag, in
  `start_stage()` zurückgesetzt, in `_attempt_capture_dive()` als erste
  Prüfung — deckelt BEIDE Wege auf genau einen Fangversuch pro Stage. Eine
  überschrittene Punkteschwelle (`_forced_pending`) verfällt dabei nicht,
  sie wartet einfach auf die nächste Stage. Bewusst NICHT umgesetzt (nach
  Rücksprache): die alternative Idee „Boss verfolgt unerbittlich, aber mit
  sichtbarem Timer + Gegenwehr" — die würde die in der dritten/siebten Runde
  ausdrücklich gewollte Unausweichlichkeit (Homing schneller als das Schiff,
  Boss dabei unverwundbar, damit die Zwillingsjäger-Belohnung zuverlässig
  erreichbar ist) wieder kippen; falls sich der Fang nach der Deckelung
  weiterhin unfair anfühlt, als eigene Runde vorgemerkt.
- **Hinweis zur Häufigkeit**: mit dem Deckel bestimmt praktisch der
  Zufallspfad die gefühlte Rate — in einer 30–60-s-Stage wird mehrfach mit
  33 % gewürfelt, statistisch kommt also fast jede Stage ein Boss. Die
  Punkteschwelle ist damit nur noch eine Untergrenze, die selten greift.
  `CAPTURE_CHANCE` auf Nutzerwunsch vorerst bei 33 % belassen — erste
  Stellschraube, falls es immer noch zu oft ist.
- **„Boss alle X Punkte" Default 5000 → 10000** (`GameSettings.DEF`,
  `menus.gd::_reset_defaults()`) — fühlte sich sonst nicht fair an.
  `extra_life` bleibt bewusst bei 5000 (die Kopplung an den Boss-Default aus
  der vierzehnten Runde ist damit wieder aufgehoben, siehe Kommentar in
  `game_settings.gd`). Eine Stage bringt grob 2900 Punkte (20×50 + 16×80 +
  4×150, ohne Boni), 10000 ≈ alle 3–4 Stages.
- **Verifikation diesmal headless statt per `godot-mcp-pro`**: parallel lief
  die Pac-Man-Session des Nutzers mit eigenem, offenem Editor — zwei
  Editoren + ein MCP-Server hätten die Live-Befehle an den falschen Editor
  geschickt (und ein `stop_scene` hätte die fremde Session getroffen). Also
  ein Wegwerf-`SceneTree`-Skript (`Formation` + `StageDirector` + Dummy-
  `player`-Node, echter Einflug via `stage_populated`, dann
  `_attempt_capture_dive()` direkt aufgerufen): 1. Versuch → `true`, 2. →
  `false`, Zwangs-Anforderung bleibt `_forced_pending`, `start_stage(2)`
  löscht den Deckel und behält die Anforderung. Alle 9 Checks grün,
  `_selftest.gd` grün. Skript danach wieder gelöscht.

**Siebzehnte Playtest-Runde (2026-09-14): komplette UI-Übersetzung ins
Englische.** Nutzerwunsch — Galaga war das einzige Projekt mit deutscher UI
(tetris/pacman sind Englisch), die frühere „Galaga bleibt deutsch"-Ausnahme
in der globalen CLAUDE.md ist damit gestrichen: Englisch ist ab jetzt
Standard für JEDES Spiel hier. **Alle älteren Abschnitte dieser Datei zitieren
noch die deutschen Bezeichnungen** („Fertig", „Weiter", „Start-Menü", „Sieg
bei X Punkten", „BEREIT", „Standardwerte", „Eintragen", „Nochmal" …) —
das sind historische Beschreibungen, nicht der aktuelle Stand. Mapping:
- Buttons/Screens (`menus.gd`): Spielen→Play, Einstellungen→Settings,
  Highscores→High Scores, Hilfe→How to Play, Beenden→Exit, Weiter→Resume
  (Pause) bzw. Continue (Summary), Start-Menü→Main Menu, Nochmal→Play Again,
  Eintragen→Enter, Fertig→Done, Standardwerte→Defaults, Ja/Nein→Yes/No,
  „Neu starten?"→„Restart?", „Zurücksetzen?"→„Reset?", SIEG!→YOU WIN!.
- Stepper: Leben→Lives, Extra-Leben→Extra life, Boss alle X Punkte→Boss every
  X points, Sieg bei X Punkten→Win at X points, Max. Schüsse→Max. shots,
  Schwierigkeit→Difficulty; `GameSettings.DIFF_NAMES` Leicht/Normal/Schwer→
  Easy/Normal/Hard; Textfeld-Wert „aus"→„off" (die Eingabe akzeptiert
  weiterhin auch „aus", damit Gewohnheit nicht zum Fehler wird).
- Summary/Game Over: Gerettete Schiffe→Rescued ships, Gesamtpunktzahl→Total
  score, Runden→laps, „Neuer Highscore — Platz N!"→„New high score — rank
  N!", „N Pkt."→„N pts", Leerzustände („keine Gegner abgeschossen", „noch
  keine Einträge") ebenfalls.
- HUD: „BEREIT"→„READY" (`game.gd`); „STAGE n"/„LAP!"/„Laps n" waren schon
  Englisch.
- Sound-Unterseite: alle 15 Anzeigenamen in `sound_manager.gd::SOUNDS`
  (Menü-Musik→Menu music, Schuss→Shot, Traktorstrahl-Fang→Tractor beam
  capture, …). Keys/Dateinamen unverändert, `CALIB_VERSION` unverändert
  (nur Anzeige, keine Bedeutungsänderung).
- Hilfe: Seitentitel in `HELP_PAGES_DESKTOP/_TOUCH` (Steuerung — Tastatur→
  Controls — Keyboard usw.) UND der eingebackene Text in allen 7
  `assets/help_src/*.svg` (per Skript ersetzt, neu gerendert, alle 7 PNGs
  einzeln gegengeprüft — einzige nötige Layoutkorrektur: in `bonus.svg`
  den rechten Pfeil etwas höher gesetzt, die Spitze berührte sonst das
  längere englische „collect").
- Nicht angefasst: Code-Kommentare, die alte deutsche Labels zitieren (rein
  erklärend), Persistenz-Keys, Signalnamen. Doku/Commits bleiben Deutsch.
- Verifikation headless (`_selftest.gd` grün, Parse-Check aller Skripte) +
  Sichtprüfung der 7 gerenderten Hilfe-PNGs; kein Live-MCP-Test, da parallel
  die Pac-Man-Session einen Editor offen hatte (siehe sechzehnte Runde).

**Achtzehnte Playtest-Runde (2026-09-14): Hyper-Ammo feuert wieder in
voller Kadenz + breiter, Jingle-Abstände beim Stage-Wechsel.** (Nutzer-
Auftrag unter Zeitdruck — „das Limit schlägt gleich zu" — daher Punkte 1+2
sofort, Bonuslevel danach, Lautstärke-Defaults nur vorgemerkt, siehe
„Offen" 12.)
- **Hyper-Ammo schoss nur einmal statt mit der eingestellten Kadenz** (Nutzer-
  Report: „sogar ein Nachteil"). Ursache: `ship.gd::shoot()` deckelte die
  Laser IN DER LUFT gegen `_max_lasers` (= „Max. Schüsse") — ein
  Hyper-Salvo sind aber zwei Laser, bei Default 2 füllte also EIN Schuss
  den Deckel, die halbe Feuerrate. Fix: der Deckel zählt Salven, nicht
  Strahlen (`cap = _max_lasers * (2 if _hyper_ammo else 1)`; Zwilling
  verdoppelt `_max_lasers` ohnehin schon selbst). Außerdem `HYPER_OFFSET`
  10 → 14 px: Abdeckung pro Salve ~23 px statt ~19 px (Hitbox 9 px je
  Strahl) — auf Nachfrage geprüft, ob die Doppelbreite wirklich spürbar mehr
  Trefferchance bringt als der 9-px-Einzelstrahl.
- **Stage-Wechsel-Jingles überlappten**: `level-cleared` (1,4 s) und der
  `stage`-Jingle (2,6 s) starteten im selben Frame, der Einflug begann,
  während der Jingle noch lief. Neu in `game.gd::_start_ready()`:
  level-cleared ausklingen lassen → `STAGE_JINGLE_GAP` (0,5 s) → Banner +
  `stage` → Banner-Zeit → Jingle ausklingen lassen → Gap → Einflug
  (`_wait_sound_then_gap()`, bricht sauber ab, wenn der Run READY verlässt).
  **Stage 1** eines neuen Spiels: die 6,9-s-Intro-Musik IST dort die
  Fanfare — der `stage`-Jingle bleibt stumm statt darüber zu spielen, der
  Einflug wartet wie bisher auf das Intro-Ende (oder den Klick/Tap-Skip),
  plus dieselbe Gap. Beides nur per `_selftest.gd` (Parse) geprüft — kein
  Live-Test möglich (Pac-Man-Session hält den Editor/MCP), beim nächsten
  Playtest bitte gegenhören.

**Neunzehnte Playtest-Runde (2026-09-14): Bonuslevel mit drei Gegner-Wellen.**
Nutzervorschlag aus der vorigen Runde, noch am selben Tag freigegeben
(„auch gleich ans Werk machen"). Neue Dateien `bonus_enemy.gd`/`.tscn`
(ein Gegner in einer Welle) und `ship_warp.gd`/`.tscn` (Übergangs-Animation),
Rest lebt direkt in `game.gd`.
- **Auslöser**: neue Einstellung „Bonus level every X stages"
  (`GameSettings.bonus_level_interval`, Default 3, 0 = aus,
  `BONUS_LEVEL_INTERVAL_MAX` = 10, Stepper zwischen „Difficulty" und dem
  Sound-Button in `menus.gd`, auch im „Standardwerte"-Reset). Geprüft in
  `game.gd::_start_ready()`, direkt nach dem `level-cleared`-Ausklingen: ist
  `_stage % interval == 0`, läuft statt der normalen Formation/Fly-in ein
  Bonuslevel — banner „BONUS LEVEL" (gleicher `flash_banner()`-Mechanismus
  wie „STAGE n"/„READY"/„LAP!"), dann derselbe Jingle+Gap-Ablauf wie bei
  einer normalen Stage (Punkt „Achtzehnte Playtest-Runde" oben), dann
  `_state = BONUS` (neuer State neben TITLE/READY/ENTERING/FORMATION/
  GAME_OVER) statt `ENTERING`.
- **Drei Wellen, drei unterschiedliche Bahnen** (`_start_bonus_level()`):
  Zako von links-oben nach rechts-unten, Goei von rechts-oben nach
  links-unten, Boss senkrecht durch die Mitte — Sprite, Start- UND Endpunkt
  wechseln also bei jeder Welle komplett, wie vom Nutzer verlangt. Jede
  Welle: `BONUS_ENEMIES_PER_WAVE` (6) `bonus_enemy`-Instanzen auf
  PARALLELEN Geraden (Start- UND Endpunkt beide um `i * BONUS_CHAIN_GAP`
  (70 px) nach oben verschoben) — das ergibt eine Kette, die als starrer
  Block „übereinander aufgereiht" startet und gemeinsam zum Zielpunkt
  wandert, ohne Zeitversatz-Tricks. `enemy-wave1.ogg` spielt pro Welle neu
  (das war der ursprüngliche, für den normalen Stage-Start versehentlich
  verdrahtete Zweck, siehe „Vierzehnte"/„Fünfzehnte Playtest-Runde" — jetzt
  endlich am richtigen Ort). Nächste Welle startet erst, wenn alle 6 Gegner
  der vorigen `resolved` haben (getroffen oder am Bahnende angekommen), plus
  `BONUS_WAVE_PAUSE` (1,2 s) Luft dazwischen.
- **Design-Entscheidungen, die die alten „noch zu klären"-Fragen beantworten**
  (bewusst getroffen statt weiter offen gelassen, passend zum
  Arcade-Vorbild „Challenging Stage"):
  - **Kein Gegnerfeuer, keine Sturzflüge, kein Lebensrisiko.**
    `bonus_enemy.gd` ist absichtlich NICHT in der Gruppe `"enemy"` —
    `ship.gd::_on_area_entered()` reagiert nur auf genau diese Gruppe für
    Rammschaden, ein Bonuslevel kann also grundsätzlich kein Leben kosten.
    Die Ketten fliegen einfach geradeaus durch und lösen sich am Bahnende
    auf, egal ob getroffen oder nicht.
  - **Punkte**: jeder Treffer gibt `EnemyKinds.DATA[kind]["points"]` (dieselben
    50/80/150 wie in der normalen Formation), Hyper-Ammo verdoppelt auch
    hier. Kein separates Punkteschema — bewusst konsistent mit dem Rest des
    Spiels statt einer neuen Zahl, die erst noch kalibriert werden müsste.
  - **Konsequenz eines nicht perfekten Durchlaufs**: keine. Ein verpasster
    Gegner verschwindet einfach am Bahnende, es gibt weder Strafe noch
    Zeitdruck. Nach allen 3 Wellen zeigt der Banner „PERFECT!" (alle 18
    getroffen, spielt `bonus-stage-cleared`) oder „BONUS: N/18" (spielt
    `level-cleared`) — reiner Bonus-Charakter, kein Muss.
  - Gegner-Sprites: aus dem bestehenden Zako/Goei/Boss-Pool (`EnemyKinds`,
    `pick_visual(kind, _stage)` inkl. der ab Stage 2 üblichen Gyaraga-
    Varianten) — keine eigene Bonuslevel-exklusive Optik, um nicht noch mehr
    unverifizierte neue Assets ins Spiel zu bringen.
- **Übergang zur nächsten normalen Stage**: `ship-warp-drive.gif` (19 Frames,
  100×100, bis dahin ungenutzt) → `ship_warp.gd`/`.tscn`, exakt nach dem
  Muster von `ship_reconstruct.gd`/`ship_explosion.gd` (SpriteFrames zur
  Laufzeit gebaut, `warp_done`-Signal, self-`queue_free()`). Frames per
  `PIL`/Farbschlüssel (`max(R,G,B) > 8`) freigestellt (dieselbe Technik wie
  beim Reconstruct-Gif) nach `assets/graphics/warp_f00..18.png`. Läuft in
  `_finish_bonus_level()` an der Schiffsposition, danach `_stage += 1` und
  ganz normal `_start_ready()` — die nächste Stage ist wieder eine normale
  Formation (außer der neue Interval-Wert trifft direkt wieder). **Nicht
  live geprüft**: `ship_warp.gd::DISPLAY_SCALE = 1.2` ist eine Schätzung
  ohne Bildvergleich gegen die echte Schiffsgröße (kein Editor/MCP-Zugriff
  diese Runde) — beim nächsten Playtest gegenchecken.
- **Aufräumen beim Abbruch**: `game.gd::_clear_board()` (läuft u. a. beim
  Wechsel zum Titelbildschirm) räumt jetzt zusätzlich die neue Gruppe
  `"bonus_transient"` leer (geteilt von `bonus_enemy.gd` UND `ship_warp.gd`)
  — sonst blieben mitten in einem Bonuslevel gespawnte Ketten oder eine
  laufende Warp-Animation beim Verlassen zum Start-Menü als Waisen im
  Baum stehen.
- **Verifikation**: kein Live-Test möglich (Pac-Man-Session hält Editor/MCP
  diese Runde), aber ein waschechter funktionaler Headless-Test statt nur
  Parse-Check — ein Wegwerf-`SceneTree`-Skript hat `game.tscn` komplett
  instanziiert (echte Autoloads, echter `Ship`/`HUD`/`Menus`), den
  Auslöse-Bedingungscheck geprüft (Stage 3 bei Intervall 3 löst aus, Stage 4
  nicht), `_start_bonus_level()` direkt aufgerufen, die 6 Ketten-Gegner der
  ersten Welle gezählt und ihren Abstand vermessen (exakt 70 px, wie
  `BONUS_CHAIN_GAP`), alle 6 „erschossen" und Punktegutschrift + Zähler
  geprüft (0→300 für 6× Zako-Kill), dann `_enter_title()` mitten in der
  Welle aufgerufen und bestätigt, dass keine Knoten übrig bleiben. Alle 8
  Prüfungen grün. Dabei außerdem geklärt, warum ein früherer Testversuch mit
  reinem Frame-Zählen (`await process_frame` in einer Schleife) hängen
  blieb: in einem headless `SceneTree`-Skript laufen Frames ungebremst
  extrem schnell durch, Sekunden an simulierter Wartezeit (Banner-/
  Jingle-Timer) brauchen also viel mehr als ein paar hundert Iterationen —
  kein Bug im Spiel selbst, per separatem Audio-Timing-Test bestätigt
  (`create_timer()`/`is_playing()` verhalten sich headless korrekt, echte
  Millisekunden vergehen wie erwartet). Bestätigt nebenbei, dass auch die
  „Achtzehnte Playtest-Runde"s Jingle-Gap-Logik strukturell in Ordnung ist.
  **Trotzdem: gleich beim ersten echten Spieltest stellte sich heraus, dass
  das Bonuslevel so nicht funktionierte — siehe „Zwanzigste Playtest-Runde"
  unten. Der eigene Headless-Test hatte den eigentlichen Bug nicht gefangen,
  weil er `resolved` selbst per `e._explode()` auslöste (der Signal-Pfad, in
  dem der Zähler kaputt war, wurde also nie unter realen Bedingungen
  durchlaufen) — eine Lehre für künftige Tests dieser Art: das Verhalten
  eines Signal-Handlers isoliert nachzustellen beweist nicht, dass der
  Signal-Pfad selbst funktioniert.**

**Zwanzigste Playtest-Runde (2026-09-14): Bonuslevel komplett redesignt —
echter Hänger-Bug behoben, Bewegung jetzt vertikale Spalte statt
Seitwärts-Formation, kein Boss mehr.** Nutzer-Report nach dem ersten
tatsächlichen Spieltest der Neunzehnten Runde: „1. Die Spielelogik bekommt
nicht mit, wenn eine Formation komplett abgeräumt wurde. 2. Die Formation
soll sich nicht als Ganzes seitwärts bewegen, sondern von oben eingeflogen
kommen und eine quasi senkrechte Linie bilden, die man dann von einem Punkt
aus abschießen kann. 3. Und das dann nacheinander insgesamt 3 Mal von
unterschiedlichen Stellen aus und mit unterschiedlichen Gegnern (keine
Bosse)."
- **Echter Bug gefunden (Punkt 1)**: `game.gd::_run_bonus_wave()` zählte die
  verbleibenden Gegner einer Welle über `var pending := 6` herunter, verändert
  aus einer PRO-GEGNER an `resolved` angehängten Lambda-Closure
  (`e.resolved.connect(func(): pending -= 1)`). Das funktioniert in GDScript
  grundsätzlich nicht: Closures fangen wertartige lokale Variablen (`int`,
  `bool`, `float`, …) BEI ERSTELLUNG als eigene Kopie ein — `pending -= 1`
  innerhalb der Lambda hat nur die private Kopie der Lambda verändert, nie
  die äußere `pending`-Variable, die die `while pending > 0`-Schleife
  tatsächlich abfragte. `pending` blieb also für immer bei 6 stehen, die
  Schleife (und damit das ganze Bonuslevel) hing nach dem letzten Kill für
  immer fest — exakt der gemeldete „Spielelogik merkt nichts"-Bug. Fix:
  komplett andere Technik, kein Zähler mehr nötig — jeder `bonus_enemy` tritt
  jetzt zusätzlich zu `"bonus_transient"` der Gruppe `"bonus_wave_active"`
  bei (`bonus_enemy.gd::_ready()`); da sich jeder Gegner beim Tod ODER am
  Bahnende ohnehin selbst per `queue_free()` entfernt (und damit automatisch
  aus jeder Gruppe fällt), reicht `while not get_tree().get_nodes_in_group
  ("bonus_wave_active").is_empty(): await get_tree().process_frame` als
  „Welle fertig"-Check — kein Signal, kein Zähler, keine Closure-Falle mehr
  möglich. Das dabei entfernte `resolved`-Signal/`_finish()`/
  `tree_exiting`-Verdrahtung in `bonus_enemy.gd` war nur noch für den alten,
  kaputten Zähler da und ist komplett raus.
- **Bewegung komplett redesignt (Punkte 2+3)**: statt zwei parallelen
  Diagonal-„Ketten", die als starrer Block quer über den Bildschirm fahren
  (altes Design der Neunzehnten Runde), fliegt jetzt jede der 3 Wellen als
  KETTE VON 6 GEGNERN NACHEINANDER auf EINER einzigen, schnurgeraden
  senkrechten Spur von oben (knapp über dem Bildschirm) nach unten (knapp
  unter dem Bildschirm) — `game.gd::_run_bonus_wave(kind, column_x)` baut
  dafür nur noch eine simple 2-Punkte-`Curve2D` (`(column_x, -60)` →
  `(column_x, vp.y+60)`, exakt senkrecht). Die „Kette" entsteht nicht mehr
  durch geometrischen Versatz (Start/Endpunkt um `BONUS_CHAIN_GAP`
  verschieben, wie in der Neunzehnten Runde), sondern durch zeitversetztes
  LAUNCHEN: alle 6 Gegner benutzen dieselbe Spur, werden aber im Abstand von
  `BONUS_LAUNCH_GAP` (0,27 s, ~70 px Sichtabstand bei den 260 px/s
  Reisegeschwindigkeit aus `bonus_enemy.gd`) nacheinander erzeugt — der
  erste ist beim Start des zweiten schon ein Stück die Spur entlang
  gewandert, genau wie eine Schlange, die nacheinander an einer Stelle
  vorbeikommt (dieselbe Technik, mit der auch `stage_director.gd`s
  normaler Formations-Einflug seine Gruppen staffelt). Der Spieler muss sich
  während einer Welle also gar nicht bewegen — einmal unter `column_x`
  postieren und durchgehend feuern reicht, exakt der Nutzer-Wunsch „von
  einem Punkt aus abschießen". **Kein Boss mehr**: `EnemyKinds` hat nur zwei
  Nicht-Boss-Sorten (ZAKO/GOEI), die 3 Wellen wechseln sich also bewusst
  ZAKO→GOEI→ZAKO ab (kein Kind zweimal hintereinander) — dokumentierte
  Design-Entscheidung, kein Versehen: „unterschiedliche Gegner" mit nur 2
  verfügbaren Nicht-Boss-Sorten kann nicht 3 komplett unterschiedliche Typen
  bedeuten, ohne einen doppelt zu belegen. Die 3 Spalten liegen bei 25 %/
  75 %/50 % der Bildschirmbreite ("von unterschiedlichen Stellen aus").
- **Verifikation**: Editor weiterhin nicht verfügbar (kein `ps aux`-Treffer,
  aber auch keine Rückmeldung, dass die Pac-Man-Session den Editor
  freigegeben hätte — sicherheitshalber weiter headless getestet). Zwei
  Wegwerf-`SceneTree`-Skripte gegen das echte `game.tscn`: eines ließ eine
  einzelne Welle OHNE jeden Eingriff komplett natürlich auslaufen (alle 6
  Gegner laufen die Spur bis ans Ende durch und geben sich per `queue_free()`
  frei) — lief in ca. 6,7 echten Sekunden sauber durch und bestätigte damit
  direkt, dass der Hänger behoben ist. Das zweite (ausführlichere) prüfte
  zusätzlich per `SceneTree.node_added`-Hook (auf das Skript-Attachment
  gefiltert, da die Gruppenzugehörigkeit zum Zeitpunkt von `node_added` noch
  nicht gesetzt ist) alle 6 Positionen einer Welle (alle exakt auf derselben
  Spalten-x), dann den kompletten Ablauf aller 3 Wellen (18 Gegner
  gesamt, 3 unterschiedliche Spalten, kein einziger Boss, mindestens 2
  unterschiedliche Gegnerarten, `_bonus_hits == 18` am Ende). Alle 8 Checks
  grün. **Stolperfalle beim Testen selbst** (zweimal, beide selbst
  gefunden und behoben, kein Bug im Spiel): (1) `game.gd::_ready()` lässt
  den `SceneTree` für den Splash-Screen pausiert (`get_tree().paused = true`)
  und verbindet `_menus.splash_done` einmalig mit `_enter_title()` — da diese
  neue Testreihe durch die vielen echten Warte-Timer (Launch-Gaps) mehrere
  echte Sekunden braucht, konnte der echte 3-Sekunden-Splash-Timer
  zwischenzeitlich auslösen und mitten im Test `_enter_title()` (räumt das
  Spielfeld komplett leer) auslösen — im Test vorher explizit
  `splash_done.disconnect(_enter_title)`. (2) Direkt danach hing ein Test
  komplett fest, weil der `SceneTree` durch denselben Splash-Setup-Schritt
  weiterhin `paused = true` war und nie (wie es `_new_run()` im echten Spiel
  immer tut) auf `false` gesetzt wurde — `bonus_enemy.gd` läuft mit
  `PROCESS_MODE_PAUSABLE`, seine `_physics_process()` (und damit jede
  Bewegung) lief bei pausiertem Baum also nie, die Welle konnte nie enden.
  Fix im Test: `paused = false` direkt nach dem Splash-Disconnect setzen —
  genau das, was `_new_run()` im echten Spielablauf ohnehin schon tut.

**Einundzwanzigste Playtest-Runde (2026-09-14): Pause pausiert jetzt wirklich
alles, Bonuslevel-Doppelzählung + Warp-Animation behoben, Bonuslevel-Tempo
variiert, Boss-Fang während Schiffsverlust unterbunden, Gegner-Aktivität
pausiert während Explosion/Wiederaufbau.** Sechs Punkte aus einem Nutzer-Test
direkt nach der Zwanzigsten Runde.
- **1. Echter Pause-Bug gefunden**: `get_tree().create_timer()` läuft laut
  Godot-Doku standardmäßig mit `process_always=true` weiter — **auch wenn der
  Baum pausiert ist**. Praktisch jeder Spielablauf-Timer in `game.gd`
  (Banner-Wartezeiten, Jingle-Gaps, Bonuslevel-Launch-/Wellen-Pausen,
  Game-Over-Delay), in `enemy.gd` (Einflug-Staffelung, Traktorstrahl-Dauer)
  und in `stage_director.gd` (Einflug-Gruppen-Abstand) benutzte das bisher
  ungeprüft — die eigentliche Spielobjekt-Bewegung fror zwar korrekt ein
  (`PROCESS_MODE_PAUSABLE`), aber die STEUERLOGIK drumherum (wann die nächste
  Welle startet, wann der Traktorstrahl loslässt, wann die nächste
  Einflug-Gruppe kommt) lief im Hintergrund einfach weiter — bei Pause direkt
  zu Beginn eines Bonuslevels am auffälligsten (neue Gegner erschienen
  während der Pause), aber laut Nutzer „auch schon bei anderen Leveln"
  aufgefallen. Fix: alle zehn `await get_tree().create_timer(...)`-Aufrufe in
  `game.gd`/`enemy.gd`/`stage_director.gd` (außerhalb des `godot_mcp`-Addons)
  bekommen jetzt explizit `process_always=false`
  (`create_timer(X, false).timeout`) — genau das macht sie pause-abhängig.
  Verifiziert per Headless-Test: ein 0,3-s-Timer mit `false` feuert
  nachweislich NICHT innerhalb von 0,9 echten Sekunden bei pausiertem Baum,
  feuert aber zuverlässig kurz nach dem Entpausieren.
- **2. „23/18"-Anzeige am Bonuslevel-Ende**: `bonus_enemy.gd::_explode()`
  hatte (anders als `enemy.gd::_explode()`, das extra `if _state == LOCKING:
  return` dafür hat) **keine** Sperre gegen einen zweiten Treffer im selben
  Frame — trifft z. B. Hyper-Ammos Doppelstrahl (nur 14 px auseinander)
  denselben Gegner gleichzeitig, feuerte `_on_area_entered()` zweimal,
  `killed` wurde zweimal (manchmal öfter) emittiert, `_bonus_hits` zählte über
  die tatsächliche Gegnerzahl hinaus — obwohl wirklich alle 18 abgeschossen
  wurden (Nutzer: „ohne Ausnahme"). Fix: neue `_dead`-Sperre am Anfang von
  `_explode()`, exakt nach demselben Muster wie in `enemy.gd`. **Zusätzlich**
  (Nutzerwunsch, unabhängig vom Bugfix): die Abschluss-Anzeige zeigt jetzt
  die tatsächlich erzielte Punktzahl („PERFECT! +1080" / „BONUS: +720") statt
  eines N/M-Verhältnisses — weniger verwirrend und aussagekräftiger. Neues
  `_bonus_points`-Feld in `game.gd`, einmal pro Bonuslevel zurückgesetzt.
  Per Headless-Test verifiziert: `_explode()` dreimal hintereinander
  aufgerufen (simuliert einen Mehrfachtreffer) → `killed` genau einmal
  emittiert; ein kompletter Level-Durchlauf zeigte „PERFECT! +1080" statt
  eines Verhältnisses.
- **3. Bonuslevel-Tempo variiert jetzt für etwas Herausforderung**: bisher
  flogen alle 18 Gegner mit exakt derselben, konstanten Geschwindigkeit
  (260 px/s) — fühlte sich zu gleichförmig/vorhersagbar an (Nutzerwunsch:
  „etwas Challenge"). `bonus_enemy.gd::setup()` nimmt jetzt einen optionalen
  `p_speed`-Parameter (Default bleibt 260, falls von woanders ohne
  Geschwindigkeitsangabe aufgerufen). `game.gd::BONUS_WAVE_SPEEDS = [230, 290,
  350]` lässt die drei Wellen nacheinander schneller werden, zusätzlich
  bekommt jedes einzelne Kettenmitglied per `BONUS_SPEED_JITTER = 0.18` eine
  zufällige ±18-%-Abweichung vom Wellentempo — die Kette läuft dadurch nicht
  mehr wie ein perfekt gleichmäßiges Förderband. Per Headless-Test
  verifiziert: `setup()` mit einer expliziten Geschwindigkeit übernimmt und
  speichert sie korrekt in `speed`.
- **4. Warp-Animation komplett entfernt** (Nutzerwunsch: „sieht für ein
  Doppelschiff nicht gut aus, und eigentlich auch nicht für ein einzelnes
  Schiff... Kommando zurück"): `ship_warp.gd`/`.tscn` und die 19 extrahierten
  `assets/graphics/warp_f00..18.png` (+ `.import`) sind komplett gelöscht
  (unbenutzter Code/Assets, siehe Projekt-Regel „wenn sicher ungenutzt,
  komplett löschen" — nicht nur auskommentiert). Das Ausgangs-GIF
  `ship-warp-drive.gif` bleibt unangetastet liegen (Nutzer-Rohmaterial, kein
  von mir generiertes Zwischenprodukt). `game.gd::_finish_bonus_level()`
  zeigt jetzt nur noch das Banner, wartet `Hud.BANNER_TOTAL`, blendet es aus
  und geht direkt in `_start_ready()` der nächsten Stage — das Schiff war ja
  die ganze Zeit sichtbar auf dem Schirm, es gibt nichts zu „materialisieren".
  `_selftest.gd`s Skript-Parse-Liste um `ship_warp.gd` bereinigt. Per
  Headless-Test verifiziert: `ResourceLoader.exists(...)` bestätigt, dass
  weder `ship_warp.gd`/`.tscn` noch `warp_f00.png` noch existieren.
- **5. Boss-Fang während Schiffsverlust unterbunden** (Nutzer: „da scheint
  noch eine Bedingung nicht abgefangen zu sein" — korrekt, gab es nicht):
  `stage_director.gd::_attempt_capture_dive()` prüfte bisher nur
  „schon ein Fang pro Stage passiert" und „trägt schon ein Boss ein
  Schiff", nie aber, ob überhaupt ein lebendiges Schiff da ist. Fix: neue
  Prüfung `get_tree().get_first_node_in_group("player")`/`player._alive` ganz
  am Anfang der Funktion — kein neuer Fangversuch, solange das Schiff gerade
  explodiert/wiederaufgebaut wird. Zusätzlich, als zweite Absicherung gegen
  den selteneren Fall, dass ein Schiff durch etwas ANDERES (Bombe, Rammen)
  stirbt, während ein Traktorstrahl schon unterwegs ist:
  `capture_beam.gd::_on_area_entered()` prüft jetzt zusätzlich `area._alive`,
  bevor es einen Fang zählt. Per Headless-Test verifiziert:
  `_attempt_capture_dive()` liefert `false`, sobald `ship._alive = false`
  gesetzt ist, unabhängig von allen anderen Bedingungen.
- **6. Gegner-Aktivität pausiert jetzt während Explosion + Wiederaufbau**
  (Nutzer: „sollten die Sounds und Aktionen von Gegnern auf dem Screen auch
  aufhören... führt sonst zu Verwirrung"): `game.gd::_on_ship_died()` rief
  `_director.stop_attacks()` bisher nur im Game-Over-Zweig auf — im normalen
  „noch Leben übrig, respawnen"-Zweig lief die Sturzflug-/Bomben-/
  Fangversuch-Lotterie des `StageDirector` einfach unbeeindruckt weiter,
  während der Spieler mangels Schiff weder ausweichen noch zurückschießen
  konnte. Fix: `_director.stop_attacks()` läuft jetzt ganz am Anfang der
  Funktion, für BEIDE Zweige (Game-Over und Respawn). Neue
  `stage_director.gd::resume_attacks()` (Gegenstück zu `stop_attacks()`) setzt
  nur `_attacks_on = true` zurück, OHNE wie `begin_attacks()` die Countdowns
  auf einen frischen „erster Sturzflug"-Wert zurückzusetzen — der Spieler hat
  gerade ein Schiff verloren, das reicht als Strafe, die Kadenz soll da
  weitermachen, wo sie stand, nicht neu anfangen. Aufgerufen in `game.gd`
  direkt nach einem erfolgreichen `_ship.respawn()`. Bewusst NICHT umgesetzt:
  ein vollständiges Einfrieren bereits laufender Sturzflüge/Bomben/Strahlen
  während der Explosions-/Wiederaufbau-Animation selbst — ein Versuch,
  dafür `get_tree().paused` zu missbrauchen, hätte sofort mit Punkt 1 dieser
  Runde kollidiert (`ship_reconstruct.gd`/`ship_explosion.gd` laufen ebenfalls
  `PROCESS_MODE_PAUSABLE` — ein pausierter Baum hätte auch DIESE Animationen
  eingefroren und `_on_ship_died()` dauerhaft zum Hängen gebracht, da es auf
  genau deren Fertig-Signale wartet). Stattdessen bewusst auf „keine NEUEN
  Aktionen mehr" beschränkt — bereits im Sturzflug befindliche Gegner
  fliegen ihre Bewegung zu Ende (können dem jetzt unsichtbaren/inaktiven
  Schiff aber ohnehin nichts anhaben, `ship.gd`s Kollisions-Handler ignoriert
  Treffer sowieso, solange `_alive == false`). Per Headless-Test verifiziert:
  `resume_attacks()` setzt `_attacks_on` auf `true`, lässt einen manuell
  gesetzten Countdown-Wert aber unangetastet (anders als `begin_attacks()`).
- **Verifikation insgesamt**: weiterhin kein Live-MCP-Zugriff möglich (Editor
  nicht offen, aber auch keine Bestätigung, dass die parallele Session ihn
  freigegeben hätte — sicherheitshalber weiter headless). Zwei
  Wegwerf-`SceneTree`-Skripte gegen das echte `game.tscn`: eines deckte alle
  sechs Punkte einzeln ab (Pause-Timer-Verhalten, Mehrfachtreffer-Sperre,
  einstellbare Geschwindigkeit, Datei-Löschungen, Boss-Fang-Sperre,
  `stop_attacks()`/`resume_attacks()`), alle 10 Prüfungen grün; das zweite
  fuhr einen kompletten Bonuslevel-Durchlauf Ende-zu-Ende (alle 18 Gegner
  automatisch beim Erscheinen abgeschossen) und bestätigte die neue
  Punkte-Anzeige im Banner-Text direkt. Beide Skripte danach gelöscht.

**Zweiundzwanzigste Playtest-Runde (2026-09-14): Boss-Fang-Regression aus der
Einundzwanzigsten Runde korrigiert — Schiff jetzt während des gesamten
Fangvorgangs unzerstörbar statt eines `_alive`-Checks im Strahl.** Nutzer-
Report direkt nach dem letzten Fix: „Werde ich durch den Boss gefangen und
sterbe nicht durch etwas anderes, bricht der Boss den Fangvorgang trotzdem ab
und ich kann niemals ein Doppelschiff bekommen."
- **Ursache der Regression**: die vorige Runde hatte
  `capture_beam.gd::_on_area_entered()` um `and area._alive` erweitert, als
  zweite Absicherung gegen den (echten) Randfall „Schiff stirbt durch etwas
  anderes, während der Strahl schon unterwegs ist". Das Problem dabei: der
  eigentliche Fang UND `ship.gd`s eigene Zerstörung reagieren auf **dasselbe**
  physische Kollisionsereignis (Strahl berührt Schiff) — `ship.gd::
  _on_area_entered()` setzt `_alive = false`, GENAU DASSELBE Ereignis lässt
  auch `capture_beam.gd::_on_area_entered()` feuern. Welcher der beiden
  Handler zuerst dran ist, ist nicht sinnvoll vorhersagbar/kontrollierbar —
  in der Praxis lief es offenbar so, dass `_alive` beim Prüfen im Strahl
  schon `false` war, wodurch praktisch JEDER echte Fang (nicht nur der
  seltene Race-Fall) als „Schiff war eh schon tot" fehlinterpretiert und
  verworfen wurde. Der `area._alive`-Check in `capture_beam.gd` ist deshalb
  komplett zurückgenommen (Datei wieder auf den Stand vor der
  Einundzwanzigsten Runde).
- **Nutzervorschlag umgesetzt statt eines erneuten Nach-der-Tat-Checks**:
  „Sobald der Boss-Fangvorgang eingeleitet ist, darf und kann das Schiff
  nicht durch etwas anderes zerstört werden." Neues `ship.gd::
  set_capture_invulnerable(bool)` + Feld `_capture_invuln` — von `enemy.gd`
  gesetzt für die GESAMTE Dauer eines Fangversuchs: `true` gleich zu Beginn
  von `capture_dive()` (Zustand CAPTURE_APPROACH), `false` erst nachdem der
  Strahl seine volle `CAPTURE_BEAM_TOTAL`-Zeit durchlaufen hat, unmittelbar
  bevor `_begin_return()` läuft. Während dieses Fensters ignoriert
  `ship.gd::_on_area_entered()` jeden Treffer AUSSER dem des Strahls selbst
  (`area.is_in_group("capture_beam")`) — der Strahl-Kontakt muss weiterhin
  ganz normal durchgehen (`_destroy(false)`, versteckt das Schiff, löst die
  Rettungs-/Twin-Belohnungskette aus), nur Bomben/Rammstöße/anderweitige
  Treffer werden in diesem Fenster wirkungslos. Damit löst sich der
  eigentliche Race auf, ohne die Reihenfolge zweier unabhängiger
  Signal-Handler beweisen zu müssen: es gibt schlicht nichts anderes mehr,
  das dem Schiff in diesem Fenster etwas anhaben könnte. Visuell wie
  gewünscht: dasselbe Blinken wie beim kurzen Unverwundbarkeits-Fenster nach
  einem Respawn (`_invuln`), nur über eine laufende Uhr statt einen
  Countdown gesteuert, da die Fangdauer variabel ist (Anflugzeit + feste
  Strahl-Dauer). `respawn()` setzt `_capture_invuln` sicherheitshalber immer
  mit zurück, falls ein Boss durch einen Stage-Abbruch mitten im Fang
  verschwindet, bevor er selbst aufräumen konnte.
- **Verifikation**: zwei Wegwerf-Headless-Tests. Der erste testete die
  Einzelteile direkt (ein simulierter Bomben-Treffer während
  `_capture_invuln` wird ignoriert; ein simulierter Strahl-Treffer geht
  trotz `_capture_invuln` durch und versteckt das Schiff korrekt mit
  `show_explosion=false`; `respawn()` setzt die Sperre zurück; ein echter
  `capture_dive()`-Aufruf setzt sie, `_begin_capture_beam()`s echter Timer
  hebt sie nach Ablauf wieder auf) — 8/8 grün. Der zweite lief den
  KOMPLETTEN Fang über echte Area2D-Physik (nicht nur direkte
  Methodenaufrufe) — echter `capture_dive()`, echtes Homing, echter
  Strahl-Kontakt — und bestätigte: `caught`-Signal feuert, der Boss trägt
  danach eine Gefangene, das Schiff ist korrekt deaktiviert. Genau der Pfad,
  den die vorige Runde kaputt gemacht hatte, funktioniert jetzt wieder end
  to end.

**Dreiundzwanzigste Playtest-Runde (2026-09-15): Rammen im Bonuslevel kostet
jetzt ein Leben, Doppelschiff verdoppelt die Gegner-Spalten.**
- **1. „Werde im Bonuslevel durch Feindberührung gar nicht zerstört"**:
  bewusst, aber ab jetzt überholt — die Neunzehnte Runde hatte „kein
  Lebensrisiko" als Design-Entscheidung getroffen (`bonus_enemy.gd` absichtlich
  nicht in der Gruppe `"enemy"`, die `ship.gd`s Kollisions-Handler dafür
  abfragt). Nutzer-Feedback: einfach ungehindert hindurchfliegen zu können
  fühlte sich falsch an. Fix: `ship.gd::_on_area_entered()` bekommt einen
  dritten Zweig — `area.is_in_group("bonus_wave_active")` (dieselbe Gruppe,
  der jeder `bonus_enemy` schon für das Wellen-Ende-Tracking beitritt) löst
  jetzt `_destroy(true)` aus, genau wie das Rammen eines stürzenden
  Formations-Gegners. Der Bonus-Gegner selbst wird dabei NICHT zerstört —
  entspricht dem bestehenden Verhalten der normalen Formation (Rammen tötet
  dort auch nur das Schiff, nie den Gegner). Weiterhin kein Gegnerfeuer, kein
  Sturzflug, kein Boss — nur dieses eine Stück Risiko kommt dazu. Per echtem
  Area2D-Kollisionstest verifiziert (Bonus-Gegner künstlich dauerhaft auf die
  Schiffsposition gezwungen, da `bonus_enemy.gd`s `_physics_process()` die
  Position ohnehin jeden Frame aus der Bahnkurve neu setzt — eine einmalige
  Platzierung hätte die Kollision nicht zuverlässig ausgelöst).
- **2. Doppelschiff verdoppelt jetzt die Gegner-Spalten im Bonuslevel**
  (Nutzerwunsch: zwei Kanonen an nur einer Spalte fühlte sich verschenkt an).
  `game.gd::_run_bonus_wave()` prüft jetzt zu Beginn JEDER Welle (nicht
  einmalig für das ganze Level — ein Treffer kann das Doppelschiff-Bonus
  jetzt ja mitten im Level wieder aufheben, siehe Punkt 1 oben) `ship._twin`
  und spawnt bei aktivem Doppelschiff zwei parallele Spalten
  (`BONUS_TWIN_ROW_GAP = 70px` auseinander, angelehnt an `ship.gd`s eigenen
  `TWIN_OFFSET * 2 = 68px` — jede Spalte landet dadurch ungefähr direkt unter
  einer der beiden Kanonen) statt einer, mit doppelter Gegnerzahl (12 statt 6
  pro Welle). `_bonus_total` (für die „PERFECT!"-Prüfung am Levelende) wird
  seitdem nicht mehr einmalig zu Levelbeginn festgelegt, sondern läuft pro
  Welle mit — sonst hätte ein Doppelschiff-Wechsel mitten im Level die
  Endsumme falsch gemacht. Per Headless-Test verifiziert: eine Welle ohne
  Doppelschiff spawnt exakt 6 Gegner auf einer Spalte, dieselbe Welle mit
  aktivem Doppelschiff spawnt exakt 12 auf zwei unterschiedlichen Spalten.

**Vierundzwanzigste Playtest-Runde (2026-09-15): Bonuslevel bricht bei
Schiffsverlust ab, Sound-Menü spielt keine Hintergrundmusik mehr und
Sound-Vorhören unterbricht sich jetzt gegenseitig statt zu überlappen.**
- **1. Bonuslevel bricht jetzt ab, sobald ein Schiff verloren geht**
  (Nutzerwunsch — gilt bewusst NUR für das Bonuslevel, keine normale Stage
  hat sich je so verhalten). Neues `game.gd`-Feld `_bonus_abort`: wird in
  `_on_ship_died()` ganz am Anfang gesetzt, falls `_state == BONUS` gerade
  gilt (VOR jeder anderen Aktion, extra dokumentiert als eigener `was_bonus`-
  Merker, da `_state` selbst absichtlich NICHT sofort verändert wird — das
  hätte `_process()`s normale Stage-Clear-Prüfung mitten in der Explosions-/
  Wiederaufbau-Animation fälschlich auslösen können, weil die „enemy"/
  „bonus_item"-Gruppen in einem Bonuslevel ohnehin schon leer sind).
  `_start_bonus_level()`/`_run_bonus_wave()` prüfen ab jetzt zusätzlich zu
  `_state != BONUS` auch `_bonus_abort` an jeder ihrer bestehenden
  Abbruchstellen und hören dadurch von selbst auf, ohne dass sie ihrerseits
  `_finish_bonus_level()` aufrufen (das würde ja ein „ganz normal
  abgeschlossen"-Banner zeigen). Sobald das neue Schiff nach Explosion +
  Wiederaufbau tatsächlich wieder da ist, ruft `_on_ship_died()` stattdessen
  `_finish_bonus_level_early()` auf — dieselbe Banner-/Warte-/Stage-Wechsel-
  Logik wie `_finish_bonus_level()`, zeigt aber IMMER die erreichte
  Punktzahl (nie „PERFECT!", da der Durchlauf ja unterbrochen wurde, nicht
  regulär beendet). Per Headless-Test verifiziert: eine laufende Welle
  (bereits mit Gegnern gespawnt) wird beim simulierten Schiffsverlust
  abgebrochen, verbliebene Gegner werden entfernt, die Stage-Zahl erhöht
  sich trotzdem, und das Banner zeigt exakt die vorher simulierten
  130 Punkte statt eines abgeschlossenen Levels.
- **2. Sound-Menü spielt keine Menü-Musik mehr** (Nutzer-Selbstkorrektur:
  „ein Fehler meinerseits" — beim ursprünglichen Entwurf der Musik-
  Zustandsmaschine in der Dreizehnten/Vierzehnten Playtest-Runde wurde
  `"sound"` versehentlich mit in `MENU_MUSIC_SCREENS` aufgenommen, obwohl der
  ganze Zweck dieses Screens — einzelne Sounds vorhören — durch eine
  mitlaufende Hintergrundmusik konterkariert wird). `"sound"` ist jetzt aus
  `menus.gd::MENU_MUSIC_SCREENS` entfernt — Betreten des Sound-Screens
  stoppt die Menü-Musik sofort (über den schon bestehenden
  `_apply_screen_music()`-Mechanismus, kein neuer Code nötig), Verlassen
  zurück zu „Einstellungen" (weiterhin in der Liste) startet sie normal
  wieder.
- **3. Vorhören unterbricht sich jetzt gegenseitig statt zu überlappen**
  (zweiter, verwandter Fehler, den derselbe Loop-Mechanismus verursacht
  hatte): `sound_manager.gd::preview()` behandelte einen Loop-Track
  (`menu-music`/`scoring-board-music`) beim Vorhören als AN/AUS-Schalter
  (spielt er gerade, stoppen; sonst starten) — unabhängig von jedem anderen
  gerade laufenden Vorhör-Sound. Zusammen mit Punkt 2 führte das dazu, dass
  z. B. das Verstellen des „Menu music"-Reglers die im Hintergrund laufende
  Musik kurz an-/abschaltete, UND mehrere normale (nicht-loopende) Vorhör-
  Sounds sich gegenseitig überlappen konnten, wenn man schnell hintereinander
  an mehreren Reglern zog. Fix: neue, komplett getrennte Methode
  `SoundManager.preview_exclusive(key)` — ob ein Sound normalerweise loopt,
  spielt beim Vorhören keine Rolle mehr; sie merkt sich nur den zuletzt
  vorgehörten Key (`_previewing`) und stoppt IMMER zuerst den vorherigen,
  bevor sie den neuen einmalig abspielt (kein automatisches Wiederholen,
  umgeht `_wanted`/`LOOPING_KEYS` bewusst komplett). `menus.gd::_sound_row()`
  ruft das jetzt beim Loslassen eines Reglers auf statt der alten `preview()`.
  Zusätzlich stoppt `menus.gd::hide_all()` jetzt IMMER einen noch laufenden
  Vorhör-Sound (`SoundManager.stop_preview()`) — ein einziger, robuster
  Ort, der sowohl den „Fertig"-Button (über `_swap()`s eigenen `hide_all()`-
  Aufruf) als auch `game.gd`s direkte Aufrufer (`_resume()`, `_new_run()`,
  `_revive_after_win_edit()`) abdeckt, damit ein Vorhör-Sound niemals bis
  ins eigentliche Spiel hineinklingt. Die alte, jetzt ungenutzte `preview()`-
  Methode wurde komplett entfernt statt nur unbenutzt liegen gelassen. Per
  Headless-Test verifiziert: Menü-Musik läuft auf „Pause", verstummt beim
  Wechsel zu „Sound", läuft wieder beim Zurückwechseln zu „Einstellungen";
  `preview_exclusive("shoot")` läuft, `preview_exclusive("extra")` direkt
  danach stoppt „shoot" zuverlässig und spielt „extra"; `hide_all()` stoppt
  einen noch laufenden Vorhör-Sound zuverlässig.

**Fünfundzwanzigste Playtest-Runde (2026-09-15): Explosions-Sound spielte
fälschlich auch bei einem Boss-Fang.** Nutzer-Report: „Der Explosions-Sound
während des Capture-Vorgangs darf natürlich nicht abgespielt werden, weil das
ja kein Verlust im üblichen Sinne ist."
- **Ursache**: `ship.gd::_destroy(show_explosion)` spielte den
  `ship-destroyed`-Sound schon immer BEDINGUNGSLOS, unabhängig vom
  `show_explosion`-Parameter — nur die BOOM-Animation selbst
  (`game.gd::_on_ship_died()`s `if show_explosion: await _play_explosion(...)`)
  war je an diesen Parameter gekoppelt. Bei einem Boss-Fang (`show_explosion
  = false`, siehe die zwölfte/vierzehnte Playtest-Runde) lief der
  eigentliche Zerstörungs-Sound also trotzdem — zusätzlich zum dafür
  vorgesehenen `beam-sound` (siehe „Traktorstrahl-Fang-Sound", Dreizehnte
  Playtest-Runde) — und ein Fang klang dadurch (akustisch) wie ein
  echter Tod. Fix: `if _snd and show_explosion: _snd.play("ship-destroyed")`
  — derselbe Parameter, der schon die Boom-Animation gattet, gattet jetzt
  auch ihren Sound.
- **Zum zweiten Teil des Reports** („...und auch durch Treffer der anderen
  Gegner oder Bomben nicht gespielt werden darf" — gemeint: während eines
  laufenden Fangversuchs): das war durch die Zweiundzwanzigste Playtest-
  Runde (`ship.gd::_capture_invuln`) bereits strukturell abgedeckt — ein
  Treffer durch irgendetwas anderes als den fangenden Strahl selbst erreicht
  `_on_area_entered()`s `_destroy()`-Aufruf während eines aktiven
  Fangversuchs gar nicht erst (wird davor schon abgefangen), es gibt also
  keinen zweiten Codepfad, der noch extra geprüft werden müsste.
- Per Headless-Test verifiziert: `_destroy(false)` (Fang) spielt
  `ship-destroyed` nachweislich NICHT, `_destroy(true)` (echter Treffer)
  spielt ihn weiterhin wie gehabt.

**Sechsundzwanzigste Playtest-Runde (2026-09-15): Sound-Lautstärke-Defaults
kalibriert (CLAUDE.md-„Offen"-Punkt 12 abgeschlossen).**
- **Keine Pegelmessung** — der Nutzer hat stattdessen für jeden der 15 Sounds
  den Prozentwert genannt, den er im Sound-Menü unter der bisherigen
  (neutralen `base_db=0.0`) Kalibrierung als angenehm eingestellt hatte:
  Menu music 40, Results music 25, Intro music (level 1) 30, Shot 15, Enemy
  kill 15, Enemy kill (diving) 15, Dive 10, Wave announcement 10, Tractor
  beam capture 15, Boss killed 25, Ship destroyed 30, Extra life 30,
  Achievement row full 20, Stage cleared 20, Next stage 20.
- **Umrechnung auf eine einheitliche 50-%-Mitte** (Nutzerwunsch: „als
  mittlere Lautstärke normieren, damit dann nach unten und nach oben quasi
  je 50 % an Lautstärke abgezogen oder hinzugefügt werden könnten"). Aus
  `volume_db = base_db + linear_to_db(prozent/100)` (`sound_manager.gd::
  _apply()`) folgt: damit der neue Default von 50 % exakt so klingt wie der
  vom Nutzer gefundene alte Prozentwert bei `base_db=0`, muss
  `base_db = 20·log10(alter_prozent / 50)` sein (hergeleitet aus
  `base_db + linear_to_db(0.5) = linear_to_db(alter_prozent/100)`). Alle 15
  `SOUNDS`-Einträge in `sound_manager.gd` haben jetzt diesen errechneten
  `base_db`-Wert UND einheitlich Default-% 50 (vorher uneinheitlich
  45–85 geraten) — „nach oben/unten" bedeutet jetzt für jeden Sound
  gleichermaßen „lauter/leiser als die vom Nutzer selbst gefundene
  Referenz", nicht mehr „lauter/leiser als ein arbiträrer Alt-Default".
  `CALIB_VERSION` 4→5, damit alte gespeicherte Prozentwerte (die gegen die
  ALTE, flachen Kurve eingestellt wurden und unter der neuen an der
  falschen Stelle klingen würden) verworfen werden und jeder wieder bei den
  neuen 50-%-Defaults startet.
- Per Headless-Test verifiziert: für jeden der 15 Keys erzeugt der neue
  `base_db` bei 50 % exakt (auf 0,01 dB genau, reine Rundungsdifferenz durch
  die zweistellige `base_db`-Rundung im Code) denselben `volume_db`-Wert,
  den die alte Kalibrierung beim vom Nutzer genannten Prozentwert erzeugt
  hätte — die Umrechnung stimmt rechnerisch exakt.

**Siebenundzwanzigste Playtest-Runde (2026-09-15): Boss spielt beim
Fangversuch keinen dive-Sound mehr; erster Versuch eines Landscape-
Kabinett-Overlays für Geräte ohne Hochkant (Anbernic RG552).**
- **1. Boss-Fang spielte fälschlich "dive" zusätzlich zu "beam-sound"**
  (Nutzer-Report): `enemy.gd::capture_dive()` spielte seit jeher `_snd.play
  ("dive")` beim Start des Fangversuchs — vermutlich aus dem normalen
  `dive()` kopiert und nie entfernt. Der Fangversuch hat aber längst seinen
  eigenen, dedizierten Sound (`beam-sound`, aus der Dreizehnten Playtest-
  Runde, gespielt beim tatsächlichen Fang). Fix: die `dive`-Zeile in
  `capture_dive()` ersatzlos gestrichen. Per Headless-Test verifiziert.
- **2. Landscape-Kabinett-Overlay (erster Versuch)** — der Nutzer möchte
  testen, wie das Spiel mit `arcade-screen1.png` als Kabinett-Rahmen auf
  seinem Anbernic RG552 aussieht (ein Gerät ohne Hochkant-Rotation). Neue
  Datei `arcade_shell.gd`/`.tscn`, jetzt `run/main_scene` (ersetzt
  `game.tscn` direkt als Startpunkt).
  - **Warum das nicht einfach ein Hintergrundbild sein kann**: Godots
    `canvas_items`+`KEEP`-Streckmodus (bisheriges Verhalten auf
    Nicht-Touch-Geräten) erzeugt die schwarzen Ränder als echtes Letterboxing
    AUSSERHALB des von der Szene erreichbaren Koordinatenraums — dort lässt
    sich grundsätzlich nichts hinzeichnen, auch kein Hintergrund-Node. Fix:
    `arcade_shell.gd` schaltet für genau diesen einen Fall die automatische
    Fenster-Skalierung ab (`Window.content_scale_mode = DISABLED`) und baut
    das Letterboxing von Hand nach: ein `Control` über das ganze Fenster mit
    dem Kabinett-Bild als `TextureRect` (`STRETCH_KEEP_ASPECT_CENTERED`),
    darüber ein `SubViewportContainer` (`stretch=true`) mit einem
    `SubViewport` fester Größe 540×960, in dem `game.tscn` unverändert läuft
    — das Spiel selbst „sieht" innen weiterhin exakt dieselbe feste
    540×960-Welt wie eh und je, nichts an `ship.gd`/`enemy.gd`/HUD/etc.
    musste dafür angefasst werden.
  - **Platzierung im Bild**: `arcade-screen1.png` direkt vermessen
    (2728×1536 Gesamtgröße) — der große zusammenhängende transparente
    Bereich läuft über die VOLLE Bildhöhe und ist horizontal zentriert, aber
    selbst deutlich breiter (~1787 px) als eine 540:960-Fläche braucht.
    Statt das Spiel auf die (nicht-Hochkant-förmige) Aussparung zu strecken
    (hätte es verzerrt), bleibt das Seitenverhältnis exakt 540:960 erhalten
    und wird auf die VOLLE Höhe der Aussparung skaliert, horizontal
    zentriert.
  - Zuerst nur per Headless-Test strukturell/rechnerisch geprüft (kein
    Display hier verfügbar) — die eigentliche Bildwirkung brauchte den
    Nutzer auf dem echten Gerät. Direkt im Anschluss per USB getestet, siehe
    „Achtundzwanzigste Playtest-Runde" unten für zwei dabei gefundene echte
    Bugs und das Ergebnis.

**Achtundzwanzigste Playtest-Runde (2026-09-15): Landscape-Kabinett-Overlay
live auf dem RG552 verifiziert — zwei echte Bugs gefunden und behoben, jetzt
bewusst für JEDES breite Fenster aktiv, nicht nur das eine Gerät.**
RG552 hing per USB im Entwicklermodus — direkter Zugriff über `adb`, daher
diesmal ausnahmsweise echte Verifikation statt nur Headless-Tests: APK bauen,
`adb -s <serial> install -r`, `adb shell monkey ... -c LAUNCHER` zum Starten,
`adb shell screencap` + `adb pull` für echte Screenshots vom Gerät, `adb
logcat` für `print()`-Ausgaben aus dem laufenden Spiel.
- **Bug 1 — Overlay erschien gar nicht**: `arcade_shell.gd::_wants_overlay()`
  hatte einen `OS.has_feature("mobile") or DisplayServer.is_touchscreen_
  available()`-Ausschluss (aus der vorigen Runde, „nicht touch UND breiter
  als hoch"). Per Diagnose-`print()` + `adb logcat` bestätigt: auf dem RG552
  (Android-Export) liefert `OS.has_feature("mobile")` `true` — der Ausschluss
  griff also *immer*, unabhängig von der tatsächlichen Bildschirmform, das
  Overlay wurde nie gebaut. Fix: der Touch/Mobile-Ausschluss ist komplett
  raus — `_wants_overlay()` prüft jetzt ausschließlich die Fensterform
  (breiter als hoch). Landscape-Bildschirme haben das Letterbox-Problem
  unabhängig davon, ob das Gerät "mobile" meldet oder einen Touchscreen hat.
  Zusätzlich neues `game.gd::force_non_touch` (von `arcade_shell.gd` vor
  `add_child()` gesetzt): der gewrappte Spiel-Screen wird jetzt bewusst NIE
  als Touch-Gerät behandelt, unabhängig davon, was `OS.has_feature("mobile")`
  dort sagt — dieser Fall ist immer Controller-/Tastatur-gesteuert, und das
  feste 540×960-SubViewport hat ohnehin keine "Extra-Höhe" für ein
  Touch-Layout herzugeben.
- **Bug 2 — Kunst nur oben links, rechts nichts**: erster Live-Screenshot
  zeigte das Kabinett-Bild nur in der LINKEN Bildschirmhälfte, rechts nur
  Schwarz — nicht symmetrisch wie erwartet. Ursache: `TextureRect` hat
  standardmäßig `expand_mode = EXPAND_KEEP_SIZE`, wodurch die Control-Größe
  der NATIVEN Textur-Pixelgröße (2728×1536) folgt und die zuvor gesetzten
  Anchors komplett ignoriert werden — das Bild wurde oben links unskaliert
  angezeigt und am Bildschirmrand (1920 px) abgeschnitten; der komplette
  rechte Bildteil (der bei echter Skalierung sichtbar gewesen wäre) lag
  jenseits des sichtbaren Bereichs. Fix: `bg.expand_mode = TextureRect.
  EXPAND_IGNORE_SIZE` — dadurch folgt die Control-Größe den Anchors wie bei
  jedem anderen Control, und `stretch_mode` (`STRETCH_KEEP_ASPECT_CENTERED`)
  greift erst dadurch tatsächlich.
- **Ergebnis nach beiden Fixes**: per Screenshot bestätigt — Kabinett-Kunst
  symmetrisch links/rechts, Spiel exakt mittig in der Aussparung, weder
  verzerrt noch abgeschnitten. Screenshots dem Nutzer direkt als Datei
  geschickt.
- **Bewusste Scope-Erweiterung** (Nutzerfrage: „würde es auf breiten
  Bildschirmen auch allen anderen Versionen gut zu Gesicht stehen, oder habe
  ich einen Denkfehler?" — keiner: durch den Wegfall des Touch/Mobile-
  Ausschlusses gilt die Bedingung jetzt ohnehin rein über die Fensterform,
  ganz ohne separate Geräte-Erkennung) — ein normales breites
  Desktop-Fenster bekommt den Kabinett-Rahmen jetzt genauso wie das RG552,
  nicht mehr nur ein einzelnes Zielgerät. Kein separater Schalter dafür
  nötig oder vorgesehen.
- Diagnose-`print()` nach Bestätigung wieder entfernt (war nur für die
  `adb logcat`-Analyse gedacht). Per Headless-Test nachverifiziert:
  `expand_mode == EXPAND_IGNORE_SIZE` gesetzt, `force_non_touch` korrekt bis
  zur gewrappten `Game`-Instanz durchgereicht.

## Gameplay-Architektur (alles im Code, wie tetris)

Main-Scene `game.tscn` (Node2D `Game` + `game.gd`): SpaceBackground, Formation,
StageDirector, Ship, HUD-CanvasLayer.

- `game.gd` (`class_name Game`) — State-Machine TITLE → READY → ENTERING →
  FORMATION → GAME_OVER + `_paused`. `_ready()` ruft nach `_apply_display_mode()`
  seit der elften Playtest-Runde zusätzlich
  `get_tree().call_group("touch_layout_listeners", "apply_touch_layout")` auf —
  `Ship` ist ein Kind-Node und hat seine eigene `_ready()` (inkl.
  `_update_home_y()`) schon VOR diesem Aufruf laufen lassen, gegen den zu dem
  Zeitpunkt noch nicht umgeschalteten `content_scale_aspect`; ohne diesen
  Nachtrag blieb die Schiffsposition auf Geräten, die Touch schon beim Start
  kennen, dauerhaft auf dem falschen (zu kleinen) Viewport-Höhenwert stehen,
  siehe dort. `_new_run()` (aus Titel/„Nochmal"): liest
  `GameSettings`, setzt Leben/Extra-Leben-Schwelle, `_director.configure(...)`
  aus der Schwierigkeit, räumt das Feld (`_clear_board`), entpausiert, Musik an,
  spielt die Ship-Reconstruct-Animation + „BEREIT"-Banner (`_play_reconstruct()`)
  bevor das Schiff überhaupt erscheint. Ship `died` → Reserve-Check (siehe
  globale Leben-Anzeige-Regel) → bei Rest: Reconstruct-Animation statt reinem
  Timer-Wait, dann `respawn()`; bei 0 → GAME_OVER (1 s Delay, dann
  `menus.show_run_summary(...)` — seit der siebten Playtest-Runde vor
  `show_game_over`, siehe dort — Tree pausiert). Während `FORMATION` außerdem alle
  `BONUS_INTERVAL_MIN/MAX` (9–16 s) ein `bonus_item` (`_spawn_bonus_item()`) —
  `_bonus_t` wird seit 2026-09-13 nur einmal pro Run gesetzt (`_new_run()`),
  NICHT mehr bei jedem Stage-Wechsel zurückgesetzt (das war der eigentliche
  Bug hinter "zu wenige Achievements", siehe „Sechste Playtest-Runde"). Pause
  (`pause`-Action / HUD-Button)
  → Tree pausiert + `menus.show_pause()`. `_enter_title()` bei „Zum Titel".
  `_snd` = `get_node_or_null("/root/Snd")` (bare `Snd` bricht `_selftest`).
  `content_scale_aspect` KEEP/KEEP_WIDTH je Touch. `process_mode = ALWAYS`.
  `_check_boss_threshold()` und `_check_win()` laufen bei jeder
  Punktegutschrift (Kill UND Bonus-Pickup) — Ersteres ruft bei
  Schwellenüberschreitung `StageDirector.force_boss_capture()` (siehe dort,
  seit 2026-09-13 „sticky"), Letzteres beendet den Lauf mit
  `show_run_summary(score, stage, won=true, ...)`, sobald `GameSettings.win_score`
  erreicht ist (0 = aus) — seit der neunten Playtest-Runde umkehrbar:
  `_ended_by_win` + `_revive_after_win_edit()` lassen eine per „Sieg"-Ende
  gestoppte Runde über den Summary-Screens eigenen „Einstellungen"-Button
  weiterlaufen, sobald der Sieg-Score wieder über dem aktuellen Punktestand
  liegt (oder ausgeschaltet wird), siehe dort. `achievement_00`-Pickup →
  `ship.activate_hyper_ammo()` (siehe „Vierte Playtest-Runde") — verdoppelt
  seit der siebten Playtest-Runde auch die Punktzahl pro Kill, nicht nur die
  Schusszahl. `_kill_stats` (seit der achten Playtest-Runde, seit der neunten
  ein Array von `{kind, variant_idx, is_rescue, icon, count, points}` statt
  eines nach `EnemyKinds`-Wert gekeyten Dictionary-Paars — pro tatsächlich
  gesehenem SPRITE, nicht nur pro Punkte-Stufe, plus ein eigener Eintrag für
  einen Boss-Rettungskill) führt mit, was wie oft abgeschossen wurde + wie
  viele Punkte das brachte — für die Kill-Aufschlüsselung im
  Run-Summary-Screen, siehe dort. `_reload_settings()` wendet seit der achten
  Playtest-Runde ALLE Einstellungen sofort mid-Run an, nicht mehr nur
  `max_shots` (`_apply_extra_life_setting()`/`_apply_boss_interval_setting()`
  rechnen die nächste Schwelle relativ zum aktuellen Score neu, `_win_score`
  löst bei Bedarf sofort `_check_win()` aus, `_director.configure(...)`
  übernimmt eine geänderte Schwierigkeit ohne Rundenneustart). Stage-Clear
  (`_process()`) wartet seit der achten Playtest-Runde zusätzlich, bis kein
  `bonus_item` mehr im Feld ist, und räumt beim tatsächlichen Wechsel die
  `enemy_shots`-Gruppe (Bomben) leer — sonst konnten längst geworfene Bomben
  noch nach Levelende treffen, siehe dort.
- `hud.gd` (`class_name Hud`) — **nur noch das In-Game-HUD**: Score (oben links),
  Stage (unten rechts, Cyan), Leben unten links (`_draw`, echte `player_trim.png`-
  Sprites statt Platzhalter-Dreiecke; ab `MANY_THRESHOLD = 3` (seit der siebten
  Playtest-Runde, vorher 5) ein Icon + „× N" statt wachsender Reihe — `_lives`
  ist die Reserve, siehe `game.gd`), Lap-Marker seit der siebten Playtest-Runde
  an fester Position nahe dem rechten Rand (siehe dort), Center-Banner,
  Pause-Button oben rechts (seit 2026-09-13 immer sichtbar/
  mausklickbar statt nur auf Touch-Geräten, mit eigenem Milchglas-Hintergrund
  via `_add_pause_glass()` — siehe „Fünfte Playtest-Runde"), Signal
  `pause_pressed`,
  `set_playing(on)` blendet das ganze HUD bei offenem Menü aus. Titel / Pause /
  Settings / Game-Over macht jetzt `menus.gd`. Bonus-Icon-Reihe unten mittig
  (`BONUS_MAX_SHOWN = 7`, `add_bonus_icon()` liefert `true` zurück, sobald eine
  Reihe voll ist — `_bonus_laps` wird dabei SOFORT hochgezählt, seit der
  zwölften Playtest-Runde ohne Timer: die volle 7er-Reihe bleibt danach
  einfach stehen (`_lap_pending`), bis irgendein KÜNFTIGES Achievement
  eintrifft — genau dieses leert dann die alte Reihe und wird selbst zum
  einzigen Icon der neuen (vorher: fester `LAP_HOLD_TIME`-Timer von 0,7 s,
  siehe „Achte"/„Zwölfte Playtest-Runde"). `_draw_lap_marker()` zeigt den türkisen
  (vorher goldenen) „× N"-Rundenzähler jetzt IMMER, auch bei 0 Runden, an
  seiner festen Position — siehe „Dritte Playtest-Runde" für die Position
  selbst). Die Icon-Reihe selbst ist seit der achten Playtest-Runde
  kollisionssicher gegen die Lebensanzeige links UND den Lap-Marker rechts
  geklemmt (`ROW_LEFT_MIN_X`/`BONUS_ROW_SHIFT_RIGHT`) und skaliert sich bei
  Bedarf (viele + breite Icons gleichzeitig) automatisch etwas kleiner, statt
  zu überlappen. `_bonus_icon_indices` (parallel zu `_bonus_icons`, seit
  2026-09-13) + `current_lap_indices()` lassen `bonus_item.gd` Duplikate
  innerhalb einer Reihe ausschließen (siehe „Sechste Playtest-Runde").
- `menus.gd` (`class_name Menus`, eigener `CanvasLayer` in `game.tscn`,
  `process_mode = ALWAYS`) — alle Menü-Screens im Code wie tetris' `ui.gd`:
  Titel, Pause, Einstellungen (`_add_stepper()` hängt Name/</Wert/>-Zellen
  seit 2026-09-13 flach in ein gemeinsames `GridContainer` statt je Zeile
  einen eigenen `HBoxContainer` zu bauen — sonst richten sich `</>` nicht
  spaltenweise aus, siehe „Sechste Playtest-Runde"; Stepper: Leben /
  Extra-Leben / Boss alle X Punkte / Sieg bei X Punkten / Max. Schüsse /
  Schwierigkeit, seit der neunten Playtest-Runde außerdem ein
  „Standardwerte"-Button, der alle sechs auf feste Werkseinstellungen
  zurücksetzt — Sound bleibt unangetastet, hat eigene Defaults). Der
  Leben-Stepper ist seit der achten Playtest-Runde gesperrt (deaktivierte
  `<`/`>`, nicht-editierbares Feld, halbtransparent), sobald die
  Einstellungen aus dem Pausenmenü ODER (seit der neunten Playtest-Runde)
  dem Sieg-Screen heraus geöffnet wurden (`_lives_stepper`,
  `_update_lives_lock()`, `_return_to == "pause" or "summary"`) — die
  Einstellung wird ohnehin nur einmalig in `_new_run()` gelesen; der
  „Standardwerte"-Button respektiert dieselbe Sperre und fragt seit der
  zehnten Playtest-Runde erst über den neuen `"confirm_reset"`-Screen nach,
  statt sofort zurückzusetzen. Sound-Unterseite (HSlider pro Sound,
  Loslassen = Vorhören), Hilfe (seit der zehnten Playtest-Runde bildbasiert —
  `HELP_PAGES_DESKTOP`/`HELP_PAGES_TOUCH`, seit der elften Playtest-Runde
  6 bzw. 5 Seiten mit `‹`/`›` (die neue „Schwierigkeitsstufen"-Karte kam
  dazu), siehe dort — vorher 3 reine Textseiten), seit der siebten Playtest-Runde ein
  Run-Summary-Screen (`"summary"`,
  `show_run_summary()`, seit der achten Playtest-Runde mit zusätzlicher
  Kill-Aufschlüsselung — seit der neunten Playtest-Runde pro tatsächlich
  gesehenem SPRITE statt nur pro Punkte-Stufe, in einem umbrechenden
  `GridContainer` statt fixer 3 Spalten, siehe dort) VOR dem Game-Over-
  Screen, dann Game-Over + Hall-of-Fame-Liste + Namenseingabe bei
  Qualifikation. Der Summary-Screen hat seit der neunten Playtest-Runde
  zusätzlich einen eigenen „Einstellungen"-Button — erhöht man dort „Sieg
  bei X Punkten" wieder über den erreichten Score (oder schaltet es aus),
  spielt die Runde über `game.gd::_revive_after_win_edit()` direkt weiter,
  siehe dort. `_close_sub()` prüft seit der achten Playtest-Runde vor dem
  Rück-Swap zu `_return_to`, ob inzwischen „summary"/„gameover" sichtbar ist
  (ein live geänderter Sieg-Score kann das synchron im selben Aufruf
  auslösen) und lässt den Swap in dem Fall aus; seit der neunten
  Playtest-Runde prüft es zuerst den entpausierten Baum als Zeichen einer
  Wiederbelebung und blendet dann stattdessen ALLE Menüs aus. Die HoF-Liste
  (`_hof_box`, gerendert über das seit der neunten Playtest-Runde geteilte
  `_render_hof_into(box, list, highlight)` — auch vom rein lesenden
  `"highscores"`-Screen genutzt, erreichbar über einen Button im
  Titel-Bildschirm UND (seit der zwölften Playtest-Runde) im Pausenmenü;
  `show_highscores(from)` setzt `_return_to` wie `_open_settings()`/
  `_open_help()`, damit „Fertig" dorthin zurückführt, siehe dort) ist seit der
  siebten
  Playtest-Runde ein `GridContainer` (Platz/Name/Score-Spalten,
  rechts-/links-/rechtsbündig) statt einer `VBoxContainer` mit
  leerzeichen-aufgefüllten Text-Zeilen — Letzteres richtete sich in einer
  proportionalen Schrift nicht wirklich aus. Namen werden seit der neunten
  Playtest-Runde immer großgeschrieben angezeigt (`.to_upper()`, deckt auch
  alte, klein gespeicherte Einträge ab) und beim Eintragen auch so
  gespeichert; `_maybe_auto_commit()` trägt einen qualifizierenden, aber
  vergessenen Score beim Verlassen über „Nochmal"/„Start-Menü"/„Beenden"
  automatisch als „YOU" ein. Signale `start_game` / `resume_game` /
  `to_title` / `settings_changed`. „Beenden" nur wenn nicht
  `OS.has_feature("web")`. Überschriften-Outline ist `UiStyle.ACCENT` (Cyan,
  seit 2026-09-13 — vorher ein unpassendes Grün).
- `game_settings.gd` (`class_name GameSettings`) — `user://settings.cfg` `[s]`:
  `lives` (`LIVES_MIN/MAX` = 2–9), `extra_life` (0 = aus, sonst
  `EXTRA_STEP`=1000 bis `EXTRA_MAX`=30000), `max_shots` (`MAX_SHOTS_MIN/MAX`
  = 1–5, gleichzeitig fliegende Laser), `boss_interval` (0 = aus, sonst
  `BOSS_INTERVAL_STEP`=1000 bis `BOSS_INTERVAL_MAX`=20000 — garantierter
  Boss-Capture-Versuch alle N Punkte, siehe „Dritte Playtest-Runde"),
  `difficulty` (0–2).
  `dive_params(difficulty)` → `{first, min, max, max_divers}` für den Director.
- `hall_of_fame.gd` (`class_name HallOfFame`) — `user://hall_of_fame.cfg`, Top 10
  nach Score (`qualifies` / `insert`). `rank_for(score)` (seit der siebten
  Playtest-Runde) liefert den voraussichtlichen Platz für den Run-Summary-Screen,
  ohne schon einzutragen.
- `sound_manager.gd` (Autoload `Snd`, `project.godot [autoload]`) — ein
  `AudioStreamPlayer` je Key, Key = Dateiname (`res://assets/sounds/<key>`,
  `EXTS` probiert `.wav` vor `.ogg`; fehlt die Datei in beiden Formaten →
  still, absichtlich — siehe „Dreizehnte"/„Vierzehnte Playtest-Runde").
  Pro-Sound-Lautstärke 0–100 in `user://settings.cfg [sound]` + `calib_version`,
  `base_db`-Kalibrierung je Sound. Mehrere Keys können gleichzeitig loopen
  (`LOOPING_KEYS`, `_wanted`-Dictionary). Aktuelle Keys (15, siehe `ORDER`) —
  ALLE mit echtem Clip, kein einziger mehr still: `menu-music
  scoring-board-music start-first-level-music shoot enemy-death1
  enemy-death2 dive enemy-wave1 beam-sound boss-killed ship-destroyed extra
  bonus-stage-cleared level-cleared stage`. Kein Gameplay-Hintergrundmusik-Key
  mehr (`music` wurde in der vierzehnten Playtest-Runde ersatzlos entfernt —
  NES-Galaga hat keine durchlaufende Musik, nur Fanfaren). Clips liegen in
  `assets/sounds/` (die erste, inzwischen komplett abgelöste Sammlung vom
  2026-09-11 liegt als `assets/sounds_old/` daneben).

### Geräte-Layout (Phase 3)

Feste Design-Canvas 540×960 + `stretch/mode=canvas_items`. `game.gd` erkennt
Touch (`OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()`,
gecacht) und schaltet zur Laufzeit `content_scale_aspect`:
Desktop → `KEEP` (Letterbox), Touch → `KEEP_WIDTH` (Feld oben angepinnt,
Überhöhe fällt unter das Feld — Fingerbereich). **Retroaktiver Flip**: `game.gd`
und `ship.gd` sind in Gruppe `touch_layout_listeners` mit `apply_touch_layout()`;
`game._input` löst beim ersten echten `InputEventScreenTouch/Drag` einen
`call_group(...)` aus (manche Mobil-Browser melden Touch verspätet).

Gameplay-Positionen (Formation `home.y`, HUD) sind **fix gegen die
960er-Canvas**, nicht gegen `get_viewport_rect()` — die Überhöhe bleibt so
freier Raum unten. `attack_paths`/`bomb` nehmen dagegen die echte
Viewport-Höhe (Divers/Bomben laufen auf hohen Phones weiter runter, bevor sie
despawnen). **Schiff-y ist seit der achten Playtest-Runde KEINE Ausnahme mehr,
sondern folgt jetzt bewusst derselben echten Viewport-Höhe wie `attack_paths`/
`bomb`** (`ship.gd::_update_home_y()`, `HUD_BOTTOM_CLEARANCE`): vorher saß das
Schiff auf hohen Touch-Geräten (KEEP_WIDTH, `get_viewport_rect().size.y` >
960) weit oberhalb dessen, wo `bonus_item`/`bomb` tatsächlich ankommen — die
960-fixe Position blieb ganz oben in der um die Fingerzone erweiterten Fläche
hängen, Achievements fielen unerreichbar daran vorbei. Auf Desktop (`KEEP`,
`get_viewport_rect().size.y` immer exakt 960) ändert sich dadurch nichts.

Steuerung Touch: **Drag irgendwo** = relatives Lenken (`ship._unhandled_input`,
`event.relative.x`), **Auto-Fire, solange der Finger tatsächlich aufliegt**
(`_touch_down`, seit der achten Playtest-Runde — vorher schoss das Schiff auf
jedem als touch-fähig ERKANNTEN Gerät dauerhaft, auch ohne aufliegenden
Finger, was auf Geräten mit Touch UND Maus/Tastatur störte). Pause: Button
oder `pause`-Action; bei Pause zusätzlich Tap = Resume.
- `formation.gd` (`class_name Formation`) — 40 Slots (`ROWS`: 4 Boss / 8+8 Goei /
  10+10 Zako), Slot-Geometrie, „Breathing"-Sway des ganzen Blocks, Flap-Timer
  (`flap_toggled`), Belegungs-Tracking (`assign`/`release`/`live_count`).
  `BOSS_ROW_Y_NUDGE = -10.0` (seit 2026-09-13) hebt nur die Boss-Zeile leicht
  an — Platz für den gefangenen-Schiff-Passagier, ohne `ROW_SPACING` für die
  übrigen Zeilen anzufassen (siehe „Sechste Playtest-Runde").
- `entry_paths.gd` (`class_name EntryPaths`) — 3 Einflug-Muster (`BOTTOM_UP`,
  `TOP_LEFT`, `TOP_RIGHT`) als viewport-skalierte `Curve2D`, Catmull-Rom-Tangenten.
- `attack_paths.gd` (`class_name AttackPaths`) — `dive(slot, player, vp)` würfelt
  bei jedem Aufruf eine von 3 Kurvenformen (Wand-Peel+Sweep / weiter
  Loop-Schlenker / steiler Mittel-Plunge, siehe „Angriffsmuster-Vielfalt")
  und `return_to(slot, vp)` (von oben zurück in den Slot). Gleiches
  Catmull-Rom-Smoothing wie EntryPaths.
- `stage_director.gd` (`class_name StageDirector`) — **Fly-in**: 40 Slots in
  5er-Gruppen à 8 entlang einer Kurve (Launch-Versatz 0,16 s; Gruppen 0,9 s),
  meldet `stage_populated`. **Attacks**: nach `begin_attacks()` schickt alle
  1,3–3,2 s einen zufälligen **Nicht-Boss**-Formations-Gegner ins `dive()`,
  max. 3 gleichzeitig (`_launch_dive` zählt über
  `is_active_diver()`/`is_available_to_dive()`; Bosse sind seit der zweiten
  Playtest-Runde ausgeschlossen — sie fliegen nur noch Capture-Versuche, nie
  stinknormale Dives, siehe unten).
  **Capture-Versuche laufen auf einem eigenen, unabhängigen Timer**
  (`_try_capture_dive()`, alle `CAPTURE_INTERVAL_MIN`–`MAX` = 5–9 s, 33 %
  Chance, nur wenn ein Boss frei ist und noch kein Schiff gefangen ist) —
  nicht mehr an die Zufallsauswahl der normalen Dive-Lotterie gekoppelt (siehe
  „Boss-Capture-Race-Condition (Teil 2)" und „Zweite Playtest-Runde"). Beide
  Wege (Zufallschance UND der garantierte Punkte-Schwellenwert aus
  `game.gd::_check_boss_threshold()`) laufen seit 2026-09-13 über dieselbe
  `_attempt_capture_dive()` — `_try_capture_dive()` würfelt zuerst
  `CAPTURE_CHANCE`, `force_boss_capture()` (von `game.gd` aufgerufen) ruft sie
  direkt ohne Würfeln auf. `force_boss_capture()` selbst setzt seit 2026-09-13
  nur noch ein `_forced_pending`-Flag, das `_process()` alle
  `FORCED_RETRY_INTERVAL` (2 s) erneut versucht, bis ein Boss frei ist —
  übersteht damit Stage-Wechsel und Schiffsverlust (siehe „Vierte
  Playtest-Runde").
  `stop_attacks()` beim Stage-Wechsel. Reicht `enemy_killed(points, kind,
  variant_idx, was_carrying_captive)` (Gegnertyp seit der achten, Sprite-
  Variante + Rettungskill-Flag seit der neunten Playtest-Runde mit im Signal,
  für die Kill-Aufschlüsselung im Run-Summary-Screen) und `ship_rescued`
  durch.
- `enemy.gd` (Area2D, kein `class_name`) — States FLYING_IN / LOCKING /
  IN_FORMATION / DIVING / RETURNING / **CAPTURE_APPROACH / CAPTURE_BEAM**
  (Boss-Capture, siehe unten). Generischer Path-Follower
  (`_start_path(curve, speed, done_callable)`): FLY 480 / DIVE 300 / RETURN
  360 px/s, Ausrichtung nach Fahrtrichtung, dann 0,4-s-Tween in den Slot.
  Beim `dive()` gibt der Gegner seinen Slot frei (`_formation.release`), wirft
  bis zu 2 Bomben (`bomb.tscn`), kehrt nach dem Kurvenende via `return_to`
  zurück und belegt den Slot neu. Sprite + Skew/Squash-Flap
  (`EnemyKinds.DATA[kind]["texture"/"scale"]`, siehe „Erste echte Assets").
  Kollision Layer 4 / Maske 8. `_is_invulnerable()` blockt `_explode()`
  (Laser wird trotzdem konsumiert) während `CAPTURE_APPROACH`, `CAPTURE_BEAM`
  und `RETURNING`-mit-`_carrying_captive` (siehe „Dritte Playtest-Runde"),
  und während `FLYING_IN`, solange die y-Position noch unter der tatsächlichen
  Kanonenmündung liegt (der `BOTTOM_UP`-Einflug startet unterhalb des
  Bildschirms — siehe „Vierte Playtest-Runde"; misst seit 2026-09-13 korrekt
  gegen `ship.gd::GUN_MUZZLE_OFFSET_Y` statt gegen den Schiffsrumpf, siehe
  „Sechste Playtest-Runde"). `CAPTIVE_SCALE`/`CAPTIVE_OFFSET_Y` (seit
  2026-09-13, siehe „Sechste Playtest-Runde") verkleinern/verschieben das
  Passagier-Sprite in `_spawn_captive_visual()`, um Überlappung mit der
  Formationsreihe darunter zu vermeiden.
- **Boss-Capture** (`enemy.gd` + `capture_beam.gd`/`.tscn`): Boss hovert statt
  durchzufliegen (CAPTURE_APPROACH), homt dabei seit der siebten Playtest-Runde
  live jeden Frame auf die AKTUELLE Spielerposition (`_home_toward_player()`,
  `CAPTURE_HOMING_SPEED = 640 px/s` > Schiffs-eigene 480 px/s — der Spieler
  kann den Fang verzögern, aber nicht entkommen) statt einer vorgebackenen
  Snapshot-Kurve (`AttackPaths.capture_approach()`, entfernt). Sobald die
  Hover-Höhe erreicht ist, lässt er `capture_beam.tscn` herab (grüner Strahl,
  jetzt Kind-Node des Bosses statt Geschwister — folgt dessen weiterhin live
  nachgeführter x-Position (`_track_player_x()`) automatisch mit; wächst/hält/
  zieht sich zurück, Gruppe `"enemy_shots"` — zerstört das Schiff über den
  schon bestehenden Kollisions-Code in `ship.gd`, kein Sonderfall nötig).
  Trifft der Strahl (`caught`-Signal), wird `_carrying_captive` **sofort im
  Signal-Handler** gesetzt (nicht erst nach Ablauf des Beam-Timers, siehe
  „Boss-Capture-Race-Condition (Teil 2)") und der Boss trägt eine
  `ship_captured.png`-Sprite als Kind-Node zurück in die Formation (folgt
  Position/Rotation automatisch).
  Wird genau dieser Boss später zerstört (`_explode()`), feuert er
  `ship_rescued(at_position)` (Positions-Parameter seit der siebten
  Playtest-Runde) — `game.gd::_on_ship_rescued()` macht daraus
  `ship.become_twin()`: zweites Schiff+Triebwerk (Duplikat, `TWIN_OFFSET=34`),
  doppelte Laser-Kapazität, ein Treffer beendet den Bonus wieder
  (`_destroy() -> _revert_twin()`). Max. ein gefangenes Schiff gleichzeitig.
  Zeigt außerdem seit der siebten Playtest-Runde einen kurzen „+Punkte"-Popup
  an der Boss-Position (`_spawn_score_popup()`, dieselbe Punktzahl wie der
  Kill selbst).
- `bomb.gd` / `bomb.tscn` — Gegner-Schuss, fällt (leicht Richtung Spieler-x zum
  Abwurfzeitpunkt), Platzhalter-Raute. Layer 16 (enemy_shots) / Maske 9
  (player + player_shots — Laser können Bomben abschießen). Unabhängig vom
  werfenden Gegner — bleibt nach dessen Abschuss regulär gefährlich (kein
  eigener Code dafür nötig). Die eine Ausnahme: `game.gd::_process()` räumt
  seit der achten Playtest-Runde beim tatsächlichen Stage-Clear die ganze
  `enemy_shots`-Gruppe leer, damit längst geworfene Bomben nicht noch nach
  Levelende treffen können.
- `laser.gd` (`class_name Laser`) — Platzhalter-Strich im `_draw()`
  (laser.png raus), Layer 8, Hitbox 9×18 (sichtbarer Strahl bleibt 3 px
  schmal — großzügiger als er aussieht, Nutzer fand Treffen zu schwer;
  Sichtlänge seit der siebten Playtest-Runde auf 2/3 gekürzt,
  `BEAM_LEN`/`BEAM_HEAD_LEN`, die Hitbox selbst unangetastet). Seit
  2026-09-13 flasht `modulate` loopend zwischen Weiß und `accent_color`
  (`ACCENT_NORMAL` Türkis normal, `ACCENT_HYPER` Rot bei Hyper-Ammo — siehe
  „Vierte Playtest-Runde" und `ship.gd::activate_hyper_ammo()`), statt
  statisch reinweiß zu sein. `ship.gd::FIRE_COOLDOWN = 0.15` s (siebte
  Playtest-Runde) begrenzt zusätzlich zur Slot-Kapazität, wie schnell
  `shoot()` überhaupt erneut feuern darf.
- `bonus_item.gd` / `bonus_item.tscn` — Bonus-Sammelobjekt, fällt langsam,
  schwingt seit 2026-09-13 selbstständig über die **gesamte** Bildschirmbreite
  (`_base_x`/`_amplitude` aus der eigenen Viewport-Breite berechnet, nicht mehr
  von außen als Spawn-x übergeben — siehe „Dritte Playtest-Runde" für den
  Reihenfolge-Bug, der es vorher an den linken Rand klebte), Layer 2
  (collectibles) / Maske 9 (player + player_shots), zufälliges Icon aus 12 von
  16 `achievement_00..15.png` (5/6/7 und 1 ausgeschlossen), 500 Punkte, per
  Berührung oder Laser einsammelbar, `collected(points, icon, icon_index,
  at_position)`-Signal (Index für Hyper-Ammo-Erkennung, Position für
  `score_popup.gd`). `exclude_indices` (seit 2026-09-13, vor `add_child()`
  von `game.gd` gesetzt) verhindert doppelte Icons innerhalb einer HUD-Reihe
  — siehe „Sechste Playtest-Runde".
- `score_popup.gd` (neu, 2026-09-13) — schlichtes `Node2D` mit eigenem
  `_draw()` (kein `.tscn`, per `preload(...).new()` instanziiert), zeigt kurz
  "+N" an einer Weltposition, treibt nach oben, blendet aus,
  `queue_free()`. Nur für Bonus-Item-Pickups (`game.gd::
  _spawn_score_popup()`), nicht für Gegner-Kills.
- `ship_reconstruct.gd` / `ship_reconstruct.tscn` — einmalige „Schiff
  materialisiert sich"-Animation (`AnimatedSprite2D`, 28 Frames aus
  `ship-(re)construction.gif`), `build_done`-Signal, self-`queue_free()`.
  Läuft am Rundenstart und bei jedem Respawn (siehe `game.gd::
  _play_reconstruct()`).
- `ship_explosion.gd` / `ship_explosion.tscn` (neu, vierzehnte Playtest-Runde)
  — gleiches Muster wie `ship_reconstruct`: einmalige Explosions-Animation
  (`AnimatedSprite2D`, 4 Frames aus `assets/graphics/ship_explosion_f0..3.png`,
  ausgeschnitten aus `assets/explosion and laser.png`), `explosion_done`-Signal,
  self-`queue_free()`. Läuft bei einem echten Treffer (nicht beim
  Boss-Traktorstrahl-Fang) VOR jedem Reconstruct/Game-Over — siehe
  `game.gd::_on_ship_died()`/`_play_explosion()` und `ship.gd::_destroy()`s
  `show_explosion`-Parameter.
- `enemy_kinds.gd` (`class_name EnemyKinds`) — ZAKO/GOEI/BOSS: Radius, Punkte,
  Sprite-Textur + Skalierung (siehe „Erste echte Assets"). `pick_visual(kind,
  stage)` liefert ab Stage 2 statt der klassischen Textur eines von
  `GOEI_VARIANTS`/`ZAKO_VARIANTS`/`BOSS_VARIANTS` (Gyaraga-2-Frame-Paare,
  siehe „Zusätzliche Gegnertypen + Hilfe-Politur") — seit der neunten
  Playtest-Runde außerdem mit `variant_idx` (-1 = klassischer Look) im
  Rückgabe-Dictionary, für `enemy.gd`s Sprite-genaue Kill-Aufschlüsselung.
  `icon_texture(kind, variant_idx)` liefert dafür einen einzelnen
  Standbild-Pfad je Kombination (Frame 0 bei 2-Frame-Varianten).

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

1. **Zusätzliche Gegnertypen für spätere Stages/Bonuslevel** — GOEI/ZAKO
   (Stage 2+, je 2 Gyaraga-Varianten) und jetzt auch BOSS (1 Variante,
   `gorg-bos--damaged`) sind erledigt, siehe „Zusätzliche Gegnertypen +
   Hilfe-Politur" weiter oben. Noch offen: `enemy1.png` (falsche Palette,
   müsste erst neu koloriert/getrimmt werden) als vierter kanonischer Typ
   oder Bonuslevel-exklusiver Gegner — Umfang/Look weiterhin unbesprochen.
2. **Auf echten Geräten testen** (OPPO Find X2 Pro, OnePlus 12 ≈ 2,2:1;
   Galaxy S4 = 16:9): Aspect-Umschaltung, Touch-Drag, Pause-Button-Position,
   Formation-Größe. In beiden Ratios im echten Browser screenshotten.
   Canvas-Wechsel bliebe ein Einzeiler in `project.godot`.
3. **Hilfe vollständig bildbasiert** (optional) — die Ziel-Seite hat seit
   2026-09-12 eine Icon-Legende (siehe oben), die beiden Steuerungs-Seiten
   sind weiterhin reiner Text. tetris macht komplette Illustrationen per
   SVG→PNG (`assets/help_src/` + `render.sh`) — reicht vorerst als Text/Icon-Mix.
4. `assets/` aufräumen (lose Test-PNGs, Loot-System `item.gd`/`gem.tscn`/… —
   Galaga hat keins), HUD-Feinschliff, „1UP"-Flash beim Extra-Leben.
5. Später evtl.: Challenging/Bonus-Stage, Combo-Scoring, Auto-Fire als
   abschaltbares Setting, Diver/Bomben gegen die 960er-Canvas festnageln statt
   `get_viewport_rect()`. Fällt uns sicher noch mehr ein.
6. **Bonus-/Sammelobjekt-Mechanismus** — erledigt, siehe „Ship-Reconstruct-
   Intro/Respawn, Bonus-Sammelobjekte aus achivements.jpg" weiter oben
   (`bonus_item.gd`/`.tscn`, HUD-Reihe unten mittig). `enemy1.png` (falsche
   Palette) bleibt separat offen als möglicher vierter kanonischer Gegnertyp.
7. **Fehlende Soundeffekte für neue Mechanismen** (Nutzerwunsch 2026-09-12,
   "merke Dir, was Du zugefügt hast") — aktuell ohne eigenen Sound:
   - Der neue Splash-Screen (`menus.gd::show_splash()`) — kein Jingle beim
     Erscheinen.
   - Der Fang-Moment selbst (`capture_beam.gd`s `caught`-Signal) — es spielt
     nur das normale `dive`-Geräusch beim Abflug und `extra` erst bei der
     späteren Rettung; kein eigener „Schiff gefangen!"-Alarm.
   - Der Bonus-/Sammelobjekt-Mechanismus (`bonus_item.gd`) — läuft aktuell
     stumm bis auf den wiederverwendeten `extra`-Sound beim Einsammeln;
     bräuchte eigentlich einen eigenen, kurzen Pickup-Jingle.
   Nutzer sucht ggf. passende Sounds selbst (auch unter den ursprünglich
   kopierten OGGs, nicht nur den SFX-Rips) — bei Bedarf hier ergänzen und
   `sound_manager.gd`s `SOUNDS`/`ORDER` erweitern.
8. **Menü-Farbkonzept + Laser-Farbe** (Nutzer-Feedback 2026-09-12) —
   Outline-Farbe (Grün→Cyan) und Überschriften-Füllfarbe (Gelb→Weiß) erledigt
   (siehe „Dritte" bzw. „Fünfte Playtest-Runde"), Laser flasht seit
   „Vierte Playtest-Runde" Weiß/Türkis statt statisch reinweiß. Kein
   konkretes weiteres Detail vom Nutzer genannt — als vorerst abgeschlossen
   zu betrachten, bis neues Feedback kommt.
9. **`ship-warp-drive.gif` / `hyper-ammo.gif` / `cyclone-ammo.gif`** —
   vorhanden (siehe „Ship-Reconstruct-Intro/Respawn..." weiter oben für Maße).
   `ship-warp-drive.gif` war 2026-09-14 kurz als Übergangs-Animation vom
   Bonuslevel zur nächsten Stage eingebaut (`ship_warp.gd`/`.tscn`), aber
   noch am selben Tag nach Nutzer-Feedback („sieht für ein Doppelschiff nicht
   gut aus, und eigentlich auch nicht für ein einzelnes Schiff") wieder
   entfernt — siehe „Einundzwanzigste Playtest-Runde" unten. Einsatzzweck
   damit wieder offen, die GIF-Datei selbst liegt weiter unangetastet bereit.
   `hyper-ammo.gif`/`cyclone-ammo.gif` weiterhin ohne konkreten Plan. **Wichtig:
   nicht verwechseln** mit der am 2026-09-13 neu eingebauten
   Gameplay-Mechanik „Hyper-Ammo" (zwei eng nebeneinanderliegende Laserstrahlen
   nach `achievement_00`-Pickup, `ship.gd::activate_hyper_ammo()`) — die nutzt
   nur gezeichnete Laser-Strahlen, nicht diese Grafikdatei. Ob/wie
   `hyper-ammo.gif` selbst noch verwendet wird, bleibt offen.
10. **Hilfe-Seiten um mehr Grafik erweitern** (Nutzerwunsch 2026-09-13) —
    nächste Runde nach Prüfung des aktuellen Stands durch den Nutzer. Die
    Ziel-Seite hat seit 2026-09-12 schon eine Icon-Legende (Punkt 3 oben), die
    beiden Steuerungs-Seiten sind weiterhin reiner Text.
11. **Bonuslevel mit mehreren Gegner-Wellen** — erledigt, siehe „Neunzehnte
    Playtest-Runde" für den ursprünglichen Stand und die dabei selbst
    getroffenen Design-Entscheidungen (Gegnerfeuer, Punkte, Konsequenz eines
    verpassten Durchlaufs), UND „Zwanzigste Playtest-Runde" für den nach dem
    ersten echten Spieltest korrigierten, aktuell gültigen Stand (echter
    Hänger-Bug behoben, Bewegung jetzt senkrechte Spalte statt Seitwärts-
    Formation, kein Boss mehr) — beides zusammen ergibt den vollen,
    aktuellen Stand, nicht mehr offen.
12. **Lautstärke-Defaults nachziehen** — erledigt, siehe „Sechsundzwanzigste
    Playtest-Runde" unten für den vollen Stand (alle 15 `base_db`-Werte
    kalibriert, einheitlicher 50-%-Default, `CALIB_VERSION` hochgezählt).
13. **Landscape-Letterbox-Bilder für Geräte ohne Hochkant** — erledigt und
    live auf dem echten Anbernic RG552 verifiziert (siehe „Siebenundzwanzigste"
    + „Achtundzwanzigste Playtest-Runde" oben — `arcade_shell.gd`/`.tscn`,
    jetzt `run/main_scene`). Bewusst nicht auf das eine Gerät eingegrenzt:
    gilt jetzt für jedes Fenster, das breiter als hoch ist (Desktop
    eingeschlossen), auf Nutzerwunsch. `arcade-screen2.png` liegt weiterhin
    als unbenutzte Alternative bereit, falls `arcade-screen1.png` sich
    später doch nicht bewährt.

## Aseprite MCP Pro

Bei Nutzung der Aseprite-MCP-Pro-Tools (`mcp__aseprite-mcp-pro__*`) dem
Pixel-Art-Skill-Guide folgen:
@/home/bernd/GodotDev/learn_2d_gamedev_godot_4_0.57.0_linux/aseprite-mcp-pro-server/skills.md
