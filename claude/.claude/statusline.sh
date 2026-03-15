#!/bin/bash
# =============================================================================
# Ankh-Morpork City Watch Statusline
# "A man who is afraid of the dark doesn't know what the dark contains."
#   -- Sam Vimes, probably about context windows
# =============================================================================

input=$(cat)

# -----------------------------------------------------------------------------
# Extract fields from Claude Code's JSON payload
# -----------------------------------------------------------------------------
MODEL=$(echo "$input"    | jq -r '.model.display_name // "Unknown"')
DIR=$(echo "$input"      | jq -r '.workspace.current_dir // ""')
PCT=$(echo "$input"      | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
TOK_IN=$(echo "$input"   | jq -r '.context_window.current_usage.input_tokens // 0')
TOK_CACHE=$(echo "$input"| jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
TOK_WRITE=$(echo "$input"| jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
TOK_OUT=$(echo "$input"  | jq -r '.context_window.current_usage.output_tokens // 0')
CTX_MAX=$(echo "$input"  | jq -r '.context_window.max_tokens // 0')

# -----------------------------------------------------------------------------
# Git status (cached to avoid lag)
# -----------------------------------------------------------------------------
CACHE_FILE="/tmp/watch-statusline-git-cache"
CACHE_MAX_AGE=5

cache_is_stale() {
  [ ! -f "$CACHE_FILE" ] || \
    [ $(( $(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0) )) -gt $CACHE_MAX_AGE ]
}

if cache_is_stale; then
  if git -C "$DIR" rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null)
    STAGED=$(git -C "$DIR" diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
    MODIFIED=$(git -C "$DIR" diff --numstat 2>/dev/null | wc -l | tr -d ' ')
    UNTRACKED=$(git -C "$DIR" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
    echo "${BRANCH}|${STAGED}|${MODIFIED}|${UNTRACKED}" > "$CACHE_FILE"
  else
    echo "|||" > "$CACHE_FILE"
  fi
fi

IFS='|' read -r BRANCH STAGED MODIFIED UNTRACKED < "$CACHE_FILE"

# -----------------------------------------------------------------------------
# Colors (ANSI)
# -----------------------------------------------------------------------------
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Ankh-Morpork palette
GOLD='\033[38;5;220m'      # City gold
COPPER='\033[38;5;172m'    # Watch copper
COBBLE='\033[38;5;240m'    # Ankh cobblestone grey
RIVER='\033[38;5;31m'      # The Ankh (murky blue)
FLAME='\033[38;5;202m'     # Warning orange
DANGER='\033[38;5;196m'    # Red alert
GREEN='\033[38;5;70m'      # Safe green
LILAC='\033[38;5;183m'     # Lilac (Nanny Ogg approved)

# -----------------------------------------------------------------------------
# Context bar — Discworld flavour
#   0–49%   : The night is young. Rincewind is almost relaxed.
#  50–74%   : The Luggage is getting restless.
#  75–89%   : Rincewind is eyeing the exits. Suggest /obsidian-summary.
#  90–99%   : The Patrician has noticed. Flee immediately.
#   100%    : DEATH arrives. Context compaction imminent.
# -----------------------------------------------------------------------------
BAR_WIDTH=12
FILLED=$(( PCT * BAR_WIDTH / 100 ))
EMPTY=$(( BAR_WIDTH - FILLED ))

[ "$FILLED" -gt 0 ] && BAR=$(printf "%${FILLED}s" | tr ' ' '▓') || BAR=""
[ "$EMPTY"  -gt 0 ] && BAR="${BAR}$(printf "%${EMPTY}s" | tr ' ' '░')"

if   [ "$PCT" -ge 100 ]; then BAR_COLOR="$DANGER";  CTX_LABEL="DEATH APPROACHES"
elif [ "$PCT" -ge 90  ]; then BAR_COLOR="$DANGER";  CTX_LABEL="flee to /obsidian-summary"
elif [ "$PCT" -ge 75  ]; then BAR_COLOR="$FLAME";   CTX_LABEL="Rincewind eyes the exit"
elif [ "$PCT" -ge 50  ]; then BAR_COLOR="$GOLD";    CTX_LABEL="The Luggage stirs"
else                          BAR_COLOR="$GREEN";   CTX_LABEL="all quiet on the Disc"
fi

# -----------------------------------------------------------------------------
# Model display — name-drop the wizard rank
# -----------------------------------------------------------------------------
case "$MODEL" in
  *opus*|*Opus*)   MODEL_DISPLAY="Archchancellor ${MODEL}" ; MODEL_COLOR="$GOLD"   ;;
  *sonnet*|*Sonnet*) MODEL_DISPLAY="Senior Wrangler ${MODEL}" ; MODEL_COLOR="$LILAC" ;;
  *haiku*|*Haiku*) MODEL_DISPLAY="Librarian ${MODEL}" ; MODEL_COLOR="$COPPER"       ;;
  *)               MODEL_DISPLAY="$MODEL"              ; MODEL_COLOR="$COBBLE"      ;;
esac

# -----------------------------------------------------------------------------
# Git section
# -----------------------------------------------------------------------------
DIRNAME="${DIR##*/}"
[ -z "$DIRNAME" ] && DIRNAME="$DIR"

if [ -n "$BRANCH" ]; then
  GIT_SECTION="${COBBLE}${DIRNAME}${RESET} ${DIM}on${RESET} ${RIVER}⎇ ${BRANCH}${RESET}"
  CHANGES=""
  [ "$STAGED"    -gt 0 ] && CHANGES="${CHANGES} ${GREEN}+${STAGED}staged${RESET}"
  [ "$MODIFIED"  -gt 0 ] && CHANGES="${CHANGES} ${FLAME}~${MODIFIED}${RESET}"
  [ "$UNTRACKED" -gt 0 ] && CHANGES="${CHANGES} ${COBBLE}?${UNTRACKED}${RESET}"
  [ -n "$CHANGES" ] && GIT_SECTION="${GIT_SECTION}${CHANGES}" || GIT_SECTION="${GIT_SECTION} ${DIM}(clean)${RESET}"
else
  GIT_SECTION="${COBBLE}${DIRNAME}${RESET} ${DIM}(no watch patrol here)${RESET}"
fi

# -----------------------------------------------------------------------------
# Token detail (shown when context is non-trivial)
# -----------------------------------------------------------------------------
if [ "$TOK_IN" -gt 0 ] || [ "$TOK_CACHE" -gt 0 ]; then
  TOK_K=$(( (TOK_IN + TOK_CACHE + TOK_WRITE) / 1000 ))
  MAX_K=$(( CTX_MAX / 1000 ))
  TOK_DETAIL=" ${DIM}${TOK_K}k/${MAX_K}k tokens${RESET}"
else
  TOK_DETAIL=""
fi

# -----------------------------------------------------------------------------
# Assemble — two lines
# Line 1: Watch badge | model | git
# Line 2: Context bar | percentage | flavour label
# -----------------------------------------------------------------------------
LINE1="${BOLD}${COPPER}⚔ City Watch${RESET}  ${MODEL_COLOR}${MODEL_DISPLAY}${RESET}  ${GIT_SECTION}"
LINE2="${BAR_COLOR}[${BAR}]${RESET} ${BOLD}${PCT}%${RESET}${TOK_DETAIL}  ${DIM}${CTX_LABEL}${RESET}"

printf "%b\n%b\n" "$LINE1" "$LINE2"
