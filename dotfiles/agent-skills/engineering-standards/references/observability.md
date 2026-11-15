# Observability profile

**Trigger:** Service processes, asynchronous operations, operationally important integrations, or existing telemetry instrumentation.

- Prefer [OpenTelemetry](https://opentelemetry.io/docs/specs/otel/) APIs/SDKs and its semantic conventions over provider-specific instrumentation where appropriate. Export via [OTLP](https://opentelemetry.io/docs/specs/otlp/) when supported. The backend/collector are deployment choices, not obligatory application dependencies.
- Follow [W3C Trace Context](https://www.w3.org/TR/trace-context/) for trace propagation over supported boundaries and vendor-neutral correlation. Explicitly propagate context through background jobs and messages where the framework doesn't do so automatically.
- Instrument relevant operations with useful spans, metrics, and structured logs; include stable service/resource names and bounded-cardinality dimensions. Do not emit user secrets, credentials, unfiltered PII, request bodies, or unique per-user IDs into high-cardinality metrics.
- Preserve causal relationships, use appropriate error recording and latency measurements, and avoid double instrumentation or uncontrolled telemetry volume.
- Validate trace connectivity, metric dimensions, sampling, and redaction with a local collector/test backend or existing integration checks. Do not deploy a full monitoring platform solely because this profile is applicable.
