{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
pname: version:
rustPlatform.buildRustPackage {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "sassman";
    repo = "amoxide-rs";
    rev = "v${version}";
    hash = "sha256-J2WdPKFLnNPt4KqEoyUJ6qG/mav3ymDTZwtg9eZ6p44=";
  };

  cargoBuildFlags = [
    "-p"
    pname
  ];

  cargoInstallFlags = [
    "-p"
    pname
  ];

  cargoHash = "sha256-sGxFhOXwODTKLcy/GnAyipwrGpoh4sU3sEo6jVyO5M8=";

  doCheck = false;

  meta = with lib; {
    description = "Context-aware shell alias manager";
    homepage = "https://amoxide.rs/";
    license = licenses.gpl3Only;
    maintainers = [ ];
    platforms = platforms.unix;
  };
}
