package com.walkingrpg.backend.risk.infrastructure;

import java.sql.Timestamp;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.walkingrpg.backend.risk.domain.ActivityRiskAssessment;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcActivityRiskRepository implements ActivityRiskRepository {

    private final JdbcTemplate jdbcTemplate;
    private final ObjectMapper objectMapper;

    public JdbcActivityRiskRepository(JdbcTemplate jdbcTemplate, ObjectMapper objectMapper) {
        this.jdbcTemplate = jdbcTemplate;
        this.objectMapper = objectMapper;
    }

    @Override
    public void save(ActivityRiskAssessment assessment) {
        jdbcTemplate.update("""
                INSERT INTO activity_risk_assessment (
                    user_id, device_id, local_date, authoritative_total,
                    accepted_delta, risk_score, decision, signals, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?::jsonb, ?)
                """,
                assessment.userId(),
                assessment.deviceId(),
                assessment.localDate(),
                assessment.authoritativeTotal(),
                assessment.acceptedDelta(),
                assessment.riskScore(),
                assessment.decision().name(),
                writeJson(assessment.signals()),
                Timestamp.from(assessment.createdAt())
        );
    }

    private String writeJson(Object value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("Не удалось сериализовать risk signals", exception);
        }
    }
}
