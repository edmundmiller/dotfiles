# Pure Nix eval: enabled Darwin hosts install Tinybar beside CodexBar.
{
  macTraitorConfig,
  seqeratopConfig,
  pkgs,
}:
let
  inherit (builtins) filter isAttrs length;
  inherit (pkgs.lib)
    any
    concatMapStrings
    escapeShellArg
    findFirst
    hasInfix
    splitString
    ;

  personal = macTraitorConfig.config;
  work = seqeratopConfig.config;

  tinybarCask = "thiloreintjes/tinybar/tinybar";
  tinybarTap = "thiloreintjes/tinybar";

  itemName = item: if isAttrs item then (item.name or "") else item;
  hasCask = name: host: any (cask: itemName cask == name) (host.homebrew.casks or [ ]);
  matchingTaps = name: host: filter (tap: itemName tap == name) (host.homebrew.taps or [ ]);
  brewfileLines = host: splitString "\n" (host.homebrew.brewfile or "");
  brewfileLine = needle: host: findFirst (line: hasInfix needle line) "" (brewfileLines host);

  hostAssertions = host: name: [
    {
      test = host.modules.desktop.apps.tinybar.enable or false;
      msg = "${name} must enable the Tinybar module";
    }
    {
      test = hasCask tinybarCask host;
      msg = "${name} must declare the Tinybar Homebrew cask";
    }
    {
      test =
        let
          taps = matchingTaps tinybarTap host;
        in
        length taps == 1 && (builtins.head taps).trusted or false;
      msg = "${name} must trust the thiloreintjes/tinybar tap";
    }
    {
      test =
        !(any (cask: itemName cask == tinybarCask && isAttrs cask && (cask.greedy or null) == true) (
          host.homebrew.casks or [ ]
        ));
      msg = "${name} must not mark Tinybar greedy, so activation does not upgrade it";
    }
    {
      test = brewfileLine tinybarCask host == ''cask "${tinybarCask}", trusted: true'';
      msg = "${name} Brewfile must list Tinybar without a greedy upgrade";
    }
    {
      test = brewfileLine tinybarTap host == ''tap "${tinybarTap}", trusted: true'';
      msg = "${name} Brewfile must tap thiloreintjes/tinybar as trusted";
    }
    {
      test = (host.homebrew.onActivation.cleanup or "none") == "none";
      msg = "${name} must leave Homebrew cleanup off so activation does not uninstall casks";
    }
    {
      test = !(host.homebrew.onActivation.upgrade or false);
      msg = "${name} must pass brew bundle --no-upgrade so activation leaves Tinybar's popover updates alone";
    }
    {
      test = host.nix-homebrew.mutableTaps or false;
      msg = "${name} must keep Homebrew taps mutable so Tinybar can upgrade its own tap";
    }
  ];

  assertions =
    (hostAssertions personal "MacTraitor-Pro")
    ++ (hostAssertions work "Seqeratop")
    ++ [
      {
        test = hasCask "steipete/tap/codexbar" personal;
        msg = "MacTraitor-Pro must keep CodexBar installed beside Tinybar";
      }
    ];

  failures = filter (assertion: !assertion.test) assertions;
in
pkgs.runCommand "tinybar-darwin-assertions"
  {
    passthru = {
      inherit assertions failures;
    };
  }
  ''
    if [ ${toString (length failures)} -ne 0 ]; then
      echo "${toString (length failures)} Tinybar Darwin assertions failed" >&2
      ${concatMapStrings (failure: ''
        echo ${escapeShellArg failure.msg} >&2
      '') failures}
      exit 1
    fi
    mkdir -p "$out"
    echo "All Tinybar Darwin assertions passed." > "$out/result"
  ''
