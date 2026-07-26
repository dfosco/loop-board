# Setup

My answers. `protocol.md` holds the rules and points here for anything that varies between people
and repos, so this is the only file you should need to edit to make the loop fit how you work.

Run the `set-up-the-board` skill to fill this in by interview. What's below are the defaults it
starts from — they work as-is, so you can also just edit them by hand.

Everything here is read by the loop on every pass. Keep it short.

---

## Repositories

Which repos this board covers. Tag memory entries with the short name.

| Short name | Path | Default branch |
| ---------- | ---- | -------------- |
| `main-repo` | `~/code/main-repo` | `main` |

## Where work comes from

Task notes are the source of truth. A note may link to an issue, and if it does, that issue is the
fuller context — read it.

- Issue tracker: none. The note body is the whole brief.

## Ready for review — what a worker must reach before it stops

The bar a change has to clear before it reaches me:

- Required checks green
- A `## Verified` section in the PR describing what the worker exercised itself

## The review gate

How an automated review signals that a change is good, and therefore what `Agent Finished` is waiting
for. Pick the one that matches your repo — the procedure for each is under Reading the review in
`protocol.md`.

- **Shape:** no automated review
- **Consequence:** judge a PR on its checks alone and hand it over. Never leave a task at
  `Agent Finished` waiting for a review nothing will post.

<!--
The two other shapes, for reference. Replace the block above with one of these if it fits better.

- **Shape:** formal review state
- **Passing decision:** APPROVED
- **Note:** the forge ties reviews to commits already, so no SHA reconciliation is needed.

- **Shape:** a bot posts a plain comment
- **Bot account:** <login>
- **Passing verdict:** the last line reading `Verdict: approve`
- **Tying a comment to a commit:** the comment links to the CI run that produced it; pull the run id
  from the body and require that run's head SHA to equal the PR's head SHA.
- **Draft PRs:** the bot skips them, so take a PR out of draft as soon as it exists.
-->

## Do I test manually?

- Yes. `Ready to Test` is a real state and it waits for me. `Ready to Merge` is mine to set.

If you answer no, the loop sets `Ready to Merge` itself once the gate passes, and `Testing` goes
unused. Everything else in the protocol is unchanged.

## Merging

- Who merges: the loop, once I've set `Ready to Merge`
- Merge method: squash
- Delete the branch after merge: yes

## Limits

- WIP limit: 3 notes at `In Progress`
- Combine threshold: 30 changed files
- Graduated memory fixes land at: `To Do`

## What the agent never touches

- My main checkout. Every task runs in its own worktree, branched from `origin/HEAD`.
- Anything outside the repos listed above.

## Project commands

What a worker runs to get a fresh worktree usable and to check its own work. Leave a line blank if
the repo doesn't have one.

| Purpose | Command |
| ------- | ------- |
| Install | `npm ci` |
| Build   | `npm run build` |
| Test    | `npm test` |
| Lint    | `npm run lint` |

Gitignored files a fresh worktree needs are listed in `.worktreeinclude` at the repo root.

## Running the app to look at it

How a worker starts the thing and reaches a real UI, if that's possible at all. If it isn't, say so —
"not reachable from a worktree" is a legitimate answer and it stops workers from inventing a
verification they couldn't perform.

- Not configured yet. Workers verify via automated checks only and say so in `## Verified`.

## How I want to be asked

- The board. A blocked task gets `status: Needs Input` and a `question`, and I answer by filling in
  `answer`.
