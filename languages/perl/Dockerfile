# Build context is the repo root: docker build -f languages/perl/Dockerfile .
ARG PERL_VERSION=5.40.2
FROM perl:${PERL_VERSION}-slim
ARG PERL_VERSION
ENV LANG_VERSION=${PERL_VERSION}

COPY --from=lang-lab-qemu-insn /plugin/qemu-aarch64 /opt/qi/qemu-aarch64
COPY --from=lang-lab-qemu-insn /plugin/libinsn.so   /opt/qi/libinsn.so
COPY --from=lang-lab-qemu-insn /plugin/lib          /opt/qi/lib

WORKDIR /app
COPY languages/perl/*.pl /app/
COPY scripts/measure.sh /usr/local/bin/measure.sh
RUN chmod +x /usr/local/bin/measure.sh

CMD ["/usr/local/bin/measure.sh", "perl", "fannkuch", "--", "perl", "/app/fannkuch.pl"]
