// Own miners. Shows what the devices report and compares the best share
// difficulty with the network difficulty, which is the number that actually
// matters for solo mining.
//
// Not tied to one device type: the daemon speaks AxeOS (Bitaxe, NerdAxe and
// the other ESP-Miner derivatives) and the cgminer API (Antminer, Avalon,
// Whatsminer and clones) and delivers both normalized, hashrate in H/s.
// Several devices at once are supported.
//
// Two pages, "Device" and "Network". The second shows hashrate, difficulty,
// block time and pools of the whole network (`NetworkView`), so the tab has
// content even without an own miner. With no device configured there is
// only the network page and no switcher.
//
// Only `import QtQuick`, so it also runs on Android.
import QtQuick
import "strings.js" as Tr
import "roll.js" as Roll

pragma ComponentBehavior: Bound

Item {
    id: root

    // Keyboard: Page Up/Down, Home, End. On the network page its own area
    // scrolls, on the device page this one (roll.js; from Main.qml via FeedTabs)
    function rollen(wie) {
        return root.paneNow === "net" ? netz.rollen(wie) : Roll.rollen(flick, wie);
    }

    property var feed: null
    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property color goodColor: "#57b894"
    property color badColor: "#d9534f"
    property real scaleUnit: Math.max(10, Math.min(width / 26, height / 16))
    // Touch input: larger buttons on the network chart
    property bool finger: false
    // When nobody is looking, the network page fetches nothing.
    property bool live: true

    // Which page is on top: "device", "net", or empty for automatic (the device
    // page if one is configured). The host keeps the choice.
    property string pane: ""
    property string netSpan: "1y"
    signal paneRequested(string p)
    signal netSpanRequested(string s)

    // Which pages exist at all, from the settings; empty means both. Without
    // "device" the tab only shows the network, even with a miner configured;
    // without a configured miner there is only the network anyway. If the
    // network is deselected and there is no device, it stays anyway: an empty
    // page helps nobody.
    property var panes: []
    function erlaubt(p) {
        var v = root.panes;
        if (!v || !v.length || typeof v.indexOf !== "function")
            return true;
        return v.indexOf(p) >= 0;
    }
    readonly property bool mitGeraet: root.configured && root.erlaubt("device")
    readonly property bool mitNetz: root.erlaubt("net") || !root.mitGeraet
    readonly property bool zweiSeiten: root.mitGeraet && root.mitNetz
    readonly property string paneNow: !root.mitGeraet ? "net"
                                    : !root.mitNetz ? "device"
                                    : (root.pane === "net" ? "net" : "device")
    // Solo chance on the device page, can be turned off like chart and best list.
    property bool showSolo: true
    // What the network page shows: "stats", "chart", "pools"; empty means all.
    property var netParts: []

    readonly property var miners: feed ? feed.miners : []
    readonly property var total: feed ? feed.minerTotal : ({})
    readonly property bool configured: feed ? feed.minerConfigured : false
    readonly property bool anyOnline: feed ? feed.minerOnline : false
    readonly property real netDiff: (feed && feed.hashrate.difficulty) || 0
    readonly property real netHash: (feed && feed.hashrate.current) || 0
    readonly property real bestShare: (netDiff > 0 && total.bestDiff)
        ? total.bestDiff / netDiff : 0

    // Solo chance. Own hashrate divided by network hashrate is the share of each
    // block; with 144 blocks a day that gives the chance per day and its inverse,
    // the mean waiting time. Both are expected values of a memoryless random
    // process: after a thousand years the chance for the next day is the same.
    readonly property real soloAnteil: (root.netHash > 0 && root.total.hashRate > 0)
        ? root.total.hashRate / root.netHash : 0
    readonly property real soloTag: root.soloAnteil * 144

    // "16.600 Jahre", "64 Tage", "5 Std 20 Min"
    function warte(tage) {
        if (!(tage > 0) || !isFinite(tage))
            return "–";
        if (tage >= 730) {
            var jahre = tage / 365.25;
            return Tr.t("duration.years", root.lang,
                        jahre >= 1e6 ? Tr.big(jahre, root.lang) : Tr.group(jahre, root.lang));
        }
        if (tage >= 2)
            return Tr.t("duration.days", root.lang, Tr.group(tage, root.lang));
        return root.span(tage * 86400);
    }
    // With exactly one device there is room for the details.
    readonly property var one: (miners.length === 1 && miners[0].online) ? miners[0] : null
    readonly property var oneHist: (one && feed) ? (feed.minerHistory[one.id] || ({})) : ({})
    // If the host already has a button bar (the DMS one in the dashboard), it
    // provides the buttons itself and turns ours off. They then sit in the top
    // row where nothing can cover them.
    property bool showActions: true
    // For the host: expand or collapse the legend.
    function toggleInfo() {
        info.open = !info.open;
    }
    // Open the device's web UI. Works for any miner that has one.
    //
    // Add the scheme. The id is the address as entered, on the phone often
    // without "http://". `DirectMiner` prepends it for its own requests
    // (`basis()`). Without it Qt treats the bare address as a path relative to
    // the QML file, and Android fails with "No Activity found to handle Intent
    // { dat=qrc:/... }".
    readonly property string webUrl: {
        if (!(root.one && root.one.type === "axeos"))
            return "";
        var u = String(root.one.id).trim();
        return u.indexOf("://") < 0 ? "http://" + u : u;
    }
    function openWeb() {
        if (webUrl)
            Qt.openUrlExternally(webUrl);
    }
    readonly property bool roomForChart: height > 200
    // Minutes over which the hash domains are averaged: one sample every five
    // seconds, in the daemon as in `DirectMiner`.
    readonly property real domainMin: root.one && root.one.domainSamples
        ? root.one.domainSamples * 5 / 60 : 0

    // Which metrics are shown. An empty list means all; the selection comes from
    // the settings, this is only the filter.
    property var metricKeys: []
    property bool showChart: true
    property bool showDomains: true
    property bool showBoard: true
    property string lang: "de"

    readonly property var metrics: {
        var m = root.one;
        if (!m)
            return [];
        var alle = [
            { "id": "temp", "k": Tr.t("miner.temp", root.lang), "v": (m.temp !== undefined && m.temp !== null)
                ? Math.round(m.temp) + " °C" : "–" },
            { "id": "power", "k": Tr.t("miner.power", root.lang), "v": m.power
                ? Tr.fixed(m.power, 1, root.lang) + " W" : "–" },
            { "id": "fan", "k": Tr.t("miner.fan", root.lang), "v": m.fanRpm ? Tr.t("miner.rpm", root.lang, m.fanRpm) : "–" },
            { "id": "error", "k": Tr.t("miner.errorRate", root.lang), "v": (m.errorPct !== undefined && m.errorPct !== null)
                ? Tr.fixed(m.errorPct, 1, root.lang) + " %" : "–" },
            { "id": "shares", "k": Tr.t("miner.shares", root.lang), "v": m.shares !== undefined
                ? (m.rejected ? Tr.t("miner.rejected", root.lang, m.shares, m.rejected)
                              : String(m.shares)) : "–" },
            { "id": "uptime", "k": Tr.t("miner.uptime", root.lang), "v": root.span(m.uptime) }
        ];
        var mk = root.metricKeys;
        if (!mk || !mk.length || typeof mk.indexOf !== "function")
            return alle;
        return alle.filter(function (x) {
            return mk.indexOf(x.id) >= 0;
        });
    }

    // From six metrics on, split into rows of three; below that one row.
    readonly property var metricRows: {
        var m = root.metrics;
        if (m.length < 6)
            return m.length ? [m] : [];
        var out = [];
        for (var i = 0; i < m.length; i += 3)
            out.push(m.slice(i, i + 3));
        return out;
    }
    readonly property bool roomForBoard: height > 240

    function big(n, unit) {
        if (!n)
            return "–";
        var u = ["", "k", "M", "G", "T", "P", "E"], i = 0;
        while (n >= 1000 && i < u.length - 1) {
            n /= 1000;
            i++;
        }
        return Tr.fixed(n, n >= 100 ? 0 : 2, root.lang)
             + " " + u[i] + (unit || "");
    }

    function span(sec) {
        if (!sec)
            return "–";
        var d = Math.floor(sec / 86400), h = Math.floor((sec % 86400) / 3600),
            m = Math.floor((sec % 3600) / 60);
        if (d > 0)
            return Tr.t("duration.dayHour", root.lang, d, h);
        if (h > 0)
            return Tr.t("duration.hourMin", root.lang, h, m);
        return Tr.t("duration.min", root.lang, m);
    }

    // All explanations in one place instead of scattered over the page.
    InfoPopup {
        id: info

        anchors.fill: parent
        buttonMargin: 0
        showButton: root.showActions
        fontSize: root.scaleUnit * 0.72
        textColor: root.textColor
        dimColor: root.dimColor
        lang: root.lang
        title: Tr.t("miner.whatIsThis", root.lang)
        // Explanations for the page currently on top.
        entries: root.paneNow === "net" ? [
            {
                "color": root.accentColor,
                "k": Tr.t("hashrate", root.lang),
                "v": Tr.t("net.hashHelp", root.lang)
            },
            {
                "color": netz.diffColor,
                "thin": true,
                "k": Tr.t("difficulty", root.lang),
                "v": Tr.t("net.diffHelp", root.lang)
            },
            {
                "k": Tr.t("pool", root.lang),
                "v": Tr.t("net.poolsHelp", root.lang)
            }
        ] : [
            {
                "color": root.accentColor,
                "thin": true,
                "k": Tr.t("miner.hashNow", root.lang),
                "v": Tr.t("miner.hashNowHelp", root.lang)
            },
            {
                "color": root.accentColor,
                "k": Tr.t("miner.hashAvg", root.lang),
                "v": Tr.t("miner.hashAvgHelp", root.lang)
            },
            {
                "color": root.textColor,
                "k": Tr.t("miner.temp", root.lang),
                "v": Tr.t("miner.tempHelp", root.lang)
            },
            {
                "k": Tr.t("miner.oneToN", root.lang),
                "v": Tr.t("miner.oneToNHelp", root.lang)
            },
            {
                "k": Tr.t("miner.solo", root.lang),
                "v": Tr.t("miner.soloHelp", root.lang)
            },
            {
                "k": Tr.t("miner.domains", root.lang),
                "v": Tr.t("miner.domainsHelp", root.lang)
            },
            {
                "k": Tr.t("miner.errorRate", root.lang),
                "v": Tr.t("miner.errorHelp", root.lang)
            }
        ]
        z: 40
    }

    Rectangle {
        id: openBtn

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.rightMargin: info.buttonWidth + root.scaleUnit * 0.4
        visible: root.showActions && root.webUrl !== "" && root.paneNow === "device"
        width: info.buttonWidth
        height: width
        radius: height / 2
        color: openArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        z: 20

        // Drawn, not a glyph. "↗" (U+2197) has an emoji presentation, and Samsung
        // uses it: a blue box with a white arrow next to the plain "i". The stroke
        // matches the color and weight of the "i" next to it.
        Canvas {
            id: pfeil

            anchors.centerIn: parent
            width: parent.width * 0.42
            height: width
            onWidthChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var w = width, s = Math.max(1.5, w * 0.16), r = s / 2;
                ctx.strokeStyle = root.textColor;
                ctx.lineWidth = s;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                ctx.beginPath();
                ctx.moveTo(r, w - r);
                ctx.lineTo(w - r, r);
                ctx.moveTo(w * 0.38, r);
                ctx.lineTo(w - r, r);
                ctx.lineTo(w - r, w * 0.62);
                ctx.stroke();
            }
        }

        MouseArea {
            id: openArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openWeb()
        }
    }

    // --- Device | Network ---
    // Only when there are two pages. Fixed at the top, both pages scroll below it.
    readonly property real kopfHoehe: root.zweiSeiten ? umschalter.height + root.scaleUnit * 0.5 : 0

    TileGoggles {
        id: umschalter

        visible: root.zweiSeiten
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: umschalter.schalterBreite
        modes: [
            { "k": "device", "l": Tr.t("miner.paneDevice", root.lang) },
            { "k": "net", "l": Tr.t("miner.paneNet", root.lang) }
        ]
        mode: root.paneNow
        labelKey: ""
        counts: []
        total: 0
        lang: root.lang
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        uiFont: root.finger ? Math.max(15, root.scaleUnit * 0.62) : root.scaleUnit * 0.62
        minTap: root.finger ? 40 : 0
        z: 20
        onPicked: function (m) {
            root.paneRequested(m);
        }
    }

    // --- Network ---
    // Without a configured device, a hint below explains how to add one: in the
    // settings on the phone, via the service's discovery on the desktop.
    NetworkView {
        id: netz

        anchors.fill: parent
        visible: root.paneNow === "net"
        live: root.live && root.visible && root.paneNow === "net"
        // Without the switcher the page starts at the top, where the i button sits
        // and needs its row.
        topInset: root.zweiSeiten ? root.kopfHoehe
                                  : (root.showActions ? info.buttonWidth + root.scaleUnit * 0.3 : 0)
        feed: root.feed
        lang: root.lang
        span: root.netSpan
        parts: root.netParts
        finger: root.finger
        // With touch input not below 20. `scaleUnit` follows the width; in portrait
        // on a phone that is about 16, and the labels of metrics and pools ended up
        // at barely nine. The desktop is unchanged.
        scaleUnit: root.finger ? Math.max(20, root.scaleUnit) : root.scaleUnit
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        footer: root.configured ? ""
              : (root.feed && root.feed.direkt)
                ? Tr.t("net.addMiner", root.lang, Tr.t("tab.settings", root.lang),
                       Tr.t("tab.miner", root.lang))
                : Tr.t("miner.none", root.lang) + ". " + Tr.t("miner.discover", root.lang)
        footerCommand: (!root.configured && !(root.feed && root.feed.direkt))
            ? "orangedeck --discover-miners --write\nsystemctl --user restart orangedeck" : ""
        onSpanRequested: function (sp) {
            root.netSpanRequested(sp);
        }
    }

    // --- Configured, but all offline ---
    Column {
        anchors.centerIn: parent
        spacing: root.scaleUnit * 0.35
        visible: root.configured && !root.anyOnline && root.paneNow === "device"

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Tr.t(root.miners.length === 1 ? "miner.notReachable"
                                               : "miner.unreachable", root.lang)
            color: root.badColor
            font.pixelSize: root.scaleUnit * 1.1
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Tr.t("miner.offNote", root.lang)
            color: root.dimColor
            font.pixelSize: root.scaleUnit * 0.62
        }
    }

    // --- Running ---
    // The content can be taller than the area: the dashboard tab (410 px) is not
    // enough for chart, hash domains and best list at once. So it scrolls: if
    // everything fits it stays centered, otherwise it can be dragged.
    Flickable {
        id: flick

        anchors.fill: parent
        anchors.topMargin: root.kopfHoehe
        clip: true
        visible: root.anyOnline && root.paneNow === "device"
        contentWidth: width
        contentHeight: body.implicitHeight + root.scaleUnit
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 2500

        // Thin bar on the right, only while there is something to scroll.
        Rectangle {
            parent: flick
            anchors.right: parent.right
            width: Math.max(2, root.scaleUnit * 0.16)
            radius: width / 2
            color: Qt.rgba(1, 1, 1, 0.22)
            visible: flick.contentHeight > flick.height + 1
            y: flick.contentY + flick.height * (flick.contentY / flick.contentHeight)
            height: flick.height * (flick.height / flick.contentHeight)
            z: 30
        }

        Column {
            id: body

                width: flick.width * 0.9
                x: (flick.width - width) / 2
                // Centered while there is room, otherwise start at the top. Pinning it to the
                // top leaves the lower half empty when only the device page is shown.
                y: Math.max(root.scaleUnit * 0.3, (flick.height - implicitHeight) / 2)
                spacing: root.scaleUnit * 0.45

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.total.online > 1
                    ? Tr.t("miner.devices", root.lang, root.total.online)
                    : (root.miners[0] ? root.miners[0].name : Tr.t("miner.title", root.lang))
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.72
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.big(root.total.hashRate, "H/s")
                color: root.accentColor
                font.pixelSize: root.scaleUnit * 2.6
                font.bold: true
            }

            // The instantaneous rate swings by about ten percent, so the top shows the
            // smoothed ten-minute value, and this compares it with what the device
            // should deliver at its clock setting.
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.one && root.one.expected
                text: root.one && root.one.expected
                    ? Tr.t("miner.smoothed", root.lang, root.big(root.one.expected, "H/s"))
                    : ""
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.55
            }

            // The reason anyone does this.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.one && root.one.blockFound > 0
                width: blockText.width + root.scaleUnit
                height: blockText.height + root.scaleUnit * 0.4
                radius: height / 2
                color: root.goodColor

                Text {
                    id: blockText

                    anchors.centerIn: parent
                    text: root.one && root.one.blockFound > 0
                        ? (root.one.blockFound === 1
                            ? Tr.t("miner.oneBlockFound", root.lang)
                            : Tr.t("miner.blocksFound", root.lang, root.one.blockFound))
                        : ""
                    color: "#0b0b12"
                    font.pixelSize: root.scaleUnit * 0.62
                    font.bold: true
                }
            }

            // The number that matters for solo mining.
            Column {
                width: parent.width
                spacing: root.scaleUnit * 0.15

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Tr.t("miner.bestShare", root.lang)
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.62
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.total.bestDiff
                        ? Tr.t("miner.ofNet", root.lang, root.big(root.total.bestDiff),
                               root.big(root.netDiff))
                        : "–"
                    color: root.textColor
                    font.pixelSize: root.scaleUnit * 0.95
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.bestShare > 0
                    // Tiny shares: "1 in N" reads better than a percentage with eight zeros.
                    text: root.bestShare >= 1
                        ? Tr.t("miner.enoughForBlock", root.lang)
                        : Tr.t("miner.oneInN", root.lang, root.big(1 / root.bestShare))
                    color: root.bestShare >= 1 ? root.goodColor : root.dimColor
                    font.pixelSize: root.scaleUnit * 0.62
                }
            }

            // Chance that one of the next blocks is ours. Below one block a day it shows
            // "1 in N per day" with the mean waiting time below; above that the waiting
            // time alone is enough.
            Column {
                width: parent.width
                spacing: root.scaleUnit * 0.15
                visible: root.showSolo && root.soloTag > 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Tr.t("miner.solo", root.lang)
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.62
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.soloTag >= 1
                        ? Tr.t("miner.soloEvery", root.lang, root.warte(1 / root.soloTag))
                        : Tr.t("miner.soloDay", root.lang, root.big(1 / root.soloTag))
                    color: root.textColor
                    font.pixelSize: root.scaleUnit * 0.95
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.soloTag > 0 && root.soloTag < 1
                    text: Tr.t("miner.soloEvery", root.lang, root.warte(1 / root.soloTag))
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.62
                }
            }

            Item {
                width: 1
                height: root.scaleUnit * 0.3
            }

            // --- Details, single device ---
            Column {
                width: parent.width
                spacing: root.scaleUnit * 0.2
                visible: root.one !== null

                // The metrics. From six on they are split into rows of three: in a single
                // row they ran past the edge in the dashboard and the outer two were cut
                // off. Up to five stay in one row.
                Column {
                    width: parent.width
                    spacing: root.scaleUnit * 0.45

                    Repeater {
                        model: root.metricRows

                        Row {
                            id: zeile

                            required property var modelData

                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: root.scaleUnit * 1.1

                            Repeater {
                                model: zeile.modelData

                                Column {
                                    id: cell

                                    required property var modelData

                                    spacing: root.scaleUnit * 0.1

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: cell.modelData.k
                                        color: root.dimColor
                                        font.pixelSize: root.scaleUnit * 0.55
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: cell.modelData.v
                                        color: root.textColor
                                        font.pixelSize: root.scaleUnit * 0.8
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    // Only the pool host: for solo mining the user name contains the payout
                    // address and is never shown.
                    text: root.one
                        ? [root.one.model, root.one.version, root.one.pool].filter(function (x) {
                              return !!x;
                          }).join(" · ")
                        : ""
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.55
                }
            }

            // --- History ---
            MinerChart {
                width: parent.width
                height: root.scaleUnit * 4.2
                visible: root.showChart && root.one !== null && root.roomForChart
                         && (root.oneHist.hr || []).length > 1
                hist: root.oneHist
                lang: root.lang
                lineColor: root.accentColor
                dimColor: root.dimColor
                labelSize: root.scaleUnit * 0.5
            }

            // Where a longer history would come from. If the device does not record its
            // own, the chart only reaches back as far as the app has been open. The
            // switch is in AxeOS, not here: the app does not change settings on the miner
            // behind the user's back. Only `DirectMiner` reports `statsFrequency`; the
            // daemon does not, and then this line is hidden.
            Text {
                width: parent.width
                visible: root.showChart && root.one !== null && root.roomForChart
                         && root.one.statsFrequency === 0
                text: Tr.t("miner.statsHint", root.lang)
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.45
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            // --- Individual hash domains ---
            Column {
                width: parent.width
                spacing: root.scaleUnit * 0.15
                visible: root.one !== null && (root.one.domains || []).length > 0
                         && root.roomForChart && root.showDomains

                Text {
                    // The chip is split internally into hash domains (four on the BM1370). Single
                    // readings fluctuate by more than ten percent, so the smoothed value is shown;
                    // otherwise noise looks like a defect.
                    // Minutes formatted per language, whole numbers from one minute up.
                    text: root.one && root.one.domainSamples
                        ? Tr.t("miner.domainsAvg", root.lang, root.domainMin >= 1
                               ? Math.round(root.domainMin)
                               : Tr.fixed(root.domainMin, 1, root.lang))
                        : Tr.t("miner.domains", root.lang)
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.55
                }

                Row {
                    width: parent.width
                    spacing: root.scaleUnit * 0.25

                    Repeater {
                        model: root.one ? (root.one.domainsAvg || root.one.domains) : []

                        Rectangle {
                            id: dom

                            required property var modelData
                            required property int index

                            readonly property var vals: root.one.domainsAvg || root.one.domains || []

                            width: (root.width * 0.9 - root.scaleUnit * 0.75) / Math.max(1, dom.vals.length)
                            height: root.scaleUnit * 0.95
                            radius: 3
                            color: Qt.rgba(1, 1, 1, 0.06)

                            Rectangle {
                                // Share relative to the strongest domain, so a weak one stands out at once.
                                width: parent.width * Math.max(0.05, Math.min(1,
                                    dom.modelData / Math.max.apply(null, dom.vals)))
                                height: parent.height
                                radius: parent.radius
                                color: root.accentColor
                                opacity: 0.75
                            }

                            Text {
                                anchors.centerIn: parent
                                text: Math.round(dom.modelData) + " GH/s"
                                color: root.textColor
                                font.pixelSize: root.scaleUnit * 0.5
                            }
                        }
                    }
                }
            }

            // --- Best list ---
            Column {
                width: parent.width
                spacing: root.scaleUnit * 0.12
                visible: root.showBoard && root.one !== null && root.roomForBoard
                         && (root.one.scoreboard || []).length > 0

                Text {
                    text: Tr.t("miner.bestList", root.lang)
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.55
                }

                Repeater {
                    model: root.one ? (root.one.scoreboard || []).slice(0, 5) : []

                    Row {
                        id: sbRow

                        required property var modelData
                        required property int index

                        width: parent.width
                        spacing: root.scaleUnit * 0.5

                        Text {
                            width: root.scaleUnit * 1.2
                            text: (sbRow.index + 1) + "."
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.58
                        }

                        Text {
                            width: root.scaleUnit * 4
                            text: root.big(sbRow.modelData.diff)
                            color: sbRow.index === 0 ? root.accentColor : root.textColor
                            font.pixelSize: root.scaleUnit * 0.58
                        }

                        Text {
                            text: root.netDiff > 0
                                ? Tr.t("miner.oneTo", root.lang,
                                       root.big(root.netDiff / sbRow.modelData.diff))
                                : ""
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.58
                        }

                        Text {
                            text: sbRow.modelData.time
                                ? Qt.formatDate(new Date(sbRow.modelData.time * 1000), Tr.datum(root.lang))
                                : ""
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.58
                        }
                    }
                }
            }

            // --- Individual devices ---
            Column {
                width: parent.width
                spacing: root.scaleUnit * 0.2

                visible: root.one === null

                Repeater {
                    model: root.miners

                    Row {
                        id: line

                        required property var modelData

                        width: parent.width
                        spacing: root.scaleUnit * 0.5

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.scaleUnit * 0.32
                            height: width
                            radius: width / 2
                            color: line.modelData.online ? root.goodColor : root.badColor
                        }

                        Text {
                            width: root.scaleUnit * 7
                            elide: Text.ElideRight
                            text: line.modelData.name || line.modelData.id
                            color: root.textColor
                            font.pixelSize: root.scaleUnit * 0.62
                        }

                        Text {
                            width: root.scaleUnit * 4
                            text: line.modelData.online ? root.big(line.modelData.hashRate, "H/s") : Tr.t("miner.off", root.lang)
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.62
                        }

                        Text {
                            visible: line.modelData.online && line.modelData.temp !== undefined
                                     && line.modelData.temp !== null
                            width: root.scaleUnit * 2.4
                            text: line.modelData.temp !== undefined && line.modelData.temp !== null
                                ? Math.round(line.modelData.temp) + " °C" : ""
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.62
                        }

                        Text {
                            visible: line.modelData.online
                            text: root.span(line.modelData.uptime)
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.62
                        }
                    }
                }
            }
        }
    }
}
