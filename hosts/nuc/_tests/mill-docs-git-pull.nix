{ nixosConfig, pkgs }:
let
  pullScript = nixosConfig.config.systemd.services.mill-docs-git-pull.serviceConfig.ExecStart;
  vaultPath = nixosConfig.config.systemd.services.mill-docs-git-pull.serviceConfig.WorkingDirectory;
  pointerGuardExpectedFailure = false;
  collisionGuardExpectedFailure = false;
  unmergedGuardExpectedFailure = false;
  serviceGuardExpectedFailure = false;
  fakeCurl = pkgs.writeShellScript "mill-docs-git-pull-test-curl" ''
    printf '%s\n' "$*" >> "''${CURL_CALL_LOG:?}"
  '';
  fakeGit = pkgs.writeShellScript "mill-docs-git-pull-test-git" ''
    case "''${1-}" in
      fetch)
        printf 'fetch\n' >> "''${GIT_CALL_LOG:?}"
        if [ "''${GIT_INJECT_CONFLICT:-false}" = true ]; then
          base_blob="$(${pkgs.git}/bin/git rev-parse HEAD:conflict.md)"
          ours_blob="$(printf 'injected local content\n' | ${pkgs.git}/bin/git hash-object -w --stdin)"
          ${pkgs.git}/bin/git update-index --force-remove conflict.md
          printf '100644 %s 1\tconflict.md\n100644 %s 2\tconflict.md\n' "$base_blob" "$ours_blob" \
            | ${pkgs.git}/bin/git update-index --index-info
        fi
        ;;
      pull)
        printf 'pull\n' >> "''${GIT_CALL_LOG:?}"
        exit 99
        ;;
      *)
        exec ${pkgs.git}/bin/git "$@"
        ;;
    esac
  '';
in
pkgs.runCommand "nuc-mill-docs-git-pull" { } ''
  guard_line="$(${pkgs.gnugrep}/bin/grep -nF 'lfs fsck --pointers HEAD' ${pullScript} | ${pkgs.coreutils}/bin/head -1 | ${pkgs.coreutils}/bin/cut -d: -f1 || true)"
  pull_line="$(${pkgs.gnugrep}/bin/grep -nF 'pull --rebase --autostash' ${pullScript} | ${pkgs.coreutils}/bin/head -1 | ${pkgs.coreutils}/bin/cut -d: -f1 || true)"

  pointer_guard_is_ordered=false
  if [ -n "$guard_line" ] && [ -n "$pull_line" ] && [ "$guard_line" -lt "$pull_line" ]; then
    pointer_guard_is_ordered=true
  fi

  if ${if pointerGuardExpectedFailure then "true" else "false"}; then
    if "$pointer_guard_is_ordered"; then
      echo "Git LFS pointer guard unexpectedly passed while marked expected-failure." >&2
      exit 1
    fi
  elif ! "$pointer_guard_is_ordered"; then
    echo "mill-docs-git-pull must reject invalid HEAD pointers before autostash." >&2
    exit 1
  fi

  collision_guard="$(${pkgs.gnugrep}/bin/grep -oE '/nix/store/[^[:space:]]+-mill-docs-git-untracked-collision-guard' ${pullScript} | ${pkgs.coreutils}/bin/head -1 || true)"
  collision_guard_works=false

  if [ -n "$collision_guard" ]; then
    remote="$TMPDIR/remote.git"
    writer="$TMPDIR/writer"
    checkout="$TMPDIR/checkout"

    ${pkgs.git}/bin/git init --quiet --bare --initial-branch=main "$remote"
    ${pkgs.git}/bin/git clone --quiet "$remote" "$writer"
    ${pkgs.git}/bin/git -C "$writer" config user.name "NUC pull test"
    ${pkgs.git}/bin/git -C "$writer" config user.email "nuc-pull-test@example.invalid"
    printf 'base\n' > "$writer/README.md"
    ${pkgs.git}/bin/git -C "$writer" add README.md
    ${pkgs.git}/bin/git -C "$writer" commit --quiet -m "test: add base"
    ${pkgs.git}/bin/git -C "$writer" push --quiet origin main

    ${pkgs.git}/bin/git clone --quiet "$remote" "$checkout"

    printf 'same upstream content\n' > "$writer/identical.md"
    printf 'different upstream content\n' > "$writer/conflict.md"
    ${pkgs.git}/bin/git -C "$writer" add identical.md conflict.md
    ${pkgs.git}/bin/git -C "$writer" commit --quiet -m "test: add upstream files"
    ${pkgs.git}/bin/git -C "$writer" push --quiet origin main

    printf 'same upstream content\n' > "$checkout/identical.md"
    printf 'different local content\n' > "$checkout/conflict.md"
    ${pkgs.git}/bin/git -C "$checkout" fetch --quiet origin

    conflict_is_preserved=false
    if ! "$collision_guard" "$checkout" origin/main \
      && [ -f "$checkout/identical.md" ] \
      && [ -f "$checkout/conflict.md" ]; then
      conflict_is_preserved=true
    fi

    ${pkgs.coreutils}/bin/rm "$checkout/conflict.md"
    identical_is_removed=false
    if "$collision_guard" "$checkout" origin/main \
      && [ ! -e "$checkout/identical.md" ]; then
      identical_is_removed=true
    fi

    if "$conflict_is_preserved" && "$identical_is_removed"; then
      collision_guard_works=true
    fi
  fi

  if ${if collisionGuardExpectedFailure then "true" else "false"}; then
    if "$collision_guard_works"; then
      echo "Untracked collision guard unexpectedly passed while marked expected-failure." >&2
      exit 1
    fi
  elif ! "$collision_guard_works"; then
    echo "mill-docs-git-pull must remove identical collisions and preserve differing files." >&2
    exit 1
  fi

  unmerged_guard="$(${pkgs.gnugrep}/bin/grep -oE '/nix/store/[^[:space:]]+-mill-docs-git-unmerged-guard' ${pullScript} | ${pkgs.coreutils}/bin/head -1 || true)"
  unmerged_guard_line="$(${pkgs.gnugrep}/bin/grep -nF 'mill-docs-git-unmerged-guard' ${pullScript} | ${pkgs.coreutils}/bin/head -1 | ${pkgs.coreutils}/bin/cut -d: -f1 || true)"
  fetch_line="$(${pkgs.gnugrep}/bin/grep -nF 'git fetch --quiet' ${pullScript} | ${pkgs.coreutils}/bin/head -1 | ${pkgs.coreutils}/bin/cut -d: -f1 || true)"
  unmerged_guard_works=false

  if [ -n "$unmerged_guard" ] && [ -n "$unmerged_guard_line" ] && [ -n "$fetch_line" ] && [ "$unmerged_guard_line" -lt "$fetch_line" ]; then
    repo="$TMPDIR/unmerged-checkout"
    ${pkgs.git}/bin/git init --quiet --initial-branch=main "$repo"
    ${pkgs.git}/bin/git -C "$repo" config user.name "NUC pull test"
    ${pkgs.git}/bin/git -C "$repo" config user.email "nuc-pull-test@example.invalid"
    printf 'base\n' > "$repo/conflict.md"
    ${pkgs.git}/bin/git -C "$repo" add conflict.md
    ${pkgs.git}/bin/git -C "$repo" commit --quiet -m "test: add conflict fixture"

    clean_checkout_passes=false
    if "$unmerged_guard" "$repo"; then
      clean_checkout_passes=true
    fi

    base_blob="$(${pkgs.git}/bin/git -C "$repo" rev-parse HEAD:conflict.md)"
    ours_blob="$(printf 'local\n' | ${pkgs.git}/bin/git -C "$repo" hash-object -w --stdin)"
    ${pkgs.git}/bin/git -C "$repo" update-index --force-remove conflict.md
    printf '100644 %s 1\tconflict.md\n100644 %s 2\tconflict.md\n' "$base_blob" "$ours_blob" \
      | ${pkgs.git}/bin/git -C "$repo" update-index --index-info

    index_before="$(${pkgs.coreutils}/bin/sha256sum "$repo/.git/index")"
    status_before="$(${pkgs.git}/bin/git -C "$repo" status --porcelain=v1)"
    file_before="$(${pkgs.coreutils}/bin/sha256sum "$repo/conflict.md")"

    conflict_status=0
    "$unmerged_guard" "$repo" || conflict_status=$?
    conflict_is_rejected=false
    if [ "$conflict_status" -eq 75 ]; then
      conflict_is_rejected=true
    fi

    if "$clean_checkout_passes" \
      && "$conflict_is_rejected" \
      && [ "$index_before" = "$(${pkgs.coreutils}/bin/sha256sum "$repo/.git/index")" ] \
      && [ "$status_before" = "$(${pkgs.git}/bin/git -C "$repo" status --porcelain=v1)" ] \
      && [ "$file_before" = "$(${pkgs.coreutils}/bin/sha256sum "$repo/conflict.md")" ]; then
      unmerged_guard_works=true
    fi
  fi

  if ${if unmergedGuardExpectedFailure then "true" else "false"}; then
    if "$unmerged_guard_works"; then
      echo "Unmerged index guard unexpectedly passed while marked expected-failure." >&2
      exit 1
    fi
  elif ! "$unmerged_guard_works"; then
    echo "mill-docs-git-pull must skip an unmerged index before fetch without changing Git or worktree state." >&2
    exit 1
  fi

  make_conflict() {
    repo="$1"
    base_blob="$(${pkgs.git}/bin/git -C "$repo" rev-parse HEAD:conflict.md)"
    ours_blob="$(printf 'local content\n' | ${pkgs.git}/bin/git -C "$repo" hash-object -w --stdin)"
    ${pkgs.git}/bin/git -C "$repo" update-index --force-remove conflict.md
    printf '100644 %s 1\tconflict.md\n100644 %s 2\tconflict.md\n' "$base_blob" "$ours_blob" \
      | ${pkgs.git}/bin/git -C "$repo" update-index --index-info
  }

  render_service_script() {
    repo="$1"
    destination="$2"
    ${pkgs.gnused}/bin/sed \
      -e 's|${pkgs.git}/bin/git|${fakeGit}|g' \
      -e 's|${pkgs.curl}/bin/curl|${fakeCurl}|g' \
      -e "s|${vaultPath}|$repo|g" \
      ${pullScript} > "$destination"
    chmod +x "$destination"
  }

  service_remote="$TMPDIR/service-remote.git"
  service_writer="$TMPDIR/service-writer"
  ${pkgs.git}/bin/git init --quiet --bare --initial-branch=main "$service_remote"
  ${pkgs.git}/bin/git clone --quiet "$service_remote" "$service_writer"
  ${pkgs.git}/bin/git -C "$service_writer" config user.name "NUC pull test"
  ${pkgs.git}/bin/git -C "$service_writer" config user.email "nuc-pull-test@example.invalid"
  printf 'base content\n' > "$service_writer/conflict.md"
  ${pkgs.git}/bin/git -C "$service_writer" add conflict.md
  ${pkgs.git}/bin/git -C "$service_writer" commit --quiet -m "test: add service fixture"
  ${pkgs.git}/bin/git -C "$service_writer" push --quiet origin main

  conflicted_repo="$TMPDIR/service-conflicted"
  ${pkgs.git}/bin/git clone --quiet "$service_remote" "$conflicted_repo"
  make_conflict "$conflicted_repo"
  conflicted_script="$TMPDIR/service-conflicted-script"
  render_service_script "$conflicted_repo" "$conflicted_script"
  conflicted_git_calls="$TMPDIR/service-conflicted-git-calls"
  conflicted_curl_calls="$TMPDIR/service-conflicted-curl-calls"
  : > "$conflicted_git_calls"
  : > "$conflicted_curl_calls"
  conflicted_status=0
  CURL_CALL_LOG="$conflicted_curl_calls" GIT_CALL_LOG="$conflicted_git_calls" \
    "$conflicted_script" || conflicted_status=$?
  conflicted_service_works=false
  if [ "$conflicted_status" -eq 0 ] \
    && ! ${pkgs.gnugrep}/bin/grep -Eq '^(fetch|pull)$' "$conflicted_git_calls" \
    && ${pkgs.gnugrep}/bin/grep -qF '/fail' "$conflicted_curl_calls"; then
    conflicted_service_works=true
  fi

  raced_repo="$TMPDIR/service-raced"
  ${pkgs.git}/bin/git clone --quiet "$service_remote" "$raced_repo"
  raced_script="$TMPDIR/service-raced-script"
  render_service_script "$raced_repo" "$raced_script"
  raced_git_calls="$TMPDIR/service-raced-git-calls"
  raced_curl_calls="$TMPDIR/service-raced-curl-calls"
  : > "$raced_git_calls"
  : > "$raced_curl_calls"
  raced_status=0
  CURL_CALL_LOG="$raced_curl_calls" GIT_CALL_LOG="$raced_git_calls" GIT_INJECT_CONFLICT=true \
    "$raced_script" || raced_status=$?
  raced_service_works=false
  if [ "$raced_status" -eq 0 ] \
    && [ "$(${pkgs.gnugrep}/bin/grep -c '^fetch$' "$raced_git_calls")" -eq 1 ] \
    && ! ${pkgs.gnugrep}/bin/grep -q '^pull$' "$raced_git_calls" \
    && ${pkgs.gnugrep}/bin/grep -qF '/fail' "$raced_curl_calls"; then
    raced_service_works=true
  fi

  broken_repo="$TMPDIR/service-broken-index"
  ${pkgs.git}/bin/git clone --quiet "$service_remote" "$broken_repo"
  printf 'not a git index\n' > "$broken_repo/.git/index"
  broken_script="$TMPDIR/service-broken-script"
  render_service_script "$broken_repo" "$broken_script"
  broken_git_calls="$TMPDIR/service-broken-git-calls"
  broken_curl_calls="$TMPDIR/service-broken-curl-calls"
  : > "$broken_git_calls"
  : > "$broken_curl_calls"
  broken_status=0
  CURL_CALL_LOG="$broken_curl_calls" GIT_CALL_LOG="$broken_git_calls" \
    "$broken_script" || broken_status=$?
  broken_service_works=false
  if [ "$broken_status" -eq 2 ] \
    && ! ${pkgs.gnugrep}/bin/grep -Eq '^(fetch|pull)$' "$broken_git_calls" \
    && ${pkgs.gnugrep}/bin/grep -qF '/fail' "$broken_curl_calls"; then
    broken_service_works=true
  fi

  service_guard_works=false
  if "$conflicted_service_works" && "$raced_service_works" && "$broken_service_works"; then
    service_guard_works=true
  fi

  if ${if serviceGuardExpectedFailure then "true" else "false"}; then
    if "$service_guard_works"; then
      echo "Service-level unmerged guard unexpectedly passed while marked expected-failure." >&2
      exit 1
    fi
  elif ! "$service_guard_works"; then
    echo "mill-docs-git-pull must report conflicts unhealthy, stop before pull, and propagate guard errors." >&2
    exit 1
  fi

  touch "$out"
''
