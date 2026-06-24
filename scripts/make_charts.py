#!/usr/bin/env python3
"""Generate self-contained SVG bar charts from a uniform qemu+insn results file.

No third-party dependencies. Usage:
    python3 scripts/make_charts.py results/2026-06-16-fannkuch.json
Writes SVGs into docs/charts/. Expects the uniform schema (one backend = qemu-insn):
each result has kind, i_n1{median,...}, i_n2{median,...}, differential.
"""
import json
import math
import os
import sys
from xml.sax.saxutils import escape as _xesc

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "charts")

BG, FG, MUTED = "#0d1117", "#e6edf3", "#9aa7b4"
PALETTE = {"native": "#3fb950", "interpreter": "#f0883e", "vm": "#a371f7"}
KIND_ARCH = {"native": "native", "interp": "interpreter",
             "inproc-vm": "vm", "launcher": "vm"}
# Some languages are measured as one process (runtimeKind=native) but belong to a
# different archetype for colouring (e.g. Elixir runs the BEAM VM directly).
LANG_ARCH = {"elixir": "vm"}
NAMES = {"c": "C", "rust": "Rust", "swift": "Swift", "go": "Go", "python": "Python",
         "perl": "Perl", "php": "PHP", "kotlin": "Kotlin", "scala": "Scala",
         "csharp": "C#", "elixir": "Elixir", "ruby": "Ruby", "cobol": "COBOL"}


def human(v):
    for unit, div in (("B", 1e9), ("M", 1e6), ("K", 1e3)):
        if v >= div:
            return f"{v / div:.2f}{unit}"
    return str(int(v))


def svg_header(w, h, title, subtitle=""):
    s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
         f'viewBox="0 0 {w} {h}" font-family="ui-sans-serif,system-ui,Segoe UI,Helvetica,Arial">']
    s.append(f'<rect width="{w}" height="{h}" rx="10" fill="{BG}"/>')
    s.append(f'<text x="22" y="34" font-size="19" font-weight="700" fill="{FG}">{title}</text>')
    if subtitle:
        s.append(f'<text x="22" y="56" font-size="13" fill="{MUTED}">{subtitle}</text>')
    return s


def bars(title, subtitle, items, outfile, logscale, value_fmt):
    """items: list of (label, value, archetype)."""
    items = sorted(items, key=lambda t: t[1])
    n = len(items)
    W, rowh, top, left, right = 760, 40, 74, 132, 96
    H = top + n * rowh + 28
    barw = W - left - right
    vmax = max(v for _, v, _ in items)
    if logscale:
        # guard log10 against non-positive values (general-purpose generator)
        vmin = max(min(v for _, v, _ in items), 1.0)
        lo, hi = math.log10(vmin * 0.8), math.log10(max(vmax, 1.0))
        length = lambda v: max(2.0, (math.log10(max(v, 1.0)) - lo) / (hi - lo) * barw)
    else:
        length = lambda v: max(2.0, v / vmax * barw)

    s = svg_header(W, H, title, subtitle)
    for i, (lab, v, arch) in enumerate(items):
        y = top + i * rowh
        bw = length(v)
        s.append(f'<text x="{left - 12}" y="{y + 23}" text-anchor="end" '
                 f'font-size="14" fill="{MUTED}">{_xesc(lab)}</text>')
        s.append(f'<rect x="{left}" y="{y + 7}" width="{bw:.1f}" height="24" rx="5" '
                 f'fill="{PALETTE[arch]}"/>')
        s.append(f'<text x="{left + bw + 9:.1f}" y="{y + 24}" font-size="13" '
                 f'fill="{FG}">{_xesc(value_fmt(v))}</text>')
    s.append('</svg>')
    os.makedirs(OUT, exist_ok=True)
    with open(outfile, "w") as f:
        f.write("\n".join(s))
    print("wrote", os.path.relpath(outfile, ROOT))


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "results", "latest-fannkuch.json")
    data = json.load(open(src))
    n1, n2 = data.get("n1", 7), data.get("n2", 9)
    isa = data.get("isa", "")
    isa_tag = f" · {isa}" if isa else ""
    bench = data.get("benchmark", "fannkuch")
    # keep only measured languages (skip build/measure failures)
    rows = [r for r in data["results"] if r.get("i_n2") and r.get("i_n1")]

    def name(r):
        return NAMES.get(r["language"], r["language"])

    def arch(r):
        return LANG_ARCH.get(r["language"]) or KIND_ARCH.get(r.get("kind", "native"), "native")

    base = next((r["differential"] for r in rows if r["language"] == "c"), None)
    if base is None:  # fall back to rust if C is absent
        base = next((r["differential"] for r in rows if r["language"] == "rust"), None)
    if base is None:
        sys.exit("make_charts: no C or Rust baseline in results; cannot normalize the diff-ratio chart")

    # 1) PRIMARY: differential work, normalized to the baseline (C = 1.0x).
    diff = [(name(r), r["differential"] / base, arch(r)) for r in rows]
    bars(f"{bench}:relative real work (I({n2})−I({n1}), C = 1.0×)",
         f"differential cancels startup + JIT · qemu+insn{isa_tag} · the fair metric · lower is better",
         diff, os.path.join(OUT, f"{bench}-diff-ratio.svg"), logscale=max(v for _, v, _ in diff) > 1000,
         value_fmt=lambda v: f"{v:.2f}×")

    # 2) Absolute instruction count at the larger size (median), log scale.
    n2_chart = [(name(r), r["i_n2"]["median"], arch(r)) for r in rows]
    bars(f"{bench}:instructions at n={n2}",
         f"absolute count · qemu+insn{isa_tag} · log scale · less = more efficient",
         n2_chart, os.path.join(OUT, f"{bench}-n2-absolute.svg"), logscale=True, value_fmt=human)

    # 3) Absolute instruction count at the smaller size (median), log scale.
    n1_chart = [(name(r), r["i_n1"]["median"], arch(r)) for r in rows]
    bars(f"{bench}:instructions at n={n1}",
         f"absolute count · qemu+insn{isa_tag} · log scale · less = more efficient",
         n1_chart, os.path.join(OUT, f"{bench}-n1-absolute.svg"), logscale=True, value_fmt=human)


if __name__ == "__main__":
    main()
