_final: prev: {
  nixVersions = prev.nixVersions.extend (
    _versions: previousVersions: {
      # Nix 2.35.1 can strand slot waiters when another process finishes a build.
      # Backport upstream fba3f6e until nixpkgs carries the fixed release.
      nixComponents_2_35 =
        assert previousVersions.nixComponents_2_35.version == "2.35.1";
        previousVersions.nixComponents_2_35.appendPatches [
          ./patches/0001-fix-lost-build-slot-wakeups.patch
        ];
    }
  );
}
