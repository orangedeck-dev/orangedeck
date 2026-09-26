// Die Bilder der sechs Ansichten gross ansehen.
//
// **Ein <dialog>, kein Nachbau.** `showModal()` sperrt den Rest der Seite,
// haelt den Fokus im Dialog und schliesst mit Escape, ohne dass hier etwas
// dafuer geschrieben werden muss. Dazu kommen nur das Blaettern (Pfeiltasten,
// Knoepfe, Wischen) und das Schliessen per Klick neben das Bild.
//
// Ohne JavaScript bleibt jedes Bild ein gewoehnlicher Link auf die Datei.
(function () {
  "use strict";

  function start() {
    var dlg = document.querySelector("dialog.lichtbox");
    var links = Array.prototype.slice.call(document.querySelectorAll("a.lb"));
    if (!dlg || !links.length || typeof dlg.showModal !== "function") return;
    var bild = dlg.querySelector("img");
    var text = dlg.querySelector(".lb-text");
    var jetzt = 0;

    function zeigen(i) {
      jetzt = (i + links.length) % links.length;
      var a = links[jetzt], klein = a.querySelector("img");
      bild.src = a.getAttribute("href");
      bild.alt = klein ? klein.alt : "";
      var titel = a.parentNode.querySelector("h3");
      text.textContent = (titel ? titel.textContent + ": " : "") + (klein ? klein.alt : "");
    }

    links.forEach(function (a, i) {
      a.addEventListener("click", function (ev) {
        ev.preventDefault();
        zeigen(i);
        dlg.showModal();
      });
    });
    dlg.querySelector(".lb-vor").addEventListener("click", function () { zeigen(jetzt + 1); });
    dlg.querySelector(".lb-zurueck").addEventListener("click", function () { zeigen(jetzt - 1); });
    dlg.querySelector(".lb-zu").addEventListener("click", function () { dlg.close(); });
    // Ein Klick auf den abgedunkelten Rand trifft den Dialog selbst.
    dlg.addEventListener("click", function (ev) { if (ev.target === dlg) dlg.close(); });
    dlg.addEventListener("keydown", function (ev) {
      if (ev.key === "ArrowRight") { zeigen(jetzt + 1); ev.preventDefault(); }
      if (ev.key === "ArrowLeft") { zeigen(jetzt - 1); ev.preventDefault(); }
    });
    var startX = null;
    dlg.addEventListener("touchstart", function (ev) { startX = ev.touches[0].clientX; }, { passive: true });
    dlg.addEventListener("touchend", function (ev) {
      if (startX === null) return;
      var dx = ev.changedTouches[0].clientX - startX;
      startX = null;
      if (Math.abs(dx) > 40) zeigen(jetzt + (dx < 0 ? 1 : -1));
    }, { passive: true });
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start);
  else start();
})();
