# Upstream `wrapProgram` renames native binaries to `.NAME-wrapped`, and the
# OS takes the process name from that file name, so terminal tabs (Rex) show
# ".NAME-wrapped". Move each real binary to libexec/NAME/NAME and repoint its
# wrapper. Wrapped scripts don't need this: their process is the interpreter.
#
# shortcut: each override misses the binary cache, so these packages, and
# anything that depends on them, now build locally. The added build time
# hasn't been measured yet; drop an entry if it costs too much.
_final: prev:
let
  showRealName =
    pkg:
    pkg.overrideAttrs (old: {
      postFixup = (old.postFixup or "") + ''
        for wrapped in "$out"/bin/.*-wrapped; do
          [ -e "$wrapped" ] || continue
          name=''${wrapped##*/.}
          name=''${name%-wrapped}
          real="$out/libexec/$name/$name"
          mkdir -p "''${real%/*}"
          mv "$wrapped" "$real"
          substituteInPlace "$out/bin/$name" --replace-fail "$wrapped" "$real"
        done
      '';
    });
in
{
  bat = showRealName prev.bat;
  gh = showRealName prev.gh;
  # Build tools depend on man-db, so overriding it rebuilds fonts, Python and
  # graphics libraries locally. Install this copy through programs.man instead.
  man-db-real-name = showRealName prev.man-db;
}
