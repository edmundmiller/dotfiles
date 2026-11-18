"""Exercise the generated startup commands with the real CLI and a local API fixture."""

import http.server
import json
import os
from pathlib import Path
import shlex
import shutil
import socketserver
import subprocess
import sys
import tempfile
import threading


startup = json.loads(Path(sys.argv[1]).read_text())
tailscale = shutil.which("tailscale")
assert tailscale
prefs = {}
enrolled = threading.Event()
starts = []
edits = []


class LocalAPI(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def read_body(self):
        if self.headers.get("Transfer-Encoding") == "chunked":
            body = b""
            while size := int(self.rfile.readline(), 16):
                body += self.rfile.read(size)
                self.rfile.readline()
            self.rfile.readline()
            return body
        return self.rfile.read(int(self.headers.get("Content-Length", "0")))

    def respond(self, value, code=200):
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        if code != 204:
            self.wfile.write(json.dumps(value).encode())

    def do_GET(self):
        path = self.path.split("?")[0]
        if path == "/localapi/v0/status":
            self.respond({
                "BackendState": "Running" if enrolled.is_set() else "NeedsLogin",
                "Self": {"TailscaleIPs": ["100.64.0.2"]},
                "Peer": {
                    "nodekey:" + "1" * 64: {
                        "DNSName": startup["exitNode"] + ".",
                        "TailscaleIPs": ["100.64.0.9"],
                        "ExitNodeOption": True,
                    }
                } if enrolled.is_set() else {},
            })
        elif path == "/localapi/v0/prefs":
            self.respond(prefs)
        elif path == "/localapi/v0/watch-ipn-bus":
            self.send_response(200)
            self.end_headers()
            self.wfile.flush()
            assert enrolled.wait(10), "CLI never submitted enrollment"
            self.wfile.write(b'{"State":6}\n')
        else:
            self.send_error(404)

    def do_POST(self):
        path = self.path.split("?")[0]
        body = self.read_body()
        if path == "/localapi/v0/start":
            request = json.loads(body)
            starts.append(request)
            prefs.update(request["UpdatePrefs"])
            enrolled.set()
            self.respond({}, 204)
        elif path == "/localapi/v0/check-prefs":
            self.respond({})
        elif path == "/localapi/v0/login-interactive":
            self.respond({}, 204)
        else:
            self.send_error(404)

    def do_PATCH(self):
        assert self.path == "/localapi/v0/prefs"
        edits.append(json.loads(self.read_body()))
        self.respond({})


class Server(socketserver.ThreadingMixIn, socketserver.UnixStreamServer):
    daemon_threads = True


with tempfile.TemporaryDirectory(prefix="qb-startup-") as directory:
    root = Path(directory)
    socket = root / "localapi.sock"
    key = root / "auth-key"
    key.write_text("test-auth-key")
    wrapper = root / "tailscale"
    wrapper.write_text(
        "#!/bin/sh\nexec " + shlex.quote(tailscale)
        + " --socket=" + shlex.quote(str(socket)) + ' "$@"\n'
    )
    wrapper.chmod(0o700)
    environment = dict(os.environ, PATH=str(root) + os.pathsep + os.environ["PATH"])
    script = startup["script"].replace("/run/qb-tailscale-auth", str(key))
    with Server(str(socket), LocalAPI) as server:
        threading.Thread(target=server.serve_forever, daemon=True).start()
        try:
            for _ in range(2):
                subprocess.run(["sh", "-eu", "-c", script], env=environment, check=True, timeout=15)
                subprocess.run([str(wrapper), "set", *startup["setFlags"]], check=True, timeout=15)
                key.unlink(missing_ok=True)
        finally:
            server.shutdown()

assert len(starts) == 1, "Restart must reuse the identity without enrolling again"
assert starts[0]["AuthKey"] == "test-auth-key", "Enrollment must read the runtime key"
assert starts[0]["UpdatePrefs"]["AdvertiseTags"] == ["tag:qb-downloads"]
assert starts[0]["UpdatePrefs"]["Hostname"] == "qb-downloads"
assert starts[0]["UpdatePrefs"]["ExitNodeIP"] in ("", None), "Enroll before resolving an exit"
assert len(edits) == 2
for edit in edits:
    assert edit["ExitNodeIP"] == "100.64.0.9", "Resolve the configured exit after enrollment"
    assert edit["ExitNodeIPSet"] is True
    assert edit["ExitNodeAllowLANAccess"] is False
    assert edit["ExitNodeAllowLANAccessSet"] is True
    assert edit["CorpDNS"] is False
    assert edit["CorpDNSSet"] is True
print("PASS: real Tailscale CLI enrolls once, selects the exit and reuses identity")
