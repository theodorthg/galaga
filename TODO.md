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
- [x] 2026-10-05 LAN-Coop RG552 (Android, v1.2.1) ↔ Linux-PC in beide Richtungen
      getestet: Hostliste findet den Host, Verbinden, Touch-Steuerung des Gasts
      (Feuer + Ziehen), Pause des Gasts, Ergebnis-Bildschirm beim Gast. Alles ok.
- [x] 2026-10-05 Online-Coop vom Nutzer im Browser/auf itch.io getestet (klappt;
      die „alte Fassung“ war eine Verwechslung der Versionen). Relay: Meldungen
      spielneutral, Raumtrennung auf dem echten Server geprüft.
- [x] 2026-10-05 Netz-Coop: LAN (Claude, RG552 ↔ PC) und Online (Nutzer) getestet;
      Triebwerksflamme + gemeinsame Pause beim Gast (v1.2.1), grünes P2-Schiff
      von Anfang an (v1.2.2), Gast-Hinweistext (v1.2.3).

- [ ] Lokaler Coop mit zwei Bluetooth-DPad-Controllern (Nutzer besorgt einen
      zweiten): prüfen, ob zwei gleiche Pads (gleiche Tastencodes) sauber
      getrennt werden — erst von Android (zwei Geräte-IDs?), dann vom Spiel
      (Beitreten-Bildschirm ordnet per `event.device` zu, `CoopInput.build()`
      bindet je Pad die Aktionen `p1_*`/`p2_*`). Zu beobachten: ändert sich die
      Geräte-ID nach Wiederverbinden/Neustart, melden D-Pad und Knöpfe
      verschiedene IDs (wie beim RG552), steuert ein Pad beide Schiffe.
      Diagnose bei Problemen: Debug-Autoload mit `adb logcat` wie in der
      globalen CLAUDE.md (Punkt 17) beschrieben.

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
