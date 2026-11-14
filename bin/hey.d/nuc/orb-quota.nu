#!/usr/bin/env -S nu --no-config-file
#MISE description="Raise the existing NUC orb storage quota to 175 GiB without restarting orbs"
use ../.lib/remote.nu *

def main [] {
  ^ssh -o BatchMode=yes -o ConnectTimeout=10 $NUC_HOST '
    set -eu
    printf "hostname=%s\n" "$(hostname)"
    uname -a
    test "$(hostname)" = nuc
    dataset=zroot/system/amp-orbs
    test "$(sudo -n zfs get -H -o value mountpoint "$dataset")" = /var/lib/amp-orbs
    test "$(sudo -n zfs get -H -o value mounted "$dataset")" = yes
    quota=$(sudo -n zfs get -Hp -o value quota "$dataset")
    case "$quota" in
      68719476736|103079215104|187904819200) ;;
      *) echo "Refusing to change an unexpected orb storage quota: $quota" >&2; exit 1 ;;
    esac
    sudo -n zfs set quota=175G "$dataset"
    test "$(sudo -n zfs get -Hp -o value quota "$dataset")" = 187904819200
    sudo -n zfs get -Hp -o name,property,value quota,used,available "$dataset"
    df -h /var/lib/amp-orbs
  '
}
