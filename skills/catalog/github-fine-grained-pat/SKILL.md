---
name: github-fine-grained-pat
description: Create least-privilege fine-grained GitHub personal access tokens. Use when the user wants a PAT template, recurring machine credential, private-repository token, or GitHub token rotation.
---

# Fine-grained GitHub PAT

Create a narrowly scoped token and keep its value out of chat, logs, command arguments, and version control.

## 1. Define the grant

Confirm or infer:

- resource owner;
- exact repositories;
- required repository permissions;
- expiration;
- token name and purpose.

Default machine-read grant:

- only the named repositories;
- `contents=read`;
- 366-day expiration;
- no account permissions.

Do not grant all repositories or write access unless the task requires it.

## 2. Generate the template link

Build this URL with percent-encoded values:

```text
https://github.com/settings/personal-access-tokens/new?name=<name>&description=<description>&target_name=<owner>&expires_in=<days>&contents=read
```

Supported template fields are `name`, `description`, `target_name`, `expires_in`, and permission names. Repository selection cannot be prefilled. Say this explicitly, then list the repositories the user must select under **Only select repositories**.

Use GitHub's current permission parameter names. If the requested grant is broader than `contents=read`, verify the parameter in GitHub's official token documentation before constructing the link.

## 3. Create only when requested

If the user asks only for a link, stop after returning the link and repository checklist.

If the user asks the agent to create the token, use an authenticated browser session. Review the visible owner, repositories, expiration, and permissions immediately before generation. Creating the token is the requested external side effect; do not broaden its scope.

If authentication, reauthentication, CAPTCHA, or repository selection requires the user, leave the exact page open as a handoff and state the remaining action.

## 4. Capture safely

The token is shown once. Never print it, paste it into chat, or expose it in tool output.

When storage is in scope, save it directly into the requested secret manager. Prefer a dedicated item whose title identifies the machine and purpose. Record these non-secret fields beside it:

- GitHub resource owner;
- selected repositories;
- granted permissions;
- expiration date;
- consuming service or host.

Do not place the token in `flake.nix`, committed `nix.conf`, shell history, or a Nix store path.

## 5. Verify the boundary

Verify without displaying the token:

- authorized repository requests succeed;
- one unselected private repository request fails;
- the consumer reads the secret through its intended runtime path;
- no command or log contains the token value.

Report scope and verification only, never the credential.
