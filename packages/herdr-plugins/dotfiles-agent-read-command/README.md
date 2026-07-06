# Dotfiles Agent Read Command

Adds pane/tab context menu actions that copy:

```text
herdr agent read <target> --source recent-unwrapped --lines 200 --format text
```

Pane actions use the clicked pane/terminal target. Tab actions use the context agent when available, otherwise the highest-priority agent in that tab.
