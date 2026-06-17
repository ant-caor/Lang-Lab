# Build context is the repo root: docker build -f languages/python/Dockerfile .
ARG PYTHON_VERSION=3.13.4
FROM python:${PYTHON_VERSION}-slim
ARG PYTHON_VERSION
ENV LANG_VERSION=${PYTHON_VERSION}

COPY --from=lang-lab-qemu-insn /plugin/qemu-aarch64 /opt/qi/qemu-aarch64
COPY --from=lang-lab-qemu-insn /plugin/libinsn.so   /opt/qi/libinsn.so
COPY --from=lang-lab-qemu-insn /plugin/lib          /opt/qi/lib

WORKDIR /app
COPY languages/python/*.py /app/
COPY scripts/measure.sh /usr/local/bin/measure.sh
RUN chmod +x /usr/local/bin/measure.sh

CMD ["/usr/local/bin/measure.sh", "python", "fannkuch", "--", "python", "/app/fannkuch.py"]
