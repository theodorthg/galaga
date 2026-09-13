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

## Gameplay-Architektur (alles im Code, wie tetris)

Main-Scene `game.tscn` (Node2D `Game` + `game.gd`): SpaceBackground, Formation,
StageDirector, Ship, HUD-CanvasLayer.

- `game.gd` (`class_name Game`) — State-Machine TITLE → READY → ENTERING →
  FORMATION → GAME_OVER + `_paused`. `_new_run()` (aus Titel/„Nochmal"): liest
  `GameSettings`, setzt Leben/Extra-Leben-Schwelle, `_director.configure(...)`
  aus der Schwierigkeit, räumt das Feld (`_clear_board`), entpausiert, Musik an,
  spielt die Ship-Reconstruct-Animation + „BEREIT"-Banner (`_play_reconstruct()`)
  bevor das Schiff überhaupt erscheint. Ship `died` → Reserve-Check (siehe
  globale Leben-Anzeige-Regel) → bei Rest: Reconstruct-Animation statt reinem
  Timer-Wait, dann `respawn()`; bei 0 → GAME_OVER (1 s Delay, dann
  `menus.show_game_over`, Tree pausiert). Während `FORMATION` außerdem alle
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
  `show_game_over(score, stage, won=true)`, sobald `GameSettings.win_score`
  erreicht ist (0 = aus). `achievement_00`-Pickup → `ship.activate_hyper_ammo()`
  (siehe „Vierte Playtest-Runde").
- `hud.gd` (`class_name Hud`) — **nur noch das In-Game-HUD**: Score (oben links),
  Stage (unten rechts), Leben unten links (`_draw`, echte `player_trim.png`-
  Sprites statt Platzhalter-Dreiecke; ab `MANY_THRESHOLD = 5` ein Icon + „× N"
  statt wachsender Reihe — `_lives` ist die Reserve, siehe `game.gd`),
  Center-Banner, Pause-Button oben rechts (seit 2026-09-13 immer sichtbar/
  mausklickbar statt nur auf Touch-Geräten, mit eigenem Milchglas-Hintergrund
  via `_add_pause_glass()` — siehe „Fünfte Playtest-Runde"), Signal
  `pause_pressed`,
  `set_playing(on)` blendet das ganze HUD bei offenem Menü aus. Titel / Pause /
  Settings / Game-Over macht jetzt `menus.gd`. Bonus-Icon-Reihe unten mittig
  (`BONUS_MAX_SHOWN = 7`, `add_bonus_icon()` liefert `true` zurück, sobald eine
  Reihe voll ist; `_bonus_laps` + `_draw_lap_marker()` zeigen dann einen
  goldenen „× N"-Rundenzähler daneben, siehe „Dritte Playtest-Runde").
  `_bonus_icon_indices` (parallel zu `_bonus_icons`, seit 2026-09-13) +
  `current_lap_indices()` lassen `bonus_item.gd` Duplikate innerhalb einer
  Reihe ausschließen (siehe „Sechste Playtest-Runde").
- `menus.gd` (`class_name Menus`, eigener `CanvasLayer` in `game.tscn`,
  `process_mode = ALWAYS`) — alle Menü-Screens im Code wie tetris' `ui.gd`:
  Titel, Pause, Einstellungen (`_add_stepper()` hängt Name/</Wert/>-Zellen
  seit 2026-09-13 flach in ein gemeinsames `GridContainer` statt je Zeile
  einen eigenen `HBoxContainer` zu bauen — sonst richten sich `</>` nicht
  spaltenweise aus, siehe „Sechste Playtest-Runde"; Stepper: Leben /
  Extra-Leben / Boss alle X Punkte / Sieg bei X Punkten / Max. Schüsse /
  Schwierigkeit), Sound-Unterseite (HSlider pro Sound,
  Loslassen = Vorhören), Hilfe (3 Textseiten mit ‹/›), Game-Over +
  Hall-of-Fame-Liste + Namenseingabe bei Qualifikation. Signale `start_game` /
  `resume_game` / `to_title` / `settings_changed`. „Beenden" nur wenn nicht
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
  `stop_attacks()` beim Stage-Wechsel. Reicht `enemy_killed(points)` und
  `ship_rescued` durch.
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
- **Boss-Capture** (`enemy.gd` + `capture_beam.gd`/`.tscn` + `attack_paths.gd`s
  `capture_approach()`): Boss hovert statt durchzufliegen (CAPTURE_APPROACH),
  lässt `capture_beam.tscn` herab (grüner Strahl, wächst/hält/zieht sich
  zurück, Gruppe `"enemy_shots"` — zerstört das Schiff über den schon
  bestehenden Kollisions-Code in `ship.gd`, kein Sonderfall nötig). Trifft der
  Strahl (`caught`-Signal), wird `_carrying_captive` **sofort im Signal-Handler**
  gesetzt (nicht erst nach Ablauf des Beam-Timers, siehe
  „Boss-Capture-Race-Condition (Teil 2)") und der Boss trägt eine
  `ship_captured.png`-Sprite als Kind-Node zurück in die Formation (folgt
  Position/Rotation automatisch).
  Wird genau dieser Boss später zerstört (`_explode()`), feuert er
  `ship_rescued` — `game.gd::_on_ship_rescued()` macht daraus
  `ship.become_twin()`: zweites Schiff+Triebwerk (Duplikat, `TWIN_OFFSET=34`),
  doppelte Laser-Kapazität, ein Treffer beendet den Bonus wieder
  (`_destroy() -> _revert_twin()`). Max. ein gefangenes Schiff gleichzeitig.
- `bomb.gd` / `bomb.tscn` — Gegner-Schuss, fällt (leicht Richtung Spieler-x zum
  Abwurfzeitpunkt), Platzhalter-Raute. Layer 16 (enemy_shots) / Maske 9
  (player + player_shots — Laser können Bomben abschießen).
- `laser.gd` (`class_name Laser`) — Platzhalter-Strich im `_draw()`
  (laser.png raus), Layer 8, Hitbox 9×18 (sichtbarer Strahl bleibt 3 px
  schmal — großzügiger als er aussieht, Nutzer fand Treffen zu schwer). Seit
  2026-09-13 flasht `modulate` loopend zwischen Weiß und `accent_color`
  (`ACCENT_NORMAL` Türkis normal, `ACCENT_HYPER` Rot bei Hyper-Ammo — siehe
  „Vierte Playtest-Runde" und `ship.gd::activate_hyper_ammo()`), statt
  statisch reinweiß zu sein.
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
- `enemy_kinds.gd` (`class_name EnemyKinds`) — ZAKO/GOEI/BOSS: Radius, Punkte,
  Sprite-Textur + Skalierung (siehe „Erste echte Assets"). `pick_visual(kind,
  stage)` liefert ab Stage 2 statt der klassischen Textur eines von
  `GOEI_VARIANTS`/`ZAKO_VARIANTS`/`BOSS_VARIANTS` (Gyaraga-2-Frame-Paare,
  siehe „Zusätzliche Gegnertypen + Hilfe-Politur").

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
   vorhanden (siehe „Ship-Reconstruct-Intro/Respawn..." weiter oben für Maße),
   Einsatzzweck noch offen, Nutzer will sich das später überlegen. **Wichtig:
   nicht verwechseln** mit der am 2026-09-13 neu eingebauten
   Gameplay-Mechanik „Hyper-Ammo" (zwei eng nebeneinanderliegende Laserstrahlen
   nach `achievement_00`-Pickup, `ship.gd::activate_hyper_ammo()`) — die nutzt
   nur gezeichnete Laser-Strahlen, nicht diese Grafikdatei. Ob/wie
   `hyper-ammo.gif` selbst noch verwendet wird, bleibt offen.
10. **Hilfe-Seiten um mehr Grafik erweitern** (Nutzerwunsch 2026-09-13) —
    nächste Runde nach Prüfung des aktuellen Stands durch den Nutzer. Die
    Ziel-Seite hat seit 2026-09-12 schon eine Icon-Legende (Punkt 3 oben), die
    beiden Steuerungs-Seiten sind weiterhin reiner Text.

## Aseprite MCP Pro

Bei Nutzung der Aseprite-MCP-Pro-Tools (`mcp__aseprite-mcp-pro__*`) dem
Pixel-Art-Skill-Guide folgen:
@/home/bernd/GodotDev/learn_2d_gamedev_godot_4_0.57.0_linux/aseprite-mcp-pro-server/skills.md
