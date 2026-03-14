# QMD bootstrap package for NixOS/Darwin.
#
# Ships pinned upstream source + package-lock, then bootstraps a writable
# runtime under ~/.local/state/qmd on first use to avoid read-only Nix store
# issues from node-llama-cpp and better-sqlite3.
{
  bash,
  cmake,
  coreutils,
  fetchFromGitHub,
  gcc,
  gnumake,
  lib,
  nodejs,
  pkg-config,
  python3,
  stdenvNoCC,
  util-linux,
}:
let
  rev = "ae3604cb884be718696dfeefc4cec64a3dc84357";
  version = "2.0.1-${lib.substring 0 7 rev}";
  runtimeId = "${version}-node${nodejs.version}-v1";
  qmdSource = fetchFromGitHub {
    owner = "tobi";
    repo = "qmd";
    inherit rev;
    hash = "sha256-NGrAPxNCUgZd3CDztXk2kGKQFMgewlDzKKZzkZnUhPM=";
  };
  runtimePath = lib.makeBinPath [
    nodejs
    python3
    gcc
    gnumake
    cmake
    pkg-config
  ];
in
stdenvNoCC.mkDerivation {
  pname = "qmd";
  inherit version;
  src = qmdSource;

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/qmd-src $out/bin
    cp -R ./. $out/share/qmd-src/
    chmod -R u+w $out/share/qmd-src
    cp ${./package-lock.json} $out/share/qmd-src/package-lock.json

    cat > $out/bin/qmd <<'EOF'
    #!${bash}/bin/bash
    set -euo pipefail

    export HOME="''${HOME:-$(cd ~ && pwd)}"
    export XDG_CACHE_HOME="''${XDG_CACHE_HOME:-$HOME/.cache}"
    export XDG_CONFIG_HOME="''${XDG_CONFIG_HOME:-$HOME/.config}"
    export XDG_STATE_HOME="''${XDG_STATE_HOME:-$HOME/.local/state}"

    : "''${QMD_CONFIG_DIR:=$XDG_CONFIG_HOME/qmd}"
    : "''${NODE_LLAMA_CPP_GPU:=off}"
    : "''${NODE_LLAMA_CPP_SKIP_DOWNLOAD:=false}"
    : "''${NODE_LLAMA_CPP_XPACKS_STORE_FOLDER:=$XDG_CACHE_HOME/qmd/node-llama/xpacks/store}"
    : "''${NODE_LLAMA_CPP_XPACKS_CACHE_FOLDER:=$XDG_CACHE_HOME/qmd/node-llama/xpacks/cache}"
    : "''${npm_config_cache:=$XDG_CACHE_HOME/qmd/npm}"

    export QMD_CONFIG_DIR
    export NODE_LLAMA_CPP_GPU
    export NODE_LLAMA_CPP_SKIP_DOWNLOAD
    export NODE_LLAMA_CPP_XPACKS_STORE_FOLDER
    export NODE_LLAMA_CPP_XPACKS_CACHE_FOLDER
    export npm_config_cache
    export npm_config_update_notifier=false
    export npm_config_fund=false
    export npm_config_audit=false
    export npm_config_progress=false
    export npm_config_yes=true
    export npm_config_python="${python3}/bin/python3"
    export PATH="${runtimePath}:$PATH"

    runtime_root="$XDG_STATE_HOME/qmd/runtime"
    runtime_dir="$runtime_root/${runtimeId}"
    lock_dir="$XDG_STATE_HOME/qmd"
    source_dir="$(cd "$(dirname "$0")/../share/qmd-src" && pwd)"

    mkdir -p \
      "$QMD_CONFIG_DIR" \
      "$XDG_CACHE_HOME/qmd/models" \
      "$NODE_LLAMA_CPP_XPACKS_STORE_FOLDER" \
      "$NODE_LLAMA_CPP_XPACKS_CACHE_FOLDER" \
      "$runtime_root" \
      "$lock_dir"

    exec 9>"$lock_dir/bootstrap.lock"
    ${util-linux}/bin/flock 9

    if [ ! -f "$runtime_dir/.bootstrap-complete" ]; then
      rm -rf "$runtime_dir"
      mkdir -p "$runtime_dir"
      ${coreutils}/bin/cp -R "$source_dir"/. "$runtime_dir"/
      chmod -R u+w "$runtime_dir"
      cd "$runtime_dir"

      ${nodejs}/bin/npm ci --include=optional
      rm -rf \
        node_modules/@node-llama-cpp/linux-x64-cuda \
        node_modules/@node-llama-cpp/linux-x64-cuda-ext \
        node_modules/@node-llama-cpp/linux-x64-vulkan
      ${nodejs}/bin/npm run build
      touch .bootstrap-complete
    fi

    exec ${nodejs}/bin/node "$runtime_dir/dist/cli/qmd.js" "$@"
    EOF

    chmod +x $out/bin/qmd

    runHook postInstall
  '';

  meta = with lib; {
    description = "Pinned QMD wrapper that bootstraps a writable runtime outside the Nix store";
    homepage = "https://github.com/tobi/qmd";
    license = licenses.mit;
    mainProgram = "qmd";
    platforms = platforms.unix;
  };
}
