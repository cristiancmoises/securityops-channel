#!/bin/sh
set -eu

# Run once as root on the build workstation. With sudo, inputs default to the
# invoking user's home. For a root login, pass the operator home as an argument.
# This does not run a Guix System or Home reconfigure.
if [ "$(id -u)" -ne 0 ]; then
  printf '%s\n' 'Run this script as root on the build workstation.' >&2
  exit 1
fi

if [ "$#" -gt 1 ]; then
  printf 'Usage: %s [operator-home]\n' "$0" >&2
  exit 2
fi
operator_home=${1:-}
if [ "$#" -eq 0 ] && [ -n "${SUDO_UID:-}" ]; then
  operator_home=$(getent passwd "$SUDO_UID" | cut -d: -f6)
fi
case "$operator_home" in
  /*) ;;
  *) printf '%s\n' 'Pass an absolute operator home or invoke with sudo.' >&2; exit 2 ;;
esac
script_dir=$(CDPATH= cd -P -- "$(dirname -- "$0")" && pwd)
private_source=$operator_home/.ssh/securityops-guix-offload-ct126
machine_source=$script_dir/machines-ct126.scm
builder_public=$operator_home/ct126-guix-signing-key.pub
private_target=/root/.ssh/securityops-guix-offload-ct126
machine_target=/etc/guix/machines.scm
machine_backup=/etc/guix/machines.scm.before-ct126-privacy-template
guix=/var/guix/profiles/per-user/root/current-guix/bin/guix
machine_rendered=

cleanup() {
  if [ -n "$machine_rendered" ]; then
    rm -f -- "$machine_rendered"
  fi
}
trap cleanup EXIT HUP INT TERM

for source in "$private_source" "$machine_source" "$builder_public"; do
  if [ ! -f "$source" ] || [ -L "$source" ]; then
    printf 'Missing or symlinked input: %s\n' "$source" >&2
    exit 1
  fi
done
if [ -L /root/.ssh ] || [ "$(stat -c %a "$private_source")" != 600 ]; then
  printf '%s\n' 'Unsafe SSH key permissions or root SSH directory.' >&2
  exit 1
fi
if [ "$(sha256sum "$machine_source" | cut -d ' ' -f 1)" != 2bfd1d848e1dbe72f63d27c5089b5fd7415ffeb3ac240dc740d1ad84c7d9d9b7 ]; then
  printf '%s\n' 'The reviewed build-machine configuration changed.' >&2
  exit 1
fi

builder_host=${SECURITYOPS_CT126_HOST:-}
if [ -z "$builder_host" ] && [ -f "$machine_target" ] && [ ! -L "$machine_target" ]; then
  builder_host=$(sed -n \
    -e 's/^[[:space:]]*(name "\([A-Za-z0-9.:-]*\)")[[:space:]]*$/\1/p' \
    -e 's/.*SECURITYOPS_CT126_HOST") "\([A-Za-z0-9.:-]*\)".*/\1/p' \
    "$machine_target" | sed -n '1p')
fi
case "$builder_host" in
  '')
    printf '%s\n' 'Set SECURITYOPS_CT126_HOST to the CT126 address or hostname.' >&2
    exit 1
    ;;
  *[!A-Za-z0-9.:-]*)
    printf '%s\n' 'SECURITYOPS_CT126_HOST contains unsupported characters.' >&2
    exit 1
    ;;
esac
machine_rendered=$(mktemp /var/tmp/securityops-ct126-machines.XXXXXXXX)
sed "s/ct126\\.invalid/$builder_host/g" "$machine_source" > "$machine_rendered"

if [ "$(sha256sum "$builder_public" | cut -d ' ' -f 1)" != e63ea7ed2b313a76169fd1af983170a4725fb7a2bd6783814b09f1f6c5731101 ]; then
  printf '%s\n' 'The CT126 public signing key changed.' >&2
  exit 1
fi
if [ -e "$private_target" ] && ! cmp -s "$private_source" "$private_target"; then
  printf 'Refusing to replace existing key: %s\n' "$private_target" >&2
  exit 1
fi
machine_matches=false
if [ -e "$machine_target" ] || [ -L "$machine_target" ]; then
  if [ ! -f "$machine_target" ] || [ -L "$machine_target" ]; then
    printf '%s\n' 'Expected a regular, non-symlinked machine configuration.' >&2
    exit 1
  fi
  if cmp -s "$machine_rendered" "$machine_target"; then
    machine_matches=true
  elif [ "$(head -n 1 "$machine_target" | sha256sum | cut -d ' ' -f 1)" = "520dd1e7680c624999e0a96c258d4216f46e77eeff1cea34ca3c5908d50e52ef" ]; then
    # A previous release rendered a different first comment. Keep that file
    # only when its entire body matches the newly rendered configuration.
    if { head -n 1 "$machine_target"; tail -n +2 "$machine_rendered"; } | cmp -s - "$machine_target"; then
      machine_matches=true
    fi
  fi
fi
if [ -e "$machine_target" ] && [ "$machine_matches" = false ]; then
  # Only migrate the exact earlier reviewed template.  Preserve it for rollback.
  case "$(sha256sum "$machine_target" | cut -d ' ' -f 1)" in
    ff51ae5a0ef9ba646b2acd78257ef498b6773c12ed047c348d6903cdcbdbbbcd|d40e823cf56b01c47599648a52acd5a9c0ea9128aefa5599f6eee492df1d2f4e|8c89cbe355434ea92cc5ba32dadb9791d00d286969bd5f921e564ef464518eea|374434ac7a3cb8d72dc45ed6a1d73a6ba1d663af2c2f782f0e24670102718032) ;;
    *)
      printf 'Refusing to replace unrecognized configuration: %s\n' "$machine_target" >&2
      exit 1
      ;;
  esac
  if [ -e "$machine_backup" ]; then
    printf '%s\n' 'Refusing to replace an existing offload backup.' >&2
    exit 1
  fi
fi

umask 077
install -d -m 700 /root/.ssh
if [ ! -e "$private_target" ]; then
  install -m 600 "$private_source" "$private_target"
fi
if [ -e "$machine_target" ] && [ "$machine_matches" = false ]; then
  install -m 600 "$machine_target" "$machine_backup"
  machine_tmp=$(mktemp /etc/guix/.machines.scm.XXXXXXXX)
  install -m 600 "$machine_rendered" "$machine_tmp"
  mv -- "$machine_tmp" "$machine_target"
elif [ ! -e "$machine_target" ]; then
  install -m 600 "$machine_rendered" "$machine_target"
fi

"$guix" archive --authorize < "$builder_public"
"$guix" offload test "$machine_target"
"$guix" offload status
printf '%s\n' 'CT126 offload is configured; no System or Home reconfigure was run.'
