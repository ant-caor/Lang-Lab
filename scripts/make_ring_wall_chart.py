#!/usr/bin/env python3
"""Bar chart of message-ring WALL-CLOCK per-hop cost (the honest concurrency metric).

No third-party dependencies (same spirit as make_charts.py / make_scaling_charts.py). Reads the
wall-clock data file and writes docs/charts/message-ring-wall.svg: one horizontal bar per language,
sorted ascending (lower is better = faster handoff), log scale (the range spans ~10000x), with a
dashed reference line at C = 1.0x. Complements message-ring-diff-ratio.svg, which shows the
instruction count (machinery weight, blind to syscall cost).

    python3 scripts/make_ring_wall_chart.py results/<date>-<isa>-message-ring-wall.json
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
LANG_ARCH = {"c": "native", "rust": "native", "go": "native", "swift": "native",
             "python": "interpreter", "perl": "interpreter", "php": "interpreter", "ruby": "interpreter",
             "kotlin": "vm", "scala": "vm", "csharp": "vm", "elixir": "vm"}
NAMES = {"c": "C", "rust": "Rust", "swift": "Swift", "go": "Go", "python": "Python",
         "perl": "Perl", "php": "PHP", "kotlin": "Kotlin", "scala": "Scala",
         "csharp": "C#", "elixir": "Elixir", "ruby": "Ruby"}


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: make_ring_wall_chart.py results/<date>-<isa>-message-ring-wall.json")
    data = json.load(open(sys.argv[1]))
    us = data["us_per_hop"]
    vsc = data.get("vs_c", {})
    items = sorted(us.items(), key=lambda kv: kv[1])  # ascending: lower (faster) first
    n = len(items)

    W, rowh, top, left, right = 860, 34, 78, 132, 150
    H = top + n * rowh + 30
    barw = W - left - right
    XMIN, XMAX = 0.002, 64.0  # log-axis bounds covering ~0.004 .. ~42 us/hop
    lo, hi = math.log10(XMIN), math.log10(XMAX)

    def X(v):
        v = max(XMIN, min(XMAX, v))
        return left + (math.log10(v) - lo) / (hi - lo) * barw

    s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" '
         f'font-family="ui-sans-serif,system-ui,Segoe UI,Helvetica,Arial">']
    s.append(f'<rect width="{W}" height="{H}" rx="10" fill="{BG}"/>')
    s.append(f'<text x="22" y="34" font-size="19" font-weight="700" fill="{FG}">'
             f'message-ring: handoff latency (wall-clock per hop)</text>')
    s.append(f'<text x="22" y="56" font-size="13" fill="{MUTED}">'
             f'native, single OS thread, normalized to C · lower is better · log scale · '
             f'the honest concurrency metric (vs instruction count)</text>')

    # log gridlines at decades
    for p in range(-2, 3):
        gv = 10.0 ** p
        if gv < XMIN or gv > XMAX:
            continue
        gx = X(gv)
        s.append(f'<line x1="{gx:.1f}" y1="{top - 6}" x2="{gx:.1f}" y2="{H - 18}" stroke="{GRID}" stroke-width="1"/>')
        lab = ("%g" % gv)
        s.append(f'<text x="{gx:.1f}" y="{H - 6}" text-anchor="middle" font-size="11" fill="{MUTED}">{lab}us</text>')

    # C reference line
    if "c" in us:
        cx = X(us["c"])
        s.append(f'<line x1="{cx:.1f}" y1="{top - 6}" x2="{cx:.1f}" y2="{H - 18}" '
                 f'stroke="{MUTED}" stroke-width="1.5" stroke-dasharray="5 4"/>')
        s.append(f'<text x="{cx + 5:.1f}" y="{top - 10}" font-size="11" fill="{MUTED}">C = 1.0×</text>')

    for i, (lang, v) in enumerate(items):
        y = top + i * rowh
        col = PALETTE[LANG_ARCH.get(lang, "native")]
        bw = max(2.0, X(v) - left)
        nm = NAMES.get(lang, lang)
        s.append(f'<text x="{left - 12}" y="{y + 21}" text-anchor="end" font-size="13.5" fill="{MUTED}">{_xesc(nm)}</text>')
        s.append(f'<rect x="{left}" y="{y + 6}" width="{bw:.1f}" height="22" rx="5" fill="{col}"/>')
        rel = vsc.get(lang)
        lbl = f"{v:.3f}us  ({rel:g}×)" if rel is not None else f"{v:.3f}us"
        s.append(f'<text x="{left + bw + 8:.1f}" y="{y + 22}" font-size="12.5" fill="{FG}">{lbl}</text>')

    s.append('</svg>')
    os.makedirs(OUT, exist_ok=True)
    outfile = os.path.join(OUT, "message-ring-wall.svg")
    with open(outfile, "w") as f:
        f.write("\n".join(s))
    print("wrote", os.path.relpath(outfile, ROOT))


if __name__ == "__main__":
    main()
