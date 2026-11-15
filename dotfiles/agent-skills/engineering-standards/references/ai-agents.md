# AI agent implementation and interoperability profile

**Trigger:** Building agent products, implementing agent tools, or configuring agent coding workflows.

- Keep repository instructions in concise [AGENTS.md](https://agents.md/) files when supported. Use [Agent Skills](https://agentskills.io/specification) to package truly reusable capabilities and load details only when needed. Treat community skills and plugins as untrusted dependencies requiring review.
- Choose a protocol only for a required interoperability boundary: [MCP](https://modelcontextprotocol.io/specification) for agent-to-tool/resource interaction; [ACP](https://agentclientprotocol.com/) for host/client-to-agent integration; [A2A](https://a2a-protocol.org/latest/specification/) for independently deployed agent collaboration. Agent Plugins can package reusable integrations. A local CLI is often simpler than a new MCP server.
- Use sandboxing, allowlists, scoped credentials, per-tool authorization, and approval for irreversible actions. Prompt instructions are **not** an authorization mechanism. Treat retrieval content and tool outputs as untrusted, protect against prompt injection and data exfiltration.
- For programmatic LLM output, prefer schema-constrained structured output with validation and explicit error handling. Avoid parsing free-form prose for security-critical decisions.
- Maintain deterministic feedback sensors (tests, lint, build, contracts, structural checks), meaningful eval cases, and traceable tool decisions. Budget context, tokens, and retries. Avoid unattended deployment or auto-merging risky changes by default.
- Preserve human review for critical changes while automating low-risk validation. Do not confuse human approvals without evidence with meaningful verification.
