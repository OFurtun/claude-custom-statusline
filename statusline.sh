#!/bin/bash
# Claude Code Enhanced Status Line
# Displays session info, token usage, and context window status

# ============================================================================
# CONFIGURATION
# ============================================================================

# Load user config if exists, otherwise use defaults
CONFIG_FILE="$HOME/.claude/statusline.config.json"
if [ -f "$CONFIG_FILE" ]; then
    SHOW_CACHE=$(jq -r '.show_cache // true' "$CONFIG_FILE")
    SHOW_GIT=$(jq -r '.show_git // true' "$CONFIG_FILE")
    SHOW_LINES=$(jq -r '.show_lines // true' "$CONFIG_FILE")
    SHOW_VELOCITY=$(jq -r '.show_velocity // false' "$CONFIG_FILE")
    SHOW_BREAKDOWN=$(jq -r '.show_breakdown // false' "$CONFIG_FILE")
    COMPACT_MODE=$(jq -r '.compact_mode // false' "$CONFIG_FILE")
    CONTEXT_LIMIT=$(jq -r '.context_limit // 200000' "$CONFIG_FILE")
    SYSTEM_PROMPT_TOKENS=$(jq -r '.system_prompt_tokens // 2800' "$CONFIG_FILE")
    SYSTEM_TOOLS_TOKENS=$(jq -r '.system_tools_tokens // 14500' "$CONFIG_FILE")
    MCP_TOOLS_TOKENS=$(jq -r '.mcp_tools_tokens // 17600' "$CONFIG_FILE")
    AUTOCOMPACT_BUFFER=$(jq -r '.autocompact_buffer // 45000' "$CONFIG_FILE")
else
    # Defaults
    SHOW_CACHE=true
    SHOW_GIT=true
    SHOW_LINES=true
    SHOW_VELOCITY=false
    SHOW_BREAKDOWN=false
    COMPACT_MODE=true
    CONTEXT_LIMIT=200000
    # Exact values from /context output
    SYSTEM_PROMPT_TOKENS=2800    # 1.4%
    SYSTEM_TOOLS_TOKENS=14500    # 7.3%
    MCP_TOOLS_TOKENS=17600       # 8.8%
    AUTOCOMPACT_BUFFER=45000     # 22.5%
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

# Get current context size from the last message (with caching)
# This gives us the actual current context window usage for messages
get_current_context_size() {
    local transcript="$1"
    local session_id="$2"
    local context_cache="/tmp/.claude_statusline_context_${session_id}.cache"

    if [ ! -f "$transcript" ]; then
        echo "0"
        return
    fi

    # Check if cache is valid (file hasn't been modified)
    local file_mtime=$(stat -c %Y "$transcript" 2>/dev/null || stat -f %m "$transcript" 2>/dev/null)
    if [ -f "$context_cache" ]; then
        read -r cached_mtime cached_context < "$context_cache"
        if [ "$cached_mtime" = "$file_mtime" ]; then
            echo "$cached_context"
            return
        fi
    fi

    # Get the last assistant message's token usage using tac for efficiency
    local last_msg=$(tac "$transcript" 2>/dev/null | grep -m1 '"type":"assistant"' || grep '"type":"assistant"' "$transcript" | tail -1)
    if [ -z "$last_msg" ]; then
        echo "0"
        return
    fi

    # Extract tokens from the last message - use head -1 to get only first match
    local input=$(echo "$last_msg" | grep -o '"input_tokens":[0-9]*' | head -1 | cut -d':' -f2)
    local cache_read=$(echo "$last_msg" | grep -o '"cache_read_input_tokens":[0-9]*' | head -1 | cut -d':' -f2)
    local cache_creation=$(echo "$last_msg" | grep -o '"cache_creation_input_tokens":[0-9]*' | head -1 | cut -d':' -f2)

    # Default to 0 if empty
    input=${input:-0}
    cache_read=${cache_read:-0}
    cache_creation=${cache_creation:-0}

    # The current context is approximately: cache_read + cache_creation + input
    local current_context=$((input + cache_read + cache_creation))

    # Cache the result
    echo "$file_mtime $current_context" > "$context_cache"

    echo "$current_context"
}

# Get tokens incrementally (only parse new messages)
get_tokens_incremental() {
    local transcript="$1"
    local session_id="$2"
    local cache_file="/tmp/.claude_statusline_tokens_${session_id}.cache"

    # Check if transcript exists
    if [ ! -f "$transcript" ]; then
        echo "0 0 0 0"
        return
    fi

    # Count total messages
    local total_messages=$(grep -c '"type":"assistant"' "$transcript" 2>/dev/null || echo 0)

    # Read cache
    local last_count=0
    local cached_input=0
    local cached_output=0
    local cached_cache_read=0
    local cached_cache_creation=0

    if [ -f "$cache_file" ]; then
        read -r last_count cached_input cached_output cached_cache_read cached_cache_creation < "$cache_file"
    fi

    # If no new messages, return cached values
    if [ "$total_messages" -le "$last_count" ]; then
        echo "$cached_input $cached_output $cached_cache_read $cached_cache_creation"
        return
    fi

    # Parse only new messages (after last_count) - use simple grep/cut for reliability
    local new_messages=$((total_messages - last_count))

    # Get all assistant messages, then skip already-counted ones and process the rest
    local new_input=$(grep '"type":"assistant"' "$transcript" | tail -n "$new_messages" | grep -o '"input_tokens":[0-9]*' | cut -d':' -f2 | paste -sd+ - | bc 2>/dev/null || echo 0)
    local new_output=$(grep '"type":"assistant"' "$transcript" | tail -n "$new_messages" | grep -o '"output_tokens":[0-9]*' | cut -d':' -f2 | paste -sd+ - | bc 2>/dev/null || echo 0)
    local new_cache_read=$(grep '"type":"assistant"' "$transcript" | tail -n "$new_messages" | grep -o '"cache_read_input_tokens":[0-9]*' | cut -d':' -f2 | paste -sd+ - | bc 2>/dev/null || echo 0)
    local new_cache_creation=$(grep '"type":"assistant"' "$transcript" | tail -n "$new_messages" | grep -o '"cache_creation_input_tokens":[0-9]*' | cut -d':' -f2 | paste -sd+ - | bc 2>/dev/null || echo 0)

    # Default to 0 if empty
    new_input=${new_input:-0}
    new_output=${new_output:-0}
    new_cache_read=${new_cache_read:-0}
    new_cache_creation=${new_cache_creation:-0}

    # Add to cached totals
    local total_input=$((cached_input + ${new_input:-0}))
    local total_output=$((cached_output + ${new_output:-0}))
    local total_cache_read=$((cached_cache_read + ${new_cache_read:-0}))
    local total_cache_creation=$((cached_cache_creation + ${new_cache_creation:-0}))

    # Update cache
    echo "$total_messages $total_input $total_output $total_cache_read $total_cache_creation" > "$cache_file"

    # Return totals
    echo "$total_input $total_output $total_cache_read $total_cache_creation"
}

# Calculate token velocity (tokens/minute over last 5 minutes)
calculate_velocity() {
    local session_id="$1"
    local current_tokens="$2"
    local velocity_file="/tmp/.claude_statusline_velocity_${session_id}.txt"
    local current_time=$(date +%s)

    # Store current measurement
    echo "$current_time $current_tokens" >> "$velocity_file"

    # Clean up entries older than 5 minutes
    local cutoff=$((current_time - 300))
    if [ -f "$velocity_file" ]; then
        grep -v "^[0-9]*$" "$velocity_file" | awk -v cutoff="$cutoff" '$1 > cutoff' > "${velocity_file}.tmp"
        mv "${velocity_file}.tmp" "$velocity_file"
    fi

    # Calculate velocity if we have enough data
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

    # Check cache
    if [ -f "$git_cache" ]; then
        read -r cached_dir cached_branch < "$git_cache"
        if [ "$cached_dir" = "$current_dir" ]; then
            echo "$cached_branch"
            return
        fi
    fi

    # Get branch
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
TRANSCRIPT_PATH=$(echo "$input" | jq -r '.transcript_path')

# Get tokens incrementally (for historical display)
read -r INPUT_TOKENS OUTPUT_TOKENS CACHE_READ CACHE_CREATION <<< $(get_tokens_incremental "$TRANSCRIPT_PATH" "$SESSION_ID")

# Get current context size (for accurate context window calculation)
CURRENT_CONTEXT_SIZE=$(get_current_context_size "$TRANSCRIPT_PATH" "$SESSION_ID")

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
if [ "$COMPACT_MODE" = "true" ]; then
    TOKEN_DISPLAY="${INPUT_DISPLAY}↓ ${OUTPUT_DISPLAY}↑"
else
    TOKEN_DISPLAY="In: ${INPUT_DISPLAY} | Out: ${OUTPUT_DISPLAY}"
fi

# Add cache if enabled and present
if [ "$SHOW_CACHE" = "true" ] && [ "$CACHE_READ" -gt 0 ]; then
    CACHE_DISPLAY=$(format_tokens $CACHE_READ)
    if [ "$COMPACT_MODE" = "true" ]; then
        TOKEN_DISPLAY="${TOKEN_DISPLAY} | 💾 ${CACHE_DISPLAY}"
    else
        TOKEN_DISPLAY="${TOKEN_DISPLAY} | Cache: ${CACHE_DISPLAY}"
    fi
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

# Context window calculation
# CURRENT_CONTEXT_SIZE is from the last API call (cache_read + cache_creation + input)
# This includes: system prompt, system tools, MCP tools, and messages

# System overhead for breakdown display
SYSTEM_OVERHEAD=$((SYSTEM_PROMPT_TOKENS + SYSTEM_TOOLS_TOKENS + MCP_TOOLS_TOKENS))

# If no transcript data yet (fresh conversation), use system overhead as minimum
if [ "$CURRENT_CONTEXT_SIZE" -eq 0 ] || [ "$CURRENT_CONTEXT_SIZE" -lt "$SYSTEM_OVERHEAD" ]; then
    CURRENT_CONTEXT_SIZE=$SYSTEM_OVERHEAD
fi

# Add autocompact buffer to get total used context
TOTAL_CONTEXT_USED=$((CURRENT_CONTEXT_SIZE + AUTOCOMPACT_BUFFER))

if [ "$EXCEEDS_200K" = "true" ]; then
    CONTEXT_DISPLAY="🔴  COMPACTED"
else
    USED_PCT=$((TOTAL_CONTEXT_USED * 100 / CONTEXT_LIMIT))
    REMAINING_PCT=$((100 - USED_PCT))
    REMAINING_TOKENS=$((CONTEXT_LIMIT - TOTAL_CONTEXT_USED))

    # Icon based on remaining % (green, yellow, red circles)
    if [ "$REMAINING_PCT" -le 10 ]; then
        ICON="🔴"
    elif [ "$REMAINING_PCT" -le 25 ]; then
        ICON="🟡"
    else
        ICON="🟢"
    fi

    REMAINING_FMT=$(format_tokens $REMAINING_TOKENS)
    LIMIT_FMT=$(format_tokens $CONTEXT_LIMIT)

    # Add breakdown if enabled - changes the display format
    if [ "$SHOW_BREAKDOWN" = "true" ]; then
        # Calculate total reserved (overhead + autocompact)
        TOTAL_RESERVED=$((SYSTEM_OVERHEAD + AUTOCOMPACT_BUFFER))
        TOTAL_RESERVED_FMT=$(format_tokens $TOTAL_RESERVED)

        # Calculate available context (limit - total reserved)
        AVAILABLE_CONTEXT=$((CONTEXT_LIMIT - TOTAL_RESERVED))
        AVAILABLE_CONTEXT_FMT=$(format_tokens $AVAILABLE_CONTEXT)

        # Calculate messages (current context minus system overhead)
        MESSAGE_TOKENS=$((CURRENT_CONTEXT_SIZE - SYSTEM_OVERHEAD))
        if [ "$MESSAGE_TOKENS" -lt 0 ]; then
            MESSAGE_TOKENS=0
        fi
        MESSAGE_FMT=$(format_tokens $MESSAGE_TOKENS)

        # Calculate percentages (*1000 for one decimal precision)
        AVAILABLE_PCT=$((AVAILABLE_CONTEXT * 1000 / CONTEXT_LIMIT))
        TOTAL_RESERVED_PCT=$((TOTAL_RESERVED * 1000 / CONTEXT_LIMIT))
        SYSTEM_PROMPT_PCT=$((SYSTEM_PROMPT_TOKENS * 1000 / CONTEXT_LIMIT))
        SYSTEM_TOOLS_PCT=$((SYSTEM_TOOLS_TOKENS * 1000 / CONTEXT_LIMIT))
        MCP_TOOLS_PCT=$((MCP_TOOLS_TOKENS * 1000 / CONTEXT_LIMIT))
        AUTOCOMPACT_PCT=$((AUTOCOMPACT_BUFFER * 1000 / CONTEXT_LIMIT))
        MESSAGE_PCT=$((MESSAGE_TOKENS * 1000 / CONTEXT_LIMIT))

        # Format tokens
        SYSTEM_PROMPT_FMT=$(format_tokens $SYSTEM_PROMPT_TOKENS)
        SYSTEM_TOOLS_FMT=$(format_tokens $SYSTEM_TOOLS_TOKENS)
        MCP_TOOLS_FMT=$(format_tokens $MCP_TOOLS_TOKENS)
        AUTOCOMPACT_FMT=$(format_tokens $AUTOCOMPACT_BUFFER)

        # Format percentages with one decimal
        AVAILABLE_PCT_FMT="$((AVAILABLE_PCT / 10)).$((AVAILABLE_PCT % 10))%"
        TOTAL_RESERVED_PCT_FMT="$((TOTAL_RESERVED_PCT / 10)).$((TOTAL_RESERVED_PCT % 10))%"
        SYSTEM_PROMPT_PCT_FMT="$((SYSTEM_PROMPT_PCT / 10)).$((SYSTEM_PROMPT_PCT % 10))%"
        SYSTEM_TOOLS_PCT_FMT="$((SYSTEM_TOOLS_PCT / 10)).$((SYSTEM_TOOLS_PCT % 10))%"
        MCP_TOOLS_PCT_FMT="$((MCP_TOOLS_PCT / 10)).$((MCP_TOOLS_PCT % 10))%"
        AUTOCOMPACT_PCT_FMT="$((AUTOCOMPACT_PCT / 10)).$((AUTOCOMPACT_PCT % 10))%"
        MESSAGE_PCT_FMT="$((MESSAGE_PCT / 10)).$((MESSAGE_PCT % 10))%"

        CONTEXT_DISPLAY="${ICON} ${AVAILABLE_CONTEXT_FMT}/${LIMIT_FMT} (${AVAILABLE_PCT_FMT}) | 💬 Used (${MESSAGE_FMT}/${AVAILABLE_CONTEXT_FMT} - ${MESSAGE_PCT_FMT}) | 🔒 Total reserved (${TOTAL_RESERVED_FMT} - ${TOTAL_RESERVED_PCT_FMT}) = System prompt (${SYSTEM_PROMPT_FMT} - ${SYSTEM_PROMPT_PCT_FMT}) + System tools (${SYSTEM_TOOLS_FMT} - ${SYSTEM_TOOLS_PCT_FMT}) + MCP tools (${MCP_TOOLS_FMT} - ${MCP_TOOLS_PCT_FMT}) + Autocompact buffer (${AUTOCOMPACT_FMT} - ${AUTOCOMPACT_PCT_FMT})"
    else
        if [ "$COMPACT_MODE" = "true" ]; then
            CONTEXT_DISPLAY="${ICON} ${REMAINING_FMT}/${LIMIT_FMT} (${REMAINING_PCT}%)"
        else
            CONTEXT_DISPLAY="${ICON}  Context: ${REMAINING_PCT}% (${REMAINING_FMT} left)"
        fi
    fi
fi

# Lines changed (if enabled)
LINES_DISPLAY=""
if [ "$SHOW_LINES" = "true" ]; then
    LINES_ADDED=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
    LINES_REMOVED=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
    if [ "$LINES_ADDED" -gt 0 ] || [ "$LINES_REMOVED" -gt 0 ]; then
        LINES_DISPLAY=" | +${LINES_ADDED}/-${LINES_REMOVED}"
    fi
fi

# Build final status line
if [ "$COMPACT_MODE" = "true" ]; then
    STATUS_LINE="[$MODEL_DISPLAY] 📁 ${CURRENT_DIR##*/}$GIT_DISPLAY | 🕐 ${SESSION_TIME} | 🪙  ${TOKEN_DISPLAY}${VELOCITY_DISPLAY} | ${CONTEXT_DISPLAY}${LINES_DISPLAY}"
else
    STATUS_LINE="[$MODEL_DISPLAY] 📁  ${CURRENT_DIR##*/}$GIT_DISPLAY | 🕐  Started $SESSION_TIME ago | 🪙  ${TOKEN_DISPLAY}${VELOCITY_DISPLAY} | ${CONTEXT_DISPLAY}${LINES_DISPLAY}"
fi

# Cleanup old session files
find /tmp -name ".claude_session_*.txt" -mtime +1 -delete 2>/dev/null
find /tmp -name ".claude_statusline_*" -mtime +1 -delete 2>/dev/null

echo "$STATUS_LINE"
