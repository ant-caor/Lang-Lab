# Build context is the repo root: docker build -f languages/elixir/Dockerfile .
ARG ELIXIR_VERSION=1.18
FROM elixir:${ELIXIR_VERSION}-slim
ARG ELIXIR_VERSION
ENV LANG_VERSION=${ELIXIR_VERSION}

COPY --from=lang-lab-qemu-insn /plugin/qemu-aarch64 /opt/qi/qemu-aarch64
COPY --from=lang-lab-qemu-insn /plugin/libinsn.so   /opt/qi/libinsn.so
COPY --from=lang-lab-qemu-insn /plugin/lib          /opt/qi/lib

WORKDIR /app
COPY languages/elixir/*.exs /app/
COPY scripts/measure.sh /usr/local/bin/measure.sh
RUN chmod +x /usr/local/bin/measure.sh

# Capture the beam.smp ELF invocation so we can run the VM directly under qemu,
# bypassing the elixir/erl shell wrappers (which qemu can't instrument on same-arch).
COPY languages/elixir/capture-beam.sh /app/capture-beam.sh
RUN sh /app/capture-beam.sh

# Source the captured env + argv, then measure beam.smp directly (one process).
CMD ["/bin/sh", "-c", "set -a; . /app/beam-launch; exec /usr/local/bin/measure.sh elixir fannkuch -- $BEAM_ARGV /app/fannkuch.exs"]
