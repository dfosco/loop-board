---
name: babysit-prs
description: Use when working the task board for one pass, normally from inside the self-paced loop (`board/loop.sh`), or when checking whether anything on the board can move without the owner.
---

Do one pass of the board.

The rules are in `<board>/protocol.md`. Read it every pass; it changes.
What varies per person and per repo is `<board>/setup.md`. Read it every pass too.
The board is the notes in `<board>/tasks/`, one note per task, `status` in frontmatter.
What the process has learned is `<board>/memory.md`. Read it every pass.

Follow the protocol exactly, including the pass order and the stop condition. Where the protocol and
this file disagree, the protocol wins.

Read every note's frontmatter. Open the body only for notes you're going to act on — `Done` and
`Backlog` are skipped entirely, and they will outnumber everything else within a couple of weeks.

Three things the protocol relies on that are yours to enforce:

- Dispatch every piece of code work to a `task-worker`, by running `<board>/dispatch-worker.sh`. It
  cuts the isolated worktree, runs the worker in it, copies in the `.worktreeinclude` files, and hands
  back the worker's `RESULT:` block on stdout. You read the board, run the forge CLI, and write
  frontmatter. You do not edit code yourself, and you do not touch the repository working tree.
- You are the only writer to the board and to `memory.md`. Workers report back to you and you record
  it. Never ask a worker to write a task note or a memory entry.
- Every dispatch opens with a `## Memory` block: `## Preferences`, `## Patterns to avoid`, and the
  `## Codebase` entries tagged for that repo. Not the other repos' entries, and not `## Retired`.
  Include the project commands from `setup.md` in the dispatch too — a worker can't run checks it
  hasn't been told about.

Each `task-worker` returns a `RESULT:` block. Map it:

- `RESULT: pr` — record `pr` and `files_changed`, set `status: Agent Finished`, set `status_since`
- `RESULT: question` — copy `NOTE` verbatim into `question`, set `status: Needs Input`, set
  `status_since`
- `RESULT: blocked` — leave the status alone, say what's blocked in one line, move on
- `MEMORY:` — hold the lines for step 7. Don't write them as they arrive; the thresholds, the caps,
  and the graduation rule all need the whole pass in front of you.

At step 7, update `memory.md` by the rules under Memory in the protocol, from the four sources the
pass already read: worker `MEMORY:` lines, the newest changes-requested blocks, review findings, and
any `answer` that got filled in. Merge before adding, evict only when a section is at its cap, and
skip anything below its threshold. Check each section against its cap before and after. A pass that
records nothing is the normal case.

Finish the pass with one line: what moved, and what you're waiting on. Add a second line only if
memory changed, saying what you learned, dropped, or graduated.

Then, as the very last line of your reply, print the loop driver's control line — the protocol's
"When to stop" section says which:

- `LOOP: stop` when the stop condition holds and nothing can move without the owner.
- `LOOP: wait <seconds>` otherwise, choosing the delay by how live the board is: short while a PR is
  active, longer once things go quiet.

`board/loop.sh` reads that line to decide whether to sleep and run again or exit. When you're running
this skill by hand for a single pass, the line is harmless — just report the pass.
