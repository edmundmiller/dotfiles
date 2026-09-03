---
name: handing-off-remote-commands
description: Copies commands to an authorized remote machine's clipboard over SSH and retrieves explicitly captured results. Use when a human must run a local interactive or privileged command on another machine but cannot conveniently transfer the command between devices.
---

# Handing Off Remote Commands

Bridge the last interactive step without making the human retype a command.
SSH transports the command to the remote clipboard; the human remains the
security boundary by reviewing, pasting, and executing it locally.

## Workflow

1. Confirm ordinary SSH reaches the intended machine and identify its clipboard
   command. Use `pbcopy` on macOS, `wl-copy` on Wayland, or `xclip -selection
clipboard` on X11. Never install a clipboard utility as part of the handoff.
2. Build the command locally with a single-quoted heredoc so local variables,
   command substitutions, backticks, and quotes remain literal.
3. Pipe it over SSH to the clipboard command. Copying is not execution: tell the
   human to paste, review, and run it in a local terminal.
4. If the result is needed remotely, make the pasted command redirect only the
   required output to a mode-0600 file under
   `$HOME/.cache/agent-command-handoffs/`. Use a random token in its filename.
   Shell redirection must happen outside `sudo`, so the file remains owned by
   the user.
5. After the human confirms completion, read the bounded result over SSH, remove
   the result file, and clear the remote clipboard. Do not retain the command or
   output elsewhere.

## macOS Pattern

Command-only handoff:

```bash
cat <<'REMOTE_COMMAND' | ssh -- "$target" pbcopy
sudo launchctl kickstart -k system/com.example.service
REMOTE_COMMAND
```

Handoff with a retrievable result:

```bash
token="$(openssl rand -hex 8)"
result_rel=".cache/agent-command-handoffs/$token.out"

cat <<REMOTE_COMMAND | ssh -- "$target" pbcopy
umask 077
mkdir -p "\$HOME/.cache/agent-command-handoffs"
sudo example-inspect --read-only > "\$HOME/$result_rel" && echo "Diagnostic complete"
REMOTE_COMMAND
```

After the human runs it:

```bash
ssh -- "$target" "cat ~/$result_rel && rm -f ~/$result_rel"
printf '' | ssh -- "$target" pbcopy
```

Quote the outer heredoc delimiter when no generated token or result path must be
inserted. When interpolation is needed, interpolate only locally generated,
validated path components and escape every remote `$` as shown above.

## Guardrails

- Use this only with a machine and SSH account the user authorized.
- Put no password, token, recovery code, decrypted secret, or sensitive result
  on a clipboard. Universal Clipboard and clipboard managers may replicate or
  retain clipboard contents.
- Keep the pasted command narrow and visible. Never hide it behind encoded text,
  a downloader, `eval`, or an opaque script.
- Use the pattern to cross an interactive boundary, not to bypass one. The human
  explicitly runs privileged commands and handles authentication locally.
- Capture only output needed for the task. Prefer a short filtered query over a
  database dump or broad system log.
- Treat a missing result file as unknown execution state. Ask the human what the
  terminal showed instead of rerunning a potentially non-idempotent command.
