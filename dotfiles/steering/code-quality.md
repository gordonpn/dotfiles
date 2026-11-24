# Code Quality

How code should be written, once the scope is settled. `code-changes.md` covers
how much to write; this file covers the shape of what gets written.

Rules are language-neutral. Parentheticals name how each lands in Java,
TypeScript and Python, the three that come up here.

## Type safety

- Never escape the type system to get past the checker (raw types or `Object`,
  `any`, `Any`). At an untyped boundary use the explicit unknown type and narrow
  with a checked conversion: `unknown` plus a guard, a runtime-validated
  Python model or `TypedDict`, or an `instanceof` check. A `TypedDict`
  declaration alone does not validate input.
- Never silence the checker to get past an absent or failed case
  (`@SuppressWarnings`, `!` non-null assertion, `# type: ignore`, a blind cast,
  discarding an error). Narrow it or handle it.
- In domain code, represent an absent lookup result in the return type
  (`Optional<T>`, `T | undefined`, `Optional[T]`). At framework boundaries,
  use the documented not-found mechanism to preserve the intended response,
  including a throwing helper when required.
- Bind once, narrowest scope. Prefer the immutable binding declared at first use
  (`final`, `const` over `let`, never `var`). Reassign only where the value
  genuinely changes.
- Do not hand out mutable internals. Fields never reassigned after construction
  are immutable, collections crossing a boundary are unmodifiable or copied, and
  a caller's argument is never mutated.
- Handle closed sets exhaustively. A `switch` over an enum or union handles every
  variant. Add a compile-time or static type check that flags a missing case.
  Use a Java switch expression with every enum constant and no default, a
  TypeScript `never` assignment, or Python's `assert_never` with a type
  checker enabled in CI.
- In dynamic languages use the strongest typing available: annotate every
  signature, parameter, return and module-level constant, and enforce it with a
  strict checker (`mypy` or `pyright`, TypeScript strict mode).
- Export named identifiers rather than anonymous defaults or wildcard
  re-exports, so every public symbol is rename-safe and greppable.

## Structure

- Prefer early returns and guard clauses over deeply nested `if`/`else`.
- Keep a function or module to a single conceptual task.
- Minimise hidden state and side effects. Favour deterministic functions with
  clear input and output contracts, so they can be understood and tested in
  isolation.
- Never embed one language inside another: SQL in `.sql` files rather than inline
  strings, scripts and styles in their own files rather than inline in markup.
  Inline code loses syntax highlighting, formatting, type checking and linting.
- Where a project declares a layering (core, adapters, edge, infrastructure),
  enforce the import direction: core never imports adapters, adapters never
  import each other, no cycles. Do not impose that structure on a project that
  never adopted it.

## Documentation in code

- API docs state the contract only: what it does, what it accepts, what it
  returns, what it throws. No implementation details, no design rationale, no
  claims about the rest of the codebase, no future plans, because those claims
  rot. Use inline comments to explain non-obvious reasons for the code.
- A type, class or module doc states its role and contract, not an enumeration of
  what each of its methods does. That is each method's own doc's job.
- Never reference ticket IDs, PR or CR numbers, sprint goals, milestones or
  timeline phases in code, comments or documentation. Plain `TODO` and `FIXME`
  markers for genuine deferred work are fine.
