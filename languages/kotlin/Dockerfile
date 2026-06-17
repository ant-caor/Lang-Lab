# Build context is the repo root: docker build -f languages/kotlin/Dockerfile .
# Kotlin has no official Docker image; build with the JetBrains compiler, run on a JRE.
ARG KOTLIN_VERSION=2.1.0

FROM eclipse-temurin:21-jdk AS build
ARG KOTLIN_VERSION
RUN apt-get update && apt-get install -y --no-install-recommends curl unzip && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL -o /tmp/kotlin.zip \
      "https://github.com/JetBrains/kotlin/releases/download/v${KOTLIN_VERSION}/kotlin-compiler-${KOTLIN_VERSION}.zip" \
 && unzip -q /tmp/kotlin.zip -d /opt && rm /tmp/kotlin.zip
ENV PATH="/opt/kotlinc/bin:${PATH}"
WORKDIR /app
COPY languages/kotlin/*.kt /app/
RUN for f in /app/*.kt; do kotlinc "$f" -include-runtime -d "/app/$(basename "$f" .kt).jar"; done

FROM eclipse-temurin:21-jre-noble
ARG KOTLIN_VERSION
ENV LANG_VERSION=${KOTLIN_VERSION}
COPY --from=lang-lab-qemu-insn /plugin/qemu-aarch64 /opt/qi/qemu-aarch64
COPY --from=lang-lab-qemu-insn /plugin/libinsn.so   /opt/qi/libinsn.so
COPY --from=lang-lab-qemu-insn /plugin/lib          /opt/qi/lib
WORKDIR /app
COPY --from=build /app/*.jar /app/
COPY scripts/measure.sh /usr/local/bin/measure.sh
RUN chmod +x /usr/local/bin/measure.sh

# JVM is a JIT+GC runtime (hard to measure - like the CLR/Go). Constrain and
# characterize with /backend-doctor (e.g. -XX:+UseSerialGC, single GC thread).
CMD ["/usr/local/bin/measure.sh", "kotlin", "fannkuch", "--", "java", "-jar", "/app/fannkuch.jar"]
