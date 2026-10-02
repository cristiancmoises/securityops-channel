#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# A missing NSS compatibility path must not silently hide signing identities.
set -euo pipefail

output=$1
nss_tools=$2
fixture=$(mktemp -d "${TMPDIR:-/tmp}/autofirma-nss.XXXXXX")
export HOME="$fixture/home with spaces"
export TMPDIR="$HOME/tmp"
mkdir -p "$HOME/.mozilla/firefox/test.default" "$HOME/.pki/nssdb" "$TMPDIR"
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} -Djava.awt.headless=true \"-Duser.home=$HOME\" \"-Djava.io.tmpdir=$TMPDIR\" \"-Djava.util.prefs.userRoot=$HOME/.java\" \"-Djava.util.prefs.systemRoot=$HOME/.java\""
unset AFIRMA_NSS_PROFILES_INI AUTOFIRMA_SHARED_DIRECTORIES
printf '%s\n' '[Profile0]' 'Name=test' 'IsRelative=1' \
    'Path=test.default' 'Default=1' > "$HOME/.mozilla/firefox/profiles.ini"
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$fixture/key.pem" \
    -out "$fixture/cert.pem" -days 1 -subj '/CN=AutoFirma NSS package test'
openssl pkcs12 -export -inkey "$fixture/key.pem" -in "$fixture/cert.pem" \
    -name autofirma-nss-test -out "$fixture/identity.p12" -passout pass:fixture
for db in "$HOME/.mozilla/firefox/test.default" "$HOME/.pki/nssdb"; do
    "$nss_tools/certutil" -N -d "sql:$db" --empty-password
    "$nss_tools/pk12util" -i "$fixture/identity.p12" -d "sql:$db" \
        -W fixture -K ''
    "$nss_tools/certutil" -L -d "sql:$db" -n autofirma-nss-test
done
failures=0
if AUTOFIRMA_SHARED_DIRECTORIES=/ "$output/bin/autofirmacl" sign -help \
    > "$fixture/help.txt"; then
    printf 'PASS: command-specific help stays outside the compatibility view\n'
else
    printf 'FAIL: command-specific help requires NSS sharing\n' >&2
    failures=$((failures + 1))
fi
if AUTOFIRMA_SHARED_DIRECTORIES=/ "$output/bin/autofirmacl" sign -HELP \
    > "$fixture/help.txt"; then
    printf 'PASS: mixed-case command-specific help stays direct\n'
else
    printf 'FAIL: mixed-case command-specific help requires NSS sharing\n' >&2
    failures=$((failures + 1))
fi
if "$output/bin/certutil" -L -d "sql:$HOME/.pki/nssdb" -n autofirma-nss-test; then
    printf 'PASS: package exposes the standard certutil command\n'
else
    printf 'FAIL: package does not expose a working certutil command\n' >&2
    failures=$((failures + 1))
fi
mkdir -p "$HOME/tools-agent"
javac --release 17 -d "$HOME/tools-agent" \
    "$(dirname "$0")/AutofirmaNssTools.java"
printf '%s\n' 'Premain-Class: AutofirmaNssTools' > "$HOME/tools-agent/manifest"
jar --create --file "$HOME/tools-agent.jar" --manifest "$HOME/tools-agent/manifest" \
    -C "$HOME/tools-agent" AutofirmaNssTools.class
export JAVA_TOOL_OPTIONS="$JAVA_TOOL_OPTIONS \"-javaagent:$HOME/tools-agent.jar\" \"-Dafirma.test.nss.db=$HOME/.pki/nssdb\""
mkdir -p "$HOME/documents"
printf '%s\n' 'AutoFirma NSS signing regression' > "$HOME/documents/document.txt"
cd "$HOME/documents"
for store in mozilla auto; do
    for launcher in autofirmacl autofirma; do
        aliases=$("$output/bin/$launcher" listaliases -store "$store" \
            -password '' -xml)
        if [[ $aliases == *'<alias>autofirma-nss-test</alias>'* ]]; then
            printf 'PASS: %s lists %s identity\n' "$launcher" "$store"
        else
            printf 'FAIL: %s hides %s identity: %s\n' "$launcher" "$store" "$aliases" >&2
            failures=$((failures + 1))
        fi
    done
    signature="$store.csig"
    if "$output/bin/autofirmacl" sign -i document.txt -o "$signature" \
        -store "$store" -password '' -alias autofirma-nss-test -format CAdES \
        -algorithm SHA256withRSA -config mode=explicit &&
        openssl cms -verify -inform DER -in "$signature" \
            -content document.txt -noverify -binary \
            -out "$HOME/$store.verified" &&
        cmp document.txt "$HOME/$store.verified"; then
        printf 'PASS: independently verified %s NSS signature\n' "$store"
    else
        printf 'FAIL: %s NSS signing\n' "$store" >&2
        failures=$((failures + 1))
    fi
done
aliases=$("$output/bin/autofirmacl" listaliases -password '' -xml)
if [[ $aliases == *'<alias>autofirma-nss-test</alias>'* ]]; then
    printf 'PASS: an unspecified store selects the shared NSS identity\n'
else
    printf 'FAIL: the default store hides the shared NSS identity\n' >&2
    failures=$((failures + 1))
fi
for password in -help -store; do
    aliases=$("$output/bin/autofirmacl" listaliases -store mozilla \
        -password "$password" -xml)
    if [[ $aliases == *'<alias>autofirma-nss-test</alias>'* ]]; then
        printf 'PASS: NSS password value %s is not parsed as an option\n' "$password"
    else
        printf 'FAIL: NSS password value %s changes launcher routing\n' "$password" >&2
        failures=$((failures + 1))
    fi
done
if AUTOFIRMA_SHARED_DIRECTORIES=/ "$output/bin/autofirmacl" -HELP \
    > "$fixture/help.txt"; then
    printf 'PASS: mixed-case general help stays direct\n'
else
    printf 'FAIL: mixed-case general help requires NSS sharing\n' >&2
    failures=$((failures + 1))
fi
if AUTOFIRMA_SHARED_DIRECTORIES=/ "$output/bin/autofirmacl" VERIFY \
    -i "$HOME/documents/mozilla.csig" -xml > "$fixture/verify.txt"; then
    printf 'PASS: mixed-case verification stays direct\n'
else
    printf 'FAIL: mixed-case verification requires NSS sharing\n' >&2
    failures=$((failures + 1))
fi
mkdir -p "$fixture/shared documents"
cd "$fixture/shared documents"
status=0
"$output/bin/autofirmacl" listaliases -store mozilla -password '' -xml \
    > "$fixture/unshared.txt" 2>&1 || status=$?
if [[ $status == 64 && $(< "$fixture/unshared.txt") == *AUTOFIRMA_SHARED_DIRECTORIES* ]]; then
    printf 'PASS: an unshared external working directory is rejected clearly\n'
else
    printf 'FAIL: unshared external working directory rejection, exit %s\n' "$status" >&2
    failures=$((failures + 1))
fi
aliases=$(AUTOFIRMA_SHARED_DIRECTORIES="$PWD" "$output/bin/autofirmacl" \
    listaliases -store mozilla -password '' -xml)
if [[ $aliases == *'<alias>autofirma-nss-test</alias>'* ]]; then
    printf 'PASS: an explicitly shared external working directory is accepted\n'
else
    printf 'FAIL: explicitly shared external working directory\n' >&2
    failures=$((failures + 1))
fi
test "$failures" -eq 0
