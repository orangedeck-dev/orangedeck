// Explorer: search, view details, follow the money.
//
// Input detection lives in `search.js` (ported from the fork). All requests
// go through the daemon, which knows whether the data comes from
// mempool.space or from an own node.
//
// Only `import QtQuick`, so it also runs on Android.
import QtQuick
import "search.js" as Search
import "txtype.js" as TxType
import "strings.js" as Tr
import "fonts.js" as Fonts
import "roll.js" as Roll

pragma ComponentBehavior: Bound

Item {
    id: root

    // Keyboard: Page Up/Down, Home, End (roll.js; from Main.qml via FeedTabs)
    function rollen(wie) {
        return Roll.rollen(flick, wie);
    }

    property var feed: null
    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property color goodColor: "#57b894"
    property color badColor: "#d9534f"
    property real scaleUnit: Math.max(10, Math.min(width / 34, height / 20))
    // The search bar should not grow with the window; in a large window it looks
    // silly. The content below may scale, the controls may not.
    readonly property real uiFont: Math.min(scaleUnit * 0.78, 15)

    // --- State ---
    property string kind: ""          // tx | block | address
    // Do not name this `data`: in QML that is the default property holding the
    // child items. Overriding it breaks the item tree.
    property var result: null         // response of the main request
    property var extra: null          // outspends or address transactions
    property var tiles: null          // tile data of the block
    property bool tilesBusy: false
    property string status: ""        // message shown instead of a result
    property bool busy: false
    property var trail: []            // path so far, for the back button

    // Opening the explorer means you want to type, so focus goes to the search
    // field. The hosts stack all views and only toggle visibility, so `visible`
    // is the signal for "opened". The desktop widget takes no keyboard input and
    // turns this off.
    property bool focusSearch: true
    // "I am giving focus back." Hosts with shortcuts (window and Quickshell) take
    // it back on this signal, otherwise their shortcuts are dead after a visit to
    // the explorer.
    signal searchFocusReleased()
    // ... and took it: digits now go into the field.
    signal searchFocusTaken()

    onVisibleChanged: {
        if (root.visible) {
            // Not immediately: while switching, the item tree is not ready yet and a
            // `forceActiveFocus` in this pass has no effect.
            if (root.focusSearch)
                Qt.callLater(root.focusSearchField);
        } else if (field.activeFocus) {
            field.focus = false;
            root.searchFocusReleased();
        }
    }

    // If the explorer is the start view it is visible from the start and
    // `onVisibleChanged` never fires.
    Component.onCompleted: {
        if (root.visible && root.focusSearch)
            Qt.callLater(root.focusSearchField);
    }

    function focusSearchField() {
        if (root.visible && root.focusSearch) {
            field.forceActiveFocus();
            root.searchFocusTaken();
        }
    }

    // Copy to clipboard. QtQuick has no API for this; the usual workaround is an
    // invisible text field that gets selected and copied.
    TextEdit {
        id: clipboard

        visible: false
    }

    property string copied: ""

    function copyText(t) {
        if (!t)
            return;
        clipboard.text = String(t);
        clipboard.selectAll();
        clipboard.copy();
        root.copied = String(t);
        copiedTimer.restart();
    }

    Timer {
        id: copiedTimer

        interval: 1400
        onTriggered: root.copied = ""
    }

    // Thousands separator per language: German uses a period, English a comma.
    // Not cosmetic: "1.234" means one thousand two hundred or one point two
    // depending on the language.
    function grp(n) {
        return Tr.group(n, root.lang);
    }

    function btc(sats) {
        if (sats === undefined || sats === null)
            return "–";
        return root.btcZeichen + " " + Tr.fixed(sats / 1e8, 8, root.lang);
    }

    function shortId(id, n) {
        if (!id)
            return "";
        var k = n || 10;
        return id.length > 2 * k ? id.slice(0, k) + "…" + id.slice(-k) : id;
    }

    // Estimated time until a projected block, based on the measured block time,
    // not the nominal ten minutes.
    function etaFor(rank) {
        var avg = (root.feed && root.feed.difficulty.timeAvg) || 600000;
        var min = Math.round((rank + 1) * avg / 60000);
        if (min < 60)
            return Tr.t("in.min", root.lang, min);
        return Tr.t("in.hourMin", root.lang, Math.floor(min / 60), min % 60);
    }

    function ago(ts) {
        if (!ts)
            return "";
        var s = Math.max(0, Math.floor(Date.now() / 1000 - ts));
        if (s < 90)
            return "gerade eben";
        var m = Math.floor(s / 60);
        if (m < 90)
            return Tr.t("ago.min", root.lang, m);
        var h = Math.floor(m / 60);
        if (h < 48)
            return Tr.t("ago.hour", root.lang, h);
        return Tr.t("ago.day", root.lang, Math.floor(h / 24));
    }

    // --- Requests ---
    function go(kind, arg, remember) {
        if (!root.feed)
            return;
        if (remember !== false && root.kind && root.result)
            root.trail = root.trail.concat([{ "kind": root.kind, "arg": root.currentArg }]);
        root.busy = true;
        root.status = "";
        root.extra = null;
        root.tiles = null;

        if (kind === "blockheight") {
            // Resolve the height to a hash first. The response is plain text, not JSON.
            root.feed.lookup("blockheight", arg, function (d, err) {
                root.busy = false;
                if (err) {
                    root.fail(err);
                    return;
                }
                root.go("blockhash", String(d), false);
            });
            return;
        }

        // For blocks use the extended form: it includes pool, reward, fee range,
        // UTXO change and SegWit share.
        var route = kind === "tx" ? "tx" : (kind === "blockhash" ? "blockinfo" : "address");
        root.currentArg = arg;
        root.feed.lookup(route, arg, function (d, err) {
            root.busy = false;
            if (err) {
                root.fail(err);
                return;
            }
            root.kind = kind === "blockhash" ? "block" : (kind === "tx" ? "tx" : "address");
            root.result = d;
            root.status = "";
            // Load what continues the path.
            if (root.kind === "tx")
                root.feed.lookup("outspends", arg, function (o) {
                    root.extra = o;
                });
            else if (root.kind === "address")
                root.feed.lookup("addresstxs", arg, function (o) {
                    root.extra = o;
                });
            else if (root.kind === "block") {
                // Tile data comes separately: it is large and the daemon has to prepare it
                // first.
                root.tiles = null;
                root.tilesBusy = true;
                root.feed.lookup("blocktiles", arg, function (t) {
                    root.tilesBusy = false;
                    root.tiles = t;
                });
            }
        });
    }

    property string currentArg: ""

    // Tile coloring for all tile graphics in this view: "fee" or "type". Kept
    // here so the choice survives navigation.
    property string tileColorMode: "fee"
    property string currency: "eur"
    property string lang: "de"
    property string btcZeichen: "\u20BF"
    property string pfeilKurz: "\u2192"
    // Sections and panels of the start page; both empty means everything.
    property var homeParts: []
    property var homePanels: []
    property bool trackProjected: true
    // The host owns the reading mode and remembers it; this only requests a
    // change. Assigning it here would break the binding from the settings.
    signal tileColorModeRequested(string mode)

    // A projected block has no hash and no fetchable contents, so it is set
    // directly instead of being loaded through `go()`.
    property int projRank: 0

    function showProjected(rank, data) {
        if (root.kind && root.result)
            root.trail = root.trail.concat([{ "kind": root.kind, "arg": root.currentArg }]);
        root.kind = "projected";
        root.projRank = rank;
        root.result = data;
        root.extra = null;
        root.tiles = null;
        root.status = "";
        root.currentArg = "";
        // `ProjectedBlock` fetches the tiles itself and keeps them updated while the
        // view is open. Fetching once would be wrong here: the projected block
        // changes every second.
    }

    function fail(msg) {
        root.kind = "";
        root.result = null;
        root.status = msg;
    }

    function submit(text) {
        var m = Search.matchQuery(text);
        if (!m) {
            root.fail(Tr.t("search.invalid", root.lang));
            return;
        }
        if (m.kind === "xpub") {
            root.fail(Tr.t("search.xpub", root.lang));
            return;
        }
        var k = m.kind === "input" || m.kind === "output" ? "tx" : m.kind;
        root.go(k, m.arg);
    }

    // Back to the start page. Without this, getting out of a transaction meant
    // pressing back repeatedly.
    function home() {
        root.trail = [];
        root.kind = "";
        root.result = null;
        root.extra = null;
        root.tiles = null;
        root.status = "";
        root.currentArg = "";
    }

    function back() {
        if (!trail.length)
            return;
        var last = trail[trail.length - 1];
        root.trail = trail.slice(0, -1);
        // The history has no request behind it; it is set, not loaded.
        if (last.kind === "history") {
            root.kind = "history";
            root.result = null;
            root.status = "";
            root.currentArg = "";
            return;
        }
        root.go(last.kind === "block" ? "blockhash" : last.kind, last.arg, false);
    }

    // The block chain for browsing. Like `showProjected` this is not a load
    // path: the component fetches the list itself.
    function showHistory() {
        if (root.kind && (root.result || root.kind === "history"))
            root.trail = root.trail.concat([{ "kind": root.kind, "arg": root.currentArg }]);
        root.kind = "history";
        root.result = null;
        root.extra = null;
        root.tiles = null;
        root.status = "";
        root.currentArg = "";
    }

    // --- Search field ---
    Item {
        id: bar

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: field.height + root.uiFont * 1.3

        Rectangle {
            id: homeBtn

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            width: root.uiFont * 2.2
            height: width
            radius: width / 2
            visible: root.kind !== "" || root.status.length > 0
            color: homeArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)

            // House icon, drawn for the same reason as the back arrow: glyphs do not
            // reliably sit centered.
            Canvas {
                anchors.centerIn: parent
                width: parent.width * 0.5
                height: width

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = root.textColor;
                    ctx.lineWidth = Math.max(1.4, width * 0.14);
                    ctx.lineCap = "round";
                    ctx.lineJoin = "round";
                    ctx.beginPath();
                    ctx.moveTo(width * 0.08, height * 0.46);
                    ctx.lineTo(width * 0.5, height * 0.1);
                    ctx.lineTo(width * 0.92, height * 0.46);
                    ctx.stroke();
                    ctx.beginPath();
                    ctx.moveTo(width * 0.2, height * 0.44);
                    ctx.lineTo(width * 0.2, height * 0.9);
                    ctx.lineTo(width * 0.8, height * 0.9);
                    ctx.lineTo(width * 0.8, height * 0.44);
                    ctx.stroke();
                }
            }

            MouseArea {
                id: homeArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.home()
            }
        }

        Rectangle {
            id: backBtn

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: homeBtn.visible ? homeBtn.right : parent.left
            anchors.leftMargin: homeBtn.visible ? root.uiFont * 0.4 : 0
            width: root.uiFont * 2.2
            height: width
            radius: width / 2
            visible: root.trail.length > 0
            color: backArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)

            // Drawn instead of typeset: the "‹" glyph brings its own side bearing and
            // baseline depending on the font and ends up off center. Two lines always
            // sit where they should.
            Canvas {
                anchors.centerIn: parent
                width: parent.width * 0.42
                height: width

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = root.textColor;
                    ctx.lineWidth = Math.max(1.5, width * 0.16);
                    ctx.lineCap = "round";
                    ctx.lineJoin = "round";
                    ctx.beginPath();
                    ctx.moveTo(width * 0.68, height * 0.12);
                    ctx.lineTo(width * 0.28, height * 0.5);
                    ctx.lineTo(width * 0.68, height * 0.88);
                    ctx.stroke();
                }
            }

            MouseArea {
                id: backArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.back()
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: backBtn.visible ? backBtn.right
                                          : (homeBtn.visible ? homeBtn.right : parent.left)
            anchors.leftMargin: (backBtn.visible || homeBtn.visible) ? root.uiFont * 0.5 : 0
            anchors.right: parent.right
            height: field.height + root.uiFont * 0.8
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.06)
            border.width: 1
            border.color: field.activeFocus ? root.accentColor : Qt.rgba(1, 1, 1, 0.12)

            TextInput {
                id: field

                anchors.left: parent.left
                anchors.right: hintLabel.left
                anchors.leftMargin: root.uiFont
                anchors.rightMargin: root.uiFont * 0.6
                anchors.verticalCenter: parent.verticalCenter
                color: root.textColor
                font.pixelSize: root.uiFont
                font.family: Fonts.mono()
                selectByMouse: true
                clip: true
                onAccepted: root.submit(text)

                // Escape gives focus back. Otherwise you are stuck when using only the
                // keyboard: the host only releases focus once the explorer becomes
                // invisible, it becomes invisible via a shortcut, and this field swallows
                // the shortcuts. With a mouse you never notice because you just click the tab.
                Keys.onEscapePressed: {
                    field.focus = false;
                    root.searchFocusReleased();
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: field.text.length === 0
                    text: Tr.t("search.placeholder", root.lang)
                    color: root.dimColor
                    font.pixelSize: root.uiFont
                }
            }

            Text {
                id: hintLabel

                anchors.right: parent.right
                anchors.rightMargin: root.uiFont
                anchors.verticalCenter: parent.verticalCenter
                // With an empty field this would repeat the placeholder, so show nothing.
                text: root.busy ? Tr.t("search.searching", root.lang)
                                : (field.text.length ? Search.hintFor(field.text, function (k, a) {
                                      return Tr.t(k, root.lang, a);
                                  }) : "")
                color: root.busy ? root.accentColor : root.dimColor
                font.pixelSize: root.uiFont * 0.82
            }
        }
    }

    // --- Result ---
    Flickable {
        id: flick

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: bar.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: root.scaleUnit * 0.5
        clip: true
        contentWidth: width
        contentHeight: body.implicitHeight + root.scaleUnit
        boundsBehavior: Flickable.StopAtBounds

        // Thin bar on the right, only while there is something to scroll. Large flow
        // graphics quickly make the content taller than the window, and then it
        // should be visible that there is more.
        Rectangle {
            parent: flick
            anchors.right: parent.right
            width: Math.max(2, root.uiFont * 0.2)
            radius: width / 2
            color: Qt.rgba(1, 1, 1, 0.22)
            visible: flick.contentHeight > flick.height + 1
            y: flick.contentY + flick.height * (flick.contentY / flick.contentHeight)
            height: flick.height * (flick.height / flick.contentHeight)
            z: 30
        }

        Column {
            id: body

            width: flick.width
            spacing: root.scaleUnit * 0.5

            // --- Message ---
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                visible: root.status.length > 0
                text: root.status
                color: root.badColor
                font.pixelSize: root.scaleUnit * 0.75
            }

            ExplorerHome {
                width: parent.width
                visible: root.kind === "" && root.status.length === 0
                // Only track while the start page is really visible. `visible` alone is not
                // enough, the window may be closed (see DOKUMENTATION).
                live: visible && root.visible && root.trackProjected
                lang: root.lang
                btcZeichen: root.btcZeichen
                colorMode: root.tileColorMode
                currency: root.currency
                parts: root.homeParts
                panelIds: root.homePanels
                onColorModeRequested: function (m) {
                    root.tileColorModeRequested(m);
                }
                feed: root.feed
                textColor: root.textColor
                dimColor: root.dimColor
                accentColor: root.accentColor
                uiFont: root.uiFont
                onBlockPicked: function (hash) {
                    root.go("blockhash", hash);
                }
                onTxPicked: function (txid) {
                    root.go("tx", txid);
                }
                onProjectedPicked: function (rank, data) {
                    root.showProjected(rank, data);
                }
                onHistoryPicked: function () {
                    root.showHistory();
                }
            }

            // --- Transaction ---
            Loader {
                width: parent.width
                // `visible` as well as `active`: a deactivated Loader keeps the height of
                // its last content, and the column only skips invisible children, not empty
                // ones. Without this, a block view left a 2571 px tall gap before the next
                // page.
                visible: active
                active: root.kind === "tx" && root.result !== null
                sourceComponent: txDetail
            }

            Loader {
                width: parent.width
                visible: active
                active: root.kind === "block" && root.result !== null
                sourceComponent: blockDetail
            }

            Loader {
                width: parent.width
                visible: active
                active: root.kind === "address" && root.result !== null
                sourceComponent: addressDetail
            }

            Loader {
                width: parent.width
                visible: active
                active: root.kind === "projected" && root.result !== null
                sourceComponent: projectedDetail
            }

            BlockHistory {
                width: parent.width
                visible: root.kind === "history"
                feed: root.feed
                lang: root.lang
                btcZeichen: root.btcZeichen
                textColor: root.textColor
                dimColor: root.dimColor
                accentColor: root.accentColor
                uiFont: root.uiFont
                onBlockPicked: function (hash) {
                    root.go("blockhash", hash);
                }
            }
        }
    }

    // === Transaction ===
    Component {
        id: txDetail

        Column {
            id: txBox

            spacing: root.scaleUnit * 0.45

            readonly property var d: root.result
            readonly property bool confirmed: !!(d.status && d.status.confirmed)

            Row {
                spacing: root.uiFont * 0.6

                Text {
                    anchors.verticalCenter: kindBadge.verticalCenter
                    text: Tr.t("tx.title", root.lang)
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.62
                }

                // The type is derived from the structure: an interpretation, not a property
                // of the transaction. So it is shown as a label with an explanation, not as
                // a fact.
                Rectangle {
                    id: kindBadge

                    readonly property string kind: TxType.classify(root.result)
                    readonly property var meta: TxType.info(kindBadge.kind)

                    width: kindLabel.width + root.uiFont * 1.1
                    height: kindLabel.height + root.uiFont * 0.5
                    radius: height / 2
                    color: Qt.rgba(kindBadge.meta.color.r || 0, 0, 0, 0)

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: kindBadge.meta.color
                        opacity: 0.22
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: "transparent"
                        border.width: 1
                        border.color: kindBadge.meta.color
                        opacity: 0.6
                    }

                    Text {
                        id: kindLabel

                        anchors.centerIn: parent
                        text: Tr.t(TxType.labelKey(kindBadge.kind), root.lang)
                        color: kindBadge.meta.color
                        font.pixelSize: root.uiFont * 0.85
                        font.bold: true
                    }
                }

                Text {
                    anchors.verticalCenter: kindBadge.verticalCenter
                    width: Math.min(flick.width - kindBadge.width - root.uiFont * 10, implicitWidth)
                    elide: Text.ElideRight
                    text: Tr.t(TxType.labelKey(kindBadge.kind) + ".help", root.lang)
                    color: root.dimColor
                    font.pixelSize: root.uiFont * 0.8
                }
            }

            Row {
                spacing: root.uiFont * 0.5

                Text {
                    id: txidLabel

                    width: Math.min(flick.width - root.uiFont * 6, implicitWidth)
                    elide: Text.ElideMiddle
                    // While switching pages there is briefly a result without txid. Without the
                    // `|| ""` Qt reports "Unable to assign [undefined] to QString".
                    text: root.result.txid || ""
                    color: root.accentColor
                    font.pixelSize: root.scaleUnit * 0.8
                    font.family: Fonts.mono()

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.copyText(root.result.txid)
                    }
                }

                CopyButton {
                    anchors.verticalCenter: txidLabel.verticalCenter
                    text: root.result.txid || ""
                    done: root.copied === (root.result.txid || "")
                    size: root.uiFont * 1.05
                    iconColor: root.dimColor
                    hoverColor: root.textColor
                    doneColor: root.goodColor
                    onCopy: function (what) { root.copyText(what); }
                }
            }

            Row {
                spacing: root.scaleUnit * 1.2

                Repeater {
                    model: [
                        { "k": Tr.t("tx.status", root.lang), "v": txBox.confirmed
                            ? Tr.t("tx.inBlock", root.lang, root.grp(root.result.status.block_height))
                            : Tr.t("tx.inMempool", root.lang) },
                        { "k": Tr.t("size", root.lang), "v": Tr.t("unit.byte", root.lang, root.grp(root.result.size)) },
                        { "k": Tr.t("weight", root.lang), "v": root.grp(root.result.weight) + " WU" },
                        { "k": Tr.t("fee", root.lang), "v": root.grp(root.result.fee) + " sat" },
                        { "k": Tr.t("feeRate", root.lang), "v": root.result.weight
                            ? Tr.fixed((root.result.fee / (root.result.weight / 4)), 2, root.lang) + " sat/vB" : "–" }
                    ]

                    Column {
                        id: sc

                        required property var modelData

                        spacing: root.scaleUnit * 0.1

                        Text {
                            text: sc.modelData.k
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.55
                        }

                        Text {
                            text: sc.modelData.v
                            color: root.textColor
                            font.pixelSize: root.scaleUnit * 0.75
                        }
                    }
                }
            }

            // --- Details ---
            Grid {
                columns: 2
                columnSpacing: root.scaleUnit * 2
                rowSpacing: root.scaleUnit * 0.2

                Repeater {
                    model: [
                        { "k": Tr.t("tx.vsize", root.lang), "v": root.result.weight
                            ? Tr.fixed((root.result.weight / 4 / 1000), 2, root.lang) + " kvB" : "–" },
                        { "k": Tr.t("block.version", root.lang), "v": String(root.result.version !== undefined ? root.result.version : "–") },
                        { "k": Tr.t("weight", root.lang), "v": root.result.weight
                            ? Tr.fixed((root.result.weight / 1000), 2, root.lang) + " kWU" : "–" },
                        { "k": Tr.t("tx.locktime", root.lang), "v": String(root.result.locktime !== undefined ? root.result.locktime : "–") },
                        { "k": Tr.t("size", root.lang), "v": root.result.size
                            ? Tr.fixed((root.result.size / 1000), 2, root.lang) + " kB" : "–" },
                        { "k": Tr.t("tx.sigops", root.lang), "v": String(root.result.sigops !== undefined ? root.result.sigops : "–") }
                    ]

                    Row {
                        id: dRow

                        required property var modelData

                        spacing: root.scaleUnit * 0.6

                        Text {
                            width: root.scaleUnit * 7
                            text: dRow.modelData.k
                            color: root.dimColor
                            font.pixelSize: root.uiFont * 0.9
                        }

                        Text {
                            text: dRow.modelData.v
                            color: root.textColor
                            font.pixelSize: root.uiFont * 0.9
                        }
                    }
                }
            }

            Item {
                width: 1
                height: root.scaleUnit * 0.3
            }

            // The flow: amounts as bands, in on the left, out on the right.
            Text {
                text: Tr.t("tx.flow", root.lang)
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.6
            }

            TxFlow {
                width: flick.width
                lang: root.lang
                btcZeichen: root.btcZeichen
                // In the chain view both sides belong to the same transaction, which is
                // shown above the details.
                txid: String(root.result.txid || "")
                // The curve depends on the ratio of height to width. The original draws at
                // 1200 x 600; this area is much flatter, so it gets more height with each
                // band. The strand stays the same thickness, so the gaps open up.
                //
                // The count is the actual bands: on the output side the fee counts too,
                // otherwise it gets too tight there. The cap is high; if the area gets taller
                // than the window, the explorer scrolls anyway.
                readonly property int bandCount: Math.max((root.result.vin || []).length,
                                                          (root.result.vout || []).length
                                                          + ((root.result.fee || 0) > 0 ? 1 : 0))
                height: Math.max(root.scaleUnit * 9, Math.min(root.scaleUnit * 48,
                        root.scaleUnit * 1.5 * bandCount + root.scaleUnit * 5))
                vin: root.result.vin || []
                vout: root.result.vout || []
                fee: root.result.fee || 0
                outColor: root.accentColor
                textColor: root.textColor
                dimColor: root.dimColor
                labelSize: root.scaleUnit * 0.62

                onActivated: function (side, index) {
                    if (side === "in") {
                        var vi = (root.result.vin || [])[index];
                        if (vi && vi.txid)
                            root.go("tx", vi.txid);
                    } else if (side === "out") {
                        var sp = root.extra && root.extra[index];
                        var vo = (root.result.vout || [])[index];
                        if (sp && sp.spent && sp.txid)
                            root.go("tx", sp.txid);
                        else if (vo && vo.scriptpubkey_address)
                            root.go("address", vo.scriptpubkey_address);
                    }
                }
            }

            Item {
                width: 1
                height: root.scaleUnit * 0.3
            }

            // Inputs and outputs side by side: the path of the money.
            Row {
                width: flick.width
                spacing: root.scaleUnit

                Column {
                    width: (flick.width - root.scaleUnit * 2) / 2
                    spacing: root.scaleUnit * 0.2

                    Text {
                        text: Tr.t("tx.nIn", root.lang, (root.result.vin || []).length)
                        color: root.dimColor
                        font.pixelSize: root.scaleUnit * 0.6
                    }

                    Repeater {
                        model: (root.result.vin || []).slice(0, 25)

                        Rectangle {
                            id: vinRow

                            required property var modelData

                            width: parent.width
                            height: vinCol.implicitHeight + root.scaleUnit * 0.4
                            radius: 4
                            color: vinArea.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.03)

                            Column {
                                id: vinCol

                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: root.scaleUnit * 0.4
                                spacing: 1

                                Text {
                                    width: parent.width
                                    elide: Text.ElideMiddle
                                    text: vinRow.modelData.prevout
                                        ? (vinRow.modelData.prevout.scriptpubkey_address
                                           || Tr.t("search.noFormat", root.lang))
                                        : Tr.t("tx.coinbase", root.lang)
                                    color: root.textColor
                                    font.pixelSize: root.scaleUnit * 0.6
                                    font.family: Fonts.mono()
                                }

                                Text {
                                    text: vinRow.modelData.prevout
                                        ? root.btc(vinRow.modelData.prevout.value) : ""
                                    color: root.dimColor
                                    font.pixelSize: root.scaleUnit * 0.6
                                }
                            }

                            MouseArea {
                                id: vinArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: vinRow.modelData.txid ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (vinRow.modelData.txid)
                                        root.go("tx", vinRow.modelData.txid);
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    // Showed up as an empty box on the phone as well. See `pfeilKurz` in `FeedTabs`.
                    text: root.pfeilKurz
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 1.2
                }

                Column {
                    width: (flick.width - root.scaleUnit * 2) / 2
                    spacing: root.scaleUnit * 0.2

                    Text {
                        text: Tr.t("tx.nOut", root.lang, (root.result.vout || []).length)
                        color: root.dimColor
                        font.pixelSize: root.scaleUnit * 0.6
                    }

                    Repeater {
                        model: (root.result.vout || []).slice(0, 25)

                        Rectangle {
                            id: voutRow

                            required property var modelData
                            required property int index

                            readonly property var spend: (root.extra && root.extra[voutRow.index]) || null

                            width: parent.width
                            height: voutCol.implicitHeight + root.scaleUnit * 0.4
                            radius: 4
                            color: voutArea.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.03)

                            Column {
                                id: voutCol

                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: root.scaleUnit * 0.4
                                spacing: 1

                                Text {
                                    width: parent.width
                                    elide: Text.ElideMiddle
                                    text: voutRow.modelData.scriptpubkey_address
                                        || ("(" + (voutRow.modelData.scriptpubkey_type || "unbekannt") + ")")
                                    color: root.textColor
                                    font.pixelSize: root.scaleUnit * 0.6
                                    font.family: Fonts.mono()
                                }

                                Row {
                                    spacing: root.scaleUnit * 0.4

                                    Text {
                                        text: root.btc(voutRow.modelData.value)
                                        color: root.dimColor
                                        font.pixelSize: root.scaleUnit * 0.6
                                    }

                                    Text {
                                        visible: voutRow.spend !== null
                                        text: voutRow.spend && voutRow.spend.spent
                                            ? Tr.t("tx.spent", root.lang)
                                            : Tr.t("tx.unspent", root.lang)
                                        color: voutRow.spend && voutRow.spend.spent
                                            ? root.accentColor : root.goodColor
                                        font.pixelSize: root.scaleUnit * 0.55
                                    }
                                }
                            }

                            MouseArea {
                                id: voutArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    // Keep following the path: to the spending transaction if the output was
                                    // spent, otherwise to the address.
                                    if (voutRow.spend && voutRow.spend.spent && voutRow.spend.txid)
                                        root.go("tx", voutRow.spend.txid);
                                    else if (voutRow.modelData.scriptpubkey_address)
                                        root.go("address", voutRow.modelData.scriptpubkey_address);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // === Projected block ===
    Component {
        id: projectedDetail

        Column {
            id: projBox

            spacing: root.scaleUnit * 0.45

            // Not `root.result`: that is the state at the time of the click. The state
            // keeps the projected blocks current, so read from there, and only while the
            // rank still exists.
            readonly property var d: (root.feed && root.feed.projected
                                      && root.feed.projected.length > root.projRank)
                ? root.feed.projected[root.projRank] : root.result
            readonly property var range: projBox.d.feeRange || []

            Text {
                text: root.projRank === 0 ? Tr.t("nextBlock", root.lang)
                                          : Tr.t("proj.nth", root.lang, root.projRank + 1)
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.62
            }

            Text {
                // Below 10 sat/vB with one decimal, otherwise quiet times show a big "~0".
                text: "~" + (projBox.d.medianFee >= 10
                    ? Math.round(projBox.d.medianFee)
                    : Tr.fixed(projBox.d.medianFee, 1, root.lang)) + " sat/vB"
                color: root.accentColor
                font.pixelSize: root.scaleUnit * 1.8
                font.bold: true
            }

            Row {
                spacing: root.scaleUnit * 1.2

                Repeater {
                    model: [
                        { "k": Tr.t("transactions", root.lang), "v": root.grp(projBox.d.nTx) },
                        { "k": Tr.t("size", root.lang), "v": Tr.fixed((projBox.d.blockSize / 1e6), 2, root.lang) + " MB" },
                        { "k": Tr.t("fees", root.lang), "v": root.btc(projBox.d.totalFees) },
                        { "k": Tr.t("block.expected", root.lang), "v": root.etaFor(root.projRank) }
                    ]

                    Column {
                        id: pc

                        required property var modelData

                        spacing: root.scaleUnit * 0.1

                        Text {
                            text: pc.modelData.k
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.55
                        }

                        Text {
                            text: pc.modelData.v
                            color: root.textColor
                            font.pixelSize: root.scaleUnit * 0.75
                        }
                    }
                }
            }

            Item {
                width: 1
                height: root.scaleUnit * 0.4
            }

            // The practical part: what you have to pay to get in.
            Rectangle {
                width: flick.width
                height: hintCol.implicitHeight + root.uiFont * 1.6
                radius: root.uiFont * 0.4
                color: Qt.rgba(1, 1, 1, 0.04)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.08)

                Column {
                    id: hintCol

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: root.uiFont * 0.9
                    spacing: root.uiFont * 0.35

                    Text {
                        text: projBox.range.length
                            ? Tr.t("proj.minFee", root.lang,Tr.fixed(
                                   projBox.range[0], 2, root.lang))
                            : ""
                        color: root.textColor
                        font.pixelSize: root.uiFont * 1.05
                    }

                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: projBox.range.length
                            ? Tr.t("proj.range", root.lang,Tr.fixed(
                                   projBox.range[0], 2, root.lang),Tr.fixed(
                                   projBox.range[projBox.range.length - 1], 2, root.lang))
                            : ""
                        color: root.dimColor
                        font.pixelSize: root.uiFont * 0.85
                    }
                }
            }

            Text {
                text: Tr.t("proj.fits", root.lang)
                color: root.dimColor
                font.pixelSize: root.uiFont * 0.9
            }

            ProjectedBlock {
                width: flick.width
                btcZeichen: root.btcZeichen
                tileHeight: Math.min(flick.width, root.scaleUnit * 34)
                rank: root.projRank
                live: root.visible && root.kind === "projected"
                showHeader: false
                lang: root.lang
                colorMode: root.tileColorMode
                onColorModeRequested: function (m) {
                    root.tileColorModeRequested(m);
                }
                feed: root.feed
                textColor: root.textColor
                dimColor: root.dimColor
                accentColor: root.accentColor
                uiFont: root.uiFont
                onTxPicked: function (txid) {
                    root.go("tx", txid);
                }
            }

            Text {
                width: flick.width
                wrapMode: Text.WordWrap
                // Explains how this differs from a confirmed block.
                text: Tr.t("proj.forecast", root.lang)
                color: root.dimColor
                font.pixelSize: root.uiFont * 0.85
            }
        }
    }

    // === Block ===
    Component {
        id: blockDetail

        Column {
            id: blockBox

            spacing: root.scaleUnit * 0.45

            readonly property var d: root.result

            Text {
                text: Tr.t("block", root.lang)
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.62
            }

            Text {
                text: root.grp(root.result.height)
                color: root.accentColor
                font.pixelSize: root.scaleUnit * 1.8
                font.bold: true
            }

            Row {
                spacing: root.uiFont * 0.5

                Text {
                    id: hashLabel

                    width: Math.min(flick.width - root.uiFont * 6, implicitWidth)
                    elide: Text.ElideMiddle
                    text: root.result.id
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.62
                    font.family: Fonts.mono()

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.copyText(root.result.id)
                    }
                }

                CopyButton {
                    anchors.verticalCenter: hashLabel.verticalCenter
                    text: root.result.id
                    done: root.copied === root.result.id
                    size: root.uiFont * 1.05
                    iconColor: root.dimColor
                    hoverColor: root.textColor
                    doneColor: root.goodColor
                    onCopy: function (what) { root.copyText(what); }
                }
            }

            Row {
                spacing: root.scaleUnit * 1.2

                readonly property var ex: root.result.extras || ({})

                Repeater {
                    model: [
                        { "k": Tr.t("time", root.lang), "v": root.ago(root.result.timestamp) },
                        { "k": Tr.t("transactions", root.lang), "v": root.grp(root.result.tx_count) },
                        { "k": Tr.t("size", root.lang), "v": root.grp(Math.round(root.result.size / 1024)) + " kB" },
                        { "k": Tr.t("weight", root.lang), "v": root.grp(Math.round(root.result.weight / 1000)) + " kWU" },
                        { "k": Tr.t("block.pool", root.lang), "v": ((root.result.extras || {}).pool || {}).name || "–" },
                        { "k": Tr.t("reward", root.lang), "v": (root.result.extras || {}).reward
                            ? root.btc((root.result.extras || {}).reward) : "–" }
                    ]

                    Column {
                        id: bc

                        required property var modelData

                        spacing: root.scaleUnit * 0.1

                        Text {
                            text: bc.modelData.k
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.55
                        }

                        Text {
                            text: bc.modelData.v
                            color: root.textColor
                            font.pixelSize: root.scaleUnit * 0.75
                        }
                    }
                }
            }

            // More block details.
            Grid {
                columns: 2
                columnSpacing: root.scaleUnit * 2
                rowSpacing: root.scaleUnit * 0.2

                Repeater {
                    model: {
                        var e = root.result.extras || {};
                        return [
                            { "k": Tr.t("block.totalFees", root.lang), "v": e.totalFees ? root.btc(e.totalFees) : "–" },
                            { "k": Tr.t("difficulty", root.lang), "v": root.result.difficulty
                                ? Tr.fixed((root.result.difficulty / 1e12), 2, root.lang) + " T" : "–" },
                            { "k": Tr.t("block.avgRate", root.lang), "v": e.medianFee !== undefined
                                ? Tr.fixed(e.medianFee, 2, root.lang) + " sat/vB" : "–" },
                            { "k": Tr.t("block.version", root.lang), "v": root.result.version !== undefined
                                ? "0x" + Number(root.result.version).toString(16) : "–" },
                            { "k": Tr.t("block.feeRange", root.lang), "v": (e.feeRange && e.feeRange.length)
                                ? Math.round(e.feeRange[0]) + " – " + Math.round(e.feeRange[e.feeRange.length - 1]) + " sat/vB" : "–" },
                            { "k": Tr.t("block.nonce", root.lang), "v": root.grp(root.result.nonce) },
                            { "k": Tr.t("block.utxoDelta", root.lang), "v": e.utxoSetChange !== undefined
                                ? (e.utxoSetChange >= 0 ? "+" : "") + root.grp(e.utxoSetChange) : "–" },
                            { "k": "SegWit", "v": (e.segwitTotalTxs && root.result.tx_count)
                                ? Math.round(100 * e.segwitTotalTxs / root.result.tx_count) + " %" : "–" },
                            { "k": Tr.t("block.avgTx", root.lang), "v": e.avgTxSize !== undefined
                                ? Tr.t("unit.byte", root.lang, Math.round(e.avgTxSize)) : "–" },
                            { "k": Tr.t("block.merkle", root.lang), "v": root.result.merkle_root
                                ? root.shortId(root.result.merkle_root, 8) : "–" }
                        ];
                    }

                    Row {
                        id: bRow

                        required property var modelData

                        spacing: root.scaleUnit * 0.6

                        Text {
                            width: root.scaleUnit * 7
                            text: bRow.modelData.k
                            color: root.dimColor
                            font.pixelSize: root.uiFont * 0.9
                        }

                        Text {
                            text: bRow.modelData.v
                            color: root.textColor
                            font.pixelSize: root.uiFont * 0.9
                        }
                    }
                }
            }

            // The block's tile graphic, same look as in the feed.
            Text {
                text: Tr.t(root.tilesBusy ? "block.tilesLoading" : "block.txsIn", root.lang)
                color: root.dimColor
                font.pixelSize: root.uiFont * 0.9
            }

            TileGoggles {
                width: flick.width
                visible: root.tiles !== null
                mode: root.tileColorMode
                lang: root.lang
                counts: blockTiles.typeCounts
                total: blockTiles.squares.length
                textColor: root.textColor
                dimColor: root.dimColor
                accentColor: root.accentColor
                uiFont: root.uiFont
                onPicked: function (m) {
                    root.tileColorModeRequested(m);
                }
            }

            BlockTiles {
                id: blockTiles

                btcZeichen: root.btcZeichen
                width: flick.width
                height: Math.min(flick.width, root.scaleUnit * 34)
                visible: root.tiles !== null
                block: root.tiles
                colorMode: root.tileColorMode
                lang: root.lang
                dimColor: root.dimColor
                labelSize: root.uiFont * 0.85
                onTxPicked: function (txid) {
                    root.go("tx", txid);
                }
            }

            // The same transactions in order, for browsing.
            TxList {
                width: flick.width
                visible: root.tiles !== null
                block: root.tiles
                colorMode: root.tileColorMode
                lang: root.lang
                btcZeichen: root.btcZeichen
                textColor: root.textColor
                dimColor: root.dimColor
                accentColor: root.accentColor
                uiFont: root.uiFont
                onTxPicked: function (txid) {
                    root.go("tx", txid);
                }
            }

            Row {
                spacing: root.scaleUnit * 0.5

                Rectangle {
                    width: prevLabel.width + root.scaleUnit * 0.8
                    height: prevLabel.height + root.scaleUnit * 0.4
                    radius: height / 2
                    color: prevArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)

                    Text {
                        id: prevLabel

                        anchors.centerIn: parent
                        text: Tr.t("block.prev", root.lang)
                        color: root.textColor
                        font.pixelSize: root.scaleUnit * 0.6
                    }

                    MouseArea {
                        id: prevArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.go("blockhash", root.result.previousblockhash)
                    }
                }

                Rectangle {
                    visible: root.feed && root.result.height < root.feed.tipHeight
                    width: nextLabel.width + root.scaleUnit * 0.8
                    height: nextLabel.height + root.scaleUnit * 0.4
                    radius: height / 2
                    color: nextArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)

                    Text {
                        id: nextLabel

                        anchors.centerIn: parent
                        text: Tr.t("block.next", root.lang)
                        color: root.textColor
                        font.pixelSize: root.scaleUnit * 0.6
                    }

                    MouseArea {
                        id: nextArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.go("blockheight", String(root.result.height + 1))
                    }
                }
            }
        }
    }

    // === Address ===
    Component {
        id: addressDetail

        Column {
            id: addrBox

            spacing: root.scaleUnit * 0.45

            readonly property var d: root.result
            readonly property var cs: d.chain_stats || ({})
            readonly property var ms: d.mempool_stats || ({})
            readonly property real balance: (cs.funded_txo_sum || 0) - (cs.spent_txo_sum || 0)
                                            + (ms.funded_txo_sum || 0) - (ms.spent_txo_sum || 0)

            Text {
                text: Tr.t("address", root.lang)
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.62
            }

            Row {
                spacing: root.uiFont * 0.5

                Text {
                    id: addrLabel

                    width: Math.min(flick.width - root.uiFont * 6, implicitWidth)
                    elide: Text.ElideMiddle
                    text: root.result.address
                    color: root.accentColor
                    font.pixelSize: root.scaleUnit * 0.8
                    font.family: Fonts.mono()

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.copyText(root.result.address)
                    }
                }

                CopyButton {
                    anchors.verticalCenter: addrLabel.verticalCenter
                    text: root.result.address
                    done: root.copied === root.result.address
                    size: root.uiFont * 1.05
                    iconColor: root.dimColor
                    hoverColor: root.textColor
                    doneColor: root.goodColor
                    onCopy: function (what) { root.copyText(what); }
                }
            }

            Row {
                spacing: root.scaleUnit * 1.2

                Repeater {
                    model: [
                        { "k": Tr.t("balance", root.lang), "v": root.btc(addrBox.balance) },
                        { "k": Tr.t("transactions", root.lang), "v": root.grp((addrBox.cs.tx_count || 0)
                                                              + (addrBox.ms.tx_count || 0)) },
                        { "k": Tr.t("addr.received", root.lang), "v": root.btc(addrBox.cs.funded_txo_sum) },
                        { "k": Tr.t("addr.sent", root.lang), "v": root.btc(addrBox.cs.spent_txo_sum) }
                    ]

                    Column {
                        id: ac

                        required property var modelData

                        spacing: root.scaleUnit * 0.1

                        Text {
                            text: ac.modelData.k
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.55
                        }

                        Text {
                            text: ac.modelData.v
                            color: root.textColor
                            font.pixelSize: root.scaleUnit * 0.75
                        }
                    }
                }
            }

            Text {
                visible: (root.extra || []).length > 0
                text: Tr.t("addr.lastTxs", root.lang)
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.6
            }

            Repeater {
                model: (root.extra || []).slice(0, 15)

                Rectangle {
                    id: atxRow

                    required property var modelData

                    width: flick.width
                    height: root.scaleUnit * 1.5
                    radius: 4
                    color: atxArea.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.03)

                    Row {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: root.scaleUnit * 0.4
                        spacing: root.scaleUnit * 0.6

                        Text {
                            width: root.scaleUnit * 9
                            elide: Text.ElideMiddle
                            text: atxRow.modelData.txid
                            color: root.textColor
                            font.pixelSize: root.scaleUnit * 0.6
                            font.family: Fonts.mono()
                        }

                        Text {
                            text: atxRow.modelData.status && atxRow.modelData.status.confirmed
                                ? root.ago(atxRow.modelData.status.block_time)
                                : Tr.t("tx.inMempool", root.lang)
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.6
                        }
                    }

                    MouseArea {
                        id: atxArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.go("tx", atxRow.modelData.txid)
                    }
                }
            }
        }
    }
}
