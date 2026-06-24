# Build context is the repo root: docker build -f languages/php/Dockerfile .
ARG PHP_VERSION=8.4.8
FROM php:${PHP_VERSION}-cli
ARG PHP_VERSION
ENV LANG_VERSION=${PHP_VERSION}

# pcntl: PHP CLI has no shared-memory threads, so the wall-clock scaling track's
# parallel benchmarks use pcntl_fork (the only fair CPU-parallel primitive in core PHP).
RUN docker-php-ext-install pcntl

COPY --from=lang-lab-qemu-insn /plugin/qemu-aarch64 /opt/qi/qemu-aarch64
COPY --from=lang-lab-qemu-insn /plugin/libinsn.so   /opt/qi/libinsn.so
COPY --from=lang-lab-qemu-insn /plugin/lib          /opt/qi/lib

WORKDIR /app
COPY languages/php/*.php /app/
COPY scripts/measure.sh /usr/local/bin/measure.sh
RUN chmod +x /usr/local/bin/measure.sh

# PHP 8 ships an opcode JIT (opcache.jit). It is OFF here so we measure the
# baseline interpreter; enabling it is a separate, documented measurement axis.
CMD ["/usr/local/bin/measure.sh", "php", "fannkuch", "--", "php", "/app/fannkuch.php"]
