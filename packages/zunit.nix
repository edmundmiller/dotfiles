{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  zsh,
}:

stdenvNoCC.mkDerivation rec {
  pname = "zunit";
  version = "0.8.2";

  src = fetchFromGitHub {
    owner = "zunit-zsh";
    repo = "zunit";
    rev = "v${version}";
    sha256 = "sha256-LU9sFMGNXPVz2dqqPRIDGTb1d+C8IHxQKsO+7JH8uhg=";
  };

  buildInputs = [ zsh ];

  installPhase = ''
    mkdir -p $out/bin $out/share/zunit
    cp -r * $out/share/zunit/
    
    # Create wrapper script
    cat > $out/bin/zunit << 'EOF'
#!/usr/bin/env zsh
source "${0:A:h}/../share/zunit/zunit"
EOF
    chmod +x $out/bin/zunit
  '';

  meta = with lib; {
    description = "A powerful unit testing framework for ZSH";
    homepage = "https://zunit.xyz";
    license = licenses.mit;
    platforms = platforms.all;
    maintainers = [ ];
  };
}
