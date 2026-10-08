"""Check accepted applications, monitoring, PKI and XML inventory entries.

Run from the checkout: python3 tests/package-inventory.py
"""

import subprocess

expected = {
    ("applications", "zupt", "5.2.9"),
    ("applications", "zupt-gui", "5.2.9"),
    ("applications", "evelin-bin", "4.4.0"),
    ("applications", "turborec", "3.10.4"),
    ("applications", "turborec-nvidia-new-feature", "3.10.4"),
    ("applications", "mirim", "1.1.1"),
    ("applications", "btp", "0.7"),
    ("applications", "whatsappel", "3.3.1"),
    ("wazuh", "wazuh-agent", "4.14.8"),
    ("wazuh", "wazuh-manager", "4.14.8"),
    ("wazuh-search", "wazuh-indexer", "4.14.8-1"),
    ("wazuh-search", "wazuh-dashboard", "4.14.8-1"),
    ("wazuh-search", "wazuh-filebeat", "7.10.2-2"),
    ("icp-brasil", "icp-brasil-roots", "2026.10.05"),
    ("icp-brasil-chain", "icp-brasil-ca-data", "2026.08.26"),
    ("phive", "phive", "12.2.0"),
    ("openpace", "openpace", "1.1.4"),
    ("ausweisapp", "ausweisapp", "2.6.0"),
}
result = subprocess.run(
    ["guix", "repl", "-q", "-L", ".", "etc/package-inventory.scm.in"],
    capture_output=True,
    text=True,
    check=False,
    timeout=180,
)
print(result.stdout, end="")
print(result.stderr, end="")
assert result.returncode == 0, result.returncode
rows = [tuple(line.split("\t")) for line in result.stdout.splitlines() if "\t" in line]
selected = [
    row[:3]
    for row in rows
    if len(row) == 4 and row[:2] in {item[:2] for item in expected}
]
assert len(selected) == len(expected) and set(selected) == expected, (
    "Missing or duplicate accepted package inventory rows",
    sorted(expected - set(selected)),
)
print(
    f"PASS: all {len(expected)} accepted application/monitoring/PKI/XML entries appear once"
)
