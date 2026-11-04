{ lib, upstream }:
let
  auditedSources = [
    {
      path = "/modules/users/default.nix";
      sha256 = "08f4abea7ce4a553283e1947c5a8f87fe6d304b1ca0c29443e0f50df4b4a9fdf";
    }
    {
      path = "/modules/system/applications.nix";
      sha256 = "89d23112a2a2ed3a29137d1aefc5ad8f81de2942bbbe91faf66c24792d7b5b6e";
    }
  ];
  audited = lib.all (
    source: builtins.hashFile "sha256" (upstream + source.path) == source.sha256
  ) auditedSources;
  recoveryBlocks = [
    {
      service = "SystemPolicySysAdminFiles";
      indent = "      ";
      text = ''
        # The TCC service required to change home directories is `kTCCServiceSystemPolicySysAdminFiles`
        # and we can reset it to ensure the user gets another prompt
        tccutil reset SystemPolicySysAdminFiles > /dev/null

        if ! dscl . -change /Users/nobody NFSHomeDirectory "$homeDirectory" "$homeDirectory" &> /dev/null; then
          printf >&2 '\e[1;31merror: permission denied when trying to %s user %s, aborting activation\e[0m\n' "$2" "$1"
          printf >&2 '`darwin-rebuild` requires permissions to administrate your computer,\n'
          printf >&2 'please accept the dialog that pops up.\n'
          printf >&2 '\n'
          printf >&2 'If you do not wish to be prompted every time `darwin-rebuild` updates your users,\n'
          printf >&2 'you can grant Full Disk Access to your terminal emulator in System Settings.\n'
          printf >&2 '\n'
          printf >&2 'This can be found in System Settings > Privacy & Security > Full Disk Access.\n'
          exit 1
        fi
      '';
    }
    {
      service = "SystemPolicyAppBundles";
      indent = "    ";
      text = ''
        # The TCC service required to modify notarised app bundles is `kTCCServiceSystemPolicyAppBundles`
        # and we can reset it to ensure the user gets another prompt
        tccutil reset SystemPolicyAppBundles > /dev/null

        if ! ensureAppManagement; then
          printf >&2 '\e[1;31merror: permission denied when trying to update apps, aborting activation\e[0m\n'
          printf >&2 '`darwin-rebuild` requires permission to update your apps, please accept the notification\n'
          printf >&2 'and grant the permission for your terminal emulator in System Settings.\n'
          printf >&2 '\n'
          printf >&2 'If you did not get a notification, you can navigate to System Settings > Privacy & Security > App Management.\n'
          exit 1
        fi
      '';
    }
  ];
  recoveryText =
    block:
    lib.concatStringsSep "\n" (
      lib.imap0 (index: line: lib.optionalString (index > 0 && line != "") block.indent + line) (
        lib.splitString "\n" (lib.removeSuffix "\n" block.text)
      )
    );
  abortCommand = block: ''
    printf >&2 '%s\n' 'error: MacTraitor-Pro refuses automatic TCC reset for ${block.service}; activation aborted. Fix permissions manually, then retry hey re.'
    exit 1
  '';
  occurrences = needle: text: builtins.length (lib.splitString needle text) - 1;
  rejectReset =
    name: text:
    assert lib.assertMsg (!lib.hasInfix "tccutil" (lib.toLower text))
      "MacTraitor-Pro activation fragment '${name}' contains an unreviewed TCC command; refusing activation.";
    text;
in
name: text:
assert lib.assertMsg audited
  "MacTraitor-Pro fail-closed activation: nix-darwin permission-check sources changed; review the TCC guard before rebuilding.";
if name != "checks" then
  rejectReset name text
else
  let
    before = map recoveryText recoveryBlocks;
    counts = map (block: occurrences block text) before;
    guarded = builtins.replaceStrings before (map abortCommand recoveryBlocks) text;
  in
  assert lib.assertMsg (builtins.elemAt counts 0 <= 1 && builtins.elemAt counts 1 == 1)
    "MacTraitor-Pro fail-closed activation: permission-check recovery shape changed; refusing activation.";
  rejectReset name guarded
