#!/usr/bin/env bash
# Die Pruef-VM aufbauen und starten.
#
# **Warum es das Skript gibt.** Am 04.09.2026 wurde die VM von Hand
# zusammengesetzt, und alles lag im Kratzverzeichnis der Sitzung: die
# 12-GB-Platte, die Buendel, die ISO. Einen Tag spaeter war nichts davon mehr
# da -- dieselbe Ursache, die auch `tools/vm.py` auf einen toten Pfad zeigen
# liess. Was man wieder braucht, muss man wieder herstellen koennen, ohne es
# aus einem Fliesstext zu rekonstruieren.
#
# Alles landet unter $ORANGEDECK_VM_DIR (Vorgabe ~/.cache/orangedeck-vm),
# demselben Ort, den `tools/vm.py` fuer den Monitor-Sockel nimmt.
#
#     tools/pruefvm.sh bauen     Buendel, Daten-ISO und Platte herstellen
#     tools/pruefvm.sh starten   QEMU starten (ohne Fenster, Monitor am Sockel)
#     tools/pruefvm.sh anhalten  QEMU beenden
#     tools/pruefvm.sh gast      die Schritte *im* Gast ausgeben
#
# Danach steuert `tools/vm.py` den Gast: Tasten senden, Bilder holen.
#
# **Was das Skript nicht tut, und lange so aussah, als taete es das.** Es
# stellt den Wirt wieder her, nicht den Gast. Eine Live-Sitzung vergisst nach
# jedem Neustart alles: das nachinstallierte flatpak, das geladene
# AppArmor-Profil, beide Einhaengungen. Am 08.09.2026 hat dasselbe Wissen
# zweimal dieselben zwei Minuten gekostet, weil es in keiner Datei stand,
# sondern in drei Absaetzen der DOKUMENTATION verteilt lag. `gast` gibt es
# jetzt am Stueck aus -- in der Reihenfolge, in der es gebraucht wird.
set -euo pipefail

VM="${ORANGEDECK_VM_DIR:-$HOME/.cache/orangedeck-vm}"
ISO="${ORANGEDECK_VM_ISO:-$HOME/VMs/ubuntu-24.04.4.iso}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# **Die Live-Sitzung schreibt in den RAM.** Deshalb liegt der Flatpak-Bestand
# im Gast auf dieser Platte, nicht im Overlay -- siehe DOKUMENTATION,
# "Pruefen in einer Live-Sitzung".
PLATTE_GB="${ORANGEDECK_VM_DISK_GB:-12}"
RAM_MB="${ORANGEDECK_VM_RAM_MB:-2560}"

# **Auch `daten/`.** Das Skript soll aus dem Nichts laufen; es tat es nicht.
# Am 05.09.2026 nach dem Loeschen des Verzeichnisses gescheitert, mit
# einem `opendir`-Fehler von xorriso -- also genau daran, wogegen es
# geschrieben wurde: etwas, das sich nicht wiederherstellen laesst.
mkdir -p "$VM/daten"

bauen() {
    echo "== Anwendung buendeln =="
    local bau="$VM/bau"
    rm -rf "$bau" "$VM/repo"
    # **Der Bauplan zum Ausliefern baut den festgenagelten Commit**, nicht das
    # Arbeitsverzeichnis. Am 25.09.2026 lief so ein Fedora-Test fuer einen
    # Fix, der erst nach 0.2.12 kam, gegen 0.2.12 -- und meldete den Fehler
    # als noch vorhanden. Wer ungepushte oder unveroeffentlichte Aenderungen
    # pruefen will, setzt ORANGEDECK_VM_BAUPLAN=dev.
    local plan="dev.orangedeck.OrangeDeck.yml"
    [ "${ORANGEDECK_VM_BAUPLAN:-}" = "dev" ] && plan="dev.orangedeck.OrangeDeck.dev.yml"
    echo "   Bauplan: $plan"
    flatpak-builder --user --repo="$VM/repo" --force-clean --disable-cache \
        --state-dir="$VM/state" "$bau" \
        "$REPO/packaging/flatpak/$plan"
    flatpak build-bundle "$VM/repo" "$VM/daten/orangedeck.flatpak" \
        dev.orangedeck.OrangeDeck \
        --runtime-repo=https://flathub.org/repo/flathub.flatpakrepo

    # **Die Laufzeit muss mit.** Im Gast bricht die Netzverbindung zu Flathub
    # reihenweise ab, und ohne die GL-Erweiterung startet die Anwendung mit
    # "Could not initialize GLX" -- wer von Flathub installiert, bekommt sie
    # automatisch, ein Buendel bringt sie nicht mit.
    echo "== Laufzeit und GL-Erweiterung buendeln =="
    flatpak build-bundle --runtime ~/.local/share/flatpak/repo \
        "$VM/daten/kde-platform-6.9.flatpak" org.kde.Platform 6.9 \
        --runtime-repo=https://flathub.org/repo/flathub.flatpakrepo
    flatpak build-bundle --runtime ~/.local/share/flatpak/repo \
        "$VM/daten/gl-default-24.08.flatpak" org.freedesktop.Platform.GL.default 24.08 \
        --runtime-repo=https://flathub.org/repo/flathub.flatpakrepo

    # Die Pruefsummen wandern mit auf die ISO: im Gast wird gegengehalten,
    # bevor man dem Ergebnis glaubt.
    ( cd "$VM/daten" && sha256sum ./*.flatpak > PRUEFSUMMEN.txt )
    echo "== Daten-ISO =="
    xorriso -as mkisofs -V ORANGEDECK -J -r -o "$VM/daten.iso" "$VM/daten"
    echo "== Platte =="
    [ -f "$VM/vmdisk.qcow2" ] || qemu-img create -f qcow2 "$VM/vmdisk.qcow2" "${PLATTE_GB}G"
    ls -la "$VM"/daten.iso "$VM"/vmdisk.qcow2
}

starten() {
    [ -f "$ISO" ] || { echo "Keine Ubuntu-ISO unter $ISO (ORANGEDECK_VM_ISO setzt den Pfad)"; exit 1; }
    [ -f "$VM/daten.iso" ] || { echo "Keine Daten-ISO -- erst 'tools/pruefvm.sh bauen'"; exit 1; }
    rm -f "$VM/mon.sock" "$VM/qmp.sock"
    # **Das Tablett von Anfang an, nicht nachgesteckt** -- und die Frage, die
    # hier bis zum 08.09.2026 als offen stand, ist seit dem 06.09. gemessen
    # und beantwortet: **es hilft nicht.**
    #
    #     (qemu) info mice
    #         Mouse #2: QEMU PS/2 Mouse
    #         Mouse #5: vmmouse (absolute)
    #       * Mouse #3: QEMU HID Tablet (absolute)
    #     (qemu) mouse_move 128 113
    #       -> der Zeiger bleibt, wo er war
    #
    # Das Tablett ist da, es ist aktiv, es ist absolut -- und `mouse_move`
    # bewegt trotzdem nichts. Von Anfang an eingehaengt statt nachgesteckt
    # aendert daran nichts; damit sind es sieben erfolglose Konfigurationen.
    #
    # **Der achte Weg geht: QMP `input-send-event`** (15.09.2026). Deshalb
    # `-qmp` neben dem Monitor. `mouse_move` schickt relative Schritte, das
    # aktive Geraet ist aber das absolute Tablett; QMP setzt dessen Achsen
    # direkt, 0 bis 32767. Gemessen im Willkommensdialog von Ubuntu 24.04:
    # `vm.klick(618, 336)` auf "Deutsch", der Zeiger stand genau dort, und
    # der Dialog schaltete auf Deutsch. `tools/vm.py` hat dafuer `zeiger()`
    # und `klick()`. Zahnrad, Liquidationen und Heatmap sind damit auch
    # unter Linux erreichbar; das Zahnrad ab dem Stand vom 15.09.2026 auch
    # ueber `,`.
    #
    # Was am Finger haengt (Kneifen, Wischen), prueft weiterhin nur ein
    # echtes Geraet.
    #
    # **Zwei Laufwerke von Anfang an.** Am 04.09. wurde das Medium im Betrieb
    # getauscht; der Gast lieferte danach weiter den alten Inhalt aus dem
    # Cache, `ls` zeigte schon den neuen Namen. Wer beide ISOs gleich
    # einhaengt, hat die Falle nicht.
    qemu-system-x86_64 -enable-kvm -m "$RAM_MB" -smp 2 -cpu host \
        -drive file="$ISO",media=cdrom,readonly=on \
        -drive file="$VM/daten.iso",media=cdrom,readonly=on \
        -drive file="$VM/vmdisk.qcow2",if=virtio,format=qcow2 \
        -vga std -display none \
        -device qemu-xhci,id=xhci -device usb-tablet,bus=xhci.0 \
        -monitor "unix:$VM/mon.sock,server,nowait" \
        -qmp "unix:$VM/qmp.sock,server,nowait" \
        -netdev user,id=n0 -device virtio-net-pci,netdev=n0 -boot d \
        > "$VM/qemu.log" 2>&1 &
    echo $! > "$VM/qemu.pid"
    echo "QEMU gestartet (PID $(cat "$VM/qemu.pid")), Monitor: $VM/mon.sock"
    echo "Steuern mit tools/vm.py -- der nimmt denselben Ort."
}

# **Ueber die notierte PID, nicht ueber ein Muster.** `pgrep -f` durchsucht
# ganze Befehlszeilen und findet dabei auch die Zeile, in der es selbst
# steht -- die Pruefung meldet dann "laeuft noch", waehrend nichts mehr
# laeuft. Am 05.09.2026 genau so passiert, und die Fehldiagnose sah aus wie
# eine haengende VM.
anhalten() {
    local pid=""
    [ -f "$VM/qemu.pid" ] && pid="$(cat "$VM/qemu.pid")"
    # Erst sauber ueber den Monitor, dann erst mit Gewalt.
    # Ueber Python, nicht ueber socat: das ist hier nicht installiert, und
    # `tools/vm.py` setzt Python ohnehin voraus.
    if [ -S "$VM/mon.sock" ]; then
        python3 -c 'import socket,sys
s=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM)
s.settimeout(5)
s.connect(sys.argv[1]); s.sendall(b"quit\n"); s.close()' "$VM/mon.sock" >/dev/null 2>&1 || true
    fi
    for _ in 1 2 3 4 5; do
        laeuft "$pid" || { rm -f "$VM/qemu.pid"; echo "angehalten"; return 0; }
        sleep 1
    done
    [ -n "$pid" ] && kill "$pid" 2>/dev/null || true
    sleep 2
    if laeuft "$pid"; then
        echo "laeuft weiterhin (PID $pid) -- von Hand nachsehen"
        return 1
    fi
    rm -f "$VM/qemu.pid"
    echo "angehalten"
}

laeuft() {
    [ -n "$1" ] && kill -0 "$1" 2>/dev/null
}

# **Die Schritte im Gast.** Jeder einzelne davon ist auf Ubuntus Live-Sitzung
# nach einem Neustart wieder faellig; keiner laesst sich vom Wirt aus
# vorwegnehmen. Getippt wird ueber `tools/vm.py` Taste fuer Taste, also lohnt
# sich die knappste Schreibweise.
gast() {
    cat <<'ENDE'
== Die Schritte im Gast (Ubuntu 24.04 Live) ==

Nach JEDEM Neustart der Live-Sitzung wieder faellig. Getippt wird ueber
tools/vm.py; der Monitor kennt eigene Tastennamen (comma, spc, shift-4).

 1  Assistent schliessen und ein Terminal oeffnen
        alt-f4          Ubuntu startet mit dem Installationsassistenten
        ctrl-alt-t      Terminal
        alt-f10         Terminal maximieren -- NICHT super-up
    **super-up maximiert hier nicht**, es oeffnet die Uebersicht, und der
    naechste getippte Befehl landet vollstaendig im Suchfeld statt in der
    Shell. Zweimal esc bringt den Fokus zurueck. (12.09.2026)

 2  flatpak nachinstallieren -- BRAUCHT NETZ
        sudo apt-get install -y flatpak
    Ubuntu 24.04 bringt flatpak nicht mit. In einer Live-Sitzung ist es
    nach jedem Neustart wieder weg; das ist kein Fehler, das ist die
    Bauart.

 3  Das AppArmor-Profil laden
        sudo apparmor_parser -r /etc/apparmor.d/flatpak
    Sonst: "bwrap: Creating new namespace failed: Permission denied".
    Das Paket LEGT das Profil ab, es LAEDT es nicht -- das tut
    apparmor.service, und der laeuft in der Live-Sitzung nicht, waehrend
    die Kernel-Sperre sehr wohl greift. Auf einem installierten Ubuntu
    faellt dieser Schritt weg.

 4  Erste Einhaengung: der Flatpak-Bestand auf die Platte
        sudo mkfs.ext4 -q /dev/vda
        mkdir -p ~/.local/share/flatpak
        sudo mount /dev/vda ~/.local/share/flatpak
        sudo chown ubuntu:ubuntu ~/.local/share/flatpak
    Das /cow der Live-Sitzung liegt im RAM: rund 1,2 GB beschreibbar.
    org.kde.Platform 6.9 braucht allein etwa 2 GB. Ohne diesen Schritt
    bricht die Installation auf halbem Weg ab, und der Fehler sieht aus
    wie einer im Flatpak.

 5  Zweite Einhaengung: die Daten-ISO
        sudo mkdir -p /mnt/od
        sudo mount /dev/sr1 /mnt/od          # sr0 ist die Ubuntu-ISO
        cd /mnt/od && sha256sum -c PRUEFSUMMEN.txt
    Das cd gehoert dazu: 'bauen' schreibt die Summen mit `sha256sum
    ./*.flatpak` aus dem Datenverzeichnis, die Pfade darin sind also
    relativ. Von anderswo aufgerufen sucht -c nach ./orangedeck.flatpak
    im falschen Verzeichnis und meldet die Datei als fehlend.
    Die Reihenfolge sr0/sr1 folgt der Reihenfolge der -drive-Zeilen in
    'starten' oben. Die Pruefsummen sind der Grund, warum sie mit auf die
    ISO gehen: erst gegenhalten, dann glauben.

 6  Installieren -- Laufzeit zuerst, Anwendung zuletzt
        flatpak install -y --user /mnt/od/kde-platform-6.9.flatpak
        flatpak install -y --user /mnt/od/gl-default-24.08.flatpak
        flatpak install -y --user /mnt/od/orangedeck.flatpak
        flatpak run dev.orangedeck.OrangeDeck
    **Kein sudo.** --user installiert in den Bestand des aufrufenden
    Kontos; mit sudo waere das der von root, und der liegt wieder im RAM
    statt auf der Platte aus Schritt 4. Genau deshalb steht dort das
    chown auf ubuntu.
    Ohne die GL-Erweiterung startet die Anwendung mit "Could not
    initialize GLX". Wer von Flathub installiert, bekommt sie automatisch;
    ein Buendel bringt sie nicht mit.

    **Herkunft der Schritte 5 und 6:** aus 'bauen' oben und den
    Fehlermeldungen der Laeufe vom 04. und 06.09. abgeleitet, nicht aus
    einem Protokoll abgeschrieben. Am 12.09.2026 sind sie beim Lauf fuer
    0.2.8 zum ersten Mal Zeile fuer Zeile gegangen und stimmen -- damit
    sind alle sechs Schritte gemessen.

== Fedora 44 KDE Live: was anders ist ==

Dasselbe Geruest, vier Abweichungen (gemessen am 12.09.2026):

  * ORANGEDECK_VM_ISO auf die Fedora-ISO setzen, sonst bootet Ubuntu:
        setsid env ORANGEDECK_VM_ISO=$HOME/VMs/fedora-kde-44.iso \
            tools/pruefvm.sh starten

  * Schritt 2 und 3 entfallen. Fedora bringt flatpak mit (1.17.6), und
    SELinux statt AppArmor stellt sich dem Sandkasten nicht in den Weg.

  * **ctrl-alt-t ist nicht belegt.** Die Konsole kommt ueber KRunner:
        alt-spc, dann 'konsole', dann ret
    **Nicht alt-f2.** Am 14.09.2026 ging KRunner darauf nicht auf; die
    Konsole kam erst Minuten spaeter, und die Befehlszeile landete bis
    dahin im Suchfeld von Firefox (DuckDuckGo) statt in einer Shell.
    Kommt sie spaeter doch noch -- ctrl-alt-t wirkt hier verzoegert --,
    stehen zwei Fenster da, und ein Befehl, der WAEHREND des Tippens den
    Fokus wechselt, wird zwischen beiden zerschnitten. Dann einfach im
    vorderen Fenster neu tippen.

    **Am 16.09.2026 ging auch alt-spc nicht.** Plasma meldete "Launching
    KRunner (Failed): startup job failed", zweimal. Sicherer Weg: das
    Startmenue per Klick (vm.klick(35, 768) im 1280x800-Bild), 'konsole'
    tippen, ret -- und dann bis zu einer Minute warten, bis das Fenster
    kommt. Getipptes landet vorher im Willkommensfenster; das loest nichts
    aus, geht aber verloren. Vor dem Tippen in die Konsole klicken.

    **Vor jeder langen Zeile eine Probezeile** (`echo FOKUS-OK`) und ein
    Bild: jede Taste geht einzeln ueber den Monitor, eine Zeile mit den
    Schritten 4 bis 6 braucht gut zwei Minuten -- und landet sie im
    falschen Fenster, merkt man es erst danach.

  * Das Konto heisst liveuser, nicht ubuntu -- das chown in Schritt 4
    entsprechend. mkfs braucht -F, weil die Platte vom vorigen Lauf noch
    ein Dateisystem traegt.

  Der Rest ist gleich, bis auf die Geraete: /dev/vda und /dev/sr1 wie
  gehabt, /dev/sr0 ist die Fedora-ISO.

== Zwei Fallen, die Zeit gekostet haben ==

  * Wird ein Wechseldatentraeger getauscht, WAEHREND er eingehaengt ist,
    liefert der Gast weiter den alten Inhalt aus dem Cache -- ls zeigt
    schon den neuen Namen. Erst umount, dann change, dann neu einhaengen.
    (Deshalb haengen oben beide ISOs von Anfang an.)

  * Frisch messen heisst auch frischer Zustand: ~/.var/app/dev.orangedeck.*
    loeschen, sonst prueft man eine alte Einrichtung.

== Was diese VM NICHT prueft ==

Gesten. Klicks gehen seit dem 15.09.2026 ueber QMP (vm.klick(x, y) in
Bildpunkten des letzten Bildes; mouse_move im Monitor bewegt weiterhin
nichts, siehe Kommentar bei 'starten'). Was am Finger haengt, prueft nur
ein Geraet.

**Und damit auch: den unteren Teil langer Seiten.** `tools/ansichten.py`
rollt mit dem Rad (`xtest.rad`); hier gibt es keines. Ueber die Tastatur
geht es nicht, denn die Ansichten rollen weder auf pgdn noch auf end --
nachgemessen am 12.09.2026 im Mining-Reiter, dessen Seite laenger ist als
das Fenster. Was unterhalb der Fensterkante liegt, prueft in dieser VM
also niemand; dafuer ist der Durchgang im Xvfb da.
ENDE
}

case "${1:-}" in
    bauen)    bauen ;;
    starten)  starten ;;
    anhalten) anhalten ;;
    gast)     gast ;;
    # Die Hilfe ist der Kopf der Datei -- bis zur ersten Zeile, die keine
    # Kommentarzeile mehr ist. Eine feste Zeilenzahl waere beim naechsten
    # eingefuegten Absatz falsch und haette Code mit ausgegeben.
    *) sed -n '2,${/^#/!q;s/^# \{0,1\}//p;}' "${BASH_SOURCE[0]}"; exit 1 ;;
esac
