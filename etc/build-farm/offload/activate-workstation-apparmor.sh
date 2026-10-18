#!/bin/sh
# Runtime bridge until the next manually initiated Guix System reconfigure.
set -eu

case "${1:-}" in
  --check) check_only=1 ;;
  '') check_only=0 ;;
  *) printf '%s\n' 'Usage: activate-workstation-apparmor.sh [--check]' >&2; exit 1 ;;
esac
if [ "$check_only" -eq 0 ] && [ "$(id -u)" -ne 0 ]; then
  printf '%s\n' 'Run as root; no password is read by this script.' >&2
  exit 1
fi

base=/run/current-system/profile/etc/apparmor.d
profile=$base/guix-daemon
patch_file=/home/berkeley/guix-config/predator-helios-intel/apparmor/guix-daemon-offload.patch
real_profile=$(readlink -f "$profile")
stage=$(mktemp -d /var/tmp/guix-offload-apparmor.XXXXXXXX)
cleanup() {
  rm -f -- "$stage/guix-daemon"
  rmdir -- "$stage"
}
trap cleanup EXIT HUP INT TERM

test -f "$real_profile"
case "$real_profile" in
  /gnu/store/*/etc/apparmor.d/guix-daemon) ;;
  *) printf '%s\n' 'Unexpected Guix daemon profile path.' >&2; exit 1 ;;
esac
test -f "$patch_file"
patch --batch --forward -o "$stage/guix-daemon" "$real_profile" "$patch_file"
apparmor_parser -Q -K -T -b "$base" -I /etc/apparmor.d -I "$base" "$stage/guix-daemon"
if [ "$check_only" -eq 1 ]; then
  printf '%s\n' 'Patch and AppArmor syntax verified; profile not loaded.'
  exit 0
fi
apparmor_parser -r -K -T -b "$base" -I /etc/apparmor.d -I "$base" "$stage/guix-daemon"
printf '%s\n' 'Guix daemon offload AppArmor rules loaded for the running system.'
