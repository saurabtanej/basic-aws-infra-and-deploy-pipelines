# Stage 1: Build
FROM maven:3.9.6-amazoncorretto-21 AS builder

WORKDIR /app
COPY src/pom.xml ./pom.xml
RUN mvn dependency:go-offline -B

# Copy to match pom.xml sourceDirectory (main/java, not src/main/java)
COPY src/main ./main
COPY src/test ./test
RUN mvn clean package -DskipTests -B
RUN java -Djarmode=layertools -jar target/app.jar extract

# Stage 2: Download New Relic Agent
FROM amazoncorretto:21-alpine AS newrelic

ARG NEWRELIC_AGENT_VERSION=8.8.0
WORKDIR /newrelic

RUN apk add --no-cache curl unzip && \
    curl -O https://download.newrelic.com/newrelic/java-agent/newrelic-agent/${NEWRELIC_AGENT_VERSION}/newrelic-java-${NEWRELIC_AGENT_VERSION}.zip && \
    unzip newrelic-java-${NEWRELIC_AGENT_VERSION}.zip && \
    rm newrelic-java-${NEWRELIC_AGENT_VERSION}.zip

# Stage 3: Runtime
FROM amazoncorretto:21-alpine AS runtime

RUN apk add --no-cache curl dumb-init && \
    addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

WORKDIR /app

COPY --from=newrelic /newrelic/newrelic /app/newrelic
COPY --from=builder /app/dependencies/ ./
COPY --from=builder /app/spring-boot-loader/ ./
COPY --from=builder /app/snapshot-dependencies/ ./
COPY --from=builder /app/application/ ./
COPY src/main/resources/newrelic.yml /app/newrelic/newrelic.yml

RUN chown -R appuser:appgroup /app
USER appuser

EXPOSE 8080

ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:InitialRAMPercentage=50.0 -Djava.security.egd=file:/dev/./urandom"

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["sh", "-c", "java $JAVA_OPTS -javaagent:/app/newrelic/newrelic.jar org.springframework.boot.loader.launch.JarLauncher"]
