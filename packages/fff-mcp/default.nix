{
  lib,
  fetchurl,
  stdenvNoCC,
}:
let
  version = "0.10.1";
  targets = {
    x86_64-linux = {
      triple = "x86_64-unknown-linux-musl";
      hash = "sha256-wXY3wzOvu73qSwPPPhVzJAxBR64SF1bjY6r6PJ0O+1g=";
    };
    aarch64-linux = {
      triple = "aarch64-unknown-linux-musl";
      hash = "sha256-KiUBkQHuk3MyfavXrB1IAGOGiOlbZ7+zvsRBv42Tjyg=";
    };
    x86_64-darwin = {
      triple = "x86_64-apple-darwin";
      hash = "sha256-08jXDUergK+iKH4bRUayP0lLtGBLgOWnBqCvcU7iVnQ=";
    };
    aarch64-darwin = {
      triple = "aarch64-apple-darwin";
      hash = "sha256-7/ZmCpxI4+GXLVV8EAPgV+X/mdYDn1+BBnHyEjCT/fw=";
    };
  };
  target =
    targets.${stdenvNoCC.hostPlatform.system}
      or (throw "fff-mcp: unsupported system ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "fff-mcp";
  inherit version;

  src = fetchurl {
    url = "https://github.com/dmtrKovalenko/fff.nvim/releases/download/v${version}/fff-mcp-${target.triple}";
    inherit (target) hash;
  };

  dontUnpack = true;
  dontFixup = true;

  installPhase = ''
    mkdir -p "$out/bin"
    install -m755 "$src" "$out/bin/fff-mcp"
  '';

  meta = with lib; {
    description = "Fast file finder MCP server";
    homepage = "https://github.com/dmtrKovalenko/fff.nvim";
    license = licenses.mit;
    mainProgram = "fff-mcp";
    platforms = platforms.unix;
  };
}
