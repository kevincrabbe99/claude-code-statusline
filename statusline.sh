#!/bin/bash
#
# Claude Code status line - icon-rich single line, all available fields.
# Every field is looked up with a `// empty` fallback in jq, so anything
# missing from the JSON payload is simply omitted (never prints "null").
#

input=$(cat)

j() { printf '%s' "$input" | jq -r "$1" 2>/dev/null; }

# --- Extract fields from JSON input ---
cwd=$(j '.workspace.current_dir // .cwd // empty')
session_id=$(j '.session_id // empty')
model=$(j '.model.display_name // empty')
output_style=$(j '.output_style.name // empty')
used_pct=$(j '.context_window.used_percentage // empty')
remaining_pct=$(j '.context_window.remaining_percentage // empty')
exceeds_200k=$(j '.exceeds_200k_tokens // empty')
cost_usd=$(j '.cost.total_cost_usd // empty')
duration_ms=$(j '.cost.total_duration_ms // empty')
lines_added=$(j '.cost.total_lines_added // empty')
lines_removed=$(j '.cost.total_lines_removed // empty')
version=$(j '.version // empty')

[ -z "$cwd" ] && cwd="$PWD"

# --- Colors (ANSI escapes; terminal renders these dimmed) ---
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
# Muted / desaturated 256-color palette so the line stays quiet.
BLUE='\033[38;5;103m'
CYAN='\033[38;5;66m'
GREEN='\033[38;5;65m'     # gray-green
YELLOW='\033[38;5;137m'   # gray-gold
RED='\033[38;5;138m'      # gray-rose
MAGENTA='\033[38;5;103m'  # gray-purple
GRAY='\033[90m'

SEP=" ${GRAY}│${RESET} "

# --- OSC 8 hyperlinks (⌘-click in iTerm opens them) ---
# A link is: ${OSC8_A}${url}${OSC8_B}${visible-text}${OSC8_C}
OSC8_A='\033]8;;'
OSC8_B='\033\\'
OSC8_C='\033]8;;\033\\'

# URL-encode just the characters that break file:// URLs (spaces, etc.)
urlencode() {
  local s="$1" out="" c
  for (( i=0; i<${#s}; i++ )); do
    c="${s:$i:1}"
    case "$c" in
      [a-zA-Z0-9/._~-]) out+="$c" ;;
      *) out+=$(printf '%%%02X' "'$c") ;;
    esac
  done
  printf '%s' "$out"
}

# --- 1. Directory: anchor to repo root when inside a git repo, else last 3 segments ---
# Worktree detection: inside a linked worktree, --show-toplevel points at the
# worktree dir (e.g. racing-web/.claude/worktrees/tracks-results-list), which
# makes the worktree name masquerade as the repo. We compare --git-dir against
# --git-common-dir: they differ only in a linked worktree, and --git-common-dir
# always points at the *real* repo's .git — so its parent is the true repo root.
repo_root=""
worktree_name=""       # non-empty only when in a linked worktree
real_repo_name=""      # the actual repo, recovered via --git-common-dir
if [ -n "$cwd" ] && command -v git >/dev/null 2>&1; then
  repo_root=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)
  if [ -n "$repo_root" ]; then
    git_dir=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" rev-parse --git-dir 2>/dev/null || true)
    common_dir=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" rev-parse --git-common-dir 2>/dev/null || true)
    # Resolve both to absolute paths for a reliable comparison.
    [ -n "$git_dir" ] && git_dir=$(cd "$cwd" 2>/dev/null && cd "$git_dir" 2>/dev/null && pwd)
    [ -n "$common_dir" ] && common_dir=$(cd "$cwd" 2>/dev/null && cd "$common_dir" 2>/dev/null && pwd)
    if [ -n "$common_dir" ] && [ "$git_dir" != "$common_dir" ]; then
      # Linked worktree. --git-dir looks like <repo>/.git/worktrees/<name>.
      worktree_name="${git_dir##*/}"
      # Real repo root = parent of the common .git dir.
      real_repo_root="${common_dir%/.git}"
      real_repo_name="${real_repo_root##*/}"
    fi
  fi
fi

if [ -n "$repo_root" ]; then
  # Inside a repo: always keep <repo-name>, then the first sub-dir, "...",
  # and the last two segments — e.g. racing-web/.claude/.../mfa-helper/scripts
  # In a linked worktree, anchor to the *real* repo name (recovered above),
  # not the worktree dir name — the worktree is surfaced separately as a badge.
  if [ -n "$worktree_name" ]; then
    repo_name="$real_repo_name"
  else
    repo_name="${repo_root##*/}"
  fi
  rel="${cwd#$repo_root}"
  rel="${rel#/}"
  if [ -z "$rel" ]; then
    short_dir="$repo_name"
  else
    IFS='/' read -ra rparts <<< "$rel"
    rsegs=()
    for p in "${rparts[@]}"; do
      [ -n "$p" ] && rsegs+=("$p")
    done
    rn=${#rsegs[@]}
    if [ "$rn" -le 3 ]; then
      short_dir="$repo_name/$rel"
    else
      last2="${rsegs[$((rn-2))]}/${rsegs[$((rn-1))]}"
      short_dir="$repo_name/${rsegs[0]}/.../$last2"
    fi
  fi
else
  # Not in a repo: shorten to last 3 path segments, ~ for home
  if [ "$cwd" = "$HOME" ]; then
    tilde_dir="~"
  elif [[ "$cwd" == "$HOME"/* ]]; then
    tilde_dir="~${cwd#$HOME}"
  else
    tilde_dir="$cwd"
  fi

  IFS='/' read -ra parts <<< "$tilde_dir"
  segments=()
  for p in "${parts[@]}"; do
    [ -n "$p" ] && segments+=("$p")
  done

  count=${#segments[@]}
  if [ "$count" -gt 3 ]; then
    keep=("${segments[@]: -3}")
  else
    keep=("${segments[@]}")
  fi

  short_dir=""
  for seg in "${keep[@]}"; do
    if [ -z "$short_dir" ]; then
      short_dir="$seg"
    else
      short_dir="$short_dir/$seg"
    fi
  done
  [ -z "$short_dir" ] && short_dir="~"
fi

# --- 2. Git branch: hide outside a repo, yellow when dirty, detached@<sha> ---
git_branch=""
branch_color="$GREEN"
branch_url=""
if [ -n "$cwd" ] && command -v git >/dev/null 2>&1 \
  && GIT_OPTIONAL_LOCKS=0 git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git_branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
  is_detached=""
  if [ "$git_branch" = "HEAD" ]; then
    short_sha=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" rev-parse --short HEAD 2>/dev/null || true)
    git_branch="detached@${short_sha}"
    is_detached="1"
  fi
  if [ -n "$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" status --porcelain 2>/dev/null)" ]; then
    branch_color="$YELLOW"
  fi

  # Build a GitHub compare URL (diff vs the default branch) for the branch name.
  if [ -z "$is_detached" ]; then
    remote_url=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" remote get-url origin 2>/dev/null || true)
    web=""
    case "$remote_url" in
      git@github.com:*)      web="https://github.com/${remote_url#git@github.com:}" ;;
      ssh://git@github.com/*) web="https://github.com/${remote_url#ssh://git@github.com/}" ;;
      https://github.com/*)  web="$remote_url" ;;
    esac
    web="${web%.git}"
    [ -n "$web" ] && branch_url="${web}/compare/${git_branch}"
  fi
fi

# --- 5. Context window usage, colored by severity ---
ctx_str=""
pct_int=""
if [ -n "$used_pct" ]; then
  pct_int=$(printf '%.0f' "$used_pct" 2>/dev/null || echo "")
elif [ -n "$remaining_pct" ]; then
  pct_int=$(awk -v r="$remaining_pct" 'BEGIN{printf "%.0f", 100-r}' 2>/dev/null || echo "")
fi

if [ -n "$pct_int" ]; then
  if [ "$pct_int" -ge 85 ]; then
    ctx_color="$RED"
  elif [ "$pct_int" -ge 60 ]; then
    ctx_color="$YELLOW"
  else
    ctx_color="$GREEN"
  fi
  ctx_str="${ctx_color}⚡ ${pct_int}% used${RESET}"
  if [ "$exceeds_200k" = "true" ]; then
    ctx_str="${ctx_str} ${RED}${BOLD}⚠200k+${RESET}"
  fi
fi

# --- 6. Session cost, formatted as $0.87 ---
cost_str=""
if [ -n "$cost_usd" ]; then
  cost_fmt=$(printf '$%.2f' "$cost_usd" 2>/dev/null || echo "")
  [ -n "$cost_fmt" ] && cost_str="${GRAY}💰 ${cost_fmt}${RESET}"
fi

# --- 7. Duration, human string (e.g. 45s, 12m, 1h3m) ---
duration_str=""
if [ -n "$duration_ms" ]; then
  duration_fmt=$(awk -v ms="$duration_ms" 'BEGIN{
    s=int(ms/1000);
    h=int(s/3600);
    m=int((s%3600)/60);
    if (s<60) printf "%ds", s;
    else if (h>0) printf "%dh%dm", h, m;
    else printf "%dm", m;
  }' 2>/dev/null || echo "")
  [ -n "$duration_fmt" ] && duration_str="${GRAY}⏱ ${duration_fmt}${RESET}"
fi

# --- 8. Lines added / removed ---
lines_str=""
if [ -n "$lines_added" ]; then
  lines_str="${GREEN}+${lines_added}${RESET}"
fi
if [ -n "$lines_removed" ]; then
  [ -n "$lines_str" ] && lines_str="${lines_str} "
  lines_str="${lines_str}${RED}-${lines_removed}${RESET}"
fi

# --- Assemble the status line, skipping any empty segment ---
segs=()
# Directory, branch, and diff share one segment (no dividers between them):
#   📁 <dir> (<branch>)  +X -Y
# Directory text links to the real cwd via file:// (opens in Finder).
dir_link="${short_dir}"
if [ -n "$cwd" ]; then
  file_url="file://$(urlencode "$cwd")"
  dir_link="${OSC8_A}${file_url}${OSC8_B}${short_dir}${OSC8_C}"
fi
dir_seg="${GRAY}📁 ${dir_link}${RESET}"

# Worktree badge: only shown inside a linked worktree. Sits between the real
# repo name and the branch, so the line reads:  📁 racing-web ⑂ <wt> (<branch>)
if [ -n "$worktree_name" ]; then
  dir_seg="${dir_seg} ${YELLOW}⑂ ${worktree_name}${RESET}"
fi

# Branch text links to the GitHub compare/diff view (when we resolved a URL).
if [ -n "$git_branch" ]; then
  branch_txt="$git_branch"
  [ -n "$branch_url" ] && branch_txt="${OSC8_A}${branch_url}${OSC8_B}${git_branch}${OSC8_C}"
  dir_seg="${dir_seg} ${GRAY}(${RESET}${branch_color}${branch_txt}${RESET}${GRAY})${RESET}"
fi
[ -n "$lines_str" ] && dir_seg="${dir_seg} ${lines_str}"
segs+=("$dir_seg")
[ -n "$model" ] && segs+=("${MAGENTA}🤖 ${model}${RESET}")
[ -n "$ctx_str" ] && segs+=("$ctx_str")
[ -n "$cost_str" ] && segs+=("$cost_str")
[ -n "$duration_str" ] && segs+=("$duration_str")

# --- Fork command: ready-to-paste command to fork this conversation into a
# new terminal. Claude Code has no interactive/clickable status line, so we
# just surface the exact command (with the live session id) to copy-paste.
# `cfork` is a shell function (see ~/.zshrc): cfork() { claude -r "$1" --fork-session; }
if [ -n "$session_id" ]; then
  segs+=("${GRAY}⑂ cfork ${session_id}${RESET}")
fi

line=""
for s in "${segs[@]}"; do
  if [ -z "$line" ]; then
    line="$s"
  else
    line="${line}${SEP}${s}"
  fi
done

printf "%b\n" "$line"
