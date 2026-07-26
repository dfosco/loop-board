# Memory

What this process has learned. The loop writes it, I edit it, workers never touch it. The rules are
under Memory in `protocol.md`.

Entry format, rule first and the metadata last:

```markdown
- **Short name** — The rule, in one or two sentences. What earned it. (N×, last YYYY-MM-DD)
```

Delete anything here that's wrong. A deleted entry goes to `## Retired` so it doesn't come back.

Start empty. This file is worth something only because it was earned one task at a time — seeding it
with guesses about your codebase teaches the loop to trust things nobody checked.

## Preferences

What I want by default. Inferred from my behavior, it takes two independent occurrences; written by
me in an `answer`, it lands at once. Cap 15.

_Nothing yet._

## Codebase

Facts worth not rediscovering, one repo tag per entry, e.g. `[main-repo]`. Lands on first sighting,
since a codebase fact is checkable. Cap 20 per repo.

_Nothing yet._

## Patterns to avoid

Defects that keep coming back: the edge case that keeps getting missed, the check that keeps failing.
Twice on different PRs before it's a pattern. Cap 15.

_Nothing yet._

## Retired

Entries I've rejected, one line each, so they don't get learned back. Evicted entries don't belong
here, only contradicted ones. Cap 10.

_Nothing yet._
