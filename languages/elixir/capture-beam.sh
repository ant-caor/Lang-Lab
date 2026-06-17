#!/bin/sh
# Build-time helper: Elixir's `elixir` → `erl` → `beam.smp` are shell wrappers.
# qemu-user can't run a shell script, and on same-arch it execs children natively
# (uninstrumented). So we capture the exact `beam.smp` ELF invocation (argv prefix
# + the BINDIR/ROOTDIR/EMU/PROGNAME env the wrappers set) and write `/app/beam-launch`,
# which the container CMD sources to run beam.smp DIRECTLY under qemu (one
# instrumented process). measure.sh then appends the benchmark size.
set -eu
export ELIXIR_ERL_OPTIONS="+S 1:1"   # single scheduler → deterministic count

R=/usr/local/lib/erlang
B="$(find "$R" -name beam.smp | head -1)"
BD="$(dirname "$B")"

# Temporarily shim beam.smp to record its argv, then restore it.
cp "$B" "$B.real"
printf '#!/bin/sh\nprintf "%%s\\n" "$@" > /app/ba\nexec %s "$@"\n' "$B.real" > "$B"
chmod +x "$B"
# Probe with NO size arg so the captured argv ends with "<script>"; the size is appended
# at run time by measure.sh, and the script (/app/<bench>.exs) by the driver.
elixir /app/fannkuch.exs >/dev/null 2>&1 || true
mv "$B.real" "$B"

# beam argv minus the trailing "<script>" (1 token) = the benchmark-independent prefix,
# ending exactly at `-extra`. The driver appends "/app/<bench>.exs", measure.sh the size.
head -n -1 /app/ba > /app/prefix
{
  echo "ROOTDIR=$R"
  echo "BINDIR=$BD"
  echo "EMU=beam.smp"
  echo "PROGNAME=erl"
  printf 'BEAM_ARGV="%s' "$B"
  while IFS= read -r a; do printf ' %s' "$a"; done < /app/prefix
  printf '"\n'
} > /app/beam-launch
rm -f /app/ba /app/prefix
echo "wrote /app/beam-launch"
