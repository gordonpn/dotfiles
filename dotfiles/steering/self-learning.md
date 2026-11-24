# Self-Learning Loop

Turn corrections and repeated failures into durable behavior change, so the same
mistake is not repeated in a later session.

Lessons live in `~/.kiro/steering/lessons.md`. That file is itself a steering
file, so anything recorded there is automatically in context next session. That
is what closes the loop.

## When to record

- The user corrects a factual claim, an approach, or a convention.
- The same failure happens twice: build, test, command, or a wrong assumption.
- A verified fact about this environment contradicts a reasonable default, such
  as a tool flag that does not exist in the installed version.
- The user states a durable preference not already covered by existing steering.

## Promotion bar

All three must hold before writing a lesson:

1. It would change behavior in a future, different session.
2. It is not already implied by an existing steering file.
3. It generalizes beyond the current task. Task-specific findings belong in the
   workspace notes file instead.

If a candidate fails the bar, do not record it. A junk drawer is worse than an
empty file, because every line costs context on every turn of every session.

## Format

One line per lesson: imperative, with a short why and the date.

```markdown
- Check tool flags against the installed version before relying on them; bash 4.2 has no `bind -X`. (2026-08-07)
```

Once more than a handful accumulate, group them under `##` headings by area
(git, zsh, aws, shell).

## Self-correction

Recording is half the loop. A stale lesson is worse than a missing one, because
it carries the authority of something already verified.

When work touches an area an existing lesson covers, check that lesson against
what you actually observe:

- It names a file, path, flag or command: confirm that still exists before
  relying on it.
- Observation contradicts it: fix or remove it in the same session, per Hygiene
  below. Do not leave it for a future one.
- It was true and the environment has since moved: remove it.

The file is the set of things currently believed true, not a history of what was
once believed.

## Hygiene

- Prefer editing an existing lesson over adding a near-duplicate.
- Delete lessons that turn out to be wrong. Do not annotate them as wrong.
- Delete lessons the environment has made obsolete.
- Consolidate when entries start to overlap: merge duplicates, generalize
  specifics, drop the stale. Length is not itself the trigger.

`lessons.md` is tracked in git. Write to it directly, but do not commit it.
Leave the diff for review.
