# Furtun's Custom Statusline for Claude Code

An enhanced statusline for [Claude Code](https://code.claude.com) that displays comprehensive session information including token usage, cache metrics, git branch, context window status, and more.

## Features

- **Token Tracking**: Real-time display of input/output tokens with efficient incremental parsing
- **Cache Metrics**: Shows cache read tokens to monitor prompt caching efficiency
- **Context Window Visualization**: Color-coded indicator (🟢/🟡/🔴) showing remaining context space
- **Git Integration**: Displays current branch with caching for performance
- **Session Timer**: Tracks elapsed time since session start
- **Lines Changed**: Shows lines added/removed during the session
- **Configurable Display**: Customize which features to show via JSON config
- **Compact Mode**: Toggle between verbose and compact display formats
- **Performance Optimized**: Uses incremental parsing and caching to minimize overhead

## Preview

Compact mode:
```
[Sonnet 4.5] 📁 my-project | 🌿 main | 🕐 15m | 🪙 45.2K↓ 12.3K↑ | 💾 7.7M | 🟢 154.8K/200K (77%) | +234/-89
```

Verbose mode:
```
[Sonnet 4.5] 📁 my-project | 🌿 main | 🕐 Started 15m ago | 🪙 In: 45.2K | Out: 12.3K | Cache: 7.7M | 🟢 Context: 77% (154.8K left) | +234/-89
```

## Installation

### Quick Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/OFurtun/claude-custom-statusline/main/install.sh | bash
```

### Manual Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/OFurtun/claude-custom-statusline.git
   cd claude-custom-statusline
   ```

2. Copy files to your Claude Code config directory:
   ```bash
   cp statusline.sh ~/.claude/statusline.sh
   cp statusline.config.json ~/.claude/statusline.config.json
   chmod +x ~/.claude/statusline.sh
   ```

3. Enable the statusline in `~/.claude/settings.json`:
   ```json
   {
     "statusline": {
       "enabled": true
     }
   }
   ```

4. Restart Claude Code

## Configuration

Edit `~/.claude/statusline.config.json` to customize the display:

```json
{
  "show_cache": true,          // Display cache read tokens
  "show_git": true,            // Show git branch
  "show_lines": true,          // Display lines changed
  "show_velocity": false,      // Show token velocity (tokens/minute)
  "compact_mode": true,        // Use compact display format
  "context_limit": 200000      // Context window limit for calculations
}
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `show_cache` | boolean | `true` | Display cache read tokens |
| `show_git` | boolean | `true` | Show current git branch |
| `show_lines` | boolean | `true` | Display lines added/removed |
| `show_velocity` | boolean | `false` | Show token velocity (tokens/min) |
| `compact_mode` | boolean | `true` | Use compact format with symbols |
| `context_limit` | number | `200000` | Context window size for percentage calculations |

## How It Works

The statusline script:
1. Receives JSON input from Claude Code with session metadata
2. Incrementally parses the transcript file to extract token usage
3. Caches results to avoid re-parsing on every update
4. Formats the data according to your configuration
5. Returns a single-line status string

### Performance Features

- **Incremental Token Parsing**: Only parses new messages since last check
- **Git Branch Caching**: Caches branch lookup per directory
- **Session State Persistence**: Maintains session start time across updates
- **Automatic Cleanup**: Removes stale cache files older than 1 day

## Troubleshooting

### Statusline not appearing
- Ensure `~/.claude/settings.json` has `"statusline": { "enabled": true }`
- Check that `~/.claude/statusline.sh` is executable: `chmod +x ~/.claude/statusline.sh`
- Restart Claude Code

### Incorrect token counts
- The script parses the transcript file incrementally
- If counts seem wrong, remove cache files: `rm /tmp/.claude_statusline_tokens_*.cache`

### Git branch not showing
- Ensure you're in a git repository
- Check that git commands work: `git branch --show-current`
- Try toggling `show_git` to `false` and back to `true`

## Requirements

- Claude Code (latest version recommended)
- Bash 4.0 or higher
- `jq` for JSON parsing
- `git` (optional, for git branch display)

## Contributing

Contributions are welcome! Feel free to:
- Report bugs via GitHub Issues
- Submit pull requests with improvements
- Share feedback and feature requests

## License

MIT License - feel free to use and modify as needed.

## Author

Created by OFurtun

## Acknowledgments

Built for the Claude Code community to enhance the development experience.
