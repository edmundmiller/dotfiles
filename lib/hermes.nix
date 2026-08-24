{ lib, ... }:

{
  renderHermesSettings =
    {
      timezone ? "",
      settings ? { },
    }:
    let
      defaults = lib.optionalAttrs (timezone != "") { inherit timezone; } // {
        kanban.dispatch_in_gateway = true;
      };
    in
    lib.recursiveUpdate (lib.recursiveUpdate defaults settings) {
      model.openai_runtime = "auto";
    };
}
