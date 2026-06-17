#!/usr/bin/env bash
# Build a per-(date, isa, benchmark) results envelope from a stream of measure.sh
# JSON lines (one per language), matching the CI `collect` job's output exactly.
#
#   scripts/bench-local.sh > /tmp/run.jsonl          # produce the per-language lines
#   scripts/collect-local.sh binary-trees arm64 < /tmp/run.jsonl
#
# Reads benchmarks/<benchmark>/spec.json for n1/n2 + the reference checksums, keeps
# only valid lines for THAT benchmark (drops other benchmarks and {"error":…} stubs),
# and writes results/<date>-<isa>-<benchmark>.json. Date defaults to today (UTC).
set -euo pipefail
cd "$(dirname "$0")/.."

bench="${1:?usage: collect-local.sh <benchmark> <isa> [date] < results.jsonl}"
isa="${2:?usage: collect-local.sh <benchmark> <isa> [date] < results.jsonl}"
date="${3:-$(date -u +%Y-%m-%d)}"

spec="benchmarks/$bench/spec.json"
[ -f "$spec" ] || { echo "collect-local: no spec at $spec" >&2; exit 1; }
n1="$(jq -r .n1 "$spec")"; n2="$(jq -r .n2 "$spec")"

mkdir -p results
out="results/${date}-${isa}-${bench}.json"
jq -s --arg b "$bench" --arg date "$date" --arg isa "$isa" \
   --argjson n1 "$n1" --argjson n2 "$n2" --slurpfile spec "$spec" \
   '{benchmark:$b, date:$date, backend:"qemu-insn", isa:$isa, n1:$n1, n2:$n2, runs:5,
     checksums:$spec[0].checksums,
     results: [ .[] | select(.benchmark==$b and (has("error")|not)) ]}' \
   > "$out"
echo "collect-local: wrote $out ($(jq '.results|length' "$out") languages)" >&2
