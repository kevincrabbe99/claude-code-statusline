# claude-code-statusline

An icon-rich, single-line status line for [Claude Code](https://claude.com/claude-code).

It renders everything Claude Code exposes on stdin into one quiet, muted line:

```
📁 racing-web/.claude/.../mfa-helper/scripts (feature-branch) +42 -7 │ 🤖 Opus │ ⚡ 34% used │ 💰 $0.87 │ ⏱ 12m │ ⑂ cfork a1b2c3d4-…
```

In a git worktree it anchors to the *real* repo, badges the worktree name, and shows the branch:

```
📁 racing-web ⑂ tracks-results-list (spec/tracks-results-list) │ 🤖 Opus │ ⚡ 34% used │ …
```

## Features

- **Directory** — anchored to the repo root when you're inside a git repo (`repo/first/.../last2`),
  otherwise the last three path segments with `~` for home.
- **Worktree aware** — inside a linked git worktree (e.g. `claude --worktree <name>`), the directory
  still anchors to the *real* repo name (not the worktree dir, which normally masquerades as the repo),
  and the worktree name is surfaced as a separate `⑂ <name>` badge. Detected by comparing `git rev-parse
  --git-dir` against `--git-common-dir`, which differ only inside a linked worktree.
- **Git branch** — hidden outside a repo, turns amber when the working tree is dirty, shows
  `detached@<sha>` when detached.
- **Diff stats** — `+lines / -lines` for the session.
- **Model**, **context-window usage** (green → amber → red by severity, with a `⚠200k+` flag),
  **session cost**, and **duration**.
- **Fork shortcut** — surfaces `⑂ cfork <session-id>` with the live session id, a ready-to-paste
  command for forking the current conversation into a new, independent session (see below).
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

## Fork shortcut (`cfork`)

The last segment shows `⑂ cfork <session-id>` using the live session id from the payload.
Claude Code's status line is display-only — it can't be a clickable button — so this is a
ready-to-paste command for **forking the current conversation into a new, independent session**
that inherits its context (leaving the original untouched).

The segment relies on a small shell function. Install it by sourcing `cfork.sh` from your shell
config, or paste the function in directly:

```bash
echo 'source ~/repos/claude-code-statusline/cfork.sh' >> ~/.zshrc   # or ~/.bashrc
source ~/.zshrc
```

Then, in a new terminal:

```bash
cfork <session-id>   # fork a specific session — copy the id from the status line
cfork                # fork the most recent session in the current directory
```

Under the hood `cfork` runs `claude -r <id> --fork-session` (or `claude -c --fork-session` with no
argument). `--fork-session` copies the history into a fresh session id instead of continuing the
original, so the two conversations diverge cleanly. Run the no-argument form from the same project
directory as the conversation you want to branch.

If you don't want the segment, delete the `session_id` line and the fork block at the bottom of
`statusline.sh`.

## Customizing

The palette is defined near the top of `statusline.sh` as ANSI 256-color escapes
(`BLUE`, `CYAN`, `GREEN`, …). Adjust those to retint the line. Segments are assembled at the
bottom of the script — reorder or drop any you don't want.
