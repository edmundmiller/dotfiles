final: prev: {
  llm-agents = (prev.llm-agents or { }) // {
    gnhf = final.buildNpmPackage rec {
      pname = "gnhf";
      version = "0.1.41";

      src = final.fetchurl {
        url = "https://registry.npmjs.org/gnhf/-/gnhf-${version}.tgz";
        hash = "sha256-LrohL6wV3TboFHzmyt4xnW0y8IE+dvGqdFx35AcuAm8=";
      };

      npmDepsHash = "sha256-W8PYARaFZtNXWXelnvNZ+0rNpd8l0td5oqdqEV0ROpY=";
      dontNpmBuild = true;
      postPatch = ''
        cat > package.json <<'EOF'
        {
          "name": "gnhf",
          "version": "0.1.41",
          "type": "module",
          "dependencies": {
            "commander": "^14.0.3",
            "js-yaml": "^4.1.1"
          },
          "bin": {
            "gnhf": "dist/cli.mjs"
          },
          "engines": {
            "node": ">=20"
          }
        }
        EOF
        cat > package-lock.json <<'EOF'
        {
          "name": "gnhf",
          "version": "0.1.41",
          "lockfileVersion": 3,
          "requires": true,
          "packages": {
            "": {
              "name": "gnhf",
              "version": "0.1.41",
              "dependencies": {
                "commander": "^14.0.3",
                "js-yaml": "^4.1.1"
              },
              "bin": {
                "gnhf": "dist/cli.mjs"
              },
              "engines": {
                "node": ">=20"
              }
            },
            "node_modules/argparse": {
              "version": "2.0.1",
              "resolved": "https://registry.npmjs.org/argparse/-/argparse-2.0.1.tgz",
              "integrity": "sha512-8+9WqebbFzpX9OR+Wa6O29asIogeRMzcGtAINdpMHHyAg10f05aSFVBbcEqGf/PXw1EjAZ+q2/bEBg3DvurK3Q==",
              "license": "Python-2.0"
            },
            "node_modules/commander": {
              "version": "14.0.3",
              "resolved": "https://registry.npmjs.org/commander/-/commander-14.0.3.tgz",
              "integrity": "sha512-H+y0Jo/T1RZ9qPP4Eh1pkcQcLRglraJaSLoyOtHxu6AapkjWVCy2Sit1QQ4x3Dng8qDlSsZEet7g5Pq06MvTgw==",
              "license": "MIT",
              "engines": {
                "node": ">=20"
              }
            },
            "node_modules/js-yaml": {
              "version": "4.2.0",
              "resolved": "https://registry.npmjs.org/js-yaml/-/js-yaml-4.2.0.tgz",
              "integrity": "sha512-ePWsvanv0DWuDRsW8dnt+R4jQ31SCRCQ7hhNcPXZPsoBZiemuZNYGf7adZdqX2D86j6rvKp3RpCxVTSb8WQlOw==",
              "funding": [
                {
                  "type": "github",
                  "url": "https://github.com/sponsors/puzrin"
                },
                {
                  "type": "github",
                  "url": "https://github.com/sponsors/nodeca"
                }
              ],
              "license": "MIT",
              "dependencies": {
                "argparse": "^2.0.1"
              },
              "bin": {
                "js-yaml": "bin/js-yaml.js"
              }
            }
          }
        }
        EOF
      '';

      nativeBuildInputs = [
        final.makeWrapper
        final.nodejs_25
      ];

      installPhase = ''
        runHook preInstall

        mkdir -p "$out/lib/node_modules/gnhf" "$out/bin"
        cp -R . "$out/lib/node_modules/gnhf/"
        makeWrapper ${final.lib.getExe final.nodejs_25} "$out/bin/gnhf" \
          --add-flags "$out/lib/node_modules/gnhf/dist/cli.mjs"

        runHook postInstall
      '';

      passthru.category = "Workflow & Project Management";
      meta = prev.llm-agents.gnhf.meta // {
        mainProgram = "gnhf";
      };
    };
  };
}
