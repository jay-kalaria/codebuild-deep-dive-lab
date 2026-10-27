# Guided investigations: hypotheses, controls, evidence

Use a single AWS Region and consistent CodeBuild environment when comparing runs. Record CodeBuild build ID, Git commit SHA, date, compute type, image, artifact configuration, experimental variable, CodeBuild phase timings, test results, estimated cost and explanation.

## 1. Baseline / cold start

- Use `buildspec.yml`, EXPERIMENT=`baseline`, project caching disabled.
- Run 3 times, same Git commit and same compute environment.
- Inspect `QUEUED`, `PROVISIONING`, `DOWNLOAD_SOURCE`, `BUILD`, `UPLOAD_ARTIFACTS` timings.
- Hypothesis: for this small application, startup and dependency downloads can dominate Maven computation.
- Caution: phases are not all equivalent to customer code time and one build proves little.

## 2. Deterministic test failure / artifact and report handling

- Use `buildspec.yml`, EXPERIMENT=`fail-test`.
- Expected: Maven tests fail on `MathServiceTest.optionalFailureForBuildSystemExperiment`.
- Inspect logs, `target/surefire-reports/*.xml`, the Reports tab and S3 output.
- Important: CodeBuild attempts `UPLOAD_ARTIFACTS` after a failed `BUILD`; the JAR may be missing, while report and diagnostics can exist.
- Hypothesis: diagnostic artifacts and reports may be preserved, but absence can depend on failure type, IAM, and artifact config.
- Compare this to *hard timeout* (experiment 6).

## 3. S3 Maven dependency caching, then offline build

- In CodeBuild, edit the project and configure an **S3** cache location in a dedicated bucket/prefix (not `No cache`).
- Switch Buildspec to `buildspec-cache.yml`, EXPERIMENT=`baseline`. Run 3 sequential builds on unchanged `pom.xml`.
- Compare Maven download behavior, cache restoration logs, `BUILD` phase, overall duration.
- Then run `EXPERIMENT=offline` with **the same cached buildspec and key**.
- Expected: offline Maven can succeed only when all required Maven artifacts/plugins have been restored; a cold build is likely to fail.
- Caveats: network conditions and CodeBuild environment image can change total duration; run multiple samples. S3 cache has transfer overhead.
- After the experiment, restore baseline buildspec and disable cache to test cold behavior again.

## 4. CPU-bound workload and compute size

- EXPERIMENT=`cpu`, set PRIME_LIMIT=`12000000` and WORKERS=`1` for three runs; repeat with WORKERS=`2`.
- Compare logged `computeSeconds`; phase BUILD also includes Maven, so use the `computeSeconds` value to isolate this workload.
- Repeat on a larger CodeBuild compute type if available and budget permits. Hold Git SHA and limit constant.
- Hypothesis: more vCPUs can help a parallel workload, but overhead, thread count and throttling matter. Not guaranteed.

## 5. Java heap limit vs build-host memory

- EXPERIMENT=`heap`; project compute remains unchanged.
- The experiment starts `java -Xmx64m` and attempts to retain 128 MiB of arrays. Expect Java `OutOfMemoryError`.
- This establishes a *JVM heap constraint*, not a CodeBuild host memory limit. Distinguish JVM settings, OS cgroups, disk, process limits and CodeBuild compute options. Never claim you measured CodeBuild RAM merely from this failure.

## 6. Build timeout vs queue timeout (optional; costs minutes)

- Configure project **build timeout** to exactly 5 minutes (minimum allowed).
- EXPERIMENT=`sleep`, SLEEP_SECONDS=`360` (6 minutes), start one build.
- Expect CodeBuild to stop the build around the configured build timeout; logs/artifacts may be incomplete.
- Queue timeout is separate; to investigate, use project concurrency controls and multiple starts, but remember some project limits reject excess builds rather than queue them.
- Reset the build timeout and EXPERIMENT after testing.

## 7. IAM identity and scoped S3 access

- EXPERIMENT=`identity`: run `aws sts get-caller-identity`; identify the *assumed service role* (not your personal console identity).
- Create a separate private S3 probe bucket with one existing object `private/probe.txt` (avoid public access).
- EXPERIMENT=`s3-probe`, PROBE_BUCKET=`YOUR_PROBE_BUCKET`, PROBE_KEY=`private/probe.txt`.
- Expect success or access denial based on that role's effective policy; a missing object can also return 403/404, so **use a known existing object** and verify bucket/key first.
- If you modify the role to grant object read, scope it to just this one probe object, then revoke. Do not change the role's log/artifact permissions.
- Learn: authorization is separate from source code/build commands and privileges should be least-privilege.

## 8. File system and disk throughput (bounded)

- EXPERIMENT=`disk` writes and fsyncs only 64 MiB, then deletes it.
- Observe `df -h .` and wall-time, compare same compute type across runs.
- This is not a disk exhaustion test, and no small sample proves a disk limit or predictable throughput.

## 9. Concurrent builds / queue behavior (console, optional)

- Set EXPERIMENT=`sleep`, SLEEP_SECONDS=`90`, restore build timeout >= 5 minutes.
- Click Start build 2–3 times in rapid succession on a project without a restrictive project-level concurrent-build limit.
- Record start/end and QUEUED time for each build. Do NOT launch large numbers to probe account quotas.
- Some builds run concurrently; account/compute type quotas can lead to queuing, while project-level concurrent limits can reject further starts. Record actual outcome, not an assumption of FIFO.
- Explore CodeBuild's Service Quotas for your **actual Region/account/compute type**.

## 10. Network/VPC limitations (research before hands-on)

- Compare non-VPC builds with AWS documentation for VPC-attached builds. Study private subnet routing, NAT gateway/instance, endpoints for AWS APIs, and private Maven registries.
- IMPORTANT: **do not create a NAT gateway solely for this beginner lab**: NAT and endpoint-related costs are separate from CodeBuild charges.
- Known CodeBuild constraints: local caching is not supported for VPC-attached builds; VPC-attached builds do not get automatic public IP addresses for egress.
- Document setup requirements rather than inferring a service bug from a missing route or permission.

## Experiment record template

| Experiment | Build ID | Git SHA | Config & region | Hypothesis | Observation (timings/logs) | Explanation | Confidence |
|---|---|---|---|---|---|---|---|
| Baseline-1 | | | | | | | |
| Failure | | | | | | | |
| Cache cold/warm | | | | | | | |
| CPU 1 vs 2 workers | | | | | | | |
| JVM heap | | | | | | | |
| Timeout | | | | | | | |
| IAM | | | | | | | |
| Concurrency | | | | | | | |

## Methodology rules

1. Compare like for like: same commit, image, compute type, Region, cache key and project settings unless that setting is the controlled variable.
2. Measure 3–5 runs where feasible; report *median and range*, not just the fastest run.
3. Separate end-to-end elapsed time from actual workload time. Review phase context and build logs.
4. Always record alternate explanations (cold dependency download, noisy neighbor effects, network latency, S3 cache transfer, permissions).
5. Categorize each issue as **documented quota**, **feature restriction**, **configuration/security trade-off**, **observed behavior**, or **hypothesis**, not simply 'bug'.
6. Avoid keeping secrets, tokens, customer data, or large artifacts in logs or diagnostics.
