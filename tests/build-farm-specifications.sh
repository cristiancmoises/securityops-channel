#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
spec="$root/etc/build-farm/specifications"
register="$root/etc/build-farm/units/securityops-cuirass-register.service"
web="$root/etc/build-farm/units/securityops-cuirass-web.service"

for file in "$spec" "$register" "$web"; do
  test -s "$file" || { printf 'missing: %s\n' "$file" >&2; exit 1; }
done

grep -qF 'https://git.securityops.com.br/cristiancmoises/securityops-channel.git' "$spec"
grep -qF '(branch "main")' "$spec"
grep -qF '(build '\''(custom (securityops build-farm ci)))' "$spec"
grep -qF '(define guix-baseline' "$spec"
grep -qF '(inherit %default-guix-channel)' "$spec"
grep -qF '(commit "99c84619b4b7aae9f250c65c89b31c817789e44d")' "$spec"
grep -qF '(channels (list securityops guix-baseline))' "$spec"
grep -qF 'fb3223f3afdc14bab294c78d88e545eda2b146d9' "$spec"
grep -qF 'https://git.securityops.com.br/cristiancmoises/gocix.git' "$spec"
grep -qF 'https://git.securityops.com.br/cristiancmoises/sops-guix.git' "$spec"
grep -qF -- '--interval=300' "$register"
grep -qF -- '--parallel-evaluations=1' "$register"
grep -qF -- '--threads=3' "$register"
grep -qF 'MemoryHigh=4G' "$register"
grep -qF 'MemoryMax=5G' "$register"
grep -qF 'MemorySwapMax=1G' "$register"
grep -qF '127.0.0.1' "$web"
grep -qF 'After=postgresql@17-main.service guix-daemon.service' "$register"
grep -qF 'ExecStartPre=/usr/bin/pg_isready -q -d cuirass' "$register"
grep -qF 'Environment=GUILE_LOAD_PATH=/etc/cuirass/modules' "$register"
grep -qF 'ExecStartPre=/usr/bin/test -r /etc/cuirass/modules/securityops/build-farm/ci.scm' "$register"
grep -qF 'ExecStartPre=/usr/bin/pg_isready -q -d cuirass' "$web"
grep -qF 'RuntimeDirectory=cuirass' "$register"

if grep -Eq 'BEGIN PRIVATE KEY|password=|token=|https://[^[:space:]"\047]+@' "$spec" "$register" "$web"; then
  printf 'secret or credential-bearing URL in build-farm configuration\n' >&2
  exit 1
fi

guix repl -q -- "$root/etc/build-farm/offload/machines-ct126.scm" >/dev/null

printf 'PASS: authenticated Security Ops channel and private Cuirass units\n'
