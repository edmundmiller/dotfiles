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
      null
    else if builtins.isString revision && builtins.match "[0-9a-f]{40}" revision != null then
      revision
    else
      throw "${name} deployment revision must be an exact 40-character lowercase Git revision";

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

  configurationRevision =
    if dotfilesRevision != null && agentsWorkspaceRevision != null then
      "dotfiles=${dotfilesRevision};agents-workspace=${agentsWorkspaceRevision}"
    else
      null;
}
