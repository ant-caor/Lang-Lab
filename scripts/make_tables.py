#!/usr/bin/env python3
"""Generate a benchmark study's results table from its qemu+insn envelope, and splice it into the
study README (single source of truth, like make_charts.py). This keeps the ~hundreds of absolute
cells across the study tables reproducible from the measured data instead of hand-maintained.

    python3 scripts/make_tables.py results/2026-06-19-arm64-sha256.json          # print the table
    python3 scripts/make_tables.py results/2026-06-19-arm64-sha256.json --write  # splice into README

Table format (sorted ascending by vs-C ratio):
    | Language | I(<n1>) | I(<n2>) | differential | vs C | determinism |
C is bold with a bold 1.00x; sub-1.0x ratios are bold; an extrapolated cell (its "note" says
"extrapolated") is marked with * and its determinism reads "projected".
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NAMES = {"c": "C", "rust": "Rust", "swift": "Swift", "go": "Go", "python": "Python",
         "perl": "Perl", "php": "PHP", "kotlin": "Kotlin", "scala": "Scala",
         "csharp": "C#", "elixir": "Elixir", "ruby": "Ruby", "cobol": "COBOL"}


def human(v):
    v = float(v)
    if v >= 1e12:
        return f"{v/1e12:.2f}T"
    if v >= 1e9:
        x = v / 1e9
        return f"{x:.2f}B" if x < 10 else f"{x:.1f}B"
    if v >= 1e6:
        return f"{v/1e6:.1f}M"
    if v >= 1e3:
        return f"{v/1e3:.1f}k"
    return str(int(v))


def szlabel(n):
    n = int(n)
    if n >= 1_000_000:
        return f"{n/1e6:g}M"
    if n >= 1000:
        return f"{n/1000:g}k"
    return str(n)


def ratio_str(r):
    return f"{r:.2f}"


def gen_table(env):
    n1, n2 = env["n1"], env["n2"]
    rows = [r for r in env["results"] if r.get("i_n1") and r.get("i_n2")]
    cdiff = next((r["differential"] for r in rows if r["language"] == "c"), None)
    if not cdiff:
        sys.exit("make_tables: no C baseline in envelope")
    rows.sort(key=lambda r: r["differential"] / cdiff)
    out = [f"| Language | I({szlabel(n1)}) | I({szlabel(n2)}) | differential | **vs C** (lower is better) | determinism |",
           "|---|--:|--:|--:|--:|---|"]
    for r in rows:
        L = r["language"]
        name = f"**{NAMES.get(L, L)}**" if L == "c" else NAMES.get(L, L)
        rat = r["differential"] / cdiff
        extrap = "extrapolat" in (r.get("note") or "").lower()
        cell = ratio_str(rat) + "×" + ("\\*" if extrap else "")
        if L == "c" or rat <= 1.0:
            cell = f"**{cell}**"
        det = r["determinism"]
        if extrap and "extrap" not in det and "project" not in det:
            det += " (extrap.)"
        out.append(f"| {name} | {human(r['i_n1']['median'])} | {human(r['i_n2']['median'])} | "
                   f"{human(r['differential'])} | {cell} | {det} |")
    return "\n".join(out)


# Locate the study's results table in the README: the markdown table whose HEADER row mentions
# "differential" or "Real work" (the matrices use benchmark-abbrev headers; the rep/correctness
# tables have no such header), then the contiguous block of "|" lines.
HDR = re.compile(r"^\|.*(differential|Real work).*\|\s*$", re.I)


def splice(readme_path, table_md):
    lines = open(readme_path, encoding="utf-8").read().split("\n")
    start = next((i for i, l in enumerate(lines) if HDR.match(l)), None)
    if start is None:
        sys.exit(f"make_tables: no results table found in {readme_path}")
    end = start
    while end + 1 < len(lines) and lines[end + 1].lstrip().startswith("|"):
        end += 1
    new = lines[:start] + table_md.split("\n") + lines[end + 1:]
    open(readme_path, "w", encoding="utf-8").write("\n".join(new))
    return start, end


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: make_tables.py <envelope.json> [--write]")
    env = json.load(open(sys.argv[1]))
    table = gen_table(env)
    if "--write" in sys.argv:
        readme = os.path.join(ROOT, "benchmarks", env["benchmark"], "README.md")
        a, b = splice(readme, table)
        print(f"spliced results table into {os.path.relpath(readme, ROOT)} (lines {a+1}-{b+1})")
    else:
        print(table)


if __name__ == "__main__":
    main()
