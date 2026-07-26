#!/usr/bin/env bash
# loop.sh — the self-paced babysit-prs loop for GitHub Copilot CLI.
#
# Copilot CLI does have a /loop command, but it is only an alias of /every: it
# fires a prompt on a FIXED interval and can't end itself — exactly the cron-job
# shape board/protocol.md argues against. This driver replaces it. It runs ONE
# board pass per iteration with `copilot -p`, then does what the pass tells it
# to through a control line the pass prints as the very last line of its reply:
#
#   LOOP: stop        nothing can move without the owner; the loop exits.
#   LOOP: wait <secs> sleep that long, then run another pass.
#
# The model picks the delay — short while a PR is active, longer once things go
# quiet — and decides when to stop, so pacing and termination stay the model's
# call, the way ScheduleWakeup was under Claude Code's /loop. A fixed interval
# is a cron job that can't end itself; this isn't one.
#
# Run it from the repo root (so git, the forge CLI, and dispatch-worker.sh all
# resolve against the right repo):
#
#   BOARD=~/board ~/board/loop.sh
#
# Environment:
#   BOARD     board directory, read/written each pass (default: ~/board)
#   COPILOT   copilot binary (default: copilot)
#   MODEL     model for the loop session (default: unset — uses your default)
#   MAX_WAIT  cap on a single sleep, in seconds (default: 1800)
#   ONCE      if non-empty, run a single pass and exit (ignore LOOP: wait)
set -euo pipefail

BOARD="${BOARD:-$HOME/board}"
COPILOT="${COPILOT:-copilot}"
MAX_WAIT="${MAX_WAIT:-1800}"

[ -d "$BOARD" ] || { echo "loop.sh: board directory not found: $BOARD" >&2; exit 1; }

# The pass prompt. board/protocol.md and the babysit-prs skill hold the actual
# rules; here we only ask for one pass and the LOOP: control line.
read -r -d '' PROMPT <<'EOF' || true
Use the babysit-prs skill to do exactly one pass of the task board, following
board/protocol.md and board/setup.md. Do not schedule or repeat the pass
yourself. When the pass is finished, print — as the very last line of your
reply — a control line for the loop driver:
  * "LOOP: stop" if the board's stop condition holds (nothing can move without
    the owner), or
  * "LOOP: wait N", where N is seconds to wait before the next pass: short
    while a PR is active, longer once things go quiet.
EOF

run_pass() {
  # --allow-all-tools so a pass never blocks on a tool prompt; path
  # verification stays ON (no --allow-all-paths) so the loop can't wander
  # outside what it's given. --add-dir makes the out-of-repo board writable.
  "$COPILOT" \
    ${MODEL:+--model "$MODEL"} \
    --add-dir "$BOARD" \
    --allow-all-tools \
    --no-ask-user \
    -p "$PROMPT" \
    --silent
}

while :; do
  out="$(run_pass)"
  printf '%s\n' "$out"

  if [ -n "${ONCE:-}" ]; then
    exit 0
  fi

  ctl="$(printf '%s\n' "$out" | grep -E '^LOOP:' | tail -n1 || true)"
  case "$ctl" in
    "LOOP: stop")
      echo "loop.sh: the board says nothing can move without you; stopping." >&2
      exit 0
      ;;
    "LOOP: wait "*)
      secs="${ctl#LOOP: wait }"
      case "$secs" in *[!0-9]*|'') secs=300 ;; esac
      [ "$secs" -gt "$MAX_WAIT" ] && secs="$MAX_WAIT"
      echo "loop.sh: sleeping ${secs}s before the next pass." >&2
      sleep "$secs"
      ;;
    *)
      echo "loop.sh: no LOOP: line from the pass; waiting 300s and retrying." >&2
      sleep 300
      ;;
  esac
done
