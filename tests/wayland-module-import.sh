#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
set -eu
cd "$(dirname "$0")/.."
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT HUP INT TERM
cat > "$temporary/import.scm" <<'SCM'
(resolve-interface '(tests wayland-packages))
(display "module import completed\n")
SCM
output=$(GUILE_AUTO_COMPILE=0 guix repl -L . "$temporary/import.scm")
test "$output" = 'module import completed'
echo 'PASS: importing Wayland tests leaves channel compilation running'
