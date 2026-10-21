#!/usr/bin/env bash
input=$(cat)

# Parse JSON with node — Claude Code is a Node.js app so node is guaranteed
# to be on PATH in the subprocess Claude Code spawns for the status line.
# jq is commonly missing from Git Bash's PATH on Windows in non-interactive
# subprocess contexts; python3 is also unreliable on Windows.
_jval() {
  # $1 = dot-path like "workspace.current_dir"
  node -e "
try {
  const d = JSON.parse(process.argv[1]);
  const keys = process.argv[2].split('.');
  let v = d;
  for (const k of keys) { if (k) v = v != null ? v[k] : undefined; }
  process.stdout.write(v != null ? String(v) : '');
} catch(e) { process.stdout.write(''); }
" "$input" "$1" 2>/dev/null
}

# Current directory — full path with home dir collapsed to ~, mirroring the
# Nushell default left_prompt. Windows backslashes are normalised to forward slashes.
cwd=$(_jval workspace.current_dir)
if [ -z "$cwd" ]; then
  cwd=$(_jval cwd)
fi
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

# Model + reasoning effort
model=$(_jval model.display_name)
effort=$(_jval effort.level)

# Context window usage: precomputed percentage plus raw token counts
ctx_pct=$(_jval context_window.used_percentage)
in_tokens=$(_jval context_window.total_input_tokens)
out_tokens=$(_jval context_window.total_output_tokens)
ctx_size=$(_jval context_window.context_window_size)

# Rate limits
five_pct=$(_jval rate_limits.five_hour.used_percentage)
five_resets_at=$(_jval rate_limits.five_hour.resets_at)
week_pct=$(_jval rate_limits.seven_day.used_percentage)
week_resets_at=$(_jval rate_limits.seven_day.resets_at)

# Prompt cache
cache_warm=$(_jval prompt_cache.warm)
cache_hit_ratio=$(_jval prompt_cache.hit_ratio)
cache_expires_at=$(_jval prompt_cache.expires_at)

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

# --- Line 1: dir (branch) [Model · effort]  bar pct% tokens ---
line1_parts=()
[ -n "$dir" ]    && line1_parts+=("$dir")
[ -n "$branch" ] && line1_parts+=("($branch)")
if [ -n "$model" ]; then
  if [ -n "$effort" ]; then
    line1_parts+=("[$model · $effort]")
  else
    line1_parts+=("[$model]")
  fi
fi
line1="${line1_parts[*]}"

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
  size_fmt=$(_fmt_tokens "$ctx_size")

  tok_str=""
  [ -n "$used_fmt" ] && [ -n "$size_fmt" ] && tok_str="${ACCENT}${used_fmt}${RESET}/${size_fmt}"

  line1="${line1}  ${COLOR}${BAR}${RESET} ${pct_int}%"
  [ -n "$tok_str" ] && line1="${line1}  ${tok_str}"
fi

# --- Line 2: cache + rate limits ---
line2=""
rl_parts=()
if [ -n "$five_pct" ]; then
  five_str="5h:${ACCENT}$(printf '%.0f' "$five_pct")%${RESET}"
  if [ -n "$five_resets_at" ]; then
    five_clock=$(_fmt_daytime "$five_resets_at")
    [ -n "$five_clock" ] && five_str="${five_str} (${five_clock})"
  fi
  rl_parts+=("$five_str")
fi
if [ -n "$week_pct" ]; then
  week_str="7d:${ACCENT}$(printf '%.0f' "$week_pct")%${RESET}"
  if [ -n "$week_resets_at" ]; then
    week_clock=$(_fmt_daytime "$week_resets_at")
    [ -n "$week_clock" ] && week_str="${week_str} (${week_clock})"
  fi
  rl_parts+=("$week_str")
fi
rl_str="${rl_parts[*]}"

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

if [ -n "$rl_str" ] && [ -n "$cache_str" ]; then
  line2="${rl_str}  ·  ${cache_str}"
else
  line2="${rl_str}${cache_str}"
fi

# herdr: pane and tab ids (env inherited from the herdr pane; absent outside herdr)
herdr_str=""
[ -n "$HERDR_PANE_ID" ] && herdr_str="pane:${ACCENT}${HERDR_PANE_ID}${RESET}"
[ -n "$HERDR_TAB_ID" ] && herdr_str="${herdr_str:+$herdr_str }tab:${ACCENT}${HERDR_TAB_ID}${RESET}"
if [ -n "$herdr_str" ]; then
  line2="${line2:+$line2  ·  }${herdr_str}"
fi

echo -e "$line1"
if [ -n "$line2" ]; then
  echo -e "$line2"
fi
