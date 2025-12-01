Toggle the statusline between Claude Pro (200K context) and Claude Max (100K context) subscription modes.

Check the current value of `context_limit` in `~/.claude/statusline.config.json`:
- If it's 200000, switch to 100000 (Max subscription)
- If it's 100000, switch to 200000 (Pro subscription)

Also adjust the `autocompact_buffer` proportionally:
- Pro (200K): autocompact_buffer = 45000 (22.5%)
- Max (100K): autocompact_buffer = 22500 (22.5%)

After toggling, tell the user which subscription mode is now active and what the new context limit is.
