# Build context is the repo root: docker build -f languages/scala/Dockerfile .
# Build with scala-cli, run the assembly jar on a JRE.
ARG SCALA_VERSION=3.6.2
# Pin the scala-cli launcher to a tagged release (NOT the mutable `main` branch) so
# builds are reproducible. Bump SCALA_CLI_VERSION via the version watcher if desired.
ARG SCALA_CLI_VERSION=1.5.4

FROM eclipse-temurin:21-jdk AS build
ARG SCALA_VERSION
ARG SCALA_CLI_VERSION
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL "https://raw.githubusercontent.com/VirtusLab/scala-cli/v${SCALA_CLI_VERSION}/scala-cli.sh" \
      -o /usr/local/bin/scala-cli \
 && chmod +x /usr/local/bin/scala-cli
WORKDIR /app
COPY languages/scala/*.scala /app/
RUN for f in /app/*.scala; do scala-cli --power package "$f" --scala "${SCALA_VERSION}" --assembly -o "/app/$(basename "$f" .scala).jar" -f; done

FROM eclipse-temurin:21-jre-noble
ARG SCALA_VERSION
ENV LANG_VERSION=${SCALA_VERSION}
COPY --from=lang-lab-qemu-insn /plugin/qemu-aarch64 /opt/qi/qemu-aarch64
COPY --from=lang-lab-qemu-insn /plugin/libinsn.so   /opt/qi/libinsn.so
COPY --from=lang-lab-qemu-insn /plugin/lib          /opt/qi/lib
WORKDIR /app
COPY --from=build /app/*.jar /app/
COPY scripts/measure.sh /usr/local/bin/measure.sh
RUN chmod +x /usr/local/bin/measure.sh

# JVM runtime - same measurement caveat as Kotlin. Characterize with /backend-doctor.
CMD ["/usr/local/bin/measure.sh", "scala", "fannkuch", "--", "java", "-jar", "/app/fannkuch.jar"]
