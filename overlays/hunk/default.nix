final: prev:
let
  hunk = prev.llm-agents.hunk.overrideAttrs (_old: {
    # Keep the package override local to overlays/hunk so future Hunk patches,
    # wrappers, or source pins have a single home. Consumers should use
    # pkgs.my.hunk, which is backed by this overlaid llm-agents.hunk package.
  });
in
{
  llm-agents = (prev.llm-agents or { }) // {
    inherit hunk;
  };
}
