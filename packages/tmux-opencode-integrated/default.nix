{
  lib,
  stdenv,
  python3,
  makeWrapper,
}:

let
  pythonEnv = python3.withPackages (ps: [ ps.libtmux ]);
  pythonTestEnv = python3.withPackages (ps: [
    ps.libtmux
    ps.pytest
  ]);
in
stdenv.mkDerivation {
  pname = "tmux-opencode-integrated";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ pythonEnv ];
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

    wrapProgram $out/share/tmux-plugins/tmux-opencode-integrated/scripts/smart-name.sh \
      --prefix PATH : ${lib.makeBinPath [ pythonEnv ]}
  '';

  meta = with lib; {
    description = "Integrated tmux smart naming and OpenCode status";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
