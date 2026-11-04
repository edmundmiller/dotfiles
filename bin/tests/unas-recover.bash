#!/usr/bin/env bash
# Real Nix profiles and bounded filesystems; hardware and installation are isolated.
set -euo pipefail

repo=$(realpath "$(dirname "${BASH_SOURCE[0]}")/../..")
if [[ ${1:-} != --inside ]]; then
  work=$(mktemp -d)
  trap 'chmod -R u+w "$work"; rm -rf "$work"' EXIT
  test_path=
  for tool in bash cat realpath find sort head cp stat tar gzip grep sed nix-env nix-store \
    python3 hostname readlink sync mkdir chmod rm truncate dirname; do
    test_path+="$(dirname "$(realpath "$(command -v "$tool")")"):"
  done
  if [[ $# == 0 ]]; then
    set -- first-use full-esp shared-payloads retained-payloads existing-payloads \
      temporary-headroom generation-limit unsupported-initrd failed-install
  fi
  for test_case in "$@"; do
    mkdir -p "$work/$test_case/root/boot"
    # Share only unshare's fresh network namespace, without configuring loopback.
    unshare --user --map-root-user --net -- \
      bwrap --unshare-all --share-net --uid 0 --gid 0 --cap-add CAP_SYS_CHROOT --hostname unas-rescue \
      --ro-bind /nix/store /nix/store --ro-bind "$repo" "$repo" \
      --ro-bind "$(command -v bash)" /bin/sh \
      --ro-bind /etc/passwd /etc/passwd --ro-bind /etc/group /etc/group \
      --bind "$work/$test_case" /tmp --dir /sys/firmware/efi --dev /dev --proc /proc \
      --size 67108864 --tmpfs /tmp/root/boot --chdir "$repo" \
      --setenv HOME /tmp/home --setenv TMPDIR /tmp --setenv PATH "${test_path%:}" \
      --setenv USER root --setenv LOGNAME root \
      -- bash "$repo/bin/tests/unas-recover.bash" --inside "$test_case"
  done
  exit
fi

scenario=$2
python3 -c 'import socket; assert {name for _, name in socket.if_nameindex()} == {"lo"}, "test networking is not isolated"'
mkdir -p /tmp/{home,bin} /tmp/root/{etc/ssh,home/emiller/.ssh,nix/var/nix/profiles}
export NIX_CONFIG=$'build-users-group =\nexperimental-features = nix-command flakes'
export PATH="/tmp/bin:$PATH"
printf fixture > /tmp/root/etc/ssh/ssh_host_ed25519_key
printf fixture > /tmp/root/home/emiller/.ssh/id_ed25519

cat > /tmp/bin/zpool <<'SH'
#!/usr/bin/env bash
case "$*" in
  'get -H -o value guid zroot') echo 17576335980796613953 ;;
  'get -H -o value guid datatank') echo 5553631198264591155 ;;
  'get -H -o value readonly '*) echo off ;;
  'get -H -o value health '*) echo ONLINE ;;
  *) exit 1 ;;
esac
SH
cat > /tmp/bin/zfs <<'SH'
#!/usr/bin/env bash
case "$1" in
  list) exit 0 ;;
  snapshot) printf '%s\n' "$*" >> /tmp/operations ;;
  *) exit 1 ;;
esac
SH
cat > /tmp/bin/findmnt <<'SH'
#!/usr/bin/env bash
case "$5" in
  OPTIONS) echo rw ;;
  FSTYPE) if [[ $3 == /tmp/root/boot ]]; then echo vfat; else echo zfs; fi ;;
  SOURCE)
    case "${3#/tmp/root}" in
      /) echo zroot/system/root ;;
      /nix) echo zroot/local/nix ;;
      /var) echo zroot/system/var ;;
      /home/*) echo "zroot/user/home/${3##*/}" ;;
      /boot) echo /dev/fixture-esp ;;
      *) exit 1 ;;
    esac ;;
  *) exit 1 ;;
esac
SH
cat > /tmp/bin/blkid <<'SH'
#!/usr/bin/env bash
echo da97d5b7-2689-4895-8934-1f1d3ca8a5ec
SH
cat > /tmp/bin/date <<'SH'
#!/usr/bin/env bash
count=$(cat /tmp/clock 2>/dev/null || echo 0)
echo $((count + 1)) > /tmp/clock
printf '20261104T0101%02dZ\n' "$count"
SH
cat > /tmp/bin/nixos-install <<'SH'
#!/usr/bin/env bash
set -euo pipefail
# Exercise real system-profile selection, but never execute a bootloader or activation.
echo install >> /tmp/operations
nix-env --store /tmp/root -p /tmp/root/nix/var/nix/profiles/system --set "$4"
[[ ${FAIL_INSTALLER:-0} == 0 ]]
SH
sed -i "1c#!$(command -v bash)" /tmp/bin/*
chmod +x /tmp/bin/*

fixture_system() {
  local name=$1 initrd_size=$2 kernel initrd tree
  mkdir -p "/tmp/linux-$name" "/tmp/initrd-$name" "/tmp/nixos-system-unas-$name"/{bin,etc}
  truncate -s 1048576 "/tmp/linux-$name/bzImage"
  truncate -s "$initrd_size" "/tmp/initrd-$name/initrd"
  kernel=$(nix-store --store /tmp/root --add "/tmp/linux-$name")/bzImage
  initrd=$(nix-store --store /tmp/root --add "/tmp/initrd-$name")/initrd
  tree="/tmp/nixos-system-unas-$name"
  printf '#!/bin/sh\n' > "$tree/bin/switch-to-configuration"
  chmod +x "$tree/bin/switch-to-configuration"
  printf '{"org.nixos.bootspec.v1":{"kernel":"%s","initrd":"%s","initrdSecrets":%s},"org.nixos.specialisation.v1":{}}\n' \
    "$kernel" "$initrd" "${3:-null}" > "$tree/boot.json"
  printf '{"configurationLimit":2,"efiBinary":"%s","extraFiles":{},"extraEntries":{},"esp":"/boot","xbootldr":null}\n' \
    "$kernel" > "$tree/etc/unas-recovery-boot.json"
  nix-store --store /tmp/root --add "$tree"
}

A=$(fixture_system A 2097152)
B=$(fixture_system B 4194304)
C=$(fixture_system C 3145728)
profiles=/tmp/root/nix/var/nix/profiles
nix-env --store /tmp/root -p "$profiles/system" --set "$A"
recover() { bash "$repo/bin/unas-recover" /tmp/root "$1" > /tmp/output 2>&1; }
profile_system() { readlink "$(dirname "$1")/$(readlink "$1")"; }
refusal_without_writes() {
  local before
  before=$(find /tmp/root -type l -printf '%p %l\n' | sort)
  if recover "$B"; then cat /tmp/output; echo 'unsafe recovery was accepted' >&2; exit 1; fi
  grep -F 'UNAS recovery refused: ESP' /tmp/output
  [[ ! -e /tmp/operations && ! -e /tmp/root/var/lib/unas-recovery ]]
  [[ $before == "$(find /tmp/root -type l -printf '%p %l\n' | sort)" ]]
}

case "$scenario" in
  first-use)
    [[ ! -d $profiles/system-profiles ]]
    recover "$B" || { cat /tmp/output; exit 1; }
    [[ $(profile_system "$profiles/system-profiles/pre-recovery") == "$A" ]]
    [[ $(profile_system "$profiles/system") == "$B" ]]
    tar -tzf /tmp/root/var/lib/unas-recovery/*/esp.tar.gz >/dev/null
    ;;
  full-esp)
    mkdir -p "$profiles/system-profiles"
    head -c 54525952 /dev/zero > /tmp/root/boot/occupied
    refusal_without_writes
    [[ $(stat -c %s /tmp/root/boot/occupied) == 54525952 ]]
    ;;
  shared-payloads)
    mkdir -p "$profiles/system-profiles"
    for profile in one two three four five six; do
      nix-env --store /tmp/root -p "$profiles/system-profiles/$profile" --set "$A"
    done
    head -c 33554432 /dev/zero > /tmp/root/boot/occupied
    recover "$B" || { cat /tmp/output; exit 1; }
    [[ $(profile_system "$profiles/system") == "$B" ]]
    ;;
  retained-payloads)
    D=$(fixture_system D 16777216)
    mkdir -p "$profiles/system-profiles"
    nix-env --store /tmp/root -p "$profiles/system-profiles/older-rollback" --set "$D"
    head -c 29360128 /dev/zero > /tmp/root/boot/occupied
    refusal_without_writes
    [[ $(profile_system "$profiles/system-profiles/older-rollback") == "$D" ]]
    ;;
  existing-payloads)
    # Only this initrd is already on the ESP. Charging its bytes again refuses
    # a recovery that fits, whereas ignoring retained A also passes the other tests.
    source=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["org.nixos.bootspec.v1"]["initrd"])' "/tmp/root$B/boot.json")
    mkdir -p /tmp/root/boot/EFI/nixos
    directory=${source%/*}
    cp "/tmp/root$source" "/tmp/root/boot/EFI/nixos/${directory##*/}-initrd.efi"
    head -c 35651584 /dev/zero > /tmp/root/boot/occupied
    recover "$B" || { cat /tmp/output; exit 1; }
    [[ $(profile_system "$profiles/system") == "$B" ]]
    ;;
  temporary-headroom)
    mkdir -p "$profiles/system-profiles"
    head -c 37748736 /dev/zero > /tmp/root/boot/occupied
    refusal_without_writes
    ;;
  generation-limit)
    D=$(fixture_system D 16777216)
    mkdir -p "$profiles/system-profiles"
    for system in "$D" "$A" "$C"; do
      nix-env --store /tmp/root -p "$profiles/system-profiles/limited" --set "$system"
    done
    head -c 29360128 /dev/zero > /tmp/root/boot/occupied
    recover "$B" || { cat /tmp/output; exit 1; }
    [[ $(profile_system "$profiles/system") == "$B" ]]
    ;;
  unsupported-initrd)
    B=$(fixture_system secrets 1048576 '"/nix/store/unbounded-secret-appender"')
    refusal_without_writes
    grep -F 'initrd secret appenders' /tmp/output
    ;;
  failed-install)
    mkdir -p "$profiles/system-profiles"
    recover "$B" || { cat /tmp/output; exit 1; }
    export FAIL_INSTALLER=1
    if recover "$C"; then echo 'installer failure was hidden' >&2; exit 1; fi
    [[ $(profile_system "$profiles/system-profiles/pre-recovery") == "$A" ]]
    mapfile -t retained < <(find "$profiles/system-profiles" -type l -name 'pre-recovery-20*' ! -name '*-link')
    [[ ${#retained[@]} == 1 && $(profile_system "${retained[0]}") == "$B" ]]
    orphan=$(fixture_system orphan 1048576)
    nix-env --store /tmp/root -p "$profiles/system" --delete-generations old
    nix-store --store /tmp/root --gc
    [[ -d /tmp/root$A && -d /tmp/root$B && -d /tmp/root$C ]]
    [[ ! -e /tmp/root$orphan ]]
    ;;
  *) echo "unknown scenario: $scenario" >&2; exit 1 ;;
esac
echo "PASS: $scenario"
