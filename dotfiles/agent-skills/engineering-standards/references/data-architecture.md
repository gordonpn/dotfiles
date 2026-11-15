# Data contracts and architecture-as-code profile

**Trigger:** Public/consumed datasets, analytic pipelines, evolving cross-team data products, or substantial system architecture changes.

- For formally managed data products, assess the [Open Data Contract Standard (ODCS)](https://bitol.io/) to describe schemas, quality expectations, and service levels. Don't add ODCS to an ordinary private table without downstream consumers.
- Use established file/serialization formats that match workloads: Parquet for columnar analytical files, Arrow for columnar in-memory interchange, and Iceberg for managed large analytical tables. These solve different layers of the problem; never mandate all of them.
- Version and validate externally consumed schemas, define ownership and data retention, and test migrations against real storage engines when possible. Prevent silent breaking changes to fields, types, and meaning.
- For complex architectures needing machine-checkable topology/policy, assess [FINOS CALM](https://calm.finos.org/). Treat CALM as an optional architecture representation, not a replacement for clear design or an excuse to create busywork.
- For concurrency-sensitive algorithms, consider bounded-state modeling using [TLA+](https://lamport.azurewebsites.net/tla/tla.html) or [Quint](https://quint-lang.org/); these are verification languages, not ordinary API interoperability standards.
