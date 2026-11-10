#!/usr/bin/env python3
# Small web server for the MOSAIC web page. Standard library only.
#
#   python3 mosaic_server.py [--port 8099] [--moonraker http://127.0.0.1:7125]
#
# Serves index.html and forwards a short list of Moonraker requests, so the
# page needs no CORS setup in Moonraker. Anyone who can open the page can move
# the printer, so run it only on a trusted network.
#
# Part of MOSAIC (github.com/Slimohan/MOSAIC), GPL-3.0.

import argparse
import http.server
import os
import urllib.error
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))

# Moonraker paths the page may use. Everything else is refused.
ALLOWED = (
    "/printer/gcode/script",
    "/printer/objects/query",
    "/printer/info",
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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8099)
    ap.add_argument("--bind", default="0.0.0.0")
    ap.add_argument("--moonraker", default="http://127.0.0.1:7125")
    a = ap.parse_args()
    srv = http.server.ThreadingHTTPServer((a.bind, a.port),
                                          make_handler(a.moonraker.rstrip("/")))
    print("MOSAIC page on port %d, Moonraker at %s" % (a.port, a.moonraker))
    srv.serve_forever()


if __name__ == "__main__":
    main()
