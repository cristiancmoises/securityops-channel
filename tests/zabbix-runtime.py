"""Exercise synthetic Zabbix agents and SQL services in private temporary state.

Usage: zabbix-runtime.py AGENT AGENT2 SERVER PROXY SCHEMA POSTGRESQL
No host checks are enabled; all TCP listeners bind only to loopback.
"""

import getpass
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path


def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, capture_output=True, **kwargs)


def available_port():
    # Zabbix agentd accepts only 1024..32767, below Linux's ephemeral range.
    for port in range(20000, 32768):
        with socket.socket() as listener:
            try:
                listener.bind(("127.0.0.1", port))
            except OSError:
                continue
            return port
    raise RuntimeError("no free loopback port in the Zabbix range")


def wait_for(check, process):
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError(f"daemon exited with {process.returncode}")
        if check():
            return
        time.sleep(0.1)
    raise TimeoutError("daemon did not become ready")


def stop(process):
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=15)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


def main():
    agent, agent2, server, proxy, schema, postgres = map(Path, sys.argv[1:])
    processes = []
    log_files = []
    with tempfile.TemporaryDirectory(prefix="securityops-zabbix-") as temporary:
        state = Path(temporary)
        try:
            for label, executable in (
                ("agentd", agent / "sbin/zabbix_agentd"),
                ("agent2", agent2 / "sbin/zabbix_agent2"),
            ):
                port = available_port()
                config = state / f"{label}.conf"
                config.write_text(
                    f"LogType=file\nLogFile={state / (label + '.log')}\n"
                    f"PidFile={state / (label + '.pid')}\n"
                    "Server=127.0.0.1\nListenIP=127.0.0.1\n"
                    f"ListenPort={port}\nHostname=isolated-fixture\n"
                    "AllowKey=agent.*\nDenyKey=*\n"
                    + (
                        "StartAgents=1\n"
                        if label == "agentd"
                        else f"ControlSocket={state / 'agent2.sock'}\n"
                    )
                )
                log = (state / f"{label}.stderr").open("w+")
                log_files.append(log)
                process = subprocess.Popen(
                    [str(executable), "-f", "-c", str(config)], stdout=log, stderr=log
                )
                processes.append(process)

                def query(key, port=port):
                    return subprocess.run(
                        [
                            str(agent / "bin/zabbix_get"),
                            "-s",
                            "127.0.0.1",
                            "-p",
                            str(port),
                            "-k",
                            key,
                        ],
                        text=True,
                        capture_output=True,
                        timeout=3,
                        check=False,
                    )

                wait_for(lambda: query("agent.ping").stdout.strip() == "1", process)
                assert query("agent.version").stdout.strip() == "7.4.15"
                # An unrelated host metric must be rejected by the test allowlist.
                forbidden = query("system.uptime")
                assert forbidden.stdout.startswith("ZBX_NOTSUPPORTED"), (
                    forbidden.returncode,
                    forbidden.stdout,
                    forbidden.stderr,
                )
                reprobe = query("agent.ping")
                assert reprobe.returncode == 0 and reprobe.stdout.strip() == "1"
                print(
                    f"PASS: {label} loopback ping/version and denied host metric",
                    flush=True,
                )
                stop(process)

            pgdata = state / "pgdata"
            pgsocket = state / "pgsocket"
            pgsocket.mkdir(mode=0o700)
            run(
                str(postgres / "bin/initdb"),
                "-D",
                str(pgdata),
                "--no-locale",
                "-A",
                "trust",
            )
            pglog = (state / "postgres.log").open("w+")
            log_files.append(pglog)
            pgprocess = subprocess.Popen(
                [
                    str(postgres / "bin/postgres"),
                    "-D",
                    str(pgdata),
                    "-k",
                    str(pgsocket),
                    "-c",
                    "listen_addresses=",
                ],
                stdout=pglog,
                stderr=pglog,
            )
            processes.append(pgprocess)

            def pgready():
                return (
                    subprocess.run(
                        [str(postgres / "bin/pg_isready"), "-h", str(pgsocket)],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                        check=False,
                    ).returncode
                    == 0
                )

            wait_for(pgready, pgprocess)
            run(str(postgres / "bin/createdb"), "-h", str(pgsocket), "zabbix_fixture")
            for sql in ("schema.sql", "images.sql", "data.sql"):
                run(
                    str(postgres / "bin/psql"),
                    "-h",
                    str(pgsocket),
                    "-d",
                    "zabbix_fixture",
                    "--set",
                    "ON_ERROR_STOP=1",
                    "-f",
                    str(schema / "database/postgresql" / sql),
                )
            config = state / "server.conf"
            port = available_port()
            config.write_text(
                f"LogFile={state / 'server.log'}\nPidFile={state / 'server.pid'}\n"
                f"SocketDir={state}\nDBHost={pgsocket}\nDBName=zabbix_fixture\n"
                f"DBUser={getpass.getuser()}\n"
                f"ListenIP=127.0.0.1\nListenPort={port}\n"
                "StartPollers=0\nStartIPMIPollers=0\nStartPingers=0\n"
                "StartDiscoverers=0\nStartHTTPPollers=0\nStartPollersUnreachable=0\n"
                "StartSNMPPollers=0\nStartAgentPollers=0\nStartHTTPAgentPollers=0\n"
            )
            log = (state / "server.stderr").open("w+")
            log_files.append(log)
            process = subprocess.Popen(
                [str(server / "sbin/zabbix_server"), "-f", "-c", str(config)],
                stdout=log,
                stderr=log,
            )
            processes.append(process)

            def server_ready():
                with socket.socket() as connection:
                    connection.settimeout(0.1)
                    return connection.connect_ex(("127.0.0.1", port)) == 0

            wait_for(server_ready, process)
            print(
                "PASS: server loads current PostgreSQL schemas in isolated state",
                flush=True,
            )
            stop(process)
            # Passive SQLite proxy creates its own empty buffer database.
            config = state / "proxy.conf"
            port = available_port()
            config.write_text(
                f"LogFile={state / 'proxy.log'}\nPidFile={state / 'proxy.pid'}\n"
                f"SocketDir={state}\nDBName={state / 'proxy.sqlite'}\n"
                "ProxyMode=1\nServer=127.0.0.1\nHostname=isolated-fixture\n"
                f"ListenIP=127.0.0.1\nListenPort={port}\n"
                "StartPollers=0\nStartPingers=0\nStartDiscoverers=0\nStartHTTPPollers=0\n"
                "StartPollersUnreachable=0\nStartSNMPPollers=0\nStartAgentPollers=0\n"
                "StartHTTPAgentPollers=0\n"
            )
            log = (state / "proxy.stderr").open("w+")
            log_files.append(log)
            process = subprocess.Popen(
                [str(proxy / "sbin/zabbix_proxy"), "-f", "-c", str(config)],
                stdout=log,
                stderr=log,
            )
            processes.append(process)
            wait_for(server_ready, process)
            assert (state / "proxy.sqlite").stat().st_size > 0
            print(
                "PASS: passive proxy initializes SQLite in isolated state", flush=True
            )
        except BaseException:
            for log in state.glob("*.log"):
                print(
                    f"--- {log.name} ---\n{log.read_text(errors='replace')}",
                    file=sys.stderr,
                )
            for log in log_files:
                log.flush()
                log.seek(0)
                print(log.read(), file=sys.stderr)
            raise
        finally:
            for process in reversed(processes):
                stop(process)
            for log in log_files:
                log.close()


if __name__ == "__main__":
    main()
