{ nixosConfig, pkgs }:
let
  pullScript = nixosConfig.config.systemd.services.mill-docs-git-pull.serviceConfig.ExecStart;
  pointerGuardExpectedFailure = false;
  collisionGuardExpectedFailure = false;
  unmergedGuardExpectedFailure = true;
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

    conflict_is_rejected=false
    if ! "$unmerged_guard" "$repo"; then
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

  touch "$out"
''
