---
purpose: Prevent and recover meshify's Quickshell crash when local plugins reload while the screen is locked.
applies_to: Omapods builds, plugin updates, restore operations, or Git writes under the local plugin directory.
entrypoint: Keep meshify unlocked and run plugin build output outside the watched plugin checkout.
verification: Check installed versions and `coredumpctl list quickshell` after plugin work or an alleged upstream fix.
update_when: Omarchy or Quickshell fixes locked-session plugin reloads, or the local build path changes.
---

# Plugin reloads while locked

On Omarchy `4.0.0-1` with `quickshell-git 0.3.0.r20.g28771c7-1`, writing
inside `~/.config/omarchy/plugins/` while the session is locked can abort the
shell. The recursive plugin watcher starts a full plugin reload, which destroys
the active `omarchy.lock` service. A later lock recovery reaches
`WlSessionLock::updateSurfaces()` without an active lock and Quickshell aborts
with:

```text
FATAL: Tried to show lockscreen surfaces without active lock
```

This happened on meshify on 2026-08-22 while Omapods setup generated many files
under `daemon/build/`. Three coredumps had the same `SIGABRT` and symbolized
stack. Memory exhaustion was ruled out, Quickshell restarted automatically, and
there was no evidence of user-data loss.

Until the tracked fix ships:

- Keep meshify unlocked while running `./manage restore` or `./manage update`.
  A changed Omapods revision can run its trusted setup adapter and write build
  output inside the watched plugin checkout.
- Avoid build, edit, synchronization, and Git operations in a local plugin while
  the screen is locked.
- For a manual Omapods build, keep generated files outside the plugin tree:

  ```bash
  src="$HOME/.config/omarchy/plugins/io.github.thisisgm.omapods/daemon"
  build="${XDG_CACHE_HOME:-$HOME/.cache}/omarchy-build/omapods"
  cmake -S "$src" -B "$build" -G Ninja -DBUILD_TESTING=OFF
  cmake --build "$build"
  cmake --install "$build" --prefix "$HOME/.local"
  ```

`/usr/share/omarchy/` is package-owned; an update replaces local changes. Track
the downstream fix in
[basecamp/omarchy#7106](https://github.com/basecamp/omarchy/issues/7106) and the
Quickshell assertion in
[quickshell-mirror/quickshell#962](https://github.com/quickshell-mirror/quickshell/issues/962).
After an Omarchy update claims the fix, verify the installed version and check
for recurrence with `coredumpctl list quickshell` before removing this warning.
