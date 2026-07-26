{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage {
  pname = "mdr";
  version = "0-unstable-2026-06-15";

  src = fetchFromGitHub {
    owner = "anthrofract";
    repo = "majjit";
    rev = "e90aca245752a10af70b79308e038f8988b39661";
    hash = "sha256-M45ckWqfjwxpG993ArZWDQ84zlhYCRhCGOluFo7EcVY=";
  };

  cargoHash = "sha256-/AAzzFZ8htv6bkoABJEKPsn61O5LWJiwmaUEjVQ0NX0=";

  patches = [
    ./patches/0001-disable-word-wrap-for-structured-log.patch
    ./patches/0002-rebrand-as-mdr.patch
  ];

  doCheck = true;

  meta = with lib; {
    description = "Macro Diff Refinement tool for manipulating the Jujutsu DAG";
    homepage = "https://github.com/anthrofract/majjit";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "mdr";
    platforms = platforms.unix;
  };
}
