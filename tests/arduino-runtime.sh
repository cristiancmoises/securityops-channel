#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Usage: sh tests/arduino-runtime.sh /gnu/store/...-arduino-ide-2.3.10
# Downloads the pinned AVR core and its toolchains; no board is required.
set -eu
arduino_prefix=${1:?Provide the built Arduino IDE store path}
arduino_tests=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
arduino_state=$(mktemp -d "${TMPDIR:-/tmp}/securityops-arduino-test.XXXXXX")
mkdir -p "$arduino_state/config" "$arduino_state/cache" "$arduino_state/data"
printf 'Isolated Arduino state and build output: %s\n' "$arduino_state"
arduino_cli() {
  env -i HOME="$arduino_state" XDG_CONFIG_HOME="$arduino_state/config" \
    XDG_CACHE_HOME="$arduino_state/cache" XDG_DATA_HOME="$arduino_state/data" \
    "$arduino_prefix/bin/arduino-ide-cli" "$@"
}
arduino_cli version
arduino_cli config dump
arduino_cli core update-index
arduino_cli core install arduino:avr@1.8.8
arduino_cli compile --fqbn arduino:avr:uno --jobs 4 \
  --build-path "$arduino_state/build" \
  "$arduino_tests/fixtures/arduino/Blink"
test -s "$arduino_state/build/Blink.ino.hex"
printf 'PASS: UNO Blink compiled using downloaded toolchains\n'
