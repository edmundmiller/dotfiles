{
  lib,
  fetchCrate,
  rustPlatform,
}:
rustPlatform.buildRustPackage rec {
  pname = "diffs-rs";
  version = "0.2.5";

  # The crate tarball ships Cargo.lock; GitHub has no release tags yet.
  src = fetchCrate {
    inherit pname version;
    hash = "sha256-aiEvNk8f5MLlVALGJLMcUhsuDnEByDkxabUwKdeAKWk=";
  };

  cargoHash = "sha256-i1ZyFlLKM5R5AUTpDSg47gS0qx/KL1yiN7FACLuHwgk=";

  # The crate tarball omits fixtures/ that the unit tests include_bytes!.
  doCheck = false;

  meta = {
    description = "Fast terminal diff viewer";
    homepage = "https://github.com/plannotator/diffs-rs";
    license = lib.licenses.asl20;
    mainProgram = "diffs";
    platforms = lib.platforms.unix;
  };
}
