final: prev: {
  llm-agents = (prev.llm-agents or { }) // {
    gnhf = prev.llm-agents.gnhf.overrideAttrs (old: {
      # llm-agents currently builds gnhf with pnpm 11 on Node 24, which aborts
      # in libuv's kqueue polling during the offline pnpm install on Darwin.
      # Use this flake's pinned pnpm/Node 22 toolchain for this package only.
      nativeBuildInputs = map (
        input:
        if (input.pname or null) == "pnpm" then
          final.pnpm
        else if (input.pname or null) == "nodejs" then
          final.nodejs_22
        else
          input
      ) old.nativeBuildInputs;

      buildInputs = map (
        input: if (input.pname or null) == "nodejs" then final.nodejs_22 else input
      ) old.buildInputs;

      pnpmDeps = old.pnpmDeps.overrideAttrs (_: {
        outputHash = "sha256-pz6tsd0XcVd0GiAXSApP9XL6IjZHyWEgLyazWuS64UM=";
      });
    });
  };
}
