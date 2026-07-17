#!/usr/bin/env python3
"""Generate the master comparison matrix: every language × every benchmark, one heatmap.

No third-party dependencies (same spirit as make_charts.py). It auto-discovers the most recent
qemu+insn envelope for each benchmark in results/, normalizes each cell to the C baseline
(C = 1.00×), sorts languages by their geometric-mean ratio across the whole suite (= the overall
leaderboard), and renders:

    docs/charts/matrix.svg   a log-colour heatmap (green = beats/ties C → red = far slower)

and prints a Markdown leaderboard. With --write it splices both (the image ref + the leaderboard)
into README.md between the <!-- MATRIX:START --> / <!-- MATRIX:END --> markers.

    python3 scripts/make_matrix.py             # write the SVG + print the leaderboard
    python3 scripts/make_matrix.py --write     # also splice the block into README.md
"""
import glob
import json
import math
import os
import sys
from xml.sax.saxutils import escape as _xesc

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "charts")
ISA = "arm64"

BG, FG, MUTED, GRID = "#0d1117", "#e6edf3", "#9aa7b4", "#0d1117"
NAMES = {"c": "C", "rust": "Rust", "swift": "Swift", "go": "Go", "python": "Python",
         "perl": "Perl", "php": "PHP", "kotlin": "Kotlin", "scala": "Scala",
         "csharp": "C#", "elixir": "Elixir", "ruby": "Ruby", "java": "Java", "javascript": "JavaScript"}
# Archetype colour for the row label (matches make_charts.py palette).
PALETTE = {"native": "#3fb950", "interpreter": "#f0883e", "vm": "#a371f7"}
KIND_ARCH = {"native": "native", "interp": "interpreter", "inproc-vm": "vm", "launcher": "vm"}
LANG_ARCH = {"elixir": "vm"}

# Column order + short headers (matches the README benchmark table's narrative order).
BENCH_ORDER = ["fannkuch", "binary-trees", "mandelbrot", "k-nucleotide", "reverse-complement",
               "sort-search", "dijkstra", "blur", "k-means", "sha256", "lz77", "vm", "bigint",
               "tak", "polymorphism", "gemm", "viterbi", "gbdt", "message-ring"]
# Shown as a column but EXCLUDED from the geomean/leaderboard ranking: the instruction count is
# blind to syscall cost, which inverts the wall-clock truth for context-switch primitives (C's
# swapcontext traps into the kernel ~2x per hop at near-zero guest-instruction cost). See
# docs/metric-validity.md and benchmarks/message-ring/README.md.
NOT_RANKED = {"message-ring"}
# Languages whose ratio is NOT ISA-robust (metric-validity Study 2: JVM codegen roughly doubles
# its ratio from arm64 to x86_64). Marked ‡ in the leaderboard + matrix so the single number is
# never read as ISA-independent.
ISA_SPECIFIC = {"kotlin", "scala", "java"}
# Axis families for the per-family geomean: the honest answer to "the 18 axes are not
# independent". Empirically (arm64, 18x18 pairwise Pearson on log ratios) 13 of the 18 axes sit
# in three families whose members correlate at r ~= 0.94-1.00, so the flat geomean effectively
# over-weights tight-loop execution; the family view casts one vote per runtime capability.
# Partition designed + validated by the algo-expert review (2026-07-17). Two flagged straddles:
# gemm sits in memory-loop-nest by design intent (cache pressure) though it still correlates
# with the arithmetic cluster at n2=256; viterbi sits in branchy-traversal (r=0.99-1.00 with
# its family) though its README frames the loop-carried dependency first.
FAMILY = {
    "fannkuch": "arith", "mandelbrot": "arith", "sha256": "arith", "bigint": "arith",
    "blur": "memnest", "gemm": "memnest", "k-means": "memnest", "reverse-complement": "memnest",
    "binary-trees": "allocgc",
    "k-nucleotide": "stdmap",
    "sort-search": "branchy", "lz77": "branchy", "gbdt": "branchy", "dijkstra": "branchy",
    "viterbi": "branchy",
    "vm": "dispatch", "tak": "dispatch", "polymorphism": "dispatch",
}
FAMILY_ORDER = ["arith", "memnest", "allocgc", "stdmap", "branchy", "dispatch"]
FAMILY_NAMES = {"arith": "arithmetic", "memnest": "memory loop nests",
                "allocgc": "allocation & GC", "stdmap": "stdlib hash map",
                "branchy": "branchy traversal", "dispatch": "calls & dispatch"}
SHORT = {"fannkuch": "fannkuch", "binary-trees": "binary-trees", "mandelbrot": "mandelbrot",
         "k-nucleotide": "k-nucleotide", "reverse-complement": "reverse-comp",
         "sort-search": "sort-search", "dijkstra": "dijkstra", "blur": "blur",
         "k-means": "k-means", "sha256": "sha256", "lz77": "lz77", "vm": "vm",
         "bigint": "bigint", "tak": "tak", "polymorphism": "polymorphism",
         "gemm": "gemm", "viterbi": "viterbi", "gbdt": "gbdt", "message-ring": "message-ring"}

# Diverging log-scale ramp on t = log10(ratio): green (beats C) → pale (ties) → YlOrRd (slower).
STOPS = [(-0.6, (35, 132, 67)), (-0.3, (65, 171, 93)), (-0.15, (173, 221, 142)),
         (0.0, (247, 252, 185)), (0.3, (255, 237, 160)), (0.7, (254, 217, 118)),
         (1.0, (254, 178, 76)), (1.7, (253, 141, 60)), (2.0, (252, 78, 42)),
         (3.0, (227, 26, 28)), (4.0, (177, 0, 38)), (5.4, (128, 0, 38))]
TLO, THI = STOPS[0][0], STOPS[-1][0]


def rgb_at(t):
    t = max(TLO, min(THI, t))
    for (t0, c0), (t1, c1) in zip(STOPS, STOPS[1:]):
        if t <= t1:
            f = (t - t0) / (t1 - t0) if t1 > t0 else 0.0
            return tuple(round(c0[i] + (c1[i] - c0[i]) * f) for i in range(3))
    return STOPS[-1][1]


def hexc(rgb):
    return "#%02x%02x%02x" % rgb


def cell_color(r):
    return rgb_at(math.log10(r))


def text_on(rgb):
    lum = 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]
    return "#0d1117" if lum > 150 else "#ffffff"


def fmt(r):
    if r < 10:
        return f"{r:.2f}"
    if r < 100:
        return f"{r:.1f}"
    if r < 1000:
        return f"{r:.0f}"
    if r < 10000:
        return f"{r / 1000:.1f}k"
    return f"{r / 1000:.0f}k"


def latest(b):
    fs = sorted(glob.glob(os.path.join(ROOT, "results", f"*-{ISA}-{b}.json")))
    return fs[-1] if fs else None


def load_matrix():
    """Return (langs_by_geomean, benches_present, ratio[lang][bench], geomean[lang], arch[lang])."""
    benches = [b for b in BENCH_ORDER if latest(b)]
    ratio, arch, extrap = {}, {}, set()
    for b in benches:
        env = json.load(open(latest(b)))
        rs = {r["language"]: r for r in env["results"] if r.get("i_n1") and r.get("i_n2")}
        cdiff = rs["c"]["differential"]
        for L, r in rs.items():
            ratio.setdefault(L, {})[b] = r["differential"] / cdiff
            arch[L] = LANG_ARCH.get(L) or KIND_ARCH.get(r.get("kind", "native"), "native")
            if "extrapolat" in (r.get("note") or "").lower():
                extrap.add((L, b))
    geomean, geomean_meas = {}, {}
    for L, row in ratio.items():
        vals = [row[b] for b in benches if b in row and b not in NOT_RANKED]
        geomean[L] = math.exp(sum(math.log(v) for v in vals) / len(vals))
        # the same geomean over directly-measured cells only (extrapolated cells dropped)
        mvals = [row[b] for b in benches
                 if b in row and b not in NOT_RANKED and (L, b) not in extrap]
        geomean_meas[L] = math.exp(sum(math.log(v) for v in mvals) / len(mvals))
    langs = sorted(ratio, key=lambda L: geomean[L])
    return langs, benches, ratio, geomean, geomean_meas, arch, extrap


def render_svg(langs, benches, ratio, geomean, arch, extrap):
    ranked = [b for b in benches if b not in NOT_RANKED]
    cw, ch = 50, 30          # cell width / height
    left, gap, ow = 86, 16, 60   # lang-label gutter, gap before OVERALL, OVERALL width
    title_h, head_h = 64, 88
    grid_x, grid_y = left, title_h + head_h
    grid_w = len(benches) * cw
    W = grid_x + grid_w + gap + ow + 18
    legend_h = 74 if any(b in NOT_RANKED for b in benches) else 56
    if any(L in ISA_SPECIFIC for L in langs):
        legend_h += 14
    H = grid_y + len(langs) * ch + legend_h + 16

    s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" '
         f'font-family="ui-sans-serif,system-ui,Segoe UI,Helvetica,Arial">']
    s.append(f'<rect width="{W}" height="{H}" rx="10" fill="{BG}"/>')
    s.append(f'<text x="22" y="34" font-size="19" font-weight="700" fill="{FG}">'
             f'Lang Lab · the matrix</text>')
    s.append(f'<text x="22" y="54" font-size="12.5" fill="{MUTED}">'
             f'real work vs C (= 1.00×, lower is better), differential I(n₂)−I(n₁) · qemu+insn · {ISA} · '
             f'sorted by geomean across {len(ranked)} compute axes († shown, not ranked)</text>')

    # rotated column headers
    for j, b in enumerate(benches):
        cx = grid_x + j * cw + cw / 2
        hdr = SHORT.get(b, b) + ("†" if b in NOT_RANKED else "")
        s.append(f'<text x="{cx:.1f}" y="{grid_y - 8}" font-size="11" fill="{MUTED}" '
                 f'text-anchor="start" transform="rotate(-45 {cx:.1f} {grid_y - 8})">'
                 f'{_xesc(hdr)}</text>')
    ox = grid_x + grid_w + gap + ow / 2
    s.append(f'<text x="{ox:.1f}" y="{grid_y - 8}" font-size="11" font-weight="700" fill="{FG}" '
             f'text-anchor="start" transform="rotate(-45 {ox:.1f} {grid_y - 8})">OVERALL</text>')

    # rows
    for i, L in enumerate(langs):
        y = grid_y + i * ch
        lab = NAMES.get(L, L) + ("‡" if L in ISA_SPECIFIC else "")
        s.append(f'<text x="{left - 12}" y="{y + ch / 2 + 4:.1f}" text-anchor="end" '
                 f'font-size="13" font-weight="600" fill="{PALETTE[arch[L]]}">{_xesc(lab)}</text>')
        for j, b in enumerate(benches):
            r = ratio[L].get(b)
            x = grid_x + j * cw
            if r is None:
                s.append(f'<rect x="{x}" y="{y}" width="{cw}" height="{ch}" fill="#161b22" '
                         f'stroke="{GRID}" stroke-width="1"/>')
                continue
            rgb = cell_color(r)
            s.append(f'<rect x="{x}" y="{y}" width="{cw}" height="{ch}" fill="{hexc(rgb)}" '
                     f'stroke="{GRID}" stroke-width="1"/>')
            mark = "*" if (L, b) in extrap else ""
            s.append(f'<text x="{x + cw / 2:.1f}" y="{y + ch / 2 + 4:.1f}" text-anchor="middle" '
                     f'font-size="10.5" font-weight="600" fill="{text_on(rgb)}">{fmt(r)}{mark}</text>')
        # OVERALL cell (geomean over ranked axes; * if any of them is extrapolated)
        g = geomean[L]
        rgb = cell_color(g)
        emark = "*" if any((L, b) in extrap for b in ranked) else ""
        s.append(f'<rect x="{grid_x + grid_w + gap}" y="{y}" width="{ow}" height="{ch}" '
                 f'fill="{hexc(rgb)}" stroke="{GRID}" stroke-width="1.5"/>')
        s.append(f'<text x="{grid_x + grid_w + gap + ow / 2:.1f}" y="{y + ch / 2 + 4:.1f}" '
                 f'text-anchor="middle" font-size="11.5" font-weight="700" '
                 f'fill="{text_on(rgb)}">{fmt(g)}×{emark}</text>')

    # legend: gradient bar + ticks
    ly = grid_y + len(langs) * ch + 26
    lx, lw = left, grid_w
    s.append('<defs><linearGradient id="ramp" x1="0" y1="0" x2="1" y2="0">')
    for t, c in STOPS:
        off = (t - TLO) / (THI - TLO)
        s.append(f'<stop offset="{off:.3f}" stop-color="{hexc(c)}"/>')
    s.append('</linearGradient></defs>')
    s.append(f'<rect x="{lx}" y="{ly}" width="{lw}" height="12" rx="3" fill="url(#ramp)"/>')
    for r, txt in [(0.3, "0.3×"), (1, "1× (C)"), (10, "10×"), (100, "100×"),
                   (1000, "1k×"), (100000, "100k×")]:
        off = (math.log10(r) - TLO) / (THI - TLO)
        tx = lx + off * lw
        s.append(f'<line x1="{tx:.1f}" y1="{ly}" x2="{tx:.1f}" y2="{ly + 12}" '
                 f'stroke="{BG}" stroke-width="1"/>')
        s.append(f'<text x="{tx:.1f}" y="{ly + 26}" text-anchor="middle" font-size="10" '
                 f'fill="{MUTED}">{txt}</text>')
    s.append(f'<text x="{lx + lw + gap}" y="{ly + 10}" font-size="10.5" fill="{MUTED}">'
             f'← beats C · slower →</text>')
    if extrap:
        s.append(f'<text x="{lx}" y="{ly + 42}" font-size="10" fill="{MUTED}">'
                 f'* extrapolated from small probes (not measured full-size)</text>')
    if any(b in NOT_RANKED for b in benches):
        s.append(f'<text x="{lx}" y="{ly + 56}" font-size="10" fill="{MUTED}">'
                 f'† shown but excluded from the geomean: instruction counts are syscall-blind, '
                 f'misleading for context-switch primitives (see the concurrency study)</text>')
    if any(L in ISA_SPECIFIC for L in langs):
        s.append(f'<text x="{lx}" y="{ly + 70}" font-size="10" fill="{MUTED}">'
                 f'‡ JVM ratios are ISA-specific (roughly 2× higher on x86_64, see '
                 f'docs/metric-validity.md); non-JVM rankings are ISA-robust</text>')
    s.append('</svg>')

    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "matrix.svg")
    with open(path, "w") as f:
        f.write("\n".join(s))
    print("wrote", os.path.relpath(path, ROOT))


def leaderboard_md(langs, benches, ratio, geomean, extrap):
    ranked = [b for b in benches if b not in NOT_RANKED]
    out = ["| # | Language | Overall (vs C) | Fastest axis | Slowest axis |",
           "|--:|----------|---------------:|--------------|--------------|"]
    for i, L in enumerate(langs, 1):
        name = NAMES.get(L, L) + ("‡" if L in ISA_SPECIFIC else "")
        if L == "c":
            out.append(f"| {i} | **C** _(baseline)_ | **1.00×** | — | — |")
            continue
        row = {b: ratio[L][b] for b in ranked if b in ratio[L]}
        best = min(row, key=row.get)
        worst = max(row, key=row.get)
        bmk = "*" if (L, best) in extrap else ""
        wmk = "*" if (L, worst) in extrap else ""
        emark = "*" if any((L, b) in extrap for b in ranked) else ""
        out.append(f"| {i} | {name} | **{fmt(geomean[L])}×{emark}** | "
                   f"{best} {fmt(row[best])}×{bmk} | {worst} {fmt(row[worst])}×{wmk} |")
    return "\n".join(out)


def family_md(langs, benches, ratio):
    """Per-family geomean table: one column per axis family, one equal vote per capability."""
    fams = [f for f in FAMILY_ORDER if any(FAMILY.get(b) == f for b in benches)]
    out = ["| Language | " + " | ".join(FAMILY_NAMES[f] for f in fams) + " |",
           "|---|" + "---:|" * len(fams)]
    for L in langs:
        cells = []
        for f in fams:
            vals = [ratio[L][b] for b in benches if b in ratio[L] and FAMILY.get(b) == f]
            if vals:
                g = math.exp(sum(math.log(v) for v in vals) / len(vals))
                cells.append(f"{fmt(g)}×")
            else:
                cells.append("—")
        name = NAMES.get(L, L) + ("‡" if L in ISA_SPECIFIC else "")
        if L == "c":
            name = "**C** _(baseline)_"
        out.append(f"| {name} | " + " | ".join(cells) + " |")
    members = " · ".join(
        f"{FAMILY_NAMES[f]} = " + ", ".join(b for b in BENCH_ORDER if FAMILY.get(b) == f)
        for f in fams)
    out.append(f"\n_Families: {members}._")
    return "\n".join(out)


def splice(block):
    path = os.path.join(ROOT, "README.md")
    txt = open(path, encoding="utf-8").read()
    a, b = "<!-- MATRIX:START -->", "<!-- MATRIX:END -->"
    if a not in txt or b not in txt:
        sys.exit(f"make_matrix: markers {a} / {b} not found in README.md")
    pre, rest = txt.split(a, 1)
    _, post = rest.split(b, 1)
    open(path, "w", encoding="utf-8").write(f"{pre}{a}\n{block}\n{b}{post}")
    print("spliced matrix block into README.md")


def main():
    langs, benches, ratio, geomean, geomean_meas, arch, extrap = load_matrix()
    ranked = [b for b in benches if b not in NOT_RANKED]
    render_svg(langs, benches, ratio, geomean, arch, extrap)
    lb = leaderboard_md(langs, benches, ratio, geomean, extrap)
    extrap_langs = sorted({L for (L, b) in extrap if b in ranked})
    foot = ""
    if extrap_langs:
        meas = ", ".join(f"{NAMES.get(L, L)} {fmt(geomean_meas[L])}×" for L in extrap_langs)
        foot = ("\n\n_* includes axes extrapolated from small probes (negligible-startup runtimes "
                f"only), not measured full-size. Over directly measured axes alone: {meas}._")
    excl = ""
    if any(b in NOT_RANKED for b in benches):
        excl = (" **message-ring is shown but not ranked**: its instruction count is syscall-blind "
                "and misleading for context-switch primitives (wall-clock inverts it; see "
                "[the concurrency study](docs/concurrency-study.md)).")
    if any(L in ISA_SPECIFIC for L in langs):
        foot += ("\n\n_‡ JVM ratios are ISA-specific: metric-validity Study 2 measured them "
                 "roughly doubling from arm64 to x86_64, so their single number holds for this "
                 "ISA only. Non-JVM rankings are ISA-robust "
                 "([details](docs/metric-validity.md))._")
    fam = family_md(langs, benches, ratio)
    famnote = ("\n\n**Per-family geomean.** The flat geomean above weights every axis equally, "
               "but the axes are not independent: 13 of the 18 sit in three families whose "
               "members correlate at r ≈ 0.94–1.00, so it over-weights tight-loop execution. "
               "This view casts one vote per runtime capability instead:\n\n" + fam)
    block = ("\n![Lang Lab — the matrix: every language × every benchmark]"
             "(docs/charts/matrix.svg)\n\n"
             "_Real work each language does vs the **C baseline** (= 1.00×), as the differential "
             f"`I(n₂)−I(n₁)` that cancels startup + JIT. **Lower is better** (less work than C). "
             f"Geomean across the {len(ranked)} compute axes; green cells beat or tie C.{excl} "
             "Full method below._\n\n"
             "<details><summary><b>Leaderboard</b> (sorted by overall geomean)</summary>\n\n"
             + lb + foot + famnote + "\n\n</details>\n")
    if "--write" in sys.argv:
        splice(block)
    else:
        print("\n" + lb)


if __name__ == "__main__":
    main()
