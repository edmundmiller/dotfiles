{ lib, stdenv, makeWrapper, python3 }:

let
  pythonEnv = python3.withPackages (ps: with ps; [ libtmux ]);
in
stdenv.mkDerivation {
  pname = "tmux-opencode-integrated";
  version = "0.1.0";

  src = ./scripts;

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ pythonEnv ];

  installPhase = ''
    mkdir -p $out/share/tmux-plugins/tmux-opencode-integrated/scripts
    cp -r * $out/share/tmux-plugins/tmux-opencode-integrated/scripts/
    
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
