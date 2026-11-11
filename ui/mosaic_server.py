#!/usr/bin/env python3
# Small web server for the MOSAIC web page. Standard library only.
#
#   python3 mosaic_server.py [--port 8099] [--moonraker http://127.0.0.1:7125]
#
# Serves index.html and forwards a short list of Moonraker requests, so the
# page needs no CORS setup in Moonraker. Anyone who can open the page can move
# the printer, so run it only on a trusted network.
#
# Slicer filament sync: every few seconds it copies the filament of every tool
# (MOSAIC_SET_FILAMENT, saved as t<N>_filament) into Moonraker's database,
# namespace lane_data, one entry T<N> per tool. OrcaSlicer's "Synchronize
# filaments" for Moonraker printers reads that namespace and fills the
# project's filament list with the colour and material of every tool. Only the
# entries T0 ... T9 are written; other lane_data entries are left alone.
# Switch it off with variable_slicer_sync: False in _MOSAIC_TOOLS_SETTINGS,
# or with --no-slicer-sync.
#
# Part of MOSAIC (github.com/Slimohan/MOSAIC), GPL-3.0.

import argparse
import http.server
import json
import os
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))

# Moonraker paths the page may use. Everything else is refused.
ALLOWED = (
    "/printer/gcode/script",
    "/printer/objects/query",
    "/printer/info",
    "/server/files/metadata",
)


def make_handler(moonraker):
    class Handler(http.server.BaseHTTPRequestHandler):
        server_version = "mosaic-ui"

        def log_message(self, fmt, *args):
            pass

        def _send(self, code, body, ctype="application/json"):
            self.send_response(code)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)

        def _proxy(self, method):
            parts = urllib.parse.urlsplit(self.path)
            path = parts.path[len("/moonraker"):]
            if path not in ALLOWED:
                return self._send(403, b'{"error":"path not allowed"}')
            data = None
            if method == "POST":
                length = int(self.headers.get("Content-Length") or 0)
                data = self.rfile.read(length)
            url = moonraker + path + ("?" + parts.query if parts.query else "")
            req = urllib.request.Request(url, data=data, method=method)
            if data is not None:
                req.add_header("Content-Type", "application/json")
            try:
                with urllib.request.urlopen(req, timeout=300) as r:
                    return self._send(r.status, r.read())
            except urllib.error.HTTPError as e:
                return self._send(e.code, e.read())
            except Exception as e:  # moonraker not reachable
                msg = str(e).replace('"', "'")
                return self._send(502, ('{"error":"%s"}' % msg).encode())

        def do_GET(self):
            if self.path.startswith("/moonraker/"):
                return self._proxy("GET")
            if self.path in ("/", "/index.html"):
                with open(os.path.join(HERE, "index.html"), "rb") as f:
                    return self._send(200, f.read(), "text/html; charset=utf-8")
            return self._send(404, b'{"error":"not found"}')

        def do_POST(self):
            if self.path.startswith("/moonraker/"):
                return self._proxy("POST")
            return self._send(404, b'{"error":"not found"}')

    return Handler


# ---------------------------------------------------------------- slicer sync
LANE_NS = "lane_data"
OWN_KEYS = ["T%d" % i for i in range(10)]


def _call(moonraker, method, path, body=None, timeout=10):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(moonraker + path, data=data, method=method)
    if data is not None:
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read() or b"{}")


def lane_entries(status):
    """The lane_data entries MOSAIC wants, from a printer status answer.
    None means: do not touch lane_data (sync off, or no tool changer yet)."""
    tc = status.get("toolchanger")
    settings = status.get("gcode_macro _MOSAIC_TOOLS_SETTINGS") or {}
    if not tc or str(settings.get("slicer_sync", True)).lower() in ("false", "0", "no"):
        return None
    variables = (status.get("save_variables") or {}).get("variables") or {}
    want = {}
    for n in tc.get("tool_numbers") or []:
        if not 0 <= int(n) <= 9:
            continue
        f = variables.get("t%d_filament" % n)
        if not isinstance(f, dict) or not (f.get("material") or f.get("color")):
            continue
        e = {"lane": str(n), "material": str(f.get("material") or "")}
        col = str(f.get("color") or "").strip().lstrip("#").upper()
        if len(col) == 6:
            e["color"] = "#" + col
        if f.get("name"):
            e["name"] = str(f["name"])
        try:
            if float(f.get("temp") or 0) > 0:
                e["nozzle_temp"] = int(round(float(f["temp"])))
        except (TypeError, ValueError):
            pass
        want["T%d" % n] = e
    return want


def sync_once(moonraker, last):
    """One pass: write changed entries, remove MOSAIC's entries that are gone.
    `last` is what this process wrote before; returns the new state."""
    q = "/printer/objects/query?toolchanger&save_variables&gcode_macro%20_MOSAIC_TOOLS_SETTINGS"
    status = _call(moonraker, "GET", q)["result"]["status"]
    want = lane_entries(status)
    if want is None:
        return last
    try:
        have = _call(moonraker, "GET", "/server/database/item?namespace=" + LANE_NS)["result"]["value"] or {}
    except urllib.error.HTTPError as e:
        if e.code != 404:   # 404: the namespace does not exist yet
            raise
        have = {}
    for key, entry in want.items():
        if have.get(key) != entry:
            _call(moonraker, "POST", "/server/database/item", {"namespace": LANE_NS, "key": key, "value": entry})
    for key in OWN_KEYS:
        if key in have and key not in want:
            _call(moonraker, "DELETE", "/server/database/item?namespace=%s&key=%s" % (LANE_NS, key))
    return want


def sync_loop(moonraker, interval):
    last, failing = None, False
    while True:
        try:
            last = sync_once(moonraker, last)
            if failing:
                print("slicer sync: working again")
            failing = False
        except Exception as e:  # Klipper not ready, Moonraker restarting ...
            if not failing:
                print("slicer sync: paused (%s)" % e)
            failing = True
        time.sleep(interval)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8099)
    ap.add_argument("--bind", default="0.0.0.0")
    ap.add_argument("--moonraker", default="http://127.0.0.1:7125")
    ap.add_argument("--no-slicer-sync", action="store_true",
                    help="do not copy the tool filaments into Moonraker's lane_data")
    ap.add_argument("--sync-interval", type=float, default=5.0)
    a = ap.parse_args()
    if not a.no_slicer_sync:
        threading.Thread(target=sync_loop, args=(a.moonraker.rstrip("/"), a.sync_interval),
                         daemon=True).start()
    srv = http.server.ThreadingHTTPServer((a.bind, a.port),
                                          make_handler(a.moonraker.rstrip("/")))
    print("MOSAIC page on port %d, Moonraker at %s" % (a.port, a.moonraker))
    srv.serve_forever()


if __name__ == "__main__":
    main()
