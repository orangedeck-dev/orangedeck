// Liquidation heatmap, the third sub-tab of the market view.
//
// This is computed, not measured. It does not show where liquidations
// happened (the tab next to it does that), but where positions would sit
// and at which price they would be wiped out. That is why the bright bands
// lie ahead of the price; a measurement cannot do that, it knows no future.
//
// Two assumptions go into it, both made up: the leverage distribution and
// the long/short split. The service sends them along and this view shows
// them. An estimate posing as a measurement would be worse than none.
//
// Only `import QtQuick`, so this also runs on Android.
import QtQuick
import "strings.js" as Tr
import "fonts.js" as Fonts

pragma ComponentBehavior: Bound

Item {
    id: root

    property string lang: "de"
    property string zeichen: "$"
    // Response of /market/heatmap
    property var yAchse: []
    property var zellen: []
    property real hoechst: 0
    property var schlusskurse: []
    property var hebel: []
    // True when the chosen span was longer than the model covers and was
    // clipped for that reason.
    property bool beschnitten: false
    property int maxTage: 30

    property color textColor: "#e6e0e9"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property color lineColor: "#2a2a38"
    property real baseFont: 12

    readonly property bool hatDaten: root.hoechst > 0 && root.zellen.length > 0
    readonly property real letzterKurs: root.schlusskurse.length
        ? root.schlusskurse[root.schlusskurse.length - 1] : 0

    // The side is given by position, not by colour, and that follows
    // necessarily, it is not a convention.
    //
    // A long level sits below its entry price. If the price were below it
    // today, it would have crossed it and the sweep rule would have removed
    // it. So every surviving long level is below the price and every short
    // level above. Checked over thirty days including a jump from 64,000 to
    // 78,000: 49 occupied levels, zero errors, 0.0 % of the amount misplaced.
    //
    // Red and green would add nothing the price line does not already say.
    // Coinglass does not colour sides for the same reason (their API returns
    // one amount per cell, no side). What was missing was making the rule
    // visible.

    // Leverage tiers as text so the assumption is shown instead of hidden
    // in the source: "5x 30 %, 10x 30 %, ..."
    readonly property string hebelText: {
        var t = [];
        for (var i = 0; i < root.hebel.length; i++)
            t.push(root.hebel[i][0] + "× " + Math.round(root.hebel[i][1] * 100) + " %");
        return t.join(" · ");
    }

    // The colour lives in one place. One function instead of the same
    // formula twice, otherwise image and legend drift apart, and a wrong
    // legend is worse than none.
    //
    // `t` is the share of the highest value, with a square-root-like curve
    // instead of linear: amounts span three orders of magnitude, and linear
    // would leave everything but the brightest cell black.
    function farbeFuer(anteil) {
        var t = Math.pow(Math.max(0, Math.min(1, anteil)), 0.45);
        return Qt.rgba(Math.min(1, 0.35 + t * 0.65),
                       Math.max(0, Math.min(1, (t - 0.35) * 1.5)),
                       Math.max(0, (t - 0.8) * 2.5),
                       Math.min(0.95, 0.12 + t));
    }

    function geld(v) {
        if (v >= 1e9)
            return Tr.fixed(v / 1e9, 1, root.lang) + " G";
        if (v >= 1e6)
            return Tr.fixed(v / 1e6, 1, root.lang) + " M";
        if (v >= 1000)
            return Math.round(v / 1000) + " k";
        return Math.round(v) + "";
    }

    // --------------------------------------------------------- header
    Column {
        id: kopf

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: root.baseFont * 0.3

        Row {
            spacing: root.baseFont * 0.5

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Tr.t("market.heatTitle", root.lang)
                color: root.textColor
                font.pixelSize: root.baseFont
                font.bold: true
            }

            // The warning badge is part of the view, not a footnote.
            // Removing it turns an estimate into a claim.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: warn.implicitWidth + root.baseFont * 0.8
                height: warn.implicitHeight + root.baseFont * 0.25
                radius: height / 2
                color: "transparent"
                border.width: 1
                border.color: root.accentColor

                Text {
                    id: warn

                    anchors.centerIn: parent
                    text: Tr.t("market.estimate", root.lang)
                    color: root.accentColor
                    font.pixelSize: root.baseFont - 3
                    font.bold: true
                }
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: Tr.t("market.heatHow", root.lang)
            color: root.dimColor
            font.pixelSize: root.baseFont - 3
        }

        Text {
            width: parent.width
            visible: root.hebel.length > 0
            wrapMode: Text.WordWrap
            text: Tr.t("market.heatAssume", root.lang, root.hebelText)
            color: root.dimColor
            font.pixelSize: root.baseFont - 3
            font.family: Fonts.mono()
        }

        // A span different from the chosen one has to be stated, otherwise
        // thirty-day bands get read as five-year bands.
        Text {
            width: parent.width
            visible: root.beschnitten
            wrapMode: Text.WordWrap
            text: Tr.t("market.heatClamped", root.lang, root.maxTage)
            color: root.accentColor
            font.pixelSize: root.baseFont - 3
        }
    }

    // ---------------------------------------------------------- image
    Item {
        id: bild

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: kopf.bottom
        anchors.bottom: legende.visible ? legende.top : parent.bottom
        anchors.topMargin: root.baseFont * 0.6
        anchors.bottomMargin: legende.visible ? root.baseFont * 0.3 : 0

        readonly property real achse: root.baseFont * 4.2
        readonly property real feld: Math.max(10, width - achse - root.baseFont * 0.5)

        Text {
            anchors.centerIn: parent
            visible: !root.hatDaten
            width: parent.width * 0.8
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: Tr.t("market.heatEmpty", root.lang)
            color: root.dimColor
            font.pixelSize: root.baseFont - 1
        }

        Canvas {
            id: leinwand

            visible: root.hatDaten
            x: bild.achse
            width: bild.feld
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            antialiasing: false

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var n = root.zellen.length;
                if (!n || root.hoechst <= 0)
                    return;
                var spalten = root.schlusskurse.length || 1;
                var stufen = root.yAchse.length || 1;
                var bw = width / spalten;
                var bh = height / stufen;
                // Square-root-like curve instead of linear, see farbeFuer.
                for (var i = 0; i < n; i++) {
                    var z = root.zellen[i];
                    // Dark red through orange to yellow, matching the
                    // heat the name promises.
                    ctx.fillStyle = root.farbeFuer(z[2] / root.hoechst);
                    // Level 0 is at the bottom: flip the y axis
                    ctx.fillRect(Math.floor(z[0] * bw),
                                 Math.floor((stufen - 1 - z[1]) * bh),
                                 Math.ceil(bw) + 1, Math.ceil(bh) + 1);
                }

                // Price line on top. Without it the bands mean nothing,
                // the question is always "where relative to now".
                if (root.yAchse.length > 1 && root.schlusskurse.length > 1) {
                    var tief = root.yAchse[0];
                    var hoch = root.yAchse[root.yAchse.length - 1];
                    if (hoch > tief) {
                        ctx.strokeStyle = "#ffffff";
                        ctx.lineWidth = 1.2;
                        ctx.globalAlpha = 0.85;
                        ctx.beginPath();
                        for (var x = 0; x < root.schlusskurse.length; x++) {
                            var yy = height * (1 - (root.schlusskurse[x] - tief) / (hoch - tief));
                            if (x === 0)
                                ctx.moveTo(x * bw + bw / 2, yy);
                            else
                                ctx.lineTo(x * bw + bw / 2, yy);
                        }
                        ctx.stroke();
                        ctx.globalAlpha = 1;
                    }
                }
            }
        }

        // Where the price is right now, the line that separates long and
        // short. The running curve shows it over time, this marker shows
        // the current moment.
        Item {
            id: kursMarke

            visible: root.hatDaten && root.letzterKurs > 0
                     && root.yAchse.length > 1
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            y: {
                if (root.yAchse.length < 2)
                    return 0;
                var tief = root.yAchse[0];
                var hoch = root.yAchse[root.yAchse.length - 1];
                if (hoch <= tief)
                    return 0;
                var t = (hoch - root.letzterKurs) / (hoch - tief);
                return Math.max(0, Math.min(1, t)) * bild.height;
            }

            Rectangle {
                anchors.fill: parent
                color: root.accentColor
                opacity: 0.55
            }

            Text {
                anchors.right: parent.right
                anchors.bottom: parent.top
                anchors.bottomMargin: 1
                text: "▲ " + Tr.t("market.shortsShort", root.lang)
                color: root.accentColor
                font.pixelSize: Math.max(7, root.baseFont - 3)
            }

            Text {
                anchors.right: parent.right
                anchors.top: parent.bottom
                anchors.topMargin: 1
                text: "▼ " + Tr.t("market.longsShort", root.lang)
                color: root.accentColor
                font.pixelSize: Math.max(7, root.baseFont - 3)
            }
        }

        // Price axis on the left
        Repeater {
            model: root.hatDaten ? root.yAchse : []

            Text {
                id: marke

                required property var modelData
                required property int index

                readonly property real zeilenhoehe:
                    bild.height / Math.max(1, root.yAchse.length)
                readonly property int jedeWievielte:
                    Math.max(1, Math.ceil((root.baseFont + 2) / zeilenhoehe))

                visible: marke.index % marke.jedeWievielte === 0
                x: 0
                y: bild.height - (marke.index + 1) * marke.zeilenhoehe
                width: bild.achse - root.baseFont * 0.4
                height: marke.zeilenhoehe
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                text: Tr.group(marke.modelData, root.lang)
                color: root.dimColor
                font.pixelSize: Math.max(7, root.baseFont - 3)
                font.family: Fonts.mono()
            }
        }

    }

    // ---------------------------------------------------------- legend
    // Without it the image is pretty and mute: nobody knows whether bright
    // means much or little, and the white line could be anything.
    // Two groups in one Flow: on a phone the legend does not fit on one
    // line and the price-line text ran off the edge. Each group stays a Row
    // because Flow has no vertical centering.
    Flow {
        id: legende

        visible: root.hatDaten
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: root.baseFont

        Row {
            spacing: root.baseFont * 0.5

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Tr.t("market.heatLittle", root.lang)
                color: root.dimColor
                font.pixelSize: Math.max(7, root.baseFont - 3)
            }

            // The gradient comes from the same function as the image
            Canvas {
                id: verlauf

                anchors.verticalCenter: parent.verticalCenter
                width: root.baseFont * 8
                height: Math.max(6, root.baseFont * 0.7)
                antialiasing: false

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    var schritte = 48;
                    for (var i = 0; i < schritte; i++) {
                        ctx.fillStyle = root.farbeFuer(i / (schritte - 1));
                        ctx.fillRect(i * width / schritte, 0,
                                     width / schritte + 1, height);
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Tr.t("market.heatMuch", root.lang) + "  "
                      + root.zeichen + " " + root.geld(root.hoechst)
                color: root.dimColor
                font.pixelSize: Math.max(7, root.baseFont - 3)
            }
        }

        Row {
            spacing: root.baseFont * 0.5

            // So nobody has to guess what the white line is
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: root.baseFont * 1.6
                height: 2
                color: "#ffffff"
                opacity: 0.85
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Tr.t("market.heatPriceLine", root.lang) + "  ·  "
                      + Tr.t("market.heatSides", root.lang)
                color: root.dimColor
                font.pixelSize: Math.max(7, root.baseFont - 3)
            }
        }
    }

    onZellenChanged: {
        leinwand.requestPaint();
        verlauf.requestPaint();
    }
    onWidthChanged: leinwand.requestPaint()
    onHeightChanged: leinwand.requestPaint()
}
