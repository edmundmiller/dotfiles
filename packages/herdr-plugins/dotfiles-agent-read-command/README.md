---
purpose: Describe the Herdr context action that copies semantic agent-read commands.
applies_to: Installing, using, or changing dotfiles.agent-read-command.
entrypoint: Read herdr-plugin.toml, then agent_read_command.py.
verification: Run agent_read_command_test.py and invoke both context actions in Herdr.
update_when: Herdr agent target rules, context payloads, or copied command options change.
---

# Dotfiles Agent Read Command

Adds pane/tab context menu actions that copy:

```text
herdr agent read <target> --source recent-unwrapped --lines 200 --format text
```

Pane actions use the clicked pane ID. Tab actions use the context agent's current pane ID when available, otherwise the highest-priority live agent in that tab. Herdr 0.7.5 agent commands reject terminal IDs and bare agent-kind labels, so neither is emitted as a target.
