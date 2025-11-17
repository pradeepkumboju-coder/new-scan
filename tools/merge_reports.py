#!/usr/bin/env python3
"""
Merge normalized scanner JSON files from a directory into one merged JSON report.

Usage:
  python tools/merge_reports.py --input-dir normalized --output merged.json
"""

import argparse, glob, json, sys, os

def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--input-dir", "-i", default="normalized", help="Directory with normalized JSON files")
    p.add_argument("--output", "-o", default=None, help="Output file path (stdout if omitted)")
    return p.parse_args()

def main():
    args = parse_args()
    merged = {"scanner": "merged", "findings": []}

    pattern = os.path.join(args.input_dir, "*.json")
    files = sorted(glob.glob(pattern))
    for fname in files:
        try:
            with open(fname, "r", encoding="utf-8") as fh:
                data = json.load(fh)
                merged["findings"].extend(data.get("findings", []))
        except Exception as e:
            print(f"Warning: failed to parse {fname}: {e}", file=sys.stderr)

    out = json.dumps(merged, indent=2)
    if args.output:
        with open(args.output, "w", encoding="utf-8") as fh:
            fh.write(out)
    else:
        print(out)

if __name__ == "__main__":
    main()
