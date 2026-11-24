# Seqera Studios for Rex

`studios.lua` finds running Seqera Studios, adds them as Rex hosts, and installs
Rex on one so several people can see and type into the same terminals.
It is one Lua file run by `rex do`. It needs Rex, `curl`, and `ssh`, plus a
Seqera token and an SSH key on your Seqera profile.

## For a teammate

1. Add your SSH public key to your Seqera Platform profile.
2. Make a Seqera token available: `export TOWER_ACCESS_TOKEN=...`, or
   `export SEQERA_TOKEN_OP='op://Vault/Item/credential'` to read it from 1Password.
3. Find the shared Studios, and add one:

```sh
rex do studios.lua                          # running Studios labelled "rex"
rex do studios.lua cmd=add studio=SESSION_ID
```

That adds a CLI host (`rex -S LABEL ls`). The Mac app keeps its own host list,
so also choose **Add Remote Host…** in the app and enter the `ssh://seqera-studio-a…`
address the command prints.

## For the Studio owner

```sh
rex do studios.lua all=true                 # every running SSH Studio you can see
rex do studios.lua cmd=setup studio=SESSION_ID
```

`setup` installs Rex on the running Studio and adds it to your hosts.
To make the Studio show up in teammates' default list, give it a label named
`rex` in Platform. Studio labels can only be changed while the Studio is stopped
or when it starts.

## Claude Code on the Studio

```sh
rex do studios.lua cmd=claude studio=SESSION_ID
```

Installs Claude Code on the Studio if it is missing, writes portable team
defaults to `~/.claude/settings.json` (auto permission mode, a read-only allow
list, and denies for `--no-verify`, `--no-gpg-sign` and force pushes),
skips the first-run screens, and opens Claude in a `claude` Rex session.
An existing, different `settings.json` is kept as `settings.json.bak`.

To skip `/login`, create a long-lived token with `claude setup-token` in your own
terminal, save it in 1Password, and run with
`CLAUDE_TOKEN_OP='op://Vault/Item/credential'`. `CLAUDE_CODE_OAUTH_TOKEN` works too.
The token reaches the Studio on ssh's stdin and is stored in
`~/.claude/.oauth-token` (mode 600). Everyone who can reach the Studio is root
there, so they can use and read it.

## Options

- `ws=Org/workspace` searches one workspace.
- `stopped=true` includes stopped Studios in `list`.
- `as=LABEL` names the Rex host (default: the Studio name as a slug).
- `TOWER_API_ENDPOINT` points at another Platform (default `https://api.cloud.seqera.io`).

## What it changes on your machine

- `~/.ssh/seqera-rex.conf`: one `Host seqera-studio-a<session>` block per Studio.
  Rex's `ssh://` endpoints reject `%` escapes, and Studio logins contain `@`.
- One `Include` line at the top of `~/.ssh/config`.
- One entry in `rex hosts` (the CLI's list; the Mac app's list is separate).

## Limits

- Rex runs inside the Studio container. Stopping the Studio ends every Rex
  session. Run `setup` again after the Studio starts.
- Everyone who reaches the same Rex server can type into every terminal on it.
  A credential stored in the Studio, such as a Claude login, can be used and
  read by everyone who can SSH into it.
