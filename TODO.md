# TODO — galaga

Offene Punkte sammeln und abhaken (gilt über Kontextwechsel hinaus; siehe
globale CLAUDE.md „TODO.md pro Projekt“). Neueste Einträge oben. Ältere
offene Punkte stehen ggf. noch in `CLAUDE.md`.

## Offen

- [ ] Alte, von Hand hochgeladene Dateien auf itch.io löschen (macht der Nutzer: https://itch.io/game/edit/…, Seite `galaga-clone`) und beim Upload des Channels `web` „This file will be played in the browser“ setzen.

Ideen für später (Einschätzung 2026-10-03, noch nicht beauftragt):
- [ ] 2 Spieler abwechselnd (wie der Automat): günstig, eigene Leben und
      Stage pro Spieler, Wechsel bei Lebensverlust.
- [ ] Coop gleichzeitig: zwei Schiffe nebeneinander, gemeinsamer
      Gegnerschwarm, Gegner zielen auf das nächste Schiff. Reizvoll: wird
      ein Schiff vom Traktorstrahl gefangen, kann der PARTNER es befreien
      (statt nur der Spieler selbst). Doppelschiff dann nur für den
      Befreiten. Eigene Leben, Team-Bestenliste.
- [ ] Coop per LAN/Online nach dem mario-clone-Prinzip (Snapshots der
      Schiffe/Gegner/Schüsse — wenige, kleine Objekte).
- Empfehlung: lohnt sich — Galaga ist der natürlichste Kandidat für Coop.

Gemeinsam für die Serie (Vorlage: mario-clone v1.6–v1.9):
- [ ] Bausteine aus mario-clone übernehmen statt neu erfinden: `CoopInput`
      + Beitreten-Bildschirm (jeder drückt A auf seinem Gerät),
      `NetLink`/`NetHost`/`NetClient` (Host rechnet, Gast zeigt; LAN +
      Online), Team-Eintrag in der Bestenliste, Spielstand/Continue,
      F12-Screenshot.
- [ ] Ein Relay für alle Spiele: `server/relay.js` um eine Spiel-Kennung
      in „host“/„join“ erweitern (sonst landet ein Galaga-Gast in einem
      Mario-Raum), Pfad bleibt `wss://broesel.net/mario-relay` oder ein
      neutraler Name.
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
