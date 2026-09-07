#!/bin/sh
# Install the reviewed mirror-only channel list; do not pull or reconfigure.
set -eu
if [ "$(id -u)" != 0 ]; then
    echo "Run this script through sudo or an authenticated root terminal." >&2
    exit 1
fi
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
channel_source="$script_dir/channels-primary.scm.in"
channel_target=/root/.config/guix/channels.scm
test -r "$channel_source"
if [ -L "$channel_target" ]; then
    echo "Root channels.scm is a symlink; inspect its owner before replacing it." >&2
    exit 1
fi
if [ ! -d /root/.config/guix ]; then
    install -d -m 700 /root/.config/guix
fi
if [ -e "$channel_target" ]; then
    backup_dir=$(mktemp -d /root/.config/guix/channel-migration-backup.XXXXXX)
    cp -a -- "$channel_target" "$backup_dir/channels.scm"
    echo "Previous root configuration preserved in $backup_dir/channels.scm"
fi
install -m 644 -- "$channel_source" "$channel_target"
echo "Installed $channel_target; root Guix has not been pulled or reconfigured."
