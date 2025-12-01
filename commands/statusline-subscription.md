Toggle the statusline between Claude Max 5x (200K context) and Claude Max 20x (100K context) subscription modes.

Check the current value of `context_limit` in `~/.claude/statusline.config.json`:
- If it's 200000, switch to 100000 (Max 20x subscription)
- If it's 100000, switch to 200000 (Max 5x subscription)

Also adjust the `autocompact_buffer` proportionally:
- Max 5x (200K): autocompact_buffer = 45000 (22.5%)
- Max 20x (100K): autocompact_buffer = 22500 (22.5%)

After toggling, tell the user which subscription mode is now active and what the new context limit is.
