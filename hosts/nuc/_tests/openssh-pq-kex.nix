{ nixosConfig, pkgs }:
let
  kexAlgorithms = nixosConfig.config.services.openssh.settings.KexAlgorithms;
  inherit (pkgs.lib) elem;
  assertions = [
    {
      test = elem "mlkem768x25519-sha256" kexAlgorithms;
      msg = "NUC OpenSSH must offer the ML-KEM hybrid post-quantum key exchange.";
    }
    {
      test = elem "sntrup761x25519-sha512" kexAlgorithms;
      msg = "NUC OpenSSH must retain the NTRU Prime hybrid post-quantum key exchange.";
    }
    {
      test = elem "curve25519-sha256" kexAlgorithms;
      msg = "NUC OpenSSH must retain the Replay Echo-compatible curve25519 key exchange.";
    }
  ];
  failures = builtins.filter (assertion: !assertion.test) assertions;
in
pkgs.runCommand "nuc-openssh-pq-kex" { } ''
  if [ ${toString (builtins.length failures)} -ne 0 ]; then
    cat >&2 <<'EOF'
  NUC OpenSSH post-quantum KEX assertions failed:
  ${builtins.concatStringsSep "\n" (map (failure: "- ${failure.msg}") failures)}
  EOF
    exit 1
  fi

  touch "$out"
''
