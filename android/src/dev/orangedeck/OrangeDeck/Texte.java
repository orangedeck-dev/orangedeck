package dev.orangedeck.OrangeDeck;

import android.content.Context;

import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

/**
 * Die Texte der Widgets, in den dreizehn Sprachen der Anwendung.
 *
 * <p><b>Warum eine Tabelle in Java und keine {@code values-xx/}.</b> Die
 * {@code build.gradle}, die Qt beim Bauen erzeugt, setzt
 * {@code resConfig 'en'} fest ({@code Qt6AndroidGradleHelpers.cmake}, ohne
 * Variable). Jede Sprachressource ausser Englisch wird dabei verworfen; am
 * 09.09.2026 hatte das APK keine einzige, und die Widgets waren auch auf einem
 * deutschen Telefon englisch. Die Alternative waere eine eigene
 * {@code build.gradle}, die wir bei jedem Qt-Sprung nachziehen muessten.
 *
 * <p>Der Preis: Name und Beschreibung in der Widget-Auswahl des Starters
 * kommen aus dem Manifest und bleiben Ressourcen, also englisch.
 *
 * <p><b>Aufbau wie in {@code ui/qml/strings.js}:</b> ein Schluessel je Zeile,
 * eine Spalte je Sprache in der Reihenfolge von {@link #SPRACHEN}. Die Woerter
 * sind, wo es sie dort gibt, von dort uebernommen, damit Widget und Anwendung
 * dasselbe sagen. Platzhalter wie in {@link String#format}; eine Uebersetzung
 * darf sie umstellen ({@code %2$s} vor {@code %1$s}), muss aber dieselben
 * enthalten.
 *
 * <p><b>Welche Sprache.</b> Die in der Anwendung gewaehlte (Schluessel
 * {@code langWahl}, dieselbe ini wie die Waehrung), sonst die des Telefons,
 * wenn wir sie fuehren, sonst Englisch. Nicht mehr {@code lang}: das schrieb
 * die Anwendung bis zum 10.09.2026 bei jedem Beenden hinein, auch ohne dass
 * jemand gewaehlt hatte, und wer das Telefon danach auf Englisch stellte,
 * behielt deutsche Widgets.
 */
final class Texte {

    private Texte() { }

    /** Dieselbe Reihenfolge wie {@code LANGS} in {@code ui/qml/strings.js}. */
    static final String[] SPRACHEN = { "de", "en", "es", "fr", "it", "pt-pt", "nl", "ru",
                                       "ja", "zh", "pt-br", "pl", "cs" };

    private static final int EN = 1;

    private static final Map<String, String[]> T = new HashMap<>();

    private static void t(String schluessel, String... je) {
        T.put(schluessel, je);
    }

    static {
        // ---------------------------------------------- Ueberschriften
        t("uhr", "Blockhöhe", "Block height", "Altura del bloque", "Hauteur de bloc",
          "Altezza blocco", "Altura do bloco", "Blokhoogte", "Высота блока", "ブロック高",
          "区块高度", "Altura do bloco", "Wysokość bloku", "Výška bloku");
        t("uhr_gross", "Blockuhr", "Block clock", "Reloj de bloques", "Horloge des blocs",
          "Orologio dei blocchi", "Relógio de blocos", "Blokklok", "Часы блоков",
          "ブロック時計", "区块时钟", "Relógio de blocos", "Zegar bloków", "Blokové hodiny");
        t("mempool", "Mempool", "Mempool", "Mempool", "Mempool", "Mempool", "Mempool",
          "Mempool", "Мемпул", "メンプール", "内存池", "Mempool", "Mempool", "Mempool");
        t("kurs", "Kurs", "Price", "Precio", "Cours", "Prezzo", "Preço", "Koers", "Курс",
          "価格", "价格", "Preço", "Kurs", "Kurz");
        t("miner", "Miner", "Miner", "Minero", "Mineur", "Miner", "Minerador", "Miner",
          "Майнер", "マイナー", "矿机", "Minerador", "Koparka", "Těžař");
        // Nicht nur "Netzwerk": auf dem Startbildschirm steht das Widget ohne
        // die App drumherum, und "Netzwerk" allein koennte auch das WLAN sein.
        t("netz", "Mining-Netzwerk", "Mining Network", "Red de minería",
          "Réseau de minage", "Rete di mining", "Rede de mineração", "Miningnetwerk",
          "Сеть майнинга", "マイニングネットワーク", "挖矿网络", "Rede de mineração",
          "Sieć wydobywcza", "Těžební síť");

        // ------------------------------- Beschriftungen der grossen Blockuhr
        t("k_gebuehr", "Gebühr", "Fee", "Comisión", "Frais", "Commissione", "Taxa", "Kosten",
          "Комиссия", "手数料", "手续费", "Taxa", "Opłata", "Poplatek");
        t("k_kurs", "Kurs", "Price", "Precio", "Cours", "Prezzo", "Preço", "Koers", "Курс",
          "価格", "价格", "Preço", "Kurs", "Kurz");
        t("k_moscow", "Moscow Time", "Moscow Time", "Moscow Time", "Moscow Time",
          "Moscow Time", "Moscow Time", "Moscow Time", "Moscow Time", "モスクワタイム",
          "莫斯科时间", "Moscow Time", "Moscow Time", "Moscow Time");
        t("k_mempool", "Mempool", "Mempool", "Mempool", "Mempool", "Mempool", "Mempool",
          "Mempool", "Мемпул", "メンプール", "内存池", "Mempool", "Mempool", "Mempool");

        // ---------------------------------------------- Werte und Zeilen
        // Einheiten bleiben ueberall stehen, wie in der Anwendung.
        t("satvb", "%1$s sat/vB", "%1$s sat/vB", "%1$s sat/vB", "%1$s sat/vB",
          "%1$s sat/vB", "%1$s sat/vB", "%1$s sat/vB", "%1$s sat/vB", "%1$s sat/vB",
          "%1$s sat/vB", "%1$s sat/vB", "%1$s sat/vB", "%1$s sat/vB");
        t("moscow", "%1$s sat/%2$s", "%1$s sat/%2$s", "%1$s sat/%2$s", "%1$s sat/%2$s",
          "%1$s sat/%2$s", "%1$s sat/%2$s", "%1$s sat/%2$s", "%1$s sat/%2$s",
          "%1$s sat/%2$s", "%1$s sat/%2$s", "%1$s sat/%2$s", "%1$s sat/%2$s",
          "%1$s sat/%2$s");
        // Die Zahl hat immer eine Nachkommastelle; im Russischen, Polnischen
        // und Tschechischen steht danach der Genitiv Singular.
        t("bloecke", "%1$s Blöcke Rückstau", "%1$s blocks backlog", "%1$s bloques en cola",
          "%1$s blocs en attente", "%1$s blocchi in coda", "%1$s blocos em fila",
          "%1$s blokken achterstand", "%1$s блока в очереди", "%1$s ブロック分の滞留",
          "积压 %1$s 个区块", "%1$s blocos na fila", "%1$s bloku w kolejce",
          "%1$s bloku ve frontě");
        // Wie "feed.mempoolLine" in strings.js; wo die Mehrzahl von der Zahl
        // abhaengt, steht die Zahl hinter dem Wort.
        t("unbestaetigt", "%1$s unbestätigt", "%1$s unconfirmed", "%1$s sin confirmar",
          "%1$s non confirmées", "%1$s non confermate", "%1$s não confirmadas",
          "%1$s onbevestigd", "не подтверждено: %1$s", "未承認 %1$s 件", "%1$s 笔未确认",
          "%1$s não confirmadas", "niepotwierdzone: %1$s", "nepotvrzené: %1$s");
        t("stufen", "schnell %1$s · sparsam %2$s", "fast %1$s · economy %2$s",
          "rápida %1$s · económica %2$s", "rapide %1$s · économique %2$s",
          "veloce %1$s · economica %2$s", "rápida %1$s · económica %2$s",
          "snel %1$s · zuinig %2$s", "быстро %1$s · экономно %2$s", "高速 %1$s · 節約 %2$s",
          "快速 %1$s · 经济 %2$s", "rápida %1$s · econômica %2$s",
          "szybka %1$s · oszczędna %2$s", "rychlý %1$s · úsporný %2$s");
        // Wo die Mehrzahl sich nach der Zahl richtet, steht die Zahl hinter
        // dem Wort -- wie "Найдено блоков: {0}" in strings.js.
        t("tx", "%1$s Transaktionen", "%1$s transactions", "%1$s transacciones",
          "%1$s transactions", "%1$s transazioni", "%1$s transações", "%1$s transacties",
          "транзакций: %1$s", "トランザクション %1$s 件", "%1$s 笔交易", "%1$s transações",
          "transakcje: %1$s", "transakce: %1$s");
        t("tag", "%1$s %% in 24 h", "%1$s %% in 24 h", "%1$s %% en 24 h", "%1$s %% sur 24 h",
          "%1$s %% in 24 h", "%1$s %% em 24 h", "%1$s %% in 24 u", "%1$s %% за 24 ч",
          "24時間で %1$s %%", "24 小时 %1$s %%", "%1$s %% em 24 h", "%1$s %% w 24 godz.",
          "%1$s %% za 24 h");
        t("seit", "%1$s %% über %2$s", "%1$s %% over %2$s", "%1$s %% en %2$s",
          "%1$s %% sur %2$s", "%1$s %% in %2$s", "%1$s %% em %2$s", "%1$s %% over %2$s",
          "%1$s %% за %2$s", "%2$sで %1$s %%", "%2$s内 %1$s %%", "%1$s %% em %2$s",
          "%1$s %% w ciągu %2$s", "%1$s %% za %2$s");
        t("punkte", "%1$d Punkte", "%1$d points", "%1$d puntos", "%1$d points",
          "%1$d punti", "%1$d pontos", "%1$d punten", "%1$d точек", "%1$d 点",
          "%1$d 个点", "%1$d pontos", "%1$d punktów", "%1$d bodů");
        t("waechst", "Verlauf entsteht · %1$d von %2$d Punkten",
          "History building · %1$d of %2$d points",
          "Historial en construcción · %1$d de %2$d puntos",
          "Historique en cours · %1$d sur %2$d points",
          "Storico in costruzione · %1$d di %2$d punti",
          "Histórico a formar-se · %1$d de %2$d pontos",
          "Verloop wordt opgebouwd · %1$d van %2$d punten",
          "История копится · %1$d из %2$d точек", "履歴を記録中 · %2$d 点中 %1$d 点",
          "正在积累历史 · %1$d / %2$d 个点", "Histórico sendo formado · %1$d de %2$d pontos",
          "Historia się zbiera · %1$d z %2$d punktów", "Historie se sbírá · %1$d z %2$d bodů");
        t("laut_pool", "laut %1$s", "per %1$s", "según %1$s", "selon %1$s", "secondo %1$s",
          "segundo %1$s", "volgens %1$s", "по данным %1$s", "%1$s の情報", "来自 %1$s",
          "segundo %1$s", "wg %1$s", "podle %1$s");
        t("beste", "beste %1$s", "best %1$s", "mejor %1$s", "meilleure %1$s",
          "migliore %1$s", "melhor %1$s", "beste %1$s", "лучший %1$s", "最高 %1$s",
          "最佳 %1$s", "melhor %1$s", "najlepszy %1$s", "nejlepší %1$s");
        t("luefter", "%1$s U/min", "%1$s RPM", "%1$s RPM", "%1$s tr/min", "%1$s RPM",
          "%1$s RPM", "%1$s RPM", "%1$s об/мин", "%1$s RPM", "%1$s 转/分", "%1$s RPM",
          "%1$s obr./min", "%1$s ot./min");
        // Das Netz-Widget. Die Woerter wie "difficulty", "net.nextAdj" und
        // "net.blockTime" in strings.js.
        t("schwierigkeit_wert", "Schwierigkeit %1$s", "Difficulty %1$s",
          "Dificultad %1$s", "Difficulté %1$s", "Difficoltà %1$s", "Dificuldade %1$s",
          "Moeilijkheid %1$s", "Сложность %1$s", "難易度 %1$s", "难度 %1$s",
          "Dificuldade %1$s", "Trudność %1$s", "Obtížnost %1$s");
        // Ohne die Restzeit: in 2x2 passen rund 22 Zeichen, "Adjustment
        // +3.0 % · 7 days 20 h" wurde am 11.09.2026 abgeschnitten.
        t("anpassung", "Anpassung %1$s %%", "Adjustment %1$s %%", "Ajuste %1$s %%",
          "Ajustement %1$s %%", "Aggiustamento %1$s %%", "Ajuste %1$s %%",
          "Aanpassing %1$s %%", "Корректировка %1$s %%", "調整 %1$s %%", "调整 %1$s %%",
          "Ajuste %1$s %%", "Korekta %1$s %%", "Úprava %1$s %%");
        t("blockzeit", "Ø Blockzeit %1$s", "Avg. block time %1$s",
          "Tiempo medio de bloque %1$s", "Temps moyen de bloc %1$s",
          "Tempo medio di blocco %1$s", "Tempo médio de bloco %1$s", "Gem. bloktijd %1$s",
          "Ср. время блока %1$s", "平均ブロック時間 %1$s", "平均出块时间 %1$s",
          "Tempo médio de bloco %1$s", "Śr. czas bloku %1$s", "Prům. doba bloku %1$s");

        // ---------------------------------------------- Fristen und Zeiten
        t("halving", "Halving bei %1$s · noch %2$s Blöcke · rund %3$s",
          "Halving at %1$s · %2$s blocks left · about %3$s",
          "Halving en %1$s · faltan %2$s bloques · unos %3$s",
          "Halving à %1$s · encore %2$s blocs · environ %3$s",
          "Halving a %1$s · mancano %2$s blocchi · circa %3$s",
          "Halving em %1$s · faltam %2$s blocos · cerca de %3$s",
          "Halving bij %1$s · nog %2$s blokken · ongeveer %3$s",
          "Халвинг на %1$s · осталось %2$s блоков · примерно %3$s",
          "半減期 %1$s · 残り %2$s ブロック · 約 %3$s",
          "减半于 %1$s · 还剩 %2$s 个区块 · 约 %3$s",
          "Halving em %1$s · faltam %2$s blocos · cerca de %3$s",
          "Halving przy %1$s · pozostało %2$s bloków · około %3$s",
          "Halving na %1$s · zbývá %2$s bloků · asi %3$s");
        t("schwierigkeit_links", "Schwierigkeit %1$s %%", "Difficulty %1$s %%",
          "Dificultad %1$s %%", "Difficulté %1$s %%", "Difficoltà %1$s %%",
          "Dificuldade %1$s %%", "Moeilijkheid %1$s %%", "Сложность %1$s %%",
          "難易度 %1$s %%", "难度 %1$s %%", "Dificuldade %1$s %%", "Trudność %1$s %%",
          "Obtížnost %1$s %%");
        t("schwierigkeit_rechts", "noch %1$s Blöcke · %2$s", "%1$s blocks left · %2$s",
          "faltan %1$s bloques · %2$s", "encore %1$s blocs · %2$s",
          "mancano %1$s blocchi · %2$s", "faltam %1$s blocos · %2$s",
          "nog %1$s blokken · %2$s", "осталось %1$s блоков · %2$s",
          "残り %1$s ブロック · %2$s", "还剩 %1$s 个区块 · %2$s",
          "faltam %1$s blocos · %2$s", "pozostało %1$s bloków · %2$s",
          "zbývá %1$s bloků · %2$s");
        t("tage_std", "%1$s Tage %2$s Std", "%1$s days %2$s h", "%1$s d %2$s h",
          "%1$s j %2$s h", "%1$s g %2$s h", "%1$s d %2$s h", "%1$s d %2$s u",
          "%1$s д %2$s ч", "%1$s日%2$s時間", "%1$s 天 %2$s 小时", "%1$s d %2$s h",
          "%1$s d %2$s godz.", "%1$s d %2$s h");
        t("std", "%1$s Std", "%1$s h", "%1$s h", "%1$s h", "%1$s h", "%1$s h", "%1$s u",
          "%1$s ч", "%1$s時間", "%1$s 小时", "%1$s h", "%1$s godz.", "%1$s h");
        t("min", "%1$s Min", "%1$s min", "%1$s min", "%1$s min", "%1$s min", "%1$s min",
          "%1$s min", "%1$s мин", "%1$s分", "%1$s 分钟", "%1$s min", "%1$s min",
          "%1$s min");
        t("vor_min", "vor %1$d Min", "%1$d min ago", "hace %1$d min", "il y a %1$d min",
          "%1$d min fa", "há %1$d min", "%1$d min geleden", "%1$d мин назад", "%1$d分前",
          "%1$d 分钟前", "há %1$d min", "%1$d min temu", "před %1$d min");
        t("in_min", "in ~%1$d Min", "in ~%1$d min", "en ~%1$d min", "dans ~%1$d min",
          "tra ~%1$d min", "em ~%1$d min", "over ~%1$d min", "через ~%1$d мин",
          "約%1$d分後", "约 %1$d 分钟后", "em ~%1$d min", "za ~%1$d min", "za ~%1$d min");

        // ---------------------------------------------- Zustaende
        t("miner_keine", "Adresse nicht gesetzt", "Address not set",
          "Dirección no configurada", "Adresse non définie", "Indirizzo non impostato",
          "Endereço não definido", "Adres niet ingesteld", "Адрес не задан",
          "アドレス未設定", "未设置地址", "Endereço não definido",
          "Adres nie jest ustawiony", "Adresa není nastavena");
        t("offline", "gerade nicht erreichbar", "not reachable right now",
          "no accesible ahora", "injoignable pour l’instant",
          "non raggiungibile al momento", "inacessível de momento", "nu niet bereikbaar",
          "сейчас недоступно", "現在接続できません", "暂时无法连接",
          "inacessível no momento", "chwilowo niedostępny", "momentálně nedostupné");
        // Ueber einem gemerkten Stand, wenn der Abruf scheiterte (DeckWidget)
        t("stand", "Stand %1$s", "as of %1$s", "actualizado %1$s", "mis à jour %1$s",
          "aggiornato %1$s", "atualizado %1$s", "bijgewerkt %1$s", "на %1$s",
          "%1$s 時点", "截至 %1$s", "atualizado %1$s", "stan z %1$s", "stav k %1$s");
    }

    /**
     * Der Text zu {@code schluessel} in der Sprache der Anwendung.
     * Ein unbekannter Schluessel kommt unveraendert zurueck: ein
     * Schreibfehler soll im Widget auffallen, nicht es leer lassen.
     */
    static String t(Context c, String schluessel, Object... werte) {
        String[] je = T.get(schluessel);
        if (je == null)
            return schluessel;
        int i = spalte(c);
        String muster = i < je.length && je[i] != null ? je[i] : je[EN];
        return werte.length == 0 ? muster : String.format(Locale.ROOT, muster, werte);
    }

    // Die Sprache wird je Aktualisierung einmal nachgesehen, nicht je Text:
    // dafuer liest `ausEinstellungen` jedes Mal die ini.
    private static int gemerkt = -1;
    private static long gemerktUm;

    private static synchronized int spalte(Context c) {
        long jetzt = System.currentTimeMillis();
        if (gemerkt < 0 || jetzt - gemerktUm > 5000) {
            gemerkt = index(sprache(c));
            gemerktUm = jetzt;
        }
        return gemerkt;
    }

    /** Die Sprache fuer diese Aktualisierung bestimmen; vor dem ersten Text und der ersten Zahl. */
    static void vorbereiten(Context c) {
        spalte(c);
    }

    /**
     * **Zahlen in der Schreibweise der gewaehlten Sprache, nicht des Telefons.**
     * Bis zum 10.09.2026 formatierte das Widget nach {@code Locale.getDefault()}:
     * die Anwendung auf Englisch, das Telefon auf de-AT, und im englischen
     * Widget stand "966 416" und "1,0 sat/vB", waehrend die Anwendung daneben
     * "966,416" schrieb. Dieselben Regeln wie {@code sep()} und
     * {@code decimal()} in {@code ui/qml/strings.js}: Englisch, Japanisch und
     * Chinesisch trennen Tausender mit Komma, Franzoesisch, Russisch,
     * Polnisch und Tschechisch mit einem schmalen Leerzeichen (U+202F), alle
     * uebrigen mit Punkt; das Dezimalzeichen ist bei den ersten dreien der
     * Punkt, sonst das Komma.
     */
    static String zahl(double d, int stellen) {
        int i = gemerkt >= 0 ? gemerkt : EN;
        String s = SPRACHEN[i];
        boolean punktDezimal = s.equals("en") || s.equals("ja") || s.equals("zh");
        char tausender = punktDezimal ? ','
            : (s.equals("fr") || s.equals("ru") || s.equals("pl") || s.equals("cs")) ? '\u202F' : '.';
        java.text.DecimalFormatSymbols z = new java.text.DecimalFormatSymbols(Locale.ROOT);
        z.setGroupingSeparator(tausender);
        z.setDecimalSeparator(punktDezimal ? '.' : ',');
        StringBuilder muster = new StringBuilder("#,##0");
        if (stellen > 0) {
            muster.append('.');
            for (int k = 0; k < stellen; k++)
                muster.append('0');
        }
        java.text.DecimalFormat f = new java.text.DecimalFormat(muster.toString(), z);
        f.setRoundingMode(java.math.RoundingMode.HALF_UP);
        return f.format(d);
    }

    /** Beim naechsten Text neu nachsehen -- nach einer Aenderung in der Anwendung. */
    static synchronized void vergessen() {
        gemerkt = -1;
    }

    /** Die Sprache als Schluessel aus {@link #SPRACHEN}. */
    static String sprache(Context c) {
        String a = DeckWidget.ausEinstellungen(c, "langWahl");
        if (a != null && index(a) >= 0)
            return a;

        Locale l = Locale.getDefault();
        String s = l.getLanguage();
        // Portugiesisch gibt es zweimal: Brasilien fuer sich, alle anderen
        // mit der europaeischen Schreibung.
        if (s.equals("pt"))
            return "BR".equals(l.getCountry()) ? "pt-br" : "pt-pt";
        return index(s) >= 0 ? s : "en";
    }

    private static int index(String sprache) {
        for (int i = 0; i < SPRACHEN.length; i++)
            if (SPRACHEN[i].equals(sprache))
                return i;
        return -1;
    }
}
