# Taskwarrior Configuration

## Report Layout

The primary report is `next`, which is also the default command. It's optimized for triage workflows at 120+ character terminal widths.

### Column Layout

```
ID  A P Due   Age    Est  Act  Description                    Project     Tags
--- - - ----- ------ ---- ---- ------------------------------ ----------- ----
 65   M -3w     3w              Put books on cover             Reminders
 35 * M -1d     2d   30m  15m   Fill out Rocketlane timecard              [3]
```

| Column | Field | Purpose |
|--------|-------|---------|
| ID | `id` | Task ID for quick action |
| A | `start.active` | Shows `*` when task is actively being worked on |
| P | `priority` | H/M/L priority level |
| Due | `due.relative` | Relative due date (`-3d`, `2h`, `1w`) |
| Age | `entry.age` | How long the task has existed (spot stale tasks) |
| Est | `estimate` | Time estimate (duration) for capacity planning |
| Act | `totalactivetime` | Actual time spent on task |
| Description | `description.truncated_count` | Task description with annotation count `[3]` |
| Project | `project.parent` | Top-level project only (saves space) |
| Tags | `tags.count` | Tag count `[2]` rather than full tag names |

### Design Decisions

1. **No workspace column** - Use contexts (`work`/`home`) instead for filtering
2. **No urgency column** - Sorted by urgency, colors indicate priority
3. **Relative dates** - `-3d` is faster to parse than `2025-12-06`
4. **Truncated description with count** - Shows annotation count without full text
5. **Parent project only** - `Monarch-Money` instead of `Monarch-Money.API-setup`

### Sort Order

```
urgency-,due+
```

Tasks are sorted by urgency (descending), then by due date (ascending) for tasks with equal urgency.

### Filter

```
status:pending -WAITING -BLOCKED
```

Shows only actionable tasks - excludes waiting and blocked tasks.

## Color Scheme

Uses Catppuccin Mocha palette with semantic meaning:

| Element | Color | Meaning |
|---------|-------|---------|
| High priority | Bold red (`rgb533`) | Urgent attention needed |
| Medium priority | Peach (`rgb543`) | Normal priority |
| Low priority | Blue (`rgb345`) | Can wait |
| Due today | Bold peach | Action needed today |
| Overdue | Bold red | Past due - triage immediately |
| Active task | White on blue | Currently being worked on |

## Capacity Planning

The `Est` and `Act` columns support capacity planning:

```bash
# Add estimate to a task
task 35 modify estimate:30min

# Estimates use ISO 8601 durations
task add "Write report" estimate:2h
task add "Quick fix" estimate:PT15M
```

The `totalactivetime` field is populated automatically by Timewarrior integration when you start/stop tasks.

## Related Reports

| Report | Purpose |
|--------|---------|
| `next` | Primary triage (default) |
| `today` | Today's scheduled + urgent items |
| `crisis` | High priority overdue only |
| `overdue` | All overdue for cleanup |
| `quick` | Low-effort tasks for momentum |
