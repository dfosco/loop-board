#!/usr/bin/env bash
# dispatch-worker.sh — run one task-worker in an isolated git worktree.
#
# Claude Code gave each task its own checkout through the `isolation: worktree`
# line in the worker's frontmatter. GitHub Copilot CLI has no such thing: a
# subagent shares the main session's working directory, so it can't be handed a
# private tree that way. This script rebuilds that guarantee out of plain git
# worktrees plus a separate, path-scoped `copilot` process:
#
#   * The worktree is branched from origin/HEAD, never from local HEAD, so the
#     owner's in-progress checkout never leaks into a task and a task's edits
#     never appear in the owner's tree.
#   * The worker runs with its working directory INSIDE the worktree and WITHOUT
#     --allow-all-paths, so Copilot's path verification refuses any file outside
#     it. A file that resolves into the main checkout is denied rather than
#     written — the whole "never touch my checkout" guarantee. For hard
#     shell-level isolation too, set WORKER_EXTRA_FLAGS="--experimental --sandbox".
#   * Gitignored files a fresh checkout needs (.env and friends) are copied in
#     from .worktreeinclude, because a worktree is a clean checkout and neither
#     git nor Copilot's own --worktree carries untracked files across.
#
# It prints the worker's RESULT: block on stdout for the loop to read, and
# removes the worktree afterwards unless --keep is given. A changes-requested or
# conflict round reuses the existing branch with --reuse --keep.
#
# Usage:
#   dispatch-worker.sh --branch NAME --dispatch-file PATH [--base origin/HEAD]
#                      [--reuse] [--keep]
#
# Environment:
#   REPO               repo root (default: current directory)
#   AGENT              custom agent name (default: task-worker)
#   COPILOT            copilot binary (default: copilot)
#   MODEL              model for the worker (default: unset — inherits the default)
#   INSTALL            command run inside the worktree before the worker starts
#   WORKTREES          where worktrees live (default: $REPO/.copilot/worktrees)
#   WORKER_EXTRA_FLAGS extra flags passed to the worker copilot process
set -euo pipefail

REPO="${REPO:-$(pwd)}"
AGENT="${AGENT:-task-worker}"
COPILOT="${COPILOT:-copilot}"
WORKTREES="${WORKTREES:-$REPO/.copilot/worktrees}"

branch=""
dispatch_file=""
base="origin/HEAD"
reuse=""
keep=""
while [ $# -gt 0 ]; do
  case "$1" in
    --branch)        branch="${2:-}"; shift 2 ;;
    --dispatch-file) dispatch_file="${2:-}"; shift 2 ;;
    --base)          base="${2:-}"; shift 2 ;;
    --reuse)         reuse=1; shift ;;
    --keep)          keep=1; shift ;;
    *) echo "dispatch-worker.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -n "$branch" ] || { echo "dispatch-worker.sh: --branch is required" >&2; exit 2; }
[ -n "$dispatch_file" ] || { echo "dispatch-worker.sh: --dispatch-file is required" >&2; exit 2; }
[ -e "$dispatch_file" ] || { echo "dispatch-worker.sh: --dispatch-file not found: $dispatch_file" >&2; exit 2; }
[ -f "$dispatch_file" ] || { echo "dispatch-worker.sh: --dispatch-file is not a regular file: $dispatch_file" >&2; exit 2; }
[ -r "$dispatch_file" ] || { echo "dispatch-worker.sh: --dispatch-file is not readable: $dispatch_file" >&2; exit 2; }
git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "dispatch-worker.sh: not a git repository: $REPO" >&2; exit 2; }

# Refresh the base so a worktree isn't cut from a stale origin/HEAD.
git -C "$REPO" fetch --quiet origin || true

slug="$(printf '%s' "$branch" | tr '/ ' '__')"
wt="$WORKTREES/$slug"
mkdir -p "$WORKTREES"

if [ -n "$reuse" ]; then
  # Changes-requested / conflict round: pick up the existing branch.
  # git's setup chatter goes to stderr so stdout carries only the worker's block.
  [ -d "$wt" ] || git -C "$REPO" worktree add "$wt" "$branch" 1>&2
else
  # New work: a fresh branch off the real default branch.
  git -C "$REPO" worktree add -b "$branch" "$wt" "$base" 1>&2
fi

# Copy gitignored files a fresh checkout needs, per .worktreeinclude
# (.gitignore syntax). Only files that are both ignored and untracked match.
if [ -r "$REPO/.worktreeinclude" ]; then
  while IFS= read -r pat; do
    case "$pat" in ''|'#'*) continue ;; esac
    git -C "$REPO" ls-files -o -i --exclude-standard -- "$pat" 2>/dev/null | while IFS= read -r f; do
      [ -e "$REPO/$f" ] || continue
      mkdir -p "$wt/$(dirname "$f")"
      cp -p "$REPO/$f" "$wt/$f"
    done
  done < "$REPO/.worktreeinclude"
fi

# Optional install so the worktree is buildable before the worker looks at it.
# Its output goes to stderr, keeping stdout for the worker's block alone.
if [ -n "${INSTALL:-}" ]; then
  ( cd "$wt" && eval "$INSTALL" ) 1>&2 || true
fi

# Run the worker as a separate, path-scoped Copilot session. Working directory
# is the worktree; no --allow-all-paths, so file access outside it is refused.
prompt="$(cat "$dispatch_file")"
status=0
( cd "$wt" && "$COPILOT" --agent "$AGENT" ${MODEL:+--model "$MODEL"} \
    --allow-all-tools --no-ask-user ${WORKER_EXTRA_FLAGS:-} \
    -p "$prompt" --silent ) || status=$?

# Tear down unless asked to keep the tree for a follow-up round. The branch
# survives either way, so a reuse round can check it out again.
if [ -z "$keep" ]; then
  git -C "$REPO" worktree remove --force "$wt" 2>/dev/null || true
fi

exit "$status"
