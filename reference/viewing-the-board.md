# Viewing the board

The board is a folder of markdown files with YAML frontmatter. Nothing in the protocol depends on a
particular tool being open, so a viewer is a convenience, not a requirement.

## Without any tool

`tasks/` in any editor works. To see the state of things:

```bash
grep -h '^status:' tasks/*.md | sort | uniq -c | sort -rn
```

To find what's waiting on you:

```bash
grep -l '^status: \(Ready to Test\|Needs Input\)' tasks/*.md
```

Editing a note is editing a file. That's the whole interface.

## With Obsidian

`board.base` gives you sortable, grouped views. It's a starting point — `.base` files are normally
built through the UI, so if a view doesn't render, the usual cause is a quoting problem in a filter
expression, and it's easier to fix in the UI than in the YAML.

1. Settings → Core plugins → enable **Bases** and **Properties**.
2. Open `board.base`. Views: Board (grouped by status), Mine, Needs input, To do, Backlog, Done
   (grouped by date), and Broken.
3. **Templater**: point folder templates at `tasks/` using `templates/task.md`. New task, right
   properties, cursor in the body. Without Templater, use `templates/task-plain.md` and set the
   timestamps by hand.

### Getting a dropdown for status

Obsidian has six property types and none of them is a select, so `status` stays **Text** and nothing
in core constrains what you type. Before installing anything, click a `status` cell and type a letter
— if Obsidian suggests values already used elsewhere in the vault, that may be enough on its own.

If it isn't, **Metadata Menu** defines `status` as a `Select` field with the ten values as preset
options, attached to a fileClass mapped to `tasks/`. It writes a plain scalar string, so every filter
in `board.base` and every rule in `protocol.md` keeps working untouched.

### The Broken view

It lists any note whose `status` isn't one of the ten valid values, including empty. A typo'd status
doesn't error — it silently drops the note out of every other view and out of the loop's attention, so
this is the only thing that makes that visible. Check it if a task seems to have vanished.

### Last updated

`board.base` has a formula, `updated: 'file.mtime.relative()'`. No plugin, no writes, and it catches
both your edits and the loop's.

**Don't install a plugin that stamps `updated:` into frontmatter on save.** Linter and the
update-time-on-edit plugins do this. Three problems: they fight the loop for the file, they only fire
for edits made inside Obsidian so they miss every loop write anyway, and they add a write to every
save.

`status_since` is the other half, and it does something `file.mtime` can't. The loop writes it only
when `status` actually changes, so it answers "how long has this been sitting at Ready to Test" —
which mtime can't, since a new PR comment moves mtime without moving the status.

### Ordering

`order` is an integer, ascending, lower first. Bases sorts by property and has no manual row order, so
reordering the queue means editing numbers rather than dragging rows. That's the one real regression
from a table. The template defaults `order` to a creation timestamp, so new tasks land at the back
without you doing anything; renumber only when you want something jumped forward.
