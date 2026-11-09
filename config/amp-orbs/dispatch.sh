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

case "$ORB_OPERATION" in
  spawn)
    : "${ORB_TOKEN:?missing ORB_TOKEN}" "${ORB_IMAGE:?missing ORB_IMAGE}"
    [[ -z ${ORB_TYPE:-} || $ORB_TYPE == small ]] || fail "only the small type is supported"
    # Serialize admission as well as creation. Resuming the same orb is allowed.
    running_orbs=$(podman ps --filter "label=$label=true" --format '{{.Names}}')
    while IFS= read -r running; do
      [[ -z $running || $running == "$ORB_ID" ]] || fail "pilot already has an active orb"
    done <<<"$running_orbs"
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
        --platform linux/amd64 --init --cpus 2 --memory 3g --memory-swap 3g \
        --pids-limit 512 --shm-size 1g --entrypoint sleep "$image" infinity
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
