# Design notes

Why each piece is shaped the way it is. Read this if you're deciding whether to adopt the thing, or
if you're about to change something and want to know what it was load-bearing for.

## Three layers, each doing one thing

A protocol, a loop, and a worker.

The **protocol** is the rules. It lives next to the board rather than inside a repo, so editing the
rules and editing the board are the same act, and so one board can cover several repos.

The **loop** reads the board, talks to the forge, writes frontmatter, and dispatches work. It writes
no code and never touches a repository working tree.

The **worker** writes code in its own worktree and reports back a small structured block. It never
touches the board and never talks to the owner directly.

The separation is what makes failures diagnosable. Each layer can only fail in its own way, so when
something goes wrong you know where to look. A loop that could also write code would be a system where
every bug is everywhere.

## One note per task, not one file with a table

Two things write to the board: you and the loop. Sharing a single file means your status change and
its status change race each other, and whichever saves second wins — silently. You find out when a
task appears to move backwards.

Per-note, you collide only when you both touch the same task, which is rare and obvious. It also means
a `|` in your own prose can't break a table, and it makes the board queryable as data rather than
parsed as text.

The same reasoning appears again a layer down: the loop is the *only* writer to the board and to
`memory.md`. Several workers running at once can't corrupt a file only one process may write.

## The board lives outside the repo

Background sessions relocate into an isolated worktree before editing files, which is right for code
and wrong for a board. An absolute path outside the repo is immune to that. It also keeps your
checkout clean for testing, and handles a backlog that spans repositories.

## The main checkout is yours

Every task runs in a worktree branched from `origin/HEAD` — not from whatever you have checked out.
Your half-finished local state never leaks into a task, and a task's edits never appear in your tree
while you're testing in it.

This is the constraint most worth keeping. You need somewhere that is still yours to think in, and a
system that occasionally writes to it while you're looking at something is worse than no system,
because you stop trusting what you see.

## Statuses that say who moves them

Ten statuses, and the table in the protocol names an owner for each. Three are yours alone —
`Testing`, `Needs Changes`, `Ready to Merge` — and the loop is forbidden from setting them. That's
what makes it safe to leave running: the transitions that mean "a human looked at this" cannot be
manufactured by the thing being reviewed.

`Testing` in particular exists so you can work through a queue without the loop reshuffling what you
haven't reached yet. It means hands off, completely.

## The review verdict has to be tied to a commit

If your reviewer posts a plain comment rather than a formal review, comments accumulate across pushes
and nothing in a comment says which code it read. Take "newest comment wins" and an approval from two
commits ago will silently promote a task whose checks only just went green after a fix.

The fix is to tie the comment to a commit through the CI run that produced it, and require that run's
head SHA to match the PR's. This is the single most subtly-wrong-able part of the setup, which is why
the onboarding interview spends a whole round on it.

## The loop has to be able to stop

Give `/loop` an interval and it becomes a cron job: it runs until you stop it by hand or until it
expires, and it cannot end itself. Bare `/loop` is self-paced — it picks its own delay after each
pass, short while a PR is active and long once things go quiet, and it can end the loop entirely.

So the protocol has an explicit stop condition written as a list of things that must all be true. When
they hold, the loop says what it's waiting on and stops. A loop that can't stop isn't autonomous, it's
expensive.

## Memory, with caps that are enforced

The loop keeps what the process has learned: codebase facts, preferences you've stated twice, defects
that recur. Each entry carries a confirmation count and a date, and every dispatch pastes the relevant
parts into the worker's prompt.

The obvious failure mode is that this becomes a log. The caps are what prevent it — and they only work
if something checks them. In the setup this was extracted from, a cap of 20 was quietly sitting at 37,
and every single dispatch was paying for all 37. So the protocol makes the loop count the section
before and after adding, and treat an over-cap section as a bug to fix that pass.

The caps aren't a storage problem. Storage is free. The cap is what keeps the file worth reading:
forty sharp rules change what gets built, four hundred observations get skimmed.

## Entries graduate into work

The rule that matters most, and the one that took longest to see.

An entry confirmed over and over isn't knowledge. It's a tax, paid on every dispatch, forever, because
nobody ever fixed the underlying thing. The original setup's highest-count entry had been confirmed
*seven times*: the CI runner drops out, here's how to recognize it, re-run the job. Another one — at
4× — literally contained the words "worth fixing at the source rather than re-reporting." It had been
saying that to itself for days, because nothing in the system was designed to listen.

So at 4×, an entry stops being a memory and becomes a task to fix it at the source. Two guards:

- Only **broken** things graduate — flakes, stale docs, checks that lie. A durable fact about how the
  code works has nothing at the source to fix, however often it's confirmed.
- One graduation per pass, so a memory cleanup can't fill every slot with maintenance at once.

## Verification moves left

`Ready to Test` should mean you're confirming something already seen working, not discovering whether
it works. So a worker exercises its own change before opening the PR and writes a `## Verified`
section saying what it ran and — explicitly — what it couldn't reach.

The honest-failure part is load-bearing. "Couldn't verify in the browser, nothing was running" is
worth more than a confident paragraph about a screen the worker never saw, because everything else it
writes gets read in the light of whether that section is true. A verification you can't trust is worse
than none.

## Match the rules to what you actually type

The protocol matches a changes-requested block loosely — any case, heading or bare line — because in
the setup this came from, the owner had written 19 of them and **not one** was the tidy `## Changes
Requested` heading the rules specified. It worked anyway, because the loop read the body and figured
it out, but the "act on the newest one" safeguard was matching nothing.

It had a second cost that was invisible for weeks: the memory rules learn preferences from
changes-requested blocks, so nineteen rounds of real taste feedback were never eligible to become
preferences. The Preferences section had two entries after a hundred completed tasks.

If a rule in your protocol has never once matched reality, it isn't a rule. Grep your own board before
you trust one.

## The bottleneck is you

Worth knowing before you build this. In the setup it came from, the board settled at zero tasks queued
and eight waiting to be tested. The loop was running at a third of capacity, and both ends of the
pipeline were the human: grooming the queue, and testing the output.

That reframes what's worth optimizing. Making the worker faster buys nothing. Making it verify its own
work buys a lot. So does anything that lets you say "no, like this" faster than you can today.
