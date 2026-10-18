# SPDX-License-Identifier: GPL-3.0-or-later
"""Forward a bounded allowlist of Docker event fields to the local Wazuh queue."""

import json
import socket
import sys

ACTIONS = frozenset(
    (
        "create",
        "start",
        "stop",
        "die",
        "kill",
        "pause",
        "unpause",
        "restart",
        "destroy",
        "oom",
        "update",
        "rename",
        "health_status: healthy",
        "health_status: unhealthy",
        "connect",
        "disconnect",
        "pull",
        "push",
        "delete",
        "tag",
        "untag",
        "mount",
        "unmount",
    )
)


def sanitize_event(event):
    """Discard labels, nested payloads and unknown fields before serialization."""
    actor = event.get("Actor", {})
    attributes = actor.get("Attributes", {}) if isinstance(actor, dict) else {}
    if not isinstance(attributes, dict):
        attributes = {}
    action = event.get("Action")
    values = {
        "time": event.get("time"),
        "type": event.get("Type"),
        # exec_create/exec_start actions contain the executed command text.
        "action": action if isinstance(action, str) and action in ACTIONS else None,
        "id": event.get("id"),
        "name": attributes.get("name"),
        "image": attributes.get("image", event.get("from")),
    }
    fields = {
        key: value
        for key, value in values.items()
        if (key == "time" and type(value) is int and 0 <= value < 2**63)
        or (
            key != "time"
            and isinstance(value, str)
            and len(value) <= 2048
            and all(character.isprintable() for character in value)
        )
    }
    return {
        "source": "securityops-docker-safe",
        "integration": "docker",
        "docker": fields,
    }


def main():
    import docker

    if len(sys.argv) != 2:
        raise SystemExit("usage: wazuh-docker-events STATE-DIRECTORY")
    # Never honor ambient DOCKER_HOST or TLS variables for a local collector.
    client = docker.DockerClient(base_url="unix:///var/run/docker.sock", timeout=30)
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as queue:
            queue.connect(sys.argv[1] + "/queue/sockets/queue")
            for event in client.events(decode=True):
                message = json.dumps(sanitize_event(event), separators=(",", ":"))
                # Wazuh's usual queue limit is 65536; stay well below it.
                payload = ("1:Wazuh-Docker:" + message).encode("utf-8")
                if len(payload) <= 16384:
                    queue.send(payload)
    finally:
        client.close()


if __name__ == "__main__":
    try:
        main()
    except Exception:  # noqa: BLE001 -- redact every Docker SDK exception at this boundary.
        # Docker exceptions can contain event content. Shepherd records only
        # this fixed diagnostic and supervises the collector's exit status.
        raise SystemExit(
            "Local Docker event collection failed; check socket availability"
        ) from None
