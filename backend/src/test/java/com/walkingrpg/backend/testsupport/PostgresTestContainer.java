package com.walkingrpg.backend.testsupport;

import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

public final class PostgresTestContainer {

    public static final String IMAGE_TAG = "postgres:17.10-alpine3.24";
    public static final String IMAGE_DIGEST =
            "sha256:742f40ea20b9ff2ff31db5458d127452988a2164df9e17441e191f3b72252193";
    public static final String IMAGE = "postgres@" + IMAGE_DIGEST;

    private static final DockerImageName DOCKER_IMAGE =
            DockerImageName.parse(IMAGE)
                    .asCompatibleSubstituteFor("postgres");

    private PostgresTestContainer() {
    }

    public static PostgreSQLContainer create() {
        return new PostgreSQLContainer(DOCKER_IMAGE);
    }
}
