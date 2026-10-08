"""Launch immutable Wazuh search runtimes using explicit private state."""

import os
import stat
import sys
from pathlib import Path
from typing import NoReturn

import yaml


def refuse(message: str) -> NoReturn:
    print(f"Wazuh search: {message}", file=sys.stderr)
    raise SystemExit(2)


def owned(path: Path, root: Path | None = None, private: bool = False) -> Path:
    try:
        result = path.resolve(strict=True)
        mode = result.stat()
    except OSError:
        refuse("WAZUH_SEARCH_STATE and its required files must already exist")
    if mode.st_uid != os.getuid() or stat.S_IMODE(mode.st_mode) & 0o022:
        refuse("WAZUH_SEARCH_STATE requires owned, non-group/world-writable files")
    if root is not None and not result.is_relative_to(root):
        refuse("configuration and state must remain beneath WAZUH_SEARCH_STATE")
    if private and stat.S_IMODE(mode.st_mode) & 0o077:
        refuse("private credential files must not be group/world-readable")
    return result


def require(condition: object, message: str) -> None:
    if not condition:
        refuse(message)


def setting(settings: dict, key: str, default: object = None) -> object:
    """Resolve native dotted/nested YAML without ambiguous duplicate settings."""
    values: list[object] = []

    def collect(mapping: dict, remaining: str) -> None:
        if remaining in mapping:
            values.append(mapping[remaining])
        for position, character in enumerate(remaining):
            if character == ".":
                child = mapping.get(remaining[:position])
                if isinstance(child, dict):
                    collect(child, remaining[position + 1 :])

    collect(settings, key)
    require(len(values) <= 1, "ambiguous dotted/nested configuration setting")
    return values[0] if values else default


def filebeat_value(settings: dict, key: str) -> object:
    return setting(settings, "output.elasticsearch." + key)


def filebeat_tunables(tunables: str) -> str:
    """Disable optional rseq registration without changing other libc policy."""
    return ":".join(
        [
            value
            for value in tunables.split(":")
            if value and value.partition("=")[0] != "glibc.pthread.rseq"
        ]
        + ["glibc.pthread.rseq=0"]
    )


def verify_module(home: Path, state: Path) -> None:
    """Keep Filebeat's strict ownership checks and the exact packaged module."""
    packaged = home / "module/wazuh"
    configured = owned(state / "module/wazuh", state, private=True)
    expected = {path.relative_to(packaged) for path in packaged.rglob("*")}
    actual = {path.relative_to(configured) for path in configured.rglob("*")}
    require(
        expected == actual, "explicit Filebeat module must match the packaged module"
    )
    for relative in expected:
        original = packaged / relative
        selected = owned(configured / relative, state, private=True)
        require(
            original.is_dir() == selected.is_dir(),
            "explicit Filebeat module must match the packaged module",
        )
        if original.is_file():
            require(
                original.read_bytes() == selected.read_bytes(),
                "explicit Filebeat module must match the packaged module",
            )


def main() -> None:
    kind, home_name, runtime_name, *arguments = sys.argv[1:]
    home = Path(home_name)
    runtime = Path(runtime_name)
    supplied = os.environ.get("WAZUH_SEARCH_STATE", "")
    require(
        supplied and Path(supplied).is_absolute(), "set absolute WAZUH_SEARCH_STATE"
    )
    state = owned(Path(supplied))
    require(
        state.is_dir()
        and len(state.parts) >= 3
        and not state.is_relative_to("/gnu/store"),
        "WAZUH_SEARCH_STATE cannot be filesystem root or the immutable store",
    )
    require(
        not stat.S_IMODE(state.stat().st_mode) & 0o077,
        "WAZUH_SEARCH_STATE must be a private directory (mode 0700)",
    )
    for ancestor in state.parents:
        metadata = ancestor.stat()
        sticky_root = metadata.st_uid == 0 and metadata.st_mode & stat.S_ISVTX
        require(
            metadata.st_uid in (0, os.getuid())
            and (not metadata.st_mode & 0o022 or sticky_root),
            "unsafe state ancestor permits directory replacement",
        )
    config = owned(state / "config", state)
    data = owned(state / "data", state)
    logs = owned(state / "logs", state)
    require(
        all(path.is_dir() for path in (config, data, logs)),
        "state directories required",
    )
    filename = {
        "indexer": "opensearch.yml",
        "dashboard": "opensearch_dashboards.yml",
        "filebeat": "filebeat.yml",
        "securityadmin": "opensearch.yml",
    }[kind]
    configuration = owned(config / filename, state, kind in ("dashboard", "filebeat"))
    try:
        require(configuration.stat().st_size <= 1024 * 1024, "configuration too large")
        settings = yaml.safe_load(configuration.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, yaml.YAMLError):
        refuse("invalid configuration")
    require(isinstance(settings, dict), "configuration must be a YAML mapping")
    # Do not log parsed configuration, which can contain private credentials.
    if kind in ("indexer", "securityadmin"):
        require(
            setting(settings, "plugins.security.ssl.http.enabled") is True,
            "indexer HTTPS is required",
        )
        require(
            setting(settings, "plugins.security.disabled", False) is False,
            "indexer authentication cannot be disabled",
        )
        require(
            all(
                setting(settings, f"plugins.security.{option}", False) is False
                for option in (
                    "allow_unsafe_democertificates",
                    "allow_default_init_securityindex",
                )
            ),
            "default or demo security initialization cannot be enabled",
        )
        require(
            setting(
                settings, "plugins.security.ssl.transport.enforce_hostname_verification"
            )
            is True,
            "transport hostname verification is required",
        )
        users = owned(
            config / "opensearch-security/internal_users.yml", state, private=True
        )
        require(users.is_file(), "explicit security users configuration is required")
        os.environ["OPENSEARCH_PATH_CONF"] = str(config)
        os.environ["OPENSEARCH_JAVA_HOME"] = str(runtime)
        if kind == "securityadmin":
            require(
                not any(
                    arg in ("-nhnv", "--disable-host-name-verification", "-icl")
                    for arg in arguments
                ),
                "security administration verification required",
            )
            command = home / "plugins/opensearch-security/tools/securityadmin.sh"
        else:
            require(os.getuid() != 0, "indexer requires a non-root service account")
            require(not arguments, "put indexer settings in the explicit configuration")
            command = home / "bin/opensearch"
            arguments = [f"-Epath.data={data}", f"-Epath.logs={logs}"]
    elif kind == "dashboard":
        require(os.getuid() != 0, "dashboard requires a non-root service account")
        require(not arguments, "put dashboard settings in the explicit configuration")
        require(
            setting(settings, "server.ssl.enabled") is True,
            "dashboard HTTPS is required",
        )
        require(
            setting(settings, "opensearch.ssl.verificationMode") == "full",
            "indexer peer and hostname verification is required",
        )
        require(
            setting(settings, "opensearch.username")
            and setting(settings, "opensearch.password"),
            "explicit indexer service credentials are required",
        )
        require(
            setting(settings, "opensearch_security.auth.anonymous_auth_enabled", False)
            is False,
            "anonymous dashboard authentication cannot be enabled",
        )
        api_configuration = owned(data / "wazuh/config/wazuh.yml", state, private=True)
        try:
            require(
                api_configuration.stat().st_size <= 1024 * 1024,
                "configuration too large",
            )
            api_settings = yaml.safe_load(api_configuration.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, yaml.YAMLError):
            refuse("invalid manager API configuration")
        require(
            isinstance(api_settings, dict),
            "manager API configuration must be a YAML mapping",
        )
        api_hosts = api_settings.get("hosts")
        require(
            isinstance(api_hosts, list)
            and api_hosts
            and all(
                isinstance(entry, dict)
                and entry
                and all(
                    isinstance(host, dict)
                    and isinstance(host.get("url"), str)
                    and host["url"].startswith("https://")
                    and host.get("username")
                    and host.get("password")
                    for host in entry.values()
                )
                for entry in api_hosts
            ),
            "HTTPS manager API endpoints and explicit credentials are required",
        )
        manager_ca = owned(config / "manager-ca.pem", state, private=True)
        require(manager_ca.is_file(), "explicit manager API CA bundle is required")
        hosts = setting(settings, "opensearch.hosts")
        require(
            hosts
            and all(
                str(host).startswith("https://")
                for host in (hosts if isinstance(hosts, list) else [hosts])
            ),
            "HTTPS indexer endpoints are required",
        )
        os.environ["OSD_PATH_CONF"] = str(config)
        os.environ["OSD_NODE_HOME"] = str(runtime)
        # Node reads its extra trust file at process startup.  Never inherit a
        # process-wide TLS bypass, arbitrary startup code, or ambient trust.
        os.environ.pop("NODE_TLS_REJECT_UNAUTHORIZED", None)
        os.environ.pop("NODE_OPTIONS", None)
        os.environ["NODE_EXTRA_CA_CERTS"] = str(manager_ca)
        command = home / "bin/opensearch-dashboards"
        arguments = ["--config", str(configuration), "--path.data", str(data)]
    else:
        require(
            not any(arg.startswith("-") for arg in arguments),
            "put Filebeat settings in the explicit configuration",
        )
        sandbox = settings.get("seccomp", {})
        require(isinstance(sandbox, dict), "native Filebeat seccomp policy is required")
        require(
            setting(settings, "seccomp.enabled", True) is True
            and not any(key in sandbox for key in ("default_action", "syscalls"))
            and not any(
                key in settings
                for key in ("seccomp.default_action", "seccomp.syscalls")
            ),
            "native Filebeat default-deny seccomp cannot be disabled or replaced",
        )
        require(
            filebeat_value(settings, "username")
            and filebeat_value(settings, "password"),
            "explicit forwarding credentials are required",
        )
        require(
            filebeat_value(settings, "ssl.verification_mode") in (None, "full"),
            "forwarding peer and hostname verification is required",
        )
        hosts = filebeat_value(settings, "hosts")
        require(
            isinstance(hosts, list)
            and hosts
            and all(
                isinstance(host, str) and host.startswith("https://") for host in hosts
            ),
            "HTTPS forwarding endpoints are required",
        )
        verify_module(home, state)
        # The unchanged native default-deny filter predates optional rseq.
        # This affects only this Filebeat process, not the kernel filter or
        # the system libc; preserve every unrelated caller tunable.
        os.environ["GLIBC_TUNABLES"] = filebeat_tunables(
            os.environ.get("GLIBC_TUNABLES", "")
        )
        command = home / "bin/filebeat"
        arguments += [
            "-c",
            str(configuration),
            "--path.home",
            str(state),
            "--path.config",
            str(config),
            "--path.data",
            str(data),
            "--path.logs",
            str(logs),
        ]
    os.execv(command, [str(command), *arguments])


if __name__ == "__main__":
    main()
