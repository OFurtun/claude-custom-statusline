# Furtun's Custom Statusline for Claude Code

An enhanced statusline for [Claude Code](https://code.claude.com) that displays comprehensive session information including token usage, cache metrics, git branch, context window status, and more.

## Features

- **Token Tracking**: Real-time display of input/output tokens with efficient incremental parsing
- **Cache Metrics**: Shows cache read tokens to monitor prompt caching efficiency
- **Context Window Visualization**: Color-coded indicator (🟢/🟡/🔴) showing remaining context space
- **Accurate Context Tracking**: Reads actual context usage from API responses, accounts for system overhead
- **Context Breakdown**: Optional detailed view showing system prompt, tools, MCP tools, and autocompact buffer usage
- **Subscription Support**: Switch between Claude Pro (200K) and Claude Max (100K) context limits
- **Git Integration**: Displays current branch with caching for performance
- **Session Timer**: Tracks elapsed time since session start
- **Lines Changed**: Shows lines added/removed during the session
- **Slash Commands**: Built-in commands to toggle features without editing config
- **Configurable Display**: Customize which features to show via JSON config
- **Compact Mode**: Toggle between verbose and compact display formats
- **Performance Optimized**: Uses incremental parsing and caching to minimize overhead

## Preview

Compact mode:
```
[Opus 4.5] 📁 my-project | 🌿 main | 🕐 15m | 🪙 45.2K↓ 12.3K↑ | 💾 7.7M | 🟢 120K/200K (61%) | +234/-89
```

With context breakdown enabled:
```
🟢 120K/200K (61%) | Total Reserved Context (79K - 39.9%) | System prompt (2.8K - 1.4%) | System tools (14K - 7.2%) | MCP tools (17K - 8.8%) | Autocompact buffer (45K - 22.5%) | Messages (47K - 23.7%)
```

Verbose mode:
```
[Opus 4.5] 📁 my-project | 🌿 main | 🕐 Started 15m ago | 🪙 In: 45.2K | Out: 12.3K | Cache: 7.7M | 🟢 Context: 61% (120K left) | +234/-89
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
  "show_cache": true,
  "show_git": true,
  "show_lines": true,
  "show_velocity": false,
  "show_breakdown": true,
  "compact_mode": true,
  "context_limit": 200000,
  "system_prompt_tokens": 2800,
  "system_tools_tokens": 14500,
  "mcp_tools_tokens": 17600,
  "autocompact_buffer": 45000
}
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `show_cache` | boolean | `true` | Display cache read tokens |
| `show_git` | boolean | `true` | Show current git branch |
| `show_lines` | boolean | `true` | Display lines added/removed |
| `show_velocity` | boolean | `false` | Show token velocity (tokens/min) |
| `show_breakdown` | boolean | `false` | Show detailed context breakdown |
| `compact_mode` | boolean | `true` | Use compact format with symbols |
| `context_limit` | number | `200000` | Context window size (200000 for Pro, 100000 for Max) |
| `system_prompt_tokens` | number | `2800` | System prompt token overhead |
| `system_tools_tokens` | number | `14500` | System tools token overhead |
| `mcp_tools_tokens` | number | `17600` | MCP tools token overhead |
| `autocompact_buffer` | number | `45000` | Autocompact buffer reservation |

## Slash Commands

After installation, restart Claude Code to enable these commands:

| Command | Description |
|---------|-------------|
| `/statusline-breakdown` | Toggle the detailed context breakdown display |
| `/statusline-subscription` | Switch between Pro (200K) and Max (100K) subscription modes |

## How It Works

The statusline script:
1. Receives JSON input from Claude Code with session metadata
2. Reads actual context usage from the last API response in the transcript
3. Accounts for system overhead (system prompt, tools, MCP tools, autocompact buffer)
4. Caches results to avoid re-parsing on every update
5. Formats the data according to your configuration
6. Returns a single-line status string

### Context Tracking

The statusline accurately tracks context by reading `cache_read_input_tokens + cache_creation_input_tokens + input_tokens` from the transcript. This represents the actual context sent to the API, which includes:
- System prompt (~2.8K tokens)
- System tools (~14.5K tokens)
- MCP tools (~17.6K tokens)
- Your conversation messages

The autocompact buffer (~45K for Pro, ~22.5K for Max) is reserved space for Claude's responses and is added to calculate true available context.

### Performance Features

- **Cached Context Parsing**: Only re-parses transcript when file changes (checks mtime)
- **Efficient File Reading**: Uses `tac | grep -m1` to find last message quickly
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
