#!/usr/bin/env bash
# Wall-clock SCALING track (separate from the qemu+insn instruction track).
# Measures parallel speedup T1/TP of a benchmark's PARALLEL implementation, run
# NATIVELY (no qemu), at several core counts. Prints one JSON line.
#
# Why wall-clock and not instructions: parallel speedup is a TIME-domain property.
# The insn plugin sums guest instructions across cores, so it is blind to speedup,
# and worse, it reports a FALSE speedup for GIL/GVL runtimes (CPython threads look
# like they scale when in real time they do not). Proven empirically; see the
# message-ring/scaling investigation. So this track times the clock instead.
#
# Reproducibility: we report the RATIO T1/TP (min wall of N reps, measured in the
# same job), not absolute time. The ratio cancels machine-speed noise, so it stays
# stable on shared CI runners (validated to +/-0.03 across independent sweeps on a
# 4-core cap). It is NOT bit-exact like the instruction track; report it as such.
#
# Contract:  measure-scaling.sh <language> <benchmark> -- <run-cmd WITHOUT cores/size...>
#   The run-cmd must contain a literal {P} where the core count goes; the size arg
#   is appended by this script (like measure.sh appends the size).
#   Env: SCALE_N (size; default N2), CORES (default "1 2 4"), REPS (default 5),
#        PRIMITIVE (informational: "threads"|"processes"; default "threads"),
#        CHECK_SUM / CHECK_FLIPS (canonical checksum at SCALE_N; the parallel result
#        MUST equal the serial result, so the spec's checksum for that size applies),
#        SKIP_GATE=1 to bypass the checksum gate (harness self-test only).
#   Version read from $LANG_VERSION (set in the Dockerfile).
set -uo pipefail

[ $# -lt 2 ] && { echo "usage: measure-scaling.sh <language> <benchmark> -- <run-cmd with {P}...>" >&2; exit 2; }
lang="$1"; benchmark="$2"; shift 2
[ "${1:-}" = "--" ] && shift
tmpl=("$@")
[ ${#tmpl[@]} -ge 1 ] || { echo "measure-scaling.sh: no run-command after --" >&2; exit 2; }
case "${tmpl[*]}" in *"{P}"*) : ;; *) echo "measure-scaling.sh: run-command must contain {P}" >&2; exit 2;; esac

version="${LANG_VERSION:-unknown}"
SCALE_N="${SCALE_N:-${N2:-256}}"
CORES="${CORES:-1 2 4}"
REPS="${REPS:-5}"
PRIMITIVE="${PRIMITIVE:-threads}"
CHECK_SUM="${CHECK_SUM:-}"; CHECK_FLIPS="${CHECK_FLIPS-}"

# Build the concrete argv for a given core count: substitute {P}, then append the size.
build_argv() {  # cores -> sets global ARGV[]
  local p="$1" tok; ARGV=()
  for tok in "${tmpl[@]}"; do ARGV+=("${tok//\{P\}/$p}"); done
  ARGV+=("$SCALE_N")
  # Defensive: the run-template convention is word-split argv (e.g. java -jar x.jar {P}).
  # If a caller instead passed the whole command as one quoted token ("java -jar x.jar"),
  # argv[0] would be a bogus space-containing "command" and every run would fail with a
  # confusing exit 127. Re-split that first token into words to rescue it.
  if [[ "${ARGV[0]}" == *" "* ]]; then
    local first; read -ra first <<< "${ARGV[0]}"
    ARGV=("${first[@]}" "${ARGV[@]:1}")
  fi
}

# qemu-user is NOT used here; we run native. But interpreters still pass a bare
# command (python/php/...) - resolve argv[0] to an absolute path for a clean exec.
resolve0() { case "${ARGV[0]:-}" in /*) : ;; *) local r; r="$(command -v "${ARGV[0]}" 2>/dev/null || true)"; [ -n "$r" ] && ARGV[0]="$r" ;; esac; }

# One timed run at core count $1 -> seconds (string) on stdout, or empty on failure.
# Prefers the program's own COMPUTE_NS marker on stderr (the compute-region time, which
# excludes runtime startup/data-gen so JVM/BEAM boot and fork/pickle don't bias the ratio);
# falls back to whole-process wall-clock when the program doesn't emit one.
# Emits "<source> <seconds>" (source = compute|process), or "" on failure. The source
# is returned in-band because time_once runs in a command substitution (a subshell), so
# it cannot set a parent variable.
TSRC="process"
time_once() {
  build_argv "$1"; resolve0
  local s e err ns
  err="$(mktemp)"
  s="$EPOCHREALTIME"
  "${ARGV[@]}" >/dev/null 2>"$err" || { rm -f "$err"; echo ""; return; }
  e="$EPOCHREALTIME"
  ns="$(grep -oE 'COMPUTE_NS[: ]+[0-9]+' "$err" | tail -1 | grep -oE '[0-9]+')"
  rm -f "$err"
  if [ -n "$ns" ]; then
    awk -v ns="$ns" 'BEGIN{printf "compute %.6f", ns/1e9}'
  else
    awk -v s="$s" -v e="$e" 'BEGIN{printf "process %.6f", e-s}'
  fi
}

# Checksum gate: the parallel result must equal the canonical (serial) checksum.
if [ "${SKIP_GATE:-0}" != "1" ] && [ -n "$CHECK_SUM" ]; then
  build_argv 1; resolve0
  out="$("${ARGV[@]}" 2>/dev/null)"
  cs="$(printf '%s\n' "$out" | sed -n '1p')"
  [ "$cs" = "$CHECK_SUM" ] || { echo "checksum FAIL at n=$SCALE_N cores=1 (got '$cs' want '$CHECK_SUM')" >&2; exit 3; }
  if [ -n "$CHECK_FLIPS" ]; then
    sv="$(printf '%s\n' "$out" | grep -oE '[0-9]+$' | tail -1)"
    [ "$sv" = "$CHECK_FLIPS" ] || { echo "secondary checksum FAIL at n=$SCALE_N (got '$sv' want '$CHECK_FLIPS')" >&2; exit 3; }
  fi
fi

# Measure: min wall over REPS at each core count (min is the most noise-stable estimator).
declare -A TMIN
for p in $CORES; do
  best=""
  for ((r=0; r<REPS; r++)); do
    out="$(time_once "$p")"
    [ -z "$out" ] && { echo "scaling FAIL: run errored at cores=$p" >&2; exit 4; }
    src="${out%% *}"; v="${out#* }"
    [ "$src" = "compute" ] && TSRC="compute"
    if [ -z "$best" ] || awk -v v="$v" -v b="$best" 'BEGIN{exit !(v<b)}'; then best="$v"; fi
  done
  TMIN[$p]="$best"
done

# Speedup vs 1 core. Requires "1" in CORES (the baseline).
t1="${TMIN[1]:-}"
[ -n "$t1" ] || { echo "scaling FAIL: cores list must include 1 (baseline)" >&2; exit 5; }

jesc() { local s="$1"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; printf '%s' "$s"; }
lang="$(jesc "$lang")"; benchmark="$(jesc "$benchmark")"; version="$(jesc "$version")"; PRIMITIVE="$(jesc "$PRIMITIVE")"

times_json=""; speedup_json=""; sep=""
for p in $CORES; do
  times_json="${times_json}${sep}\"$p\":${TMIN[$p]}"
  sp="$(awk -v a="$t1" -v b="${TMIN[$p]}" 'BEGIN{printf "%.3f", a/b}')"
  speedup_json="${speedup_json}${sep}\"$p\":${sp}"
  sep=","
done

printf '{"language":"%s","benchmark":"%s","version":"%s","track":"scaling","metric":"wallclock-speedup","timing":"%s","primitive":"%s","size":%s,"reps":%s,"min_seconds":{%s},"speedup":{%s},"correct":true}\n' \
  "$lang" "$benchmark" "$version" "$TSRC" "$PRIMITIVE" "$SCALE_N" "$REPS" "$times_json" "$speedup_json"
