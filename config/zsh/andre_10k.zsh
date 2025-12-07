# jj prompt instructions:
# -----------------------
# 1. add a p10k segment named `jj` to your prompt.
# 2. turn off git status in jj repos at the top of my_git_formatter:
#      emulate -L zsh -o extended_glob
#      if [[ -n ./(../)#(.jj)(#qN/) ]]; then
#        typeset -g my_git_format=""
#        return
#      fi
# 3. comment out any sections that you don't want in your own prompt,
#    using the table of contents below as a guide.

# jj prompt table of contents:
# ----------------------------
# jj_add     | add changes to jj for this prompt   | (no output)
# jj_at      | bookmark name and distance from @   | main›1
# jj_remote  | count changes ahead/behind remote   | 2⇡1⇣
# jj_change  | the current jj change ID            | kkor
# jj_desc    | current change description          | first line of description (or  )
# jj_status  | counts of added, removed, modified  | +1 -4 ^2
# jj_op      | the current jj operation ID         | b44825e56a5a

function jj_status() {
emulate -L zsh
cd "$1"

local grey='%244F'
local green='%2F'
local blue='%39F'
local red='%196F'
local yellow='%3F'
local cyan='%6F'
local magenta='%5F'

## jj_add
jj --at-operation=@ debug snapshot


## jj_at
local branch=$(jj --ignore-working-copy --at-op=@ --no-pager log --no-graph --limit 1 -r "
    coalesce(
    heads(::@ & (bookmarks() | remote_bookmarks() | tags())),
    heads(@:: & (bookmarks() | remote_bookmarks() | tags())),
    trunk()
    )" -T "separate(' ', bookmarks, tags)" 2> /dev/null | cut -d ' ' -f 1)
if [[ -n $branch ]]; then
    [[ $branch =~ "\*$" ]] && branch=${branch::-1}

    local VCS_STATUS_COMMITS_AFTER=$(jj --ignore-working-copy --at-op=@ --no-pager log --no-graph -r "$branch..@ & (~empty() | merges())" -T '"n"' 2> /dev/null | wc -c | tr -d ' ')
    local VCS_STATUS_COMMITS_BEFORE=$(jj --ignore-working-copy --at-op=@ --no-pager log --no-graph -r "@..$branch & (~empty() | merges())" -T '"n"' 2> /dev/null | wc -c | tr -d ' ')
    local counts=($(jj --ignore-working-copy --at-op=@ --no-pager bookmark list -r $branch -T '
    if(remote,
        separate(" ",
        name ++ "@" ++ remote,
        coalesce(tracking_ahead_count.exact(), tracking_ahead_count.lower()),
        coalesce(tracking_behind_count.exact(), tracking_behind_count.lower()),
        if(tracking_ahead_count.exact(), "0", "+"),
        if(tracking_behind_count.exact(), "0", "+"),
        ) ++ "\n"
    )
    '))

    local VCS_STATUS_LOCAL_BRANCH=$branch
    local VCS_STATUS_COMMITS_AHEAD=$counts[2]
    local VCS_STATUS_COMMITS_BEHIND=$counts[3]
    local VCS_STATUS_COMMITS_AHEAD_PLUS=$counts[4]
    local VCS_STATUS_COMMITS_BEHIND_PLUS=$counts[5]
fi

local status_color=${green}
(( VCS_STATUS_COMMITS_AHEAD )) && status_color=${cyan}
(( VCS_STATUS_COMMITS_BEHIND )) && status_color=${magenta}
(( VCS_STATUS_COMMITS_AHEAD && VCS_STATUS_COMMITS_BEHIND )) && status_color=${red}

local res
local where=${(V)VCS_STATUS_LOCAL_BRANCH}
# If local branch name or tag is at most 32 characters long, show it in full.
# Otherwise show the first 12 … the last 12.
(( $#where > 32 )) && where[13,-13]="…"
res+="${status_color}${where//\%/%%}"  # escape %

# ‹42 if before the local bookmark
(( VCS_STATUS_COMMITS_BEFORE )) && res+="‹${VCS_STATUS_COMMITS_BEFORE}"
# ›42 if beyond the local bookmark
(( VCS_STATUS_COMMITS_AFTER )) && res+="›${VCS_STATUS_COMMITS_AFTER}"


## jj_remote
# # ⇣42 if behind the remote.
# (( VCS_STATUS_COMMITS_BEHIND )) && res+=" ${green}⇣${VCS_STATUS_COMMITS_BEHIND}"
# (( VCS_STATUS_COMMITS_BEHIND_PLUS )) && res+="${VCS_STATUS_COMMITS_BEHIND_PLUS}"
# # ⇡42 if ahead of the remote; no leading space if also behind the remote: ⇣42⇡42.
# (( VCS_STATUS_COMMITS_AHEAD && !VCS_STATUS_COMMITS_BEHIND )) && res+=" "
# (( VCS_STATUS_COMMITS_AHEAD  )) && res+="${green}⇡${VCS_STATUS_COMMITS_AHEAD}"
# (( VCS_STATUS_COMMITS_AHEAD_PLUS )) && res+="${VCS_STATUS_COMMITS_AHEAD_PLUS}"


## jj_change
IFS="#" local change=($(jj --ignore-working-copy --at-op=@ --no-pager log --no-graph --limit 1 -r "@" -T '
    separate("#", change_id.shortest(4).prefix(), coalesce(change_id.shortest(4).rest(), "\0"),
    commit_id.shortest(4).prefix(),
    coalesce(commit_id.shortest(4).rest(), "\0"),
    concat(
        if(conflict, "💥"),
        if(divergent, "🚧"),
        if(hidden, "👻"),
        if(immutable, "🔒"),
    ),
    )'))
local VCS_STATUS_CHANGE=($change[1] $change[2])
local VCS_STATUS_COMMIT=($change[3] $change[4])
local VCS_STATUS_ACTION=$change[5]
# 'zyxw' with the standard jj color coding for shortest name
res+=" ${magenta}${VCS_STATUS_CHANGE[1]}${grey}${VCS_STATUS_CHANGE[2]}"
# '💥🚧👻🔒' if the repo is in an unusual state.
[[ -n $VCS_STATUS_ACTION     ]] && res+=" ${red}${VCS_STATUS_ACTION}"
# # '123abc' with the standard jj color coding for shortest name
# res+=" ${blue}${VCS_STATUS_COMMIT[1]}${grey}${VCS_STATUS_COMMIT[2]}"


## jj_desc
local VCS_STATUS_MESSAGE=$(jj --ignore-working-copy --at-op=@ --no-pager log --no-graph --limit 1 -r "@" -T "coalesce(description.first_line(), if(!empty, '\Uf040 '))")
[[ -n $VCS_STATUS_MESSAGE ]] && res+=" ${green}${VCS_STATUS_MESSAGE}"


## jj_status
local VCS_STATUS_CHANGES=($(jj log --ignore-working-copy --at-op=@ --no-graph --no-pager -r @ -T "diff.summary()" 2> /dev/null | awk 'BEGIN {a=0;d=0;m=0} /^A / {a++} /^D / {d++} /^M / {m++} /^R / {m++} /^C / {a++} END {print(a,d,m)}'))
(( VCS_STATUS_CHANGES[1] )) && res+=" %F{green}+${VCS_STATUS_CHANGES[1]}"
(( VCS_STATUS_CHANGES[2] )) && res+=" %F{red}-${VCS_STATUS_CHANGES[2]}"
(( VCS_STATUS_CHANGES[3] )) && res+=" ${yellow}^${VCS_STATUS_CHANGES[3]}"


## jj_op
# local VCS_STATUS_MESSAGE=$(jj --ignore-working-copy --at-op=@ --no-pager op log --limit 1 --no-graph -T "id.short()")
# [[ -n $VCS_STATUS_MESSAGE ]] && res+=" ${blue}${VCS_STATUS_MESSAGE}"


# return results
echo $res
}
function jj_status_callback() {
emulate -L zsh
if [[ $2 -ne 0 ]]; then
    typeset -g p10k_jj_status=
else
    typeset -g p10k_jj_status="$3"
fi
typeset -g p10k_jj_status_stale= p10k_jj_status_updated=1
p10k display -r
}
async_start_worker        jj_status_worker -u
async_unregister_callback jj_status_worker
async_register_callback   jj_status_worker jj_status_callback
function prompt_jj() {
emulate -L zsh -o extended_glob
(( $+commands[jj]         )) || return
[[ -n ./(../)#(.jj)(#qN/) ]] || return
typeset -g p10k_jj_status_stale=1 p10k_jj_status_updated=
p10k segment -f grey -c '$p10k_jj_status_stale' -e -t '$p10k_jj_status'
p10k segment -c '$p10k_jj_status_updated' -e -t '$p10k_jj_status'
async_job jj_status_worker jj_status $PWD
}
