// Rahmen um die Ansicht: Kopfzeile, Blockangaben, Grafik, Legende, Fusszeile.
// Reines QtQuick -- die Farben werden von aussen gesetzt, damit derselbe
// Baustein im DMS-Plugin und im eigenen Fenster laufen kann.
import QtQuick
import "colors.js" as Palette
import "money.js" as Money
import "strings.js" as Tr
import "txtype.js" as TxType
import "fonts.js" as Fonts

Item {
    id: root

    property var feed: null
    property bool paused: false
    property real density: 1.0
    property bool headerVisible: true
    property bool infoVisible: true
    property bool legendVisible: true
    // Untergrund hinter den Textangaben. Ohne ihn gehen sie im Zoom unter,
    // wenn grosse helle Kachelflaechen direkt dahinter liegen.
    // Kachel angetippt -- wird von FeedCanvas durchgereicht
    signal txActivated(string txid)
    // Der Wirt haelt die Lesart -- er merkt sie sich auch ueber Sitzungen
    signal colorModeRequested(string mode)
    property bool frostedInfo: true
    property bool frostedBlur: true
    // Die gestrichelte Linie ueber der Halde
    property bool rulerVisible: true
    property bool footerVisible: true
    // Die Kachelgrafik des letzten Blocks in der Mitte
    property bool blockVisible: true
    property string colorMode: "age"
    // Welche Waehrung angezeigt wird -- der Daemon liefert sieben mit
    property string currency: "eur"
    property string sizeMode: "value"

    property color textColor: "#e6e0e9"
    property color dimColor: "#9a94a6"
    property color accentColor: "#c9a227"
    property color lineColor: "#2a2a38"
    // Toenung der Milchglas-Kaestchen (Kopf, Info, Legende, Goggles). Vorgabe wie
    // bisher dunkel; die DMS-Wirte geben eine Theme-Flaeche mit, damit sie im
    // Hellmodus hell werden.
    property color frostedTint: "#0b0b12"
    property int baseFont: 12
    property string lang: "de"
    property string btcZeichen: "\u20BF"
    property string pfeilLang: "\u27F6"

    readonly property bool showHeader: headerVisible && height >= 108
    readonly property bool showFooter: footerVisible && height >= 168
    readonly property bool showInfo: infoVisible && width >= 480 && height >= 300
    // In flachen Flaechen (Dashboard-Tab) nur das Noetigste, sonst laeuft die
    // Spalte in die Halde hinein
    readonly property bool infoCompact: height < 520
    // 420 war zu hoch gegriffen: der Dashboard-Tab ist 410 hoch und bekam
    // dadurch **nie** eine Legende -- und mit ihr auch nicht den Umschalter
    // darunter. Gemessen passt sie samt Umschalter ab 330 in die Flaeche.
    // **Und nur, wenn sie neben den Block passt.** Die feste Grenze von 420
    // Punkten reichte nicht: der Block waechst mit der Hoehe
    // (`blockSide`), und in einem schmalen, hohen Fenster (480 x 900) lag die
    // Legende halb ueber ihm (11.09.2026 im Xvfb). Gerechnet wird mit dem
    // Rand neben dem ungezoomten Block; `legend.width` ist auch dann bekannt,
    // wenn sie ausgeblendet ist, das gibt keine Schleife. Die 16 sind die
    // acht Punkte, die ihr Kasten nach aussen traegt, und etwas Luft.
    readonly property bool legendePasst:
        (canvasView.width - canvasView.blockSide) / 2 >= legend.width + 16
    readonly property bool showLegend: legendVisible && width >= 420 && height >= 330
                                       && legendePasst

    // **Der Umschalter haengt nicht am Platz fuer die Legende.** Bisher tat
    // er es, weil beide an `showLegend` hingen -- und das ist zweierlei: die
    // Legende ist eine Tafel, die Platz braucht, der Umschalter ein
    // Bedienelement. Auf dem Schreibtisch schaltet `c` die Lesart durch, dort
    // darf er unter 420 Punkten weg. Ohne Tastatur ist er die **einzige**
    // Moeglichkeit, und ihn wegzulassen nimmt die Funktion ganz weg.
    //
    // Am 08.09.2026 auf einem Galaxy A55 gemeldet: bei 384 dp fiel er weg,
    // und die drei Lesarten waren nicht mehr erreichbar. `Qt.platform.os`
    // steht hier direkt, wie in `fonts.js` -- eine Eigenschaft durch drei
    // Ebenen zu reichen waere fuer diese eine Frage zu viel Leitung.
    readonly property bool showGoggles: legendVisible
        && (showLegend || Qt.platform.os === "android" || Qt.platform.os === "ios")
    // **Links und rechts derselbe Abstand zur Kopfzeile.** Vorher rechnete
    // jede Seite fuer sich: links 0,03/0,10 mit einem Mindestabstand, rechts
    // 0,04/0,10 ohne. Zwischen 460 und 520 Pixeln Hoehe kam links der
    // Mindestabstand zum Tragen und rechts schon der grosse Bruchteil -- die
    // Legende sass dadurch bis zu dreissig Pixel tiefer als die Blockangaben.
    // Sichtbar wird das, weil beide denselben Kasten ueber sich haben und die
    // Fuge darunter ungleich breit ausfiel.
    //
    // Der Mindestabstand gilt jetzt fuer beide: `FrostedPanel` traegt acht
    // Pixel Rand nach aussen, ohne ihn stossen die Kaesten in flachen
    // Flaechen aneinander.
    readonly property int sideTopMargin: Math.max(
        Math.round(root.baseFont * 1.6),
        Math.round(canvasView.height * (root.infoCompact ? 0.04 : 0.10)))
    readonly property var tip: feed ? feed.tip : ({})
    readonly property var nextBlock: feed ? feed.nextBlock : ({})
    readonly property var block: feed ? feed.block : ({})

    // Tausender- und Dezimaltrenner haengen an der Sprache -- Deutsch nimmt
    // den Punkt, Englisch das Komma, Polnisch und Tschechisch ein schmales
    // Leerzeichen.
    function grp(n) {
        return Tr.group(n, root.lang);
    }

    function dec(n, digits) {
        return Tr.fixed(n, digits, root.lang);
    }

    function fee(v) {
        if (!v)
            return "–";
        return (v < 10 ? dec(v, 2) : grp(v)) + " sat/vB";
    }

    function ago(ts) {
        if (!ts)
            return "";
        var s = Math.max(0, Math.round(Date.now() / 1000 - ts));
        if (s < 60)
            return Tr.t("ago.sec", root.lang, s);
        return Tr.t("ago.min", root.lang, Math.floor(s / 60));
    }

    function stamp(ts) {
        if (!ts)
            return "";
        var d = new Date(ts * 1000);
        return Qt.formatDateTime(d, Tr.datum(root.lang) + "  HH:mm");
    }

    function fiat(sats) {
        var pr = root.feed ? root.feed.price : null;
        return Tr.fiat(sats, Money.rate(pr, root.currency),
                       Money.symbol(Money.actual(pr, root.currency)), root.lang);
    }

    // Blockanimation von Hand ausloesen (Taste b im eigenen Fenster) -- zum
    // Pruefen, ohne zehn Minuten auf den naechsten Block zu warten
    function triggerBlockAnimation() {
        canvasView.startBlockAnimation();
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.visible
        onTriggered: agoLabel.text = root.ago(root.tip.time)
    }

    // ------------------------------------------------------------ Kopfzeile
    // ------------------------------------------------ Untergrund der Angaben
    FrostedPanel {
        content: header
        backdropSource: canvasView
        blurred: root.frostedBlur
        tint: root.frostedTint
        visible: root.frostedInfo && header.visible
        z: 4
    }

    FrostedPanel {
        content: info
        backdropSource: canvasView
        blurred: root.frostedBlur
        tint: root.frostedTint
        visible: root.frostedInfo && info.visible
        z: 4
    }

    FrostedPanel {
        content: legend
        backdropSource: canvasView
        blurred: root.frostedBlur
        tint: root.frostedTint
        visible: root.frostedInfo && legend.visible
        z: 4
    }

    // **Der Umschalter braucht denselben Untergrund wie die Legende.** Er
    // steht unter ihr, also genau dort, wo die Halde bei vollem Mempool nach
    // oben waechst -- und dann lagen die Knoepfe ueber den Kacheln und waren
    // nicht mehr zu lesen. Dass es der Legende darueber nicht so ging, lag
    // allein an ihrem Kasten.
    FrostedPanel {
        content: goggles
        backdropSource: canvasView
        blurred: root.frostedBlur
        tint: root.frostedTint
        visible: root.frostedInfo && goggles.visible
        z: 4
    }

    Item {
        id: header

        z: 5

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.showHeader ? Math.round(root.baseFont * 2.4) : 0
        visible: root.showHeader

        Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Row {
                spacing: 6

                Rectangle {
                    width: 7
                    height: 7
                    radius: 4
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.feed && root.feed.online ? "#5cb946" : "#d33f3f"
                }

                Text {
                    text: Tr.t("block", root.lang) + " " + root.grp(root.tip.height)
                    color: root.textColor
                    font.pixelSize: root.baseFont + 2
                    font.weight: Font.DemiBold
                }
            }

            Text {
                id: agoLabel

                text: root.ago(root.tip.time)
                color: root.dimColor
                font.pixelSize: root.baseFont - 2
            }
        }

        Column {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                anchors.right: parent.right
                text: Tr.t("feed.inMempool", root.lang,
                           root.grp(root.feed ? root.feed.mempoolCount : 0))
                color: root.textColor
                font.pixelSize: root.baseFont
            }

            Text {
                anchors.right: parent.right
                text: root.fee(root.feed ? root.feed.feeFastest : 0)
                color: root.accentColor
                font.pixelSize: root.baseFont - 2
            }
        }
    }

    FeedCanvas {
        id: canvasView
        
        onTxActivated: function (txid) { root.txActivated(txid); }

        anchors.top: header.bottom
        anchors.bottom: footer.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: root.showHeader ? 4 : 0

        feed: root.feed
        paused: root.paused
        density: root.density
        colorMode: root.colorMode
        lang: root.lang
        sizeMode: root.sizeMode
        showBlock: root.blockVisible && height > 130
        showRuler: root.rulerVisible
        gridColor: root.lineColor
        rulerColor: root.dimColor
        labelFont: root.baseFont - 1
    }

    // -------------------------------------------------- Angaben zum Block
    Column {
        id: info

        z: 5

        anchors.left: canvasView.left
        anchors.top: canvasView.top
        anchors.topMargin: root.sideTopMargin
        width: Math.min(160, root.width * 0.22)
        spacing: 2
        visible: root.showInfo && root.block.height !== undefined

        Text {
            text: Tr.t("lastBlock", root.lang)
            color: root.dimColor
            font.pixelSize: root.baseFont - 1
        }

        Text {
            text: root.grp(root.block.height)
            color: root.textColor
            font.pixelSize: root.baseFont + 6
            font.weight: Font.DemiBold
        }

        Text {
            text: root.stamp(root.block.time)
            color: root.dimColor
            font.pixelSize: root.baseFont - 2
            bottomPadding: 6
        }

        // Ohne Beschriftung war nicht zu erkennen, was die Zahl meint. Sie ist
        // die Summe **aller Ausgaenge dieses Blocks**, nicht der Mempool und
        // nicht "was den Besitzer gewechselt hat": Wechselgeld an den Absender
        // zaehlt mit, deshalb liegt sie regelmaessig ueber dem, was tatsaechlich
        // geflossen ist.
        Text {
            visible: !root.infoCompact
            text: Tr.t("feed.movedValue", root.lang)
            color: root.dimColor
            font.pixelSize: root.baseFont - 2
        }

        Text {
            text: root.btcZeichen + " " + root.dec((root.block.totalValue || 0) / 1e8, 4)
            color: root.textColor
            font.pixelSize: root.baseFont
        }

        Text {
            visible: !root.infoCompact
            text: root.fiat(root.block.totalValue)
            color: root.dimColor
            font.pixelSize: root.baseFont - 2
            bottomPadding: 6
        }

        Text {
            visible: !root.infoCompact
            text: Tr.t("feed.bytes", root.lang, root.grp(root.block.size))
            color: root.dimColor
            font.pixelSize: root.baseFont - 1
        }

        Text {
            text: Tr.t("txlist.count", root.lang, root.grp(root.block.nTx))
            color: root.dimColor
            font.pixelSize: root.baseFont - 1
            bottomPadding: 6
        }

        Text {
            visible: !root.infoCompact
            text: Tr.t("feed.avgFee", root.lang)
            color: root.dimColor
            font.pixelSize: root.baseFont - 2
        }

        Text {
            text: (root.infoCompact ? "Ø " : "") + root.dec(root.block.avgFeeRate, 2) + " sat/vByte"
            color: root.textColor
            font.pixelSize: root.baseFont - 1
        }

        Text {
            visible: !root.infoCompact
            text: root.block.pool || ""
            color: root.dimColor
            font.pixelSize: root.baseFont - 2
            topPadding: 6
        }
    }

    // ------------------------------------------------------------- Legende
    Column {
        id: legend

        z: 5

        anchors.right: canvasView.right
        anchors.top: canvasView.top
        anchors.topMargin: root.sideTopMargin
        spacing: 4
        visible: root.showLegend

        Text {
            anchors.right: parent.right
            text: Tr.t(root.sizeMode === "vbytes" ? "feed.sizeVbytes" : "feed.sizeValue", root.lang)
            color: root.dimColor
            font.pixelSize: root.baseFont - 2
        }

        Repeater {
            // **Die Zahlen der Legende gehen durch dieselbe Schreibweise wie
            // jede andere Zahl.** Vorher standen sie hier als Text: in der
            // englischen Oberflaeche las man "< 1.024" (tausendvierundzwanzig
            // oder eins Komma null?) und "< 0,01" neben lauter englischen
            // Formaten. Am 19.09.2026 auf den Bildern fuer F-Droid gesehen.
            model: root.sizeMode === "vbytes"
                ? [256, 1024, 2304, 4096, 6400].map(function (n) {
                    return "< " + Tr.group(n, root.lang);
                })
                : [0.01, 0.1, 1, 10, 100].map(function (n) {
                    return "< " + root.btcZeichen + " "
                         + Tr.fixed(n, n < 1 ? (n < 0.1 ? 2 : 1) : 0, root.lang);
                })

            Row {
                spacing: 6
                anchors.right: parent.right

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData
                    color: root.dimColor
                    font.pixelSize: root.baseFont - 2
                    font.family: Fonts.mono()
                }

                Item {
                    width: 22
                    height: 22

                    Rectangle {
                        anchors.centerIn: parent
                        width: 3 + index * 4
                        height: width
                        color: Palette.blockAgeColor()
                    }
                }
            }
        }

        Text {
            anchors.right: parent.right
            text: Tr.t(root.colorMode === "type" ? "feed.typeScale"
                : (root.colorMode === "fee" ? "feed.feeScale" : "feed.ageScale"), root.lang)
            color: root.dimColor
            font.pixelSize: root.baseFont - 2
            topPadding: 4
        }

        // Farbtafel der Arten. Nur die, die im Block auch vorkommen.
        Repeater {
            model: {
                if (root.colorMode !== "type")
                    return [];
                var z = canvasView.blockTypeCounts || [];
                var out = [];
                for (var i = 0; i < z.length; i++) {
                    if (z[i] > 0)
                        out.push({ "i": i, "n": z[i] });
                }
                out.sort(function (a, b) {
                    return b.n - a.n;
                });
                return out;
            }

            Row {
                id: artZeile

                required property var modelData

                readonly property var meta: TxType.info(TxType.kindAt(artZeile.modelData.i))

                anchors.right: parent.right
                spacing: 5

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Tr.t(TxType.labelKey(TxType.kindAt(artZeile.modelData.i)), root.lang)
                    color: root.dimColor
                    font.pixelSize: root.baseFont - 2
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.baseFont - 3
                    height: width
                    radius: 2
                    color: artZeile.meta.color
                }
            }
        }

        Text {
            anchors.right: parent.right
            horizontalAlignment: Text.AlignRight
            visible: root.colorMode === "type"
            text: Tr.t("feed.noTypeMempool", root.lang)
            color: root.dimColor
            font.pixelSize: root.baseFont - 3
            topPadding: 2
        }

        Row {
            anchors.right: parent.right
            spacing: 4
            visible: root.colorMode !== "type"

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.colorMode === "fee" ? "2" : "0"
                color: root.dimColor
                font.pixelSize: root.baseFont - 3
            }

            Rectangle {
                width: 90
                height: 8
                anchors.verticalCenter: parent.verticalCenter

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0
                        color: root.colorMode === "fee" ? Palette.feeColorForRate(2) : Palette.ageColor(0)
                    }

                    GradientStop {
                        position: 0.5
                        color: root.colorMode === "fee" ? Palette.feeColorForRate(16) : Palette.ageColor(30000)
                    }

                    GradientStop {
                        position: 1
                        color: root.colorMode === "fee" ? Palette.feeColorForRate(128) : Palette.ageColor(60000)
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.colorMode === "fee" ? "128+" : "60+"
                color: root.dimColor
                font.pixelSize: root.baseFont - 3
            }
        }
    }

    // Umschalter fuer die Kachelfarbe. Dieselben Knoepfe wie im Explorer,
    // hier mit drei Lesarten: Alter, Gebuehr, Art.
    TileGoggles {
        id: goggles

        z: 6
        // Unter der Legende am rechten Rand. Unten links lag er in der Halde
        // und war ueber den Kacheln nicht mehr zu lesen.
        anchors.right: legend.right
        // **Unter der Legende, aber nicht tiefer als die Halde reicht.**
        //
        // Der Abstand zur Legende ist gerechnet, nicht geraten: seit der
        // Umschalter einen eigenen Untergrund hat, ist er die Fuge zwischen
        // zwei Kaesten, und jeder traegt acht Pixel nach aussen
        // (`FrostedPanel.pad`). Die frueheren 0,8 Schriftgraden waren
        // weniger -- die Kaesten haetten sich ueberlappt, und zwei
        // durchscheinende Flaechen uebereinander geben eine dunkle Naht.
        //
        // Der Boden darunter ist der zweite Teil: in der Lesart "Art" traegt
        // die Legende sieben Zeilen mehr, und in einer flachen Flaeche schob
        // sie den Umschalter aus der Zeichenflaeche heraus bis in die
        // Fusszeile. Solange er nur Schrift war, sah man darueber hinweg;
        // als Kasten deckt er den Kurs darunter zu. Also endet er
        // spaetestens am unteren Rand der Halde.
        //
        // Und **ohne Legende dicht unter die Kopfzeile**, also direkt unter
        // die Zeile mit Blockhoehe und sat/vB. Ein unsichtbares Element
        // behaelt in QML seine Hoehe; unter der Legende klebte er sonst unter
        // einer Tafel, die niemand sieht -- in der Lesart "Art" sieben Zeilen
        // weit unten.
        //
        // Zwei Anlaeufe davor, beide am 08.09.2026 auf einem Galaxy A55
        // verworfen:
        //
        //   unter dem Block   Die Lage kam aus `blockCenterY` und
        //                     `blockSide`. **Bei Zoom zwangslaeufig falsch**,
        //                     denn dann kann der Block ueberall stehen -- der
        //                     Kasten landete mitten im Bild.
        //   `sideTopMargin`   Das sind zehn Prozent der Flaechenhoehe (fuer
        //                     die Legende gedacht, die weit oben ansetzt).
        //                     Auf einem Telefon schob das den Kasten wieder
        //                     auf die Kacheln.
        //
        // Der allgemeine Fall: **eine Lage, die sich aus dem Inhalt
        // errechnet, wandert mit ihm.** Fuer eine Beschriftung ist das
        // richtig, fuer ein Bedienelement nicht -- das gehoert an einen
        // Platz, an dem man es wiederfindet, und der ist hier die Oberkante.
        //
        // Die Klemme nach unten bleibt in beiden Faellen: was nicht passt,
        // endet am unteren Rand der Halde statt in der Fusszeile.
        //
        // **Unter der Kopfzeile dieselbe Fuge wie unter der Legende.** Hier
        // stand `canvasView.y + 2`, also 6 Punkte unter der Kopfzeile -- aber
        // beide Kaesten tragen 8 Punkte nach aussen, und sie ueberlappten
        // sich um 10. Am 11.09.2026 auf dem Galaxy A55 gesehen: der Kasten
        // mit "Farbe" lag ueber der Unterkante von Blockhoehe und sat/vB.
        y: Math.min(root.showLegend
                    ? legend.y + legend.height + 8 + 8 + 2
                    : (root.showHeader ? header.y + header.height + 8 + 8 + 2
                                       : canvasView.y + 2),
                    canvasView.y + canvasView.height - goggles.height)
        // Genau so breit wie die Knopfreihe, damit der Untergrund dahinter
        // sie umschliesst und nicht daneben steht. `baseFont * 14` war
        // geraten und lag bei den deutschen Beschriftungen zu knapp.
        width: goggles.schalterBreite
        alignRight: true
        visible: root.showGoggles
        mode: root.colorMode
        lang: root.lang
        modes: [
            { "k": "age", "l": Tr.t("color.age", root.lang) },
            { "k": "fee", "l": Tr.t("color.fee", root.lang) },
            { "k": "type", "l": Tr.t("color.type", root.lang) }
        ]
        // Die Farbtafel steht schon in der Legende rechts -- zweimal dasselbe
        // waere nur Rauschen. Hier bleibt der blosse Umschalter.
        counts: []
        total: 0
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        uiFont: root.baseFont
        onPicked: function (m) {
            root.colorModeRequested(m);
        }
    }

    // ------------------------------------------------------------ Fusszeile
    Item {
        id: footer

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.showFooter ? Math.round(root.baseFont * 1.9) : 0
        visible: root.showFooter

        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: root.lineColor
            opacity: 0.6
        }

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Text {
                text: Tr.t("feed.nextBlockLine", root.lang,
                           root.grp(root.nextBlock.nTx),
                           root.fee(root.nextBlock.medianFee).replace(" sat/vB", ""))
                color: root.dimColor
                font.pixelSize: root.baseFont - 2
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.feed
                ? root.btcZeichen + " " + Tr.price1(Money.rate(root.feed.price, root.currency),
                                   Money.symbol(Money.actual(root.feed.price, root.currency)),
                                   root.lang)
                : ""
            color: root.dimColor
            font.pixelSize: root.baseFont - 2
        }
    }

    // ---------------------------------------------------------- Tooltip
    // Zeigt beim Ueberfahren die Angaben zur Transaktion, wie auf bitfeed.live.
    // Ein- und Ausgaenge stehen nicht im Datenstrom und werden bei Bedarf
    // einzeln nachgeladen.
    property var inOutCache: ({})
    property string inOutKey: ""
    property string inOutText: ""

    function loadInOut(txid) {
        if (!txid)
            return;
        if (root.inOutCache[txid] !== undefined) {
            root.inOutText = root.inOutCache[txid];
            root.inOutKey = txid;
            return;
        }
        root.inOutKey = txid;
        root.inOutText = "";
        var req = new XMLHttpRequest();
        req.open("GET", "https://mempool.space/api/tx/" + txid);
        req.onreadystatechange = function () {
            if (req.readyState !== XMLHttpRequest.DONE)
                return;
            var out = "";
            if (req.status === 200) {
                try {
                    var d = JSON.parse(req.responseText);
                    var ni = (d.vin || []).length, no = (d.vout || []).length;
                    out = Tr.ersetzen(
                        Tr.t("tip.inOut", root.lang, ni,
                             Tr.t(ni === 1 ? "in.one" : "in.many", root.lang), no,
                             Tr.t(no === 1 ? "out.one" : "out.many", root.lang)),
                        root.btcZeichen, root.pfeilLang);
                } catch (e) {}
            }
            root.inOutCache[txid] = out;
            if (root.inOutKey === txid)
                root.inOutText = out;
        };
        req.send();
    }

    Timer {
        id: inOutDelay

        interval: 350
        onTriggered: {
            var t = canvasView.hoveredTx;
            if (t && t.t)
                root.loadInOut(t.t);
        }
    }

    Connections {
        target: canvasView

        function onHoveredTxChanged() {
            var t = canvasView.hoveredTx;
            if (!t || !t.t) {
                inOutDelay.stop();
                root.inOutText = "";
                root.inOutKey = "";
                return;
            }
            if (root.inOutCache[t.t] !== undefined) {
                root.inOutKey = t.t;
                root.inOutText = root.inOutCache[t.t];
            } else {
                root.inOutText = "";
                inOutDelay.restart();
            }
        }
    }

    FrostedPanel {
        content: tip
        backdropSource: canvasView
        blurred: root.frostedBlur
        tint: root.frostedTint
        pad: 0
        visible: root.frostedInfo && tip.visible
        z: 199
    }

    Rectangle {
        id: tip

        readonly property var tx: canvasView.hoveredTx

        // **Die Rate muss zu den beiden Zeilen darueber passen.** Gezeigt
        // wurde `r` aus dem Zustand -- das ist die *wirksame* Rate von
        // mempool.space, die Vorgaenger (CPFP) und Sigops mitrechnet. Daneben
        // standen Groesse und Gebuehr, und aus denen ergab sich eine andere
        // Zahl: 1000 sat / 219,25 vB = 4,56, angezeigt 4,54 (19.09.2026). Der
        // Explorer rechnet ebenfalls Gebuehr durch vBytes (`fee / (weight/4)`)
        // und stand damit im Widerspruch zum Tooltip derselben Transaktion.
        //
        // Hier steht jetzt die Rechnung, die man an den eigenen Zahlen
        // nachvollziehen kann; die wirksame Rate kommt als eigene Zeile dazu,
        // wenn sie abweicht. **Die Farbe der Kachel bleibt bei der wirksamen
        // Rate** -- sie ist die, nach der ein Miner auswaehlt.
        readonly property real eigenRate: tip.tx && tip.tx.v > 0
            ? tip.tx.f / tip.tx.v : (tip.tx ? (tip.tx.r || 0) : 0)
        // Eine Abweichung ist erst eine, wenn man sie sieht: ein Prozent,
        // mindestens aber 0,01 sat/vB -- darunter faellt sie beim Runden auf
        // zwei Stellen ohnehin weg.
        readonly property bool rateWeichtAb: tip.tx && (tip.tx.r || 0) > 0
            && Math.abs(tip.tx.r - tip.eigenRate)
               > Math.max(0.01, tip.eigenRate * 0.01)

        visible: tx !== null && root.width > 300
        // Groesse aus dem Inhalt, aber ueber childrenRect statt ueber die
        // Spalte: waere die Spalte im Rechteck zentriert, haenge die Groesse
        // des Rechtecks an der Spalte und umgekehrt -- QML bricht diese
        // Abhaengigkeit auf und laesst beides bei null.
        width: tipCol.width + 20
        height: tipCol.height + 16
        radius: 6
        // Derselbe dunkle Untergrund wie bei den uebrigen Angaben: auf dem
        // Kachelfeld ist die Linienfarbe zu hell, die Schrift verliert dagegen.
        color: Qt.rgba(root.frostedTint.r, root.frostedTint.g, root.frostedTint.b, 0.88)
        border.width: 1
        border.color: Qt.lighter(root.lineColor, 1.4)
        z: 200

        x: Math.max(0, Math.min(root.width - width, canvasView.x + canvasView.hoverX + 14))
        y: Math.max(0, Math.min(root.height - height, canvasView.y + canvasView.hoverY - height - 12))

        Column {
            id: tipCol

            x: 10
            y: 8
            width: childrenRect.width
            height: childrenRect.height
            spacing: 3

            Text {
                text: tip.tx && tip.tx.t
                    ? Tr.t("tip.txid", root.lang, String(tip.tx.t).substring(0, 20) + "…") : ""
                color: root.textColor
                font.pixelSize: root.baseFont - 1
                font.family: Fonts.mono()
            }

            // Gehoert die Transaktion zu einer beobachteten Wallet, ist das
            // die wichtigste Angabe an ihr -- also nach oben.
            Text {
                visible: tip.tx && tip.tx.m === 1
                text: Tr.t("feed.ownWallet", root.lang)
                color: root.accentColor
                font.pixelSize: root.baseFont - 2
            }

            Text {
                visible: root.inOutText.length > 0
                text: root.inOutText
                color: root.dimColor
                font.pixelSize: root.baseFont - 2
            }

            Text {
                text: tip.tx ? Tr.t("tip.size", root.lang, root.dec(tip.tx.v, 2)) : ""
                color: root.dimColor
                font.pixelSize: root.baseFont - 2
            }

            Text {
                text: tip.tx ? Tr.t("tip.rate", root.lang, root.dec(tip.eigenRate, 2)) : ""
                color: root.dimColor
                font.pixelSize: root.baseFont - 2
            }

            Text {
                visible: tip.rateWeichtAb
                text: tip.tx ? Tr.t("tip.rateEff", root.lang, root.dec(tip.tx.r, 2)) : ""
                color: root.dimColor
                font.pixelSize: root.baseFont - 2
            }

            Text {
                text: tip.tx ? Tr.t("tip.fee", root.lang, root.grp(tip.tx.f)) : ""
                color: root.dimColor
                font.pixelSize: root.baseFont - 2
            }

            Text {
                text: tip.tx ? Tr.ersetzen(Tr.t("tip.total", root.lang, Tr.fixed(
                                    (tip.tx.a / 1e8), 8, root.lang)),
                                    root.btcZeichen, root.pfeilLang)
                               + "  " + root.fiat(tip.tx.a) : ""
                color: root.textColor
                font.pixelSize: root.baseFont - 2
            }
        }
    }

    // **Auf eigenem Grund, nicht blank ueber dem Block.** Mittig stand der
    // Satz genau auf dem orangen Block, in blasser Schrift -- am 10.09.2026
    // auf dem Telefon als "kaum lesbar" gemeldet. Die Pille traegt dieselbe
    // Deckkraft wie der Tooltip, und das Rot ist dasselbe wie bei "keine
    // Verbindung" in der Uhr.
    Rectangle {
        anchors.centerIn: parent
        visible: root.feed !== null && !root.feed.online
        z: 25
        width: keineVerbindung.implicitWidth + root.baseFont * 1.6
        height: keineVerbindung.implicitHeight + root.baseFont * 0.9
        radius: height / 2
        color: Qt.rgba(0.05, 0.05, 0.08, 0.92)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)

        Text {
            id: keineVerbindung

            anchors.centerIn: parent
            text: Tr.t("feed.noConnection", root.lang)
            color: "#e06c6c"
            font.pixelSize: root.baseFont
        }
    }
}
