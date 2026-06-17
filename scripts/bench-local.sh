#!/usr/bin/env bash
# Build + measure languages × benchmarks locally under qemu-user + the insn plugin.
# Requires Docker.
#   scripts/bench-local.sh            # all languages × all benchmarks
#   scripts/bench-local.sh rust       # one language × all benchmarks
#   BENCH=binary-trees scripts/bench-local.sh rust   # one × one
# Tunable: RUNS (default 5). N1/N2/checksums come from each benchmarks/<b>/spec.json.
set -euo pipefail
cd "$(dirname "$0")/.."

# 1) Build the shared qemu-insn base (provides qemu + plugin + lib bundle to every image).
echo ">> building qemu-insn base" >&2
docker build -q -f languages/_base/Dockerfile.qemu-insn -t lang-lab-qemu-insn . >&2

if [ $# -ge 1 ]; then langs=("$1"); else mapfile -t langs < <(jq -r 'keys[]' languages.json); fi
if [ -n "${BENCH:-}" ]; then
  benches=("$BENCH")
else
  mapfile -t benches < <(find benchmarks -name spec.json | sed 's:^benchmarks/::; s:/spec.json$::' | sort)
fi

for lang in "${langs[@]}"; do
  version="$(jq -r --arg l "$lang" '.[$l]' versions.lock.json)"
  arg="$(jq -r --arg l "$lang" '.[$l].buildArg' languages.json)"
  kind="$(jq -r --arg l "$lang" '.[$l].runtimeKind // "native"' languages.json)"
  run_tmpl="$(jq -r --arg l "$lang" '.[$l].run' languages.json)"
  wrap="$(jq -r --arg l "$lang" '.[$l].launchWrap // false' languages.json)"
  echo ">> building $lang $version" >&2
  docker build -q -f "languages/$lang/Dockerfile" --build-arg "${arg}=${version}" -t "lang-lab-$lang" . >&2

  envflags=()
  while IFS=$'\t' read -r k v; do
    [ -n "$k" ] && envflags+=(-e "$k=$v")
  done < <(jq -r --arg l "$lang" '.[$l].runtimeEnv // {} | to_entries[] | "\(.key)\t\(.value)"' languages.json)

  for bench in "${benches[@]}"; do
    spec="benchmarks/$bench/spec.json"
    [ -f "$spec" ] || { echo "!! no spec for benchmark $bench" >&2; continue; }
    n1="$(jq -r .n1 "$spec")"; n2="$(jq -r .n2 "$spec")"
    # // "" so an omitted secondary key becomes empty (skip the secondary check),
    # not the literal string "null" (which would false-FAIL the checksum gate).
    c1="$(jq -r '.checksums.n1.sum' "$spec")"; s1="$(jq -r '.checksums.n1.secondary // ""' "$spec")"
    c2="$(jq -r '.checksums.n2.sum' "$spec")"; s2="$(jq -r '.checksums.n2.secondary // ""' "$spec")"
    runcmd="${run_tmpl//\{b\}/$bench}"
    if [ "$wrap" = "true" ]; then
      # Elixir: source the captured beam env, then run beam.smp directly ($BEAM_ARGV).
      override=(sh -c "set -a; . /app/beam-launch; exec /usr/local/bin/measure.sh $lang $bench -- $runcmd")
    else
      override=(/usr/local/bin/measure.sh "$lang" "$bench" -- $runcmd)
    fi
    echo ">> measuring $lang / $bench" >&2
    docker run --rm \
      -e "RUNTIME_KIND=$kind" -e "N1=$n1" -e "N2=$n2" -e "RUNS=${RUNS:-5}" \
      -e "CHECK1_SUM=$c1" -e "CHECK1_FLIPS=$s1" -e "CHECK2_SUM=$c2" -e "CHECK2_FLIPS=$s2" \
      ${envflags[@]+"${envflags[@]}"} "lang-lab-$lang" "${override[@]}"
  done
done
