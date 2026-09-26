package dev.orangedeck.OrangeDeck;

import android.content.Context;
import android.widget.RemoteViews;

import org.json.JSONArray;
import org.json.JSONObject;

/**
 * Die grosse Blockuhr: derselbe Aufbau wie der Reiter "Uhr" in der Anwendung.
 *
 * <p>Zentrierte Ueberschrift, grosse Blockhoehe, eine Zeile aus beschrifteten
 * Spalten, dann Schwierigkeit mit Fortschrittsbalken und die Halving-Zeile.
 *
 * <p><b>Vier Spalten statt fuenf.</b> Die Anwendung fuehrt zusaetzlich die
 * Hashrate; sie kommt aus {@code /v1/mining/hashrate/3d}, und dieser Aufruf
 * brach am 09.09.2026 nach <b>19,7 Sekunden</b> ohne Antwort ab. Ein Widget
 * hat ueber {@code goAsync()} zusammen rund zehn. Der Wert ist damit nicht
 * teuer, sondern unerreichbar.
 *
 * <p><b>Vier Abfragen in einer Frist.</b> Deshalb steht die Frist je Aufruf
 * auf drei Sekunden, und jeder Block ist einzeln abgesichert: faellt einer
 * aus, fehlt seine Spalte und der Rest steht.
 */
public class WidgetUhrGross extends DeckWidget {

    /** Halving alle 210 000 Bloecke. */
    private static final long HALVING_ABSTAND = 210000;
    /** Zielabstand zweier Bloecke in Sekunden. */
    private static final long BLOCKZEIT = 600;

    @Override protected String titel(Context c) { return Texte.t(c, "uhr_gross"); }
    @Override protected String aktion() { return "dev.orangedeck.OrangeDeck.VIEW_CLOCK"; }
    @Override protected int layoutId() { return R.layout.widget_uhr_gross; }

    @Override
    protected String[] werte(Context c) throws Exception {
        // 1. Block: ohne ihn gibt es keine Uhr.
        JSONArray a = new JSONArray(holeVon(api(c) + "/v1/blocks", 3000));
        if (a.length() == 0)
            throw new IllegalStateException("keine Bloecke");
        long hoehe = a.getJSONObject(0).getLong("height");

        String gebuehr = null, kurs = null, moscow = null, mempool = null;

        try {
            JSONObject g = new JSONObject(
                holeVon(api(c) + "/v1/fees/recommended", 3000));
            gebuehr = zahl(g.optDouble("halfHourFee", 0), 1) + " sat/vB";
        } catch (Exception e) { /* Spalte bleibt leer */ }

        try {
            JSONObject p = new JSONObject(
                holeVon(api(c) + "/v1/prices", 3000));
            double wert = p.optDouble(waehrungSchluessel(c), 0);
            if (wert > 0) {
                kurs = zahl(wert, 0) + " " + waehrungZeichen(c);
                moscow = zahl(Math.round(1e8 / wert), 0) + " sat";
            }
        } catch (Exception e) { /* Spalten bleiben leer */ }

        try {
            JSONObject m = new JSONObject(
                holeVon(api(c) + "/mempool", 3000));
            mempool = zahl(m.optLong("count", 0), 0);
        } catch (Exception e) { /* Spalte bleibt leer */ }

        String diffLinks = null, diffRechts = null, fortschritt = "0";
        try {
            JSONObject d = new JSONObject(
                holeVon(api(c) + "/v1/difficulty-adjustment", 3000));
            double aend = d.optDouble("difficultyChange", 0);
            diffLinks = Texte.t(c, "schwierigkeit_links",
                                    (aend >= 0 ? "+" : "") + zahl(aend, 2));
            long rest = d.optLong("remainingBlocks", 0);
            diffRechts = Texte.t(c, "schwierigkeit_rechts",
                                     zahl(rest, 0),
                                     dauer(c, d.optLong("remainingTime", 0) / 1000));
            fortschritt = String.valueOf(Math.round(d.optDouble("progressPercent", 0)));
        } catch (Exception e) { /* Zeile und Balken bleiben leer */ }

        // Das Halving ist reine Rechnung, keine fuenfte Abfrage.
        long naechstes = (hoehe / HALVING_ABSTAND + 1) * HALVING_ABSTAND;
        long fehlt = naechstes - hoehe;
        String halving = Texte.t(c, "halving",
                                     zahl(naechstes, 0), zahl(fehlt, 0),
                                     dauer(c, fehlt * BLOCKZEIT));

        return new String[] { zahl(hoehe, 0), gebuehr, kurs, moscow, mempool,
                              diffLinks, diffRechts, fortschritt, halving };
    }

    @Override
    protected void fuelle(Context c, RemoteViews v, String[] z) {
        v.setTextViewText(R.id.widget_titel, Texte.t(c, "uhr"));
        v.setTextViewText(R.id.widget_gross, wert(z, 0));

        v.setTextViewText(R.id.widget_k1, Texte.t(c, "k_gebuehr"));
        v.setTextViewText(R.id.widget_v1, wert(z, 1));
        v.setTextViewText(R.id.widget_k2, Texte.t(c, "k_kurs"));
        v.setTextViewText(R.id.widget_v2, wert(z, 2));
        v.setTextViewText(R.id.widget_k3, Texte.t(c, "k_moscow"));
        v.setTextViewText(R.id.widget_v3, wert(z, 3));
        v.setTextViewText(R.id.widget_k4, Texte.t(c, "k_mempool"));
        v.setTextViewText(R.id.widget_v4, wert(z, 4));

        setzeZeile(v, R.id.widget_diff_links, z.length > 5 ? z[5] : null);
        setzeZeile(v, R.id.widget_diff_rechts, z.length > 6 ? z[6] : null);
        int p = 0;
        try {
            p = Integer.parseInt(z.length > 7 && z[7] != null ? z[7] : "0");
        } catch (NumberFormatException e) { /* bleibt 0 */ }
        v.setProgressBar(R.id.widget_balken, 100, p, false);
        setzeZeile(v, R.id.widget_halving, z.length > 8 ? z[8] : null);
    }

    /** Ein fehlender Wert wird zum Gedankenstrich, nicht zur Luecke. */
    private static String wert(String[] z, int i) {
        return (z.length > i && z[i] != null && !z[i].isEmpty()) ? z[i] : "–";
    }
}
