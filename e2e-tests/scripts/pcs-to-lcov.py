#!/usr/bin/env python3
# Convert a list of executed program counters to lcov tracefile format.
#
# SPDX-License-Identifier: MIT
#
"""Convert a list of executed program counters to lcov tracefile format.

Extracts ALL instruction addresses from the SP ELF (via llvm-objdump),
resolves them to source lines (via llvm-addr2line), then marks which
lines were hit based on the coverage log from the TCG plugin.  This
produces meaningful coverage percentages — lines that exist but weren't
executed show as DA:line,0.

Usage:
    pcs-to-lcov.py --elf <SP_ELF> --input <coverage.log> --output <coverage.info>
"""

import argparse
import re
import subprocess
import sys
from collections import defaultdict


def get_all_instruction_pcs(elf):
    """Extract all instruction addresses from the ELF via llvm-objdump."""
    proc = subprocess.run(
        ["llvm-objdump", "-d", "--no-show-raw-insn", elf],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        print(f"llvm-objdump failed: {proc.stderr}", file=sys.stderr)
        sys.exit(1)

    # Match lines like "  20802000: mov x0, x1"
    pattern = re.compile(r"^\s*([0-9a-fA-F]+):")
    pcs = []
    for line in proc.stdout.split("\n"):
        m = pattern.match(line)
        if m:
            pcs.append(f"0x{m.group(1)}")
    return pcs


def resolve_pcs(elf, pcs):
    """Batch-resolve PCs to (pc, file, line) triples using llvm-addr2line."""
    proc = subprocess.run(
        ["llvm-addr2line", "-e", elf],
        input="\n".join(pcs),
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        print(f"llvm-addr2line failed: {proc.stderr}", file=sys.stderr)
        sys.exit(1)

    lines = proc.stdout.strip().split("\n")
    results = []
    # Output is one line per PC: file:line[:col]
    for i, loc in enumerate(lines):
        pc = pcs[i]
        if loc.startswith("??") or ":0" in loc:
            continue
        colon = loc.rfind(":")
        if colon <= 0:
            continue
        filepath = loc[:colon]
        try:
            lineno = int(loc[colon + 1 :])
        except ValueError:
            continue
        if lineno == 0:
            continue
        results.append((pc, filepath, lineno))

    return results


def write_lcov(hits, outpath):
    """Write an lcov tracefile."""
    with open(outpath, "w") as f:
        f.write("TN:e2e-coverage\n")
        for filepath in sorted(hits):
            f.write(f"SF:{filepath}\n")
            for lineno in sorted(hits[filepath]):
                f.write(f"DA:{lineno},{hits[filepath][lineno]}\n")
            f.write("end_of_record\n")


def main():
    parser = argparse.ArgumentParser(description="Convert PCs to lcov format")
    parser.add_argument("--elf", required=True, help="Path to SP ELF binary")
    parser.add_argument("--input", required=True, help="Coverage log (hex PCs)")
    parser.add_argument("--output", required=True, help="Output lcov tracefile")
    parser.add_argument(
        "--source-prefix",
        action="append",
        default=None,
        help="Only include sources whose paths contain this substring (repeatable)",
    )
    args = parser.parse_args()

    # Load executed PCs from the coverage plugin log
    with open(args.input) as f:
        executed_pcs = {line.strip() for line in f if line.strip()}
    print(f"Loaded {len(executed_pcs)} executed PCs from {args.input}")

    # Extract ALL instruction addresses from the ELF
    all_pcs = get_all_instruction_pcs(args.elf)
    print(f"Found {len(all_pcs)} total instructions in ELF")

    # Resolve all PCs to source locations
    print("Resolving all instruction PCs to source lines...")
    all_locations = resolve_pcs(args.elf, all_pcs)
    print(f"  {len(all_locations)} resolved to source locations")

    # Build the full map: file -> line -> {exists, hit}
    # "exists" lines get DA:line,0; "hit" lines get DA:line,N
    file_lines = defaultdict(lambda: defaultdict(int))  # file -> line -> hit_count
    for pc, filepath, lineno in all_locations:
        if args.source_prefix and not any(p in filepath for p in args.source_prefix):
            continue
        # Ensure the line exists in the map (even if not hit)
        if lineno not in file_lines[filepath]:
            file_lines[filepath][lineno] = 0
        # If this PC was executed, mark it
        if pc in executed_pcs:
            file_lines[filepath][lineno] += 1

    write_lcov(file_lines, args.output)
    total_lines = sum(len(v) for v in file_lines.values())
    hit_lines = sum(1 for f in file_lines.values() for c in f.values() if c > 0)
    print(f"Wrote lcov tracefile: {args.output}")
    print(f"  {len(file_lines)} source files, {total_lines} lines, {hit_lines} hit")


if __name__ == "__main__":
    main()
