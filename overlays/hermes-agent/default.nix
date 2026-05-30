_final: prev:

{
  llm-agents = (prev.llm-agents or { }) // {
    "hermes-agent" = prev.llm-agents."hermes-agent".overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        ../../patches/hermes-agent/0002-normalize-auto-title-inputs.patch
      ];
    });
  };
}
