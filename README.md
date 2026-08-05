# claude-code-statusline

An icon-rich, single-line status line for [Claude Code](https://claude.com/claude-code).

It renders everything Claude Code exposes on stdin into one quiet, muted line:

```
📁 racing-web/.claude/.../mfa-helper/scripts (feature-branch) +42 -7 │ 🤖 Opus │ ⚡ 34% used │ 💰 $0.87 │ ⏱ 12m
```

## Features

- **Directory** — anchored to the repo root when you're inside a git repo (`repo/first/.../last2`),
  otherwise the last three path segments with `~` for home.
- **Git branch** — hidden outside a repo, turns amber when the working tree is dirty, shows
  `detached@<sha>` when detached.
- **Diff stats** — `+lines / -lines` for the session.
- **Model**, **context-window usage** (green → amber → red by severity, with a `⚠200k+` flag),
  **session cost**, and **duration**.
- **OSC 8 hyperlinks** — ⌘-click the directory to open it in Finder; ⌘-click the branch to open
  the GitHub compare view (works in iTerm2 and other OSC 8-capable terminals).
- **Graceful fallbacks** — every field is looked up with a `// empty` jq fallback, so anything
  missing from the payload is simply omitted (it never prints `null`).

## Dependencies

- `bash`
- `jq`
- `git`
- `awk`
- A 256-color terminal (for the muted palette). OSC 8 hyperlinks require an OSC 8-capable terminal.

## Install

```bash
cp statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

Then add the following to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  }
}
```

Start a new Claude Code session (or reload) and the status line appears at the bottom.

## Customizing

The palette is defined near the top of `statusline.sh` as ANSI 256-color escapes
(`BLUE`, `CYAN`, `GREEN`, …). Adjust those to retint the line. Segments are assembled at the
bottom of the script — reorder or drop any you don't want.
