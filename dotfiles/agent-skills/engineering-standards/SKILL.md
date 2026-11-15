---
name: engineering-standards
description: Load domain-specific engineering standards profiles (HTTP APIs, events, observability, identity/security, supply chain, frontend accessibility, data architecture, AI agents) only when triggered by the files or behavior being changed.
---

# Engineering standards profiles

Keep always-loaded instructions small and read only the profile under `references/` triggered by the files or behavior being changed. These profiles are engineering baselines, not instructions to install new dependencies, protocols, or tools that do not serve the project's real requirements. Prefer interoperable, maintained standards checked by linters, contract validators, tests, and security scanners over bespoke formats or prose-only rules.

If the project already defines a convention or contract, preserve it and validate compatibility against it; propose breaking migrations separately rather than silently rewriting existing interfaces. Check current tool compatibility before selecting specification versions.

## Profile triggers (load only when applicable)

| Reference | Activate when changing or reviewing |
| --- | --- |
| [references/http-apis.md](references/http-apis.md) | Public/internal HTTP APIs or clients (RFC 9110/9111, OpenAPI, JSON Schema, RFC 9457, RFC 3339) |
| [references/events.md](references/events.md) | Queues, brokers, and asynchronous messages (AsyncAPI, CloudEvents 1.0, schema compatibility, delivery semantics) |
| [references/observability.md](references/observability.md) | Runtime telemetry, structured logs, metrics, or tracing (OpenTelemetry, OTLP, W3C Trace Context, redaction) |
| [references/identity-security.md](references/identity-security.md) | Authentication, authorization, sensitive data, or public endpoints (OWASP ASVS 5.0, NIST SSDF, OAuth RFC 9700/10017, OIDC, WebAuthn, SPIFFE) |
| [references/supply-chain.md](references/supply-chain.md) | Dependencies, licenses, CI/CD, releases, or containers (SPDX, OCI, SBOM, SLSA v1.2, in-toto, pinned GitHub Actions, `zizmor`) |
| [references/frontend.md](references/frontend.md) | User-facing web UI and accessibility (WCAG 2.2 Level AA, semantic HTML, WAI-ARIA APG) |
| [references/data-architecture.md](references/data-architecture.md) | Formal data products, analytic pipelines, or substantial architecture changes (ODCS, Parquet/Arrow/Iceberg, FINOS CALM, TLA+/Quint) |
| [references/ai-agents.md](references/ai-agents.md) | AI agent products, agent tools, MCP/ACP/A2A boundaries, sandboxing, or evals |

## Compatibility and verification rules

- Update the existing machine-readable contract (OpenAPI, AsyncAPI, JSON Schema, Protobuf, ODCS) alongside compatibility-affecting changes and run contract validation. Introduce a new contract format only when consumers require it.
- Do not assert security, compliance, interoperability, or SLSA provenance from generated docs or a single happy-path check.
- Before completion, run the closest supported formatter, linter, typecheck/build, test suite, contract validation, and security checks. State which profiles/standards were applied, validation statuses (`pass`, `fail`, or `not-run` with reason), compatibility or security concerns, and any proposed follow-up work not performed.
