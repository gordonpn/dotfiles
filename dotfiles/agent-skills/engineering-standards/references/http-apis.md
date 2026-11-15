# HTTP API profile

**Trigger:** Designing, modifying, or consuming an HTTP interface. Avoid creating an API specification for a utility with no HTTP surface.

- Follow [RFC 9110 HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110.html): correct method safety/idempotency, status codes, content negotiation, preconditions, and headers. Use [RFC 9111](https://www.rfc-editor.org/rfc/rfc9111.html) when HTTP caching applies.
- Treat the **existing OpenAPI document** as a public contract; update operations, authentication requirements, request/response schemas, documented error statuses, and examples with behavior changes. For new public HTTP APIs, prefer [OpenAPI](https://spec.openapis.org/oas/) when its tooling is supported. Choose a supported spec version; do not blindly upgrade existing documents to the newest release.
- Reuse [JSON Schema](https://json-schema.org/specification) when defining JSON contracts. Understand the OpenAPI version's JSON Schema dialect and distinguish missing vs `null` values.
- When using machine-readable HTTP error bodies, prefer [RFC 9457 Problem Details](https://www.rfc-editor.org/rfc/rfc9457.html) (`application/problem+json`) rather than inventing a fresh error format; preserve existing external contracts unless migration is approved.
- Use [RFC 3339](https://www.rfc-editor.org/rfc/rfc3339.html) for interoperable timestamp strings when appropriate; include explicit UTC or offset and do not confuse timestamps with local date-only values.
- Validate input at trust boundaries; constrain pagination, timeouts, payload sizes, and rate limits as needed. Do not log secrets or tokens. Test status codes, schema conformance, authentication failures and backward compatibility.
- Run available OpenAPI validation, linting (e.g. Spectral), implementation/contract checks, and breaking-change analysis; do not assert conformance solely from generated docs.
