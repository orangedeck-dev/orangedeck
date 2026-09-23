// Keeps the feed process alive while the plugin is active.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins

PluginComponent {
    id: root

    // Start the service, not a separate process; otherwise there would be
    // two managers for one daemon. Falls back to the binary when the unit is
    // not set up (tools/install-links.sh).
    property var feedCommand: ["sh", "-c",
        "systemctl --user start orangedeck.service 2>/dev/null || exec \"$HOME/.local/bin/orangedeck\""]

    // Without OrangeDeck on the machine there is nothing to start. Installed
    // from the DMS plugin registry, only the plugin folder exists: no unit, no
    // orangedeck in PATH. The timer below would then see stale state forever
    // and spawn a failing shell every ten seconds.
    //
    // The command above covers this: it only exits with an error on its own when
    // both paths are missing, i.e. `systemctl start` failed and `exec` did not
    // find the binary. After that nothing more is tried; the widget then gets
    // its data directly (`FeedState`, mode "auto").
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

    // Check every 10 s whether the state is fresh. The file lock in orangedeck
    // prevents several instances from running side by side.
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
