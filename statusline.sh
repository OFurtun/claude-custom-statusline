#!/bin/bash
# Claude Code Enhanced Status Line
# Displays session info, token usage, and context window status
# Uses real context_window data from Claude Code's JSON input

# ============================================================================
# CONFIGURATION
# ============================================================================

CONFIG_FILE="$HOME/.claude/statusline.config.json"
if [ -f "$CONFIG_FILE" ]; then
    SHOW_CACHE=$(jq -r '.show_cache // true' "$CONFIG_FILE")
    SHOW_GIT=$(jq -r '.show_git // true' "$CONFIG_FILE")
    SHOW_LINES=$(jq -r '.show_lines // true' "$CONFIG_FILE")
    SHOW_VELOCITY=$(jq -r '.show_velocity // false' "$CONFIG_FILE")
    SHOW_DETAILED=$(jq -r '.show_detailed // false' "$CONFIG_FILE")
    COMPACT_MODE=$(jq -r '.compact_mode // true' "$CONFIG_FILE")
    AUTOCOMPACT_BUFFER=$(jq -r '.autocompact_buffer // 33000' "$CONFIG_FILE")
else
    SHOW_CACHE=true
    SHOW_GIT=true
    SHOW_LINES=true
    SHOW_VELOCITY=false
    SHOW_DETAILED=false
    COMPACT_MODE=true
    AUTOCOMPACT_BUFFER=33000
fi

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Format tokens with K/M suffixes
format_tokens() {
    local tokens=$1
    if [ "$tokens" -ge 1000000 ]; then
        local millions=$((tokens / 100000))
        local decimal=$((millions % 10))
        local whole=$((millions / 10))
        echo "${whole}.${decimal}M"
    elif [ "$tokens" -ge 10000 ]; then
        echo "$((tokens / 1000))K"
    elif [ "$tokens" -ge 1000 ]; then
        local hundreds=$((tokens / 100))
        local decimal=$((hundreds % 10))
        local whole=$((hundreds / 10))
        echo "${whole}.${decimal}K"
    else
        echo "${tokens}"
    fi
}

# Calculate token velocity (tokens/minute over last 5 minutes)
calculate_velocity() {
    local session_id="$1"
    local current_tokens="$2"
    local velocity_file="/tmp/.claude_statusline_velocity_${session_id}.txt"
    local current_time=$(date +%s)

    echo "$current_time $current_tokens" >> "$velocity_file"

    local cutoff=$((current_time - 300))
    if [ -f "$velocity_file" ]; then
        grep -v "^[0-9]*$" "$velocity_file" | awk -v cutoff="$cutoff" '$1 > cutoff' > "${velocity_file}.tmp"
        mv "${velocity_file}.tmp" "$velocity_file"
    fi

    local lines=$(wc -l < "$velocity_file" 2>/dev/null || echo 0)
    if [ "$lines" -ge 2 ]; then
        local first_line=$(head -1 "$velocity_file")
        local last_line=$(tail -1 "$velocity_file")

        read -r first_time first_tokens <<< "$first_line"
        read -r last_time last_tokens <<< "$last_line"

        local time_diff=$((last_time - first_time))
        if [ "$time_diff" -gt 0 ]; then
            local token_diff=$((last_tokens - first_tokens))
            local velocity=$((token_diff * 60 / time_diff))
            echo "$velocity"
            return
        fi
    fi

    echo "0"
}

# Get git branch (cached)
get_git_branch() {
    local current_dir="$1"
    local session_id="$2"
    local git_cache="/tmp/.claude_statusline_git_${session_id}.cache"

    if [ -f "$git_cache" ]; then
        read -r cached_dir cached_branch < "$git_cache"
        if [ "$cached_dir" = "$current_dir" ]; then
            echo "$cached_branch"
            return
        fi
    fi

    if git --no-optional-locks rev-parse --git-dir > /dev/null 2>&1; then
        local branch=$(git --no-optional-locks branch --show-current 2>/dev/null)
        if [ -n "$branch" ]; then
            echo "$current_dir $branch" > "$git_cache"
            echo "$branch"
            return
        fi
    fi

    echo ""
}

# Get git repository name from remote origin URL (cached)
get_git_repo_name() {
    local current_dir="$1"
    local session_id="$2"
    local repo_cache="/tmp/.claude_statusline_repo_${session_id}.cache"

    if [ -f "$repo_cache" ]; then
        read -r cached_dir cached_repo < "$repo_cache"
        if [ "$cached_dir" = "$current_dir" ]; then
            echo "$cached_repo"
            return
        fi
    fi

    local repo_name=""
    if git --no-optional-locks rev-parse --git-dir > /dev/null 2>&1; then
        local remote_url=$(git --no-optional-locks remote get-url origin 2>/dev/null)
        if [ -n "$remote_url" ]; then
            repo_name=$(basename "$remote_url" .git)
        else
            repo_name=$(basename "$(git --no-optional-locks rev-parse --show-toplevel 2>/dev/null)")
        fi
    fi

    if [ -n "$repo_name" ]; then
        echo "$current_dir $repo_name" > "$repo_cache"
    fi
    echo "$repo_name"
}

# Get repo owner from remote origin URL (cached per directory)
get_repo_owner() {
    local current_dir="$1"
    local session_id="$2"
    local owner_cache="/tmp/.claude_statusline_owner_${session_id}.cache"

    if [ -f "$owner_cache" ]; then
        read -r cached_dir cached_owner < "$owner_cache"
        if [ "$cached_dir" = "$current_dir" ]; then
            echo "$cached_owner"
            return
        fi
    fi

    local owner=""
    if git --no-optional-locks rev-parse --git-dir > /dev/null 2>&1; then
        local remote_url=$(git --no-optional-locks remote get-url origin 2>/dev/null)
        if [ -n "$remote_url" ]; then
            # Extract owner from SSH (git@github.com:owner/repo.git) or HTTPS (https://github.com/owner/repo.git)
            owner=$(echo "$remote_url" | sed -E 's#.*[:/]([^/]+)/[^/]+\.git$#\1#; s#.*[:/]([^/]+)/[^/]+$#\1#')
        fi
    fi

    if [ -n "$owner" ]; then
        echo "$current_dir $owner" > "$owner_cache"
    fi
    echo "$owner"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

# Read JSON input from stdin
input=$(cat)

# Extract basic values
MODEL_DISPLAY=$(echo "$input" | jq -r '.model.display_name')
CURRENT_DIR=$(echo "$input" | jq -r '.workspace.current_dir')
SESSION_ID=$(echo "$input" | jq -r '.session_id // ""')
EXCEEDS_200K=$(echo "$input" | jq -r '.exceeds_200k_tokens // false')

# Extract token data directly from JSON (no transcript parsing)
INPUT_TOKENS=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
OUTPUT_TOKENS=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
CACHE_READ=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
CACHE_CREATION=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
SESSION_COST=$(echo "$input" | jq -r '.cost.total_cost // 0')

# Session timing
CURRENT_TIME=$(date +%s)
SESSION_FILE="/tmp/.claude_session_${SESSION_ID}.txt"
if [ -f "$SESSION_FILE" ]; then
    SESSION_START=$(cat "$SESSION_FILE")
else
    SESSION_START=$CURRENT_TIME
    echo "$SESSION_START" > "$SESSION_FILE"
fi

SESSION_ELAPSED=$((CURRENT_TIME - SESSION_START))
if [ "$SESSION_ELAPSED" -lt 60 ]; then
    SESSION_TIME="${SESSION_ELAPSED}s"
elif [ "$SESSION_ELAPSED" -lt 3600 ]; then
    SESSION_TIME="$((SESSION_ELAPSED / 60))m"
else
    SESSION_HOURS=$((SESSION_ELAPSED / 3600))
    SESSION_MINS=$(((SESSION_ELAPSED % 3600) / 60))
    if [ "$COMPACT_MODE" = "true" ]; then
        SESSION_TIME="${SESSION_HOURS}h${SESSION_MINS}m"
    else
        SESSION_TIME="${SESSION_HOURS}h ${SESSION_MINS}m"
    fi
fi

# Build token display
INPUT_DISPLAY=$(format_tokens $INPUT_TOKENS)
OUTPUT_DISPLAY=$(format_tokens $OUTPUT_TOKENS)
if [ "$SHOW_DETAILED" = "true" ]; then
    TOKEN_DISPLAY="Tokens ${INPUT_DISPLAY}↓ ${OUTPUT_DISPLAY}↑"
else
    TOKEN_DISPLAY="${INPUT_DISPLAY}↓ ${OUTPUT_DISPLAY}↑"
fi

# Token velocity (optional)
VELOCITY_DISPLAY=""
if [ "$SHOW_VELOCITY" = "true" ]; then
    TOTAL_TOKENS_COUNTED=$((INPUT_TOKENS + OUTPUT_TOKENS + CACHE_READ))
    VELOCITY=$(calculate_velocity "$SESSION_ID" "$TOTAL_TOKENS_COUNTED")
    if [ "$VELOCITY" -gt 0 ]; then
        VELOCITY_FMT=$(format_tokens $VELOCITY)
        if [ "$COMPACT_MODE" = "true" ]; then
            VELOCITY_DISPLAY=" | ⚡ ${VELOCITY_FMT}/m"
        else
            VELOCITY_DISPLAY=" | ⚡ ${VELOCITY_FMT}/min"
        fi
    fi
fi

# Git branch (if enabled)
GIT_DISPLAY=""
if [ "$SHOW_GIT" = "true" ]; then
    BRANCH=$(get_git_branch "$CURRENT_DIR" "$SESSION_ID")
    if [ -n "$BRANCH" ]; then
        if [ "$COMPACT_MODE" = "true" ]; then
            GIT_DISPLAY=" | 🌿 $BRANCH"
        else
            GIT_DISPLAY=" | 🌿  $BRANCH"
        fi
    fi
fi

# Repo owner and name from remote origin
REPO_NAME=$(get_git_repo_name "$CURRENT_DIR" "$SESSION_ID")
REPO_OWNER=$(get_repo_owner "$CURRENT_DIR" "$SESSION_ID")

# Shorten home directory to ~
SHORT_DIR="${CURRENT_DIR/#$HOME/\~}"

# Build location display: 📁 ~/path | 🔗 user/repo
LOCATION_DISPLAY="${SHORT_DIR}"
if [ -n "$REPO_OWNER" ] && [ -n "$REPO_NAME" ]; then
    LOCATION_DISPLAY="${LOCATION_DISPLAY} | 🔗 ${REPO_OWNER}/${REPO_NAME}"
elif [ -n "$REPO_NAME" ]; then
    LOCATION_DISPLAY="${LOCATION_DISPLAY} | 🔗 ${REPO_NAME}"
fi

# Context window — uses real data from Claude Code's context_window JSON
CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
HAS_CONTEXT_DATA=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

if [ "$EXCEEDS_200K" = "true" ]; then
    CONTEXT_DISPLAY="🔴 COMPACTED"
elif [ -z "$HAS_CONTEXT_DATA" ]; then
    CONTEXT_DISPLAY="⏳"
else
    USED_PCT=$HAS_CONTEXT_DATA

    # Derive remaining from used
    REMAINING_TOKENS=$(( CONTEXT_SIZE * (100 - USED_PCT) / 100 ))
    FREE_TOKENS=$((REMAINING_TOKENS - AUTOCOMPACT_BUFFER))
    if [ "$FREE_TOKENS" -lt 0 ]; then
        FREE_TOKENS=0
    fi
    FREE_PCT=$((FREE_TOKENS * 100 / CONTEXT_SIZE))

    # Used tokens (from percentage)
    USED_TOKENS=$((CONTEXT_SIZE * USED_PCT / 100))
    # Warning icon based on free %
    if [ "$FREE_PCT" -le 10 ]; then
        ICON="🔴"
    elif [ "$FREE_PCT" -le 25 ]; then
        ICON="🟡"
    else
        ICON="🟢"
    fi

    FREE_FMT=$(format_tokens $FREE_TOKENS)
    LIMIT_FMT=$(format_tokens $CONTEXT_SIZE)

    if [ "$SHOW_DETAILED" = "true" ]; then
        USED_FMT=$(format_tokens $USED_TOKENS)
        AUTOCOMPACT_FMT=$(format_tokens $AUTOCOMPACT_BUFFER)
        AUTOCOMPACT_PCT=$((AUTOCOMPACT_BUFFER * 100 / CONTEXT_SIZE))

        DETAILED_DISPLAY=" | 📊 Used: ${USED_FMT} (${USED_PCT}%) | 🔒 Compaction Buffer: ${AUTOCOMPACT_FMT} (~${AUTOCOMPACT_PCT}%)"

        # Cache statistics (only shown in detailed mode)
        if [ "$SHOW_CACHE" = "true" ]; then
            CACHE_READ_FMT=$(format_tokens $CACHE_READ)
            CACHE_CREATION_FMT=$(format_tokens $CACHE_CREATION)
            DETAILED_DISPLAY="${DETAILED_DISPLAY} | 💾 Cache Read: ${CACHE_READ_FMT} | Cache Write: ${CACHE_CREATION_FMT}"
        fi

        # Lines changed (only shown in detailed mode)
        if [ "$SHOW_LINES" = "true" ]; then
            LINES_ADDED=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
            LINES_REMOVED=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
            if [ "$LINES_ADDED" -gt 0 ] || [ "$LINES_REMOVED" -gt 0 ]; then
                DETAILED_DISPLAY="${DETAILED_DISPLAY} | ✏️ Total Lines +${LINES_ADDED}/-${LINES_REMOVED}"
            fi
        fi
    else
        DETAILED_DISPLAY=""
    fi

    if [ "$SHOW_DETAILED" = "true" ]; then
        CONTEXT_DISPLAY="${ICON} ${FREE_FMT}/${LIMIT_FMT} (${FREE_PCT}%) remaining"
    else
        CONTEXT_DISPLAY="${ICON} ${FREE_FMT}/${LIMIT_FMT} (${FREE_PCT}%)"
    fi
fi # end context_window branches

# Session cost display
COST_DISPLAY=""
if [ "$SESSION_COST" != "0" ] && [ "$SESSION_COST" != "null" ] && [ -n "$SESSION_COST" ]; then
    if [ "$SHOW_DETAILED" = "true" ]; then
        COST_DISPLAY=" | 💲 Session Cost: ${SESSION_COST}"
    else
        COST_DISPLAY=" | 💲 ${SESSION_COST}"
    fi
fi

# Build session time display
if [ "$SHOW_DETAILED" = "true" ]; then
    TIME_DISPLAY="🕐 Started ${SESSION_TIME} ago"
else
    TIME_DISPLAY="🕐 ${SESSION_TIME}"
fi

# Build final status line
if [ "$COMPACT_MODE" = "true" ]; then
    STATUS_LINE="[$MODEL_DISPLAY] 📁 ${LOCATION_DISPLAY}$GIT_DISPLAY | ${CONTEXT_DISPLAY} | ${TIME_DISPLAY} | 🪙 ${TOKEN_DISPLAY}${VELOCITY_DISPLAY}${COST_DISPLAY}${DETAILED_DISPLAY}"
else
    STATUS_LINE="[$MODEL_DISPLAY] 📁  ${LOCATION_DISPLAY}$GIT_DISPLAY | ${CONTEXT_DISPLAY} | ${TIME_DISPLAY} | 🪙 ${TOKEN_DISPLAY}${VELOCITY_DISPLAY}${COST_DISPLAY}${DETAILED_DISPLAY}"
fi

# Cleanup old session files
find /tmp -name ".claude_session_*.txt" -mtime +1 -delete 2>/dev/null
find /tmp -name ".claude_statusline_*" -mtime +1 -delete 2>/dev/null

echo "$STATUS_LINE"
