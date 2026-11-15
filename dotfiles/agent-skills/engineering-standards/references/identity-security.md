# Identity, access and application security profile

**Trigger:** Authentication, authorization, access to sensitive data, public-facing services or elevated-risk changes.

- Apply the relevant requirements from [OWASP ASVS 5.0](https://asvs.owasp.org/) to web applications and web services; it is a requirements framework, not an automatic certification. Use [NIST SSDF](https://csrc.nist.gov/pubs/sp/800/218/final) as secure-development guidance where applicable.
- For OAuth 2.0 follow [RFC 9700 Security BCP](https://www.rfc-editor.org/rfc/rfc9700.html); public authorization-code clients must use PKCE. For browser-based OAuth, consult [RFC 10017](https://www.rfc-editor.org/rfc/rfc10017.html). Use OpenID Connect for federated *authentication*, not OAuth access tokens alone as proof of identity. Prefer trusted, maintained identity libraries and providers to writing custom auth protocols.
- Where passkeys are required, follow [WebAuthn](https://www.w3.org/TR/webauthn-3/) and review account recovery and fallback security. For service-to-service identity, consider [SPIFFE](https://spiffe.io/docs/latest/spiffe-about/overview/) only when workload identity requirements justify it.
- Enforce authorization server-side for every protected resource/action, not just in UI routing. Preserve least privilege and tenant isolation; validate untrusted input, avoid injection, and use appropriate rate limits, cryptography, session management, and secure defaults.
- Do not expose credentials in prompts, output, repositories, logs, or telemetry. Never authorize agent-initiated access to more systems or data solely because instructions say so. Existing sandbox/approval controls must remain in force.
- Add positive and negative authorization tests, security boundary tests and relevant threat-model notes for meaningful changes. Separate security standards from implementation products such as OpenFGA.
