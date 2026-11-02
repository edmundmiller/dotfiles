# Pinned herdr-t3 layout (Apache-2.0).
# https://github.com/JinJieBeWater/herdr-t3
#
# The leading underscore keeps module discovery from importing this file.
# Bump rev and hash together. Keep mods equal to the mods/t3-* directories
# in that commit. The native test fails when they drift. Do not add
# extras/mods/pulls-review or the Maple Mono font here.
{ pkgs }:
let
  rev = "2d4c304f0a5480b4405a28b42f8a8c7d166b3254";
in
{
  inherit rev;
  src = pkgs.fetchFromGitHub {
    owner = "JinJieBeWater";
    repo = "herdr-t3";
    inherit rev;
    hash = "sha256-1PJ5oP4V2ZBPD4S60Q9wxb3Tx8yg7LB9IqK5Ramdl6I=";
  };
  mods = [
    "t3-agents"
    "t3-chrome"
    "t3-focus"
    "t3-new-menu"
    "t3-pane"
    "t3-spaces"
    "t3-tabs"
  ];
}
