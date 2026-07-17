final: prev:

let
  paaPatches = [
    ./patches/0001-skip-unparseable-paa-certs.patch
    ./patches/0002-test-skip-unparseable-paa-certs.patch
  ];

  # Prefer overrideAttrs so callPackage's `.override { withDashboard = … }`
  # remains available for the dashboard self-build.
  withPaaPatches = old: {
    patches = (old.patches or [ ]) ++ paaPatches;
  };
in
{
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (_pyFinal: pyPrev: {
      python-matter-server = pyPrev.python-matter-server.overrideAttrs withPaaPatches;
    })
  ];

  # Re-derive the CLI application from the patched python package set.
  python-matter-server =
    with final.python3Packages;
    toPythonApplication (
      python-matter-server.overridePythonAttrs (old: {
        dependencies = old.dependencies ++ old.optional-dependencies.server;
      })
    );
}
