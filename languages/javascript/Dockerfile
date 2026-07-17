# Build context is the repo root: docker build -f languages/javascript/Dockerfile .
ARG NODE_VERSION=26.5.0
FROM node:${NODE_VERSION}-bookworm-slim
ARG NODE_VERSION
ENV LANG_VERSION=${NODE_VERSION}

COPY --from=lang-lab-qemu-insn /plugin/qemu-aarch64 /opt/qi/qemu-aarch64
COPY --from=lang-lab-qemu-insn /plugin/libinsn.so   /opt/qi/libinsn.so
COPY --from=lang-lab-qemu-insn /plugin/lib          /opt/qi/lib

WORKDIR /app
COPY languages/javascript/*.js /app/
COPY scripts/measure.sh /usr/local/bin/measure.sh
RUN chmod +x /usr/local/bin/measure.sh

# --predictable --single-threaded --single-threaded-gc collapse V8's background compiler/GC
# threads (the insn plugin sums instructions across ALL threads, so those add counted,
# jittery work). All three are V8 flags NODE_OPTIONS rejects ("not allowed in NODE_OPTIONS"),
# so they must be passed as CLI args here, not as env vars. UV_THREADPOOL_SIZE=1 (a normal
# env var, not filtered by NODE_OPTIONS) is defensive insurance for any future benchmark that
# touches libuv's threadpool (fs/crypto/zlib); none of the current 19 do.
ENV UV_THREADPOOL_SIZE=1
CMD ["/usr/local/bin/measure.sh", "javascript", "fannkuch", "--", "node", "--predictable", "--single-threaded", "--single-threaded-gc", "/app/fannkuch.js"]
