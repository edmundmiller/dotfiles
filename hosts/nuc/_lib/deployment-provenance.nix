{
  lib,
  self,
  agentsWorkspace,
  markerPath,
}:
let
  validateRevision =
    name: revision:
    if revision == null then
      throw "${name} deployment revision is missing"
    else if builtins.isString revision && builtins.match "[0-9a-f]{40}(-dirty)?" revision != null then
      revision
    else
      throw "${name} deployment revision must be a 40-character lowercase Git revision, optionally suffixed with -dirty";

  markerRevision =
    if builtins.pathExists markerPath then
      lib.removeSuffix "\n" (builtins.readFile markerPath)
    else
      null;
  dotfilesRevision = validateRevision "dotfiles" (self.rev or markerRevision);
  agentsWorkspaceRevision = validateRevision "agents-workspace" (agentsWorkspace.rev or null);
in
{
  inherit dotfilesRevision agentsWorkspaceRevision;

  configurationRevision = "dotfiles=${dotfilesRevision};agents-workspace=${agentsWorkspaceRevision}";
}
