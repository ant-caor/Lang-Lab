# Build context is the repo root: docker build -f languages/ruby/Dockerfile .
ARG RUBY_VERSION=3.3
FROM ruby:${RUBY_VERSION}-slim
ARG RUBY_VERSION
ENV LANG_VERSION=${RUBY_VERSION}

COPY --from=lang-lab-qemu-insn /plugin/qemu-aarch64 /opt/qi/qemu-aarch64
COPY --from=lang-lab-qemu-insn /plugin/libinsn.so   /opt/qi/libinsn.so
COPY --from=lang-lab-qemu-insn /plugin/lib          /opt/qi/lib

WORKDIR /app
COPY languages/ruby/*.rb /app/
COPY scripts/measure.sh /usr/local/bin/measure.sh
RUN chmod +x /usr/local/bin/measure.sh

CMD ["/usr/local/bin/measure.sh", "ruby", "fannkuch", "--", "ruby", "/app/fannkuch.rb"]
