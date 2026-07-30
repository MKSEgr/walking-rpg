package com.walkingrpg.backend.operations;

import java.sql.Connection;

import javax.sql.DataSource;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.health.contributor.AbstractHealthIndicator;
import org.springframework.boot.health.contributor.Health;
import org.springframework.stereotype.Component;

@Component("dbHealthContributor")
public final class BoundedDataSourceHealthIndicator
        extends AbstractHealthIndicator {

    static final int VALIDATION_TIMEOUT_SECONDS = 3;

    private final DataSource dataSource;

    public BoundedDataSourceHealthIndicator(
            @Qualifier("dataSource") DataSource dataSource
    ) {
        super("Bounded DataSource health check failed");
        this.dataSource = dataSource;
    }

    @Override
    protected void doHealthCheck(Health.Builder builder) throws Exception {
        try (Connection connection = dataSource.getConnection()) {
            if (connection.isValid(VALIDATION_TIMEOUT_SECONDS)) {
                builder.up();
            } else {
                builder.down();
            }
        }
    }
}
