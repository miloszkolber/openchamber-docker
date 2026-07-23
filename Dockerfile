# syntax=docker/dockerfile:1.7

ARG BUN_VERSION=1.3.14

FROM docker.io/library/docker:29.6.2-cli AS docker-cli

FROM docker.io/oven/bun:${BUN_VERSION}-alpine AS openchamber-package

ARG OPENCHAMBER_VERSION
ARG OPENCHAMBER_PACKAGE_SHA256

RUN apk add --no-cache ca-certificates curl patch

WORKDIR /opt/openchamber

COPY patches/disable-openchamber-updates.patch /tmp/disable-openchamber-updates.patch

RUN curl --fail --location --retry 3 \
        --output /tmp/openchamber.tgz \
        "https://github.com/openchamber/openchamber/releases/download/v${OPENCHAMBER_VERSION}/openchamber-web-${OPENCHAMBER_VERSION}.tgz" \
    && echo "${OPENCHAMBER_PACKAGE_SHA256}  /tmp/openchamber.tgz" | sha256sum -c - \
    && tar -xzf /tmp/openchamber.tgz --strip-components=1 \
    && test "$(bun -e "console.log(require('./package.json').version)")" = "${OPENCHAMBER_VERSION}" \
    && patch -p1 < /tmp/disable-openchamber-updates.patch \
    && bun install --production --ignore-scripts

FROM docker.io/library/alpine:3.22 AS opencode-download

ARG OPENCODE_VERSION
ARG OPENCODE_AMD64_SHA256

RUN apk add --no-cache ca-certificates curl libstdc++ \
    && curl --fail --location --retry 3 \
        --output /tmp/opencode.tar.gz \
        "https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}/opencode-linux-x64-musl.tar.gz" \
    && echo "${OPENCODE_AMD64_SHA256}  /tmp/opencode.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/opencode.tar.gz -C /usr/local/bin \
    && chmod 0755 /usr/local/bin/opencode

FROM docker.io/oven/bun:${BUN_VERSION}-alpine

ARG OPENCHAMBER_VERSION
ARG OPENCODE_VERSION
ARG VCS_REF

LABEL org.opencontainers.image.title="OpenChamber with managed OpenCode" \
      org.opencontainers.image.description="OpenChamber web interface with managed OpenCode and host Docker access" \
      org.opencontainers.image.source="https://github.com/miloszkolber/openchamber-docker" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.version="${OPENCHAMBER_VERSION}+${OPENCODE_VERSION}" \
      io.openchamber.version="${OPENCHAMBER_VERSION}" \
      io.opencode.version="${OPENCODE_VERSION}"

RUN apk add --no-cache \
        bash \
        ca-certificates \
        curl \
        git \
        libstdc++ \
        tini \
    && deluser bun \
    && addgroup -g 1000 openchamber \
    && adduser -D -u 1000 -G openchamber -h /home/data -s /bin/bash openchamber \
    && install -d -o openchamber -g openchamber \
        /home/data/.config/openchamber \
        /home/data/.config/opencode \
        /home/data/.docker \
        /home/data/.local/share/opencode \
        /home/data/.local/state/opencode

WORKDIR /opt/openchamber

COPY --from=openchamber-package /opt/openchamber/node_modules ./node_modules
COPY --from=openchamber-package /opt/openchamber/package.json ./package.json
COPY --from=openchamber-package /opt/openchamber/bin ./bin
COPY --from=openchamber-package /opt/openchamber/server ./server
COPY --from=openchamber-package /opt/openchamber/dist ./dist
COPY --from=opencode-download /usr/local/bin/opencode /usr/local/bin/opencode
COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker-cli /usr/local/libexec/docker/cli-plugins/docker-compose /usr/local/libexec/docker/cli-plugins/docker-compose

ENV DOCKER_CONFIG=/home/data/.docker \
    DOCKER_HOST=unix:///var/run/docker.sock \
    HOME=/home/data \
    NODE_ENV=production \
    OPENCHAMBER_ALLOW_UNAUTHENTICATED_LAN=true \
    OPENCHAMBER_API_ONLY=false \
    OPENCHAMBER_DATA_DIR=/home/data/.config/openchamber \
    OPENCHAMBER_DISABLE_UPDATE=true \
    OPENCHAMBER_GIT_BINARY=/usr/bin/git \
    OPENCHAMBER_OPENCODE_CWD=/home/data \
    OPENCHAMBER_OPENCODE_HOSTNAME=127.0.0.1 \
    OPENCHAMBER_PORT=4098 \
    OPENCODE_BINARY=/usr/local/bin/opencode \
    OPENCODE_CONFIG_DIR=/home/data/.config/opencode \
    OPENCODE_DATA_DIR=/home/data/.local/share/opencode \
    OPENCODE_DISABLE_AUTOUPDATE=true \
    OPENCODE_ENABLE_EXA=true \
    OPENCODE_DISABLE_PRUNE=false \
    OPENCODE_AUTO_SHARE=false \
    OPENCODE_SKIP_START=false \
    XDG_CONFIG_HOME=/home/data/.config \
    XDG_DATA_HOME=/home/data/.local/share \
    XDG_STATE_HOME=/home/data/.local/state

USER openchamber

EXPOSE 4098

HEALTHCHECK --interval=60s --timeout=5s --retries=3 --start-period=10s \
    CMD curl -fsS "http://127.0.0.1:${OPENCHAMBER_PORT:-4098}/health" || exit 1

ENTRYPOINT ["/sbin/tini", "-s", "--"]
CMD ["sh", "-c", "exec bun bin/cli.js serve --foreground --host 0.0.0.0 --port \"${OPENCHAMBER_PORT:-4098}\""]
