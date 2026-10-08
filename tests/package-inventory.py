"""Check accepted monitoring, PKI and XML validation entries in the inventory.

Run from the checkout: python3 tests/package-inventory.py
"""

import subprocess

expected = {
    ("wazuh", "wazuh-agent", "4.14.8"),
    ("wazuh", "wazuh-manager", "4.14.8"),
    ("wazuh-search", "wazuh-indexer", "4.14.8-1"),
    ("wazuh-search", "wazuh-dashboard", "4.14.8-1"),
    ("wazuh-search", "wazuh-filebeat", "7.10.2-2"),
    ("icp-brasil", "icp-brasil-roots", "2026.10.05"),
    ("icp-brasil-chain", "icp-brasil-ca-data", "2026.08.26"),
    ("phive", "phive", "12.2.0"),
    ("openpace", "openpace", "1.1.4"),
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
    if len(row) == 4 and row[0] in {item[0] for item in expected}
]
assert len(selected) == len(expected) and set(selected) == expected, (
    "Missing or duplicate accepted package inventory rows",
    sorted(expected - set(selected)),
)
print("PASS: all nine accepted monitoring/PKI/XML entries are reported once")
