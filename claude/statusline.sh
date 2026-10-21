#!/usr/bin/env bash
input=$(cat)

# Parse JSON with node — Claude Code is a Node.js app so node is guaranteed
# to be on PATH in the subprocess Claude Code spawns for the status line.
# jq is commonly missing from Git Bash's PATH on Windows in non-interactive
# subprocess contexts; python3 is also unreliable on Windows.
# One node call reads every field: one value per line, empty when missing.
_fields=(
  workspace.current_dir cwd model.display_name effort.level
  context_window.used_percentage context_window.total_input_tokens
  context_window.total_output_tokens context_window.context_window_size
  rate_limits.five_hour.used_percentage rate_limits.five_hour.resets_at
  rate_limits.seven_day.used_percentage rate_limits.seven_day.resets_at
  prompt_cache.warm prompt_cache.hit_ratio prompt_cache.expires_at
)
_vals=()
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
_i=0
for _name in cwd_ws cwd_alt model effort ctx_pct in_tokens out_tokens ctx_size \
             five_pct five_resets_at week_pct week_resets_at \
             cache_warm cache_hit_ratio cache_expires_at; do
  printf -v "$_name" '%s' "${_vals[_i]:-}"
  _i=$((_i + 1))
done

# Terminal width: Claude Code sets COLUMNS for the status line (tput does not work here).
# Keep a 2-column margin: emoji count as one character below but draw two columns wide.
cols=${COLUMNS:-}
[[ "$cols" =~ ^[0-9]+$ ]] && [ "$cols" -gt 20 ] || cols=100
max_w=$((cols - 2))

# Character counting needs a UTF-8 locale (agent shells often run in C).
for _loc in en_US.UTF-8 C.UTF-8 UTF-8; do
  if locale -a 2>/dev/null | grep -qix "${_loc//-/}\|$_loc"; then export LC_ALL="$_loc"; break; fi
done

# Cut a string that holds literal "\033[..m" colour codes to $2 visible characters,
# ending with an ellipsis. Prints the result with the escape codes expanded.
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

# Shorten a path to $2 characters: herdr worktrees become wt:<repo>/<name>, and a
# path that is still too long keeps only its last two directories.
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

# Current directory — full path with home dir collapsed to ~, mirroring the
# Nushell default left_prompt. Windows backslashes are normalised to forward slashes.
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

# Git branch (skip optional locks to avoid hanging)
branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
# Hide the branch when it repeats the directory name (herdr worktrees do: worktree/x vs worktree-x)
dir_base=${cwd_fwd%/}; dir_base=${dir_base##*/}
[ -n "$branch" ] && [ "${branch//\//-}" = "$dir_base" ] && branch=""

# Human-readable token counts, e.g. 45.2K, and total context size, e.g. 200K
_fmt_tokens() {
  local n=$1
  if [ -z "$n" ]; then echo ""; return; fi
  if [ "$n" -ge 1000 ]; then
    awk -v n="$n" 'BEGIN { v = n/1000; printf (v == int(v)) ? "%dK" : "%.1fK", v }'
  else
    echo "$n"
  fi
}

# Compact time/day stamp, e.g. "17:00 06/09"
# GNU date (Linux, Windows Git Bash) uses -d; BSD date (macOS) uses -r.
_fmt_daytime() {
  date -d "@$1" "+%H:%M %d/%m" 2>/dev/null || date -r "$1" "+%H:%M %d/%m" 2>/dev/null
}

# Accent color for the numbers that matter most at a glance: token counts,
# 5h%, and 7d%.
RESET='\033[0m'
ACCENT='\033[1;36m'

# Segments, in display order. Empty ones are skipped. Each holds literal "\033[..m" codes.
segments=()

# Path (+ branch)
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

# Context bar, percentage, tokens
if [ -n "$ctx_pct" ]; then
  pct_int=$(printf '%.0f' "$ctx_pct")

  total_tokens=$(( ${in_tokens:-0} + ${out_tokens:-0} ))

  if [ "$total_tokens" -ge 150000 ]; then COLOR='\033[31m'   # red: >=150k tokens
  elif [ "$total_tokens" -ge 100000 ]; then COLOR='\033[33m' # yellow: >=100k tokens
  else COLOR='\033[32m'; fi                                  # green

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

# Rate limits: 5h and 7d
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

# Cache: 🔥/❄️ warm indicator, hit-ratio percentage, and TTL remaining
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

# herdr: pane and tab ids (env inherited from the herdr pane; absent outside herdr)
herdr_str=""
[ -n "$HERDR_PANE_ID" ] && herdr_str="pane:${ACCENT}${HERDR_PANE_ID}${RESET}"
[ -n "$HERDR_TAB_ID" ] && herdr_str="${herdr_str:+$herdr_str }tab:${ACCENT}${HERDR_TAB_ID}${RESET}"
[ -n "$herdr_str" ] && segments+=("$herdr_str")

# Pack the segments into as few lines as possible, keeping their order: add each one
# to the current line while it fits, otherwise start a new line with it.
shopt -s extglob
sep="  ·  "
sep_w=${#sep}
lines=()
cur=""
cur_w=0
for seg in "${segments[@]}"; do
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

# A single segment wider than the terminal is still cut so Claude Code never truncates it
for _l in "${lines[@]}"; do
  _fit "$_l" "$max_w"; printf '\n'
done
