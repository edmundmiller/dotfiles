{
  applyPatches,
  fetchFromGitHub,
}:

applyPatches {
  name = "pi-github-tools-1.0.1";

  src = fetchFromGitHub {
    owner = "PriNova";
    repo = "pi-github-tools";
    rev = "bf229248c65fcbce77377c4b3918ddedfc80dcfd";
    hash = "sha256-VJhWKinjgiByLgY/2nSnn+6t0fg2oPr1yCLZGEkK634=";
  };

  patches = [
    ./patches/0001-use-host-peer-dependencies.patch
  ];
}
