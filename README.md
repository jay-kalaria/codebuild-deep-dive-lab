# CodeBuild Deep Dive Lab — research-quality customer experiments

**Goal:** discover what CodeBuild actually does and characterize customer-visible limitations using a controlled, inexpensive Java/Maven project. Designed as the **next step after a successful simple CodeBuild build**. This is NOT AWS-internal architecture documentation.

## What is included?

- `buildspec.yml` — baseline build, unit reports, diagnostics, S3 artifacts.
- `buildspec-cache.yml` — identical build with Maven dependencies in an S3 cache. Requires project-level cache configuration.
- `src/main/java/dev/lab/BuildLab.java` — bounded CPU/memory workloads.
- `src/test/.../MathServiceTest.java` — includes a controlled failing test.
- `scripts/run_experiment.sh` — selects one of 9 experiment modes using `EXPERIMENT`.
- `scripts/capture_environment.sh` — logs non-secret build metadata and sampled environment details.
- `scripts/summarize_builds.py` — prints phase timings from AWS CLI JSON output.
- `docs/EXPERIMENTS.md` — step-by-step experiments, expectations, scientific-method log.
- `docs/SYSTEM_DESIGN.md` — distributed-systems questions and plausible design trade-offs.
- `docs/KNOWN_LIMITS.md` — documented quotas vs measured behavior with primary-source links.

## Prerequisites and costs

GitHub, Java 17, Maven, Git, an AWS account with CodeBuild permissions, and (for artifact collection) a private S3 bucket. Use on-demand small general-purpose Linux / Amazon Linux standard managed image supporting Corretto 17. Choose the same AWS Region for the project and bucket. Enable CloudWatch Logs. All AWS usage may incur charges. Set an AWS Budget alert (NOT a hard cap), avoid VPC NAT gateways for this lab, and clean up afterward. `sleep` intentionally runs minutes and costs build time.

## 1. Local run

```bash
mvn -B clean verify
java -jar target/codebuild-deep-dive-lab-1.0.0.jar
# You can also test individual workloads without AWS:
java -cp target/classes dev.lab.BuildLab cpu 1000000 2
java -Xmx64m -cp target/classes dev.lab.BuildLab heap 128   # expected OOME
```

## 2. Push this folder to a fresh GitHub repository

```bash
git init -b main
git add .
git commit -m "Add CodeBuild deep-dive lab"
git remote add origin https://github.com/YOUR_USERNAME/codebuild-deep-dive-lab.git
git push -u origin main
```

Create a private empty repo first. You may also use the GitHub web interface. Avoid uploading `target/` or `.m2repo/` (ignored).

## 3. Create or update CodeBuild project

Since your first CodeBuild demo works, the easiest path is to **create a second CodeBuild project with the same small on-demand managed Linux configuration** but pointed to this new GitHub repository. Set root buildspec path to `buildspec.yml`, enable CloudWatch Logs, set a 10-minute build timeout for normal experiments, and select your private S3 artifact bucket with ZIP packaging. Let CodeBuild generate a scoped service role; make sure it can write logs and artifacts. Leave privileged mode disabled and automatic retries off.

Run a build with no overrides. Expected: 4 passing JUnit tests, a JAR in S3, a JUnit report group (if role permits) and `diagnostics/` files in the S3 artifact ZIP.

## 4. Choose an experiment in the CodeBuild console

- Open the project and select **Start build**.
- Under environment variables overrides (the Console labels may vary), add a *PLAINTEXT, non-secret* variable named `EXPERIMENT`, with a value from the table below. This **overrides** the default `EXPERIMENT: baseline` in the buildspec.
- Start the build, examine Build phases / Logs / Reports / Artifact, and record its build ID.
- You can optionally add `PRIME_LIMIT`, `WORKERS`, `SLEEP_SECONDS`, `PROBE_BUCKET`, `PROBE_KEY` for applicable modes.

| EXPERIMENT value | What happens | Intended status |
|---|---|---|
| `baseline` | Maven clean verify, four JUnit tests, build JAR | SUCCEEDED |
| `fail-test` | Force one JUnit assertion to fail | FAILED |
| `cpu` | Build, run bounded prime-counting workload | SUCCEEDED |
| `heap` | Attempt 128MiB allocations under a 64MiB JVM heap | FAILED (Java OOME) |
| `offline` | Try Maven `-o` against repository-local dependencies | Succeeds only if cache/warm repo complete |
| `sleep` | Sleep 30..420 seconds; try a 5-minute project timeout | SUCCEEDED or TIMED_OUT (based on configuration) |
| `identity` | Display the STS identity of the assumed build role | SUCCEEDED if networking available |
| `s3-probe` | Read metadata of a known S3 object with the build role | SUCCEEDED or FAILED (IAM/policy dependent) |
| `disk` | Write and fsync only 64MiB, then delete | SUCCEEDED |

**Important:** `heap` demonstrates a JVM `-Xmx` constraint, not a CodeBuild machine limit. For `s3-probe`, use a bucket *you own* and an *existing* test object; never publish your service role's permissions or secrets. The failure scenarios are intentionally controlled.

## 5. Enable S3 Maven caching (separate experiment)

- In CodeBuild project configuration, turn on **S3 caching**, pointing to a dedicated private S3 cache location. Ensure permissions to read/write cache, and do not confuse cache storage with build artifact output.
- Switch project buildspec path to `buildspec-cache.yml` (or use buildspec override when starting a build).
- Run `EXPERIMENT=baseline` three times on the same Git commit. The first run populates cache, later runs can restore it.
- Run `EXPERIMENT=offline`; its result reveals whether dependency/plugin artifacts were restored completely.
- Compare `BUILD` duration *and* total duration across repeats. S3 transfers can offset saved dependency download time.
- Reset project settings afterwards. **Simply adding a cache stanza without enabling S3 caching on the project does not make it persist across hosts.**

## 6. Summarize phase timings using AWS CLI (optional)

Install and configure AWS CLI with your authorized account. Supply **real** build IDs (from the CodeBuild console):

```bash
aws codebuild batch-get-builds --ids   'codebuild-deep-dive-lab:BUILD_ID_1'   'codebuild-deep-dive-lab:BUILD_ID_2' > builds.json
python3 scripts/summarize_builds.py builds.json
```

Without AWS CLI, you can test the parser using a clearly fictional example:

```bash
python3 scripts/summarize_builds.py fixtures/example-builds.json
```

## 7. Run the investigations in order

Read `docs/EXPERIMENTS.md`: it specifies which setting to change, predicted result, what to measure, why a result may be misleading, and how to interpret limits. For architecture, read `docs/SYSTEM_DESIGN.md`. For public documented limits, read `docs/KNOWN_LIMITS.md`.

## Research standard

Document observations separately from AWS published limits and from assumptions about internal architecture. Keep project settings and source revision fixed when comparing performance. Investigate failures by phase, exit code, logs, relevant AWS policy, and resource status.

## Useful AWS documentation (read online)

- Buildspec: https://docs.aws.amazon.com/codebuild/latest/userguide/build-spec-ref.html
- Service quotas: https://docs.aws.amazon.com/codebuild/latest/userguide/limits.html
- Build concurrency: https://docs.aws.amazon.com/codebuild/latest/userguide/builds-working.html
- Build phase transitions: https://docs.aws.amazon.com/codebuild/latest/userguide/view-build-details-phases.html
- S3 caching: https://docs.aws.amazon.com/codebuild/latest/userguide/caching-s3.html
- Local cache limitations: https://docs.aws.amazon.com/codebuild/latest/userguide/caching-local.html
- VPC integration: https://docs.aws.amazon.com/codebuild/latest/userguide/vpc-support.html
- Compute types: https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-compute-types.html

## Cleanup

Delete the temporary CodeBuild project, cache and artifact objects/buckets *created solely for this lab*, CloudWatch log group and dedicated role/connection if no other application uses them. Check AWS Billing after the experiments.
