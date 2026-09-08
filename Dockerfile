FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/runtime-deps:8.0-bookworm-slim AS download
ARG TARGETARCH
ARG MANAGER_VERSION
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl jq tar \
    && rm -rf /var/lib/apt/lists/*
COPY MANAGER_VERSION /build/MANAGER_VERSION
COPY scripts/download-manager.sh /build/download-manager.sh
RUN bash /build/download-manager.sh

FROM mcr.microsoft.com/dotnet/runtime-deps:8.0-bookworm-slim AS runtime
ARG MANAGER_VERSION
ARG SOURCE_URL=https://github.com/zdb00/managerio-docker
LABEL org.opencontainers.image.title="Manager.io Server (community Docker packaging)" \
      org.opencontainers.image.description="Unofficial Manager.io Server with Chromium; Manager is proprietary" \
      org.opencontainers.image.source="${SOURCE_URL}" \
      org.opencontainers.image.version="${MANAGER_VERSION}" \
      org.opencontainers.image.vendor="managerio-docker community contributors" \
      org.opencontainers.image.licenses="MIT AND LicenseRef-Manager-Proprietary"
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl chromium fonts-liberation gosu tzdata \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /data
WORKDIR /opt/manager-server
COPY --from=download /opt/manager-server/ ./
COPY --chmod=0755 chromium-wrapper docker-entrypoint.sh /usr/local/bin/
COPY LICENSE /usr/share/licenses/managerio-docker/LICENSE
ENV TZ=UTC PUID=1000 PGID=1000 UMASK=0027 \
    PUPPETEER_EXECUTABLE_PATH=/usr/local/bin/chromium-wrapper
EXPOSE 8080
VOLUME ["/data"]
STOPSIGNAL SIGTERM
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl --fail --silent --show-error --max-time 4 http://127.0.0.1:8080/healthz || exit 1
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/opt/manager-server/ManagerServer", "-port", "8080", "-path", "/data"]
