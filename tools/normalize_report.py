#!/usr/bin/env python3
"""
normalize_report.py

Usage:
  python tools/normalize_report.py --input raw.json --output normalized.json --scanner trivy \
     --repo myorg/myrepo --commit <sha> --branch <branch> --lang node --profile node:pnpm

If --input is omitted, reads JSON from stdin.
"""

import argparse
import json
import os
from datetime import datetime
import sys

def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--input", "-i", help="Raw scanner input file (json). If omitted, read stdin.")
    p.add_argument("--output", "-o", required=True, help="Output normalized JSON file")
    p.add_argument("--scanner", required=True, help="Scanner short name (trivy, npm-audit, bandit...)")
    p.add_argument("--repo", required=False, help="repository full name")
    p.add_argument("--commit", required=False, help="commit sha")
    p.add_argument("--branch", required=False, help="branch name")
    p.add_argument("--lang", required=False, help="primary language")
    p.add_argument("--profile", required=False, help="scan profile")
    return p.parse_args()

def read_input(path):
    if path:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    else:
        return json.load(sys.stdin)

def make_base(scanner, repo, commit, branch, lang, profile):
    return {
        "scanner": scanner,
        "scanner_version": "unknown",
        "repository": repo or os.environ.get("GITHUB_REPOSITORY"),
        "commit": commit or os.environ.get("GITHUB_SHA"),
        "branch": branch or os.environ.get("GITHUB_REF") or "",
        "language": lang or os.environ.get("PRIMARY_LANG", ""),
        "profile": profile or os.environ.get("SCAN_PROFILE", ""),
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "findings": []
    }

# Tool-specific mappers:
def map_npm_audit(raw, base):
    # npm audit output format (older/newer variants). Normalize vulnerabilities dictionary.
    vulns = raw.get("vulnerabilities") or {}
    for pkg,info in vulns.items():
        sev = info.get("severity") or info.get("severity", "UNKNOWN")
        via = info.get("via", [])
        if isinstance(via, dict):
            via = [via]
        for v in via:
            rule = v.get("source") or v.get("title") or v.get("url") or pkg
            add_finding(base, rule, v.get("title") or v.get("name") or "", sev, pkg, 0, "dependency", v.get("cwe") or None, v)

def map_trivy_fs(raw, base):
    # Trivy FS JSON format
    for result in raw.get("Results", []):
        for vuln in result.get("Vulnerabilities", []) or []:
            add_finding(base,
                        rule=vuln.get("VulnerabilityID"),
                        msg=vuln.get("Title") or vuln.get("Description"),
                        sev=vuln.get("Severity"),
                        file=vuln.get("PkgName") or result.get("Target"),
                        line=0,
                        category="dependency" if vuln.get("Type") == "library" else "config",
                        cwe=vuln.get("CweIDs"),
                        raw_payload=vuln)

def map_bandit(raw, base):
    for f in raw.get("results", []) or []:
        add_finding(base,
                    rule=f.get("test_id"),
                    msg=f.get("issue_text"),
                    sev=f.get("issue_severity"),
                    file=f.get("filename"),
                    line=f.get("line_number"),
                    category="sast",
                    cwe=None,
                    raw_payload=f)

def add_finding(base, rule, msg, sev, file, line, category, cwe, raw_payload):
    base["findings"].append({
        "rule_id": rule or "unknown",
        "message": msg or "",
        "severity": (sev or "UNKNOWN").upper(),
        "file": file or "",
        "line": int(line or 0),
        "category": category or "generic",
        "cwe": cwe,
        "raw_payload": raw_payload or {}
    })

def main():
    args = parse_args()
    raw = read_input(args.input)
    base = make_base(args.scanner, args.repo, args.commit, args.branch, args.lang, args.profile)

    scanner = args.scanner.lower()
    if scanner in ("npm-audit","npm_audit","pnpm-audit","pnpm_audit"):
        map_npm_audit(raw, base)
    elif scanner in ("trivy","trivy-fs","trivy_fs"):
        map_trivy_fs(raw, base)
    elif scanner == "bandit":
        map_bandit(raw, base)
    else:
        # fallback: attach entire raw output as a single finding
        add_finding(base, "raw", f"raw output from {args.scanner}", "INFO", "", 0, "raw", None, raw)

    with open(args.output, "w", encoding="utf-8") as fh:
        json.dump(base, fh, indent=2)

if __name__ == "__main__":
    main()
