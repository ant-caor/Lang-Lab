#!/usr/bin/env bash
# Measure deterministic guest-instruction count under qemu-user + the TCG `insn`
# plugin. Runs inside each language image; prints one JSON line.
#
# Contract:  measure.sh <language> <benchmark> -- <run-cmd WITHOUT size...>
# Sizes and run-count come from env; measure.sh appends the size argument itself.
#   N1 (default 7), N2 (default 9), RUNS (default 5)
#   RUNTIME_KIND = native|interp|inproc-vm|launcher   (launcher → sum child procs)
#   QEMU (default /opt/qi/qemu-aarch64), PLUGIN (default /opt/qi/libinsn.so), QEMU_LIB (/opt/qi/lib)
#   CHECK{1,2}_SUM / CHECK{1,2}_FLIPS  expected checksums (MUST match N1/N2)
# Version read from $LANG_VERSION (set in the Dockerfile).
set -uo pipefail

[ $# -lt 2 ] && { echo "usage: measure.sh <language> <benchmark> -- <run-cmd...>" >&2; exit 2; }
lang="$1"; benchmark="$2"; shift 2
[ "${1:-}" = "--" ] && shift
runcmd=("$@")
[ ${#runcmd[@]} -ge 1 ] || { echo "measure.sh: no run-command after --" >&2; exit 2; }

# qemu-user does NOT PATH-resolve a bare command name (it just fails, silently,
# exit 1). Native runs pass an absolute path already; interpreters/VMs pass a bare
# command (python, java, elixir, …) - resolve argv[0] to an absolute path here.
case "${runcmd[0]:-}" in
  /*) : ;;
  *) _resolved="$(command -v "${runcmd[0]}" 2>/dev/null || true)"
     [ -n "$_resolved" ] && runcmd[0]="$_resolved" ;;
esac

version="${LANG_VERSION:-unknown}"
N1="${N1:-7}"; N2="${N2:-9}"
# Adaptive RUNS: when RUNS is not pinned, probe with RUNS_LOW reps and escalate to RUNS_HIGH only
# if the language jitters (a bit-exact language is proven deterministic in RUNS_LOW reps). An
# explicit RUNS disables adaptation. The differential is identical to a fixed run for deterministic
# languages, and uses >= as many reps for jittery ones.
RUNS_FIXED="${RUNS:+1}"
RUNS_LOW="${RUNS_LOW:-2}"; RUNS_HIGH="${RUNS_HIGH:-5}"
RUNS="${RUNS:-$RUNS_HIGH}"
QEMU="${QEMU:-/opt/qi/qemu-aarch64}"
PLUGIN="${PLUGIN:-/opt/qi/libinsn.so}"
QEMU_LIB="${QEMU_LIB:-/opt/qi/lib}"   # bundled shared-lib closure (libcapstone, libglib, …)
KIND="${RUNTIME_KIND:-native}"
CHECK1_SUM="${CHECK1_SUM:-228}";   CHECK1_FLIPS="${CHECK1_FLIPS-16}"
CHECK2_SUM="${CHECK2_SUM:-8629}"; CHECK2_FLIPS="${CHECK2_FLIPS-30}"
# `-` (not `:-`): an explicitly-empty CHECK*_FLIPS (benchmarks with a single checksum)
# stays empty and skips the secondary check; only an UNSET var falls back to fannkuch's.

# %.0f (not %d): instruction counts exceed 2^31, and mawk's `printf "%d"` saturates
# there. %.0f formats the double directly - exact up to 2^53, far above any count.
median() { printf '%s\n' "$@" | sort -n | awk '{a[NR]=$1} END{m=int((NR+1)/2); if(NR%2)printf "%.0f\n",a[m]; else printf "%.0f\n",int((a[NR/2]+a[NR/2+1]+1)/2)}'; }
minv()   { printf '%s\n' "$@" | sort -n | head -1; }
maxv()   { printf '%s\n' "$@" | sort -n | tail -1; }
csv()    { local IFS=,; echo "$*"; }

# Checksum gate: run the program plain (no qemu - fast) and confirm correctness.
# Line 1 must equal the expected checksum; the secondary value is checked only if given
# (fannkuch uses Pfannkuchen(n); benchmarks with a single checksum pass "" to skip it).
validate() {  # n expected_sum expected_secondary("" = skip)
  local out cs sv
  # Gate on OUTPUT, not exit status: correctness is proven by line 1 == expected
  # checksum. Under memory pressure an interpreter/JVM/BEAM can be OOM-reaped at
  # teardown AFTER printing the right answer (non-zero exit) - that must not false-FAIL.
  # A real crash before output leaves line 1 empty/wrong, so it still fails correctly.
  out="$("${runcmd[@]}" "$1" 2>/dev/null)"
  cs="$(printf '%s\n' "$out" | sed -n '1p')"
  [ "$cs" = "$2" ] || return 1
  [ -z "$3" ] && return 0
  sv="$(printf '%s\n' "$out" | grep -oE '[0-9]+$' | tail -1)"
  [ "$sv" = "$3" ]
}

# Stderr + exit code of the most recent guest run, kept so a failed count can be diagnosed
# (the qemu plugin writes "total insns" to stderr; a crash/OOM leaves its trace there too).
RUN_ERR="$(mktemp)"; RUN_RC=0
trap 'rm -f "$RUN_ERR"' EXIT

# One instruction count at size $1 (summed over processes for launcher runtimes).
count_once() {
  local n="$1"
  # No LD_LIBRARY_PATH: qemu finds its bundled libs via RPATH ($ORIGIN/lib), so the
  # emulated guest's library resolution stays clean (else interpreters/VMs break).
  # GLIBC_TUNABLES disables glibc's rseq registration, which qemu-user 7.2 doesn't
  # emulate - without it CPython/Perl/PHP/JVM/BEAM crash silently at startup.
  RUN_RC=0
  GLIBC_TUNABLES="glibc.pthread.rseq=0" \
    "$QEMU" -plugin "$PLUGIN" -d plugin "${runcmd[@]}" "$n" >/dev/null 2>"$RUN_ERR" || RUN_RC=$?
  if [ "$KIND" = "launcher" ]; then
    awk '/total insns/ {s+=$3} END{print s+0}' "$RUN_ERR"
  else
    awk '/total insns/ {print $3; exit}' "$RUN_ERR"
  fi
}

# RUNS measurements at size $1 -> "median min max csv"
measure_size() {
  local n="$1" vals=() i v
  for ((i=0; i<RUNS; i++)); do
    v="$(count_once "$n")"
    if ! [ "${v:-0}" -gt 0 ] 2>/dev/null; then
      echo "measure FAIL: no instruction count at n=$n (kind=$KIND, run exit=${RUN_RC:-?})" >&2
      echo "  exit hint: 137≈OOM-kill (SIGKILL), 139=SIGSEGV, 132=SIGILL, 134=SIGABRT; run stderr tail:" >&2
      tail -n 12 "$RUN_ERR" 2>/dev/null | sed 's/^/    /' >&2
      exit 4
    fi
    vals+=("$v")
  done
  echo "$(median "${vals[@]}") $(minv "${vals[@]}") $(maxv "${vals[@]}") $(csv "${vals[@]}")"
}

# Checksum gate (native runs). Decoupled for the parallel driver:
#   SKIP_GATE=1 -> assume already gated elsewhere; go straight to counting (the parallel phase)
#   GATE_ONLY=1 -> validate both sizes and exit 0 (the serial gate phase)
# The guest instruction count is contention-immune, so only this native gate must run serially.
if [ "${SKIP_GATE:-0}" != "1" ]; then
  validate "$N1" "$CHECK1_SUM" "$CHECK1_FLIPS" || { echo "checksum FAIL at n=$N1" >&2; exit 3; }
  validate "$N2" "$CHECK2_SUM" "$CHECK2_FLIPS" || { echo "checksum FAIL at n=$N2" >&2; exit 3; }
fi
[ "${GATE_ONLY:-0}" = "1" ] && { echo "gate OK"; exit 0; }

# Measure both sizes (sets m/lo/hi/cs globals). Adaptive: probe at RUNS_LOW, escalate on jitter.
measure_both() {
  local o1 o2
  o1="$(measure_size "$N1")" || exit $?; read -r m1 lo1 hi1 cs1 <<<"$o1"
  o2="$(measure_size "$N2")" || exit $?; read -r m2 lo2 hi2 cs2 <<<"$o2"
}
if [ -n "$RUNS_FIXED" ]; then
  measure_both
else
  RUNS="$RUNS_LOW"; measure_both
  if ! { [ "$lo1" = "$hi1" ] && [ "$lo2" = "$hi2" ]; }; then RUNS="$RUNS_HIGH"; measure_both; fi
fi

diff=$(( m2 - m1 ))
# A single run can't prove determinism, so don't claim "exact" with RUNS<2.
if [ "$RUNS" -lt 2 ]; then det="single-run"
elif [ "$lo1" = "$hi1" ] && [ "$lo2" = "$hi2" ]; then det="exact"
else det="jitter"; fi

# Escape string fields so a stray quote/backslash can't produce invalid JSON.
jesc() { local s="$1"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; printf '%s' "$s"; }
lang="$(jesc "$lang")"; benchmark="$(jesc "$benchmark")"; version="$(jesc "$version")"; KIND="$(jesc "$KIND")"

printf '{"language":"%s","benchmark":"%s","version":"%s","backend":"qemu-insn","metric":"instructions","kind":"%s","n1":%s,"n2":%s,"runs":%s,"i_n1":{"median":%s,"min":%s,"max":%s,"runs":[%s]},"i_n2":{"median":%s,"min":%s,"max":%s,"runs":[%s]},"differential":%s,"correct":true,"determinism":"%s"}\n' \
  "$lang" "$benchmark" "$version" "$KIND" "$N1" "$N2" "$RUNS" \
  "$m1" "$lo1" "$hi1" "$cs1" "$m2" "$lo2" "$hi2" "$cs2" "$diff" "$det"
