#!/usr/bin/env bash
# Run by the existing exact-revision NUC deployment workflow, not an orb SSH session.
set -euo pipefail

printf 'hostname=%s\n' "$(hostname)"
uname -a
[[ $(hostname) == nuc ]] || { echo 'Wrong host' >&2; exit 1; }

case "${1:-}" in
  preflight)
    cpus=$(getconf _NPROCESSORS_ONLN)
    available_kib=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
    free_kib=$(df -Pk /var/lib | awk 'END {print $4}')
    printf 'CPUs=%s MemAvailableKiB=%s LocalFreeKiB=%s\n' "$cpus" "$available_kib" "$free_kib"
    printf 'Load=%s\n' "$(cat /proc/loadavg)"
    [[ $(stat -fc %T /sys/fs/cgroup) == cgroup2fs ]]
    # Reserve 2 GiB for the host above the pilot's 3 GiB memory limit.
    if ! (( cpus >= 4 && available_kib >= 5 * 1024 * 1024 && free_kib >= 100 * 1024 * 1024 )); then
      echo 'FAIL: pilot requires 4 CPUs, 5 GiB available RAM and 100 GiB free local storage' >&2
      exit 1
    fi
    echo 'PASS: live NUC pilot capacity preflight'
    ;;
  verify)
    home=/var/lib/amp-orbs
    uid=$(id -u amp-orbs)
    sudo -n systemctl is-active amp-orb-storage.service
    sudo -n test -x "$home/.amp/bin/amp"
    sudo -n zfs get -Hp -o name,property,value quota,used zroot/system/amp-orbs
    # Run only under the dedicated account and its delegated user manager.
    sudo -n -u amp-orbs env HOME="$home" XDG_RUNTIME_DIR="/run/user/$uid" \
      DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
      CONTAINERS_STORAGE_CONF=/etc/amp-orbs/storage.conf bash -s <<'SMOKE'
    set -euo pipefail
    cd "$HOME"
    test "$(podman info --format '{{.Host.Security.Rootless}}')" = true
    mkdir -p "$HOME/.local/state/amp-orbs"
    exec 9>"$HOME/.local/state/amp-orbs/dispatch.lock"
    flock -x -w 240 9
    running=$(podman ps --format '{{.Names}}')
    if test -n "$running"; then
      echo 'Refusing smoke tests while this account has running containers' >&2
      exit 1
    fi
    name="amp-pilot-smoke-$(date +%s)-$$"
    clone="$name-clone"
    snapshot="localhost/$name:snapshot"
    cleanup() {
      podman rm --force --ignore "$name" "$clone" >/dev/null
      podman image rm "$snapshot" >/dev/null 2>&1 || true
    }
    trap cleanup EXIT
    image=us-central1-docker.pkg.dev/amp-prod-0/amp-orb/amp-orb:latest
    podman run --detach --init --name "$name" --cpus 2 --memory 3g \
      --memory-swap 3g --pids-limit 512 --shm-size 1g --entrypoint sleep "$image" infinity
    podman exec "$name" sh -c 'printf live-pilot-sentinel > /home/user/pilot-sentinel'
    test "$(podman exec "$name" cat /sys/fs/cgroup/memory.max)" = 3221225472
    test "$(podman exec "$name" cat /sys/fs/cgroup/cpu.max)" = '200000 100000'
    podman stop --time 10 "$name"
    podman start "$name"
    test "$(podman exec "$name" cat /home/user/pilot-sentinel)" = live-pilot-sentinel
    podman stop --time 10 "$name"
    podman commit "$name" "$snapshot"
    podman run --detach --init --name "$clone" --cpus 2 --memory 3g \
      --memory-swap 3g --pids-limit 512 --shm-size 1g --entrypoint sleep "$snapshot" infinity
    test "$(podman exec "$clone" cat /home/user/pilot-sentinel)" = live-pilot-sentinel
    echo 'PASS: live rootless image, CPU/memory limits, disk resume and snapshot clone'
    echo 'This is a container-backend smoke test, not an Amp thread/provider end-to-end test.'
    if test -e "$HOME/.config/amp/orb-provider-ready"; then
      systemctl --user start amp-orb-provider.service
      systemctl --user is-active amp-orb-provider.service
    else
      echo 'PENDING: dedicated Amp sign-in and nuc-orbs provider registration on NUC'
    fi
SMOKE
    ;;
  diagnostics)
    home=/var/lib/amp-orbs
    uid=$(id -u amp-orbs)
    printf 'configurationRevision=%s\n' "$(nixos-version --configuration-revision)"
    # Print only selected state fields, never inspect container environments.
    sudo -n -u amp-orbs env HOME="$home" XDG_RUNTIME_DIR="/run/user/$uid" \
      DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
      CONTAINERS_STORAGE_CONF=/etc/amp-orbs/storage.conf bash -s <<'DIAGNOSTICS'
    set -euo pipefail
    cd "$HOME"
    systemctl --user show amp-orb-provider.service -p ActiveState -p SubState -p MainPID
    containers=$(podman ps -a --filter label=io.dotfiles.amp-orb=true --format '{{.Names}}')
    while IFS= read -r container; do
      test -n "$container" || continue
      podman inspect --format '{{.Name}} running={{.State.Running}} started={{.State.StartedAt}} finished={{.State.FinishedAt}}' "$container"
    done <<<"$containers"
DIAGNOSTICS
    # Amp redacts known token formats and this account's stored credentials
    # before journal text reaches the workflow. Do not use tracing or raw logs.
    sudo -n journalctl --no-pager --since '-30 min' -n 120 -o short-iso \
      _UID="$uid" _SYSTEMD_USER_UNIT=amp-orb-provider.service |
      sudo -n -u amp-orbs env HOME="$home" bash -c 'cd "$HOME"; exec .amp/bin/amp orb redact-output'
    ;;
  *) echo 'Usage: amp-orb-pilot.sh preflight|verify|diagnostics' >&2; exit 2 ;;
esac
