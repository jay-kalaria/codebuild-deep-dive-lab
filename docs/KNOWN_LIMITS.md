# What counts as a limitation? Verify against AWS documentation

**Verified against public AWS documentation in October 2026.** These are customer-facing rules and current documentation, not claims about private CodeBuild internals. AWS may revise details; check the documentation in your own Region before concluding.

| Topic | Documented boundary or behavior | What to test safely | How to classify |
|---|---|---|---|
| Build timeout | Configurable from 5 to 2,160 minutes (36 hours); max is not adjustable by quota request. | A six-minute sleep with a five-minute timeout, one run. | Hard service limit (per public docs) |
| Queue timeout | Configurable roughly 5 minutes to 8 hours; separate from execution timeout. | Observe queue behavior with two or three builds, not an account-scale stress test. | Service configuration limit |
| Concurrent builds | Quotas vary with account/Region/environment compute type; project-specific concurrent-build limits can reject additional builds. | Check your Service Quotas and start only 2-3 small builds. | Quota + account-specific behavior |
| Queue order | AWS states it is not possible to predict the order in which queued builds start. | Record order and timings, don't assume FIFO. | Scheduler behavior / documented caveat |
| Build history retention | AWS documentation states build history is accessible for one year. | Inspect history retention policy rather than building to test it. | Documented data retention limit |
| Local build cache | Host-local, not reliably available on another worker; unsupported with VPC-enabled builds. | Contrast S3 cache with local cache docs. | Feature restriction and affinity trade-off |
| Cache correctness | Keying and paths control cache reuse; a cache hit doesn't guarantee a faster build. | Run repeated identical commits using `buildspec-cache.yml`. | Performance trade-off / observed behavior |
| VPC egress | CodeBuild VPC network interfaces do not receive public IP addresses; private builds normally require NAT for public endpoints, or suitable private endpoints for supported services. | Study routing; avoid paying for NAT solely for the lab. | Networking configuration requirement |
| Build memory/CPU | Different compute types and modes provide different resources; options are Region-dependent. | Try a bounded workload at small and medium. | Configured resources, not always a universal limit |
| Failure artifacts | CodeBuild attempts UPLOAD_ARTIFACTS even if BUILD fails. Success of upload depends on files, permissions and failure mode. | Use intentional unit-test failure and inspect output. | Documented phase behavior |
| `finally` block | Runs even after an earlier command in its phase fails under normal phase execution. | Inspect `diagnostics/finalization.txt` on test failure. | Lifecycle semantics |
| `on-failure` semantics | Buildspec `on-failure` has compute-mode restrictions (EC2 CodeBuild-managed images; not Lambda or reserved fleets per current docs). | Read docs, do not assume uniform behavior across compute modes. | Feature restriction |
| Sensitive environment variables | PLAINTEXT values can be exposed in AWS API/console, so use Secrets Manager or Parameter Store. `CODEBUILD_` prefix is reserved. | Inspect variable precedence using non-secret `EXPERIMENT`. | Security boundary / configuration |

## Source documents

- https://docs.aws.amazon.com/codebuild/latest/userguide/limits.html
- https://docs.aws.amazon.com/codebuild/latest/userguide/builds-working.html
- https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-compute-types.html
- https://docs.aws.amazon.com/codebuild/latest/userguide/view-build-details-phases.html
- https://docs.aws.amazon.com/codebuild/latest/userguide/caching-local.html
- https://docs.aws.amazon.com/codebuild/latest/userguide/caching-s3.html
- https://docs.aws.amazon.com/codebuild/latest/userguide/vpc-support.html
- https://docs.aws.amazon.com/codebuild/latest/userguide/build-spec-ref.html
- https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-env-vars.html

## A useful formal way to write findings

1. **Claim:** "A warm S3 cache improved my median end-to-end build time by X%."
2. **Evidence:** link three or more matched CodeBuild build IDs, Git SHA, phase timings, cache-restore logs and total durations.
3. **Alternative explanations:** networking variability, Maven artifact repo caching, instance/image variation, S3 cache transfer overhead.
4. **Confidence:** Low for a single run, moderate for repeated controlled runs, higher if repeated across sessions and configurations.
5. **Scope:** your account, Region, source code, compute type, repository and measured period.

Avoid generalizing a single experiment across all CodeBuild users or concluding how AWS's internal scheduler is implemented.
