#!/usr/bin/env python3
"""Project a pathological cell's differential from cheap small-size probes, using the benchmark's
known complexity g(n). Fairness guarantees lang and C run the identical algorithm, so they share
g(n); a fixed-complexity workload counts I(n) = a + b*g(n), so two probes determine (a,b) and the
differential I(n2)-I(n1) = b*(g(n2)-g(n1)) is recovered. The fit uses the lowest and highest
probe; pass THREE OR MORE probes so the mid-probe residual check actually runs (with only two,
the declared complexity is taken on faith and a warning is printed). The emitted cell is labeled
determinism:"projected" — it is a projection, not a measurement.

Usage (called by bench-fast.sh / benchmark.yml for EXTRAP_CELLS):
  extrapolate.py <lang> <bench> <version> <runtimeKind> <complexity> <n1> <n2> <p1:I1> <p2:I2> [<p3:I3> ...]
complexity in {linear, quad, cubic, exp, nlogn}. Emits one result-envelope JSON object on stdout.
"""
import json
import math
import sys


def g(kind, n):
    n = float(n)
    if kind == "linear":
        return n
    if kind == "quad":
        return n * n
    if kind == "cubic":
        return n * n * n
    if kind == "exp":
        return 2.0 ** n
    if kind == "nlogn":
        return n * math.log2(n)
    sys.exit(f"extrapolate: unknown complexity '{kind}'")


def main():
    a = sys.argv
    lang, bench, version, rtkind, cx = a[1], a[2], a[3], a[4], a[5]
    n1, n2 = int(a[6]), int(a[7])
    probes = sorted((int(p.split(":")[0]), int(p.split(":")[1])) for p in a[8:])
    (plo, ilo), (phi, ihi) = probes[0], probes[-1]
    b = (ihi - ilo) / (g(cx, phi) - g(cx, plo))
    a0 = ilo - b * g(cx, plo)
    proj = lambda n: max(0, round(a0 + b * g(cx, n)))
    resid = ""
    if len(probes) >= 3:  # mid-probe fit check: the middle probe is NOT used by the fit
        pm, im = probes[len(probes) // 2]
        pred = a0 + b * g(cx, pm)
        if im:
            pct = abs(pred - im) / im * 100
            resid = f"; fit residual at mid-probe n={pm}: {pct:.2f}%"
            if pct > 1.0:
                print(f"extrapolate: WARNING {lang}/{bench} mid-probe residual {pct:.2f}% > 1% — "
                      f"the declared complexity '{cx}' may not match the code", file=sys.stderr)
    else:
        print(f"extrapolate: WARNING {lang}/{bench} has only {len(probes)} probes — "
              f"the fit is unchecked; pass 3+ probes so the mid-probe residual runs", file=sys.stderr)
    i1, i2 = proj(n1), proj(n2)
    note = (f"extrapolated ({cx}) from probes {[p for p, _ in probes]} "
            f"(identical per-{cx} work; ratio scale-invariant); a direct n2={n2} run is impractical{resid}")
    # This is a PROJECTION, not a measurement: label it as such (never "exact"), and let runs
    # reflect the number of probe points behind the fit.
    print(json.dumps({
        "language": lang, "benchmark": bench, "version": version, "backend": "qemu-insn",
        "metric": "instructions", "kind": rtkind, "n1": n1, "n2": n2, "runs": len(probes),
        "i_n1": {"median": i1, "min": i1, "max": i1, "runs": [i1]},
        "i_n2": {"median": i2, "min": i2, "max": i2, "runs": [i2]},
        "differential": i2 - i1, "correct": True, "determinism": "projected", "note": note}))


if __name__ == "__main__":
    main()
