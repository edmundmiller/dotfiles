_:

{
  ".pi/session-search/config.json".text = builtins.toJSON {
    # Avoid startup DB lock storms when multiple Pi panes launch at once.
    # Manual /session-sync and search against the existing index still work.
    sync = {
      interval = -1;
      initialDelay = -1;
    };
  };
}
