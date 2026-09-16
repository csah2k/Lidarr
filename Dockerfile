ARG DOTNET_SDK_VERSION=8.0
ARG DOTNET_RUNTIME_VERSION=8.0
ARG NODE_MAJOR=20
ARG RUNTIME=linux-x64
ARG FRAMEWORK=net8.0

FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_SDK_VERSION} AS build

ARG NODE_MAJOR
ARG RUNTIME
ARG FRAMEWORK

WORKDIR /src

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g yarn@1.22.19 \
    && rm -rf /var/lib/apt/lists/*

COPY . .

RUN rm -f global.json \
    && ./build.sh --backend --frontend --packages -f "${FRAMEWORK}" -r "${RUNTIME}"

FROM mcr.microsoft.com/dotnet/runtime-deps:${DOTNET_RUNTIME_VERSION}

ARG RUNTIME
ARG FRAMEWORK

ENV COMPlus_EnableDiagnostics=0 \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
    LIDARR_IDENTIFICATION_RELEASE_CONCURRENCY=1 \
    LIDARR_IDENTIFICATION_TRACK_DISTANCE_CONCURRENCY=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl libicu72 tzdata \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -u 1000 -m -s /usr/sbin/nologin lidarr \
    && mkdir -p /app /config /downloads /music \
    && chown -R lidarr:lidarr /app /config /downloads /music

COPY --from=build --chown=lidarr:lidarr /src/_artifacts/${RUNTIME}/${FRAMEWORK}/Lidarr/ /app/

USER lidarr
WORKDIR /app
VOLUME ["/config", "/downloads", "/music"]
EXPOSE 8686

ENTRYPOINT ["/app/Lidarr", "-nobrowser", "-data=/config"]
