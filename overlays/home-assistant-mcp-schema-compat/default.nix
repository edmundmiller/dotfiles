_final: prev: {
  home-assistant = prev.home-assistant.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./patches/0001-skip-invalid-mcp-tool-schemas.patch
    ];
  });
}
