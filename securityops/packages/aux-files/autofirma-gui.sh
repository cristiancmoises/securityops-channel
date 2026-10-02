#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Compatibility filesystem, not a security sandbox: HOME and selected sockets
# remain available to the signed upstream application.
set -euo pipefail

afirma_output='@OUTPUT@'
afirma_java_launcher="$afirma_output/libexec/autofirma-java"
afirma_cli=false

# NSS discovery ignores its environment override on Linux.  Only operations
# that can use NSS need the compatibility filesystem; help, verification and
# explicitly selected non-NSS stores retain their direct CLI behavior.
if [[ ${0##*/} == autofirmacl || ( $# -gt 0 && ${1,,} != afirma://* ) ]]; then
    afirma_java_launcher="$afirma_output/libexec/autofirma-cli-java"
    afirma_cli=true
    afirma_command=${1:-}
    afirma_second=${2:-}
    case "${afirma_command,,}" in
        ''|-help|--help|verify)
            exec "$afirma_java_launcher" "$@" ;;
    esac
    # Upstream recognizes command-specific help only in the second argument.
    case "${afirma_second,,}" in
        -help|--help) exec "$afirma_java_launcher" "$@" ;;
    esac
    afirma_store=auto
    afirma_arguments=("$@")
    for ((afirma_index = 1; afirma_index < $#; afirma_index++)); do
        case "${afirma_arguments[afirma_index]}" in
            -store)
                ((afirma_index + 1 < $#)) || exec "$afirma_java_launcher" "$@"
                afirma_index=$((afirma_index + 1))
                afirma_store=${afirma_arguments[afirma_index]} ;;
            -i|-o|-alias|-filter|-format|-password|-algorithm|-config|\
                -operation|-preurl|-posturl|-hformat|-halgorithm)
                # Like CommandLineParameters, consume the value, even if it
                # starts with a dash.  The application validates arguments.
                afirma_index=$((afirma_index + 1)) ;;
        esac
    done
    case "$afirma_store" in
        mozilla|auto) ;;
        *) exec "$afirma_java_launcher" "$@" ;;
    esac
fi

afirma_reject_share() {
    printf 'AutoFirma: invalid shared directory: %s\n' "$1" >&2
    exit 64
}

afirma_directory() {
    local original=$1 canonical
    [[ $original == /* && -d $original ]] || afirma_reject_share "$original"
    canonical=$('@REALPATH@' -e -- "$original") || afirma_reject_share "$original"
    # Refuse filesystem roots and broad system trees, including their aliases.
    case "$canonical" in
        /|/home|/gnu|/gnu/store|/etc|/dev|/proc|/sys|/run|/usr|/var|/tmp|/opt)
            afirma_reject_share "$original" ;;
    esac
    printf '%s\n' "$canonical"
}

afirma_home=$(afirma_directory "${HOME:-}")
afirma_workdir=$HOME
afirma_workdir_shared=false
if $afirma_cli; then
    afirma_workdir=$('@REALPATH@' -e -- "$PWD")
    case "$afirma_workdir/" in
        "$afirma_home/"*)
            afirma_workdir="$HOME${afirma_workdir#"$afirma_home"}"
            afirma_workdir_shared=true ;;
    esac
fi
afirma_mounts=()
while IFS= read -r afirma_store_item; do
    afirma_mounts+=(--ro-bind "$afirma_store_item" "$afirma_store_item")
done < '@CLOSURE@'
afirma_mounts+=(--ro-bind "$afirma_output" "$afirma_output"
    --proc /proc --dev /dev --tmpfs /tmp --dir /opt
    --ro-bind '@NSS@' /usr/lib/nss --bind "$afirma_home" "$HOME")

if [[ -n ${AUTOFIRMA_SHARED_DIRECTORIES:-} ]]; then
    case "$AUTOFIRMA_SHARED_DIRECTORIES" in
        :*|*:|*::*) afirma_reject_share "$AUTOFIRMA_SHARED_DIRECTORIES" ;;
    esac
    IFS=: read -r -a afirma_shares <<< "$AUTOFIRMA_SHARED_DIRECTORIES"
    for afirma_share in "${afirma_shares[@]}"; do
        afirma_share=$(afirma_directory "$afirma_share")
        afirma_mounts+=(--bind "$afirma_share" "$afirma_share")
        case "$afirma_workdir/" in
            "$afirma_share/"*) afirma_workdir_shared=true ;;
        esac
    done
fi
if $afirma_cli && ! $afirma_workdir_shared; then
    printf 'AutoFirma: NSS CLI working directory is outside HOME; share it with AUTOFIRMA_SHARED_DIRECTORIES: %s\n' "$PWD" >&2
    exit 64
fi

for afirma_file in /etc/resolv.conf /etc/hosts /etc/nsswitch.conf \
    /etc/localtime /etc/passwd /etc/group; do
    if [[ -f $afirma_file ]]; then
        afirma_mounts+=(--ro-bind "$afirma_file" "$afirma_file")
    fi
done
if [[ -n ${XAUTHORITY:-} && $XAUTHORITY == /* && -f $XAUTHORITY ]]; then
    afirma_mounts+=(--ro-bind "$XAUTHORITY" "$XAUTHORITY")
fi

afirma_socket() {
    if [[ $1 == /* && -S $1 ]]; then
        afirma_mounts+=(--ro-bind "$1" "$1")
    fi
}
if [[ ${DISPLAY:-} =~ ^(unix)?:([0-9]+)(\.[0-9]+)?$ ]]; then
    afirma_socket "/tmp/.X11-unix/X${BASH_REMATCH[2]}"
fi
afirma_runtime=${XDG_RUNTIME_DIR:-/run/user/$UID}
afirma_socket "$afirma_runtime/${WAYLAND_DISPLAY:-wayland-0}"
afirma_socket "$afirma_runtime/bus"
if [[ ${DBUS_SESSION_BUS_ADDRESS:-} == unix:path=/* ]]; then
    afirma_bus=${DBUS_SESSION_BUS_ADDRESS#unix:path=}
    afirma_socket "${afirma_bus%%,*}"
fi
afirma_socket /run/pcscd/pcscd.comm
afirma_socket /var/run/pcscd/pcscd.comm
afirma_socket "${PCSCLITE_CSOCK_NAME:-/run/pcscd/pcscd.comm}"

export FONTCONFIG_FILE='@FONTS@'
exec '@BWRAP@' --unshare-user --unshare-pid --new-session --die-with-parent \
    "${afirma_mounts[@]}" --chdir "$afirma_workdir" "$afirma_java_launcher" "$@"
