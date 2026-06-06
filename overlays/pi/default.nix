final: prev:
let
  version = "0.78.1";

  srcWithLock = final.runCommand "pi-src-with-lock-${version}" { } ''
    mkdir -p $out
    tar -xzf ${
      final.fetchurl {
        url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
        hash = "sha256-72mCHDg9kv0n59mtvcseN2IUQelMUjSOR6KQHqnX3Qw=";
      }
    } -C $out --strip-components=1
    rm -f $out/npm-shrinkwrap.json
    cp ${./package-lock.json} $out/package-lock.json
    chmod u+w $out/package-lock.json
    truncate -s -1 $out/package-lock.json
  '';
in
{
  llm-agents = (prev.llm-agents or { }) // {
    # Temporary override until numtide/llm-agents.nix packages Pi >= 0.78.1.
    pi = prev.llm-agents.pi.overrideAttrs (_old: {
      inherit version;
      src = srcWithLock;
      npmDepsHash = "sha256-D+qsBPRAoEB5L0vSgsjNhAswybeQ0kBtXO/Hj/edpuo=";
      npmDeps = final.fetchNpmDeps {
        src = srcWithLock;
        name = "pi-${version}-npm-deps";
        hash = "sha256-D+qsBPRAoEB5L0vSgsjNhAswybeQ0kBtXO/Hj/edpuo=";
        fetcherVersion = 2;
      };
    });
  };
}
