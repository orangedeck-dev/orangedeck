// Der Kopf von orangedeck.dev: alle sechs Ansichten, im Wechsel.
//
// **Was live geht, geht live.** Blöcke, Mempool, einzelne Transaktionen,
// Gebühren, Kurse und die Schwierigkeitsanpassung kommen aus demselben
// öffentlichen WebSocket, an dem auch die Anwendung hängt --
// `wss://mempool.space/api/v1/ws`. Der Browser spricht direkt mit ihm; es
// gibt keinen Server dazwischen, und es gibt keinen von uns.
//
// **Was nicht geht, sagt es.** Ein fremder Bitaxe und eine fremde Wallet
// lassen sich von hier aus nicht abfragen. Diese beiden Ansichten zeigen
// erfundene Zahlen und tragen deshalb ein Schild, das genau das sagt --
// dieselbe Regel wie bei der Liquidations-Heatmap in der Anwendung: wo eine
// Zahl kein Messwert ist, steht das daneben.
//
// **Packung und Farben kommen aus der Anwendung selbst**: `mondrian.js` setzt
// die Kacheln, `colors.js` färbt sie nach Alter. Beide liegen unverändert
// unter `ui/qml/` und werden von `tools/website.py` hierher kopiert; nur die
// Zeile `.pragma library` fällt weg, die kennt allein QML.
//
// **Das Standbild bleibt liegen, bis Daten da sind.** Ohne JavaScript, bei
// `prefers-reduced-motion` und solange der WebSocket nichts geliefert hat,
// sieht man das Bild aus `bilder/`. Erst die erste Nachricht mit
// Transaktionen schaltet um. Vorher wurde das Bild sofort entfernt, und wer
// mempool.space nicht erreichte (Werbeblocker, Firmennetz, Ausfall), sah
// einen leeren Kasten.
(function () {
  "use strict";

  var WS_URL = "wss://mempool.space/api/v1/ws";
  var WECHSEL_MS = 7000;
  // Der Strom läuft nur, solange jemand hinsieht. Das ist fremder Verkehr.
  var STILL_NACH_MS = 5 * 60 * 1000;
  var HALVING = 1050000;

  var T = (window.ORANGEDECK_LIVE || {});
  function t(k, a) {
    var s = T[k] || k;
    return a === undefined ? s : String(s).replace("{0}", a);
  }

  function zahl(n, stellen) {
    try {
      return new Intl.NumberFormat(document.documentElement.lang || "de", {
        minimumFractionDigits: stellen || 0, maximumFractionDigits: stellen || 0
      }).format(n);
    } catch (e) {
      return String(Math.round(n));
    }
  }

  function el(tag, klasse, text) {
    var d = document.createElement(tag);
    if (klasse) d.className = klasse;
    if (text !== undefined) d.textContent = text;
    return d;
  }

  var gestartet = false;
  function bereit() {
    if (gestartet) return;
    var wirt = document.getElementById("live");
    if (!wirt || !window.MondrianLayout || !window.ageColor) return;
    if (!("WebSocket" in window)) return;
    if (window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    gestartet = true;
    new Kopf(wirt);
  }

  // =====================================================================
  function Kopf(wirt) {
    var ich = this;
    this.stand = { txs: [], blocks: [], fees: null, kurse: null, info: null, da: null, vbps: 0 };
    this.blick = Date.now();
    this.ws = null;
    this.seite = 0;

    this.wirt = wirt;
    this.laeuft = false;
    this.huelle = el("div", "live-huelle");
    wirt.appendChild(this.huelle);

    // Reiterzeile in derselben Reihenfolge wie in der Anwendung
    var namen = T.reiter || ["Feed", "Clock", "Mining", "Explorer", "Market", "Wallet"];
    this.reiter = el("div", "live-reiter");
    this.knoepfe = [];
    namen.forEach(function (n, i) {
      var b = el("button", "live-reiter-knopf", n);
      b.type = "button";
      b.addEventListener("click", function () { ich.zeigen(i, true); });
      ich.reiter.appendChild(b);
      ich.knoepfe.push(b);
    });
    this.huelle.appendChild(this.reiter);

    this.buehne = el("div", "live-buehne");
    this.huelle.appendChild(this.buehne);

    this.seiten = [new Feed(), new Uhr(), new Miner(), new Explorer(), new Markt(), new Wallet()];
    this.seiten.forEach(function (s) {
      s.wurzel = el("div", "live-seite");
      s.aufbauen(s.wurzel);
      ich.buehne.appendChild(s.wurzel);
    });

    this.verbinden();

    document.addEventListener("visibilitychange", function () {
      if (document.hidden) ich.anhalten();
      else ich.wecken();
    });
    ["pointermove", "keydown", "scroll"].forEach(function (n) {
      window.addEventListener(n, function () { ich.blick = Date.now(); }, { passive: true });
    });
  }

  // Erst jetzt verschwindet das Standbild, und erst jetzt laufen die Uhren.
  Kopf.prototype.losgehen = function () {
    var ich = this;
    this.laeuft = true;
    this.wirt.classList.add("laeuft");
    this.zeigen(0, false);
    this.uhrwerk = window.setInterval(function () { ich.weiter(); }, WECHSEL_MS);
    this.takt = window.setInterval(function () { ich.auffrischen(); }, 1000);
  };

  Kopf.prototype.zeigen = function (i, vonHand) {
    if (vonHand) {
      this.blick = Date.now();
      // **Die Uhr faengt von vorn an.** Ohne das springt die Anzeige gleich
      // nach dem Klick weiter -- wer einen Reiter waehlt, sieht ihn dann
      // vielleicht eine Sekunde.
      if (this.uhrwerk) {
        var ich = this;
        window.clearInterval(this.uhrwerk);
        this.uhrwerk = window.setInterval(function () { ich.weiter(); }, WECHSEL_MS);
      }
    }
    this.seite = i;
    for (var k = 0; k < this.seiten.length; k++) {
      var an = k === i;
      this.seiten[k].wurzel.classList.toggle("an", an);
      this.knoepfe[k].classList.toggle("an", an);
      if (an && this.seiten[k].sichtbar) this.seiten[k].sichtbar(this.stand);
      if (an && this.seiten[k].auffrischen) this.seiten[k].auffrischen(this.stand);
      if (!an && this.seiten[k].verdeckt) this.seiten[k].verdeckt();
    }
  };

  Kopf.prototype.weiter = function () {
    if (document.hidden) return;
    this.zeigen((this.seite + 1) % this.seiten.length, false);
  };

  Kopf.prototype.auffrischen = function () {
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
    };
    this.ws.onmessage = function (ev) {
      var m;
      try { m = JSON.parse(ev.data); } catch (e) { return; }
      var st = ich.stand;
      if (m.transactions && m.transactions.length) {
        st.txs = m.transactions;
        ich.seiten[0].zulauf(m.transactions);
      }
      if (m.blocks && m.blocks.length) st.blocks = m.blocks;
      if (m.block) {
        st.blocks = st.blocks.concat([m.block]).slice(-8);
        ich.seiten[0].neuerBlock();
      }
      if (m.fees) st.fees = m.fees;
      if (m.conversions) st.kurse = m.conversions;
      if (m.mempoolInfo) st.info = m.mempoolInfo;
      if (m.da) st.da = m.da;
      if (typeof m.vBytesPerSecond === "number") st.vbps = m.vBytesPerSecond;
      if (!ich.laeuft) {
        if (m.transactions && m.transactions.length) ich.losgehen();
        return;
      }
      var s = ich.seiten[ich.seite];
      if (s.auffrischen) s.auffrischen(st);
    };
    this.ws.onclose = function () {
      ich.ws = null;
      if (Date.now() - ich.blick < STILL_NACH_MS) window.setTimeout(function () { ich.verbinden(); }, 8000);
    };
    this.ws.onerror = function () { try { ich.ws.close(); } catch (e) {} };
  };

  // ================================================================ Feed
  function Feed() {
    this.halde = [];
    this.fallend = [];
    this.schlange = [];
    this.lauf = 0;
  }
  Feed.prototype.aufbauen = function (w) {
    this.leinwand = el("canvas", "live-leinwand");
    w.appendChild(this.leinwand);
    this.ctx = this.leinwand.getContext("2d");
    this.marke = el("div", "live-marke", t("quelle"));
    w.appendChild(this.marke);
  };
  Feed.prototype.messen = function () {
    var dpr = Math.min(2, window.devicePixelRatio || 1);
    this.b = this.leinwand.clientWidth;
    this.h = this.leinwand.clientHeight;
    if (!this.b || !this.h) return false;
    this.leinwand.width = Math.round(this.b * dpr);
    this.leinwand.height = Math.round(this.h * dpr);
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    this.zelle = this.b < 520 ? 4 : 5;
    var sp = Math.max(8, Math.floor(this.b / this.zelle));
    if (sp !== this.spalten) {
      this.spalten = sp;
      this.lage = new window.MondrianLayout(sp);
      this.halde.length = 0;
      this.fallend.length = 0;
    }
    return true;
  };
  Feed.prototype.zulauf = function (txs) {
    for (var i = 0; i < txs.length && this.schlange.length < 400; i++) {
      var r = window.txSize ? window.txSize(txs[i].value, 5)
                            : Math.min(5, Math.max(1, Math.ceil(Math.sqrt((txs[i].value || 1) / 1e7))));
      this.schlange.push({ r: r, t: Date.now() });
    }
  };
  Feed.prototype.neuerBlock = function () {
    // Welche Transaktionen bestätigt wurden, nennt mempool.space nicht mit.
    // Der Block räumt die Halde, statt so zu tun, als kenne er ihren Inhalt.
    this.halde.length = 0;
    this.fallend.length = 0;
    if (this.spalten) this.lage = new window.MondrianLayout(this.spalten);
    this.blitz = 1;
  };
  Feed.prototype.sichtbar = function () {
    var ich = this;
    if (!this.messen()) return;
    if (!this.lauf) this.lauf = window.requestAnimationFrame(function () { ich.bild(); });
  };
  Feed.prototype.verdeckt = Feed.prototype.anhalten = function () {
    if (this.lauf) { window.cancelAnimationFrame(this.lauf); this.lauf = 0; }
  };
  Feed.prototype.bild = function () {
    var ich = this;
    this.lauf = window.requestAnimationFrame(function () { ich.bild(); });
    if (!this.b && !this.messen()) return;
    var jetzt = Date.now(), c = this.ctx, z = this.zelle;
    var n = Math.min(3, this.schlange.length);
    while (n-- > 0) {
      var q = this.schlange.shift();
      var p = this.lage.place(q.r);
      p.t = q.t;
      this.halde.push(p);
      this.fallend.push({ x: p.x * z, r: q.r * z, ziel: this.h - (p.y + q.r) * z,
                          py: -q.r * z - Math.random() * 140, v: 0, t: q.t, s: p });
      p.faellt = true;
      if (p.y + q.r > this.h / z) this.abraeumen();
    }
    c.clearRect(0, 0, this.b, this.h);
    for (var i = 0; i < this.halde.length; i++) {
      var s = this.halde[i];
      if (s.faellt) continue;
      c.fillStyle = window.ageColor(jetzt - (s.t || jetzt));
      c.fillRect(s.x * z, this.h - (s.y + s.r) * z, s.r * z - 1, s.r * z - 1);
    }
    for (var j = this.fallend.length - 1; j >= 0; j--) {
      var f = this.fallend[j];
      f.v += 0.9; f.py += f.v;
      if (f.py >= f.ziel) { f.py = f.ziel; f.s.faellt = false; this.fallend.splice(j, 1); }
      c.fillStyle = window.ageColor(jetzt - f.t);
      c.fillRect(f.x, f.py, f.r - 1, f.r - 1);
    }
    if (this.blitz > 0) {
      this.blitz = Math.max(0, this.blitz - 0.02);
      c.fillStyle = "rgba(247,147,26," + (0.7 * this.blitz).toFixed(3) + ")";
      c.fillRect(0, 0, this.b, 2);
    }
  };
  Feed.prototype.abraeumen = function () {
    this.halde.splice(0, Math.ceil(this.halde.length * 0.3));
    this.lage = new window.MondrianLayout(this.spalten);
    for (var i = 0; i < this.halde.length; i++) {
      var alt = this.halde[i], neu = this.lage.place(alt.r);
      neu.t = alt.t; this.halde[i] = neu;
    }
    this.fallend.length = 0;
  };

  // ================================================================= Uhr
  function Uhr() {}
  Uhr.prototype.aufbauen = function (w) {
    w.classList.add("live-uhr");
    this.hoehe = el("div", "live-gross", "—");
    this.unter = el("div", "live-unter", t("block"));
    var g = el("div", "live-gitter");
    this.felder = {};
    var ich = this;
    [["gebuehr", "sat/vB"], ["kurs", ""], ["moscow", "sat"], ["mempool", ""]].forEach(function (p) {
      var f = el("div", "live-feld");
      f.appendChild(el("div", "live-feld-name", t(p[0])));
      var v = el("div", "live-feld-wert", "—");
      f.appendChild(v);
      ich.felder[p[0]] = v;
      g.appendChild(f);
    });
    this.balken = el("div", "live-balken");
    this.balkenFuell = el("div", "live-balken-fuell");
    this.balken.appendChild(this.balkenFuell);
    this.balkenText = el("div", "live-balken-text", "");
    w.appendChild(this.hoehe); w.appendChild(this.unter);
    w.appendChild(g); w.appendChild(this.balken); w.appendChild(this.balkenText);
  };
  Uhr.prototype.auffrischen = function (st) {
    var b = st.blocks && st.blocks.length ? st.blocks[st.blocks.length - 1] : null;
    if (b) {
      this.hoehe.textContent = zahl(b.height);
      var min = Math.max(0, Math.round((Date.now() / 1000 - b.timestamp) / 60));
      this.unter.textContent = t("block") + " · " + t("vorMin", min);
    }
    if (st.fees) this.felder.gebuehr.textContent = zahl(st.fees.halfHourFee || 0, 1) + " sat/vB";
    if (st.kurse) {
      var eur = st.kurse.EUR || st.kurse.USD;
      this.felder.kurs.textContent = zahl(eur) + (st.kurse.EUR ? " €" : " $");
      this.felder.moscow.textContent = zahl(1e8 / eur) + " sat";
    }
    if (st.info) this.felder.mempool.textContent = zahl(st.info.size);
    if (st.da && b) {
      this.balkenFuell.style.width = Math.max(1, st.da.progressPercent).toFixed(1) + "%";
      var bisHalving = HALVING - b.height;
      this.balkenText.textContent =
        t("schwierigkeit") + " " + (st.da.difficultyChange >= 0 ? "+" : "")
        + zahl(st.da.difficultyChange, 2) + " %   ·   "
        + t("halving") + " " + t("bloecke") + " " + zahl(bisHalving);
    }
  };

  // =============================================================== Miner
  // Erfundene Zahlen, und sie sagen es. Ein fremder Bitaxe steht im fremden
  // Heimnetz -- von hier ist er nicht erreichbar, und das soll er auch nicht.
  function Miner() { this.phase = 0; }
  Miner.prototype.aufbauen = function (w) {
    w.classList.add("live-miner");
    var kopf = el("div", "live-kopf");
    kopf.appendChild(el("span", "live-kopf-name", "bitaxe"));
    kopf.appendChild(el("span", "live-schild", t("beispiel")));
    w.appendChild(kopf);
    this.rate = el("div", "live-gross live-orange", "1,07 TH/s");
    w.appendChild(this.rate);
    var g = el("div", "live-gitter");
    this.felder = {};
    var ich = this;
    [["beste", "296 M"], ["temperatur", "63 °C"], ["leistung", "18,1 W"]].forEach(function (p) {
      var f = el("div", "live-feld");
      f.appendChild(el("div", "live-feld-name", t(p[0])));
      var v = el("div", "live-feld-wert", p[1]);
      f.appendChild(v); ich.felder[p[0]] = v; g.appendChild(f);
    });
    w.appendChild(g);
    w.appendChild(el("div", "live-fussnote", t("beispielHinweis")));
  };
  Miner.prototype.auffrischen = function () {
    // Ein ruhiges Rauschen um 1,07 TH/s -- so verhält sich ein Bitaxe.
    this.phase += 0.6;
    var v = 1.07 + Math.sin(this.phase) * 0.012 + (Math.random() - 0.5) * 0.006;
    this.rate.textContent = zahl(v, 2) + " TH/s";
    this.felder.temperatur.textContent = (62 + Math.round(Math.sin(this.phase / 3))) + " °C";
  };

  // ============================================================ Explorer
  function Explorer() {}
  Explorer.prototype.aufbauen = function (w) {
    w.classList.add("live-explorer");
    this.reihe = el("div", "live-bloecke");
    w.appendChild(this.reihe);
    this.marke = el("div", "live-marke", t("quelle"));
    w.appendChild(this.marke);
  };
  Explorer.prototype.auffrischen = function (st) {
    if (!st.blocks || !st.blocks.length) return;
    var letzte = st.blocks.slice(-4).reverse(), ich = this;
    this.reihe.textContent = "";
    letzte.forEach(function (b, i) {
      var k = el("div", "live-block" + (i === 0 ? " neu" : ""));
      k.appendChild(el("div", "live-block-hoehe", zahl(b.height)));
      k.appendChild(el("div", "live-block-zeile",
        zahl(b.tx_count || (b.extras && b.extras.totalFees ? 0 : 0)) + " " + t("txn")));
      k.appendChild(el("div", "live-block-zeile",
        zahl((b.size || 0) / 1e6, 2) + " MB"));
      var min = Math.max(0, Math.round((Date.now() / 1000 - b.timestamp) / 60));
      k.appendChild(el("div", "live-block-zeile live-gedaempft", t("vorMin", min)));
      ich.reihe.appendChild(k);
    });
  };

  // =============================================================== Markt
  // Der Kurs, wie ihn derselbe WebSocket meldet. Kerzen bräuchten die
  // Börsenströme -- die holt die Anwendung, nicht diese Seite.
  function Markt() { this.punkte = []; this.geholt = false; }
  // **Die Linie braucht Vergangenheit.** Aus dem WebSocket kommt der Kurs nur
  // alle paar Minuten -- ein Besucher saehe in der ersten Viertelstunde zwei
  // Punkte, also nichts. Dieselbe Quelle liefert die Historie in einem
  // einzigen Abruf; die Anwendung holt sie an derselben Stelle
  // (`/v1/historical-price` im Dienst).
  Markt.prototype.holen = function () {
    if (this.geholt || !window.fetch) return;
    this.geholt = true;
    var ich = this;
    fetch("https://mempool.space/api/v1/historical-price?currency=EUR")
      .then(function (a) { return a.json(); })
      .then(function (d) {
        if (!d || !d.prices || !d.prices.length) return;
        var r = d.prices.slice(0, 120).reverse();
        ich.punkte = r.map(function (x) { return x.EUR || x.USD; })
                      .filter(function (x) { return x > 0; });
        ich.zeichnen();
      })
      .catch(function () { /* ohne Historie bleibt die Linie leer, das ist kein Fehler */ });
  };
  Markt.prototype.aufbauen = function (w) {
    w.classList.add("live-markt");
    this.wert = el("div", "live-gross", "—");
    w.appendChild(this.wert);
    this.leinwand = el("canvas", "live-linie");
    w.appendChild(this.leinwand);
    this.ctx = this.leinwand.getContext("2d");
    this.marke = el("div", "live-marke", t("quelle"));
    w.appendChild(this.marke);
  };
  Markt.prototype.sichtbar = function () { this.holen(); };
  Markt.prototype.auffrischen = function (st) {
    this.holen();
    if (!st.kurse) return;
    var eur = st.kurse.EUR || st.kurse.USD;
    this.wert.textContent = zahl(eur) + (st.kurse.EUR ? " €" : " $");
    var letzt = this.punkte[this.punkte.length - 1];
    if (letzt !== eur) this.punkte.push(eur);
    if (this.punkte.length > 240) this.punkte.shift();
    this.zeichnen();
  };
  Markt.prototype.zeichnen = function () {
    var c = this.ctx, b = this.leinwand.clientWidth, h = this.leinwand.clientHeight;
    if (!b || !h || this.punkte.length < 2) return;
    var dpr = Math.min(2, window.devicePixelRatio || 1);
    this.leinwand.width = Math.round(b * dpr);
    this.leinwand.height = Math.round(h * dpr);
    c.setTransform(dpr, 0, 0, dpr, 0, 0);
    var min = Math.min.apply(null, this.punkte), max = Math.max.apply(null, this.punkte);
    var spanne = Math.max(1, max - min);
    c.clearRect(0, 0, b, h);
    c.beginPath();
    for (var i = 0; i < this.punkte.length; i++) {
      var x = (i / (this.punkte.length - 1)) * b;
      var y = h - ((this.punkte[i] - min) / spanne) * (h - 6) - 3;
      i ? c.lineTo(x, y) : c.moveTo(x, y);
    }
    c.strokeStyle = "#f7931a";
    c.lineWidth = 1.6;
    c.stroke();
  };

  // ============================================================== Wallet
  function Wallet() {}
  Wallet.prototype.aufbauen = function (w) {
    w.classList.add("live-wallet");
    var kopf = el("div", "live-kopf");
    kopf.appendChild(el("span", "live-kopf-name", t("guthaben")));
    kopf.appendChild(el("span", "live-schild", t("beispiel")));
    w.appendChild(kopf);
    w.appendChild(el("div", "live-gross", "₿ 0,4213"));
    var g = el("div", "live-gitter");
    [[t("adressen"), "12"], [t("unbestaetigt"), "1"], [t("txn"), "348"]].forEach(function (p) {
      var f = el("div", "live-feld");
      f.appendChild(el("div", "live-feld-name", p[0]));
      f.appendChild(el("div", "live-feld-wert", p[1]));
      g.appendChild(f);
    });
    w.appendChild(g);
    w.appendChild(el("div", "live-fussnote", t("beispielHinweis")));
  };
  // **Der Start gehoert ans Ende der Datei.** Die Seiten haengen ihre
  // Methoden ueber `X.prototype.y = ...` an, und das sind Zuweisungen: sie
  // laufen in der Reihenfolge der Datei, anders als die Deklarationen selbst.
  // Stand dieser Aufruf oben, war er bei `defer` bereits faellig
  // (`readyState` ist dann "interactive"), bevor eine einzige Zuweisung
  // gelaufen war -- `new Feed()` gab es, `feed.aufbauen` noch nicht.
  //
  // Ohne `defer` faellt es nicht auf: dort ist `readyState` waehrend des
  // Parsens "loading", der Sofortaufruf entfaellt, und bis DOMContentLoaded
  // ist die Datei laengst durch. **Genau so ist es durchgerutscht** -- die
  // Probe lud das Skript ohne `defer`, die Seite mit.
  document.addEventListener("DOMContentLoaded", bereit);
  if (document.readyState !== "loading") bereit();
})();
