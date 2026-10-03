#!/usr/bin/env python3
"""Mehrere nachgebaute Miner in einem Prozess, fuer die Pruefung der
Mining-Ansicht mit mehreren Geraeten.

Ein echter Bitaxe reicht dafuer nicht: es ist nur einer, und in fremden
Netzen (Gaeste-WLAN, Router mit Client-Trennung) ist er vom Rechner aus oft
gar nicht zu sehen. Der Pruefstand spielt Geraete, die sich so
unterscheiden, wie es bei Anwendern vorkommt:

    gamma-wohnzimmer  Bitaxe Gamma 601, public-pool, mit Statistik
    gamma-buero       Bitaxe Gamma 601, ckpool, Statistik aus (Auslieferung)
    supra-keller      Bitaxe Supra 401, public-pool, mit Statistik
    nerdqaxe-regal    NerdQaxe++ mit vier Chips, eigener Pool im Heimnetz
    flackert          Gamma, faellt jede Minute 25 s aus
    antminer-s19      cgminer-Schnittstelle (TCP), meldet keine Leistung

Dazu ein public-pool (--pool-port, Vorgabe 21059) fuer die Pool-Seite. Unter
der Adresse bc1qbeispiel meldet er die Geraete, die auf public-pool.io
schuerfen, mit dem Teil nach dem Punkt im Stratum-Benutzer als Namen; "flackert"
bleibt im Aussetzer mit seiner letzten Meldung stehen. Jede andere Adresse
hat keine Geraete. In der App: Pool 127.0.0.1:21059 (http:// davor, der
Nachbau spricht kein TLS), Adresse bc1qbeispiel.

Die AxeOS-Felder folgen tools/axeos-nachbau.py (am 10.09.2026 an einem
echten Bitaxe v2.14.2 abgelesen). Jedes Geraet bekommt einen eigenen Port ab
--port (Vorgabe 21051), der Antminer --cgminer-port (Vorgabe 21058).

    python3 tools/miner-pruefstand.py              nur 127.0.0.1
    python3 tools/miner-pruefstand.py --an 192.168.122.1
                                                   fuer die Windows-VM (libvirt)
    python3 tools/miner-pruefstand.py --alle       auf allen Schnittstellen

Die Linux-VMs aus tools/pruefvm.sh brauchen nichts davon: im Benutzernetz
von QEMU ist 10.0.2.2 der Rechner selbst, auch dessen 127.0.0.1. --alle
bietet die Geraete auch im WLAN an; in fremden Netzen lieber --an.
    python3 tools/miner-pruefstand.py --nur 2      nur die ersten zwei

Am Telefon ueber USB, ohne dass beide im selben WLAN sein muessen:

    for p in 21051 21052 21053 21054 21055; do adb reverse tcp:$p tcp:$p; done

dann in den Einstellungen 127.0.0.1:21051 usw. eintragen. Beim Start
schreibt der Pruefstand die Zeile fuer die Einstellungen (minerHostsRaw) und
den Block fuer sources.json des Dienstes aus.
"""
import argparse, http.server, json, math, random, socket, socketserver, threading, time, urllib.parse

START = time.time()
VORLAUF = 48 * 3600
TAKT = 60
GRENZE = 720

# Grundwerte je Geraet. "hr" in GH/s, "watt" in W.
GERAETE = [
    {"name": "gamma-wohnzimmer", "asic": "BM1370", "board": "601", "hr": 1180, "erw": 1250,
     "watt": 18.6, "temp": 61, "pool": "stratum+tcp://public-pool.io:21496/bc1qbeispiel.wohnzimmer",
     "best": "412M", "statistik": True, "chips": 1, "domaenen": 4},
    {"name": "gamma-buero", "asic": "BM1370", "board": "601", "hr": 1050, "erw": 1100,
     "watt": 16.9, "temp": 58, "pool": "stratum+tcp://solo.ckpool.org:3333/bc1qbeispiel.buero",
     "best": "88.1M", "statistik": False, "chips": 1, "domaenen": 4},
    {"name": "supra-keller", "asic": "BM1368", "board": "401", "hr": 610, "erw": 650,
     "watt": 12.8, "temp": 54, "pool": "stratum+tcp://public-pool.io:21496/bc1qbeispiel.keller",
     "best": "1.07G", "statistik": True, "chips": 1, "domaenen": 4},
    {"name": "nerdqaxe-regal", "asic": "BM1370", "board": "NerdQAxe++", "hr": 4750, "erw": 4800,
     "watt": 76.0, "temp": 63, "pool": "stratum+tcp://umbrel.local:2018/bc1qbeispiel.regal",
     "best": "2.31G", "statistik": True, "chips": 4, "domaenen": 4},
    {"name": "flackert", "asic": "BM1370", "board": "601", "hr": 990, "erw": 1100,
     "watt": 17.2, "temp": 66, "pool": "stratum+tcp://public-pool.io:21496/bc1qbeispiel.flackert",
     "best": "35.6M", "statistik": False, "chips": 1, "domaenen": 4, "aussetzer": (60, 25)},
]


def offline(g):
    """Im Aussetzer antwortet das Geraet nicht, wie ein Bitaxe ohne WLAN."""
    a = g.get("aussetzer")
    if not a:
        return False
    periode, aus = a
    return (time.time() - START) % periode >= periode - aus


def geraetezeit(g):
    """Sekunden seit dem Start des Geraets. Die Startzeiten liegen auseinander,
    wie bei echten Geraeten, die nicht gleichzeitig eingeschaltet wurden."""
    return VORLAUF + (sum(map(ord, g["name"])) % 50) * 7 + time.time() - START


def langsam(g, t):
    """Der geglaettete Gang. Live-Wert und Statistik folgen derselben Kurve,
    sonst springt der Verlauf am Uebergang -- ein echtes Geraet misst beides
    gleich."""
    return g["hr"] + math.sin(t / 5400) * g["hr"] * 0.05


def satz(g):
    t = time.time() - START
    hr, phase = g["hr"], sum(map(ord, g["name"])) % 100
    glatt = langsam(g, geraetezeit(g))
    domaenen = []
    for c in range(g["chips"]):
        domaenen.append({"domains": [round(hr / g["chips"] / g["domaenen"]
                                           + math.sin(t / 5 + i + c + phase) * hr * 0.01, 1)
                                     for i in range(g["domaenen"])]})
    return {
        "hostname": g["name"],
        "ASICModel": g["asic"],
        "boardVersion": g["board"],
        "axeOSVersion": "v2.14.2",
        "hashRate": glatt + math.sin(t / 7 + phase) * hr * 0.08 + random.uniform(-0.02, 0.02) * hr,
        "hashRate_1m": glatt + math.sin(t / 30 + phase) * hr * 0.035,
        "hashRate_10m": glatt,
        "expectedHashrate": g["erw"],
        "bestDiff": g["best"],
        "bestSessionDiff": "12.4M",
        "poolDifficulty": "1000",
        "networkDifficulty": "142.3T",
        "blockFound": 0,
        "errorPercentage": 0.31 + random.uniform(0, 0.2),
        "temp": g["temp"] + math.sin(t / 20 + phase) * 2.5,
        "power": g["watt"] + random.uniform(-0.6, 0.6),
        "fanrpm": 4120,
        "sharesAccepted": 84213,
        "sharesRejected": 12,
        "uptimeSeconds": int(geraetezeit(g)),
        "statsFrequency": TAKT if g["statistik"] else 0,
        "statsLimit": GRENZE,
        "miningPaused": False,
        # Mit Benutzername: die App darf davon nur den Wirt behalten.
        "stratumURL": g["pool"],
        "hashrateMonitor": {"asics": domaenen},
    }


SPALTEN = ["hashrate", "hashrate_1m", "hashrate_10m", "hashrate_1h", "errorPercentage",
           "asicTemp", "asicTemp2", "vrTemp", "asicVoltage", "voltage", "power",
           "current", "fanSpeed", "fanRpm", "fan2Rpm", "wifiRssi", "freeHeap",
           "responseTime", "timestamp"]


def statistik(g, spalten):
    jetzt_ms = int(geraetezeit(g) * 1000)
    labels = [c for c in SPALTEN if c in spalten or c == "timestamp"]
    zeilen = []
    if g["statistik"]:
        hr = g["hr"]
        for k in range(GRENZE, 0, -1):
            ts = jetzt_ms - k * TAKT * 1000
            t = ts / 1000
            werte = {
                "hashrate": langsam(g, t) + random.uniform(-0.03, 0.03) * hr,
                "hashrate_10m": langsam(g, t),
                "errorPercentage": 0.3 + random.uniform(0, 0.2),
                "asicTemp": g["temp"] + math.sin(t / 7200) * 2.5,
                "power": g["watt"],
            }
            zeilen.append([ts if c == "timestamp" else round(werte.get(c, 0), 2)
                           for c in labels])
    return {"currentTimestamp": jetzt_ms, "labels": labels, "statistics": zeilen}


def handler_fuer(g):
    class H(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            if offline(g):
                # Verbindung ohne Antwort schliessen
                self.close_connection = True
                return
            teile = urllib.parse.urlsplit(self.path)
            pfad = teile.path.rstrip("/")
            if pfad == "/api/system/statistics":
                q = urllib.parse.parse_qs(teile.query)
                spalten = q["columns"][0].split(",") if "columns" in q else SPALTEN
                b = json.dumps(statistik(g, spalten)).encode()
            elif pfad == "/api/system/info":
                b = json.dumps(satz(g)).encode()
            elif pfad == "/api/system/scoreboard":
                b = json.dumps([{"difficulty": g["best"], "ntime": int(START - 3600 * (i + 1) * 7),
                                 "nonce": "0x%08x" % (i * 2654435761 % 2**32)}
                                for i in range(5)]).encode()
            else:
                self.send_response(404)
                self.end_headers()
                return
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Content-Length", str(len(b)))
            self.end_headers()
            self.wfile.write(b)

        def log_message(self, *a):
            pass
    return H


class Cgminer(socketserver.BaseRequestHandler):
    """Antwortet wie cgminer/bmminer: JSON mit angehaengtem Nullbyte, ohne
    Laengenangabe, Verbindung danach zu."""
    def handle(self):
        try:
            self.request.recv(4096)
        except OSError:
            return
        t = time.time() - START
        mhs = 95e6 + math.sin(t / 40) * 2e6
        antwort = {
            "STATUS": [{"STATUS": "S", "Description": "bmminer 1.0.0"}],
            "SUMMARY": [{"Elapsed": int(VORLAUF + t), "MHS av": mhs, "MHS 5s": mhs * 1.01,
                         "Accepted": 31877, "Rejected": 41, "Best Share": 6_210_000_000,
                         "Temperature": 71.0}],
        }
        self.request.sendall(json.dumps(antwort).encode() + b"\x00")


POOL_TYPEN = [("bitaxe", 3076, 3.68e15, "336526649849.58"), ("NerdQAxe++", 335, 1.70e15, "1796426508035.12"),
              ("Antminer", 16, 0.85e15, "48088950635.76"), ("cgminer", 41, 0.62e15, "35907557004549.51"),
              ("NerdMiner", 812, 0.0004e15, "1208123.5"), ("BitChimney", 3, 0.002e15, "8813321.1"),
              ("LuckyMiner", 74, 0.031e15, "92011233.7")]


def iso(t):
    return time.strftime("%Y-%m-%dT%H:%M:%S.000Z", time.gmtime(t))


def arbeiter(adresse):
    out = []
    for g in GERAETE:
        benutzer = g["pool"].rsplit("/", 1)[-1]
        addr, _, name = benutzer.partition(".")
        # Ein Pool sieht nur die Geraete, die bei ihm schuerfen.
        if addr != adresse or "public-pool.io" not in g["pool"]:
            continue
        jetzt = time.time()
        zuletzt = jetzt - (time.time() - START) % 60 + 35 if offline(g) else jetzt - 4
        out.append({"sessionId": "%08x" % sum(map(ord, g["name"])), "name": name,
                    "bestDifficulty": "%.2f" % (float(g["best"][:-1]) * {"M": 1e6, "G": 1e9}[g["best"][-1]]),
                    "hashRate": 0 if offline(g) else langsam(g, geraetezeit(g)) * 1e9,
                    "startTime": iso(START - VORLAUF), "lastSeen": iso(min(jetzt, zuletzt))})
    return out


def pool_kurve(summe_gh, schwankung):
    jetzt = time.time() - time.time() % 600
    return [{"label": iso(jetzt - k * 600),
             "data": "%.0f" % (summe_gh * 1e9 * (1 + math.sin((jetzt - k * 600) / 9000) * schwankung))}
            for k in range(144)]


class Pool(http.server.BaseHTTPRequestHandler):
    """Antwortet wie public-pool (benjamin-wilson/public-pool), Felder wie
    am 03.10.2026 bei pool.solomining.de abgelesen."""
    def do_GET(self):
        pfad = urllib.parse.urlsplit(self.path).path.rstrip("/")
        gesamt = sum(t[2] for t in POOL_TYPEN)
        teile = pfad.split("/")
        if pfad == "/api/info":
            d = {"blockData": [], "uptime": iso(START - 90 * 86400),
                 "userAgents": [{"userAgent": n, "count": str(c), "bestDifficulty": b,
                                 "totalHashRate": "%.6f" % h} for n, c, h, b in POOL_TYPEN],
                 "highScores": [{"updatedAt": iso(START - 86400 * 40), "bestDifficulty": "35907557004549.51",
                                 "bestDifficultyUserAgent": "cgminer"}]}
        elif pfad == "/api/info/chart":
            d = pool_kurve(gesamt / 1e9, 0.04)
        elif pfad == "/api/pool":
            d = {"totalHashRate": gesamt, "blockHeight": 969702,
                 "totalMiners": sum(t[1] for t in POOL_TYPEN), "blocksFound": [], "fee": 0}
        elif pfad == "/api/network":
            d = {"blocks": 969702, "difficulty": 132716002350731.3, "networkhashps": 9.05e20}
        elif len(teile) == 4 and teile[2] == "client":
            w = arbeiter(teile[3])
            best = max([float(x["bestDifficulty"]) for x in w] or [27.9])
            d = {"bestDifficulty": "%.2f" % best, "workersCount": len(w), "workers": w}
        elif len(teile) == 5 and teile[2] == "client" and teile[4] == "chart":
            w = [g for g in GERAETE if g["pool"].rsplit("/", 1)[-1].partition(".")[0] == teile[3]
                 and "public-pool.io" in g["pool"]]
            d = pool_kurve(sum(g["hr"] for g in w), 0.03) if w else []
        else:
            self.send_response(404)
            self.end_headers()
            return
        b = json.dumps(d).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def log_message(self, *a):
        pass


class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


class TcpServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    daemon_threads = True
    allow_reuse_address = True


def main():
    ap = argparse.ArgumentParser(description="Mehrere nachgebaute Miner")
    ap.add_argument("--port", type=int, default=21051)
    ap.add_argument("--cgminer-port", type=int, default=21058)
    ap.add_argument("--alle", action="store_true", help="auf allen Schnittstellen lauschen")
    ap.add_argument("--an", default="", help="auf dieser einen Adresse lauschen")
    ap.add_argument("--nur", type=int, default=0, help="nur die ersten N AxeOS-Geraete")
    ap.add_argument("--ohne-cgminer", action="store_true")
    ap.add_argument("--pool-port", type=int, default=21059)
    a = ap.parse_args()

    adresse = "0.0.0.0" if a.alle else (a.an or "127.0.0.1")
    gast = a.an or "127.0.0.1"
    geraete = GERAETE[:a.nur] if a.nur else GERAETE
    hosts, quellen = [], []
    for i, g in enumerate(geraete):
        port = a.port + i
        srv = Server((adresse, port), handler_fuer(g))
        threading.Thread(target=srv.serve_forever, daemon=True).start()
        hosts.append("%s:%d" % (gast, port))
        quellen.append({"type": "axeos", "url": "http://%s:%d" % (gast, port)})
        print("%-17s http://%s:%d" % (g["name"], adresse, port))
    if not a.ohne_cgminer:
        srv = TcpServer((adresse, a.cgminer_port), Cgminer)
        threading.Thread(target=srv.serve_forever, daemon=True).start()
        quellen.append({"type": "cgminer", "host": gast, "port": a.cgminer_port})
        print("%-17s tcp://%s:%d (cgminer, nur ueber den Dienst)" % ("antminer-s19", adresse, a.cgminer_port))
    srv = Server((adresse, a.pool_port), Pool)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    print("%-17s http://%s:%d (public-pool, Adresse bc1qbeispiel)" % ("pool", adresse, a.pool_port))
    print()
    print("Einstellungen (minerHostsRaw):")
    print("  " + "|".join(hosts))
    print("sources.json des Dienstes:")
    print("  " + json.dumps({"miners": quellen}))
    try:
        while True:
            time.sleep(3600)
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
