#!/bin/bash
# Installer for Furtun's Custom Statusline for Claude Code

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

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

# Check for jq
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Warning: 'jq' is not installed. The statusline requires jq to function.${NC}"
    echo "Please install jq:"
    echo "  - Ubuntu/Debian: sudo apt-get install jq"
    echo "  - macOS: brew install jq"
    echo "  - Fedora: sudo dnf install jq"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Backup existing files if they exist
echo -e "${BLUE}[2/6]${NC} Backing up existing files..."
BACKUP_DIR="$CLAUDE_DIR/statusline_backup_$(date +%Y%m%d_%H%M%S)"

if [ -f "$CLAUDE_DIR/statusline.sh" ] || [ -f "$CLAUDE_DIR/statusline.config.json" ]; then
    mkdir -p "$BACKUP_DIR"
    [ -f "$CLAUDE_DIR/statusline.sh" ] && cp "$CLAUDE_DIR/statusline.sh" "$BACKUP_DIR/"
    [ -f "$CLAUDE_DIR/statusline.config.json" ] && cp "$CLAUDE_DIR/statusline.config.json" "$BACKUP_DIR/"
    echo -e "${GREEN}✓${NC} Backup created at: $BACKUP_DIR"
else
    echo -e "${GREEN}✓${NC} No existing files to backup"
fi

# Install statusline files
echo -e "${BLUE}[3/6]${NC} Installing statusline files..."

# Determine the source directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ -f "$SCRIPT_DIR/statusline.sh" ]; then
    # Local installation
    cp "$SCRIPT_DIR/statusline.sh" "$CLAUDE_DIR/statusline.sh"
    cp "$SCRIPT_DIR/statusline.config.json" "$CLAUDE_DIR/statusline.config.json"
else
    # Remote installation
    echo "Downloading from GitHub..."
    curl -fsSL https://raw.githubusercontent.com/OFurtun/claude-custom-statusline/main/statusline.sh -o "$CLAUDE_DIR/statusline.sh"
    curl -fsSL https://raw.githubusercontent.com/OFurtun/claude-custom-statusline/main/statusline.config.json -o "$CLAUDE_DIR/statusline.config.json"
fi

chmod +x "$CLAUDE_DIR/statusline.sh"
echo -e "${GREEN}✓${NC} Files installed successfully"

# Update settings.json if needed
echo -e "${BLUE}[4/6]${NC} Installing slash commands..."
COMMANDS_DIR="$CLAUDE_DIR/commands"
mkdir -p "$COMMANDS_DIR"

if [ -d "$SCRIPT_DIR/commands" ]; then
    # Local installation
    cp "$SCRIPT_DIR/commands/"*.md "$COMMANDS_DIR/" 2>/dev/null || true
else
    # Remote installation
    curl -fsSL https://raw.githubusercontent.com/OFurtun/claude-custom-statusline/main/commands/statusline-breakdown.md -o "$COMMANDS_DIR/statusline-breakdown.md"
    curl -fsSL https://raw.githubusercontent.com/OFurtun/claude-custom-statusline/main/commands/statusline-subscription.md -o "$COMMANDS_DIR/statusline-subscription.md"
fi
echo -e "${GREEN}✓${NC} Slash commands installed"

echo -e "${BLUE}[5/6]${NC} Configuring Claude Code settings..."
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

if [ -f "$SETTINGS_FILE" ]; then
    # Check if statusline is already enabled
    if grep -q '"statusline"' "$SETTINGS_FILE"; then
        if grep -q '"enabled".*true' "$SETTINGS_FILE"; then
            echo -e "${GREEN}✓${NC} Statusline already enabled in settings"
        else
            echo -e "${YELLOW}Note: Statusline exists but may not be enabled. Please check $SETTINGS_FILE${NC}"
        fi
    else
        # Add statusline config
        echo -e "${YELLOW}Adding statusline configuration to settings.json...${NC}"
        # Create backup of settings
        cp "$SETTINGS_FILE" "$SETTINGS_FILE.bak"

        # Add statusline config (simple approach - append before closing brace)
        if [ -s "$SETTINGS_FILE" ]; then
            # File has content
            if grep -q "^{$" "$SETTINGS_FILE" && grep -q "^}$" "$SETTINGS_FILE"; then
                # Simple JSON structure
                sed -i 's/^}$/,\n  "statusline": {\n    "enabled": true\n  }\n}/' "$SETTINGS_FILE"
                echo -e "${GREEN}✓${NC} Statusline enabled in settings"
            else
                echo -e "${YELLOW}Warning: Could not automatically update settings.json${NC}"
                echo "Please manually add to $SETTINGS_FILE:"
                echo '  "statusline": { "enabled": true }'
            fi
        fi
    fi
else
    # Create new settings file
    echo '{
  "statusline": {
    "enabled": true
  }
}' > "$SETTINGS_FILE"
    echo -e "${GREEN}✓${NC} Created settings.json with statusline enabled"
fi

# Done
echo -e "${BLUE}[6/6]${NC} Installation complete!"
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
echo "  - show_breakdown: Show detailed context breakdown"
echo "  - compact_mode: Use compact display format"
echo "  - context_limit: 200000 (Max 5x) or 100000 (Max 20x)"
echo ""
echo "Slash commands (restart Claude Code to use):"
echo "  /statusline-breakdown    - Toggle context breakdown display"
echo "  /statusline-subscription - Switch between Max 5x/20x subscription modes"
echo ""
echo "For more information, visit:"
echo "  https://github.com/OFurtun/claude-custom-statusline"
echo ""

if [ -d "$BACKUP_DIR" ]; then
    echo -e "${BLUE}Note:${NC} Your previous statusline was backed up to:"
    echo "  $BACKUP_DIR"
    echo ""
fi
