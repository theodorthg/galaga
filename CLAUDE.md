# CLAUDE.md — Galaga

Ergänzt die übergeordnete `CLAUDE.md` unter
`~/GodotDev/learn_2d_gamedev_godot_4_0.57.0_linux/`.

**Stand: v0.1.0 — Scaffolding.** Projekt-Infrastruktur steht (project.godot auf
GL-Compat + vollständige Input-Map, `export_presets.cfg`, Keystores, `build.sh`,
`_selftest.gd`, CI, Git/GitHub). Gameplay ist noch der halb migrierte
GDQuest-Twin-Stick-Rest + draufgeworfenes Galaga-Asset-Pack (chalaka.itch.io).
Der eigentliche Galaga-Ausbau hat noch nicht begonnen.

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
2. **`splash-screen.png`** (Bindestrich, Wurzelverzeichnis) fehlt noch —
   vom Nutzer liefern lassen oder generieren, dann als Boot-Splash + Ladescreen
   einbinden.
7. **Sprites vom Nutzer** — kommen nach, je Einheit **mind. 2 Frames als
   Animation**, evtl. als `.gif`. Pipeline: `.gif` → Aseprite-MCP
   (`open_sprite`/Frames extrahieren) → `export_sprite_sheet` bzw.
   `generate_spriteframes_tres` → `SpriteFrames` in Godot. Bis dahin die
   Bestands-Sprites (`assets/Images/`) als Platzhalter nutzen.
3. Laufzeit-`content_scale_aspect`-Umschaltung (Desktop KEEP / Touch KEEP_WIDTH).
4. Galaga-Gameplay von vorn: Formation, Einflug, Sturzflüge, Gegnerfeuer, Wellen.
5. Menüs + Settings + `sound_manager.gd` nach pacman-Muster.
6. `assets/` aufräumen, `ship_count` → echte 3 Leben, HUD responsiv.

## Aseprite MCP Pro

Bei Nutzung der Aseprite-MCP-Pro-Tools (`mcp__aseprite-mcp-pro__*`) dem
Pixel-Art-Skill-Guide folgen:
@/home/bernd/GodotDev/learn_2d_gamedev_godot_4_0.57.0_linux/aseprite-mcp-pro-server/skills.md
