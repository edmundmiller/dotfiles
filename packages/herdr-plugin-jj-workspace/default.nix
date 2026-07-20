{
  lib,
  rustPlatform,
  fetchFromGitHub,
  coreutils,
  gitMinimal,
  jujutsu,
}:

rustPlatform.buildRustPackage {
  pname = "herdr-plugin-jj-workspace";
  version = "0.1.0-unstable-2026-07-19";

  src = fetchFromGitHub {
    owner = "NathanFlurry";
    repo = "herdr-plugin-jj-workspace";
    rev = "a9f1d3bcdaa2354e336a5173da85cbe4970c0f2e";
    hash = "sha256-xspdQfcwTEdUwZ0nWAfrdvz5IBVNVyMkmpmpzkUl0LE=";
  };

  # This repo carries the lifecycle-safety work locally; upstream PR #4 is
  # provenance only, not a deployment dependency.
  patches = [
    ./patches/0001-make-jj-workspace-lifecycle-safe.patch
  ];

  postPatch = ''
    substituteInPlace src/main.rs \
      --replace-fail /bin/mkdir ${lib.getExe' coreutils "mkdir"}
  '';

  cargoHash = "sha256-DhRLJs6ikN1q6TY+D7ghffvWdwCVMhw9YJL4D7TARt4=";

  nativeCheckInputs = [
    gitMinimal
    jujutsu
  ];

  postInstall = ''
    plugin_dir="$out/share/herdr/plugins/nathanflurry-jj-workspace"
    mkdir -p "$plugin_dir/target/release"
    cp herdr-plugin.toml README.md LICENSE "$plugin_dir/"
    cp "$out/bin/jj-workspace" "$plugin_dir/target/release/"
  '';

  meta = {
    description = "Create and safely remove Jujutsu workspaces from Herdr";
    homepage = "https://github.com/NathanFlurry/herdr-plugin-jj-workspace";
    license = lib.licenses.mit;
    mainProgram = "jj-workspace";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
