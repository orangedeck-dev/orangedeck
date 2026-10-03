package dev.orangedeck.OrangeDeck;

import android.content.Context;
import org.json.JSONObject;

/**
 * Hashrate und Temperatur des eigenen Bitaxe.
 *
 * <p>Fragt AxeOS direkt ab, wie {@code ui/qml/DirectMiner.qml} -- dieselbe
 * Adresse aus denselben Einstellungen. **Es ist http, kein https**: das Geraet
 * spricht nichts anderes, und Android verbietet Klartext seit Jahren per
 * Vorgabe. Erlaubt wird es in {@code res/xml/network_security_config.xml}, und
 * weil das Widget im selben Paket laeuft, gilt die Ausnahme auch hier.
 */
public class WidgetMiner extends DeckWidget {

    @Override protected String titel(Context c) { return Texte.t(c, "miner"); }
    @Override protected String aktion() { return "dev.orangedeck.OrangeDeck.VIEW_MINER"; }

    @Override
    protected String[] werte(Context c) throws Exception {
        String adresse = minerAdresse(c);
        if (adresse == null) {
            // Kein Fehler, sondern eine offene Einstellung -- und der Satz
            // sagt, wo sie steht.
            return new String[] { "--", Texte.t(c, "miner_keine"), null };
        }
        JSONObject d;
        try {
            d = new JSONObject(holeVon("http://" + adresse + "/api/system/info", 3500));
        } catch (Exception e) {
            // Im Netz nicht erreichbar (unterwegs, Gaeste-WLAN): was der Pool
            // ueber ihn weiss, mit dem Pool als Quelle. Ohne Pool bleibt es
            // der Fehler wie bisher.
            PoolStand p = vomPool(c, adresse, false);
            if (p == null)
                throw e;
            String rate = p.gh >= 1025 ? zahl(p.gh / 1000.0, 2) + " TH/s" : zahl(p.gh, 0) + " GH/s";
            String best = p.best > 0 ? Texte.t(c, "beste", kurz(String.valueOf(p.best))) : null;
            return new String[] { rate, Texte.t(c, "laut_pool", p.wirt), best, null };
        }

        // AxeOS meldet die Hashrate in GH/s. Ab etwa einem TH/s liest sich
        // TH/s besser -- dieselbe Schwelle wie im Graphen der Anwendung.
        double gh = d.optDouble("hashRate", 0);
        String rate = gh >= 1025
            ? zahl(gh / 1000.0, 2) + " TH/s"
            : zahl(gh, 0) + " GH/s";

        String temp = d.has("temp")
            ? zahl(d.optDouble("temp", 0), 0) + " °C" : null;
        String best = d.has("bestDiff")
            ? Texte.t(c, "beste", kurz(d.optString("bestDiff", ""))) : null;
        // Leistung und Luefter stehen in derselben Antwort. Beide nur, wenn
        // das Geraet sie meldet: AxeOS-Fassungen fuehren nicht dieselben
        // Felder, und eine erfundene Zahl waere schlimmer als eine fehlende.
        String last = null;
        if (d.has("power") || d.has("fanrpm")) {
            String w = d.has("power")
                ? zahl(d.optDouble("power", 0), 1) + " W" : null;
            String f = d.has("fanrpm")
                ? Texte.t(c, "luefter", zahl(d.optLong("fanrpm", 0), 0)) : null;
            last = w == null ? f : (f == null ? w : w + " · " + f);
        }
        return new String[] { rate, temp, best, last };
    }
}
