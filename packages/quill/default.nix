{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

let
  # SPM dependencies pinned from upstream Package.resolved. Both are leaf
  # packages (no transitive dependencies), so path-substituting them makes
  # `swift build` fully offline.
  swift-argument-parser = fetchFromGitHub {
    owner = "apple";
    repo = "swift-argument-parser";
    rev = "6a52f3251125d74daf04fcbd5e6f08a75d074382"; # 1.8.2
    hash = "sha256-BWm2ZbNIvlamNp8cxoicFlAcujjhH22VPzs67lEIXWU=";
  };
  fluidaudio = fetchFromGitHub {
    owner = "FluidInference";
    repo = "FluidAudio";
    rev = "19600a485baa4998812e4654b70d2bab8f2c9949"; # 0.15.5
    hash = "sha256-/KTcZLu4G7W+NAOIKLi+SRDq4IpuRw+wwxdTDyPQ2hE=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "quill";
  version = "0-unstable-2026-07-28";

  src = fetchFromGitHub {
    owner = "digimata";
    repo = "quill";
    rev = "7ea94e27cbf403dd1fa14f460b1bea56bf78477d";
    hash = "sha256-YQ4OVDNHlyx3S19VcNI0iwlvIYUkxbR0jcYtd5LbT9c=";
  };

  postPatch = ''
    rm Package.resolved
    cp -R ${swift-argument-parser} ../swift-argument-parser
    cp -R ${fluidaudio} ../FluidAudio
    chmod -R u+w ../swift-argument-parser ../FluidAudio
    substituteInPlace Package.swift \
      --replace-fail \
        '.package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")' \
        '.package(path: "../swift-argument-parser")' \
      --replace-fail \
        '.package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.7.0")' \
        '.package(path: "../FluidAudio")'
  '';

  # quill requires swift-tools 6.0 and the macOS 15 SDK; nixpkgs' `swift`
  # is 5.10 and there is no reproducible Swift 6 toolchain in nixpkgs yet
  # (upstream bootstrapping/SDK-drift work is unfinished as of writing).
  # This derivation is therefore an IMPURE, non-reproducible, host-Xcode
  # build: it shells out to the ambient `/usr/bin/xcrun swift build`.
  # `__noChroot` only takes effect under `sandbox = relaxed` (strict
  # `sandbox = true` rejects this derivation outright); it cannot build on
  # Linux or on a host without Xcode/CLT installed. Because the output
  # depends on the ambient Xcode/SDK version rather than anything encoded
  # in the drv hash, never build remotely or serve this from a binary
  # cache: force a local build with the toolchain actually present.
  __noChroot = true;
  preferLocalBuild = true;
  allowSubstitutes = false;

  buildPhase = ''
    runHook preBuild
    if ! /usr/bin/xcrun --find swift >/dev/null 2>&1; then
      echo "quill requires Xcode / Command Line Tools (xcrun swift) on the build host" >&2
      exit 1
    fi
    export HOME="$TMPDIR/quill-home"
    mkdir -p "$HOME"
    /usr/bin/xcrun swift build -c release --disable-sandbox
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    install -m755 .build/release/quill "$out/bin/quill"
    for bundle in .build/release/*.bundle; do
      [ -e "$bundle" ] && cp -R "$bundle" "$out/bin/"
    done
    runHook postInstall
  '';

  meta = {
    description = "Minimal, fully local macOS meeting recorder and transcriber (impure host-Xcode Swift build)";
    homepage = "https://github.com/digimata/quill";
    platforms = [ "aarch64-darwin" ];
    mainProgram = "quill";
  };
}
