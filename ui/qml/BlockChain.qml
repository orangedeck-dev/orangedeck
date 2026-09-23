// The chain in one strip: projected blocks from the mempool on the left,
// confirmed blocks on the right, with the boundary between "pending" and
// "settled" in between. You see right away which block would be confirmed
// next.
//
// Order as in the original: projected blocks run from far out inwards,
// the next one sits right at the boundary; to its right the newest
// confirmed block, then older ones.
//
// Only imports QtQuick, so it also runs on Android.
import QtQuick
import "strings.js" as Tr

pragma ComponentBehavior: Bound

Item {
    id: root

    property var feed: null
    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    // Color separates the states: green is pending, violet is settled.
    property color pendingColor: "#2f9e63"
    property color minedColor: "#7b5cd6"
    property real uiFont: 13
    property string lang: "de"

    property var blocks: []
    // Fallback: projected blocks via REST. Only needed while the state does
    // not carry them yet.
    property var projected: []
    property string error: ""

    // Preferably from the state: they arrive over the WebSocket and change
    // with the feed, without a separate request.
    readonly property var projectedNow: (root.feed && root.feed.projected
                                         && root.feed.projected.length)
        ? root.feed.projected : root.projected

    signal blockPicked(string hash)
    // A projected block has no hash, so it is reported by its rank
    // (0 = the next one).
    signal projectedPicked(int rank, var data)

    // Expected time until this projected block. Based on the measured average
    // block time from the difficulty adjustment, not the nominal ten minutes.
    function etaFor(rank) {
        var avg = (root.feed && root.feed.difficulty.timeAvg) || 600000;
        var min = Math.round((rank + 1) * avg / 60000);
        if (min < 60)
            return Tr.t("in.min", root.lang, min);
        var h = Math.floor(min / 60);
        return Tr.t("in.hourMin", root.lang, h, min % 60);
    }

    implicitHeight: uiFont * 13.5

    // Tiles are square; a block is not a column. The edge length is the
    // smaller of column width and the space left below the label.
    readonly property real cellWidth: uiFont * 9
    readonly property real cardSide: Math.max(uiFont * 4,
        Math.min(cellWidth, implicitHeight - uiFont * 3.2))

    // Thousands separator per language: German uses a period, English a comma.
    // This matters: "1.234" means either one thousand two hundred thirty-four
    // or one point two three four depending on the language.
    function grp(n) {
        return Tr.group(n, root.lang);
    }

    // Fees below 10 sat/vB need one decimal. Rounded, every block would show
    // "~0 sat/vB" and a range of 0 to 0, exactly in the quiet times when the
    // number is interesting.
    function fee(n) {
        if (n === undefined || n === null)
            return "–";
        return n >= 10 ? String(Math.round(n)) : Tr.fixed(n, 1, root.lang);
    }

    function ago(ts) {
        if (!ts)
            return "";
        var s = Math.max(0, Math.floor(Date.now() / 1000 - ts));
        var m = Math.floor(s / 60);
        if (m < 1)
            return Tr.t("ago.now", root.lang);
        if (m < 60)
            return Tr.t("ago.min", root.lang, m);
        var h = Math.floor(m / 60);
        if (h < 48)
            return Tr.t("ago.hour", root.lang, h);
        return Tr.t("ago.day", root.lang, Math.floor(h / 24));
    }

    // Graded by fee in the same green: the next block carries the highest
    // fees and is brightest.
    function feeShade(medianFee) {
        var f = Math.max(0, Math.min(1, (medianFee || 0) / 12));
        return Qt.hsva(root.pendingColor.hsvHue, 0.45 + 0.3 * f, 0.34 + 0.30 * f, 1);
    }

    function reload() {
        if (!root.feed)
            return;
        root.feed.lookup("blocks", "recent", function (d, err) {
            if (err) {
                root.error = err;
                return;
            }
            root.error = "";
            root.blocks = d || [];
        });
        // Only request when the state has nothing; otherwise the request just
        // duplicates data that is already there.
        if (!(root.feed.projected && root.feed.projected.length))
            root.feed.lookup("mempoolblocks", "now", function (d, err) {
                if (!err)
                    root.projected = d || [];
            });
    }

    Component.onCompleted: reload()

    Connections {
        target: root.feed
        enabled: root.feed !== null
        function onBlockMined() {
            reloadTimer.restart();
        }
    }

    Timer {
        id: reloadTimer

        interval: 4000
        onTriggered: root.reload()
    }

    // The next block sits on the right at the boundary, later ones to its left
    readonly property var projectedShown: {
        var p = (root.projectedNow || []).slice(0, 8);
        var out = [];
        // Reversed so the next block sits on the right at the boundary; the
        // original rank is carried along.
        for (var i = p.length - 1; i >= 0; i--) {
            var e = {};
            for (var k in p[i])
                e[k] = p[i][k];
            e.rank = i;
            out.push(e);
        }
        return out;
    }

    Text {
        id: label

        anchors.left: parent.left
        anchors.top: parent.top
        text: Tr.t("chain.label", root.lang)
        color: root.dimColor
        font.pixelSize: root.uiFont * 0.85
    }

    Flickable {
        id: strip

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: label.bottom
        anchors.topMargin: root.uiFont * 0.5
        anchors.bottom: parent.bottom
        clip: true
        contentWidth: row.width
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds

        // On first layout scroll to the boundary, that is where things happen
        onContentWidthChanged: {
            if (contentWidth > width && contentX === 0)
                contentX = Math.max(0, pending.width - width * 0.45);
        }

        Row {
            id: row

            spacing: root.uiFont * 0.55

            // ------------------------------------------------ projected
            Row {
                id: pending

                spacing: root.uiFont * 0.55

                Repeater {
                    model: root.projectedShown

                    Item {
                        id: pcell

                        required property var modelData

                        width: root.cellWidth
                        height: strip.height

                        Text {
                            id: etaLabel

                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.etaFor(pcell.modelData.rank)
                            color: root.dimColor
                            font.pixelSize: root.uiFont * 0.85
                        }

                        BlockCard {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: etaLabel.bottom
                            anchors.topMargin: root.uiFont * 0.3
                            width: root.cardSide
                            height: root.cardSide
                            tone: root.feeShade(pcell.modelData.medianFee)
                            hovered: parea.containsMouse
                            cornerRadius: root.uiFont * 0.3

                            Column {
                                anchors.centerIn: parent
                                width: parent.width - root.uiFont
                                spacing: root.uiFont * 0.18

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "~" + root.fee(pcell.modelData.medianFee) + " sat/vB"
                                    color: "#ffffff"
                                    font.pixelSize: root.uiFont
                                    font.bold: true
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: (pcell.modelData.feeRange && pcell.modelData.feeRange.length)
                                        ? root.fee(pcell.modelData.feeRange[0]) + " – "
                                          + root.fee(pcell.modelData.feeRange[pcell.modelData.feeRange.length - 1])
                                        : ""
                                    color: Qt.rgba(1, 1, 1, 0.72)
                                    font.pixelSize: root.uiFont * 0.72
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Tr.t("txlist.count", root.lang, root.grp(pcell.modelData.nTx))
                                    color: Qt.rgba(1, 1, 1, 0.74)
                                    font.pixelSize: root.uiFont * 0.72
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Tr.fixed((pcell.modelData.blockSize / 1e6), 2, root.lang) + " MB"
                                    color: Qt.rgba(1, 1, 1, 0.74)
                                    font.pixelSize: root.uiFont * 0.72
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Tr.fixed((pcell.modelData.totalFees / 1e8), 3, root.lang) + " BTC"
                                    color: Qt.rgba(1, 1, 1, 0.74)
                                    font.pixelSize: root.uiFont * 0.72
                                }
                            }

                            // Fill level. It is the only part of the tile that visibly moves and
                            // shows the row is alive. The last block collects everything else and is
                            // therefore always full.
                            Item {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: root.uiFont * 0.4
                                height: root.uiFont * 0.28
                                // Only show it when it says something: a full block is the normal case,
                                // and a bar that is always full is just decoration.
                                visible: pcell.modelData.blockVSize !== undefined
                                         && pcell.modelData.blockVSize < 0.99e6

                                Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    color: Qt.rgba(0, 0, 0, 0.28)
                                }

                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(1,
                                        (pcell.modelData.blockVSize || 0) / 1e6))
                                    height: parent.height
                                    radius: height / 2
                                    color: Qt.rgba(1, 1, 1, 0.7)

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: 600
                                            easing.type: Easing.OutQuad
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: parea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.projectedPicked(pcell.modelData.rank, pcell.modelData)
                            }
                        }
                    }
                }
            }

            // ------------------------------------------------- the boundary
            Item {
                width: root.uiFont * 1.6
                height: strip.height
                visible: root.projectedShown.length > 0 && root.blocks.length > 0

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: root.uiFont * 1.8
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: root.uiFont * 0.4
                    width: 1
                    color: Qt.rgba(1, 1, 1, 0.18)
                }
            }

            // --------------------------------------------- confirmed
            Repeater {
                model: root.blocks

                Item {
                    id: cell

                    required property var modelData
                    required property int index

                    readonly property var ex: cell.modelData.extras || ({})

                    width: root.cellWidth
                    height: strip.height

                    Text {
                        id: heightLabel

                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.grp(cell.modelData.height)
                        color: root.accentColor
                        font.pixelSize: root.uiFont * 0.95
                        font.bold: true
                    }

                    BlockCard {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: heightLabel.bottom
                        anchors.topMargin: root.uiFont * 0.3
                        width: root.cardSide
                        height: root.cardSide
                        tone: root.minedColor
                        highlighted: cell.index === 0
                        hovered: area.containsMouse
                        cornerRadius: root.uiFont * 0.3

                        Column {
                            anchors.centerIn: parent
                            width: parent.width - root.uiFont
                            spacing: root.uiFont * 0.18

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: cell.ex.medianFee !== undefined
                                    ? "~" + root.fee(cell.ex.medianFee) + " sat/vB" : ""
                                color: Qt.rgba(1, 1, 1, 0.75)
                                font.pixelSize: root.uiFont * 0.75
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: cell.ex.reward
                                    ? Tr.fixed((cell.ex.reward / 1e8), 3, root.lang) + " BTC" : ""
                                color: "#ffffff"
                                font.pixelSize: root.uiFont * 0.95
                                font.bold: true
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Tr.t("txlist.count", root.lang, root.grp(cell.modelData.tx_count))
                                color: Qt.rgba(1, 1, 1, 0.72)
                                font.pixelSize: root.uiFont * 0.72
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Tr.fixed((cell.modelData.size / 1024 / 1024), 2, root.lang) + " MB"
                                color: Qt.rgba(1, 1, 1, 0.72)
                                font.pixelSize: root.uiFont * 0.72
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.ago(cell.modelData.timestamp)
                                color: Qt.rgba(1, 1, 1, 0.72)
                                font.pixelSize: root.uiFont * 0.72
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: (cell.ex.pool && cell.ex.pool.name) || ""
                                color: Qt.rgba(1, 1, 1, 0.92)
                                font.pixelSize: root.uiFont * 0.72
                            }
                        }

                        MouseArea {
                            id: area

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.blockPicked(cell.modelData.id)
                        }
                    }
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.blocks.length === 0
        text: root.error.length ? Tr.grund(root.error, root.lang) : Tr.t("loading", root.lang)
        color: root.dimColor
        font.pixelSize: root.uiFont * 0.85
    }
}
