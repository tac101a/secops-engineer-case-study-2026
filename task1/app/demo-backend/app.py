"""Synthetic backend with deterministic data and no application writes."""

import json
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/healthz":
            status, payload = 200, {"status": "ok"}
        elif self.path == "/data":
            status, payload = 200, {
                "source": "demo-backend",
                "value": "representative-data",
            }
        else:
            status, payload = 404, {"error": "not found"}

        body = (json.dumps(payload, separators=(",", ":")) + "\n").encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", 8081), Handler).serve_forever()
