---
name: babysit-prs
description: Use when working the task board for one pass, normally from inside a self-paced /loop, or when checking whether anything on the board can move without the owner.
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

- Dispatch every piece of code work to the `task-worker` subagent. You read the board, run the forge
  CLI, and write frontmatter. You do not edit code, and you do not touch the repository working tree.
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
