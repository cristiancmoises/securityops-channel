#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
spec="$root/etc/build-farm/specifications"
register="$root/etc/build-farm/units/securityops-cuirass-register.service"
web="$root/etc/build-farm/units/securityops-cuirass-web.service"
priority_service="$root/etc/build-farm/units/securityops-cuirass-prioritize.service"
priority_timer="$root/etc/build-farm/units/securityops-cuirass-prioritize.timer"
priority_sql="$root/etc/build-farm/prioritize-securityops.sql"

for file in "$spec" "$register" "$web" "$priority_service" "$priority_timer" "$priority_sql"; do
  test -s "$file" || { printf 'missing: %s\n' "$file" >&2; exit 1; }
done

grep -qF 'https://git.securityops.com.br/cristiancmoises/securityops-channel.git' "$spec"
grep -qF '(branch branch)' "$spec"
grep -qF '(build '\''(custom (securityops build-farm ci)))' "$spec"
grep -qF '(define guix-baseline' "$spec"
grep -qF '(inherit %default-guix-channel)' "$spec"
grep -qF '(commit "b7f6549b5026b5776141482f9e228c49f09b5569")' "$spec"
grep -qF '(define securityops-nonguix' "$spec"
grep -qF '(commit "c241d19ff840dc75556f722b231760d119b6adea")' "$spec"
grep -qF '(channels (list securityops guix-baseline securityops-nonguix))' "$spec"
grep -qF 'fb3223f3afdc14bab294c78d88e545eda2b146d9' "$spec"
grep -qF 'https://git.securityops.com.br/cristiancmoises/gocix.git' "$spec"
grep -qF 'https://git.securityops.com.br/cristiancmoises/sops-guix.git' "$spec"
grep -qF 'https://git.securityops.co/cristiancmoises/guix.git' "$spec"
grep -qF 'https://git.securityops.co/cristiancmoises/nonguix.git' "$spec"
grep -qF 'https://git.securityops.co/cristiancmoises/radix-channel.git' "$spec"
grep -qF 'https://git.securityops.co/cristiancmoises/rosenthal.git' "$spec"
grep -qF 'https://git.securityops.co/cristiancmoises/small-guix.git' "$spec"
if grep -qF 'https://git.securityops.co/cristiancmoises/radix.git' "$spec"; then
  printf 'obsolete Radix mirror URL in build-farm specification\n' >&2
  exit 1
fi
for name in guix nonguix radix rosenthal small-guix securityops gocix sops-guix; do
  grep -qF "(name \"$name\")" "$spec"
done
test "$(grep -cF '(is-active? #f)' "$spec")" -eq 7
grep -qF -- '--interval=300' "$register"
grep -qF -- '--parallel-evaluations=1' "$register"
grep -qF -- '--threads=3' "$register"
grep -qF 'MemoryHigh=6G' "$register"
grep -qF 'MemoryMax=8G' "$register"
grep -qF 'MemorySwapMax=2G' "$register"
grep -qF '127.0.0.1' "$web"
grep -qF 'After=postgresql@17-main.service guix-daemon.service' "$register"
grep -qF 'ExecStartPre=/usr/bin/pg_isready -q -d cuirass' "$register"
grep -qF 'Environment=GUILE_LOAD_PATH=/etc/cuirass/modules' "$register"
grep -qF 'ExecStartPre=/usr/bin/test -r /etc/cuirass/modules/securityops/build-farm/ci.scm' "$register"
grep -qF 'ExecStartPre=/usr/bin/pg_isready -q -d cuirass' "$web"
grep -qF 'RuntimeDirectory=cuirass' "$register"
grep -qF "e.specification = 'securityops'" "$priority_sql"
grep -qF 'AND b.status < 0' "$priority_sql"
grep -qF 'UPDATE Builds' "$priority_sql"
grep -qF 'SET priority = 0' "$priority_sql"
grep -qF 'CASE WHEN status = 4 THEN -2 ELSE status END' "$priority_sql"
grep -qF 'SET status = 4' "$priority_sql"
grep -qF 'AND specification.is_active = 0' "$priority_sql"
test "$(grep -cF 'AND build.status < 0' "$priority_sql")" -eq 1
grep -qF 'AND build.id NOT IN (SELECT id FROM required)' "$priority_sql"
grep -qF 'User=postgres' "$priority_service"
grep -qF 'OnUnitActiveSec=5min' "$priority_timer"
grep -qF 'Persistent=true' "$priority_timer"

if grep -Eq 'BEGIN PRIVATE KEY|password=|token=|https://[^[:space:]"\047]+@' "$spec" "$register" "$web" "$priority_service" "$priority_timer" "$priority_sql"; then
  printf 'secret or credential-bearing URL in build-farm configuration\n' >&2
  exit 1
fi

guix repl -q -- "$root/etc/build-farm/offload/machines-ct126.scm" >/dev/null

printf 'PASS: authenticated Security Ops channel and private Cuirass units\n'
