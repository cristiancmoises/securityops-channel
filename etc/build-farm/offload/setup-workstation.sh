#!/bin/sh
set -eu

# Run once as root on predator-helios-intel after reviewing this file.
# This does not run a Guix System or Home reconfigure.
if [ "$(id -u)" -ne 0 ]; then
  printf '%s\n' 'Run this script with sudo on predator-helios-intel.' >&2
  exit 1
fi

private_source=/home/berkeley/.ssh/securityops-guix-offload-ct126
machine_source=/home/berkeley/securityops-channel/.worktrees/build-farm/etc/build-farm/offload/machines-ct126.scm
builder_public=/home/berkeley/ct126-guix-signing-key.pub
private_target=/root/.ssh/securityops-guix-offload-ct126
machine_target=/etc/guix/machines.scm
guix=/var/guix/profiles/per-user/root/current-guix/bin/guix

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
if [ "$(sha256sum "$machine_source" | cut -d ' ' -f 1)" != 374434ac7a3cb8d72dc45ed6a1d73a6ba1d663af2c2f782f0e24670102718032 ]; then
  printf '%s\n' 'The reviewed build-machine configuration changed.' >&2
  exit 1
fi
if [ "$(sha256sum "$builder_public" | cut -d ' ' -f 1)" != e63ea7ed2b313a76169fd1af983170a4725fb7a2bd6783814b09f1f6c5731101 ]; then
  printf '%s\n' 'The CT126 public signing key changed.' >&2
  exit 1
fi
if [ -e "$private_target" ] && ! cmp -s "$private_source" "$private_target"; then
  printf 'Refusing to replace existing key: %s\n' "$private_target" >&2
  exit 1
fi
if [ -e "$machine_target" ] && ! cmp -s "$machine_source" "$machine_target"; then
  # Only migrate the exact earlier reviewed template.  Preserve it for rollback.
  if [ -L "$machine_target" ]; then
    printf 'Refusing to replace symlinked configuration: %s\n' "$machine_target" >&2
    exit 1
  fi
  case "$(sha256sum "$machine_target" | cut -d ' ' -f 1)" in
    d40e823cf56b01c47599648a52acd5a9c0ea9128aefa5599f6eee492df1d2f4e|8c89cbe355434ea92cc5ba32dadb9791d00d286969bd5f921e564ef464518eea) ;;
    *)
      printf 'Refusing to replace unrecognized configuration: %s\n' "$machine_target" >&2
      exit 1
      ;;
  esac
  if [ -e /etc/guix/machines.scm.before-import ]; then
    printf '%s\n' 'Refusing to replace an existing offload backup.' >&2
    exit 1
  fi
fi

umask 077
install -d -m 700 /root/.ssh
if [ ! -e "$private_target" ]; then
  install -m 600 "$private_source" "$private_target"
fi
if [ -e "$machine_target" ] && ! cmp -s "$machine_source" "$machine_target"; then
  install -m 600 "$machine_target" /etc/guix/machines.scm.before-import
  machine_tmp=$(mktemp /etc/guix/.machines.scm.XXXXXXXX)
  install -m 600 "$machine_source" "$machine_tmp"
  mv -- "$machine_tmp" "$machine_target"
elif [ ! -e "$machine_target" ]; then
  install -m 600 "$machine_source" "$machine_target"
fi

"$guix" archive --authorize < "$builder_public"
"$guix" offload test "$machine_target"
"$guix" offload status
printf '%s\n' 'CT126 offload is configured; no System or Home reconfigure was run.'
