# NixOS defaultIntegrations

These integrations are **always loaded** by the NixOS HA module. No need to add
them to `extraComponents`. Entities can be declared directly in `config = { }`.

Source: `services.home-assistant.defaultIntegrations` (read-only option)

## Core

| Integration               | What it provides         |
| ------------------------- | ------------------------ |
| `application_credentials` | OAuth credential storage |
| `frontend`                | Web UI                   |
| `hardware`                | Hardware info            |
| `logger`                  | Log filtering            |
| `network`                 | Network config           |
| `system_health`           | System diagnostics       |
| `backup`                  | Backup management        |

## Key features

| Integration  | What it provides    |
| ------------ | ------------------- |
| `automation` | Automation engine   |
| `person`     | Person tracking     |
| `scene`      | Scene management    |
| `script`     | Script sequences    |
| `tag`        | NFC/QR tag scanning |
| `zone`       | Geographic zones    |

## Built-in helpers

All of these can be declared in Nix `config = { }` with no `extraComponents`:

| Integration      | Nix config key   | Example use                            |
| ---------------- | ---------------- | -------------------------------------- |
| `counter`        | `counter`        | Track occurrences (TV sessions/day)    |
| `input_boolean`  | `input_boolean`  | Toggles (goodnight, DND, guest mode)   |
| `input_button`   | `input_button`   | Trigger-only buttons                   |
| `input_datetime` | `input_datetime` | Time/date pickers (wake time, bedtime) |
| `input_number`   | `input_number`   | Numeric sliders (sleep timer minutes)  |
| `input_select`   | `input_select`   | Dropdowns (house mode)                 |
| `input_text`     | `input_text`     | Free text fields                       |
| `schedule`       | `schedule`       | Weekly schedules (UI-defined)          |
| `timer`          | `timer`          | Countdown timers                       |

## Nix example

```nix
services.home-assistant.config = {
  input_boolean.goodnight = {
    name = "Goodnight";
    icon = "mdi:weather-night";
  };
  input_number.sleep_timer = {
    name = "Sleep Timer";
    min = 0; max = 240; step = 15;
    unit_of_measurement = "min";
  };
  timer.sleep = {
    name = "Sleep Timer";
    duration = "02:00:00";
  };
  counter.tv_sessions = {
    name = "TV Sessions Today";
    step = 1;
  };
};
```
