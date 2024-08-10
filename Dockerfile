FROM debian:bookworm-slim

ARG VERSION=9.10.1

ENV TZ=Asia/Seoul \
    PATH="/mattermost/bin:${PATH}" \
    PUID=1001 \
    PGID=1001 \
    MM_PACKAGE_BASE="https://releases.mattermost.com/${VERSION}/mattermost-${VERSION}-linux"

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
        ca-certificates curl mime-support unrtf \
        wv poppler-utils tini tidy tzdata \
    && rm -rf /var/lib/apt/lists/*

RUN TARGETARCH="$(dpkg --print-architecture)" && \
    case "${TARGETARCH}" in \
      "amd64" | "arm64") \
        mkdir -p /mattermost/data /mattermost/plugins /mattermost/client/plugins && \
        addgroup --gid ${PGID} mattermost && \
        adduser --disabled-password --uid ${PUID} --gid ${PGID} --gecos "" --home /mattermost mattermost && \
        curl -sSL "${MM_PACKAGE_BASE}-${TARGETARCH}.tar.gz?src=docker" | tar -xz -C /mattermost --strip-components=1 && \
        chown -R mattermost:mattermost /mattermost; \
        ;; \
      *) echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac

USER mattermost

HEALTHCHECK --interval=30s --timeout=10s \
  CMD curl -f http://localhost:8065/api/v4/system/ping || exit 1

COPY start.sh /usr/local/bin/

WORKDIR /mattermost

EXPOSE 8065 8067 8074 8075

VOLUME [ "/mattermost/data", "/mattermost/logs", "/mattermost/config", "/mattermost/plugins", "/mattermost/client/plugins" ]

ENTRYPOINT [ "tini", "--", "start.sh" ]
CMD [ "mattermost" ]
