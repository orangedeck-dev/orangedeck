// Keeps the feed process alive while the plugin is active, and holds the one
// FeedState that the bar pills and the desktop widgets share.
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

    // ------------------------------------------------------------ Shared feed
    // Without it every bar pill and every desktop widget had a FeedState of its
    // own, and in direct mode each one kept a WebSocket to mempool.space: three
    // widgets, four connections. Hosts find this one through
    // `PluginService.pluginDaemonInstances` and fall back to their own when it
    // is missing.
    //
    // Hosts report whether they are looking (`setViewer`). Nobody looking, no
    // requests. A visible desktop widget needs the fast pace for the rain; the
    // pill alone shows two numbers and gets by with 2 s.
    property var viewers: ({})
    readonly property bool anyViewer: Object.keys(root.viewers).length > 0
    readonly property bool desktopViewer: {
        for (var k in root.viewers) {
            if (root.viewers[k] === "desktop")
                return true;
        }
        return false;
    }

    function setViewer(key, kind) {
        var v = Object.assign({}, root.viewers);
        if (kind)
            v[key] = kind;
        else
            delete v[key];
        root.viewers = v;
    }

    readonly property var _t: SettingsData.pluginSettings

    function setting(key, def) {
        root._t;
        return SettingsData.getPluginSetting("orangedeck", key, def);
    }

    property alias feed: sharedFeed

    FeedState {
        id: sharedFeed

        active: root.anyViewer
        pollMs: root.desktopViewer ? 500 : 2000
        mode: root.setting("dataSource", "auto")
        mempoolHost: root.setting("mempoolHost", "")
        minerHostsRaw: root.setting("minerHostsRaw", "")
    }

    IpcHandler {
        target: "orangedeck"

        function restart(): string {
            feedProc.running = false;
            feedProc.running = true;
            return "orangedeck neu gestartet";
        }

        // Who reads the shared feed and at what pace
        function feed(): string {
            return JSON.stringify({
                "viewers": root.viewers,
                "active": sharedFeed.active,
                "pollMs": sharedFeed.pollMs,
                "mode": sharedFeed.effMode,
                "online": sharedFeed.online
            });
        }

        function status(): string {
            probe.reload();
            return probe.text() || "kein Zustand";
        }
    }
}
