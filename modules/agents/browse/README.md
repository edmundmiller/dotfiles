# OpenCode Browse

`modules.agents.browse.enable` installs the pinned `browse` CLI. The host-owned
MCP catalog registers it when `modules.agents.mcp.servers.browse.enable` is true.
MacTraitor-Pro enables both, making Browse available to its enabled MCP clients,
including Amp. Other hosts remain unchanged.

Nix owns CLI updates. The package disables Browse's automatic updater. The
Chrome Web Store still owns extension updates. Pairing keys, sessions, and
settings stay in Browse's writable XDG directories, outside the Nix store.
The relay starts on demand and retains its upstream loopback-only default.

## First use

After an authorized `hey re` on MacTraitor-Pro:

1. Add the [Browse extension](https://chromewebstore.google.com/detail/mfnicocicmmlkpjnaffgihfjhdgjkdjg)
   to the Chromium browser you want agents to use.
2. Run `browse pair` on that Mac. Open the extension's Options page, enter the
   one-time code, and pair it with the local relay.
3. Restart your MCP clients, then ask an agent to open a public page.
   `browse status` and `browse doctor` diagnose the connection.

Do not run the upstream installer or `browse install` to register clients.
The dotfiles MCP reconciler owns those entries. Do not run `browse update`;
update the version and platform hashes in `packages/opencode-browse/default.nix`
and rebuild instead.

If the agent and browser run on different computers, this local setup alone is
not enough. Follow the [upstream remote-browser instructions](https://github.com/anomalyco/browse#browser-on-another-computer)
over an encrypted network. This module does not expose the relay to the network.

## Validation and removal

Build `.#opencode-browse`, then run `hey check packages/opencode-browse
modules/agents/browse config/agents/mcp.nix hosts/mactraitorpro/default.nix`.
The package checks CLI startup; source checks do not prove extension pairing.

To remove it, disable the host's Browse module and MCP server selection, then
activate with `hey re`. The reconciler removes its managed MCP entries without
deleting browser pairing keys or other user data.
