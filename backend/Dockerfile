FROM eclipse-temurin:21-jdk-jammy AS build

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

FROM eclipse-temurin:21-jre-jammy

ARG APP_UID=10001
ARG APP_GID=10001

RUN groupadd --gid "${APP_GID}" walkingrpg \
    && useradd \
       --uid "${APP_UID}" \
       --gid "${APP_GID}" \
       --create-home \
       --home-dir /home/walkingrpg \
       --shell /usr/sbin/nologin \
       walkingrpg \
    && install -d -o walkingrpg -g walkingrpg -m 0700 /app

COPY --from=build --chown=walkingrpg:walkingrpg --chmod=0444 \
    /workspace/walking-rpg-backend.jar /app/walking-rpg-backend.jar
COPY --chown=root:root --chmod=0555 \
    backend/docker-entrypoint.sh /usr/local/bin/walking-rpg-entrypoint

ENV HOME=/home/walkingrpg

USER walkingrpg:walkingrpg
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/walking-rpg-entrypoint"]
