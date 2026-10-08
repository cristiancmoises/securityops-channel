"""Render the unconfigured frontend with PHP on an isolated loopback listener."""

import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path


def main():
    frontend, php = map(Path, sys.argv[1:])
    php_version = subprocess.check_output(
        [str(php / "bin/php"), "-n", "-r", "echo PHP_VERSION;"],
        text=True,
        timeout=10,
    )
    with tempfile.TemporaryDirectory(prefix="securityops-zabbix-php-") as temporary:
        state = Path(temporary)
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            port = listener.getsockname()[1]
        with (state / "php.log").open("w+") as log:
            process = subprocess.Popen(
                [
                    str(php / "bin/php"),
                    "-n",
                    "-d",
                    f"session.save_path={state}",
                    "-S",
                    f"127.0.0.1:{port}",
                    "-t",
                    str(frontend / "share/zabbix/php"),
                ],
                stdout=log,
                stderr=log,
            )
            try:
                deadline = time.monotonic() + 20
                while time.monotonic() < deadline:
                    if process.poll() is not None:
                        raise RuntimeError("PHP server exited")
                    try:
                        with urllib.request.urlopen(
                            f"http://127.0.0.1:{port}/setup.php", timeout=10
                        ) as response:
                            assert response.status == 200
                            page = response.read().decode()
                        break
                    except urllib.error.URLError:
                        time.sleep(0.1)
                else:
                    raise TimeoutError("PHP server did not become ready")
                assert "7.4.15" in page
                assert "Welcome" in page and "Zabbix" in page
                log.flush()
                log.seek(0)
                messages = log.read()
                assert "Fatal error" not in messages and "Warning:" not in messages
                print(
                    f"PASS: PHP{php_version} renders Zabbix7.4.15 setup page "
                    "without warnings"
                )
            except BaseException:
                log.flush()
                log.seek(0)
                print(log.read(), file=sys.stderr)
                raise
            finally:
                if process.poll() is None:
                    process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)


if __name__ == "__main__":
    main()
