#!/usr/bin/env bash
# Prepared pilot only. Run under a dedicated rootless Podman account.
set -euo pipefail
umask 077

fail() {
  echo "amp-orbs: $*" >&2
  exit 1
}

# Podman starts long-lived conmon/fuse-overlayfs children. Only this shell owns
# the lifecycle lock; its children must not retain the descriptor after exit.
podman() {
  command podman "$@" 9>&-
}

# NUC keeps its existing two-orb ceiling; NAS opts into one via its user unit.
max_active=${AMP_ORB_MAX_ACTIVE:-2}
[[ $max_active == 1 || $max_active == 2 ]] || fail "invalid active orb limit"

[[ ${ORB_ID:-} =~ ^amp-[a-zA-Z0-9_.-]+$ ]] || fail "invalid ORB_ID"
case "${ORB_OPERATION:-}" in spawn | pause | delete) ;; *) fail "invalid operation" ;; esac
[[ $(id -u) != 0 ]] || fail "run as a dedicated non-root account"
[[ $(podman info --format '{{.Host.Security.Rootless}}') == true ]] || fail "rootless Podman required"

state="${XDG_STATE_HOME:-$HOME/.local/state}/amp-orbs"
mkdir -p "$state"
exec 9>"$state/dispatch.lock"
flock -x -w 240 9

label=io.dotfiles.amp-orb
exists=false
if podman container exists "$ORB_ID"; then
  exists=true
  [[ $(podman inspect --format '{{index .Config.Labels "io.dotfiles.amp-orb"}}' "$ORB_ID") == true ]] || fail "container belongs to another workload"
else
  status=$?
  [[ $status == 1 ]] || fail "cannot inspect container"
fi

check_space() {
  local root available
  root=$(podman info --format '{{.Store.GraphRoot}}')
  available=$(df -Pk "$root" | awk 'END {print $4}')
  [[ $available =~ ^[0-9]+$ ]] || fail "cannot determine free space"
  ((available >= 20 * 1024 * 1024)) || fail "less than 20 GiB free in container storage"
}

check_capacity() {
  local running_orbs running memory cpu extra used available cpus
  local count=1 assigned_memory=$((2 * 1024 * 1024 * 1024)) assigned_cpu=2000000000
  # Repeated spawn of an already running orb allocates no additional resources.
  if [[ $target_running == true ]]; then return; fi
  local remaining=$assigned_memory
  # Include every running container in this dedicated account, not just labels.
  running_orbs=$(podman ps --format '{{.Names}}')
  while IFS= read -r running; do
    [[ -n $running ]] || continue
    [[ $(podman inspect --format '{{index .Config.Labels "io.dotfiles.amp-orb"}}' "$running") == true ]] || fail "unmanaged container in provider account"
    read -r memory cpu extra <<<"$(podman inspect --format '{{.HostConfig.Memory}} {{.HostConfig.NanoCpus}}' "$running")"
    [[ $memory =~ ^[1-9][0-9]*$ && $cpu =~ ^[1-9][0-9]*$ && -z $extra ]] || fail "cannot determine running orb limits"
    # Use the raw integer statistic, not the human-formatted MemUsage value.
    used=$(podman stats --no-stream --format '{{.ContainerStats.MemUsage}}' "$running")
    [[ $used =~ ^[0-9]+$ ]] && ((used <= memory)) || fail "cannot determine running orb memory usage"
    count=$((count + 1))
    assigned_memory=$((assigned_memory + memory))
    assigned_cpu=$((assigned_cpu + cpu))
    remaining=$((remaining + memory - used))
  done <<<"$running_orbs"
  ((count <= max_active)) || fail "provider already has $max_active active orbs"
  # Existing running 3-GiB orbs stay intact; stopped orbs adopt 2 GiB on resume.
  ((assigned_memory <= 5 * 1024 * 1024 * 1024 && assigned_cpu <= 4000000000)) || fail "aggregate orb limits exceed 5 GiB or 4 CPUs"
  cpus=$(getconf _NPROCESSORS_ONLN)
  [[ $cpus =~ ^[0-9]+$ ]] && ((assigned_cpu <= (cpus - 4) * 1000000000)) || fail "less than four CPUs reserved for the host"
  available=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
  [[ $available =~ ^[0-9]+$ ]] || fail "cannot determine available host memory"
  # MemAvailable already excludes current usage. Reserve all remaining container
  # allowances as well as 2 GiB for host services; low current use is not spare RAM.
  ((available * 1024 >= remaining + 2 * 1024 * 1024 * 1024)) || fail "insufficient memory for orb limits plus 2 GiB host headroom"
}

case "$ORB_OPERATION" in
  spawn)
    : "${ORB_TOKEN:?missing ORB_TOKEN}" "${ORB_IMAGE:?missing ORB_IMAGE}"
    [[ -z ${ORB_TYPE:-} || $ORB_TYPE == small ]] || fail "only the small type is supported"
    target_running=false
    if [[ $exists == true ]]; then
      target_running=$(podman inspect --format '{{.State.Running}}' "$ORB_ID")
      [[ $target_running == true || $target_running == false ]] || fail "cannot determine orb state"
    fi
    # The lifecycle lock also serializes admission, including resume.
    check_capacity
    check_space
    if [[ $exists == false ]]; then
      image=$ORB_IMAGE
      if [[ -n ${ORB_SNAPSHOT_ID:-} ]]; then
        [[ $ORB_SNAPSHOT_ID != -* ]] || fail "invalid snapshot name"
        if podman image exists "$ORB_SNAPSHOT_ID"; then
          image=$ORB_SNAPSHOT_ID
        else
          status=$?
          [[ $status == 1 ]] || fail "cannot inspect snapshot"
        fi
      fi
      [[ $image != -* ]] || fail "invalid image"
      podman create --name "$ORB_ID" --label "$label=true" \
        --platform linux/amd64 --init --cpus 2 --memory 2g --memory-swap 2g \
        --pids-limit 512 --shm-size 1g --entrypoint sleep "$image" infinity
    elif [[ $target_running == false ]]; then
      # Apply the small type's current limits before restart, never during work.
      # Podman update changes resource configuration without replacing the disk.
      podman update --cpus 2 --memory 2g --memory-swap 2g "$ORB_ID"
    fi
    podman start "$ORB_ID"
    # Do not store the short-lived token in container configuration or images.
    # An unset AMP_URL must not inherit a value saved in a snapshot.
    export AMP_URL="${AMP_URL:-https://ampcode.com}"
    podman exec --detach --env ORB_TOKEN --env AMP_URL "$ORB_ID" amp orb bootstrap
    ;;
  pause)
    if [[ $exists == true ]]; then
      podman stop --time 10 "$ORB_ID"
      if [[ -n ${ORB_SNAPSHOT_ID:-} ]]; then
        [[ $ORB_SNAPSHOT_ID != -* ]] || fail "invalid snapshot name"
        check_space
        podman commit "$ORB_ID" "$ORB_SNAPSHOT_ID"
      fi
    fi
    ;;
  delete)
    if [[ $exists == true ]]; then podman rm --force "$ORB_ID"; fi
    ;;
esac
