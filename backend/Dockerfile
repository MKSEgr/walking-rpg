FROM eclipse-temurin:21-jdk-jammy@sha256:55fb9bf738f5d9b4a6c01b39337e3070d3e27370dd3c478fd1d5d3cd2233c6d8 AS build

WORKDIR /workspace/backend

RUN apt-get update \
    && apt-get install --yes --no-install-recommends curl unzip \
    && rm -rf /var/lib/apt/lists/*

COPY backend/.mvn .mvn
COPY backend/mvnw backend/pom.xml ./
RUN chmod 0555 mvnw \
    && ./mvnw --batch-mode --no-transfer-progress -DskipTests dependency:go-offline

COPY backend/src src
RUN ./mvnw --batch-mode --no-transfer-progress -DskipTests package \
    && find target -maxdepth 1 -type f -name '*.jar' ! -name '*.original' \
       -exec cp '{}' /workspace/walking-rpg-backend.jar ';'

FROM eclipse-temurin:21-jre-jammy@sha256:3097cbbebb7d490494a98aed2301f284b38f79eba158eef098c6fc8c8af11c23

ARG APP_UID=10001
ARG APP_GID=10001
ARG SOURCE_GIT_SHA=unknown
ARG SOURCE_GIT_TREE=unknown

LABEL org.opencontainers.image.source="https://github.com/MKSEgr/walking-rpg" \
      org.opencontainers.image.revision="${SOURCE_GIT_SHA}" \
      game.stepbeyond.source-tree="${SOURCE_GIT_TREE}"

RUN groupadd --gid "${APP_GID}" walkingrpg \
    && useradd \
       --uid "${APP_UID}" \
       --gid "${APP_GID}" \
       --create-home \
       --home-dir /home/walkingrpg \
       --shell /usr/sbin/nologin \
       walkingrpg \
    && install -d -o walkingrpg -g walkingrpg -m 0700 /app \
    && install -d -o root -g root -m 0755 /usr/local/share/walking-rpg \
    && printf '%s\n' "${SOURCE_GIT_SHA}" \
       > /usr/local/share/walking-rpg/source-git-sha \
    && printf '%s\n' "${SOURCE_GIT_TREE}" \
       > /usr/local/share/walking-rpg/source-git-tree \
    && chmod 0444 \
       /usr/local/share/walking-rpg/source-git-sha \
       /usr/local/share/walking-rpg/source-git-tree \
    && chmod 0555 /usr/local/share/walking-rpg

COPY --from=build --chown=walkingrpg:walkingrpg --chmod=0444 \
    /workspace/walking-rpg-backend.jar /app/walking-rpg-backend.jar
COPY --chown=root:root --chmod=0555 \
    backend/docker-entrypoint.sh /usr/local/bin/walking-rpg-entrypoint

ENV HOME=/home/walkingrpg

USER walkingrpg:walkingrpg
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/walking-rpg-entrypoint"]
