# Build context is the repo root: docker build -f languages/swift/Dockerfile .
ARG SWIFT_VERSION=6.1
FROM swift:${SWIFT_VERSION}
ARG SWIFT_VERSION
ENV LANG_VERSION=${SWIFT_VERSION}

COPY --from=lang-lab-qemu-insn /plugin/qemu-aarch64 /opt/qi/qemu-aarch64
COPY --from=lang-lab-qemu-insn /plugin/libinsn.so   /opt/qi/libinsn.so
COPY --from=lang-lab-qemu-insn /plugin/lib          /opt/qi/lib

WORKDIR /app
COPY languages/swift/*.swift /app/
RUN for f in /app/*.swift; do swiftc -O "$f" -o "/app/$(basename "$f" .swift)"; done
COPY scripts/measure.sh /usr/local/bin/measure.sh
RUN chmod +x /usr/local/bin/measure.sh

CMD ["/usr/local/bin/measure.sh", "swift", "fannkuch", "--", "/app/fannkuch"]
