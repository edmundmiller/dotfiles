{
  lib,
  stdenvNoCC,
  fetchurl,
  cacert,
  coreutils,
  git,
  writeText,
}:

let
  version = "1.6.14";

  sources = {
    "x86_64-linux" = fetchurl {
      url = "https://usegitai.com/worker/releases/download/v${version}/git-ai-linux-x64";
      hash = "sha256-ybTQ+bYn5NqXAEcn7/Voh2WLHVZfogvKz0C98GmqPIs=";
    };
    "aarch64-linux" = fetchurl {
      url = "https://usegitai.com/worker/releases/download/v${version}/git-ai-linux-arm64";
      hash = "sha256-CterRjh9wlbi6sEpt+Dh4N+TyNSBtJxhdac0rtSEYiE=";
    };
    "x86_64-darwin" = fetchurl {
      url = "https://usegitai.com/worker/releases/download/v${version}/git-ai-macos-x64";
      hash = "sha256-ioM7E9tELovjfDBB3IGE9V54ZOJwKBCLJkd+PVCXpAk=";
    };
    "aarch64-darwin" = fetchurl {
      url = "https://usegitai.com/worker/releases/download/v${version}/git-ai-macos-arm64";
      hash = "sha256-GfkaEAnPx1V7dP7HNGAlifRbQSdHihJ54BT0eF1siwg=";
    };
  };

  src =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "Unsupported platform: ${stdenvNoCC.hostPlatform.system}");

  certFile = "${cacert}/etc/ssl/certs/ca-bundle.crt";

  linuxCertSetup = lib.optionalString stdenvNoCC.hostPlatform.isLinux ''
    if [ -z "''${SSL_CERT_FILE:-}" ] && [ -e "${certFile}" ]; then
      export SSL_CERT_FILE="${certFile}"
    fi
    if [ -z "''${NIX_SSL_CERT_FILE:-}" ] && [ -e "${certFile}" ]; then
      export NIX_SSL_CERT_FILE="${certFile}"
    fi
  '';

  wrapper = writeText "git-ai-wrapper" ''
    #!${stdenvNoCC.shell}
    set -euo pipefail

    script_path="$0"
    resolved_path="$(${coreutils}/bin/readlink -f "$script_path" 2>/dev/null || true)"
    if [ -n "$resolved_path" ]; then
      script_path="$resolved_path"
    fi

    self_dir="$(${coreutils}/bin/dirname "$script_path")"
    pkg_root="$(${coreutils}/bin/dirname "$self_dir")"

    export PATH="$self_dir:''${PATH:-}"

    if [ -n "''${HOME:-}" ]; then
      config_dir="$HOME/.git-ai"
      config_file="$config_dir/config.json"
      if [ ! -e "$config_file" ]; then
        ${coreutils}/bin/mkdir -p "$config_dir"
        tmp="$config_file.tmp.$$"
        ${coreutils}/bin/cat > "$tmp" <<'JSON'
    {
      "git_path": "${git}/bin/git"
    }
    JSON
        ${coreutils}/bin/mv "$tmp" "$config_file"
        ${coreutils}/bin/chmod 0644 "$config_file" 2>/dev/null || true
      fi
    fi

    ${linuxCertSetup}

    exec -a git-ai "$pkg_root/share/git-ai/git-ai-unwrapped" "$@"
  '';
in
stdenvNoCC.mkDerivation {
  pname = "git-ai";
  inherit version src;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/share/git-ai/git-ai-unwrapped
    install -Dm755 ${wrapper} $out/bin/git-ai

    # Provide the real git binary under the upstream helper name so hook
    # integrations can bypass git-ai when they need plain git.
    ln -s ${git}/bin/git $out/bin/git-og

    # Some GUI integrations expect git's libexec helpers next to the git binary.
    if [ -e ${git}/libexec ]; then
      ln -s ${git}/libexec $out/libexec
    fi

    runHook postInstall
  '';

  meta = with lib; {
    description = "AI-powered git extension with context layer and ai-blame";
    homepage = "https://usegitai.com";
    license = licenses.unfree;
    maintainers = [ ];
    mainProgram = "git-ai";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
}
