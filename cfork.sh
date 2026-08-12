# --- Claude Code ---
# Fork a conversation into a new independent session that inherits its context.
# Pairs with the `⑂ cfork <id>` segment in statusline.sh.
#
#   cfork <session-id>   fork a specific session (the status line shows the id)
#   cfork                fork the most recent session in the current directory
#
# Source this from your ~/.zshrc or ~/.bashrc, or paste the function into it.
cfork() {
  if [ -n "$1" ]; then
    claude -r "$1" --fork-session
  else
    claude -c --fork-session
  fi
}
