{
  lib,
  stdenv,
  python3,
}:

let
  pythonTestEnv = python3.withPackages (ps: [ ps.pytest ]);
in
stdenv.mkDerivation {
  pname = "tmux-opencode-integrated";
  version = "0.2.0";

  src = ./.;

  nativeCheckInputs = [ pythonTestEnv ];

  doCheck = true;
  checkPhase = ''
    pytest -q tests
  '';

  installPhase = ''
    mkdir -p $out/share/tmux-plugins/tmux-opencode-integrated/scripts
    cp -r scripts/* $out/share/tmux-plugins/tmux-opencode-integrated/scripts/

    chmod +x $out/share/tmux-plugins/tmux-opencode-integrated/scripts/smart-name.sh
    chmod +x $out/share/tmux-plugins/tmux-opencode-integrated/scripts/smart_name.py
  '';

  meta = with lib; {
    description = "Integrated tmux smart naming and AI agent status";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
