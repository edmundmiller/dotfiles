# Rex ships its CLI inside the macOS app bundle rather than installing it on PATH.
# Add both common install locations when present; keep the bundled `rex` executable
# available to shells and tools launched from them (including Pi extensions).
for rex_cli_dir in \
  /Applications/Rex\ Beta.app/Contents/Helpers/Rex\ Server.rex/Contents/MacOS \
  "$HOME/Applications/Rex Beta.app/Contents/Helpers/Rex Server.rex/Contents/MacOS"; do
  [[ -x "$rex_cli_dir/rex" ]] && path=("$rex_cli_dir" $path)
done
unset rex_cli_dir
