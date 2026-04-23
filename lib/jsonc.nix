{ lib, ... }:
let
  trimStart = lib.trimWith {
    start = true;
    end = false;
  };
  trimEnd = lib.trimWith {
    start = false;
    end = true;
  };
in
rec {
  # Convert a JSONC string (with // comments and trailing commas) to clean JSON.
  stripJsoncComments =
    raw:
    let
      lines = lib.splitString "\n" raw;
      # Drop full-line // comments, then strip inline " //" suffixes.
      stripped = map
        (line:
          let parts = lib.splitString " //" line;
          in if builtins.length parts > 1 then builtins.head parts else line)
        (builtins.filter (line: !lib.hasPrefix "//" (trimStart line)) lines);
      # Remove trailing commas before ] or } in a single reverse pass.
      # Walk the reversed list with foldl', tracking whether the next
      # non-blank line (in original order) starts with a closing bracket.
      removeTrailingCommas =
        let
          step = acc: line:
            let
              trimmed = trimStart line;
              isBlank = trimmed == "";
              clean = lib.removeSuffix "," (trimEnd line);
              outLine =
                if isBlank then line
                else if acc.closingNext && lib.hasSuffix "," (trimEnd line) then clean
                else line;
            in
            {
              closingNext =
                if isBlank then acc.closingNext
                else lib.hasPrefix "]" trimmed || lib.hasPrefix "}" trimmed;
              lines = [ outLine ] ++ acc.lines;
            };
        in
        (builtins.foldl' step { closingNext = false; lines = [ ]; } (lib.reverseList stripped)).lines;
    in
    lib.concatStringsSep "\n" removeTrailingCommas;

  # Read a JSONC file and parse it.
  # Returns { success = bool; value = attrs; }.
  # If the file doesn't exist, returns { success = false; value = {}; }.
  readJsonc =
    path:
    if !builtins.pathExists path then
      {
        success = false;
        value = { };
      }
    else
      let
        stripped = stripJsoncComments (builtins.readFile path);
      in
      builtins.tryEval (builtins.fromJSON stripped);
}
