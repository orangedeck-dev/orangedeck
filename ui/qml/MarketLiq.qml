// Liquidationen und Positionierung -- der zweite Unterreiter im Markt.
//
// Zwei Fragen, die der Kurs nicht beantwortet:
//
//   **Wie stehen die anderen?**  Der Anteil der Konten, die long sind, je
//   Boerse. Echte Zahlen der Boersen, keine Schaetzung.
//
//   **Wo mussten Positionen aufgeben?**  Ein Balken je Preisstufe aus den
//   Zwangsliquidationen, die der Dienst selbst gehoert hat.
//
// **Bewusst keine Heatmap nach Art von Coinglass.** Deren Bild ist gerechnet,
// nicht gemessen: aus offenem Interesse und *angenommenen* Hebeln wird
// hochgerechnet, wo Liquidationen laegen. Die echten Liquidationspreise
// offener Positionen kennt nur die Boerse, und niemand veroeffentlicht sie.
// Hier steht deshalb nur, was wirklich passiert ist -- weniger Bild, aber
// jede Angabe belegbar.
//
// Nur `import QtQuick` -- laeuft damit auch unter Android.
import QtQuick
import "strings.js" as Tr
import "fonts.js" as Fonts

pragma ComponentBehavior: Bound

Item {
    id: root

    property string lang: "de"
    property string zeichen: "$"
    // [[preisMitte, wertLong, wertShort], ...] -- Dollar je Preisstufe
    property var hist: []
    // [{id, name, long}] -- Anteil der Konten, die long stehen
    property var ratio: []
    // Seit wann ueberhaupt zugehoert wird, 0 = noch nie
    property int seit: 0
    // {id, name, online, since} je Quelle; `since` gibt es nur im Direktbezug
    property var liqQuellen: []
    // **Bybit getrennt, wenn es spaeter kam.** Im Direktbezug ist `seit` der
    // Beginn des OKX-Rueckgriffs, rund ein Tag zurueck; Bybit hat keinen
    // Rueckgriff und zaehlt erst ab dem Verbinden (15.09.2026). Der Dienst
    // hoert beiden gleich lange zu und schickt kein `since`.
    readonly property int bybitSeit: {
        for (var i = 0; i < root.liqQuellen.length; i++) {
            var q = root.liqQuellen[i];
            if (q.id === "bybit-liq" && q.since > 0)
                return q.since;
        }
        return 0;
    }

    function seitText() {
        var f = Tr.datum(root.lang) + " HH:mm";
        var s = Qt.formatDateTime(new Date(root.seit * 1000), f);
        if (root.bybitSeit > root.seit + 600)
            s += " (OKX), " + Qt.formatDateTime(new Date(root.bybitSeit * 1000), f) + " (Bybit)";
        return s;
    }
    property real preis: 0
    property var quellen: []

    property color textColor: "#e6e0e9"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property color lineColor: "#2a2a38"
    property real baseFont: 12

    readonly property color upColor: "#5cb946"
    readonly property color downColor: "#d33f3f"

    // Summen ueber das ganze Fenster -- die Zeile, die man zuerst liest
    readonly property real summeLong: {
        var s = 0;
        for (var i = 0; i < root.hist.length; i++)
            s += root.hist[i][1];
        return s;
    }
    readonly property real summeShort: {
        var s = 0;
        for (var i = 0; i < root.hist.length; i++)
            s += root.hist[i][2];
        return s;
    }
    readonly property real groessteStufe: {
        var m = 0;
        for (var i = 0; i < root.hist.length; i++)
            m = Math.max(m, root.hist[i][1] + root.hist[i][2]);
        return m;
    }
    // Der Dienst schickt auch leere Stufen -- sonst waere die Preisachse
    // keine. "Nichts gehoert" erkennt man deshalb nicht an der Laenge der
    // Liste, sondern daran, dass nirgends etwas steht.
    readonly property bool hatDaten: root.groessteStufe > 0

    // Kurze Schreibweise fuer Geld: 298.826 wird zu "299 k", 1.240.000 zu
    // "1,2 M". Neben zwanzig Balken hat eine volle Zahl keinen Platz, und
    // die Groessenordnung ist ohnehin das, was zaehlt.
    function geld(v) {
        if (v >= 1e9)
            return Tr.fixed(v / 1e9, 1, root.lang) + " G";
        if (v >= 1e6)
            return Tr.fixed(v / 1e6, 1, root.lang) + " M";
        if (v >= 1000)
            return Math.round(v / 1000) + " k";
        return Math.round(v) + "";
    }

    // ------------------------------------------------------ Positionierung
    Column {
        id: oben

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: root.baseFont * 0.35

        Text {
            text: Tr.t("market.longShort", root.lang)
            color: root.textColor
            font.pixelSize: root.baseFont
            font.bold: true
        }

        // **Anteil der Konten, nicht des Kapitals.** Ohne diesen Satz liest
        // man 53 % als Uebergewicht -- es heisst aber nur, dass jedes zweite
        // Konto long steht, nicht dass dort das halbe Geld liegt.
        Text {
            text: Tr.t("market.accountShare", root.lang)
            color: root.dimColor
            font.pixelSize: root.baseFont - 3
            visible: root.ratio.length > 0
        }

        Repeater {
            model: root.ratio

            Row {
                id: zeile

                required property var modelData

                spacing: root.baseFont * 0.6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.baseFont * 4.5
                    text: zeile.modelData.name
                    color: root.dimColor
                    font.pixelSize: root.baseFont - 1
                    elide: Text.ElideRight
                }

                // Der Balken: gruen der Long-Anteil, rot der Rest. Die Mitte
                // ist markiert -- ohne Bezugslinie sagt "53 %" nichts.
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.baseFont * 14
                    height: Math.max(6, root.baseFont * 0.75)
                    radius: 2
                    color: root.downColor

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * Math.max(0, Math.min(1, zeile.modelData.long))
                        radius: 2
                        color: root.upColor
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 1
                        color: Qt.rgba(1, 1, 1, 0.55)
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Tr.fixed(zeile.modelData.long * 100, 1, root.lang) + " %"
                    color: zeile.modelData.long >= 0.5 ? root.upColor : root.downColor
                    font.pixelSize: root.baseFont - 1
                    font.family: Fonts.mono()
                }
            }
        }

        Text {
            visible: root.ratio.length === 0
            text: Tr.t("market.noRatio", root.lang)
            color: root.dimColor
            font.pixelSize: root.baseFont - 1
        }

        Item {
            width: 1
            height: root.baseFont * 0.6
        }

        // ------------------------------------------------- Liquidationen
        Text {
            text: Tr.t("market.liqTitle", root.lang)
            color: root.textColor
            font.pixelSize: root.baseFont
            font.bold: true
        }

        Text {
            text: root.seit > 0
                  ? Tr.t("market.liqSince", root.lang, root.seitText())
                  : Tr.t("market.liqNever", root.lang)
            color: root.dimColor
            font.pixelSize: root.baseFont - 3
            width: parent.width
            wrapMode: Text.WordWrap
        }

        // **Flow, nicht Row**: am Telefon passen beide Summen nicht
        // nebeneinander, und "Shorts liquidiert" lief rechts aus dem Bild
        // (13.09.2026, 384 Punkte breit).
        Flow {
            width: parent.width
            spacing: root.baseFont * 1.2
            visible: root.hatDaten

            Text {
                text: "▼ " + Tr.t("market.longsLiq", root.lang) + "  "
                      + root.zeichen + " " + root.geld(root.summeLong)
                color: root.downColor
                font.pixelSize: root.baseFont - 1
                font.family: Fonts.mono()
            }

            Text {
                text: "▲ " + Tr.t("market.shortsLiq", root.lang) + "  "
                      + root.zeichen + " " + root.geld(root.summeShort)
                color: root.upColor
                font.pixelSize: root.baseFont - 1
                font.family: Fonts.mono()
            }
        }
    }

    // -------------------------------------------------------- Histogramm
    // Preis nach oben, Betrag nach rechts. **Quer, nicht laengs**: die Frage
    // ist "auf welcher Hoehe", nicht "wann" -- das beantwortet der CVD.
    Item {
        id: bild

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: oben.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: root.baseFont * 0.7

        readonly property real achse: root.baseFont * 4.2
        readonly property real feld: Math.max(10, width - achse - root.baseFont * 3)

        Text {
            anchors.centerIn: parent
            visible: !root.hatDaten
            width: parent.width * 0.8
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: Tr.t("market.liqEmpty", root.lang)
            color: root.dimColor
            font.pixelSize: root.baseFont - 1
        }

        // Wie viele Beschriftungen die Achse vertraegt, ohne dass sie
        // uebereinander liegen -- lieber jede dritte lesbar als jede
        // unleserlich.
        readonly property real zeilenhoehe: Math.max(2, height / Math.max(1, root.hist.length))
        readonly property int jedeWievielte:
            Math.max(1, Math.ceil((root.baseFont + 2) / zeilenhoehe))

        Repeater {
            // Die hoechste Preisstufe oben -- der Dienst schickt sie
            // aufsteigend, gezeichnet wird andersherum.
            model: root.hatDaten ? root.hist.slice().reverse() : []

            Item {
                id: stufe

                required property var modelData
                required property int index

                readonly property real wert: stufe.modelData[1] + stufe.modelData[2]
                readonly property bool amKurs: root.preis > 0
                    && Math.abs(stufe.modelData[0] - root.preis)
                       <= (root.hist.length > 1
                           ? Math.abs(root.hist[1][0] - root.hist[0][0]) / 2 : 0)

                width: bild.width
                height: bild.zeilenhoehe
                y: stufe.index * height

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: bild.achse
                    // Die Stufe am laufenden Kurs steht immer da, egal wie
                    // eng es wird -- sie ist der Bezugspunkt fuer alles
                    // andere.
                    visible: stufe.amKurs || stufe.index % bild.jedeWievielte === 0
                    text: Tr.group(stufe.modelData[0], root.lang)
                    color: stufe.amKurs ? root.accentColor : root.dimColor
                    font.pixelSize: Math.max(7, root.baseFont - 3)
                    font.family: Fonts.mono()
                    horizontalAlignment: Text.AlignRight
                }

                // Rot: liquidierte Longs. Gruen: liquidierte Shorts. Beide
                // von links, aneinander -- so bleibt die Gesamtlaenge der
                // Betrag der Stufe.
                Rectangle {
                    id: balkenLong

                    x: bild.achse + root.baseFont * 0.5
                    anchors.verticalCenter: parent.verticalCenter
                    // Eine leere Stufe zeichnet nichts, aber sie **haelt
                    // ihren Platz** -- daran haengt die Achse.
                    height: Math.max(1, parent.height - 2)
                    width: root.groessteStufe > 0
                           ? bild.feld * stufe.modelData[1] / root.groessteStufe : 0
                    color: root.downColor
                }

                Rectangle {
                    x: balkenLong.x + balkenLong.width
                    anchors.verticalCenter: parent.verticalCenter
                    height: balkenLong.height
                    width: root.groessteStufe > 0
                           ? bild.feld * stufe.modelData[2] / root.groessteStufe : 0
                    color: root.upColor
                }

                Text {
                    x: balkenLong.x + bild.feld + root.baseFont * 0.5
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.geld(stufe.wert)
                    color: root.dimColor
                    font.pixelSize: Math.max(7, root.baseFont - 3)
                    font.family: Fonts.mono()
                    visible: stufe.wert > 0 && stufe.height >= root.baseFont - 2
                }
            }
        }

        // Der laufende Kurs als Linie -- ohne ihn sagt "wo" nichts, weil die
        // Frage immer "wo **relativ zu jetzt**" heisst.
        Rectangle {
            visible: root.hatDaten && root.hist.length > 1 && root.preis > 0
            // **Nur ueber der Balkenflaeche.** Ueber die volle Breite lief
            // sie durch die Wertangaben rechts und strich sie durch.
            x: bild.achse + root.baseFont * 0.5
            width: bild.feld
            height: 1
            color: root.accentColor
            opacity: 0.7
            y: {
                if (root.hist.length < 2)
                    return 0;
                var hoch = root.hist[root.hist.length - 1][0];
                var tief = root.hist[0][0];
                if (hoch <= tief)
                    return 0;
                var t = (hoch - root.preis) / (hoch - tief);
                return Math.max(0, Math.min(1, t)) * bild.height;
            }
        }
    }
}
