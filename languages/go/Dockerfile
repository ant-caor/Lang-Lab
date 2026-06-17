# Build context is the repo root: docker build -f languages/go/Dockerfile .
ARG GO_VERSION=1.24.4
FROM golang:${GO_VERSION}-bookworm
ARG GO_VERSION
ENV LANG_VERSION=${GO_VERSION}

COPY --from=lang-lab-qemu-insn /plugin/qemu-aarch64 /opt/qi/qemu-aarch64
COPY --from=lang-lab-qemu-insn /plugin/libinsn.so   /opt/qi/libinsn.so
COPY --from=lang-lab-qemu-insn /plugin/lib          /opt/qi/lib

WORKDIR /app
COPY languages/go/*.go /app/
RUN for f in /app/*.go; do go build -o "/app/$(basename "$f" .go)" "$f"; done
COPY scripts/measure.sh /usr/local/bin/measure.sh
RUN chmod +x /usr/local/bin/measure.sh

CMD ["/usr/local/bin/measure.sh", "go", "fannkuch", "--", "/app/fannkuch"]
