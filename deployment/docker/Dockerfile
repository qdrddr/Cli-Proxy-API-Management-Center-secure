# syntax=docker/dockerfile:1
# Build from repository root:
#   docker build -f deployment/docker/Dockerfile .

FROM oven/bun:1.3.14 AS build

WORKDIR /app

COPY package.json bun.lock ./
RUN bun install --frozen-lockfile

COPY . .

ARG VERSION=v1.26.7
ENV VERSION=${VERSION}

RUN bun run build \
  && mv dist/index.html dist/management.html \
  && cp dist/management.html dist/index.html

FROM debian:bookworm

ARG NONO_VERSION=0.80.0
ARG TARGETARCH

RUN apt-get update && apt-get install -y --no-install-recommends \
    tzdata ca-certificates wget nginx gettext-base socat \
  && wget -q "https://github.com/nolabs-ai/nono/releases/download/v${NONO_VERSION}/nono-cli_${NONO_VERSION}_${TARGETARCH}.deb" \
  && dpkg -i "nono-cli_${NONO_VERSION}_${TARGETARCH}.deb" \
  && rm -f "nono-cli_${NONO_VERSION}_${TARGETARCH}.deb" \
  && rm -rf /var/lib/apt/lists/*

ENV HOME=/root

RUN mkdir -p /root/.config/nono/profiles \
  && nono pull nolabs-ai/claude

COPY deployment/docker/nono/profiles/management.json /root/.config/nono/profiles/management.json

LABEL org.opencontainers.image.title="CLI Proxy API Management Center" \
  org.opencontainers.image.description="Official web UI for CLIProxyAPI with optional API reverse proxy (nono sandbox)" \
  org.opencontainers.image.source="https://github.com/router-for-me/Cli-Proxy-API-Management-Center"

ENV NGINX_PORT=8080 \
  CLIPROXY_API_BACKEND=http://cli-proxy-api:8317 \
  TZ=UTC

COPY --from=build /app/dist/management.html /usr/share/nginx/html/management.html
COPY --from=build /app/dist/index.html /usr/share/nginx/html/index.html
COPY deployment/docker/nginx.conf.template /etc/nginx/templates/default.conf.template

COPY deployment/docker/nono/nono-entrypoint.sh /usr/local/bin/nono-entrypoint.sh
RUN chmod +x /usr/local/bin/nono-entrypoint.sh

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- "http://127.0.0.1:${NGINX_PORT}/management.html" >/dev/null 2>&1 || exit 1

ENTRYPOINT ["/usr/local/bin/nono-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
