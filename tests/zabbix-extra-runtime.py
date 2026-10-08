"""Exercise Java Gateway and real PDF rendering in a private network namespace."""

import argparse
import contextlib
import http.client
import http.server
import json
import os
import re
import socket
import struct
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path


@contextlib.contextmanager
def running(command, state, environment):
    with tempfile.TemporaryFile() as log:
        process = subprocess.Popen(
            command, cwd=state, env=environment, stdout=log, stderr=log
        )
        try:
            yield process
        except BaseException:
            log.seek(0)
            print(log.read().decode(errors="replace"), flush=True)
            raise
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
            else:
                process.wait()


def wait_port(process, port):
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        assert process.poll() is None, "component exited before readiness"
        try:
            with socket.create_connection(("127.0.0.1", port), timeout=0.2):
                return
        except OSError:
            time.sleep(0.1)
    raise AssertionError("component readiness timed out")


def receive(connection, length):
    data = b""
    while len(data) < length:
        chunk = connection.recv(length - len(data))
        assert chunk, "truncated Zabbix protocol response"
        data += chunk
    return data


def gateway_query(port, request):
    payload = json.dumps(request).encode()
    with socket.create_connection(("127.0.0.1", port), timeout=10) as connection:
        connection.sendall(b"ZBXD\x01" + struct.pack("<Q", len(payload)) + payload)
        assert receive(connection, 5) == b"ZBXD\x01"
        length = struct.unpack("<Q", receive(connection, 8))[0]
        assert length <= 1024 * 1024
        return json.loads(receive(connection, length))


def java_test(gateway, jdk, state, environment):
    command = str(gateway / "bin/zabbix-java-gateway")
    version = subprocess.check_output(
        [command, "-V"], env=environment, text=True, timeout=10
    )
    assert "7.4.15" in version
    environment = environment.copy()
    environment["JAVA_TOOL_OPTIONS"] = (
        "-Dzabbix.listenIP=127.0.0.1 -Dzabbix.listenPort=23052 "
        "-Dzabbix.server=127.0.0.1 -Dzabbix.startPollers=1"
    )
    # Only this synthetic Java process exposes JMX, within the private namespace.
    fixture = state / "Fixture.java"
    fixture.write_text(
        "public class Fixture { public static void main(String[] args) "
        "throws Exception { Thread.sleep(120000); } }\n"
    )
    jmx_environment = environment.copy()
    jmx_environment.pop("JAVA_TOOL_OPTIONS", None)
    jmx = [
        str(jdk / "bin/java"),
        "-Dcom.sun.management.jmxremote",
        "-Dcom.sun.management.jmxremote.host=127.0.0.1",
        "-Dcom.sun.management.jmxremote.port=23054",
        "-Dcom.sun.management.jmxremote.rmi.port=23055",
        "-Dcom.sun.management.jmxremote.authenticate=false",
        "-Dcom.sun.management.jmxremote.ssl=false",
        "-Djava.rmi.server.hostname=127.0.0.1",
        str(fixture),
    ]
    with (
        running([command], state, environment) as process,
        running(jmx, state, jmx_environment) as fixture_process,
    ):
        wait_port(process, 23052)
        wait_port(fixture_process, 23054)
        response = gateway_query(
            23052,
            {
                "request": "java gateway internal",
                "keys": ["zabbix[java,,ping]", "zabbix[java,,version]"],
            },
        )
        assert response == {
            "response": "success",
            "data": [{"value": "1"}, {"value": "7.4.15"}],
        }, response
        response = gateway_query(
            23052,
            {
                "request": "java gateway jmx",
                "jmx_endpoint": "service:jmx:rmi:///jndi/rmi://127.0.0.1:23054/jmxrmi",
                "keys": ["jmx[java.lang:type=Runtime,VmName]"],
            },
        )
        assert response["response"] == "success", response
        assert "OpenJDK" in response["data"][0]["value"], response
    print("PASS: Java Gateway protocol ping/version and synthetic loopback JMX")


class Dashboard(http.server.BaseHTTPRequestHandler):
    browser_executable = ""
    browser_verified = False
    service_pid = 0

    def do_GET(self):
        if self.path == "/favicon.ico":
            self.send_error(404)
            return
        assert self.path == "/zabbix.php?action=dashboard.print", self.path
        assert self.headers.get("Cookie") == "fixture=isolated", self.headers
        # Inspect only direct children forked by the owned service's threads.
        # A network-only namespace must never cause a host-wide proc scan.
        children = set()
        for thread in Path(f"/proc/{self.service_pid}/task").iterdir():
            try:
                children.update((thread / "children").read_text().split())
            except OSError:
                continue
        for pid in children:
            process = Path("/proc") / pid
            try:
                arguments = (process / "cmdline").read_bytes().split(b"\0")
                executable = os.readlink(process / "exe")
            except OSError:
                continue
            if executable == self.browser_executable:
                tokens = b" ".join(arguments).split()
                assert not {
                    b"--no-sandbox",
                    b"--disable-setuid-sandbox",
                    b"--disable-seccomp-filter-sandbox",
                    b"--no-zygote-sandbox",
                    b"--disable-gpu-sandbox",
                }.intersection(tokens), arguments
                if not any(token.startswith(b"--type=") for token in tokens):
                    status = (process / "status").read_text()
                    uid = re.search(r"^Uid:\s+(\d+)", status, re.MULTILINE)
                    assert uid and int(uid.group(1)) == os.getuid() != 0
                    Dashboard.browser_verified = True
                    print("Chrome browser executable:", executable, flush=True)
                    print("Chrome browser argv:", arguments, flush=True)
        assert self.browser_verified, "pinned sandboxed Chrome process not observed"
        data = (
            b"<!doctype html><html><body><div class='wrapper is-ready'>"
            b"Zabbix isolated PDF fixture 7.4.15</div></body></html>"
        )
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, format, *args):
        pass


def report_request(body):
    connection = http.client.HTTPConnection("127.0.0.1", 23053, timeout=60)
    try:
        connection.request(
            "POST", "/report", json.dumps(body), {"Content-Type": "application/json"}
        )
        response = connection.getresponse()
        return response.status, response.getheader("Content-Type"), response.read()
    finally:
        connection.close()


def web_test(service, state, environment):
    assert os.getuid() != 0, "Chrome sandbox acceptance requires a non-root UID"
    environment = environment.copy()
    poison = state / "browser-poison"
    poison.mkdir(mode=0o700)
    marker = state / "ambient-browser-used"
    candidate = poison / "headless_shell"
    candidate.write_text(
        f"#!{sys.executable}\nfrom pathlib import Path\nimport sys\n"
        f"Path({str(marker)!r}).touch()\nsys.exit(99)\n"
    )
    candidate.chmod(0o700)
    environment["PATH"] = str(poison) + os.pathsep + environment["PATH"]
    command = str(service / "sbin/zabbix_web_service")
    browser_path = re.search(
        r'^export PATH="(/gnu/store/[^"\n]+/bin)"$',
        Path(command).read_text(),
        re.MULTILINE,
    )
    assert browser_path, "web service must replace PATH with its pinned browser"
    Dashboard.browser_executable = str(
        Path(browser_path.group(1)).parent / "share/google/chrome/chrome"
    )
    Dashboard.browser_verified = False
    assert "7.4.15" in subprocess.check_output(
        [command, "-V"], env=environment, text=True, timeout=10
    )
    config = state / "web-service.conf"
    request = {
        "url": "http://127.0.0.1:23056/zabbix.php?action=dashboard.print",
        "headers": {"Cookie": "fixture=isolated"},
        "parameters": {"width": "800", "height": "600"},
    }
    for allowed in ("127.0.0.2", "127.0.0.1"):
        config.write_text(
            f"LogType=console\nListenPort=23053\nAllowedIP={allowed}\nTimeout=30\n"
        )
        subprocess.run(
            [command, "-T", "-c", str(config)],
            env=environment,
            check=True,
            capture_output=True,
            timeout=10,
        )
        with running([command, "-c", str(config)], state, environment) as process:
            Dashboard.service_pid = process.pid
            wait_port(process, 23053)
            if allowed == "127.0.0.2":
                status, content_type, data = report_request(request)
                assert status == 500 and content_type == "application/problem+json"
                assert json.loads(data)["detail"] == (
                    "Cannot accept incoming connection for peer: 127.0.0.1."
                )
                assert process.poll() is None
                continue
            invalid = dict(request, url="http://127.0.0.1:23056/wrong")
            status, content_type, data = report_request(invalid)
            assert status == 400 and content_type == "application/problem+json"
            assert "Unexpected URL path" in json.loads(data)["detail"]
            with http.server.HTTPServer(("127.0.0.1", 23056), Dashboard) as dashboard:
                thread = threading.Thread(target=dashboard.serve_forever, daemon=True)
                thread.start()
                try:
                    status, content_type, data = report_request(request)
                finally:
                    dashboard.shutdown()
                    thread.join(timeout=5)
            assert status == 200 and content_type == "application/pdf", data
            assert data.startswith(b"%PDF-") and len(data) > 1000
            pdf = state / "report.pdf"
            pdf.write_bytes(data)
            text = subprocess.check_output(
                ["pdftotext", str(pdf), "-"], text=True, timeout=10
            )
            assert "Zabbix isolated PDF fixture 7.4.15" in text, text
            assert Dashboard.browser_verified
            assert process.poll() is None
            assert not marker.exists(), "ambient browser superseded pinned Chrome"
    print("PASS: web service peer rejection, URL validation and real Chrome PDF")


def javascript_test(prefix, environment):
    command = str(prefix / "bin/zabbix_js")
    assert "7.4.15" in subprocess.check_output(
        [command, "-V"], env=environment, text=True, timeout=10
    )
    result = subprocess.run(
        [command, "-s", "-", "-p", '{"fixture":41}'],
        input="return JSON.parse(value).fixture + 1;",
        env=environment,
        text=True,
        capture_output=True,
        check=True,
        timeout=10,
    )
    assert result.stdout.strip() == "42", result.stdout
    print("PASS: zabbix_js version and harmless local JavaScript execution")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("gateway", type=Path)
    parser.add_argument("service", type=Path)
    parser.add_argument("jdk", type=Path)
    parser.add_argument("--mode", choices=("java", "web", "both"), default="both")
    parser.add_argument("--js", type=Path)
    arguments = parser.parse_args()
    if {name for _, name in socket.if_nameindex()} != {"lo"}:
        parser.error("requires a private network namespace with only loopback")
    with tempfile.TemporaryDirectory(prefix="zabbix-extra-") as temporary:
        state = Path(temporary)
        environment = os.environ.copy()
        for name in ("HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "XDG_DATA_HOME"):
            directory = state / name.lower()
            directory.mkdir(mode=0o700)
            environment[name] = str(directory)
        environment.pop("JAVA_TOOL_OPTIONS", None)
        environment.pop("LD_LIBRARY_PATH", None)
        if arguments.mode in ("java", "both"):
            java_test(arguments.gateway, arguments.jdk, state, environment)
        if arguments.mode in ("web", "both"):
            web_test(arguments.service, state, environment)
        if arguments.js is not None:
            javascript_test(arguments.js, environment)


if __name__ == "__main__":
    main()
