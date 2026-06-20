# Build context is the repo root: docker build -f languages/cobol/Dockerfile .
# COBOL via GnuCOBOL: cobc transpiles COBOL -> C -> a native ELF, so COBOL measures as a
# NATIVE single-process language under qemu+insn (bit-exact, like C). Requires the prebuilt
# base: docker build -f languages/_base/Dockerfile.qemu-insn -t lang-lab-qemu-insn .
ARG GNUCOBOL_VERSION=3.1
FROM debian:bookworm-slim
ARG GNUCOBOL_VERSION
ENV LANG_VERSION=${GNUCOBOL_VERSION}

RUN apt-get update && apt-get install -y --no-install-recommends \
      gnucobol build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY --from=lang-lab-qemu-insn /plugin/qemu-aarch64 /opt/qi/qemu-aarch64
COPY --from=lang-lab-qemu-insn /plugin/libinsn.so   /opt/qi/libinsn.so
COPY --from=lang-lab-qemu-insn /plugin/lib          /opt/qi/lib

WORKDIR /app
COPY languages/cobol/*.cob /app/
RUN for f in /app/*.cob; do cobc -x -O2 -free "$f" -o "/app/$(basename "$f" .cob)"; done
COPY scripts/measure.sh /usr/local/bin/measure.sh
RUN chmod +x /usr/local/bin/measure.sh

CMD ["/usr/local/bin/measure.sh", "cobol", "fannkuch", "--", "/app/fannkuch"]
