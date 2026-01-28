{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  installShellFiles,
}:

stdenvNoCC.mkDerivation rec {
  pname = "git-hunks";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "rockorager";
    repo = "git-hunks";
    rev = "v${version}";
    hash = "sha256-VRscBmZ0Q/vL4B+8mkmQGV4Ppoj1qPpDz0kPAACjV94=";
  };

  nativeBuildInputs = [ installShellFiles ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 git-hunks $out/bin/git-hunks
    installManPage git-hunks.1

    runHook postInstall
  '';

  meta = with lib; {
    description = "Non-interactive selective hunk staging for git";
    homepage = "https://github.com/rockorager/git-hunks";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "git-hunks";
    platforms = platforms.unix;
  };
}
