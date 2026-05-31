_final: prev: {
  llm-agents = (prev.llm-agents or { }) // {
    gnhf = prev.llm-agents.gnhf.overrideAttrs (old: {
      pnpmDeps = old.pnpmDeps.overrideAttrs (_: {
        outputHash = "sha256-pz6tsd0XcVd0GiAXSApP9XL6IjZHyWEgLyazWuS64UM=";
      });
    });
  };
}
