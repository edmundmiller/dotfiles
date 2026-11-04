# Zed reference snapshot

`settings.json` is a parked copy of live `~/.config/zed/settings.json`, not a
managed deployment source. Refresh from the live file when requested. Wiring
it into Nix or Home Manager requires a separate request; preserve user comments.

Verification is a reviewed source diff only. `hey check config/zed` can validate
repository policy, but no rebuild or activation will apply this parked snapshot.
