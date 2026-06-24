#!/usr/bin/env python3
"""Generate self-contained SVG charts for the WALL-CLOCK SCALING track.

No third-party dependencies. Usage:
    python3 scripts/make_scaling_charts.py results/scaling/2026-06-22-arm64-gemm.json
Writes docs/charts/<bench>-scaling.svg (speedup vs cores, one line per language, with an
ideal-linear reference) and docs/charts/<bench>-scaling-bars.svg (speedup at max cores).

Scaling-results schema (one file per date/isa/benchmark), produced by a driver that
collects measure-scaling.sh's per-language JSON lines:
    {
      "benchmark": "gemm", "date": "...", "isa": "arm64", "track": "scaling",
      "cores": [1, 2, 4],
      "results": [
        {"language": "c", "primitive": "threads", "timing": "compute",
         "size": 1024, "speedup": {"1": 1.0, "2": 1.92, "4": 3.63}},
        ...
      ]
    }
Speedup is the wall-clock ratio T1/TP of the compute region (COMPUTE_NS), so runtime
startup is excluded; for JIT runtimes the timed run is JIT-warmed. NOT bit-reproducible
like the instruction track — it is a ratio reported as such.
"""
import json
import math
import os
import sys
from xml.sax.saxutils import escape as _xesc

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "charts")

BG, FG, MUTED, GRID = "#0d1117", "#e6edf3", "#9aa7b4", "#21262d"
PALETTE = {"native": "#3fb950", "interpreter": "#f0883e", "vm": "#a371f7"}
# How each language reaches CPU parallelism on this track (for colouring/grouping).
LANG_ARCH = {
    "c": "native", "rust": "native", "go": "native", "swift": "native",
    "python": "interpreter", "perl": "interpreter", "php": "interpreter", "ruby": "interpreter",
    "kotlin": "vm", "scala": "vm", "csharp": "vm", "elixir": "vm",
}
NAMES = {"c": "C", "rust": "Rust", "swift": "Swift", "go": "Go", "python": "Python",
         "perl": "Perl", "php": "PHP", "kotlin": "Kotlin", "scala": "Scala",
         "csharp": "C#", "elixir": "Elixir", "ruby": "Ruby", "cobol": "COBOL"}


def name(r):
    # Drop a "-proc"/"-threads" suffix for display but keep it distinct in the label.
    lang = r["language"]
    base = lang.split("-")[0]
    disp = NAMES.get(base, base)
    if "-" in lang:
        disp += " (" + lang.split("-", 1)[1] + ")"
    return disp


def arch(r):
    return LANG_ARCH.get(r["language"].split("-")[0], "native")


def svg_header(w, h, title, subtitle=""):
    s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
         f'viewBox="0 0 {w} {h}" font-family="ui-sans-serif,system-ui,Segoe UI,Helvetica,Arial">']
    s.append(f'<rect width="{w}" height="{h}" rx="10" fill="{BG}"/>')
    s.append(f'<text x="22" y="34" font-size="19" font-weight="700" fill="{FG}">{_xesc(title)}</text>')
    if subtitle:
        s.append(f'<text x="22" y="56" font-size="13" fill="{MUTED}">{_xesc(subtitle)}</text>')
    return s


def line_chart(bench, isa_tag, cores, rows, outfile):
    """rows: list of result dicts with speedup[str(core)]. X = cores, Y = speedup."""
    W, H = 820, 470
    left, right, top, bot = 64, 150, 80, 46
    px0, px1, py0, py1 = left, W - right, top, H - bot
    ncore = len(cores)
    # Y range: at least up to max cores (ideal), extend if super-linear observed.
    obs = [r["speedup"][str(c)] for r in rows for c in cores]
    ymax = max([float(max(cores))] + obs)
    ymax = math.ceil(ymax * 1.05)

    def X(i):  # equal spacing per core count
        return px0 + (px1 - px0) * (i / (ncore - 1) if ncore > 1 else 0)

    def Y(v):
        return py1 - (py1 - py0) * (v / ymax)

    s = svg_header(W, H, f"{bench}: parallel speedup vs cores",
                   f"wall-clock T1/TP of the compute region (startup excluded){isa_tag} · higher is better, ideal = linear")
    # Y gridlines + labels (integer speedups)
    for g in range(0, ymax + 1):
        y = Y(g)
        s.append(f'<line x1="{px0}" y1="{y:.1f}" x2="{px1}" y2="{y:.1f}" stroke="{GRID}" stroke-width="1"/>')
        s.append(f'<text x="{px0 - 10}" y="{y + 4:.1f}" text-anchor="end" font-size="12" fill="{MUTED}">{g}×</text>')
    # X ticks (core counts)
    for i, c in enumerate(cores):
        s.append(f'<text x="{X(i):.1f}" y="{py1 + 24:.1f}" text-anchor="middle" font-size="13" fill="{MUTED}">{c} core{"s" if c > 1 else ""}</text>')
    # Ideal-linear reference (dashed): speedup == cores
    pts = " ".join(f"{X(i):.1f},{Y(float(c)):.1f}" for i, c in enumerate(cores))
    s.append(f'<polyline points="{pts}" fill="none" stroke="{MUTED}" stroke-width="1.5" stroke-dasharray="5 4"/>')
    s.append(f'<text x="{X(ncore - 1) + 8:.1f}" y="{Y(float(cores[-1])) + 4:.1f}" font-size="12" fill="{MUTED}">ideal</text>')
    # One polyline per language, sorted by speedup at max cores (label stacking order)
    rows = sorted(rows, key=lambda r: r["speedup"][str(cores[-1])], reverse=True)
    last_label_y = -1e9
    for r in rows:
        col = PALETTE[arch(r)]
        pts = " ".join(f"{X(i):.1f},{Y(r['speedup'][str(c)]):.1f}" for i, c in enumerate(cores))
        s.append(f'<polyline points="{pts}" fill="none" stroke="{col}" stroke-width="2.5" opacity="0.92"/>')
        for i, c in enumerate(cores):
            s.append(f'<circle cx="{X(i):.1f}" cy="{Y(r["speedup"][str(c)]):.1f}" r="3" fill="{col}"/>')
        # End labels run top->bottom (rows are sorted by descending speedup, and higher
        # speedup = smaller y). Keep a minimum vertical gap so near-tied lines don't collide.
        ly = Y(r["speedup"][str(cores[-1])])
        if ly < last_label_y + 16:
            ly = last_label_y + 16
        last_label_y = ly
        s.append(f'<text x="{px1 + 8}" y="{ly + 4:.1f}" font-size="12.5" fill="{col}">'
                 f'{_xesc(name(r))} {r["speedup"][str(cores[-1])]:.2f}×</text>')
    s.append('</svg>')
    os.makedirs(OUT, exist_ok=True)
    with open(outfile, "w") as f:
        f.write("\n".join(s))
    print("wrote", os.path.relpath(outfile, ROOT))


def bars_at_max(bench, isa_tag, cores, rows, outfile):
    """Bar chart: speedup at the max core count, per language."""
    mc = cores[-1]
    items = sorted(((name(r), r["speedup"][str(mc)], arch(r)) for r in rows), key=lambda t: t[1])
    n = len(items)
    W, rowh, top, left, right = 760, 38, 76, 150, 96
    H = top + n * rowh + 24
    barw = W - left - right
    vmax = max(float(mc), max(v for _, v, _ in items))

    s = svg_header(W, H, f"{bench}: speedup at {mc} cores",
                   f"wall-clock, compute region{isa_tag} · higher is better, dashed = ideal {mc}×")
    ideal_x = left + (float(mc) / vmax) * barw
    s.append(f'<line x1="{ideal_x:.1f}" y1="{top - 6}" x2="{ideal_x:.1f}" y2="{H - 16}" '
             f'stroke="{MUTED}" stroke-width="1.5" stroke-dasharray="5 4"/>')
    for i, (lab, v, a) in enumerate(items):
        y = top + i * rowh
        bw = max(2.0, v / vmax * barw)
        s.append(f'<text x="{left - 12}" y="{y + 22}" text-anchor="end" font-size="13.5" fill="{MUTED}">{_xesc(lab)}</text>')
        s.append(f'<rect x="{left}" y="{y + 6}" width="{bw:.1f}" height="23" rx="5" fill="{PALETTE[a]}"/>')
        s.append(f'<text x="{left + bw + 9:.1f}" y="{y + 23}" font-size="13" fill="{FG}">{v:.2f}×</text>')
    s.append('</svg>')
    os.makedirs(OUT, exist_ok=True)
    with open(outfile, "w") as f:
        f.write("\n".join(s))
    print("wrote", os.path.relpath(outfile, ROOT))


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: make_scaling_charts.py results/scaling/<date>-<isa>-<bench>.json")
    data = json.load(open(sys.argv[1]))
    bench = data.get("benchmark", "bench")
    isa = data.get("isa", "")
    isa_tag = f" · {isa}" if isa else ""
    cores = data.get("cores", [1, 2, 4])
    rows = [r for r in data["results"] if r.get("speedup") and all(str(c) in r["speedup"] for c in cores)]
    if not rows:
        sys.exit("make_scaling_charts: no usable speedup rows")
    line_chart(bench, isa_tag, cores, rows, os.path.join(OUT, f"{bench}-scaling.svg"))
    bars_at_max(bench, isa_tag, cores, rows, os.path.join(OUT, f"{bench}-scaling-bars.svg"))


if __name__ == "__main__":
    main()
