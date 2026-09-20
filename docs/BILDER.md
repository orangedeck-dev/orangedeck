# Bilder: was gebraucht wird, und woher

Zum Abhaken. Drei Stellen wollen Bilder, mit verschiedenen Regeln.

## A. Verzeichnis von DMS -- ein Bild

| | |
|---|---|
| Ablage | `shell/dms/assets/screenshot.png` (der Erzeuger nimmt `assets/` mit) |
| Groesse | **beliebiges Seitenverhaeltnis**, 1280x720 oder 1280x800 passt |
| Inhalt | Popout offen, echte Daten, Feed mit Halde |
| Thema | **Standard-Thema von DMS** (dank purple) |
| Sprache | Englisch |

**Nicht 960x540.** Das Verzeichnis baut die Karte selbst und legt das Bild
mittig auf einen weichgezeichneten Grund, ohne zu beschneiden; die fertige
Karte holt man unter `https://api.danklinux.com/previews/orangedeck` ab. Aus
`CONTRIBUTING.md` des Registry: *"Screenshots of any aspect ratio work well --
the card letterboxes them over a blurred backdrop rather than cropping.
Capture your plugin in a representative state (popout open, real data visible)
on the default dank purple theme where possible."*

Der Eintrag `packaging/dms-registry/orangedeck-dev-orangedeck.json` zeigt mit
einer Roh-URL auf `assets/screenshot.png` im Plugin-Repo. Das Bild muss also
**vor** dem Push dort liegen, sonst prueft `validate_links.py` ins Leere.

Nicht drauf: die eigene Leiste mit fremden Plugins, Wallet-Zahlen,
Miner-Namen, Namen von Arbeitsflaechen.

## B. README des Plugin-Repos -- freiwillig, zwei bis drei

Gleiche Regeln wie A, Groesse frei. Sinnvoll: Kontrollzentrum-Kachel
aufgeklappt, Desktop-Widget frei auf dem Desktop, Leiste mit der Pille in
Grossaufnahme -- die drei Orte, an denen das Plugin sitzt.

## C. F-Droid-Eintrag -- drei bis fuenf

| | |
|---|---|
| Ablage | `packaging/fdroid/metadata/dev.orangedeck.OrangeDeck/en-US/phoneScreenshots/1.png`, `2.png`, ... |
| Groesse | was das Geraet liefert, Hochformat, alle gleich |
| Inhalt | 1 Feed, 2 Blockuhr, 3 Mining, 4 Explorer, 5 Markt |
| Sprache | Englisch, Waehrung USD |

Der Pfad stimmt: `fdroidserver/update.py` kennt
`SCREENSHOT_DIRS = ('phoneScreenshots', ...)` und durchsucht dafuer
ausdruecklich `metadata/<paket>/<locale>/`. `tools/fdroid-repo.sh` verlinkt
`packaging/fdroid/metadata` als `metadata`, `fdroid update` nimmt die Bilder
also von selbst mit -- ohne Aenderung am Skript.

Nicht drauf: die eigene Statusleiste (Uhrzeit, Akku, VPN, Benachrichtigungen),
watch-only-Adressen, Miner aus dem eigenen Netz.

## Wie aufnehmen

**Fuer A und B: der Probestand**, nicht die eigene Shell -- dort ist das
Standard-Thema, eine leere Leiste, Englisch und keine eigenen Daten:

    tools/dms-probe.sh neu        # Plugin erzeugen, frisches HOME anlegen
    tools/dms-probe.sh start      # geschachtelte Sitzung, Fenster auf dem Schirm
    tools/dms-probe.sh popout     # Popout auf
    tools/dms-probe.sh bild ~/bild.png
    tools/dms-probe.sh ende

Die eigene Sitzung bleibt dabei unberuehrt. Das Fenster laesst sich wie jedes
andere bedienen -- Reiter wechseln, Einstellungen oeffnen, Ansicht waehlen.

**Fuer B muss das Desktop-Widget von Hand hingelegt werden**: der Eintrag in
`settings.json` legt die Instanz an, ihre Lage und Groesse bestimmt man im
Probestand selbst (Kontrollzentrum, Desktop-Widgets).

**Fuer C: das Galaxy.**

    adb exec-out screencap -p > 1.png

Statusleiste vorher in den Vorfuehrmodus:

    adb shell settings put global sysui_demo_allowed 1
    adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 1000
    adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false
    adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false
    # hinterher:
    adb shell am broadcast -a com.android.systemui.demo -e command exit
