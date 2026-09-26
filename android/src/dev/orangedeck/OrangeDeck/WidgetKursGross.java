package dev.orangedeck.OrangeDeck;

import android.content.Context;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;

/**
 * Kurs mit Verlauf.
 *
 * <p><b>Die Geschichte wird einmal geholt und danach fortgeschrieben.</b>
 * `historical-price` ohne Zeitstempel sind 1.477.817 Byte (gemessen am
 * 09.09.2026); zweimal je Stunde waeren 72 MB am Tag. Also einmal beim ersten
 * Lauf, danach je Aktualisierung ein Punkt (160 Byte).
 *
 * <p><b>Und nur die letzten dreissig Tage.</b> Die Antwort reicht Jahre
 * zurueck. Ungefiltert stand unter dem Graphen "+11 292,9 % ueber 180 Punkte"
 * -- rechnerisch richtig, als Aussage wertlos. Der Graph zeigt jetzt einen
 * benannten Zeitraum, und die Veraenderung gilt fuer genau diesen.
 */
public class WidgetKursGross extends GraphWidget {

    /**
     * **Je Waehrung ein eigener Verlauf.** Sonst stuenden nach einem
     * Wechsel Euro- und Dollarwerte in derselben Reihe, und die Kurve
     * haette einen Sprung, den es nie gab.
     */
    private String speicher(Context c) { return "kurs_" + waehrung(c); }
    private static final int PUNKTE = 180;
    /** Der gezeigte Zeitraum beim ersten Lauf. */
    private static final long FENSTER = 30L * 24 * 3600;

    @Override protected String titel(Context c) { return Texte.t(c, "kurs"); }
    private String zeichen = "$";
    @Override protected String einheit() { return " " + zeichen; }
    @Override protected String aktion() { return "dev.orangedeck.OrangeDeck.VIEW_CLOCK"; }

    @Override
    protected String[] werte(Context c) throws Exception {
        JSONObject p = holeObjekt("/v1/prices");
        String schl = waehrungSchluessel(c);
        zeichen = waehrungZeichen(c);
        double eur = p.optDouble(schl, 0);
        if (eur <= 0)
            throw new IllegalStateException("kein Kurs");

        double[] w;
        // Neu aufbauen, wenn er leer ist -- oder wenn er aus der Fassung ohne
        // Zeitstempel stammt: der reichte Jahre zurueck, und unter dem
        // Graphen stand "+11 292,9 % ueber 180 Punkte".
        if (Verlauf.leer(c, speicher(c)) || Verlauf.ohneZeit(c, speicher(c)))
            w = ersteGeschichte(c, eur);
        else
            w = Verlauf.anhaengen(c, speicher(c), eur, PUNKTE);

        // Veraenderung und Zeitraum aus dem Verlauf selbst: keine
        // zusaetzliche Abfrage, und beide beschreiben dasselbe Bild.
        String neben = null;
        long spanne = Verlauf.spanne(c, speicher(c));
        if (w.length >= 2 && w[0] > 0) {
            double d = (eur - w[0]) / w[0] * 100.0;
            String zeitraum = spanne > 0 ? dauer(c, spanne)
                                         : Texte.t(c, "punkte", w.length);
            neben = Texte.t(c, "seit",
                                (d >= 0 ? "+" : "") + zahl(d, 1), zeitraum);
        }
        // Die beiden Datumsangaben an den unteren Ecken, wie in der
        // Anwendung. Sie kommen aus den Zeitstempeln des Verlaufs selbst.
        String von = null, bis = null;
        java.util.List<Verlauf.Punkt> p2 = Verlauf.lesen(c, speicher(c));
        if (p2.size() >= 2) {
            von = datum(p2.get(0).zeit);
            bis = datum(p2.get(p2.size() - 1).zeit);
        }
        return new String[] { zahl(eur, 0) + " " + zeichen, neben, alsText(w), von, bis };
    }

    private static String datum(long sekunden) {
        if (sekunden <= 0)
            return null;
        return new java.text.SimpleDateFormat("dd.MM.yyyy", java.util.Locale.getDefault())
            .format(new java.util.Date(sekunden * 1000));
    }

    private double[] ersteGeschichte(Context c, double jetzt) {
        try {
            JSONObject h = new JSONObject(
                holeVon(api(c) + "/v1/historical-price?currency="
                        + waehrungSchluessel(c), 8000));
            JSONArray a = h.optJSONArray("prices");
            if (a == null || a.length() == 0)
                throw new IllegalStateException("kein Verlauf");

            long ab = System.currentTimeMillis() / 1000 - FENSTER;
            // Die Reihe kommt neueste zuerst: einsammeln, bis das Fenster
            // ueberschritten ist, dann ausduennen und umdrehen.
            ArrayList<Verlauf.Punkt> roh = new ArrayList<>();
            for (int i = 0; i < a.length(); i++) {
                JSONObject e = a.getJSONObject(i);
                long t = e.optLong("time", 0);
                double v = e.optDouble(waehrungSchluessel(c), 0);
                if (t < ab)
                    break;
                if (v > 0)
                    roh.add(new Verlauf.Punkt(t, v));
            }
            if (roh.size() < 2)
                throw new IllegalStateException("Fenster leer");

            int schritt = Math.max(1, roh.size() / PUNKTE);
            ArrayList<Verlauf.Punkt> fein = new ArrayList<>();
            for (int i = roh.size() - 1; i >= 0; i -= schritt)
                fein.add(roh.get(i));

            Verlauf.schreiben(c, speicher(c), fein, PUNKTE);
            double[] w = new double[fein.size()];
            for (int i = 0; i < w.length; i++)
                w[i] = fein.get(i).wert;
            return w;
        } catch (Exception e) {
            // Faellt der grosse Abruf aus, faengt der Verlauf bei einem Punkt
            // an. Beim naechsten Lauf wird es noch einmal versucht.
            return Verlauf.anhaengen(c, speicher(c), jetzt, PUNKTE);
        }
    }
}
