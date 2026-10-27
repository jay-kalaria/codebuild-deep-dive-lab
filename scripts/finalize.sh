#!/usr/bin/env bash
set -euo pipefail
mkdir -p diagnostics
{
  echo "finalization_utc=$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  echo "experiment=${EXPERIMENT:-baseline}"
  echo "source_revision=${CODEBUILD_RESOLVED_SOURCE_VERSION:-unknown}"
  echo "build_id=${CODEBUILD_BUILD_ID:-local}"
  echo "See result.txt for exit code on regular command failures."
  echo "On a hard timeout or termination, the result file and reports may be absent."
} > diagnostics/finalization.txt
