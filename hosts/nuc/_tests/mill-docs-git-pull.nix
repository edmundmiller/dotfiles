{ nixosConfig, pkgs }:
let
  pullScript = nixosConfig.config.systemd.services.mill-docs-git-pull.serviceConfig.ExecStart;
  pointerGuardExpectedFailure = false;
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

  touch "$out"
''
