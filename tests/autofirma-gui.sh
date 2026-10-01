#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Rejecting a broad/invalid share must happen before starting Java or a GUI.
set -eu

output=${1:?Usage: autofirma-gui.sh PACKAGE-OUTPUT}
task_home=$(mktemp -d /tmp/autofirma-gui-check.XXXXXX)
export HOME="$task_home"
export JAVA_TOOL_OPTIONS="-Djava.awt.headless=true -Duser.home=$task_home"
ln -s / "$task_home/root-link"

for share in relative / /tmp/.. /does-not-exist-autofirma-check \
    "$task_home/root-link" ":$task_home" "$task_home:" \
    "$task_home::$task_home"; do
    status=0
    AUTOFIRMA_SHARED_DIRECTORIES="$share" "$output/bin/autofirma" \
        >"$task_home/result.log" 2>&1 || status=$?
    if test "$status" -ne 64; then
        printf 'FAIL: invalid share %s exited %s instead of 64\n' "$share" "$status"
        exit 1
    fi
done
printf 'AutoFirma GUI share validation: PASS\n'
