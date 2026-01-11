{
  lib,
  stdenv,
  python3,
  fetchFromGitHub,
  makeWrapper,
}:

let
  pythonWithLibtmux = python3.withPackages (ps: [ ps.libtmux ]);
in
stdenv.mkDerivation rec {
  pname = "tmux-window-name";
  version = "unstable-2025-01-05";

  src = fetchFromGitHub {
    owner = "ofirgall";
    repo = "tmux-window-name";
    rev = "master";
    hash = "sha256-klS3MoGQnEiUa9RldKGn7D9yxw/9OXbfww43Wi1lV/w=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    # Install tmux plugin files
    mkdir -p $out/share/tmux-plugins/tmux-window-name/scripts

    # Install and patch the main tmux file to use absolute path
    substitute tmux_window_name.tmux $out/share/tmux-plugins/tmux-window-name/tmux_window_name.tmux \
      --replace-fail 'CURRENT_DIR="$( cd "$( dirname "''${BASH_SOURCE[0]}" )" && pwd )"' "CURRENT_DIR=$out/share/tmux-plugins/tmux-window-name"

    # Install scripts and make them executable
    cp scripts/*.py $out/share/tmux-plugins/tmux-window-name/scripts/
    chmod +x $out/share/tmux-plugins/tmux-window-name/scripts/*.py

    # Wrap ONLY the main entry point script (not library modules like path_utils.py)
    # wrapProgram adds shell headers which corrupt Python module imports
    wrapProgram "$out/share/tmux-plugins/tmux-window-name/scripts/rename_session_windows.py" \
      --set PATH "${pythonWithLibtmux}/bin:$PATH"

    chmod +x $out/share/tmux-plugins/tmux-window-name/tmux_window_name.tmux

    runHook postInstall
  '';

  meta = with lib; {
    description = "Automatic window naming for tmux based on running program and path";
    homepage = "https://github.com/ofirgall/tmux-window-name";
    license = licenses.mit;
    maintainers = [ ];
  };
}
