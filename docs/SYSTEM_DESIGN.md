# Offline architecture questions and thought exercises

## Build-job lifecycle: what can we infer?

A customer calls an API to start a build. You can observe that the request has a build ID and moves through documented lifecycle phases. A plausible high-level design contains request validation, persisted job state, quota checks, work scheduling, capacity provisioning, source retrieval, build execution, log collection and artifact publication. **This is a conceptual model, not a claim about AWS CodeBuild's actual private architecture.**

1. Which steps must be durable if a control-plane host dies after acknowledging a `StartBuild` call?
2. How might the service preserve job isolation across customer accounts, VPC configurations, credentials and build images?
3. When should the service retry a job? Distinguish infrastructure failure from a deterministic failing test. Why can retries cause duplicate writes?
4. How would you prevent a noisy tenant from consuming all worker capacity? What fairness and admission-control policy would you choose?
5. How would you surface the root cause when container provisioning fails before customer commands start?
6. How would you measure queue latency vs provisioning latency vs build runtime and report SLOs separately?
7. What strategies could preserve logs and reports if the worker crashes unexpectedly?
8. How might cache poisoning or stale dependencies occur? What isolation and keying policy would prevent it?

## Suggested answers: reasoning frameworks

- Persist a stable build ID, accepted request metadata, state transitions, source revision and customer correlation IDs. Use idempotency and atomic transitions when appropriate.
- Apply account/Region/compute-type admission limits and consider fairness separately from per-project limits.
- Retry transient infrastructure errors only when safe; jobs may invoke external APIs and be non-idempotent. Provide observability for reason codes and outcomes.
- Treat caching as a correctness/security boundary: use namespaces, keys, invalidation and access controls.
- Partition the observed timeline into API acceptance, queue wait, environment provisioning, source download, execution and artifact handling. Do not assert these exactly match internal implementation boundaries.

## Triage exercise

Scenario: A build is QUEUED for 12 minutes, PROVISIONING for 20 seconds, DOWNLOAD_SOURCE for 4 seconds and BUILD for 12 seconds. The application itself uses a 1-second Maven test. Is it fair to recommend JVM optimization? No. The dominant observed delay is queue time. Investigate capacity, quotas and admission before optimizing Java test logic.

Scenario: A VPC build cannot reach Maven Central, but succeeds outside the VPC. Is that necessarily a CodeBuild defect? No. Validate route tables, NAT or an appropriate private endpoint/proxy, DNS and security group egress before drawing a conclusion.
