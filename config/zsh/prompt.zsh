# Functional theme - Minimal P10K prompt
# Inspired by hlissner/dotfiles autumnal theme
#
# Features:
# - Left: dir + prompt_char (λ with vim mode awareness)
# - Right: jj/git status, nix-shell, direnv only
# - No clutter, no icons, just essential info

'builtin' 'local' '-a' 'p10k_config_opts'
[[ ! -o 'aliases'         ]] || p10k_config_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || p10k_config_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || p10k_config_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

() {
  emulate -L zsh -o extended_glob
  unset -m '(POWERLEVEL9K_*|DEFAULT_USER)~POWERLEVEL9K_GITSTATUS_DIR'

  # ==========================================================================
  # PROMPT ELEMENTS - Minimal setup
  # ==========================================================================

  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
    dir                       # current directory
    prompt_char               # prompt symbol
  )

  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
    vcs                       # git status
    jj                        # jj status (async)
    nix_shell                 # nix shell indicator
    direnv                    # direnv status
  )

  # ==========================================================================
  # BASIC STYLE - Clean, transparent, minimal
  # ==========================================================================

  typeset -g POWERLEVEL9K_MODE=ascii
  typeset -g POWERLEVEL9K_ICON_PADDING=none
  typeset -g POWERLEVEL9K_BACKGROUND=                            # transparent
  typeset -g POWERLEVEL9K_{LEFT,RIGHT}_{LEFT,RIGHT}_WHITESPACE=  # no whitespace
  typeset -g POWERLEVEL9K_{LEFT,RIGHT}_SUBSEGMENT_SEPARATOR=' '  # space between segments
  typeset -g POWERLEVEL9K_{LEFT,RIGHT}_SEGMENT_SEPARATOR=        # no separators
  typeset -g POWERLEVEL9K_ICON_BEFORE_CONTENT=true
  typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=true

  # No multiline decorations
  typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX=
  typeset -g POWERLEVEL9K_MULTILINE_NEWLINE_PROMPT_PREFIX=
  typeset -g POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX=
  typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_SUFFIX=
  typeset -g POWERLEVEL9K_MULTILINE_NEWLINE_PROMPT_SUFFIX=
  typeset -g POWERLEVEL9K_MULTILINE_LAST_PROMPT_SUFFIX=
  typeset -g POWERLEVEL9K_LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL=
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_LAST_SEGMENT_END_SYMBOL=

  # ==========================================================================
  # PROMPT CHARACTER - λ with vim mode support
  # ==========================================================================

  # Green on success, red on error
  typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=76
  typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=196

  # λ for insert mode, N for normal, V for visual, O for overwrite
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIINS_CONTENT_EXPANSION='λ'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VICMD_CONTENT_EXPANSION='N'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIVIS_CONTENT_EXPANSION='V'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIOWR_CONTENT_EXPANSION='O'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_OVERWRITE_STATE=true
  typeset -g POWERLEVEL9K_PROMPT_CHAR_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL=''
  typeset -g POWERLEVEL9K_PROMPT_CHAR_LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL=

  # ==========================================================================
  # DIRECTORY - Smart truncation
  # ==========================================================================

  typeset -g POWERLEVEL9K_DIR_FOREGROUND=4
  typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_unique
  typeset -g POWERLEVEL9K_SHORTEN_DELIMITER=
  typeset -g POWERLEVEL9K_DIR_SHORTENED_FOREGROUND=39
  typeset -g POWERLEVEL9K_DIR_ANCHOR_FOREGROUND=4
  typeset -g POWERLEVEL9K_DIR_ANCHOR_BOLD=true

  # Only anchor on VCS directories
  local anchor_files=(.bzr .git .hg .jj)
  typeset -g POWERLEVEL9K_SHORTEN_FOLDER_MARKER="(${(j:|:)anchor_files})"
  typeset -g POWERLEVEL9K_DIR_TRUNCATE_BEFORE_MARKER=false
  typeset -g POWERLEVEL9K_SHORTEN_DIR_LENGTH=1
  typeset -g POWERLEVEL9K_DIR_MAX_LENGTH=80
  typeset -g POWERLEVEL9K_DIR_MIN_COMMAND_COLUMNS=40
  typeset -g POWERLEVEL9K_DIR_MIN_COMMAND_COLUMNS_PCT=50
  typeset -g POWERLEVEL9K_DIR_HYPERLINK=false
  typeset -g POWERLEVEL9K_DIR_SHOW_WRITABLE=v3
  typeset -g POWERLEVEL9K_DIR_CLASSES=()

  # ==========================================================================
  # GIT STATUS - Minimal, informative
  # ==========================================================================

  typeset -g POWERLEVEL9K_VCS_BRANCH_ICON=
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_ICON='?'

  function my_git_formatter() {
    emulate -L zsh

    # Skip git display in jj repositories (jj segment handles it)
    [[ -n ./(../)#(.jj)(#qN/) ]] && { typeset -g my_git_format=; return; }

    if [[ -n $P9K_CONTENT ]]; then
      typeset -g my_git_format=$P9K_CONTENT
      return
    fi

    if (( $1 )); then
      local meta='%f' clean='%2F' modified='%3F' untracked='%4F' conflicted='%1F'
    else
      local meta='%244F' clean='%244F' modified='%244F' untracked='%244F' conflicted='%244F'
    fi

    local res

    if [[ -n $VCS_STATUS_LOCAL_BRANCH ]]; then
      local branch=${(V)VCS_STATUS_LOCAL_BRANCH}
      (( $#branch > 32 )) && branch[13,-13]="..."
      res+="${clean}${branch//\%/%%}"
    elif [[ -n $VCS_STATUS_TAG ]]; then
      local tag=${(V)VCS_STATUS_TAG}
      (( $#tag > 32 )) && tag[13,-13]="..."
      res+="${meta}#${clean}${tag//\%/%%}"
    else
      res+="${meta}@${clean}${VCS_STATUS_COMMIT[1,8]}"
    fi

    [[ -n ${VCS_STATUS_REMOTE_BRANCH:#$VCS_STATUS_LOCAL_BRANCH} ]] &&
      res+="${meta}:${clean}${(V)VCS_STATUS_REMOTE_BRANCH//\%/%%}"

    (( VCS_STATUS_COMMITS_BEHIND )) && res+=" ${clean}${VCS_STATUS_COMMITS_BEHIND}<"
    (( VCS_STATUS_COMMITS_AHEAD && !VCS_STATUS_COMMITS_BEHIND )) && res+=" "
    (( VCS_STATUS_COMMITS_AHEAD )) && res+="${clean}>${VCS_STATUS_COMMITS_AHEAD}"
    (( VCS_STATUS_STASHES )) && res+=" ${clean}*${VCS_STATUS_STASHES}"
    [[ -n $VCS_STATUS_ACTION ]] && res+=" ${conflicted}${VCS_STATUS_ACTION}"
    (( VCS_STATUS_NUM_CONFLICTED )) && res+=" ${conflicted}~${VCS_STATUS_NUM_CONFLICTED}"
    (( VCS_STATUS_NUM_STAGED )) && res+=" ${modified}+${VCS_STATUS_NUM_STAGED}"
    (( VCS_STATUS_NUM_UNSTAGED )) && res+=" ${modified}!${VCS_STATUS_NUM_UNSTAGED}"
    (( VCS_STATUS_NUM_UNTRACKED )) && res+=" ${untracked}?${VCS_STATUS_NUM_UNTRACKED}"
    (( VCS_STATUS_HAS_UNSTAGED == -1 )) && res+=" ${modified}-"

    typeset -g my_git_format=$res
  }
  functions -M my_git_formatter 2>/dev/null

  typeset -g POWERLEVEL9K_VCS_MAX_INDEX_SIZE_DIRTY=-1
  typeset -g POWERLEVEL9K_VCS_DISABLED_WORKDIR_PATTERN='~'
  typeset -g POWERLEVEL9K_VCS_DISABLE_GITSTATUS_FORMATTING=true
  typeset -g POWERLEVEL9K_VCS_CONTENT_EXPANSION='${$((my_git_formatter(1)))+${my_git_format}}'
  typeset -g POWERLEVEL9K_VCS_LOADING_CONTENT_EXPANSION='${$((my_git_formatter(0)))+${my_git_format}}'
  typeset -g POWERLEVEL9K_VCS_{STAGED,UNSTAGED,UNTRACKED,CONFLICTED,COMMITS_AHEAD,COMMITS_BEHIND}_MAX_NUM=-1
  typeset -g POWERLEVEL9K_VCS_VISUAL_IDENTIFIER_COLOR=76
  typeset -g POWERLEVEL9K_VCS_LOADING_VISUAL_IDENTIFIER_COLOR=244
  typeset -g POWERLEVEL9K_VCS_VISUAL_IDENTIFIER_EXPANSION=
  typeset -g POWERLEVEL9K_VCS_BACKENDS=(git)
  typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND=76
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND=76
  typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND=178

  # ==========================================================================
  # JJ STATUS - Async implementation
  # ==========================================================================

  function jj_status() {
    emulate -L zsh
    cd "$1"

    local grey='%244F' green='%2F' blue='%39F' red='%196F'
    local yellow='%3F' cyan='%6F' magenta='%5F'

    # Snapshot changes
    jj --at-operation=@ debug snapshot 2>/dev/null

    # Get branch info
    local branch=$(jj --ignore-working-copy --at-op=@ --no-pager log --no-graph --limit 1 -r "
      coalesce(
        heads(::@ & (bookmarks() | remote_bookmarks() | tags())),
        heads(@:: & (bookmarks() | remote_bookmarks() | tags())),
        trunk()
      )" -T "separate(' ', bookmarks, tags)" 2>/dev/null | cut -d ' ' -f 1)

    local res
    if [[ -n $branch ]]; then
      [[ $branch =~ "\*$" ]] && branch=${branch::-1}

      local commits_after=$(jj --ignore-working-copy --at-op=@ --no-pager log --no-graph \
        -r "$branch..@ & (~empty() | merges())" -T '"n"' 2>/dev/null | wc -c | tr -d ' ')
      local commits_before=$(jj --ignore-working-copy --at-op=@ --no-pager log --no-graph \
        -r "@..$branch & (~empty() | merges())" -T '"n"' 2>/dev/null | wc -c | tr -d ' ')

      local where=${(V)branch}
      (( $#where > 32 )) && where[13,-13]="..."
      res+="${green}${where//\%/%%}"
      (( commits_before )) && res+="<${commits_before}"
      (( commits_after )) && res+=">${commits_after}"
    fi

    # Change ID
    IFS="#" local change=($(jj --ignore-working-copy --at-op=@ --no-pager log --no-graph --limit 1 -r "@" -T '
      separate("#",
        change_id.shortest(4).prefix(),
        coalesce(change_id.shortest(4).rest(), "\0"),
        concat(if(conflict, "!"), if(divergent, "~"), if(hidden, "?"), if(immutable, "*")),
      )' 2>/dev/null))

    res+=" ${magenta}${change[1]}${grey}${change[2]}"
    [[ -n $change[3] ]] && res+=" ${red}${change[3]}"

    # File changes
    local changes=($(jj log --ignore-working-copy --at-op=@ --no-graph --no-pager -r @ \
      -T "diff.summary()" 2>/dev/null | awk 'BEGIN {a=0;d=0;m=0} /^A / {a++} /^D / {d++} /^M / {m++} END {print(a,d,m)}'))
    (( changes[1] )) && res+=" ${green}+${changes[1]}"
    (( changes[2] )) && res+=" ${red}-${changes[2]}"
    (( changes[3] )) && res+=" ${yellow}^${changes[3]}"

    echo $res
  }

  function jj_status_callback() {
    emulate -L zsh
    if [[ $2 -ne 0 ]]; then
      typeset -g p10k_jj_status=
    else
      typeset -g p10k_jj_status="$3"
    fi
    typeset -g p10k_jj_status_stale= p10k_jj_status_updated=1 p10k_jj_placeholder=
    p10k display -r
  }

  async_start_worker        jj_status_worker -u
  async_unregister_callback jj_status_worker
  async_register_callback   jj_status_worker jj_status_callback

  function prompt_jj() {
    emulate -L zsh -o extended_glob
    (( $+commands[jj] )) || return
    [[ -n ./(../)#(.jj)(#qN/) ]] || return

    typeset -g p10k_jj_status_stale=1 p10k_jj_status_updated=

    if [[ -z $p10k_jj_status ]]; then
      typeset -g p10k_jj_placeholder=1
      typeset -g p10k_jj_quick=$(jj --ignore-working-copy --no-pager log --no-graph --limit 1 -r "@" \
        -T 'separate(" ", coalesce(bookmarks, ""), change_id.shortest(4))' 2>/dev/null)
      [[ -z $p10k_jj_quick ]] && typeset -g p10k_jj_quick="jj"
      p10k_jj_quick+=" ..."
    fi

    p10k segment -f grey -c '$p10k_jj_placeholder' -e -t '$p10k_jj_quick'
    p10k segment -f grey -c '$p10k_jj_status_stale' -e -t '$p10k_jj_status'
    p10k segment -c '$p10k_jj_status_updated' -e -t '$p10k_jj_status'

    async_job jj_status_worker jj_status $PWD
  }

  # ==========================================================================
  # NIX SHELL & DIRENV - Simple indicators
  # ==========================================================================

  typeset -g POWERLEVEL9K_NIX_SHELL_FOREGROUND=74
  typeset -g POWERLEVEL9K_DIRENV_FOREGROUND=178

  # ==========================================================================
  # BEHAVIOR - No instant prompt, no transient
  # ==========================================================================

  typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=off
  typeset -g POWERLEVEL9K_INSTANT_PROMPT=off
  typeset -g POWERLEVEL9K_DISABLE_HOT_RELOAD=true

  (( ! $+functions[p10k] )) || p10k reload
}

(( ${#p10k_config_opts} )) && setopt ${p10k_config_opts[@]}
'builtin' 'unset' 'p10k_config_opts'
