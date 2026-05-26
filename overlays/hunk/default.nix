final: prev:
let
  hunk = prev.llm-agents.hunk.overrideAttrs (_old: {
    # Keep the package override local to overlays/hunk so future Hunk patches,
    # wrappers, or source pins have a single home instead of being re-exported
    # directly from the llm-agents input in flake.nix.
  });
in
{
  llm-agents = (prev.llm-agents or { }) // {
    inherit hunk;
  };

  inherit hunk;
}
