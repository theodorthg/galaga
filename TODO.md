# TODO — galaga

Offene Punkte sammeln und abhaken (gilt über Kontextwechsel hinaus; siehe
globale CLAUDE.md „TODO.md pro Projekt“). Neueste Einträge oben. Ältere
offene Punkte stehen ggf. noch in `CLAUDE.md`.

## Offen

- [ ] RG552: installierte Galaga-Version ist anders signiert (debug) als
      der release-Build → `adb install -r` scheitert
      (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`). Nutzer fragen: deinstallieren
      (löscht Einstellungen/Highscores auf dem Gerät) und neu installieren?

## Erledigt

- [x] 2026-09-27 Android-System-Startbildschirm (vor dem Splash) einheitlich
      reines Weiß: `splash_screen/icon` = transparentes
      `assets/icon/android_splash_blank.png`, `branding_image` leer (Nutzer-
      wunsch, ohne Gradle-Build; Hintergrundfarbe ließe sich nur per Gradle
      ändern).
