# Agent modules

`default.nix` installs shared agent CLI tools. Runtime-specific packages and
wiring belong in `modules.agents.<runtime>`; shared instruction sources live in
`config/agents/` and skills in `skills/catalog/`.

Herdr's shell module installs integrations for enabled runtimes during
activation. Agent modules bootstrap their runtime directories before that step;
they do not install Herdr integrations themselves.

`pi-runtime-drift` and `hermes-runtime-drift` pre-push hooks are warning-only,
read-only checks of mutable state. They neither repair state nor block pushes.
Authorized repairs use the relevant rebuild/update command.

`modules.agents.exo.enable` installs the Exo CLI for isolated agent environments.
`modules.agents.hermes` is NixOS host wiring; `hermes-local` owns the Mac CLI.
Reusable Hermes profiles/presets belong in `agents-workspace`. Desktop app
installation is separate. Plannotator is excluded from Codex because its global
Stop hook interrupts normal responses. `callstack-diff skill` prints that tool's
version-matched instructions.
