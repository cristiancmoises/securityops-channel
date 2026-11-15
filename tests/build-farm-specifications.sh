#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
spec="$root/etc/build-farm/specifications"
register="$root/etc/build-farm/units/securityops-cuirass-register.service"
mirror_service="$root/etc/build-farm/units/securityops-channel-mirror.service"
mirror_timer="$root/etc/build-farm/units/securityops-channel-mirror.timer"
web="$root/etc/build-farm/units/securityops-cuirass-web.service"
priority_service="$root/etc/build-farm/units/securityops-cuirass-prioritize.service"
priority_timer="$root/etc/build-farm/units/securityops-cuirass-prioritize.timer"
priority_sql="$root/etc/build-farm/prioritize-securityops.sql"
requeue_script="$root/etc/build-farm/requeue-stalled-builds"
requeue_service="$root/etc/build-farm/units/securityops-cuirass-requeue.service"
requeue_timer="$root/etc/build-farm/units/securityops-cuirass-requeue.timer"

for file in "$spec" "$register" "$mirror_service" "$mirror_timer" \
            "$web" "$priority_service" "$priority_timer" \
            "$priority_sql" "$requeue_script" "$requeue_service" "$requeue_timer"; do
  test -s "$file" || { printf 'missing: %s\n' "$file" >&2; exit 1; }
done

grep -qF 'file:///var/lib/cuirass/mirrors/securityops-channel.git' "$spec"
grep -qF 'https://git.securityops.com.br/cristiancmoises/securityops-channel.git' \
  "$mirror_service"
grep -qF '(branch branch)' "$spec"
grep -qF '(build '\''(custom (securityops build-farm ci)))' "$spec"
grep -qF '(define guix-baseline' "$spec"
grep -qF '(inherit guix)' "$spec"
grep -qF '(url "file:///var/lib/cuirass/mirrors/guix.git")' "$spec"
grep -qF '(commit "3f81f6643f69194f7b0c3243c214e3dbbdc3b805")' "$spec"
grep -qF '(define securityops-nonguix' "$spec"
grep -qF '(url "file:///var/lib/cuirass/mirrors/nonguix.git")' "$spec"
grep -qF '(commit "c241d19ff840dc75556f722b231760d119b6adea")' "$spec"
grep -qF '(channels (list securityops guix-baseline securityops-nonguix))' "$spec"
grep -qF '1662809a25bf267088b0c066eed8992bd52da8d7' "$spec"
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
grep -qF 'Wants=network-online.target securityops-channel-mirror.service' "$register"
grep -qF 'ExecStartPre=/usr/bin/pg_isready -q -d cuirass' "$register"
grep -qF 'ExecStartPre=/usr/bin/test -d /var/lib/cuirass/mirrors/securityops-channel.git' \
  "$register"
grep -qF 'ExecStartPre=/usr/bin/test -d /var/lib/cuirass/mirrors/guix.git' \
  "$mirror_service"
grep -qF 'ExecStartPre=/usr/bin/test -d /var/lib/cuirass/mirrors/nonguix.git' \
  "$mirror_service"
grep -qF 'Environment=GUILE_LOAD_PATH=/etc/cuirass/modules' "$register"
grep -qF 'ExecStartPre=/usr/bin/test -r /etc/cuirass/modules/securityops/build-farm/ci.scm' "$register"
grep -qF 'ExecStartPre=/usr/bin/pg_isready -q -d cuirass' "$web"
grep -qF 'RuntimeDirectory=cuirass' "$register"
grep -qF 'User=cuirass' "$mirror_service"
grep -qF 'ExecStart=/usr/bin/git --git-dir=/var/lib/cuirass/mirrors/securityops-channel.git fetch --prune --no-tags' \
  "$mirror_service"
grep -qF 'ExecStart=/usr/bin/git --git-dir=/var/lib/cuirass/mirrors/guix.git fetch --prune --no-tags' \
  "$mirror_service"
grep -qF 'ExecStart=/usr/bin/git --git-dir=/var/lib/cuirass/mirrors/nonguix.git fetch --prune --no-tags' \
  "$mirror_service"
grep -qF 'https://git.securityops.com.br/cristiancmoises/securityops-channel.git +refs/heads/main:refs/heads/main +refs/heads/keyring:refs/heads/keyring' \
  "$mirror_service"
grep -qF 'https://git.securityops.com.br/cristiancmoises/guix.git +refs/heads/master:refs/heads/master +refs/heads/keyring:refs/heads/keyring' \
  "$mirror_service"
grep -qF 'https://git.securityops.com.br/cristiancmoises/nonguix.git +refs/heads/master:refs/heads/master +refs/heads/keyring:refs/heads/keyring' \
  "$mirror_service"
grep -qF 'ProtectSystem=strict' "$mirror_service"
grep -qF 'ReadWritePaths=/var/lib/cuirass/mirrors' "$mirror_service"
grep -qF 'OnUnitActiveSec=2min' "$mirror_timer"
grep -qF 'Persistent=true' "$mirror_timer"
grep -qF 'Unit=securityops-channel-mirror.service' "$mirror_timer"
grep -qF "e.specification = 'securityops'" "$priority_sql"
test "$(grep -cF 'JOIN Evaluations AS e ON e.id = job.evaluation' "$priority_sql")" -eq 2
test "$(grep -cF 'JOIN Builds AS b ON b.id = job.build' "$priority_sql")" -eq 2
grep -qF '(b.status < 0 OR' "$priority_sql"
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
grep -qF '"$RUNUSER" -u postgres -- "$PSQL"' "$requeue_script"
grep -qF 'FROM builds WHERE status = -2' "$requeue_script"
grep -qF 'FROM builds WHERE status = -1' "$requeue_script"
grep -qF '"$SYSTEMCTL" restart "$REGISTER"' "$requeue_script"
grep -qF 'NoNewPrivileges=yes' "$requeue_service"
grep -qF 'OnUnitActiveSec=15min' "$requeue_timer"
grep -qF 'Persistent=true' "$requeue_timer"

# Match PEM headers without embedding a literal credential marker in the test.
if grep -Eq 'BEGIN [P]RIVATE KEY|password=|token=|https://[^[:space:]"\047]+@' \
    "$spec" "$register" "$mirror_service" "$mirror_timer" \
    "$web" "$priority_service" "$priority_timer" \
    "$priority_sql" "$requeue_script" "$requeue_service" "$requeue_timer"; then
  printf 'secret or credential-bearing URL in build-farm configuration\n' >&2
  exit 1
fi

guix repl -q -- "$root/etc/build-farm/offload/machines-ct126.scm" >/dev/null

printf 'PASS: authenticated Security Ops channel and private Cuirass units\n'
