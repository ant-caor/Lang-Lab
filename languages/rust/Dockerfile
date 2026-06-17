# Build context is the repo root: docker build -f languages/rust/Dockerfile .
ARG RUST_VERSION=1.88.0
FROM rust:${RUST_VERSION}-slim-bookworm
ARG RUST_VERSION
ENV LANG_VERSION=${RUST_VERSION}

COPY --from=lang-lab-qemu-insn /plugin/qemu-aarch64 /opt/qi/qemu-aarch64
COPY --from=lang-lab-qemu-insn /plugin/libinsn.so   /opt/qi/libinsn.so
COPY --from=lang-lab-qemu-insn /plugin/lib          /opt/qi/lib

WORKDIR /app
COPY languages/rust/*.rs /app/
RUN for f in /app/*.rs; do rustc -O "$f" -o "/app/$(basename "$f" .rs)"; done
COPY scripts/measure.sh /usr/local/bin/measure.sh
RUN chmod +x /usr/local/bin/measure.sh

CMD ["/usr/local/bin/measure.sh", "rust", "fannkuch", "--", "/app/fannkuch"]
