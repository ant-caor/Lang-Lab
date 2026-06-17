# Build context is the repo root: docker build -f languages/c/Dockerfile .
# C is the 1.0x baseline (hand-tuned native, no GC) - not one of the 10 tracked
# backend languages, and excluded from the version watcher.
# Requires the prebuilt base image:  docker build -f languages/_base/Dockerfile.qemu-insn -t lang-lab-qemu-insn .
ARG GCC_VERSION=14
FROM gcc:${GCC_VERSION}
ARG GCC_VERSION
ENV LANG_VERSION=${GCC_VERSION}

COPY --from=lang-lab-qemu-insn /plugin/qemu-aarch64 /opt/qi/qemu-aarch64
COPY --from=lang-lab-qemu-insn /plugin/libinsn.so   /opt/qi/libinsn.so
COPY --from=lang-lab-qemu-insn /plugin/lib          /opt/qi/lib

WORKDIR /app
COPY languages/c/*.c /app/
RUN for f in /app/*.c; do gcc -O2 "$f" -o "/app/$(basename "$f" .c)"; done
COPY scripts/measure.sh /usr/local/bin/measure.sh
RUN chmod +x /usr/local/bin/measure.sh

CMD ["/usr/local/bin/measure.sh", "c", "fannkuch", "--", "/app/fannkuch"]
