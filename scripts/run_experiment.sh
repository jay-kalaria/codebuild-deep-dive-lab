#!/usr/bin/env bash
set -Eeuo pipefail
mkdir -p diagnostics
EXPERIMENT="${EXPERIMENT:-baseline}"
export EXPERIMENT
started="$(date +%s)"
finish() {
  result=$?
  finished="$(date +%s)"
  printf 'experiment=%s\nexit_code=%s\nelapsed_seconds=%s\n' "$EXPERIMENT" "$result" "$((finished - started))" > diagnostics/result.txt
  echo "Experiment $EXPERIMENT exited with code $result after $((finished - started)) seconds"
}
trap finish EXIT

# A repository-scoped Maven cache makes dependency-caching experiments observable.
MAVEN_REPO="$PWD/.m2repo"
case "$EXPERIMENT" in
  baseline)
    mvn -B -ntp -Dmaven.repo.local="$MAVEN_REPO" clean verify
    java -jar target/codebuild-deep-dive-lab-1.0.0.jar
    ;;
  fail-test)
    mvn -B -ntp -Dmaven.repo.local="$MAVEN_REPO" -Dlab.forceFailure=true clean verify
    ;;
  cpu)
    mvn -B -ntp -Dmaven.repo.local="$MAVEN_REPO" clean verify
    java -cp target/classes dev.lab.BuildLab cpu "${PRIME_LIMIT:-12000000}" "${WORKERS:-1}" | tee diagnostics/cpu.txt
    ;;
  heap)
    mvn -B -ntp -Dmaven.repo.local="$MAVEN_REPO" -DskipTests clean package
    # Deliberately limits only the Java HEAP to 64 MiB; does not exhaust the host.
    java -Xmx64m -cp target/classes dev.lab.BuildLab heap 128
    ;;
  offline)
    # Will generally fail on a cold workspace unless dependencies were restored.
    mvn -B -ntp -o -Dmaven.repo.local="$MAVEN_REPO" clean verify
    ;;
  sleep)
    seconds="${SLEEP_SECONDS:-360}"
    if ! [[ "$seconds" =~ ^[0-9]+$ ]] || (( seconds < 30 || seconds > 420 )); then
      echo "SLEEP_SECONDS must be 30..420" >&2; exit 2
    fi
    echo "Sleeping ${seconds}s; configure CodeBuild's build timeout to 5 minutes to test enforcement."
    sleep "$seconds"
    ;;
  identity)
    aws sts get-caller-identity
    ;;
  s3-probe)
    : "${PROBE_BUCKET:?Set PROBE_BUCKET to a bucket you own}"
    : "${PROBE_KEY:?Set PROBE_KEY to an EXISTING test object}"
    aws s3api head-object --bucket "$PROBE_BUCKET" --key "$PROBE_KEY"
    ;;
  disk)
    echo "Writing and fsyncing a bounded 64-MiB temporary file; NOT a disk-exhaustion test."
    df -h .
    dd if=/dev/zero of=diagnostics/test-64MiB.bin bs=1M count=64 conv=fsync status=progress
    ls -lh diagnostics/test-64MiB.bin
    rm -f diagnostics/test-64MiB.bin
    ;;
  *)
    echo "Unknown EXPERIMENT: $EXPERIMENT" >&2; exit 2
    ;;
esac
