# Messaging and event-driven interfaces profile

**Trigger:** Publishing, consuming, or evolving asynchronous messages and event contracts.

- Describe externally consumed message channels and operations with [AsyncAPI](https://www.asyncapi.com/docs/reference/specification/latest) when appropriate; match bindings and operations to the actual broker and application behavior. Do not require AsyncAPI for private in-process events.
- Prefer [CloudEvents 1.0](https://github.com/cloudevents/spec/blob/v1.0.2/cloudevents/spec.md) for interoperable event envelopes where multiple producers or consumers benefit. Distinguish the CloudEvents envelope from the domain payload schema.
- Select an interoperable schema (JSON Schema, Protobuf, or Avro) based on existing consumers; never introduce all three by default. Publish schema changes deliberately and test backward/forward compatibility for the chosen serialization system.
- Explicitly document and test ordering assumptions, partition keys, at-least-once vs at-most-once delivery, acknowledgments, retry behavior, poison-message handling, retention, replay, and duplicate processing. Avoid promises of exactly-once *external side effects* without an end-to-end proof.
- Prefer idempotent consumers, stable message identifiers, and transactionally safe publishing patterns such as an outbox when the failure model calls for them. These are engineering patterns, not provisions guaranteed by AsyncAPI or CloudEvents.
- Preserve tracing context across asynchronous boundaries where practical; see observability profile.
