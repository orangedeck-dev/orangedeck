// GET /api/spenden-adresse: eine Empfangsadresse aus dem zpub der Spendenwallet.
//
// **Warum wechselnd.** Eine feste Adresse auf der Seite legt jede Spende
// offen: wer sie kennt, sieht alle Zahlungen und den Stand. Hier kommt je
// Abruf eine Adresse aus der Empfangskette m/84'/0'/0'/0/i, und i ist
// zufaellig aus 0 .. SPENDEN_BEREICH-1.
//
// **Warum zufaellig und nicht fortlaufend.** Ein Zaehler braucht Speicher
// (KV) und liefe bei jedem Abruf durch Crawler weiter, bis die Wallet die
// Adressen nicht mehr absucht. Zufall im festen Bereich braucht nichts;
// dass zwei Spender einmal dieselbe Adresse bekommen, ist hinnehmbar. In
// Sparrow muss das Gap-Limit mindestens so gross sein wie der Bereich
// (Settings > Advanced > Gap Limit), sonst fehlen dort eingegangene Spenden.
//
// Einstellungen im Pages-Projekt (Settings > Variables and Secrets):
//   SPENDEN_ZPUB     der zpub der Spendenwallet, als Secret (verschluesselt)
//   SPENDEN_BEREICH  optional, Standard 200
//
// Der zpub kann nichts ausgeben, verraet aber alle Adressen der Wallet.
// Deshalb eine eigene Wallet nur fuer Spenden, nie die Hauptwallet.
import { adresse } from "../_lib/ableitung.js";

const KOPF = {
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "no-store",
  "X-Robots-Tag": "noindex",
};

export async function onRequestGet({ env }) {
  const zpub = (env.SPENDEN_ZPUB || "").trim();
  if (!zpub) return new Response('{"fehler":"nicht eingerichtet"}', { status: 503, headers: KOPF });
  const bereich = Math.min(Math.max(parseInt(env.SPENDEN_BEREICH || "200", 10) || 200, 1), 10000);
  const zufall = new Uint32Array(1);
  crypto.getRandomValues(zufall);
  try {
    return new Response(JSON.stringify({ adresse: adresse(zpub, zufall[0] % bereich) }), { headers: KOPF });
  } catch (fehler) {
    // Falscher oder abgeschnittener Schluessel. Nicht die Meldung ausgeben:
    // sie koennte Teile des Schluessels enthalten.
    return new Response('{"fehler":"Schluessel ungueltig"}', { status: 500, headers: KOPF });
  }
}
