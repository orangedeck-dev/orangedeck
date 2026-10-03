package dev.orangedeck.OrangeDeck;

import android.content.Context;

import org.json.JSONArray;
import org.json.JSONObject;

/**
 * Miner mit Hashrate-Verlauf.
 *
 * <p><b>Der Verlauf entsteht erst im Betrieb.</b> AxeOS zeichnet nur auf,
 * wenn {@code statsFrequency} gesetzt ist, und die cgminer-Schnittstelle
 * kennt gar keinen Verlauf: derselbe Satz steht seit dem 02.09.2026 im Kopf
 * von {@code ui/qml/MinerChart.qml}. Das Widget schreibt deshalb selbst mit,
 * einen Punkt je Aktualisierung. Am Anfang ist der Graph leer; nach einem Tag
 * hat er rund achtundvierzig Punkte.
 *
 * <p>Aufgezeichnet wird der **Momentanwert** ({@code hashRate}), nicht der
 * geglaettete Zehnminutenwert. Der ist im Betrieb fast eine Waagerechte, und
 * genau deshalb ist er am 09.09.2026 aus dem Graphen der Anwendung
 * geflogen.
 *
 * <p><b>Fuehrt das Geraet selbst einen Verlauf, kommt er von dort.</b> Seit
 * dem 10.09.2026, wie in der Anwendung ({@code DirectMiner.qml}): mit
 * gesetztem {@code statsFrequency} haelt AxeOS bis zu zwoelf Stunden vor,
 * und das Widget zeigt sie sofort, statt einen Tag auf 48 eigene Punkte zu
 * warten. Dann der Zehnminutenwert: ueber Stunden ist der Momentanwert nur
 * Rauschen. Die Eintraege liegen ungleich weit auseinander (die Firmware
 * duennt aeltere aus), und {@link Graph} zeichnet nach der Reihenfolge --
 * also auf gleich breite Zeitabschnitte gemittelt, sonst waeren die letzten
 * Minuten auf die halbe Breite gezogen. Das eigene Mitschreiben laeuft
 * weiter; faellt die Statistik aus, ist es der Rueckfall.
 */
public class WidgetMinerGross extends GraphWidget {

    private static final String SPEICHER = "miner";
    private static final int PUNKTE = 180;

    @Override protected String titel(Context c) { return Texte.t(c, "miner"); }
    @Override protected String aktion() { return "dev.orangedeck.OrangeDeck.VIEW_MINER"; }


    @Override
    protected String[] werte(Context c) throws Exception {
        String adresse = minerAdresse(c);
        if (adresse == null)
            // Kein Verlauf: `null` statt "" -- sonst stuende unter "Adresse
            // nicht gesetzt" ein "Verlauf entsteht · 0 von 180 Punkten", und
            // ohne Adresse entsteht keiner (11.09.2026 im Emulator).
            return new String[] { "–", Texte.t(c, "miner_keine"), null };

        JSONObject d;
        try {
            d = new JSONObject(holeVon("http://" + adresse + "/api/system/info", 3500));
        } catch (Exception e) {
            // Im Netz nicht erreichbar: der Stand laut Pool, wie im Widget
            // WidgetMiner. Der Verlauf kommt dann vom Pool, wenn unter der
            // Adresse genau ein Geraet steht; den eigenen fuehrt das Widget
            // nicht fort, sonst mischte er Messung und Schaetzung.
            PoolStand p = vomPool(c, adresse, true);
            if (p == null)
                throw e;
            String rate = p.gh >= 1025 ? zahl(p.gh / 1000.0, 2) + " TH/s" : zahl(p.gh, 0) + " GH/s";
            String neben = Texte.t(c, "laut_pool", p.wirt);
            if (p.best > 0)
                neben += " · " + Texte.t(c, "beste", kurz(String.valueOf(p.best)));
            return new String[] { rate, neben, p.kurve != null ? alsText(p.kurve) : null };
        }
        double gh = d.optDouble("hashRate", 0);
        double[] w = Verlauf.anhaengen(c, SPEICHER, gh, PUNKTE);
        if (d.optInt("statsFrequency", 0) > 0) {
            double[] geraet = ausGeraet(adresse);
            if (geraet != null && geraet.length >= 3)
                w = geraet;
        }

        String rate = gh >= 1025 ? zahl(gh / 1000.0, 2) + " TH/s" : zahl(gh, 0) + " GH/s";
        StringBuilder neben = new StringBuilder();
        if (d.has("temp"))
            neben.append(zahl(d.optDouble("temp", 0), 0)).append(" °C");
        if (d.has("bestDiff")) {
            if (neben.length() > 0)
                neben.append(" · ");
            neben.append(Texte.t(c, "beste", kurz(d.optString("bestDiff", ""))));
        }
        return new String[] { rate, neben.length() > 0 ? neben.toString() : null, alsText(w) };
    }

    /** Der Verlauf aus AxeOS, auf {@code ABSCHNITTE} gleich breite Zeitstuecke gemittelt. */
    private static final int ABSCHNITTE = 120;

    private static double[] ausGeraet(String adresse) {
        try {
            JSONObject s = new JSONObject(holeVon("http://" + adresse
                + "/api/system/statistics?columns=hashrate_10m", 4000));
            JSONArray lab = s.optJSONArray("labels"), z = s.optJSONArray("statistics");
            if (lab == null || z == null || z.length() < 3)
                return null;
            int iT = -1, iH = -1;
            for (int i = 0; i < lab.length(); i++) {
                if ("timestamp".equals(lab.optString(i))) iT = i;
                if ("hashrate_10m".equals(lab.optString(i))) iH = i;
            }
            if (iT < 0 || iH < 0)
                return null;
            double t0 = z.getJSONArray(0).optDouble(iT), t1 = z.getJSONArray(z.length() - 1).optDouble(iT);
            if (!(t1 > t0))
                return null;
            double[] summe = new double[ABSCHNITTE];
            int[] anzahl = new int[ABSCHNITTE];
            for (int k = 0; k < z.length(); k++) {
                JSONArray r = z.getJSONArray(k);
                int fach = (int) Math.min(ABSCHNITTE - 1,
                                          Math.floor((r.optDouble(iT) - t0) / (t1 - t0) * ABSCHNITTE));
                summe[fach] += r.optDouble(iH);
                anzahl[fach]++;
            }
            java.util.List<Double> reihe = new java.util.ArrayList<>();
            for (int f = 0; f < ABSCHNITTE; f++)
                if (anzahl[f] > 0)
                    reihe.add(Math.round(summe[f] / anzahl[f] * 10) / 10.0);
            double[] w = new double[reihe.size()];
            for (int f = 0; f < w.length; f++)
                w[f] = reihe.get(f);
            return w;
        } catch (Exception e) {
            return null;
        }
    }
}
