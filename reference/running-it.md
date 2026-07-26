# Running it

## Starting

From the repo root, with the board reachable by the session. The loop is a small driver that runs one
board pass at a time and paces itself:

```bash
BOARD=~/board ~/board/loop.sh
```

`loop.sh` runs each pass as `copilot -p`, reads the `LOOP:` line the pass ends on, and either sleeps
for the interval the pass chose or exits when the board says nothing can move without you. It passes
`--add-dir "$BOARD"` for you, so the board outside the repo is readable and writable.

To make board access permanent instead of per-run, add its absolute path to `allowed_directories` in
`~/.copilot/permissions-config.json`. `~` may not expand there, so use the full path.

Knobs, all optional:

| Variable | Default | |
|---|---|---|
| `BOARD` | `~/board` | the board directory |
| `MODEL` | your default | model for the loop session |
| `MAX_WAIT` | `1800` | cap on a single self-chosen sleep, in seconds |
| `ONCE` | unset | run a single pass and exit, ignoring `LOOP: wait` |

**Why a script and not `/loop`.** Copilot's `/loop` is an alias of `/every`: it fires a prompt on a
fixed interval and can't end itself, which is the cron-job shape this system is built to avoid. The
driver keeps pacing and stopping in the model's hands — short delays while a PR is active, long ones
when the board is quiet, and a clean exit when nothing can move. The native command still works if you
want it — give `/every` an interval and a prompt that runs the `babysit-prs` skill — but you own
stopping it and it keeps firing on an empty board.

**Watch the first pass** rather than backgrounding it. The review gate is the part most likely to be
subtly wrong, and the first pass is where that shows. `ONCE=1 ~/board/loop.sh` runs exactly one pass so
you can read it before letting the loop run on its own. To hand a running loop off to the background,
press `Ctrl+X` then `b`.

## Watching

The board is the truth, so the fastest read is the board itself — the loop prints what moved at the end
of every pass, and the notes carry the rest:

```bash
grep -rl 'status: Needs Input' ~/board/tasks      # anything waiting on you
grep -rl 'status: Agent Finished' ~/board/tasks   # PRs the loop is watching
```

To watch or steer a running session from your phone or another machine, turn on remote control and open
it from GitHub.com or GitHub Mobile:

```
/remote on
```

The repo has to be hosted on GitHub for this. `--remote-export` is the read-only version if you only
want to see progress, not send input. Inside a session, `/usage` shows the live token count and
`/context` how full the window is.

## Stopping

`loop.sh` is an ordinary shell loop around `copilot`, so you stop the *loop* by stopping the script and
a *pass in flight* the way you stop any Copilot session.

| | |
|---|---|
| `Ctrl+C` in the `loop.sh` terminal | ends the loop; the current pass finishes or dies with it |
| `Esc`, or `Ctrl+C` twice, inside a pass | interrupts the pass that's running |
| `Ctrl+D` or `/exit` | ends a session you're attached to |
| reaching `LOOP: stop` | the loop exits on its own once nothing can move without you |

Leftover worktrees from a pass you killed are cleaned with git, not by deleting files by hand:

```bash
git worktree list
git worktree remove --force .copilot/worktrees/<name>
git worktree prune
```

`dispatch-worker.sh` removes a worktree when its worker finishes on its own, so this is only for passes
you interrupted.

## Daily use

Set `status: Testing` on something before you start testing it. That makes it immune to the combine
rule and to everything else, so you can work through the queue without the loop reshuffling what you
haven't reached yet.

Then `Ready to Merge` if it's good, or `Needs Changes` with a `Changes requested:` block in the body
if it isn't. Those two and `Testing` are the only statuses you set.

## Getting told when you're needed

The board is the source of truth: a blocked task gets `status: Needs Input` and a `question`, and
answering means filling in the `answer` cell. That works with nothing else set up and it can't
silently fail. Anything below is a nudge on top of it.

Two nudges fit Copilot without extra services:

- **Remote control.** With `/remote on`, a running session surfaces on GitHub.com and GitHub Mobile,
  and it's two-way — a pass that pauses for input can be answered from your phone, so the nudge and the
  reply are the same channel. Because that channel puts text in front of a session authorized to push
  code and merge PRs, keep it to your own account and a repo only you can reach.
- **A hook that calls out.** Copilot runs hooks on session events. A `notification` or `agentStop`
  hook that curls a webhook you own — your own chat, an ntfy topic, an incoming webhook URL — turns
  "the loop paused" into a push on your phone. Hooks live in `~/.copilot/hooks/*.json`,
  `.github/hooks/*.json`, or the `hooks` block of settings; a `command`-type hook is the simplest.

Then add a line to `babysit-prs/SKILL.md`: after any pass that sets a task to `Needs Input`, send the
question through whichever nudge you set up.

Whichever you choose, the board still holds the question, so nothing is lost if the nudge doesn't reach
you or the session is down when you reply. That's why the board is the source of truth and the nudge is
only ever a nudge.

## Things that will bite

**A stopped loop doesn't watch the board.** If it exited on `LOOP: stop` because everything was at
`Needs Input` and you answer by filling in `answer`, nothing happens until you start `loop.sh` again.
Remote control avoids this, since the session is still alive and the reply arrives while it's paused.

**A pass only runs when the driver runs it.** `loop.sh` sleeps between passes, so a note you change
during that sleep isn't seen until the next pass wakes. Lower `MAX_WAIT` for a tighter ceiling on that
gap, or run a one-off `ONCE=1 ~/board/loop.sh` when you want a pass right now.

**`/loop` is `/every`, and `/every` is experimental.** If you reach for the native command instead of
the driver, it fires on a fixed interval, keeps going on an empty board, and can change under you. The
driver exists precisely so the loop doesn't depend on that.

**Each pass is a real turn against your usage.** Three workers doing real work adds up faster than it
looks. Self-pacing helps by stretching the gaps when the board is quiet; watch the first day with
`/usage` for the live session and `/chronicle cost tips` for the trend.

**A worktree can be cut from a stale base.** `origin/HEAD` is only as fresh as your last fetch.
`dispatch-worker.sh` fetches before it branches, and running `git remote set-head origin -a` once at
setup keeps the default-branch pointer honest; still expect the occasional branch that doesn't yet
contain a PR that merged seconds ago.
