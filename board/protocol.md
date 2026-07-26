# Board protocol

The rules the loop follows. Read this every pass; it changes.

Throughout, **I** means the person who owns this board, and **you** means the loop reading it.
Anything that varies between people or repos lives in `setup.md` next to this file, and this document
points at it rather than guessing. Read `setup.md` every pass too.

One note per task, in `tasks/`. The `status` property is the board. Any view over it — an Obsidian
base, a script, nothing at all — is just a view, so nothing here depends on a particular tool being
open.

Read every note's frontmatter each pass. Open the body only for notes you're going to act on:
`Done` and `Backlog` notes are skipped entirely, and a board accumulates far more of those than
anything else.

## What you may write

Frontmatter, and one section of the body. Nothing else.

- Yours to set: `status`, `pr`, `files_changed`, `question`, `status_since`, `done_date`
- Mine alone: `status` when it's `Testing`, `Needs Changes`, or `Ready to Merge`; `answer`; `order`;
  the note title; the body above `## Review notes`
- Derived, never written by anyone: how recently a task changed. Compute it from `file.mtime`. Don't
  add an `updated` property. A written one is wrong the moment anything touches the file without
  going through you.

`memory.md` is the exception to all of this. It's a file next to this one rather than a note, it's
yours to write and mine to edit, and its rules are under Memory.

Edit frontmatter surgically, one key at a time. Never rewrite a note wholesale. The body is my prose
and it is not yours to tidy.

`status_since` is `YYYY-MM-DD HH:mm`, and you set it only when `status` actually changes. It answers
"how long has this been sitting here", which `file.mtime` can't: a new PR comment touches nothing
about the status but moves mtime.

## Statuses

| Status         | Meaning                                      | Who sets it | What the loop does                                                    |
| -------------- | -------------------------------------------- | ----------- | --------------------------------------------------------------------- |
| Backlog        | Future work                                  | me          | Nothing. Skipped entirely.                                            |
| To Do          | Up next                                      | me          | Promotes the lowest `order` when there's a free slot.                 |
| In Progress    | A worker is on it in its own worktree        | loop        | Works the task, opens a PR, records `pr`.                             |
| Needs Input    | Blocked on a question only I can answer      | loop        | Nothing until `answer` is filled in.                                  |
| Agent Finished | Work pushed, not yet clean                   | loop        | Drives checks green and iterates on review feedback.                  |
| Ready to Test  | Green and unblocked                          | loop        | Nothing, except combining. Waiting on me.                             |
| Testing        | I'm testing it right now                     | **me**      | Nothing at all. Hands off entirely.                                   |
| Needs Changes  | I tested it and want changes                 | **me**      | Reads the newest changes-requested block, sends it back to In Progress. |
| Ready to Merge | I tested it and want it in                   | **me**      | Re-verifies, then merges.                                             |
| Done           | All PRs merged                               | loop        | Sets `done_date`.                                                     |

If `setup.md` says I don't test manually, `Ready to Test` and `Testing` collapse into one waiting
state and `Ready to Merge` is set by you rather than by me. Everything else is unchanged.

`order` is an integer, ascending, and lower always means sooner. It decides which To Do note gets
promoted first and which `Ready to Merge` note gets merged first. It's mine to set.

## Each pass, in this order

1. Merge the `Ready to Merge` notes, lowest `order` first.
2. Restart the `Needs Input` notes that have an `answer`.
3. Pick up the `Needs Changes` notes.
4. Work the `Agent Finished` notes.
5. Combine small `Ready to Test` notes.
6. Promote from To Do.
7. Record what the pass learned.
8. Check the stop condition.

Merges go first because they change what every later step sees: landing one PR can put another
behind or into conflict, so doing them first means the rest of the pass reads the new base rather
than a stale one. Finishing beats starting, which is why `Needs Changes` takes a free slot before
To Do does. Recording comes last of the work steps because it records what the pass did, and a pass
that hasn't happened yet has taught nobody anything.

## Rules

The WIP limit is in `setup.md`, and it counts only notes at `In Progress`. Nothing else occupies a
slot, since no worker is actively on those. Separately, if that many notes are already at
`Needs Input`, stop promoting from To Do. Nothing new starts while a pile of questions is waiting,
or I come back to a wall of them.

## Worktree rules

The main checkout is mine. It is where I test and decide what I want changed next. Nothing in this
process writes to it.

- Every task runs in its own worker, and every worker gets its own temporary git worktree. The loop
  dispatches through `<board>/dispatch-worker.sh`, which cuts the worktree, runs the worker confined
  to it, and removes it when the worker finishes without changes.
- The worker is confined to its worktree: it runs as its own session scoped to that directory, so a
  command that resolves into my checkout is refused rather than run. That confinement is the guarantee
  the whole process rests on.
- Worktrees branch from `origin/HEAD`, not from whatever branch I have checked out. My in-progress
  local state never leaks into a task, and a task's edits never appear in my tree.
- Never configure a worktree to base off local `HEAD`.
- The loop session itself only reads the board, runs the forge CLI, and dispatches workers. It does
  not edit code.

One-time setup this depends on is in the repository README, under Install.

### Merging

Work `Ready to Merge` notes lowest `order` first, one at a time, re-checking each after the previous
merge lands rather than reading all of them up front.

All of these must hold before merging:

- The PR is mergeable — no conflicts
- Required checks are green
- No review is in a changes-requested state
- No comment on the PR is newer than the newest automated review. Someone speaking up after the last
  review is a new issue, whatever it says.
- The review gate in `setup.md` passes, by the procedure under Reading the review

Merge to the PR's own base branch, not to the default branch. They aren't always the same, and for
stacked PRs merging to the default branch is how you lose the stack. Pin the merge method explicitly
— `setup.md` says which — because there's nobody here to answer an interactive prompt.

If the PR is conflicting: don't merge and don't ask me. Dispatch a worker to resolve the conflicts in
that task's worktree, push, and set `status: In Progress`. It goes back through `Agent Finished`,
checks, and review from there.

If mergeability is still being computed, which is normal in the seconds after another merge lands,
that is not a conflict. Leave the note alone and look again next pass.

If any other check fails, leave it at `Ready to Merge`, say in one line what blocked it, and move to
the next.

After a merge, if every PR for that task is merged, set `status: Done` and `done_date` to today in
`YYYY-MM-DD`, local time. Never backfill or edit a `done_date` that's already set.

### Asking me something

A worker that can't proceed sets `status: Needs Input`, writes `question`, sets `status_since`, and
stops. It does not guess and it does not pick the interpretation that's easiest to build.

Escalate only for things I actually have to decide: which of two reasonable behaviors is the intended
one, a product call the task doesn't cover, or something needing access I have and you don't. Do not
escalate for style, for permission to continue, or for anything answerable from the codebase, the PR,
or the linked issue. A question I could have answered by reading the issue is a bug in this process.

`question` is a property, so it renders as one cell in a table I might be reading on my phone. Keep it
to a couple of sentences: the context, the options, and which one you'd pick and why. One question per
note. If several are open, ask the one that unblocks the most and put the rest in the body under
`## Open questions`.

When I fill in `answer`: on the next pass, hand it to the worker, set `status: In Progress`, and clear
both `question` and `answer` back to empty. Never write to `answer` yourself, and never treat an empty
`answer` as agreement.

Once a PR exists, a blocked task stays at `Needs Input` rather than moving forward. Don't open a PR
just to have somewhere to put the question.

### Testing

I set this while I'm actually testing a change. It means hands off, completely: don't combine it,
don't touch its branch, don't push to its PR, don't rewrite its description, don't change its status.
Read it if you need to, change nothing.

A note sitting at `Testing` is not stuck and doesn't need chasing. The exits are `Needs Changes`,
`Ready to Merge`, and back to `Ready to Test`, and all three are mine.

### Needs Changes

I set this when I've tested something and want changes. The request goes in the note body, below
whatever's already there, opening with a line that starts `Changes requested`:

```markdown
Changes requested:

The drawer should close when the split panel is hidden.
```

Match that line loosely: any case, with or without a trailing colon or date, as a markdown heading or
as plain text. People write this as a bare line far more often than as a tidy heading, and a rule that
only matches one exact spelling silently matches nothing.

The request is everything from that line down to the next heading, or to the end of the note.

Act on the **last** one in the file. Everything above it is history that's already built. Requests get
appended, so last in file order is newest; if two are left, the lower one counts. Dispatch a worker to
that task's existing branch and worktree, set `status: In Progress`, and let it run the normal path
from there: push, `Agent Finished`, checks, review.

Don't open a new PR. The changes go onto the existing one and `pr` doesn't change. Don't edit or
delete the block; it's my record of what I asked for.

If the newest block is ambiguous, that's a `Needs Input`, not a guess.

I'm responsible for pairing each new block with the status flip. If `status` is anything other than
`Needs Changes`, a new block in the body is a note, not an instruction.

### Promoting from To Do

When fewer notes are at `In Progress` than the WIP limit, take the To Do note with the lowest `order`,
set `status: In Progress`, and dispatch a worktree-isolated worker. The context is the note body, or
the issue it links to. If the body is empty and there's no linked issue, leave it at `To Do` and say
so instead of guessing.

### Opening the PR

Every PR this process opens carries two sections in its description.

`## Verified` is what the worker exercised itself before handing the change over, and what it
couldn't. `Ready to Test` should mean I'm confirming something that has already been seen working,
not finding out whether it works.

- Name what was actually run: which checks, which routes, which states, which widths.
- Name what wasn't, and why. "Couldn't verify in the browser: the dev stack wasn't running" is a
  normal answer and a useful one.
- Never write a verification that didn't happen. An empty `## Verified` costs one careful test round.
  A false one costs the credibility of every other line in the section.

`## Testing instructions` is written for someone who hasn't read the diff. It covers how to get to the
change starting from where I'd start, what correct looks like in enough detail that I could tell it
was wrong, and the edge cases worth checking for this particular change. Write what's actually worth
checking; don't paste a generic list.

When a task reaches `Ready to Test` with nothing exercised, say so in the pass summary, so I know
which ones need the closer look.

Once the work is pushed and a PR exists:

1. Take it out of draft, if the review gate in `setup.md` needs that. Many automated reviewers skip
   draft PRs, so a task that skips this sits at `Agent Finished` forever waiting for a review that
   will never be posted.
2. Set `pr` to the URL, `files_changed` to the PR's changed-file count, and `status: Agent Finished`.

Refresh `files_changed` whenever you push to a PR. The combine rule reads it.

### Agent Finished

In this order:

1. Check the required checks. If any are red, diagnose before touching anything and take the branch
   that fits, under Red checks below.
2. If they're green, read the review by the procedure below.
3. If the review for the current head passes the gate, set `status: Ready to Test` and delete the
   worktree the work was happening on. If it doesn't, copy the review body into a request for the
   worker to keep iterating and leave the note at `Agent Finished`, subject to the bound under When a
   review won't pass. If there's no review for the current head yet, do nothing this pass.

#### Red checks

Diagnose before you touch anything. Pushing a fix for a check you haven't read is how a branch grows
commits that fix nothing, and it's the fastest way to make a flake look like a defect. Pull the
failing job's logs, then take the branch that fits:

- **It's this branch's failure.** Push a minimal fix from that task's worktree and leave the note at
  `Agent Finished` to be rechecked next pass.
- **It's already on the default branch.** Say so, merge the default branch in, and push. Don't fix it
  here; someone else's breakage doesn't belong in this task's diff.
- **It's infrastructure, or a known flake.** Re-run the job and change nothing. `memory.md` is the
  list of what's known, and a failure matching an entry there needs no diagnosis past the match.

One re-run per job per head. A job that fails the same way twice isn't flaky, whatever memory says, so
treat the second failure as real. If it still isn't attributable to the branch after that, it's a
`Needs Input`: say what's failing, what you ruled out, and that you'd re-run or wait it out.

A skipped check is not a passed one. When a required job was skipped because an earlier one failed,
the PR has no coverage from it, and a green-looking rollup doesn't change that. Fix the upstream
failure and let it run.

### Reading the review

`setup.md` says what the review gate is. There are three shapes, and the third is the one with a trap
in it.

**No automated review.** Judge on checks alone and hand it over. Don't leave a task at
`Agent Finished` waiting for a review that nothing will ever post.

**A formal review state.** Read the PR's review decision directly. This is the easy case: the forge
already ties a review to a commit for you.

**A bot that posts a plain comment.** Then comments are the only record, and a comment carries no
commit reference — so you have to establish one yourself:

1. Get the PR's head SHA.
2. List the PR's comments and take the newest from the reviewing bot.
3. Tie it to a commit through the job it ran in. These comments generally link to the CI run that
   produced them; pull that run id out of the body and confirm the run's head SHA equals the PR's.
4. If no comment maps to the current head, the review for this code hasn't posted yet. That is not a
   failing verdict. Do nothing this pass.
5. Read the verdict line out of that body, in whatever form `setup.md` says it takes.

Step 3 is the load-bearing one. Comments accumulate across pushes and nothing in a comment says which
code it read, so without it an approval from two commits ago silently promotes a task whose checks
just went green after a fix. **Never fall back to "newest comment wins."**

A passing review can still carry non-blocking observations. Don't act on them and don't hold the task
for them. Append a one-line bullet under `## Review notes` in the body, creating the section if it
isn't there, then promote.

#### When a review won't pass

The gate doesn't move. But iterating at a review that was never going to pass is a loop with no exit,
so the iterating gets bounded.

Send the review body back to the worker and leave the note at `Agent Finished`, as before. Then check
two things:

- **The review names nothing blocking.** A body whose findings are all non-blocking, or that says the
  change looks fine while stopping short of whatever word the gate wants, leaves a worker nothing to
  act on. Another round can only produce the same review.
- **Three distinct heads have now drawn a non-passing review on this PR.** Count them by the procedure
  above, one per head. A fourth round has never been the thing that fixed it.

Either one means stop iterating and set `status: Needs Input`. Ask whether to merge as it stands or
keep going, quote what the last review actually said, and say which you'd pick. That's an override of
the merge gate, so it's mine, and asking is the only way it reaches me.

Escalating never merges anything by itself. It costs one question, and it's the only branch here that
terminates, so prefer it to a fourth round.

### Combining small tasks

When two notes are both at `Ready to Test`, both have `files_changed` under the threshold in
`setup.md`, and they're the same kind of work on the same surface, fold them into one so I can test
once.

1. Merge the smaller PR's branch into the larger PR's branch.
2. Close the smaller PR with a comment pointing at the larger one.
3. Keep the larger task's note. Append the smaller note's body to it under a `## Also covers` heading,
   and merge the two `## Testing instructions` sections in the PR description into one coherent set
   rather than two lists stapled together. Delete the smaller note.
4. Set the surviving note to `Agent Finished`, not `Ready to Test`, and refresh `files_changed`.

Step 4 is not optional. Combining pushes new commits, so the review that passed for the old head no
longer describes what's on the branch. The combined PR earns its way back to me through checks and a
fresh review like anything else.

Limits:

- One combine per pass.
- Don't combine if the result would exceed the threshold.
- Don't combine across surfaces. Two fixes to the same screen, yes. A UI fix and a data-layer change,
  no, however small both are.
- Don't touch a note I've set to `Testing`, `Ready to Merge`, or `Needs Changes`.
- When it isn't obvious that two things are the same kind of work, leave them alone. A wrong combine
  means I test two unrelated changes at once and can't tell which one broke; a missed combine costs
  one extra test round.

### Memory

What this process has learned, in `memory.md`, next to this file. It's outside the repo because it
outlives any one worktree and it covers more than one repo.

You're its only writer and I'm its only editor. Workers neither read it nor write it. You paste the
relevant parts into a dispatch, and they hand candidates back in their `MEMORY:` lines. The same
single-writer rule that keeps the board from racing keeps this file from racing several workers at
once.

Four sections, each a list of entries, each entry one rule:

```markdown
- **Dark mode on new surfaces** — Check both themes on anything that sets a background color.
  Asked on #114, #131, #147. (3×, last 2026-07-21)
```

The rule first, the evidence that earned it second, `(N×, last YYYY-MM-DD)` last. The count and the
date aren't decoration. They're what turns eviction into a lookup instead of a judgment call.

| Section           | Holds                                                       | Cap         |
| ----------------- | ----------------------------------------------------------- | ----------- |
| Preferences       | What I want by default                                      | 15          |
| Codebase          | Facts about the code worth not rediscovering; tag the repo  | 20 per repo |
| Patterns to avoid | Defects that keep coming back                               | 15          |
| Retired           | One line each for entries I've deleted                      | 10          |

#### What earns an entry

Four sources, and what each costs to believe:

- **A worker's `MEMORY:` line.** A codebase fact is checkable, so it lands the first time. "The tests
  need a migration step before they pass" doesn't have to happen twice to be true.
- **The newest changes-requested block.** Matched the loose way, per Needs Changes above. Two
  independent occurrences before it becomes a preference. Generalizing my taste from one instance is
  the same mistake as picking the interpretation that's easiest to build.
- **A review finding.** Same threshold: twice, on different PRs, before it's a pattern. One nit is a
  nit.
- **An `answer` I filled in.** That's me talking, so it lands at once, but only the part of it that
  outlives the task it was asked about.

Nothing that's already written somewhere a worker will read anyway. The repo's agent instructions,
the linked issue, and the code itself are not memory. An entry restating them costs context on every
dispatch and buys nothing back.

#### Adding

Prefer merging into an existing entry over writing a new one. That's how counts grow and how the file
stays short. Bump the count and update `last` whenever something confirms an entry, even when the
wording doesn't change.

When you fold two existing entries together, the survivor takes the **higher** of the two counts and
the later `last`, never the sum. The count means "how many times this was confirmed", and two separate
facts confirmed once each is not a fact confirmed twice.

When a section is at its cap, a candidate has to beat the weakest entry in it: fewest confirmations,
oldest `last` breaking the tie. If it doesn't beat it, it doesn't go in, and that's a normal outcome
rather than a failure.

The caps aren't a storage problem, they're what keeps this from turning into a log. Forty sharp rules
change what gets built. Four hundred observations get skimmed.

Count the section against its cap before you add and again after. A section over its cap is a bug in
this process, not a large section: evict down to the cap in the same pass that notices it, by the rule
above, and say in the pass summary what lost its slot. The cap is not advisory. It is the only thing
standing between a dispatch someone reads and a dispatch someone skims.

#### Graduating

An entry that keeps getting confirmed has stopped being knowledge and become a tax. Every dispatch
pays it, and the count is the evidence that something upstream is broken and nobody has fixed it.

Only entries describing something **broken** graduate: a flake, a document that's out of date, a check
that lies, a misconfiguration, a step that shouldn't be manual. A durable fact about how the code
works doesn't graduate however often it gets confirmed, because there's nothing at the source to fix.
"The runner drops out weekly" graduates. "A worktree is a fresh checkout, so install your own
dependencies" never does.

When such an entry reaches **4×**, it graduates: open a task for fixing it at the source, then delete
the entry. The note carries the entry's full text, so the deletion loses nothing.

- The note lands wherever `setup.md` says graduated work goes. Parking it somewhere I don't read is
  the same tax wearing a different hat.
- Give it an `order` of the creation timestamp, so it queues behind everything already waiting rather
  than jumping the line. It's real work, but it isn't urgent work.
- Title it as the fix, not the observation. "Stop the docs check from silently skipping lint", not
  "the docs check has a line cap".
- One graduation per pass. If several qualify, take the highest count. That cap is what stops a memory
  cleanup from filling every WIP slot with maintenance in a single pass.
- Say in the pass summary that it graduated, and to what.

Graduate even when the fix looks like it belongs to somebody else. "The CI runner drops out" is still
a task: pin it, retry it automatically, or write down that it's accepted and why. A tax nobody has
decided to keep is a tax nobody has looked at.

A graduated entry does not go to `Retired`. Retired is for rules I rejected.

#### Removing

- **I contradict it.** Delete it and leave one line in `## Retired`. That's a correction, not an
  eviction, and Retired is what stops you learning it back next week.
- **The code disagrees with it.** The code wins, every time. Delete the entry and say so in the pass
  summary. A worker that runs into this reports it and follows the code; it does not work around the
  memory.
- **Evicted by a better entry.** It goes, and it does not go to Retired. Retired is for things I
  rejected, not for things that lost a slot.

#### Using it

Every dispatch carries memory. Include `## Preferences`, `## Patterns to avoid`, and the `## Codebase`
entries tagged for that repo. Leave out the other repos' entries, and leave out Retired.

Say what each is worth, because they aren't worth the same. Preferences and Patterns to avoid are
requirements for the work, as binding as anything in the task itself. Codebase entries are leads to
check rather than facts to trust: they were true when they were written, and the branch has moved
since.

### Done

Never move a note out of `Ready to Test` on your own, other than combining. The exits are `Testing`,
`Needs Changes`, and `Ready to Merge`, and all three are mine.

If there's nothing eligible to work, say so in one line and don't invent work.

### When to stop

Stop when nothing on the board can move without me. All of these must hold:

- Nothing at `To Do`
- Nothing at `In Progress`, `Agent Finished`, `Needs Changes`, or `Ready to Merge`
- No two `Ready to Test` notes are combinable
- Every remaining note is `Ready to Test`, `Testing`, `Backlog`, `Done`, or `Needs Input` with an
  empty `answer`

Say what you're waiting on in one line, then end the loop: print `LOOP: stop` as the last line of the
pass. `board/loop.sh` reads that and exits.

Keep going otherwise. A quiet pass is not a reason to stop. `Agent Finished` is still actionable while
checks are running, so ask for a short delay — `LOOP: wait <seconds>` as the last line — and look
again. A `Needs Input` note whose `answer` I've filled in is actionable immediately.

The delay and the stop are mine to choose each pass, which is why the loop is driven by
`board/loop.sh` rather than a fixed interval. A fixed-interval loop — Copilot's own `/loop`, which is
an alias of `/every` — is a cron job: it runs until stopped by hand or until it expires, and can't end
itself.
