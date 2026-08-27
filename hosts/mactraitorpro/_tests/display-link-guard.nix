{
  darwinConfig,
  pkgs,
}:
let
  inherit (builtins) filter length;
  inherit (pkgs.lib.strings) hasInfix;

  mac = darwinConfig.config;
  launchAgent = mac.launchd.user.agents."display-link-guard" or null;
  service = if launchAgent == null then { } else launchAgent.serviceConfig;
  missingProgram = pkgs.writeShellScript "missing-display-link-guard" "exit 1";
  program = if launchAgent == null then missingProgram else launchAgent.command;

  assertions = [
    {
      test = launchAgent != null;
      msg = "MacTraitor-Pro must declare the display-link guard";
    }
    {
      test = service.RunAtLoad or false;
      msg = "the display-link guard must check the dock topology at login";
    }
    {
      test = (service.StartInterval or 0) == 300;
      msg = "the display-link guard must poll at the bounded five-minute interval";
    }
    {
      test = (service.KeepAlive or false) == false || (service.KeepAlive or null) == null;
      msg = "the display-link guard must be periodic rather than continuously resident";
    }
    {
      test = hasInfix "display-link-guard" (toString program);
      msg = "the launch agent must execute the repo-owned display-link guard";
    }
  ];

  failures = filter (assertion: !assertion.test) assertions;

  fakeDisplayctl = pkgs.writeShellScript "fake-displayctl-link-failure" ''
    if [ "''${DISPLAY_LINK_GUARD_FAKE_STATE:-unhealthy}" = unobserved ]; then
      printf '%s\n' '{"ok":null,"state":"unobserved","observed":{"display_paths":false,"usb_c_display_paths":false,"dock":false},"dock":null,"issues":[],"recovery":[]}'
      exit 0
    fi
    cat <<'JSON'
    {
      "ok": false,
      "state": "unhealthy",
      "dock": {"model": "TS5", "host_port": 1, "expected_host_port": 2},
      "issues": [
        {"code": "display_link_training_failed", "transports": ["Port-USB-C@1/CIO/DisplayPort@1"]},
        {"code": "ts5_host_port_mismatch", "actual_host_port": 1, "expected_host_port": 2}
      ],
      "recovery": [
        "Connect the TS5 host cable to the bottom-left Mac USB-C port nearest the trackpad.",
        "Connect displays only to rear, lightning-marked TS5 downstream ports.",
        "If one display has HPD but no link, disconnect ASUS, wait for LG to appear, then reconnect ASUS."
      ]
    }
    JSON
    exit 1
  '';

  fakeOsascript = pkgs.writeShellScript "fake-display-link-osascript" ''
    printf '%s\n' "$*" >> "''${DISPLAY_LINK_GUARD_TEST_LOG:?}"
  '';
in
pkgs.runCommand "display-link-guard-regressions"
  {
    passthru = {
      inherit assertions failures;
    };
  }
  ''
    if [ ${toString (length failures)} -ne 0 ]; then
      echo "${toString (length failures)} display-link guard assertions failed" >&2
      exit 1
    fi

    if ! grep -F -- '/bin/displayctl' '${program}' >/dev/null \
      || ! grep -F -- 'macos status' '${program}' >/dev/null; then
      echo "the guard must use displayctl's read-only macOS status command" >&2
      exit 1
    fi
    if grep -E -- 'killall|WindowServer|shutdown|reboot|defaults write|launchctl kickstart' '${program}' >/dev/null; then
      echo "the guard must not reset system or display processes" >&2
      exit 1
    fi

    state_dir="$TMPDIR/state"
    notification_log="$TMPDIR/notifications"
    : > "$notification_log"
    for _attempt in 1 2; do
      DISPLAYCTL_BIN='${fakeDisplayctl}' \
        OSASCRIPT_BIN='${fakeOsascript}' \
        DISPLAY_LINK_GUARD_STATE_DIR="$state_dir" \
        DISPLAY_LINK_GUARD_TEST_LOG="$notification_log" \
        '${program}'
    done

    if [ "$(wc -l < "$notification_log" | tr -d ' ')" -ne 1 ]; then
      echo "the guard must notify once for an unchanged incident" >&2
      exit 1
    fi
    grep -F -- 'USB-C port 1' "$notification_log" >/dev/null
    grep -F -- 'port 2' "$notification_log" >/dev/null
    grep -F -- 'lightning-marked TS5 downstream ports' "$notification_log" >/dev/null

    DISPLAY_LINK_GUARD_FAKE_STATE=unobserved \
      DISPLAYCTL_BIN='${fakeDisplayctl}' \
      OSASCRIPT_BIN='${fakeOsascript}' \
      DISPLAY_LINK_GUARD_STATE_DIR="$state_dir" \
      DISPLAY_LINK_GUARD_TEST_LOG="$notification_log" \
      '${program}'
    grep -Fx -- unobserved "$state_dir/state" >/dev/null
    if [ "$(wc -l < "$notification_log" | tr -d ' ')" -ne 1 ]; then
      echo "unobserved hardware must remain quiet without being called healthy" >&2
      exit 1
    fi

    DISPLAYCTL_BIN='${fakeDisplayctl}' \
      OSASCRIPT_BIN='${fakeOsascript}' \
      DISPLAY_LINK_GUARD_STATE_DIR="$state_dir" \
      DISPLAY_LINK_GUARD_TEST_LOG="$notification_log" \
      '${program}'
    if [ "$(wc -l < "$notification_log" | tr -d ' ')" -ne 2 ]; then
      echo "the guard must notify when an incident recurs after an unobserved interval" >&2
      exit 1
    fi

    mkdir -p "$out"
    echo "Display-link guard regressions passed." > "$out/result"
  ''
