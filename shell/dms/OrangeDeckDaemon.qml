// Haelt den Feed-Prozess am Leben, solange das Plugin aktiv ist.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins

PluginComponent {
    id: root

    // Den **Dienst** anstossen, nicht einen eigenen Prozess starten: sonst gibt
    // es zwei Verwalter fuer einen Daemon. Der Rueckfall auf das Programm
    // greift, wenn die Unit nicht eingerichtet ist (tools/install-links.sh).
    property var feedCommand: ["sh", "-c",
        "systemctl --user start orangedeck.service 2>/dev/null || exec \"$HOME/.local/bin/orangedeck\""]

    // **Ohne OrangeDeck auf dem Rechner gibt es hier nichts anzustossen.**
    // Wer das Plugin aus dem Verzeichnis von DMS installiert, hat den Ordner
    // und sonst nichts: keine Unit, kein orangedeck im Pfad. Der Zeitgeber
    // unten faende den Zustand dann fuer immer veraltet und startete alle
    // zehn Sekunden eine Shell, die an derselben Stelle scheitert.
    //
    // Der Befehl oben sagt es selbst: er endet nur dann von sich aus mit
    // einem Fehler, wenn **beide** Wege fehlen -- `systemctl start` hat
    // nicht funktioniert und `exec` fand das Programm nicht. Danach wird
    // nicht weiter gesucht; das Widget bezieht seine Daten in dem Fall
    // direkt (`FeedState`, Betriebsart "auto").
    property bool dienstVorhanden: true
    property string statePath: (Quickshell.env("XDG_RUNTIME_DIR") || (Quickshell.env("HOME") + "/.local/state")) + "/orangedeck/state.json"

    Process {
        id: feedProc

        command: root.feedCommand
        running: false

        onExited: function (exitCode) {
            if (exitCode !== 0)
                root.dienstVorhanden = false;
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    console.log("orangedeck:", text.trim());
            }
        }
    }

    FileView {
        id: probe

        path: root.statePath
        blockLoading: false
        printErrors: false
    }

    // Alle 10 s pruefen, ob der Zustand frisch ist. Die Dateisperre in orangedeck
    // verhindert, dass mehrere Instanzen nebeneinander laufen.
    Timer {
        interval: 10000
        repeat: true
        running: root.dienstVorhanden
        triggeredOnStart: true

        onTriggered: {
            probe.reload();
            var stale = true;
            try {
                var d = JSON.parse(probe.text() || "{}");
                stale = (Date.now() / 1000 - (d.ts || 0)) > 20;
            } catch (e) {}
            if (stale && !feedProc.running)
                feedProc.running = true;
        }
    }

    IpcHandler {
        target: "orangedeck"

        function restart(): string {
            feedProc.running = false;
            feedProc.running = true;
            return "orangedeck neu gestartet";
        }

        function status(): string {
            probe.reload();
            return probe.text() || "kein Zustand";
        }
    }
}
