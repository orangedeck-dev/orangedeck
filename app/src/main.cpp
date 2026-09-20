// Eigenstaendige Fassung des Bitcoin-Feeds: dieselbe QML-Grafik wie in der
// Shell, nur in einem gewoehnlichen Qt-Fenster. Laeuft damit auf jedem
// Linux-Desktop und ist zugleich die Grundlage fuer die Android-Fassung.
//
// Zweite Betriebsart: `--layer`. Dann wird aus dem Fenster eine
// Layer-Shell-Flaeche -- also ein Desktop-Widget oder eine Leiste, ohne
// Rahmen, an eine Kante geheftet und unter (oder ueber) den gewoehnlichen
// Fenstern. Das ist der Weg fuer alle Wayland-Compositoren ausser DMS:
// niri, sway, Hyprland, river, labwc. Ohne die Bibliothek
// (`layer-shell-qt`, Qt6) baut alles wie zuvor, nur `--layer` fehlt dann.
#include <QGuiApplication>
#include <QIcon>
#include <QCommandLineParser>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QQmlProperty>
#include <QTimer>
#include <QMargins>

#ifdef Q_OS_WIN
#include <QScreen>
#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#endif

#ifdef ORANGEDECK_LAYERSHELL
#include <LayerShellQt/Window>
#endif

#ifdef Q_OS_ANDROID
#include <QHash>
#include <QJniObject>
#endif

namespace {

#ifdef Q_OS_ANDROID
// **Die Ansicht steckt in der Aktion, nicht in einem Extra.** Ein statisches
// `<intent>` in `res/xml/shortcuts.xml` traegt keine `<extra>`-Kinder --
// Android dokumentiert dort nur `action`, `targetPackage` und `targetClass`.
// Also bekommt jede Verknuepfung ihre eigene Aktion, und hier wird sie beim
// Start ausgelesen. Auf dem Schreibtisch macht `--view` dasselbe.
//
// **Nur beim Start.** Die Activity laeuft `singleTop`: tippt jemand eine
// zweite Verknuepfung an, waehrend die Anwendung schon offen ist, kommt das
// als `onNewIntent` -- das reicht hier nicht durch, die Ansicht bleibt dann
// stehen. Wer wechseln will, nimmt die Reiter. Aufgeschrieben, damit es
// niemand fuer einen Fehler haelt.
int ansichtAusAbsicht()
{
    QJniObject activity = QNativeInterface::QAndroidApplication::context();
    if (!activity.isValid())
        return -1;
    QJniObject absicht = activity.callObjectMethod(
        "getIntent", "()Landroid/content/Intent;");
    if (!absicht.isValid())
        return -1;
    QJniObject aktion = absicht.callObjectMethod(
        "getAction", "()Ljava/lang/String;");
    if (!aktion.isValid())
        return -1;

    // Dieselben Zahlen wie bei `--view`; sie muessen zu den Aktionen in
    // `android/res/xml/shortcuts.xml` passen.
    static const QHash<QString, int> karte{
        {QStringLiteral("dev.orangedeck.OrangeDeck.VIEW_FEED"), 0},
        {QStringLiteral("dev.orangedeck.OrangeDeck.VIEW_CLOCK"), 1},
        {QStringLiteral("dev.orangedeck.OrangeDeck.VIEW_EXPLORER"), 3},
        // **Der Miner kam am 09.09.2026 dazu**, und zwar fuer die
        // Homescreen-Widgets: `WidgetMiner` springt hierher. Er stand
        // urspruenglich nicht in dieser Liste, weil er am Dienst hing und die
        // Verknuepfung im Emulator auf eine leere Seite fuehrte. Seit
        // `DirectMiner.qml` (08.09.) fragt die Oberflaeche AxeOS selbst ab;
        // der Reiter traegt auf dem Geraet also Inhalt.
        {QStringLiteral("dev.orangedeck.OrangeDeck.VIEW_MINER"), 2},
        // Das Netz-Widget (11.09.2026): derselbe Reiter, aber die Seite
        // "Netz" -- siehe `seiteAusAbsicht()`.
        {QStringLiteral("dev.orangedeck.OrangeDeck.VIEW_NETWORK"), 2},
        // Kein Markt: der haengt am Dienst, und auf Android gibt es nur den
        // Direktbezug. Die Verknuepfung dorthin oeffnete eine leere Seite.
    };
    return karte.value(aktion.toString(), -1);
}

// Die Seite im Miner-Reiter, wenn die Aktion eine bestimmt. Nur das
// Netz-Widget tut das: wer es antippt, will das Netz sehen, auch wenn ein
// eigenes Geraet eingetragen ist und zuletzt dessen Seite offen war.
QString seiteAusAbsicht()
{
    QJniObject activity = QNativeInterface::QAndroidApplication::context();
    if (!activity.isValid())
        return {};
    QJniObject absicht = activity.callObjectMethod(
        "getIntent", "()Landroid/content/Intent;");
    if (!absicht.isValid())
        return {};
    QJniObject aktion = absicht.callObjectMethod(
        "getAction", "()Ljava/lang/String;");
    if (aktion.isValid()
        && aktion.toString() == QLatin1String("dev.orangedeck.OrangeDeck.VIEW_NETWORK"))
        return QStringLiteral("net");
    return {};
}
#endif

#ifdef ORANGEDECK_LAYERSHELL
using LSWindow = LayerShellQt::Window;

LSWindow::Layer ebeneAus(const QString &s)
{
    if (s == QLatin1String("background"))
        return LSWindow::LayerBackground;
    if (s == QLatin1String("top"))
        return LSWindow::LayerTop;
    if (s == QLatin1String("overlay"))
        return LSWindow::LayerOverlay;
    return LSWindow::LayerBottom;
}

LSWindow::Anchors kantenAus(const QString &s)
{
    LSWindow::Anchors a;
    const auto teile = s.split(QLatin1Char(','), Qt::SkipEmptyParts);
    for (const QString &t : teile) {
        const QString k = t.trimmed().toLower();
        if (k == QLatin1String("top"))
            a |= LSWindow::AnchorTop;
        else if (k == QLatin1String("bottom"))
            a |= LSWindow::AnchorBottom;
        else if (k == QLatin1String("left"))
            a |= LSWindow::AnchorLeft;
        else if (k == QLatin1String("right"))
            a |= LSWindow::AnchorRight;
    }
    return a;
}
#endif

} // namespace

// **Der Bildschirm bleibt an, solange das Fenster im Vollbild ist.** Fuer ein
// altes Telefon oder Tablet als Blockuhr an der Wand ist das der ganze Zweck;
// ohne das geht der Schirm nach der eingestellten Frist aus. QML kennt das
// Fensterflag nicht, also hoert diese Klasse auf `vollbild` in Main.qml und
// setzt oder loescht FLAG_KEEP_SCREEN_ON an der Activity. Es gilt nur fuer
// dieses Fenster und nur, solange es vorn ist -- keine Berechtigung noetig,
// und die Anwendung im Hintergrund haelt nichts wach.
//
// Auf dem Schreibtisch tut sie nichts: dort entscheidet der Anwender ueber
// den Bildschirmschoner.
class Wache : public QObject
{
    Q_OBJECT

public:
    explicit Wache(QObject *fenster)
        : QObject(fenster), m_fenster(fenster)
    {
    }

public slots:
    void anpassen()
    {
#ifdef Q_OS_ANDROID
        const bool an = m_fenster->property("vollbild").toBool();
        // Fensterflags gehoeren dem UI-Faden von Android, nicht dem von Qt.
        QNativeInterface::QAndroidApplication::runOnAndroidMainThread([an]() {
            QJniObject activity = QNativeInterface::QAndroidApplication::context();
            if (!activity.isValid())
                return;
            QJniObject fenster = activity.callObjectMethod(
                "getWindow", "()Landroid/view/Window;");
            if (!fenster.isValid())
                return;
            const jint FLAG_KEEP_SCREEN_ON = 0x00000080;
            fenster.callMethod<void>(an ? "addFlags" : "clearFlags", "(I)V",
                                     FLAG_KEEP_SCREEN_ON);
        });
#endif
    }

private:
    QObject *m_fenster;
};

// **Die Widgets ziehen nach, wenn sich in der Anwendung etwas aendert, das
// sie zeigen:** Sprache, Waehrung, Miner-Adresse. Sie lesen dieselbe ini wie
// die Anwendung, frischen sich aber nur alle 30 Minuten auf; am 10.09.2026
// blieben sie nach dem Umstellen auf Englisch deutsch, waehrend neu
// platzierte schon englisch waren.
//
// **Zwei Sekunden nach der letzten Aenderung, nicht sofort.** QML-Settings
// schreibt eine Aenderung erst nach kurzer Frist in die ini; ein Widget, das
// sofort liest, laese noch den alten Wert. Und wer sich durch die Sprachen
// klickt, loest so einen Anstoss aus statt dreizehn.
class WidgetWecker : public QObject
{
    Q_OBJECT

public:
    explicit WidgetWecker(QObject *fenster)
        : QObject(fenster)
    {
        m_frist.setSingleShot(true);
        m_frist.setInterval(2000);
        connect(&m_frist, &QTimer::timeout, this, &WidgetWecker::wecken);
    }

public slots:
    void geaendert()
    {
        m_frist.start();
    }

private:
    void wecken()
    {
#ifdef Q_OS_ANDROID
        QJniObject kontext = QNativeInterface::QAndroidApplication::context();
        if (!kontext.isValid())
            return;
        QJniObject::callStaticMethod<void>("dev/orangedeck/OrangeDeck/DeckWidget",
                                           "alleAnstossen",
                                           "(Landroid/content/Context;)V",
                                           kontext.object<jobject>());
#endif
    }

    QTimer m_frist;
};

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setOrganizationName("orangedeck");
    app.setOrganizationDomain("21rebel.dev");
    app.setApplicationName("orangedeck");
    app.setApplicationVersion(QStringLiteral(ORANGEDECK_VERSION));
    app.setApplicationDisplayName(QStringLiteral("OrangeDeck"));
    // Ausdruecklich gesetzt: sonst leitet Qt die Wayland-app_id aus der
    // umgedrehten Domain und dem Programmnamen ab ("dev.21rebel.orangedeck-app"),
    // und der Fensterverwalter findet das Symbol nicht, weil die
    // .desktop-Datei anders heisst. Der Unterstrich gehoert dazu -- ein
    // Segment einer solchen Kennung darf nicht mit einer Ziffer beginnen.
    app.setDesktopFileName(QStringLiteral("dev.orangedeck.OrangeDeck"));
    // **Und das Symbol dazu.** Die Zeile darueber genuegt unter Wayland: der
    // Verwalter schlaegt die app_id in der .desktop-Datei nach. Unter X11 und
    // XWayland tut er das nicht -- dort liest er `_NET_WM_ICON` am Fenster,
    // und das ist leer, solange niemand es setzt. Genau so stand das Fenster
    // unter Fedora ohne Symbol in der Leiste (18.09.2026); im Xvfb
    // nachgemessen: die Eigenschaft fehlte ganz.
    app.setWindowIcon(QIcon(QStringLiteral(":/app/icons/dev.orangedeck.OrangeDeck-256.png")));

    QCommandLineParser p;
    p.setApplicationDescription(QStringLiteral(
        "OrangeDeck -- Mempool, Uhr, Miner, Explorer.\n"
        "Ohne Schalter ein gewoehnliches Fenster; mit --layer ein Widget "
        "oder eine Leiste auf dem Desktop."));
    p.addHelpOption();
    p.addVersionOption();
    // Kein kurzes "-v": das ist schon von --version belegt, und
    // QCommandLineParser lehnt dann die **ganze** Option ab -- "--view" waere
    // stillschweigend unbekannt.
    const QCommandLineOption oAnsicht(QStringLiteral("view"),
        QStringLiteral("Ansicht: 0 Feed, 1 Uhr, 2 Miner, 3 Explorer, "
                       "4 Wallet, 5 Einstellungen, 6 Markt. "
                       "Ohne Angabe die zuletzt benutzte."),
        QStringLiteral("nr"));
    const QCommandLineOption oLayer(QStringLiteral("layer"),
        QStringLiteral("Als Layer-Shell-Flaeche: background, bottom (Vorgabe), top, overlay."),
        QStringLiteral("ebene"), QStringLiteral("bottom"));
    const QCommandLineOption oKante(QStringLiteral("anchor"),
        QStringLiteral("Kanten, mit Komma: top,bottom,left,right. "
                       "Zwei gegenueberliegende dehnen die Flaeche."),
        QStringLiteral("kanten"));
    const QCommandLineOption oBreite(QStringLiteral("width"),
        QStringLiteral("Breite in Pixeln (nur mit --layer)."), QStringLiteral("px"));
    const QCommandLineOption oHoehe(QStringLiteral("height"),
        QStringLiteral("Hoehe in Pixeln (nur mit --layer)."), QStringLiteral("px"));
    const QCommandLineOption oRand(QStringLiteral("margin"),
        QStringLiteral("Abstand zur Kante: eine Zahl oder oben,rechts,unten,links."),
        QStringLiteral("px"));
    const QCommandLineOption oPlatz(QStringLiteral("exclusive"),
        QStringLiteral("Platz, den andere Fenster freilassen. 0 keiner (Vorgabe), "
                       "-1 sich selbst ueberlappen lassen."),
        QStringLiteral("px"), QStringLiteral("0"));
    const QCommandLineOption oTasten(QStringLiteral("keyboard"),
        QStringLiteral("Tastatur annehmen (nur mit --layer)."));
    const QCommandLineOption oNackt(QStringLiteral("bare"),
        QStringLiteral("Ohne Reiter, Kopf- und Fusszeile -- fuer ein Widget."));
    const QCommandLineOption oQuelle(QStringLiteral("source"),
        QStringLiteral("Datenquelle: daemon (eigener Dienst, Vorgabe) oder "
                       "direct (selbst zu mempool.space)."),
        QStringLiteral("name"));
    const QCommandLineOption oKennung(QStringLiteral("id"),
        QStringLiteral("Eigener Einstellungsspeicher unter diesem Namen. "
                       "Mehrere Widgets koennen so verschiedene Ansichten "
                       "behalten, ohne sich gegenseitig zu ueberschreiben."),
        QStringLiteral("name"));
    p.addOption(oAnsicht);
    p.addOption(oLayer);
    p.addOption(oKante);
    p.addOption(oBreite);
    p.addOption(oHoehe);
    p.addOption(oRand);
    p.addOption(oPlatz);
    p.addOption(oTasten);
    p.addOption(oNackt);
    p.addOption(oQuelle);
    p.addOption(oKennung);
    p.process(app);

    // Muss **vor** dem Laden des QML stehen: die Settings-Gruppe darin holt
    // sich den Namen beim Erzeugen, spaeter wirkt eine Aenderung nicht mehr.
    if (p.isSet(oKennung) && !p.value(oKennung).isEmpty())
        app.setApplicationName(QStringLiteral("orangedeck-") + p.value(oKennung));

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, []() { QCoreApplication::exit(1); },
                     Qt::QueuedConnection);

    // Das Fenster entsteht unsichtbar und wird erst unten gezeigt. Sonst
    // haengt die Wayland-Flaeche schon, bevor sie zur Layer-Flaeche erklaert
    // werden kann -- und `--layer` bliebe wirkungslos.
    QVariantMap start{{QStringLiteral("visible"), false}};
    if (p.isSet(oAnsicht)) {
        bool ok = false;
        const int nr = p.value(oAnsicht).toInt(&ok);
        if (ok)
            start.insert(QStringLiteral("forcedView"), nr);
    }
#ifdef Q_OS_ANDROID
    // Auf Android gibt es keine Befehlszeile; dieselbe Angabe kommt von der
    // angetippten Verknuepfung. `--view` behaelt trotzdem den Vorrang: es
    // wird nur gesetzt, wenn es ueberhaupt gesetzt werden kann, und beim
    // Pruefen ueber `adb shell am` ist es der kuerzere Weg.
    else {
        const int nr = ansichtAusAbsicht();
        if (nr >= 0)
            start.insert(QStringLiteral("forcedView"), nr);
        const QString seite = seiteAusAbsicht();
        if (!seite.isEmpty())
            start.insert(QStringLiteral("forcedPane"), seite);
    }
#endif
    if (p.isSet(oNackt))
        start.insert(QStringLiteral("bare"), true);
    if (p.isSet(oQuelle))
        start.insert(QStringLiteral("forcedSource"), p.value(oQuelle));
    engine.setInitialProperties(start);
    engine.loadFromModule("OrangeDeck", "Main");

    const auto wurzeln = engine.rootObjects();
    if (wurzeln.isEmpty())
        return 1;
    auto *fenster = qobject_cast<QQuickWindow *>(wurzeln.first());
    if (!fenster)
        return 1;

#ifdef ORANGEDECK_LAYERSHELL
    if (p.isSet(oLayer)) {
        if (LSWindow *ls = LSWindow::get(fenster)) {
            ls->setLayer(ebeneAus(p.value(oLayer)));
            ls->setScope(QStringLiteral("orangedeck"));
            if (p.isSet(oKante))
                ls->setAnchors(kantenAus(p.value(oKante)));
            if (p.isSet(oRand)) {
                const auto t = p.value(oRand).split(QLatin1Char(','), Qt::SkipEmptyParts);
                if (t.size() == 4)
                    ls->setMargins({t[3].toInt(), t[0].toInt(), t[1].toInt(), t[2].toInt()});
                else if (t.size() == 1)
                    ls->setMargins(QMargins(t[0].toInt(), t[0].toInt(),
                                            t[0].toInt(), t[0].toInt()));
            }
            ls->setExclusiveZone(p.value(oPlatz).toInt());
            ls->setKeyboardInteractivity(p.isSet(oTasten)
                ? LSWindow::KeyboardInteractivityOnDemand
                : LSWindow::KeyboardInteractivityNone);
            // Gewuenschte Groesse: was nicht angegeben ist, bleibt die
            // Groesse aus dem QML -- an zwei gegenueberliegenden Kanten
            // bestimmt ohnehin der Compositor.
            const int b = p.isSet(oBreite) ? p.value(oBreite).toInt() : fenster->width();
            const int h = p.isSet(oHoehe) ? p.value(oHoehe).toInt() : fenster->height();
            ls->setDesiredSize(QSize(b, h));
            fenster->resize(b, h);
        }
    }
#elif defined(Q_OS_WIN)
    // **Unter Windows gibt es keine Layer-Shell -- aber das meiste, was sie
    // hier leisten soll, geben die Fensterflags her.** Dieselbe Befehlszeile
    // wie unter niri, damit eine Startzeile auf beiden Systemen dasselbe
    // meint:
    //
    //   ohne Rahmen, nicht in der Taskleiste   FramelessWindowHint | Tool
    //   background, bottom                     WindowStaysOnBottomHint
    //   top, overlay                           WindowStaysOnTopHint
    //   --anchor, --margin, --width, --height  Lage von Hand, im Arbeitsbereich
    //                                          des Bildschirms (ohne Taskleiste)
    //
    // Was fehlt: `--exclusive` (dafuer braeuchte es eine AppBar ueber
    // SHAppBarMessage) und `--keyboard` -- das Fenster nimmt Tasten immer an,
    // denn ohne Rahmen und Taskleisten-Eintrag ist **Q** der einzige Weg,
    // es wieder zu schliessen. Anklicken, dann Q.
    //
    // Gewuenscht vom Anwender am 12.09.2026, als klar war, dass es unter
    // Windows weder Layer-Shell noch ein Dashboard gibt.
    if (p.isSet(oLayer)) {
        const QString ebene = p.value(oLayer);
        Qt::WindowFlags f = Qt::FramelessWindowHint | Qt::Tool;
        if (ebene == QLatin1String("top") || ebene == QLatin1String("overlay"))
            f |= Qt::WindowStaysOnTopHint;
        else
            f |= Qt::WindowStaysOnBottomHint;
        fenster->setFlags(fenster->flags() | f);

        QMargins rand;
        if (p.isSet(oRand)) {
            const auto t = p.value(oRand).split(QLatin1Char(','), Qt::SkipEmptyParts);
            if (t.size() == 4)
                rand = {t[3].toInt(), t[0].toInt(), t[1].toInt(), t[2].toInt()};
            else if (t.size() == 1)
                rand = QMargins(t[0].toInt(), t[0].toInt(), t[0].toInt(), t[0].toInt());
        }

        // Dieselben Kantennamen wie `kantenAus()` oben, nur ohne Layer-Shell,
        // die sie entgegennimmt.
        bool oben = false, unten = false, links = false, rechts = false;
        for (const QString &t : p.value(oKante).split(QLatin1Char(','), Qt::SkipEmptyParts)) {
            const QString k = t.trimmed().toLower();
            oben |= k == QLatin1String("top");
            unten |= k == QLatin1String("bottom");
            links |= k == QLatin1String("left");
            rechts |= k == QLatin1String("right");
        }

        // Je Achse wie bei der Layer-Shell: eine Kante heftet an, zwei
        // gegenueberliegende dehnen, keine setzt in die Mitte.
        const auto lage = [](bool anfang, bool ende, int start, int laenge,
                             int randA, int randE, int soll, int &pos, int &groesse) {
            groesse = soll;
            if (anfang && ende) {
                pos = start + randA;
                groesse = laenge - randA - randE;
            } else if (anfang) {
                pos = start + randA;
            } else if (ende) {
                pos = start + laenge - soll - randE;
            } else {
                pos = start + (laenge - soll) / 2;
            }
        };

        QScreen *schirm = fenster->screen() ? fenster->screen()
                                            : QGuiApplication::primaryScreen();
        const QRect flaeche = schirm->availableGeometry();
        const int b = p.isSet(oBreite) ? p.value(oBreite).toInt() : fenster->width();
        const int h = p.isSet(oHoehe) ? p.value(oHoehe).toInt() : fenster->height();
        int x = 0, y = 0, breite = b, hoehe = h;
        lage(links, rechts, flaeche.x(), flaeche.width(), rand.left(), rand.right(), b, x, breite);
        lage(oben, unten, flaeche.y(), flaeche.height(), rand.top(), rand.bottom(), h, y, hoehe);
        fenster->setGeometry(x, y, breite, hoehe);

        // **Win+D raeumte die Uhr weg.** Am 12.09.2026 in der Pruef-VM
        // gemessen: ein Widget auf `bottom` verschwand bei "Desktop anzeigen"
        // -- also genau dann, wenn man es sehen will --, der Prozess lief
        // weiter. Windows laesst dabei nur Fenster stehen, die dem Desktop
        // gehoeren. Also bekommt das Widget `Progman` als Besitzer (nicht als
        // Eltern: dann waere es ein Kindfenster und zeichnete sich nicht mehr
        // selbst). Fuer `top` nicht -- das soll gerade ueber allem bleiben.
        //
        // **Erst nach dem Zeigen.** Gemessen in der VM (user32
        // `GetWindow(GW_OWNER)`): hier, vor `setVisible`, gesetzt, stand der
        // Besitzer danach leer, und Win+D raeumte die Uhr weiter weg. Von
        // aussen auf das schon sichtbare Fenster gesetzt, hielt er -- und die
        // Uhr blieb bei Win+D stehen. Vermutlich setzt Qt `GWLP_HWNDPARENT`
        // beim Zeigen neu; nachgesehen ist das nicht. Der Nulltimer laeuft
        // beim Start der Ereignisschleife, also nach `setVisible`.
        if (!(f & Qt::WindowStaysOnTopHint)) {
            QTimer::singleShot(0, fenster, [fenster]() {
                if (HWND schreibtisch = FindWindowW(L"Progman", nullptr))
                    SetWindowLongPtrW(reinterpret_cast<HWND>(fenster->winId()), GWLP_HWNDPARENT,
                                      reinterpret_cast<LONG_PTR>(schreibtisch));
            });
        }

        if (p.value(oPlatz).toInt() != 0)
            qWarning("--exclusive wirkt unter Windows nicht -- das Fenster haelt keinen Platz frei.");
    }
#else
    if (p.isSet(oLayer)) {
        qWarning("--layer ist nicht einkompiliert: layer-shell-qt (Qt6) fehlte beim Bauen.");
    }
#endif

    auto *wecker = new WidgetWecker(fenster);
    for (const char *name : {"lang", "currency", "minerHostsRaw"})
        QQmlProperty(fenster, QString::fromLatin1(name)).connectNotifySignal(wecker, SLOT(geaendert()));

    auto *wache = new Wache(fenster);
    QQmlProperty(fenster, QStringLiteral("vollbild")).connectNotifySignal(wache, SLOT(anpassen()));
    wache->anpassen();

    fenster->setVisible(true);
    return app.exec();
}

#include "main.moc"

