---
purpose: Provide a safe, responsive TRMNL private-plugin template for agent-authored messages.
applies_to: The TRMNL OG and TRMNL X agent-message plugin project.
entrypoint: Run the structural test, then use trmnlp lint/build/serve from this directory.
verification: Structural checks, OG/X body-pixel assertions, and trmnlp lint/build pass.
update_when: TRMNL framework versions, display models, or the message payload contract changes.
---

# Agent Message for TRMNL

This is a small official [TRMNLP](https://github.com/usetrmnl/trmnlp) project for
one short, agent-authored message. The four standard views share one responsive
markup contract, so the same private plugin works in mashups and on both the
TRMNL OG and TRMNL X. TRMNL applies the device-specific screen class; the
templates use `lg:` and `portrait:` variants for layout adjustments.

Payload keys:

- `headline` — short title, clamped in each view.
- `message` — concise body, clamped in each view.
- `source` — attribution shown in the title bar.
- `status` — small status label.
- `timestamp` — optional human-readable timestamp.
- `progress` — optional numeric percentage; omit it to hide the progress bar.

## Local preview

Enter the repo-pinned toolchain, then work from this directory:

```sh
nix develop .#display-devices
cd config/trmnl/agent-message
bundle install
./test_project.sh
./test_push_guard.sh
./test_render.sh
./bin/trmnlp lint
./bin/trmnlp build
./bin/trmnlp serve
```

The committed `gemset.nix` and pinned framework assets make the registered
Linux PNG render check hermetic. Regenerate `gemset.nix` with
`nix run nixpkgs#bundix --` whenever `Gemfile.lock` changes. Darwin authoring
uses the same packaged gems but runs the render check directly from the shell.

`test_render.sh` builds all four views at both the OG (800×480, 1-bit) and X
(1040×780, 4-bit) viewport sizes. It checks each view's body for at least 500
foreground pixels and checks separate headline/status and message/progress
regions in the full view, catching clipped or zero-width flex children that
still leave valid HTML and a visible title bar.

The checked-in values under `.trmnlp.yml` are generic preview data. Keep
`fixtures/example.json` as the payload contract for agents and integrations;
it contains no household-specific data.

## Publishing guard

`src/settings.yml` deliberately uses `id: __UNASSIGNED__`. The local
`bin/trmnlp` wrapper refuses `push` while that placeholder is present, so a
normal agent command cannot silently create a duplicate plugin. Do not bypass
that guard: the placeholder is not an account target.
After authenticating, verify the account, device, and intended private-plugin
settings ID in the TRMNL UI/API, replace the placeholder, and re-read the
resulting server-side settings before publishing. A webhook UUID/API secret
belongs in the secret manager, never in this repository.
