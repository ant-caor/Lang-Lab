# Build context is the repo root: docker build -f languages/java/Dockerfile .
# Plain Java (Temurin/OpenJDK build). Each benchmark's top-level class is
# non-public (e.g. `class BinaryTrees`) so its filename can differ from the class
# name; compile each *.java independently and pack a self-contained runnable jar
# per benchmark, deriving Main-Class from the bench name (kebab-case -> PascalCase).
ARG JAVA_VERSION=26

FROM eclipse-temurin:${JAVA_VERSION}-jdk AS build
ARG JAVA_VERSION
WORKDIR /app
COPY languages/java/*.java /app/src/
RUN mkdir -p /app/classes && \
    for f in /app/src/*.java; do \
      b="$(basename "$f" .java)"; \
      cls="$(printf '%s' "$b" | awk -F- '{s="";for(i=1;i<=NF;i++){w=$i;s=s toupper(substr(w,1,1)) substr(w,2)};print s}')"; \
      outdir="/app/classes/$b"; \
      mkdir -p "$outdir"; \
      javac -d "$outdir" "$f"; \
      ( cd "$outdir" && jar --create --file "/app/$b.jar" --main-class "$cls" *.class ); \
    done

FROM eclipse-temurin:${JAVA_VERSION}-jre-noble
ARG JAVA_VERSION
ENV LANG_VERSION=${JAVA_VERSION}
COPY --from=lang-lab-qemu-insn /plugin/qemu-aarch64 /opt/qi/qemu-aarch64
COPY --from=lang-lab-qemu-insn /plugin/libinsn.so   /opt/qi/libinsn.so
COPY --from=lang-lab-qemu-insn /plugin/lib          /opt/qi/lib
WORKDIR /app
COPY --from=build /app/*.jar /app/
COPY scripts/measure.sh /usr/local/bin/measure.sh
RUN chmod +x /usr/local/bin/measure.sh

# JVM is a JIT+GC runtime (like Kotlin/Scala/C#) - constrained via runtimeEnv
# (JAVA_TOOL_OPTIONS=-XX:+UseSerialGC) and characterized with /backend-doctor.
# message-ring additionally pins the virtual-thread carrier pool to 1 OS thread
# via System.setProperty at startup (before spawning any virtual thread).
CMD ["/usr/local/bin/measure.sh", "java", "fannkuch", "--", "java", "-jar", "/app/fannkuch.jar"]
