package dev.orangedeck.OrangeDeck;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.res.Configuration;
import android.graphics.Paint;
import android.graphics.Typeface;
import android.os.Bundle;
import android.util.DisplayMetrics;
import android.util.TypedValue;
import android.widget.RemoteViews;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.Locale;

/**
 * Gemeinsamer Unterbau der Homescreen-Widgets.
 *
 * <p><b>Warum das hier Java ist und kein QML.</b> Ein Android-Widget zeichnet
 * nicht die Anwendung, sondern der Systemprozess des Launchers -- ueber
 * {@link RemoteViews}, also Text, Zahlen, Bilder, Fortschrittsbalken. Kein
 * Canvas, kein Qt, keine Kachelgrafik. Der Kommentar in
 * {@code res/xml/shortcuts.xml} sagt das seit dem 05.09.2026 voraus; hier ist
 * es eingeloest.
 *
 * <p><b>Und warum Java und nicht Kotlin:</b> das von androiddeployqt erzeugte
 * Gradle-Projekt legt zwar ein {@code kotlin.srcDirs} an, wendet aber kein
 * Kotlin-Plugin an -- Kotlin-Dateien fielen stillschweigend weg. Java aus
 * {@code android/src/} uebersetzt es ohne Zutun. Fuer Kotlin muessten wir eine
 * eigene {@code build.gradle} mitliefern und bei jedem Qt-Sprung nachziehen.
 *
 * <p><b>Der Takt ist nicht unsere Entscheidung.</b> {@code updatePeriodMillis}
 * laesst fruehestens alle 30 Minuten aktualisieren. Ein Widget ist damit immer
 * ein Standbild in grossen Abstaenden, nie ein laufender Mempool. Der Wert
 * steht in den {@code res/xml/widget_*.xml}.
 */
public abstract class DeckWidget extends AppWidgetProvider {

    /** Ueberschrift der Kachel. */
    protected abstract String titel(Context c);

    /**
     * Welches Layout die Kachel benutzt. Die grosse Blockuhr bringt ein
     * eigenes mit; alle anderen teilen sich {@code widget_deck}.
     */
    protected int layoutId() {
        return R.layout.widget_deck;
    }

    /**
     * Die Textfelder unter dem Hauptwert, von oben nach unten. Ein Widget mit
     * mehr Platz fuehrt hier mehr auf, und {@link #werte} darf entsprechend
     * mehr Zeilen liefern.
     */
    protected int[] zeilenIds() {
        return new int[] { R.id.widget_zeile1, R.id.widget_zeile2, R.id.widget_zeile3 };
    }

    /** Welche Ansicht beim Antippen aufgeht -- dieselben Aktionen wie die Verknuepfungen. */
    protected abstract String aktion();

    /**
     * Holt die Werte. Laeuft **nicht** im Vordergrund-Faden.
     *
     * @return bis zu vier Zeilen: gross, dann drei kleine. Ein {@code null}
     *         laesst die Zeile weg, und die uebrigen ruecken nach: bei 2x2
     *         bliebe sonst die untere Haelfte leer.
     */
    protected abstract String[] werte(Context c) throws Exception;

    /**
     * Die Mempool-Instanz aus den Einstellungen der App, Schluessel
     * {@code mempoolHost}, wie {@code FeedState.basisAus} in QML: leer ist
     * mempool.space, ohne Schema https, ein angehaengtes "/api" faellt weg.
     * Vor jedem Abruf eines Widgets neu gelesen ({@link #api(Context)}), damit
     * eine Aenderung in der App beim naechsten Aufwachen gilt.
     */
    private static volatile String API = "https://mempool.space/api";

    protected static String api(Context c) {
        String h = ausEinstellungen(c, "mempoolHost");
        h = h == null ? "" : h.trim();
        if (h.isEmpty())
            return "https://mempool.space/api";
        if (!h.matches("(?i)^https?://.*"))
            h = "https://" + h;
        h = h.replaceAll("/+$", "").replaceAll("(?i)/api(/v1)?$", "").replaceAll("/+$", "");
        return h + "/api";
    }

    /**
     * **Alle Abrufe eines Widgets zusammen, nicht je Anfrage.** Am 15.09.2026
     * nach einer Neuinstallation am Galaxy: der Starter schickte allen zehn
     * Widgets auf einmal ihre Groesse, jedes holte mit bis zu 6 s Frist je
     * Anfrage ueber ein VPN, und nach rund elf Sekunden meldete Android
     * "bg anr" und beendete den Prozess -- viermal hintereinander, und jedes
     * Mal mit den halb fertigen Abrufen der anderen Widgets darin. Keine
     * Kachel wurde gezeichnet, nicht einmal der Strich fuer "offline".
     * Zwischen Prozessstart und ANR lagen 11,6 s; der Start selbst nimmt
     * davon einen Teil. Sechs Sekunden fuer das Netz lassen Luft.
     */
    private static final long BUDGET_MS = 6000;
    private static final ThreadLocal<Long> ENDE = new ThreadLocal<>();

    @Override
    public void onUpdate(Context context, AppWidgetManager manager, int[] ids) {
        final Context c = context.getApplicationContext();
        Texte.vorbereiten(c);
        // **Zuerst zeichnen, ohne Netz**: der zuletzt geholte Stand, beim
        // ersten Mal Ueberschrift und Auslassung. Wird der Prozess danach
        // doch beendet, bleibt eine Kachel mit Inhalt statt einer leeren.
        final String[] alt = gemerkt(c);
        try {
            zeichne(c, manager, ids, alt != null ? alt : new String[] { "…", null, null });
        } catch (Exception e) {
            // Ein Widget mit eigenem Aufbau kann mit dem Platzhalter nichts
            // anfangen -- dann eben erst nach dem Abruf.
        }

        // **Netz nie im Vordergrund-Faden.** `onUpdate` laeuft aus
        // `onReceive` heraus, und dort wirft jede Verbindung eine
        // NetworkOnMainThreadException. `goAsync()` haelt den Empfaenger am
        // Leben, bis der Faden fertig ist -- und wird spaetestens nach dem
        // Budget freigegeben, damit Android keinen ANR ausloest. Der Faden
        // darf danach weiterzeichnen, solange der Prozess lebt.
        final PendingResult offen = goAsync();
        final java.util.concurrent.atomic.AtomicBoolean frei =
                new java.util.concurrent.atomic.AtomicBoolean(false);
        final Runnable freigeben = new Runnable() {
            @Override
            public void run() {
                if (frei.compareAndSet(false, true))
                    offen.finish();
            }
        };
        new android.os.Handler(android.os.Looper.getMainLooper())
                .postDelayed(freigeben, BUDGET_MS + 1500);
        new Thread(new Runnable() {
            @Override
            public void run() {
                // **Gewartet wird hoechstens das Budget, gezeichnet wird immer
                // vor dem Freigeben.** Die erste Fassung vom 15.09.2026 liess
                // den Abruf nach dem Freigeben weiterlaufen. Android friert
                // einen Prozess ohne laufenden Empfaenger aber kurz danach
                // ein, und der Faden kam nie mehr dazu, "offline" zu zeichnen:
                // am Galaxy blieb hinter einem VPN, dem mempool.space nicht
                // antwortete, das Auslassungszeichen stehen. Ein DNS-Haenger
                // ist von keiner Frist in `holeVon` gedeckt, deshalb die Wache
                // hier aussen.
                final String[][] ergebnis = new String[1][];
                Thread abruf = new Thread(new Runnable() {
                    @Override
                    public void run() {
                        ENDE.set(System.currentTimeMillis() + BUDGET_MS);
                        try {
                            API = api(c);
                            String[] w = werte(c);
                            merke(c, w);
                            synchronized (ergebnis) {
                                ergebnis[0] = w;
                            }
                        } catch (Exception e) {
                            // Bleibt leer, gezeichnet wird "offline". Der Grund
                            // gehoert ins Protokoll: am 16.09.2026 liess sich
                            // nachher nicht mehr sagen, warum alle scheiterten.
                            android.util.Log.w("OrangeDeck", "Widget "
                                    + DeckWidget.this.getClass().getSimpleName() + ": " + e);
                        }
                    }
                });
                abruf.setDaemon(true);
                abruf.start();
                try {
                    abruf.join(BUDGET_MS + 300);
                } catch (InterruptedException e) {
                    // weiter mit dem, was da ist
                }
                String[] z;
                synchronized (ergebnis) {
                    z = ergebnis[0];
                }
                // **Gescheitert: der gemerkte Stand, mit seiner Uhrzeit.** Bis
                // zum 18.09.2026 stand hier immer "-- gerade nicht erreichbar",
                // und am Galaxy zeigten fuenf Kacheln keine einzige Zahl,
                // obwohl der Kurs von vor einer Minute bekannt war. Der Strich
                // bleibt fuer den Fall, dass es nichts Gemerktes gibt: eine
                // leere Flaeche saehe aus wie ein Fehler im Launcher.
                // Und ein zweiter Versuch, sobald Netz da ist -- sonst bleibt
                // der alte Stand bis zum naechsten Takt stehen (WidgetNachholen).
                String stand = null;
                if (z == null) {
                    String[] alt = gemerkt(c);
                    long zeit = gemerktZeit(c);
                    if (alt != null && zeit > 0) {
                        z = alt;
                        stand = Texte.t(c, "stand", uhrzeit(c, zeit));
                    } else {
                        z = new String[] { "--", Texte.t(c, "offline"), null };
                    }
                    WidgetNachholen.einplanen(c, DeckWidget.this.getClass());
                } else {
                    WidgetNachholen.erledigt(c, DeckWidget.this.getClass());
                }
                try {
                    zeichne(c, manager, ids, z, stand);
                } finally {
                    freigeben.run();
                }
            }
        }).start();
    }

    // -- der zuletzt geholte Stand ---------------------------------------------

    private String gemerktSchluessel() {
        return getClass().getName();
    }

    private String[] gemerkt(Context c) {
        String roh = c.getSharedPreferences("widget_stand", Context.MODE_PRIVATE)
                      .getString(gemerktSchluessel(), null);
        if (roh == null)
            return null;
        try {
            JSONArray a = new JSONArray(roh);
            String[] z = new String[a.length()];
            for (int i = 0; i < z.length; i++)
                z[i] = a.isNull(i) ? null : a.getString(i);
            return z;
        } catch (Exception e) {
            return null;
        }
    }

    private void merke(Context c, String[] z) {
        JSONArray a = new JSONArray();
        for (String s : z)
            a.put(s == null ? JSONObject.NULL : s);
        c.getSharedPreferences("widget_stand", Context.MODE_PRIVATE).edit()
         .putString(gemerktSchluessel(), a.toString())
         .putLong(gemerktSchluessel() + ".zeit", System.currentTimeMillis()).apply();
    }

    /**
     * Wann der gemerkte Stand geholt wurde, oder 0. Staende von vor dem
     * 19.09.2026 haben keine Zeit; die zeigen wir nicht als "Stand", bis der
     * erste Abruf danach gelungen ist.
     */
    private long gemerktZeit(Context c) {
        return c.getSharedPreferences("widget_stand", Context.MODE_PRIVATE)
                .getLong(gemerktSchluessel() + ".zeit", 0);
    }

    /**
     * **Eine Uhrzeit, kein Alter.** "vor 3 Min" wuerde auf der Kachel stehen
     * bleiben, bis sie das naechste Mal gezeichnet wird -- ohne Netz bis zu
     * 30 Minuten und laenger --, und waere dann falsch. "14:32" bleibt wahr.
     * Von einem anderen Tag kommt das Datum dazu. Das Format ist das des
     * Telefons (12 oder 24 Stunden).
     */
    private static String uhrzeit(Context c, long zeit) {
        java.util.Date d = new java.util.Date(zeit);
        String uhr = android.text.format.DateFormat.getTimeFormat(c).format(d);
        java.util.Calendar dann = java.util.Calendar.getInstance();
        dann.setTime(d);
        java.util.Calendar jetzt = java.util.Calendar.getInstance();
        if (dann.get(java.util.Calendar.YEAR) == jetzt.get(java.util.Calendar.YEAR)
                && dann.get(java.util.Calendar.DAY_OF_YEAR) == jetzt.get(java.util.Calendar.DAY_OF_YEAR))
            return uhr;
        String muster = android.text.format.DateFormat.getBestDateTimePattern(
                Locale.getDefault(), "dMMM");
        return new java.text.SimpleDateFormat(muster, Locale.getDefault()).format(d) + " " + uhr;
    }

    /**
     * Die Kachel wurde in der Groesse veraendert: neu zeichnen. Ohne das
     * bliebe ein Bild im Seitenverhaeltnis der alten Groesse stehen und
     * wuerde verzogen, bis in bis zu 30 Minuten der naechste Takt kommt.
     */
    @Override
    public void onAppWidgetOptionsChanged(Context context, AppWidgetManager manager,
                                          int id, Bundle neu) {
        onUpdate(context, manager, new int[] { id });
    }

    private void zeichne(Context c, AppWidgetManager manager, int[] ids, String[] z) {
        zeichne(c, manager, ids, z, null);
    }

    /**
     * @param stand {@code null}, wenn {@code z} frisch geholt ist; sonst der
     *              Text fuer die Ueberschrift ("Stand 14:32"). Er ersetzt sie
     *              ganz, in Orange: neben dem Namen der Kachel waere in der
     *              Breite von 2x2 die Uhrzeit abgeschnitten worden, und
     *              welche Kachel es ist, sagt ihr Inhalt.
     */
    private void zeichne(Context c, AppWidgetManager manager, int[] ids, String[] z,
                         String stand) {
        for (int id : ids) {
            RemoteViews v = new RemoteViews(c.getPackageName(), layoutId());
            fuelle(c, v, z, manager.getAppWidgetOptions(id));
            // **Die Farbe jedes Mal setzen, auch die graue.** Am 19.09.2026
            // blieb die Ueberschrift am Galaxy nach dem Nachholen orange:
            // der Starter wendet neue RemoteViews auf die schon gezeichnete
            // Kachel an, und was keine Aktion setzt, bleibt, wie es war --
            // das Grau aus dem Layout kommt dann nicht zurueck.
            if (stand != null)
                v.setTextViewText(R.id.widget_titel, stand);
            v.setTextColor(R.id.widget_titel, stand != null ? 0xfff7931a : 0xff9a94a6);

            Intent i = new Intent(aktion());
            i.setClassName(c.getPackageName(), "org.qtproject.qt.android.bindings.QtActivity");
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            // FLAG_IMMUTABLE ist ab Android 12 Pflicht; wir aendern die
            // Absicht ohnehin nicht mehr.
            v.setOnClickPendingIntent(R.id.widget_wurzel, PendingIntent.getActivity(
                    c, aktion().hashCode(), i,
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE));

            manager.updateAppWidget(id, v);
        }
    }

    /**
     * Traegt die Werte in die Kachel ein. Die Vorgabe passt zu
     * {@code widget_deck}: Ueberschrift, Hauptwert, dann die Zeilen aus
     * {@link #zeilenIds()}. Ein Widget mit eigenem Aufbau ueberschreibt das
     * ganz -- die grosse Blockuhr tut es, weil sie Spalten und einen Balken
     * hat und nicht nur Zeilen.
     */
    protected void fuelle(Context c, RemoteViews v, String[] z) {
        v.setTextViewText(R.id.widget_titel, titel(c));
        v.setTextViewText(R.id.widget_gross, z.length > 0 && z[0] != null ? z[0] : "");
        int[] felder = zeilenIds();
        for (int k = 0; k < felder.length; k++)
            setzeZeile(v, felder[k], z.length > k + 1 ? z[k + 1] : null);
    }

    /**
     * Wie {@link #fuelle(Context, RemoteViews, String[])}, mit den Optionen der
     * Kachel. Ueberschreibt, wer ein Bild zeichnet und dafuer die Groesse
     * braucht; alle anderen bleiben bei der Fassung ohne.
     */
    protected void fuelle(Context c, RemoteViews v, String[] z, Bundle optionen) {
        fuelle(c, v, z);
    }

    /**
     * Die Bildflaeche in {@code widget_graph}, in Geraetepixeln, oder
     * {@code null}, wenn der Starter keine Groesse meldet.
     *
     * <p>Der Starter nennt die Kachel nur als Spanne in dp: im Hochformat gilt
     * die kleinste Breite und die groesste Hoehe, quer umgekehrt. Davon gehen
     * die Abstaende aus {@code widget_graph.xml} ab -- 14dp Rand ringsum, 6dp
     * ueber dem Bild -- und die Textzeilen darueber in der Hoehe, die eine
     * {@code TextView} mit Schriftpolster wirklich hat. Die Schriftgroesse der
     * Einstellungen geht dabei mit ein.
     *
     * @param mitZeile ob die Nebenzeile unter dem Hauptwert zu sehen ist
     */
    protected static int[] bildFlaeche(Context c, Bundle o, boolean mitZeile) {
        if (o == null)
            return null;
        boolean quer = c.getResources().getConfiguration().orientation
                       == Configuration.ORIENTATION_LANDSCAPE;
        int bDp = o.getInt(quer ? AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH
                                : AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH);
        int hDp = o.getInt(quer ? AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT
                                : AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT);
        if (bDp <= 0 || hDp <= 0)
            return null;

        DisplayMetrics dm = c.getResources().getDisplayMetrics();
        float b = (bDp - 2 * 14) * dm.density;
        float h = (hDp - 2 * 14 - 6) * dm.density
                  - zeilenHoehe(dm, 11, false)
                  - zeilenHoehe(dm, 30, true)
                  // Die Nebenzeile hat seit dem 11.09.2026 eine feste Hoehe
                  // (autoSize in widget_graph.xml), nicht mehr die der Schrift.
                  - (mitZeile ? 18 * dm.density : 0);
        // Darunter lohnt kein Bild; dann lieber die alte feste Groesse.
        if (b < 32 || h < 32)
            return null;
        return new int[] { Math.round(b), Math.round(h) };
    }

    /** Hoehe einer einzeiligen TextView: {@code includeFontPadding} rechnet von top bis bottom. */
    private static float zeilenHoehe(DisplayMetrics dm, float sp, boolean fett) {
        Paint p = new Paint();
        p.setTextSize(TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, sp, dm));
        if (fett)
            p.setTypeface(Typeface.DEFAULT_BOLD);
        Paint.FontMetrics fm = p.getFontMetrics();
        return fm.bottom - fm.top;
    }

    protected static void setzeZeile(RemoteViews v, int id, String text) {
        if (text == null || text.isEmpty()) {
            v.setViewVisibility(id, android.view.View.GONE);
        } else {
            v.setViewVisibility(id, android.view.View.VISIBLE);
            v.setTextViewText(id, text);
        }
    }

    // ---------------------------------------------------------------- Hilfen

    /** Zahl mit den Trennzeichen der gewaehlten Sprache -- 80.619, nicht 80619 (siehe Texte.zahl). */
    protected static String zahl(double d, int stellen) {
        return Texte.zahl(d, stellen);
    }

    /**
     * Grosse Zahlen kurz: 673673426 wird zu "673 M".
     *
     * <p>Dieselbe Staffel wie {@code big()} in {@code ui/qml/MinerView.qml},
     * damit Widget und Anwendung dieselbe Zahl gleich schreiben. AxeOS liefert
     * {@code bestDiff} mal als Zeichenkette mit Suffix ("673M"), mal als blanke
     * Zahl; am 09.09.2026 stand deshalb "beste 673673426" auf dem
     * Startbildschirm.
     */
    protected static String kurz(String roh) {
        if (roh == null || roh.isEmpty())
            return null;
        String t = roh.trim();
        double n;
        try {
            n = Double.parseDouble(t);
        } catch (NumberFormatException e) {
            // Schon mit Suffix: so lassen, wie das Geraet es meldet.
            return t;
        }
        String[] u = { "", " k", " M", " G", " T", " P", " E" };
        int i = 0;
        while (n >= 1000 && i < u.length - 1) {
            n /= 1000;
            i++;
        }
        return zahl(n, n >= 100 ? 0 : 2) + u[i];
    }

    /** Dauer wie in der Anwendung: "9 Tage 9 Std", "11 Std", "40 Min". */
    protected static String dauer(Context c, long sekunden) {
        if (sekunden <= 0)
            return "";
        long tage = sekunden / 86400, std = (sekunden % 86400) / 3600;
        if (tage > 0)
            return Texte.t(c, "tage_std", zahl(tage, 0), zahl(std, 0));
        if (std > 0)
            return Texte.t(c, "std", zahl(std, 0));
        return Texte.t(c, "min", zahl(sekunden / 60, 0));
    }

    protected static String hole(String pfad) throws Exception {
        return holeVon(API + pfad, 6000);
    }

    /**
     * Ein GET, mehr nicht. Kurze Fristen: `goAsync()` gibt uns rund zehn
     * Sekunden fuer alles zusammen.
     */
    protected static String holeVon(String url, int frist) throws Exception {
        // Die eigene Frist, aber nie ueber das Budget des Widgets hinaus
        Long ende = ENDE.get();
        if (ende != null) {
            long rest = ende - System.currentTimeMillis();
            if (rest < 300)
                throw new java.io.IOException("Budget des Widgets aufgebraucht");
            frist = (int) Math.min(frist, rest);
        }
        HttpURLConnection v = (HttpURLConnection) new URL(url).openConnection();
        try {
            v.setConnectTimeout(frist);
            v.setReadTimeout(frist);
            v.setRequestProperty("User-Agent", "OrangeDeck-Widget");
            BufferedReader r = new BufferedReader(new InputStreamReader(v.getInputStream()));
            StringBuilder b = new StringBuilder();
            String zeile;
            while ((zeile = r.readLine()) != null)
                b.append(zeile);
            r.close();
            return b.toString();
        } finally {
            v.disconnect();
        }
    }

    protected static JSONObject holeObjekt(String pfad) throws Exception {
        return new JSONObject(hole(pfad));
    }

    protected static JSONArray holeFeld(String pfad) throws Exception {
        return new JSONArray(hole(pfad));
    }

    /**
     * Die Miner-Adresse aus den Einstellungen der Anwendung.
     *
     * <p>Qt legt sie ueber QSettings als schlichte ini-Datei ab
     * ({@code orangedeck/orangedeck.conf}, Schluessel {@code minerHostsRaw}).
     * Der Empfaenger laeuft im **eigenen** Prozess der Anwendung und kommt
     * damit an {@code getFilesDir()} -- eine Bruecke ueber C++ braucht es
     * nicht. Mehrere Adressen trennt die Anwendung mit {@code |}; genommen
     * wird die erste.
     *
     * <p>Bis 03.10.2026 wurde hier am Komma getrennt. Die Anwendung schreibt
     * aber {@code |}, und mit zwei Adressen fragte das Widget die ganze
     * Zeichenkette als eine Adresse ab. Komma gilt weiter, falls jemand so
     * getippt hat, als es nur ein Textfeld gab.
     */
    protected static String minerAdresse(Context c) {
        String wert = ausEinstellungen(c, "minerHostsRaw");
        if (wert == null || wert.isEmpty())
            return null;
        for (String teil : wert.split("[|,]")) {
            String t = teil.trim();
            if (!t.isEmpty())
                return t;
        }
        return null;
    }

    /** Was ein public-pool ueber den Miner weiss (siehe {@code PoolKlient.qml}). */
    protected static final class PoolStand {
        double gh;          // Hashrate in GH/s, wie der Pool sie schaetzt
        double best;        // beste Freigabe
        String wirt;        // fuer "laut pool.solomining.de"
        double[] kurve;     // GH/s, aeltester Punkt zuerst; null ohne
    }

    /**
     * Der Miner aus Sicht des Pools, wenn das Widget ihn im Netz nicht
     * erreicht -- unterwegs, im Gaeste-WLAN. Dieselbe Regel wie in
     * {@code MinerView.qml}: das Geraet, dessen Worker-Name sich die
     * Anwendung beim letzten direkten Kontakt gemerkt hat; ohne gemerkten
     * Namen das einzige aktive Geraet unter der Adresse; sonst die Summe aller
     * aktiven. Null, wenn kein Pool oder keine Adresse eingetragen ist oder
     * der Pool nichts Aktives meldet.
     *
     * <p>Die Adresse geht nur an den eingetragenen Pool, der sie vom Miner
     * ohnehin kennt.
     */
    protected static PoolStand vomPool(Context c, String minerId, boolean mitKurve) {
        String url = ausEinstellungen(c, "poolUrl");
        String adresse = ausEinstellungen(c, "poolAddress");
        if (url == null || adresse == null)
            return null;
        url = entklammern(url).trim();
        adresse = entklammern(adresse).trim();
        if (url.isEmpty() || adresse.isEmpty())
            return null;
        // Ohne Worker-Namen: "bc1q....bitaxe" -> "bc1q...", eine Adresse hat keinen Punkt.
        int punkt = adresse.indexOf('.');
        if (punkt > 0)
            adresse = adresse.substring(0, punkt);
        if (!url.contains("://"))
            url = "https://" + url;
        url = url.replaceAll("/+$", "").replaceAll("(?i)/api$", "");
        try {
            String a = java.net.URLEncoder.encode(adresse, "UTF-8");
            JSONObject d = new JSONObject(holeVon(url + "/api/client/" + a, 4000));
            JSONArray w = d.optJSONArray("workers");
            if (w == null || w.length() == 0)
                return null;
            String gemerkt = null;
            String zu = ausEinstellungen(c, "zuordnungJson");
            if (zu != null && minerId != null) {
                JSONObject z = new JSONObject(entklammern(zu)).optJSONObject(minerId);
                if (z != null && !z.optString("worker", "").isEmpty())
                    gemerkt = z.optString("worker");
            }
            long jetzt = System.currentTimeMillis() / 1000;
            PoolStand p = new PoolStand();
            p.wirt = url.replaceFirst("^[a-zA-Z]+://", "").replaceFirst("[:/].*$", "");
            int aktiv = 0;
            JSONObject einer = null;
            for (int i = 0; i < w.length(); i++) {
                JSONObject x = w.getJSONObject(i);
                double h = x.optDouble("hashRate", 0);
                long gesehen;
                try {
                    gesehen = java.time.Instant.parse(x.optString("lastSeen")).getEpochSecond();
                } catch (Exception e) {
                    gesehen = 0;
                }
                if (!(h > 0) || jetzt - gesehen >= 600)
                    continue;
                if (gemerkt != null && !gemerkt.equals(x.optString("name")))
                    continue;
                aktiv++;
                einer = x;
                p.gh += h / 1e9;
                p.best = Math.max(p.best, x.optDouble("bestDifficulty", 0));
            }
            if (aktiv == 0)
                return null;
            // Der Verlauf gehoert zur ganzen Adresse; er passt nur, wenn dort
            // genau ein Geraet steht.
            if (mitKurve && w.length() == 1 && einer != null) {
                JSONArray k = new JSONArray(holeVon(url + "/api/client/" + a + "/chart", 3000));
                java.util.TreeMap<Long, Double> reihe = new java.util.TreeMap<>();
                for (int i = 0; i < k.length(); i++) {
                    JSONObject x = k.getJSONObject(i);
                    try {
                        reihe.put(java.time.Instant.parse(x.optString("label")).getEpochSecond(),
                                  x.optDouble("data", 0) / 1e9);
                    } catch (Exception e) {
                        // Punkt ohne lesbare Zeit: weglassen
                    }
                }
                if (reihe.size() >= 3) {
                    p.kurve = new double[reihe.size()];
                    int i = 0;
                    for (double v : reihe.values())
                        p.kurve[i++] = v;
                }
            }
            return p;
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * QSettings schreibt Zeichenketten mit Sonderzeichen in Anfuehrungszeichen
     * und maskiert darin {@code "} und {@code \}: aus {@code {"a":1}} wird
     * {@code "{\"a\":1}"}.
     */
    protected static String entklammern(String roh) {
        String t = roh.trim();
        if (t.length() >= 2 && t.startsWith("\"") && t.endsWith("\""))
            t = t.substring(1, t.length() - 1).replace("\\\"", "\"").replace("\\\\", "\\");
        return t;
    }

    /** Ein Wert aus Qts Einstellungsdatei, oder null. */
    protected static String ausEinstellungen(Context c, String schluessel) {
        File f = findeEinstellungen(c);
        if (f == null)
            return null;
        try {
            BufferedReader r = new BufferedReader(new java.io.FileReader(f));
            String zeile, wert = null;
            while ((zeile = r.readLine()) != null) {
                int gleich = zeile.indexOf('=');
                if (gleich < 0)
                    continue;
                if (!zeile.substring(0, gleich).trim().equals(schluessel))
                    continue;
                wert = zeile.substring(gleich + 1).trim();
                break;
            }
            r.close();
            return wert;
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * Sucht Qts Einstellungsdatei im eigenen Datenverzeichnis.
     *
     * <p><b>Warum gesucht und nicht angegeben.</b> Am 09.09.2026 stand hier
     * ein geratener Pfad ({@code .config/orangedeck/orangedeck.conf}), und das
     * Miner-Widget meldete daraufhin auf dem Geraet "Adresse in den
     * Einstellungen setzen", obwohl sie gesetzt war. Wo QSettings unter
     * Android wirklich ablegt, haengt an der Qt-Fassung
     * ({@code AppConfigLocation}) und kann sich mit ihr aendern. Ein Pfad, den
     * man nicht nachsehen kann, ist eine Vermutung: die Anwendung ist ein
     * Release-Bau, {@code adb run-as} greift also nicht.
     *
     * <p>Gesucht wird nur im eigenen {@code getFilesDir()}, hoechstens vier
     * Ebenen tief. Das sind eine Handvoll Dateien; die Suche kostet nichts und
     * haelt auch, wenn Qt den Ort verlegt.
     */
    private static File findeEinstellungen(Context c) {
        return suche(c.getFilesDir(), "orangedeck.conf", 4);
    }

    private static File suche(File verzeichnis, String name, int tiefe) {
        if (verzeichnis == null || tiefe < 0 || !verzeichnis.isDirectory())
            return null;
        File[] kinder = verzeichnis.listFiles();
        if (kinder == null)
            return null;
        for (File k : kinder) {
            if (k.isFile() && k.getName().equals(name))
                return k;
        }
        for (File k : kinder) {
            if (k.isDirectory()) {
                File t = suche(k, name, tiefe - 1);
                if (t != null)
                    return t;
            }
        }
        return null;
    }

    /**
     * Die eingestellte Waehrung, aus derselben ini wie die Miner-Adresse.
     *
     * <p><b>Vorgabe ist USD, nicht EUR.</b> Bitcoin wird weltweit in Dollar
     * notiert; Euro ist eine bewusste Wahl und muss gesetzt werden. Dieselbe
     * Vorgabe gilt in der Anwendung, damit Widget und Reiter nicht
     * auseinanderlaufen, wenn niemand etwas eingestellt hat.
     *
     * <p>Die Schluessel sind die aus {@code ui/qml/money.js}: eur, usd, gbp,
     * chf, cad, aud, jpy. {@code /v1/prices} fuehrt genau diese, in
     * Grossbuchstaben.
     */
    protected static String waehrung(Context c) {
        String w = ausEinstellungen(c, "currency");
        if (w == null || w.isEmpty())
            return "usd";
        return w.toLowerCase(java.util.Locale.ROOT);
    }

    /** Der Schluessel in `/v1/prices`: EUR, USD, ... */
    protected static String waehrungSchluessel(Context c) {
        return waehrung(c).toUpperCase(java.util.Locale.ROOT);
    }

    /** Das Zeichen dahinter, wie in `money.js`. */
    protected static String waehrungZeichen(Context c) {
        String w = waehrung(c);
        if (w.equals("eur")) return "€";
        if (w.equals("gbp")) return "£";
        if (w.equals("chf")) return "CHF";
        if (w.equals("cad")) return "CA$";
        if (w.equals("aud")) return "A$";
        if (w.equals("jpy")) return "¥";
        return "$";
    }

    /**
     * **Alle Widgets auffrischen, wenn sich in der Anwendung etwas aendert,
     * das sie zeigen:** Sprache, Waehrung, Miner-Adresse. Aufgerufen aus
     * main.cpp. Ohne das zogen sie erst beim naechsten Takt nach, bis zu
     * 30 Minuten spaeter; am 10.09.2026 blieben sie nach dem Umstellen auf
     * Englisch deutsch, waehrend neu platzierte schon englisch waren.
     */
    public static void alleAnstossen(Context c) {
        Texte.vergessen();
        Class<?>[] arten = { WidgetUhr.class, WidgetUhrGross.class, WidgetMempool.class,
                             WidgetMempoolGross.class, WidgetKurs.class, WidgetKursGross.class,
                             WidgetMiner.class, WidgetMinerGross.class,
                             WidgetNetz.class, WidgetNetzGross.class };
        for (Class<?> a : arten)
            anstossen(c, a.asSubclass(DeckWidget.class));
    }

    /** Alle Widgets dieser Art sofort auffrischen -- fuer den Aufruf aus der Anwendung. */
    static void anstossen(Context c, Class<? extends DeckWidget> art) {
        AppWidgetManager m = AppWidgetManager.getInstance(c);
        int[] ids = m.getAppWidgetIds(new ComponentName(c, art));
        if (ids == null || ids.length == 0)
            return;
        Intent i = new Intent(c, art);
        i.setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE);
        i.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids);
        c.sendBroadcast(i);
    }
}
