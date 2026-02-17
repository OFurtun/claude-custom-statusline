# Furtun's Custom Statusline for Claude Code

An enhanced statusline for [Claude Code](https://code.claude.com) that displays comprehensive session information including token usage, session cost, cache statistics, git branch, repo info, context window status, and more.

## Features

- **Token Tracking**: Real-time display of input/output tokens with arrow indicators (↓/↑)
- **Session Cost**: Live dollar cost of the current session
- **Context Window Visualization**: Color-coded indicator (🟢/🟡/🔴) showing remaining context space
- **Detailed Mode**: Toggle expanded view with descriptors, context usage, compaction buffer, cache read/write stats, lines changed, and session start time
- **Git Integration**: Displays current branch with caching for performance
- **Repo & Owner Display**: Shows repository owner/name parsed from git remote origin URL
- **Session Timer**: Tracks elapsed time since session start
- **Token Velocity**: Optional tokens/minute tracking over a 5-minute window
- **Slash Commands**: Built-in commands to toggle features without editing config
- **Configurable Display**: Customize which features to show via JSON config
- **Performance Optimized**: Uses caching for git branch, repo name, and owner lookups

## Preview

Normal mode:
```
[Opus 4.6] 📁 ~/Projects/my-project | 🔗 OFurtun/my-project | 🌿 main | 🟢 120K/200K (60%) | 🕐 15m | 🪙 45K↓ 12K↑ | 💲 0.42
```

Detailed mode:
```
[Opus 4.6] 📁 ~/Projects/my-project | 🔗 OFurtun/my-project | 🌿 main | 🟢 120K/200K (60%) remaining | 🕐 Started 15m ago | 🪙 Tokens 45K↓ 12K↑ | 💲 Session Cost: 0.42 | 📊 Used: 47K (23%) | 🔒 Compaction Buffer: 33K (~16%) | 💾 Cache Read: 7.7M | Cache Write: 1.2K | ✏️ Total Lines +234/-89
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
  "show_detailed": false,
  "compact_mode": true,
  "autocompact_buffer": 33000
}
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `show_cache` | boolean | `true` | Show cache read/write stats in detailed mode |
| `show_git` | boolean | `true` | Show current git branch |
| `show_lines` | boolean | `true` | Show lines added/removed in detailed mode |
| `show_velocity` | boolean | `false` | Show token velocity (tokens/min) |
| `show_detailed` | boolean | `false` | Enable detailed mode with expanded stats |
| `compact_mode` | boolean | `true` | Use compact format with symbols |
| `autocompact_buffer` | number | `33000` | Reserved tokens for compaction buffer |

## Slash Commands

After installation, restart Claude Code to enable these commands:

| Command | Description |
|---------|-------------|
| `/statusline-detailed` | Toggle the detailed display mode |

## How It Works

The statusline script:
1. Receives JSON input from Claude Code with session metadata and context window data
2. Reads token usage, context percentage, and session cost directly from Claude Code's native JSON fields
3. Subtracts the compaction buffer to calculate usable remaining context
4. Resolves repo owner and name from the git remote origin URL
5. Formats the data according to your configuration
6. Returns a single-line status string

### Display Layout

The statusline follows a consistent block order in both normal and detailed modes:

```
[Model] 📁 path | 🔗 owner/repo | 🌿 branch | 🟢 context | 🕐 time | 🪙 tokens | 💲cost
```

Detailed mode adds descriptors to core blocks and appends extra sections at the end without changing block positions.

### Context Tracking

The statusline uses Claude Code's built-in `context_window` JSON data:
- `context_window.used_percentage` — percentage of context window used
- `context_window.context_window_size` — total context window size
- `context_window.total_input_tokens` / `total_output_tokens` — cumulative token counts
- `context_window.current_usage.cache_read_input_tokens` — tokens served from prompt cache
- `context_window.current_usage.cache_creation_input_tokens` — tokens written to prompt cache

The compaction buffer (default 33K) is subtracted from remaining context to show how much usable space you have before autocompaction triggers.

### Performance Features

- **Git Branch Caching**: Caches branch lookup per directory per session
- **Repo Name/Owner Caching**: Caches remote origin parsing per directory per session
- **Session State Persistence**: Maintains session start time across updates
- **Automatic Cleanup**: Removes stale cache files older than 1 day

## Troubleshooting

### Statusline not appearing
- Ensure `~/.claude/settings.json` has `"statusline": { "enabled": true }`
- Check that `~/.claude/statusline.sh` is executable: `chmod +x ~/.claude/statusline.sh`
- Restart Claude Code

### Context showing ⏳
- This means Claude Code hasn't provided context data yet — it appears on the first prompt before any API response

### Git branch not showing
- Ensure you're in a git repository
- Check that git commands work: `git branch --show-current`
- Try clearing the cache: `rm /tmp/.claude_statusline_git_*.cache`

### Repo owner/name not showing
- Ensure the repo has a remote origin: `git remote get-url origin`
- The owner is parsed from the remote URL (supports both SSH and HTTPS formats)

## Requirements

- Claude Code (latest version recommended)
- Bash 4.0 or higher
- `jq` for JSON parsing
- `git` (optional, for git branch and repo display)

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
