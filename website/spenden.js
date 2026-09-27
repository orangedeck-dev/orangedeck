// Spendenteil der Startseite: QR-Codes, Kopierknoepfe und die wechselnde
// On-chain-Adresse aus /api/spenden-adresse (functions/api/).
//
// **Die Adresse erst auf Klick.** Beim Laden der Seite abgerufen, zoege jeder
// Crawler und jeder Besuch ohne Spendenabsicht eine Adresse; das kostet nichts,
// verteilt aber die Spenden ueber mehr Adressen als noetig. Die Texte kommen
// aus data-Attributen, die tools/website.py je Sprache setzt.
(function () {
  var teil = document.getElementById("spenden");
  if (!teil || !window.OrangeQR) return;

  function qr(ziel, text) {
    // Schwarz auf Weiss mit Rand: dunkle QR-Codes auf dunklem Grund lesen
    // viele Kameras nicht.
    ziel.innerHTML = window.OrangeQR.renderSVG(text, { border: 2, pixelSize: 6 });
  }

  teil.querySelectorAll(".qr[data-qr]").forEach(function (q) { qr(q, q.dataset.qr); });

  teil.addEventListener("click", function (e) {
    var k = e.target.closest(".kopier");
    if (!k || !k.dataset.wert) return;
    var alt = k.textContent;
    navigator.clipboard.writeText(k.dataset.wert).then(function () {
      k.textContent = teil.dataset.kopiert;
      setTimeout(function () { k.textContent = alt; }, 1600);
    });
  });

  var knopf = teil.querySelector("[data-aktion=adresse]");
  if (!knopf) return;
  var weg = knopf.closest(".spendeweg");
  var wert = weg.querySelector(".wert");
  var kopier = weg.querySelector(".kopier");
  var fehler = weg.querySelector(".spende-fehler");
  knopf.addEventListener("click", function () {
    knopf.disabled = true;
    fehler.hidden = true;
    fetch("/api/spenden-adresse", { cache: "no-store" })
      .then(function (r) { return r.ok ? r.json() : Promise.reject(r.status); })
      .then(function (d) {
        if (!/^bc1q[02-9ac-hj-np-z]{38}$/.test(d.adresse)) throw new Error("Antwort");
        wert.textContent = d.adresse;
        wert.hidden = false;
        kopier.dataset.wert = d.adresse;
        kopier.hidden = false;
        qr(weg.querySelector(".qr"), "bitcoin:" + d.adresse);
        knopf.hidden = true;
      })
      .catch(function () {
        fehler.hidden = false;
        knopf.disabled = false;
      });
  });
})();
