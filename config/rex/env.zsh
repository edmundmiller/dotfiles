# Rex ships its CLI inside the macOS app bundle rather than installing it on PATH.
# Add both common install locations when present; keep the bundled `rex` executable
# available to shells and tools launched from them (including Pi extensions).
for rex_cli_dir in \
  /Applications/Rex\ Beta.app/Contents/Helpers/Rex\ Server.rex/Contents/MacOS \
  "$HOME/Applications/Rex Beta.app/Contents/Helpers/Rex Server.rex/Contents/MacOS"; do
  [[ -x "$rex_cli_dir/rex" ]] && path=("$rex_cli_dir" $path)
done
unset rex_cli_dir

# rex-studio defaults. scidev/testing's Git builds fail on its ECR credential.
export REX_STUDIO_WORKSPACE=seqeralabs/showcase
export REX_STUDIO_COMPUTE_ENV=studios-aws-cloud-m6i-large

# Rex tabs are narrow; show Rex's own tab name instead of Claude Code's long
# terminal title. Status comes from OSC 7501 hooks (see README).
[[ -n "$REX_SESSION" ]] && export CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1
