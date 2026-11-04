{
  macTraitorConfig,
  seqeratopConfig,
  inputs,
  pkgs,
}:
let
  inherit (pkgs) lib;
  personal = macTraitorConfig.config;
  work = seqeratopConfig.config;
  guard = import ../_lib/fail-closed-tcc-reset.nix {
    inherit lib;
    upstream = inputs.nix-darwin.outPath;
  };
  appReset = "tccutil reset SystemPolicyAppBundles > /dev/null";
  userReset = "tccutil reset SystemPolicySysAdminFiles > /dev/null";
  fixture = activeUsers.config.system.checks.text;
  contextFixture = fixture + "\n# ${pkgs.writeText "tcc-context-sentinel" "context"}\n";
  rejects = text: !(builtins.tryEval (guard "checks" text)).success;
  unreviewedGuard = import ../_lib/fail-closed-tcc-reset.nix {
    inherit lib;
    upstream = ./fixtures/unreviewed-upstream;
  };
  activeUsers = macTraitorConfig.extendModules {
    modules = [
      {
        # Evaluation-only: never activate this synthetic account configuration.
        users.knownUsers = lib.mkForce [ "nix-tcc-check-fixture" ];
        users.users.nix-tcc-check-fixture = {
          uid = 65001;
          gid = 20;
          home = "/var/empty";
          shell = pkgs.bash;
          ignoreShellProgramCheck = true;
        };
      }
    ];
  };
  inactiveUsers = macTraitorConfig.extendModules {
    modules = [
      { users.knownUsers = lib.mkForce [ ]; }
    ];
  };
  textModule = import "${inputs.nix-darwin}/modules/lib/write-text.nix" {
    inherit lib;
    mkTextDerivation = name: text: pkgs.writeScript "fixture-${name}" text;
  };
  merged =
    (lib.evalModules {
      specialArgs = { inherit inputs; };
      modules = [
        {
          options.system.activationScripts = lib.mkOption {
            type = lib.types.attrsOf (lib.types.submodule textModule);
            default = { };
          };
          config.system.activationScripts.checks.text = lib.mkBefore fixture;
          config.system.activationScripts.unrelated.text = "printf unchanged";
        }
        ../fail-closed-activation.nix
        { system.activationScripts.checks.text = lib.mkAfter "# later contribution"; }
      ];
    }).config.system.activationScripts;
  assertions = [
    {
      test = !(lib.hasInfix "nix-tcc-check-fixture" personal.system.activationScripts.script.text);
      msg = "The evaluation-only account must never enter the deployed activation";
    }
    {
      test = !(lib.hasInfix "tccutil" personal.system.activationScripts.script.text);
      msg = "MacTraitor-Pro full activation must not invoke TCC tooling";
    }
    {
      test = lib.hasInfix "refuses automatic TCC reset" personal.system.activationScripts.checks.text;
      msg = "MacTraitor-Pro must abort rather than reset privacy permissions";
    }
    {
      test = lib.hasInfix "ensureAppManagement()" personal.system.activationScripts.checks.text;
      msg = "The actual application permission probe must remain enabled";
    }
    {
      test = lib.hasInfix appReset work.system.activationScripts.checks.text;
      msg = "Seqeratop must retain its existing upstream permission policy";
    }
    {
      test = !(lib.hasInfix "refuses automatic TCC reset" work.system.activationScripts.script.text);
      msg = "The MacTraitor-Pro guard must not affect Seqeratop";
    }
    {
      test = !(lib.hasInfix "ensurePerms()" inactiveUsers.config.system.activationScripts.checks.text);
      msg = "The guard must support inactive managed-user checks";
    }
    {
      test = !(lib.hasInfix "tccutil" inactiveUsers.config.system.activationScripts.checks.text);
      msg = "Inactive user checks must not bypass the application guard";
    }
    {
      test = builtins.getContext (guard "checks" contextFixture) == builtins.getContext contextFixture;
      msg = "Guarding text must retain its Nix dependency context";
    }
    {
      test = rejects (fixture + "\n" + appReset) && rejects (fixture + "\n" + userReset);
      msg = "Duplicated reset commands must fail evaluation";
    }
    {
      test = rejects (fixture + "\ntccutil reset UnknownService") && rejects userReset;
      msg = "New or missing reset shapes must fail evaluation";
    }
    {
      test =
        rejects (fixture + "\nTCCUTIL reset UnknownService")
        && !(builtins.tryEval (guard "preActivation" "TCCUTIL reset UnknownService")).success;
      msg = "Unknown TCC commands in any fragment must fail regardless of filename case";
    }
    {
      test = !(builtins.tryEval (unreviewedGuard "checks" appReset)).success;
      msg = "Upstream source drift must fail even when user checks are inactive";
    }
    {
      test =
        merged.unrelated.text == "printf unchanged"
        && lib.hasInfix "# later contribution" merged.checks.text
        && !(lib.hasInfix "tccutil" merged.checks.text);
      msg = "Actual-library submodule merging must guard merged checks without changing other fragments";
    }
  ];
  failures = lib.filter (item: !item.test) assertions;
  # These fixtures inspect script bytes without executing their store references.
  # Keep the real generated source, but do not build its referenced host closure.
  scriptFixture =
    source:
    source.overrideAttrs (old: {
      text = builtins.unsafeDiscardStringContext old.text;
    });
  textFixture = name: text: pkgs.writeText name (builtins.unsafeDiscardStringContext text);
  checksSource = scriptFixture personal.system.activationScripts.checks.source;
  scriptSource = scriptFixture personal.system.activationScripts.script.source;
  userChecksSource = scriptFixture activeUsers.config.system.activationScripts.checks.source;
  expectedChecks = textFixture "expected-fail-closed-checks" personal.system.activationScripts.checks.text;
  expectedScript = textFixture "expected-fail-closed-script" personal.system.activationScripts.script.text;
  rawChecks = textFixture "raw-permission-checks" personal.system.checks.text;
  forbiddenRuntime = pkgs.runCommand "activation-fixture-runtime-must-not-build" { } ''
    echo "A content-only activation fixture tried to build a runtime dependency" >&2
    exit 1
  '';
  contextProbe = scriptFixture (
    pkgs.writeScript "activation-context-probe" "echo ${forbiddenRuntime}"
  );
in
assert lib.assertMsg (failures == [ ]) (lib.concatMapStringsSep "\n" (item: item.msg) failures);
pkgs.runCommand "mactraitor-fail-closed-activation"
  {
    passthru = { inherit assertions failures; };
  }
  ''
        export PYTHONDONTWRITEBYTECODE=1
      # Match nix-darwin's existing output-message exclusions; SC2317 stays enabled.
    ${pkgs.shellcheck}/bin/shellcheck --exclude=SC2016,SC1112 ${scriptSource}
        ${pkgs.python3}/bin/python ${./test_fail_closed_activation.py} \
          --raw-checks ${rawChecks} \
          --checks-source ${checksSource} \
        --raw-user-checks ${textFixture "raw-active-user-checks" activeUsers.config.system.checks.text} \
        --user-checks-source ${userChecksSource} \
          --expected-checks ${expectedChecks} \
          --script-source ${scriptSource} \
          --expected-script ${expectedScript} \
          --bash ${pkgs.bash}/bin/bash
        ${pkgs.diffutils}/bin/cmp ${scriptFixture merged.checks.source} ${textFixture "expected-merged-checks" merged.checks.text}
        ${pkgs.gnugrep}/bin/grep -F 'echo /nix/store/' ${contextProbe}
        touch "$out"
  ''
