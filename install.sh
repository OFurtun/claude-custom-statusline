#!/bin/bash
# Installer for Furtun's Custom Statusline for Claude Code

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SIGNATURE="# Furtun's Custom Statusline"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Furtun's Custom Statusline Installer${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if Claude Code config directory exists
CLAUDE_DIR="$HOME/.claude"
if [ ! -d "$CLAUDE_DIR" ]; then
    echo -e "${RED}Error: Claude Code config directory not found at $CLAUDE_DIR${NC}"
    echo "Please ensure Claude Code is installed and has been run at least once."
    exit 1
fi

echo -e "${BLUE}[1/6]${NC} Checking prerequisites..."

# Check for jq (required)
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: 'jq' is required but not installed.${NC}"
    echo "Please install jq:"
    echo "  - Ubuntu/Debian: sudo apt-get install jq"
    echo "  - macOS: brew install jq"
    echo "  - Fedora: sudo dnf install jq"
    exit 1
fi
echo -e "${GREEN}✓${NC} Prerequisites met"

# ── Step 2: Detect existing statusline and prompt before overwriting ──
echo -e "${BLUE}[2/6]${NC} Checking for existing installation..."

IS_UPGRADE=false
STATUSLINE_FILE="$CLAUDE_DIR/statusline.sh"

if [ -f "$STATUSLINE_FILE" ]; then
    if grep -q "$SIGNATURE" "$STATUSLINE_FILE"; then
        IS_UPGRADE=true
        echo -e "${GREEN}✓${NC} Existing Furtun's Custom Statusline detected — upgrading to latest version"
    else
        echo -e "${YELLOW}Warning: A custom statusline already exists at $STATUSLINE_FILE${NC}"
        echo "  It does not appear to be Furtun's Custom Statusline."
        read -p "  Replace it? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${RED}Installation aborted.${NC}"
            exit 1
        fi
    fi
fi

# Check if settings.json points to a different statusline script
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
if [ -f "$SETTINGS_FILE" ]; then
    EXISTING_CMD=$(jq -r '.statusline.command // empty' "$SETTINGS_FILE" 2>/dev/null)
    if [ -n "$EXISTING_CMD" ] && [[ "$EXISTING_CMD" != *"statusline.sh"* ]]; then
        echo -e "${YELLOW}Warning: settings.json statusline command points to a different script:${NC}"
        echo "  $EXISTING_CMD"
        read -p "  Overwrite with Furtun's statusline? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${RED}Installation aborted.${NC}"
            exit 1
        fi
    fi
fi

# ── Step 3: Backup existing files ──
echo -e "${BLUE}[3/6]${NC} Backing up existing files..."
BACKUP_DIR="$CLAUDE_DIR/statusline_backup_$(date +%Y%m%d_%H%M%S)"

if [ -f "$CLAUDE_DIR/statusline.sh" ] || [ -f "$CLAUDE_DIR/statusline.config.json" ]; then
    mkdir -p "$BACKUP_DIR"
    [ -f "$CLAUDE_DIR/statusline.sh" ] && cp "$CLAUDE_DIR/statusline.sh" "$BACKUP_DIR/"
    [ -f "$CLAUDE_DIR/statusline.config.json" ] && cp "$CLAUDE_DIR/statusline.config.json" "$BACKUP_DIR/"
    echo -e "${GREEN}✓${NC} Backup created at: $BACKUP_DIR"
else
    echo -e "${GREEN}✓${NC} No existing files to backup"
fi

# ── Step 4: Install statusline files ──
echo -e "${BLUE}[4/6]${NC} Installing statusline files..."

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Install statusline.sh
if [ -f "$SCRIPT_DIR/statusline.sh" ]; then
    cp "$SCRIPT_DIR/statusline.sh" "$CLAUDE_DIR/statusline.sh"
else
    echo "Downloading from GitHub..."
    curl -fsSL https://raw.githubusercontent.com/OFurtun/claude-custom-statusline/main/statusline.sh -o "$CLAUDE_DIR/statusline.sh"
fi
chmod +x "$CLAUDE_DIR/statusline.sh"

# Install / merge config
CONFIG_FILE="$CLAUDE_DIR/statusline.config.json"
if [ -f "$SCRIPT_DIR/statusline.config.json" ]; then
    NEW_DEFAULTS="$SCRIPT_DIR/statusline.config.json"
else
    NEW_DEFAULTS=$(mktemp)
    curl -fsSL https://raw.githubusercontent.com/OFurtun/claude-custom-statusline/main/statusline.config.json -o "$NEW_DEFAULTS"
fi

if [ -f "$CONFIG_FILE" ] && [ "$IS_UPGRADE" = true ]; then
    # Merge: new defaults as base, user values overlay, then filter to only valid keys
    VALID_KEYS=$(jq -r 'keys[]' "$NEW_DEFAULTS")
    MERGED=$(jq -s '.[0] * .[1]' "$NEW_DEFAULTS" "$CONFIG_FILE")
    FILTERED=$(echo "$MERGED" | jq --argjson valid "$(jq 'keys' "$NEW_DEFAULTS")" 'with_entries(select(.key as $k | $valid | index($k)))')

    # Report changes
    ADDED_KEYS=$(jq -r --argjson user "$(jq 'keys' "$CONFIG_FILE")" 'keys | map(select(. as $k | $user | index($k) | not)) | .[]' "$NEW_DEFAULTS")
    REMOVED_KEYS=$(jq -r --argjson valid "$(jq 'keys' "$NEW_DEFAULTS")" 'keys | map(select(. as $k | $valid | index($k) | not)) | .[]' "$CONFIG_FILE")

    if [ -n "$ADDED_KEYS" ]; then
        echo -e "${GREEN}  New config keys added:${NC}"
        for key in $ADDED_KEYS; do
            DEFAULT_VAL=$(jq -r --arg k "$key" '.[$k]' "$NEW_DEFAULTS")
            echo "    + $key = $DEFAULT_VAL"
        done
    fi
    if [ -n "$REMOVED_KEYS" ]; then
        echo -e "${YELLOW}  Obsolete config keys removed:${NC}"
        for key in $REMOVED_KEYS; do
            echo "    - $key"
        done
    fi

    echo "$FILTERED" | jq '.' > "$CONFIG_FILE"
    echo -e "${GREEN}✓${NC} Config merged (user values preserved, defaults updated)"
else
    cp "$NEW_DEFAULTS" "$CONFIG_FILE"
    echo -e "${GREEN}✓${NC} Default config installed"
fi

# Clean up temp file if we downloaded it
if [ ! -f "$SCRIPT_DIR/statusline.config.json" ] && [ -f "$NEW_DEFAULTS" ]; then
    rm -f "$NEW_DEFAULTS"
fi

echo -e "${GREEN}✓${NC} Statusline files installed"

# ── Step 5: Install slash commands ──
echo -e "${BLUE}[5/6]${NC} Installing slash commands..."
COMMANDS_DIR="$CLAUDE_DIR/commands"
mkdir -p "$COMMANDS_DIR"

if [ -d "$SCRIPT_DIR/commands" ]; then
    cp "$SCRIPT_DIR/commands/"*.md "$COMMANDS_DIR/" 2>/dev/null || true
else
    curl -fsSL https://raw.githubusercontent.com/OFurtun/claude-custom-statusline/main/commands/statusline-detailed.md -o "$COMMANDS_DIR/statusline-detailed.md"
fi
echo -e "${GREEN}✓${NC} Slash commands installed"

# ── Step 6: Configure settings.json with jq ──
echo -e "${BLUE}[6/6]${NC} Configuring Claude Code settings..."

if [ -f "$SETTINGS_FILE" ]; then
    # Use jq to ensure statusline.enabled = true
    UPDATED=$(jq '.statusline.enabled = true' "$SETTINGS_FILE")
    echo "$UPDATED" > "$SETTINGS_FILE"
    echo -e "${GREEN}✓${NC} Statusline enabled in settings"
else
    jq -n '{"statusline": {"enabled": true}}' > "$SETTINGS_FILE"
    echo -e "${GREEN}✓${NC} Created settings.json with statusline enabled"
fi

# ── Done ──
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation Successful!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Restart Claude Code for changes to take effect"
echo "  2. Customize the statusline by editing: $CLAUDE_DIR/statusline.config.json"
echo ""
echo "Configuration options:"
echo "  - show_cache: Display cache read tokens"
echo "  - show_git: Show git branch"
echo "  - show_lines: Display lines changed"
echo "  - show_velocity: Show tokens/minute velocity"
echo "  - show_detailed: Show detailed context breakdown"
echo "  - compact_mode: Use compact display format"
echo "  - autocompact_buffer: Reserved tokens before compaction triggers (default: 33000)"
echo ""
echo "Slash commands (restart Claude Code to use):"
echo "  /statusline-detailed - Toggle context breakdown display"
echo ""
echo "For more information, visit:"
echo "  https://github.com/OFurtun/claude-custom-statusline"
echo ""

if [ -d "$BACKUP_DIR" ]; then
    echo -e "${BLUE}Note:${NC} Your previous statusline was backed up to:"
    echo "  $BACKUP_DIR"
    echo ""
fi
