#!/usr/bin/env bash
# Fast parallel measurement driver.
#   1) build the qemu base + each language image ONCE (build-once)
#   2) GATE phase: validate every (lang,bench) checksum SERIALLY (cheap native runs, no OOM risk)
#   3) COUNT phase: run every (lang,bench) qemu instruction-count in PARALLEL -- the guest
#      instruction count is contention-immune (deterministic regardless of host load), so only
#      the native gate must be serial. Wall-clock drops from sum-of-cells to ~slowest-cell.
#   4) merge per-(date,isa,bench) envelopes + regenerate charts.
#
#   scripts/bench-fast.sh                  # all languages x all benchmarks
#   scripts/bench-fast.sh rust go          # a subset of languages
#   PAR=8 BENCH=sha256 scripts/bench-fast.sh c   # cap parallelism / one benchmark
# Honors the adaptive RUNS in measure.sh (set RUNS to pin). Pathological cells can be handed to
# scripts/extrapolate.sh separately.
set -uo pipefail
cd "$(dirname "$0")/.."

ISA="${ISA:-arm64}"; STAMP="$(date +%Y-%m-%d)"
# PAR caps memory pressure (qemu + heaps). PAR_JIT is the JIT/GC batch: those runtimes (JVM/CLR/
# BEAM) re-JIT/re-GC under load, so their instruction count SHIFTS with contention (and they OOM).
# They are measured at low/serial parallelism to match the canonical low-load values.
PAR="${PAR:-6}"; PAR_JIT="${PAR_JIT:-1}"
[ "$PAR" -lt 1 ] && PAR=2
LOGD="$(mktemp -d)"; RES="${RESDIR:-results}"; mkdir -p "$RES"
echo ">> bench-fast: PAR=$PAR  logs=$LOGD" >&2

if [ $# -ge 1 ]; then langs=("$@"); else langs=($(jq -r 'keys[]' languages.json)); fi
if [ -n "${BENCH:-}" ]; then benches=("$BENCH")
else benches=($(find benchmarks -name spec.json | sed 's:^benchmarks/::; s:/spec.json$::' | sort)); fi

# --- run one cell. mode=gate -> GATE_ONLY (exit nonzero on checksum fail); mode=count -> SKIP_GATE
run_cell() {
  local mode="$1" L="$2" B="$3"
  local kind tmpl wrap runcmd spec n1 n2 c1 s1 c2 s2
  kind=$(jq -r --arg l "$L" '.[$l].runtimeKind // "native"' languages.json)
  tmpl=$(jq -r --arg l "$L" '.[$l].run' languages.json)
  wrap=$(jq -r --arg l "$L" '.[$l].launchWrap // false' languages.json)
  spec="benchmarks/$B/spec.json"
  n1=$(jq -r .n1 "$spec"); n2=$(jq -r .n2 "$spec")
  c1=$(jq -r '.checksums.n1.sum' "$spec"); s1=$(jq -r '.checksums.n1.secondary // ""' "$spec")
  c2=$(jq -r '.checksums.n2.sum' "$spec"); s2=$(jq -r '.checksums.n2.secondary // ""' "$spec")
  runcmd="${tmpl//\{b\}/$B}"
  local envf=()
  while IFS=$'\t' read -r k v; do [ -n "$k" ] && envf+=(-e "$k=$v"); done < <(
    jq -r --arg l "$L" '.[$l].runtimeEnv // {} | to_entries[] | "\(.key)\t\(.value)"' languages.json)
  local override
  if [ "$wrap" = "true" ]; then
    override=(sh -c "set -a; . /app/beam-launch; exec /usr/local/bin/measure.sh $L $B -- $runcmd")
  else
    override=(/usr/local/bin/measure.sh "$L" "$B" -- $runcmd)
  fi
  local redir="$RES/${STAMP}__result-$L-$B.json"
  [ "$mode" = "gate" ] && redir="/dev/null"
  # Extrapolation for pathological cells (count phase only): EXTRAP_CELLS="lang:bench:complexity:p1:p2 ..."
  # Probe two small sizes and project via g(n). The native gate still ran at the real spec sizes.
  # ONLY valid for runtimes with negligible startup (COBOL/native): a JIT/GC VM (JVM/CLR/BEAM) has a
  # large startup baseline that dominates tiny probes, so the projected work collapses to ~0. Use it
  # for COBOL only.
  if [ "$mode" = "count" ]; then
    local ex="" c
    for c in ${EXTRAP_CELLS:-}; do case "$c" in "$L:$B:"*) ex="$c";; esac; done
    if [ -n "$ex" ]; then
      local cx ver probes pa pb pout ia ib
      local pargs=()
      cx=$(printf '%s' "$ex"|cut -d: -f3)
      probes=$(printf '%s' "$ex"|cut -d: -f4-|tr ':' ' ')
      ver=$(jq -r --arg l "$L" '.[$l]' versions.lock.json)
      # Measure consecutive probe pairs (measure.sh takes two sizes per run). Pass 3+ probes so
      # extrapolate.py can run its mid-probe fit check instead of taking the complexity on faith.
      set -- $probes
      while [ $# -ge 2 ]; do
        pa="$1"; pb="$2"
        pout=$(docker run --rm -e SKIP_GATE=1 -e RUNS=1 -e RUNTIME_KIND="$kind" -e N1="$pa" -e N2="$pb" \
          ${envf[@]+"${envf[@]}"} "lang-lab-$L" "${override[@]}" 2>>"$LOGD/extrap-$L-$B.err")
        ia=$(printf '%s' "$pout"|jq -r '.i_n1.median'); ib=$(printf '%s' "$pout"|jq -r '.i_n2.median')
        [ "${#pargs[@]}" -eq 0 ] && pargs+=("$pa:$ia")
        pargs+=("$pb:$ib")
        shift
      done
      python3 scripts/extrapolate.py "$L" "$B" "$ver" "$kind" "$cx" "$n1" "$n2" "${pargs[@]}" \
        > "$redir" 2>>"$LOGD/extrap-$L-$B.err"
      return
    fi
  fi
  local gateflag="-e SKIP_GATE=1"
  [ "$mode" = "gate" ] && gateflag="-e GATE_ONLY=1"
  docker run --rm $gateflag \
    -e RUNTIME_KIND="$kind" -e N1="$n1" -e N2="$n2" \
    -e CHECK1_SUM="$c1" -e CHECK1_FLIPS="$s1" -e CHECK2_SUM="$c2" -e CHECK2_FLIPS="$s2" \
    ${envf[@]+"${envf[@]}"} "lang-lab-$L" "${override[@]}" > "$redir" 2>"$LOGD/$mode-$L-$B.err"
}

# 1) build base + per-language images once
echo ">> build qemu base" >&2
docker build -q -f languages/_base/Dockerfile.qemu-insn -t lang-lab-qemu-insn . >&2
for L in "${langs[@]}"; do
  ver=$(jq -r --arg l "$L" '.[$l]' versions.lock.json)
  arg=$(jq -r --arg l "$L" '.[$l].buildArg' languages.json)
  echo ">> build $L $ver" >&2
  docker build -q -f "languages/$L/Dockerfile" --build-arg "${arg}=${ver}" -t "lang-lab-$L" . >&2 \
    || { echo "!! BUILD FAIL $L" >&2; exit 10; }
done

# 2) GATE phase (serial; cheap native runs; abort before counting on any failure)
echo ">> gate (serial)" >&2
gate_fail=0
for L in "${langs[@]}"; do for B in "${benches[@]}"; do
  # spec-declared N/A cells (e.g. message-ring for perl/cobol: no cooperative primitive)
  if jq -e --arg l "$L" '.na // [] | index($l)' "benchmarks/$B/spec.json" >/dev/null; then
    echo "   skip $L/$B (N/A per spec)" >&2; continue
  fi
  # extrap cells are projected from small probes; their full-size NATIVE gate is itself slow, and
  # their checksum was verified when the spec was bootstrapped, so skip the gate for them.
  skip=0; for ec in ${EXTRAP_CELLS:-}; do case "$ec" in "$L:$B:"*) skip=1;; esac; done
  [ "$skip" = 1 ] && { echo "   skip gate $L/$B (extrapolated)" >&2; continue; }
  if run_cell gate "$L" "$B"; then :; else
    echo "!! GATE FAIL $L/$B :: $(tail -1 "$LOGD/gate-$L-$B.err" 2>/dev/null)" >&2; gate_fail=1
  fi
done; done
[ "$gate_fail" = 1 ] && { echo "!! gate failures above; fix checksums before counting" >&2; exit 3; }
echo "   all gates OK" >&2

# 3) COUNT phase. Partition langs: native + interpreters are contention-immune (count value is
# deterministic regardless of host load) -> full parallel. JIT/GC VMs (inproc-vm + elixir/BEAM)
# shift their count under load -> low/serial parallelism. Polling semaphore (bash 3.2 safe).
parsafe=(); jitgc=()
for L in "${langs[@]}"; do
  k=$(jq -r --arg l "$L" '.[$l].runtimeKind // "native"' languages.json)
  if [ "$k" = "inproc-vm" ] || [ "$L" = "elixir" ]; then jitgc+=("$L"); else parsafe+=("$L"); fi
done
count_batch() { # par_limit langs...
  local p="$1"; shift; local L B
  for L in "$@"; do for B in "${benches[@]}"; do
    jq -e --arg l "$L" '.na // [] | index($l)' "benchmarks/$B/spec.json" >/dev/null && continue
    while [ "$(jobs -rp | wc -l)" -ge "$p" ]; do sleep 0.3; done
    run_cell count "$L" "$B" &
  done; done
  wait
}
echo ">> count native+interp (PAR=$PAR): ${parsafe[*]:-none}" >&2
[ "${#parsafe[@]}" -gt 0 ] && count_batch "$PAR" "${parsafe[@]}"
echo ">> count JIT/GC at low contention (PAR=$PAR_JIT): ${jitgc[*]:-none}" >&2
[ "${#jitgc[@]}" -gt 0 ] && count_batch "$PAR_JIT" "${jitgc[@]}"
echo "   counting done" >&2

# 4) merge per-(date,isa,bench) envelopes + charts
echo ">> merge envelopes + charts" >&2
for B in "${benches[@]}"; do
  spec="benchmarks/$B/spec.json"
  n1=$(jq -r .n1 "$spec"); n2=$(jq -r .n2 "$spec")
  files=("$RES/${STAMP}__result-"*"-$B.json")
  # keep only non-empty result files
  ok=(); for f in "${files[@]}"; do [ -s "$f" ] && jq -e .differential "$f" >/dev/null 2>&1 && ok+=("$f"); done
  [ "${#ok[@]}" -gt 0 ] || { echo "   no results for $B" >&2; continue; }
  # envelope-level runs = the max any cell actually ran (adaptive RUNS: 2 for bit-exact, 5 on jitter)
  jq -s --arg b "$B" --arg date "$STAMP" --arg isa "$ISA" \
     --argjson n1 "$n1" --argjson n2 "$n2" --slurpfile spec "$spec" \
     '{benchmark:$b, date:$date, backend:"qemu-insn", isa:$isa, n1:$n1, n2:$n2,
       runs:(map(.runs // empty) | max), checksums:$spec[0].checksums, results: .}' \
     "${ok[@]}" > "$RES/${STAMP}-${ISA}-${B}.json"
  [ "${CHARTS:-1}" = "1" ] && { python3 scripts/make_charts.py "$RES/${STAMP}-${ISA}-${B}.json" >/dev/null 2>&1 || true; }
  echo "   $B: ${#ok[@]} langs -> $RES/${STAMP}-${ISA}-${B}.json" >&2
done
rm -f "$RES/${STAMP}__result-"*.json
echo ">> DONE" >&2
