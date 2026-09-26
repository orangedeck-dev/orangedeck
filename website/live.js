// Der Kopf von orangedeck.dev: die fünf Ansichten der Anwendung, im Wechsel.
//
// **So, wie die Anwendung aussieht.** Jede Ansicht ist nach dem Fenster der
// Anwendung in 1280 x 800 gebaut, mit denselben Abständen, Farben und
// Beschriftungen, und wird als Ganzes auf die Breite der Seite skaliert. Bis
// zum 26.09.2026 standen hier eigene, vereinfachte Nachbauten, die in der
// Anwendung so nirgends vorkommen; dazu ein Miner und eine Wallet mit
// erfundenen Zahlen. Beides ist weg: gezeigt wird nur, was sich von hier aus
// messen lässt, und die Reiter sind die, die die Anwendung ohne eigenen Dienst
// zeigt (Feed, Uhr, Mining, Explorer, Markt).
//
// **Die Wörter kommen aus der Anwendung.** `tools/website.py` zieht die
// nötigen Schlüssel aus `ui/qml/strings.js` in der Sprache der Seite und
// reicht sie als `ORANGEDECK_LIVE.s` herein. Diese Datei trägt keinen Text.
//
// **Quellen**, dieselben wie in der Anwendung ohne Dienst:
//   mempool.space  WebSocket (Blöcke, Mempool, Gebühren, nächster Block mit
//                  seinen Transaktionen), REST für Kurs, Hashrate und die
//                  Zusammenfassung des letzten Blocks
//   Binance, Bybit öffentliche Trades und Kerzen, erst wenn der Markt einmal
//                  gezeigt wurde, und nur solange jemand hinsieht
//
// **Packung und Farben kommen aus der Anwendung selbst**: `mondrian.js` setzt
// die Kacheln, `colors.js` färbt sie. Beide liegen unverändert unter
// `ui/qml/` und werden von `tools/website.py` hierher kopiert.
//
// **Das Standbild bleibt liegen, bis Daten da sind.** Ohne JavaScript, bei
// `prefers-reduced-motion` und solange der WebSocket nichts geliefert hat,
// sieht man das Bild aus `bilder/`. Erst die erste Nachricht mit
// Transaktionen schaltet um. Wer mempool.space nicht erreicht (Werbeblocker,
// Firmennetz, Ausfall), sieht also das Bild und keinen leeren Kasten.
(function () {
  "use strict";

  var MP = "https://mempool.space";
  var WS_URL = "wss://mempool.space/api/v1/ws";
  var BINANCE = "https://data-api.binance.vision/api/v3/klines?symbol=BTCUSDT&interval=15m&limit=96";
  var BINANCE_WS = "wss://data-stream.binance.vision/ws/btcusdt@aggTrade";
  var BYBIT_WS = "wss://stream.bybit.com/v5/public/spot";
  var B = 1280, H = 800;
  var WECHSEL_MS = 8000;
  // Der Strom läuft nur, solange jemand hinsieht. Das ist fremder Verkehr.
  var STILL_NACH_MS = 5 * 60 * 1000;
  var HALVING = 1050000;

  var TEXT = "#f2eef8", DIM = "#9a94a6", ORANGE = "#f7931a", LINIE = "#1c1c23";
  var GRUEN = "#5cb946", ROT = "#d33f3f";

  var L = window.ORANGEDECK_LIVE || {};
  var S = L.s || {};
  var LANG = document.documentElement.lang || "en";

  function t(k, a0, a1, a2) {
    var s = S[k] !== undefined ? S[k] : k;
    return String(s).replace("{0}", a0).replace("{1}", a1).replace("{2}", a2);
  }
  function zahl(n, stellen) {
    try {
      return new Intl.NumberFormat(LANG, {
        minimumFractionDigits: stellen || 0, maximumFractionDigits: stellen || 0
      }).format(n);
    } catch (e) {
      return String(Math.round(n));
    }
  }
  // Wie `fee()` in BlockChain.qml: unter 10 sat/vB eine Nachkommastelle.
  function gebuehr(n) {
    if (n === undefined || n === null) return "–";
    return n >= 10 ? zahl(Math.round(n)) : zahl(n, 1);
  }
  // Wie `Tr.big`: 1,306 EH/s, 133 T, 98.64 T. Endet bei E, die Anwendung
  // schreibt 1,306 EH/s und nicht 1.31 ZH/s.
  function gross(v, einheit) {
    var p = ["", "k", "M", "G", "T", "P", "E"], i = 0;
    while (Math.abs(v) >= 1000 && i < p.length - 1) { v /= 1000; i++; }
    var st = Math.abs(v) >= 100 ? 0 : 2;
    return (zahl(v, st) + " " + p[i] + (einheit || "")).trim();
  }
  function vor(ts) {
    var m = Math.floor(Math.max(0, Date.now() / 1000 - ts) / 60);
    return m < 1 ? t("ago.now") : t("ago.min", m);
  }
  function dauer(ms) {
    var h = Math.round(ms / 3600000);
    return t("duration.dayHour", Math.floor(h / 24), h % 24);
  }
  function z2(n) { return (n < 10 ? "0" : "") + n; }
  function tag(ts) {
    var d = new Date(ts * 1000);
    if (LANG === "de") return z2(d.getDate()) + "." + z2(d.getMonth() + 1) + "." + d.getFullYear();
    return d.getFullYear() + "-" + z2(d.getMonth() + 1) + "-" + z2(d.getDate());
  }
  function datum(ts) {
    var d = new Date(ts * 1000);
    return tag(ts) + "  " + z2(d.getHours()) + ":" + z2(d.getMinutes());
  }
  function holen(url) {
    return fetch(url).then(function (a) { if (!a.ok) throw new Error(a.status); return a.json(); });
  }

  // Ein Element mit fester Lage im 1280 x 800-Fenster.
  function el(tag, stil, text) {
    var d = document.createElement(tag);
    if (stil) d.style.cssText = stil;
    if (text !== undefined) d.textContent = text;
    return d;
  }
  function an(eltern, kind) { eltern.appendChild(kind); return kind; }
  function leinwand(eltern, x, y, w, h) {
    var c = an(eltern, el("canvas", "position:absolute;left:" + x + "px;top:" + y + "px;width:" + w + "px;height:" + h + "px"));
    c.lw = w; c.lh = h;
    return c;
  }
  // Canvas in Gerätepixeln: logische Größe mal Skalierung mal devicePixelRatio.
  function vorbereiten(c, k) {
    var f = Math.max(0.5, k * Math.min(2, window.devicePixelRatio || 1));
    var w = Math.round(c.lw * f), h = Math.round(c.lh * f);
    if (c.width !== w || c.height !== h) { c.width = w; c.height = h; }
    var ctx = c.getContext("2d");
    ctx.setTransform(f, 0, 0, f, 0, 0);
    return ctx;
  }

  // Farben der Blockkarten, wie BlockCard.qml und feeShade() in BlockChain.qml
  function hsv(h, s, v) {
    var i = Math.floor(h * 6), f = h * 6 - i, p = v * (1 - s), q = v * (1 - f * s), u = v * (1 - (1 - f) * s);
    return [[v, q, p, p, u, v][i % 6], [u, v, v, q, p, p][i % 6], [p, p, u, v, v, q][i % 6]];
  }
  function rgb(c) {
    return "rgb(" + c.map(function (x) { return Math.round(Math.min(1, x) * 255); }).join(",") + ")";
  }
  function heller(c, f) { return [c[0] * f, c[1] * f, c[2] * f]; }
  function karte(basis) {
    return "background:linear-gradient(180deg," + rgb(heller(basis, 1.18)) + " 0%," + rgb(basis) + " 55%," + rgb(heller(basis, 1 / 1.4)) + " 100%);"
      + "border:1px solid rgba(255,255,255,0.16);border-radius:4px;box-shadow:inset 0 1px 0 rgba(255,255,255,0.3);box-sizing:border-box;";
  }
  var GRUEN_HUE = 0.4097; // pendingColor #2f9e63
  function wartend(median) {
    var f = Math.max(0, Math.min(1, (median || 0) / 12));
    return hsv(GRUEN_HUE, 0.45 + 0.3 * f, 0.34 + 0.30 * f);
  }
  var LILA = [0x7b / 255, 0x5c / 255, 0xd6 / 255]; // minedColor

  var gestartet = false;
  function bereit() {
    if (gestartet) return;
    var wirt = document.getElementById("live");
    if (!wirt || !window.MondrianLayout || !window.ageColor) return;
    if (!("WebSocket" in window) || !window.fetch) return;
    if (window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    gestartet = true;
    new Kopf(wirt);
  }

  // =====================================================================
  function Kopf(wirt) {
    var ich = this;
    this.stand = { blocks: [], mbloecke: [], info: null, fees: null, da: null, preis: 0,
                   netz: null, naechster: {}, summe: null };
    this.blick = Date.now();
    this.ws = null;
    this.seite = 0;
    this.wirt = wirt;
    this.laeuft = false;
    this.k = 1;

    this.huelle = an(wirt, el("div", ""));
    this.huelle.className = "live-huelle";
    this.fenster = an(this.huelle, el("div", "position:absolute;left:0;top:0;width:" + B + "px;height:" + H
      + "px;transform-origin:0 0;background:#0b0b12;overflow:hidden;color:" + TEXT
      + ";font-family:'Noto Sans',system-ui,sans-serif;line-height:1.3;text-align:left;"));

    // Reiter oben links, wie ViewTabs.qml
    var reihe = an(this.fenster, el("div", "position:absolute;left:14px;top:6px;display:flex;gap:19px;font-size:14px;"));
    var namen = [t("tab.feed"), t("tab.clock"), t("tab.miner"), t("tab.explorer"), t("tab.market")];
    this.knoepfe = namen.map(function (n, i) {
      var b = an(reihe, el("button", "all:unset;cursor:pointer;color:" + DIM + ";padding-bottom:5px;border-bottom:2px solid transparent;", n));
      b.type = "button";
      b.addEventListener("click", function () { ich.zeigen(i, true); });
      return b;
    });
    // Zahnrad und Vollbild der Anwendung, hier nur als Bild
    var symbole = an(this.fenster, el("div", "position:absolute;right:18px;top:8px;display:flex;gap:24px;pointer-events:none;"));
    symbole.setAttribute("aria-hidden", "true");
    symbole.innerHTML = '<svg width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="' + TEXT + '" stroke-width="1.8"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/></svg>'
      + '<svg width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="' + TEXT + '" stroke-width="2"><path d="M4 9V4h5M15 4h5v5M20 15v5h-5M9 20H4v-5"/></svg>';

    this.seiten = [new Feed(), new Uhr(), new Mining(), new Explorer(), new Markt()];
    this.seiten.forEach(function (s) {
      s.kopf = ich;
      s.wurzel = an(ich.fenster, el("div", "position:absolute;left:0;top:0;width:" + B + "px;height:" + H + "px;display:none;"));
      s.aufbauen(s.wurzel);
    });

    this.verbinden();
    window.addEventListener("resize", function () { ich.skalieren(); });
    document.addEventListener("visibilitychange", function () {
      if (document.hidden) ich.anhalten();
      else ich.wecken();
    });
    ["pointermove", "keydown", "scroll"].forEach(function (n) {
      window.addEventListener(n, function () { ich.blick = Date.now(); }, { passive: true });
    });
  }

  Kopf.prototype.skalieren = function () {
    this.k = (this.wirt.clientWidth || B) / B;
    this.fenster.style.transform = "scale(" + this.k + ")";
    if (this.laeuft) this.auffrischen();
  };

  // Erst jetzt verschwindet das Standbild, und erst jetzt laufen die Uhren.
  Kopf.prototype.losgehen = function () {
    var ich = this;
    this.laeuft = true;
    this.wirt.classList.add("laeuft");
    this.skalieren();
    this.nachladen();
    this.zeigen(0, false);
    this.uhrwerk = window.setInterval(function () { ich.weiter(); }, WECHSEL_MS);
    this.takt = window.setInterval(function () { ich.auffrischen(); }, 1000);
    this.kurswerk = window.setInterval(function () { ich.kurs(); }, 60000);
  };

  // Was der WebSocket nicht mitbringt: Kurs, Hashrate über ein Jahr und der
  // Inhalt des letzten Blocks.
  Kopf.prototype.nachladen = function () {
    var ich = this;
    this.kurs();
    holen(MP + "/api/v1/mining/hashrate/1y").then(function (d) {
      ich.stand.netz = d;
      ich.auffrischen();
    }).catch(function () {});
    this.blockInhalt();
  };
  Kopf.prototype.kurs = function () {
    var ich = this;
    if (document.hidden) return;
    holen(MP + "/api/v1/prices").then(function (d) {
      if (d && d.USD) { ich.stand.preis = d.USD; ich.auffrischen(); }
    }).catch(function () {});
  };
  Kopf.prototype.blockInhalt = function () {
    var ich = this, b = this.letzter();
    if (!b || (this.stand.summe && this.stand.summe.id === b.id)) return;
    holen(MP + "/api/v1/block/" + b.id + "/summary").then(function (d) {
      ich.stand.summe = { id: b.id, txs: d };
      ich.seiten[0].blockNeu(ich.stand);
    }).catch(function () {});
  };
  Kopf.prototype.letzter = function () {
    var b = this.stand.blocks;
    return b.length ? b[b.length - 1] : null;
  };

  Kopf.prototype.zeigen = function (i, vonHand) {
    var ich = this;
    if (vonHand) {
      this.blick = Date.now();
      // **Die Uhr fängt von vorn an.** Sonst springt die Anzeige gleich nach
      // dem Klick weiter, und der gewählte Reiter steht eine Sekunde da.
      if (this.uhrwerk) {
        window.clearInterval(this.uhrwerk);
        this.uhrwerk = window.setInterval(function () { ich.weiter(); }, WECHSEL_MS);
      }
    }
    this.seite = i;
    for (var k = 0; k < this.seiten.length; k++) {
      var aktiv = k === i, s = this.seiten[k], b = this.knoepfe[k];
      s.wurzel.style.display = aktiv ? "block" : "none";
      b.style.color = aktiv ? TEXT : DIM;
      b.style.fontWeight = aktiv ? "700" : "400";
      b.style.borderBottomColor = aktiv ? ORANGE : "transparent";
      if (aktiv && s.sichtbar) s.sichtbar(this.stand);
      if (aktiv && s.auffrischen) s.auffrischen(this.stand);
      if (!aktiv && s.verdeckt) s.verdeckt();
    }
  };

  Kopf.prototype.weiter = function () {
    if (document.hidden) return;
    this.zeigen((this.seite + 1) % this.seiten.length, false);
  };

  Kopf.prototype.auffrischen = function () {
    if (!this.laeuft) return;
    var s = this.seiten[this.seite];
    if (s.auffrischen) s.auffrischen(this.stand);
    if (Date.now() - this.blick > STILL_NACH_MS) this.anhalten();
  };

  Kopf.prototype.anhalten = function () {
    if (this.ws) { try { this.ws.close(); } catch (e) {} this.ws = null; }
    this.seiten.forEach(function (s) { if (s.anhalten) s.anhalten(); });
  };

  Kopf.prototype.wecken = function () {
    this.blick = Date.now();
    if (!this.ws) this.verbinden();
    if (this.laeuft) this.zeigen(this.seite, false);
  };

  Kopf.prototype.verbinden = function () {
    var ich = this;
    try { this.ws = new WebSocket(WS_URL); } catch (e) { return; }
    this.ws.onopen = function () {
      ich.ws.send(JSON.stringify({ action: "want", data: ["blocks", "stats", "mempool-blocks"] }));
      ich.ws.send(JSON.stringify({ action: "init" }));
      // Der nächste Block mit seinen Transaktionen: füllt die Halde im Feed
      // und die Kachelgrafik im Explorer.
      ich.ws.send(JSON.stringify({ "track-mempool-block": 0 }));
    };
    this.ws.onmessage = function (ev) {
      var m;
      try { m = JSON.parse(ev.data); } catch (e) { return; }
      var st = ich.stand;
      if (m.blocks && m.blocks.length) st.blocks = m.blocks.slice(-8);
      if (m.block) {
        st.blocks = st.blocks.concat([m.block]).slice(-8);
        ich.seiten[0].neuerBlock(m.block);
        if (ich.laeuft) ich.blockInhalt();
      }
      if (m["mempool-blocks"]) st.mbloecke = m["mempool-blocks"];
      if (m.fees) st.fees = m.fees;
      if (m.mempoolInfo) st.info = m.mempoolInfo;
      if (m.da) st.da = m.da;
      var p = m["projected-block-transactions"];
      if (p) ich.naechster(p);
      if (m.transactions && m.transactions.length) {
        ich.seiten[0].zulauf(m.transactions);
        if (!ich.laeuft) ich.losgehen();
      }
      if (ich.laeuft) {
        var s = ich.seiten[ich.seite];
        if (s.auffrischen) s.auffrischen(st);
      }
    };
    this.ws.onclose = function () {
      ich.ws = null;
      if (Date.now() - ich.blick < STILL_NACH_MS) window.setTimeout(function () { ich.verbinden(); }, 8000);
    };
    this.ws.onerror = function () { try { ich.ws.close(); } catch (e) {} };
  };

  // [txid, fee, vsize, value, rate, flags, time]; erst alle, dann Änderungen.
  Kopf.prototype.naechster = function (p) {
    var n = this.stand.naechster;
    if (p.blockTransactions) {
      n = this.stand.naechster = {};
      p.blockTransactions.forEach(function (x) { n[x[0]] = x; });
      this.seiten[0].vorfuellen(p.blockTransactions);
    } else if (p.delta) {
      (p.delta.removed || []).forEach(function (id) { delete n[id]; });
      (p.delta.added || []).forEach(function (x) { n[x[0]] = x; });
    }
    this.seiten[3].neuPacken = true;
  };

  // ================================================================ Feed
  // Wie FeedPanel.qml: oben der Kopf, links der letzte Block, rechts die
  // Legende, in der Mitte der letzte Block als Kacheln, unten die Halde.
  // Zelle 6 px: Kachel 4 px, Fuge je 1 px, wie `zelleDev` in FeedCanvas.qml.
  var HALDE_Y = 678, HALDE_UNTEN = 760, ZELLE = 6, HALDE_X = 14;
  var FALL_G = (HALDE_UNTEN - 80) * 1.1;
  var SPALTEN = Math.floor((B - 2 * HALDE_X) / ZELLE), ZEILEN = Math.floor((HALDE_UNTEN - HALDE_Y) / ZELLE);
  function Feed() {
    this.halde = [];
    this.fallend = [];
    this.schlange = [];
    this.lauf = 0;
    this.block = null;
    this.lage = new window.MondrianLayout(SPALTEN);
  }
  Feed.prototype.aufbauen = function (w) {
    this.c = leinwand(w, 0, 0, B, H);
    var kopf = an(w, el("div", "position:absolute;left:6px;top:30px;width:1268px;height:46px;border:1px solid " + LINIE + ";border-radius:6px;box-sizing:border-box;"));
    var li = an(kopf, el("div", "position:absolute;left:8px;top:4px;"));
    var z1 = an(li, el("div", "font-size:16px;font-weight:700;"));
    an(z1, el("span", "display:inline-block;width:7px;height:7px;border-radius:4px;background:" + GRUEN + ";margin-right:6px;vertical-align:middle;"));
    this.kHoehe = an(z1, el("span", ""));
    this.kVor = an(li, el("div", "font-size:12px;color:" + DIM + ";"));
    var re = an(kopf, el("div", "position:absolute;right:8px;top:4px;text-align:right;"));
    this.kMempool = an(re, el("div", "font-size:13px;"));
    this.kRate = an(re, el("div", "font-size:12px;color:" + ORANGE + ";"));

    var links = an(w, el("div", "position:absolute;left:6px;top:133px;width:176px;border:1px solid " + LINIE + ";border-radius:6px;box-sizing:border-box;padding:7px 8px;font-size:12px;color:" + DIM + ";"));
    an(links, el("div", "font-size:13px;", t("lastBlock")));
    this.lHoehe = an(links, el("div", "font-size:20px;font-weight:700;color:" + TEXT + ";"));
    this.lDatum = an(links, el("div", "font-size:11px;margin-bottom:6px;white-space:pre;"));
    an(links, el("div", "", t("feed.movedValue")));
    this.lWert = an(links, el("div", "font-size:13px;color:" + TEXT + ";"));
    this.lFiat = an(links, el("div", "font-size:11px;margin-bottom:6px;"));
    this.lBytes = an(links, el("div", ""));
    this.lTx = an(links, el("div", "margin-bottom:6px;"));
    an(links, el("div", "", t("feed.avgFee")));
    this.lFee = an(links, el("div", "font-size:13px;color:" + TEXT + ";margin-bottom:6px;"));
    this.lPool = an(links, el("div", "font-size:11px;"));

    var leg = an(w, el("div", "position:absolute;right:7px;top:133px;width:140px;border:1px solid " + LINIE + ";border-radius:6px;box-sizing:border-box;padding:7px 8px;font-size:11px;color:" + DIM + ";text-align:right;"));
    an(leg, el("div", "font-size:12px;margin-bottom:4px;", t("feed.sizeValue")));
    [["0.01", 3], ["0.1", 6], ["1", 9], ["10", 12], ["100", 18]].forEach(function (z) {
      var r = an(leg, el("div", "display:flex;justify-content:flex-end;align-items:center;gap:8px;height:24px;font-family:'Noto Sans Mono',monospace;"));
      an(r, el("span", "", "< ₿ " + z[0]));
      var box = an(r, el("span", "display:inline-flex;width:18px;justify-content:center;"));
      an(box, el("span", "display:inline-block;width:" + z[1] + "px;height:" + z[1] + "px;background:" + ORANGE + ";"));
    });
    an(leg, el("div", "font-size:12px;margin-top:6px;", t("feed.ageScale")));
    var skala = an(leg, el("div", "display:flex;align-items:center;gap:5px;justify-content:flex-end;margin-top:3px;"));
    an(skala, el("span", "", "0"));
    var stufen = [];
    for (var i = 0; i <= 10; i++) stufen.push(window.ageColor(i * 6000) + " " + (i * 10) + "%");
    an(skala, el("span", "display:inline-block;width:90px;height:7px;background:linear-gradient(90deg," + stufen.join(",") + ");"));
    an(skala, el("span", "", "60+"));

    var farbe = an(w, el("div", "position:absolute;right:7px;top:332px;border:1px solid " + LINIE + ";border-radius:6px;padding:5px 8px;font-size:11px;color:" + DIM + ";display:flex;gap:10px;align-items:center;"));
    an(farbe, el("span", "", t("color.label")));
    [t("color.age"), t("color.fee"), t("color.type")].forEach(function (n, j) {
      an(farbe, el("span", "border:1px solid " + (j === 0 ? "#b06a17" : "#29292f") + ";border-radius:10px;padding:1px 8px;" + (j === 0 ? "color:" + TEXT + ";background:#29292f;" : ""), n));
    });

    this.mZeile = an(w, el("div", "position:absolute;left:14px;top:655px;font-size:12px;color:" + DIM + ";"));
    an(w, el("div", "position:absolute;left:14px;right:14px;top:673px;border-top:1px dashed #74707f;"));
    this.fLinks = an(w, el("div", "position:absolute;left:14px;top:764px;font-size:11px;color:" + DIM + ";white-space:pre;"));
    this.fRechts = an(w, el("div", "position:absolute;right:14px;top:764px;font-size:11px;color:" + DIM + ";"));
  };
  Feed.prototype.auffrischen = function (st) {
    var b = st.blocks.length ? st.blocks[st.blocks.length - 1] : null;
    if (b) {
      var x = b.extras || {}, wert = (x.totalOutputAmt || 0) / 1e8;
      this.kHoehe.textContent = t("block") + " " + zahl(b.height);
      this.kVor.textContent = vor(b.timestamp);
      this.lHoehe.textContent = zahl(b.height);
      this.lDatum.textContent = datum(b.timestamp);
      this.lWert.textContent = "₿ " + zahl(wert, 4);
      this.lFiat.textContent = st.preis ? "≈ " + gross(wert * st.preis, "") + " $" : "";
      this.lBytes.textContent = t("feed.bytes", zahl(b.size || 0));
      this.lTx.textContent = t("txlist.count", zahl(b.tx_count || 0));
      // avgFeeRate kommt gerundet; unter 1 sat/vB stünde dort 0.
      var vb = (b.weight || 0) / 4;
      this.lFee.textContent = zahl(vb ? (x.totalFees || 0) / vb : (x.avgFeeRate || 0), 2) + " sat/vByte";
      this.lPool.textContent = x.pool ? x.pool.name : "";
    }
    if (st.info) {
      this.kMempool.textContent = t("feed.inMempool", zahl(st.info.size));
      this.mZeile.textContent = t("feed.mempoolLine", zahl(st.info.size));
    }
    if (st.fees) this.kRate.textContent = zahl(st.fees.fastestFee, 2) + " sat/vB";
    var n = st.mbloecke[0];
    if (n) this.fLinks.textContent = t("feed.nextBlockLine", zahl(n.nTx), zahl(n.medianFee, 2));
    if (st.preis) this.fRechts.textContent = "₿ " + zahl(st.preis) + " $";
  };
  // Der letzte Block als Kacheln, orange wie in der Anwendung. Die Fläche
  // bleibt gleich groß (`blockSide` in FeedCanvas.qml), ein voller Block
  // bekommt nur kleinere Zellen.
  Feed.prototype.blockNeu = function (st) {
    var txs = st.summe ? st.summe.txs : [];
    if (!txs.length) return;
    var groessen = txs.map(function (x) { return window.txSize(x.value, 5); });
    var flaeche = groessen.reduce(function (a, r) { return a + r * r; }, 0);
    var spalten = Math.max(8, Math.ceil(Math.sqrt(flaeche * 1.08)));
    var lage = new window.MondrianLayout(spalten), teile = [], hoehe = 0;
    groessen.forEach(function (r) {
      var p = lage.place(r);
      teile.push(p);
      hoehe = Math.max(hoehe, p.y + p.r);
    });
    var seite = 236, z = seite / Math.max(spalten, hoehe);
    this.block = { teile: teile, z: z, x: Math.round(640 - spalten * z / 2), unten: Math.round(302 + hoehe * z / 2) };
  };
  Feed.prototype.vorfuellen = function (liste) {
    if (this.halde.length) return;
    var jetzt = Date.now();
    var alt = liste.slice().sort(function (a, b) { return (a[6] || 0) - (b[6] || 0); });
    for (var i = 0; i < alt.length; i++) {
      var r = window.txSize(alt[i][3], 5);
      var p = this.lage.place(r);
      if (p.y + r > ZEILEN - 1) { this.lage = this.neuGepackt(); break; }
      p.t = alt[i][6] ? alt[i][6] * 1000 : jetzt - 600000;
      this.halde.push(p);
    }
  };
  Feed.prototype.neuGepackt = function () {
    var lage = new window.MondrianLayout(SPALTEN);
    for (var i = 0; i < this.halde.length; i++) {
      var a = this.halde[i], n = lage.place(a.r);
      n.t = a.t; this.halde[i] = n;
    }
    return lage;
  };
  // **Regen statt Schauer.** mempool.space liefert neue Transaktionen als
  // Paket, alle ein bis zwei Sekunden. Wie `drainQueue()` in FeedCanvas.qml
  // fallen sie einzeln, verteilt über den Abstand bis zum nächsten Paket.
  // Gemessen wird dieser Abstand hier, statt ihn anzunehmen.
  Feed.prototype.zulauf = function (txs) {
    var jetzt = Date.now();
    if (this.zuletzt) {
      var d = Math.min(5000, Math.max(300, jetzt - this.zuletzt));
      this.abstand = this.abstand ? this.abstand * 0.7 + d * 0.3 : d;
    }
    this.zuletzt = jetzt;
    // Was niemand sieht, wird nicht gesammelt; sonst fiele beim Zurückkehren
    // alles auf einmal. Und höchstens zwei Pakete Rückstand, wie `queueMax`.
    if (!this.lauf) return;
    for (var i = 0; i < txs.length; i++)
      this.schlange.push({ r: window.txSize(txs[i].value, 5), t: jetzt });
    if (this.schlange.length > 40) this.schlange.splice(0, this.schlange.length - 40);
  };
  Feed.prototype.neuerBlock = function () {
    // Welche Transaktionen bestätigt wurden, nennt der Strom nicht mit. Die
    // Halde gibt von unten ab, die ältesten zuerst.
    this.halde.splice(0, Math.ceil(this.halde.length * 0.4));
    this.fallend.length = 0;
    this.lage = this.neuGepackt();
    this.blitz = 1;
  };
  Feed.prototype.sichtbar = function () {
    var ich = this;
    if (!this.lauf) this.lauf = window.requestAnimationFrame(function () { ich.bild(); });
  };
  Feed.prototype.verdeckt = Feed.prototype.anhalten = function () {
    if (this.lauf) { window.cancelAnimationFrame(this.lauf); this.lauf = 0; }
    this.schlange.length = 0;
    this.vorher = 0;
    // Was gerade fällt, landet sofort; sonst hinge es unsichtbar in der Luft.
    this.fallend.forEach(function (f) { f.s.faellt = false; });
    this.fallend.length = 0;
  };
  Feed.prototype.bild = function () {
    var ich = this;
    this.lauf = window.requestAnimationFrame(function () { ich.bild(); });
    var c = vorbereiten(this.c, this.kopf.k), jetzt = Date.now(), z = ZELLE;
    var dt = this.vorher ? Math.min(0.1, (jetzt - this.vorher) / 1000) : 0;
    this.vorher = jetzt;
    if (!this.schlange.length) this.guthaben = 0;
    else this.guthaben = (this.guthaben || 0) + this.schlange.length / ((this.abstand || 1000) * 0.85 / 1000) * dt;
    while (this.guthaben >= 1 && this.schlange.length) {
      this.guthaben -= 1;
      var q = this.schlange.shift();
      var p = this.lage.place(q.r);
      if (p.y + q.r > ZEILEN) {
        this.halde.splice(0, Math.ceil(this.halde.length * 0.3));
        this.lage = this.neuGepackt();
        p = this.lage.place(q.r);
      }
      p.t = q.t; p.faellt = true;
      this.halde.push(p);
      // Start über der Fläche, wie `fromY` in FeedCanvas.qml
      this.fallend.push({ x: HALDE_X + p.x * z, r: q.r * z, ziel: HALDE_UNTEN - (p.y + q.r) * z,
                          py: 80 - q.r * z - Math.random() * 340, v: 0, t: q.t, s: p });
    }
    c.clearRect(0, 0, B, H);
    var bl = this.block;
    if (bl) {
      var fuge = Math.max(0.35, bl.z / 5);
      c.fillStyle = window.blockAgeColor();
      for (var k = 0; k < bl.teile.length; k++) {
        var tb = bl.teile[k];
        c.fillRect(bl.x + tb.x * bl.z + fuge / 2, bl.unten - (tb.y + tb.r) * bl.z + fuge / 2, tb.r * bl.z - fuge, tb.r * bl.z - fuge);
      }
    }
    for (var i = 0; i < this.halde.length; i++) {
      var s = this.halde[i];
      if (s.faellt) continue;
      c.fillStyle = window.ageColor(jetzt - (s.t || jetzt));
      c.fillRect(HALDE_X + s.x * z + 1, HALDE_UNTEN - (s.y + s.r) * z + 1, s.r * z - 2, s.r * z - 2);
    }
    for (var j = this.fallend.length - 1; j >= 0; j--) {
      var f = this.fallend[j];
      // Schwerkraft `height * 1.1` pro s², wie `step()` in FeedCanvas.qml
      f.v += FALL_G * dt; f.py += f.v * dt;
      if (f.py >= f.ziel) { f.py = f.ziel; f.s.faellt = false; this.fallend.splice(j, 1); }
      if (f.py + f.r < 80) continue;
      c.fillStyle = window.ageColor(jetzt - f.t);
      c.fillRect(f.x + 1, f.py + 1, f.r - 2, f.r - 2);
    }
    if (this.blitz > 0) {
      this.blitz = Math.max(0, this.blitz - 0.02);
      c.fillStyle = "rgba(247,147,26," + (0.7 * this.blitz).toFixed(3) + ")";
      c.fillRect(0, 0, B, 2);
    }
  };

  // ================================================================= Uhr
  // Wie ClockView.qml
  function Uhr() {}
  Uhr.prototype.aufbauen = function (w) {
    an(w, el("div", "position:absolute;left:0;right:0;top:158px;text-align:center;font-size:38px;letter-spacing:3.5px;color:" + DIM + ";", t("blockHeight")));
    this.hoehe = an(w, el("div", "position:absolute;left:0;right:0;top:216px;text-align:center;font-size:124px;font-weight:700;color:" + ORANGE + ";line-height:1.1;letter-spacing:1px;"));
    var reihe = an(w, el("div", "position:absolute;left:102px;right:102px;top:412px;display:flex;justify-content:space-between;text-align:center;"));
    this.felder = {};
    var ich = this;
    [["fee", "fee"], ["price", "price"], ["clock.moscow", "moscow"], ["mempool", "mempool"], ["hashrate", "hashrate"]].forEach(function (p) {
      var f = an(reihe, el("div", ""));
      an(f, el("div", "font-size:24px;color:" + DIM + ";", t(p[0])));
      ich.felder[p[1]] = an(f, el("div", "font-size:37px;color:" + TEXT + ";"));
    });
    this.diff = an(w, el("div", "position:absolute;left:102px;top:558px;font-size:28px;color:" + DIM + ";"));
    this.rest = an(w, el("div", "position:absolute;left:681px;top:558px;font-size:28px;color:" + DIM + ";"));
    var balken = an(w, el("div", "position:absolute;left:102px;width:1076px;top:607px;height:7px;border-radius:4px;background:#1e1e25;overflow:hidden;"));
    this.fuell = an(balken, el("div", "height:100%;width:0;background:" + ORANGE + ";border-radius:4px;"));
    this.halving = an(w, el("div", "position:absolute;left:102px;top:622px;font-size:28px;color:" + DIM + ";"));
  };
  Uhr.prototype.auffrischen = function (st) {
    var b = st.blocks.length ? st.blocks[st.blocks.length - 1] : null;
    if (b) this.hoehe.textContent = zahl(b.height);
    if (st.fees) this.felder.fee.textContent = gebuehr(st.fees.halfHourFee) + " sat/vB";
    if (st.preis) {
      this.felder.price.textContent = zahl(st.preis) + " $";
      this.felder.moscow.textContent = zahl(1e8 / st.preis) + " sat";
    }
    if (st.info) this.felder.mempool.textContent = zahl(st.info.size);
    if (st.netz) this.felder.hashrate.textContent = gross(st.netz.currentHashrate, "H/s");
    if (st.da) {
      var d = st.da;
      this.diff.textContent = t("clock.diffLine", (d.difficultyChange >= 0 ? "+" : "") + zahl(d.difficultyChange, 2) + " %");
      this.rest.textContent = t("clock.remaining", zahl(d.remainingBlocks), dauer(d.remainingTime));
      this.fuell.style.width = Math.max(1, d.progressPercent).toFixed(1) + "%";
    }
    if (b) {
      var bis = HALVING - b.height;
      this.halving.textContent = t("clock.halving", zahl(HALVING), zahl(bis), dauer(bis * 600000));
    }
  };

  // ============================================================== Mining
  // Wie NetworkView.qml und NetworkChart.qml, die Seite "Netz". Das Gerät
  // steht im Heimnetz des Besuchers und ist von hier nicht erreichbar.
  function Mining() {}
  Mining.prototype.aufbauen = function (w) {
    var pillen = an(w, el("div", "position:absolute;left:0;right:0;top:37px;display:flex;justify-content:center;gap:26px;font-size:22px;"));
    an(pillen, el("span", "border:1px solid #29292f;border-radius:21px;padding:4px 18px;color:" + DIM + ";", t("miner.paneDevice")));
    an(pillen, el("span", "border:1px solid #b06a17;background:#29292f;border-radius:21px;padding:4px 18px;color:" + TEXT + ";", t("miner.paneNet")));
    var raster = [[256, 114, "hashrate", "rate"], [640, 114, "difficulty", "diff"], [1023, 114, "net.nextAdj", "anp"],
                  [256, 250, "net.blockTime", "zeit"], [640, 250, "net.lastBlock", "letzter"]];
    this.w = {};
    var ich = this;
    raster.forEach(function (r) {
      var box = an(w, el("div", "position:absolute;left:" + (r[0] - 200) + "px;width:400px;top:" + r[1] + "px;text-align:center;"));
      an(box, el("div", "font-size:24px;color:" + DIM + ";", t(r[2])));
      ich.w[r[3]] = an(box, el("div", "font-size:38px;font-weight:700;line-height:1.2;color:" + (r[3] === "rate" ? ORANGE : TEXT) + ";"));
      ich.w[r[3] + "Unter"] = an(box, el("div", "font-size:21px;color:" + DIM + ";"));
    });
    var kopf = an(w, el("div", "position:absolute;left:78px;top:394px;font-size:22px;"));
    an(kopf, el("span", "color:" + ORANGE + ";font-weight:600;", t("hashrate")));
    this.wandel = an(kopf, el("span", "font-size:21px;margin-left:11px;"));
    an(kopf, el("span", "font-size:21px;margin-left:11px;color:" + TEXT + ";", "· " + t("difficulty")));
    var wahl = an(w, el("div", "position:absolute;right:77px;top:395px;display:flex;gap:22px;font-size:18px;color:" + DIM + ";"));
    ["30d", "90d", "1y", "3y", "Max"].forEach(function (n) {
      an(wahl, el("span", "border:1px solid " + (n === "1y" ? "#b06a17" : "#29292f") + ";border-radius:16px;padding:2px 13px;" + (n === "1y" ? "background:#29292f;color:" + TEXT + ";" : ""), n));
    });
    this.c = leinwand(w, 70, 440, 1140, 330);
  };
  Mining.prototype.auffrischen = function (st) {
    var d = st.da, b = st.blocks.length ? st.blocks[st.blocks.length - 1] : null;
    if (st.netz) {
      this.w.rate.textContent = gross(st.netz.currentHashrate, "H/s");
      this.w.diff.textContent = gross(st.netz.currentDifficulty, "");
    }
    if (d) {
      this.w.anp.textContent = (d.difficultyChange >= 0 ? "+" : "−") + zahl(Math.abs(d.difficultyChange), 2) + " %";
      this.w.anpUnter.textContent = t("clock.remaining", zahl(d.remainingBlocks), dauer(d.remainingTime));
      var s = Math.round(d.timeAvg / 1000);
      this.w.zeit.textContent = t("duration.min", Math.floor(s / 60) + ":" + z2(s % 60));
    }
    if (b) {
      var m = Math.floor(Math.max(0, Date.now() / 1000 - b.timestamp) / 60);
      this.w.letzter.textContent = m < 1 ? t("net.justNow") : t("ago.min", m);
      this.w.letzterUnter.textContent = b.extras && b.extras.pool ? b.extras.pool.name : "";
    }
    this.zeichnen(st);
  };
  Mining.prototype.zeichnen = function (st) {
    if (!st.netz || !st.netz.hashrates || st.netz.hashrates.length < 2) return;
    var c = vorbereiten(this.c, this.kopf.k), W = this.c.lw, Hh = this.c.lh;
    var FAKTOR = 4294967296 / 600, FENSTER = 3.5 * 86400;
    var r = st.netz.hashrates.map(function (x) { return [x.timestamp, x.avgHashrate]; });
    if (!this.mittel || this.mittelVon !== r.length) {
      this.mittel = r.map(function (p) {
        var s = 0, n = 0;
        for (var i = 0; i < r.length; i++) if (Math.abs(r[i][0] - p[0]) <= FENSTER) { s += r[i][1]; n++; }
        return [p[0], s / n];
      });
      this.mittelVon = r.length;
    }
    var mittel = this.mittel, t0 = r[0][0];
    var diffs = (st.netz.difficulty || []).map(function (x) { return [x.time, x.difficulty * FAKTOR, x.adjustment]; });
    var treppe = [];
    if (diffs.length) {
      var anfang = diffs[0][1] / (diffs[0][2] || 1);
      treppe.push([t0, anfang]);
      diffs.forEach(function (x) { if (x[0] > t0) treppe.push([x[0], x[1]]); });
    }
    var tEnde = Math.max(r[r.length - 1][0], treppe.length ? treppe[treppe.length - 1][0] : 0);
    var min = Infinity, max = -Infinity;
    r.concat(treppe).forEach(function (p) { min = Math.min(min, p[1]); max = Math.max(max, p[1]); });
    var padL = 117, padR = 66, padT = 21, unten = Hh - 53;
    function xb(tt) { return padL + (tt - t0) / (tEnde - t0) * (W - padL - padR); }
    function yb(v) { return unten - (v - min) / (max - min) * (unten - padT); }
    c.clearRect(0, 0, W, Hh);
    var wd = (mittel[mittel.length - 1][1] - mittel[0][1]) / mittel[0][1] * 100;
    this.wandel.textContent = (wd >= 0 ? "+" : "−") + zahl(Math.abs(wd), Math.abs(wd) >= 100 ? 0 : 1) + " %";
    this.wandel.style.color = wd >= 0 ? GRUEN : ROT;
    // Zwischenlinien an runden Werten, beschriftet links
    c.font = "19px 'Noto Sans', sans-serif";
    var schritt = Math.pow(10, Math.floor(Math.log(max - min) / Math.LN10));
    if ((max - min) / schritt < 3) schritt /= 2;
    while ((max - min) / schritt > 4) schritt *= 2;
    c.strokeStyle = "#1d1d26"; c.fillStyle = "#6f6a7a"; c.lineWidth = 1;
    for (var v = Math.ceil(min / schritt) * schritt; v < max; v += schritt) {
      var y = Math.round(yb(v)) + 0.5;
      if (y - padT < 30 || unten - y < 30) continue;
      c.beginPath(); c.moveTo(padL, y); c.lineTo(W - padR, y); c.stroke();
      c.fillText(gross(v, "H/s"), 7, y + 6);
    }
    c.strokeStyle = "#2a2a38";
    c.beginPath(); c.moveTo(padL, padT + 0.5); c.lineTo(W - padR, padT + 0.5);
    c.moveTo(padL, unten - 0.5); c.lineTo(W - padR, unten - 0.5); c.stroke();
    c.strokeStyle = "rgba(247,147,26,0.3)"; c.lineWidth = 1;
    c.beginPath();
    r.forEach(function (p, i) { i ? c.lineTo(xb(p[0]), yb(p[1])) : c.moveTo(xb(p[0]), yb(p[1])); });
    c.stroke();
    var g = c.createLinearGradient(0, padT, 0, unten);
    g.addColorStop(0, "rgba(247,147,26,0.28)"); g.addColorStop(1, "rgba(247,147,26,0)");
    c.fillStyle = g;
    c.beginPath(); c.moveTo(xb(mittel[0][0]), unten);
    mittel.forEach(function (p) { c.lineTo(xb(p[0]), yb(p[1])); });
    c.lineTo(xb(mittel[mittel.length - 1][0]), unten); c.closePath(); c.fill();
    c.strokeStyle = ORANGE; c.lineWidth = 2; c.lineJoin = "round";
    c.beginPath();
    mittel.forEach(function (p, i) { i ? c.lineTo(xb(p[0]), yb(p[1])) : c.moveTo(xb(p[0]), yb(p[1])); });
    c.stroke();
    if (treppe.length) {
      c.strokeStyle = "rgba(200,192,200,0.8)"; c.lineWidth = 1.3; c.lineJoin = "miter";
      c.beginPath(); c.moveTo(xb(treppe[0][0]), yb(treppe[0][1]));
      for (var s = 1; s < treppe.length; s++) {
        c.lineTo(xb(treppe[s][0]), yb(treppe[s - 1][1]));
        c.lineTo(xb(treppe[s][0]), yb(treppe[s][1]));
      }
      c.lineTo(W - padR, yb(treppe[treppe.length - 1][1])); c.stroke();
    }
    c.font = "20px 'Noto Sans', sans-serif";
    c.fillStyle = ORANGE; c.textAlign = "left";
    c.fillText(gross(max, "H/s"), 7, padT + 14);
    c.fillText(gross(min, "H/s"), 7, unten - 2);
    c.fillStyle = TEXT; c.textAlign = "right";
    c.fillText(gross(max / FAKTOR, ""), W - 7, padT + 14);
    c.fillText(gross(min / FAKTOR, ""), W - 7, unten - 2);
    c.fillStyle = DIM;
    c.textAlign = "left"; c.fillText(tag(t0), padL, Hh - 14);
    c.textAlign = "right"; c.fillText(tag(tEnde), W - padR, Hh - 14);
    c.textAlign = "left";
  };

  // ============================================================ Explorer
  // Wie ExplorerHome.qml und BlockChain.qml
  var KARTE = 134, LUECKE = 9, TRENNER = 516;
  function Explorer() { this.neuPacken = true; }
  Explorer.prototype.aufbauen = function (w) {
    an(w, el("div", "position:absolute;left:14px;right:14px;top:40px;height:33px;box-sizing:border-box;border:1px solid #c57a1c;border-radius:17px;background:#191920;padding:5px 15px;font-size:16px;color:" + DIM + ";", t("search.placeholder")));
    var reihe = an(w, el("div", "position:absolute;left:14px;top:95px;display:flex;gap:27px;"));
    this.werte = {};
    var ich = this;
    [["blockHeight", "hoehe"], ["explorer.inMempool", "mempool"], ["fee", "fee"], ["hashrate", "rate"], ["difficulty", "diff"], ["price", "preis"]].forEach(function (p) {
      var f = an(reihe, el("div", ""));
      an(f, el("div", "font-size:13px;color:" + DIM + ";", t(p[0])));
      ich.werte[p[1]] = an(f, el("div", "font-size:19px;"));
    });
    an(w, el("div", "position:absolute;left:14px;top:151px;font-size:13px;color:" + DIM + ";white-space:pre;", t("chain.label")));
    this.kette = an(w, el("div", "position:absolute;left:14px;right:14px;top:170px;height:170px;overflow:hidden;"));
    an(w, el("div", "position:absolute;left:" + TRENNER + "px;top:200px;height:150px;border-left:1px solid #37373d;"));
    an(w, el("div", "position:absolute;left:14px;top:375px;font-size:13px;color:" + DIM + ";", t("explorer.browseAll")));
    var nb = an(w, el("div", "position:absolute;left:14px;top:409px;font-size:17px;"));
    an(nb, el("span", "", t("nextBlock")));
    an(nb, el("span", "display:inline-block;width:6px;height:6px;border-radius:3px;background:" + GRUEN + ";margin:0 7px 2px 9px;vertical-align:middle;"));
    this.nbZeile = an(nb, el("span", "font-size:13px;color:" + DIM + ";"));
    an(w, el("div", "position:absolute;left:14px;top:435px;font-size:13px;color:" + DIM + ";", t("proj.unchanged")));
    var farbe = an(w, el("div", "position:absolute;left:14px;top:458px;font-size:13px;color:" + DIM + ";display:flex;gap:12px;align-items:center;"));
    an(farbe, el("span", "", t("color.label")));
    an(farbe, el("span", "border:1px solid #b06a17;background:#29292f;color:" + TEXT + ";border-radius:11px;padding:1px 10px;", t("color.fee")));
    an(farbe, el("span", "border:1px solid #29292f;border-radius:11px;padding:1px 10px;", t("color.type")));
    this.c = leinwand(w, 424, 527, 434, 273);
  };
  Explorer.prototype.karten = function (st) {
    var k = this.kette;
    k.textContent = "";
    var links = TRENNER - 14 - 20;
    st.mbloecke.slice(0, 4).forEach(function (m, i) {
      var x = links - KARTE - i * (KARTE + LUECKE);
      var box = an(k, el("div", "position:absolute;left:" + x + "px;top:0;width:" + KARTE + "px;text-align:center;"));
      an(box, el("div", "font-size:13px;color:" + DIM + ";height:26px;line-height:22px;", t("in.min", (i + 1) * 10)));
      var kt = an(box, el("div", karte(wartend(m.medianFee)) + "height:" + KARTE + "px;display:flex;flex-direction:column;justify-content:center;font-size:11px;color:rgba(255,255,255,0.85);white-space:nowrap;overflow:hidden;"));
      an(kt, el("div", "font-size:16px;font-weight:700;color:#fff;", "~" + gebuehr(m.medianFee) + " sat/vB"));
      var fr = m.feeRange || [];
      an(kt, el("div", "", fr.length ? gebuehr(fr[0]) + " – " + gebuehr(fr[fr.length - 1]) : ""));
      an(kt, el("div", "", t("txlist.count", zahl(m.nTx))));
      an(kt, el("div", "", zahl(m.blockSize / 1e6, 2) + " MB"));
      an(kt, el("div", "", zahl(m.totalFees / 1e8, 3) + " BTC"));
    });
    var rechts = TRENNER - 14 + 21;
    st.blocks.slice().reverse().forEach(function (b, i) {
      var x = rechts + i * (KARTE + LUECKE), e = b.extras || {};
      if (x > B) return;
      var box = an(k, el("div", "position:absolute;left:" + x + "px;top:0;width:" + KARTE + "px;text-align:center;"));
      an(box, el("div", "font-size:15px;font-weight:700;color:" + ORANGE + ";height:26px;line-height:26px;", zahl(b.height)));
      var kt = an(box, el("div", karte(LILA) + "height:" + KARTE + "px;display:flex;flex-direction:column;justify-content:center;font-size:11px;color:rgba(255,255,255,0.85);white-space:nowrap;overflow:hidden;"));
      an(kt, el("div", "font-size:12px;", "~" + gebuehr(e.medianFee) + " sat/vB"));
      an(kt, el("div", "font-size:15px;font-weight:700;color:#fff;", zahl((e.reward || 0) / 1e8, 3) + " BTC"));
      an(kt, el("div", "", t("txlist.count", zahl(b.tx_count))));
      an(kt, el("div", "", zahl(b.size / 1e6, 2) + " MB"));
      an(kt, el("div", "", vor(b.timestamp)));
      an(kt, el("div", "color:#fff;", e.pool ? e.pool.name : ""));
    });
  };
  Explorer.prototype.auffrischen = function (st) {
    var b = st.blocks.length ? st.blocks[st.blocks.length - 1] : null;
    if (b) this.werte.hoehe.textContent = zahl(b.height);
    if (st.info) this.werte.mempool.textContent = zahl(st.info.size);
    if (st.fees) this.werte.fee.textContent = gebuehr(st.fees.halfHourFee) + " sat/vB";
    if (st.netz) this.werte.rate.textContent = gross(st.netz.currentHashrate, "H/s");
    if (st.da) this.werte.diff.textContent = zahl(st.da.difficultyChange, 2) + " %";
    if (st.preis) this.werte.preis.textContent = zahl(st.preis) + " $";
    this.karten(st);
    var n = st.mbloecke[0];
    if (n) this.nbZeile.textContent = t("txlist.count", zahl(n.nTx)) + " · ~" + gebuehr(n.medianFee) + " sat/vB";
    this.zeichnen(st);
  };
  // Der nächste Block als Kacheln, nach Gebühr gefärbt, die höchste oben.
  Explorer.prototype.zeichnen = function (st) {
    var ids = Object.keys(st.naechster);
    if (!ids.length) return;
    var c = vorbereiten(this.c, this.kopf.k), z = 9, spalten = Math.floor(this.c.lw / z);
    if (this.neuPacken || !this.teile) {
      var txs = ids.map(function (k) { return st.naechster[k]; });
      txs.sort(function (a, b) { return b[4] - a[4]; });
      var lage = new window.MondrianLayout(spalten);
      this.teile = txs.map(function (x) {
        // Größe nach vBytes wie `txSize()` in FeedCanvas.qml mit sizeMode "vbytes"
        var p = lage.place(Math.min(5, Math.max(1, Math.ceil(Math.sqrt((x[2] || 1) / 256)))));
        p.farbe = window.feeColorForRate(x[4]);
        return p;
      });
      this.neuPacken = false;
    }
    c.clearRect(0, 0, this.c.lw, this.c.lh);
    for (var i = 0; i < this.teile.length; i++) {
      var p = this.teile[i];
      if (p.y * z > this.c.lh) continue;
      c.fillStyle = p.farbe;
      c.fillRect(p.x * z, p.y * z, p.r * z - 1, p.r * z - 1);
    }
  };

  // =============================================================== Markt
  // Wie MarketView.qml und PriceChart.qml, Reiter "Kurs": Kerzen und
  // Volumen über 24 Stunden in 15-Minuten-Kerzen, darunter die Trades.
  function Markt() { this.kerzen = []; this.trades = []; this.anzahl = 0; this.gestartet = false; this.quellen = {}; }
  Markt.prototype.aufbauen = function (w) {
    var kopf = an(w, el("div", "position:absolute;left:14px;top:33px;display:flex;align-items:baseline;gap:19px;font-size:15px;color:" + DIM + ";"));
    an(kopf, el("span", "color:" + TEXT + ";font-weight:700;border-bottom:2px solid " + ORANGE + ";padding-bottom:5px;", t("market.sub.price")));
    an(kopf, el("span", "", t("market.sub.liq")));
    an(kopf, el("span", "", t("market.sub.heat")));
    this.preis = an(kopf, el("span", "font-size:20px;font-weight:700;color:" + TEXT + ";"));
    this.anz = an(kopf, el("span", "font-size:12px;"));
    this.boersen = an(kopf, el("span", "font-size:12px;display:flex;gap:12px;"));
    var rechts = an(w, el("div", "position:absolute;right:14px;top:37px;display:flex;gap:10px;align-items:center;font-size:11px;color:" + DIM + ";"));
    [[t("market.candles"), 1], [t("market.line"), 0], [t("market.volume"), 1], [t("market.cvd"), 0]].forEach(function (p) {
      an(rechts, el("span", "border:1px solid " + (p[1] ? "#b06a17" : "#29292f") + ";border-radius:10px;padding:2px 8px;" + (p[1] ? "background:#292a4e;color:" + TEXT + ";" : ""), p[0]));
    });
    an(rechts, el("span", "border:1px solid #29292f;border-radius:8px;padding:5px 10px;font-size:13px;color:" + TEXT + ";white-space:pre;", t("market.24h") + "  ▾"));
    this.c = leinwand(w, 0, 80, B, 560);
    this.band = an(w, el("div", "position:absolute;left:14px;right:58px;top:643px;font-family:'Noto Sans Mono',monospace;font-size:11px;"));
    this.warte = an(w, el("div", "position:absolute;left:0;right:0;top:330px;text-align:center;font-size:14px;color:" + DIM + ";", t("market.waiting")));
  };
  Markt.prototype.sichtbar = function () {
    if (this.gestartet) return;
    this.gestartet = true;
    var ich = this;
    if (!this.kerzen.length) {
      holen(BINANCE).then(function (d) {
        // [Öffnungszeit, open, high, low, close, volume, ..., taker buy volume (9)]
        ich.kerzen = d.map(function (k) { return { t: k[0], o: +k[1], h: +k[2], l: +k[3], c: +k[4], v: +k[5], kauf: +k[9] }; });
        ich.auffrischen();
      }).catch(function () {});
    }
    this.binance();
    this.bybit();
  };
  Markt.prototype.trade = function (boerse, preis, menge, zeit, kauf) {
    this.quellen[boerse] = true;
    this.anzahl++;
    var k = this.kerzen[this.kerzen.length - 1];
    if (k) {
      if (zeit >= k.t + 900000) {
        k = { t: k.t + 900000, o: preis, h: preis, l: preis, c: preis, v: 0, kauf: 0 };
        this.kerzen.push(k); this.kerzen.shift();
      }
      k.c = preis; k.h = Math.max(k.h, preis); k.l = Math.min(k.l, preis);
      k.v += menge; if (kauf) k.kauf += menge;
    }
    this.letzt = preis;
    // Das Band zeigt Trades ab 1.000 $, wie in der Anwendung.
    if (preis * menge >= 1000) {
      this.trades.unshift({ z: zeit, p: preis, b: boerse, u: preis * menge, kauf: kauf });
      if (this.trades.length > 8) this.trades.length = 8;
    }
  };
  Markt.prototype.binance = function () {
    var ich = this;
    try {
      var ws = new WebSocket(BINANCE_WS);
      ws.onmessage = function (ev) {
        var m = JSON.parse(ev.data);
        ich.trade("binance", +m.p, +m.q, m.T, !m.m);
      };
      this.wsB = ws;
    } catch (e) {}
  };
  Markt.prototype.bybit = function () {
    var ich = this;
    try {
      var ws = new WebSocket(BYBIT_WS);
      ws.onopen = function () { ws.send(JSON.stringify({ op: "subscribe", args: ["publicTrade.BTCUSDT"] })); };
      ws.onmessage = function (ev) {
        var m = JSON.parse(ev.data);
        (m.data || []).forEach(function (x) { ich.trade("bybit", +x.p, +x.v, x.T, x.S === "Buy"); });
      };
      this.wsY = ws;
    } catch (e) {}
  };
  Markt.prototype.anhalten = function () {
    [this.wsB, this.wsY].forEach(function (w) { try { if (w) w.close(); } catch (e) {} });
    this.wsB = this.wsY = null;
    this.gestartet = false;
  };
  Markt.prototype.auffrischen = function () {
    if (!this.kerzen.length) return;
    this.warte.style.display = "none";
    var letzt = this.letzt || this.kerzen[this.kerzen.length - 1].c;
    this.preis.textContent = zahl(letzt) + " $";
    this.anz.textContent = this.anzahl ? t("market.trades", zahl(this.anzahl)) : "";
    var ich = this;
    this.boersen.textContent = "";
    Object.keys(this.quellen).forEach(function (q) {
      var s = an(ich.boersen, el("span", ""));
      an(s, el("span", "color:" + GRUEN + ";margin-right:4px;", "●"));
      an(s, el("span", "", q.charAt(0).toUpperCase() + q.slice(1)));
    });
    this.zeichnen();
    this.bandFuellen();
  };
  Markt.prototype.zeichnen = function () {
    var c = vorbereiten(this.c, this.kopf.k), K = this.kerzen;
    var links = 14, rechts = 1222, oben = 8, kursUnten = 388, volUnten = 523;
    var min = Infinity, max = -Infinity, vmax = 0;
    K.forEach(function (k) { min = Math.min(min, k.l); max = Math.max(max, k.h); vmax = Math.max(vmax, k.v); });
    var breite = (rechts - links) / K.length;
    function y(p) { return oben + (max - p) / (max - min) * (kursUnten - oben); }
    c.clearRect(0, 0, B, 560);
    c.strokeStyle = "#292936"; c.lineWidth = 1; c.fillStyle = DIM; c.font = "11px 'Noto Sans', sans-serif";
    for (var i = 0; i < 5; i++) {
      var p = max - (max - min) * i / 4, yy = Math.round(y(p)) + 0.5;
      c.beginPath(); c.moveTo(links, yy); c.lineTo(rechts, yy); c.stroke();
      c.fillText(zahl(p), rechts + 4, yy + 4);
    }
    K.forEach(function (k, j) {
      var x = links + j * breite, m = Math.round(x + breite / 2) + 0.5, auf = k.c >= k.o;
      c.strokeStyle = c.fillStyle = auf ? GRUEN : ROT;
      c.beginPath(); c.moveTo(m, y(k.h)); c.lineTo(m, y(k.l)); c.stroke();
      var y1 = y(Math.max(k.o, k.c)), y2 = y(Math.min(k.o, k.c));
      c.fillRect(x + breite * 0.15, y1, breite * 0.7, Math.max(1, y2 - y1));
      // Volumen: unten Kauf (grün), darüber Verkauf (rot)
      var hv = k.v / vmax * (volUnten - kursUnten - 10), hk = k.kauf / vmax * (volUnten - kursUnten - 10);
      c.fillStyle = ROT; c.fillRect(x + breite * 0.1, volUnten - hv, breite * 0.8, hv - hk);
      c.fillStyle = GRUEN; c.fillRect(x + breite * 0.1, volUnten - hk, breite * 0.8, hk);
    });
    function hm(ms) { var d = new Date(ms); return z2(d.getHours()) + ":" + z2(d.getMinutes()); }
    c.fillStyle = DIM; c.textAlign = "left"; c.fillText(hm(K[0].t), links, 540);
    c.textAlign = "right"; c.fillText(hm(K[K.length - 1].t), rechts, 540);
    c.textAlign = "left";
    c.fillStyle = "#3a3a44"; c.fillRect(links, 551, rechts - links, 3);
    c.fillStyle = "#c9c4cf"; c.beginPath(); c.arc(rechts - 6, 552.5, 5, 0, 7); c.fill();
  };
  Markt.prototype.bandFuellen = function () {
    var b = this.band;
    b.textContent = "";
    this.trades.forEach(function (x, i) {
      var z = new Date(x.z);
      var farbe = x.kauf ? (i % 2 ? "#141e18" : "#1a2b1c") : (i % 2 ? "#221417" : "#2e1a1d");
      var r = an(b, el("div", "display:flex;height:18px;align-items:center;padding:0 4px;background:" + farbe + ";"));
      an(r, el("span", "width:61px;color:" + DIM + ";", z2(z.getHours()) + ":" + z2(z.getMinutes()) + ":" + z2(z.getSeconds())));
      an(r, el("span", "flex:1;color:" + TEXT + ";", zahl(x.p)));
      an(r, el("span", "width:60px;text-align:right;color:" + DIM + ";margin-right:14px;", x.b));
      an(r, el("span", "width:70px;text-align:right;color:" + TEXT + ";", "$ " + zahl(x.u)));
    });
  };

  // **Der Start gehört ans Ende der Datei.** Die Seiten hängen ihre Methoden
  // über `X.prototype.y = ...` an, und das sind Zuweisungen: sie laufen in der
  // Reihenfolge der Datei. Stand dieser Aufruf oben, war er bei `defer`
  // bereits fällig, bevor eine einzige Zuweisung gelaufen war.
  document.addEventListener("DOMContentLoaded", bereit);
  if (document.readyState !== "loading") bereit();
})();
