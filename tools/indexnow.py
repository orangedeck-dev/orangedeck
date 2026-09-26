#!/usr/bin/env python3
"""Meldet alle Seiten aus website/fertig/sitemap.xml an IndexNow.

    tools/indexnow.py            melden
    tools/indexnow.py --pruefen  nur zeigen, was gemeldet wuerde

Erst nach dem Veroeffentlichen laufen lassen: IndexNow holt die
Schluesseldatei von orangedeck.dev und prueft sie. Eine Meldung reicht fuer
Bing, Yandex, Seznam und Naver; Google nimmt an IndexNow nicht teil und
liest die sitemap.
"""
import json, pathlib, re, sys, urllib.request

WURZEL = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(WURZEL / "tools"))
from website import INDEXNOW, SEITE  # noqa: E402

karte = (WURZEL / "website" / "fertig" / "sitemap.xml").read_text(encoding="utf-8")
adressen = re.findall(r"<loc>([^<]+)</loc>", karte)
print("%d Adressen" % len(adressen))
if "--pruefen" in sys.argv:
    print("\n".join(adressen))
    raise SystemExit
daten = json.dumps({"host": "orangedeck.dev", "key": INDEXNOW,
                    "keyLocation": "%s/%s.txt" % (SEITE, INDEXNOW),
                    "urlList": adressen}).encode()
anfrage = urllib.request.Request("https://api.indexnow.org/indexnow", data=daten,
                                 headers={"Content-Type": "application/json; charset=utf-8"})
with urllib.request.urlopen(anfrage, timeout=30) as antwort:
    # 200 angenommen, 202 angenommen und Schluessel wird noch geprueft
    print("Antwort", antwort.status)
