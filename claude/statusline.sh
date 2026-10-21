#!/usr/bin/env bash
# Claude Code status line.
#
# Claude Code runs this script (settings.json -> statusLine.command) every time the status
# bar refreshes. It sends one JSON object on stdin and draws whatever we print on stdout
# (one printed line = one status row). Source of truth: dotfiles repo, claude/statusline.sh;
# ~/.claude/statusline.sh is a symlink to it (see install.sh / install.ps1). It also runs on
# Windows (Git Bash), so stay portable: plain bash, node for JSON, no jq/python.
#
# Layout, built in four steps:
#   1. Parse the JSON once and read the terminal width (COLUMNS).
#   2. Build "segments": small independent pieces of text (path, model, context bar, ...).
#   3. Pack the segments, in order, into as few lines as fit the width.
#   4. Print the lines, cutting any that are still too wide.
# Why: when everything sat on fixed lines, long herdr worktree paths made Claude Code cut
# the line with "…" and hide the model and the context bar. Fitting the width ourselves
# keeps every segment visible. The footer below the status line (permission mode, MR badge,
# agents) is drawn by Claude Code itself and cannot be changed from here.
#
# Test by piping sample JSON in, e.g.:
#   echo '{"cwd":"/tmp","model":{"display_name":"X"}}' | COLUMNS=60 bash statusline.sh
# Colours are kept as literal "\033[..m" text in variables and expanded with printf '%b'
# only when measuring or printing, so ${#var} never counts them by accident.

input=$(cat)

# Parse JSON with node — Claude Code is a Node.js app so node is guaranteed
# to be on PATH in the subprocess Claude Code spawns for the status line.
# jq is commonly missing from Git Bash's PATH on Windows in non-interactive
# subprocess contexts; python3 is also unreliable on Windows.
# One node call reads every field: one value per line, empty when missing.
# _fields (JSON dot-paths) and the variable names in the loop below must stay in the same
# order: value N of the node output goes into name N.
_fields=(
  workspace.current_dir cwd model.display_name effort.level
  context_window.used_percentage context_window.total_input_tokens
  context_window.total_output_tokens context_window.context_window_size
  rate_limits.five_hour.used_percentage rate_limits.five_hour.resets_at
  rate_limits.seven_day.used_percentage rate_limits.seven_day.resets_at
  prompt_cache.warm prompt_cache.hit_ratio prompt_cache.expires_at
)
_vals=()
# CR is stripped because node on Windows may print CRLF. A missing field gives an empty line,
# so positions never shift. Invalid JSON gives no output, so every value stays empty.
while IFS= read -r _line; do
  _vals+=("${_line%$'\r'}")
done < <(node -e "
try {
  const d = JSON.parse(process.argv[1]);
  for (const path of process.argv.slice(2)) {
    let v = d;
    for (const k of path.split('.')) v = v != null ? v[k] : undefined;
    process.stdout.write((v != null ? String(v).replace(/[\\r\\n]/g, ' ') : '') + '\\n');
  }
} catch (e) {}
" "$input" "${_fields[@]}" 2>/dev/null)
# Variables are assigned by name (printf -v); the names are what the rest of the script uses.
_i=0
for _name in cwd_ws cwd_alt model effort ctx_pct in_tokens out_tokens ctx_size \
             five_pct five_resets_at week_pct week_resets_at \
             cache_warm cache_hit_ratio cache_expires_at; do
  printf -v "$_name" '%s' "${_vals[_i]:-}"
  _i=$((_i + 1))
done

# Terminal width: Claude Code sets COLUMNS for the status line (tput does not work here).
# Fall back to 100 when it is missing or not a sensible number.
# Keep a 2-column margin: emoji count as one character below but draw two columns wide, and
# the margin also absorbs small differences in how Claude Code measures the width.
cols=${COLUMNS:-}
[[ "$cols" =~ ^[0-9]+$ ]] && [ "$cols" -gt 20 ] || cols=100
max_w=$((cols - 2))

# ${#var} and ${var:i:1} count bytes in the C locale, which would break the width maths for
# "·", "…", the bar blocks and emoji. Switch to the first UTF-8 locale this machine has
# (macOS: en_US.UTF-8; Git Bash and Linux: C.UTF-8 or en_US.UTF-8). If none is found we
# keep the current locale and the widths may be off for non-ASCII text.
for _loc in en_US.UTF-8 C.UTF-8 UTF-8; do
  if locale -a 2>/dev/null | grep -qix "${_loc//-/}\|$_loc"; then export LC_ALL="$_loc"; break; fi
done

# _fit STRING MAX: print STRING cut to MAX visible characters, with colour codes expanded.
# STRING holds literal "\033[..m" codes. They are copied through without being counted, so a
# cut never splits a code. A cut string ends with "…" (replacing the last kept character)
# and a colour reset, so a colour that was open cannot leak into the next line.
# Only used as a last resort: the packing step already keeps normal lines within the width.
_fit() {
  local s i ch out="" n=0 max=$2 cut=0
  s=$(printf '%b' "$1")
  for ((i = 0; i < ${#s}; i++)); do
    ch=${s:i:1}
    if [ "$ch" = $'\033' ]; then
      out+="$ch"
      while [ $((++i)) -lt ${#s} ]; do
        ch=${s:i:1}; out+="$ch"
        [ "$ch" = m ] && break
      done
      continue
    fi
    if [ "$n" -ge "$max" ]; then cut=1; break; fi
    out+="$ch"; n=$((n + 1))
  done
  if [ "$cut" = 1 ]; then
    # drop the last visible character to make room for the ellipsis
    out="${out%?}…"
    out+=$'\033[0m'
  fi
  printf '%s' "$out"
}

# _short_path PATH MAX: shorten PATH (already with ~ for home) to fit MAX characters.
#   1. herdr worktrees (~/.herdr/worktrees/<repo>/<name>[/sub]) become wt:<repo>/<name>[/sub],
#      because the long prefix says nothing the repo and worktree name do not.
#   2. If it is still longer than MAX, keep only the last two directories: …/prev/last.
# The result can still be too long on a very narrow terminal; _fit cuts it at print time.
_short_path() {
  local p=$1 max=$2 base
  if [[ "$p" =~ /\.herdr/worktrees/([^/]+)/(.*)$ ]]; then
    p="wt:${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  fi
  if [ "${#p}" -gt "$max" ]; then
    base=${p%/}
    local last=${base##*/}; base=${base%/*}
    local prev=${base##*/}
    p="…/${prev}/${last}"
  fi
  printf '%s' "$p"
}

# Current directory: workspace.current_dir, else cwd. Home is collapsed to ~, mirroring the
# Nushell default prompt. Windows backslashes are normalised to forward slashes.
# $cwd_fwd (forward-slash path) is also used below for the branch check.
cwd=${cwd_ws:-$cwd_alt}
if [ -n "$cwd" ]; then
  cwd_fwd="${cwd//\\//}"
  home_fwd="${HOME//\\//}"
  if [[ "$cwd_fwd" == "$home_fwd"* ]]; then
    dir="~${cwd_fwd#"$home_fwd"}"
  else
    dir="$cwd_fwd"
  fi
fi

# Git branch. --no-optional-locks stops git from taking the index lock, so the status line
# never blocks or interferes with a git command running in the session. Empty outside a repo
# or on a detached HEAD.
branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
# Hide the branch when it only repeats the directory name. herdr names a worktree directory
# "worktree-x" and its branch "worktree/x"; comparing with "/" turned into "-" catches that.
dir_base=${cwd_fwd%/}; dir_base=${dir_base##*/}
[ -n "$branch" ] && [ "${branch//\//-}" = "$dir_base" ] && branch=""

# _fmt_tokens N: human-readable token count, e.g. 850 -> 850, 45200 -> 45.2K, 200000 -> 200K.
# Prints nothing for an empty N.
_fmt_tokens() {
  local n=$1
  if [ -z "$n" ]; then echo ""; return; fi
  if [ "$n" -ge 1000 ]; then
    awk -v n="$n" 'BEGIN { v = n/1000; printf (v == int(v)) ? "%dK" : "%.1fK", v }'
  else
    echo "$n"
  fi
}

# _fmt_daytime EPOCH: local time and date of a Unix timestamp, e.g. "17:00 06/09" (HH:MM DD/MM).
# GNU date (Linux, Windows Git Bash) uses -d; BSD date (macOS) uses -r.
_fmt_daytime() {
  date -d "@$1" "+%H:%M %d/%m" 2>/dev/null || date -r "$1" "+%H:%M %d/%m" 2>/dev/null
}

# Colour codes, kept as literal text (see the header). ACCENT (bold cyan) marks the numbers
# that matter most at a glance: token counts, 5h%, 7d%, pane and tab ids.
RESET='\033[0m'
ACCENT='\033[1;36m'

# Segments, in display order. A segment is added only when its data exists, so a missing
# field just makes the line shorter. Order matters: the packing step never reorders, so the
# most important segments come first. Keep each one self-contained and short; the packing
# step breaks lines only between segments, never inside one.
segments=()

# Path (+ branch). The path gets the width left after the branch, so the branch stays whole.
if [ -n "$dir" ]; then
  branch_part=""
  [ -n "$branch" ] && branch_part=" ($branch)"
  segments+=("$(_short_path "$dir" $((max_w - ${#branch_part})))${branch_part}")
fi

# [Model · effort]
if [ -n "$model" ]; then
  if [ -n "$effort" ]; then
    segments+=("[$model · $effort]")
  else
    segments+=("[$model]")
  fi
fi

# Context bar, percentage, tokens used / window size. The colour warns as the context fills:
# green below 100k tokens, yellow from 100k, red from 150k.
if [ -n "$ctx_pct" ]; then
  pct_int=$(printf '%.0f' "$ctx_pct")

  total_tokens=$(( ${in_tokens:-0} + ${out_tokens:-0} ))

  if [ "$total_tokens" -ge 150000 ]; then COLOR='\033[31m'   # red: >=150k tokens
  elif [ "$total_tokens" -ge 100000 ]; then COLOR='\033[33m' # yellow: >=100k tokens
  else COLOR='\033[32m'; fi                                  # green

  # 10-cell bar: filled cells ▓, empty cells ░ (capped so a pct over 100 cannot overflow)
  BAR_WIDTH=10
  FILLED=$((pct_int * BAR_WIDTH / 100))
  [ "$FILLED" -gt "$BAR_WIDTH" ] && FILLED=$BAR_WIDTH
  EMPTY=$((BAR_WIDTH - FILLED))
  BAR=""
  [ "$FILLED" -gt 0 ] && printf -v FILL "%${FILLED}s" && BAR="${FILL// /▓}"
  [ "$EMPTY" -gt 0 ] && printf -v PAD "%${EMPTY}s" && BAR="${BAR}${PAD// /░}"

  used_fmt=$(_fmt_tokens "$total_tokens")
  # shellcheck disable=SC2154  # ctx_size is assigned dynamically via printf -v
  size_fmt=$(_fmt_tokens "$ctx_size")

  ctx_str="${COLOR}${BAR}${RESET} ${pct_int}%"
  [ -n "$used_fmt" ] && [ -n "$size_fmt" ] && ctx_str="${ctx_str}  ${ACCENT}${used_fmt}${RESET}/${size_fmt}"
  segments+=("$ctx_str")
fi

# Rate limits: used % of the 5-hour and 7-day windows, plus when each one resets.
# Two separate segments so a narrow terminal can put them on different lines.
if [ -n "$five_pct" ]; then
  five_str="5h:${ACCENT}$(printf '%.0f' "$five_pct")%${RESET}"
  if [ -n "$five_resets_at" ]; then
    five_clock=$(_fmt_daytime "$five_resets_at")
    [ -n "$five_clock" ] && five_str="${five_str} (${five_clock})"
  fi
  segments+=("$five_str")
fi
if [ -n "$week_pct" ]; then
  week_str="7d:${ACCENT}$(printf '%.0f' "$week_pct")%${RESET}"
  if [ -n "$week_resets_at" ]; then
    week_clock=$(_fmt_daytime "$week_resets_at")
    [ -n "$week_clock" ] && week_str="${week_str} (${week_clock})"
  fi
  segments+=("$week_str")
fi

# Prompt cache: 🔥 warm / ❄️ cold, hit ratio in %, and (only while warm and not yet expired)
# the time the cache expires.
cache_str=""
if [ -n "$cache_warm" ]; then
  if [ "$cache_warm" = "true" ]; then cache_icon="🔥"; else cache_icon="❄️"; fi
  if [ -n "$cache_hit_ratio" ]; then
    cache_pct=$(awk -v r="$cache_hit_ratio" 'BEGIN { printf "%.0f", r * 100 }')
    cache_str="${cache_icon} ${cache_pct}%"
  else
    cache_str="${cache_icon}"
  fi

  if [ "$cache_warm" = "true" ] && [ -n "$cache_expires_at" ]; then
    now_epoch=$(date +%s)
    if [ "$cache_expires_at" -gt "$now_epoch" ]; then
      expires_clock=$(_fmt_daytime "$cache_expires_at")
      [ -n "$expires_clock" ] && cache_str="${cache_str} (${expires_clock})"
    fi
  fi
fi

[ -n "$cache_str" ] && segments+=("$cache_str")

# herdr: pane and tab ids (env inherited from the herdr pane; absent outside herdr).
# Useful for `herdr agent prompt <pane_id>` and for telling sessions apart.
herdr_str=""
[ -n "$HERDR_PANE_ID" ] && herdr_str="pane:${ACCENT}${HERDR_PANE_ID}${RESET}"
[ -n "$HERDR_TAB_ID" ] && herdr_str="${herdr_str:+$herdr_str }tab:${ACCENT}${HERDR_TAB_ID}${RESET}"
[ -n "$herdr_str" ] && segments+=("$herdr_str")

# Pack the segments into as few lines as possible, keeping their order (greedy fill):
# add each segment to the current line while it fits (joined with $sep), otherwise start
# a new line with it. Because the order is fixed, this gives the fewest possible lines.
# Width = visible characters only: colour codes are removed before measuring.
# extglob is needed for the +(...) pattern that strips the codes.
shopt -s extglob
sep="  ·  "
sep_w=${#sep}
lines=()
cur=""
cur_w=0
for seg in "${segments[@]}"; do
  # expand the literal codes into real escape characters, then delete them to get the text
  expanded=$(printf '%b' "$seg")
  plain=${expanded//$'\033'\[+([0-9;])m/}
  seg_w=${#plain}
  if [ -z "$cur" ]; then
    cur=$seg; cur_w=$seg_w
  elif [ $((cur_w + sep_w + seg_w)) -le "$max_w" ]; then
    cur="${cur}${sep}${seg}"; cur_w=$((cur_w + sep_w + seg_w))
  else
    lines+=("$cur")
    cur=$seg; cur_w=$seg_w
  fi
done
[ -n "$cur" ] && lines+=("$cur")

# Print. _fit only changes a line when one segment alone is wider than the terminal
# (very narrow terminal); then we cut it ourselves so Claude Code does not cut it for us.
for _l in "${lines[@]}"; do
  _fit "$_l" "$max_w"; printf '\n'
done
