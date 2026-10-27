#!/usr/bin/env python3
"""Summarize real AWS 'aws codebuild batch-get-builds' JSON output. No dependencies."""
import json
import sys

ORDER = ["SUBMITTED", "QUEUED", "PROVISIONING", "DOWNLOAD_SOURCE", "INSTALL", "PRE_BUILD", "BUILD", "POST_BUILD", "UPLOAD_ARTIFACTS", "FINALIZING", "COMPLETED"]

def main():
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python3 scripts/summarize_builds.py builds.json")
    with open(sys.argv[1], encoding="utf-8") as f:
        payload = json.load(f)
    for build in payload.get("builds", []):
        print("\nBUILD:", build.get("id", "unknown"))
        print("Status:", build.get("buildStatus", "unknown"))
        print("Compute:", build.get("environment", {}).get("computeType", "unknown"))
        for phase in sorted(build.get("phases", []), key=lambda p: ORDER.index(p["phaseType"]) if p.get("phaseType") in ORDER else len(ORDER)):
            name = phase.get("phaseType", "?")
            secs = phase.get("durationInSeconds", "?")
            status = phase.get("phaseStatus", "-")
            context = "; ".join(x.get("message", "") for x in phase.get("contexts", []) if x.get("message"))
            print(f"  {name:<20} {str(secs):>6}s  {status}")
            if context: print("      ", context[:180])

if __name__ == "__main__":
    main()
