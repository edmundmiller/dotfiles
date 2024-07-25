{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  pname = "llama-fs";
  version = "unstable-2024-05-31";

  src = fetchFromGitHub {
    owner = "iyaja";
    repo = "llama-fs";
    rev = "f18f678a9542c7d9f689279a6aa26f8022d8fa7c";
    hash = "sha256-mPZ6gEia8b9KARI+zo0MzfT2SjSrBjp4/oMpn1ZNfRQ=";
  };

  meta = with lib; {
    description = "";
    homepage = "https://github.com/iyaja/llama-fs";
    license = licenses.mit;
    maintainers = with maintainers; [edmundmiller];
    mainProgram = "llama-fs";
    platforms = platforms.all;
  };
}
