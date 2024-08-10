FROM debian:bookworm-slim

ARG VERSION

ENV TZ=Asia/Seoul \
    PATH="/mattermost/bin:${PATH}" \
    GOSU_VERSION=1.17 \
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
        mkdir -p /mattermost/data /mattermost/logs /mattermost/config /mattermost/plugins /mattermost/client/plugins  && \
        addgroup --gid ${PGID} mattermost && \
        adduser --disabled-password --uid ${PUID} --gid ${PGID} --gecos "" --home /mattermost mattermost && \
        curl -sSL "${MM_PACKAGE_BASE}-${TARGETARCH}.tar.gz" | tar -xz -C /mattermost --strip-components=1 && \
        chown -R mattermost:mattermost /mattermost; \
        ;; \
      *) echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac

RUN set -eux; \
      # save list of currently installed packages for later so we can clean up
          savedAptMark="$(apt-mark showmanual)"; \
          apt-get update; \
          apt-get install -y --no-install-recommends ca-certificates gnupg wget; \
          rm -rf /var/lib/apt/lists/*; \
          \
          dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
          wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
          wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
          \
      # verify the signature
          export GNUPGHOME="$(mktemp -d)"; \
          gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
          gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
          gpgconf --kill all; \
          rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
          \
      # clean up fetch dependencies
          apt-mark auto '.*' > /dev/null; \
          [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; \
          apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
          \
          chmod +x /usr/local/bin/gosu; \
      # verify that the binary works
          gosu --version; \
          gosu nobody true

HEALTHCHECK --interval=30s --timeout=10s \
  CMD curl -f http://localhost:8065/api/v4/system/ping || exit 1

COPY start.sh /usr/local/bin/

WORKDIR /mattermost

EXPOSE 8065/tcp 8067/tcp 8074/tcp 8074/udp

VOLUME [ "/mattermost/data", "/mattermost/logs", "/mattermost/config", "/mattermost/plugins", "/mattermost/client/plugins" ]

ENTRYPOINT [ "tini", "--", "start.sh" ]
CMD [ "mattermost" ]
