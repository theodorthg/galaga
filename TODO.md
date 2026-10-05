# TODO — galaga

Offene Punkte sammeln und abhaken (gilt über Kontextwechsel hinaus; siehe
globale CLAUDE.md „TODO.md pro Projekt“). Neueste Einträge oben. Ältere
offene Punkte stehen ggf. noch in `CLAUDE.md`.

## Offen

- [ ] Alte, von Hand hochgeladene Dateien auf itch.io löschen (macht der Nutzer: https://itch.io/game/edit/…, Seite `galaga-clone`) und beim Upload des Channels `web` „This file will be played in the browser“ setzen.

Mehrspieler (Einschätzung 2026-10-03; lokal umgesetzt am 2026-10-03, Rest offen):
- [x] 2 Spieler abwechselnd (wie der Automat) — Einstellung „Players: 2 (turns)“,
      siehe CLAUDE.md „Fünfunddreißigste Playtest-Runde“. Noch nicht auf
      Gerät/von Hand gespielt, nur headless geprüft.
- [x] Coop gleichzeitig am selben Gerät (zwei Schiffe, gemeinsamer Schwarm und
      Punktestand, eigene Leben je Spieler, Befreien durch den Partner) —
      Einstellung „Players: 2 (co-op)“ + Beitreten-Bildschirm. Nur headless
      geprüft, noch nicht live gespielt.
- [x] 2026-10-05 Coop und Abwechseln im Editor live gespielt (Schiffe, HUD, Wechsel
      „PLAYER 2“): ohne Auffälligkeit. Mit zwei Menschen noch nicht.
- [ ] Coop mit zwei Menschen nachjustieren (Tastenbelegung, Schiff-Farbe P2,
      HUD-Reihen, ob ein verlorenes Schiff im Bonuslevel den Level beenden soll).
- [x] 2026-10-05 Hilfe-Seite „2 Players“ (coop.svg/coop.png) ergänzt.
- [x] 2026-10-05 Coop per LAN und Online (v1.2.0): Host rechnet, Gast zeigt,
      siehe CLAUDE.md „Sechsunddreißigste Playtest-Runde“. Headless mit zwei
      Prozessen geprüft (LAN-Loopback, lokales und echtes Relay); mit echten
      Geräten (Handy/RG552/zwei PCs) noch nicht.
- [ ] Netz-Coop auf echten Geräten testen: LAN zwischen zwei Rechnern/Handy,
      Online über das Mobilnetz; Verzögerung/Ruckeln beurteilen (Schnappschüsse
      25/s, Glättung `SMOOTH` in `net_guest.gd`). Bekannte Lücken: keine
      Triebwerksflamme beim Gast; Gast hat keine eigene Pause (nur „Leave“).

Gemeinsam für die Serie (Vorlage: mario-clone v1.6–v1.9):
- [ ] Bausteine aus mario-clone übernehmen statt neu erfinden: `CoopInput`
      + Beitreten-Bildschirm (jeder drückt A auf seinem Gerät),
      `NetLink`/`NetHost`/`NetClient` (Host rechnet, Gast zeigt; LAN +
      Online), Team-Eintrag in der Bestenliste, Spielstand/Continue,
      F12-Screenshot.
- [x] Ein Relay für alle Spiele: Spiel-Kennung `"g"` gibt es längst (Galaga
      sendet `"galaga"`); am 2026-10-05 gegen das echte Relay getestet.
- Hinweise: Hochkant-Spiele auf dem Handy zu zweit nur per Netz (zwei
  Leute an einem Handy-Bildschirm ist unpraktisch); lokal zu zweit am PC
  (geteilte Tastatur / zwei Pads) bzw. im Browser. Das RG552 kann wegen
  des kaputten Bluetooth kein zweites Pad.

## Erledigt

- [x] 2026-09-29 itch.io jetzt per `butler` in die Channels linux / android / windows / web (`theodorthg/galaga-clone`, wie bei mario-clone)
- [x] 2026-09-27 RG552: alte, anders signierte Galaga-Version auf
      Nutzerwunsch deinstalliert, release-Build installiert (APK im
      Download-Ordner aktualisiert).
- [x] 2026-09-27 Android-System-Startbildschirm (vor dem Splash) einheitlich
      reines Weiß: `splash_screen/icon` = transparentes
      `assets/icon/android_splash_blank.png`, `branding_image` leer (Nutzer-
      wunsch, ohne Gradle-Build; Hintergrundfarbe ließe sich nur per Gradle
      ändern).
