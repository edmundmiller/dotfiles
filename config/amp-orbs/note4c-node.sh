#!/usr/bin/env bash
# Root-only udev helper. Export one identity-checked node, never a USB bus.
set -euo pipefail
[[ $# == 3 && $2 =~ ^[0-9]+$ && $3 =~ ^[0-9]+$ ]]
directory=/dev/amp-note4c-port
node=$directory/serial
exec 9>/run/lock/amp-note4c-node.lock
flock -x 9
case "$1" in
  add)
    usb=$(readlink -e "/sys/dev/char/$2:$3/device/..")
    [[ $(cat "$usb/idVendor") == 303a &&
      $(cat "$usb/idProduct") == 1001 &&
      $(cat "$usb/serial") == 80:45:6B:37:55:E8 ]]
    # Never replace this directory: existing container binds must see updates.
    install -d -o root -g amp-orbs -m 0750 "$directory"
    rm -f -- "$node"
    mknod -m 0660 "$node" c "$2" "$3"
    chown root:amp-orbs "$node"
    ;;
  remove)
    # A delayed remove must not unlink a newer enumeration with another minor.
    if [[ -c $node && $(stat -c '%t:%T' "$node") == "$(printf '%x:%x' "$2" "$3")" ]]; then
      rm -- "$node"
    fi
    ;;
  *) exit 1 ;;
esac
