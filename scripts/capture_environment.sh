#!/usr/bin/env bash
set -euo pipefail
mkdir -p diagnostics
{
  echo "=== Non-secret build context ==="
  echo "UTC time: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  echo "Experiment: ${EXPERIMENT:-baseline}"
  echo "Build ID: ${CODEBUILD_BUILD_ID:-local}"
  echo "Source revision: ${CODEBUILD_RESOLVED_SOURCE_VERSION:-unknown}"
  echo "AWS Region: ${AWS_REGION:-not-set}"
  echo "OS: $(uname -srm)"
  echo "CPU count (nproc): $(nproc)"
  echo "Available space in working directory:"
  df -h .
  echo "Cgroup memory limit (may be 'max'):"
  if [ -r /sys/fs/cgroup/memory.max ]; then cat /sys/fs/cgroup/memory.max; else echo "not exposed"; fi
  echo "Cgroup v1 memory limit (if available):"
  if [ -r /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then cat /sys/fs/cgroup/memory/memory.limit_in_bytes; else echo "not exposed"; fi
} | tee diagnostics/environment.txt
