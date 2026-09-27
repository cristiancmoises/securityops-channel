#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later

set -eu

channel_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
package_output=$(guix build -L "$channel_dir" \
    -e '(@ (securityops packages webpki) lacuna-webpki)')
host="$package_output/bin/lacuna-webpki"

test -x "$host"

check_manifest() {
    manifest="$package_output/share/lacuna-webpki/native-messaging-hosts/$1.json"
    expected_key="$2"
    expected_id="$3"

    jq -e --arg host "$host" --arg key "$expected_key" --arg id "$expected_id" \
        '.name == "com.lacunasoftware.webpki" and
         .path == $host and
         .type == "stdio" and
         (.[$key] | index($id) != null)' "$manifest" >/dev/null
}

check_manifest firefox allowed_extensions webpki@lacunasoftware.com
check_manifest firefox allowed_extensions webpki-beta@lacunasoftware.com
check_manifest chromium allowed_origins chrome-extension://dcngeagmmhegagicpcmpinaoklddcgon/
check_manifest edge allowed_origins chrome-extension://nedeegdmhlnmboboahchfpkmdnnemapd/

printf 'Web PKI package and native messaging manifests: PASS\n'
