"""Synthetic API: fetch backend data, write its temporary cache, return JSON."""

import json
import os
from http.client import HTTPException
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.request import urlopen


BACKEND_URL = os.environ.get("BACKEND_URL", "http://demo-backend:8081").rstrip("/")
EXPECTED_DATA = {"source": "demo-backend", "value": "representative-data"}
CACHE_PATH = Path("/tmp/demo-cache.json")


def encode_json(payload):
    return (json.dumps(payload, separators=(",", ":")) + "\n").encode("utf-8")


class Handler(BaseHTTPRequestHandler):
    def respond(self, status, body):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/healthz":
            self.respond(200, encode_json({"status": "ok"}))
            return
        if self.path != "/data":
            self.respond(404, encode_json({"error": "not found"}))
            return

        try:
            with urlopen(BACKEND_URL + "/data", timeout=3) as response:
                if response.status != 200:
                    raise ValueError("unexpected backend status")
                # The fixture is tiny; reject an oversized or different payload.
                raw = response.read(4097)
                if len(raw) > 4096 or json.loads(raw) != EXPECTED_DATA:
                    raise ValueError("unexpected backend data")
        except (OSError, ValueError, HTTPException):
            self.respond(502, encode_json({"error": "backend unavailable or invalid"}))
            return

        body = encode_json(EXPECTED_DATA)
        try:
            CACHE_PATH.write_bytes(body)
        except OSError:
            self.respond(500, encode_json({"error": "cache write failed"}))
            return
        self.respond(200, body)


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
