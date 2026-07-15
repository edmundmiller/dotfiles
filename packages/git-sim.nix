{
  ffmpeg-headless,
  fetchPypi,
  git-sim,
  python313,
}:

let
  git-dummy = python313.pkgs.git-dummy.overridePythonAttrs {
    postInstall = "";
  };

  package = git-sim.override {
    python3 = python313;
    packageOverrides = final: prev: {
      cloup =
        let
          setuptools-scm-9 = prev.setuptools-scm.overridePythonAttrs rec {
            version = "9.2.2";
            src = fetchPypi {
              pname = "setuptools_scm";
              inherit version;
              hash = "sha256-HGdKtGZWhqCIfX4kwDqyXyQgHCE+guponS8+Fp7371c=";
            };
            dependencies = with final; [
              packaging
              setuptools
              typing-extensions
            ];
          };
        in
        prev.cloup.overridePythonAttrs {
          build-system = [ setuptools-scm-9 ];
        };
      inherit git-dummy;
      manim = prev.manim.override { ffmpeg = ffmpeg-headless; };
      pyglet = prev.pyglet.override { ffmpeg-full = ffmpeg-headless; };
    };
  };
in
package.overrideAttrs {
  postInstall = ''
    ln -s ${git-dummy}/bin/git-dummy $out/bin/
  '';
}
