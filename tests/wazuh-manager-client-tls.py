"""Check the installed dashboard manager client against owned loopback TLS peers."""

import argparse
import base64
import importlib.util
import json
import os
import secrets
import ssl
import subprocess
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dashboard", type=Path)
    parser.add_argument("node", type=Path)
    args = parser.parse_args()
    interfaces = {
        line.partition(":")[0].strip()
        for line in Path("/proc/net/dev").read_text().splitlines()
        if ":" in line
    }
    assert interfaces == {"lo"}, "Use a private no-network container/guest"
    assert os.getuid() != 0, "Use an unprivileged fixture account"
    source = Path(__file__).with_name("wazuh-search-runtime.py")
    spec = importlib.util.spec_from_file_location("search_fixture", source)
    assert spec and spec.loader
    shared = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(shared)
    with tempfile.TemporaryDirectory(prefix="wazuh-manager-tls-") as temporary:
        root = Path(temporary)
        shared.certificate(root, "ca", "/CN=ManagerFixtureCA", ca=True)
        shared.certificate(root, "node", "/CN=localhost")
        shared.certificate(root, "wrong-ca", "/CN=UnrelatedManagerCA", ca=True)
        username, password = "fixture-api", secrets.token_urlsafe(24)
        token = secrets.token_urlsafe(48)
        basic = "Basic " + base64.b64encode(f"{username}:{password}".encode()).decode()
        observed = {"manager": 0, "collector": 0}
        collector_port = 0

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, format: str, *values: object) -> None:
                pass  # Do not log credential-bearing request headers.

            def reply(self, status: int, payload: dict[str, object]) -> None:
                body = json.dumps(payload).encode()
                self.send_response(status)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

            def do_POST(self) -> None:
                observed["manager"] += 1
                if (
                    self.path != "/security/user/authenticate"
                    or self.headers.get("Authorization") != basic
                ):
                    self.reply(401, {})
                    return
                self.reply(200, {"data": {"token": token}})

            def do_GET(self) -> None:
                assert isinstance(self.server, ThreadingHTTPServer)
                if self.server.server_port == collector_port:
                    observed["collector"] += 1
                    self.reply(200, {})
                else:
                    observed["manager"] += 1
                    if self.headers.get("Authorization") != "Bearer " + token:
                        self.reply(401, {})
                    elif self.path == "/redirect":
                        self.send_response(302)
                        self.send_header(
                            "Location", f"https://127.0.0.1:{collector_port}/collector"
                        )
                        self.send_header("Content-Length", "0")
                        self.end_headers()
                    else:
                        self.reply(200, {"marker": "authenticated-manager-client"})

        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(root / "node.pem", root / "node-key.pem")
        servers = []
        threads = []
        try:
            for _ in range(2):
                server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
                server.socket = context.wrap_socket(server.socket, server_side=True)
                thread = threading.Thread(target=server.serve_forever, daemon=True)
                thread.start()
                servers.append(server)
                threads.append(thread)
            collector_port = servers[1].server_port
            client = (
                args.dashboard
                / "share/wazuh-dashboard/plugins/wazuhCore/server/services/server-api-client.js"
            )
            for mode, ca in (("untrusted", "wrong-ca.pem"), ("trusted", "ca.pem")):
                env = dict(os.environ, NODE_EXTRA_CA_CERTS=str(root / ca))
                for ambient in (
                    "NODE_TLS_REJECT_UNAUTHORIZED",
                    "NODE_OPTIONS",
                    "HTTP_PROXY",
                    "HTTPS_PROXY",
                    "ALL_PROXY",
                    "http_proxy",
                    "https_proxy",
                    "all_proxy",
                ):
                    env.pop(ambient, None)
                fixture = {
                    "mode": mode,
                    "token": token,
                    "host": {
                        "url": "https://127.0.0.1",
                        "port": servers[0].server_port,
                        "username": username,
                        "password": password,
                    },
                }
                result = subprocess.run(
                    [
                        str(args.node),
                        str(Path(__file__).with_suffix(".cjs")),
                        str(client),
                    ],
                    input=json.dumps(fixture).encode(),
                    env=env,
                    capture_output=True,
                    check=False,
                    timeout=30,
                )
                assert result.returncode == 0, (
                    f"Installed manager client {mode} TLS/redirect assertion failed; "
                    f"application requests observed: {observed['manager']}"
                )
                if mode == "untrusted":
                    assert observed["manager"] == 0, (
                        "Credentials reached the application before CA verification"
                    )
            assert observed == {"manager": 3, "collector": 0}, (
                "Authenticated requests did not remain at the expected manager endpoint"
            )
            print(
                "PASS installed manager client: untrusted CA refused before credentials"
            )
            print(
                "PASS installed manager client: trusted TLS auth and no redirect forwarding"
            )
        finally:
            for server in servers:
                server.shutdown()
                server.server_close()
            for thread in threads:
                thread.join(timeout=5)


if __name__ == "__main__":
    main()
