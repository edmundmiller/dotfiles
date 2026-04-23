{ lib, ... }:
rec {
  # Strip full-line // comments (after trimming leading whitespace).
  isCommentLine =
    line:
    lib.hasPrefix "//" (
      lib.trimWith {
        start = true;
        end = false;
      } line
    );

  # Strip inline // comments: split on " //" and keep only the first part.
  # Safe because JSON string values containing " //" would be unusual.
  stripInlineComment =
    line:
    let
      parts = lib.splitString " //" line;
    in
    if builtins.length parts > 1 then builtins.head parts else line;

  # Remove trailing commas before } or ] (invalid in strict JSON).
  removeTrailingCommas =
    lines:
    let
      indexed = lib.imap0 (i: line: { inherit i line; }) lines;
      nextNonEmpty =
        i:
        let
          rest = lib.drop (i + 1) lines;
          nonEmpty = builtins.filter (l: builtins.match "^[[:space:]]*$" l == null) rest;
        in
        if nonEmpty == [ ] then "" else builtins.head nonEmpty;
      stripTrailingComma =
        { i, line }:
        let
          next = nextNonEmpty i;
          trimmedNext = lib.trimWith {
            start = true;
            end = false;
          } next;
          nextStartsClosing = lib.hasPrefix "]" trimmedNext || lib.hasPrefix "}" trimmedNext;
          trimmedLine = lib.removeSuffix " " (lib.removeSuffix "\t" line);
          hasTrailingComma = lib.hasSuffix "," trimmedLine;
        in
        if hasTrailingComma && nextStartsClosing then lib.removeSuffix "," trimmedLine else line;
    in
    map stripTrailingComma indexed;

  # Convert a JSONC string (with // comments and trailing commas) to clean JSON.
  stripJsoncComments =
    raw:
    let
      lines = lib.splitString "\n" raw;
      filtered = map stripInlineComment (builtins.filter (line: !isCommentLine line) lines);
      cleaned = removeTrailingCommas filtered;
    in
    lib.concatStringsSep "\n" cleaned;

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
