# Software supply chain, release and container profile

**Trigger:** CI configuration, dependencies, build artifacts, releases, or containers.

- Respect current build files and lockfiles; use minimal, maintained dependencies and reproducible build settings when feasible. Avoid unrelated upgrades. For licenses, use valid [SPDX identifiers](https://spdx.org/licenses/) rather than invented license names.
- For containers follow relevant [OCI image, runtime, and distribution specifications](https://opencontainers.org/); prefer immutable digests in deployment/promotion processes where useful, and avoid unnecessary privileged containers and baked-in secrets.
- For published artifacts generate an SBOM using [SPDX](https://spdx.dev/) **or** [CycloneDX](https://cyclonedx.org/) according to downstream requirements. Use [SLSA](https://slsa.dev/spec/v1.2/) and [in-toto attestation](https://in-toto.io/) formats when build provenance and verification are required. These complement one another but are not all needed for a prototype.
- Use least-privilege CI tokens, restrict untrusted pull-request execution, avoid leaking secrets to forks, verify third-party actions, and pin third-party GitHub Actions to reviewed commit SHAs where appropriate. Check GitHub workflows with a tool such as `zizmor` if available (tool, not standard).
- Add dependency/secret/vulnerability checks appropriate to deployment risk. Don't claim a SLSA level or secure build provenance without actual evidence; preserve attestations and verification commands in release documentation.
