# Code Changes

How much code to write, and how far to reach, once the approach is settled.
`problem-solving.md` covers choosing the approach. Use the project's testing
guidance to verify the change. This file covers scope.

Biased toward caution over speed. For a trivial edit with an obvious answer,
use judgement rather than ceremony.

## Simplicity first

Write the minimum code that solves the stated problem.

- No features beyond what was asked.
- No abstraction for a single call site.
- No configurability or extension point nobody requested.
- No error handling for a case that cannot occur.

If it could be substantially shorter, rewrite it before showing it. The test:
would a senior engineer call this overcomplicated?

## Check what is already installed

Before hand-rolling retry or backoff, date and timezone maths, pagination,
caching, grouping or deduping, hashing, or validation, check what the project's
existing dependencies provide.

Verify the capability against the resolved version's real API by reading its
source, types, or lockfile, not from memory. A primitive that looks right by name
can throw the wrong type or cover only half the case.

This is not licence to add a dependency. When nothing available covers it, write
the minimum yourself.

## Surgical changes

Touch only what the request requires.

- Do not improve adjacent code, comments, or formatting.
- Do not refactor what is not broken.
- Match the surrounding style, even where you would write it differently.
- Report unrelated dead code instead of deleting it.

Clean up only your own mess: remove the imports, variables, and helpers that
*this* change orphaned, and leave pre-existing dead code alone unless asked.

Every changed line should trace to the request. An unrequested change shows up
in the diff, not in the summary, which is why the full staged diff gets read
before committing.

## Verifiable goals

Restate the task as something checkable, then loop until it passes.

- "Add validation" becomes tests for the invalid inputs, then make them pass.
- "Fix the bug" becomes a test that reproduces it, then make it pass.
- "Refactor X" becomes the suite passing before and after, unchanged.

For multi-step work, state the plan and each step's check before starting.
Weak criteria ("make it work") force a round trip to find out whether it is
done; strong criteria let the work run to completion unattended.

End a turn with the outcome and the one command that verifies it, so the next
step is runnable rather than inferred.
